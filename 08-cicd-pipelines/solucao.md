[← exercícios](exercicios.md) | [índice](../README.md)

# T8 — Solução

> **Status:** `VALIDADO NO CLUSTER` — CRC 4.22.14 com o Pipelines Operator v1.24.3 (instalado por você), `developer` impersonado: antes `0 PASS / 4 FAIL`, depois **`4 PASS / 0 FAIL`**. Verificado: `mini-ci` `Succeeded`; `build-and-deploy` `Succeeded` (`fetch` 52 s, `build` 44 s, `deploy` 10 s) e a rota `ci-app` respondeu `"app":"webapp-docker"` com UID aleatório; Tasks reais do Operator na 1.24: `git-clone` (params `URL`, `REVISION`, `DELETE_EXISTING`…; workspaces `output`, `basic-auth`), `buildah` (`IMAGE`, `DOCKERFILE`, `TLS_VERIFY`…; workspace `source`) e `openshift-client` (`SCRIPT`, `VERSION`) — os nomes usados em `pipeline-ci.yaml` estão corretos; o Git privado funcionou com o Secret `basic-auth` anotado `tekton.dev/git-0` e ligado à SA `pipeline`. **E3 verificado:** `runAfter: ["writ"]` é **rejeitado no `oc apply`** (`task read depends on writ but writ wasn't present in Pipeline`); com o workspace `dados` ≠ `data` o PipelineRun termina `CreateRunFailed: expected workspace "dados" to be provided by pipelinerun for pipeline task "read"`. **E4 verificado:** `POST` no webhook Generic → HTTP 200 → novo build `Complete` com `TESTS PASSED` no log do hook.

```bash
oc project ex288-v3-t8                         # no simulado, use o projeto da task (ex288-v3-sa-t8 / sb-t8)
oc get task -n openshift-pipelines            # git-clone, buildah, openshift-client...
for t in git-clone buildah openshift-client; do echo "== $t"; oc get task $t -n openshift-pipelines -o jsonpath='{.spec.params[*].name}{"\n"}{.spec.workspaces[*].name}{"\n"}'; done
```

## E1

```bash
oc apply -f apps/pipeline/pipeline-mini.yaml
cat <<'EOF' | oc create -f -
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: mini-ci-run-
spec:
  pipelineRef: {name: mini-ci}
  taskRunTemplate: {serviceAccountName: pipeline}
EOF
oc get pipelinerun
oc get pipelinerun -l tekton.dev/pipeline=mini-ci -o jsonpath='{.items[0].status.conditions[0].reason}{"\n"}'     # Succeeded
```

## E2 — Git privado → buildah → deploy

Credencial do Git para o Tekton (já criada pelo `preparar-08.sh`; para fazer à mão):

```bash
oc create secret generic git-basic-auth --type=kubernetes.io/basic-auth --from-literal=username=USUARIO --from-literal=password=SENHA
oc annotate secret git-basic-auth tekton.dev/git-0=http://GIT-INTERNO
oc secrets link pipeline git-basic-auth
```

```bash
oc apply -f apps/pipeline/pipeline-ci.yaml        # confira/ajuste os nomes dos parametros antes (comando acima)
NS=$(oc project -q)                               # o IMAGE precisa apontar para o PROJETO ATUAL (veja o aviso abaixo)
cat <<EOF | oc create -f -
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: build-and-deploy-run-
spec:
  pipelineRef: {name: build-and-deploy}
  taskRunTemplate: {serviceAccountName: pipeline}
  params:
    - {name: GIT_URL, value: "http://GIT-INTERNO/ex288/webapp-docker.git"}
    - {name: IMAGE, value: "image-registry.openshift-image-registry.svc:5000/$NS/ci-app:latest"}
    - {name: APP_NAME, value: ci-app}
  workspaces:
    - name: shared
      volumeClaimTemplate:
        spec:
          accessModes: [ReadWriteOnce]
          resources: {requests: {storage: 1Gi}}
EOF
oc logs -f -l tekton.dev/pipelineRun --all-containers --max-log-requests=100 --prefix --tail=-1 | head -100
curl -s "http://$(oc get route ci-app -o jsonpath='{.spec.host}')/"
```

> [!WARNING]
> **O `IMAGE` tem de usar o namespace do projeto onde o pipeline roda** (`…:5000/<projeto>/<imagem>:<tag>`). A ServiceAccount `pipeline` só tem permissão de push no próprio projeto: apontar para outro namespace (por exemplo, colar o `ex288-v3-t8` deste exercício dentro do `ex288-v3-sa-t8` do simulado) faz o `buildah` falhar no fim do push com `trying to reuse blob … authentication required`. Observado no seu simulado A (a task `fetch` passa, a `build` falha no push e a `deploy` fica `0/1`); a causa vem do log, e com o `IMAGE` no projeto certo este mesmo pipeline passou nas minhas rodadas de validação (E2 e simulado A). Conferir: `oc get pipelinerun NOME -o jsonpath='{.spec.params}'`. Corrigir: novo PipelineRun com o `IMAGE` certo (o Pipeline não muda).

## E3 — depurar `broken-ci`

```bash
oc apply -f apps/pipeline/pipeline-broken.yaml        # defeito 1: runAfter "writ" nao existe (rejeitado)
# corrija runAfter para ["write"]; reaplique; crie um PipelineRun com workspace shared:
#   defeito 2: a task 'read' declara o workspace "dados" mas o pipeline liga o nome "data" -> use o mesmo nome nos dois lados
```

Correção (trecho de `spec.tasks[1]`): `runAfter: ["write"]`, `taskSpec.workspaces: [{name: data}]` e `$(workspaces.data.path)`. PipelineRun com `volumeClaimTemplate` como no E2.

## E4 — gatilhos nativos

```bash
oc new-app --name native --source-secret git-creds --image-stream openshift/nodejs:22-ubi9 --code http://GIT-INTERNO/ex288/webapp.git
oc set triggers bc/native --from-webhook                  # Generic
oc set triggers bc/native --from-image=nodejs:22-ubi9     # ImageChange (confira com oc set triggers bc/native)
oc set build-hook bc/native --post-commit --script='npm test'
NS=$(oc project -q)
oc policy add-role-to-group system:webhook system:unauthenticated -n "$NS"     # desde o 4.16
oc describe bc native | grep -A2 'Webhook Generic'          # mostra a URL completa (…/webhooks/<segredo>/generic)
SEC=$(oc get bc native -o jsonpath='{.spec.triggers[?(@.type=="Generic")].generic.secret}' | awk '{print $1}')
curl -sk -X POST "https://api.crc.testing:6443/apis/build.openshift.io/v1/namespaces/$NS/buildconfigs/native/webhooks/$SEC/generic"   # HTTP 200
oc logs -f bc/native | grep 'TESTS PASSED'
```

(`oc describe bc/native` mostra a URL completa do webhook. O formato exato da saída varia: copie a URL manualmente se o `awk` acima não casar.)

## Validar e limpar

```bash
bash scripts/validar-08.sh && bash scripts/limpar-08.sh
```
