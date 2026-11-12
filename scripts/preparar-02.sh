#!/usr/bin/env bash
# preparar-02.sh - projeto da T2 + Secret git-creds (credenciais do Git interno, geradas a partir do Secret da infra).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
require_login
exists "$INFRA_NS" route gitea || die "Git interno nao encontrado: rode bash scripts/infra-up.sh"
NS=ex288-v3-t2
new_project "$NS"
oc create secret generic git-creds -n "$NS" --type=kubernetes.io/basic-auth \
  --from-literal=username="$(git_user)" --from-literal=password="$(git_pass)" --dry-run=client -o yaml | oc apply -n "$NS" -f - >/dev/null
echo "Projeto $NS pronto (Secret git-creds criado). Git: $(git_url webapp-docker)  Nexus: $(nexus_url)"
