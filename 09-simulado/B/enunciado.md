[← simulado](../README.md) | [solução B →](solucao.md)

# Simulado B — enunciado (2 horas, 8 tasks independentes)

Prepare com `bash scripts/simulado-preparar.sh B`. Cada task tem seu **projeto próprio** (`ex288-v3-sb-tN`; a T4 usa também `ex288-v3-sb-t4-shared`). Git interno: URL e usuário via `bash scripts/credenciais.sh`; o Secret `git-creds` existe nos projetos T1, T2, T3 e T8. Todos os nomes são exatos.

## Task 1 — Deploy a partir do Git, repositório com dois componentes (`ex288-v3-sb-t1`)
O repositório **`monorepo`** tem os diretórios `api/` (Node.js) e `site/` (estático).
1. Faça o deploy de `api` como **`gateway`** (S2I Node.js 22, Secret `git-creds`).
2. Faça o deploy de `site` como **`static`** com o builder **httpd**.
3. `gateway` recebe **`APP_MESSAGE=sim-b`** (runtime) e o rótulo **`tier=edge`** nos recursos criados e é exposto pela Route `gateway`; crie também a Route **`static-tls`** (edge, redirecionando HTTP para HTTPS) para `static`.

## Task 2 — Dockerfile (`ex288-v3-sb-t2`)
1. A aplicação **`legacy`** usa o arquivo **`Dockerfile.root`** de `webapp-docker`. Crie o BuildConfig, deixe o pod `Running` (corrija o Dockerfile no repositório se necessário) e exponha com a Route `legacy`.
2. No BuildConfig `legacy`, passe o `ARG` **`NPM_REGISTRY`** apontando para o repositório **`npm-public`** do Nexus.
3. Baixe do Nexus (`raw-hosted`, `ex288/site-1.0.tar.gz`) o site estático e faça um **build binário** chamado **`ledger`** (Dockerfile com `ubi9/httpd-24`); Route `ledger` mostrando `site 1.0`.

## Task 3 — S2I (`ex288-v3-sb-t3`)
A aplicação **`reports`** (monorepo, diretório `api`) foi criada e o build está falhando.
1. Descubra a causa e corrija a **variável de build** para usar o **Nexus** (`npm-public`).
2. O novo build deve terminar `Complete` e o pod ficar `Ready`.
3. Defina **`APP_MESSAGE=reports-b`** em runtime e exponha a Route `reports` (a resposta contém `monorepo-api` e `reports-b`).

## Task 4 — ConfigMap, Secret existente e Secret de outro projeto (`ex288-v3-sb-t4`)
`cfgapp` já está implantada. O Secret **`shop-db`** (chaves `u` e `p`) já existe. No projeto `ex288-v3-sb-t4-shared` existe o Secret **`shop-token`** (chave `value`).
1. ConfigMap **`shop-cfg`** com `GREETING=SimB` e `LANG_CODE=en-US`, injetado por completo em `cfgapp`.
2. **`DB_USER`** (chave `u`) e **`DB_PASSWORD`** (chave `p`) vindos de `shop-db`, sem valores literais.
3. Recrie `shop-token` neste projeto (mesma chave e mesmo valor) e disponibilize **`API_TOKEN`** a `cfgapp` por `secretKeyRef`.

## Task 5 — Probes (`ex288-v3-sb-t5`)
`slowapp` e `slowbad` demoram ~20 s para subir (`/healthz` e `/ready`, porta 8080).
1. `slowapp`: **startup** e **readiness** por **TCP** 8080 (startup tolerando ≥ 30 s).
2. `slowapp`: **liveness por comando** (qualquer comando que retorne 0); pod `Ready`, sem reinícios.
3. `slowbad` reinicia continuamente por causa da liveness: **mantenha a liveness** e acrescente o que falta (tolerância de partida ≥ 40 s); `Ready`, sem reinícios.

## Task 6 — Templates (`ex288-v3-sb-t6`)
1. Crie o template **`stack`** com Secret, Deployment, Service e Route; parâmetros **`NAME`** (obrigatório), **`MESSAGE`** (valor padrão) e **`TOKEN`** (gerado, 12 caracteres alfanuméricos), com o token na chave **`token`** do Secret `${NAME}-token`. A aplicação responde `${MESSAGE}` (imagem `registry.access.redhat.com/ubi9/nodejs-22-minimal:latest`).
2. Instancie **`stack-a`** e **`stack-b`** (com `MESSAGE` diferente).
3. Os tokens têm 12 caracteres e as Routes respondem.

## Task 7 — Helm (`ex288-v3-sb-t7`)
Chart local: `apps/helm/ex288-hello`.
1. Gere o pacote `.tgz` e instale-o como release **`inventory`**.
2. Com um arquivo de valores: `replicaCount: 2` e `message: prod-b`.
3. Faça um **upgrade** (qualquer mudança) e um **rollback** para a revisão 1: a release termina com **3 revisões**.

## Task 8 — CI/CD (`ex288-v3-sb-t8`) — 16 pontos
1. (6) O arquivo **`apps/pipeline/pipeline-broken.yaml`** define o Pipeline **`broken-ci`**, que tem defeitos: corrija-o, aplique-o neste projeto e obtenha um PipelineRun `Succeeded` (o pipeline **não** vem aplicado no projeto).
2. (6) Pipeline **`sim-ci`** com 2 tasks encadeadas (taskSpec embutido); PipelineRun `Succeeded`.
3. (4) BuildConfig **`native`** (S2I Node.js, repositório `webapp`, source secret) com triggers **Generic** e **ImageChange** e **post-commit hook** `npm test`.

Ao terminar: `bash scripts/simulado-corrigir.sh B`.
