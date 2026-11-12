#!/usr/bin/env bash
# simulado-preparar.sh - prepara o simulado (variante A ou B): 8 projetos independentes, ex288-v3-s<a|b>-t1..t8.
# Uso: bash scripts/simulado-preparar.sh A|B     (tempo: 2 h; enunciado em 09-simulado/<variante>/enunciado.md)
# Recriar so alguns projetos que sumiram, sem mexer nos outros nem reiniciar o cronometro:
#   SIM_ONLY="4 5" bash scripts/simulado-preparar.sh A
# Rodar de novo sem SIM_ONLY mantem o inicio ja marcado (sim-start); para reiniciar o relogio, rode simulado-limpar.sh antes.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
V="${1:-}"; case "$V" in A|B) ;; *) die "uso: simulado-preparar.sh A|B" ;; esac
v="$(echo "$V" | tr 'A-Z' 'a-z')"; P="ex288-v3-s${v}-t"
ONLY="${SIM_ONLY:-1 2 3 4 5 6 7 8}"
want() { case " $ONLY " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }   # <n> : a task n entra nesta execucao?
require_login
exists "$INFRA_NS" route gitea || die "Git interno nao encontrado: rode bash scripts/infra-up.sh"
for n in 1 2 3 4 5 6 7 8; do if want "$n"; then new_project "${P}${n}"; fi; done
for n in 1 2 3 8; do   # credenciais do Git interno (o enunciado so informa usuario/URL; a senha: scripts/credenciais.sh --show)
  if want "$n"; then
    oc create secret generic git-creds -n "${P}${n}" --type=kubernetes.io/basic-auth \
      --from-literal=username="$(git_user)" --from-literal=password="$(git_pass)" --dry-run=client -o yaml | oc apply -n "${P}${n}" -f - >/dev/null
  fi
done

slow() {  # <ns> <nome> <START_DELAY>
  sed -e "s/probeapp/$2/g" -e "s/value: \"25\"/value: \"$3\"/" "$LAB_ROOT/apps/k8s/probeapp.yaml" | oc apply -n "$1" -f - >/dev/null
}

if [ "$V" = A ]; then
  if want 4; then
    oc apply -n "${P}4" -f "$LAB_ROOT/apps/k8s/cfgapp.yaml" >/dev/null
    exists "${P}4" secret catalog-db || oc create secret generic catalog-db -n "${P}4" --from-literal=login=svc --from-literal=secret="$(openssl rand -hex 8)" >/dev/null
  fi
  if want 5; then slow "${P}5" slowapp 30; fi
else
  if want 4; then
    new_project "${P}4-shared"
    oc apply -n "${P}4" -f "$LAB_ROOT/apps/k8s/cfgapp.yaml" >/dev/null
    exists "${P}4" secret shop-db || oc create secret generic shop-db -n "${P}4" --from-literal=u=shop --from-literal=p="$(openssl rand -hex 8)" >/dev/null
    exists "${P}4-shared" secret shop-token || oc create secret generic shop-token -n "${P}4-shared" --from-literal=value="$(openssl rand -hex 10)" >/dev/null
  fi
  if want 5; then
    slow "${P}5" slowapp 20
    slow "${P}5" slowbad 20
    oc set probe -n "${P}5" deployment/slowbad --liveness --get-url=http://:8080/healthz --initial-delay-seconds=3 --period-seconds=4 --failure-threshold=2 >/dev/null
  fi
  if want 3; then
    # T3-B: app com registry npm invalido (corrigir)
    git_resolve_env
    oc new-app -n "${P}3" --name reports --source-secret git-creds --image-stream openshift/nodejs:22-ubi9 --context-dir api \
      --build-env npm_config_registry=http://127.0.0.1:9/ --code "$(git_url monorepo)" >/dev/null 2>&1 || echo "AVISO: nao consegui criar 'reports' (T3-B) agora; crie conforme o enunciado."
  fi
  # T8-B: o 'broken-ci' NAO e pre-aplicado: o webhook do Tekton rejeita o arquivo (runAfter para task inexistente; VERIFICADO),
  # entao o enunciado manda corrigir apps/pipeline/pipeline-broken.yaml e aplicar. (Antes havia um apply silencioso que nunca criava o Pipeline.)
fi
if want 8; then
  if has_tekton; then
    oc create secret generic git-basic-auth -n "${P}8" --type=kubernetes.io/basic-auth --from-literal=username="$(git_user)" --from-literal=password="$(git_pass)" --dry-run=client -o yaml | oc apply -n "${P}8" -f - >/dev/null
    oc annotate secret git-basic-auth -n "${P}8" "tekton.dev/git-0=http://$(gitea_host)" --overwrite >/dev/null
    exists "${P}8" sa pipeline && oc secrets link pipeline git-basic-auth -n "${P}8" >/dev/null || true
  else
    echo "AVISO: Pipelines Operator ausente: T8 nao sera pontuada."
  fi
fi
if want 1; then
  if exists "${P}1" configmap sim-start; then
    echo "Inicio ja marcado (sim-start mantido): $(val "${P}1" configmap sim-start '{.data.epoch}')"
  else
    oc create configmap sim-start -n "${P}1" --from-literal=epoch="$(date +%s)" >/dev/null
    echo "Inicio marcado agora."
  fi
fi
echo "Simulado $V: projetos preparados: $ONLY (prefixo ${P}). Leia 09-simulado/$V/enunciado.md. Tempo: 2 horas."
