# O que este protótipo valida

O documento de stack fecha três decisões e faz uma aposta. O protótipo existe
pra testar a aposta antes de qualquer arte:

> Prototipe o *feel* da moto primeiro, com cubos brancos, antes de qualquer
> arte. Se acelerar/inclinar/bater não estiver gostoso em uma semana de
> protótipo, arte nenhuma salva.

Os cinco pilares e onde cada um vive no código:

| Pilar | Arquivo | Estado |
| --- | --- | --- |
| Feel da moto | `scripts/player_bike.gd` | jogável e medido |
| O corredor | `scripts/world.gd` (`_score_corridor`), `world_tuning.gd` | jogável, medido e ajustável ao vivo |
| Combate lateral | `player_bike.gd` + `rival_bike.gd` | jogável e medido |
| A corrida | `rival_bike.gd` + `world.gd` (`_update_standings`) | jogável e medido, ritmo do pelotão por calibrar |
| Nota da entrega | `scripts/race_run.gd` | prazo e estilo pesam na nota, nunca na classificação |

## As decisões de arquitetura, e por que elas se seguram

**Mundo 3D real, não pseudo-3D por scanlines.** A pista é uma `Curve3D` gerada
com curvatura e inclinação sorteadas (`scripts/road_track.gd`); ladeira e curva
saem de graça. O salto na crista da ladeira não tem uma linha de código de
rampa — cai fora do fato de a moto herdar a subida da pista e a gravidade
cuidar do resto.

**O chão não tem colisor.** Altura e direção são amostradas analiticamente da
curva. A 50 m/s um `CharacterBody3D` atravessaria um trimesh de pista. Colisor
existe só pro que importa: carros, postes, guard-rail.

**Só o jogador roda física.** Trânsito e rivais são paramétricos na curva —
cada um sabe seu próprio offset e nunca precisa se projetar. Só a moto do
jogador faz a projeção, e mesmo assim com busca local em janela (`RoadTrack.project`),
não com `get_closest_offset()`, que varre todos os pontos bakeados.

**640×360 com upscale inteiro de 2×.** Via `SubViewportContainer.stretch_shrink = 2`,
e a janela escalando o resto em modo fracionário: 1920×1080 dá 3× por pixel,
exato. O modo `integer` foi tentado e saiu — ele arredonda sobre o viewport
base de 1280×720, e em 1920×1080 desenhava o jogo em metade da janela. Setar `SubViewport.size` na mão **não funciona** com `stretch`
ligado — o container sobrescreve e você renderiza em 1280×720 achando que está
em 640×360. Foi 320×180 (`stretch_shrink = 4`) até a P1 da prova visual: a
320×180 o piloto tem uns 37 px no talo, e não cabe nele o que faz um ator ler
como foto. A conta está no `DIRECAO_VISUAL.md`. A HUD continua escrita em
unidades de 320×180 e escala por `Hud.ESCALA`, até a P8 redesenhar.
A HUD mora dentro do SubViewport de propósito: HUD nítida sobre mundo pixelado
é o visual de remaster preguiçoso.

## O modelo da moto, em uma frase

**O input controla a inclinação, e a inclinação é que controla a curva.**

Isso é a decisão de design mais importante do arquivo. Você precisa se
comprometer com um lado antes de virar, e precisa endireitar antes de flicar
pro outro. Duas taxas separadas (`lean_rate` pra deitar, `lean_return_rate` pra
levantar) fazem a moto cair fácil pro lado e voltar sozinha. É daí que sai o
peso.

Em cima disso:

- **Agilidade em função da velocidade** — quase nula parada (moto não anda de
  lado), máxima em velocidade média, reduzida no talo.
- **Aderência como perseguição, não como trilho** — a velocidade real persegue
  a desejada. A diferença é a derrapada.
- **Assistência de alinhamento** (`align_assist`) — um empurrão suave pro
  sentido da pista. Sem um pingo disso, um curvão a 180 km/h vira briga com o
  controle em vez de briga com o trânsito, e o trânsito é o jogo.

