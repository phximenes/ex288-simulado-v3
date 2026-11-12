[← exercícios](exercicios.md) | [índice](../README.md)

# T1 — Solução

> **Status:** `VALIDADO NO CLUSTER` — CRC 4.22.14 (6 CPUs / 16 GiB / 64 GiB), Gitea privado, builds S2I reais, como `developer` impersonado: antes `0 PASS / 4 FAIL`, depois **`4 PASS / 0 FAIL`**. Respostas reais: `web1` → `"branch":"main-v2"` após o `git push` + `oc start-build`; `web-dev` → `"branch":"dev","message":"from-dev"`; `api` → `monorepo-api`; `site-tls` (edge + Redirect) → `monorepo-site`. **Descobertas da execução** (já refletidas abaixo): (1) com repositório **privado** o `oc new-app` **aborta** (`could not read Username`) se o **cliente** não tiver credencial de Git — o `--source-secret` só serve ao build; (2) para um repositório sem linguagem detectável (site estático) o `--image-stream … --code …` falha com `No language matched`, é preciso a forma `builder~repositório`; (3) o plano B (BuildConfig por YAML) foi testado e funciona; (4) logo após criar uma Route o roteador pode devolver "Application is not available" por alguns segundos.

Variáveis usadas (valores vêm de `bash scripts/credenciais.sh --show`; **não** grave a senha em arquivo):

```bash
GIT=http://GIT-INTERNO/ex288          # rota do Gitea
oc project ex288-v3-t1
```

## E1 — `web1` a partir do repositório privado

```bash
# 1) o oc new-app CLONA no cliente: autentique o git do cliente (a senha fica so em memoria)
git config --global credential.helper 'cache --timeout=3600'
git ls-remote "$GIT/webapp.git"                          # digite usuario e senha uma vez
# 2) o Secret serve ao BUILD (o pod de build clona de novo)
oc create secret generic git-creds --type=kubernetes.io/basic-auth \
  --from-literal=username="$GIT_USER" --from-literal=password="$GIT_PASS"
oc new-app --name web1 --source-secret git-creds \
  --image-stream openshift/nodejs:22-ubi9 --code "$GIT/webapp.git"
oc logs -f bc/web1
oc expose service web1
curl -s "http://$(oc get route web1 -o jsonpath='{.spec.host}')/"       # {"app":"webapp","branch":"main",...}
```

(`NÃO VERIFICADO`: o helper `cache` do Git do RHEL — nos testes o cliente foi autenticado por um helper transitório equivalente. Sem nenhuma credencial no cliente o `oc new-app` **falha**; veja o plano B.)

**Plano B — sem clonar no cliente** (`VERIFICADO`: build `Complete`, rota respondendo `"branch":"main-v2"`): crie a ImageStream e o BuildConfig por YAML (com o source secret) e depois a aplicação a partir da ImageStream.

```bash
oc create imagestream web1
cat <<EOF | oc create -f -
apiVersion: build.openshift.io/v1
kind: BuildConfig
metadata: {name: web1}
spec:
  source:
    type: Git
    git: {uri: "$GIT/webapp.git", ref: main}
    sourceSecret: {name: git-creds}
  strategy:
    type: Source
    sourceStrategy:
      from: {kind: ImageStreamTag, namespace: openshift, name: "nodejs:22-ubi9"}
  output:
    to: {kind: ImageStreamTag, name: "web1:latest"}
  triggers:
    - type: ConfigChange
EOF
oc get builds                                    # web1-1 inicia sozinho (ConfigChange); espere Complete
oc new-app --image-stream web1:latest --name web1        # Deployment + Service a partir da ImageStream
oc expose service web1
```

## E2 — branch `dev`, rótulo e variável

```bash
oc new-app --name web-dev --source-secret git-creds -l env=dev -e APP_MESSAGE=from-dev \
  --image-stream openshift/nodejs:22-ubi9 --code "$GIT/webapp.git#dev"
oc expose service web-dev
curl -s "http://$(oc get route web-dev -o jsonpath='{.spec.host}')/"    # "branch":"dev","message":"from-dev"
```

`-l` põe o rótulo em BuildConfig, ImageStream, Deployment e Service; a Route criada depois por `oc expose` herda os rótulos do Service.

## E3 — monorepo (dois componentes) e route edge

```bash
oc new-app --name api  --source-secret git-creds --context-dir api  --image-stream openshift/nodejs:22-ubi9 --code "$GIT/monorepo.git"
oc new-app --name site --source-secret git-creds --context-dir site "openshift/httpd:2.4-ubi9~$GIT/monorepo.git"
oc expose service api
oc expose service site
oc create route edge site-tls --service=site --insecure-policy=Redirect
curl -sk "https://$(oc get route site-tls -o jsonpath='{.spec.host}')/"          # <h1>monorepo-site</h1>
```

> [!NOTE]
> `VERIFICADO`: para `site` (só `index.html`, sem linguagem detectável) a forma `--image-stream httpd:… --code URL` falha com `error: No language matched the source repository`; use `builder~URL` como acima. Para `api` (tem `package.json`) as duas formas funcionam.

## E4 — alterar, `git push` e `start-build`

```bash
git clone "http://$GIT_USER:$GIT_PASS@GIT-INTERNO/ex288/webapp.git" /tmp/webapp && cd /tmp/webapp
echo main-v2 > BRANCH
git -c user.name=aluno -c user.email=aluno@example.invalid commit -am "branch main-v2"
git push origin main
oc start-build web1 --follow
curl -s "http://$(oc get route web1 -o jsonpath='{.spec.host}')/"       # "branch":"main-v2"
```

(Em casa o `clone` com a senha na URL é aceitável; **na prova** prefira `git config credential.helper` ou o prompt, para não deixar a senha no histórico do shell.)

## Validar e limpar

```bash
bash scripts/validar-01.sh      # PASS/FAIL por exercício
bash scripts/limpar-01.sh
```
