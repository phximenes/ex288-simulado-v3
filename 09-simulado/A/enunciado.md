[← simulado](../README.md) | [solução A →](solucao.md)

# Simulado A — enunciado (2 horas, 8 tasks independentes)

Prepare com `bash scripts/simulado-preparar.sh A`. Cada task tem seu **projeto próprio** (`ex288-v3-sa-tN`). Git interno: URL e usuário via `bash scripts/credenciais.sh`; Secret `git-creds` já existe nos projetos T1, T2, T3 e T8. Nexus (usuário `admin`) e registry interno conforme o script de credenciais. Todos os nomes são exatos.

## Task 1 — Deploy a partir do Git (projeto `ex288-v3-sa-t1`)
1. Faça o deploy do repositório **`webapp`**, branch **`dev`**, como **`portal`** usando o builder Node.js 22 (UBI 9) e o Secret `git-creds`.
2. A aplicação recebe a variável de ambiente (runtime) **`APP_MESSAGE=sim-a`**; os recursos criados (BuildConfig, Deployment, Service) têm o rótulo **`tier=web`**.
3. Exponha com a Route **`portal`** (HTTP) e crie a Route **`portal-tls`** (edge, redirecionando HTTP para HTTPS) para o mesmo Service.

## Task 2 — Deploy a partir de um Dockerfile (projeto `ex288-v3-sa-t2`)
1. Crie o BuildConfig **`shop`** (estratégia Docker) a partir de **`webapp-docker`**, com saída **`shop:2.0`** e o `ARG` **`NPM_REGISTRY`** apontando para o repositório **`npm-public`** do Nexus. Build `Complete`.
2. Faça o deploy **`shop`** a partir da ImageStreamTag `shop:2.0`.
3. A Route **`shop`** deve responder `"app":"webapp-docker"` e o processo não pode ser UID 0.

## Task 3 — Deploy com S2I (projeto `ex288-v3-sa-t3`)
1. Faça o deploy de **`webapp-s2i`** como **`catalog`** com o builder Node.js 22 e o Secret `git-creds`.
2. O build deve usar o **Nexus** (`npm-public`) como registry (variável de **build**); o caminho `/build-info` deve mostrar o endereço do Nexus.
3. Sobrescreva em **runtime** a mensagem da aplicação com **`APP_MESSAGE=catalog-a`** (ela é definida em `.s2i/environment`) e exponha a Route `catalog`.

## Task 4 — ConfigMap e Secret existente (projeto `ex288-v3-sa-t4`)
A aplicação `cfgapp` já está implantada. O Secret **`catalog-db`** já existe (chaves `login` e `secret`).
1. Crie o ConfigMap **`catalog-cfg`** com `GREETING=SimA`, `LANG_CODE=pt-BR` e `API_HOST=http://catalog:8080` e injete **todas** as chaves como variáveis de ambiente em `cfgapp`.
2. Defina **`DB_USER`** (chave `login`) e **`DB_PASSWORD`** (chave `secret`) a partir de `catalog-db`, sem valores literais.
3. Crie o ConfigMap **`catalog-files`** a partir de um arquivo `app.properties` com `mode=sim` e monte-o **somente leitura** em **`/etc/catalog`**.

## Task 5 — Probes (projeto `ex288-v3-sa-t5`)
O Deployment `slowapp` demora ~30 s para subir (endpoints `/healthz` e `/ready`, porta 8080).
1. **Startup** HTTP em `/healthz`, tolerando pelo menos **45 s**.
2. **Liveness** HTTP `/healthz` (período 8 s, timeout 2 s, 3 falhas) e **readiness** HTTP `/ready` (período 4 s).
3. Escale para **2 réplicas**, ambas `Ready` e sem reinícios; a Route `slowapp` responde.

## Task 6 — Templates (projeto `ex288-v3-sa-t6`)
Template fornecido: `apps/templates/webapp-template.yaml`.
1. Cadastre-o no projeto (objeto `Template` chamado `webapp-template`).
2. Instancie **`orders`** usando um **arquivo de parâmetros** (`NAME=orders`, `MESSAGE=sim-a`, `REPLICAS=2`): 2 réplicas prontas e Route respondendo `sim-a`.
3. Instancie **`orders-dev`** (`MESSAGE=dev`) com o rótulo **`env=dev`** em todos os objetos criados.

## Task 7 — Helm (projeto `ex288-v3-sa-t7`)
O Nexus tem um repositório Helm (`helm-hosted`, exige usuário e senha) com o chart `ex288-hello` nas versões 0.1.0 e 0.2.0.
1. Adicione o repositório e instale a versão **0.1.0** como release **`inventory`** neste projeto.
2. Faça o **upgrade** para a versão **0.2.0**: a Route `inventory-hello` deve responder `hello from helm v2`.
3. No upgrade, passe **`replicaCount=2`**: 2 réplicas prontas.

## Task 8 — CI/CD (projeto `ex288-v3-sa-t8`) — 16 pontos
1. (6) Pipeline **`sim-ci`** com **3 tasks** encadeadas por `runAfter` (taskSpec embutido) e parâmetro **`TARGET`**; execute até `Succeeded`.
2. (6) Pipeline **`sim-build`**: `git-clone` (Tasks do Operator, cluster resolver) do repositório privado `webapp-docker` → `buildah` publicando `image-registry.openshift-image-registry.svc:5000/ex288-v3-sa-t8/simapp:latest`; `Succeeded`.
3. (4) Deployment **`simapp`** com essa imagem e Route `simapp` respondendo `"app":"webapp-docker"`.

Ao terminar: `bash scripts/simulado-corrigir.sh A`.
