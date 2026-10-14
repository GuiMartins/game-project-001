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
- **Cenário é kit, não cenografia.** Todo elemento de cenário (prédio,
  mobiliário, pintura, fundo, trecho de via, peça de HUD) sai como peça
  **reaproveitável**: gerada por script em `arte/` com os números como
  parâmetro, montada pela `Cidade` a partir da semente, e sem nada preso a
  um ponto da pista, a uma imagem de referência ou a uma única corrida.
  O teste é a próxima fase: se uma outra avenida, outra cidade ou outro
  trecho não consegue usar a peça só mudando parâmetro e sorteio, ela foi
  feita como cenografia e não serve. Vale a mesma régua do `CLAUDE.md` para
  moto e piloto: o que muda de uma variante para outra sai de dado (lista,
  paleta, atlas), nunca de `if` por lugar. *Por quê:* a fila ainda pede
  via expressa, fundo e obra, e o jogo vai querer mais de uma rua; peça que
  só existe para casar com uma parada vira refação na segunda.

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

- [x] **V07b** — Bag do vídeo: mais larga que alta, capacete por cima (13/10/2026, #92)

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

  **Resultado:** a `Bag` foi de 0,45 × 0,43 m, com o topo na nuca, para
  0,51 × 0,36 m (~1,4 para 1), com o topo na linha do ombro e a base perto
  do banco. Na prova de trás o capacete sobra inteiro acima dela, e os
  cotovelos ainda passam das bordas. Regeradas a CG, a XRE e a PCX. Só
  malha, sem peça nova: baseline sem variação, sem `fps`.

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

- [x] **V08a** — Borrão que risca o asfalto já em cruzeiro (13/10/2026, #93)

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

  **Resultado:** as duas causas, as duas consertadas. A força segue uma
  curva (`Borrao.CURVA` 0,6) e a 128 km/h está em 71% do inteiro, e não em
  55%. O chão abaixo do ponto de fuga borra até 3× mais no pé da tela
  (`chao` no shader), e o teto do risco foi de 0,1 para 0,14 da tela. O
  asfalto ganhou contraste em `arte/chao.py`: remendo 12 → 22, trilha de
  pneu −24 → −32 e um veio longitudinal de palmo (14), com semente própria
  para a calçada não mudar. Na folha a 128 km/h o terço de baixo e a zebra
  riscam, o piloto fica nítido e o rival a 15 m lê; a referência ainda
  risca mais claro e escuro, porque o asfalto dela tem mais contraste que o
  nosso. `fps` p50 8,33 ms, preso no refresh de 120 Hz deste Mac, como na
  V08. Baseline sem variação.

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

- [x] **V09a** — Meio-fio que lê, e calçada de pedra quente (13/10/2026, #94)

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

- [~] **V10a** — Pintura de canalização e faixa azul (14/10/2026)

  O chão do cruzamento da `02_praca_maua` não é só zebra: a ilha entre as
  pistas tem área zebrada (hachura branca diagonal dentro de um contorno),
  e a `01_centro` tem uma faixa azul contínua colada ao meio-fio da direita.

  - **Referências:** `02_praca_maua` (hachura em volta da ilha, à direita
    do quadro, e a rua que abre em leque); `01_centro` (faixa azul junto ao
    meio-fio da direita, do primeiro plano até o fundo).
  - **Reaproveitável:** a hachura é um tipo de pintura da `RoadTrack.pintar`
    (contorno + ângulo + espaçamento), não um decalque desenhado para um
    cruzamento; a faixa azul é uma linha de bordo com cor e largura de
    parâmetro, ligada por trecho. A mesma peça serve de ilha, de bifurcação
    e de acesso de via expressa (V11b).
  - **O risco:** hachura é coisa fina atravessada, justamente o que a regra
    da P4a (`arte/chao.py`) proíbe abaixo de 1,7 m de período. Espaçar e
    engrossar até não piscar, como a V10 conferiu a zebra.
  - **Aceite:** a hachura não pisca a 180 km/h, julgado rodando; `fps` igual.
  - **Cancelada pelo Guilherme:** desnecessária. Chegou a ser feita (bico
    hachurado na saída de cada rua e faixa azul em metade dos corredores) e
    foi revertida sem entrar: a pintura que a avenida já tem basta.

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

- [x] **V11a** 👤 — Refazer a fachada: cânion de pedra bege, não bloco pastel (13/10/2026, #95)

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
  - **Decisão (13/10/2026, Guilherme):** o largo **fica, como praça**.

  **Resultado:** paredes só em pedra e reboco de pedra (bege, ocre, creme;
  `Predio.PINTURAS`), cor viva só no toldo e no outdoor. O mural saiu da
  empena do `Comercio`, que ficou lisa, e as cores dele saíram da paleta.
  Cornija saliente com faixa de sombra embaixo no topo do `Comercio`, do
  `Deco` e da `Torre` (o `Sobrado` já tinha). O corredor sorteia de 12 a
  30 m, e não de 6 a 26: sai sobrado, entra mais deco e torre, e o cânion
  sai pelo topo do quadro. O largo ficou mais curto (40–80 m, era 60–130) e
  menos recuado (4–7 m, era 8–12), com canteiros de mureta e grama no
  recuo, com colisor; árvore e gente ficam para a V16 e a V19. Janela com
  moldura já existia. `fps` p50 8,33 ms (refresh de 120 Hz). Baseline sem
  variação.

- [x] **V11b** 👤 — Trecho de via expressa: viaduto, muro com mural, mureta e cerca (14/10/2026)

  Metade das paradas não é avenida de centro. A `03_viaduto` corre embaixo
  de um tabuleiro elevado de concreto apoiado em pilares retangulares
  pintados de mosaico (arara, rosto), com um canteiro de mureta de concreto
  separando a pista ao lado e um muro comprido coberto de mural do outro. A
  `04_vertical` é uma via expressa entre muros altos de mural e grafite, com
  cerca de tela e arame farpado em cima do muro da direita, poste alto de
  braço e grama na base do muro. A `02_praca_maua` tem o muro de pedra com
  pichação. A V11a tirou o mural da fachada justamente porque ele é de muro
  de via expressa, e nenhum item o pôs no lugar certo; o `DIRECAO_VISUAL.md`
  já previa o viaduto na fase 7.

  - **Referências:** `03_viaduto` (tabuleiro, pilares pintados, mureta,
    muro de mural e contêiner); `04_vertical` (muros de mural, cerca com
    arame, poste alto, grama); `02_praca_maua` (muro de pedra pichado à
    esquerda e grafite na base do poste).
  - **Decisão 👤:** como a via expressa entra na corrida.
    **Recomendação:** como **tipo de trecho** que a `Cidade` sorteia ao lado
    do quarteirão e da praça (`_sorteia_trechos`), e não como pista própria:
    a mesma corrida passa de avenida para via expressa e volta, que é o
    ritmo "aberto/fechado" que o vídeo pede, e o viaduto é um vão por cima
    de parte do trecho. Na via expressa não há cruzamento, pedestre nem
    calçada larga; a borda é muro.
  - **Reaproveitável:** um kit em `arte/` (`via_expressa.py` ou dentro de
    `predios.py`), com peças modulares: vão de tabuleiro de comprimento
    paramétrico, pilar, módulo de muro, mureta, painel de cerca com arame,
    poste alto. Os murais e o grafite saem de um **atlas** de painéis
    gerado por script e sorteado por módulo, nunca um mural único pintado
    para casar com o quadro da `03`. O muro segue a curva e a rampa da
    `RoadTrack` como a calçada segue. Nada disso tem colisor de chão (o
    invariante); muro e pilar têm colisor de parede, como a fachada.
  - **Aceite:** na folha, um quadro da prova dentro do trecho lê como a
    `03_viaduto` e outro como a `04_vertical`; a sombra do tabuleiro passa
    por cima da moto; `fps` medido no pior caso (embaixo do viaduto, com
    trânsito).
  - **Decisão (14/10/2026, Guilherme):** tipo de trecho, como recomendado, e
    **somando pista**: a expressa não toma o lugar de um corredor, a corrida
    fica mais longa por ela.

  **Resultado:** duas expressas por corrida, de 320 a 480 m, depois do
  segundo e do quarto corredor (`Cidade.EXPRESSA_*`): a pista foi de 3,2 para
  4,0 km com a semente fixa. Os 3,2 km da avenida saem idênticos e o gerador do
  mundo gasta o mesmo que gastava (a pista a mais, os postes dela e os painéis
  saem de geradores próprios); com as expressas desligadas o banco de provas
  bate o baseline antigo sem variação. O kit é `arte/via_expressa.py` (atlas
  de 16 painéis de mural e grafite, concreto com limo, tela de alambrado com
  furo) e `scripts/via_expressa.gd`, extrudado na curva como o meio-fio: lado
  fechado com grama, muro de 5,5 m e alambrado com aba de arame; lado aberto
  com mureta, pilares pintados, pista de serviço e muro baixo; o tabuleiro de
  7 m chega e vai embora de lado nos 60 m das pontas, e cobre a pista até
  passar do eixo. O acostamento fica livre. Na expressa não há cruzamento,
  prédio, pedestre nem travessia, e o poste do lado do viaduto não nasce
  embaixo dele; a placa verde entra 50 m depois da entrada. A prova ganhou os
  quadros `muro` (ao lado da `04`) e `viaduto` (da `03`), que saíram da curva
  e da ladeira. Baseline: na corrida solta o piloto automático fugia do
  trânsito pela calçada esquerda a 1028 m, onde agora há mureta; até ali as
  duas corridas são iguais quadro a quadro, e a distância (−14%), a posição,
  o líder e a batida que vem depois andaram por isso; o desnível subiu 0,9 m
  com a pista a mais. Visual: fração de céu +22% de dia e +21% de noite, o céu
  por cima do muro onde antes havia prédio. `fps` p50 8,33 ms, p95 8,39 ms
  (teto de 120 Hz). Ficou para depois: prédio atrás do muro baixo (o fundo é
  da V14a) e trânsito na pista de serviço.

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

- [x] **V13a** — Outdoor deitado, de foto colorida (13/10/2026, #96)

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

  **Resultado:** os dois outdoors deitados (telhado 7 × 4 m, bandeira
  3,8 × 2,2 m, era 2,8 × 4,2 em pé), com moldura e uma "foto" inventada por
  face, sorteada entre praia, produto e gente: manchas grandes em nove cores
  novas (`foto_*`), nenhuma vermelha, sobre o fundo que cada prédio pinta.
  A foto acende a 2 (`foto_brilho`) e o fundo a 4: a 4 a foto estourava em
  branco no tonemap. `fps` p50 8,33 ms (refresh de 120 Hz). Baseline sem
  variação.

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

- [x] **V14a** — O fundo: serra, morro e marcos do Rio (14/10/2026, #116)

  O que faz a tela ler "Rio" de longe é o que está atrás dos prédios, e o
  jogo hoje termina em torre e neblina. A `04_vertical` tem a serra azulada
  no horizonte, no fim da avenida; a `02_praca_maua`, um morro de pedra e
  mato com a igreja branca no alto e a roda-gigante e o prédio do museu
  atrás do cruzamento; a `01_centro` e o vídeo, a torre de igreja e as
  torres de vidro formando o *skyline* no fim da rua.

  - **Referências:** `04_vertical` (serra no horizonte, azul de
    distância); `02_praca_maua` (morro com igreja, roda-gigante, prédio
    baixo do museu); `01_centro` e `video_01/t0.0s`–`t2.0s` (torre de
    igreja, torres de vidro ao fundo).
  - **O que fazer:** três camadas de distância. Serra como silhueta em anel
    em volta do mundo (malha baixa ou faixa no shader do céu), com a cor
    puxada para o horizonte do `ceu.gdshader`; marcos como peças 3D baixas
    que aparecem no fim de reta; e o *skyline* de torres que já existe,
    conferido contra a referência.
  - **Reaproveitável:** a serra é um perfil gerado por semente e parâmetro
    (altura, rugosidade, cor), não a silhueta de um morro real desenhada à
    mão; os marcos são um **catálogo** (igreja no morro, roda-gigante,
    museu, torre de igreja) que a `Cidade` posiciona onde a pista dá vista,
    e trocar de cidade é trocar o catálogo. Nenhum marco nasce em
    coordenada fixa.
  - **Aceite:** a serra aparece no fim das retas dos quadros da prova sem
    cintilar andando; um marco, pelo menos, aparece numa corrida inteira
    sem repetir na mesma tela; `fps` igual.

  **Resultado:** a serra mora no `ceu.gdshader`: duas fileiras (a de trás
  alta e a da frente baixa e mais escura), perfil por azimute com ruído sobre
  o círculo (sem emenda), semente da semente do mundo, borda em rampa de um
  pixel (`fwidth`) como a da nuvem, e o sol não aparece através dela. Mais
  clara que o céu ela sumia: a 6° o gradiente já está a 38% do topo, então a
  cor é o ar escurecido (vale em qualquer hora). Sliders no F3, grupo Ceu:
  `ceu_serra_altura` (9°) e `ceu_serra_rugosidade`. Os marcos são o catálogo
  `Marcos.rio()` (igreja no morro, roda-gigante, museu, torre de igreja),
  em primitivas montadas no código e não em modelo do Blender: a 200 m é
  silhueta. A `Cidade` planta um no fim de cada reta, a 170–260 m e quase no
  eixo, porque o canyon de prédios esconde tudo que está de lado; as peças
  têm escala maior que o real pelo mesmo motivo, e não usam a neblina do
  mundo (a 250 m ela cobre 67% e apagava a roda), e sim o azul do ar na
  própria cor. Sorteio próprio, sem colisor, nunca a mesma peça duas vezes
  seguidas, folga da pista medida. A prova ganhou o quadro `fundo`, onde a
  roda-gigante aparece pela fresta do corredor. O canyon ainda esconde marco
  baixo (o museu) enquanto a moto está no corredor; ele aparece nas
  aberturas. Baseline visual dentro da tolerância (céu 0,100 → 0,096,
  luminância 0,452 → 0,445). `selftest` sem variação; `fps` p50 8,33 ms,
  igual.

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

- [x] **V16** — Palmeira e árvore de copa, inclusive por cima da pista (13/10/2026, #97)

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

  **Resultado:** low-poly, e não billboard: `arte/arvores.py` gera a
  palmeira (fuste de 9 m, onze folhas em arco, de face dupla) e a copa
  (tronco inclinado e um cacho de bolas de vinte faces em dois verdes,
  centrada 3 m para fora do tronco). O `Arvore` planta como o `Poste`, com
  malha compartilhada e colisor só no pé. A cidade planta um grupo a cada
  35–75 m de cada lado, na faixa de serviço: 40% copa, o resto duas ou três
  palmeiras; sorteio no gerador da cidade, depois de tudo, para não mexer
  em prédio nem no trânsito. A copa cobre a faixa da direita a partir de
  4,5 m de altura. Um primeiro jeito, com a copa achatada, saiu cogumelo
  ao lado da `t2.0s` e foi engrossado. `fps` p50 8,33 ms (refresh de
  120 Hz). Baseline sem variação.

- [x] **V17** — Mobiliário: lixeira, mupi, placa de curva, canteiro (13/10/2026, #98)

  Barato, e cada um é um bloco de cor que marca distância: caçamba
  vermelho-alaranjada (cuidado para não competir com a bag do jogador), mupi
  de ponto de ônibus iluminado (usa o glow da V12), losango amarelo antes da
  curva, faixa de grama entre calçada e prédio nos trechos de praça.

  - **Referências:** `01_centro` (mupi iluminado à esquerda, caçamba
    vermelha dos dois lados, placa amarela); `video_01/t1.0s` (caçamba à
    esquerda, lixeira à direita), `t2.0s` (losango amarelo e faixa de grama à
    direita) e `t3.0s` (losango no alto à direita).
  - **Aceite:** o critério de densidade da seção, junto com V15 e V16.

  **Resultado:** `arte/mobiliario.py` gera a caçamba (vermelho de tijolo,
  não laranja, para não ser um segundo entregador), o mupi aceso dos dois
  lados com uma foto (brilho 3, passa no glow) e o losango amarelo de curva,
  com a seta para cada lado (dois modelos: escala negativa vira o winding).
  Caçamba e mupi saem do mesmo sorteio da faixa de serviço que as árvores
  da V16, um item por ponto, para nunca cair um dentro do outro: em 3,2 km
  dão ~40 copas, ~130 palmeiras, ~17 caçambas e ~16 mupis. A placa vai
  50 m antes de cada curva que gira mais de 0,2 rad em 40 m, do lado
  direito, e lê o mesmo sinal da guinada (teste). A praça ganhou a faixa
  de grama colada na fachada. Lixeira ficou de fora: some a 640×360.
  `fps` p50 8,33 ms (refresh de 120 Hz), com um pico isolado de 76 ms,
  provavelmente compilação de shader. Baseline sem variação.

- [x] **V17a** — Obra: prédio no esqueleto e guindaste (14/10/2026, #117)

  A `04_vertical` tem um prédio de 20 andares no concreto cru, sem fachada,
  com dois guindastes de torre amarelos; a `03_viaduto` tem guindaste ao
  fundo, atrás do muro. É a silhueta que diz "cidade crescendo" e um marco
  alto que se vê de longe.

  - **Referências:** `04_vertical` (prédio no esqueleto à esquerda, dois
    guindastes); `03_viaduto` (guindaste ao fundo, à direita).
  - **Reaproveitável:** o esqueleto é o mesmo gerador de prédio da V11a com
    um parâmetro de "fase de obra" (só laje e pilar, laje com parte da
    fachada, pronto), e não um modelo à parte; o guindaste é peça própria
    com altura e lança de parâmetro, que a `Cidade` põe ao lado de qualquer
    prédio em obra, na avenida ou na via expressa (V11b).
  - **Aceite:** obra e guindaste aparecem na corrida e no fundo das retas;
    `fps` igual.

  **Resultado:** `arte/predios.py` ganhou `torre(rng, prontos, nome, lona)`:
  com todos os 16 andares prontos é a `Torre` de sempre (os cinco modelos
  antigos saem byte a byte iguais); com 0 é o esqueleto (laje, pilar, miolo
  do elevador, ferro de espera no topo) e com 8 é a meia-obra, metade de
  baixo vestida. Só o ferro no topo fazia a obra parecer prédio com defeito
  no último andar, então o corpo inteiro vira obra: **andaime tubular** só
  na frente, dentro da largura do corpo (o quarteirão encosta um prédio no
  outro, e andaime nas laterais entrava na parede do vizinho; 2,2 m para
  fora, para passar do toldo da loja, que avança 1,9 m, montantes até acima do topo,
  piso de tábua a cada 4 m, diagonais alternadas), **lona laranja ou azul**
  semitransparente (alpha de 0,62, numa segunda superfície da malha com
  material próprio; o xadrez de pixel furado que veio antes lia como ruído)
  por cima em painéis planos de uma baia por três andares, do chão ao topo e
  sem falha (buraco sorteado lia como lona rasgada), e o andaime desce até a calçada, sem tapume nem marquise (a tampa de madeira
  escondia o andaime do chão). São quatro malhas (esqueleto ou
  meia-obra, laranja ou azul): a lona é geometria, e não pintura por
  instância. Vira obra uma torre em cada três do corredor
  (`Cidade.OBRA_UMA_EM`), por **hash** da semente e da posição
  (`Cidade.fase_de_obra`), e não por sorteio do `rua`: o `rua` é
  sequencial, e a obra gasta os mesmos dois sorteios da torre que
  substitui, então a cidade que vem depois é a mesma. A planta e o colisor
  são os da torre (o passo e o `lateral` do quarteirão ainda saem da malha
  dela): o andaime e a lona ficam só na frente, dentro da largura do corpo. O guindaste é o `Guindaste.criar(altura, lanca, giro)`: trechos
  de mastro (3 m) e de lança (4 m) repetidos, mais o topo (cabine, torre em
  A, contra-lança com concreto) e o gancho, do mesmo `.glb` e do mesmo
  material, sem sombra (treliça projetada no chão cintila). Em cima da obra
  pisa na laje do topo, com 15 m de mastro e 28 m de lança virada para uma
  de oito direções; na via expressa, um de 36 m e 24 m atrás do muro alto de
  cada trecho. Fica de fora: a obra no largo (a torre não nasce lá) e o
  guindaste ao lado de um prédio no chão, que o `Guindaste.criar` já permite
  mas nenhum quarteirão pede.

- [~] **V17b** — BRT: estação e ônibus articulado (14/10/2026)

  A `03_viaduto` tem a estação de BRT comprida, de cobertura metálica e
  vidro, no canteiro da esquerda, com o articulado amarelo e branco parado
  nela. O ônibus da V20 é o comum.

  - **Referências:** `03_viaduto` (estação e articulado à esquerda,
    embaixo do viaduto).
  - **Reaproveitável:** a estação é modular (módulo de cobertura repetido
    pelo comprimento, cabeceira com rampa), posta no canteiro de qualquer
    trecho largo; o articulado entra no elenco do `arte/carros.py` como os
    outros, com a sanfona sendo o mesmo `Carro` em dois corpos, e roda no
    trânsito comum também, não só parado na estação. Cor de operadora sai
    de paleta, sem marca.
  - **Aceite:** a estação aparece onde há canteiro; o articulado anda no
    trânsito sem atravessar a curva (dois corpos seguindo a pista); `fps`
    igual.
  - **Cancelada pelo Guilherme** antes de começar. Era a maior peça da fila
    de cenário (estação modular, ônibus de dois corpos no trânsito, colisor
    que dobra na curva) para um elemento que só uma das referências mostra.

- [~] **V17c** — Placa de regulamentação (14/10/2026)

  A `02_praca_maua` tem a placa redonda de borda vermelha ("proibido virar
  à direita") no poste do semáforo. A V17 fez só a de advertência (losango
  amarelo de curva).

  - **Referências:** `02_praca_maua` (placa redonda à direita, no alto).
  - **Reaproveitável:** um gerador de placa por tipo (redonda de
    regulamentação, losango de advertência, que já existe) e por símbolo,
    num atlas; a `Cidade` escolhe a placa pelo que a pista tem ali
    (cruzamento, curva), e não por posição.
  - **Aceite:** placa lê a 640×360 a ~30 m; `fps` igual.
  - **Cancelada pelo Guilherme** antes de começar: a placa redonda no poste
    do semáforo não muda a pergunta do protótipo.

- [x] **V18** — Por cima da pista: semáforo suspenso e placa verde (13/10/2026, #99)

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

  **Resultado:** `Portal` (só cenário, foco sempre no verde): em cada
  cruzamento, na retenção, um poste do lado direito com braço de 9 m a 6 m
  de altura e dois focos pendurados encarando quem vem; em cruzamento sim,
  cruzamento não, um pórtico 30 m antes com a placa verde e azul de 5,4 ×
  2,6 m sobre as faixas da direita, com nomes de via do Rio em `Label3D`
  (Linha Vermelha, Av. Brasil, Rodoviária…), sem marca. Colisor só no
  fuste. `fps` p50 8,33 ms (refresh de 120 Hz). Baseline sem variação.

- [x] **V19** — Pedestres (13/10/2026, #100)

  Textura de vida nos dois lados, em pé, andando e na esquina. Billboard em
  `MultiMesh`, sem lógica nenhuma, e ninguém atravessa a pista.

  - **Referências:** `01_centro` (dezenas, dos dois lados e na escadaria);
    `02_praca_maua` (nas duas calçadas); `video_01/t1.0s` (escadaria do
    teatro) e `t3.0s` (esquina).
  - **Aceite:** gente visível na calçada nos quatro quadros da prova; o `fps`
    não regride além do orçamento com a calçada inteira povoada (V15–V19).

  **Resultado:** gente low-poly (`arte/pedestres.py`, 152 triângulos, de
  pé e andando), e não billboard, num `MultiMesh` por pose: mais de mil
  pessoas por corrida em duas chamadas de desenho. A camisa é a superfície
  `roupa`, pintada pela cor da instância. Grupos de 1–3 a cada 6–16 m de
  cada lado e 3–6 na esquina, entre a faixa de serviço e a fachada: fora do
  andável e longe dos troncos. Sem lógica, sem colisor. Gente visível nos
  cinco quadros da prova; com a calçada inteira povoada (V15–V19) o `fps`
  fica em p50 8,33 ms e pior quadro 9,09 ms (refresh de 120 Hz). Baseline
  sem variação.

  **Depois (#111):** o "sem lógica" e o "ninguém atravessa a pista" caíram.
  A gente do `MultiMesh` anda e vira no vértice (`pedestres.gdshader`,
  relógio no `Multidao`); quem atravessa a rua, desce do carro, pula da
  frente da moto ou voa no atropelo é a `Pessoa`, articulada, posada no
  código. A travessia (`Travessia`) é 4 na zebra das transversais para 1
  fora da faixa, na avenida. Todo pedestre tem atropelo, com mancha de
  sangue (`Sangue`), e a calçada perdeu o teto de velocidade.

### O trânsito

- [x] **V20** — Trânsito do vídeo: denso, quase na velocidade da moto (13/10/2026, #101)

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

  **Resultado:** aprovado jogando pelo Guilherme (13/10/2026), na primeira
  rodada. O fluxo sorteia entre 18 e 26 m/s (65–94 km/h; era 0 a 7 m/s),
  com 25 carros (eram 10), e a lanterna fica acesa a 35% andando, com o
  freio a 100% por cima. Para o carro rápido não entrar no lento: ele olha
  à frente até a distância de frenagem (era 24 m fixos) e freia a 7 m/s²
  (era 4,5). Baseline com motivo: raspadas 7 → 10 (o objetivo), corrida
  solta +2,9% de distância, quique da batida traseira −2,7% (o freio novo)
  e a disputa de 260 m de 1º para 6º, porque o trânsito andando segura o
  piloto automático. Caminhão baú e van foram para a V20a.

- [x] **V20a** — Caminhão baú e van no elenco (14/10/2026)

  A segunda metade da V20, separada para o feel entrar antes. O vídeo tem
  caminhão baú (`video_01/t3.0s`) e as paradas também (`03_viaduto`,
  `04_vertical`); o elenco do `arte/carros.py` só tinha hatch, sedã, SUV,
  táxi e ônibus.

  - **Referências:** `video_01/t3.0s` (baú no fundo, na faixa da direita);
    `03_viaduto`, `04_vertical`.
  - **Feito:** `Bau` (VUC de 6,3 × 2,2 × 3,1 m, cabine avançada, baú de
    alumínio com nervuras, portas de trás com as barras de trava, barra de
    lanternas embaixo e rodado duplo) e `Van` (furgão de teto alto de 5,4 m,
    porta corrediça só desenhada) em `arte/carros.py`, com a árvore de nós dos
    outros. Na rua, 7% cada; a cabine sai da lista de frota de empresa, quase
    toda branca. O baú ficou de fora dos carros parados das ruas laterais
    (`cidade.gd`): lá o sorteio é outro, e mexer nele move a cidade inteira.
  - **O que o banco de provas pegou:** com carro mais comprido na rua, um
    carro entrou em outro três vezes. Eram três furos antigos no trânsito: o
    `_desencosta` contava a frenagem pela diferença de velocidade, como se o
    da frente não freasse, e não olhava quem estava trocando para a faixa; e o
    carro de trás só enxergava quem entrava na frente dele quando a lataria já
    estava na faixa. Os três consertados no `world.gd`.
  - **Aceite:** na prova a 128 km/h, um baú lê como o da `t3.0s`.

### O ator

- [x] **V21** — A roupa do entregador (14/10/2026)

  Camiseta de manga curta, bermuda jeans e tênis, no lugar da jaqueta: lê como
  entregador de verdade, com antebraço de fora. A bag continua quadrada e
  rígida.

  - **Referências:** as T-poses de `docs/referencias/tpose/` (feitas no Google
    Flow, a partir das folhas do sprite da #102), `01_centro` e
    `02_praca_maua`.
  - **Decisão 👤, tomada:** vermelho. Camiseta e bag vermelhas lisas, como
    nas T-poses e no sprite, sem nome nem logo; a *Nota de marca* do
    `PROTOTIPO.md` registra a troca. Das T-poses, a da bermuda e tênis, que
    bate com o vídeo; as outras duas são de calça e bota.
  - **Feito:** em `arte/entregador.py`, camiseta com boca de manga e braço de
    pele, gola e pescoço, alças da bag cruzando o peito com tira de peito,
    vivo escuro em volta da bag, bermuda com a barra dobrada, canela de fora,
    tênis de sola clara e capacete preto de viseira fumê. Árvore de nós e
    pivôs intactos, então as três motos regeraram sem tocar no ator.
    `PlayerBike.COR` foi para o vermelho da bag, a camiseta escurece 0,1 da
    cor do corredor (era 0,6: a jaqueta escura não era a roupa das folhas), e
    o rival rosado virou laranja para não encostar no jogador.
  - **Aceite:** de trás, na câmera da V04, lê camiseta e bermuda; os rivais
    continuam um por cor (`dev.py prova`).

- [x] **V22** — Cadência do ator: 12 fps ou liso (14/10/2026, #106)

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
  - **Feito:** `Cadencia`, filha do `Entregador`, e o slider
    `ator_cadencia` no grupo Ator do F3 (0 a 30; 0 é liso). Mola, roda, voo
    e soco seguem integrando a 60 Hz; só a pose aplicada espera a vez, e
    quando sai é a do estado de agora (o teste confere roda contra roda com
    o ator liso). A trava segura também a rotação do ator no mundo, então a
    inclinação do `Visual` e a virada do corpo pulam junto; só a posição na
    pista fica lisa, porque a câmera segue o corpo a 60 Hz e a moto parada
    enquanto a câmera anda tremeria a tela inteira. Vale para jogador e
    rivais, no 3D e no sprite.
  - **Decisão 👤, jogando: 12 é o default.** O primeiro corte travava só o
    miolo (roda, guidão, joelho), com a inclinação lisa por fora, e o
    Guilherme pediu a inclinação junto. Os vídeos de referência são lisos a
    24 fps; na tela de pixel, o travado leu melhor. O `selftest` não anda
    (física intocada).

### Partículas

Nenhuma referência do repositório mostra partícula: nas quatro paradas e nos
dois vídeos ninguém derrapa nem cai. O pilar 5 vem do `DIRECAO_VISUAL.md`, não
de uma imagem. Ficam depois do cenário por isso, e
porque dependem do glow (V12). O catálogo inteiro e as quatro regras de
partícula em pixel estão no `DIRECAO_VISUAL.md`, *Partículas*.

- [x] **V23** — Fumaça de pneu e marca de derrapagem (14/10/2026, #108)

  Gatilho já existe: a derrapada de `player_bike.gd::_integrate`. Flipbook de
  fumaça com alfa macio, `fixed_fps` em 12–15; marca como `Decal` (não
  `AtlasTexture`, que o `Decal` recusa).

  - **Referências:** nenhuma das de `docs/referencias/` mostra fumaça. O alvo
    sai do `DIRECAO_VISUAL.md`, *Partículas*.
  - **Aceite:** derrapou, fumaçou e marcou; andou reto, nada.
  - **Feito:** `Derrapagem` (`scripts/derrapagem.gd`), no corpo da moto
    embaixo do eixo traseiro, em jogador e rival. Fumaça em
    `GPUParticles3D` com flipbook de quatro quadros gerado no código, alfa
    macio, 24 partículas, `fixed_fps` 12 (a cadência do ator) sem
    interpolar, herdando 90% do embalo para nascer no pneu e ficar para trás
    aos poucos. Marca em pool de 40 `Decal` de 0,8 m que desbotam em 6 s.
    O gatilho é a componente **lateral** da derrapada de `_integrate` (a de
    frente é a moto ganhando embalo): medida no piloto automático da
    `corrida`, curva normal escorrega 1–3,5 m/s; a fumaça liga em 4 e enche
    em 10, então sai na curva forçada e na pancada de lado. No ar e caído,
    nada (o tombo é faísca, V24). O rival é paramétrico e manda zero.
    `selftest` sem variação; teste próprio em `test_derrapagem.gd`.

- [x] **V24** — Faísca, poeira de queda, impacto do soco e fogo (14/10/2026, #118)

  Faísca no sinal `scraped(intensity)`, poeira no `crashed`, impacto no
  `punch_landed`, fogo com `OmniLight3D` pulsante na moto caída. Aqui se
  confirma se `GPUParticlesCollisionHeightField3D` enxerga mesh sem colisor;
  se não, a alternativa sem ferir o invariante do chão já está desenhada.

  - **Referências:** nenhuma das de `docs/referencias/` mostra faísca, poeira
    nem fogo. O alvo sai do `DIRECAO_VISUAL.md`, *Partículas*.
  - **Aceite:** cada efeito no evento certo; `fps` no **pior caso** (queda no
    meio do trânsito); nenhuma medida do `selftest` depende de partícula.

  **Resultado:** `scripts/estrago.gd`, no corpo de **toda** moto (jogador e
  rival), no chão embaixo do centro, como a `Derrapagem`. **Faísca** no
  `scraped` (um tranco de 0,12 a 0,35 s pela intensidade) e enquanto a moto
  deitada arrasta acima de 3 m/s: rampa de amarelo a vermelho acima do
  limiar do glow, para trás e para cima com metade do embalo, em **risco**
  de 2,5 × 25 cm alinhado à velocidade (o primeiro quadradinho de 12 cm lia
  como pipoca). **Poeira** no tombo, one-shot, com a nuvem da fumaça de pneu
  (`Derrapagem.nuvem`) tingida de terra, dez nuvens de 1,1 m para não
  esconder o carro em que a moto bateu. **Fogo** só na queda acima de metade
  do teto (26 m/s, ~94 km/h): chama em flipbook de 4 quadros gerado no
  código, presa na moto (solta no mundo, a moto deslizando deixava uma
  fileira de labaredas), e `OmniLight3D` laranja de 6 m que pulsa em degrau,
  na cadência da chama; apaga quando a moto levanta. **Estalo** do soco: 5
  lascas em quem levou, no `punch_landed` do jogador e no `hit_player` do
  rival. Tudo a 12 quadros por segundo, sem interpolar. O chão: o
  `GPUParticlesCollisionHeightField3D` rasteriza a geometria desenhada, mas
  com `follow_camera_enabled` refaz o campo todo quadro; ficou a alternativa
  do `DIRECAO_VISUAL.md`, uma `GPUParticlesCollisionBox3D` rasa com o topo
  no chão embaixo da moto, que a física não vê. Pior caso medido com o
  `dev.py fps --queda` (novo: jogador e pelotão no chão a cada 4 s, seis
  fogos com luz no trânsito), contra a `master` com o mesmo `--queda`: p50
  igual de noite (6,94 ms nos dois, refresh de 144 Hz) e pior quadro de 24
  ms contra 85; de dia 6,94 contra 9,09 ms, ruído. `selftest` sem variação;
  teste próprio em `test_estrago.gd`.

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

- [ ] **V25a** 👤 — Minimapa de GPS e nome da rua

  A V25 fechou antes de as paradas existirem e leu "quatro cantos, centro
  vazio" em todas. A `04_vertical` não é assim: no canto de baixo à esquerda
  ela tem um **GPS de celular**, e é o elemento que mais diz "entregador de
  app" na HUD inteira. Quadrado de ~16% da largura da imagem, moldura branca
  grossa com contorno preto (a mesma linguagem das barras), quarteirões
  azul-acinzentados com as ruas em branco, e uma seta vermelha fixa no centro
  apontando para cima: o mapa gira em volta dela (*heading-up*), não ela no
  mapa. Embaixo, o nome da rua em caixa alta (`AV. RODRIGUES ALVES`), na fonte
  da HUD, branco e sem degradê.

  - **Referências:** só a `04_vertical` (canto de baixo à esquerda). As
    outras três e os dois vídeos não têm mapa.
  - **Reaproveitável:** o minimapa lê qualquer `RoadTrack` (curva,
    cruzamentos, trecho de via expressa da V11b) e a lista de nomes é dado
    por cidade: outra pista ou outra cidade usa o mesmo widget sem mudar
    código.
  - **De onde sai o mapa:** a `RoadTrack` já sabe tudo. A avenida é a
    `curve`, e as transversais são os `cruzamentos` (`[offset, lados]`) com
    a `boca`: dá para desenhar no próprio `Control` da HUD, em 2D, a partir
    da curva amostrada em volta do jogador, sem câmera nem `SubViewport` a
    mais. Os quarteirões são o fundo; as ruas, linhas brancas por cima.
  - **Decisão 👤:** onde ele mora e de onde sai o nome.
    **Recomendação:** coluna da esquerda, **em cima do `SPEED`**, que é onde
    ficou espaço vazio entre o `BOOST` e as barras de baixo; ~72×72 a
    640×360, com o nome da rua entre o mapa e a legenda `SPEED`. Não trocar
    o `SPEED` de canto: a `01`, a `02` e a `03` põem ele ali. O nome sai de
    uma lista de avenidas do Rio sorteada pela semente da pista (uma por
    corrida, que hoje é uma avenida só), e as transversais não ganham nome.
    Sem rota desenhada: a corrida é uma reta de A a B, e uma linha em cima
    da avenida só repetiria a avenida.
  - **Aceite:** o mapa gira junto com a moto na curva e a transversal passa
    por ele quando o cruzamento passa na tela; legível a 640×360 sobre
    asfalto claro, como a V25; não entra na medida do `shots` (que é sem
    HUD); `fps` igual.

- [ ] **V25b** 👤 — HUD da vertical: barra do entregador e local da fase

  O resto da HUD da `04_vertical`, que a V25 e a V25a não pegam: no topo
  esquerdo, `ENTREGADOR` com uma barra de vida de verde a vermelho; no topo
  direito, `RIO DE JANEIRO` e `FASE 01`. O jogo hoje não tem vida nem fase,
  então este item depende de decisão de produto antes de ser HUD.

  - **Referências:** `04_vertical` (topo esquerdo e topo direito).
  - **Decisão 👤:** o que a barra mede, e se "fase" existe.
    **Recomendação:** a barra é a **integridade da moto**, que cai com
    pancada e tombo e dá sentido ao soco e ao corredor apertado; a fase é a
    corrida atual (cidade e número) até existir mais de uma, e então vira
    seleção no menu. Se a barra não tiver efeito no jogo, ela não entra:
    HUD que não muda decisão é enfeite.
  - **Reaproveitável:** barra e rótulo de local são peças do `hud.gd` que
    leem do `RaceRun` (nome da cidade, número da fase, integridade), sem
    texto fixo; trocar de cidade ou de fase é trocar dado.
  - **Aceite:** a barra reage à pancada no mesmo quadro; legível a 640×360
    sobre asfalto claro, como a V25.

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

## Feito fora da fila

- [x] **A corrida que anoitece.** Larga ao meio-dia e cruza a linha de noite,
  com céu, lua, LUT, postes, faróis, lanternas, janelas e vitrines. Não estava
  na fila: entrou por curiosidade, e o desenho está no `DIRECAO_VISUAL.md`.
  Não muda a "próxima tarefa", que continua sendo o primeiro `[ ]` acima.

## Fora do backlog

Herdado dos estudos, e continua fora: chuva, asfalto molhado e neon;
áudio; semáforo com lógica; marca ou logo de app real; shader de
mundo curvo; e perseguir a referência pixel a pixel, porque o alvo é a
leitura em meio segundo, não o quadro.
