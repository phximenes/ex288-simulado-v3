#!/usr/bin/env bash
# validar-04.sh - valida os exercicios E1-E4 da T4. Uso: bash scripts/validar-04.sh [projeto]
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
NS="${1:-ex288-v3-t4}"; assert_v3_ns "$NS"; require_login
SH="${NS}-shared"
ENVJ() { val "$NS" deployment cfgapp "{.spec.template.spec.containers[0].env[?(@.name==\"$1\")]$2}"; }

e1() {
  [ "$(val "$NS" cm app-config '{.data.GREETING}')" = Ola ] &&
  [ "$(val "$NS" cm app-config '{.data.LANG_CODE}')" = pt-BR ] &&
  [ "$(val "$NS" cm app-config '{.data.API_HOST}')" = http://api:8080 ] &&
  [ "$(ENVJ GREETING .valueFrom.configMapKeyRef.name)" = app-config ] &&
  [ "$(ENVJ LANG_CODE .valueFrom.configMapKeyRef.name)" = app-config ] &&
  [ "$(ENVJ API_HOST .valueFrom.configMapKeyRef.name)" = app-config ] &&
  route_has "$NS" cfgapp '"greeting":"Ola"' && route_has "$NS" cfgapp '"lang":"pt-BR"' && route_has "$NS" cfgapp '"apiHost":"http://api:8080"'
}
e2() {
  [ "$(ENVJ DB_USER .valueFrom.secretKeyRef.name)" = db-credentials ] &&
  [ "$(ENVJ DB_USER .valueFrom.secretKeyRef.key)" = username ] &&
  [ "$(ENVJ DB_PASSWORD .valueFrom.secretKeyRef.key)" = password ] &&
  [ -z "$(ENVJ DB_USER .value)" ] && [ -z "$(ENVJ DB_PASSWORD .value)" ] &&
  route_has "$NS" cfgapp '"dbUser":"app"' && route_has "$NS" cfgapp '"hasPassword":true'
}
e3() {
  local a b
  a="$(secret_val "$NS" shared-api token)"; b="$(secret_val "$SH" shared-api token)"
  [ -n "$a" ] && [ "$a" = "$b" ] &&
  [ "$(ENVJ API_TOKEN .valueFrom.secretKeyRef.name)" = shared-api ] &&
  [ "$(ENVJ API_TOKEN .valueFrom.secretKeyRef.key)" = token ] &&
  route_has "$NS" cfgapp '"hasToken":true'
}
e4() {
  [ "$(ENVJ APP_HOST .valueFrom.configMapKeyRef.name)" = extra-config ] &&
  [ "$(ENVJ APP_PORT .valueFrom.configMapKeyRef.key)" = PORT ] &&
  [ "$(val "$NS" deployment cfgapp '{.spec.template.spec.containers[0].volumeMounts[?(@.mountPath=="/etc/app")].readOnly}')" = true ] &&
  [ "$(val "$NS" deployment cfgapp '{.spec.template.spec.volumes[?(@.configMap.name=="app-files")].name}')" != "" ] &&
  route_has "$NS" cfgapp '"appHost":"cfg.example.invalid"' &&
  oc exec -n "$NS" deploy/cfgapp -- cat /etc/app/app.properties | grep -qx 'feature.flag=on'
}
test_task 'E1 ConfigMap app-config injetado por completo (configMapKeyRef) e rota reflete' e1
test_task 'E2 Secret existente db-credentials: DB_USER/DB_PASSWORD via secretKeyRef, sem valor literal' e2
test_task 'E3 Secret do outro projeto recriado como shared-api e API_TOKEN via secretKeyRef' e3
test_task 'E4 extra-config com prefixo APP_ e app-files montado somente leitura em /etc/app' e4
test_task 'Extra: rollout do cfgapp concluido' wait_rollout "$NS" cfgapp 120s
complete_validation 'T4'
