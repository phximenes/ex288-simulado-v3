[← estratégia](estrategia-de-prova.md) | [índice](../README.md) | [cheatsheet →](cheatsheet.md)

# Dia da prova — checklist (remota)

> Fonte principal: **Red Hat Remote Exam Technical & Setup Guide (eBook_V13)**, PDF oficial que você forneceu e eu li inteiro (19 páginas) — `[OFICIAL]`. Itens do seu amigo estão marcados `[RELATO PESSOAL]`. O blog de 2020 da Red Hat (`[OFICIAL]`, **desatualizado** por declaração do próprio post) só foi usado onde o V13 é omisso. **Antes de usar o PDF como verdade, confira se há uma versão mais nova**: o próprio guia diz para sempre baixar a ISO mais recente.

## Semanas/dias antes

| # | Item | Origem |
|---|---|---|
| 1 | Crie/entre na conta Red Hat **que comprou a prova** (o login do teste de compatibilidade e da prova é o mesmo) | `[OFICIAL]` V13 p.11 |
| 2 | Verifique os requisitos: computador **x86_64** (não funciona em Apple Silicon M1–M5; Macs T2 problemáticos), **UEFI** (Legacy/CSM pode não funcionar), **Secure Boot desativado** recomendado, **8 GB de RAM** no mínimo, **8 GB livres** no disco para baixar a ISO e gravar o pendrive | `[OFICIAL]` V13 p.3 |
| 3 | Pendrive de **≥ 4 GB** (será totalmente apagado). VM não vale: a ISO precisa ser gravada em pendrive | `[OFICIAL]` V13 p.3, p.17 |
| 4 | Baixe a **ISO mais recente** (~1,8 GB) — versões antigas podem não funcionar. No Windows ela aparece como "corrompida" (é criptografada): é normal. Grave com Fedora Media Writer, Rufus, balenaEtcher ou outra ferramenta confiável (precisa de administrador) | `[OFICIAL]` V13 p.5 |
| 5 | **Confira o checksum** da ISO. Valores do V13: MD5 `881de281740f7e90e66e037a4b335f1b` · SHA256 `67a7ee704c6490f854d6685e625ddd21de15a1f7c1d96362b33b8eb454b93bd2`. Os valores atuais ficam em <http://red.ht/rhre-checksum>; seu amigo usou a `rhre-20261001.iso` (ela pode ter checksum diferente do V13) | `[OFICIAL]` V13 p.16 · `[RELATO PESSOAL]` |
| 6 | **Webcam USB com fio**, grande angular, ≥ 720p, cabo ≥ 1 m, **sem função de gravação**; ligue **direto** na porta do computador (não em hub/dock). Rosto, mãos e teclado visíveis o tempo todo; mesa pequena não é recomendada. Celular, DSLR, câmera IP e GoPro **não** valem | `[OFICIAL]` V13 p.3–4, p.19 |
| 7 | Periféricos: **um** teclado e **um** monitor físico (nada de TV/Smart TV/"smart monitor"); mouse **com fio** (opcional; sem fio é proibido); teclado externo no laptop ⇒ **tampa fechada**, com monitor externo, teclado e mouse com fio; sem KVM/splitter/gravador de vídeo. Hub USB com fio é permitido se necessário | `[OFICIAL]` V13 p.3–4 |
| 8 | Microfone obrigatório (o da webcam serve; headset sem fio é proibido) | `[OFICIAL]` V13 p.3 |
| 9 | Rede **cabeada** (Wi-Fi não é aconselhado e pode não ser detectado); modem USB (dongle) proibido; **mínimo 2 Mbps de download e de upload, exclusivos** (upload é crítico: vários vídeos sobem) | `[OFICIAL]` V13 p.3–4, p.16 |
| 10 | Notebook: bateria **carregada**, mas não use a bateria como fonte principal; considere nobreak. Desktop/torre: sobre a mesa ou de forma que dê para fazer **360°** | `[OFICIAL]` V13 p.4 |
| 11 | **Rode o teste de compatibilidade** na LiveUSB antes de agendar e de novo **2–3 dias úteis antes, no mesmo horário da prova**. Se falhar, não agende. Teste aprovado não garante ausência de problemas | `[OFICIAL]` V13 p.1, p.13 |
| 12 | Cancelar/reagendar só até **24 h** antes do início | `[OFICIAL]` V13 p.1 |
| 13 | Prepare o documento de identidade: o proctor precisa **ler o texto pequeno** da foto no vídeo (teste de câmera) | `[OFICIAL]` V13 p.14 |
| 14 | Conferir o layout de teclado antes de começar (ABNT2 × US) — escolha com cuidado | `[RELATO PESSOAL]` (o V13 não detalha; "Settings → region and language") |

