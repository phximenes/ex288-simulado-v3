#!/usr/bin/env bash
# validar-01.sh - valida os exercicios E1-E4 da T1. Uso: bash scripts/validar-01.sh [projeto]
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
NS="${1:-ex288-v3-t1}"; assert_v3_ns "$NS"; require_login
WEBAPP="$(git_url webapp)"

e1() {
  [ "$(val "$NS" bc web1 '{.spec.source.git.uri}')" = "$WEBAPP" ] &&
  [ "$(val "$NS" bc web1 '{.spec.source.sourceSecret.name}')" = git-creds ] &&
  [ "$(val "$NS" secret git-creds '{.type}')" = kubernetes.io/basic-auth ] &&
  build_complete "$NS" web1 &&
  [ "$(ready_replicas "$NS" web1)" -ge 1 ] &&
  route_has "$NS" web1 '"branch":"main'
}
e2() {
  [ "$(val "$NS" bc web-dev '{.spec.source.git.ref}')" = dev ] &&
  [ "$(val "$NS" deployment web-dev '{.metadata.labels.env}')" = dev ] &&
  [ "$(val "$NS" bc web-dev '{.metadata.labels.env}')" = dev ] &&
  env_list "$NS" web-dev | grep -qx 'APP_MESSAGE=from-dev' &&
  route_has "$NS" web-dev '"branch":"dev"' &&
  route_has "$NS" web-dev '"message":"from-dev"'
}
e3() {
  [ "$(val "$NS" bc api '{.spec.source.contextDir}')" = api ] &&
  [ "$(val "$NS" bc site '{.spec.source.contextDir}')" = site ] &&
  [[ "$(val "$NS" bc site '{.spec.strategy.sourceStrategy.from.name}')" == httpd* ]] &&
  route_has "$NS" api monorepo-api &&
  [ "$(route_tls "$NS" site-tls)" = edge ] &&
  [ "$(val "$NS" route site-tls '{.spec.tls.insecureEdgeTerminationPolicy}')" = Redirect ] &&
  [ "$(val "$NS" route site-tls '{.spec.to.name}')" = site ] &&
  [[ "$(http_body "https://$(route_host "$NS" site-tls)/")" == *monorepo-site* ]]
}
e4() {
  route_has "$NS" web1 '"branch":"main-v2"' &&
  [ "$(build_count "$NS" web1)" -ge 2 ] &&
  [ "$(val "$NS" build "$(last_build "$NS" web1)" '{.status.phase}')" = Complete ]
}
test_task 'E1 web1: Git privado, source secret git-creds, build Complete, rota main' e1
test_task 'E2 web-dev: branch dev, rotulo env=dev, APP_MESSAGE=from-dev, rota reflete' e2
test_task 'E3 monorepo: api e site (context-dir), route edge site-tls com Redirect' e3
test_task 'E4 push em main + novo build: rota devolve main-v2 (>= 2 builds)' e4
complete_validation 'T1'
