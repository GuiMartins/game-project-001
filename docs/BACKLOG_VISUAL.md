# Backlog visual

A fila do que falta para a tela do protótipo chegar nas referências: as quatro
imagens paradas, o vídeo de 6 s (`video_01`) e a filmagem de garupa
(`video_02`). É **uma lista só, em ordem**, e a ordem é o ponto: cada item foi
posto depois daquilo que muda a cara dele.

Os estudos que sustentam cada item continuam onde estão, e este arquivo não
repete as contas deles, só aponta:

- [DIRECAO_VISUAL.md](DIRECAO_VISUAL.md): os nove pilares do look, resolução,
  luz, partícula, borrão, HUD.
- [PROVA_VISUAL.md](PROVA_VISUAL.md): o plano P0–P9, o manifesto de assets e
  os critérios de abandono.
- [REFERENCIA_VIDEO.md](REFERENCIA_VIDEO.md): o vídeo de 6 s medido quadro a
  quadro, com a tabela "o que o jogo já tem, e o que falta".
- [REFERENCIA_CAMERA_GARUPA.md](REFERENCIA_CAMERA_GARUPA.md): a câmera
  `GARUPA`, já entregue.

## Como usar

**"Faz a próxima tarefa" = o primeiro item `[ ]` desta lista**, de cima para
baixo. Item marcado 👤 depende do Guilherme (decisão de produto ou arquivo que
só ele tem): quem for implementar pergunta na hora, com a recomendação que o
item já traz, e não pula para o seguinte sem a resposta.