## Números medidos

`python tools/dev.py selftest` roda o jogo de verdade contra entradas
sintéticas (via `Input.action_press`, mesmo caminho do jogador) e mede.

Ele roda nos **defaults do repositório**, ignorando o `user://` de propósito: a
semente já era fixa pra o número ser comparável entre rodadas, mas enquanto o
tuning salvo entrava, bastava alguém clicar em Salvar pra "regrediu" e "você
mexeu num slider ontem" virarem a mesma coisa. Pra medir os seus ajustes,
`--user-tuning`. O relatório diz qual dos dois usou.

```
relevo               rampa max 14%, desnivel 40 m
0-100 km/h          2.75 s
velocidade em 22s   183.6 km/h  (teto do tuning 187.2)
freada 183 km/h -> 0   1.48 s / 37 m
inclinacao 0->90%    0.35 s
a 175 km/h: 35.8 graus/s, raio 78 m
hitbox do soco       0.133 s aberta (tuning pede 0.130)
calcada              33.3 m/s no asfalto, 13.8 m/s na calcada, parede em 8.80 m
combate              soco acertou, rival empurrado 3.30 m, cambaleou
corrida solta 45s    1095 m percorridos, 11 raspadas, 5 quedas
pelotao em 45s       6/6, 204 m do lider (media dele 102 km/h)
disputa 260 m        6/6, 5 de 5 rivais cruzaram
```

As cinco últimas linhas não medem a moto, medem o **mundo**: elas existem
porque "a calçada virou a linha rápida", "o soco parou de empurrar o rival" e
"ninguém mais cruza a linha de chegada" são regressões que não travam nada — o
jogo continua rodando lindamente sem elas, e ninguém percebe até jogar a fase
inteira.

O 0-100 e a freada são medidos com a **ladeira desligada** (`slope_enabled`).
Medir aceleração numa subida mede a subida. A elevação volta a valer na corrida
solta, que é onde a pergunta é "dá pra jogar isto?".

O número que amarra tudo: a curva mais fechada que o gerador de pista produz é
**0,6 grau/m**, o que a 48,6 m/s exige 29 graus/s de guinada. A moto entrega
35,8. **Curvão passa raspando sem frear, e qualquer coisa mais fechada que isso
seria injusta** — por isso o teto de curvatura em `road_track.gd` é um número
de design, não estético.

Estes números vivem agora em [`tests/baseline.json`](../tests/baseline.json),
e o banco de provas compara cada rodada com eles. A lista acima é para leitura
humana; quando as duas discordarem, o baseline é que está certo — este bloco
nasceu desatualizado uma vez, e foi o baseline que percebeu.

"Está gostoso?" é subjetivo. "0-100 em 9 segundos" não é — e o banco pega uma
regressão de tuning sem ninguém abrir o jogo.

## O que o protótipo já mostrou (e custou conserto)

Seis bugs que só apareceram porque as medidas existem. Ficam registrados
porque quatro deles são armadilhas de Godot que vão voltar:

1. **Sinal da guinada invertido.** Em Godot (Y pra cima, mão direita) guinada
   positiva gira pra *esquerda*. Inclinar pra direita mandava a moto pra
   esquerda. A assistência de alinhamento disfarçava o erro até a moto encostar
   no guard-rail. Hoje tem asserção dedicada no banco: inclinou pra direita, a
   lateral na pista **tem** que crescer.
2. **Pista invisível por backface culling.** Godot considera face frontal a de
   winding **horário**. Os quadriláteros saíam anti-horários e a pista inteira
   era descartada — sem um erro no console. O mundo virava caixas flutuando no
   vazio.
3. **Guard-rail prendia a moto a 6 km/h.** A raspada cobrava velocidade
   multiplicativamente *a cada frame* encostado. Uma vez fora da pista, nunca
   mais se voltava. Hoje é desaceleração contínua (`rail_friction`) mais uma
   cobrança única na entrada.