## No dia

| # | Item | Origem |
|---|---|---|
| 1 | Ligue tudo (webcam, rede, mouse, teclado, monitor) **antes** de dar o boot; reinicie e abra o menu de boot (a tecla varia por fabricante) e escolha o pendrive | `[OFICIAL]` V13 p.6 |
| 2 | Chegue cedo: o boot e as checagens são demorados. Seu amigo recomenda **ligar o pendrive pelo menos 30 min antes**. Com Secure Boot ligado há uma **tela preta prolongada**: é esperado, aguarde alguns minutos | `[RELATO PESSOAL]` · `[OFICIAL]` V13 p.8 |
| 3 | Na LiveUSB: Settings → Network (conferir a rede cabeada), Sound (microfone para a direita, **~75%**, nunca no extremo), resolução **1920×1080** se a tela for maior, velocidade do mouse/touchpad | `[OFICIAL]` V13 p.8–10, p.13–14, p.18 |
| 4 | Feche o Settings; entre com **login Red Hat + código da prova** (e-mail de confirmação). O exame fica disponível até **20 min** depois do horário marcado; se não aparecer, use o chat de suporte (24×5) dentro da LiveUSB | `[OFICIAL]` V13 p.12, p.15, p.19 |
| 5 | Aviso "falso" de tela cheia ao entrar | `[RELATO PESSOAL]` (V13 omisso) |
| 6 | Monitores extras desconectados; apenas um teclado/mouse; mesa limpa | `[OFICIAL]` V13 p.3–4 · `[RELATO PESSOAL]` |

## Dentro do ambiente de prova (impacta sua técnica)

| # | Item | Origem |
|---|---|---|
| 1 | **Não use Ctrl+C / Ctrl+X / Ctrl+V** (podem travar terminais, consoles do navegador e teclados virtuais, e custar tempo de reset): copie/cole com o **mouse** (selecionar → botão direito → copiar; no terminal, botão direito → colar). Para colar numa console de VM: copie, abra a caixa de texto ("text dialog"), cole nela e clique em enviar | `[OFICIAL]` V13 p.19 |
| 2 | Consequência prática: evite comandos que dependem de **Ctrl+C** para sair (`oc logs -f`, `watch`, `oc get -w`). Use `oc logs --tail=50`, `timeout 60 oc logs -f …`, `oc rollout status --timeout=…`, `oc wait` | `[BOA PRÁTICA]` derivada do item 1 |
| 3 | Alt+Tab não funciona/é caro; ambiente lento. Prefira **um terminal**, CLI em vez de console web, YAML gerado e aplicado de uma vez | `[RELATO PESSOAL]` · `[RELATO PÚBLICO]` (2021, 4.6) |
| 4 | A documentação oficial está disponível dentro do ambiente; abra em visualizador de PDF se houver (o navegador pode pesar) | `[OFICIAL]` página da prova · `[RELATO PÚBLICO]` (2021, `NÃO VERIFICADO` para 4.22) |
| 5 | Git, Nexus e credenciais vêm no ambiente; leia as instruções iniciais com calma | `[RELATO PESSOAL]` · `[RELATO PÚBLICO]` (2024) |
| 6 | Resultado por e-mail em até 3 dias úteis; só nota total | `[OFICIAL]` página da prova |

## Treino antes do dia

- Faça pelo menos um [simulado](../09-simulado/README.md) cronometrado **com um terminal só**, sem Alt+Tab e **sem Ctrl+C/V** (copie/cole com o mouse).
- Rode `bash scripts/checar-ambiente.sh` e treine o `oc login`, o `~/.vimrc` e o completion.
- Releia a [estratégia](estrategia-de-prova.md).

> [!NOTE]
> Divergências: o blog de 2020 fala em RAM ≥ 4 GB, pendrive ≥ 8 GB e 768/512 kbps; o V13 (2025) exige **8 GB, ≥ 4 GB e 2 Mbps/2 Mbps**. Vale o V13.
