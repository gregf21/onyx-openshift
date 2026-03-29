{{/*
Expand the name of the chart.
*/}}
{{- define "onyx.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Fully qualified app name. Truncated to 63 chars (DNS label limit).
*/}}
{{- define "onyx.fullname" -}}
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
Chart name and version for the chart label.
*/}}
{{- define "onyx.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels applied to all resources.
*/}}
{{- define "onyx.labels" -}}
helm.sh/chart: {{ include "onyx.chart" . }}
{{ include "onyx.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels used in matchLabels and pod templates.
*/}}
{{- define "onyx.selectorLabels" -}}
app.kubernetes.io/name: {{ include "onyx.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Name of the PostgreSQL secret.
*/}}
{{- define "onyx.pgSecretName" -}}
{{- if .Values.auth.postgresql.existingSecret }}
{{- .Values.auth.postgresql.existingSecret }}
{{- else }}
{{- include "onyx.fullname" . }}-postgresql
{{- end }}
{{- end }}

{{/*
Name of the Redis secret.
*/}}
{{- define "onyx.redisSecretName" -}}
{{- if .Values.auth.redis.existingSecret }}
{{- .Values.auth.redis.existingSecret }}
{{- else }}
{{- include "onyx.fullname" . }}-redis
{{- end }}
{{- end }}

{{/*
OpenShift-compatible security context for all pods.
No runAsUser, no privileged — lets OpenShift assign a random UID.
*/}}
{{- define "onyx.podSecurityContext" -}}
runAsNonRoot: true
seccompProfile:
  type: RuntimeDefault
{{- end }}

{{- define "onyx.containerSecurityContext" -}}
allowPrivilegeEscalation: false
capabilities:
  drop:
    - ALL
{{- end }}

{{/*
Common env vars injected into all backend pods (API, celery workers, model servers).
Includes PostgreSQL and optionally Redis credentials from secrets.
*/}}
{{- define "onyx.backendEnv" -}}
- name: POSTGRES_USER
  valueFrom:
    secretKeyRef:
      name: {{ include "onyx.pgSecretName" . }}
      key: POSTGRES_USER
- name: POSTGRES_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "onyx.pgSecretName" . }}
      key: POSTGRES_PASSWORD
{{- if .Values.vectorDB.enabled }}
- name: REDIS_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "onyx.redisSecretName" . }}
      key: REDIS_PASSWORD
{{- end }}
{{- end }}
