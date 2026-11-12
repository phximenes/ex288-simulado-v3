[← enunciado A](enunciado.md) | [simulado](../README.md)

# Simulado A — solução (resumo)

> **Status:** T1–T7 `VALIDADO NO CLUSTER`: `simulado-preparar.sh A` → corretor `0/84` → comandos abaixo → corretor **`84/84 (100%)`** (CRC 4.22.14, builds e Nexus reais). **T8 `VALIDADO NO CLUSTER`** (Pipelines Operator 1.24.3): `16/16` em rodada separada. Cada item reaproveita uma solução das pastas 01–08; os nomes são os do enunciado. Detalhe: o `oc new-app` do T2 só cria o Deployment `shop` **depois** que o build `shop:2.0` terminar (a ImageStreamTag precisa existir).

## Antes de começar (T1, T2, T3 e T8): credenciais e o Secret `git-creds`

```bash
bash scripts/credenciais.sh --show            # URL do Git, usuário e senha (do Git e do Nexus)
GIT_USER=<usuario> ; GIT_PASS=<senha>         # só no terminal; não grave em arquivo
GIT=http://<host-do-git>/ex288 ; NEXUS=http://<host-do-nexus> ; NEXUS_PASS=<senha-do-nexus>
```

**1. O Secret `git-creds`.** O `simulado-preparar.sh` já o criou nos projetos T1, T2, T3 e T8 (por isso o enunciado diz que "já existe"). Se faltar, ou se você quiser refazê-lo como faria na prova, é um Secret `basic-auth` com usuário e senha do Git:

```bash
oc create secret generic git-creds --type=kubernetes.io/basic-auth \
  --from-literal=username="$GIT_USER" --from-literal=password="$GIT_PASS" -n ex288-v3-sa-t1   # idem para ...-sa-t2 e ...-sa-t3
oc get secret git-creds -n ex288-v3-sa-t1 -o jsonpath='{.type}'                              # kubernetes.io/basic-auth
```

Ele só serve ao **build** (o pod de build clona de novo com ele, via `--source-secret git-creds` ou `oc set build-secret --source bc/NOME git-creds`). Na T8 o Tekton usa outro Secret, `git-basic-auth`, com a anotação `tekton.dev/git-0` (veja a [solução da T8](../../08-cicd-pipelines/solucao.md)).

**2. A credencial no seu cliente `git`.** O `oc new-app`/`new-build` **clona o repositório na sua máquina** antes de criar o BuildConfig, e o Secret não vale para isso. Autentique o `git` do WSL uma vez (a senha fica só em memória):

```bash
git config --global credential.helper 'cache --timeout=3600'
git ls-remote "$GIT/webapp.git"               # digite usuário e senha uma vez; depois não pede mais
```

`VERIFICADO` no seu WSL: sem credencial, o `git ls-remote` falha (rc 128); com o helper `cache` e a credencial digitada uma vez, o `oc new-app` do T1 abaixo criou o BuildConfig com `sourceSecret: git-creds` e `ref: dev`, e o build terminou `Complete`. O cache dura 3600 s: se o `oc new-app` voltar a falhar em um repositório privado depois de uma hora, repita o `git ls-remote`.

