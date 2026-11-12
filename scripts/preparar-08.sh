#!/usr/bin/env bash
# preparar-08.sh - projeto da T8. Exige o Pipelines Operator (instalado por voce; ver 00-guia/preparar-wsl-rhel.md, passo 12).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
require_login
has_tekton || die "Pipelines Operator nao instalado (API tekton.dev ausente): passo 12 do preparar-wsl-rhel.md"
exists "$INFRA_NS" route gitea || die "Git interno nao encontrado: rode bash scripts/infra-up.sh"
NS=ex288-v3-t8
new_project "$NS"
oc create secret generic git-creds -n "$NS" --type=kubernetes.io/basic-auth \
  --from-literal=username="$(git_user)" --from-literal=password="$(git_pass)" --dry-run=client -o yaml | oc apply -n "$NS" -f - >/dev/null
# credencial no formato do Tekton: anotacao tekton.dev/git-0 + vinculo com a SA pipeline
oc create secret generic git-basic-auth -n "$NS" --type=kubernetes.io/basic-auth \
  --from-literal=username="$(git_user)" --from-literal=password="$(git_pass)" --dry-run=client -o yaml | oc apply -n "$NS" -f - >/dev/null
oc annotate secret git-basic-auth -n "$NS" "tekton.dev/git-0=http://$(gitea_host)" --overwrite >/dev/null
if exists "$NS" sa pipeline; then oc secrets link pipeline git-basic-auth -n "$NS" >/dev/null; else echo "AVISO: SA pipeline ainda nao existe; aguarde o Operator e rode de novo."; fi
oc apply -n "$NS" -f "$LAB_ROOT/apps/pipeline/pipeline-broken.yaml" >/dev/null 2>&1 || echo "(broken-ci foi rejeitado na aplicacao: e o defeito 1 do E3)"
echo "Projeto $NS pronto."
