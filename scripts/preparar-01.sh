#!/usr/bin/env bash
# preparar-01.sh - cria o projeto da T1 e confere se o Git interno esta no ar.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
require_login
exists "$INFRA_NS" route gitea || die "Git interno nao encontrado: rode bash scripts/infra-up.sh"
new_project ex288-v3-t1
echo "Projeto ex288-v3-t1 pronto. Git: http://$(gitea_host)/ex288/webapp.git (usuario $(git_user); senha: bash scripts/credenciais.sh --show)"