**Antes de escolher o item, atualize a branch:** `git fetch origin` e comece
de `origin/master`, não da `master` local nem do worktree que já estava
aberto. A fila anda a cada merge, e a cópia velha mente sobre qual é o
primeiro `[ ]`: foi assim que a V01 começou a ser refeita minutos depois de
mergeada (#72).

```bash
git fetch origin
git switch -c <assunto> origin/master
```

Cada item vira **uma branch e um PR**, com o portão verde, do jeito do
`CLAUDE.md`. Ao fechar:

1. Marcar `[x]`, com a data e o PR: `- [x] **V03** ... (08/10/2026, #55)`.
2. Escrever embaixo uma linha de **resultado**, com número quando houver:
   `fps` antes e depois, o baseline que andou e por quê, o slider que ficou.
   É o mesmo papel do *Estado* em cada tarefa da `PROVA_VISUAL.md`.
3. A marcação entra **no mesmo PR** da tarefa, não num commit separado depois.

Se uma tarefa revelar trabalho que não cabe nela, o trabalho novo entra como
item próprio logo abaixo (`V08a`, `V08b`), sem renumerar a lista: os números
são citados em commit e em PR, e renumerar quebra a referência.

Se uma tarefa se mostrar errada (a referência não pedia aquilo, ou a medida
diz que não paga), ela é marcada `[~]` com uma linha dizendo por quê. Cortar
também é resultado.

### O aceite de todo item

Além do aceite próprio de cada um:

- **Abrir as referências antes de modelar.** Cada item aberto tem uma linha
  **Referências** com os arquivos de `docs/referencias/` onde o elemento
  aparece: abra as imagens (não só o texto do item) antes de escrever o
  primeiro script, e volte a elas a cada iteração. A descrição do item é o
  resumo de quem olhou, e resumo perde forma, proporção e cor. A V14 e a V15
  foram modeladas só a partir do texto e precisaram ser refeitas quando o
  Guilherme perguntou "como é isso nas referências?". Item novo já nasce com
  a sua linha **Referências**; se nenhuma referência mostra o elemento, a
  linha diz isso, e de onde sai o alvo.
- **`dev.py prova --referencia`**, não só a `prova`. Antes e depois mostra se
  mudou; a folha lado a lado com a referência mostra se chegou mais perto,
  que é a pergunta do backlog.
- **`dev.py prova` antes e depois**, lado a lado. Toda mudança visual se julga
  no quadro congelado, não num print que calhou.
- **`dev.py fps`** quando o item põe coisa na tela. Comparar a mesma máquina.
- Se `tests/baseline_visual.json` ou `tests/baseline.json` andou, o número
  novo entra no mesmo commit, com o motivo no corpo da mensagem.
- Itens de *feel* (câmera, inclinação, trânsito) se julgam **jogando**, e não
  em captura.

## O que já está feito

Para ninguém refazer. Detalhes no *Estado* de cada tarefa da `PROVA_VISUAL.md`
e no `git log`.

| | Feito em |
| --- | --- |
| Quadro congelado (`dev.py prova`) e `dev.py fps` | P0 |
| Resolução interna 640×360 | P1 |
| Sol com sombra de 250 m, céu procedural, ambiente vindo do céu | P2, #34 |
| Tonemap, LUT do dia, quantização com dither | P3 |
| Asfalto e calçada de pedra portuguesa texturizados | P4a, #30 |
| Quatro prédios modelados (sobrado, comércio com toldo, escritório, torre) | #31 |
| Entregador 3D posado pela física, com paleta por corredor | #22 |
| Suspensão da CG, corpo que sente a freada, soco | #47 |
| Hatch, sedã, SUV, táxi e ônibus, com lanterna de freio e porta | #43 |
| Câmera `GARUPA` (`F2`) | #37, #38, #50 |
| Ampliação sem tremor em tela de escala quebrada (`ampliacao.gdshader`) | V28 |

## Revisão dos itens fechados contra as referências (12/10/2026)

A V14 e a V15 saíram do texto e foram refeitas; os itens fechados antes da
regra de abrir as referências podem ter o mesmo problema. Cada um foi
comparado com `dev.py prova --referencia` (a 90 km/h, que é a da prova, e a
128 km/h, que é a de todas as referências) e com as imagens da sua linha
**Referências**. Os de *feel* foram comparados pela medida quadro a quadro do
vídeo (`REFERENCIA_VIDEO.md`) contra os números do `selftest`; jogando, o
veredito continua com o Guilherme.

**Aprovado pelo Guilherme em 12/10/2026.** Cada desvio e refação virou item
aberto logo abaixo do original: V03a, V05b, V07b, V08a, V09a, V11a e V13a.

| Item | Classificação | O que falta |
| --- | --- | --- |
| V03 | desvio pequeno 👤 | Decidida sem as paradas. Nelas o pixel é 2–3× mais grosso que 640×360 só no céu, na nuvem e no asfalto borrado (trama em tufo, não grade), e a fachada é lisa. O jogo põe o Bayer fino por igual, fachada inclusive, e lê como retícula. Reabrir: trama só em gradiente e mais grossa. |
| V04 | bate | Piloto em ~45% da altura (ref. ~46%), horizonte a ~45% do topo (ref. ~40%). |
| V05 | desvio pequeno 👤 | Saída (~0,17 s) e contra-inclinação (−4,6°) batem. A entrada no teclado vai a ~60°/s; o vídeo deita a 12–25°/s, porque o piloto põe peso aos poucos. Rampa no pedido de inclinação do teclado, julgada jogando. |
| V05a | bate | Nenhuma referência mostra PCX nem XRE; o alvo é a ficha. |
| V06 | bate | Tremor (1,2 cm) e pneu preto sem banda batem com o vídeo. |
| V07 | desvio pequeno | Postura e losango batem. A bag não: no vídeo é mais larga que alta, assenta nos ombros e o capacete fica inteiro acima; no jogo é quase quadrada, sobe acima do ombro e esconde meio capacete. |
| V07a | bate | Nenhuma referência mostra os comandos nessa escala. |
| V08 | desvio pequeno | A 128 km/h as referências têm o terço de baixo do asfalto todo em risco e a zebra riscada; o jogo, na mesma velocidade, deixa o asfalto e a zebra quase nítidos e só borra o rival na borda. Força maior em cruzeiro, e asfalto com contraste para ter o que riscar. |
| V09 | desvio pequeno | Largura bate no corredor. Falta o meio-fio alto com sombra (no jogo a calçada lê no nível da pista), tom mais quente, e pedra portuguesa ou placa em vez de cimentado liso: `01_centro` e `t0.0s` mostram pedra portuguesa na avenida. No largo da V11 a calçada vira descampado que nenhuma referência tem. |
| V10 | bate | Zebra ao longo da pista e linha de bordo branca, como no vídeo. |
| V11 | refazer | A referência é um cânion de 8–15 andares em pedra bege e ocre, com cornija e toldo de cor lisa em todo o térreo, saindo pelo topo do quadro. O jogo mostra blocos pastel (amarelo, rosa, menta, lilás) de janela chapada, mural de triângulos que nenhuma referência tem, e o largo com recuo de 8–12 m abre céu e chão vazio. |
| V12 | bate | Lanterna e outdoor brilham, asfalto não. O halo do vídeo nos carros brancos é exposição, não glow. |
| V13 | desvio pequeno | Posição e brilho batem. Formato não: na referência é deitado (~16:9), de foto colorida e com moldura; no jogo, muito em pé (bandeira 2,8 × 4,2 m) e tela de uma cor só com disco e barras, puxando para o rosa. |

Quem abriu as imagens antes de implementar, pelos transcripts (sessão
compactada pode esconder leitura anterior): V07 e V07a (`moto_ampliada`),
V10 (`t3.0s`) e V13 (`t3.0s`, `t3.8s`), sim. V03 e V04 só a
`video_01/folha.png`, e as paradas ainda não existiam. V08 abriu `t5.0s`
depois de implementar. V05, V05a, V06, V11 e V12, nenhuma. A V09 fechou no
#61 (08/10), antes da folha da V02 e das paradas.

## A fila

### Fundação

- [x] **V01** 👤 — As quatro imagens paradas entram no repositório (12/10/2026)

  Hoje só os dois vídeos estão em `docs/referencias/`. As imagens chegaram num
  chat e nunca viraram arquivo, e a `PROVA_VISUAL.md` já registra isso como o
  único item do manifesto que só quem as tem pode produzir.

  - **O que fazer:** salvar em `docs/referencias/` como `01_centro.png`,
    `02_praca_maua.png`, `03_viaduto.png`, `04_vertical.png` (nomes da
    `PROVA_VISUAL.md`), por Git LFS.
  - **Aceite:** os quatro arquivos no repositório.
  - Não bloqueia os itens seguintes, só a folha de comparação (V02) e o
    veredito (V27). Se faltar, faz-se o resto e volta-se aqui.
  - **Resultado:** estavam no `~/Downloads` como as quatro fotos do WhatsApp
    de 11/09/2026 (19h02, 19h33 e duas às 19h48), na ordem dos nomes: Theatro
    Municipal, Gamboa com a roda-gigante, viaduto com mural e a vertical com
    a bag. Viraram PNG sem mexer em pixel nem tamanho (o original é JPEG de
    WhatsApp, então o artefato de compressão é da fonte). A folha do
    `dev.py prova --referencia` passou a ter a terceira coluna sem tocar em
    código: o mapeamento da V02 já esperava esses nomes.

- [x] **V02** — Folha de comparação: o jogo ao lado da referência (11/10/2026, #65)

  `dev.py prova` hoje compara o jogo com ele mesmo. Falta pôr o quadro do jogo
  **ao lado da referência**, que é a pergunta do projeto inteiro e o aceite da
  P9.

  - **O que fazer:** `dev.py prova --referencia` gera `.dev/prova/comparacao.png`:
    cada quadro da prova lado a lado com o quadro de referência mais próximo
    em enquadramento (`video_01/t*.png`, e as imagens da V01 quando
    existirem), na mesma altura.
  - **Aceite:** um comando, uma imagem, e ela sai igual nos três sistemas.
  - É ferramenta: daqui em diante todo item anexa a comparação no PR.
  - **Resultado:** `dev.py prova --referencia` monta a folha no próprio Godot
    (`prova.gd`, sem Pillow), então sai igual nos três sistemas. O jogo fica
    em 640×360 e a referência é que se ajusta à altura dele. Pares escolhidos
    a olho em `Prova.REFERENCIAS`: largada↔`t0.0s`, curva↔`t3.8s`,
    ladeira↔`t1.0s`, reta↔`t5.0s`. As quatro imagens da V01 já estão
    mapeadas e entram sozinhas na linha quando os arquivos existirem.

- [x] **V03** 👤 — Decidir quanto de pixel (11/10/2026, #66)

  A pergunta aberta nº 1 da `REFERENCIA_VIDEO.md`. As imagens paradas e o
  `DIRECAO_VISUAL.md` pedem pixel (640×360, dither, ator a 12 fps). O vídeo é
  "HD saturado com HUD de arcade", liso a 24 fps. Os dois são legítimos, e não
  são o mesmo look. Decide-se **antes** de pintar mais textura, porque muda o
  quanto investir em detalhe.

  - **Referências:** as quatro paradas (`01_centro`, `02_praca_maua`,
    `03_viaduto`, `04_vertical`: bloco de pixel e trama grossa no céu, na
    nuvem e no asfalto borrado, e fachada lisa, sem trama) e `video_01/t*.png`
    (HD liso). A decisão é de 11/10, só com o vídeo: as paradas entraram no
    #72.
  - **O que fazer:** três variantes no mesmo quadro da prova, lado a lado com
    o vídeo: (a) como está, (b) sem a quantização e o dither, (c) com dither
    mais fraco (`paleta.gdshader`). Levar a folha para a decisão.
  - **Recomendação:** manter 640×360 (já está pago, e o vídeo também tem
    bloco de pixel no asfalto) e decidir só a força do dither. A cadência de
    12 fps do ator fica para a V22, que é onde ela se julga rodando.
  - **Aceite:** a decisão escrita aqui, com a data, e o default do shader
    ajustado se ela mudou alguma coisa.
  - **Decisão (11/10/2026, Guilherme):** fica **como está**: 640×360, 16
    níveis por canal e o Bayer inteiro (`forca = 1`). Comparadas em 1080p,
    contra "sem paleta" e "dither pela metade", a trama visível no céu e na
    neblina ganhou: é ela que diz pixel art, e não só a resolução. O default
    do shader não mudou. As variantes da V03 saíram da
    `dev.py prova --variantes` na V03a, que pôs as dela no lugar.

- [x] **V03a** 👤 — Trama de pixel só no gradiente, e mais grossa (13/10/2026, #90)

  A V03 foi decidida em 11/10, só com o vídeo: as quatro paradas entraram
  no #72. Nelas o pixel é 2–3× mais grosso que 640×360, mas só no céu, na
  nuvem e no asfalto borrado, e a trama é em tufo, não grade; a fachada é
  lisa. O jogo põe o Bayer fino por igual, fachada inclusive, e de perto
  lê como retícula de jornal, não pixel art.

  - **Referências:** `01_centro` (céu, nuvem e fachada do Theatro),
    `02_praca_maua` (céu e asfalto da zebra), `03_viaduto`, `04_vertical`
    (asfalto em bloco); recorte lado a lado em *Revisão dos itens
    fechados*.
  - **O que fazer:** variantes no `paleta.gdshader` na
    `dev.py prova --variantes`: trama pesada pelo gradiente local (some em
    superfície lisa), e matriz maior ou em bloco de 2 px. Levar a folha com
    as paradas ao lado para a decisão.
  - **Recomendação:** manter 640×360 (a fachada da referência tem esse
    detalhe) e mexer só na trama.
  - **Aceite:** a decisão escrita aqui; na prova, fachada sem retícula e céu
    com trama em tufo, perto do recorte da `01_centro`.
  - **Decisão (13/10/2026, Guilherme):** **tufo de 2 px só no gradiente
    suave**, entre quatro variantes no mesmo recorte de 1080p ao lado da
    `01_centro`: Bayer por igual (o de antes), Bayer só no gradiente, Bayer
    em célula de 2 px e ruído em célula de 2 px. O peso da trama mede, a
    4 px, o quanto a cor anda (gradiente) e o quanto ela dobra (laplaciano):
    céu e neblina andam sem dobrar e recebem trama; parede chapada não anda,
    janela dobra, e as duas ficam lisas. Continua 640×360 e 16 níveis.
  - **Resultado:** `fps` na mesma máquina p50 6,9 ms contra 8,3 ms antes,
    dentro do ruído (quatro amostras a mais por pixel a 640×360). As
    variantes perdedoras ficam em `dev.py prova --variantes`.

### Enquadramento

- [x] **V04** — Câmera de perseguição perto e baixa (12/10/2026, #68)

  A maior distância entre o vídeo e o jogo, e a que decide o que todo o resto
  precisa mostrar: no vídeo o piloto ocupa ~53% da altura e a câmera está
  **abaixo do capacete**; no jogo, ~29% e acima. Com a câmera alta, o corredor
  vira mapa.

  - **Referências:** `video_01/t0.0s`, `t1.0s` e `moto_ampliada` (piloto em
    ~46% da altura, lente na altura do capacete); `01_centro`, `02_praca_maua`
    e `04_vertical` (mesmo enquadramento, horizonte a ~40% do topo).
  - **Ponto de partida** (`REFERENCIA_VIDEO.md`, *Proposta de partida*):
    `cam_distance` ≈ 4,0, `cam_height` ≈ 1,6, `cam_lean_follow` ≈ 0. O
    `cam_fov_speed_gain` já está em 8.
  - **A mira** (14 m à frente, 1,2 m de altura) está cravada em
    `chase_camera.gd::_alvos()`. Vira slider no `BikeTuning`, começando em
    1,4 m para o horizonte ficar em ~40% do topo.
  - **Onde:** `scripts/bike_tuning.gd`, `scripts/chase_camera.gd`.
  - **Aceite:** jogando, o corredor entre dois carros parece mais apertado e o
    que vem à frente continua legível a 180 km/h. Piloto em 40–45% da altura
    em cruzeiro. A prova muda de cara: baseline visual no mesmo commit.
  - **Resultado:** a proposta de partida (4,0 m, 1,6 m, mira a 1,4 m)
    cortava a moto: lente quase nivelada, só o tronco do piloto no quadro.
    Ficou `cam_distance` 4,5, `cam_height` 1,2, mira virou slider
    (`cam_mira_distancia` 8, `cam_mira_altura` 0,2: lente ~4,5° para baixo)
    e `cam_lean_follow` 0. Na prova, piloto em ~45% da altura com a roda
    inteira e horizonte em ~44% do topo (antes ~29%). Baseline visual:
    `visual_fracao_ceu` 0,104 → 0,082, porque a câmera baixa vê mais
    fachada e menos céu.

### A moto viva

- [x] **V05** — Inclinação com mola: entra devagar, sai seca, passa do zero (12/10/2026, #71)

  O vídeo deita em ~1 s e levanta em ~0,3 s, com uma contra-inclinação de
  4–8° no fim. O `lerp` exponencial de hoje nunca passa do alvo, então a troca
  de direção lê como ponteiro voltando ao centro, e não como peso.

  - **Referências:** `video_01.mp4` de 2,0 a 6,0 s e `video_01/moto_ampliada`,
    medidos quadro a quadro em `REFERENCIA_VIDEO.md`, *A inclinação*.
  - **O que fazer:** trocar o `lerp` por mola (ângulo + velocidade angular)
    em `player_bike.gd`, retorno ~3× mais rápido que a entrada e *overshoot*
    pequeno. Os parâmetros viram slider.
  - **Mexe no `selftest`.** O baseline anda, e o corpo do commit diz quanto e
    por quê.
  - **Aceite:** jogando, a troca de lado no corredor tem peso: a moto deita,
    volta e assenta. Pico numa curva suave perto de 25°.
  - **Resultado:** duas molas em `PlayerBike.passo_da_inclinacao`. Deitar é
    crítica (`lean_freq` 8): 0→90% em 0,52 s (era 0,35), com arrancada macia.
    Levantar é `lean_return_freq` 13 com `lean_return_damping` 0,45: do
    pedido ao zero em ~0,17 s, um terço da entrada, e passa ~19% do outro
    lado (−4,6° saindo de 25°, −7° saindo de 38°), assentando em ~0,2 s. Os
    sliders trocaram de nome junto com o sentido, para um `tuning.tres` velho
    não injetar taxa de `lerp` numa frequência. Baseline: `inclinacao_0_90_s`
    0,35 → 0,52 (o objetivo); corrida solta e disputa andaram por caos de
    trajetória do piloto automático (1381 → 1217 m, mas com a entrada a 0,38 s
    cai para 1018 m: não é perda de agilidade); `batida_quina_desvio_m`
    4,5 → 2,0 porque o segurador de faixa da prova chega 14 cm mais dentro do
    carro e pega a quina mais em cheio. O portão da disputa reprovava quando
    o piloto automático vencia, e foi consertado antes, em PR próprio.

- [x] **V05a** 👤 — Física por moto: CG, XRE e PCX andam diferente (12/10/2026, #73)

  Hoje as três motos só trocam de modelo: a física é uma só, do
  `BikeTuning`. Depois da mola da V05, o Guilherme quer que cada moto tenha
  a sua calibração, a começar pela inclinação (`lean_freq`,
  `lean_return_freq`, `lean_return_damping`).

  - **Referências:** nenhuma mostra PCX nem XRE, e o `video_01` só tem uma
    naked; o alvo é a ficha técnica (`FichaDaMoto`).
  - **Decisão 👤:** quais números variam por moto (só inclinação, ou também
    velocidade, aceleração e curva), e se os rivais herdam a física da moto
    sorteada ou só o jogador.
  - **Recomendação:** um `BikeTuning` base e um recurso pequeno por moto que
    sobrepõe só o que muda. A scooter (roda pequena, entre-eixos curto)
    deita mais rápido e volta mais nervosa; a XRE (alta, roda grande) mais
    lenta e assentada; a CG fica no meio, com os valores de hoje.
  - **Mexe no `selftest`:** ele roda numa moto fixa (a CG), e o baseline
    continua valendo para ela. As outras ganham teste unitário da mola.
  - **Aceite:** jogando, dá pra dizer de olho fechado qual moto você
    escolheu pela troca de lado no corredor.

  **Resultado:** decidido só inclinação, e os rivais também. Em vez de número
  na mão, a mola sai da **ficha técnica real** (`FichaDaMoto`: peso, entre-eixos,
  altura do banco, pneus, e o motor guardado para depois): um índice de
  agilidade relativo à CG (`FisicaDaMoto.agilidade`), multiplicador sobre o
  `BikeTuning` para o F3 continuar valendo nas três. Moto nova entra com a
  ficha e nasce calibrada; sem ficha, o teste reprova. PCX 1,21×, XRE 0,76×.
  Deitar 0->90%: 0,42 / 0,5 / 0,65 s; contra-inclinação saindo de 25 graus:
  6,6 / 4,6 / 2,0. O rival trocou o `lerp` pela mesma mola, na moto sorteada.
  Baseline sem variação (o banco roda na CG, que dá 1).

- [x] **V05b** 👤 — Rampa no pedido de inclinação do teclado (13/10/2026, #91)

  A saída (~0,17 s) e a contra-inclinação (−4,6°) da V05 batem com o vídeo.
  A entrada não: com a tecla, o pedido vai a 100% na hora e a moto deita a
  ~60°/s; no vídeo ela deita a 12–25°/s, porque o piloto põe peso aos
  poucos. A mola está certa; quem entra seco é o pedido.

  - **Referências:** `video_01.mp4` de 2,0 a 3,9 s (0° → 25° em ~1,6 s) e
    `video_01/moto_ampliada`; números em `REFERENCIA_VIDEO.md`, *A
    inclinação*.
  - **O que fazer:** o pedido vem de `Controls.steer_axis()` e entra cru
    em `PlayerBike._update_lean`. Rampa no pedido de tecla: sobe enquanto
    segurada e solta seco; analógico passa direto. A taxa vira slider.
  - **Decisão 👤:** a taxa, jogando. Partida: 0 → máximo em ~0,8 s.
  - **Mexe no `selftest`** se a rampa ficar no caminho que a prova usa:
    o baseline anda com o motivo, ou a rampa fica só na leitura da tecla.
  - **Aceite:** jogando, a troca de faixa curta continua viva e a curva
    longa deita aos poucos.
  - **Decisão (13/10/2026, Guilherme):** rampa de **0,8 s**, mas **só na
    arte**. Com ela na física a moto andava pouco de lado (a guinada sai
    da inclinação) e a direção ficou dura. Agora são duas inclinações na
    mesma mola: a `lean` da física, com a tecla crua, de onde saem a curva
    e o deslocamento na pista; e a `lean_visual`, com a rampa, que moto,
    piloto e câmeras leem. O analógico passa direto nas duas.
  - **Resultado:** a CG que aparece chega a 25° em 0,77 s (tecla crua:
    0,28 s; vídeo: ~1,6 s). Slider `lean_input_ramp`, grupo Inclinacao e
    curva. Baseline sem variação: o banco mede a física, que não mudou.

- [x] **V06** — Vibração miúda, roda lisa em alta e cabeça no horizonte (12/10/2026, #76)

  Três coisas pequenas de pose, todas no `Entregador`, nenhuma na física.

  - **Referências:** `video_01.mp4` e `video_01/moto_ampliada` (topo da bag
    oscilando ±3 px, pneu preto sem desenho de banda); `video_02.mp4` (moto de
    verdade em movimento).
  - **Vibração:** 1–2 cm, 8–15 Hz, crescendo com a velocidade, no corpo da
    moto e do piloto. É o "veículo que não é rígido" do vídeo. A suspensão da
    #47 já cuida da ondulação longa (`ASFALTO`); isto é o tremor curto que ela
    deixou de fora de propósito. A fonte tem de ser determinística (fase do
    tempo de física), nunca `randf()`.
  - **Roda:** acima de ~15 m/s, o desenho da banda dá lugar a um anel liso.
    A 35 m/s a roda dá volta e meia por quadro e pisca ou gira para trás.
  - **Cabeça:** desfaz ~20% do *roll*, para o olhar ficar mais perto do
    horizonte.
  - **Aceite:** em movimento, a moto treme de leve no cruzeiro e a roda não
    estrobosca. Nenhum número do `selftest` anda.

  **Resultado:** tremor de 1,2 cm de pico a 35 m/s, crescendo com o quadrado
  da velocidade, de 8 a 15 Hz, com fase integrada do tempo de física
  (`Tremor`); entra somado à suspensão, então as rodas continuam no chão pela
  mesma conta. A roda das três motos ficou preta com detalhe cinza (friso no
  meio de cada raio da CG e da PCX; o raio de aço da XRE), e os raios viraram
  peça própria (`Raios_*`). Acima de 16 m/s (voltam abaixo de 14) eles somem
  e entra o borrão (`RodaLisa`): um disco de anéis com a média do que passa
  em cada distância do eixo, lida da malha dos raios, e o friso vira anel
  cinza girando. Com a roda toda cinza-escuro de antes o disco saía da mesma
  cor e ninguém notava a troca. A cabeça já desfazia ~29% do *roll* desde
  a #47 (0,35 da moto menos o que o tronco deita), e ficou como estava.
  Jogador e rival ganham os dois, nas três motos. Baseline sem variação; a
  prova de trás sai igual, porque dali a roda mal aparece.

- [x] **V07** — Postura do vídeo: sentado e de cotovelo aberto (12/10/2026, #77)

  A 128 km/h o entregador do vídeo continua **sentado**, tronco a 10–15°, com
  os cotovelos bem abertos: são as pontas mais largas da silhueta, mais largas
  que a bag. O jogo deita o tronco com a velocidade (`TRONCO_DEITADO`).

  - **Referências:** `video_01/moto_ampliada` e `t1.0s` (sentado, cotovelo
    passando da bag, bag mais larga que alta e capacete inteiro acima dela);
    `01_centro`, `02_praca_maua`, `04_vertical`.
  - **Onde:** `scripts/entregador.gd` (pose e IK dos braços).
  - **Aceite:** de trás, a silhueta mostra o losango braço-guidão. Faz mais
    sentido depois da V04, quando o piloto está grande na tela.

  **Resultado:** `TRONCO_DEITADO` −16 → −3: no talo o tronco vai de 12 a 15
  graus para a frente, em vez de 30, e o capacete volta a aparecer acima da
  bag na prova. O polo do cotovelo virou `COTOVELO` (1; −0,3; 0,3), quase só
  para fora, em vez de (1; −1; 0,3): de trás, nas três motos, os cotovelos
  passam da bag e o braço fecha o losango com o guidão. Parado no losango a
  corrida inteira ficava boneco, então o braço ganhou vida própria
  (`Cotovelos`): de tempos em tempos um braço relaxa, desce e cola no corpo
  por 0,6–2,5 s, às vezes os dois, e volta; aberto, cada vez dobra um pouco
  diferente. Quando e quanto é sorteio, não ciclo, com semente da posição em
  que o ator nasce: dois pilotos não relaxam juntos e a mesma corrida repete.
  Relaxa mais devagar (60% por sorteio) que no talo (25%), e na curva acima
  de 20° ninguém solta o braço. Só pose: baseline sem variação, e nenhuma
  malha nova na tela (sem `fps`).

- [x] **V07a** 👤 — Mãos e pés nos comandos: gás, freio e marcha (12/10/2026, #78)

  Ideia do Guilherme jogando a V07: acelerar é torcer o pulso para baixo,
  quase em ângulo reto com o antebraço, e a pilotagem tem ainda o freio e a
  troca de marcha.

  - **Referências:** nenhuma mostra pulso, manete ou pedal na escala da
    câmera; `video_01/moto_ampliada` só confirma as mãos nas pontas do guidão.
    O alvo é a pilotagem real.
  - **Decisão 👤:** pose **e** peças que se mexem (manete, pedal), e não só
    pose.
  - **Resultado:** `Comandos`, classe pequena do ator. O pulso direito torce
    até 65° com o gás e volta 12° na freada; a freada é a que o ator já mede
    (a mesma que afunda o garfo), então vale para o rival sem nada novo no
    corpo. Manete (embreagem e freio), pedal de câmbio, pedal de freio e os
    dedos viraram peças no Blender nas três motos (`Manete_E/D`,
    `Pedal_Cambio`, `Pedal_Freio`, `Dedos_E/D`); na PCX os pedais são vazios
    pelo contrato da árvore, e a manete esquerda é o freio de trás. Os dedos
    grudam na manete e largam quando o pulso torce o gás. A marcha é de
    mentira, contada pela velocidade em faixas que encurtam: quantas sai da
    ficha (`FichaDaMoto.marchas`: CG e XRE 5, PCX automática), e cada troca
    puxa a embreagem, alivia o gás e mexe a bota (redução com tapa no gás).
    A manete antiga era uma `barra` que media só em Y e Z, e saía um cubo de
    1 cm: ninguém via. Baseline sem variação; `shots` passa.
    Depois, jogando: o freio passou a vir do pedido (botão do jogador; no
    rival, estar acima da velocidade-alvo), e não da desaceleração medida,
    que puxava a manete ao soltar o gás em alta e em toda batida. E o rival
    em cruzeiro segura meio gás, em vez do pulso fechado de quem embala.

- [ ] **V07b** — Bag do vídeo: mais larga que alta, capacete por cima

  A postura da V07 bate. A bag não: no vídeo ela é mais larga que alta,
  assenta nos ombros e o capacete fica inteiro acima dela; no jogo é quase
  quadrada, sobe acima do ombro e esconde meio capacete, e a silhueta perde
  a cabeça.

  - **Referências:** `video_01/moto_ampliada` (os oito quadros),
    `video_01/t1.0s`; `01_centro`, `02_praca_maua`, `04_vertical`.
  - **O que fazer:** proporção e altura da `Bag` em `arte/entregador.py`
    (dimensões em `"bag"` e o `altura_bag`), nas três motos, e regerar.
  - **Aceite:** na prova de trás o capacete aparece inteiro acima da bag, e
    os cotovelos continuam passando dela.

### Velocidade

- [x] **V08** — Borrão radial com máscara de profundidade (12/10/2026)

  O que mais vende velocidade nas cinco referências, e o que mais compensa a
  falta de detalhe do cenário: o que está borrado não precisa ter detalhe. O
  vídeo mostra que é **este** o efeito, e não as linhas de velocidade que a
  P7 mandava testar primeiro.

  - **Referências:** `01_centro`, `02_praca_maua` e `04_vertical` (terço de
    baixo do asfalto em risco de bloco, carro colado borrado);
    `video_01/t3.0s` a `t6.0s` (zebra e linha virando risco, táxi e sedã
    colados borrados). Tudo a 128 km/h.
  - **O que fazer:** `ColorRect` com shader lendo cor e profundidade,
    `CanvasLayer` **acima** do mundo e **abaixo** da quantização (a ordem dos
    passes está em `DIRECAO_VISUAL.md`, *Ordem dos passes*). Força amarrada a
    `speed / max_speed`, saturando no boost. A máscara de profundidade deixa o
    piloto nítido e borra o carro colado, não o carro a 20 m.
  - **Na `GARUPA`** o mesmo passe resolve o terço de baixo, que é sempre chão
    (ver *Ordem de entrega*, etapa 4, da `REFERENCIA_CAMERA_GARUPA.md`).
  - **Aceite:** a 180 km/h a periferia e o chão borram e o piloto fica
    nítido; o tracejado vira risco. `fps` medido. Ruído do portão visual
    medido em 4 rodadas, porque borrão aumenta a variância.
  - **Resultado:** o `ColorRect` do plano não existe no 4.7.2 (`canvas_item`
    recusa `hint_depth_texture`): virou um quad 3D preso à câmera
    (`Borrao`, `borrao.gdshader`), no passe transparente, lendo cor e
    profundidade. Risco do tamanho do movimento de verdade (distância do
    ponto de fuga ÷ distância da câmera, com piso de 15% para a periferia
    longe borrar), ponto de fuga no rumo da moto e não no centro da lente.
    O piloto fica de fora por **stencil** (`foco.gdshader`, overlay no ator
    via `Entregador.foco`), porque pela profundidade ele é igual ao asfalto
    em volta da roda. Começa em 30% da velocidade máxima, satura em 1,25 no
    boost; slider `borrao` no F3 (0,2; zero desliga). A 180 km/h
    (`dev.py prova --kmh 180`, opção nova) o chão, o carro colado e o
    tracejado viram risco, o rival a 15 m continua legível e o piloto fica
    nítido. Vidro de carro fica nítido por cima (é desenhado depois). `fps`
    igual antes e depois (p50 8,33 ms, preso no refresh de 120 Hz deste
    Mac). Baseline sem variação. Para caber no limite de 1000 linhas, a
    medida de aceleração do ator saiu para `Acelerometro`. **Ruído do
    portão visual em 4 rodadas: não medido** — o `shots` travou nesta
    máquina com 0 quadros, inclusive na `master`; fica com o CI.

- [ ] **V08a** — Borrão que risca o asfalto já em cruzeiro

  A 128 km/h as referências têm o terço de baixo do asfalto todo em risco e
  a zebra riscada. O jogo, na mesma velocidade (`dev.py prova --kmh 128`),
  deixa asfalto e zebra quase nítidos e só borra o rival na borda. Duas
  causas: a força ainda é baixa em cruzeiro, e o asfalto quase liso não tem
  contraste para virar risco.

  - **Referências:** `01_centro`, `02_praca_maua`, `04_vertical` (asfalto
    em risco de bloco no terço de baixo); `video_01/t3.0s` a `t6.0s`
    (zebra e linha virando risco).
  - **O que fazer:** curva da força em `Borrao` e `borrao.gdshader` (o
    terço de baixo borra mais que a periferia de cima), e o contraste do
    asfalto em `arte/chao.py` se o risco não aparecer.
  - **Aceite:** na folha a 128 km/h o chão lê como a referência; o piloto
    continua nítido e o rival a 15 m legível. `fps` medido.

### A rua

- [x] **V09** — Calçada larga até a fachada

  O item em que o vídeo está mais longe do jogo. Lá a calçada tem 5–8 m e dá
  espaço para poste, árvore, lixeira e gente. Aqui ela é um friso de 2,2 m e,
  entre ela e o prédio, aparece **grama** (dá pra ver em todos os quadros da
  prova).

  - **Referências:** `01_centro`, `video_01/t0.0s` e `t1.0s` (pedra portuguesa
    clara, meio-fio alto com sombra, ~5 m de calçada com árvore, mupi e
    gente); `t3.0s` (meio-fio pintado de amarelo); `t5.0s` e `t6.0s` (calçada
    lisa de *downtown*); `02_praca_maua` (meio-fio alto na curva).
  - **O que fazer:** separar a **largura andável** (`SHOULDER`, que mexe no
    *feel* e no `selftest`) da **largura visual** (pedra portuguesa até a
    fachada, ~6 m). O andável fica onde está; o resto vira faixa de serviço,
    que bloqueia a moto e é onde moram os objetos da V15–V19.
  - **Onde:** `scripts/road_track.gd`, `scripts/world.gd` (os prédios nascem
    em `edge + 6.0`).
  - **Aceite:** do meio-fio à fachada é calçada, sem grama. `selftest` sem
    variação, se o andável não mudou.

  - **Feito**, com um desvio: a calçada é cimentado liso (a onda de
    Copacabana é calçadão de praia, não avenida), e o andável não ficou onde
    estava. A pedido do Guilherme o guard-rail saiu: a moto vai até a fachada
    e bate no prédio, que tem colisor (`scripts/cidade.gd`). A faixa de
    serviço está desenhada, mas não bloqueia — quem bloqueia é o que mora nela.

- [x] **V09a** — Meio-fio que lê, e calçada de pedra quente (13/10/2026)

  A largura da V09 bate no corredor. Falta o resto: na referência o
  meio-fio é alto, com sombra embaixo, e às vezes pintado de amarelo; a
  calçada é clara e quente, em pedra portuguesa na avenida do Theatro e em
  placa no *downtown*. No jogo a calçada lê no nível da pista, num
  cimentado frio. E no largo da V11 ela vira descampado, que nenhuma
  referência mostra.

  - **Referências:** `01_centro`, `video_01/t0.0s` e `t1.0s` (pedra
    portuguesa, meio-fio alto com sombra); `t3.0s` (meio-fio amarelo);
    `t5.0s`, `t6.0s` (placa lisa de *downtown*); `02_praca_maua` (meio-fio
    alto na curva).
  - **O que fazer:** altura e face do meio-fio em `road_track.gd`; textura
    da calçada em `arte/chao.py` com junta de placa e trecho de pedra
    portuguesa, respeitando a regra de "visto a 180 km/h" do topo dele.
  - **Aceite:** na prova o meio-fio separa pista e calçada sem a linha de
    bordo, e o tom da calçada fica perto do da `01_centro`.

  **Resultado:** o meio-fio virou degrau de 15 cm (era tira de 3 cm), com o
  topo claro e uma face escura virada para a pista, e abre na boca das ruas
  que cruzam: por isso ele mora agora no `RoadTrack.pintar`, que conhece os
  cruzamentos. Só visual: para a física a calçada continua no nível do
  asfalto, e a moto que sobe nela atravessa o degrau num quadro. A calçada
  virou pedra portuguesa lisa e quente (`arte/chao.py`, pedra de 7 cm
  sorteada, sem padrão que repita), no lugar do cimentado frio. Ficaram de
  fora: a placa de *downtown* (a junta transversal a cada metro pisca a
  180 km/h, regra 1 do `chao.py`), o meio-fio amarelo e o das ruas
  transversais, que segue tinta de 3 cm. O largo descampado é da V11a.
  `fps` p50 8,33 ms (refresh de 120 Hz). Baseline sem variação.

- [x] **V10** — Faixa de pedestres e linha de bordo (12/10/2026, #81)

  A zebra é a pintura de maior contraste do vídeo e o marcador de velocidade
  mais forte dele: as listas brancas passando sob a roda.

  - **Referências:** `video_01/t3.0s`, `t6.0s` e `02_praca_maua` (zebra larga,
    listras ao longo da pista); `video_01/t0.0s` e `01_centro` (linha de bordo
    branca junto ao meio-fio).
  - **O que fazer:** linha de bordo branca contínua junto ao meio-fio; faixas
    de pedestres com linha de retenção, nos cruzamentos.
  - **O risco:** a regra da P4a (`arte/chao.py`) proíbe coisa fina atravessada
    com período menor que 1,7 m, e a zebra real tem ~1 m. Ela vai piscar.
    Testar rodando as duas saídas: zebra mais larga que a real (período de
    2 m) ou decalque com mipmap forte.
  - A linha dupla amarela do vídeo **não entra**: é erro da IA (separa
    sentidos opostos, e todo o trânsito do vídeo vai no mesmo sentido).
  - **Aceite:** a zebra passa sem piscar a 180 km/h, julgado rodando.
  - **Resultado:** o risco não existia. A zebra do CTB e a do vídeo têm as
    listras **ao longo** da pista, lado a lado: o período (1,2 m, listra de
    50 cm) é lateral, e quem passa por cima vê cada listra como uma barra de
    4 m. Nada fino atravessado, então a regra da P4a não chega a valer. A
    única coisa atravessada é a linha de retenção (50 cm, 1,6 m antes da
    zebra), que passa uma vez só. Conferido numa sequência de 90 quadros a
    0,83 m cada (180 km/h a 60 Hz), de 95 m até em cima: a zebra não pisca
    nem de longe. Uma zebra por cruzamento, na chegada; o tracejado para na
    retenção e volta depois da boca da rua, e a linha de bordo (20 cm, branca,
    a 10 cm do meio-fio — a antiga ficava em cima do meio-fio e brigava com
    ele no depth buffer) abre na boca e na zebra. A pintura da avenida virou
    malha própria (`RoadTrack.pintar`), refeita quando a `Cidade` sorteia os
    cruzamentos. A tinta ficou branca (`RoadTrack.TINTA`), também nas ruas.
    A prova ganhou o quadro `faixa`, ao lado do `t3.0s`. Baseline de física
    sem variação; visual dentro da tolerância (luminância −2,5%, céu −2,2%).
    `fps` depois: p50 e p95 em 8,33 ms, no teto de 120 Hz da tela, então não
    há diferença para medir; a mudança custa uma chamada de desenho.
    Depois, jogando: a zebra das ruas transversais, que já existia, saía
    torta (40 cm de margem de um lado, 10 do outro) e com outro desenho.
    Passou a usar a mesma zebra e a mesma retenção da avenida, centrada
    (`RoadTrack.listras_da_zebra`), a 1 m do asfalto da avenida.
    E a rua ganhou meio-fio (no sol o asfalto dela some contra o cimentado,
    e a zebra parecia pintada na calçada), e poste da avenida não nasce mais
    na boca da rua (`Cidade.na_boca`).
    E o que fazia a zebra da rua parecer torta e voando era a ladeira: a rua
    inclina na largura junto com a avenida, e a zebra, o meio-fio e a fila
    eram desenhados na horizontal. A 10% de rampa, uma borda ficava 30 cm
    acima do asfalto e a outra enterrada; agora tudo segue o plano da rua.

### Os prédios e o céu

- [x] **V11** 👤 — Fachada contínua, térreo vivo (12/10/2026)

  Depois dos 2,5 s o vídeo é um corredor de paredes: prédio colado em prédio,
  loja com toldo e letreiro no térreo. Hoje os prédios são sorteados com
  buraco entre eles, e só o `Comercio` tem loja embaixo.

  - **Referências:** `video_01/t3.0s` a `t6.0s` (corredor de 8 a 15 andares em
    pedra bege e ocre, com cornija, e toldo de cor lisa no térreo inteiro);
    `01_centro`, `video_01/t0.0s` e `t1.0s` (Theatro e sobrado colonial ao
    fundo); `02_praca_maua` (muro e casario).
  - **Decisão 👤:** Rio ou cidade genérica? **Recomendação** da
    `REFERENCIA_VIDEO.md`: Rio com o ritmo do *downtown* — sobrado, art déco
    de Copacabana e colonial do Centro, colados em sequência, com térreo
    comercial. Alternar trechos de avenida aberta com trechos de corredor
    fechado, porque a alternância é ritmo.
  - **O que fazer:** colocação em sequência no `world.gd`; térreo com loja e
    toldo em todos os tipos de rua (não nas torres do fundo), em
    `arte/predios.py`; mais um ou dois tipos se a sequência repetir à vista.
  - **Em andamento:** a colocação em sequência está feita
    (`scripts/cidade.gd`): prédio colado em prédio, junta de até meio metro, e
    ruas transversais a cada 70–160 m, com semáforo e fila parada nas de
    acesso. Falta o térreo com loja nos outros tipos e a alternância avenida
    aberta / corredor fechado.
  - **Aceite:** num trecho de corredor não se vê céu entre prédios no nível
    da rua; `fps` medido, porque é aqui que a conta de desenho aperta.

  - **Feito**, Rio. Quinto prédio, o `Deco` (art déco de Copacabana, 7
    andares, torreão com friso vertical passando do telhado). Loja com
    letreiro e toldo no `Sobrado` (dois dos três arcos), no `Deco` e na
    `Torre` (dos dois lados da portaria); o `Escritorio` ficou sem, é a torre
    do fundo. A avenida alterna **largo** (60–130 m, fachada recuada 8–12 m,
    só sobrado e comércio) e **corredor** (180–380 m, colado, de tudo), e
    começa no largo. A fração de céu da regressão visual subiu 35% por isso,
    e o `baseline_visual.json` andou junto. `fps`: os dois no teto de 120 do
    monitor, p95 8,33 → 8,65 ms.

- [ ] **V11a** 👤 — Refazer a fachada: cânion de pedra bege, não bloco pastel

  A V11 fez a sequência colada e o térreo com loja, e isso fica. O que não
  lê como a referência é o prédio. No vídeo é um cânion de 8–15 andares em
  pedra bege e ocre, com cornija, janela com moldura e toldo de cor lisa
  em todo o térreo, saindo pelo topo do quadro. No jogo são blocos pastel
  (amarelo, rosa, menta, lilás) de janela chapada, com mural de triângulos
  que nenhuma referência tem, e o largo com recuo de 8–12 m abre céu e
  chão vazio.

  - **Referências:** `video_01/t3.0s` a `t6.0s` (o corredor); `01_centro`,
    `video_01/t0.0s` e `t1.0s` (Theatro e sobrado colonial); `02_praca_maua`
    (casario e muro). O mural colorido só existe no `03_viaduto` e no
    `04_vertical`, em muro de via expressa, não em fachada.
  - **Decisão 👤:** o largo fica (mais curto e sem o recuo vazio) ou sai?
    **Recomendação:** fica, mas como praça com árvore e gente (V16, V19), e
    não como chão vazio.
  - **O que fazer:** paleta e material das fachadas em `arte/predios.py` e
    `predio.gd` (pedra bege, ocre, creme; cor viva só no toldo e no
    outdoor), cornija e moldura de janela, prédios de corredor mais altos,
    mural fora da fachada.
  - **Aceite:** na folha, o corredor do jogo ao lado de `t5.0s` lê como a
    mesma rua. `fps` medido.

- [x] **V12** — Glow: outdoor, lanterna e cromo brilhando (12/10/2026, #84)

  O vídeo tem *bloom* nos outdoors, nos carros brancos e no cromo. O jogo não
  liga `glow_enabled` (é o item 4 da tabela de luz do `DIRECAO_VISUAL.md`).
  Vem antes do outdoor e da partícula porque os dois dependem dele para ler:
  sem glow, faísca é um pixel laranja.

  - **Referências:** `video_01/t3.0s` e `t5.0s` (outdoor com halo), `t1.0s`
    (lanterna de freio do táxi); `03_viaduto` (painel de LED).
  - **O que fazer:** glow no `Environment` com limiar alto (só o que é
    emissivo passa); lanterna dos carros emissiva; SSAO leve, e só se o `fps`
    deixar (é o primeiro a cortar).
  - **Aceite:** lanterna acesa brilha a 30 m; asfalto ao sol **não** brilha.
  - **Resultado:** glow aditivo com limiar 2,2 e rampa 1, só os três níveis
    finos (`world.gd`). O limiar foi medido, e não escolhido: com a cena em
    HDR, o mais claro que o sol produz é 2,0 (calçada branca e sacada de
    frente para ele), e o asfalto não passa de 1. Nos cinco quadros da prova
    o glow muda **0 pixels**. A pegadinha: o Godot compara com o limiar
    **depois** do primeiro desfoque, e a lanterna a 30 m chegava lá com 13%
    do que tinha (detalhe no `DIRECAO_VISUAL.md`). Freio e seta passaram
    de ~1,4 e ~2,1 para 45, com cor de luz pura (`carro.gdshader`) para não
    desbotar em salmão; a lanterna acesa sem freio continua abaixo do
    limiar, só cor.
    Conferido com carro plantado freando a 30 m e a 10 m, parado e a
    90 km/h. **SSAO cortado**: leve, muda 0,3% dos pixels e o contato do
    pneu fica igual (quem faz isso é a sombra); forte, escurece a sombra
    inteira e desfaz o cinza frio do ambiente. **Cromo fica de fora**: o
    mundo inteiro é `specular_disabled` de propósito (reflexo a 640×360
    pisca), e sem especular não há brilho de cromo para o glow pegar. A
    lanterna da moto também: o shader do entregador não tem canal de
    máscara livre para emissão. Outdoor é a V13, já em cima deste limiar.

- [x] **V13** — Outdoor luminoso e letreiro (12/10/2026, #85)

  Depois do céu, a coisa mais clara do quadro do vídeo. Retângulo emissivo nas
  fachadas e no topo dos prédios, com cor viva. Conteúdo inventado: nenhuma
  marca real.

  - **Referências:** `video_01/t3.0s`, `t5.0s` e `t6.0s` (outdoor deitado, de
    foto colorida, na esquina e na fachada, virado para a rua); `01_centro`
    (mupi iluminado no ponto de ônibus); `03_viaduto` (painel de LED de
    texto).
  - **Onde:** `arte/predios.py` (onde o outdoor encaixa) e `predio.gd` (a cor).
  - **Aceite:** com o glow da V12, o outdoor é o ponto mais claro abaixo do
    horizonte.
  - **Resultado:** painel de duas faces, **de topo para a rua** — colado na
    fachada ele sumia, porque a câmera vê a fachada de raspão. O `Deco` tem
    uma bandeira de 2,8 × 4,2 m a 6 m do chão, avançando 3,5 m sobre a
    calçada; o `Comercio`, um de 7 × 3,5 m no telhado. Moldura clara, tela
    na cor sorteada (seis, nenhuma vermelha: vermelho aceso é freio) e
    disco e barras brancos por cima, sem texto. A máscara ganhou o canal B
    (1 = tela, 0,4 = desenho), e o shader acende os dois com
    `tela_brilho` 4, acima do limiar 2,2 do glow. O `Predio.frente` passou a
    medir só até 5 m de altura, senão a bandeira recuava o `Deco` 2 m. Com
    o glow da V12, nos cinco quadros da prova o branco cheio fora do céu é
    só o outdoor. Baseline visual:
    `visual_familias_de_cor` 48,4 → 66,3, pelas cores de tela novas. `fps`
    igual, no teto de 120.

- [ ] **V13a** — Outdoor deitado, de foto colorida

  Posição e brilho da V13 batem. O formato não: na referência o outdoor é
  deitado (~16:9), com moldura, e mostra uma foto colorida (gente, praia,
  produto); no jogo a bandeira é em pé (2,8 × 4,2 m) e a tela é de uma cor
  só com disco e barras, puxando para o rosa.

  - **Referências:** `video_01/t3.0s` (na esquina, virado para a rua),
    `t5.0s` e `t6.0s` (na fachada); `01_centro` (mupi iluminado com foto de
    praia); `03_viaduto` (painel de LED de texto).
  - **O que fazer:** em `arte/predios.py` (`outdoor`), painel deitado e
    textura de "foto" inventada, várias cores por tela, sem marca real e
    sem vermelho dominante (vermelho aceso é freio).
  - **Aceite:** com o glow da V12, o outdoor continua o ponto mais claro
    abaixo do horizonte e, ao lado da `t3.0s`, lê como o dela.

- [x] **V14** — Céu com nuvem (12/10/2026, #87)

  O céu de hoje é gradiente liso. O vídeo e as imagens têm cúmulo branco,
  gordo, de borda dura e base azulada, concentrado numa faixa baixa — e com
  banda de cor visível, que é o sotaque que o `DIRECAO_VISUAL.md` pede.

  - **Referências:** as quatro paradas (`01_centro` e `02_praca_maua`, tufo
    pequeno espalhado no céu todo; `03_viaduto`, cúmulo à direita;
    `04_vertical`, véu fino à esquerda) e `video_01/t1.0s`, `t2.0s`, `t3.0s`
    (cúmulo gordo no alto e acúmulo acinzentado perto do horizonte).
  - **O que fazer:** `ceu_nuvens.png` (2048×1024, equirretangular, alfa =
    cobertura, **já dithered**) gerado por script em `arte/`, ligado em
    `ProceduralSkyMaterial.sky_cover`, com `use_debanding` desligado.
  - **Aceite:** nuvem visível nos quatro quadros da prova, sem cintilar com a
    câmera andando. Baseline visual de céu anda, com o motivo.
  - **Resultado:** a textura saiu, e o céu virou shader próprio
    (`scripts/ceu.gdshader`). A `ceu_nuvens.png` do plano chegou a existir e
    o Guilherme achou estranha; jogando, foram comparadas cinco saídas
    (textura com trama, textura lisa, nuvens esparsas, shader de ruído e
    nuvem como objeto no mundo) e ganhou o shader. A forma levou mais três
    voltas, cada uma contra as referências: ruído recortado era "poça de
    leite"; cúmulo de domo arrumado não é o que elas têm; e tufo desenhado
    como círculo empilhava em bolas. O que ficou:
    - **campo de tufos**: cada tufo soma uma bolha macia (metaball) e a nuvem
      é onde a soma passa do limiar, então vizinhos se fundem num contorno
      só, com o pé quase reto; uma máscara de baixa frequência agrupa os
      tufos e deixa azul entre os grupos;
    - **perspectiva**: o olhar é projetado num teto de nuvem
      (`tan(elev)^-0,35`; o plano puro achatava demais), e o tufo encolhe
      para o horizonte;
    - **banco no horizonte**: a cobertura cresce lá embaixo, com tufos do
      dobro do tamanho que só existem ali;
    - **cinza onde acumula**: o tom sai da forma da massa (a densidade caindo
      para cima é o alto, ao sol) e da espessura somada, em cinco faixas de
      cinza azulado até o branco; a nuvem do horizonte puxa para a cor dele;
    - **sem tremer andando**: contorno e troca de faixa são rampa de um pixel
      por `fwidth`, e a trama é a da paleta da tela. Trama própria presa à
      tela na borda, com a nuvem deslizando, era o tremor da V28 de novo.
    O gradiente é o mesmo do `ProceduralSkyMaterial` (cores e curva), para a
    luz ambiente não mudar; o Sky refaz o mapa de luz em modo incremental,
    porque o vento muda o céu todo quadro. Os números são sliders do F3,
    grupo Ceu (`WorldTuning`), e os defaults do repositório são os que foram
    aprovados jogando. O plano pedia nuvem numa faixa baixa: o Guilherme
    achou baixa e numerosa demais, e ela foi para o céu inteiro com banco no
    horizonte. Baseline visual: `visual_fracao_ceu` 0,107 → 0,126 e
    `visual_luminancia` 0,474 → 0,500, pelo branco da nuvem e pela luz
    ambiente mais clara (a fração de céu provavelmente sobe porque o banco do
    horizonte, puxado para a cor dele, fica parecido com o prédio distante na
    neblina). Portão sem variação; `fps` no teto de 120.

### A calçada povoada

O critério dos cinco itens abaixo é um só, e vem do vídeo: **algo passa ao
lado da câmera a cada 0,3–0,5 s, de cada lado**. Hoje é um poste a cada
~0,75 s, de um lado só por vez. Cada item mede isso e o `fps`.

- [x] **V15** — Poste de dois braços (12/10/2026, #88)

  O referencial de velocidade mais limpo do vídeo: ornamental, 8–10 m, dois
  braços curvos com luminária. Substitui a caixa de 0,35 × 6 m. O colisor fica
  igual, porque é ele que serve ao combate (dá pra jogar rival no poste).

  - **Referências:** `video_01/t1.0s` (o de dois braços curvos, na calçada
    da direita) e `t0.0s`; `01_centro` (curvo no meio da avenida e de globo
    na frente do teatro); `02_praca_maua` (braço único com luminária, à
    esquerda); `04_vertical` (alto, à direita).
  - **Aceite:** o braço do poste cruza o topo do quadro na V04.
  - **Resultado:** `arte/poste.py` gera o poste do vídeo
    (`video_01/t1.0s.png`): fuste liso cinza-chumbo até 6,8 m, que abre em
    dois braços em tulipa até 10 m, com cabeça chata de LED na ponta de cada
    um. A primeira versão, verde com globo e pescoço de cisne, ficou longe
    da referência e foi refeita. O braço tem 12 cm, o dobro do real, para não
    piscar a 20 m. O poste saiu da faixa de serviço para 0,6 m do meio-fio
    (`Poste.LATERAL`), como no vídeo. De lá a cabeça de 3,2 m chega sobre a
    faixa da direita e cruza o topo do quadro. Na calçada, ele agora fica no
    andável: quem sobe nela desvia. O colisor continua a caixa de
    0,35 × 6 m, nos eixos do mundo. Rival que termina a corrida passou a
    encostar depois da linha dos postes, senão parava em cima de um. A prova
    de combate usava um rival de corrida já terminada e passou a correr com
    ele. `selftest` sem variação; baseline visual dentro da tolerância;
    `fps` igual ao da master, os dois no teto de 144.

- [ ] **V16** — Palmeira e árvore de copa, inclusive por cima da pista

  O que mais diz "cidade quente" e "Rio". E a árvore de copa larga debruçada
  sobre a pista resolve o item 4 de *Como o vídeo vende velocidade*: passar
  **por baixo** de algo, que o jogo hoje não tem.

  - **Referências:** `01_centro` (palmeira e copa larga à esquerda);
    `02_praca_maua` (palmeiras no morro, copa no alto à esquerda);
    `video_01/t1.0s` (palmeiras à esquerda), `t2.0s` (copa larga no
    canteiro) e `t3.0s` (copa por cima, na borda esquerda).
  - **Como:** rota A do `DIRECAO_VISUAL.md` (numeroso, estático, visto de
    longe): `MultiMeshInstance3D` com quad billboard, ou low-poly se o
    billboard não aguentar a câmera baixa da V04. Decidir pela prova.
  - **Aceite:** a copa passa por cima da câmera e escurece o quadro por um
    instante; palmeira em grupo de 2–3 na faixa de serviço.

- [ ] **V17** — Mobiliário: lixeira, mupi, placa de curva, canteiro

  Barato, e cada um é um bloco de cor que marca distância: caçamba
  vermelho-alaranjada (cuidado para não competir com a bag do jogador), mupi
  de ponto de ônibus iluminado (usa o glow da V12), losango amarelo antes da
  curva, faixa de grama entre calçada e prédio nos trechos de praça.

  - **Referências:** `01_centro` (mupi iluminado à esquerda, caçamba
    vermelha dos dois lados, placa amarela); `video_01/t1.0s` (caçamba à
    esquerda, lixeira à direita), `t2.0s` (losango amarelo e faixa de grama à
    direita) e `t3.0s` (losango no alto à direita).
  - **Aceite:** o critério de densidade da seção, junto com V15 e V16.

- [ ] **V18** — Por cima da pista: semáforo suspenso e placa verde

  O "portal" de cruzamento do vídeo e a placa verde de rodovia das imagens
  paradas (pilar 9). **Só cenário**: semáforo com lógica saiu do protótipo de
  propósito (`PROTOTIPO.md`, *O que não está aqui*). Nomes de via reais são
  livres; marca não.

  - **Referências:** `02_praca_maua` (semáforo suspenso e placa verde e
    azul por cima da pista); `03_viaduto` (placa verde em braço, viaduto por
    cima); `04_vertical` (placa verde e azul); `video_01/t2.0s` e `t3.0s`
    (semáforo em braço, com o losango).
  - **Aceite:** nos cruzamentos da V10, o braço do semáforo passa por cima da
    câmera.

- [ ] **V19** — Pedestres

  Textura de vida nos dois lados, em pé, andando e na esquina. Billboard em
  `MultiMesh`, sem lógica nenhuma, e ninguém atravessa a pista.

  - **Referências:** `01_centro` (dezenas, dos dois lados e na escadaria);
    `02_praca_maua` (nas duas calçadas); `video_01/t1.0s` (escadaria do
    teatro) e `t3.0s` (esquina).
  - **Aceite:** gente visível na calçada nos quatro quadros da prova; o `fps`
    não regride além do orçamento com a calçada inteira povoada (V15–V19).

### O trânsito

- [ ] **V20** — Trânsito do vídeo: denso, quase na velocidade da moto

  No vídeo o táxi fica emparelhado quase 2 s e o corredor dura um segundo
  inteiro, porque o trânsito anda **quase na velocidade da moto**: 8–15
  veículos visíveis, 2–4 nos primeiros 20 m, corredor de menos de 1 m. Aqui os
  carros são obstáculos mais lentos, e o corredor vira um piscar.

  - **Referências:** `video_01/folha` (a linha do tempo inteira),
    `t0.0s` (táxi emparelhado), `t3.0s` (caminhão baú), `t4.5s` e `t5.0s`
    (o corredor); `03_viaduto` e `04_vertical` (caminhão baú no fundo).
  - **O que fazer:** sessão de F3 com trânsito mais rápido e mais denso, com a
    raspada (`near_missed`) como métrica; o que ficar vira default. Lanterna
    sempre acesa (no vídeo todas estão), com o freio mais forte por cima.
    Caminhão baú e van entram no elenco do `arte/carros.py`.
  - **Mexe no feel, e talvez no `selftest`** (densidade). Baseline com motivo.
  - **Aceite:** jogando, o corredor entre dois carros dura e puxa o jogador
    para dentro; a contagem de raspadas por corrida sobe.

### O ator

- [ ] **V21** 👤 — A roupa do entregador

  Camiseta de manga curta, bermuda jeans e tênis, no lugar da jaqueta: lê como
  entregador de verdade, com antebraço de fora. A bag continua quadrada e
  rígida. Depois da V04, porque a 29% da tela a diferença mal aparece.

  - **Referências:** `01_centro` e `02_praca_maua` (camiseta, bermuda jeans,
    antebraço de fora), `04_vertical` (camiseta escura e calça) e
    `video_01/moto_ampliada`.
  - **Decisão 👤:** a cor. Camiseta e bag vermelhas são a identidade de um app
    real, e o `PROTOTIPO.md` proíbe cor exata de app real. **Recomendação:**
    manter a bag na cor do corredor (é a troca de paleta dos rivais) e a
    camiseta num tom escuro dela, como a jaqueta faz hoje.
  - **Onde:** `arte/entregador.py` (fonte), regerar `assets/entregador/`.
  - **Aceite:** de trás, na câmera da V04, lê camiseta e bermuda; os rivais
    continuam um por cor.

- [ ] **V22** — Cadência do ator: 12 fps ou liso

  A P5 que ficou aberta. O `DIRECAO_VISUAL.md` diz que a cadência travada é o
  que faz o ator ler como digitalizado; o vídeo é liso a 24 fps e tira um
  argumento dela. A V03 já decidiu quanto de pixel; aqui se testa o que
  sobrou.

  - **Referências:** `video_01.mp4` e `video_02.mp4`, **rodando**: cadência
    é movimento, e quadro parado não decide nada aqui.
  - **O que fazer:** cadência do `Entregador` travada como opção (pose
    calculada a 60 Hz, aplicada a 12), com slider. Julgar **rodando**, com
    rivais e trânsito em volta.
  - **Aceite:** a decisão escrita aqui, com o default que ficou.

### Partículas

Nenhuma referência do repositório mostra partícula: nas quatro paradas e nos
dois vídeos ninguém derrapa nem cai. O pilar 5 vem do `DIRECAO_VISUAL.md`, não
de uma imagem. Ficam depois do cenário por isso, e
porque dependem do glow (V12). O catálogo inteiro e as quatro regras de
partícula em pixel estão no `DIRECAO_VISUAL.md`, *Partículas*.

- [ ] **V23** — Fumaça de pneu e marca de derrapagem

  Gatilho já existe: a derrapada de `player_bike.gd::_integrate`. Flipbook de
  fumaça com alfa macio, `fixed_fps` em 12–15; marca como `Decal` (não
  `AtlasTexture`, que o `Decal` recusa).

  - **Referências:** nenhuma das de `docs/referencias/` mostra fumaça. O alvo
    sai do `DIRECAO_VISUAL.md`, *Partículas*.
  - **Aceite:** derrapou, fumaçou e marcou; andou reto, nada.

- [ ] **V24** — Faísca, poeira de queda, impacto do soco e fogo

  Faísca no sinal `scraped(intensity)`, poeira no `crashed`, impacto no
  `punch_landed`, fogo com `OmniLight3D` pulsante na moto caída. Aqui se
  confirma se `GPUParticlesCollisionHeightField3D` enxerga mesh sem colisor;
  se não, a alternativa sem ferir o invariante do chão já está desenhada.

  - **Referências:** nenhuma das de `docs/referencias/` mostra faísca, poeira
    nem fogo. O alvo sai do `DIRECAO_VISUAL.md`, *Partículas*.
  - **Aceite:** cada efeito no evento certo; `fps` no **pior caso** (queda no
    meio do trânsito); nenhuma medida do `selftest` depende de partícula.

### HUD

- [x] **V25** 👤 — A HUD de arcade (08/10/2026, #62)

  Mesmo vocabulário nas cinco referências: quatro cantos, centro vazio,
  legenda pequena itálica com degradê amarelo→laranja, valor grande branco com
  contorno preto grosso, barras segmentadas de verde a vermelho com os
  segmentos apagados em cinza. Estática: não treme com a câmera.

  - **Decisão 👤:** o conteúdo. A corrida é de A a B com prazo, não de volta.
    **Recomendação:** `POS` no topo esquerdo, **distância restante** no topo
    direito (no lugar do `LAP`), `SPEED` com barra embaixo à esquerda, `TIME`
    regressivo com a barra apagando conforme o prazo acaba embaixo à direita.
    Estrelas num canto discreto; combo `CORREDOR xN` como texto que aparece e
    some no centro alto; adrenalina como efeito na borda da tela.
  - **O que fazer:** fonte bitmap (antialias, hinting e subpixel desligados),
    layout desenhado para 640×360 em vez do `Hud.ESCALA = 2` sobre 320×180.
    Continua dentro do SubViewport e acima da quantização.
  - **Aceite:** legível a 640×360 sobre asfalto claro, que é o pior fundo.

  **Resultado:** conteúdo da recomendação, decidido pelo Guilherme, com uma
  troca: a adrenalina foi para a borda e voltou. A borda pontilhada lia como
  moldura de outro jogo; ficou uma barrinha `BOOST` de 8 segmentos embaixo das
  estrelas (ciano enchendo, amarela queimando). Fonte gerada em código
  (`scripts/fonte_hud.gd`: itálico, negrito, contorno e degradê assados no
  glifo), não `FontFile`, porque fonte bitmap no Godot não tem contorno nem
  degradê. A medida do `shots` passou a ser **sem HUD** (a HUD nova sozinha
  subia a `fracao_ceu`): `fracao_ceu` 0,139 → 0,104 e `familias_de_cor`
  51,5 → 45,8, só por tirar a HUD velha da conta. `fps` igual ao do `master`
  (p50 8,33 ms nos dois, mesma máquina).

### Tela e resolução

O mundo renderiza em 640×360 e a janela amplia. Custo de GPU fixo, seja a tela
de 720p ou 4K, e é por isso que a escolha escala. O que sobra de problema está
no passo de ampliar, não no render.

- [x] **V28** — Tela cheia sem tremor nem cintilação em movimento (12/10/2026)

  Em `scale_mode = fractional` com filtro nearest, toda janela que não é
  múltipla inteira de 640×360 (tela de Mac a 3,76×, 1366×768, 1600×900) faz
  colunas de pixel de larguras diferentes, e com a câmera andando cada borda
  pula de coluna a cada quadro: a tela inteira vibra.

  **Resultado:** `scripts/ampliacao.gdshader` no `SubViewportContainer`
  ("sharp bilinear"): nearest no miolo do pixel, rampa de um pixel de tela na
  costura, com o filtro do container em linear. Em escala inteira é idêntico
  ao nearest, então `shots` e `prova` (1920×1080, 3×) não andaram. Custo: uma
  passada na resolução da tela, a mesma cópia que já existia.

  Jogando, isso sozinho não mudou quase nada: o tremor maior vinha do render
  sem antialiasing (faixa pintada, quina de prédio e caixilho mais finos que
  um pixel acendendo e apagando). Entraram junto **MSAA 4×** no SubViewport e
  filtro **trilinear** na textura dos prédios (era nearest). Na `prova` o
  quadro parado fica quase igual; `shots` andou menos de 1%; `fps` igual
  (p50 8,33 ms, mesma máquina da V25).

  O que ainda tremia era a **borda das sombras**, só andando. Sombra não passa
  pelo MSAA (é sombreamento, não geometria), e dura ela é mais fina que o
  pixel. Ficou macia na qualidade máxima de PCF com `shadow_blur = 3`, uma
  penumbra de ~1 pixel em todas as divisões; anisotrópico do chão subiu de 4×
  para 16×. Testado e descartado no caminho: sombra dura (continua
  serrilhando), FOV em degraus (o Godot escala a sombra pelo FOV, mas não era
  isso que se via) e dither mais fraco (não era ele). `shots`:
  `familias_de_cor` +3,6%, o resto abaixo de 1%; `fps` igual.

- [ ] **V29** — Proporção de tela: tarja ou mais mundo

  Com `aspect = keep`, tela 16:10 (Mac, Steam Deck) ganha tarja em cima e
  embaixo, e ultrawide (21:9) ganha tarja dos lados. A alternativa é
  `aspect = expand`: o mundo cresce na largura ou na altura em vez de tarja.

  - **Referências:** não se aplica, é a tela e não a cena. As paradas vêm em
    proporções diferentes (`01` e `02` em 4:3, `03` em 16:9, `04` vertical),
    e nenhuma serve de alvo para isso.
  - **O risco:** mexe no enquadramento da câmera (FOV horizontal muda com a
    proporção) e na HUD, que hoje é desenhada para 640×360 cravado. Os quatro
    cantos teriam de ancorar na borda real, e a `prova` e o `shots` teriam de
    continuar em 16:9 para comparar com o baseline.
  - **Aceite:** jogando em 16:10 e 21:9, sem tarja, a HUD nos cantos e o
    piloto no mesmo lugar relativo da tela.

- [ ] **V30** 👤 — Pixel grande demais em tela grande

  640×360 em 4K é 6× por pixel. É a estética que a V03 decidiu, mas em
  monitor grande perto do rosto o pixel pode passar de "look" a "borrado de
  propósito". Degraus com escala inteira nas telas comuns: 960×540 (perde
  720p) ou resolução interna escolhida pela tela (mais detalhe em 4K, o mesmo
  look em 1080p).

  - **Referências:** as quatro paradas, para o tamanho do pixel que o look
    pede; o pixel grande demais se julga na tela, não nelas.
  - **Decisão 👤:** se a resolução interna é fixa (o mesmo quadro para todo
    mundo) ou acompanha a tela. Fixa é mais fácil de afinar e de comparar na
    `prova`; variável muda o tamanho do dither e do pixel entre máquinas.
  - **Custo:** o render 3D cresce com o quadrado da resolução interna
    (960×540 são 2,25× os fragmentos de 640×360). Medir com `dev.py fps`.

### Fechamento

- [ ] **V26** — Barril na `GARUPA` (opcional)

  Última etapa da `REFERENCIA_CAMERA_GARUPA.md`: a distorção de barril que faz
  o poste curvar na borda, como a lente 0,5× do celular. Opcional porque
  reamostrar 640×360 briga com o pixel; só entra se a prova mostrar que não
  suja. Se sujar, marcar `[~]`.

  - **Referências:** `video_02/folha` e `video_02/tempo_1`–`tempo_4` (o poste
    curvando na borda, lente 0,5×).

- [ ] **V27** — O veredito

  A P9. A folha da V02 com o estado final, e a pergunta "isso é o mesmo
  jogo?" feita a alguém que não trabalhou no protótipo.

  - **Referências:** todas, pela folha do `dev.py prova --referencia`.
  - **Aceite:** a resposta escrita aqui e na `PROVA_VISUAL.md`, com a data.
    Sim ou não, as duas são resultado.

## Fora do backlog

Herdado dos estudos, e continua fora: chuva, noite, asfalto molhado e neon;
áudio; semáforo com lógica; marca, logo ou cor exata de app real; shader de
mundo curvo; e perseguir a referência pixel a pixel, porque o alvo é a
leitura em meio segundo, não o quadro.
