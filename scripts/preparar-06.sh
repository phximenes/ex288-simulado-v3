#!/usr/bin/env bash
# preparar-06.sh - projeto da T6.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
require_login
new_project ex288-v3-t6
echo "Projeto ex288-v3-t6 pronto. Template fornecido: $LAB_ROOT/apps/templates/webapp-template.yaml"