4. **Andar colado no rail era a linha rápida.** Consertar o item 3 sem cobrar
   nada tornou o guard-rail mais seguro e mais rápido que o corredor — o pilar
   do jogo morria de vez. `rail_friction` existe pra isso, e é o slider que
   decide se o jogador entra no trânsito ou foge dele.
5. **Corpo físico não girava com a moto.** A cápsula de colisão e as hitboxes
   de soco ficavam alinhadas ao mundo. O soco saía pro lado errado sempre que a
   pista curvava.
6. **`Area3D` responde com o mundo do frame passado.** No primeiro passo de
   física de cada corrida, os corpos ainda estavam todos na origem — recém
   criados, antes de qualquer `global_transform` — e o sensor de acidente de
   **cada** rival lia os dez carros do trânsito como "encostei". Os cinco
   rivais capotavam no frame 1 de toda largada, contra carros a 150 m dali, e
   nada no console reclamava: só a corrida começava com o pelotão no chão. Vale
   para toda reposição em massa — a largada, o `R`, o teleporte de +9000 m do
   banco de provas. Hoje o sensor confere a distância antes de aceitar o
   encosto (`RivalBike.WIPEOUT_ALCANCE`).

Também apareceu uma lacuna de design: nada avisava que a moto estava na
contramão. Capotar, levantar virado e passar dez segundos sem entender o que
houve. Hoje tem aviso na HUD.

## O que **não** está aqui

Deliberadamente fora do escopo até o feel fechar:

- **Arte do mundo.** Prédio, carro, poste e pista são caixa. A exceção é o
  entregador, que é modelo 3D (ver *O entregador*). Sprite pré-renderizado,
  se entrar no cenário, entra como `Sprite3D` com `billboard = Y-Billboard`,
  `texture_filter = Nearest` e **`alpha_cut = Discard` em todos** — sem isso o
  depth sorting quebra e o sprite some atrás do carro errado.
- **Semáforo, engarrafamento e bifurcação.** Existiram e foram removidos:
  estavam custando complexidade no `world.gd` antes de o feel da moto estar
  fechado, que é a única pergunta que este protótipo existe pra responder.
  O código está no histórico — `git log --diff-filter=D -- scripts/traffic_light.gd`
  acha o commit que os tirou, e com ele o estado completo de cada um.
- Áudio, progressão, upgrade de moto.
- Shader de mundo curvo ("SEGA curved world").
- Chuva, noite com neon no asfalto molhado.

## A corrida

O protótipo nasceu como entrega contra o relógio e virou **corrida**: seis
motos na pista, e o que decide o resultado é a posição na chegada. O prazo e o
estilo continuam lá, mas mudaram de papel — eles pesam na nota, nunca na
classificação. Chegar em primeiro arrastando a moto é vitória feia, não
derrota.

Houve também uma **integridade da bag** em porcentagem, com barra na HUD, que
caía a cada queda, raspada e pancada. Ela saiu: media a mesma coisa que o resto
do painel já media — quem cai e apanha também chega tarde e sem estilo — e
cobrava por essa redundância uma barra permanente numa tela que então era de
320×180, onde o espaço era o recurso escasso. O custo de raspar virou estilo, e os 20 pontos que
ela valia na nota foram divididos entre prazo e estilo, deixando a metade da
posição intacta.

Três decisões sustentam isso.

**Quem decide o fim é a linha, não o cronômetro.** Estourar o prazo antes
encerrava a corrida na hora. Numa corrida isso tira do jogador justamente o que
ainda estava em disputa: a posição. Hoje o prazo estourado acende `ATRASADO` na
HUD e limita a nota a três estrelas (`LATE_SCORE_CAP`), e a corrida continua
até alguém cruzar.

