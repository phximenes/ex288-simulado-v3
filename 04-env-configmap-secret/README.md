[← T3](../03-deploy-s2i/README.md) | [índice](../README.md) | [T5 →](../05-probes/README.md)

# T4 — Configuração por variáveis de ambiente: ConfigMap novo + Secret que **já existe**

|                        |                                                                                                                                                                |
| ---------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Task relatada**      | "Configuração por variáveis de ambiente: criar um ConfigMap e usar um Secret que já existe no cluster" `[RELATO PESSOAL]`                                      |
| **Objetivos oficiais** | "Create configuration maps" · "Create secret resources" · "Use configuration maps to inject data into applications" `[OFICIAL]`                                |
| **Projetos**           | `ex288-v3-t4` (app e Secret existente) e `ex288-v3-t4-shared` (Secret em **outro** projeto) · `bash scripts/preparar-04.sh` · `validar-04.sh` · `limpar-04.sh` |
| **Pré-requisito**      | só o CRC (não usa Git nem Nexus; credenciais do Nexus em Secret é outra variação, ver T2/T3)                                                                   |

## Caminho mais rápido na prova

```bash
oc project ex288-v3-t4
oc get secret                                   # ache o Secret que ja existe
oc describe secret db-credentials               # chaves e tamanhos (nao mostra valores)
oc extract secret/db-credentials --to=-         # valores (so se precisar conferir)
oc create configmap app-config --from-literal=GREETING=Ola --from-literal=LANG_CODE=pt-BR
oc set env deployment/cfgapp --from=configmap/app-config
oc set env deployment/cfgapp --list             # confira
```

## O que o `oc set env` faz (e não faz) — `VERIFICADO` com `oc` 4.22.14

| Fato | Detalhe |
|---|---|
| `--from=configmap/X` / `--from=secret/X` | importa **todas** as chaves como `valueFrom` (configMapKeyRef / secretKeyRef); o nome da variável é a chave em **maiúsculas** (`db_user` → `DB_USER`) |
| `--prefix=P_` | acrescenta prefixo aos nomes importados |
| **`--keys` não existe** em `oc set env` | `oc set env -h` não lista a flag. Para importar **uma** chave ou dar **outro nome** à variável, use `valueFrom` (patch/YAML) |
| Cada alteração gera novo rollout | acompanhe com `oc rollout status deployment/cfgapp` |

Variável `DB_USER` vinda da chave `username` de um Secret (sem valor literal no Deployment):

```bash
oc patch deployment/cfgapp --type=json -p '[{"op":"add","path":"/spec/template/spec/containers/0/env/-","value":{"name":"DB_USER","valueFrom":{"secretKeyRef":{"name":"db-credentials","key":"username"}}}}]'
```

(O patch `add … /env/-` só funciona se `env` já existir; se não existir, use `"path":"…/env","value":[{…}]`. Alternativas: `oc edit deployment/cfgapp` ou `oc set env … --from` + renomear.)

## Variações prováveis

| Variação | Como | Verificar |
|---|---|---|
| ConfigMap por arquivo | `oc create configmap x --from-file=app.properties` / `--from-env-file=file.env` | `oc get cm x -o yaml` |
| Importar com prefixo | `oc set env deploy/x --from=configmap/y --prefix=APP_` | `oc set env deploy/x --list` |
| Variável com nome ≠ chave | `valueFrom` via patch/YAML | `oc get deploy x -o yaml \| grep -B2 -A4 secretKeyRef` |
| ConfigMap/Secret como **volume** | `oc set volume deploy/x --add --name=v --type=configmap --configmap-name=y --mount-path=/etc/app` (`--type=secret --secret-name=…`) | `oc exec deploy/x -- ls /etc/app` |
| Secret **em outro projeto** | **não há referência entre projetos**: leia o valor e recrie no seu projeto | `oc get secret NOME -n OUTRO -o jsonpath='{.data.chave}' \| base64 -d` |
| Secret novo | `oc create secret generic s --from-literal=K=V` · TLS/docker-registry/basic-auth | `oc get secret s -o yaml` (base64) |
| Mudou o ConfigMap, o pod não mudou | variáveis só são lidas na criação do container: `oc rollout restart deployment/x` | `oc exec deploy/x -- env` |
| Só gerar YAML | `oc create configmap … --dry-run=client -o yaml` | — |

## Armadilhas

| Sintoma | Causa |
|---|---|
| `CreateContainerConfigError` | ConfigMap/Secret ou **chave** inexistente (`oc describe pod` mostra qual) |
| Valor "estranho" no Secret | dupla codificação em base64 (`--from-literal` já codifica; em YAML use `stringData`) |
| Variável vazia | chave com nome diferente do esperado pela app |
| Alterou o objeto no projeto errado | `oc project` / `-n` |
| Colocou a senha em claro no Deployment | a task pede Secret: use `valueFrom.secretKeyRef` |

## Onde achar na documentação (OCP 4.22)

- Building applications → cap. 9 *Using config maps with applications*: <https://docs.redhat.com/en/documentation/openshift_container_platform/4.22/html-single/building_applications/index#config-maps>
- Nodes → 2.7 *Providing sensitive data to pods by using secrets* (**não** está em Building applications): <https://docs.redhat.com/en/documentation/openshift_container_platform/4.22/html-single/nodes/index#nodes-pods-secrets>
- Referência `oc set env`: <https://docs.redhat.com/en/documentation/openshift_container_platform/4.22/html-single/cli_tools/index#oc-set-env>

Próximo: [exercícios](exercicios.md) · [solução](solucao.md)
