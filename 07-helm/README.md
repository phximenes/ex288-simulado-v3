[← T6](../06-templates/README.md) | [índice](../README.md) | [T8 →](../08-cicd-pipelines/README.md)

# T7 — Deploy de aplicação com Helm

|                        |                                                                                                          |
| ---------------------- | -------------------------------------------------------------------------------------------------------- |
| **Task relatada**      | "Deploy de aplicação com Helm" `[RELATO PESSOAL]` (o repositório de charts pode ser o Nexus: `HIPÓTESE`) |
| **Objetivos oficiais** | "Create and use Helm charts" `[OFICIAL]`                                                                 |
| **Projeto**            | `ex288-v3-t7` · `bash scripts/preparar-07.sh` · `validar-07.sh` · `limpar-07.sh`                         |
| **Pré-requisito**      | `helm` no WSL; Nexus (E4) com o chart `ex288-hello` 0.1.0 e 0.2.0 (carregados por `infra-up.sh`)         |

## Caminho mais rápido na prova

```bash
oc project ex288-v3-t7
helm repo add meu-repo URL --username USUARIO --password SENHA     # se houver repositório
helm repo update && helm search repo ex288-hello --versions
helm show values meu-repo/ex288-hello --version 0.2.0 | head -30  # veja o que dá para sobrescrever
helm install rel3 meu-repo/ex288-hello --version 0.2.0 -n ex288-v3-t7 --set replicaCount=2
helm list -n ex288-v3-t7 ; oc get all -n ex288-v3-t7 -l app=rel3-hello
```

## Variações prováveis

| Variação | Comando | Verificar |
|---|---|---|
| Chart local (diretório) | `helm install rel1 ./ex288-hello -n NS --set k=v` | `helm list -n NS` |
| Arquivo de valores | `helm install … -f values-prod.yaml` (várias vezes `-f`; a última vence; `--set` vence os arquivos) | `helm get values rel -n NS` |
| Versão específica | `--version 0.1.0` | `helm list` (coluna CHART) |
| Upgrade / histórico / rollback | `helm upgrade rel CHART --set k=v` · `helm history rel` · `helm rollback rel 1` (cria uma **nova** revisão) | `helm history rel -n NS` |
| Instalar ou atualizar | `helm upgrade --install rel CHART` | — |
| Ver antes de aplicar | `helm template rel CHART -f v.yaml` · `helm install … --dry-run` · `helm lint ./chart` | — |
| Pacote `.tgz` | `helm package ./ex288-hello` → `helm install rel ./ex288-hello-0.1.0.tgz` ou `helm pull REPO/CHART --untar` | arquivo `.tgz` |
| Criar projeto/namespace | `--create-namespace` (precisa permissão) | — |
| Desinstalar | `helm uninstall rel -n NS` | `oc get all` |
| Repositório do console (todos os projetos: admin) | `HelmChartRepository`; **do projeto:** `ProjectHelmChartRepository` com `connectionConfig.url` e `basicAuthConfig.name` (Secret no projeto) — ver abaixo | Developer → +Add → Helm Chart |
| Ajustes para OpenShift | chart que roda como root/porta < 1024 quebra na SCC `restricted-v2`: ajuste `securityContext`/portas via `values`; `Route` em vez de `Ingress` | `oc get pods` |

`ProjectHelmChartRepository` (campos `VERIFICADO` com `oc explain` no CRC: `spec.name`, `spec.connectionConfig.url`, `spec.connectionConfig.basicAuthConfig.name`):

```yaml
apiVersion: helm.openshift.io/v1beta1
kind: ProjectHelmChartRepository
metadata: {name: nexus-charts}
spec:
  name: Nexus charts
  connectionConfig:
    url: http://nexus.ex288-v3-infra.svc:8081/repository/helm-hosted/
    basicAuthConfig: {name: nexus-basic}     # Secret com username/password no mesmo projeto
```

> [!NOTE]
> Se o `helm` CLI não existir no host da prova, o caminho é o console (Developer → Helm) com um repositório cadastrado, ou `helm template … | oc apply -f -` num host que tenha helm. Nos relatos públicos que li não há nada sobre isso (`NÃO VERIFICADO`).
> Helm 3 × 4: o v3 foi escrito com helm 3.17–3.22 e exercitado com helm 4.3.1; `helm repo add/update/search/install/upgrade/rollback/history/template/show values` são os mesmos.

## Armadilhas e diagnóstico

| Sintoma | Causa |
|---|---|
| `Error: INSTALLATION FAILED: cannot re-use a name that is still in use` | release já existe → `helm list -A`, `helm uninstall` ou `upgrade --install` |
| `Error: failed to download "repo/chart"` / `401` | repo sem credencial ou URL sem `/` final | `helm repo add … --username --password`; `helm repo update` |
| `chart "x" matching version "" not found` | faltou `helm repo update` ou nome/versão errados | `helm search repo x --versions` |
| Instalou no projeto errado | `-n` esquecido (o helm usa o namespace do contexto) | `helm list -A` |
| `--set` não surtiu efeito | caminho de valor errado (`image.tag` ≠ `imageTag`) | `helm show values` / `helm get values REL -a` |
| Pod `CrashLoopBackOff` pelo chart | SCC (root/porta baixa) | `oc describe pod`, `oc logs` |
| Rollback "não voltou" | o rollback cria a revisão N+1 com a config da revisão alvo | `helm history` |

## Onde achar na documentação (OCP 4.22)

- Building applications → cap. 6 *Working with Helm charts* (repositórios, instalar, releases): <https://docs.redhat.com/en/documentation/openshift_container_platform/4.22/html-single/building_applications/index#working-with-helm-charts>
- Mesmo livro → *Creating a custom Helm chart on OpenShift* e *Configuring custom Helm chart repositories*.
- Sintaxe de templates do Helm: <https://helm.sh/docs/chart_template_guide/> · `helm <cmd> -h`

Próximo: [exercícios](exercicios.md) · [solução](solucao.md)