**Uma chave só ordena o pelotão.** Comparar quem já cruzou a linha com quem
ainda está na pista precisaria de dois casos em toda conta, e o empate entre
dois que terminaram sairia pela ordem da lista — ou seja, por acidente.
`RaceRun.rank_key` devolve o progresso de quem corre e `100000 - tempo` de quem
chegou: um número, uma comparação, e quem cruzou primeiro fica na frente por
construção. É o pedaço testável da corrida, e está coberto por unitário.

**O rival tem ritmo próprio, com rubber band por cima — nessa ordem.** Antes
ele perseguia a velocidade do jogador e nada mais: nunca ganhava, nunca perdia,
só acompanhava. Agora cada rival sorteia um `pace` entre `rival_pace_min` e
`rival_pace_max` (fração do teto da moto) e corre por ele; o band entra depois,
e é **assimétrico de propósito** — puxa quem ficou para trás com o dobro da
força com que segura quem abriu. Segurar o líder tanto quanto se empurra o
lanterna é o que faz o jogador sentir que a corrida está encenada, porque
estaria.

`rival_rubber_band` é o slider de *quanto de corrida, quanto de briga*: em zero
o pelotão se espalha até sumir e a briga lateral quase não acontece; alto
demais ele gruda em você e a colocação deixa de depender do que você faz.

A IA ganhou as intenções que o [GDD](GDD.md) pede (`RivalBike.Mode`): `FOLLOW`
segue a pista, `OVERTAKE` abre caminho quando a frente fecha a dois terços da
janela de visão, `ATTACK` briga com quem está emparelhado. Elas são separadas
de `State` (de pé, cambaleando, no chão) porque cair acontece por cima de
qualquer intenção — juntar os dois faria "cair atacando" precisar de um estado
próprio.

**Derrubar rival é conquista, não acidente de trânsito.** Rival no chão pagava
150 de estilo e 20 de adrenalina toda vez que um rival caía, sem perguntar quem
o derrubou. Somado ao bug 6 acima, a conta de **ficar parado na largada** era:
em dois segundos os cinco rivais se espatifavam sozinhos, e o jogador terminava
com o boost cheio e 750 de estilo — um quinto da nota — sem ter acelerado.
Pilar que acontece sozinho deixa de ser pilar.

Hoje quem paga é a **autoria**: `RivalBike` guarda por 1,5 s
(`CREDITO_DO_SOCO`) o soco que o empurrou, e o sinal `went_down` diz se a queda
é do jogador. O prazo existe porque o golpe do Road Rash não derruba, empurra —
a lataria pode estar alguns metros adiante, e o rival ainda passa o
`punch_stagger` inteiro sem governar a moto. Quem cai sozinho continua valendo
o que sempre valeu de verdade: a posição que ele perde, que é sua de graça.

**O grid larga o jogador em último.** Fila dupla, corredores alternados, e o
índice mais alto — sempre o do jogador — no fundo. Numa corrida em que você já
começa na frente, a primeira coisa que o jogo ensina é que a posição não
depende de você.

### O que está medido, e o que não está

O banco de provas ganhou uma fase própria (`disputa`): larga o grid a 260 m da
linha e roda a chegada de verdade, em ~12 s em vez dos dois minutos que a rota
inteira custaria. Ela mede a colocação final, quantos rivais cruzaram, e checa
a única coisa que prova que o placar não mente — **quem cruzou antes está na
frente no resultado**. A corrida solta, que era só distância e raspadas, agora
também reporta a colocação aos 45 s, a distância para o líder e **quantos
rivais foram ao chão, separados por quem os derrubou**. O piloto automático não
dá um soco em 45 s, então o número de rivais creditados a ele tem que ser zero:
é a asserção que impede a queda alheia de voltar a pagar estilo. O outro
número, o de quedas sozinhas, é calibragem — hoje mede **1** em 45 s.

O que **não** está medido é se o ritmo do pelotão é justo. O piloto automático
do banco faz uns 24 m/s de média; os rivais, 29 a 37 m/s nominais. Por isso ele
termina os 45 s em último e chega em sexto na disputa — e isso não quer dizer
que o jogo está difícil, quer dizer que o bot é ruim.

