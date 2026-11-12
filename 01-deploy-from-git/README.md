[← mapa](../00-guia/mapa-8-tasks.md) | [índice](../README.md) | [T2 →](../02-deploy-from-dockerfile/README.md)

# T1 — Deploy de aplicação a partir de um repositório Git

|                        |                                                                                                                                                                                                                                               |
| ---------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Task relatada**      | "Deploy de aplicação a partir de um repositório Git" `[RELATO PESSOAL]` (várias subtarefas; Git **interno** fornecido pelo ambiente)                                                                                                          |
| **Objetivos oficiais** | "Understand basic Git usage and work with Git in the context of deploying applications in OpenShift" · "Pull applications from existing Git repositories" · "Create and deploy single container and multi-container applications" `[OFICIAL]` |
| **Projeto do lab**     | `ex288-v3-t1` · preparar: `bash scripts/preparar-01.sh` · validar: `bash scripts/validar-01.sh` · limpar: `bash scripts/limpar-01.sh`                                                                                                         |
| **Pré-requisito**      | `bash scripts/infra-up.sh` (Git privado com 5 repositórios) · credenciais: `bash scripts/credenciais.sh --show`                                                                                                                               |
| **Validação**          | veja o status em [solucao.md](solucao.md)                                                                                                                                                                                                     |

## Caminho mais rápido na prova

```bash
oc project ex288-v3-t1                                   # confira SEMPRE o projeto
git config --global credential.helper 'cache --timeout=3600'     # o oc new-app clona no CLIENTE (ver armadilhas)
git ls-remote http://GIT-INTERNO/ex288/webapp.git                # digite usuario/senha UMA vez (fica so em memoria)
oc create secret generic git-creds --type=kubernetes.io/basic-auth \
  --from-literal=username=USUARIO --from-literal=password=SENHA
oc new-app --name web1 --source-secret git-creds \
  --image-stream openshift/nodejs:22-ubi9 --code http://GIT-INTERNO/ex288/webapp.git
oc logs -f bc/web1                                       # acompanhe o build (não bloqueie o resto da prova)
oc expose service web1 && oc get route web1
```

`oc new-app` cria **BuildConfig + ImageStream + Deployment + Service** (não cria Route). O Deployment espera o 1º build terminar: um `ErrImagePull` transitório no começo é normal.

## Variações prováveis (comando → como verificar)

| Variação                               | Comando                                                                                                        | Verificar                                                                                            |
| -------------------------------------- | -------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| Branch/tag/commit                      | `--code URL#dev` (ou `oc new-app nodejs:22-ubi9~URL#dev`)                                                      | `oc get bc web-dev -o jsonpath='{.spec.source.git.ref}'`                                             |
| Subdiretório do repositório            | `--context-dir api`                                                                                            | `oc get bc api -o jsonpath='{.spec.source.contextDir}'`                                              |
| Nome e rótulos                         | `--name web1 -l env=dev`                                                                                       | `oc get all -l env=dev`                                                                              |
| Estratégia explícita                   | `--strategy source` ou `docker` (vê [T2](../02-deploy-from-dockerfile/README.md))                              | `oc get bc -o jsonpath='{.items[0].spec.strategy.type}'`                                             |
| Variável **de runtime** × **de build** | `-e APP_MESSAGE=x` · `--build-env K=V`                                                                         | `oc set env deploy/web1 --list` · `oc get bc web1 -o jsonpath='{.spec.strategy.sourceStrategy.env}'` |
| Repositório privado (source secret)    | `--source-secret git-creds` ou depois: `oc set build-secret --source bc/web1 git-creds`                        | `oc get bc web1 -o jsonpath='{.spec.source.sourceSecret.name}'`                                      |
| Só gerar o YAML                        | `oc new-app … -o yaml > app.yaml`                                                                              | revisar e `oc apply -f`                                                                              |
| Expor                                  | `oc expose service web1` · TLS edge: `oc create route edge web1-tls --service=web1 --insecure-policy=Redirect` | `oc get route` · `curl -k https://…`                                                                 |
| Novo build após `git push`             | `oc start-build web1 --follow`                                                                                 | `oc get builds` · rota devolve o novo conteúdo                                                       |
| Console web (alternativa lenta)        | Developer → +Add → Import from Git                                                                             | —                                                                                                    |

