# ArgoCD GitOps Configuration

ArgoCD will be implemented in the next phase to provide GitOps-based continuous deployment for DocBridge.

Planned implementation:
- ArgoCD installed on AKS cluster via Helm
- Application CRD pointing to DocBridge-kubernetes repository
- Automatic sync when Helm values or manifests change
- Health status visible in ArgoCD dashboard
- Rollback via ArgoCD UI or CLI

This folder will contain:
- argocd/application.yaml (ArgoCD Application CRD)
- argocd/project.yaml (ArgoCD AppProject for RBAC)
- argocd/install/ (ArgoCD installation values)

Current deployment method: Helm via GitHub Actions deploy.yml
Future deployment method: ArgoCD GitOps sync
