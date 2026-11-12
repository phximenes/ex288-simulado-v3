#!/usr/bin/env bash
# lib.sh - funcoes comuns dos scripts do v3 (bash + oc + curl + git + coreutils; jq nao e necessario).
# Uso: source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
# Regras: so toca em projetos ex288-v3-*; nunca grava senhas/tokens em arquivos do material.
# Variaveis: OC=/caminho/oc  OC_AS=developer (impersona; so para testes com kubeconfig admin)
#            ROUTE_IP=127.0.0.1 (IP do roteador do CRC para curl --resolve; vazio = usar DNS normal)

# shellcheck disable=SC2034  # usado pelos scripts que fazem source deste arquivo
LAB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
V3_PREFIX="ex288-v3-"
INFRA_NS="${V3_PREFIX}infra"
ROUTE_IP="${ROUTE_IP-127.0.0.1}"
APPS_DOMAIN="${APPS_DOMAIN:-apps-crc.testing}"
OC_BIN="${OC:-oc}"

oc() {
  if [ -n "${OC_AS:-}" ]; then
    command "$OC_BIN" --as="$OC_AS" --as-group=system:authenticated --as-group=system:authenticated:oauth "$@"
  else
    command "$OC_BIN" "$@"
  fi
}

die() { echo "FAIL: $*" >&2; exit 2; }

assert_v3_ns() {
  case "$1" in "${V3_PREFIX}"*) ;; *) die "recusado: '$1' nao tem o prefixo ${V3_PREFIX}" ;; esac
}

require_login() {
  command -v "$OC_BIN" >/dev/null 2>&1 || [ -x "$OC_BIN" ] || die "oc nao encontrado (defina OC=/caminho/oc)"
  oc whoami >/dev/null 2>&1 || die "nao logado no cluster (oc login ... ou KUBECONFIG)"
}

# ---- projetos (sem 'oc project': nao altera o contexto do kubeconfig) ----
new_project() {  # <nome completo ex288-v3-*>
  local ns="$1" i; assert_v3_ns "$ns"
  # Projeto recem-deletado (--wait=false) fica Terminating por ~30 s: ainda "existe" para o oc get, mas nao aceita objetos.
  # Sem esta espera, limpar seguido de preparar deixava projetos sem criar (VERIFICADO no CRC 4.22.14).
  for i in $(seq 1 60); do
    [ "$(oc get project "$ns" -o jsonpath='{.status.phase}' 2>/dev/null)" = Terminating ] || break
    [ "$i" = 1 ] && echo "(aguardando a remocao de $ns terminar...)"
    sleep 3
  done
  [ "$(oc get project "$ns" -o jsonpath='{.status.phase}' 2>/dev/null)" = Terminating ] && die "$ns continua em remocao (Terminating) apos 3 min"
  if ! oc get project "$ns" >/dev/null 2>&1; then
    printf 'apiVersion: project.openshift.io/v1\nkind: ProjectRequest\nmetadata:\n  name: %s\ndisplayName: %s\n' "$ns" "$ns" | oc create -f - >/dev/null
  fi
  oc label namespace "$ns" ex288-lab=v3 --overwrite >/dev/null 2>&1 || true
}

delete_projects() {  # <ns>... ; so remove ex288-v3-* ; nunca a infra a menos que pedido explicitamente
  local n
  for n in "$@"; do
    assert_v3_ns "$n"
    if oc get project "$n" >/dev/null 2>&1; then echo "removendo projeto $n"; oc delete project "$n" --wait=false >/dev/null; else echo "(nao existe) $n"; fi
  done
}

# ---- consultas ----
val()    { oc get "$2" "$3" -n "$1" -o "jsonpath=$4" 2>/dev/null; }          # <ns> <kind> <name> <jsonpath>
exists() { oc get "$2" "$3" -n "$1" >/dev/null 2>&1; }                        # <ns> <kind> <name>
route_host() { val "$1" route "$2" '{.spec.host}'; }                          # <ns> <route>
route_tls()  { val "$1" route "$2" '{.spec.tls.termination}'; }

# ---- HTTP (curl --resolve evita depender de /etc/hosts nas rotas novas) ----
_resolve_args() {
  local host="$1"
  [ -n "$ROUTE_IP" ] && printf -- '--resolve\n%s\n--resolve\n%s\n' "${host}:80:${ROUTE_IP}" "${host}:443:${ROUTE_IP}"
  return 0
}
curl_route() {  # curl_route <url> [args...]  (aceita http/https; -k sempre)
  local url="$1"; shift
  local host; host="${url#*://}"; host="${host%%[/:]*}"
  local args=(); while IFS= read -r a; do [ -n "$a" ] && args+=("$a"); done < <(_resolve_args "$host")
  curl -sk -m 15 "${args[@]}" "$@" "$url"
}
http_code() { curl_route "$1" -o /dev/null -w '%{http_code}' "${@:2}" 2>/dev/null || echo 000; }
http_body() { curl_route "$1" "${@:2}" 2>/dev/null; }

