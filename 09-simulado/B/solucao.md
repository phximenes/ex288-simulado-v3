[← enunciado B](enunciado.md) | [simulado](../README.md)

# Simulado B — solução (resumo)

> **Status:** T1–T7 `VALIDADO NO CLUSTER`: `simulado-preparar.sh B` → corretor `0/84` → comandos abaixo → corretor **`84/84 (100%)`** (CRC 4.22.14, builds e Nexus reais). **T8 `VALIDADO NO CLUSTER`** (Pipelines Operator 1.24.3): `16/16` em rodada separada. Reaproveita as soluções das pastas 01–08. **T2, T6 e T8 estão escritos por completo** (blocos extraídos deste arquivo e executados literalmente em projeto descartável, com as funções do corretor). Dica verificada: no T2 o `legacy` precisa de **dois** builds extras (o 1º `oc new-app` usa o `Dockerfile` padrão; depois `dockerfilePath` + correção + novo build).

## Antes de começar (T1, T2, T3 e T8): credenciais e o Secret `git-creds`

```bash
bash scripts/credenciais.sh --show            # URL do Git, usuário e senha (do Git e do Nexus)
GIT_USER=<usuario> ; GIT_PASS=<senha>         # só no terminal; não grave em arquivo
GIT=http://<host-do-git>/ex288 ; NEXUS=http://<host-do-nexus> ; NEXUS_PASS=<senha-do-nexus>
```

**1. O Secret `git-creds`.** O `simulado-preparar.sh` já o criou nos projetos T1, T2, T3 e T8 (por isso o enunciado diz que "já existe"). Se faltar, ou se você quiser refazê-lo como faria na prova, é um Secret `basic-auth` com usuário e senha do Git:

```bash
oc create secret generic git-creds --type=kubernetes.io/basic-auth \
  --from-literal=username="$GIT_USER" --from-literal=password="$GIT_PASS" -n ex288-v3-sb-t1   # idem para ...-sb-t2 e ...-sb-t3
oc get secret git-creds -n ex288-v3-sb-t1 -o jsonpath='{.type}'                              # kubernetes.io/basic-auth
```

Ele só serve ao **build** (o pod de build clona de novo com ele, via `--source-secret git-creds` ou `oc set build-secret --source bc/NOME git-creds`). Na T8 o Tekton usa outro Secret, `git-basic-auth`, com a anotação `tekton.dev/git-0` (veja a [solução da T8](../../08-cicd-pipelines/solucao.md)).

**2. A credencial no seu cliente `git`.** O `oc new-app`/`new-build` **clona o repositório na sua máquina** antes de criar o BuildConfig, e o Secret não vale para isso. Autentique o `git` do WSL uma vez (a senha fica só em memória):

```bash
git config --global credential.helper 'cache --timeout=3600'
git ls-remote "$GIT/webapp.git"               # digite usuário e senha uma vez; depois não pede mais
```

`VERIFICADO` no seu WSL: sem credencial, o `git ls-remote` falha (rc 128); com o helper `cache` e a credencial digitada uma vez, o `oc new-app` do T1 abaixo criou o BuildConfig com `sourceSecret: git-creds` e `ref: dev`, e o build terminou `Complete`. O cache dura 3600 s: se o `oc new-app` voltar a falhar em um repositório privado depois de uma hora, repita o `git ls-remote`.

