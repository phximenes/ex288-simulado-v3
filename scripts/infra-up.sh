#!/usr/bin/env bash
# infra-up.sh - sobe (ou reconcilia) o Git interno (Gitea) e o Nexus no projeto ex288-v3-infra e carrega o conteudo.
# Idempotente. Uso: bash scripts/infra-up.sh
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
require_login
new_project "$INFRA_NS"
N="$INFRA_NS"
# IMPORTANTE: rode este script com o MESMO usuario que fara os exercicios (developer). Quem cria o projeto ex288-v3-infra
# e dono dele e le as rotas e as credenciais; outro usuario (ex.: kubeadmin) criaria um projeto que o developer nao enxerga
# (VERIFICADO: os validadores e o preparar-0N.sh falham). Nenhuma permissao extra e concedida por este script.

echo "== 1/5 manifests (Gitea + Nexus)"
# SKIP_GIT=1 / SKIP_NEXUS=1: sobe so uma das pecas (util em CRC apertado: cada imagem puxada consome disco do no)
GH=""
if [ "${SKIP_GIT:-0}" != 1 ]; then
  oc apply -n "$N" -f "$LAB_ROOT/apps/infra/gitea.yaml" >/dev/null
  oc scale -n "$N" deployment/gitea --replicas=1 >/dev/null
  echo "   aguardando o Gitea..."
  oc rollout status -n "$N" deployment/gitea --timeout=600s >/dev/null || die "Gitea nao ficou pronto (oc get events -n $N; DiskPressure no no?)"
fi
if [ "${SKIP_NEXUS:-0}" != 1 ]; then
  oc apply -n "$N" -f "$LAB_ROOT/apps/infra/nexus.yaml" >/dev/null
  oc scale -n "$N" deployment/nexus --replicas=1 >/dev/null
fi

if [ "${SKIP_GIT:-0}" != 1 ]; then
echo "== 2/5 credenciais do Gitea e repositorios privados"
if ! exists "$N" secret gitea-admin; then
  GPW="$(openssl rand -hex 10)"
  oc create secret generic gitea-admin -n "$N" --from-literal=username=ex288 --from-literal=password="$GPW" >/dev/null
  oc label secret gitea-admin -n "$N" ex288-lab=v3 >/dev/null
fi
GU="$(git_user)"; GPW="$(git_pass)"; GH="$(gitea_host)"
# o banco do Gitea e emptyDir: recria o usuario sempre que o pod foi recriado (erro "already exists" e ignorado)
oc exec -n "$N" deploy/gitea -- gitea admin user create --username "$GU" --password "$GPW" \
  --email ex288@example.invalid --admin --must-change-password=false >/dev/null 2>&1 || true
git_resolve_env
gapi() { curl_route "http://$GH/api/v1$1" -u "$GU:$GPW" -H 'Content-Type: application/json' "${@:2}"; }
push_repo() {  # <dir-em-apps/git-repos> [branch-extra]
  local name="$1" d="$LAB_ROOT/apps/git-repos/$1" tmp
  if [ "$(gapi "/repos/ex288/$name" -o /dev/null -w '%{http_code}')" != 200 ]; then
    gapi /user/repos -o /dev/null -d "{\"name\":\"$name\",\"private\":true,\"default_branch\":\"main\"}"
  fi
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/v3-push-XXXXXX")"
  cp -a "$d"/. "$tmp"/
  (
    cd "$tmp"
    git init -q -b main
    git config core.autocrlf false
    git add -A
    [ -f .s2i/bin/assemble ] && git add --chmod=+x .s2i/bin/assemble
    git -c user.name=ex288 -c user.email=ex288@example.invalid commit -q -m "lab v3: $name"
    # credential.helper= : nao deixa o Git Credential Manager gravar a senha gerada (VERIFICADO: no Git for Windows ele guardava)
    git -c credential.helper= push -q --force "http://$GU:$GPW@$GH/ex288/$name.git" main >/dev/null 2>&1
    if [ "$name" = webapp ]; then
      git checkout -q -b dev
      echo dev > BRANCH
      git -c user.name=ex288 -c user.email=ex288@example.invalid commit -q -am "branch dev"
      git -c credential.helper= push -q --force "http://$GU:$GPW@$GH/ex288/$name.git" dev >/dev/null 2>&1
    fi
  )
  case "$tmp" in */v3-push-*) rm -rf "$tmp" ;; esac
  echo "   repo privado $name -> $(git_url "$name")"
}
for r in webapp monorepo webapp-docker webapp-s2i httpd-ex; do push_repo "$r"; done
fi

