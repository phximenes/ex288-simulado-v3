[← preparar WSL](preparar-wsl-rhel.md) | [índice](../README.md) | [dia da prova →](dia-da-prova.md)

# Estratégia de prova (ambiente lento, 8 tasks independentes)

Origem de cada item entre colchetes. O desenho vem do relato do seu amigo (8 tasks na mesma ordem, independentes entre si, várias subtarefas, ambiente muito lento) `[RELATO PESSOAL]`; a página oficial diz **4 h** na versão 4.22, e há versões em uso de **3 h** (4.18) `[OFICIAL]`/`[RELATO PESSOAL]`. **Planeje para 3 h**; se tiver 4 h, a sobra vira revisão.

## Antes de tocar no teclado (5–8 min)

1. Leia **todas** as tasks e **todas** as subtarefas. As tasks são independentes: nada precisa ser feito em ordem, mas cada uma tem várias partes `[RELATO PESSOAL]`.
2. Em um bloco de notas, copie nomes exatos (projeto, app, Route, labels, imagens, tags, URLs, usuários) — nome errado zera a subtarefa `[BOA PRÁTICA]`.
3. Marque o que **demora** (builds S2I/Docker, PipelineRun, Helm com imagens grandes): são os primeiros a iniciar.

## Ordem sugerida

Siga a ordem original do relato, pulando o que travar:

`T1 Git → T2 Dockerfile → T3 S2I → T4 ConfigMap/Secret → T5 probes → T6 template → T7 Helm → T8 CI/CD` `[RELATO PESSOAL]`

Ajuste: dispare **primeiro** os builds de T1/T2/T3 (cada um leva minutos) e resolva T4/T5/T6 (rápidas, pouco I/O) enquanto eles rodam; deixe T8 para um bloco único, porque exige mais leitura `[BOA PRÁTICA]`.

## Orçamento de tempo (3 h = 180 min)

| Bloco | Minutos | Observação |
|---|---|---|
| Leitura e notas | 8 | |
| T1 Git | 18 | cuidado com credenciais do Git interno |
| T2 Dockerfile | 22 | build + conferência da rota |
| T3 S2I | 22 | variável de build / mirror |
| T4 ConfigMap + Secret | 12 | procurar o Secret existente |
| T5 probes | 12 | três probes + conferir `Ready` |
| T6 template | 15 | |
| T7 Helm | 17 | |
| T8 CI/CD | 32 | maior bloco |
| Revisão final | 22 | passar por **todas** as tasks e conferir |
| **Total** | **180** | folga ≈ 0: se travar > 10–15 min, **pule e volte** `[BOA PRÁTICA]` |

Com 4 h, some os 60 min à revisão e às tasks travadas.

## Como trabalhar em ambiente lento

| Prática | Por quê |
|---|---|
| CLI em vez de console web; **um terminal só** (use `tmux` se existir, ou uma aba) | Alt+Tab não funciona e trocar de janela é caro `[RELATO PÚBLICO]` 2021 · `[RELATO PESSOAL]` |
| Gere YAML e aplique de uma vez: `oc create … --dry-run=client -o yaml`, `oc new-app … -o yaml`, `oc explain X --recursive` | menos viagens ao servidor `[BOA PRÁTICA]` |
| Evite `watch`, `oc get -w`, `oc logs -f` infinito (exigem Ctrl+C, que o guia de prova remota desaconselha) | use `--timeout`, `oc wait`, `oc rollout status`, `oc logs --tail` `[OFICIAL]` V13 p.19 |
| Copiar/colar com o **mouse** (botão direito) | `[OFICIAL]` V13 p.19 |
| Não espere build em primeiro plano: inicie, anote "T2 build em andamento" e siga | `[BOA PRÁTICA]` |
| Tenha prontos os comandos de verificação (abaixo) num arquivo de notas | `[BOA PRÁTICA]` |
| `~/.vimrc` com `ts=2 sw=2 et ai` antes de editar YAML | `[RELATO PÚBLICO]` 2021 · [pré-requisitos §11](preparar-wsl-rhel.md) |
| Prefira `oc explain`/`oc <cmd> -h` à documentação web; abra a doc só quando precisar do caminho exato | `[BOA PRÁTICA]` |

## Verificação de cada task (antes de passar para a próxima)

```bash
oc project                                # estou no projeto pedido?
oc get all,route,cm,secret,pvc            # o recurso existe com o nome EXATO?
oc get pods                               # Running e READY n/n; RESTARTS estável
oc get builds,pipelinerun 2>/dev/null     # Complete / Succeeded
curl -s http://$(oc get route NOME -o jsonpath='{.spec.host}')/     # a rota responde o esperado
```

Sem correção automática visível na prova `[RELATO PÚBLICO]` 2021: **você** confere. Persistência: nada deve depender de `oc port-forward`, de shell aberta ou de arquivo em `/tmp` `[BOA PRÁTICA]`.

## Armadilhas que custam pontos `[BOA PRÁTICA]`

1. Recurso no projeto/usuário errado (`oc project`, `oc whoami`).
2. Nome, rótulo ou valor diferente do pedido (copie do enunciado).
3. Editar dentro do pod (`oc rsh`) em vez de na definição (some no restart).
4. Esquecer o `git push` antes do `oc start-build`.
5. Valor codificado duas vezes em Secret (`stringData` × `data`).
6. Deixar recurso em estado intermediário (build falhando, pod `CrashLoopBackOff`, rollout pendente).
7. `ClusterTask` (descontinuado): use `resolver: cluster` com o namespace `openshift-pipelines`.
8. Leitura apressada do enunciado: no relato público de 2024 a maior parte das falhas veio de **interpretação** `[RELATO PÚBLICO]`.

## Geração rápida de YAML

```bash
oc create deployment x --image=IMG --dry-run=client -o yaml
oc create configmap c --from-literal=A=1 --dry-run=client -o yaml
oc create secret generic s --from-literal=k=v --dry-run=client -o yaml
oc create route edge r --service=svc --dry-run=client -o yaml
oc new-app --name x --image-stream openshift/nodejs:22-ubi9 --code URL -o yaml
oc get deploy x -o yaml                       # limpe status, uid, resourceVersion, creationTimestamp
oc explain deployment.spec.template.spec.containers.startupProbe
```
