[← exercícios](exercicios.md) | [índice](../README.md)

# T6 — Solução

> **Status:** E1–E3 `VALIDADO NO CLUSTER` (CRC 4.22.14, como `developer`): antes `0 PASS / 3 FAIL`, depois **`3 PASS / 0 FAIL`** (token de 16 caracteres confirmado). O 1º run do E1 falhou por eu ter rodado `oc process` sem `-n` (usou o projeto `default`: `Forbidden … processedtemplates`) — virou armadilha no README. **E4 `VALIDADO NO CLUSTER`** (Gitea privado + build real, `PASS`): o `httpd-example` criou BuildConfig e Deployment; o 1º build (`site-tpl-1`) **falhou sem credencial** (esperado), depois de `oc set build-secret --source bc/site-tpl git-creds` + `oc start-build` o `site-tpl-2` ficou `Complete` e a rota respondeu a página do `httpd-ex`. Parâmetros do template no 4.22.14: `NAME`, `NAMESPACE`, `SOURCE_REPOSITORY_URL`, `SOURCE_REPOSITORY_REF`, `CONTEXT_DIR` (+ outros).

```bash
oc project ex288-v3-t6
T=apps/templates/webapp-template.yaml        # caminho do arquivo no material
```

## E1

```bash
oc process --parameters -f $T
oc process -f $T -p NAME=tpl1 -p MESSAGE=ola-template -p REPLICAS=2 | oc apply -f -
oc rollout status deployment/tpl1
curl -s "http://$(oc get route tpl1 -o jsonpath='{.spec.host}')/"
oc get secret tpl1-token -o jsonpath='{.data.token}' | base64 -d | wc -c        # 16
```

## E2

```bash
oc create -f $T                      # cria o objeto Template no projeto
printf 'NAME=tpl2\nMESSAGE=param-file\nREPLICAS=1\n' > /tmp/params.env
oc new-app --template=webapp-template --param-file=/tmp/params.env
oc rollout status deployment/tpl2
```

`oc new-app --template=NOME` procura primeiro no projeto atual e depois em `openshift`. A senha **não** vai no arquivo de parâmetros (o `APP_TOKEN` é gerado).

## E3 — template próprio

```yaml
apiVersion: template.openshift.io/v1
kind: Template
metadata:
  name: mini
parameters:
  - {name: NAME, required: true}
  - {name: MESSAGE, value: hi}
objects:
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
              env: [{name: MESSAGE, value: "${MESSAGE}"}]
              command: ["node", "-e"]
              args: ["require('http').createServer((q,s)=>s.end(process.env.MESSAGE+'\\n')).listen(8080)"]
              ports: [{containerPort: 8080}]
  - {apiVersion: v1, kind: Service, metadata: {name: "${NAME}"}, spec: {selector: {app: "${NAME}"}, ports: [{port: 8080, targetPort: 8080}]}}
  - {apiVersion: route.openshift.io/v1, kind: Route, metadata: {name: "${NAME}"}, spec: {to: {kind: Service, name: "${NAME}"}}}
```

```bash
oc create -f mini.yaml
oc process --parameters mini
oc new-app --template=mini -p NAME=mini-a
oc new-app --template=mini -p NAME=mini-b -p MESSAGE=bravo
```

## E4 — `httpd-example` com o Git interno

```bash
oc process --parameters httpd-example -n openshift | grep -E 'NAME|SOURCE'
oc new-app --template=openshift/httpd-example -p NAME=site-tpl -p SOURCE_REPOSITORY_URL=http://GIT-INTERNO/ex288/httpd-ex.git
oc create secret generic git-creds --type=kubernetes.io/basic-auth --from-literal=username=USUARIO --from-literal=password=SENHA
oc set build-secret --source bc/site-tpl git-creds
oc start-build site-tpl --follow
curl -s "http://$(oc get route site-tpl -o jsonpath='{.spec.host}')/"
```

(Os nomes exatos dos parâmetros e da ImageStream usada pelo template devem ser conferidos com `oc process --parameters` e `oc describe template httpd-example -n openshift`.)

## Validar e limpar

```bash
bash scripts/validar-06.sh && bash scripts/limpar-06.sh
```
