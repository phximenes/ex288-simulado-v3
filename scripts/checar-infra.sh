#!/usr/bin/env bash
# checar-infra.sh - confere (SOMENTE LEITURA) a infraestrutura do cluster: Operators, Gitea, Nexus, registry e GitOps (opcional).
# Roda como developer, depois do cookbook (00-guia/cookbook-infra.md). Nao cria, altera nem apaga nada; senhas so em memoria.
# Uso: bash scripts/checar-infra.sh        (sai com codigo != 0 se algum item obrigatorio falhar)
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
require_login
PASS=0; FAIL=0; WARN=0
ok()   { PASS=$((PASS+1)); printf 'PASS  %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf 'FAIL  %s\n        -> %s\n' "$1" "${2:-}"; }
warn() { WARN=$((WARN+1)); printf 'WARN  %s\n        -> %s\n' "$1" "${2:-}"; }
chk()  { local d="$1" h="$2"; shift 2; if ( "$@" ) >/dev/null 2>&1; then ok "$d"; else bad "$d" "$h"; fi; }   # obrigatorio
opt()  { local d="$1" h="$2"; shift 2; if ( "$@" ) >/dev/null 2>&1; then ok "$d"; else warn "$d" "$h"; fi; }   # opcional

N="$INFRA_NS"
echo "== usuario e projeto da infra"
if [ "$(oc whoami)" = "kube:admin" ]; then warn "logado como kubeadmin" "o lab e os exercicios usam developer (R4 do cookbook)"; else ok "logado como $(oc whoami)"; fi
if oc get project "$N" >/dev/null 2>&1; then ok "projeto $N visivel"; else
  bad "projeto $N visivel" "rode infra-up.sh como developer (R7); um projeto criado pelo kubeadmin fica invisivel ao developer"
  echo; echo "[checar-infra] sem o projeto $N nao ha o que conferir"; exit 1
fi

echo "== Operators (CSV copiado para os namespaces; modo AllNamespaces)"
csv_ok() { oc get csv -n "$N" --no-headers 2>/dev/null | awk -v p="$1" 'index($1,p)==1 && $NF=="Succeeded" {f=1} END {exit !f}'; }
chk "OpenShift Pipelines Operator (CSV Succeeded)" "R5: oc apply -f apps/pipeline/operator-subscription.yaml (kubeadmin)" csv_ok openshift-pipelines-operator-rh
for t in git-clone buildah openshift-client; do
  chk "Task $t em openshift-pipelines (cluster resolver)" "o Operator ainda esta instalando? oc get pods -n openshift-pipelines" exists openshift-pipelines task "$t"
done
opt "OpenShift GitOps Operator (CSV Succeeded)" "opcional; R6: oc apply -f apps/gitops/operator-subscription.yaml (kubeadmin)" csv_ok openshift-gitops-operator

echo "== Gitea (Git interno)"
GH="$(gitea_host)"; GU="$(git_user)"; GP="$(git_pass)"
chk "Deployment gitea pronto" "oc get pods -n $N ; oc describe pod -n $N -l app=gitea (DiskPressure? veja R12)" [ "$(ready_replicas "$N" gitea)" -ge 1 ]
gget() { printf 'user = "%s:%s"\n' "$GU" "$GP" | curl_route "http://$GH$1" -K - "${@:2}"; }
chk "Gitea responde (/api/healthz = 200)" "a rota resolve? (R2/R7) curl --resolve ..." [ "$(http_code "http://$GH/api/healthz")" = 200 ]
chk "Secret gitea-admin existe e a credencial autentica (GET /api/v1/user = 200)" "rode infra-up.sh de novo (recria o usuario)" [ "$(gget /api/v1/user -o /dev/null -w '%{http_code}')" = 200 ]
for r in webapp monorepo webapp-docker webapp-s2i httpd-ex; do
  repo_private() { gget "/api/v1/repos/ex288/$r" | grep -q '"private" *: *true'; }
  chk "repositorio privado $r" "rode infra-up.sh (republica os 5 repositorios)" repo_private
done
chk "branch dev em webapp" "rode infra-up.sh" [ "$(gget /api/v1/repos/ex288/webapp/branches/dev -o /dev/null -w '%{http_code}')" = 200 ]
anon_git() { [ "$(http_code "http://$GH/api/v1/repos/ex288/webapp")" != 200 ]; }
chk "acesso anonimo recusado (repositorios privados)" "GITEA__service__REQUIRE_SIGNIN_VIEW deveria ser true em apps/infra/gitea.yaml" anon_git

echo "== Nexus"
NU="$(nexus_url)"; NP="$(nexus_pass)"
chk "Deployment nexus pronto" "oc logs -n $N deploy/nexus (a 1a subida leva alguns minutos)" [ "$(ready_replicas "$N" nexus)" -ge 1 ]
nget() { printf 'user = "admin:%s"\n' "$NP" | curl_route "$NU$1" -K - "${@:2}"; }
chk "Nexus responde (/service/rest/v1/status = 200)" "aguarde; R7 passo 3" [ "$(http_code "$NU/service/rest/v1/status")" = 200 ]
chk "admin autentica com a senha do Secret nexus-admin" "senha trocada fora do infra-up.sh? veja R7" [ "$(nget /service/rest/v1/security/users -o /dev/null -w '%{http_code}')" = 200 ]
eula_ok() { nget /service/rest/v1/system/eula | grep -q '"accepted" *: *true'; }
chk "EULA do Nexus Community aceito" "decisao sua: leia o EULA e rode NEXUS_ACCEPT_EULA=yes bash scripts/infra-up.sh (sem o aceite: HTTP 403 nos uploads)" eula_ok
repos_ok() { local l; l="$(nget /service/rest/v1/repositories)"; for r in npm-proxy npm-public maven-proxy maven-hosted maven-public helm-hosted raw-hosted docker-hosted; do echo "$l" | grep -q "\"name\" *: *\"$r\"" || return 1; done; }
chk "8 repositorios do Nexus (npm, maven, helm, raw, docker)" "rode infra-up.sh (idempotente)" repos_ok
charts_ok() { local b; b="$(nget /repository/helm-hosted/index.yaml)"; echo "$b" | grep -q 'version: 0.1.0' && echo "$b" | grep -q 'version: 0.2.0'; }
chk "charts ex288-hello 0.1.0 e 0.2.0 em helm-hosted" "EULA aceito? rode infra-up.sh de novo" charts_ok
chk "artefato raw ex288/site-1.0.tar.gz" "idem" [ "$(nget /repository/raw-hosted/ex288/site-1.0.tar.gz -o /dev/null -w '%{http_code}')" = 200 ]
chk "JAR de teste em maven-hosted" "idem" [ "$(nget /repository/maven-hosted/org/ex288/ex288-hello/1.0/ex288-hello-1.0.jar -o /dev/null -w '%{http_code}')" = 200 ]
chk "anonimo: helm-hosted exige login (401)" "R7 passo 4 (so maven e npm sao anonimos)" [ "$(http_code "$NU/repository/helm-hosted/index.yaml")" = 401 ]
opt "anonimo: npm-public responde 200 (precisa de internet no CRC para o proxy npm)" "sem internet no CRC o proxy npm nao busca pacotes" [ "$(http_code "$NU/repository/npm-public/ms")" = 200 ]

echo "== registry interno"
RH="$(oc registry info --public 2>/dev/null)"
chk "oc registry info --public devolve o host" "o registry precisa estar exposto (defaultRoute; no CRC ja vem)" [ -n "$RH" ]
reg_ok() { local c; c="$(curl -sk -m 10 --resolve "$RH:443:${ROUTE_IP:-127.0.0.1}" -o /dev/null -w '%{http_code}' "https://$RH/v2/")"; [ "$c" = 200 ] || [ "$c" = 401 ]; }
chk "registry responde em https://$RH/v2/ (200/401)" "R2 (nomes) e R8 (CA do podman)" reg_ok

echo "== GitOps (opcional)"
opt "CRDs argoproj.io disponiveis (Application, ArgoCD)" "R6: instale o GitOps Operator" [ "$(oc api-resources --api-group=argoproj.io -o name 2>/dev/null | grep -c -E '^(applications|argocds)\.')" = 2 ]
if oc get project ex288-v3-gitops >/dev/null 2>&1; then
  argo_ok() { [ "$(oc get argocd lab -n ex288-v3-gitops -o jsonpath='{.status.phase}' 2>/dev/null)" = Available ]; }
  opt "Argo CD lab (ex288-v3-gitops) Available" "R9; oc get pods -n ex288-v3-gitops" argo_ok
  sync_ok() { [ "$(oc get application gitops-demo -n ex288-v3-gitops -o jsonpath='{.status.sync.status}/{.status.health.status}' 2>/dev/null)" = Synced/Healthy ]; }
  opt "Application gitops-demo Synced/Healthy" "R9; oc describe application gitops-demo -n ex288-v3-gitops" sync_ok
else
  warn "projeto ex288-v3-gitops ausente" "so se voce for praticar GitOps (R9)"
fi

echo "== higiene"
TERM_N="$(oc get projects --no-headers 2>/dev/null | awk '$1 ~ /^ex288-v3-/ && $NF == "Terminating" {print $1}' | wc -l | tr -d ' ')"
[ "$TERM_N" = 0 ] && ok "nenhum projeto ex288-v3-* em Terminating" || warn "$TERM_N projeto(s) ex288-v3-* em Terminating" "espere ~30 s antes de recriar (o new_project dos scripts ja espera)"

echo
echo "[checar-infra] $PASS PASS / $WARN WARN / $FAIL FAIL"
[ "$FAIL" -eq 0 ]
