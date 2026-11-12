[← mapa das 8 tasks](../00-guia/mapa-8-tasks.md) | [índice](../README.md)

# Git interno e Nexus — como usar (a lacuna que o relato apontou)

> Relato: o ambiente da prova fornece um **servidor Git** e um **repositório de artefatos Nexus**; o Nexus apareceu "em algumas tasks" e pegou o seu amigo de surpresa `[RELATO PESSOAL]`. Não há relato público sobre isso. O courseware DO288 também usa um Nexus de sala (mirror Maven/npm), o que é indício `[OFICIAL]` de que ele existe no ecossistema de treinamento. **O uso exato na prova é `HIPÓTESE`**: o que segue cobre os usos plausíveis.

## O lab (como foi desenhado)

| Peça | Imagem / produto | Onde | Observação |
|---|---|---|---|
| Git interno | Gitea 1.27.3 (rootless, MIT) | `ex288-v3-infra`, rota `gitea-ex288-v3-infra.apps-crc.testing` | 5 repositórios **privados** (`webapp` com branches `main`/`dev`, `monorepo`, `webapp-docker`, `webapp-s2i`, `httpd-ex`); autenticação básica |
| Nexus | `sonatype/nexus3:3.96.5-ubi` (Community) | `ex288-v3-infra`, rota `nexus-ex288-v3-infra.apps-crc.testing` | repositórios `npm-proxy`/`npm-public`, `maven-proxy`/`maven-hosted`/`maven-public`, `helm-hosted`, `raw-hosted`, `docker-hosted` (:5000) |
| Subir tudo | `bash scripts/infra-up.sh` (idempotente) **logado como `developer`** — o mesmo usuário dos exercícios; criado por `kubeadmin`, o projeto fica invisível ao `developer` (`VERIFICADO`) | — | requer o CRC com disco/memória suficientes ([pré-requisitos §13](../00-guia/preparar-wsl-rhel.md#13-capacidade-do-crc-decisão-pendente)) |
| Credenciais | `bash scripts/credenciais.sh --show` | Secrets `gitea-admin` e `nexus-admin` | senhas **geradas**, só no Secret; nunca em arquivo |

> [!WARNING]
> **Status final (`VERIFICADO` no CRC 4.22.14 ampliado: 6 CPUs / 16 GiB / 64 GiB):** Gitea e Nexus rodam juntos (`1/1 Running`, `BestEffort`); o EULA foi **aceito por você** (POST → HTTP 204) e `infra-up.sh` carregou os charts `ex288-hello` 0.1.0 e 0.2.0 (`helm-hosted`, HTTP 200), o artefato `ex288/site-1.0.tar.gz` (`raw-hosted`, 201) e o JAR/POM de teste (`maven-hosted`, 201). Acesso anônimo: `npm-public` 200; `helm-hosted` e `raw-hosted` 401 (como desenhado). O proxy npm cacheia o `ms` e a busca `…/search?repository=npm-proxy&name=ms` o encontra. Usado de verdade em T2 (ARG e artefato), T3 (`npm_config_registry`), T7 (`helm repo add`) e nos simulados.
>
> **Histórico da 1ª tentativa (CRC padrão, 32 GB de disco):**
> - **Nexus:** o pod `sonatype/nexus3:3.96.5-ubi` chegou a `1/1 Running` (heap 512–768 MB, BestEffort, sem PVC); o `infra-up.sh` trocou a senha inicial do admin, criou `npm-proxy`, `npm-public`, `maven-proxy`, `maven-hosted`, `helm-hosted`, `raw-hosted` e `docker-hosted` pela API REST e o gate do EULA funciona. **Uploads e downloads via proxy retornam HTTP 403 até você aceitar o EULA da edição Community** (veja [pré-requisitos §14](../00-guia/preparar-wsl-rhel.md#14-eula-do-nexus-community--decisão-sua-verificado-que-é-exigido)); eu não aceitei por você. Acesso anônimo a `helm-hosted` retorna 401 (como desenhado).
> - **Estabilidade:** puxar a imagem do Nexus (~1 GB) empurra o disco da VM do CRC acima do limite (`imagefs.available < 15%`): o nó fica em `DiskPressure`, recebe o taint `disk-pressure:NoSchedule` e despeja pods `BestEffort` em loop. Por isso o lab completo (Git + Nexus + builds + Pipelines) **não roda** com o CRC "como está" — ver [relatório](../_meta/RELATORIO-FINAL.md).
> - **Gitea:** subiu no CRC (`1/1`, storage `emptyDir`, porque o PVC dependia do driver CSI do CRC que caiu com o `DiskPressure`); o `infra-up.sh` criou o usuário e publicou os 5 repositórios **privados** (branches `main` e `dev` no `webapp`); o clone anônimo é recusado. Os dados somem se o pod reiniciar: rode `infra-up.sh` de novo.
> - Limites de uso e consumo real de memória da edição Community do Nexus: `NÃO VERIFICADO`.

## Git interno: o que praticar

| Tarefa | Como |
|---|---|
| Achar a URL de clone | UI: repositório → **Clone** (HTTP). API: `curl -u U:P http://GIT/api/v1/repos/search?limit=50 \| grep clone_url`. Teste: `git ls-remote http://GIT/ex288/webapp.git` |
| Credenciais no OpenShift | `oc create secret generic git-creds --type=kubernetes.io/basic-auth --from-literal=username=U --from-literal=password=P` e `--source-secret git-creds` (ou `oc set build-secret --source bc/x git-creds`) |
| Tekton | Secret `basic-auth` com a anotação `tekton.dev/git-0: http://GIT` + `oc secrets link pipeline SEGREDO` |
| `git clone/push` | `git clone http://U@GIT/ex288/webapp.git` (peça a senha no prompt) · `git push origin main` |
| Branch/tag/contexto | `--code URL#dev` · `--context-dir dir` |

O `oc new-app <url>` **clona no cliente**: o nome do servidor Git precisa resolver no host de onde você roda o `oc`.

## Nexus: usos plausíveis (todos `HIPÓTESE`)

| # | Uso | Como (comando-chave) | Onde treinar |
|---|---|---|---|
| 1 | **Mirror de dependências** em builds S2I | Node: `--build-env npm_config_registry=http://NEXUS/repository/npm-public/` · Maven (builders Java): `--build-env MAVEN_MIRROR_URL=http://NEXUS/repository/maven-public/` (nome da variável: conferir no README do builder, `NÃO VERIFICADO` aqui) | [T3](../03-deploy-s2i/README.md) |
| 2 | Mirror no **Dockerfile** | `ARG NPM_REGISTRY` + `--build-arg` | [T2](../02-deploy-from-dockerfile/README.md) |
| 3 | **Baixar um artefato pronto** (JAR, `.tar.gz`) e fazer **build binário** | `curl -u U:P -O http://NEXUS/repository/raw-hosted/ex288/site-1.0.tar.gz` → `oc new-build --binary` + `oc start-build --from-dir`/`--from-archive`/`--from-file` | [T2 E4](../02-deploy-from-dockerfile/exercicios.md) |
| 4 | **Repositório Helm** autenticado | `helm repo add nexus http://NEXUS/repository/helm-hosted/ --username U --password P` | [T7](../07-helm/README.md) |
| 5 | **Registry de imagens** | `oc create secret docker-registry nx --docker-server=HOST:5000 --docker-username=U --docker-password=P` + `oc secrets link default nx --for=pull` (e `builder` para build); como o Nexus aqui é HTTP: `oc import-image ... --insecure --reference-policy=local` | opcional, `NÃO VALIDADO` |
| 6 | Credenciais do Nexus em **Secret** | `oc create secret generic nexus-cred --from-literal=username=… --from-literal=password=…` (e `settings.xml`/`.npmrc` em ConfigMap/Secret montado no build, como no curso) | [T3](../03-deploy-s2i/README.md) |

### Achar a URL certa de um artefato

| Onde | Passo |
|---|---|
| **UI** | *Browse* → escolha o repositório → navegue até o arquivo → painel **Path** / botão **Copy URL**. Para Maven: `/repository/REPO/GROUP/COM/BARRAS/ARTEFATO/VERSAO/ARTEFATO-VERSAO.jar` |
| **API REST** | `curl -s -u U:P http://NEXUS/service/rest/v1/repositories` (lista repos e tipos) · `…/service/rest/v1/search/assets?repository=raw-hosted&name=ex288/site-1.0.tar.gz` (devolve `downloadUrl`) · `…/service/rest/v1/search?repository=npm-proxy&name=ms` (componente) |
| **Padrões** | npm: URL do **grupo** (`/repository/npm-public/`) como registry · Helm: URL do repositório **com `/` final** · raw: `/repository/REPO/caminho/arquivo` · Docker: porta própria (`:5000`) |

Se o Nexus pedir login para leitura (anônimo desligado), use `-u USUARIO:SENHA` no `curl`, `--username/--password` no helm e Secrets nos builds.

## Se o nome do servidor não resolver

`getent hosts HOST`. Com o WSL em `mirrored`, o próprio CRC mantém o `hosts` do Windows com as rotas novas (`VERIFICADO` em 2026-11-08: resolve em segundos), então isto só falha com o `crc` parado ou o WSL em NAT. Plano B: `bash scripts/hosts-sync.sh | sudo tee -a /etc/hosts`. Para `curl`, `--resolve HOST:80:127.0.0.1` basta; para `oc new-app`/`helm`/`podman` é preciso resolver de verdade. Na prova real o ambiente resolve os nomes para você.
