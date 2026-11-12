[← T7](../07-helm/README.md) | [índice](../README.md) | [simulado →](../09-simulado/README.md)

# T8 — Deploy de aplicação usando CI/CD (OpenShift Pipelines)

|                        |                                                                                                                                                                                                                                                               |
| ---------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Task relatada**      | "Deploy de aplicação usando CI/CD" `[RELATO PESSOAL]` — a task não diz se é Tekton ou gatilhos de build nativos; o v3 cobre os dois (os gatilhos nativos são `HIPÓTESE`)                                                                                      |
| **Objetivos oficiais** | "Understand and work with standard Tekton CRDs for defining CI/CD pipelines" · "Design and define, and troubleshoot CI/CD workflows" · "Configure and trigger Pipeline workflows" · "Create a build hook / manage and trigger application builds" `[OFICIAL]` |
| **Projeto**            | `ex288-v3-t8` · `bash scripts/preparar-08.sh` · `validar-08.sh` · `limpar-08.sh`                                                                                                                                                                              |
| **Pré-requisito**      | **Pipelines Operator instalado** ([passo 12](../00-guia/preparar-wsl-rhel.md#12-pipelines-operator-no-crc-t8--você-executa-como-kubeadmin)); Git interno para o E2                                                                                            |

> [!IMPORTANT]
> `ClusterTask` foi descontinuado. Nas versões atuais as Tasks fornecidas (`git-clone`, `buildah`, `openshift-client`, `s2i-*`…) ficam no namespace **`openshift-pipelines`** e são usadas com o **cluster resolver** (`taskRef.resolver: cluster`). Isso aparece no próprio material do curso (`do288`, cap. 7) e em registros de terceiros; a versão em que `ClusterTask` sumiu é `NÃO VERIFICADO` na documentação oficial. Confira: `oc get task -n openshift-pipelines`.

## Caminho mais rápido na prova

```bash
oc project ex288-v3-t8
oc get task -n openshift-pipelines                                  # o que o Operator oferece
oc get task git-clone -n openshift-pipelines -o jsonpath='{.spec.params[*].name}{"\n"}{.spec.workspaces[*].name}{"\n"}'
oc apply -f pipeline.yaml
oc create -f pipelinerun.yaml                                       # generateName: sem o tkn
oc get pipelinerun,taskrun ; oc logs -f -l tekton.dev/pipelineRun=NOME --all-containers --prefix
```

Sem `tkn`: use `oc create -f` com `generateName`, `oc get pipelinerun NOME -o jsonpath='{.status.conditions[0].reason}'` e `oc logs` por rótulo.

## Variações prováveis

| Variação | Como | Verificar |
|---|---|---|
| Pipeline com Tasks do Operator | `taskRef` com `resolver: cluster` e params `kind`/`name`/`namespace` | `oc get pipeline NOME -o yaml` |
| Encadear | `runAfter: ["tarefa-anterior"]` | grafo no console |
| Workspace compartilhado | PipelineRun com `volumeClaimTemplate` (RWO) ou PVC existente | `oc get pvc` |
| Git **privado** | Secret `kubernetes.io/basic-auth` com a anotação `tekton.dev/git-0: http://HOST` ligado à SA `pipeline`: `oc secrets link pipeline SEGREDO` | log do `git-clone` sem `could not read Username` |
| Parâmetros do PipelineRun | `params:` no `spec` do PipelineRun | `oc get pipelinerun NOME -o yaml` |
| Passo final sempre | bloco `finally:` | tasks `finally` rodam mesmo com falha |
| Reexecutar | `oc create -f` novamente (cada `generateName` cria um novo PipelineRun) | — |
| ServiceAccount | `spec.taskRunTemplate.serviceAccountName: pipeline` | permissões do deploy |
| Gatilhos **nativos** (sem Tekton) | BuildConfig com webhook `generic`/`github` (`oc set triggers bc/x --from-webhook`), `ImageChange` e `ConfigChange`; hook `oc set build-hook bc/x --post-commit --script='npm test'` | `oc describe bc x`; `curl -X POST URL-do-webhook` cria um build |
| Webhook sem autenticação | desde o 4.16 usuários não autenticados não têm `system:webhook`: `oc policy add-role-to-group system:webhook system:unauthenticated -n NS` | HTTP 200 no POST |

## Armadilhas e diagnóstico

| Sintoma | Causa | Como achar |
|---|---|---|
| `oc apply` rejeita o Pipeline | `runAfter` aponta para task inexistente | mensagem de validação |
| PipelineRun `PipelineValidationFailed` | parâmetro/workspace com nome errado ou ausente | `oc describe pipelinerun`; nomes: `oc get task X -n openshift-pipelines -o yaml` |
| PipelineRun `Pending`/PVC `Pending` | falta de StorageClass ou de espaço | `oc get pvc,events` |
| `git-clone` falha com autenticação | Secret sem a anotação ou não ligado à SA | `oc get sa pipeline -o yaml` |
| `buildah` falha no push | parâmetro `IMAGE` com registry/namespace errado; SA sem permissão | `oc logs POD -c step-push` |
| Deploy "passa" mas nada sobe | a task `openshift-client` rodou no namespace errado | `oc get all` |
| Logs vazios | step ainda não começou | `oc get taskrun`, `oc get pods` (pod `…-pod`) |

Depuração em camadas: `PipelineRun` → `TaskRun` (`oc get taskrun -l tekton.dev/pipelineRun=NOME`) → pod do step (`oc logs POD -c step-NOME`).

## Onde achar na documentação

A documentação do Pipelines é **outro produto** (versão 1.24 no catálogo do CRC): <https://docs.redhat.com/en/documentation/red_hat_openshift_pipelines/1.24/html-single/creating_cicd_pipelines/index>
- *Creating CI/CD solutions for applications using OpenShift Pipelines* (Tasks, Pipelines, PipelineRun, workspaces, resolvers): âncora `#creating-applications-with-cicd-pipelines` e `#remote-pipelines-tasks-resolvers`.
- Instalação do Operator: livro *Installing and configuring*.
- Builds (gatilhos nativos): OCP → Builds using BuildConfig → cap. 8 *Triggering and modifying builds*: <https://docs.redhat.com/en/documentation/openshift_container_platform/4.22/html-single/builds_using_buildconfig/index#triggering-builds-build-hooks>
- Campos no cluster: `oc explain pipeline.spec.tasks --recursive`.

Próximo: [exercícios](exercicios.md) · [solução](solucao.md)