Para essa pergunta ter um alvo em vez de um palpite, o banco também mede o
**ritmo do líder**: hoje **108 km/h de média**, trânsito e quedas incluídos. É
o número que dá para comparar com o próprio velocímetro numa sessão de jogo —
sustentou mais que isso, ganhou a corrida. Calibrar `rival_pace_min` e
`rival_pace_max` continua sendo trabalho de polegar, e está nos próximos
passos; o que mudou é que agora se sabe contra o quê.

## O fluxo em volta da corrida

O GDD pede um menu (§5: Jogar, Configurações, Sair) e o contrato manda menu
para depois de o feel fechar. As duas coisas continuam de pé, porque o que
entrou não é a camada de interface do jogo — é o **caminho** de entrar e sair
de uma corrida.

Até aqui, jogar duas corridas seguidas exigia saber que `R` reinicia, e
descobrir que existe troca de câmera exigia ler o README. Quem baixa o zip da
release não lê o README. O protótipo é exportado para as três plataformas
justamente para alguém sentar e responder *"está gostoso?"* — e essa pessoa
estava esbarrando na porta antes de chegar na pergunta.

Quatro telas, em [`scripts/race_flow.gd`](../scripts/race_flow.gd):

| Tela | O que faz |
| --- | --- |
| `MENU` | JOGAR / CONFIGURACOES / SAIR |
| `CORRIDA` | o jogo; o fluxo não desenha nada |
| `CONFIGURACOES` | pixel, câmera e painel de tuning — os três atalhos de `F1`–`F3` |
| `RESULTADO` | o placar de `RaceRun.summary()`, com CORRER DE NOVO e MENU |

Quatro decisões que não são óbvias:

**As configurações mostram o que existe, e nada além.** As três linhas são os
três atalhos de debug que já existiam e que ninguém achava sem o README. Um
slider de volume numa tela sem áudio seria menu de mentira, e menu de mentira é
pior que menu nenhum.

**`ESC` no meio da corrida congela, e `CONTINUAR` devolve a mesma corrida.**
Menu de pausa que larga tudo de novo apagaria a colocação de quem pausou
faltando 200 m — e menu que faz isso é menu que ninguém abre. Por isso a
primeira linha troca de **nome** (JOGAR ↔ CONTINUAR) e nunca de lugar: mexer no
número de itens moveria o índice que `_escolher` usa, e SAIR passaria a morar
onde CONFIGURACOES morava. É um bug que continua desenhando lindamente, e que
só aparece quando alguém fecha o jogo sem querer.

**O mundo congela por `process_mode` no `World`, não nó a nó.** Uma linha
derruba a árvore inteira: moto, rivais, trânsito e câmera. Desligar um por um é
uma lista que alguém esquece de atualizar quando nascer o próximo nó, e
`get_tree().paused` levaria junto o próprio menu e o painel de tuning.

**O banco de provas não passa por aqui.** `iniciar(true)` larga direto na
corrida. Menu esperando `ENTER` num processo headless não reprova o portão: ele
o **trava**, e travado não tem código de saída para a CI ler. É a regressão
mais cara que este arquivo podia introduzir, e é a primeira coisa que
[`tests/unit/test_race_flow.gd`](../tests/unit/test_race_flow.gd) verifica.

### O que está medido, e o que não está

O unitário cobre a navegação inteira: a ordem das linhas em cada tela, a volta
da seleção, o ESC que congela sem jogar a corrida fora, e o largar direto no
modo selftest. São nove casos que rodam em milissegundos.

O que ele **não** cobre é o desenho. A regressão visual mede o frame da
corrida, e nenhuma das telas novas aparece nela — o fluxo não desenha nada em
`CORRIDA`, que é justamente o que mantém o baseline visual intacto (medido:
a luminância do frame andou 0,2 ponto percentual, dentro do ruído da própria
medida). As três telas foram conferidas a olho, uma captura por tela, e a
conferência pegou exatamente um erro: o placar de dez linhas passava por cima
das duas saídas, porque a entrelinha padrão da fonte de 8px estoura 150 px
numa tela de 180 (a resolução da época; o layout da HUD ainda é escrito nela). É o tipo de coisa que nenhum número pega.

