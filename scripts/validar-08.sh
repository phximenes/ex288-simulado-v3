#!/usr/bin/env bash
# validar-08.sh - valida os exercicios E1-E4 da T8. Uso: bash scripts/validar-08.sh [projeto]
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
NS="${1:-ex288-v3-t8}"; assert_v3_ns "$NS"; require_login
if ! has_tekton; then
  echo "SKIP  todos: Pipelines Operator nao instalado (API tekton.dev ausente)"; exit 3
fi

succeeded() {  # <pipeline> -> existe PipelineRun Succeeded
  oc get pipelinerun -n "$NS" -l "tekton.dev/pipeline=$1" -o jsonpath='{range .items[*]}{.status.conditions[0].reason}{"\n"}{end}' 2>/dev/null | grep -qx Succeeded
}
e1() {
  [ "$(val "$NS" pipeline mini-ci '{.spec.tasks[*].name}' | wc -w | tr -d ' ')" -ge 2 ] &&
  [ -n "$(val "$NS" pipeline mini-ci '{.spec.tasks[?(@.runAfter)].name}')" ] &&
  [ -n "$(val "$NS" pipeline mini-ci '{.spec.params[?(@.name=="MESSAGE")].default}')" ] &&
  succeeded mini-ci
}
e2() {
  [ "$(val "$NS" pipeline build-and-deploy '{.spec.tasks[0].taskRef.resolver}')" = cluster ] &&
  succeeded build-and-deploy && [ "$(ready_replicas "$NS" ci-app)" -ge 1 ] && route_has "$NS" ci-app '"app":"webapp-docker"'
}
e3() {
  exists "$NS" pipeline broken-ci &&
  [ "$(val "$NS" pipeline broken-ci '{.spec.tasks[?(@.name=="read")].runAfter[0]}')" = write ] &&
  succeeded broken-ci
}
e4() {
  local t; t="$(val "$NS" bc native '{.spec.triggers[*].type}')"
  [[ "$t" == *Generic* ]] && [[ "$t" == *ImageChange* ]] &&
  [ -n "$(val "$NS" bc native '{.spec.postCommit.script}{.spec.postCommit.command}')" ] &&
  [ "$(build_count "$NS" native)" -ge 2 ] &&
  oc logs -n "$NS" "build/$(last_build "$NS" native)" 2>/dev/null | grep -q 'TESTS PASSED'
}
test_task 'E1 mini-ci: 2 tasks com runAfter, parametro padrao, PipelineRun Succeeded' e1
if exists "$INFRA_NS" route gitea 2>/dev/null && [ "$(ready_replicas "$INFRA_NS" gitea)" = 1 ]; then
  test_task 'E2 build-and-deploy: git-clone (resolver cluster) -> buildah -> deploy, rota ok' e2
  test_task 'E4 BuildConfig native: Generic + ImageChange + post-commit, build por webhook com TESTS PASSED' e4
else
  echo "SKIP  E2 e E4 (Git interno fora do ar)"
fi
test_task 'E3 broken-ci corrigido: runAfter e workspace, PipelineRun Succeeded' e3
complete_validation 'T8'
