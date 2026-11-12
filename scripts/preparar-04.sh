#!/usr/bin/env bash
# preparar-04.sh - simula o ambiente da prova: app sem configuracao + Secret JA EXISTENTE + Secret em outro projeto.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
require_login
NS=ex288-v3-t4; SH=ex288-v3-t4-shared
new_project "$NS"; new_project "$SH"
oc apply -n "$NS" -f "$LAB_ROOT/apps/k8s/cfgapp.yaml" >/dev/null
# Secret "que ja existe" (a senha e gerada aqui e nunca gravada em arquivo)
if ! exists "$NS" secret db-credentials; then
  oc create secret generic db-credentials -n "$NS" --from-literal=username=app --from-literal=password="$(openssl rand -hex 8)" >/dev/null
fi
if ! exists "$SH" secret shared-api; then
  oc create secret generic shared-api -n "$SH" --from-literal=token="$(openssl rand -hex 12)" >/dev/null
fi
echo "Projetos $NS e $SH prontos. cfgapp implantada sem configuracao; Secret db-credentials ja existe em $NS."
