[← README](README.md) | [índice](../README.md) | [solução →](solucao.md)

# T8 — Exercícios

Preparação: `bash scripts/preparar-08.sh` (exige o Pipelines Operator; cria `ex288-v3-t8`, o Secret `git-basic-auth` anotado para o Tekton, o vínculo com a SA `pipeline` e o pipeline defeituoso `broken-ci`). Validar: `bash scripts/validar-08.sh`.

**E1 — Pipeline com duas tasks encadeadas.**
Crie o Pipeline **`mini-ci`** com duas tasks encadeadas por `runAfter` (task `prepare` e task `verify`; use `taskSpec` embutido e a imagem `registry.access.redhat.com/ubi9/ubi-minimal:latest`) e um parâmetro `MESSAGE` com valor padrão. Execute-o com um PipelineRun (sem `tkn`) até `Succeeded`.

**E2 — Git → build → deploy.**
Crie o Pipeline **`build-and-deploy`** que (1) clona o repositório privado `webapp-docker` do Git interno com a task fornecida pelo Operator, (2) faz o build da imagem com o `Dockerfile` e publica em `image-registry.openshift-image-registry.svc:5000/ex288-v3-t8/ci-app:latest`, (3) faz o deploy da aplicação **`ci-app`**. Use um workspace `shared` com `volumeClaimTemplate`. Depois de um PipelineRun `Succeeded`, a Route `ci-app` deve responder `"app":"webapp-docker"`.

**E3 — Depurar um pipeline que não roda.**
O Pipeline **`broken-ci`** (já aplicado, ou rejeitado ao ser aplicado) tem dois defeitos. Corrija-o **no lugar** e obtenha um PipelineRun `Succeeded` que leia o arquivo escrito pela primeira task.

**E4 — Gatilhos nativos de build (variação; requer Git interno e builds).**
No projeto, crie o BuildConfig **`native`** (S2I Node.js, repositório `webapp` do Git interno, source secret) com: trigger **Generic** (webhook), trigger **ImageChange** e um **post-commit hook** que roda `npm test`. Dispare um build chamando o webhook Generic com `curl` (sem `oc start-build`) e confirme no log do build o `TESTS PASSED`.
