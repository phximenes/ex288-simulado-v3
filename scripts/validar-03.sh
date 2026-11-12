#!/usr/bin/env bash
# validar-03.sh - valida os exercicios E1-E4 da T3. Uso: bash scripts/validar-03.sh [projeto]
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
NS="${1:-ex288-v3-t3}"; assert_v3_ns "$NS"; require_login

e1() {
  [ "$(val "$NS" bc s2i1 '{.spec.strategy.type}')" = Source ] &&
  [[ "$(val "$NS" bc s2i1 '{.spec.strategy.sourceStrategy.from.name}')" == nodejs* ]] &&
  build_complete "$NS" s2i1 && [ "$(ready_replicas "$NS" s2i1)" -ge 1 ] &&
  route_has "$NS" s2i1 '"message":"from-s2i-environment"' &&
  route_has "$NS" s2i1 'built-at=' /build-info
}
e2() {
  local env; env="$(val "$NS" bc s2i-nexus '{.spec.strategy.sourceStrategy.env[?(@.name=="npm_config_registry")].value}')"
  [[ "$env" == *"$(nexus_host)"* ]] && build_complete "$NS" s2i-nexus &&
  [ "$(ready_replicas "$NS" s2i-nexus)" -ge 1 ] &&
  route_has "$NS" s2i-nexus "$(nexus_host)" /build-info
}
e3() {
  local env; env="$(val "$NS" bc s2i-broken '{.spec.strategy.sourceStrategy.env[?(@.name=="npm_config_registry")].value}')"
  [[ "$env" != *127.0.0.1* ]] && build_complete "$NS" s2i-broken &&
  [ "$(ready_replicas "$NS" s2i-broken)" -ge 1 ] && [ -n "$(route_host "$NS" s2i-broken)" ] &&
  route_has "$NS" s2i-broken '"app":"webapp"'
}
e4() {
  route_has "$NS" s2i1 'custom=yes' /build-info &&
  [ "$(build_count "$NS" s2i1)" -ge 2 ] &&
  [ "$(val "$NS" build "$(last_build "$NS" s2i1)" '{.status.phase}')" = Complete ]
}
test_task 'E1 s2i1: builder nodejs, build Complete, .s2i/environment aplicado, /build-info' e1
test_task 'E2 s2i-nexus: npm_config_registry (build-env) aponta para o Nexus e aparece no /build-info' e2
test_task 'E3 s2i-broken: BuildConfig corrigido, build Complete, rota responde' e3
test_task 'E4 assemble customizado no repositorio: custom=yes no /build-info (>= 2 builds)' e4
complete_validation 'T3'
