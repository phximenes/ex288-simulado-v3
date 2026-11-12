[índice](../README.md) | [pré-requisitos do WSL (detalhes) →](preparar-wsl-rhel.md)

# Cookbook — montar a infraestrutura do lab do zero (Windows 11 + CRC zerado)

Receitas na ordem de execução para sair de **um Windows 11 com o OpenShift Local (CRC) instalado e sem cluster** até **Pipelines, GitOps, Gitea e Nexus funcionando** e conferidos por script. Cada receita diz onde roda, com que usuário, o que esperar e como conferir.

> [!IMPORTANT]
> **Honestidade sobre a validação (2026-11-08 e 09).** Não existe uma execução única "CRC zerado → tudo pronto": isso exigiria destruir o cluster que você usa nos simulados. O que existe: (1) o estado final foi conferido **hoje, só leitura, no seu cluster**, por [`scripts/checar-infra.sh`](../scripts/checar-infra.sh): **31 PASS / 1 WARN / 0 FAIL** (33 PASS / 0 WARN com o GitOps da R9 no ar); (2) R5, R7 e R8 foram executadas e validadas nas sessões anteriores (relatório final); (3) hoje executei **literalmente, extraindo os blocos deste arquivo**, os de R2 (conectividade), R5 (Tasks), R7 (`credenciais.sh`), R9 passo 1 (repositório no Gitea, com nome de teste, removido depois) e R10 (smoke do Tekton: `mini-ci` **Succeeded**); a 1ª execução do smoke **falhou** (corrida com a ServiceAccount `pipeline`) e o bloco foi corrigido; (4) R6 foi **instalada por você** e conferida por leitura (CSV `Succeeded`); (5) **R9 foi executada de ponta a ponta em 2026-11-09** (você autorizou): Argo CD `Available` em 45 s, `Application` `Synced/Healthy`, ciclo `gitops v1` → `v2` e `selfHeal`; depois, `ex288-v3-gitops` e o repositório de teste foram removidos; (6) R1 (`crc setup` + 1º `crc start`) é o procedimento padrão da Red Hat e **não foi repetido** neste PC. Marcadores: `VERIFICADO` · `NÃO VERIFICADO` · `[OFICIAL]` · `[BOA PRÁTICA]`.

## Mapa

