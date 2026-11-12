#!/usr/bin/env bash
# validar-05.sh - valida os exercicios E1-E4 da T5. Uso: bash scripts/validar-05.sh [projeto]
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
NS="${1:-ex288-v3-t5}"; assert_v3_ns "$NS"; require_login

P() { val "$NS" deployment "$1" "{.spec.template.spec.containers[0].$2}"; }   # <deploy> <caminho-jsonpath>
pod_ready_clean() {  # <app> -> pod(s) ativo(s) Ready e nenhum reinicio (pods Terminating sao ignorados)
  [ "$(ready_replicas "$NS" "$1")" -ge 1 ] || return 1
  local r; for r in $(pod_restarts "$NS" "$1"); do [ "$r" -eq 0 ] || return 1; done
}
budget() { echo $(( $(P "$1" "$2.failureThreshold") * $(P "$1" "$2.periodSeconds") )); }   # failureThreshold * period

e1() {
  [ "$(P probeapp startupProbe.httpGet.path)" = /healthz ] && [ "$(P probeapp startupProbe.httpGet.port)" = 8080 ] &&
  [ "$(budget probeapp startupProbe)" -ge 60 ] &&
  [ "$(P probeapp livenessProbe.httpGet.path)" = /healthz ] && [ "$(P probeapp livenessProbe.periodSeconds)" = 10 ] &&
  [ "$(P probeapp livenessProbe.timeoutSeconds)" = 2 ] && [ "$(P probeapp livenessProbe.failureThreshold)" = 3 ] &&
  [ "$(P probeapp readinessProbe.httpGet.path)" = /ready ] && [ "$(P probeapp readinessProbe.periodSeconds)" = 5 ] &&
  pod_ready_clean probeapp
}
e2() {
  [ "$(P probeapp2 startupProbe.tcpSocket.port)" = 8080 ] && [ "$(P probeapp2 readinessProbe.tcpSocket.port)" = 8080 ] &&
  [ -n "$(P probeapp2 livenessProbe.exec.command)" ] && pod_ready_clean probeapp2
}
e3() {
  [ "$(P probe-broken livenessProbe.httpGet.port)" = 8080 ] && pod_ready_clean probe-broken
}
e4() {
  [ -n "$(P probeapp3 livenessProbe)" ] && [ -n "$(P probeapp3 startupProbe)" ] &&
  [ "$(budget probeapp3 startupProbe)" -ge 50 ] && pod_ready_clean probeapp3
}
test_task 'E1 probeapp: startup (>= 60 s), liveness e readiness HTTP com os tempos pedidos, Ready sem reinicios' e1
test_task 'E2 probeapp2: startup/readiness TCP 8080 e liveness por comando, Ready' e2
test_task 'E3 probe-broken: liveness corrigida para 8080, Ready sem reinicios' e3
test_task 'E4 probeapp3: liveness mantida + startup (>= 50 s), Ready sem reinicios' e4
complete_validation 'T5'
