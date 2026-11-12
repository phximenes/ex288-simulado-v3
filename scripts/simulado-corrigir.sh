#!/usr/bin/env bash
# simulado-corrigir.sh - corrige o simulado (A ou B): pontuacao por task e total. Somente leitura.
# Uso: bash scripts/simulado-corrigir.sh A|B      (T8 so pontua se o Pipelines Operator existir)
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
V="${1:-}"; case "$V" in A|B) ;; *) die "uso: simulado-corrigir.sh A|B" ;; esac
v="$(echo "$V" | tr 'A-Z' 'a-z')"; P="ex288-v3-s${v}-t"
require_login
GOT=0; TOT=0; TGOT=0; TTOT=0
n1="${P}1"; n2="${P}2"; n3="${P}3"; n4="${P}4"; n5="${P}5"; n6="${P}6"; n7="${P}7"; n8="${P}8"

pts() {  # <pontos> <descricao> <funcao...>
  local n="$1" d="$2"; shift 2
  TOT=$((TOT+n)); TTOT=$((TTOT+n))
  if ( "$@" ) >/dev/null 2>&1; then GOT=$((GOT+n)); TGOT=$((TGOT+n)); printf '   +%-2s %s\n' "$n" "$d"; else printf '   +0  %s (de %s)\n' "$d" "$n"; fi
}
task()    { TGOT=0; TTOT=0; echo "T$1 - $2"; }
endtask() { echo "   => $TGOT / $TTOT"; echo; }

