[← T5](../05-probes/README.md) | [índice](../README.md) | [T7 →](../07-helm/README.md)

# T6 — Deploy de aplicação a partir de um Template

|                        |                                                                                                                                                                                                 |
| ---------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Task relatada**      | "Deploy de aplicação a partir de Template" `[RELATO PESSOAL]`                                                                                                                                   |
| **Objetivos oficiais** | "Create an OpenShift template" · "Use pre-existing templates written in either JSON or YAML format" · "Work with multi-container templates" · "Add custom parameters to a template" `[OFICIAL]` |
| **Projeto**            | `ex288-v3-t6` · `bash scripts/preparar-06.sh` · `validar-06.sh` · `limpar-06.sh`                                                                                                                |
| **Pré-requisito**      | CRC; o E4 usa o Git interno (builds)                                                                                                                                                            |

## Caminho mais rápido na prova

```bash
oc project ex288-v3-t6
oc process --parameters -f webapp-template.yaml                       # quais parametros existem / obrigatorios
oc process -f webapp-template.yaml -p NAME=tpl1 -p MESSAGE=ola -p REPLICAS=2 | oc apply -f -
oc get all,secret -l template=webapp-template
```

Equivalente em um passo: `oc new-app -f webapp-template.yaml -p NAME=tpl1 -p …`. Para templates **já cadastrados**: `oc get templates -n openshift` e `oc new-app --template=openshift/httpd-example -p NAME=site`.

## Variações prováveis

| Variação | Comando | Verificar |
|---|---|---|
| Listar parâmetros | `oc process --parameters -f t.yaml` · `oc process --parameters httpd-example -n openshift` | saída com `NAME`, `GENERATOR`, `VALUE` |
| Passar parâmetros | `-p K=V` (repetível) · `--param-file=params.env` (`K=V` por linha) | `oc get deploy -o yaml` |
| Template de arquivo (YAML **ou** JSON) | `oc process -f t.json …` · `oc new-app -f t.yaml` | idem |
| Cadastrar no projeto | `oc create -f t.yaml` e depois `oc new-app --template=NOME -p …` | `oc get template` |
| Cadastrar globalmente | só admin: `oc create -f t.yaml -n openshift` | — |
| Sem servidor | `oc process -f t.yaml --local -p NAME=x` | — |
| Parâmetro gerado | `generate: expression` + `from: "[a-zA-Z0-9]{16}"` | `oc get secret NOME-token -o jsonpath='{.data.token}' \| base64 -d \| wc -c` (16) |
| Número como número | `${{REPLICAS}}` (sem aspas no objeto) em vez de `${REPLICAS}` | `oc get deploy -o jsonpath='{.items[0].spec.replicas}'` |
| Rótulos do template | `labels:` no Template → vão para todos os objetos | `oc get all -l template=webapp-template` |
| Criar seu template | `oc get deploy,svc,route -o yaml` limpo + `parameters:` ou escreva do zero | `oc process -f novo.yaml --parameters` |
| Converter YAML ↔ JSON | `oc create -f t.yaml --dry-run=client -o json` | — |
| Ignorar parâmetro desconhecido | `--ignore-unknown-parameters` | — |

## Armadilhas e diagnóstico

| Sintoma | Causa |
|---|---|
| `error: unable to process template: ... required parameter NAME` / "parameter is required" | parâmetro `required: true` sem valor |
| `processedtemplates ... is forbidden ... in the namespace "default"` (`VERIFICADO` no CRC) | `oc process` usa o **projeto atual**; sem `oc project NS` ou `-n NS` ele tenta processar em `default` → rode `oc project ex288-v3-t6` antes (ou `oc process -n NS`) |
| `unknown parameter name "X"` | typo em `-p X=…` (use `--parameters`) |
| `replicas: "2"` rejeitado | usou `${REPLICAS}` onde precisa de número → `${{REPLICAS}}` |
| Reaplicar o mesmo `oc process \| oc apply` trocou a senha | `generate: expression` gera um **novo** valor a cada `process`; fixe com `-p TOKEN=…` |
| `Forbidden` ao processar template do `openshift` | falta de acesso no namespace do template; use `--template=openshift/NOME` (o `oc new-app` resolve) |
| Objetos criados no projeto errado | `oc project`; objetos de `oc process` não levam namespace (vão no projeto atual) |
| Imagem do template não existe | confira `image:`/ImageStream do template (`oc describe template`) |

## Onde achar na documentação (OCP 4.22)

- Building applications → 3.1 *Using templates* (escrever, enviar, instanciar): <https://docs.redhat.com/en/documentation/openshift_container_platform/4.22/html-single/building_applications/index#using-templates>
- Referência de campos: <https://docs.redhat.com/en/documentation/openshift_container_platform/4.22/html-single/template_apis/index> e `oc explain template`
- Referência `oc process`: <https://docs.redhat.com/en/documentation/openshift_container_platform/4.22/html-single/cli_tools/index#oc-process>

## Variante com Git interno

O template `httpd-example` do namespace `openshift` aponta para um repositório no GitHub; na prova o código vem do Git interno. Passe `SOURCE_REPOSITORY_URL` (e dê ao BuildConfig o source secret, E4).

Próximo: [exercícios](exercicios.md) · [solução](solucao.md)
