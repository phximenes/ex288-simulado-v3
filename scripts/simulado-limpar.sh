#!/usr/bin/env bash
# simulado-limpar.sh - remove os 8 projetos do simulado A ou B (e o projeto -t4-shared da B). Nao toca na infra.
# Tambem apaga, na raiz do material, os arquivos soltos que as solucoes deixam (app.properties, stack.yaml, values.yaml, *.tgz, wd/).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
V="${1:-}"; case "$V" in A|B) ;; *) die "uso: simulado-limpar.sh A|B" ;; esac
v="$(echo "$V" | tr 'A-Z' 'a-z')"; P="ex288-v3-s${v}-t"
require_login
delete_projects "${P}1" "${P}2" "${P}3" "${P}4" "${P}5" "${P}6" "${P}7" "${P}8"
[ "$V" = B ] && delete_projects "${P}4-shared"

# Sobras das solucoes na RAIZ do material (os blocos gravam no diretorio atual: A-T4 app.properties, B-T6 stack.yaml,
# B-T7 values.yaml + pacote .tgz, B-T2 wd/ e o tarball do Nexus). Somente estes nomes, somente na raiz; nada de apps/ nem do resto.
for f in app.properties stack.yaml values.yaml site-1.0.tar.gz "$LAB_ROOT"/ex288-hello-*.tgz; do
  f="${f#"$LAB_ROOT"/}"
  if [ -f "$LAB_ROOT/$f" ] && [ ! -L "$LAB_ROOT/$f" ]; then rm -f -- "$LAB_ROOT/$f"; echo "removido arquivo solto: $f"; fi
done
if [ -d "$LAB_ROOT/wd" ] && [ ! -L "$LAB_ROOT/wd" ]; then rm -rf -- "$LAB_ROOT/wd"; echo "removido diretorio solto: wd/"; fi
exit 0