# ---- helpers ----
dep()  { val "$1" deployment "$2" "{.spec.template.spec.containers[0].$3}"; }          # <ns> <deploy> <caminho>
envk() { dep "$1" "$2" "env[?(@.name==\"$3\")].valueFrom.$4"; }                        # <ns> <deploy> <VAR> <configMapKeyRef.key|secretKeyRef.key|...>
budget() { echo $(( $(dep "$1" "$2" "$3.failureThreshold") * $(dep "$1" "$2" "$3.periodSeconds") )); }
clean_pods() {  # <ns> <app> [minimo-de-replicas]
  local r; [ "$(ready_replicas "$1" "$2")" -ge "${3:-1}" ] || return 1
  for r in $(pod_restarts "$1" "$2"); do [ "$r" -eq 0 ] || return 1; done
}
edge_redirect() { [ "$(route_tls "$1" "$2")" = edge ] && [ "$(val "$1" route "$2" '{.spec.tls.insecureEdgeTerminationPolicy}')" = Redirect ]; }
https_has() { [[ "$(http_body "https://$(route_host "$1" "$2")/")" == *"$3"* ]]; }   # <ns> <route> <texto>
revs()  { oc get secret -n "$1" -l "owner=helm,name=$2" --no-headers 2>/dev/null | wc -l | tr -d ' '; }
rdep()  { oc get secret -n "$1" -l "owner=helm,name=$2,status=deployed" --no-headers 2>/dev/null | wc -l | tr -d ' '; }
succeeded() {  # <ns> <pipeline>
  oc get pipelinerun -n "$1" -l "tekton.dev/pipeline=$2" -o jsonpath='{range .items[*]}{.status.conditions[0].reason}{"\n"}{end}' 2>/dev/null | grep -qx Succeeded
}
ntasks() { val "$1" pipeline "$2" '{.spec.tasks[*].name}' | wc -w | tr -d ' '; }
nexus_in() { [[ "$1" == *"$(nexus_host)"* ]]; }

# ---- variante A ----
a1a() { [ "$(val $n1 bc portal '{.spec.source.git.ref}')" = dev ] && [ -n "$(val $n1 bc portal '{.spec.source.sourceSecret.name}')" ] && build_complete $n1 portal && [ "$(ready_replicas $n1 portal)" -ge 1 ]; }
a1b() { env_list $n1 portal | grep -qx APP_MESSAGE=sim-a && for k in deployment service bc; do [ "$(val $n1 $k portal '{.metadata.labels.tier}')" = web ] || return 1; done; }
a1c() { route_has $n1 portal '"branch":"dev"' && route_has $n1 portal '"message":"sim-a"' && edge_redirect $n1 portal-tls && https_has $n1 portal-tls dev; }
a2a() { [ "$(val $n2 bc shop '{.spec.strategy.type}')" = Docker ] && [ "$(val $n2 bc shop '{.spec.output.to.name}')" = shop:2.0 ] && nexus_in "$(val $n2 bc shop '{.spec.strategy.dockerStrategy.buildArgs[?(@.name=="NPM_REGISTRY")].value}')" && build_complete $n2 shop; }
a2b() { [ "$(ready_replicas $n2 shop)" -ge 1 ] && oc get istag shop:2.0 -n $n2 >/dev/null; }
a2c() { route_has $n2 shop '"app":"webapp-docker"' && ! route_has $n2 shop '"uid":0,'; }
a3a() { [ "$(val $n3 bc catalog '{.spec.strategy.type}')" = Source ] && [ -n "$(val $n3 bc catalog '{.spec.source.sourceSecret.name}')" ] && build_complete $n3 catalog && [ "$(ready_replicas $n3 catalog)" -ge 1 ]; }
a3b() { route_has $n3 catalog "$(nexus_host)" /build-info; }
a3c() { route_has $n3 catalog '"message":"catalog-a"'; }
a4a() { [ "$(val $n4 cm catalog-cfg '{.data.GREETING}')" = SimA ] && [ "$(val $n4 cm catalog-cfg '{.data.API_HOST}')" = http://catalog:8080 ] && route_has $n4 cfgapp '"greeting":"SimA"' && route_has $n4 cfgapp '"apiHost":"http://catalog:8080"'; }
a4b() { [ "$(envk $n4 cfgapp DB_USER secretKeyRef.key)" = login ] && [ "$(envk $n4 cfgapp DB_PASSWORD secretKeyRef.key)" = secret ] && route_has $n4 cfgapp '"dbUser":"svc"' && route_has $n4 cfgapp '"hasPassword":true'; }
a4c() { [ "$(dep $n4 cfgapp 'volumeMounts[?(@.mountPath=="/etc/catalog")].readOnly')" = true ] && oc exec -n $n4 deploy/cfgapp -- cat /etc/catalog/app.properties | grep -qx 'mode=sim'; }
a5a() { [ "$(dep $n5 slowapp startupProbe.httpGet.path)" = /healthz ] && [ "$(budget $n5 slowapp startupProbe)" -ge 45 ]; }
a5b() { [ "$(dep $n5 slowapp livenessProbe.periodSeconds)" = 8 ] && [ "$(dep $n5 slowapp livenessProbe.timeoutSeconds)" = 2 ] && [ "$(dep $n5 slowapp livenessProbe.failureThreshold)" = 3 ] && [ "$(dep $n5 slowapp readinessProbe.httpGet.path)" = /ready ] && [ "$(dep $n5 slowapp readinessProbe.periodSeconds)" = 4 ]; }
a5c() { clean_pods $n5 slowapp 2 && [ "$(ready_replicas $n5 slowapp)" = 2 ] && route_has $n5 slowapp slowapp; }
a6a() { exists $n6 template webapp-template; }
a6b() { [ "$(ready_replicas $n6 orders)" = 2 ] && route_has $n6 orders sim-a; }
a6c() { for k in deployment route secret; do :; done; [ "$(val $n6 deployment orders-dev '{.metadata.labels.env}')" = dev ] && [ "$(val $n6 route orders-dev '{.metadata.labels.env}')" = dev ] && [ "$(val $n6 secret orders-dev-token '{.metadata.labels.env}')" = dev ] && route_has $n6 orders-dev dev; }
a7a() { [ "$(rdep $n7 inventory)" = 1 ] && [ "$(ready_replicas $n7 inventory-hello)" -ge 1 ]; }
a7b() { [ "$(revs $n7 inventory)" -ge 2 ] && route_has $n7 inventory-hello 'hello from helm v2'; }
a7c() { [ "$(ready_replicas $n7 inventory-hello)" = 2 ]; }
a8a() { [ "$(ntasks $n8 sim-ci)" -ge 3 ] && [ -n "$(val $n8 pipeline sim-ci '{.spec.params[?(@.name=="TARGET")].name}')" ] && succeeded $n8 sim-ci; }
a8b() { [ "$(val $n8 pipeline sim-build '{.spec.tasks[0].taskRef.resolver}')" = cluster ] && succeeded $n8 sim-build; }
a8c() { [ "$(ready_replicas $n8 simapp)" -ge 1 ] && route_has $n8 simapp webapp-docker; }

# ---- variante B ----
b1a() { [ "$(val $n1 bc gateway '{.spec.source.contextDir}')" = api ] && [ -n "$(val $n1 bc gateway '{.spec.source.sourceSecret.name}')" ] && build_complete $n1 gateway && [ "$(ready_replicas $n1 gateway)" -ge 1 ]; }
b1b() { [ "$(val $n1 bc static '{.spec.source.contextDir}')" = site ] && [[ "$(val $n1 bc static '{.spec.strategy.sourceStrategy.from.name}')" == httpd* ]] && build_complete $n1 static && [ "$(ready_replicas $n1 static)" -ge 1 ]; }
b1c() { env_list $n1 gateway | grep -qx APP_MESSAGE=sim-b && [ "$(val $n1 deployment gateway '{.metadata.labels.tier}')" = edge ] && route_has $n1 gateway '"message":"sim-b"' && edge_redirect $n1 static-tls; }
b2a() { [ "$(val $n2 bc legacy '{.spec.strategy.dockerStrategy.dockerfilePath}')" = Dockerfile.root ] && [ "$(build_count $n2 legacy)" -ge 2 ] && [ "$(ready_replicas $n2 legacy)" -ge 1 ] && route_has $n2 legacy '"app":"webapp-docker"'; }
b2b() { nexus_in "$(val $n2 bc legacy '{.spec.strategy.dockerStrategy.buildArgs[?(@.name=="NPM_REGISTRY")].value}')"; }
b2c() { [ "$(val $n2 bc ledger '{.spec.source.type}')" = Binary ] && [ "$(ready_replicas $n2 ledger)" -ge 1 ] && route_has $n2 ledger 'site 1.0'; }
b3a() { local e; e="$(val $n3 bc reports '{.spec.strategy.sourceStrategy.env[?(@.name=="npm_config_registry")].value}')"; nexus_in "$e"; }
b3b() { build_complete $n3 reports && [ "$(ready_replicas $n3 reports)" -ge 1 ]; }
b3c() { route_has $n3 reports monorepo-api && route_has $n3 reports reports-b; }
b4a() { [ "$(val $n4 cm shop-cfg '{.data.GREETING}')" = SimB ] && [ "$(val $n4 cm shop-cfg '{.data.LANG_CODE}')" = en-US ] && route_has $n4 cfgapp '"greeting":"SimB"' && route_has $n4 cfgapp '"lang":"en-US"'; }
b4b() { [ "$(envk $n4 cfgapp DB_USER secretKeyRef.key)" = u ] && [ "$(envk $n4 cfgapp DB_PASSWORD secretKeyRef.key)" = p ] && route_has $n4 cfgapp '"dbUser":"shop"'; }
b4c() { local a b; a="$(secret_val $n4 shop-token value)"; b="$(secret_val ${P}4-shared shop-token value)"; [ -n "$a" ] && [ "$a" = "$b" ] && route_has $n4 cfgapp '"hasToken":true'; }
b5a() { [ "$(dep $n5 slowapp startupProbe.tcpSocket.port)" = 8080 ] && [ "$(dep $n5 slowapp readinessProbe.tcpSocket.port)" = 8080 ] && [ "$(budget $n5 slowapp startupProbe)" -ge 30 ]; }
b5b() { [ -n "$(dep $n5 slowapp livenessProbe.exec.command)" ] && clean_pods $n5 slowapp; }
b5c() { [ -n "$(dep $n5 slowbad livenessProbe)" ] && [ "$(budget $n5 slowbad startupProbe)" -ge 40 ] && clean_pods $n5 slowbad; }
b6a() { [ "$(val $n6 template stack '{.parameters[?(@.name=="NAME")].required}')" = true ] && [ -n "$(val $n6 template stack '{.parameters[?(@.name=="MESSAGE")].value}')" ] && [ -n "$(val $n6 template stack '{.parameters[?(@.name=="TOKEN")].generate}')" ] && [ "$(val $n6 template stack '{.objects[*].kind}' | wc -w | tr -d ' ')" -ge 4 ]; }
b6b() { [ "$(ready_replicas $n6 stack-a)" -ge 1 ] && [ "$(ready_replicas $n6 stack-b)" -ge 1 ] && [ "$(route_body $n6 stack-a)" != "$(route_body $n6 stack-b)" ]; }   # MESSAGE diferente => corpos diferentes
b6c() { [ "$(secret_val $n6 stack-a-token token | wc -c | tr -d ' ')" = 12 ] && [ "$(secret_val $n6 stack-b-token token | wc -c | tr -d ' ')" = 12 ] && [ "$(http_code "http://$(route_host $n6 stack-a)/")" = 200 ] && [ "$(http_code "http://$(route_host $n6 stack-b)/")" = 200 ]; }   # HTTP 200: a pagina 503 do router nao conta
b7a() { [ "$(rdep $n7 inventory)" = 1 ] && [ "$(ready_replicas $n7 inventory-hello)" -ge 1 ]; }
b7b() { [ "$(ready_replicas $n7 inventory-hello)" = 2 ] && route_has $n7 inventory-hello prod-b; }
b7c() { [ "$(revs $n7 inventory)" = 3 ]; }
b8a() { [ "$(val $n8 pipeline broken-ci '{.spec.tasks[?(@.name=="read")].runAfter[0]}')" = write ] && succeeded $n8 broken-ci; }
b8b() { [ "$(ntasks $n8 sim-ci)" -ge 2 ] && succeeded $n8 sim-ci; }
b8c() { local t; t="$(val $n8 bc native '{.spec.triggers[*].type}')"; [[ "$t" == *Generic* ]] && [[ "$t" == *ImageChange* ]] && [ -n "$(val $n8 bc native '{.spec.postCommit.script}{.spec.postCommit.command}')" ]; }

HAS_TEKTON=0; has_tekton && HAS_TEKTON=1
echo "=== Simulado $V ==="
START="$(val $n1 cm sim-start '{.data.epoch}')"
[ -n "$START" ] && echo "tempo decorrido: $(( ($(date +%s) - START) / 60 )) min (limite: 120 min)"
echo

if [ "$V" = A ]; then
  task 1 "Git (portal)"
  pts 4 "portal: S2I da branch dev com source secret, build Complete, pod pronto" a1a
  pts 4 "APP_MESSAGE=sim-a (runtime) e rotulo tier=web em BC, Deployment e Service" a1b
  pts 4 "rotas portal e portal-tls (edge + Redirect) respondem branch dev / sim-a" a1c; endtask
  task 2 "Dockerfile (shop)"
  pts 4 "BuildConfig shop (Docker), saida shop:2.0, ARG NPM_REGISTRY do Nexus, build Complete" a2a
  pts 4 "Deployment shop a partir da ImageStreamTag shop:2.0, pronto" a2b
  pts 4 "rota shop responde webapp-docker e nao roda como UID 0" a2c; endtask
  task 3 "S2I (catalog)"
  pts 4 "catalog: S2I Node.js do webapp-s2i com source secret, build Complete, pronto" a3a
  pts 4 "build usa o Nexus (build-env npm_config_registry); /build-info mostra o endereco" a3b
  pts 4 "APP_MESSAGE=catalog-a em runtime (sobrepoe .s2i/environment); rota responde" a3c; endtask
  task 4 "ConfigMap + Secret existente (catalog)"
  pts 4 "ConfigMap catalog-cfg (GREETING=SimA, LANG_CODE=pt-BR, API_HOST) injetado" a4a
  pts 4 "DB_USER <- catalog-db/login e DB_PASSWORD <- catalog-db/secret (secretKeyRef)" a4b
  pts 4 "ConfigMap catalog-files montado somente leitura em /etc/catalog" a4c; endtask
  task 5 "Probes (slowapp)"
  pts 4 "startup HTTP /healthz:8080 tolerando >= 45 s" a5a
  pts 4 "liveness /healthz (periodo 8, timeout 2, 3 falhas) e readiness /ready (periodo 4)" a5b
  pts 4 "slowapp com 2 replicas prontas, sem reinicios, rota responde" a5c; endtask
  task 6 "Templates (orders)"
  pts 4 "Template webapp-template cadastrado no projeto" a6a
  pts 4 "orders (--param-file: MESSAGE=sim-a, REPLICAS=2) com 2 replicas e rota" a6b
  pts 4 "orders-dev (MESSAGE=dev) com rotulo env=dev em todos os objetos" a6c; endtask
  task 7 "Helm (inventory, repositorio do Nexus)"
  pts 4 "release inventory (deployed) e inventory-hello pronto" a7a
  pts 4 "upgrade para 0.2.0: >= 2 revisoes e mensagem 'hello from helm v2'" a7b
  pts 4 "2 replicas prontas apos o upgrade" a7c; endtask
  task 8 "CI/CD (Pipelines)"
  if [ "$HAS_TEKTON" = 1 ]; then
    pts 6 "sim-ci com 3 tasks encadeadas e parametro TARGET; PipelineRun Succeeded" a8a
    pts 6 "sim-build: git-clone (resolver cluster) + buildah; PipelineRun Succeeded" a8b
    pts 4 "Deployment simapp com a imagem publicada e rota responde" a8c
  else echo "   (T8 nao pontuada: Pipelines Operator ausente)"; fi; endtask
else
  task 1 "Git (monorepo: gateway e static)"
  pts 4 "gateway: monorepo/api (S2I Node.js), source secret, build Complete, pronto" b1a
  pts 4 "static: monorepo/site (builder httpd), build Complete, pronto" b1b
  pts 4 "APP_MESSAGE=sim-b + tier=edge no gateway; rota static-tls edge com Redirect" b1c; endtask
  task 2 "Dockerfile (legacy e ledger)"
  pts 4 "legacy: Dockerfile.root corrigido (>= 2 builds), pod pronto, rota ok" b2a
  pts 4 "legacy: ARG NPM_REGISTRY apontando para o npm-public do Nexus" b2b
  pts 4 "ledger: build binario Docker com artefato do Nexus; rota mostra 'site 1.0'" b2c; endtask
  task 3 "S2I (reports)"
  pts 4 "reports: variavel de build corrigida para o Nexus (nao 127.0.0.1)" b3a
  pts 4 "build Complete e pod pronto" b3b
  pts 4 "APP_MESSAGE=reports-b em runtime; rota responde monorepo-api" b3c; endtask
  task 4 "ConfigMap + Secret existente + Secret de outro projeto (shop)"
  pts 4 "ConfigMap shop-cfg (GREETING=SimB, LANG_CODE=en-US) injetado por completo" b4a
  pts 4 "DB_USER <- shop-db/u e DB_PASSWORD <- shop-db/p (secretKeyRef)" b4b
  pts 4 "Secret shop-token recriado do outro projeto; API_TOKEN via secretKeyRef" b4c; endtask
  task 5 "Probes (slowapp e slowbad)"
  pts 4 "slowapp: startup e readiness TCP 8080 (startup >= 30 s)" b5a
  pts 4 "slowapp: liveness por comando (exec); Ready sem reinicios" b5b
  pts 4 "slowbad: liveness mantida + startup (>= 40 s); Ready sem reinicios" b5c; endtask
  task 6 "Templates (stack)"
  pts 4 "template stack: NAME obrigatorio, MESSAGE com padrao, TOKEN gerado, >= 4 objetos" b6a
  pts 4 "instancias stack-a e stack-b prontas" b6b
  pts 4 "tokens de 12 caracteres e rotas respondendo" b6c; endtask
  task 7 "Helm (inventory, pacote .tgz)"
  pts 4 "release inventory instalada do .tgz (deployed) e pronta" b7a
  pts 4 "valores de arquivo (-f): replicaCount=2 e message=prod-b" b7b
  pts 4 "upgrade + rollback: 3 revisoes" b7c; endtask
  task 8 "CI/CD"
  if [ "$HAS_TEKTON" = 1 ]; then
    pts 6 "broken-ci corrigido (runAfter e workspace); PipelineRun Succeeded" b8a
    pts 6 "sim-ci com 2 tasks encadeadas; PipelineRun Succeeded" b8b
    pts 4 "BuildConfig native: triggers Generic + ImageChange e post-commit hook" b8c
  else echo "   (T8 nao pontuada: Pipelines Operator ausente)"; fi; endtask
fi
echo "TOTAL: $GOT / $TOT  ($(( TOT > 0 ? GOT * 100 / TOT : 0 ))%)"
if [ "$TOT" -gt 0 ] && [ $(( GOT * 100 / TOT )) -ge 70 ]; then echo "Referencia de aprovacao 70% (HIPOTESE; confirme o criterio vigente com a Red Hat): ATINGIDA"; else echo "Referencia de aprovacao 70% (HIPOTESE): nao atingida"; fi
