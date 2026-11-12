[← exercícios](exercicios.md) | [índice](../README.md)

# T4 — Solução

> **Status:** `VALIDADO NO CLUSTER` — solução executada no CRC 4.22.14 como `developer` (impersonado): antes `1 PASS / 4 FAIL` (só o rollout inicial), depois **`5 PASS / 0 FAIL`**. Confirmado com `oc set env -h`: `--from`, `--prefix`, `--list`, `--resolve`, `--overwrite`; **não** existe `--keys`. Observado: `--prefix=API_` com a chave `token` gera `API_TOKEN` (chave em maiúsculas).

```bash
oc project ex288-v3-t4
oc get secret                         # db-credentials ja existe
oc describe secret db-credentials     # username, password
```

## E1

```bash
oc create configmap app-config --from-literal=GREETING=Ola --from-literal=LANG_CODE=pt-BR --from-literal=API_HOST=http://api:8080
oc set env deployment/cfgapp --from=configmap/app-config
oc rollout status deployment/cfgapp
curl -s "http://$(oc get route cfgapp -o jsonpath='{.spec.host}')/"
```

## E2 — Secret existente, variável com nome diferente da chave

**Você não precisa decorar o JSON patch abaixo.** O que importa é entender que o `oc set env` não renomeia chaves; para isso há três caminhos, do mais fácil para o mais seco:

1. **`oc edit deployment/cfgapp`** (interativo: não o executei aqui; o `oc explain` mostra a estrutura): em `spec.template.spec.containers[0]` acrescente (com `.vimrc` de `expandtab`, a indentação sai certa) e salve:
   ```yaml
   env:
   - name: DB_USER
     valueFrom:
       secretKeyRef: {name: db-credentials, key: username}
   - name: DB_PASSWORD
     valueFrom:
       secretKeyRef: {name: db-credentials, key: password}
   ```
   Para lembrar a estrutura sem decorar: `oc explain deployment.spec.template.spec.containers.env.valueFrom.secretKeyRef` (`VERIFICADO`: lista `key` e `name`).
2. **Console web** (`NÃO VERIFICADO` aqui; é o caminho padrão das 4.x): *Workloads → Deployments → cfgapp → aba **Environment** → **Add from ConfigMap or Secret*** → *Name* `DB_USER`, *Resource* `db-credentials`, *Key* `username` → repita para a senha → *Save*. Dá o mesmo `secretKeyRef`.
3. **`oc patch` com YAML** (strategic merge pelo nome do container; sem índice e sem `op`; `VERIFICADO` com `env` vazio também):
   ```bash
   oc patch deployment/cfgapp -p '
   spec:
     template:
       spec:
         containers:
         - name: cfgapp
           env:
           - {name: DB_USER, valueFrom: {secretKeyRef: {name: db-credentials, key: username}}}
           - {name: DB_PASSWORD, valueFrom: {secretKeyRef: {name: db-credentials, key: password}}}
   '
   ```

Se os nomes das variáveis puderem ser os das chaves, é uma linha só: `oc set env deployment/cfgapp --from=secret/db-credentials --prefix=DB_` (gera `DB_USERNAME` e `DB_PASSWORD`; `VERIFICADO` que com `login`/`secret` gera `DB_LOGIN`/`DB_SECRET`).

O JSON patch equivalente (o mais verboso; só para referência):

```bash
oc patch deployment/cfgapp --type=json -p '[
 {"op":"add","path":"/spec/template/spec/containers/0/env/-","value":{"name":"DB_USER","valueFrom":{"secretKeyRef":{"name":"db-credentials","key":"username"}}}},
 {"op":"add","path":"/spec/template/spec/containers/0/env/-","value":{"name":"DB_PASSWORD","valueFrom":{"secretKeyRef":{"name":"db-credentials","key":"password"}}}}]'
oc rollout status deployment/cfgapp
oc set env deployment/cfgapp --list      # DB_USER e DB_PASSWORD "from secret db-credentials"
```

Alternativa curta para a senha: `oc set env deployment/cfgapp --from=secret/db-credentials --prefix=DB_` cria `DB_USERNAME` e `DB_PASSWORD` — mas **não** `DB_USER`, então a primeira variável ainda exige `valueFrom`. Se `env` ainda não existir no container, o `add …/env/-` falha: rode antes `oc set env deployment/cfgapp X=1` ou use `"path":"…/env","value":[…]`.

## E3 — Secret de outro projeto

```bash
TOKEN=$(oc get secret shared-api -n ex288-v3-t4-shared -o jsonpath='{.data.token}' | base64 -d)
oc create secret generic shared-api --from-literal=token="$TOKEN"
oc set env deployment/cfgapp --from=secret/shared-api --prefix=API_       # cria API_TOKEN
unset TOKEN
oc rollout status deployment/cfgapp
```

`--prefix=API_` + chave `token` → `API_TOKEN` (maiúsculas). Sem prefixo, a variável seria `TOKEN`.

## E4 — prefixo e volume

```bash
oc create configmap extra-config --from-literal=HOST=cfg.example.invalid --from-literal=PORT=9090
oc set env deployment/cfgapp --from=configmap/extra-config --prefix=APP_
printf 'feature.flag=on\n' > app.properties
oc create configmap app-files --from-file=app.properties
oc set volume deployment/cfgapp --add --name=files --type=configmap --configmap-name=app-files --mount-path=/etc/app --read-only=true
oc rollout status deployment/cfgapp
oc exec deploy/cfgapp -- cat /etc/app/app.properties
curl -s "http://$(oc get route cfgapp -o jsonpath='{.spec.host}')/"
```

## Validar e limpar

```bash
bash scripts/validar-04.sh && bash scripts/limpar-04.sh
```
