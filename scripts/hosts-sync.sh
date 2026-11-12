#!/usr/bin/env bash
# hosts-sync.sh - IMPRIME as linhas de /etc/hosts para as rotas do lab (nao altera nada).
# O WSL/Windows nao resolvem rotas novas de *.apps-crc.testing. Uso (voce decide aplicar):
#   bash scripts/hosts-sync.sh | sudo tee -a /etc/hosts
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
require_login
IP="${ROUTE_IP:-127.0.0.1}"
echo "# ex288-v3 (gerado por hosts-sync.sh)"
{ for ns in $(oc get projects -o name 2>/dev/null | sed 's#.*/##' | grep "^${V3_PREFIX}" || true); do
    oc get route -n "$ns" -o jsonpath='{range .items[*]}{.spec.host}{"\n"}{end}' 2>/dev/null
  done; } | sort -u | awk -v ip="$IP" 'NF{printf "%s %s\n", ip, $1}'
