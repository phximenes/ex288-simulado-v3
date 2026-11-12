[← dia da prova](dia-da-prova.md) | [índice](../README.md)

# Cheatsheet (comandos por task) — conferidos com `-h` do `oc` 4.22.14

> Flags `VERIFICADO` em `oc … -h`: `new-app --source-secret/--build-env/--strategy/--template/--param-file/-l/--context-dir`, `new-build --binary/--to/--build-arg`, `set build-secret --source`, `set probe --startup/--open-tcp`, `create route edge --insecure-policy`, `process --param-file/--parameters/--local`, `start-build --from-dir/--from-archive/--follow/--wait`. **`oc set env` não tem `--keys`.**

## Geral
```bash
oc whoami; oc project; oc project NS; oc get all,route
oc get events --sort-by=.lastTimestamp | tail -15
oc describe X NOME | tail -30 ; oc logs POD --previous --tail=50
oc explain RECURSO.campo --recursive ; oc COMANDO -h
```

## T1 Git
```bash
git config --global credential.helper 'cache --timeout=3600' ; git ls-remote URL     # o oc new-app clona no CLIENTE (repo privado ABORTA sem credencial)
oc create secret generic git-creds --type=kubernetes.io/basic-auth --from-literal=username=U --from-literal=password=P
oc new-app --name N --source-secret git-creds --image-stream openshift/nodejs:22-ubi9 --code URL[#branch] [--context-dir D] [-l k=v] [-e K=V]
oc new-app --name S --source-secret git-creds --context-dir site "openshift/httpd:2.4-ubi9~URL"   # sem linguagem detectavel: builder~URL
oc set build-secret --source bc/N git-creds ; oc start-build N --follow
oc expose service N ; oc create route edge N-tls --service=N --insecure-policy=Redirect
```

## T2 Dockerfile
```bash
oc new-app --name N --source-secret git-creds --strategy docker --code URL
oc new-build --name N --strategy docker --code URL --to N:1.0 --build-arg K=V
oc patch bc/N -p '{"spec":{"strategy":{"dockerStrategy":{"dockerfilePath":"Dockerfile.x"}}}}'
oc new-build --binary --strategy docker --name N ; oc start-build N --from-dir=. --follow
HOST=$(oc registry info --public) ; podman login -u developer -p "$(oc whoami -t)" $HOST ; podman build -t $HOST/NS/IMG:T . ; podman push $HOST/NS/IMG:T   # developer nao le a route do registry
# UID arbitrario: USER 1001 ; RUN chgrp -R 0 /dir && chmod -R g=u /dir ; porta > 1024
```

## T3 S2I
```bash
oc get is -n openshift | grep -E 'nodejs|httpd|python|java'
oc new-app --name N --image-stream openshift/nodejs:22-ubi9 --code URL --build-env npm_config_registry=http://NEXUS/repository/npm-public/
oc set env bc/N npm_config_registry=URL ; oc start-build N --follow
# repo: .s2i/environment, .s2i/bin/assemble (chama /usr/libexec/s2i/assemble), .s2i/bin/run (git update-index --chmod=+x)
```

## T4 ConfigMap + Secret existente
```bash
oc get secret ; oc describe secret S ; oc extract secret/S --to=-
oc create configmap C --from-literal=K=V [--from-file=f]
oc set env deploy/D --from=configmap/C [--prefix=P_] ; oc set env deploy/D --from=secret/S [--prefix=P_]   # sem --keys!
oc edit deploy/D          # env: - name: X / valueFrom: / secretKeyRef: {name: S, key: k}   (oc explain deploy.spec.template.spec.containers.env.valueFrom.secretKeyRef)
oc patch deploy/D -p 'spec: {template: {spec: {containers: [{name: C, env: [{name: X, valueFrom: {secretKeyRef: {name: S, key: k}}}]}]}}}'   # YAML, VERIFICADO; sem indice nem op
# Console: Workloads > Deployments > D > Environment > Add from ConfigMap or Secret   (NAO VERIFICADO)
oc set volume deploy/D --add --name=v --type=configmap --configmap-name=C --mount-path=/etc/x --read-only=true
oc set env deploy/D --list ; oc rollout status deploy/D
# Secret em outro projeto: oc get secret S -n OUTRO -o jsonpath='{.data.k}' | base64 -d  -> recrie no seu projeto
```

## T5 Probes
```bash
oc set probe deploy/D --startup   --get-url=http://:8080/healthz --period-seconds=2 --failure-threshold=30
oc set probe deploy/D --liveness  --get-url=http://:8080/healthz --period-seconds=10 --timeout-seconds=2 --failure-threshold=3
oc set probe deploy/D --readiness --open-tcp=8080 --period-seconds=5
oc set probe deploy/D --liveness -- cat /proc/1/cmdline      ; oc set probe deploy/D --remove --liveness
# startup: failureThreshold x period = tempo maximo de partida ; liveness/startup: successThreshold = 1
```

## T6 Templates
```bash
oc process --parameters -f T.yaml ; oc get templates -n openshift
oc process -f T.yaml -p NAME=x -p REPLICAS=2 | oc apply -f -
oc create -f T.yaml ; oc new-app --template=NOME --param-file=p.env     # K=V por linha
oc new-app --template=openshift/httpd-example -p NAME=x -p SOURCE_REPOSITORY_URL=URL
# ${PARAM} = texto ; ${{PARAM}} = numero/bool ; generate: expression ; from: "[a-zA-Z0-9]{16}"
```

## T7 Helm
```bash
helm repo add R URL --username U --password P ; helm repo update ; helm search repo CHART --versions
helm show values R/CHART --version V ; helm template REL R/CHART -f v.yaml ; helm lint ./chart
helm install REL R/CHART --version V -n NS --set a=b -f v.yaml ; helm upgrade --install REL ...
helm list -n NS ; helm history REL -n NS ; helm rollback REL N -n NS ; helm uninstall REL -n NS
helm package ./chart ; helm install REL ./chart-0.1.0.tgz
```

## T8 CI/CD
```bash
oc get task -n openshift-pipelines
oc get task git-clone -n openshift-pipelines -o jsonpath='{.spec.params[*].name}{"\n"}{.spec.workspaces[*].name}{"\n"}'
# taskRef: {resolver: cluster, params: [{name: kind, value: task},{name: name, value: git-clone},{name: namespace, value: openshift-pipelines}]}
oc create -f pipelinerun.yaml        # metadata.generateName ; spec.taskRunTemplate.serviceAccountName: pipeline ; workspaces com volumeClaimTemplate
oc get pipelinerun,taskrun ; oc logs --tail=100 -l tekton.dev/pipelineRun=NOME --all-containers --prefix
oc set triggers bc/N --from-webhook ; oc set build-hook bc/N --post-commit --script='npm test' ; oc describe bc N
```

## Diagnóstico rápido
`ImagePullBackOff` → nome/tag/secret · `CrashLoopBackOff` → `oc logs --previous`, probes · `CreateContainerConfigError` → ConfigMap/Secret/chave · `Pending` → eventos (PVC, recursos, taints) · build `Failed` → `oc logs -f bc/N` · rota 503 → `oc get endpoints N`.