## Armadilhas e diagnóstico

| Sintoma | Causa provável | Como achar / corrigir |
|---|---|---|
| `Could not resolve host` ao rodar `oc new-app` | o **cliente** clona o repositório; a rota do Git não resolve no seu WSL | `getent hosts HOST`; ver [pré-requisitos §3](../00-guia/preparar-wsl-rhel.md) |
| `oc new-app` **aborta** com `error: cloning repository … could not read Username … terminal prompts disabled` (`VERIFICADO` no CRC) | o **cliente** `oc` clona o repositório privado para analisá-lo; o `--source-secret` só vale para o **build** | autentique o `git` do cliente (`git config --global credential.helper 'cache --timeout=3600'` + `git ls-remote URL`, senha uma vez) **ou** crie o BuildConfig por YAML sem clonar (plano B da [solução](solucao.md)). Evite `https://usuario:senha@…` no `--code`: a senha vai parar no BuildConfig |
| Build falha com `could not read Username` | repositório privado sem source secret | `oc set build-secret --source bc/web1 git-creds`; `oc start-build web1` |
| Build usa o branch errado | `#branch` esquecido ou com erro de digitação | `oc get bc web1 -o yaml \| grep -A3 'git:'` |
| Nada mudou depois do rebuild | esqueceu o `git push` (o build clona do servidor) | `git log origin/main` |
| Rota 503 / "Application is not available" | Service/porta errados ou pod não `Ready`; **logo após criar a Route** pode durar alguns segundos (`VERIFICADO`) | `oc get endpoints web1`, `oc get pods`; espere ~10 s e repita |
| `error: No language matched the source repository` (`VERIFICADO`) | repositório sem linguagem detectável (ex.: só `index.html`) | use a forma `builder~URL`: `oc new-app "openshift/httpd:2.4-ubi9~URL" --context-dir site` |
| Pod `ImagePullBackOff` no início | o build ainda não publicou a ImageStreamTag | `oc get builds` e espere `Complete` |
| Criou em outro projeto | `oc project` não conferido | `oc get all -n OUTRO` e recrie no projeto pedido |

Ordem de diagnóstico: `oc get bc,build,is,deploy,pod,svc,route` → `oc logs -f bc/NOME` → `oc describe build NOME-1` → `oc get events --sort-by=.lastTimestamp | tail`.

## Onde achar na documentação (OCP 4.22)

- Building applications → *Creating applications by using the CLI* (`oc new-app`, detecção de estratégia): <https://docs.redhat.com/en/documentation/openshift_container_platform/4.22/html-single/building_applications/index#creating-applications-using-cli>
- Builds using BuildConfig → *Git source* e *Using a source secret* (inputs): <https://docs.redhat.com/en/documentation/openshift_container_platform/4.22/html-single/builds_using_buildconfig/index#builds-source-code_creating-build-inputs>
- Referência do `oc new-app`: <https://docs.redhat.com/en/documentation/openshift_container_platform/4.22/html-single/cli_tools/index#oc-new-app>
- Na prova: `oc new-app -h` mostra os exemplos de `--source-secret`, `--context-dir` e `#branch` sem abrir o navegador.

## Variante com o Git interno do ambiente

Na prova o Git não é o GitHub: a URL e as credenciais vêm no enunciado. Treine sempre com o Git **privado** do lab (`bash scripts/credenciais.sh`) e com `git clone`/`git push` autenticado (E4), não com repositórios públicos.

Próximo: [exercícios](exercicios.md) · [solução](solucao.md)
