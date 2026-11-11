{{- define "spring-app.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "spring-app.fullname" -}}
{{- printf "%s-%s" .Release.Name (include "spring-app.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "spring-app.labels" -}}
app.kubernetes.io/name: {{ include "spring-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "spring-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "spring-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "spring-app.serviceAccountName" -}}
{{- if .Values.serviceAccount.name -}}
{{- .Values.serviceAccount.name -}}
{{- else -}}
{{- include "spring-app.fullname" . -}}
{{- end -}}
{{- end -}}
