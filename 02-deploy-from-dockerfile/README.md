[← T1](../01-deploy-from-git/README.md) | [índice](../README.md) | [T3 →](../03-deploy-s2i/README.md)

# T2 — Deploy de aplicação a partir de um Dockerfile

| | |
|---|---|
| **Task relatada** | "Deploy de aplicação a partir de um Dockerfile" `[RELATO PESSOAL]`; o Nexus apareceu em "algumas tasks" (uso exato: `HIPÓTESE`) |
| **Objetivos oficiais** | "Understand how to create container images based on pre-built images" · "Understand and work with image builds and image build configurations" · "Publish container images to the OpenShift image registry" `[OFICIAL]` |
| **Projeto** | `ex288-v3-t2` · `bash scripts/preparar-02.sh` · `validar-02.sh` · `limpar-02.sh` |
| **Pré-requisito** | infra no ar (`scripts/infra-up.sh`); `podman` no WSL para o E5 |

## Caminho mais rápido na prova

```bash
oc new-app --name docker1 --source-secret git-creds --strategy docker --code http://GIT/ex288/webapp-docker.git
oc logs -f bc/docker1 && oc expose service docker1
```

Sem `--strategy`, o `oc new-app` **detecta** um `Dockerfile` na raiz do repositório e usa a estratégia `docker` sozinho. O arquivo precisa se chamar **`Dockerfile`** na detecção do `oc new-build/new-app` (com outro nome, ajuste `dockerStrategy.dockerfilePath` no BuildConfig). O build usa o `buildah` do cluster.

## Variações prováveis

| Variação | Comando | Verificar |
|---|---|---|
| Subdiretório ou outro nome de arquivo | `--context-dir sub` · `oc patch bc/x -p '{"spec":{"strategy":{"dockerStrategy":{"dockerfilePath":"Dockerfile.root"}}}}'` | `oc get bc x -o jsonpath='{.spec.strategy.dockerStrategy}'` |
| `ARG` do Dockerfile (ex.: mirror npm do **Nexus**) | `oc new-build … --build-arg NPM_REGISTRY=http://NEXUS/repository/npm-public/` ou `oc start-build x --build-arg K=V` | `oc get bc x -o jsonpath='{.spec.strategy.dockerStrategy.buildArgs}'` · log do build |
| Build binário (código local ou baixado do Nexus) | `oc new-build --binary --strategy docker --name x` + `oc start-build x --from-dir=. --follow` | `oc get build` · `oc get istag x:latest` |
| Imagem base de registry **autenticado** | `oc create secret docker-registry …` + `oc secrets link builder SEGREDO` (build) / `--for=pull` (default) | `oc get sa builder -o yaml` |
| Dockerfile compatível com OpenShift (UID arbitrário) | `USER 1001`, `chgrp -R 0 DIR && chmod -R g=u DIR`, porta > 1024 | pod `Running`; `oc rsh POD id` |
| Publicar com **podman** e subir da ImageStream | `HOST=$(oc registry info --public)` → `podman login` → `podman build` → `podman push $HOST/ns/img:tag` → `oc new-app --image-stream ns/img:tag` | `oc get istag` |
| Saída do build para outra tag | `oc new-build … --to nome:1.0` | `oc get is` |

> [!WARNING]
> Sob a SCC `restricted-v2` o container roda com UID **aleatório** (grupo 0): um Dockerfile que escreve em diretório só do root, ou que escuta na porta 80, quebra mesmo com `USER 0` no arquivo. Veja o E3.

## Armadilhas e diagnóstico

| Sintoma | Causa | Como achar |
|---|---|---|
| `No Dockerfile was found in the repository` | arquivo com outro nome (ex.: `Containerfile`) | renomeie ou use `dockerfilePath` |
| `CrashLoopBackOff` com `EACCES` nos logs | diretório de escrita só do root (UID arbitrário) | `oc logs POD --previous`; corrija permissões no Dockerfile |
| `permission denied` ao escutar em `:80` | porta < 1024 sem root | use 8080 e `EXPOSE 8080` |
| Build "trava" no `npm install` | sem acesso ao registry público; use o mirror do Nexus | `--build-arg NPM_REGISTRY=…`; `oc logs -f bc/x` |
| `podman push` com erro de certificado | CA do registry não confiável no WSL | [pré-requisitos §9](../00-guia/preparar-wsl-rhel.md) |
| `unauthorized` no push | token expirado ou projeto errado no nome da imagem | `podman login -u developer -p "$(oc whoami -t)" $(oc registry info --public)` |
| Deploy não sobe depois do push | tag ≠ a usada no Deployment | `oc get istag`; `oc set image-lookup` |

## Onde achar na documentação (OCP 4.22)

- Builds using BuildConfig → *Docker build* (`dockerStrategy`, `buildArgs`, `dockerfilePath`): <https://docs.redhat.com/en/documentation/openshift_container_platform/4.22/html-single/builds_using_buildconfig/index#builds-strategy-docker-build_build-strategies-docker>
- Builds using BuildConfig → *Binary (local) source*: `…/builds_using_buildconfig/index#builds-binary-source_creating-build-inputs`
- Images → *Guidelines for creating images* (UID arbitrário, `chgrp -R 0`): `…/images/index#images-create-guide-general_create-images`
- Registry → *Accessing the registry* (login e push): `…/registry/index#accessing-the-registry`

## Variante com Git interno e Nexus

O repositório é o `webapp-docker` do Git privado; o Nexus entra como **mirror npm** no `ARG`, como **origem de artefato** (raw) para o build binário e (hipótese) como registry de imagens.

Próximo: [exercícios](exercicios.md) · [solução](solucao.md)