**T1** (`-n ex288-v3-sb-t1`)
```bash
oc new-app --name gateway --source-secret git-creds --context-dir api -l tier=edge -e APP_MESSAGE=sim-b --image-stream openshift/nodejs:22-ubi9 --code "$GIT/monorepo.git"
oc new-app --name static  --source-secret git-creds --context-dir site "openshift/httpd:2.4-ubi9~$GIT/monorepo.git"      # so index.html: precisa de builder~URL
oc expose service gateway ; oc expose service static ; oc create route edge static-tls --service=static --insecure-policy=Redirect
```
**T2** (`-n ex288-v3-sb-t2`) — `legacy` e `ledger`; o raciocínio do `Dockerfile.root` está em [T2 E3](../../02-deploy-from-dockerfile/solucao.md) e o do build binário em [T2 E4](../../02-deploy-from-dockerfile/solucao.md). O corretor exige ≥ 2 builds do `legacy` (o 1º, do `oc new-app`, usa o `Dockerfile` padrão e funciona; o 2º vem depois do `dockerfilePath` + correção).
```bash
# 1 e 2) legacy: BuildConfig no Dockerfile.root + ARG do Nexus; corrigir o Dockerfile no Git; novo build
oc new-app --name legacy --source-secret git-creds --strategy docker --code "$GIT/webapp-docker.git"
oc patch bc/legacy -p '{"spec":{"strategy":{"dockerStrategy":{"dockerfilePath":"Dockerfile.root","buildArgs":[{"name":"NPM_REGISTRY","value":"'"$NEXUS"'/repository/npm-public/"}]}}}}'
oc expose service legacy
git clone "$GIT/webapp-docker.git" wd
cat > wd/Dockerfile.root <<'EOF'
FROM registry.access.redhat.com/ubi9/nodejs-22-minimal:latest
ARG NPM_REGISTRY=https://registry.npmjs.org/
USER 0
WORKDIR /app
COPY package.json server.js ./
RUN mkdir -p /app/data && npm config set registry "${NPM_REGISTRY}" && npm install --omit=dev && chgrp -R 0 /app && chmod -R g=u /app
ENV DATA_DIR=/app/data
EXPOSE 8080
USER 1001
CMD ["node", "server.js"]
EOF
( cd wd && git -c user.name=aluno -c user.email=aluno@example.invalid commit -qam "Dockerfile.root: UID arbitrario e ARG do Nexus" && git push -q origin main )
oc start-build legacy --follow
oc rollout status deployment/legacy
curl -sf --retry 6 --retry-delay 2 "http://$(oc get route legacy -o jsonpath='{.spec.host}')/"       # "app":"webapp-docker" ... "dataDir":"/app/data"
# 3) ledger: build binario com o artefato do Nexus (raw-hosted)
mkdir ledger-src
curl -fsu "admin:$NEXUS_PASS" "$NEXUS/repository/raw-hosted/ex288/site-1.0.tar.gz" | tar xz -C ledger-src          # deixa index.html
printf 'FROM registry.access.redhat.com/ubi9/httpd-24\nCOPY index.html /var/www/html/\n' > ledger-src/Dockerfile
oc new-build --binary --strategy docker --name ledger
oc start-build ledger --from-dir=ledger-src --follow
oc new-app --image-stream ledger:latest --name ledger ; oc expose service ledger
oc rollout status deployment/ledger
curl -sf --retry 6 --retry-delay 2 "http://$(oc get route ledger -o jsonpath='{.spec.host}')/"       # site 1.0
```
**T3** (`reports` já existe com `npm_config_registry=http://127.0.0.1:9/`)
```bash
oc set env bc/reports npm_config_registry="$NEXUS/repository/npm-public/"
oc set env deployment/reports APP_MESSAGE=reports-b
oc start-build reports --follow ; oc expose service reports
```
**T4**
```bash
oc create configmap shop-cfg --from-literal=GREETING=SimB --from-literal=LANG_CODE=en-US ; oc set env deployment/cfgapp --from=configmap/shop-cfg
oc patch deployment/cfgapp --type=json -p '[{"op":"add","path":"/spec/template/spec/containers/0/env/-","value":{"name":"DB_USER","valueFrom":{"secretKeyRef":{"name":"shop-db","key":"u"}}}},{"op":"add","path":"/spec/template/spec/containers/0/env/-","value":{"name":"DB_PASSWORD","valueFrom":{"secretKeyRef":{"name":"shop-db","key":"p"}}}}]'
V=$(oc get secret shop-token -n ex288-v3-sb-t4-shared -o jsonpath='{.data.value}' | base64 -d)
oc create secret generic shop-token --from-literal=value="$V" ; unset V
```
Para `API_TOKEN` a partir da chave `value` use `valueFrom` (`oc set env --from=secret/… --prefix=API_` geraria `API_VALUE`, e `oc set env` não tem `--keys`):
```bash
oc patch deployment/cfgapp --type=json -p '[{"op":"add","path":"/spec/template/spec/containers/0/env/-","value":{"name":"API_TOKEN","valueFrom":{"secretKeyRef":{"name":"shop-token","key":"value"}}}}]'
```
**T5**
```bash
oc set probe deployment/slowapp --startup --open-tcp=8080 --period-seconds=3 --failure-threshold=12
oc set probe deployment/slowapp --readiness --open-tcp=8080 --period-seconds=5
oc set probe deployment/slowapp --liveness --period-seconds=10 -- cat /proc/1/cmdline
oc set probe deployment/slowbad --startup --get-url=http://:8080/healthz --period-seconds=5 --failure-threshold=12
```
**T6** (`-n ex288-v3-sb-t6`) — o template é escrito do zero; o corretor lê o objeto `Template` **`stack`** no projeto (`oc create -f`), os parâmetros `NAME`/`MESSAGE`/`TOKEN`, a chave **`token`** do Secret `${NAME}-token` e as rotas.
```bash
cat > stack.yaml <<'EOF'
apiVersion: template.openshift.io/v1
kind: Template
metadata:
  name: stack
parameters:
  - {name: NAME, description: Nome da instancia, required: true}
  - {name: MESSAGE, description: Mensagem devolvida pela app, value: hello}
  - {name: TOKEN, description: Token gerado, generate: expression, from: "[a-zA-Z0-9]{12}"}
objects:
  - apiVersion: v1
    kind: Secret
    metadata: {name: "${NAME}-token"}
    stringData: {token: "${TOKEN}"}
  - apiVersion: apps/v1
    kind: Deployment
    metadata: {name: "${NAME}"}
    spec:
      replicas: 1
      selector: {matchLabels: {app: "${NAME}"}}
      template:
        metadata: {labels: {app: "${NAME}"}}
        spec:
          containers:
            - name: app
              image: registry.access.redhat.com/ubi9/nodejs-22-minimal:latest
              env:
                - {name: MESSAGE, value: "${MESSAGE}"}
                - name: TOKEN
                  valueFrom: {secretKeyRef: {name: "${NAME}-token", key: token}}
              command: ["node", "-e"]
              args: ["require('http').createServer((q,s)=>s.end(process.env.MESSAGE+'\\n')).listen(8080)"]
              ports: [{containerPort: 8080}]
  - {apiVersion: v1, kind: Service, metadata: {name: "${NAME}"}, spec: {selector: {app: "${NAME}"}, ports: [{port: 8080, targetPort: 8080}]}}
  - {apiVersion: route.openshift.io/v1, kind: Route, metadata: {name: "${NAME}"}, spec: {to: {kind: Service, name: "${NAME}"}}}
EOF
oc create -f stack.yaml ; oc process --parameters stack          # NAME obrigatorio, MESSAGE com padrao, TOKEN gerado
oc new-app --template=stack -p NAME=stack-a
oc new-app --template=stack -p NAME=stack-b -p MESSAGE=bravo
oc rollout status deployment/stack-a ; oc rollout status deployment/stack-b
oc get secret stack-a-token -o jsonpath='{.data.token}' | base64 -d | wc -c            # 12
for n in stack-a stack-b; do curl -sf --retry 6 --retry-delay 2 "http://$(oc get route $n -o jsonpath='{.spec.host}')/"; done      # hello / bravo (o --retry cobre os segundos em que o router ainda devolve 503)
```
**T7**
```bash
helm package apps/helm/ex288-hello
printf 'replicaCount: 2\nmessage: prod-b\n' > values.yaml
helm install inventory ./ex288-hello-0.1.0.tgz -f values.yaml -n ex288-v3-sb-t7
helm upgrade inventory ./ex288-hello-0.1.0.tgz -f values.yaml --set message=prod-b2 -n ex288-v3-sb-t7
helm rollback inventory 1 -n ex288-v3-sb-t7        # revisao 3, mensagem prod-b
```
**T8** (`-n ex288-v3-sb-t8`; execute a partir da raiz do material, onde está `apps/`) — os nomes do enunciado são exatos: `broken-ci`, `sim-ci`, `native`. Os mecanismos estão em [08-cicd-pipelines/solucao.md](../../08-cicd-pipelines/solucao.md) (E3 e E4).
```bash
# 1) broken-ci: o arquivo do material NAO e aplicado (o webhook rejeita o runAfter "writ"); corrija os 2 defeitos e aplique
oc apply -f apps/pipeline/pipeline-broken.yaml          # Error ... task read depends on writ but writ wasn't present in Pipeline
sed -e 's/runAfter: \["writ"\]/runAfter: ["write"]/' -e 's/name: dados/name: data/' -e 's/workspaces\.dados\.path/workspaces.data.path/' \
  apps/pipeline/pipeline-broken.yaml | oc apply -f -
cat <<'EOF' | oc create -f -
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata: {generateName: broken-ci-run-}
spec:
  pipelineRef: {name: broken-ci}
  taskRunTemplate: {serviceAccountName: pipeline}
  workspaces:
    - name: shared
      volumeClaimTemplate:
        spec: {accessModes: [ReadWriteOnce], resources: {requests: {storage: 1Gi}}}
EOF
# 2) sim-ci: 2 tasks encadeadas por runAfter, taskSpec embutido
cat <<'EOF' | oc create -f -
apiVersion: tekton.dev/v1
kind: Pipeline
metadata: {name: sim-ci}
spec:
  tasks:
    - name: a
      taskSpec: {steps: [{name: s, image: "registry.access.redhat.com/ubi9/ubi-minimal:latest", script: "echo a"}]}
    - name: b
      runAfter: ["a"]
      taskSpec: {steps: [{name: s, image: "registry.access.redhat.com/ubi9/ubi-minimal:latest", script: "echo b"}]}
EOF
cat <<'EOF' | oc create -f -
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata: {generateName: sim-ci-run-}
spec:
  pipelineRef: {name: sim-ci}
  taskRunTemplate: {serviceAccountName: pipeline}
EOF
# 3) native: BuildConfig S2I com Generic + ImageChange + post-commit hook
oc new-app --name native --source-secret git-creds --image-stream openshift/nodejs:22-ubi9 --code "$GIT/webapp.git"
oc set triggers bc/native --from-webhook
oc set triggers bc/native --from-image=nodejs:22-ubi9
oc set build-hook bc/native --post-commit --script='npm test'
oc get pipelinerun                                                                  # broken-ci-run-* e sim-ci-run-*: Succeeded
oc get bc native -o jsonpath='{.spec.triggers[*].type}{"\n"}{.spec.postCommit}{"\n"}'     # ... Generic ... ImageChange ...  {"script":"npm test"}
```
