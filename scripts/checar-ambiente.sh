#!/usr/bin/env bash
# checar-ambiente.sh - confere o WSL RHEL 10.2 para o lab v3 e imprime PASS / FAIL / WARN por item.
# Uso: bash scripts/checar-ambiente.sh        (sai com codigo != 0 se algum item obrigatorio falhar)
set -uo pipefail
PASS=0; FAIL=0; WARN=0
ok()   { PASS=$((PASS+1)); printf 'PASS  %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf 'FAIL  %s\n        -> %s\n' "$1" "${2:-}"; }
warn() { WARN=$((WARN+1)); printf 'WARN  %s\n        -> %s\n' "$1" "${2:-}"; }
need() { command -v "$1" >/dev/null 2>&1 && ok "ferramenta: $1 ($(command -v "$1"))" || bad "ferramenta ausente: $1" "$2"; }
opt()  { command -v "$1" >/dev/null 2>&1 && ok "ferramenta (opcional): $1" || warn "ferramenta opcional ausente: $1" "$2"; }

echo "== sistema"
grep -q 'Red Hat Enterprise Linux' /etc/os-release 2>/dev/null && ok "RHEL: $(. /etc/os-release; echo "$VERSION")" || warn "nao e RHEL" "o alvo e o WSL RedHatEnterpriseLinux-10.2"
[ "$(id -u)" -ne 0 ] && ok "executando como usuario comum ($(id -un))" || warn "executando como root" "na prova voce nao e root; use seu usuario"
[ "$(ps -p 1 -o comm= 2>/dev/null)" = systemd ] && ok "systemd ativo" || warn "systemd inativo" "/etc/wsl.conf: [boot] systemd=true"

echo "== ferramentas (RHEL)"
need git "sudo dnf install -y git-core"
need curl "sudo dnf install -y curl"
need podman "sudo dnf install -y podman"
need skopeo "sudo dnf install -y skopeo"
need jq "sudo dnf install -y jq"
need vim "sudo dnf install -y vim-enhanced"
need oc "baixe oc.tar do console (ver 00-guia/preparar-wsl-rhel.md, passo 6)"
need helm "baixe o helm (ver preparar-wsl-rhel.md, passo 7)"
opt tkn "so existe depois que o Pipelines Operator estiver instalado (passo 12)"
opt shellcheck "pip install shellcheck-py (passo 5)"
opt yamllint "pip install yamllint (passo 5)"
opt yq "opcional"

echo "== oc / cluster"
if command -v oc >/dev/null 2>&1; then
  CV="$(oc version --client 2>/dev/null | sed -n 's/^Client Version: *//p')"
  [ -n "$CV" ] && ok "oc client $CV" || bad "oc version --client nao respondeu" "reinstale o oc"
  case "$(command -v oc)" in /mnt/*) warn "oc esta em /mnt (Windows)" "use o binario Linux em ~/.local/bin" ;; *) ok "oc nativo do Linux" ;; esac
  if oc whoami >/dev/null 2>&1; then
    ok "logado como $(oc whoami) em $(oc whoami --show-server)"
    SV="$(oc get clusterversion version -o jsonpath='{.status.desired.version}' 2>/dev/null)"
    if [ -n "$SV" ]; then
      [ "${SV%.*}" = "$(echo "$CV" | grep -o '[0-9]\+\.[0-9]\+' | head -1)" ] && ok "oc na mesma versao menor do cluster ($SV)" || warn "versao do oc diferente do cluster ($CV x $SV)" "use o oc do console do cluster"
    else
      warn "nao consegui ler clusterversion" "normal para o usuario developer"
    fi
  else
    bad "nao logado no cluster" "oc login -u developer https://api.crc.testing:6443 (senha: crc.exe console --credentials)"
  fi
fi
case "${KUBECONFIG:-$HOME/.kube/config}" in /mnt/*) bad "kubeconfig em /mnt/..." "mantenha o kubeconfig em ~/.kube (nunca no D:)" ;; *) ok "kubeconfig em $(echo "${KUBECONFIG:-$HOME/.kube/config}")" ;; esac
[ "$(stat -c %a "$HOME/.kube" 2>/dev/null)" = 700 ] && ok "\$HOME/.kube com modo 700" || warn "\$HOME/.kube sem modo 700" "chmod 700 \$HOME/.kube"

echo "== rede WSL -> CRC"
for h in api.crc.testing console-openshift-console.apps-crc.testing default-route-openshift-image-registry.apps-crc.testing; do
  ip="$(getent hosts "$h" | awk '{print $1; exit}')"
  [ -n "$ip" ] && ok "resolve $h -> $ip" || bad "nao resolve $h" "ver preparar-wsl-rhel.md, passo 2/3"
done
c="$(curl -sk -m 8 -o /dev/null -w '%{http_code}' https://api.crc.testing:6443/version 2>/dev/null)"
[ "$c" = 200 ] || [ "$c" = 401 ] || [ "$c" = 403 ] && ok "API https://api.crc.testing:6443 responde (HTTP $c)" || bad "API do CRC inacessivel (HTTP $c)" "modo de rede NAT? use networkingMode=mirrored (passo 2)"
c="$(curl -sk -m 8 -o /dev/null -w '%{http_code}' https://console-openshift-console.apps-crc.testing/ 2>/dev/null)"
[ "$c" = 200 ] || [ "$c" = 302 ] && ok "console responde (HTTP $c)" || bad "console inacessivel (HTTP $c)" "idem"

echo "== podman rootless"
if command -v podman >/dev/null 2>&1; then
  [ "$(podman info --format '{{.Host.Security.Rootless}}' 2>/dev/null)" = true ] && ok "podman rootless" || bad "podman nao esta rootless/funcional" "grep \$USER /etc/subuid /etc/subgid; podman info"
fi

echo "== editor, completion e Git/Nexus internos"
grep -qs 'expandtab\|^set et\| et ' "$HOME/.vimrc" && ok "\$HOME/.vimrc com expandtab" || warn "\$HOME/.vimrc sem expandtab" "passo 11"
[ -r /etc/bash_completion.d/oc ] || oc completion bash >/dev/null 2>&1 && ok "completion do oc disponivel" || warn "completion do oc" "passo 11"
if command -v oc >/dev/null 2>&1 && oc get route gitea -n ex288-v3-infra >/dev/null 2>&1; then
  for n in gitea nexus; do
    h="$(oc get route "$n" -n ex288-v3-infra -o jsonpath='{.spec.host}' 2>/dev/null)"
    getent hosts "$h" >/dev/null 2>&1 && ok "resolve $h" || warn "nao resolve $h" "bash scripts/hosts-sync.sh | sudo tee -a /etc/hosts (passo 3)"
  done
else
  warn "infra do lab nao encontrada (ex288-v3-infra)" "bash scripts/infra-up.sh"
fi
[ -d /mnt/d ] && ok "/mnt/d montado" || warn "/mnt/d nao montado" "passo 1 (so necessario para ler o material em D:)"

echo
echo "[checar-ambiente] $PASS PASS / $WARN WARN / $FAIL FAIL"
[ "$FAIL" -eq 0 ]
