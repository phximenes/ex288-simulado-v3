[← exercícios](exercicios.md) | [índice](../README.md)

# T2 — Solução

> **Status:** `VALIDADO NO CLUSTER` (CRC 4.22.14, Gitea privado, Nexus, builds Docker reais). **E1–E4:** `developer` impersonado, antes `0 PASS / 5 FAIL`, depois `4 PASS` (+ E5). **E5:** executado no WSL RHEL 10.2 com `podman` 5.8.2 e o login real de `developer`: `PASS` (imagem de 258 MB, `istag pushed:1.0` criado, rota respondeu `"app":"webapp-docker"`); o push funcionou **com TLS verificado** (CA em `/etc/containers/certs.d/`, [pré-requisitos §9](../00-guia/preparar-wsl-rhel.md)). Respostas reais: `docker1` → `"uid":1000690000` (não é 0); `root-app` → `"dataDir":"/app/data"` depois da correção; `site-bin` → `site 1.0` (artefato baixado do Nexus `raw-hosted`); o pacote `ms` apareceu no `npm-proxy` do Nexus (mirror usado no `ARG`). **Sintoma do E3 verificado:** o pod novo fica em `CrashLoopBackOff` com `Error: EACCES … open '/app/data/started'` (SCC `restricted-v2`) enquanto o pod antigo segue `Running`. As soluções **alteram os repositórios** do Gitea (E3 e T1/T3): rode `bash scripts/infra-up.sh` de novo para restaurá-los.

```bash
oc project ex288-v3-t2
GIT=http://GIT-INTERNO/ex288 ; NEXUS=http://NEXUS-INTERNO
```

## E1 — `docker1`

```bash
oc new-app --name docker1 --source-secret git-creds --strategy docker --code "$GIT/webapp-docker.git"
oc logs -f bc/docker1
oc expose service docker1
curl -s "http://$(oc get route docker1 -o jsonpath='{.spec.host}')/"        # "uid":1000xxxxxx (nunca 0)
```

## E2 — mirror npm do Nexus via `ARG`

```bash
oc new-build --name docker-nexus --source-secret git-creds --strategy docker \
  --code "$GIT/webapp-docker.git" --to docker-nexus:1.0 \
  --build-arg NPM_REGISTRY="$NEXUS/repository/npm-public/"
oc logs -f bc/docker-nexus
# prova no Nexus (usuario admin; senha: scripts/credenciais.sh --show)
curl -su admin:SENHA "$NEXUS/service/rest/v1/search?repository=npm-proxy&name=ms" | grep -c '"name" *: *"ms"'
```

(`oc new-build` já inicia o 1º build. Se a opção `--build-arg` não existir no seu `oc`, confirme com `oc new-build -h` e use `oc start-build docker-nexus --build-arg NPM_REGISTRY=…`.)

## E3 — corrigir o Dockerfile para UID arbitrário

```bash
oc new-app --name root-app --source-secret git-creds --strategy docker --code "$GIT/webapp-docker.git"
oc patch bc/root-app -p '{"spec":{"strategy":{"dockerStrategy":{"dockerfilePath":"Dockerfile.root"}}}}'
oc start-build root-app --follow
oc expose service root-app
oc get pods -l deployment=root-app           # pod novo em CrashLoopBackOff (os pods do oc new-app usam deployment=NOME, nao app=)
oc logs POD-QUE-FALHA --tail=8               # Error: EACCES: permission denied, open '/app/data/started'
```

Causa: `/app/data` foi criado por root; sob `restricted-v2` o processo roda com UID aleatório (grupo 0). Correção no repositório (arquivo `Dockerfile.root`):

```dockerfile
RUN mkdir -p /app/data && npm install --omit=dev && chgrp -R 0 /app && chmod -R g=u /app
USER 1001
```

```bash
git clone "http://USUARIO:SENHA@GIT-INTERNO/ex288/webapp-docker.git" /tmp/wd && cd /tmp/wd
# edite Dockerfile.root como acima
git commit -am "dockerfile.root: permissoes para UID arbitrario" && git push origin main
oc start-build root-app --follow && oc rollout status deploy/root-app
```

## E4 — build binário com o artefato do Nexus

```bash
mkdir /tmp/sitebin && cd /tmp/sitebin
curl -u admin:SENHA -O "$NEXUS/repository/raw-hosted/ex288/site-1.0.tar.gz"
tar xzf site-1.0.tar.gz && rm site-1.0.tar.gz            # deixa index.html
printf 'FROM registry.access.redhat.com/ubi9/httpd-24\nCOPY index.html /var/www/html/\n' > Dockerfile
oc new-build --binary --strategy docker --name site-bin
oc start-build site-bin --from-dir=. --follow
oc new-app --image-stream site-bin:latest --name site-bin
oc expose service site-bin
curl -s "http://$(oc get route site-bin -o jsonpath='{.spec.host}')/"      # site 1.0
```

## E5 — `podman build` + `push` + deploy da ImageStream

```bash
HOST=$(oc registry info --public)        # depreciado, mas funciona para o developer (VERIFICADO)
podman login -u developer -p "$(oc whoami -t)" "$HOST"
git clone "http://USUARIO:SENHA@GIT-INTERNO/ex288/webapp-docker.git" /tmp/wd2 && cd /tmp/wd2
podman build -t "$HOST/ex288-v3-t2/pushed:1.0" -f Dockerfile .
podman push "$HOST/ex288-v3-t2/pushed:1.0"
oc get istag pushed:1.0
oc new-app --image-stream ex288-v3-t2/pushed:1.0 --name pushed && oc expose service pushed
```

> [!WARNING]
> **Armadilha `VERIFICADA`:** o `developer` **não** lê `oc get route default-route -n openshift-image-registry` (Forbidden); o host do registry sai de `oc registry info --public` (no CRC: `default-route-openshift-image-registry.apps-crc.testing`). Se o `push` reclamar do certificado, a CA não está confiada no WSL: use `--tls-verify=false` (aceitável no lab) ou o [§9](../00-guia/preparar-wsl-rhel.md). O `podman login` grava o token em `${XDG_RUNTIME_DIR}/containers/auth.json`; saia com `podman logout "$HOST"`.

Se a rota do registry não existir (precisa de admin): `oc patch configs.imageregistry.operator.openshift.io/cluster --type=merge -p '{"spec":{"defaultRoute":true}}'` — no CRC ela já existe (`VERIFICADO`).

## Validar e limpar

```bash
bash scripts/validar-02.sh && bash scripts/limpar-02.sh
```
