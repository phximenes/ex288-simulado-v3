[← exercícios](exercicios.md) | [índice](../README.md)

# T5 — Solução

> **Status:** `VALIDADO NO CLUSTER` — executado no CRC 4.22.14 como `developer`: antes `0 PASS / 4 FAIL`, depois **`4 PASS / 0 FAIL`**. Sintoma real do E3 observado: *Liveness probe failed: … :9090 … connection refused* + *Killing*. Uma falha inicial do E4 foi bug do **validador** (contava reinícios de um pod antigo em `Terminating`) e foi corrigida (`pod_restarts` ignora pods com `deletionTimestamp`).

```bash
oc project ex288-v3-t5
```

## E1 — três probes HTTP

```bash
oc set probe deployment/probeapp --startup   --get-url=http://:8080/healthz --period-seconds=2  --failure-threshold=30
oc set probe deployment/probeapp --liveness  --get-url=http://:8080/healthz --period-seconds=10 --timeout-seconds=2 --failure-threshold=3
oc set probe deployment/probeapp --readiness --get-url=http://:8080/ready   --period-seconds=5
oc rollout status deployment/probeapp
oc get pods -l app=probeapp          # 1/1 Running, RESTARTS 0
```

Startup: 30 × 2 s = 60 s ≥ 25 s de partida da app.

## E2 — TCP e comando

```bash
oc set probe deployment/probeapp2 --startup   --open-tcp=8080 --period-seconds=2 --failure-threshold=15
oc set probe deployment/probeapp2 --readiness --open-tcp=8080 --period-seconds=5
oc set probe deployment/probeapp2 --liveness  --period-seconds=10 -- cat /proc/1/cmdline
```

## E3 — liveness em porta errada

```bash
oc get pods -l app=probe-broken                     # RESTARTS crescendo
oc describe pod -l app=probe-broken | grep -A12 Events      # Liveness probe failed: ... :9090 ... connection refused
oc get deploy probe-broken -o jsonpath='{.spec.template.spec.containers[0].livenessProbe}'
oc set probe deployment/probe-broken --liveness --get-url=http://:8080/healthz --initial-delay-seconds=15 --period-seconds=10 --failure-threshold=3
oc rollout status deployment/probe-broken
```

## E4 — startup protege a liveness

```bash
oc describe pod -l app=probeapp3 | grep -B1 -A3 'Liveness probe failed'
oc set probe deployment/probeapp3 --startup --get-url=http://:8080/healthz --period-seconds=5 --failure-threshold=12     # 60 s
oc rollout status deployment/probeapp3
```

Com a startup probe presente, a liveness só começa depois que ela passa.

## Validar e limpar

```bash
bash scripts/validar-05.sh && bash scripts/limpar-05.sh
```
