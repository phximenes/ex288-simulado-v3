#!/usr/bin/env bash
# limpar-07.sh - remove apenas o(s) projeto(s) da task 7 (ex288-v3-t7*). Nao toca na infra.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
require_login
delete_projects ex288-v3-t7
