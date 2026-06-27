
{{- define "docbridge.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}


{{- define "docbridge.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "docbridge.image" -}}
{{- $registry := .context.Values.global.imageRegistry -}}
{{- $tag := .context.Values.global.imageTag -}}
{{- $serviceTag := dig .name "image" "tag" "" .context.Values.services -}}
{{- if $serviceTag -}}
  {{- $tag = $serviceTag -}}
{{- end -}}
{{- printf "%s/%s:%s" $registry .name $tag -}}
{{- end }}
