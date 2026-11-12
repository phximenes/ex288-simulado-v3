[← README](README.md) | [índice](../README.md) | [solução →](solucao.md)

# T7 — Exercícios

Preparação: `bash scripts/preparar-07.sh` (cria `ex288-v3-t7`). Chart local: `apps/helm/ex288-hello` (valores `replicaCount`, `message`, `image.*`, `route.enabled`; recursos chamados `<release>-hello`). Validar: `bash scripts/validar-07.sh`. O `helm` precisa estar no PATH.

**E1 — Instalar um chart local.**
Instale o chart como release **`rel1`** no projeto `ex288-v3-t7` com **2 réplicas** e a mensagem `ola helm`. O Deployment `rel1-hello` deve ter 2 réplicas prontas e a Route `rel1-hello` deve responder `ola helm`.

**E2 — Arquivo de valores, upgrade e rollback.**
Instale o chart como **`rel2`** usando um **arquivo de valores** seu (`replicaCount: 1`, `message: first`). Faça um `upgrade` mudando a mensagem para `second` e depois um **rollback para a revisão 1**. Ao final a release deve ter **3 revisões**, estar `deployed` e a Route `rel2-hello` deve responder `first`.

**E3 — Pacote `.tgz`.**
Gere o pacote do chart (`helm package`) e instale-o a partir do arquivo `.tgz` como **`rel3`**, sobrescrevendo `message=from-tgz`. A Route `rel3-hello` deve responder `from-tgz`.

**E4 — Repositório de charts no Nexus (requer Nexus).**
O Nexus tem um repositório Helm hospedado (`helm-hosted`, exige usuário e senha). Adicione-o como repositório do helm, liste as versões do chart `ex288-hello` e instale a versão **0.2.0** como **`rel4`**. Sem sobrescrever a mensagem, a Route `rel4-hello` deve responder `hello from helm v2`.
