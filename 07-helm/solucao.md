[← exercícios](exercicios.md) | [índice](../README.md)

# T7 — Solução

> **Status:** E1–E3 `VALIDADO NO CLUSTER` (CRC 4.22.14, `helm` 4.3.1 do `v2\lab-crc\tools`, `developer` impersonado via `--kube-as-user`): antes `0 PASS / 3 FAIL`, depois **`3 PASS / 0 FAIL`**; `helm history rel2` mostrou 3 revisões (a 3ª "Rollback to 1"). `helm lint`: 0 falhas (só o aviso "icon is recommended"). O helm 3.x do seu WSL (3.22.1) não foi exercitado (o WSL não alcança o cluster). **E4 `VALIDADO NO CLUSTER`** (Nexus real, `PASS`): `helm repo add nexus … --username admin --password …`, `helm search repo ex288-hello --versions` listou `0.2.0` e `0.1.0`, e `helm install rel4 nexus/ex288-hello --version 0.2.0` respondeu `hello from helm v2`. Como o Windows não resolve a rota nova do Nexus, o `helm repo add` foi feito por `oc port-forward svc/nexus` (`http://localhost:…`) — só para o cliente, com arquivos de configuração do helm isolados (`--repository-config`).

```bash
oc project ex288-v3-t7
CH=apps/helm/ex288-hello
helm lint $CH
```

## E1

```bash
helm install rel1 $CH -n ex288-v3-t7 --set replicaCount=2 --set message="ola helm"
oc rollout status deployment/rel1-hello
curl -s "http://$(oc get route rel1-hello -o jsonpath='{.spec.host}')/"
```

## E2

```bash
printf 'replicaCount: 1\nmessage: first\n' > /tmp/values-rel2.yaml
helm install rel2 $CH -n ex288-v3-t7 -f /tmp/values-rel2.yaml
helm upgrade rel2 $CH -n ex288-v3-t7 -f /tmp/values-rel2.yaml --set message=second       # revisao 2
helm rollback rel2 1 -n ex288-v3-t7                                                      # revisao 3 (config da 1)
helm history rel2 -n ex288-v3-t7
oc rollout status deployment/rel2-hello
```

## E3

```bash
helm package $CH                         # gera ex288-hello-0.1.0.tgz no diretorio atual
helm install rel3 ./ex288-hello-0.1.0.tgz -n ex288-v3-t7 --set message=from-tgz
```

## E4 — repositório no Nexus

```bash
NEXUS=http://NEXUS-INTERNO
helm repo add nexus "$NEXUS/repository/helm-hosted/" --username admin --password "$NEXUS_PASS"
helm repo update
helm search repo ex288-hello --versions
helm install rel4 nexus/ex288-hello --version 0.2.0 -n ex288-v3-t7
```

`$NEXUS_PASS` vem de `bash scripts/credenciais.sh --show`; **não** grave a senha em arquivo. Se o nome do Nexus não resolver no WSL, use `oc port-forward -n ex288-v3-infra svc/nexus 8081:8081` apenas para o `helm repo add http://localhost:8081/…` (só para o cliente; não deixe nada dependendo do port-forward).

## Validar e limpar

```bash
bash scripts/validar-07.sh && bash scripts/limpar-07.sh
```
