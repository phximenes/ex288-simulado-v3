[← README](README.md) | [índice](../README.md) | [solução →](solucao.md)

# T4 — Exercícios

Preparação: `bash scripts/preparar-04.sh` — cria `ex288-v3-t4` com a aplicação `cfgapp` (Route `cfgapp`, ainda sem configuração) e **um Secret que já existe** (`db-credentials`); cria também o projeto `ex288-v3-t4-shared`. Validar: `bash scripts/validar-04.sh`.
A `cfgapp` devolve em JSON o que recebeu (`greeting`, `lang`, `dbUser`, `hasPassword`, `hasToken`, `appHost`, `apiHost`); ela nunca mostra senhas.

**E1 — ConfigMap novo como variáveis de ambiente.**
Crie o ConfigMap **`app-config`** com `GREETING=Ola`, `LANG_CODE=pt-BR` e `API_HOST=http://api:8080` e injete **todas** as chaves como variáveis de ambiente no Deployment `cfgapp`. A Route deve mostrar `"greeting":"Ola"`, `"lang":"pt-BR"` e `"apiHost":"http://api:8080"`.

**E2 — Usar o Secret que já existe, com nomes de variável diferentes das chaves.**
O Secret **`db-credentials`** (no projeto `ex288-v3-t4`) tem as chaves `username` e `password`. A aplicação espera as variáveis **`DB_USER`** (valor da chave `username`) e **`DB_PASSWORD`** (valor da chave `password`). Configure o Deployment para isso **sem** valores literais no Deployment. A Route deve mostrar `"dbUser":"app"` e `"hasPassword":true`.

**E3 — Secret de outro projeto.**
No projeto `ex288-v3-t4-shared` existe o Secret **`shared-api`** com a chave `token`. A aplicação precisa da variável **`API_TOKEN`** com esse valor. Não é possível referenciar o Secret de outro projeto: faça o necessário para que `cfgapp` receba `API_TOKEN` via Secret de **seu** projeto (chamado `shared-api`, mesma chave e mesmo valor). A Route deve mostrar `"hasToken":true`.

**E4 — Prefixo e volume (variação mais difícil).**
Crie o ConfigMap **`extra-config`** com `HOST=cfg.example.invalid` e `PORT=9090`. Importe-o com o prefixo **`APP_`** (variáveis `APP_HOST` e `APP_PORT`). Crie também o ConfigMap **`app-files`** a partir de um arquivo local `app.properties` (conteúdo `feature.flag=on`) e monte-o **somente leitura** em `/etc/app` no `cfgapp`. A Route deve mostrar `"appHost":"cfg.example.invalid"` e o arquivo `/etc/app/app.properties` deve existir no pod.

Critérios: nada de senha escrita em arquivos do material; ao final, `oc rollout status deployment/cfgapp` bem-sucedido.
