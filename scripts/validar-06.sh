#!/usr/bin/env bash
# validar-06.sh - valida os exercicios E1-E4 da T6. Uso: bash scripts/validar-06.sh [projeto]
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
NS="${1:-ex288-v3-t6}"; assert_v3_ns "$NS"; require_login

e1() {
  [ "$(ready_replicas "$NS" tpl1)" = 2 ] &&
  [ "$(secret_val "$NS" tpl1-token token | wc -c | tr -d ' ')" = 16 ] &&
  [ "$(val "$NS" deployment tpl1 '{.metadata.labels.template}')" = webapp-template ] &&
  [ "$(val "$NS" route tpl1 '{.metadata.labels.template}')" = webapp-template ] &&
  route_has "$NS" tpl1 ola-template
}
e2() {
  exists "$NS" template webapp-template &&
  [ "$(ready_replicas "$NS" tpl2)" -ge 1 ] && route_has "$NS" tpl2 param-file
}
e3() {
  exists "$NS" template mini &&
  [ "$(val "$NS" template mini '{.parameters[?(@.name=="NAME")].required}')" = true ] &&
  [ "$(val "$NS" template mini '{.parameters[?(@.name=="MESSAGE")].value}')" = hi ] &&
  [ "$(val "$NS" template mini '{.objects[*].kind}' | wc -w | tr -d ' ')" -ge 3 ] &&
  [ "$(ready_replicas "$NS" mini-a)" -ge 1 ] && [ "$(ready_replicas "$NS" mini-b)" -ge 1 ] &&
  route_has "$NS" mini-a hi && route_has "$NS" mini-b bravo
}
e4() {
  [ "$(val "$NS" bc site-tpl '{.spec.source.git.uri}')" = "$(git_url httpd-ex)" ] &&
  [ -n "$(val "$NS" bc site-tpl '{.spec.source.sourceSecret.name}')" ] &&
  build_complete "$NS" site-tpl && route_has "$NS" site-tpl httpd-ex
}
test_task 'E1 tpl1 (-f arquivo): 2 replicas, token de 16 caracteres, rotulo do template, rota' e1
test_task 'E2 Template cadastrado no projeto + --param-file: tpl2 responde param-file' e2
test_task 'E3 template proprio mini (NAME obrigatorio, MESSAGE=hi): mini-a e mini-b' e3
if exists "$INFRA_NS" route gitea 2>/dev/null && [ "$(ready_replicas "$INFRA_NS" gitea)" = 1 ]; then
  test_task 'E4 httpd-example com o Git interno (source secret) e rota' e4
else
  echo "SKIP  E4 httpd-example com o Git interno (Git interno fora do ar)"
fi
complete_validation 'T6'