if [ "${SKIP_NEXUS:-0}" = 1 ]; then
  echo; echo "Pronto (SKIP_NEXUS=1: sem Nexus). Git: http://$GH   (senha: bash scripts/credenciais.sh --show)"; exit 0
fi
echo "== 3/5 Nexus (heap reduzido; a 1a subida leva alguns minutos)"
oc rollout status -n "$N" deployment/nexus --timeout=900s >/dev/null || die "Nexus nao ficou pronto (oc logs -n $N deploy/nexus)"
NU="$(nexus_url)"
nx() { curl_route "$NU$1" "${@:2}"; }
i=0; until [ "$(nx /service/rest/v1/status -o /dev/null -w '%{http_code}')" = 200 ]; do
  i=$((i+1)); [ "$i" -gt 90 ] && die "Nexus nao respondeu em /service/rest/v1/status"; sleep 10
done
if exists "$N" secret nexus-admin; then
  NPW="$(nexus_pass)"
else
  NPW="$(openssl rand -hex 10)"
  [ "$(nx /service/rest/v1/security/users/admin/change-password -u admin:admin123 -X PUT -H 'Content-Type: text/plain' -d "$NPW" -o /dev/null -w '%{http_code}')" = 204 ] \
    || die "nao consegui trocar a senha inicial do admin do Nexus (ja trocada em outro run? apague o Secret e o pod)"
  oc create secret generic nexus-admin -n "$N" --from-literal=username=admin --from-literal=password="$NPW" >/dev/null
  oc label secret nexus-admin -n "$N" ex288-lab=v3 >/dev/null
fi
nxa() { nx "$1" -u "admin:$NPW" "${@:2}"; }
JSON=(-H 'Content-Type: application/json')
repo_exists() { nxa /service/rest/v1/repositories | grep -q "\"name\" *: *\"$1\""; }
mkrepo() {  # <nome> <path-api> <json>
  if repo_exists "$1"; then echo "   repo $1 ja existe"; return 0; fi
  local c; c="$(nxa "/service/rest/v1/repositories/$2" -X POST "${JSON[@]}" -d "$3" -o /dev/null -w '%{http_code}')"
  [ "$c" = 201 ] && echo "   repo $1 criado" || echo "   AVISO: repo $1 -> HTTP $c"
}
ST='"storage":{"blobStoreName":"default","strictContentTypeValidation":true'
mkrepo npm-proxy npm/proxy "{\"name\":\"npm-proxy\",\"online\":true,$ST},\"proxy\":{\"remoteUrl\":\"https://registry.npmjs.org\",\"contentMaxAge\":1440,\"metadataMaxAge\":1440},\"negativeCache\":{\"enabled\":true,\"timeToLive\":1440},\"httpClient\":{\"blocked\":false,\"autoBlock\":true}}"
mkrepo npm-public npm/group "{\"name\":\"npm-public\",\"online\":true,$ST},\"group\":{\"memberNames\":[\"npm-proxy\"]}}"
mkrepo maven-proxy maven/proxy "{\"name\":\"maven-proxy\",\"online\":true,$ST},\"proxy\":{\"remoteUrl\":\"https://repo1.maven.org/maven2/\",\"contentMaxAge\":-1,\"metadataMaxAge\":1440},\"negativeCache\":{\"enabled\":true,\"timeToLive\":1440},\"httpClient\":{\"blocked\":false,\"autoBlock\":true},\"maven\":{\"versionPolicy\":\"RELEASE\",\"layoutPolicy\":\"PERMISSIVE\"}}"
mkrepo maven-hosted maven/hosted "{\"name\":\"maven-hosted\",\"online\":true,$ST,\"writePolicy\":\"allow\"},\"maven\":{\"versionPolicy\":\"RELEASE\",\"layoutPolicy\":\"STRICT\"}}"
mkrepo maven-public maven/group "{\"name\":\"maven-public\",\"online\":true,$ST},\"group\":{\"memberNames\":[\"maven-hosted\",\"maven-proxy\"]}}"
mkrepo helm-hosted helm/hosted "{\"name\":\"helm-hosted\",\"online\":true,$ST,\"writePolicy\":\"allow\"}}"
mkrepo raw-hosted raw/hosted "{\"name\":\"raw-hosted\",\"online\":true,$ST,\"writePolicy\":\"allow\"}}"
mkrepo docker-hosted docker/hosted "{\"name\":\"docker-hosted\",\"online\":true,$ST,\"writePolicy\":\"allow\"},\"docker\":{\"v1Enabled\":false,\"forceBasicAuth\":true,\"httpPort\":5000}}"

