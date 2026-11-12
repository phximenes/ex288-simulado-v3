#!/usr/bin/env bash
# preparar-07.sh - projeto da T7 (o chart local fica em apps/helm/ex288-hello).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
require_login
new_project ex288-v3-t7
command -v helm >/dev/null 2>&1 || echo "AVISO: helm nao esta no PATH (ver 00-guia/preparar-wsl-rhel.md, passo 7)"
echo "Projeto ex288-v3-t7 pronto. Chart local: $LAB_ROOT/apps/helm/ex288-hello"
