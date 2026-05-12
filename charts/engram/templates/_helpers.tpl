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
Return the PostgreSQL database URL for Engram Cloud.
When postgresql subchart is enabled and engram.databaseUrl is not set,
auto-builds the DSN from the subchart connection values.
*/}}
{{- define "engram.databaseUrl" -}}
{{- if .Values.engram.databaseUrl -}}
{{- .Values.engram.databaseUrl -}}
{{- else if .Values.postgresql.enabled -}}
{{- printf "postgres://%s:%s@%s-postgresql:5432/%s?sslmode=disable"
    .Values.postgresql.auth.username
    .Values.postgresql.auth.password
    .Release.Name
    .Values.postgresql.auth.database -}}
{{- end -}}
{{- end }}