echo "== 4/5 leitura anonima so para maven e npm (helm/raw/docker exigem usuario e senha)"
nxa /service/rest/v1/security/roles -X POST "${JSON[@]}" -o /dev/null -d '{"id":"ex288-anon","name":"ex288-anon","description":"leitura anonima: maven e npm","privileges":["nx-repository-view-maven2-*-read","nx-repository-view-maven2-*-browse","nx-repository-view-npm-*-read","nx-repository-view-npm-*-browse"],"roles":[]}' || true
nxa /service/rest/v1/security/users/anonymous -X PUT "${JSON[@]}" -o /dev/null -d '{"userId":"anonymous","firstName":"Anonymous","lastName":"User","emailAddress":"anonymous@example.org","source":"default","status":"active","roles":["ex288-anon"]}' || true
nxa /service/rest/v1/security/anonymous -X PUT "${JSON[@]}" -o /dev/null -d '{"enabled":true,"userId":"anonymous","realmName":"NexusAuthorizingRealm"}' || true

echo "== 5/5 conteudo do Nexus (charts Helm, artefato raw, jar de teste)"
# A edicao Community EXIGE aceitar o EULA da Sonatype antes de aceitar uploads (VERIFICADO: HTTP 403 com a mensagem do EULA).
# O script NAO aceita por voce: leia https://links.sonatype.com/products/nxrm/ce-eula e, se concordar, rode de novo com NEXUS_ACCEPT_EULA=yes
# (ou aceite pelo wizard da interface web do Nexus).
if ! nxa /service/rest/v1/system/eula | grep -q '"accepted" *: *true'; then
  if [ "${NEXUS_ACCEPT_EULA:-}" = yes ]; then
    # corpo = o proprio JSON devolvido pelo Nexus com accepted=true (VERIFICADO: HTTP 204); via stdin para preservar o texto com aspas tipograficas
    nxa /service/rest/v1/system/eula | sed 's/"accepted" *: *false/"accepted" : true/' \
      | nxa /service/rest/v1/system/eula -X POST "${JSON[@]}" --data-binary @- -o /dev/null -w "   EULA aceito a seu pedido (NEXUS_ACCEPT_EULA=yes) -> HTTP %{http_code}\n"
  else
    echo "   PENDENTE: o Nexus Community exige aceitar o EULA antes dos uploads."
    echo "   Leia https://links.sonatype.com/products/nxrm/ce-eula e, se concordar: NEXUS_ACCEPT_EULA=yes bash scripts/infra-up.sh"
    echo "   (ou aceite no wizard da interface web). Os repositorios foram criados, mas SEM o aceite o Nexus devolve HTTP 403 (VERIFICADO) nos uploads e no download do tarball via proxy npm; charts e artefatos raw nao foram carregados."
    echo; echo "Pronto, com a pendencia acima. Git: ${GH:-n/a}  Nexus: $NU   (senhas: bash scripts/credenciais.sh --show)"; exit 0
  fi
fi
tmp="$(mktemp -d "${TMPDIR:-/tmp}/v3-nexus-XXXXXX")"
for v in 0.1.0 0.2.0; do
  mkdir -p "$tmp/$v" && cp -a "$LAB_ROOT/apps/helm/ex288-hello" "$tmp/$v/"
  sed -i "s/^version: .*/version: $v/" "$tmp/$v/ex288-hello/Chart.yaml"
  [ "$v" = 0.2.0 ] && sed -i 's/^message: .*/message: "hello from helm v2"/' "$tmp/$v/ex288-hello/values.yaml"
  tar -C "$tmp/$v" -czf "$tmp/ex288-hello-$v.tgz" ex288-hello
  nxa "/repository/helm-hosted/ex288-hello-$v.tgz" --upload-file "$tmp/ex288-hello-$v.tgz" -o /dev/null -w "   helm ex288-hello-$v.tgz -> HTTP %{http_code}\n"
done
tar -C "$LAB_ROOT/apps/nexus/site" -czf "$tmp/site-1.0.tar.gz" .
nxa /repository/raw-hosted/ex288/site-1.0.tar.gz --upload-file "$tmp/site-1.0.tar.gz" -o /dev/null -w "   raw ex288/site-1.0.tar.gz -> HTTP %{http_code}\n"
for ext in jar pom; do
  nxa "/repository/maven-hosted/org/ex288/ex288-hello/1.0/ex288-hello-1.0.$ext" --upload-file "$LAB_ROOT/apps/nexus/seed/ex288-hello-1.0.$ext" \
    -o /dev/null -w "   maven ex288-hello-1.0.$ext -> HTTP %{http_code}\n"
done
case "$tmp" in */v3-nexus-*) rm -rf "$tmp" ;; esac

echo
echo "Pronto. Git: http://$GH  Nexus: $NU   (senhas: bash scripts/credenciais.sh --show)"
