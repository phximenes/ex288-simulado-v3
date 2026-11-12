[índice](../README.md) | [próximo: estratégia de prova →](estrategia-de-prova.md)

# Pré-requisitos — preparar o WSL RHEL 10.2 e o CRC (você executa)

> Por decisão sua (regra 9), **eu não alterei nada** no WSL, no Windows nem no CRC. Este arquivo é a lista do que **você** deve fazer, na ordem. Cada passo tem o motivo, o comando e como conferir. `VERIFICADO` = consultei no seu ambiente em 2026-10-31; `NÃO VERIFICADO` = comando que eu não executei. No fim, `bash scripts/checar-ambiente.sh` confere tudo com PASS/FAIL. Para montar o **cluster** do zero (CRC, Pipelines, GitOps, Gitea, Nexus) numa ordem só, veja o [cookbook da infraestrutura](cookbook-infra.md).

## Estado encontrado (VERIFICADO, só leitura)

| Item | Hoje |
|---|---|
| WSL | 3.0.3.0; distro `RedHatEnterpriseLinux-10.2` (RHEL 10.2, kernel 6.18.54.1), usuário `phximenes` com `sudo` sem senha, systemd ativo |
| Rede do WSL | **NAT** (sem `.wslconfig`): os nomes `*.crc.testing` resolvem para `127.0.0.1`, mas esse é o loopback do WSL e não o do Windows → `curl` para a API/console/registry dá HTTP 000 |
| Disco | **só `C:` montado**; não existe `/mnt/d` |
| Ferramentas | presentes: `git` 2.52, `curl`, `openssl`, `helm` 3.22.1, `kubectl` 1.36.1, `python3` 3.12, `docker` 29.9.2 (Docker Desktop). **Ausentes:** `oc`, `podman`, `skopeo`, `jq`, `tkn`, `vim-enhanced` |
| Repositórios | `rhel-10-for-x86_64-baseos-rpms` e `…appstream-rpms` ativos; `dnf` oferece `podman` 5.8.2, `skopeo` 1.22.2, `jq` 1.7.1, `vim-enhanced` 9.1, `bash-completion` 2.11. `ShellCheck`, `yamllint` e `yq` **não** estão nesses repos |
| CRC | 2.64.0 / OpenShift 4.22.14, configuração **padrão** (4 CPUs, ~11 GB de RAM, disco 32,68 GB) |

