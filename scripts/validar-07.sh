#!/usr/bin/env bash
# validar-07.sh - valida os exercicios E1-E4 da T7 usando so oc (os Secrets sh.helm.release.v1.* guardam as revisoes).
# Uso: bash scripts/validar-07.sh [projeto]
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
NS="${1:-ex288-v3-t7}"; assert_v3_ns "$NS"; require_login

revs()   { oc get secret -n "$NS" -l "owner=helm,name=$1" --no-headers 2>/dev/null | wc -l | tr -d ' '; }
status() { oc get secret -n "$NS" -l "owner=helm,name=$1,status=deployed" --no-headers 2>/dev/null | wc -l | tr -d ' '; }

e1() {
  [ "$(revs rel1)" -ge 1 ] && [ "$(status rel1)" = 1 ] &&
  [ "$(ready_replicas "$NS" rel1-hello)" = 2 ] && route_has "$NS" rel1-hello 'ola helm'
}
e2() {
  [ "$(revs rel2)" = 3 ] && [ "$(status rel2)" = 1 ] &&
  [ "$(ready_replicas "$NS" rel2-hello)" -ge 1 ] && route_has "$NS" rel2-hello first
}
e3() {
  [ "$(status rel3)" = 1 ] && [ "$(ready_replicas "$NS" rel3-hello)" -ge 1 ] && route_has "$NS" rel3-hello from-tgz
}
e4() {
  [ "$(status rel4)" = 1 ] && [ "$(ready_replicas "$NS" rel4-hello)" -ge 1 ] && route_has "$NS" rel4-hello 'hello from helm v2'
}
test_task 'E1 rel1 (chart local, --set): 2 replicas e mensagem' e1
test_task 'E2 rel2: -f valores, upgrade, rollback => 3 revisoes, deployed, mensagem original' e2
test_task 'E3 rel3: instalado do pacote .tgz com message=from-tgz' e3
if exists "$INFRA_NS" route nexus 2>/dev/null && [ "$(ready_replicas "$INFRA_NS" nexus)" = 1 ]; then
  test_task 'E4 rel4: chart 0.2.0 vindo do repositorio Helm do Nexus' e4
else
  echo "SKIP  E4 rel4 do Nexus (Nexus fora do ar)"
fi
complete_validation 'T7'
