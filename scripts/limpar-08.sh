#!/usr/bin/env bash
# limpar-08.sh - remove apenas o(s) projeto(s) da task 8 (ex288-v3-t8*). Nao toca na infra.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
require_login
delete_projects ex288-v3-t8
