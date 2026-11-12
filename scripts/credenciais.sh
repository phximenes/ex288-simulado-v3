#!/usr/bin/env bash
# credenciais.sh - mostra URLs e usuarios do Git interno e do Nexus; --show imprime tambem as senhas (nunca grava em arquivo).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
require_login
echo "Git interno : http://$(gitea_host)   usuario: $(git_user)"
echo "Nexus       : $(nexus_url)   usuario: admin"
echo "Registry    : image-registry.openshift-image-registry.svc:5000 (interno)"
if [ "${1:-}" = "--show" ]; then
  echo "senha git   : $(git_pass)"
  echo "senha nexus : $(nexus_pass)"
else
  echo "(use --show para ver as senhas)"
fi
