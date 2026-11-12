[← simulado](../09-simulado/README.md) | [índice](../README.md)

# Anexo — objetivos oficiais fora das 8 tasks relatadas

O relato do seu amigo é de **uma** prova; a página oficial lista 11 domínios e avisa que há várias versões em uso `[OFICIAL]`. O que ficou de fora das 8 tasks está no material anterior (`v2\`, somente leitura; caminhos relativos a `v2\`) e nos itens abaixo.

| Objetivo oficial | Onde estudar (no `v2\`) | No v3 |
|---|---|---|
| **Kustomize** ("Customizing deployments with Kustomize") — o amigo disse que **não caiu**; é o tópico "mais chato" porque não há gerador `oc create` | `02-deploy-multi-container\05-ch06s05-the-kustomize-cli.md`, `06-ch06s06-exercicio-…`, `lab-crc\02-helm-e-kustomize\` e `lab-crc\apps\kustomize\` | Comandos-chave: `oc kustomize DIR` (renderiza), `oc apply -k DIR`, `kustomization.yaml` (`resources`, `namePrefix`, `patches`, `images`, `configMapGenerator`); documentação: referência do `oc kustomize` (não há capítulo dedicado no OCP) |
| **Image streams** e triggers por mudança | `04-image-streams-e-deployments\01-ch03s05-…`, `lab-crc\04-image-streams-e-triggers\` | `oc import-image`, `oc tag`, `oc set triggers deploy/x --from-image=is:tag -c ctr`, `oc set image-lookup` |
| **Build hooks e triggers** | `lab-crc\07-build-hooks-e-triggers\` (o curso não cobre `postCommit`) | T8 E4 e [README da T8](../08-cicd-pipelines/README.md) |
| **Custom builder** / customizar builder S2I | `03-imagens-e-builds\13-ch04s07-…`, `14-ch04s08-…`, `lab-crc\06-s2i-e-builder-customizado\` | [T3 E4](../03-deploy-s2i/exercicios.md) cobre o `assemble` no repositório; o builder customizado está só no `v2` |
| **Registry interno** (acessar, publicar) | `03-imagens-e-builds\03-ch03s03-…`, `lab-crc\00-preparacao.md §4` | [T2 E5](../02-deploy-from-dockerfile/exercicios.md) |
| **Operators** ("Creating applications from installed Operators") | `lab-crc\10-operators\` (o curso não cobre) | só no `v2`; documentação: OCP *Operators → Creating applications from installed Operators* |
| **Troubleshooting** de builds e deploys | `lab-crc\11-troubleshooting-quebra-e-conserta\` | cenários espalhados nas T1–T8 (E3 de T2/T3/T5/T8) |
| **Projetos, multi-container, console web, estratégias de deployment, stateful** | `01-trabalhando-com-openshift\`, `04-…\05-ch05s03-…`, `07-ch05s05-…` | — |
| **Shipwright** (o curso 4.22 ensina; os objetivos citam BuildConfig) | `03-imagens-e-builds\07-ch04-…` | fora do escopo do v3 |

Mapa de onde achar cada assunto na documentação oficial: `v2\00-guia-de-estudo\mapa-documentacao.md` (âncoras conferidas no 4.22 em 2026-10-26).

> [!NOTE]
> O `v2\` tem o courseware DO288 traduzido (proprietário da Red Hat, uso pessoal). Por isso o v3 **não copia** essas páginas; só aponta para elas.
