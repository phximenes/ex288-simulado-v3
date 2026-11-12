#!/usr/bin/env bash
# preparar-03.sh - projeto da T3, Secret git-creds e a app defeituosa s2i-broken (registry npm inalcancavel).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
require_login
exists "$INFRA_NS" route gitea || die "Git interno nao encontrado: rode bash scripts/infra-up.sh"
NS=ex288-v3-t3
new_project "$NS"
git_resolve_env
oc create secret generic git-creds -n "$NS" --type=kubernetes.io/basic-auth \
  --from-literal=username="$(git_user)" --from-literal=password="$(git_pass)" --dry-run=client -o yaml | oc apply -n "$NS" -f - >/dev/null
if ! exists "$NS" bc s2i-broken; then
  oc new-app -n "$NS" --name s2i-broken --source-secret git-creds --image-stream openshift/nodejs:22-ubi9 \
    --build-env npm_config_registry=http://127.0.0.1:9/ --code "$(git_url webapp-s2i)" >/dev/null
fi
echo "Projeto $NS pronto. s2i-broken foi criado com um registry npm invalido (o build vai falhar: e o exercicio E3)."
