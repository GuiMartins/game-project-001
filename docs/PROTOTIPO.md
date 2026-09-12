# O que este protótipo valida

O documento de stack fecha três decisões e faz uma aposta. O protótipo existe
pra testar a aposta antes de qualquer arte:

> Prototipe o *feel* da moto primeiro, com cubos brancos, antes de qualquer
> arte. Se acelerar/inclinar/bater não estiver gostoso em uma semana de
> protótipo, arte nenhuma salva.

Os quatro pilares e onde cada um vive no código:

| Pilar | Arquivo | Estado |
| --- | --- | --- |
| Feel da moto | `scripts/player_bike.gd` | jogável e medido |
| O corredor | `scripts/world.gd` (`_score_corridor`), `world_tuning.gd` | jogável, medido e ajustável ao vivo |
| Combate lateral | `player_bike.gd` + `rival_bike.gd` | jogável, não medido |
| Loop de entrega | `scripts/delivery_run.gd` | jogável, números provisórios |

## As decisões de arquitetura, e por que elas se seguram

**Mundo 3D real, não pseudo-3D por scanlines.** A pista é uma `Curve3D` gerada
com curvatura e inclinação sorteadas (`scripts/road_track.gd`); ladeira e curva
saem de graça. Confirmado na prática: o salto na crista da ladeira não tem uma
linha de código de rampa — cai fora do fato de a moto herdar a subida da pista
e a gravidade cuidar do resto.

**O chão não tem colisor.** Altura e direção são amostradas analiticamente da
curva. A 50 m/s um `CharacterBody3D` atravessaria um trimesh de pista. Colisor
existe só pro que importa: carros, postes, guard-rail.

**Só o jogador roda física.** Trânsito e rivais são paramétricos na curva —
cada um sabe seu próprio offset e nunca precisa se projetar. Só a moto do
jogador faz a projeção, e mesmo assim com busca local em janela (`RoadTrack.project`),
não com `get_closest_offset()`, que varre todos os pontos bakeados.

