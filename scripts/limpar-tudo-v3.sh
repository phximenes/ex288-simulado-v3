#!/usr/bin/env bash
# limpar-tudo-v3.sh - lista os projetos do lab v3 (label ex288-lab=v3 OU prefixo ex288-v3-), mostra o que sera removido,
# pede confirmacao e so entao remove. A infra (ex288-v3-infra: Git + Nexus) so e removida com --infra.
# Uso: bash scripts/limpar-tudo-v3.sh [--infra]
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
require_login
WITH_INFRA=0; [ "${1:-}" = "--infra" ] && WITH_INFRA=1
LIST="$( { oc get projects -l ex288-lab=v3 -o name 2>/dev/null; oc get projects -o name 2>/dev/null | grep "/${V3_PREFIX}" || true; } | sed 's#.*/##' | sort -u | grep "^${V3_PREFIX}" || true)"
[ "$WITH_INFRA" = 0 ] && LIST="$(echo "$LIST" | grep -v "^${INFRA_NS}$" || true)"
if [ -z "$LIST" ]; then echo "Nada para remover."; exit 0; fi
echo "Projetos que serao removidos:"; echo "$LIST" | sed 's/^/  - /'
[ "$WITH_INFRA" = 0 ] && echo "(a infra $INFRA_NS foi preservada; use --infra para remove-la)"
printf 'Confirmar remocao? [digite sim] '
read -r ans
[ "$ans" = sim ] || { echo "Cancelado."; exit 1; }
# shellcheck disable=SC2086
delete_projects $LIST