# ---- Git do lab: a rota do Gitea precisa resolver no cliente (oc new-app clona localmente) ----
gitea_host() { route_host "$INFRA_NS" gitea; }
git_resolve_env() {
  # Nunca abrir prompt nem navegador: no Git for Windows o Git Credential Manager abria uma aba OAuth do Gitea
  # (VERIFICADO). Sem helper, o clone de repositorio privado falha rapido e o oc new-app so avisa.
  # Alem disso, o 'oc new-app' CLONA o repositorio no cliente e ABORTA em repositorio privado sem credencial
  # (VERIFICADO: "could not read Username"). Aqui o cliente recebe as credenciais do lab por um helper TRANSITORIO
  # (so variaveis de ambiente deste processo, so para o host do Gitea; nada e gravado em arquivo).
  export GIT_TERMINAL_PROMPT=0 GCM_INTERACTIVE=never GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=credential.helper GIT_CONFIG_VALUE_0=
  local h u p k; h="$(gitea_host)"
  [ -n "$h" ] || return 0
  u="$(git_user)"; p="$(git_pass)"
  if [ -n "$u" ] && [ -n "$p" ]; then
    export GIT_CONFIG_COUNT=2 GIT_CONFIG_KEY_1="credential.http://${h}.helper" GIT_CONFIG_VALUE_1="!f() { echo username=${u}; echo password=${p}; }; f"
  fi
  if [ -n "$ROUTE_IP" ]; then
    k="$GIT_CONFIG_COUNT"
    export "GIT_CONFIG_KEY_${k}=http.curloptResolve" "GIT_CONFIG_VALUE_${k}=${h}:80:${ROUTE_IP}" "GIT_CONFIG_COUNT=$((k+1))"
  fi
  return 0
}
secret_val() { oc get secret "$2" -n "$1" -o "jsonpath={.data.$3}" 2>/dev/null | base64 -d; }   # <ns> <secret> <key>
git_user() { secret_val "$INFRA_NS" gitea-admin username; }
git_pass() { secret_val "$INFRA_NS" gitea-admin password; }
git_url()  { echo "http://$(gitea_host)/ex288/$1.git"; }                      # <repo>
nexus_host() { route_host "$INFRA_NS" nexus; }
nexus_url()  { echo "http://$(nexus_host)"; }
nexus_pass() { secret_val "$INFRA_NS" nexus-admin password; }

wait_rollout() {  # <ns> <deployment> [timeout]
  oc rollout status "deployment/$2" -n "$1" --timeout="${3:-300s}" >/dev/null 2>&1
}
wait_build() {  # <ns> <build-name> [segundos] -> 0 se Complete
  local ns="$1" b="$2" t="${3:-600}" p i=0
  while [ "$i" -lt "$t" ]; do
    p="$(val "$ns" build "$b" '{.status.phase}')"
    case "$p" in Complete) return 0 ;; Failed|Error|Cancelled) return 1 ;; esac
    sleep 5; i=$((i+5))
  done
  return 1
}
last_build() { oc get build -n "$1" -l "buildconfig=$2" --sort-by=.metadata.creationTimestamp -o name 2>/dev/null | tail -1 | sed 's#.*/##'; }

has_tekton() {  # Pipelines Operator instalado? (descoberta de API: o 'developer' NAO pode fazer 'oc get crd' - VERIFICADO: Forbidden)
  oc api-resources --api-group=tekton.dev -o name 2>/dev/null | grep -q '^pipelines\.'
}
ready_replicas() { val "$1" deployment "$2" '{.status.readyReplicas}'; }     # <ns> <deployment>
build_complete() {  # <ns> <buildconfig> -> 0 se existe algum build Complete
  oc get build -n "$1" -l "buildconfig=$2" -o jsonpath='{range .items[*]}{.status.phase}{"\n"}{end}' 2>/dev/null | grep -qx Complete
}
build_count() { oc get build -n "$1" -l "buildconfig=$2" --no-headers 2>/dev/null | wc -l | tr -d ' '; }
route_body() { local h; h="$(route_host "$1" "$2")"; [ -n "$h" ] || return 1; http_body "http://$h${3:-/}"; }   # <ns> <route> [path]
route_has()  { [[ "$(route_body "$1" "$2" "${4:-/}")" == *"$3"* ]]; }                                           # <ns> <route> <texto> [path]
env_list()   { oc set env "deployment/$2" -n "$1" --list 2>/dev/null; }                                      # <ns> <deployment>
pod_restarts() {  # <ns> <app>: reinicios do 1o container de cada pod ATIVO (ignora os que estao em Terminating)
  oc get pods -n "$1" -l "app=$2" -o go-template='{{range .items}}{{if not .metadata.deletionTimestamp}}{{(index .status.containerStatuses 0).restartCount}} {{end}}{{end}}' 2>/dev/null
}

# ---- validacao: PASS/FAIL por item, codigo != 0 se algum falhar ----
PASS=0; FAIL=0
test_task() {  # <descricao> <funcao> [args...]
  local name="$1"; shift
  if ( "$@" ) >/dev/null 2>&1; then PASS=$((PASS+1)); printf 'PASS  %s\n' "$name"; else FAIL=$((FAIL+1)); printf 'FAIL  %s\n' "$name"; fi
}
complete_validation() {  # <titulo>
  echo; echo "[$1] $PASS PASS / $FAIL FAIL"
  [ "$FAIL" -eq 0 ]; exit $?
}
