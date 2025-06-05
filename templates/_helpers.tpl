{{/*
Expand the name of the chart.
*/}}
{{- define "dify.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "dify.fullname" -}}
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
{{- define "dify.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "dify.labels" -}}
dify.sh/chart: {{ include "dify.chart" . }}
{{ include "dify.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "dify.selectorLabels" -}}
app.kubernetes.io/name: {{ include "dify.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "dify.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "dify.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Host name for the gateway
*/}}
{{- define "dify.hostName" -}}
{{- if .Values.gateway.hostName }}
{{- .Values.gateway.hostName | quote }}
{{- else }}
{{- printf "%s.%s.svc.cluster.local" (include "dify.fullname" .) .Release.Namespace | quote }}
{{- end }}
{{- end }}

{{/*
Common environment variables
*/}}
{{- define "dify.commonEnvs" -}}
- name: EDITION
  value: {{ .Values.global.edition | quote }}
{{- range tuple "CONSOLE_API_URL" "CONSOLE_WEB_URL" "SERVICE_API_URL" "APP_API_URL" "APP_WEB_URL" "FILES_URL" }}
- name: {{ . }}
  value: {{ printf "https://%s" (include "dify.hostName" $ | replace "\"" "") }}
{{- end }}
{{- end }}