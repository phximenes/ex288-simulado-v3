# Síntese dos relatos × relato do amigo

> Confiança: **alta** (várias fontes independentes ou oficial), **média**, **baixa** (uma fonte/antiga). Origem de cada afirmação entre colchetes. Fontes: [relatos.md](relatos.md).

## 1. Resposta às divergências do prompt

| Ponto | Relato do amigo | Página oficial hoje (2026-10-31) | Resolução | Confiança |
|---|---|---|---|---|
| Versão do OCP | "ex288v418k" (4.18) `[RELATO PESSOAL]` | **4.22** `[OFICIAL]` (EN e pt-BR); a mesma página avisa **"Multiple versions of this exam are in use"** | Não é contradição: **existem versões simultâneas**. A 4.18 que ele fez é uma versão anterior ainda em uso; listagens de terceiros ainda mostram "4.18" (`NÃO VERIFICADO` na fonte). Qual você pega depende da **versão designada no seu LMS** (PDF *Exam Objectives by Version*, que não consegui abrir). | alta (existência de várias versões); `HIPÓTESE` (qual será a sua) |
| Duração | 3 horas `[RELATO PESSOAL]` | **4 horas** `[OFICIAL]` | Coerente com versões diferentes: relatos antigos (4.12) e listagens de terceiros dizem 3 h `[RELATO PÚBLICO]`; a página atual diz 4 h. | média |
| Decisão para o v3 | — | — | **Preparar para o cenário mais exigente: 3 horas** (simulado em 2 h com folga, como pedido) e **escrever comandos válidos em 4.18 e 4.22**. Diferenças de comando entre 4.18 e 4.22 que afetam as 8 tasks entram nas páginas (T8: resolver/`ClusterTask`; T7: Helm; T1/T3: webhook e Samples Operator) depois de conferidas na doc oficial na Fase 3. | — |

## 2. O que converge com o amigo

| Tema | Evidência pública | Confiança |
|---|---|---|
| Ambiente lento; Alt+Tab ruim/inoperante | R2 (4.6) diz que Alt+Tab não funciona; R3 diz que o console é lento e que o navegador pode deixar o ambiente lento | média (antigo, mas consistente) |
| Preferir CLI | R3 | média |
| "O difícil é como a tarefa é pedida" | R1: vários candidatos falharam por interpretação/descompasso entre treino e prova; "leia com foco" | média |
| Documentação disponível durante a prova | O1 oficial; R3 | alta |
| Objetivos incluem Git, imagens/Dockerfile, S2I, ConfigMap/Secret, probes, Templates, Helm, Pipelines | O1 oficial (os 11 domínios cobrem T1–T8) | alta |
| Login/URLs de Git fornecidos pelo ambiente | R1 (candidato travou nas instruções de acesso ao Git) | baixa |

## 3. O que diverge ou não tem confirmação pública

| Ponto do amigo | Situação |
|---|---|
| **8 tasks, nessa ordem, independentes, com subtarefas** | **Sem confirmação pública** (provável efeito do NDA). Fica `[RELATO PESSOAL]`. |
| **Nexus em algumas tasks** | **Sem relato público.** Indício indireto `[OFICIAL]`: o courseware DO288 cita um Nexus da sala (mirror Maven/npm). Uso exato na prova: `HIPÓTESE`. |
| **Servidor Git interno** | Sem nome de produto em fonte pública; R1 sugere Git fornecido pelo ambiente. |
| **"Retake costuma ser igual à primeira prova"** | **Contradito** por R1: um candidato fez o retake em **outra versão (V410)** e passou. `[RELATO PÚBLICO]`, baixa confiança (1 caso, antigo). Não conte com repetição. |
| **Kustomize não caiu** | Kustomize **está** nos objetivos oficiais `[OFICIAL]`; fica como item de anexo (uma prova ≠ todas). |
| "Atividades tranquilas" | R1 mistura opiniões opostas (de "uma das melhores provas" a "não recomendo"): a dificuldade percebida varia por versão. |

## 4. Nível de confiança geral e limites

- **Poucos relatos confiáveis:** há 0 relatos públicos de candidatos da 4.22 e todos os relatos de candidatos são de 2021 e 2024. O que o v3 afirma sobre o formato da prova vem do **relato do amigo + objetivos oficiais**, não de confirmação pública.
- O único material da 4.22 achado é de **estudo** (R4, repositório de terceiros, 2026-10-29); trato como `[BOA PRÁTICA]` até conferir cada ponto na documentação oficial.
- Nada do que li reproduz enunciados de prova; nenhuma fonte foi descartada por violar NDA explicitamente (os sites de dumps foram descartados por serem dumps).
- **PDF oficial (V13):** inicialmente não estava no caminho informado; você reenviou em `D:\src\…\Red Hat Remote Exam Technical & Setup Guide (PDF eBook_V13).pdf` e eu o li inteiro. Ele **substitui** o blog de 2020 onde divergem (RAM 8 GB, pendrive ≥ 4 GB, 2 Mbps) e acrescenta a orientação de **não usar Ctrl+C/X/V** — o que muda a estratégia (evitar `-f`/`watch`). Itens que o PDF **não** traz e que só existem no relato do amigo: ligar o pendrive 30 min antes, aviso falso de tela cheia, escolha do layout de teclado.