## O entregador

O contrato mandava arte para depois do feel, e o entregador entrou antes, por
decisão de 30/09/2026 registrada no `CLAUDE.md`. O mundo continua de caixas; o
que mudou é o ator. Moto e piloto são um modelo 3D low-poly de 1380 triângulos
([`assets/entregador/`](../assets/entregador)), gerado por script no Blender
([`arte/entregador.py`](../arte/entregador.py)) e posado a cada passo de
física por [`scripts/entregador.gd`](../scripts/entregador.gd), no nó `Visual`
de `player_bike.gd` e `rival_bike.gd`.

Cinco decisões que não são óbvias:

**A pose sai do estado, não de clipe.** Quatro números por passo — velocidade,
acelerador, esterço e se caiu — e o resto é conta: a roda gira na velocidade
da moto, o joelho fecha conforme ela ganha velocidade, o tronco deita no gás,
o pé esquerdo desce quando ela para abaixo de 1 m/s, e na queda a moto tomba
para o lado em que estava inclinada. Clipe de animação desencontra da física
no primeiro passo em que os dois discordam; pose lida do estado não tem como.

**Moto e piloto são árvores separadas, de peças rígidas.** Cada peça tem a
origem na articulação e nenhuma rotação em repouso. Braço e perna são cadeias
de dois ossos resolvidas por IK — é o que põe a mão na manopla quando o guidão
vira e o pé no chão quando a moto para —, e o comprimento de cada osso é lido
do próprio modelo. Não há rig nem skin: o que o jogo anima é transformação de
nó.

**O `Visual` desceu para o chão.** Ele ficava no centro da cápsula de colisão,
0,875 m acima do asfalto, e a moto inclinava em volta desse ponto. Com caixa
não se via; com roda, nos 38° de fábrica o pneu escorregaria 54 cm para fora
da curva. Agora a moto inclina em volta do pneu, e o tombo pivota na lateral que
bate no chão — em volta do centro, meia moto afundaria no asfalto.

**O tronco acompanha metade do esterço.** Devagar e com o guidão no batente, a
manopla de fora sai do alcance do braço: o `test_entregador.gd` pegou a mão
4 cm curta. Girar os ombros para o lado da curva é o que todo piloto faz, e é
o que deixa o IK chegar. O guidão também vira pouco (20° parado, 4° a partir de
50 km/h), porque no `PlayerBike` a curva sai da inclinação, e guidão girando
muito em velocidade mentiria sobre isso.

**Uma cor por corredor.** Bag e moto na cor, jaqueta num tom escuro dela,
trocadas por shader com a máscara do modelo (R = bag, G = jaqueta, B =
pintura). De longe, o que separa um entregador do outro é a mancha de cor, e
"passei o amarelo" só funciona se o amarelo for amarelo da bag ao paralama. O
jogador é laranja, como a bag do primeiro cubo.

### O que está medido, e o que não está

Os sete casos do `test_entregador.gd` cobrem o que a física não enxerga e que
nasce de um sinal trocado: a roda girando para a frente, o pé no chão e de
volta na pedaleira, as mãos nas manoplas com o guidão virado, o joelho que
fecha, o tombo para o lado pedido sem o pé atravessar o asfalto e as cores de
fábrica batendo com a textura. Com o erro plantado — roda de sinal invertido,
cor da bag fora da textura — eles reprovam.

O banco de provas não andou: o ator não toca na física, e as medidas ficaram
idênticas. O baseline visual foi regravado depois de olhar os frames —
luminância +9,9%, céu +3,8%, famílias de cor −1,6% —, porque, mesmo dentro dos
20% de tolerância, a mudança de propósito comia metade da margem de um teste
cujo ruído medido chega a 13,5%.

