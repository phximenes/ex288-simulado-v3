[← README](README.md) | [índice](../README.md) | [solução →](solucao.md)

# T1 — Exercícios (resultado esperado; sem passo a passo)

Preparação: `bash scripts/preparar-01.sh` · Projeto: `ex288-v3-t1` · Git: `bash scripts/credenciais.sh --show` · Validar: `bash scripts/validar-01.sh`.
Repositórios no Git interno (todos **privados**, usuário/senha do script): `webapp` (branches `main` e `dev`) e `monorepo` (pastas `api/` e `site/`).

**E1 — Aplicação a partir do repositório privado (básico).**
Faça o deploy do repositório `webapp` (branch `main`) como aplicação **`web1`**, usando o builder Node.js 22 (UBI 9) do namespace `openshift`. O BuildConfig deve usar um Secret chamado **`git-creds`** como source secret. A aplicação deve estar com 1 réplica pronta e a Route **`web1`** deve devolver JSON com `"branch":"main"`.

**E2 — Branch, rótulo e variável de runtime.**
Faça o deploy do branch **`dev`** do mesmo repositório como **`web-dev`**. Todos os recursos criados devem ter o rótulo **`env=dev`**. A aplicação deve receber **`APP_MESSAGE=from-dev`** como variável de ambiente (sem alterar o código). A Route **`web-dev`** deve devolver `"branch":"dev"` e `"message":"from-dev"`.

**E3 — Monorepo, dois componentes e TLS.**
Do repositório `monorepo`, faça o deploy de **`api`** (diretório `api`, Node.js) e **`site`** (diretório `site`, builder **httpd**). Exponha `api` com a Route `api` e `site` com a Route `site`. Crie ainda a Route **`site-tls`** para o Service `site` com terminação **edge** e redirecionamento do HTTP para HTTPS. `https://…/` do `site-tls` deve devolver a página do `monorepo-site`.

**E4 — Mudança no código e novo build (variação mais difícil).**
Clone o repositório `webapp` com suas credenciais, altere o conteúdo do arquivo `BRANCH` para `main-v2`, faça commit e push para `main`, e dispare um novo build de `web1`. A Route `web1` deve passar a devolver `"branch":"main-v2"` e `web1` deve ter pelo menos 2 builds, o último `Complete`.

Critérios gerais: tudo no projeto `ex288-v3-t1`; nomes exatos; nada que dependa de `oc port-forward`; nenhuma senha escrita em arquivos do material.