**320×180 com upscale inteiro de 4×.** Via `SubViewportContainer.stretch_shrink = 4`.
Setar `SubViewport.size` na mão **não funciona** com `stretch` ligado — o
container sobrescreve e você renderiza em 1280×720 achando que está em 320×180.
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
bifurcacao           atalho de 275 m no lugar de 340 m (-65 m)
corrida solta 45s    1369 m percorridos, 19 raspadas, 3 quedas
transito parando     52 carros no vermelho de uma vez, 2 engarrafamentos
fila parada          90 m de fila, vao de 1.90 m entre as colunas
```

As três últimas linhas não medem a moto, medem o **mundo**: elas existem porque
"o engarrafamento parou de nascer" e "o atalho virou um caminho mais longo" são
regressões que não travam nada — o jogo continua rodando lindamente sem elas, e
ninguém percebe até jogar a fase inteira. A fase da bifurcação é a mais
paranoica do banco: ela entra no atalho, volta pra avenida e confere que o
progresso não andou pra trás na troca de pista.

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

Cinco bugs que só apareceram porque as medidas existem. Ficam registrados
porque três deles são armadilhas de Godot que vão voltar:

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

Também apareceu uma lacuna de design: nada avisava que a moto estava na
contramão. Capotar, levantar virado e passar dez segundos sem entender o que
houve. Hoje tem aviso na HUD.

## O que **não** está aqui

Deliberadamente fora do escopo até o feel fechar:

- **Sprites pré-renderizados.** Tudo é caixa. Quando entrarem, entram como
  `Sprite3D` com `billboard = Y-Billboard`, `texture_filter = Nearest` e
  **`alpha_cut = Discard` em todos** — sem isso o depth sorting quebra e o
  entregador some atrás do carro errado. O ponto de troca é o nó `Visual` de
  `player_bike.gd` / `rival_bike.gd`.
- Áudio, menu, progressão, upgrade de moto.
- Shader de mundo curvo ("SEGA curved world").
- Chuva, noite com neon no asfalto molhado.

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
- **O banco de provas não cobre isto.** O piloto automático nunca sobe na
  calçada, porque `free_lateral` só considera centros de faixa e de corredor.
  Os números da corrida solta ficaram idênticos depois da mudança — regressão
  aqui não é pega por lá, só pelo polegar.

## O trânsito para: semáforo e engarrafamento

Duas maneiras de fechar a pista, opostas de propósito.

**Semáforo** (`traffic_light.gd`) é geometria fixa da rota, a cada 260–520 m.
O carro que se aproxima do vermelho freia na faixa de retenção e fila atrás de
quem já parou — o mesmo car-following que impede dois carros de ocuparem o
mesmo metro de asfalto.

A cada ciclo vermelho ele **sorteia uma faixa que não segura ninguém**, e quem
estava nela sai antes de parar. Sem essa faixa vazia a fila fecha as quatro
pistas e o semáforo vira um muro: a 50 m/s a única resposta possível seria
parar, e parar não é o jogo. Como a faixa livre muda de ciclo pra ciclo,
ninguém decora "é sempre a da direita".

**Engarrafamento** é o contrário, e é por isso que ele existe: ali as quatro
faixas **são** ocupadas, em fileiras de para-choque a para-choque. A pista
acaba de verdade e a única passagem é o vão entre as filas — é a hora em que o
jogo cobra o pilar do corredor em vez de oferecê-lo.

Os carros dele são **criados à parte**, e não emprestados da frota que circula.
A primeira versão emprestava, e o resultado media 13 m: com 20 carros e metade
da frota davam duas fileiras — o jogador atravessa isso antes de perceber que
era pra ser uma parede. Agora `jam_length` está em metros (90 por padrão, 56
carros) e o número quer dizer o que diz.

Quando dá, **a fila nasce atrás de um sinal vermelho**, que fica segurado
enquanto ela existe. Fila de 90 m num cruzamento aberto é fila sem motivo;
atrás do vermelho ela vira consequência, e quando o sinal abre, ela anda.

O vão entre duas colunas é de 1,90 m para uma moto de 0,75 m: 1,50 do vão
natural entre faixas, mais o `jam_spread` (0.12), que encosta as colunas nas
guias. Antes eram 1,40 m com um jitter lateral de ±0,25 que no pior caso
fechava pra **0,90 m** — 8 cm de folga de cada lado. O banco agora falha se o
vão cair abaixo de 1,60.

Custo medido, porque 90 m de fila põem 76 carros no mundo: montar tudo num
frame só levava 9,8 ms, mais da metade do orçamento a 60 Hz. Ela passou a ser
montada duas fileiras por frame (1,2 ms), e cada carro reconsulta a pista à
frente a cada 4 frames em vez de todo frame, descontando o vão pelo que ele
mesmo andou — hipótese conservadora, então errar aqui freia cedo demais, nunca
tarde demais. Junto, o trânsito inteiro caiu de 4,7 para 1,3 ms por frame.

## Bifurcações

A rota abre atalhos onde a avenida faz volta grande. Não há level design nisto:
o `World` varre a pista atrás de trechos em que a **corda** entre duas pontas é
pelo menos 14% mais curta que a pista entre elas — que é a definição geométrica
de "aqui daria pra cortar". Onde a avenida já é reta, atalho nenhum nasce.

O atalho é outra `RoadTrack`, uma Bézier cúbica cujas tangentes nas pontas são
as da própria avenida. É isso que permite **trocar a moto de pista sem
teleporte**: na boca e na reentrada as duas curvas se encostam apontando pro
mesmo lado, e o que muda é só em qual delas o offset passa a ser medido.

O atalho sai e volta **em ângulo** (22°), e não pelas tangentes da própria
avenida. Com as tangentes dela o atalho nascia grudado e voltava grudado —
medido, 8,6 m entre os dois eixos no miolo, com as duas pistas tendo 13 m de
largura. Na tela isso não lia como bifurcação: lia como uma avenida de 30 m com
duas pinturas de faixa sobrepostas, e todo prédio que mora entre as duas
aparecia no meio do caminho. Agora o miolo precisa se afastar no mínimo 26 m do
eixo da avenida (`BRANCH_MIN_APART`) ou o atalho não nasce, e o banco falha se
algum nascer colado.

A curva do atalho é traçada antes da malha (`plan_shortcut` / `build_surface`):
a maioria dos candidatos é recusada, e construir um `SurfaceTool` completo pra
cada um fazia o boot passar de dez minutos.

O atalho **segue o relevo da avenida**: a altura de cada ponto vem do pedaço de
avenida mais próximo, e não da fração do caminho. Sem isso ele era uma ponte
reta sobre um terreno que sobe e desce, e como o carpete de chão da avenida tem
43 m de cada lado do eixo, era ele que passava por cima do atalho — medido,
1,7 m de asfalto enterrado. Em jogo isso aparecia como a moto afundando no chão
no meio da rua. A média móvel que tira os degraus da altura também corta pra
baixo, então o último passo trava o piso em 0,25 m abaixo do terreno — ainda
acima da terra, que fica 0,35 m abaixo da pista. Medido depois: 3 cm.

E o cenário é construído **depois** dos atalhos, pulando prédio ou poste que
caia dentro deles. Prédio e poste são plantados em função da avenida, e o
atalho corta justamente a faixa de terreno em que eles moram: eram 3 props
dentro de cada atalho, agora zero.

Três decisões que não são óbvias:

- **Entra quem estava do lado da boca** (2 m do eixo pra fora). Bifurcação que
  você toma sem querer é bifurcação que você xinga.
- **A corrida continua sendo medida na avenida.** Dentro do atalho o offset da
  moto é de outra curva; `player_progress()` traduz de volta. Sem isso, cortar
  caminho zeraria o cronômetro — e como o atalho é mais curto que o trecho que
  substitui, cada metro rodado nele avança mais de um metro de rota. Esse é o
  prêmio, e o jogador vê ele no "faltam X m" caindo mais rápido.
- **Tem carro parado largado dentro.** Sem eles a escolha não existe: pista
  mais curta e vazia seria sempre a resposta certa, e escolha com resposta
  certa não é escolha.

O que o banco **não** cobre: a raspada no corredor não pontua dentro do atalho,
porque a frota vive na avenida e os offsets das duas curvas se parecem sem
querer dizer a mesma coisa. Também é dentro do atalho que os rivais deixam de
tentar emparelhar — eles continuam na avenida, correndo a corrida deles.

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
3. **Fechar o combate.** Derrubar rival no poste já funciona, mas não tem
   medida nenhuma. Falta o feedback de impacto (hit stop, shake, som).
4. **Calibrar as estrelas.** `SECONDS_PER_METER = 0.055` exige ~65 km/h de
   média. Dá pra entregar dirigindo limpo; 5 estrelas exige o corredor. É a
   intenção, mas não foi verificada com um humano no controle.
5. **Só então** modelar o entregador low-poly e começar o batch de render.

## Nota de marca

O nome do protótipo é **RushFood**, paródia óbvia. Nada de nome, logo ou cor
exata de app real.