O que **não** está feito: o piloto não se solta da moto na queda (os dois
tombam juntos, embora o modelo já tenha as árvores separadas para isso), e a
cadência travada da animação, que faria o ator ler como digitalizado em vez de
3D, não existe.

## A porta do carro

Porta só abre em **carro encostado**: parado de verdade (velocidade zero) e
numa das duas faixas da ponta. Carro no fluxo nunca abre — porta abrindo a
25 km/h no meio da pista é bug com cara de recurso.

Duas coisas são sorteadas de propósito:

- **Nem todo encostado abre** (`door_chance`, 0.6). Se encostar fosse sinônimo
  de porta, a faixa da ponta viraria regra decorada e o jogador aprenderia a
  nunca chegar perto, em vez de calcular o risco.
- **O lado é sorteado**, pista ou calçada. Porta previsível deixa de ser susto
  e vira pedágio.

Medido em 120 s de simulação, 19 aberturas: nenhuma em carro em movimento,
nenhuma fora das faixas da ponta, os dois lados usados. `parked_chance` (0.3)
controla quantos carros encostam — é ele que decide se as faixas da ponta são
uma aposta ou uma parede.

## A calçada

Dá pra subir na calçada e continuar andando, com teto de velocidade — grama do
Mario Kart. É a válvula de escape quando o trânsito fecha: você foge por ali,
mas paga em tempo.

O limite andável passou de `half_width + SHOULDER*0.6` (7,92 m) para
`half_width + SHOULDER` (8,80 m). O número antigo caía no **meio** da faixa de
acostamento, que o mesh já desenha numa cor distinta — parede invisível no meio
de uma coisa com cara de andável. Agora o limite coincide com onde o terreno
cai 0,35 m, que o jogador vê.

Medido: 42,7 m/s no asfalto contra 18,6 m/s encostado na calçada, e a parede
segurou exatamente em 8,80 sem vazar.

Duas ressalvas honestas:

- **A faixa é estreita.** 2,2 m de calçada para uma moto de 0,76 m deixa ~1,4 m
  de jogo antes de raspar o guard-rail. Funciona, mas exige linha. Alargar é
  mexer em `SHOULDER` no `road_track.gd`, e o mesh acompanha sozinho.
- **Hoje o banco de provas cobre isto**, numa fase própria. Ela sobe na
  calçada de propósito, porque o piloto automático da corrida solta nunca
  sobe: `free_lateral` só considera centros de faixa e de corredor, e por isso
  os números da corrida ficaram idênticos quando o limite andável mudou. A
  fase mede a velocidade estabilizada contra o teto que o `sidewalk_speed_factor`
  declara, e confere que a parede segura exatamente no `sidewalk_limit()`.

## Ladeira

A pista sempre teve inclinação; ela era de ±5,5% e servia só pra mexer a
câmera. Agora o relevo tem **trecho próprio**, mais curto que o da curva (70 a
200 m contra 90 a 260 m), e chega a 14%.

Ter trecho próprio é o detalhe que importa: antes a subida era sorteada junto
com a curvatura, então toda ladeira começava exatamente onde começava uma
curva e a rota inteira tinha o mesmo ritmo. Separados, sobe no meio do curvão e
empina na reta.

Duas coisas caem de graça da arquitetura:

- **O salto na crista.** A moto herda a subida da pista ao chegar no topo
  (`_integrate`), então rampa que troca de sinal em poucos metros cospe a moto
  no ar. Não há código de rampa nenhum — quem controla isso é o `GRADE_BLEND`.
  A conta é `v² · (−dgrade/ds) > g`: decola onde a crista curva mais forte que
  a gravidade. Na rota da semente fixa isso só acontece numa crista (~300 m) e
  acima de ~180 km/h — salto é prêmio de boost, não evento de toda ladeira.

  Até a 0.0.5 parecia muito mais comum, e era bug: a moto herdava só a subida
  **positiva**, pousava na descida com vertical zero e quicava 40 cm a cada
  12 m até a ladeira acabar. Se o salto fizer falta, ele volta com crista mais
  seca (`GRADE_BLEND`) ou com rampa de verdade — não reabrindo o `maxf`.
