{{- define "selfscan.name" -}}
{{ .Release.Name }}
{{- end }}

{{- define "selfscan.sa" -}}
{{ printf "%s-sa" (include "selfscan.name" .) }}
{{- end }}