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

## A fila

### Fundação

- [ ] **V01** 👤 — As quatro imagens paradas entram no repositório

  Hoje só os dois vídeos estão em `docs/referencias/`. As imagens chegaram num
  chat e nunca viraram arquivo, e a `PROVA_VISUAL.md` já registra isso como o
  único item do manifesto que só quem as tem pode produzir.

  - **O que fazer:** salvar em `docs/referencias/` como `01_centro.png`,
    `02_praca_maua.png`, `03_viaduto.png`, `04_vertical.png` (nomes da
    `PROVA_VISUAL.md`), por Git LFS.
  - **Aceite:** os quatro arquivos no repositório.
  - Não bloqueia os itens seguintes, só a folha de comparação (V02) e o
    veredito (V27). Se faltar, faz-se o resto e volta-se aqui.

- [ ] **V02** — Folha de comparação: o jogo ao lado da referência

  `dev.py prova` hoje compara o jogo com ele mesmo. Falta pôr o quadro do jogo
  **ao lado da referência**, que é a pergunta do projeto inteiro e o aceite da
  P9.

  - **O que fazer:** `dev.py prova --referencia` gera `.dev/prova/comparacao.png`:
    cada quadro da prova lado a lado com o quadro de referência mais próximo
    em enquadramento (`video_01/t*.png`, e as imagens da V01 quando
    existirem), na mesma altura.
  - **Aceite:** um comando, uma imagem, e ela sai igual nos três sistemas.
  - É ferramenta: daqui em diante todo item anexa a comparação no PR.

- [ ] **V03** 👤 — Decidir quanto de pixel

  A pergunta aberta nº 1 da `REFERENCIA_VIDEO.md`. As imagens paradas e o
  `DIRECAO_VISUAL.md` pedem pixel (640×360, dither, ator a 12 fps). O vídeo é
  "HD saturado com HUD de arcade", liso a 24 fps. Os dois são legítimos, e não
  são o mesmo look. Decide-se **antes** de pintar mais textura, porque muda o
  quanto investir em detalhe.

  - **O que fazer:** três variantes no mesmo quadro da prova, lado a lado com
    o vídeo: (a) como está, (b) sem a quantização e o dither, (c) com dither
    mais fraco (`paleta.gdshader`). Levar a folha para a decisão.
  - **Recomendação:** manter 640×360 (já está pago, e o vídeo também tem
    bloco de pixel no asfalto) e decidir só a força do dither. A cadência de
    12 fps do ator fica para a V22, que é onde ela se julga rodando.
  - **Aceite:** a decisão escrita aqui, com a data, e o default do shader
    ajustado se ela mudou alguma coisa.

### Enquadramento

- [ ] **V04** — Câmera de perseguição perto e baixa

  A maior distância entre o vídeo e o jogo, e a que decide o que todo o resto
  precisa mostrar: no vídeo o piloto ocupa ~53% da altura e a câmera está
  **abaixo do capacete**; no jogo, ~29% e acima. Com a câmera alta, o corredor
  vira mapa.

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

### A moto viva

- [ ] **V05** — Inclinação com mola: entra devagar, sai seca, passa do zero

  O vídeo deita em ~1 s e levanta em ~0,3 s, com uma contra-inclinação de
  4–8° no fim. O `lerp` exponencial de hoje nunca passa do alvo, então a troca
  de direção lê como ponteiro voltando ao centro, e não como peso.

  - **O que fazer:** trocar o `lerp` por mola (ângulo + velocidade angular)
    em `player_bike.gd`, retorno ~3× mais rápido que a entrada e *overshoot*
    pequeno. Os parâmetros viram slider.
  - **Mexe no `selftest`.** O baseline anda, e o corpo do commit diz quanto e
    por quê.
  - **Aceite:** jogando, a troca de lado no corredor tem peso: a moto deita,
    volta e assenta. Pico numa curva suave perto de 25°.

- [ ] **V06** — Vibração miúda, roda lisa em alta e cabeça no horizonte

  Três coisas pequenas de pose, todas no `Entregador`, nenhuma na física.

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

- [ ] **V07** — Postura do vídeo: sentado e de cotovelo aberto

  A 128 km/h o entregador do vídeo continua **sentado**, tronco a 10–15°, com
  os cotovelos bem abertos: são as pontas mais largas da silhueta, mais largas
  que a bag. O jogo deita o tronco com a velocidade (`TRONCO_DEITADO`).

  - **Onde:** `scripts/entregador.gd` (pose e IK dos braços).
  - **Aceite:** de trás, a silhueta mostra o losango braço-guidão. Faz mais
    sentido depois da V04, quando o piloto está grande na tela.