| Receita | O que faz | Onde / usuário | Estado |
|---|---|---|---|
| [R1](#r1--crc-configurar-preparar-e-iniciar) | CRC: recursos, `setup`, `start` | PowerShell (admin no `setup`) | `[OFICIAL]`; config `VERIFICADO` |
| [R2](#r2--windows--wsl-rede-espelhada-e-nomes) | WSL alcança o CRC; nomes das rotas | PowerShell + WSL | `VERIFICADO` |
| [R3](#r3--ferramentas-no-wsl) | `oc`, `helm`, `podman`, `git`, `tkn` | WSL, usuário comum | `VERIFICADO` (versões) |
| [R4](#r4--login-e-kubeconfig-developer-e-kubeadmin-separados) | Login `developer`; admin em arquivo separado | WSL | `VERIFICADO` |
| [R5](#r5--openshift-pipelines-operator) | Tekton (T8) | WSL, **kubeadmin** | `VERIFICADO` |
| [R6](#r6--openshift-gitops-operator) | Argo CD | WSL, **kubeadmin** | instalado `VERIFICADO` (leitura); comandos `NÃO VERIFICADO` |
| [R7](#r7--git-interno-gitea-e-nexus) | Gitea + Nexus + conteúdo | WSL, **developer** | `VERIFICADO` |
| [R8](#r8--registry-interno-e-ca-no-podman) | `podman` confia no registry | WSL | `VERIFICADO` |
| [R9](#r9--argo-cd-de-laboratório-e-app-de-demonstração) | Argo CD restrito a um projeto + app | WSL, developer | `VERIFICADO` de ponta a ponta (2026-11-09) |
| [R10](#r10--verificação-final) | Conferir tudo | WSL, developer | `VERIFICADO` |
| [R11](#r11--operação-parar-religar-recuperar-limpar) | Dia a dia, capacidade, recomeçar | PS + WSL | `VERIFICADO` (observado) |
| [R12](#r12--diagnóstico-sintoma--causa--correção) | Tabela de problemas | — | `VERIFICADO` salvo indicação |

Quem usa o quê: **PowerShell** = Windows; **WSL** = bash do `RedHatEnterpriseLinux-10.2` como usuário comum; **kubeadmin** só em R5 e R6 (e nunca para criar projetos do lab); **developer** em todo o resto.

## O que o lab precisa de cada peça

| Peça | Usada por |
|---|---|
| Gitea (Git privado) | T1, T2, T3, T8, simulados |
| Nexus (npm, Helm, raw, Maven) | T2 (`ARG` e artefato), T3 (`npm_config_registry`), T7 (`helm repo add`), simulados |
| OpenShift Pipelines | T8 e simulados |
| Registry interno + `podman` | T2 E5 |
| OpenShift GitOps (Argo CD) | **fora das 8 tasks relatadas**; incluído porque você pediu. Relevância para a prova: `HIPÓTESE` (sem relato) |

## Versões que este cookbook conhece (lidas hoje no seu PC)

| Componente | Versão | Como foi lida |
|---|---|---|
| Windows 11 Pro | build 10.0.26300 | `wsl --version` |
| WSL / kernel | 3.0.3.0 / 6.18.54.1 | `wsl --version` |
| CRC / OpenShift / MicroShift | 2.64.0 / **4.22.14** / 4.22.13 | `crc version` |
| `oc` (cliente, do console) / `helm` / `podman` / `git` | 4.22.0 / 3.17.4 (build Red Hat) / 5.8.2 / 2.52.0 | no WSL |
| OpenShift Pipelines | **1.24.3** | CSV `Succeeded` |
| OpenShift GitOps | **1.22.3** (modo AllNamespaces) | CSV `Succeeded` |
| Gitea | 1.27.3 rootless | `apps/infra/gitea.yaml` |
| Nexus Repository Community | 3.96.5-ubi | `apps/infra/nexus.yaml` |
| StorageClass padrão | `crc-csi-hostpath-provisioner` | `oc get storageclass` |

---

## R1 — CRC: configurar, preparar e iniciar

**Onde:** PowerShell. **Pressuposto:** CRC instalado (`crc version` responde), conta Red Hat e o *pull secret* baixado de <https://console.redhat.com/openshift/create/local> para **fora** deste repositório (por exemplo `%USERPROFILE%\pull-secret.txt`). Nunca grave o pull secret no material.

```powershell
crc version
crc config set cpus 8                  # validado: 6 e 8
crc config set memory 16384            # validado: 16384 (MiB)
crc config set disk-size 128           # validado: 64 e 128; só CRESCE depois
crc config set consent-telemetry no    # opcional
crc config set pull-secret-file "$env:USERPROFILE\pull-secret.txt"    # opcional: evita colar o secret no prompt
crc setup                              # prepara o host (Hyper-V etc.); exige elevar para Administrador; pode pedir reinício
crc start                              # sem o pull-secret-file, cole o secret quando pedir
crc status
crc console --credentials              # mostra developer e kubeadmin SO na tela: não copie para arquivo
```

- **Por que ampliar antes do 1º `start`:** com o padrão (observado aqui em 2026-10-31: 4 CPUs, ~11 GB de RAM, ~32 GB de disco) o nó entrou em `DiskPressure` ao puxar as imagens do Nexus e do Pipelines e passou a despejar pods (`VERIFICADO`). Perfil validado: **6 CPUs / 16 GiB / 64 GiB**; o seu atual é **8 / 16 GiB / 128 GiB** (`crc config view`).
- **Crescer depois:** `crc stop` → `crc config set disk-size N` → `crc start` cresce o disco da VM existente, sem `crc delete` (`VERIFICADO`). Diminuir não é possível.
- **Consumo observado hoje** com Pipelines, GitOps, Gitea, Nexus e o simulado A ativos: RAM 13,72 de 16,76 GB; disco 78,16 de 136,8 GB dentro da VM (`crc status`). O disco cresce com imagens e builds: veja [R11](#r11--operação-parar-religar-recuperar-limpar).
- `crc setup` e o 1º `crc start` seguem o procedimento oficial ([Red Hat OpenShift Local — getting started](https://docs.redhat.com/en/documentation/red_hat_openshift_local/2.41/html/getting_started_guide/using)) `[OFICIAL]`; neste PC **não foram repetidos** (`NÃO VERIFICADO`).

**Conferir:** `crc status` → `CRC VM: Running` e `OpenShift: Running (v4.22.x)`.

## R2 — Windows ↔ WSL: rede espelhada e nomes

**Por quê:** o CRC no Windows publica a API e o roteador no **loopback do Windows**: no `hosts` do Windows, `api.crc.testing`, `console-openshift-console.apps-crc.testing` etc. apontam para `127.0.0.1` (`VERIFICADO`). Com a rede NAT padrão do WSL, o `127.0.0.1` do WSL é outro loopback e o `curl` dá HTTP 000. Com `mirrored` os dois compartilham o loopback.

```powershell
Set-Content -Path "$env:USERPROFILE\.wslconfig" -Value "[wsl2]`nnetworkingMode=mirrored"
wsl --shutdown          # derruba TODAS as distros e o Docker Desktop
```

```bash
curl -sk -o /dev/null -w '%{http_code}\n' https://api.crc.testing:6443/version                    # 200
curl -sk -o /dev/null -w '%{http_code}\n' https://console-openshift-console.apps-crc.testing/     # 200 ou 302
```

**Nomes das rotas novas (`VERIFICADO` em 2026-11-08):** o próprio `crc` mantém o bloco `# Added by CRC` do `hosts` do Windows, **acrescentando e removendo** as rotas do cluster em segundos; o WSL em modo `mirrored` resolve pelo Windows. Teste: criei uma rota num projeto descartável, ela resolveu em menos de 2 s e a entrada sumiu do `hosts` depois que o projeto foi removido. Portanto **não é preciso** editar `/etc/hosts` nem o `hosts` do Windows para Gitea, Nexus ou rotas de exercícios; [`scripts/hosts-sync.sh`](../scripts/hosts-sync.sh) fica só como plano B (por exemplo, `crc` parado ou WSL em NAT).

> [!NOTE]
> Isto corrige o que o [passo 3 dos pré-requisitos](preparar-wsl-rhel.md#3-resolver-as-rotas-do-lab-git-e-nexus) dizia ("rotas novas não resolvem"): aquele teste usou um nome de rota que não existia.

## R3 — Ferramentas no WSL

**Onde:** WSL, usuário comum (nunca root).

```bash
sudo dnf install -y git-core curl podman skopeo jq vim-enhanced bash-completion
mkdir -p ~/.local/bin ~/.kube && chmod 700 ~/.kube
# oc: baixe o do PROPRIO cluster (mesma versao). O console precisa resolver (R2); -k porque a CA do CRC nao e confiada
cd /tmp && curl -kLO https://downloads-openshift-console.apps-crc.testing/amd64/linux/oc.tar
tar -tf oc.tar                              # confira o conteudo antes
tar -xf oc.tar -C ~/.local/bin oc && rm oc.tar
oc version --client
```

| Ferramenta | De onde | Nota |
|---|---|---|
| `helm` | `https://mirror.openshift.com/pub/openshift-v4/clients/helm/latest/` (confira o `sha256sum.txt` ao lado) | o seu é o build Red Hat 3.17.4; a versão da prova é `NÃO VERIFICADO` |
| `tkn` (opcional) | `https://mirror.openshift.com/pub/openshift-v4/clients/pipelines/latest/tkn-linux-amd64.tar.gz` | só faz sentido depois da R5; o v3 funciona sem ele |
| `~/.vimrc`, completion | [preparar-wsl-rhel.md §11](preparar-wsl-rhel.md#11-completion-e-vimrc-o-que-você-terá-na-prova) | o que você terá na prova |

Detalhes, motivos e alternativas: [preparar-wsl-rhel.md §1–§11](preparar-wsl-rhel.md). **Conferir:** `bash scripts/checar-ambiente.sh` (seu estado atual: 32 PASS).

## R4 — Login e kubeconfig: `developer` e `kubeadmin` separados

Dois kubeconfigs evitam trocar de usuário no meio do caminho e protegem o contexto do `developer` (o que você usa nos exercícios).

```bash
# developer: kubeconfig padrao (~/.kube/config). A senha e pedida no prompt (nao use -p: ela iria para o ~/.bash_history)
oc login -u developer https://api.crc.testing:6443 --insecure-skip-tls-verify=true
oc whoami

# kubeadmin: arquivo separado, usado SO nas receitas R5 e R6
export KA="$HOME/.kube/admin.kubeconfig"
KUBECONFIG="$KA" oc login -u kubeadmin https://api.crc.testing:6443 --insecure-skip-tls-verify=true
chmod 600 "$KA"
```

- Senhas: `crc console --credentials` (PowerShell), só na tela.
- **Rode `infra-up.sh` e todos os `preparar-0N.sh` como `developer`**: quem cria o projeto é o dono; um projeto criado pelo `kubeadmin` fica invisível ao `developer` (`VERIFICADO`).
- Se uma senha já foi digitada com `-p`, apague a linha: `history | grep -n 'login.* -p'`, depois `history -d N` e `history -w`.

## R5 — OpenShift Pipelines Operator

**Onde:** WSL, **kubeadmin** (`$KA`). O Operator é de cluster e vive em `openshift-operators`; o v3 não instala Operators sozinho.

```bash
KUBECONFIG="$KA" oc apply -f apps/pipeline/operator-subscription.yaml
until KUBECONFIG="$KA" oc get csv -n openshift-operators --no-headers 2>/dev/null | grep -q 'openshift-pipelines-operator-rh.*Succeeded'; do sleep 10; done
until oc get task git-clone -n openshift-pipelines >/dev/null 2>&1; do sleep 5; done      # ja como developer
oc get task -n openshift-pipelines --no-headers | awk '{print $1}' | tr '\n' ' '
```

- Canal `latest` → `openshift-pipelines-operator-rh.v1.24.3`; modo AllNamespaces (`VERIFICADO`).
- Tasks reais da 1.24 (lidas hoje): `git-clone`, `buildah`, `openshift-client`, `s2i-*`, `skopeo-copy`, `kn`, `helm-upgrade-from-repo`, `argocd-task-sync-and-wait`… O `ClusterTask` não existe mais nesta versão (`oc api-resources` não o lista, `VERIFICADO`): os pipelines do v3 usam o **cluster resolver** (`namespace: openshift-pipelines`).
- Um namespace novo ganha a ServiceAccount `pipeline` sozinha, **com um atraso de alguns segundos** (os scripts esperam por ela). `VERIFICADO` em 2026-11-08: um PipelineRun criado logo depois do `oc new-project` falhou com `PodCreationFailed … serviceaccounts "pipeline" not found`.

## R6 — OpenShift GitOps Operator

**Onde:** WSL, **kubeadmin** (`$KA`). Forma documentada pela Red Hat desde o GitOps 1.10: namespace próprio, OperatorGroup e Subscription (`channel: latest`) [(docs 1.22)](https://docs.redhat.com/fr/documentation/red_hat_openshift_gitops/1.22/html/installing_gitops/installing-openshift-gitops) `[OFICIAL]`.

```bash
KUBECONFIG="$KA" oc apply -f apps/gitops/operator-subscription.yaml
until KUBECONFIG="$KA" oc get csv -n openshift-gitops-operator --no-headers 2>/dev/null | grep -q 'openshift-gitops-operator.*Succeeded'; do sleep 10; done
oc api-resources --api-group=argoproj.io -o name | grep -E '^(applications|argocds)\.'        # developer ja enxerga os CRDs
```

Estado **encontrado** no seu cluster (leitura como `developer`, hoje): CSV `openshift-gitops-operator.v1.22.3` `Succeeded`, modo `AllNamespaces`, CRDs `argocds`, `applications`, `applicationsets`, `appprojects`, `rolloutmanagers`…; o Operator cria a instância padrão em `openshift-gitops` (a rota `openshift-gitops-server-openshift-gitops.apps-crc.testing` está no `hosts`). O `developer` **não** lê `Subscription`, `PackageManifest` nem lista `argocds` no cluster inteiro (`Forbidden`), por isso o canal exato da sua Subscription é `NÃO VERIFICADO`. Para conferir o canal padrão: `KUBECONFIG="$KA" oc get packagemanifest openshift-gitops-operator -n openshift-marketplace -o jsonpath='{.status.defaultChannel}'`.

> [!NOTE]
> Capacidade: cada instância do Argo CD pesa. Se faltar memória, a Red Hat documenta desligar a instância padrão com a variável `DISABLE_DEFAULT_ARGOCD_INSTANCE=true` na Subscription (`spec.config.env`) `NÃO VERIFICADO` aqui. A R9 usa uma instância pequena, restrita a um projeto.

## R7 — Git interno (Gitea) e Nexus

**Onde:** WSL, **developer**. [`scripts/infra-up.sh`](../scripts/infra-up.sh) é idempotente e faz tudo:

```bash
bash scripts/infra-up.sh                       # 1a vez: Gitea sobe logo; o Nexus leva alguns minutos
```

| Etapa | O que acontece |
|---|---|
| 1/5 | `apps/infra/gitea.yaml` e `nexus.yaml` no projeto `ex288-v3-infra` (Deployment, Service, Route; `emptyDir`; BestEffort) |
| 2/5 | Secret `gitea-admin` (senha gerada), usuário `ex288` e **5 repositórios privados**: `webapp` (`main` e `dev`), `monorepo`, `webapp-docker`, `webapp-s2i`, `httpd-ex` |
| 3/5 | Nexus: troca a senha inicial do `admin` (Secret `nexus-admin`) e cria `npm-proxy`/`npm-public`, `maven-proxy`/`maven-hosted`/`maven-public`, `helm-hosted`, `raw-hosted`, `docker-hosted` |
| 4/5 | Leitura anônima só para maven e npm; Helm, raw e Docker exigem login |
| 5/5 | Conteúdo: charts `ex288-hello` 0.1.0 e 0.2.0, `ex288/site-1.0.tar.gz` (raw), JAR/POM de teste |

> [!WARNING]
> **EULA do Nexus Community: decisão sua.** Sem o aceite o Nexus devolve **HTTP 403** em uploads e em downloads pelo proxy npm (`VERIFICADO`) e a etapa 5/5 fica pendente. Leia <https://links.sonatype.com/products/nxrm/ce-eula> e, se concordar: `NEXUS_ACCEPT_EULA=yes bash scripts/infra-up.sh`. O script não aceita por você.

```bash
bash scripts/credenciais.sh                    # URLs e usuarios (as senhas so com --show; nunca em arquivo)
```

- **Persistência (observado hoje):** os pods têm 8 dias e 2 reinícios e **mantêm** repositórios e charts (`checar-infra.sh` PASS). Mas `emptyDir` morre se o **pod for recriado** (despejo por `DiskPressure`, `oc delete pod`, `rollout restart`): rode `infra-up.sh` de novo.
- **Cuidado:** `infra-up.sh` republica os repositórios com `git push --force` e **apaga as suas correções** nos repositórios (por exemplo, o `Dockerfile.root` consertado no T2). Não rode no meio de um simulado.
- Variáveis: `SKIP_GIT=1` / `SKIP_NEXUS=1` sobem só uma das peças.
- Uso no dia a dia: [Git interno e Nexus](../00-nexus-e-git-interno/README.md).

## R8 — Registry interno e CA no `podman`

Para o T2 E5 (`podman push` para o registry do cluster) sem `--tls-verify=false`: veja [preparar-wsl-rhel.md §9](preparar-wsl-rhel.md#9-confiar-na-ca-do-crc-para-o-podman-no-registry-interno-verificado-no-seu-wsl). Em resumo: o host sai de `oc registry info --public` (o `developer` **não** lê a rota `default-route`: `Forbidden`), a CA vem do ConfigMap `default-ingress-cert` (exige admin; use `$KA`) e vai para `/etc/containers/certs.d/<host>/ca.crt`.

## R9 — Argo CD de laboratório e app de demonstração

**Objetivo:** praticar GitOps sem `cluster-admin` e sem pesar o CRC: uma instância do Argo CD **restrita a um projeto**, sincronizando o repositório privado `gitops-demo` do Gitea.

> [!WARNING]
> **Estado: `VERIFICADO` de ponta a ponta em 2026-11-09** (você autorizou; blocos extraídos deste arquivo, com `KUBECONFIG` privado, e tudo removido depois). Resultado: instância `lab` `Available` em **45 s**; `Application` `Synced/Healthy` em ~30 s; o app respondeu `gitops v1`; um `git push` com `gitops v2` foi aplicado depois de um *refresh* (veja o passo 4); o `selfHeal` desfez uma alteração manual em ~4 s; o login do `admin` na API deu HTTP 200; `checar-infra.sh` passou a **33 PASS / 0 WARN / 0 FAIL** com o GitOps no ar. O `developer` cria `argocds`, `applications` e `appprojects` no próprio projeto (`oc auth can-i`: yes). **Custo:** `crc status` foi de 14,19 para 14,49 GB de RAM (de 16,76 GB) com o lab no ar; os pods do Gitea e do Nexus **não** foram recriados. Como o Gitea e o Nexus são `BestEffort` (nos YAMLs), eles seriam os primeiros despejados se a RAM acabasse (comportamento documentado do kubelet; não ocorreu): confira `crc status` antes de subir e apague o projeto quando terminar.

**1. Repositório `gitops-demo` no Gitea** (a senha só em memória):

```bash
GH="$(oc get route gitea -n ex288-v3-infra -o jsonpath='{.spec.host}')"
GU="$(oc get secret gitea-admin -n ex288-v3-infra -o jsonpath='{.data.username}' | base64 -d)"
GP="$(oc get secret gitea-admin -n ex288-v3-infra -o jsonpath='{.data.password}' | base64 -d)"
printf 'user = "%s:%s"\n' "$GU" "$GP" | curl -s -K - -H 'Content-Type: application/json' \
  -d '{"name":"gitops-demo","private":true,"default_branch":"main"}' "http://$GH/api/v1/user/repos" -o /dev/null -w 'repo: HTTP %{http_code}\n'      # 201
D="$(mktemp -d)" && cp -a apps/gitops/demo-app/. "$D"/ && ( cd "$D" && git init -q -b main && git add -A \
  && git -c user.name=ex288 -c user.email=ex288@example.invalid commit -qm "gitops-demo v1" \
  && git -c credential.helper= push -q "http://$GU:$GP@$GH/ex288/gitops-demo.git" main ) ; rm -rf "$D"
sleep 4; printf 'user = "%s:%s"\n' "$GU" "$GP" | curl -s -K - "http://$GH/api/v1/repos/ex288/gitops-demo/branches/main" -o /dev/null -w 'branch main: HTTP %{http_code}\n'      # 200 (logo apos o push a API devolve 500 por ~3 s)
```

**2. Projeto e instância do Argo CD** (`--skip-config-write` deixa o seu projeto corrente como está):

```bash
oc new-project ex288-v3-gitops --skip-config-write
oc apply -n ex288-v3-gitops -f apps/gitops/argocd-lab.yaml
for i in $(seq 1 72); do [ "$(oc get argocd lab -n ex288-v3-gitops -o jsonpath='{.status.phase}' 2>/dev/null)" = Available ] && break; sleep 5; done; oc get pods -n ex288-v3-gitops      # ~45 s: lab-application-controller-0, lab-redis, lab-repo-server, lab-server
oc get route -n ex288-v3-gitops              # lab-server-ex288-v3-gitops.apps-crc.testing (reencrypt; HTTP 200); entre em https://... com o usuario 'admin'
oc get secret lab-cluster -n ex288-v3-gitops -o jsonpath='{.data.admin\.password}' | base64 -d; echo     # senha do 'admin' (32 caracteres; login na API: HTTP 200)
```

**3. Credencial do repositório e `Application`** (o Argo CD lê Secrets com o rótulo `argocd.argoproj.io/secret-type=repository`):

```bash
oc create secret generic gitea-repo -n ex288-v3-gitops --from-literal=type=git \
  --from-literal=url=http://gitea.ex288-v3-infra.svc.cluster.local:3000/ex288/gitops-demo.git \
  --from-literal=username="$GU" --from-literal=password="$GP"
oc label secret gitea-repo -n ex288-v3-gitops argocd.argoproj.io/secret-type=repository
oc apply -n ex288-v3-gitops -f apps/gitops/application.yaml
for i in $(seq 1 60); do [ "$(oc get application gitops-demo -n ex288-v3-gitops -o jsonpath='{.status.sync.status}/{.status.health.status}' 2>/dev/null)" = Synced/Healthy ] && break; sleep 5; done
oc get application -n ex288-v3-gitops                                   # Synced / Healthy em ~30 s (logo apos o apply o status vem vazio)
curl -sf --retry 6 --retry-delay 2 "http://$(oc get route gitops-demo -n ex288-v3-gitops -o jsonpath='{.spec.host}')/"      # gitops v1
```

**4. O ciclo GitOps** (`VERIFICADO`): altere `MESSAGE` em `deployment.yaml` no repositório (`gitops v1` → `gitops v2`), faça `git commit` e `git push`. O Argo CD consulta o Git a cada **~3 min** (padrão; sem *webhook*): 32 s depois do push o app ainda respondia `gitops v1`. Para não esperar, peça um *refresh*; em ~10 s o `curl` passou a responder `gitops v2`:

```bash
oc annotate application gitops-demo -n ex288-v3-gitops argocd.argoproj.io/refresh=normal --overwrite
curl -sf --retry 6 --retry-delay 2 "http://$(oc get route gitops-demo -n ex288-v3-gitops -o jsonpath='{.spec.host}')/"      # gitops v2
```

`selfHeal`: `oc patch deployment gitops-demo -n ex288-v3-gitops -p '{"spec":{"replicas":3}}'` voltou a `1` réplica em ~4 s, revertido pelo Argo CD. Para um pipeline sincronizar o Argo CD, o Operator de Pipelines já traz a Task `argocd-task-sync-and-wait` (existe; não executada aqui).

Remover (feito no teste): `oc delete project ex288-v3-gitops` e o repositório no Gitea (`DELETE /api/v1/repos/ex288/gitops-demo`, HTTP 204, com a mesma credencial do passo 1).

## R10 — Verificação final

```bash
bash scripts/checar-ambiente.sh      # WSL, ferramentas, rede, podman, kubeconfig
bash scripts/checar-infra.sh         # cluster: Operators, Gitea, Nexus, registry, GitOps (somente leitura)
```

`checar-infra.sh` confere, como `developer`: CSV do Pipelines e do GitOps; Tasks `git-clone`/`buildah`/`openshift-client`; Gitea (healthz, autenticação, 5 repositórios **privados**, branch `dev`, acesso anônimo recusado); Nexus (status, EULA aceito, 8 repositórios, charts 0.1.0 e 0.2.0, artefato raw, JAR, anônimo `helm-hosted` 401 e `npm-public` 200); registry (`/v2/`); projetos presos em `Terminating`. Os itens do GitOps são opcionais (`WARN`). Seu estado hoje: **31 PASS / 1 WARN (projeto `ex288-v3-gitops` ainda não criado) / 0 FAIL**.

**Smoke do Tekton** (cria e remove um projeto descartável sem mexer no seu projeto corrente):

```bash
oc new-project ex288-v3-smoke --skip-config-write
oc apply -n ex288-v3-smoke -f apps/pipeline/pipeline-mini.yaml
for i in $(seq 1 30); do oc get sa pipeline -n ex288-v3-smoke >/dev/null 2>&1 && break; sleep 2; done      # o Operator cria a SA 'pipeline' alguns segundos depois do projeto
cat <<'EOF' | oc create -n ex288-v3-smoke -f -
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata: {generateName: mini-ci-run-}
spec:
  pipelineRef: {name: mini-ci}
  taskRunTemplate: {serviceAccountName: pipeline}
EOF
for i in $(seq 1 36); do
  r="$(oc get pipelinerun -n ex288-v3-smoke -o jsonpath='{.items[0].status.conditions[0].reason}' 2>/dev/null)"
  case "$r" in Succeeded|Failed|CouldntGetTask|PipelineRunTimeout) break ;; esac ; sleep 5
done ; echo "mini-ci: ${r:-sem resultado}"                                  # Succeeded
oc delete project ex288-v3-smoke
```

`VERIFICADO` hoje, extraindo este bloco: `mini-ci: Succeeded` e o projeto removido. O fluxo normal do material (`preparar-0N.sh` → resolver → `validar-0N.sh`) já foi validado task a task (veja cada `solucao.md`); aqui só se confirma a infraestrutura.

## R11 — Operação: parar, religar, recuperar, limpar

| Quero | Faça | Nota |
|---|---|---|
| Parar o dia | `crc stop` (PowerShell) | libera RAM/CPU do Windows |
| Religar | `crc start`, `crc status`, `oc whoami` | os pods voltam sozinhos; confira com `checar-infra.sh` |
| Gitea/Nexus vazios depois de um despejo | `bash scripts/infra-up.sh` | refaz usuário, repositórios e conteúdo (EULA já aceito não pergunta de novo) |
| Zerar só os exercícios | `bash scripts/limpar-tudo-v3.sh` | lista, pede confirmação; a infra só sai com `--infra` |
| Zerar um simulado | `bash scripts/simulado-limpar.sh A` (ou `B`) | depois, `simulado-preparar.sh` |
| Liberar disco | apagar projetos de exercícios; no WSL, `podman system prune`; imagens e builds antigos do cluster: prune com admin (`oc adm prune`, `NÃO VERIFICADO` aqui) | o disco da VM só cresce; hoje: 78 de 136,8 GB usados |
| Mais recursos | `crc stop` → `crc config set cpus/memory/disk-size` → `crc start` | disco só cresce |
| **Recomeçar do zero** | `crc delete` (apaga o cluster e todos os dados) e volte à R1 | destrutivo: só se for o que você quer |

Regras do material: nenhum script mexe fora de `ex288-v3-*`; nenhum grava senha, token ou kubeconfig no repositório.

## R12 — Diagnóstico: sintoma → causa → correção

| Sintoma | Causa | Correção |
|---|---|---|
| `curl`/`oc` no WSL: HTTP 000 ou "no such host" para `api.crc.testing` | WSL em NAT (loopback diferente) | R2: `networkingMode=mirrored` + `wsl --shutdown` |
| Pods despejados, nó com `DiskPressure`, `taint disk-pressure` | CRC com o disco/RAM padrão | R1: ampliar (`disk-size` só cresce); depois `infra-up.sh` |
| `infra-up.sh`/`preparar-0N.sh` falham ou o projeto "não existe" para o `developer` | projeto criado pelo `kubeadmin` | recriar como `developer` (R4) |
| `oc new-app <url-git>` aborta com `could not read Username` | o `oc` **clona no cliente**; falta credencial no `git` do WSL | `git config --global credential.helper 'cache --timeout=3600'` e um `git ls-remote` com a senha |
| Upload ao Nexus / pacotes npm: HTTP 403 | EULA da edição Community não aceito | R7: `NEXUS_ACCEPT_EULA=yes bash scripts/infra-up.sh` |
| Tekton `buildah`: `trying to reuse blob … authentication required` | `IMAGE` aponta para outro namespace; a SA `pipeline` só publica no próprio projeto | use `…:5000/<projeto atual>/<imagem>:<tag>` |
| Projeto recriado logo depois de apagado não aceita objetos | projeto em `Terminating` por ~30 s | esperar (o `new_project` do lab já espera) |
| `error: you do not have rights to view project "X" specified in your config` | o contexto corrente aponta para um projeto que foi apagado (acontece com `oc new-project` + `oc delete project`) | `oc project <existente>`; nos scripts use `--skip-config-write` ou `-n` |
| Rota recém-criada responde "Application is not available" (HTTP 503) | o roteador demora alguns segundos depois do `rollout` | `curl -sf --retry 6 --retry-delay 2 …` |
| PipelineRun: `PodCreationFailed … serviceaccounts "pipeline" not found` | o Operator cria a SA `pipeline` alguns segundos depois do projeto | esperar a SA existir antes do PipelineRun (`oc get sa pipeline`), ou recriar o PipelineRun |
| API do Gitea devolve HTTP 500 (com `PANIC … nil pointer` no corpo) logo depois de um `git push` num repositório novo | o Gitea ainda está registrando o push; some em ~3 s (`VERIFICADO`: 500 em t=0, 200 em t≈3 s) | esperar e repetir; o `git` sobre HTTP (clone, Argo CD) não depende disso |
| Eventos `Warning InternalError … expected imageID to be separable by @` em PipelineRun/TaskRun | ruído do Tekton Chains (assinatura) em imagens sem digest; o PipelineRun segue normalmente | ignorar (`VERIFICADO`: a execução termina `Succeeded`) |
| `Forbidden` em `packagemanifest`, `nodes`, `subscription`, `argocds -A` | o `developer` não é admin | usar `$KA` (kubeadmin) só para isso |
| Chrome/Edge abre uma aba de login do Gitea ao rodar `git` no Windows | Git Credential Manager do Git for Windows | `git -c credential.helper= …` (os scripts do lab já fazem) |
| `ImagePullBackOff` com `toomanyrequests` ao subir Gitea/Nexus | as imagens vêm do Docker Hub, sem login | `HIPÓTESE` (não observado aqui): espere o limite zerar ou autentique o pull |

Origem: as linhas sem marcação foram observadas neste PC e estão no [relatório final](../_meta/RELATORIO-FINAL.md); o 503 e o contexto apagado foram vistos em 2026-11-02 e 2026-11-08.
