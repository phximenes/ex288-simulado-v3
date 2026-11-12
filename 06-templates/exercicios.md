[← README](README.md) | [índice](../README.md) | [solução →](solucao.md)

# T6 — Exercícios

Preparação: `bash scripts/preparar-06.sh` (cria `ex288-v3-t6`). O template fornecido é `apps/templates/webapp-template.yaml` (parâmetros `NAME` obrigatório, `MESSAGE`, `REPLICAS`, `APP_TOKEN` gerado). Validar: `bash scripts/validar-06.sh`.

**E1 — Instanciar um template de arquivo.**
Instancie o template fornecido com `NAME=tpl1`, `MESSAGE=ola-template` e `REPLICAS=2`. O Deployment `tpl1` deve ter 2 réplicas prontas, o Secret `tpl1-token` deve existir (token de 16 caracteres) e a Route `tpl1` deve responder `ola-template`. Todos os objetos devem ter o rótulo `template=webapp-template`.

**E2 — Template cadastrado no projeto e arquivo de parâmetros.**
Cadastre o template no projeto **`ex288-v3-t6`** (objeto `Template` chamado `webapp-template`) e crie, a partir dele, a instância `tpl2` usando um **arquivo de parâmetros** (`NAME=tpl2`, `MESSAGE=param-file`, `REPLICAS=1`). A Route `tpl2` deve responder `param-file`.

**E3 — Escreva o seu template.**
Crie um template chamado **`mini`** com um Deployment, um Service e uma Route, e dois parâmetros: **`NAME`** (obrigatório) e **`MESSAGE`** (valor padrão `hi`). A aplicação deve responder o valor de `MESSAGE` (use a imagem `registry.access.redhat.com/ubi9/nodejs-22-minimal:latest` com um servidor HTTP simples na porta 8080). Cadastre o template no projeto e instancie-o duas vezes: `mini-a` (padrão) e `mini-b` com `MESSAGE=bravo`.

**E4 — Template do namespace `openshift` com o Git interno (requer Git interno e builds).**
Use o template **`httpd-example`** do namespace `openshift` para criar a aplicação **`site-tpl`** com `SOURCE_REPOSITORY_URL` apontando para o repositório `httpd-ex` do Git interno. O repositório é privado: faça o build funcionar (source secret) e deixe a Route responder a página do `httpd-ex`.
