#!/usr/bin/env bash
# validar-02.sh - valida os exercicios E1-E5 da T2. Uso: bash scripts/validar-02.sh [projeto]
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
NS="${1:-ex288-v3-t2}"; assert_v3_ns "$NS"; require_login

e1() {
  [ "$(val "$NS" bc docker1 '{.spec.strategy.type}')" = Docker ] &&
  build_complete "$NS" docker1 && [ "$(ready_replicas "$NS" docker1)" -ge 1 ] &&
  route_has "$NS" docker1 '"app":"webapp-docker"' &&
  ! route_has "$NS" docker1 '"uid":0,'
}
e2() {
  local np
  [[ "$(val "$NS" bc docker-nexus '{.spec.strategy.dockerStrategy.buildArgs[?(@.name=="NPM_REGISTRY")].value}')" == *"$(nexus_host)"* ]] &&
  build_complete "$NS" docker-nexus &&
  [ "$(val "$NS" bc docker-nexus '{.spec.output.to.name}')" = docker-nexus:1.0 ] &&
  np="$(nexus_pass)" &&
  curl_route "$(nexus_url)/service/rest/v1/search?repository=npm-proxy&name=ms" -u "admin:$np" | grep -q '"name" *: *"ms"'
}
e3() {
  [ "$(val "$NS" bc root-app '{.spec.strategy.dockerStrategy.dockerfilePath}')" = Dockerfile.root ] &&
  [ "$(build_count "$NS" root-app)" -ge 2 ] &&
  [ "$(ready_replicas "$NS" root-app)" -ge 1 ] &&
  route_has "$NS" root-app '"app":"webapp-docker"'
}
e4() {
  [ "$(val "$NS" bc site-bin '{.spec.source.type}')" = Binary ] &&
  [ "$(val "$NS" bc site-bin '{.spec.strategy.type}')" = Docker ] &&
  [ "$(ready_replicas "$NS" site-bin)" -ge 1 ] &&
  route_has "$NS" site-bin 'site 1.0'
}
e5() {
  exists "$NS" imagestreamtag pushed:1.0 &&
  [ "$(ready_replicas "$NS" pushed)" -ge 1 ] &&
  [ -n "$(route_host "$NS" pushed)" ] && route_has "$NS" pushed '"app":"webapp-docker"'
}
test_task 'E1 docker1: estrategia Docker detectada, build Complete, rota ok, UID != 0' e1
test_task 'E2 docker-nexus: ARG NPM_REGISTRY do Nexus, build Complete, ms presente no npm-proxy' e2
test_task 'E3 root-app: Dockerfile.root corrigido (>= 2 builds), pod Ready, rota ok' e3
test_task 'E4 site-bin: build binario Docker com artefato do Nexus, rota mostra site 1.0' e4
test_task 'E5 pushed:1.0 publicado com podman e deploy a partir da ImageStreamTag' e5
complete_validation 'T2'