### Velocidade

- [ ] **V08** — Borrão radial com máscara de profundidade

  O que mais vende velocidade nas cinco referências, e o que mais compensa a
  falta de detalhe do cenário: o que está borrado não precisa ter detalhe. O
  vídeo mostra que é **este** o efeito, e não as linhas de velocidade que a
  P7 mandava testar primeiro.

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

### A rua

- [x] **V09** — Calçada larga até a fachada

  O item em que o vídeo está mais longe do jogo. Lá a calçada tem 5–8 m e dá
  espaço para poste, árvore, lixeira e gente. Aqui ela é um friso de 2,2 m e,
  entre ela e o prédio, aparece **grama** (dá pra ver em todos os quadros da
  prova).

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

- [ ] **V10** — Faixa de pedestres e linha de bordo

  A zebra é a pintura de maior contraste do vídeo e o marcador de velocidade
  mais forte dele: as listas brancas passando sob a roda.

  - **O que fazer:** linha de bordo branca contínua junto ao meio-fio; faixas
    de pedestres com linha de retenção, nos cruzamentos.
  - **O risco:** a regra da P4a (`arte/chao.py`) proíbe coisa fina atravessada
    com período menor que 1,7 m, e a zebra real tem ~1 m. Ela vai piscar.
    Testar rodando as duas saídas: zebra mais larga que a real (período de
    2 m) ou decalque com mipmap forte.
  - A linha dupla amarela do vídeo **não entra**: é erro da IA (separa
    sentidos opostos, e todo o trânsito do vídeo vai no mesmo sentido).
  - **Aceite:** a zebra passa sem piscar a 180 km/h, julgado rodando.

### Os prédios e o céu

- [ ] **V11** 👤 — Fachada contínua, térreo vivo

  Depois dos 2,5 s o vídeo é um corredor de paredes: prédio colado em prédio,
  loja com toldo e letreiro no térreo. Hoje os prédios são sorteados com
  buraco entre eles, e só o `Comercio` tem loja embaixo.

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

- [ ] **V12** — Glow: outdoor, lanterna e cromo brilhando

  O vídeo tem *bloom* nos outdoors, nos carros brancos e no cromo. O jogo não
  liga `glow_enabled` (é o item 4 da tabela de luz do `DIRECAO_VISUAL.md`).
  Vem antes do outdoor e da partícula porque os dois dependem dele para ler:
  sem glow, faísca é um pixel laranja.

  - **O que fazer:** glow no `Environment` com limiar alto (só o que é
    emissivo passa); lanterna dos carros emissiva; SSAO leve, e só se o `fps`
    deixar (é o primeiro a cortar).
  - **Aceite:** lanterna acesa brilha a 30 m; asfalto ao sol **não** brilha.

- [ ] **V13** — Outdoor luminoso e letreiro

  Depois do céu, a coisa mais clara do quadro do vídeo. Retângulo emissivo nas
  fachadas e no topo dos prédios, com cor viva. Conteúdo inventado: nenhuma
  marca real.

  - **Onde:** `arte/predios.py` (onde o outdoor encaixa) e `predio.gd` (a cor).
  - **Aceite:** com o glow da V12, o outdoor é o ponto mais claro abaixo do
    horizonte.

- [ ] **V14** — Céu com nuvem

  O céu de hoje é gradiente liso. O vídeo e as imagens têm cúmulo branco,
  gordo, de borda dura e base azulada, concentrado numa faixa baixa — e com
  banda de cor visível, que é o sotaque que o `DIRECAO_VISUAL.md` pede.

  - **O que fazer:** `ceu_nuvens.png` (2048×1024, equirretangular, alfa =
    cobertura, **já dithered**) gerado por script em `arte/`, ligado em
    `ProceduralSkyMaterial.sky_cover`, com `use_debanding` desligado.
  - **Aceite:** nuvem visível nos quatro quadros da prova, sem cintilar com a
    câmera andando. Baseline visual de céu anda, com o motivo.

### A calçada povoada

O critério dos cinco itens abaixo é um só, e vem do vídeo: **algo passa ao
lado da câmera a cada 0,3–0,5 s, de cada lado**. Hoje é um poste a cada
~0,75 s, de um lado só por vez. Cada item mede isso e o `fps`.

