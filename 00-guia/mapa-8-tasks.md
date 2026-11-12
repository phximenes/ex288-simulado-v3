[índice](../README.md) | [Git/Nexus →](../00-nexus-e-git-interno/README.md)

# Mapa das 8 tasks × objetivos oficiais × relatos × material

Origem: tasks e ordem = relato do seu amigo `[RELATO PESSOAL]` (2026-10-30, uma prova, não confirmado pela Red Hat); objetivos = página oficial lida em 2026-10-31 `[OFICIAL]`; relatos públicos = [relatos.md](../90-fontes/relatos.md) (nenhum público da 4.22).

| # | Task relatada | Objetivos oficiais relacionados | Relatos públicos | Pasta / laboratório | v2 (referência) | Validação (CRC 4.22.14) |
|---|---|---|---|---|---|---|
| **T1** | Deploy a partir de um repositório Git | "Understand basic Git usage and work with Git in the context of deploying applications" · "Pull applications from existing Git repositories" | R1 (um candidato travou no acesso ao Git) | [01-deploy-from-git](../01-deploy-from-git/README.md) | `01-trabalhando-com-openshift`, `lab-crc\01`, `04` | **`VALIDADO NO CLUSTER`** (4 PASS, builds reais, Git privado) |
| **T2** | Deploy a partir de um Dockerfile | "Understand and work with image builds and image build configurations" · "Publish container images to the OpenShift image registry" | — | [02-deploy-from-dockerfile](../02-deploy-from-dockerfile/README.md) | `03-imagens-e-builds`, `lab-crc\03` | **`VALIDADO NO CLUSTER`** (E1–E4: 4 PASS, Nexus; **E5** `podman` no WSL: PASS) |
| **T3** | Deploy com S2I | "Build and deploy applications using S2I framework" · "Customize existing S2I builder images" | — | [03-deploy-s2i](../03-deploy-s2i/README.md) | `lab-crc\06`, `03-…\13-ch04s07` | **`VALIDADO NO CLUSTER`** (4 PASS, mirror do Nexus) |
| **T4** | ConfigMap + Secret **existente** por variáveis de ambiente | "Create configuration maps" · "Create secret resources" · "Use configuration maps to inject data into applications" | — | [04-env-configmap-secret](../04-env-configmap-secret/README.md) | `lab-crc\05` | **`VALIDADO NO CLUSTER`** (5 PASS) |
| **T5** | Probes: startup, liveness, readiness | "Use application health monitoring" | — | [05-probes](../05-probes/README.md) | `lab-crc\01` (T3) | **`VALIDADO NO CLUSTER`** (4 PASS) |
| **T6** | Deploy com Template | "Create an OpenShift template" · "Use pre-existing templates (JSON/YAML)" · "multi-container templates" · "custom parameters" | — | [06-templates](../06-templates/README.md) | `lab-crc\08` | **`VALIDADO NO CLUSTER`** (E1–E3: 3 PASS; E4 com Git interno: PASS) |
| **T7** | Deploy com Helm | "Create and use Helm charts" | — | [07-helm](../07-helm/README.md) | `lab-crc\02` | **`VALIDADO NO CLUSTER`** (E1–E3: 3 PASS; E4 repositório do Nexus: PASS; helm 4.3.1) |
| **T8** | Deploy usando CI/CD | "Understand and work with standard Tekton CRDs" · "Design, define and troubleshoot CI/CD workflows" · "Configure and trigger Pipeline workflows" · "Create a build hook…/manage and trigger application builds" | — | [08-cicd-pipelines](../08-cicd-pipelines/README.md) | `lab-crc\09`, `07` | **`VALIDADO NO CLUSTER`** (4 PASS; Operator 1.24.3: git-clone, buildah, openshift-client) |

Transversal: [Git interno e Nexus](../00-nexus-e-git-interno/README.md) (`HIPÓTESE` sobre o uso exato do Nexus na prova). **Simulados A e B:** T1–T7 `84/84` e T8 `16/16` cada (rodadas separadas) — ver [09-simulado](../09-simulado/README.md).

## Ordem relatada e o que fazer primeiro

`T1 → T2 → T3 → T4 → T5 → T6 → T7 → T8`, independentes entre si `[RELATO PESSOAL]`. Builds (T1–T3) e o PipelineRun (T8) são os mais lentos: inicie-os cedo ([estratégia](estrategia-de-prova.md)).

## Diferenças 4.18 × 4.22 que afetam as 8 tasks (cuidado: parte `NÃO VERIFICADA`)

| Tema | Detalhe | Task | Status |
|---|---|---|---|
| Várias versões da prova em uso | a página oficial avisa; o amigo fez a 4.18 (3 h); a atual é a 4.22 (4 h) | todas | `[OFICIAL]` · `[RELATO PESSOAL]` |
| Tasks fornecidas do Tekton | usar `resolver: cluster` com o namespace `openshift-pipelines`; `ClusterTask` descontinuado (versão exata da remoção: `NÃO VERIFICADO` na doc oficial) | T8 | consultar `oc get task -n openshift-pipelines` |
| Webhook de build | desde o 4.16 usuários não autenticados não têm `system:webhook` (fonte de terceiros) | T8 (variante) | `NÃO VERIFICADO` em doc oficial |
| `oc set env` | não tem `--keys` (em 4.22.14) | T4 | `VERIFICADO` |
| `oc set probe --startup` | existe em 4.22.14 | T5 | `VERIFICADO` |
| `oc new-app` + repositório privado | o cliente clona e **aborta** sem credencial de Git no cliente; `--source-secret` só vale para o build | T1, T3, T6 | `VERIFICADO` (4.22.14) |
| `oc new-app` + repositório sem linguagem detectável | exige a forma `builder~URL` | T1 | `VERIFICADO` (4.22.14) |
| `oc process` | usa o projeto atual (Forbidden em `default` sem `-n`) | T6 | `VERIFICADO` |
| `DeploymentConfig` | deprecado desde o 4.14; `oc new-app` cria `Deployment` | T1–T3 | `[OFICIAL]` (curso/doc) |
| Samples Operator deprecado | `image streams`/templates do `openshift` podem faltar em outros clusters; no CRC atual há builders e 50 templates | T3, T6 | `VERIFICADO` só no CRC |
| Helm | repositórios OCI/basic auth no console; a versão do CLI da prova é desconhecida | T7 | `NÃO VERIFICADO` |