**T1** (`-n ex288-v3-sa-t1`)
```bash
oc new-app --name portal --source-secret git-creds -l tier=web -e APP_MESSAGE=sim-a --image-stream openshift/nodejs:22-ubi9 --code "$GIT/webapp.git#dev"
oc expose service portal ; oc create route edge portal-tls --service=portal --insecure-policy=Redirect
```
**T2**
```bash
oc new-build --name shop --source-secret git-creds --strategy docker --code "$GIT/webapp-docker.git" --to shop:2.0 --build-arg NPM_REGISTRY="$NEXUS/repository/npm-public/"
oc new-app --image-stream shop:2.0 --name shop ; oc expose service shop
```
**T3**
```bash
oc new-app --name catalog --source-secret git-creds --image-stream openshift/nodejs:22-ubi9 --build-env npm_config_registry="$NEXUS/repository/npm-public/" -e APP_MESSAGE=catalog-a --code "$GIT/webapp-s2i.git"
oc expose service catalog
```
**T4**
```bash
oc create configmap catalog-cfg --from-literal=GREETING=SimA --from-literal=LANG_CODE=pt-BR --from-literal=API_HOST=http://catalog:8080
oc set env deployment/cfgapp --from=configmap/catalog-cfg
# DB_USER/DB_PASSWORD com nome ≠ chave: o oc set env nao renomeia. Forma mais facil de lembrar (patch em YAML, VERIFICADO):
oc patch deployment/cfgapp -p '
spec:
  template:
    spec:
      containers:
      - name: cfgapp
        env:
        - {name: DB_USER, valueFrom: {secretKeyRef: {name: catalog-db, key: login}}}
        - {name: DB_PASSWORD, valueFrom: {secretKeyRef: {name: catalog-db, key: secret}}}
'
# Alternativas sem decorar nada: `oc edit deployment/cfgapp` (cole as 2 linhas de env) ou a console web (veja 04-env-configmap-secret/solucao.md, E2)
printf 'mode=sim\n' > app.properties ; oc create configmap catalog-files --from-file=app.properties
oc set volume deployment/cfgapp --add --name=files --type=configmap --configmap-name=catalog-files --mount-path=/etc/catalog --read-only=true
```
**T5**
```bash
oc set probe deployment/slowapp --startup --get-url=http://:8080/healthz --period-seconds=5 --failure-threshold=12
oc set probe deployment/slowapp --liveness --get-url=http://:8080/healthz --period-seconds=8 --timeout-seconds=2 --failure-threshold=3
oc set probe deployment/slowapp --readiness --get-url=http://:8080/ready --period-seconds=4
oc scale deployment/slowapp --replicas=2
```
**T6**
```bash
oc create -f apps/templates/webapp-template.yaml
printf 'NAME=orders\nMESSAGE=sim-a\nREPLICAS=2\n' > p.env ; oc new-app --template=webapp-template --param-file=p.env
oc new-app --template=webapp-template -p NAME=orders-dev -p MESSAGE=dev -l env=dev
```
**T7**
```bash
helm repo add nexus "$NEXUS/repository/helm-hosted/" --username admin --password "$NEXUS_PASS" ; helm repo update
helm install inventory nexus/ex288-hello --version 0.1.0 -n ex288-v3-sa-t7
helm upgrade inventory nexus/ex288-hello --version 0.2.0 --set replicaCount=2 -n ex288-v3-sa-t7
```
**T8** (`-n ex288-v3-sa-t8`; **os nomes do enunciado são exatos**: `sim-ci`, `sim-build`, `simapp` — o corretor não reconhece `mini-ci` nem `build-and-deploy`). `VALIDADO NO CLUSTER` (16/16).
```bash
NS=ex288-v3-sa-t8
# 1) sim-ci: 3 tasks encadeadas por runAfter, taskSpec embutido, parametro TARGET
cat <<'EOF' | oc create -f -
apiVersion: tekton.dev/v1
kind: Pipeline
metadata: {name: sim-ci}
spec:
  params: [{name: TARGET, type: string, default: sim}]
  tasks:
    - name: one
      params: [{name: TARGET, value: "$(params.TARGET)"}]
      taskSpec: {steps: [{name: s, image: "registry.access.redhat.com/ubi9/ubi-minimal:latest", script: "echo one $(params.TARGET)"}]}
    - name: two
      runAfter: ["one"]
      taskSpec: {steps: [{name: s, image: "registry.access.redhat.com/ubi9/ubi-minimal:latest", script: "echo two"}]}
    - name: three
      runAfter: ["two"]
      taskSpec: {steps: [{name: s, image: "registry.access.redhat.com/ubi9/ubi-minimal:latest", script: "echo three"}]}
EOF
cat <<'EOF' | oc create -f -
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata: {generateName: sim-ci-run-}
spec:
  pipelineRef: {name: sim-ci}
  taskRunTemplate: {serviceAccountName: pipeline}
EOF
# 2) sim-build: o pipeline-ci.yaml (git-clone + buildah + deploy) com outro nome
sed 's/name: build-and-deploy/name: sim-build/' apps/pipeline/pipeline-ci.yaml | oc apply -f -
cat <<EOF | oc create -f -
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata: {generateName: sim-build-run-}
spec:
  pipelineRef: {name: sim-build}
  taskRunTemplate: {serviceAccountName: pipeline}
  params:
    - {name: GIT_URL, value: "$GIT/webapp-docker.git"}
    - {name: IMAGE, value: "image-registry.openshift-image-registry.svc:5000/$NS/simapp:latest"}   # SEU projeto (sa-t8), nome simapp
    - {name: APP_NAME, value: simapp}
  workspaces:
    - name: shared
      volumeClaimTemplate:
        spec: {accessModes: [ReadWriteOnce], resources: {requests: {storage: 1Gi}}}
EOF
oc get pipelinerun -w            # sim-ci e sim-build: Succeeded
curl -s "http://$(oc get route simapp -o jsonpath='{.spec.host}')/"      # {"app":"webapp-docker",...}
```
O `IMAGE` tem de ser do **projeto atual**: apontar para outro namespace (por exemplo `ex288-v3-t8`, do exercício) dá `authentication required` no push ([aviso na solução da T8](../../08-cicd-pipelines/solucao.md)). O item 3 (Deployment `simapp` + Route) sai da própria task `deploy` do `sim-build` (`APP_NAME=simapp`).
