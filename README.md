# DocBridge - Kubernetes Repository

This repository contains all raw Kubernetes manifests, Helm charts, and GitOps integration configurations for the DocBridge application stack.

- Application Code: [DocBridge-application](../DocBridge-application)
- Infrastructure Code: [DocBridge-terraform](../DocBridge-terraform)

## Architecture Overview

All microservices are deployed inside a managed Azure Kubernetes Service (AKS) cluster under a secure, locked-down networking footprint.

```
                    Internet
                       |
                       v
         +-------------+-------------+
         |    Azure App Gateway      | (Application Gateway Ingress Controller - AGIC)
         +-------------+-------------+
                       |
                       v
        +--------------+--------------+
        |    production namespace     |
        |  +-----------------------+  |
        |  |  Ingress controller   |  |
        |  +-----------+-----------+  |
        |              |              |
        |              v              |
        |  +-----------+-----------+  |
        |  |    api-gateway pod    |  |
        |  +-----------+-----------+  |
        |              |              |
        |     +--------+--------+     |
        |     |                 |     |
        |     v                 v     |
        | +---+---+         +---+---+ |
        | | pods  |         | pods  | |
        | +-------+         +-------+ |
        +-----------------------------+
```

### Production Namespace

By default, the application runs inside the `production` namespace instead of `default` or `docbridge` namespaces. 
- Implements strict role-based access controls (RBAC).
- Enables logical segregation of production compute workloads, configmaps, and secrets.
- Enforces namespace-level network policies to block traffic leaks.

## Helm Chart Structure

The Helm chart is located under `helm/docbridge/`:
- `Chart.yaml`: Contains the chart metadata and version numbers.
- `values.yaml`: Defines default values, global settings, image registry routes, default probe paths, and resources.
- `values.dev.yaml`: Environment-specific overrides.
- `templates/`: Templates for resource creation:
  - `namespace.yaml`: Production namespace definition.
  - `serviceaccount.yaml`: Defines workload identities.
  - `secretproviderclass.yaml`: Secret store CSI driver parameters linking to Azure Key Vault.
  - `configmap.yaml`: App configurations.
  - `ingress.yaml`: Ingress controller setup linking to App Gateway.
  - `deployments/`: Contains deployments templates for all 11 microservices and Redis.
  - `services/`: Contains Service definitions.
  - `networkpolicies/`: Implements egress and ingress rules.
  - `jobs/`: Database migration and seeding jobs.
  - `hpa/`: Autoscaling rules.

## Secrets Management & Workload Identity

DocBridge uses **Azure Workload Identity** and the **Secrets Store CSI Driver** to mount secrets without exposing raw credentials.

1. **Pod serviceAccount**: Pods specify `serviceAccountName: docbridge-workload-sa`.
2. **Managed Identity Token**: The AKS OIDC issuer validates the pod service account and returns an Azure AD token.
3. **CSI Secret Retrieval**: The CSI driver logs in to Azure Key Vault using the token, retrieves secrets (`db-password`, etc.), and creates a native Kubernetes secret (`docbridge-secrets`) in the pod namespace.
4. **Volume Mount**: Secrets are mounted as a tmpfs volume inside `/mnt/secrets-store/` and referenced as environment variables.

## Application Gateway Ingress Controller (AGIC)

External access is managed via AGIC, which connects the Azure Application Gateway directly to the Kubernetes Ingress resource.
- AGIC watches for changes to Ingress resources in the `production` namespace.
- It dynamically updates backend address pools on the Azure Application Gateway to point directly to the AKS pods' IPs.
- This eliminates the need for a secondary in-cluster ingress controller (like Nginx-Ingress) and provides low-latency SSL offloading and WAF rules.

## Zero-Trust Network Policies

The `templates/networkpolicies/` directory implements a zero-trust model:
- `default-deny-all.yaml`: Denies all ingress and egress traffic by default.
- `allow-gateway-to-services.yaml`: Allows the API Gateway to route traffic to backend microservices, and blocks direct client communication.
- `allow-services-to-db.yaml`: Restricts database egress to only services that require state storage.
- `allow-redis-ingress.yaml`: Restricts Redis ingress.
- `allow-monitoring.yaml`: Restricts metrics gathering.

## Health Probes

All microservices define health endpoints:
- **Liveness probe (`/healthz`)**: Verifies the service container is alive. If this returns a non-200 code, Kubernetes kills and restarts the pod.
- **Readiness probe (`/ready`)**: Verifies the service is ready to serve traffic. If this fails, the pod is taken out of the load balancer pool.
- **Backward compatibility**: The old `/health` and `/api/v1/health` routes remain active.

## Manual Helm Chart Installation

You can install the Helm chart manually:
```bash
helm upgrade --install docbridge ./helm/docbridge \
  --namespace production \
  --create-namespace \
  --values ./helm/docbridge/values.yaml \
  --values ./helm/docbridge/values.dev.yaml \
  --set azure.keyVaultName=<your_keyvault> \
  --set azure.workloadIdentityClientId=<your_identity_client_id> \
  --set azure.tenantId=<your_tenant_id> \
  --set database.host=<your_db_fqdn> \
  --set gateway.corsOrigin=http://<app_gateway_public_ip> \
  --wait \
  --timeout 10m
```

### Manifest Dry-Run Validation

To validate the syntax of generated manifests before applying:
```bash
helm template ./helm/docbridge \
  --values ./helm/docbridge/values.yaml \
  --values ./helm/docbridge/values.dev.yaml \
  --set azure.keyVaultName=test \
  --set azure.workloadIdentityClientId=test \
  --set azure.tenantId=test \
  --set database.host=test \
  --set gateway.corsOrigin=http://1.2.3.4
```
For raw manifests:
```bash
kubectl apply -f kubernetes/ --dry-run=client --namespace production
```

## ArgoCD GitOps Placeholder

ArgoCD GitOps configurations will be implemented in a future phase.
For more details, see [argocd/README.md](argocd/README.md).

## Branching Strategy & Protection Rules

- `main`: Protected branch. Merges only via PR.
- `develop`: Integration branch.
- Feature branches `feature/*` branch off `develop`.
- Direct pushes are blocked on both `main` and `develop`.
