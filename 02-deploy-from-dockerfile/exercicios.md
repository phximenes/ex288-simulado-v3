[← README](README.md) | [índice](../README.md) | [solução →](solucao.md)

# T2 — Exercícios

Preparação: `bash scripts/preparar-02.sh` (cria `ex288-v3-t2` e o Secret `git-creds`) · Validar: `bash scripts/validar-02.sh`.
Repositório: `webapp-docker` (arquivos `Dockerfile` e `Dockerfile.root`). Nexus: `bash scripts/credenciais.sh --show`.

**E1 — Build Docker detectado automaticamente.**
Faça o deploy de `webapp-docker` como **`docker1`** com estratégia **Docker**, usando o Secret `git-creds`. A Route `docker1` deve responder `"app":"webapp-docker"` e o processo **não** pode rodar como UID 0.

**E2 — `ARG` apontando para o mirror npm do Nexus.**
Crie o BuildConfig **`docker-nexus`** (saída `docker-nexus:1.0`) a partir do mesmo repositório, passando o `ARG` **`NPM_REGISTRY`** com a URL do repositório **`npm-public`** do Nexus. O build deve terminar `Complete` e o pacote `ms` precisa aparecer no repositório `npm-proxy` do Nexus (prova de que o mirror foi usado).

**E3 — Dockerfile incompatível com OpenShift.**
Faça o deploy de **`root-app`** usando o arquivo **`Dockerfile.root`** do repositório. O pod vai falhar: descubra a causa nos logs e corrija **no repositório** (commit e push em `main`), de modo que o novo build gere um pod `Running` com a Route `root-app` respondendo `"app":"webapp-docker"`. Mantenha o nome do arquivo `Dockerfile.root`.

**E4 — Build binário com artefato vindo do Nexus.**
Baixe do Nexus (repositório **raw** `raw-hosted`, caminho `ex288/site-1.0.tar.gz`; exige usuário e senha) o site estático, escreva um Dockerfile que o sirva com `registry.access.redhat.com/ubi9/httpd-24` e faça um **build binário** chamado **`site-bin`**. A aplicação `site-bin` deve estar pronta e a Route `site-bin` deve devolver a página `site 1.0`.

**E5 — Imagem construída e publicada com podman (requer `podman`).**
Construa com `podman` a imagem do `webapp-docker` e publique-a no registry interno como **`pushed:1.0`** no projeto `ex288-v3-t2`. Faça o deploy **`pushed`** a partir dessa ImageStreamTag, com a Route `pushed` respondendo.
