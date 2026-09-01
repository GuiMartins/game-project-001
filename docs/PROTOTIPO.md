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

`godot --headless --path . -- --selftest` roda o jogo de verdade contra entradas
sintéticas (via `Input.action_press`, mesmo caminho do jogador) e mede.

Ele roda nos **defaults do repositório**, ignorando o `user://` de propósito: a
semente já era fixa pra o número ser comparável entre rodadas, mas enquanto o
tuning salvo entrava, bastava alguém clicar em Salvar pra "regrediu" e "você
mexeu num slider ontem" virarem a mesma coisa. Pra medir os seus ajustes,
`-- --selftest --selftest-user`. O relatório diz qual dos dois usou.

```
0-100 km/h          2.75 s
velocidade em 22s   183.6 km/h  (teto do tuning 187.2)
freada 183 km/h -> 0   1.48 s / 37 m
inclinacao 0->90%    0.35 s
a 175 km/h: 35.8 graus/s, raio 78 m
hitbox do soco       0.133 s aberta (tuning pede 0.130)
corrida solta 45s    1147 m percorridos, 13 raspadas, 4 quedas
```

O número que amarra tudo: a curva mais fechada que o gerador de pista produz é
**0,6 grau/m**, o que a 48,6 m/s exige 29 graus/s de guinada. A moto entrega
35,8. **Curvão passa raspando sem frear, e qualquer coisa mais fechada que isso
seria injusta** — por isso o teto de curvatura em `road_track.gd` é um número
de design, não estético.

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
