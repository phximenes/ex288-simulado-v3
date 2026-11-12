[← T4](../04-env-configmap-secret/README.md) | [índice](../README.md) | [T6 →](../06-templates/README.md)

# T5 — Probes: startup, liveness e readiness

|                      |                                                                                  |
| -------------------- | -------------------------------------------------------------------------------- |
| **Task relatada**    | "Definir probes: startup, liveness e readiness" `[RELATO PESSOAL]`               |
| **Objetivo oficial** | "Use application health monitoring" `[OFICIAL]`                                  |
| **Projeto**          | `ex288-v3-t5` · `bash scripts/preparar-05.sh` · `validar-05.sh` · `limpar-05.sh` |
| **Pré-requisito**    | só o CRC (sem Git/Nexus)                                                         |

## Caminho mais rápido na prova

```bash
oc project ex288-v3-t5
oc set probe deployment/probeapp --startup   --get-url=http://:8080/healthz --period-seconds=2  --failure-threshold=30
oc set probe deployment/probeapp --liveness  --get-url=http://:8080/healthz --period-seconds=10 --timeout-seconds=2 --failure-threshold=3
oc set probe deployment/probeapp --readiness --get-url=http://:8080/ready   --period-seconds=5
oc rollout status deployment/probeapp && oc get deploy probeapp -o yaml | grep -A8 -E 'startupProbe|livenessProbe|readinessProbe'
```

`oc set probe` existe com `--startup` no `oc` 4.22.14 (`VERIFICADO` com `oc set probe -h`: `--startup`, `--liveness`, `--readiness`, `--get-url`, `--open-tcp`, `-- COMANDO`, `--initial-delay-seconds`, `--period-seconds`, `--timeout-seconds`, `--failure-threshold`, `--success-threshold`, `--remove`). Cada chamada gera um novo rollout; para vários ajustes de uma vez prefira `oc edit`/`oc patch`.

## Como as três probes se relacionam

| Probe | Pergunta | Se falhar | Observação |
|---|---|---|---|
| **startup** | "a app já terminou de subir?" | o container é **reiniciado** depois de `failureThreshold × periodSeconds` | enquanto não passar, **liveness e readiness nem rodam**; `successThreshold` deve ser 1 |
| **liveness** | "a app ainda está viva?" | reinicia o container (`CrashLoopBackOff` se persistir) | `successThreshold` deve ser 1 |
| **readiness** | "pode receber tráfego?" | tira o pod do Service (`0/1 Ready`), **não** reinicia | pode ir e voltar |

Regra prática: o tempo máximo de partida é `startup.failureThreshold × startup.periodSeconds` (ex.: 30 × 2 = 60 s); use startup para apps lentas em vez de inflar `initialDelaySeconds` da liveness.

## Variações prováveis

| Variação | Como | YAML equivalente |
|---|---|---|
| HTTP | `--get-url=http://:8080/healthz` (host vazio = IP do pod) | `httpGet: {path: /healthz, port: 8080}` |
| TCP | `--open-tcp=8080` | `tcpSocket: {port: 8080}` |
| Comando | `oc set probe deploy/x --liveness -- cat /proc/1/cmdline` (comando **depois** de `--`) | `exec: {command: [cat, /proc/1/cmdline]}` |
| Ajuste de tempos | `--initial-delay-seconds`, `--period-seconds`, `--timeout-seconds`, `--failure-threshold`, `--success-threshold` | campos do mesmo nome |
| Remover | `oc set probe deploy/x --remove --liveness` | apagar o bloco |
| Listar | `oc set probe deploy/x` (sem flags) | `oc get deploy x -o yaml` |
| Vários containers | `-c NOME` | `containers[N]` |
| Conferir o campo | `oc explain deployment.spec.template.spec.containers.startupProbe` | — |

## Armadilhas e diagnóstico

| Sintoma | Causa | Como achar |
|---|---|---|
| Pod `0/1 Running` para sempre | readiness aponta para caminho/porta errados (404/503) | `oc describe pod` → *Readiness probe failed: HTTP probe failed with statuscode: 503* |
| `CrashLoopBackOff` com `RESTARTS` subindo e logs limpos | liveness mata a app antes de ela subir (sem startup) | `oc describe pod` → *Liveness probe failed*, `Killing`; `oc logs --previous` |
| Probe em porta errada (ex.: 9090) | typo no `--get-url` | `oc get deploy x -o jsonpath='{.spec.template.spec.containers[0].livenessProbe}'` |
| Mudei a probe e nada reiniciou | falta aguardar o rollout | `oc rollout status deploy/x` |
| `successThreshold` > 1 em liveness/startup | o API rejeita | mensagem do `oc` |
| `oc set probe` em objeto que não é workload | usou `pod/` | use `deployment/` |

Eventos primeiro: `oc get events --sort-by=.lastTimestamp | tail -15`; depois `oc describe pod`, `oc logs POD --previous`.

## Onde achar na documentação (OCP 4.22)

- Building applications → cap. 11 *Monitoring application health* (**não** está em Nodes): <https://docs.redhat.com/en/documentation/openshift_container_platform/4.22/html-single/building_applications/index#application-health>
- Referência `oc set probe`: <https://docs.redhat.com/en/documentation/openshift_container_platform/4.22/html-single/cli_tools/index#oc-set-probe>
- Campos: `oc explain deployment.spec.template.spec.containers.livenessProbe --recursive`

Próximo: [exercícios](exercicios.md) · [solução](solucao.md)
