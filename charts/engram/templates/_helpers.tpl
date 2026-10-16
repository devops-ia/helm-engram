{{/*
Expand the name of the chart.
*/}}
{{- define "engram.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "engram.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "engram.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "engram.labels" -}}
helm.sh/chart: {{ include "engram.chart" . }}
{{ include "engram.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "engram.selectorLabels" -}}
app.kubernetes.io/name: {{ include "engram.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "engram.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "engram.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Return the name of the secret containing sensitive env vars.
Uses existingSecret if set, otherwise the chart-managed secret.
*/}}
{{- define "engram.secretName" -}}
{{- if .Values.engram.existingSecret }}
{{- .Values.engram.existingSecret }}
{{- else }}
{{- include "engram.fullname" . }}
{{- end }}
{{- end }}

{{/*
Fail-fast configuration validation.
Rendered from templates/validate.yaml so it runs on `helm install/upgrade` and on
`helm template` (ArgoCD, Flux, helmfile), not only when NOTES.txt is rendered.
Token/DSN checks are skipped when existingSecret is set — Helm cannot inspect Secret contents.
*/}}
{{- define "engram.validateConfig" -}}
{{- if empty .Values.engram.allowedProjects }}
  {{- fail "\n\nERROR: engram.allowedProjects is required.\nSet it to a comma-separated list of project names, e.g.:\n  --set engram.allowedProjects=\"my-project\"\n" }}
{{- end }}
{{- if not .Values.engram.insecureNoAuth }}
  {{- if empty .Values.engram.existingSecret }}
    {{- if empty .Values.engram.cloudToken }}
      {{- fail "\n\nERROR: engram.cloudToken is required when engram.insecureNoAuth=false (authenticated mode).\nSet engram.cloudToken or use engram.existingSecret.\nFor local dev only: set engram.insecureNoAuth=true instead.\n" }}
    {{- end }}
    {{- if empty .Values.engram.jwtSecret }}
      {{- fail "\n\nERROR: engram.jwtSecret is required when engram.insecureNoAuth=false.\nSet engram.jwtSecret or use engram.existingSecret.\n" }}
    {{- end }}
  {{- end }}
  {{- if and .Values.engram.tokenPepper (eq .Values.engram.tokenPepper .Values.engram.jwtSecret) }}
    {{- fail "\n\nERROR: engram.tokenPepper must be different from engram.jwtSecret.\n" }}
  {{- end }}
{{- else }}
  {{- if not (empty .Values.engram.cloudToken) }}
    {{- fail "\n\nERROR: engram.cloudToken must be empty when engram.insecureNoAuth=true.\nThese are mutually exclusive auth modes.\n" }}
  {{- end }}
  {{- if not (empty .Values.engram.adminToken) }}
    {{- fail "\n\nERROR: engram.adminToken requires authenticated mode (engram.insecureNoAuth must be false).\n" }}
  {{- end }}
  {{- if not (empty .Values.engram.tokenPepper) }}
    {{- fail "\n\nERROR: engram.tokenPepper requires authenticated mode (engram.insecureNoAuth must be false).\n" }}
  {{- end }}
{{- end }}
{{- if empty (include "engram.databaseUrlSource" .) }}
  {{- fail "\n\nERROR: no PostgreSQL connection configured.\nSet engram.databaseUrl, engram.existingSecret, or enable the bundled PostgreSQL (postgresql.enabled=true).\n" }}
{{- end }}
{{- if and .Values.postgresql.enabled (empty .Values.postgresql.auth.password) (empty .Values.postgresql.auth.existingSecret) }}
  {{- fail "\n\nERROR: postgresql.auth.password or postgresql.auth.existingSecret is required when postgresql.enabled=true.\nGenerate one with: openssl rand -hex 24\n" }}
{{- end }}
{{- end }}

{{/*
Where ENGRAM_DATABASE_URL comes from:
- existingSecret: key ENGRAM_DATABASE_URL of engram.existingSecret
- value:          chart-managed Secret built from engram.databaseUrl
- bundled:        built in the pod from the bundled PostgreSQL password Secret
- "" (empty):     not configured (validation fails)
*/}}
{{- define "engram.databaseUrlSource" -}}
{{- if .Values.engram.existingSecret -}}
existingSecret
{{- else if .Values.engram.databaseUrl -}}
value
{{- else if .Values.postgresql.enabled -}}
bundled
{{- end -}}
{{- end }}

{{/*
Bundled PostgreSQL resource name (Service, StatefulSet and chart-managed Secret).
*/}}
{{- define "engram.postgresql.fullname" -}}
{{- printf "%s-postgresql" .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Name of the Secret that holds the bundled PostgreSQL password.
*/}}
{{- define "engram.postgresql.secretName" -}}
{{- default (include "engram.postgresql.fullname" .) .Values.postgresql.auth.existingSecret }}
{{- end }}

{{/*
Key inside the bundled PostgreSQL password Secret.
*/}}
{{- define "engram.postgresql.secretKey" -}}
{{- if .Values.postgresql.auth.existingSecret }}
{{- .Values.postgresql.auth.existingSecretPasswordKey | default "password" }}
{{- else }}
{{- "password" }}
{{- end }}
{{- end }}

{{/*
DSN for the bundled PostgreSQL. The password is injected through the
ENGRAM_POSTGRES_PASSWORD env var using Kubernetes $(VAR) interpolation,
so it never needs to be duplicated into the Engram Secret.
*/}}
{{- define "engram.postgresql.databaseUrl" -}}
{{- printf "postgres://%s:$(ENGRAM_POSTGRES_PASSWORD)@%s:%v/%s?sslmode=disable" .Values.postgresql.auth.username (include "engram.postgresql.fullname" .) .Values.postgresql.service.port .Values.postgresql.auth.database -}}
{{- end }}

{{/*
Image for the wait-for-postgresql init container.
*/}}
{{- define "engram.waitForReady.image" -}}
{{- $img := .Values.postgresql.waitForReady.image -}}
{{- if $img.registry -}}
{{- printf "%s/%s:%s" $img.registry $img.repository $img.tag -}}
{{- else -}}
{{- printf "%s:%s" $img.repository $img.tag -}}
{{- end -}}
{{- end }}