> [!WARNING]
> **Capacidade do CRC (decisão D1 = "deixar como está").** No estado atual o nó entra em `DiskPressure` quando um pod grande é agendado (disco da VM com ~85% de uso) e ~93% da memória já está *requisitada*. Medi isso ao tentar subir o Gitea e o Nexus: o kubelet despeja os pods. Com essa configuração o lab não roda; veja o [passo 13](#13-capacidade-do-crc-decisao-pendente).

## 1. Montar o `D:` no WSL — para ler/rodar o material em `/mnt/d` (`NÃO VERIFICADO`)

```bash
sudo mkdir -p /mnt/d && sudo mount -t drvfs D: /mnt/d
echo 'D: /mnt/d drvfs defaults 0 0' | sudo tee -a /etc/fstab     # persistir
ls "/mnt/d/src/Red Hat Certified OpenShift Application Development (EX288)/v3"
```

Sempre use aspas no caminho (tem espaços e parênteses). Rode os scripts com `bash scripts/x.sh` (o bit de execução pode não persistir em `/mnt/d`). Alternativa mais rápida: copie para o ext4 (`cp -a "/mnt/d/…/v3" ~/v3`).

## 2. Fazer o WSL alcançar o CRC: rede `mirrored` (`NÃO VERIFICADO`)

No PowerShell do Windows (cria um arquivo novo; **derruba todas as distros e o Docker Desktop**):

```powershell
Set-Content -Path "$env:USERPROFILE\.wslconfig" -Value "[wsl2]`nnetworkingMode=mirrored"
wsl --shutdown
```

Depois, no WSL, confira:

```bash
curl -sk -o /dev/null -w '%{http_code}\n' https://api.crc.testing:6443/version     # esperado: 200
curl -sk -o /dev/null -w '%{http_code}\n' https://console-openshift-console.apps-crc.testing/   # 200 ou 302
```

Se após o `mirrored` os nomes deixarem de resolver, edite `/etc/wsl.conf` para `[network]` + `generateHosts = false` e copie para `/etc/hosts` a linha `127.0.0.1 api.crc.testing …` da seção "Added by CRC" do arquivo hosts do Windows (foi o que o v2 precisou fazer). Para desfazer: apague `.wslconfig` e rode `wsl --shutdown`.

## 3. Resolver as rotas do lab (Git e Nexus)

`VERIFICADO` em 2026-11-08 (**corrige** a versão anterior deste passo, que dizia "rotas novas não resolvem"): com o `mirrored`, o **próprio CRC** mantém o bloco `# Added by CRC` do `hosts` do Windows, **incluindo as rotas novas e removendo as apagadas** em poucos segundos, e o WSL resolve pelo Windows. Criei uma rota num projeto descartável: resolveu no WSL em ~0 s e a linha sumiu do `hosts` quando o projeto foi removido. A conclusão antiga vinha de um teste com um nome de rota que não existia.

Normalmente **não há nada a fazer**. O `oc new-app <url-git>` clona no cliente, então a rota do Gitea precisa resolver no WSL; confira:

```bash
getent hosts gitea-ex288-v3-infra.apps-crc.testing        # 127.0.0.1
```

Plano B, só se o nome **não** resolver (por exemplo, `crc` parado ou WSL em NAT) — `NÃO VERIFICADO` como necessidade:

```bash
bash scripts/hosts-sync.sh | sudo tee -a /etc/hosts      # imprime as linhas das rotas ex288-v3-*; revise antes de aplicar
```

(Os validadores do lab usam `curl --resolve`, então não dependem disso; `oc new-app`, `git`, `helm` e `podman` dependem.)

## 4. Assinatura e repositórios (`NÃO VERIFICADO`; os repos já aparecem ativos)

```bash
sudo subscription-manager status
sudo subscription-manager register --username SEU_LOGIN_REDHAT     # só se "Not registered" (Developer Subscription)
sudo dnf repolist
```

## 5. Pacotes do RHEL e utilitários de lint (`VERIFICADO` que existem nos repos)

```bash
sudo dnf install -y podman skopeo jq vim-enhanced bash-completion
python3 -m venv ~/.venvs/lint && ~/.venvs/lint/bin/pip install yamllint shellcheck-py    # opcional, para validar o material
echo 'export PATH="$HOME/.venvs/lint/bin:$HOME/.local/bin:$PATH"' >> ~/.bashrc
```

`yq` é opcional (fora dos repos RHEL; binário do projeto `mikefarah/yq` no GitHub com checksum — `NÃO VERIFICADO`).

## 6. `oc` na versão do cluster, com checksum (URLs `VERIFICADO`: HTTP 200)

```bash
mkdir -p ~/.local/bin && cd /tmp
curl -LO https://mirror.openshift.com/pub/openshift-v4/clients/ocp/4.22.14/openshift-client-linux.tar.gz
curl -L  https://mirror.openshift.com/pub/openshift-v4/clients/ocp/4.22.14/sha256sum.txt | grep ' openshift-client-linux.tar.gz$' | sha256sum -c -
tar -xzf openshift-client-linux.tar.gz -C ~/.local/bin oc kubectl
oc version --client        # Client Version: 4.22.14
```

Alternativa (do próprio cluster, `VERIFICADO` HTTP 200): `curl -kLO https://downloads-openshift-console.apps-crc.testing/amd64/linux/oc.tar`.

## 7. `helm`

Há `helm` 3.22.1 no WSL. O cluster publica o `helm` que ele "recomenda": `oc get consoleclidownload helm-download-links -o jsonpath='{range .spec.links[*]}{.text} {.href}{"\n"}{end}'` (links no console, `VERIFICADO` que o recurso existe). O build da Red Hat está em `https://mirror.openshift.com/pub/openshift-v4/clients/helm/latest/` (hoje 3.17.4.2-61, com `sha256sum.txt`). A versão que a prova entrega é `NÃO VERIFICADO`; os comandos do v3 valem para helm 3.x (e 4.x, ver T7).

## 8. Login e kubeconfig no lugar certo

```bash
mkdir -p ~/.kube && chmod 700 ~/.kube          # o kubeconfig fica em ~/.kube (ext4), nunca em /mnt/d
crc.exe console --credentials                   # no terminal do WSL; mostra as senhas só na tela, não copie para arquivo
oc login -u developer https://api.crc.testing:6443 --insecure-skip-tls-verify=true
```

Use `kubeadmin` **só** para o passo 12 (e volte para `developer` em seguida). **Rode `infra-up.sh` e todos os `preparar-0N.sh` logado como `developer`**: quem cria o projeto é dono dele; um projeto criado pelo `kubeadmin` não é visível ao `developer` (`VERIFICADO` ao testar). Nunca grave senha em arquivo do material.

## 9. Confiar na CA do CRC para o `podman` no registry interno (`VERIFICADO` no seu WSL)

Trade-off: `--tls-verify=false` é rápido, mas desliga a verificação (aceitável no lab, **não** em produção). Para confiar só nesse registry:

```bash
H=default-route-openshift-image-registry.apps-crc.testing
oc get cm default-ingress-cert -n openshift-config-managed -o jsonpath='{.data.ca-bundle\.crt}' > /tmp/crc-ca.crt   # requer admin
sudo mkdir -p /etc/containers/certs.d/$H && sudo cp /tmp/crc-ca.crt /etc/containers/certs.d/$H/ca.crt
podman login -u developer -p "$(oc whoami -t)" $H
```

Sem admin: `podman login --tls-verify=false -u developer -p "$(oc whoami -t)" $H`. Conferido em 2026-11-01 no seu WSL: com `/etc/containers/certs.d/$H/ca.crt` instalado, `podman login`/`push` funcionam **sem** `--tls-verify=false` (o `openssl s_client` continua dizendo `self-signed certificate in certificate chain`, porque o trust do sistema não foi alterado — só o do `podman`). O host do registry, para o `developer`, vem de `oc registry info --public`.

## 10. `podman` rootless (build e push da T2)

```bash
podman info --format '{{.Host.Security.Rootless}}'                  # true
grep "^$USER:" /etc/subuid /etc/subgid                              # VERIFICADO: phximenes:524288:65536
podman run --rm registry.access.redhat.com/ubi9/ubi-minimal echo ok
```

## 11. Completion e `~/.vimrc` (o que você terá na prova)

```bash
oc completion bash | sudo tee /etc/bash_completion.d/oc >/dev/null
helm completion bash | sudo tee /etc/bash_completion.d/helm >/dev/null
cat > ~/.vimrc <<'EOF'
syntax on
set ts=2 sw=2 et ai
set cursorcolumn
autocmd FileType yaml setlocal ts=2 sw=2 et ai indentkeys-=0#
EOF
```

## 12. Pipelines Operator no CRC (T8) — você executa como `kubeadmin`

O Operator é de cluster (`openshift-operators`, fora de `ex288-v3-*`), por isso não instalei. Canal `latest` = `openshift-pipelines-operator-rh.v1.24.3` (`VERIFICADO` com `oc get packagemanifest`); modo de instalação: **AllNamespaces**.

```bash
oc login -u kubeadmin https://api.crc.testing:6443          # senha: crc.exe console --credentials
oc apply -f apps/pipeline/operator-subscription.yaml
oc get csv -n openshift-operators -w                         # espere openshift-pipelines-operator-rh.* = Succeeded
oc get crd | grep tekton.dev
oc get task -n openshift-pipelines                           # git-clone, buildah, openshift-client...
oc login -u developer https://api.crc.testing:6443
```

Depois instale o `tkn` (opcional; o v3 funciona sem ele): `https://mirror.openshift.com/pub/openshift-v4/clients/pipelines/latest/tkn-linux-amd64.tar.gz` (diretório `VERIFICADO`; confira o `sha256sum.txt` ao lado). O Operator consome memória e disco: veja o passo 13.

## 13. Capacidade do CRC (**feito por você em 2026-10-31; `VERIFICADO`**)

Na configuração padrão o nó entra em `DiskPressure` ao agendar pods grandes (medido). Você ampliou o CRC; conferi depois: `cpus 6`, `memory 16384`, `disk-size 64` em `crc config view`, VM com **68,11 GB** (28,36 usados, 42%), 16,76 GB de RAM, sem taint. **Resolvido o `NÃO VERIFICADO`:** o `disk-size` **cresce numa VM existente** com `crc stop`/`crc config set`/`crc start` (sem `crc delete`). Os comandos que você usou (referência):

```powershell
crc stop
crc config set cpus 6
crc config set memory 16384
crc config set disk-size 64        # só cresce; se o `crc start` não aplicar a um cluster existente, a alternativa é recriar (crc delete — destrói o cluster)
crc start
```

(Perfil que o v2 usou: 8 CPUs / 14 GiB / 64 GiB; o v3 foi validado com 6 / 16 GiB / 64 GiB.) A alternativa "rodar Gitea e Nexus fora do cluster" **não foi necessária** e ficou como `HIPÓTESE` não testada.

## 14. EULA do Nexus Community — decisão sua (`VERIFICADO` que é exigido)

O Nexus Repository **Community Edition** (imagem `sonatype/nexus3:3.96.5-ubi`) devolve **HTTP 403** em uploads e no download de pacotes via proxy até que o EULA seja aceito (a resposta cita o EULA e o endpoint `GET /service/rest/v1/system/eula` mostra `"accepted": false`). **Eu não aceitei por você.** Leia <https://links.sonatype.com/products/nxrm/ce-eula> e, se concordar, aceite de uma das formas:

```bash
NEXUS_ACCEPT_EULA=yes bash scripts/infra-up.sh      # o script faz o POST do aceite e carrega charts/artefatos
```

ou pelo wizard da interface web do Nexus. Limites de uso da edição Community: `NÃO VERIFICADO`.

## Conferir tudo

```bash
bash scripts/checar-ambiente.sh
```
