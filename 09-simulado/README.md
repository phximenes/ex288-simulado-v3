[← T8](../08-cicd-pipelines/README.md) | [índice](../README.md) | [anexo →](../10-outros-objetivos/README.md)

# Simulado — 8 tasks, 2 horas, duas variantes (A e B)

Reproduz o formato relatado `[RELATO PESSOAL]`: **8 tasks na mesma ordem (T1–T8), independentes entre si**, cada uma com **3 subtarefas**, usando o **Git interno privado** e o **Nexus**. O tempo é de **2 h** (margem para um ambiente lento; a prova real tem 3 h na versão 4.18 e 4 h na 4.22). Os enunciados são **originais** (tema, não texto de prova).

| | Variante A | Variante B |
|---|---|---|
| Enunciado | [A/enunciado.md](A/enunciado.md) | [B/enunciado.md](B/enunciado.md) |
| Solução | [A/solucao.md](A/solucao.md) | [B/solucao.md](B/solucao.md) |
| Projetos | `ex288-v3-sa-t1` … `sa-t8` | `ex288-v3-sb-t1` … `sb-t8` (+ `sb-t4-shared`) |

## Como rodar

```bash
bash scripts/infra-up.sh                    # uma vez: Git privado + Nexus
bash scripts/simulado-preparar.sh A         # cria os 8 projetos e marca o inicio (cronometre 2 h)
#  ... resolva as 8 tasks lendo 09-simulado/A/enunciado.md ...
bash scripts/simulado-corrigir.sh A         # pontuacao por task e total (somente leitura)
bash scripts/simulado-limpar.sh A           # remove os projetos do simulado e os arquivos soltos que as soluções deixam na raiz
```

Credenciais do Git e do Nexus: `bash scripts/credenciais.sh --show`.

Se algum projeto do simulado sumir no meio da prova (`You are not a member of project`), recrie **só** os que faltam, sem tocar nos outros e sem reiniciar o cronômetro: `SIM_ONLY="4 5" bash scripts/simulado-preparar.sh A` (números das tasks). Rodar o `simulado-preparar.sh` inteiro de novo também preserva o início já marcado; para zerar o relógio, rode antes `simulado-limpar.sh`. Se o projeto ainda estiver em remoção (`Terminating`), espere terminar. Atenção: recriar uma task devolve o estado **inicial** dela (o que você já tinha feito naquele projeto se perdeu).

## Pontuação (100 pontos)

T1–T7: **12 pontos** cada (3 subtarefas × 4); T8: **16 pontos** (6 + 6 + 4). A T8 só pontua se o Pipelines Operator existir (senão o total é calculado sobre o máximo possível). A referência de aprovação de 70% é `HIPÓTESE`: confirme o critério vigente com a Red Hat. A nota é por **estado final** do cluster; builds precisam estar `Complete`, pods `Ready`, rotas respondendo.

> [!NOTE]
> Regras do treino (para simular o ambiente): um terminal só, sem Alt+Tab, copiar/colar com o mouse, só a documentação oficial. Leia as 8 tasks antes de começar e use a [estratégia](../00-guia/estrategia-de-prova.md).

## Status de validação (`VERIFICADO` no CRC 4.22.14 ampliado)

| Variante | Corretor **antes** da solução | Corretor **depois** | Observação |
|---|---|---|---|
| A | `0 / 84 (0%)` | **`84 / 84 (100%)`** | T1–T7 executadas de verdade (Git privado, builds, Nexus, helm); a T8 foi rodada à parte (`16/16`, abaixo) |
| B | `0 / 84 (0%)` | **`84 / 84 (100%)`** | idem |

As soluções de `A/solucao.md` e `B/solucao.md` foram executadas como `developer` (impersonado). **T8 dos simulados** (depois que você instalou o Pipelines Operator): A **`16/16`** (`sim-ci` com 3 tasks e `TARGET`, `sim-build` com `git-clone`+`buildah`, `simapp` respondendo) e B **`16/16`** (`broken-ci` corrigido, `sim-ci`, BuildConfig `native`) — executadas em rodada separada; T1–T7 `84/84` cada, logo **100/100** por composição (as duas rodadas não foram feitas juntas). Veja o [relatório final](../_meta/RELATORIO-FINAL.md).