- **O sorteio se corrige.** Sem puxar os sinais de volta pro nível do mar, a
  sequência é um passeio aleatório e a rota de 3 km termina 200 m acima de onde
  começou. Com a correção, o desnível total ficou em 40 m.

O que a ladeira cobra da moto é o `slope_pull` (16 m/s² por 100% de rampa, no
F3): subida come o gás que você não tinha sobrando, descida devolve. Ele entra
como aceleração e **não** como teto — mexer no teto faria `max_speed` deixar de
ser a velocidade máxima, e slider que mente é slider que ninguém ajusta.

## Próximos passos, em ordem de risco

1. **Sentar e jogar com o F3 aberto.** Os números do banco dizem que a moto é
   sã, não que ela é gostosa. Só o polegar decide isso, e o painel existe pra
   essa sessão.
2. **Densidade do trânsito.** Agora vive em `scripts/world_tuning.gd` e sai
   nos sliders do F3, com a frota se ajustando com a moto andando. A densidade
   real é `traffic_count / (traffic_ahead + traffic_behind)` — os carros são
   reciclados pra viver sempre nessa janela em volta do jogador, então o
   espaçamento da largada só decide os primeiros segundos.

   O padrão saiu de 54 carros para 20. A série medida, sempre 45 s e mesma
   semente:

   | carros | `traffic_behind` | distância | raspadas | quedas |
   | --- | --- | --- | --- | --- |
   | 54 | 70 m | 887 m | 22 | 7 |
   | 36 | 70 m | 874 m | 13 | 6 |
   | 20 | 30 m | 1012 m | 16 | 7 |
   | 20 | 30 m | 1147 m | 13 | 4 | (com porta só em carro encostado) |

   A terceira linha desmente a leitura óbvia. Menos carros deveria dar menos
   raspadas, e de 54 para 36 deu — mas de 36 para 20 elas **subiram**, porque
   junto veio `traffic_behind` de 70 para 30 m. O carro é reciclado 40 m mais
   cedo depois que você passa, e `recycle()` zera a flag `near_missed`: os
   mesmos 20 carros voltam pra frente com mais frequência e podem ser raspados
   de novo.

   **`traffic_behind` não é faxina, é taxa de reciclagem.** Não dá pra ler
   densidade só pelo `traffic_count`. Como a raspada é a métrica que mede se o
   corredor está puxando o jogador pra dentro do trânsito, é o número pra
   vigiar em qualquer mexida aqui. Continua sendo o segundo maior risco depois
   do feel.
3. **Calibrar o ritmo do pelotão.** `rival_pace_min` / `rival_pace_max` e
   `rival_rubber_band`, os três no F3. O banco prova que a corrida existe e
   termina; ele não tem como dizer se ficou disputada, porque o piloto
   automático dele não joga bem o bastante para ser referência. A pergunta é
   uma sessão de jogo: *dá pra virar a corrida no último quilômetro, e custa
   suor?*
4. **Fechar o combate.** Derrubar rival no poste já funciona, mas não tem
   medida nenhuma. Falta o feedback de impacto (hit stop, shake, som).
5. **Calibrar as estrelas.** `SECONDS_PER_METER = 0.055` exige ~65 km/h de
   média. Dá pra entregar dirigindo limpo; 5 estrelas exige o corredor, e agora
   exige também chegar na frente — metade da nota é posição. É a intenção, mas
   não foi verificada com um humano no controle.
6. **O entregador low-poly** entrou antes desta lista acabar, por decisão
   (ver *O entregador*). O que continua para depois do feel é o resto da arte:
   mundo, céu, partículas.

## Nota de marca

O nome do protótipo é **RushFood**, paródia óbvia. Nada de nome, logo ou cor
exata de app real.
