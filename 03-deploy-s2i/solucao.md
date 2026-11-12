[← exercícios](exercicios.md) | [índice](../README.md)

# T3 — Solução

> **Status:** `VALIDADO NO CLUSTER` (CRC 4.22.14, Gitea privado, Nexus, builds S2I reais, `developer` impersonado): antes `0 PASS / 4 FAIL`, depois **`4 PASS / 0 FAIL`**. Respostas reais do `/build-info`: `s2i1` → `registry=https://registry.npmjs.org/` e depois `custom=yes`; `s2i-nexus` → `registry=http://nexus-ex288-v3-infra.apps-crc.testing/repository/npm-public/` (o `npm_config_registry` de build chega ao `npm config get registry` dentro do `assemble`); `s2i-broken` falha com `npm error … If you are behind a proxy` / `error: build error: … RUN /tmp/scripts/assemble: exit status 1` e fica `Complete` depois de corrigir a variável. Observado também: um `assemble` com erro de sintaxe (meu `sed` errado no 1º teste) derruba o build (`s2i1-2 Failed`) — por isso confira `cat .s2i/bin/assemble` antes do `git push`. As soluções alteram o repositório: rode `bash scripts/infra-up.sh` para restaurá-lo.

```bash
oc project ex288-v3-t3 ; GIT=http://GIT-INTERNO/ex288 ; NEXUS=http://NEXUS-INTERNO
```

## E1

```bash
oc new-app --name s2i1 --source-secret git-creds --image-stream openshift/nodejs:22-ubi9 --code "$GIT/webapp-s2i.git"
oc logs -f bc/s2i1                 # procure: ---> EX288 custom assemble
oc expose service s2i1
curl -s "http://$(oc get route s2i1 -o jsonpath='{.spec.host}')/"             # "message":"from-s2i-environment"
curl -s "http://$(oc get route s2i1 -o jsonpath='{.spec.host}')/build-info"   # built-at=...
```

## E2 — mirror do Nexus (variável de build)

```bash
oc new-app --name s2i-nexus --source-secret git-creds --image-stream openshift/nodejs:22-ubi9 \
  --build-env npm_config_registry="$NEXUS/repository/npm-public/" --code "$GIT/webapp-s2i.git"
oc logs -f bc/s2i-nexus
oc expose service s2i-nexus
curl -s "http://$(oc get route s2i-nexus -o jsonpath='{.spec.host}')/build-info"   # registry=http://NEXUS.../repository/npm-public/
```

Para Java (Maven) o conceito é o mesmo com `MAVEN_MIRROR_URL`; confirme o nome da variável no README do builder (`NÃO VERIFICADO`).

## E3 — build quebrado

```bash
oc get builds                                  # s2i-broken-1  Failed
oc logs -f bc/s2i-broken                       # npm ERR! ... ECONNREFUSED 127.0.0.1:9  (registry errado)
oc get bc s2i-broken -o jsonpath='{.spec.strategy.sourceStrategy.env}'
oc set env bc/s2i-broken npm_config_registry="$NEXUS/repository/npm-public/"
oc start-build s2i-broken --follow
oc expose service s2i-broken
```

## E4 — customizar o `assemble`

```bash
git clone "http://USUARIO:SENHA@GIT-INTERNO/ex288/webapp-s2i.git" /tmp/ws && cd /tmp/ws
sed -i 's|^  echo "built-at=.*|&\n  echo "custom=yes" >> build-info.txt|' .s2i/bin/assemble
cat .s2i/bin/assemble                           # confira
git add .s2i/bin/assemble && git update-index --chmod=+x .s2i/bin/assemble
git -c user.name=aluno -c user.email=a@example.invalid commit -m "assemble: custom=yes" && git push origin main
oc start-build s2i1 --follow
curl -s "http://$(oc get route s2i1 -o jsonpath='{.spec.host}')/build-info"    # ... custom=yes
```

Se o script perder o bit de execução o build falha com `Permission denied`: `git ls-files -s .s2i/bin/assemble` deve mostrar o modo `100755`.

## Validar e limpar

```bash
bash scripts/validar-03.sh && bash scripts/limpar-03.sh
```