- [ ] **V15** — Poste de dois braços

  O referencial de velocidade mais limpo do vídeo: ornamental, 8–10 m, dois
  braços curvos com luminária. Substitui a caixa de 0,35 × 6 m. O colisor fica
  igual, porque é ele que serve ao combate (dá pra jogar rival no poste).

  - **Aceite:** o braço do poste cruza o topo do quadro na V04.

- [ ] **V16** — Palmeira e árvore de copa, inclusive por cima da pista

  O que mais diz "cidade quente" e "Rio". E a árvore de copa larga debruçada
  sobre a pista resolve o item 4 de *Como o vídeo vende velocidade*: passar
  **por baixo** de algo, que o jogo hoje não tem.

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

  - **Aceite:** o critério de densidade da seção, junto com V15 e V16.

- [ ] **V18** — Por cima da pista: semáforo suspenso e placa verde

  O "portal" de cruzamento do vídeo e a placa verde de rodovia das imagens
  paradas (pilar 9). **Só cenário**: semáforo com lógica saiu do protótipo de
  propósito (`PROTOTIPO.md`, *O que não está aqui*). Nomes de via reais são
  livres; marca não.

  - **Aceite:** nos cruzamentos da V10, o braço do semáforo passa por cima da
    câmera.

- [ ] **V19** — Pedestres

  Textura de vida nos dois lados, em pé, andando e na esquina. Billboard em
  `MultiMesh`, sem lógica nenhuma, e ninguém atravessa a pista.

  - **Aceite:** gente visível na calçada nos quatro quadros da prova; o `fps`
    não regride além do orçamento com a calçada inteira povoada (V15–V19).

### O trânsito

- [ ] **V20** — Trânsito do vídeo: denso, quase na velocidade da moto

  No vídeo o táxi fica emparelhado quase 2 s e o corredor dura um segundo
  inteiro, porque o trânsito anda **quase na velocidade da moto**: 8–15
  veículos visíveis, 2–4 nos primeiros 20 m, corredor de menos de 1 m. Aqui os
  carros são obstáculos mais lentos, e o corredor vira um piscar.

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

  - **O que fazer:** cadência do `Entregador` travada como opção (pose
    calculada a 60 Hz, aplicada a 12), com slider. Julgar **rodando**, com
    rivais e trânsito em volta.
  - **Aceite:** a decisão escrita aqui, com o default que ficou.

### Partículas

As referências paradas têm fumaça, faísca e poeira (pilar 5); o vídeo não,
porque nele ninguém derrapa nem cai. Ficam depois do cenário por isso, e
porque dependem do glow (V12). O catálogo inteiro e as quatro regras de
partícula em pixel estão no `DIRECAO_VISUAL.md`, *Partículas*.

- [ ] **V23** — Fumaça de pneu e marca de derrapagem

  Gatilho já existe: a derrapada de `player_bike.gd::_integrate`. Flipbook de
  fumaça com alfa macio, `fixed_fps` em 12–15; marca como `Decal` (não
  `AtlasTexture`, que o `Decal` recusa).

  - **Aceite:** derrapou, fumaçou e marcou; andou reto, nada.

- [ ] **V24** — Faísca, poeira de queda, impacto do soco e fogo

  Faísca no sinal `scraped(intensity)`, poeira no `crashed`, impacto no
  `punch_landed`, fogo com `OmniLight3D` pulsante na moto caída. Aqui se
  confirma se `GPUParticlesCollisionHeightField3D` enxerga mesh sem colisor;
  se não, a alternativa sem ferir o invariante do chão já está desenhada.

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

### Fechamento

- [ ] **V26** — Barril na `GARUPA` (opcional)

  Última etapa da `REFERENCIA_CAMERA_GARUPA.md`: a distorção de barril que faz
  o poste curvar na borda, como a lente 0,5× do celular. Opcional porque
  reamostrar 640×360 briga com o pixel; só entra se a prova mostrar que não
  suja. Se sujar, marcar `[~]`.

- [ ] **V27** — O veredito

  A P9. A folha da V02 com o estado final, e a pergunta "isso é o mesmo
  jogo?" feita a alguém que não trabalhou no protótipo.

  - **Aceite:** a resposta escrita aqui e na `PROVA_VISUAL.md`, com a data.
    Sim ou não, as duas são resultado.

## Fora do backlog

Herdado dos estudos, e continua fora: chuva, noite, asfalto molhado e neon;
áudio; semáforo com lógica; marca, logo ou cor exata de app real; shader de
mundo curvo; e perseguir a referência pixel a pixel, porque o alvo é a
leitura em meio segundo, não o quadro.
