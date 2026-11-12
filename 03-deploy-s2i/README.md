[← T2](../02-deploy-from-dockerfile/README.md) | [índice](../README.md) | [T4 →](../04-env-configmap-secret/README.md)

# T3 — Deploy de aplicação com S2I (Source-to-Image)

|                        |                                                                                                                                               |
| ---------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| **Task relatada**      | "Deploy de aplicação com S2I" `[RELATO PESSOAL]` (o Nexus pode entrar como mirror de dependências: `HIPÓTESE`)                                |
| **Objetivos oficiais** | "Build and deploy applications using S2I framework" · "Customize existing S2I builder images" · "Troubleshoot application builds" `[OFICIAL]` |
| **Projeto**            | `ex288-v3-t3` · `bash scripts/preparar-03.sh` · `validar-03.sh` · `limpar-03.sh`                                                              |
| **Pré-requisito**      | infra no ar (Git privado + Nexus)                                                                                                             |

## Caminho mais rápido na prova

```bash
oc get is -n openshift | grep -E 'nodejs|httpd|python|java|php'      # builders disponíveis e tags
oc new-app --name s2i1 --source-secret git-creds --image-stream openshift/nodejs:22-ubi9 \
  --code http://GIT/ex288/webapp-s2i.git
oc logs -f bc/s2i1 && oc expose service s2i1
```

Forma curta equivalente: `oc new-app nodejs:22-ubi9~URL --source-secret git-creds`. Se você **não** informar o builder, o `oc new-app` escolhe pela linguagem detectada (`package.json` → Node.js); sempre confira com `oc get bc -o jsonpath='{.items[*].spec.strategy.sourceStrategy.from.name}'`.

## Variações prováveis

| Variação | Como | Verificar |
|---|---|---|
| Variáveis de **build** (ex.: mirror do Nexus) | `--build-env npm_config_registry=http://NEXUS/repository/npm-public/` (Node) · `MAVEN_MIRROR_URL=…/repository/maven-public/` (builders Java; confirme no README da imagem: `NÃO VERIFICADO` aqui) | `oc get bc x -o jsonpath='{.spec.strategy.sourceStrategy.env}'` · `oc set env bc/x --list` |
| Variáveis de **runtime** | `-e K=V` (vão ao Deployment) ou `.s2i/environment` no repositório | `oc set env deploy/x --list` · resposta da app |
| Customizar `assemble`/`run` **no repositório** | arquivos executáveis em `.s2i/bin/assemble` e `.s2i/bin/run` (chame o original: `/usr/libexec/s2i/assemble`) | log do build mostra seu `echo` |
| Corrigir variável de build errada | `oc set env bc/x npm_config_registry=URL` + `oc start-build x --follow` | build `Complete` |
| Outro builder / outra tag | `--image-stream openshift/nodejs:20-ubi9` ou `oc patch bc` em `strategy.sourceStrategy.from` | `oc describe bc x` |
| Build incremental | `oc patch bc/x -p '{"spec":{"strategy":{"sourceStrategy":{"incremental":true}}}}'` | 2º build restaura artefatos (depende do builder: `HIPÓTESE`) |
| Somente o BuildConfig | `oc new-build nodejs:22-ubi9~URL --name x` + `oc start-build` | `oc get bc,is` |
| Ler os scripts do builder | `oc get istag nodejs:22-ubi9 -n openshift -o jsonpath='{.image.dockerImageMetadata.Config.Labels}'` → `io.openshift.s2i.scripts-url` | — |

## Armadilhas e diagnóstico

| Sintoma | Causa | Como achar |
|---|---|---|
| Build `Failed` no passo `npm install` | registry/mirror inacessível ou URL errada em `npm_config_registry` | `oc logs -f bc/x`; teste a URL com `curl` |
| `assemble: Permission denied` | script custom sem bit de execução no Git | `git update-index --chmod=+x .s2i/bin/assemble` |
| Seu `assemble` roda mas a app não instala dependências | esqueceu de chamar `/usr/libexec/s2i/assemble` | veja o conteúdo do script |
| App sobe mas variável de `.s2i/environment` "não existe" | ela vale no build **e** no runtime só se estiver no arquivo certo (`.s2i/environment`, sem `export`) | `oc exec deploy/x -- env` |
| `Build ... is not Complete` e Deployment sem imagem | rollout espera a 1ª imagem | `oc get builds` |
| Usou `--build-env` achando que era runtime | `-e` ≠ `--build-env` | `oc set env deploy/x --list` |

## Onde achar na documentação (OCP 4.22)

- Builds using BuildConfig → *Source-to-image build* (`sourceStrategy`, `env`, `incremental`, `scripts`): <https://docs.redhat.com/en/documentation/openshift_container_platform/4.22/html-single/builds_using_buildconfig/index#builds-strategy-s2i-build_build-strategies-docker>
- Images → *Create images from source code with source-to-image* (`assemble`, `run`, `save-artifacts`, `.s2i/bin`): <https://docs.redhat.com/en/documentation/openshift_container_platform/4.22/html-single/images/index#images-create-s2i_create-images>
- Support → *Troubleshooting the Source-to-Image process*: <https://docs.redhat.com/en/documentation/openshift_container_platform/4.22/html-single/support/index#troubleshooting-s2i>
- Variáveis do builder Node.js: README da imagem (`oc get istag nodejs:22-ubi9 -n openshift -o yaml` → `annotations`/labels com a URL do README).

## Variante com Git interno e Nexus

Repositório `webapp-s2i` (privado) com `.s2i/environment` e um `assemble` customizado que grava `/build-info`. O **mirror** do Nexus aparece em `registry=` dentro do `/build-info` quando `npm_config_registry` foi passada no build.

Próximo: [exercícios](exercicios.md) · [solução](solucao.md)
