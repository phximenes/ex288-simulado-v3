#!/usr/bin/env bash
# preparar-05.sh - projeto da T5 com quatro Deployments (sem probes ou com probes defeituosas).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
require_login
NS=ex288-v3-t5
new_project "$NS"
variant() {  # <nome> <START_DELAY>
  sed -e "s/probeapp/$1/g" -e "s/value: \"25\"/value: \"$2\"/" "$LAB_ROOT/apps/k8s/probeapp.yaml" | oc apply -n "$NS" -f - >/dev/null
}
variant probeapp 25
variant probeapp2 10
variant probe-broken 10
variant probeapp3 40
# defeitos propositais: liveness em porta errada / liveness agressiva demais para uma app lenta
oc set probe -n "$NS" deployment/probe-broken --liveness --get-url=http://:9090/healthz --initial-delay-seconds=3 --period-seconds=5 --failure-threshold=1 >/dev/null
oc set probe -n "$NS" deployment/probeapp3 --liveness --get-url=http://:8080/healthz --initial-delay-seconds=5 --period-seconds=5 --failure-threshold=2 >/dev/null
echo "Projeto $NS pronto: probeapp, probeapp2, probe-broken e probeapp3 (sem probes ou com probes defeituosas)."
