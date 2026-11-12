#!/usr/bin/env bash
# limpar-04.sh - remove apenas o(s) projeto(s) da task 4 (ex288-v3-t4*). Nao toca na infra.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
require_login
delete_projects ex288-v3-t4 ex288-v3-t4-shared
