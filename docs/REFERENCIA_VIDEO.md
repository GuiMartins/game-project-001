# Referência em movimento: o vídeo de 6 segundos

Descrição detalhada de um vídeo de referência, para servir de alvo aos
próximos passos do protótipo. Ela cobre tudo o que dá pra observar nos 6
segundos: câmera, moto, piloto, trânsito, rua, calçada, prédios, céu, luz,
HUD e o jeito como o vídeo vende velocidade. Cada item vem comparado com o que
o jogo tem hoje e com o que fazer a respeito.

Os documentos anteriores, [DIRECAO_VISUAL.md](DIRECAO_VISUAL.md) e
[PROVA_VISUAL.md](PROVA_VISUAL.md), foram escritos sobre **quatro imagens
paradas**. Este é o primeiro alvo **com tempo**. O vídeo responde ao que
imagem parada não responde: quanto a moto inclina e em quanto tempo, se a
câmera gira junto, se a suspensão trabalha, com que frequência passa um poste,
quanto tempo um carro leva para ficar para trás. Esses números são de *feel*,
e *feel* é a pergunta que este protótipo existe para responder.

Este documento é **descrição e proposta**, não plano aprovado. Onde ele propõe
mudar um número do jogo, a mudança passa pelo portão e pela conversa de
sempre.

## Onde estão os arquivos

| Arquivo | O que é |
| --- | --- |
| `docs/referencias/video_01.mp4` | O vídeo original, intacto |
| `docs/referencias/video_01/folha.png` | 12 quadros, um a cada 0,5 s: a linha do tempo numa imagem |
| `docs/referencias/video_01/t*.png` | Oito quadros inteiros, com o tempo no nome (`t3.8s.png` = 3,8 s) |
| `docs/referencias/video_01/moto_ampliada.png` | A moto ampliada em oito momentos, do reto à inclinação máxima |
| `docs/referencias/video_01/mede.py` | O script que mediu a inclinação e a posição da moto quadro a quadro |

O vídeo mora no repositório pelo mesmo motivo que as quatro imagens deveriam
morar (`PROVA_VISUAL.md`, seção *As referências*): comparar com um arquivo que
só existe no chat de alguém não é reproduzível. Tudo vai por Git LFS, que o
`.gitattributes` já configura para `.mp4` e `.png`.

## O que o vídeo é, e o que ele não é

**Ficha técnica:** 6,04 s, 145 quadros a 24 fps, 640×480 (**4:3**), H.264.
Áudio AAC estéreo a 48 kHz.

**É gerado por IA**, como as quatro imagens. Não é captura de jogo. A prova
está nele mesmo, e listar os sinais importa, porque **eles não podem virar
requisito**:

- **O relógio anda para trás.** O `TIME` mostra 17,3 → 17,0 → 13,9 → 13,0 →
  14,1 → 15,9 → 16,3. Um relógio de corrida só sobe ou só desce.
- **A velocidade não muda.** `128 km/h` cravados nos 145 quadros, com curva,
  corredor e faixa de pedestres no caminho. O desenho da barra também não
  muda.
- **A cidade troca no meio.** Começa no centro do Rio, com um teatro
  neoclássico de estátuas douradas no telhado (lê como o Theatro Municipal),
  uma torre de igreja e palmeiras. Por volta de 2,5 s vira um *downtown*
  americano genérico: prédios de pedra e tijolo de 6 a 15 andares, toldos,
  outdoors e caminhão baú. Não há corte. A IA foi "esquecendo" o Rio.
- **Linha dupla amarela com trânsito no mesmo sentido.** A partir de 3 s a
  moto anda em cima de uma linha dupla amarela, que no mundo real separa
  sentidos opostos. Mesmo assim, todo carro dos dois lados mostra a traseira.
- **O sol não se decide.** A sombra da moto cai para a direita e para a
  câmera, o que põe o sol na frente e à esquerda. Mas as costas do piloto
  estão em plena luz, o que exige sol atrás.
- **O táxi muda de modelo e de distância** sem motivo físico: some, volta
  colado, volta longe.

O que se aproveita é a **leitura**: enquadramento, ritmo, densidade, a forma
de mostrar velocidade e a linguagem da HUD. O que não se aproveita são os
erros de continuidade, nem o detalhe fotográfico. Esse segundo ponto o
`DIRECAO_VISUAL.md` já fecha, e continua valendo: *o alvo é a leitura em meio
segundo, não o quadro*.

**Áudio.** Não consigo ouvir, então o que segue é medida, não escuta. Volume
médio de −16,8 dB, pico de −3,6 dB. O espectrograma é ruído largo e constante
até ~16 kHz, sem linha tonal: não há melodia nem fala, e o som não muda ao
longo dos 6 s. É compatível com ronco de motor somado a vento. Áudio continua
fora de escopo (`PROTOTIPO.md`). Fica registrado só para que ninguém procure
música nele.

### Como foi medido

A posição e a inclinação da moto saíram de `mede.py`, rodado nos 145
quadros. O script segmenta a bag vermelha, que é o maior bloco de cor
saturada da tela, e acha o pneu traseiro como a linha mais baixa de pixel
quase preto sob ela. A **inclinação** é o ângulo da reta que liga o centro da
bag ao ponto de contato do pneu.

Precisão: cerca de **±3°**. Quatro quadros saíram absurdos porque o detector
de pneu pegou um carro ou a sombra (`073`, `091`, `115` e `130`) e ficaram
fora das tabelas. Os números servem de ordem de grandeza e de forma da curva,
não de terceira casa decimal.

Para refazer:

```bash
ffmpeg -i docs/referencias/video_01.mp4 quadros/%03d.png
python docs/referencias/video_01/mede.py quadros
```

## Linha do tempo

Convenção para o documento inteiro: **inclinação positiva = topo da moto para
a direita.** Esquerda e direita são da tela.

| Tempo | Rua | Moto | Trânsito e cenário |
| --- | --- | --- | --- |
| **0,0–1,0 s** | Avenida larga, reta, 3 a 4 faixas no mesmo sentido, tracejado branco | Na faixa central-esquerda, levemente inclinada à esquerda (−5° a −8°) e derivando devagar para a esquerda | Táxi amarelo emparelhado à esquerda, a 1,5–2 m. Teatro neoclássico com escadaria à direita, praça larga, pedestres. À esquerda, palmeiras, árvores de copa larga, painel iluminado de ponto de ônibus e torre de vidro azul |
| **1,0–2,0 s** | Reta | Quase em pé (−2° a −3°) | O táxi fica para trás devagar. Torre de igreja ao fundo. Postes de dois braços, semáforo suspenso e uma caixa vermelha (lixeira ou caçamba) na calçada da direita |
| **2,0–2,5 s** | Começa uma curva suave à direita | A inclinação sobe de 0° a +12° em ~0,5 s | Árvore enorme de copa baixa, debruçada sobre a pista. Primeira faixa de pedestres. Semáforo com placa amarela em losango |
| **2,5–3,0 s** | Faixa de pedestres; o asfalto escurece | +10° a +14° | O cenário vira *downtown*: toldos coloridos, outdoors iluminados, caminhão baú branco à frente |
| **3,0–4,0 s** | A linha dupla amarela aparece sob a moto | **+15° a +26°, pico de ~25° entre 3,6 e 3,9 s** | O táxi volta colado à esquerda, enorme e borrado. O caminhão baú passa à direita |
| **4,0–5,0 s** | Linha amarela | Segura +15° a +21° | **O corredor:** sedã branco à esquerda e sedã escuro à direita, a menos de 1 m da moto, os dois borrados |
| **5,0–5,4 s** | Saída da curva | **Desfaz a inclinação em 0,2 a 0,4 s**, de +17° a ~0° | O carro branco da esquerda passa rente e some pela borda da tela |
| **5,4–6,0 s** | Segunda faixa de pedestres; segue sobre a amarela | Contra-inclinação leve, −4° a −8° | Outro corredor: sedã prata à esquerda, carro branco à direita. Fim |

O roteiro desses 6 s é, em miniatura, **o roteiro do jogo inteiro**: reta com
trânsito, curva inclinando, faixa de pedestres, e o corredor entre dois carros
no fim. A pergunta do protótipo — *acelerar, inclinar, se enfiar no corredor e
bater está gostoso?* — está encenada ali, menos a batida.

## A câmera

### Posição: perto e baixa

A diferença mais importante entre o vídeo e o jogo está aqui, e ela muda a
sensação inteira.

**No vídeo, o conjunto moto + piloto ocupa ~53% da altura da tela.** Vai do
topo do capacete, em y≈165, ao contato do pneu, em y≈423, num quadro de 480.
A bag sozinha tem ~15% da largura.

**No jogo** (quadro `reta` da prova, 640×360), o conjunto ocupa **~29%**. O
piloto do vídeo é quase **duas vezes maior** na tela.

A posição da câmera dá pra estimar pela geometria do quadro. Duas medidas
bastam:

- **O horizonte fica em y≈190**, a 40% do topo. O ponto de fuga da avenida
  está ali.
- **O topo do capacete fica 25 px acima do horizonte** e o contato do pneu,
  233 px abaixo.

Um ponto acima do horizonte está mais alto que o olho da câmera, então
**a câmera está abaixo do topo do capacete**. Supondo o capacete a 1,65 m do
chão, a razão 25/233 põe a câmera a **~1,5 m de altura**. Com FOV vertical
entre 45° e 55°, que é o que a convergência das faixas sugere, a distância
fica em **~3 a 3,7 m atrás do pneu traseiro**.

| | Vídeo (estimado) | Jogo hoje (`bike_tuning.gd`) |
| --- | --- | --- |
| Distância atrás da moto | ~3–3,7 m | `cam_distance = 6.4` |
| Altura | ~1,5 m (abaixo do capacete) | `cam_height = 2.25` (acima do capacete) |
| FOV | constante | `cam_fov = 50`, abre até 66° no talo (`cam_fov_speed_gain = 16`) |
| Horizonte | 40% do topo | ~46% do topo |
| Piloto na tela | ~53% da altura | ~29% da altura |

**Por que importa, além do tamanho:** com a câmera abaixo do capacete, o
piloto **corta o horizonte**. A cabeça e a bag ficam recortadas contra a
cidade, não contra o asfalto, e a silhueta lê melhor. Os carros ao lado
aparecem em altura de olho, não vistos de cima: o táxi colado à esquerda
ocupa um terço da tela. É isso que faz o corredor parecer apertado. Com a
câmera a 2,25 m, olhando de cima, o mesmo corredor vira um mapa.

### Seguimento lateral: a câmera mira o tronco, não a roda

Durante a curva à direita, o **topo** da moto (a bag) desliza até ~30 px à
direita do centro, enquanto o **pneu** vai até ~45 px à esquerda. Fora da
curva, os dois ficam a ±10 px do centro.

Ou seja: a câmera mantém o **tronco do piloto** perto do centro, e a
inclinação aparece como a roda saindo de baixo dele, não como o piloto
tombando para fora do quadro. A moto **pivota no ponto de contato**, e o olho
vê o pivô se deslocar.

O atraso lateral é pequeno. O piloto nunca sai de uma faixa de ±5% da largura
em torno do centro. Não há a moto "escapando" da câmera na saída de curva, que
o `chase_camera.gd` cultiva de propósito com `cam_follow = 7.0`. No vídeo a
câmera é quase rígida.

### A câmera não gira

**Nenhum quadro tem horizonte torto.** As verticais dos prédios continuam
verticais nos 145 quadros, inclusive com a moto a 25°. A câmera não acompanha
a inclinação.

No jogo, `cam_lean_follow = 0.2` passa 20% da inclinação para a câmera: a 38°
de `max_lean`, são 7,6° de horizonte torto. O comentário do `chase_camera.gd`
defende esse "pingo" para a curva ter peso. O vídeo sugere o contrário: com
câmera parada, **a inclinação inteira fica visível na moto**, e o horizonte
reto é a régua que deixa o olho medir o tombo. Vale testar no F3 com
`cam_lean_follow` entre 0 e 0,05.

### Sem tremor, sem respiro

A câmera não treme, não balança e não tem oscilação vertical. A velocidade é
vendida pelo borrão e pela densidade do cenário (ver *Como o vídeo vende
velocidade*), não por movimento de câmera. O `add_shake` do jogo continua com
sentido para impacto. Em cruzeiro, o vídeo não tem nenhum tremor.

### Proposta de partida

Para a proporção 16:9 do jogo, e não a 4:3 do vídeo, um alvo razoável é o
piloto ocupando **40–45% da altura** em velocidade de cruzeiro. A 53%, num
quadro mais largo e mais baixo, ele taparia o corredor à frente.

A conta (FOV vertical de 50°, conjunto de 1,75 m): para 45% da altura, a
distância efetiva fica em ~4,2 m. Ponto de partida para o F3:

- `cam_distance` ≈ **4,0**
- `cam_height` ≈ **1,6**
- mira 14 m à frente, mas a **1,4 m** de altura em vez de 1,2, para segurar o
  horizonte em ~40%
- `cam_fov_speed_gain` **menor** (8 em vez de 16). Hoje o FOV abrindo no talo
  encolhe o piloto de 29% para ~21% da tela, e o vídeo, a 128 km/h, não
  encolhe nada.
- `cam_lean_follow` ≈ **0**

São números para começar a sessão de jogo, não para colar no código. Câmera
mais perto também **esconde mais do que vem à frente**, e isso é *feel*: se o
corredor some atrás do piloto, a câmera chegou perto demais. A medida que
decide é jogar.

## A moto

### O que se vê

Uma *naked* de rua, preta, de cilindrada média (lê como 150 a 300 cc). Vista
sempre de trás, um pouco de cima:

- **Pneu traseiro largo e preto**, sem desenho de banda visível. O borrão come
  o desenho.
- **Lanterna traseira** retangular vermelha, embaixo do banco, sobre o suporte
  da placa.
- **Dois piscas âmbar** redondos, um de cada lado da lanterna.
- **Escapamento cromado** saindo baixo à direita, curto, com ponteira redonda.
  É o único metal brilhante da traseira e pega o reflexo do céu.
- **Pedaleiras** e o pé do garupa vazio. Embaixo do banco, o conjunto da
  suspensão traseira.
- **Retrovisores** nas pontas do guidão, pequenos, visíveis acima das mãos.

### O pneu

A roda não "gira" na tela: a 128 km/h, nenhum desenho de banda sobrevive ao
borrão. O que vende a rotação é o que está **em volta** do pneu:

- **O asfalto embaixo dele é risco**, não textura.
- **Um rastro claro sai de trás do ponto de contato**, visível nas curvas
  (`moto_ampliada.png`, fileira de baixo).
- **Na inclinação, a lateral do pneu aparece**, com uma faixa de brilho no
  ombro da borracha. É o que diz ao olho que a moto está de lado sobre um pneu
  redondo, e não tombada como uma caixa.

O jogo já gira a roda na velocidade exata da física (`entregador.gd`). A 35
m/s isso é uma volta e meia por quadro, e a 60 Hz, sem borrão, uma roda com
desenho de banda pisca ou parece girar para trás (efeito estroboscópico).
**Proposta:** acima de ~15 m/s, trocar o desenho da banda por um anel liso, ou
por um material de "roda borrada". É o truque de sempre dos jogos de corrida.

### A suspensão

Aqui o vídeo pede honestidade: **a suspensão não trabalha de forma visível.**

Medido quadro a quadro, o topo da bag oscila **±3 px** (~1% da altura do
conjunto, uns 2 cm em escala real), sem ritmo definido. Não há compressão na
entrada da curva nem nas duas faixas de pedestres, e a traseira não afunda nem
levanta.

O que dá a sensação de moto "viva", e não colada no chão, é esse **tremor
miúdo** somado à sombra parada embaixo dela. O vídeo não mostra amortecedor
trabalhando. Mostra um veículo que não é rígido.

O jogo hoje não tem nada disso: o modelo é de peças rígidas, e o corpo da moto
só inclina. Proposta, em ordem de retorno:

1. **Vibração de alta frequência** no corpo da moto e do piloto: 1 a 2 cm de
   amplitude, 8 a 15 Hz, crescendo com a velocidade. Barato e é o que o vídeo
   tem.
2. **Compressão leve na frenagem e na aceleração lateral**: 2 a 4 cm, com
   retorno amortecido. O vídeo não mostra isso, mas ladeira, crista e salto
   (`PROTOTIPO.md`, *Ladeira*) vão pedir. A moto que pousa de um salto sem
   afundar parece de brinquedo.
3. **O garfo dianteiro** afundando na frenagem. Da câmera de trás quase não se
   vê, então fica por último.

Os três são pose, não física. Moram no `Entregador`, que já lê velocidade,
acelerador e esterço a cada passo, e não mexem no `PlayerBike`. O invariante
*só o jogador roda física* fica intacto, e nenhuma medida do `selftest` muda.

### A inclinação

A medida mais útil do vídeo, porque é número de *feel*:

| Momento | Inclinação | Ritmo |
| --- | --- | --- |
| Reta (0–2 s) | −2° a −8° | Deriva lenta, quase parada |
| Entrada da curva (2,0–2,5 s) | 0° → +12° | ~25°/s |
| Aprofundando (2,5–3,6 s) | +12° → +25° | ~12°/s |
| Pico (3,6–3,9 s) | **~25°** | — |
| Segurando (4,0–5,0 s) | +15° a +21° | Correções pequenas, ±3° |
| Saída (5,0–5,4 s) | +17° → ~0° | **~50 a 80°/s** |
| Contra-inclinação (5,4–6,0 s) | −4° a −8° | — |

Três leituras:

- **A entrada é progressiva e a saída é seca.** Deita em mais de um segundo e
  levanta em um quarto disso. É o padrão da pilotagem real: entrar na curva é
  colocar peso aos poucos, e sair é soltar.
- **O pico é ~25°, não 38°.** O `max_lean = 38` do jogo deve valer para curva
  fechada no talo. O vídeo mostra uma curva suave a 128 km/h. Não há conflito,
  mas fica um dado: **numa curva suave, 25° já lê como muita inclinação**
  quando a câmera não gira junto.
- **Há contra-inclinação na saída.** A moto passa do zero e deita uns graus
  para o outro lado antes de se acomodar. É o que faz a troca de direção
  parecer peso em movimento, e não um ponteiro voltando ao centro.

No jogo, `lean_rate = 7` e `lean_return_rate = 9` são taxas exponenciais
(1/s). O retorno ser mais rápido que a entrada **já está certo em espírito**.
O vídeo pede uma diferença maior: retorno umas **3 vezes** mais rápido que a
entrada, e um *overshoot* pequeno no fim. Esse *overshoot* não existe hoje,
porque `lerp` exponencial nunca passa do alvo. Precisaria de uma mola
(posição + velocidade angular) no lugar do `lerp`, e isso é mudança no
`player_bike.gd`, que **mexe no `selftest`**. Se for feito, o baseline anda, e
a mensagem do commit diz por quê.

**Onde a moto pivota:** no ponto de contato do pneu, não no centro de massa.
O pneu desliza para o lado de fora na tela, e a bag para o de dentro. O
`Entregador` já tem a origem no chão, sob o centro da moto, o que bate com o
vídeo.

### A sombra

**Dura, escura e curta.** Grudada no pneu, sem nenhum espaço entre o pneu e o
início da sombra. É azul muito escuro, não preto puro, e cai para a direita e
um pouco para a câmera. Quando a moto deita para a direita, a sombra do corpo
se alonga para o mesmo lado e fica do tamanho da moto. Todo carro tem a sua,
igualmente dura.

O jogo já tem sombra de sol desde a P2. O que o vídeo acrescenta é a **cor**
(azul, que vem do céu: o `AMBIENT_SOURCE_SKY` da P2 já faz isso) e a
**dureza**: sem *blur* de borda.

## O piloto

### O que ele veste

- **Capacete preto** fechado, redondo, sem desenho.
- **Camiseta vermelha de manga curta**, com os antebraços de fora.
- **Bermuda jeans** azul, com dobra e desbotado visíveis.
- **Tênis** com sola clara, apoiados nas pedaleiras.
- **Bag térmica vermelha quadrada**, de ~45 cm de lado, presa nas costas. Tem
  borda costurada com vivo (o friso em volta) e fica ligeiramente acolchoada.
  O topo vai até a altura da orelha, a base até a cintura, e ela cobre as
  costas inteiras.

**Atenção de marca:** bag vermelha com camiseta vermelha é a identidade visual
de um app real. O `PROTOTIPO.md` fecha com *nada de nome, logo ou cor exata
de app real*, e o jogo hoje usa bag laranja (`BAG_FABRICA`) com jaqueta
escura. O que se copia do vídeo é a **roupa de calor carioca** (camiseta,
bermuda, tênis, antebraço de fora), que lê como entregador de verdade melhor
que a jaqueta. **A cor não se copia.** Decidir a cor da roupa é uma pergunta
em aberto, no fim.

### Postura e tronco

- **Tronco inclinado ~10–15° para a frente.** Sentado, sem deitar no tanque.
  O `TRONCO_DEITADO` do jogo, que deita mais conforme a velocidade, não
  aparece aqui: a 128 km/h, o entregador do vídeo continua sentado.
- **Cotovelos bem abertos para fora**, com os braços formando um losango
  com o guidão. As mãos ficam nas pontas do guidão, e os ombros, acima delas.
  É a postura de quem pilota *naked* no trânsito, e é muito legível de trás:
  os dois cotovelos são as pontas mais largas da silhueta, mais largos que a
  bag.
- **Joelhos fechados no tanque**, pés nas pedaleiras e calcanhar para dentro.
  Bate com o `JOELHO_FECHA = 15` m/s do jogo.
- **A bag é rígida e não balança.** Ela se move junto com o tronco, sem atraso
  e sem quique.

### O corpo na inclinação

**Piloto e moto inclinam como um bloco só.** Não há piloto pendurado para
dentro da curva (*hang-off*), não há joelho para fora e não há tronco
compensando para o lado oposto. A linha do capacete, o centro da bag e o eixo
da moto ficam praticamente alinhados em todos os quadros inclinados.

A cabeça acompanha a moto: o capacete inclina junto. A 24 fps não dá pra
afirmar se ele inclina um pouco menos, e no máximo seria uns poucos graus.

Também não dá pra afirmar **antecipação** (o tronco indo antes da moto na
entrada da curva). Em `moto_ampliada.png` e na tira de quadros consecutivos,
tronco e moto começam a deitar juntos.

O que isso significa para o jogo: o piloto inclinando com a moto já é o que
acontece hoje, porque quem inclina é o `Visual`, pai dos dois. **Não é preciso
inventar animação de corpo para a curva.** Os detalhes que valem a pena são
pequenos:

- O **tronco gira** levemente (yaw) para o lado do esterço. Já existe
  (`TRONCO_SEGUE_GUIDAO`).
- A **cabeça desfaz o *pitch*** do tronco. Já existe.
- **Falta:** a cabeça desfazer uma **fração pequena do *roll***, tipo 20%, para
  o olhar ficar mais perto do horizonte. O vídeo não prova isso, mas também
  não contradiz, e é o que piloto de verdade faz.

### Cadência da animação

O vídeo é **liso a 24 fps**. Não há a cadência travada em 12 fps que o
`DIRECAO_VISUAL.md` recomenda para o ator "ler como digitalizado". Não é
contradição, porque o vídeo não é pixel art, mas é um dado: **a referência em
movimento não pede cadência travada.** A decisão continua em aberto, e o
vídeo tira um argumento a favor dela.

## O trânsito

- **Todos no mesmo sentido.** Todo veículo mostra a traseira, o que bate com o
  jogo: o trânsito é paramétrico na curva e anda para a frente.
- **Elenco:** táxi amarelo (sedã com luminoso no teto e faixa quadriculada na
  lateral), sedãs brancos e prata, sedã escuro, SUV escuro, caminhão baú
  branco e uma van. **Não aparece ônibus nem moto.** Ônibus está no manifesto
  da P4, e não há motivo para tirá-lo.
- **Densidade:** 8 a 15 veículos visíveis por quadro, e 2 a 4 deles nos
  primeiros ~20 m. Ninguém fica sozinho em mais de uma faixa.
- **Velocidade relativa baixa.** O táxi fica emparelhado quase 2 s, e os
  carros à frente se aproximam devagar. **O trânsito anda quase na velocidade
  da moto.** É por isso que o corredor dura: os dois carros dos lados ficam um
  segundo inteiro ao lado do piloto. Com trânsito lento, o corredor viraria um
  piscar.
- **Distância no corredor:** menos de 1 m de cada lado, entre 4,0 e 5,3 s.
- **Lanternas acesas** (vermelhas) em todos, com brilho. Cada carro tem sombra
  dura embaixo.
- **Borrão por proximidade:** o carro colado borra quase até perder a forma.
  O carro a 20 m continua nítido. É a mesma regra do borrão de periferia (ver
  adiante).

Comparação: no jogo, o trânsito tem 20 carros vivendo numa janela em volta do
jogador (`PROTOTIPO.md`, *Densidade do trânsito*). O que o vídeo acrescenta é
a **diferença de velocidade pequena**: hoje os carros são obstáculos mais
lentos. Vale testar no F3 um trânsito mais rápido e mais denso, com a raspada
(`near_missed`) como métrica. É ela que diz se o corredor está puxando o
jogador para dentro.

## A rua

- **Faixas:** 3 a 4 no mesmo sentido, como as 4 de 3,3 m do jogo
  (`LANE_COUNT`, `LANE_WIDTH`).
- **Marcação:**
  - tracejado branco entre faixas, com traço longo e espaço longo;
  - linha de bordo branca contínua junto ao meio-fio;
  - **duas faixas de pedestres zebradas**, em ~2,6 s e ~5,6 s, cada uma
    seguida de linha de retenção;
  - a linha dupla amarela, a partir de 3 s.
- **Asfalto:** cinza médio puxando para o quente, com manchas mais claras,
  remendos e desgaste. Tudo vira risco longitudinal com o borrão. A P4a
  (`arte/chao.py`) já entregou asfalto com brita, remendo e marca de pneu.
  O que o vídeo acrescenta é a **faixa de pedestres**, que é a pintura de
  maior contraste do quadro e o marcador de velocidade mais forte do vídeo:
  as listas brancas passando sob a roda.
- **Cruzamentos:** dois, com semáforo suspenso. Nenhum carro atravessa: o
  cruzamento é cenário.
- **Relevo:** plano. A curva à direita é suave, de raio grande.

Atenção à regra da P4a: *nada fino atravessado na pista com período menor que
1,7 m*, porque pisca em vez de passar. A zebra tem listas de ~0,5 m com
período de ~1 m. **Ela vai piscar.** Duas saídas: zebra mais larga que a real
(listas de 1 m, período de 2 m), ou a zebra como decalque com mipmap forte.
Precisa ser testado rodando, não em captura.

## A calçada

É o item onde o vídeo está **mais longe** do jogo, e o que mais muda o
quadro.

### Largura

No vídeo a calçada tem **~5 a 8 m** nos trechos comuns. Na frente do teatro
vira praça, com mais de 15 m, e uma escadaria monumental. No jogo,
`SHOULDER = 2.2` m.

A calçada larga faz duas coisas no vídeo: dá **espaço para objetos** (poste,
árvore, pedestre, lixeira e toldo convivem sem se encostar) e **afasta os
prédios**, o que abre o céu e deixa a cena respirar. Com 2,2 m, a calçada é
um friso.

Separar as duas larguras ajuda:

- **Largura andável** (`SHOULDER`): mexe no *feel*, na fuga pela calçada e no
  `selftest` (fase da calçada). Pode continuar estreita.
- **Largura visual** (quanto chão existe entre o meio-fio e a fachada): não
  mexe em física nenhuma. Hoje os prédios nascem em `edge + 6.0`, então já há
  6 m de chão, mas é terreno, não calçada.

**Proposta:** desenhar a calçada (pedra portuguesa, que a P4a já fez) até a
fachada, com ~6 m. O limite andável fica onde está, ou vai para ~4 m, decisão
de *feel*. O resto vira faixa de serviço, onde ficam poste, árvore e lixeira,
e que bloqueia a moto, como no mundo real.

### O que mora nela

Cada item vem com a frequência aproximada no vídeo e o jeito como ele lê a
128 km/h:

| Objeto | Como é | Frequência | Como lê em movimento |
| --- | --- | --- | --- |
| **Poste de luz** | Ornamental, alto (~8–10 m), com dois braços curvos e luminária na ponta | A cada ~25–30 m, dos dois lados | Linha vertical fina passando. É o referencial de velocidade mais limpo do quadro |
| **Semáforo** | Braço projetado sobre a pista com caixa amarela de 3 focos; também em coluna na esquina | Nos dois cruzamentos | Passa por cima da câmera, um "portal" de cruzamento |
| **Placa de advertência** | Losango amarelo com seta de curva, em coluna | Uma, antes da curva | Mancha amarela alta. Avisa a curva antes de ela aparecer |
| **Palmeira** | Tronco fino e alto, leque no topo. Isolada ou em grupo de 2–3 | Constante nos primeiros 2,5 s | Silhueta inconfundível de cidade quente. É o que diz "Rio" |
| **Árvore de copa larga** | Tronco grosso e copa baixa e enorme, debruçada sobre a pista (lê como figueira ou amendoeira) | Duas ou três, em 2–3,5 s | Teto verde sobre a pista. Passa por cima da câmera e escurece o quadro por um instante |
| **Pedestre** | Dezenas, de 10 a 25 px de altura, roupa colorida, em pé, andando e na esquina | Sempre, nos dois lados | Textura de vida. Os próximos borram |
| **Lixeira / caçamba** | Caixa retangular vermelho-alaranjada, ~1,5 × 1 × 1 m, na beira do meio-fio | Uma a cada ~1,5 s | Bloco de cor saturada, ótimo marcador de distância |
| **Painel iluminado** | Mupi de ponto de ônibus, vertical, com tela clara | Um, no início | Retângulo luminoso, com brilho |
| **Toldo** | Lona colorida sobre cada loja do térreo: verde, vermelho, laranja, azul, amarelo | Contínuo depois de 2,5 s | Faixa de cor saturada na altura da cabeça. É o que dá ritmo à fachada |
| **Canteiro de grama** | Faixa verde baixa entre calçada e prédio | Na praça | Quebra o cinza do chão |
| **Escadaria** | Monumental, larga, na frente do teatro, com gente sentada | Uma | Marco: diz "lugar", não "rua genérica" |

No jogo hoje: **postes** (caixas de 0,35 × 6 m, a cada 18–34 m, com colisor:
dá pra derrubar rival neles) e nada mais na calçada.

**Proposta, em ordem de retorno por esforço:**

1. **Palmeira e árvore de copa** como *billboard* (rota A do
   `DIRECAO_VISUAL.md`: numeroso, estático, visto de longe), via
   `MultiMeshInstance3D`. É o que mais muda a leitura de "cidade quente".
2. **Lixeira vermelho-alaranjada**: uma caixa com material. Custo quase zero.
   Cuidado com a cor, que não pode competir com a bag do jogador.
3. **Postes com dois braços** no lugar da caixa. O colisor fica igual, porque
   é ele que serve ao combate.
4. **Pedestres** como *billboard* em `MultiMesh`, sem lógica nenhuma. Ninguém
   atravessa a pista, por enquanto.
5. **Toldo** como parte da fachada da P4b, não como objeto.
6. **Semáforo suspenso e placa**: só cenário. O semáforo **com lógica** saiu
   do protótipo de propósito (`PROTOTIPO.md`, *O que não está aqui*), e o
   vídeo não muda isso.

O critério de densidade vem do vídeo: **algo passa ao lado da câmera a cada
0,3–0,5 s**, de cada lado. Hoje, com poste a cada ~26 m a 35 m/s, passa um a
cada ~0,75 s, de um lado só por vez.

## Os prédios

- **Fachada contínua.** Depois dos 2,5 s não há buraco entre prédios: a rua é
  um corredor de paredes, e o céu só aparece em cima. Antes disso, há praças e
  recuos. A alternância entre **avenida aberta** e **corredor fechado** é
  ritmo, e vale manter.
- **Altura:** de 3 a 15 andares na rua, e torres de vidro bem mais altas ao
  fundo, formando o *skyline*.
- **Tipos:** teatro neoclássico com colunas e estátuas douradas, torre de
  igreja, sobrado colonial bege com telhado laranja, torre espelhada azul,
  prédio comercial de pedra ou tijolo com loja no térreo.
- **Térreo vivo:** vitrine, toldo, letreiro. O térreo é o que passa na altura
  dos olhos, e é o que tem mais detalhe.
- **Outdoors iluminados** nas fachadas e no topo dos prédios, com cor viva e
  brilho de tela. São a coisa mais brilhante do quadro depois do céu.

No jogo hoje: caixas de 6 a 26 m de altura, sorteadas, com fachada e mural
previstos na P4b. O jogo já tem prédio colonial e torre (quadro `reta` da
prova). Falta o térreo vivo e o outdoor luminoso, que com o *glow* da P3 vira
o ponto mais claro da tela, como no vídeo.

**Sobre a troca Rio → *downtown*:** é erro da IA, mas aponta uma decisão
real. O vídeo fica mais "jogo" depois da troca, porque a fachada contínua com
toldos tem mais ritmo que a praça aberta. **A proposta é Rio com o ritmo do
*downtown*:** prédio carioca (sobrado, art déco de Copacabana, colonial do
Centro) colado em sequência, com térreo comercial e toldo. Rio tem isso de
sobra. Fica fora qualquer marco real reconhecível em escala (o teatro inteiro,
por exemplo), por custo de arte, não por regra.

## O céu

- **Gradiente:** azul profundo e saturado no topo, clareando até um azul
  pálido no horizonte.
- **Nuvens cúmulo**, brancas, gordas e com borda definida. Têm base azulada
  ou acinzentada e topo estourado de luz. Ficam concentradas numa faixa entre
  o horizonte e o meio do céu, mais esparsas no alto.
- Em vários quadros, **as nuvens mostram blocos e degraus de cor**: lembram o
  dither e a banda que o `DIRECAO_VISUAL.md` pede.
- **O sol não aparece.** A luz é de sol alto.
- As nuvens não se movem de forma perceptível em 6 s, só derivam junto com a
  câmera.

No jogo hoje (P2): céu procedural com gradiente, **sem nuvem**. O quadro
`reta` da prova mostra um azul liso. O manifesto da P4 já prevê
`ceu_nuvens.png` (`sky_cover` do `ProceduralSkyMaterial`), e o vídeo confirma
o desenho dela: cúmulo, faixa baixa, borda dura e base azulada.

## Luz e cor

- **Meio-dia de sol duro.** Toda superfície voltada para cima está clara e
  quente, e toda sombra é curta e azulada.
- **Saturação alta em tudo:** o amarelo do táxi, o vermelho da bag, o verde da
  árvore e o azul do céu estão todos no limite.
- **Contraste alto** sem sombra esmagada: dá pra ler o que está na sombra.
- **Brilho (*bloom*)** nos outdoors, nos carros brancos e nos reflexos do
  cromo.
- **Textura de pixel em alguns pontos:** o asfalto do primeiro quadro tem
  blocos visíveis, como um *upscale* de pixel art. No resto, o vídeo é mais
  pintura digital que pixel.

A P3 já entregou tonemap, LUT do dia e dither. **Pergunta que o vídeo levanta:**
o quanto de pixel o jogo quer. O vídeo é "HD saturado com HUD de arcade", e o
jogo está em "640×360 com quantização e dither". Os dois são legítimos, e
eles não são o mesmo look. Ver *Perguntas em aberto*.

## Como o vídeo vende velocidade

A 128 km/h, e sem um único quadro de tremor de câmera, o vídeo parece muito
rápido. Os ingredientes, em ordem de peso:

1. **Borrão radial forte.** O chão, a periferia e os carros próximos viram
   risco. **O piloto fica 100% nítido.** O borrão cresce com a distância do
   centro e com a proximidade da câmera: o táxi colado some, e o carro a 20 m
   não borra. É exatamente o efeito com máscara de profundidade da P7.
2. **Faixas viram linhas.** O tracejado e a zebra viram riscos contínuos.
3. **Densidade lateral.** Algo passa ao lado a cada 0,3–0,5 s (ver
   *A calçada*).
4. **Coisas passando por cima.** Árvore de copa, semáforo suspenso e braço de
   poste cruzam o topo do quadro. Passar por baixo de algo é a sensação mais
   forte de velocidade que existe, e o jogo hoje não tem nada acima da pista.
5. **Câmera baixa.** Com a câmera a 1,5 m, o chão rasante ocupa a metade de
   baixo da tela, e chão rasante é onde o borrão mais aparece.

**O que o vídeo não usa:** linhas de velocidade desenhadas por cima, FOV que
abre, tremor de câmera, rastro de luz. A P7 manda testar primeiro as linhas de
velocidade, que são baratas. O vídeo sugere que o **borrão com máscara** é o
que vale, e que as linhas talvez nem façam falta.

## A HUD

Quatro cantos, com o centro vazio. Mesmo vocabulário das quatro imagens
paradas, agora visto em detalhe:

| Canto | Legenda | Valor | Extra |
| --- | --- | --- | --- |
| Topo esquerdo | `POS` | `1/6` | — |
| Topo direito | `LAP` | `1/3` | — |
| Baixo esquerdo | `SPEED` | `128` grande + `km/h` pequeno | Barra segmentada |
| Baixo direito | `TIME` | `00:17.3` (mm:ss.d) | Barra segmentada |

Margem de ~5% da largura e da altura em relação à borda.

**Tipografia:**

- **Legenda:** pequena, itálica, negrito, com **degradê vertical do amarelo
  para o laranja**. Contorno preto grosso e sombra deslocada para baixo.
- **Valor:** grande, itálico, branco com leve degradê para cinza-claro
  embaixo (lê como chanfro), contorno preto grosso.
- A unidade (`km/h`) vem menor que o número, na mesma linha de base.
- O estilo é de arcade dos anos 90: itálico, pesado, sem serifa.

**A barra segmentada:**

- **Moldura** escura, de canto arredondado, com borda fina clara (branca ou
  prateada).
- **Segmentos** separados por um vão escuro: 18 na barra de `SPEED` e 15 na
  de `TIME`.
- **Degradê por segmento** de verde → amarelo-verde → amarelo → laranja →
  vermelho. Cada segmento tem uma cor só, então o degradê sobe em degraus.
- Os segmentos **apagados** ficam cinza-escuro, não somem.
- **A barra não mexe** nos 6 s, porque a velocidade não muda (erro da IA). Num
  jogo, ela acenderia segmento a segmento.

**A HUD é estática:** não treme com a câmera e não pulsa. É a única coisa
perfeitamente parada na tela, e isso ajuda o olho a separar interface de
mundo.

**No jogo hoje** (`hud.gd`): posição, velocidade, tempo restante, distância
restante, estrelas, adrenalina e combo `CORREDOR xN`, com fonte padrão sem
contorno, desenhados em coordenadas de 320×180. A P8 já prevê o redesenho, e o
vídeo fecha a forma. O conteúdo tem três diferenças que são decisão de design:

- **`LAP`**: a corrida do jogo é rota de A a B, não volta. O canto vira
  **distância restante** ou **entrega**, e a forma é a mesma.
- **`TIME`**: no jogo, o relógio é **regressivo** (tempo de entrega). Vale a
  pergunta: a barra do `TIME` mede o tempo que sobra? Segmento apagando
  conforme o prazo acaba lê melhor que um número.
- **Estrelas, adrenalina e combo** não existem no vídeo. Não é defeito: o jogo
  tem mecânica que o vídeo não mostra. O `DIRECAO_VISUAL.md` já sugere que
  adrenalina vire efeito de borda de tela em vez de barra, e o combo
  `CORREDOR x3` cabe como texto que aparece e some no centro alto, sem ocupar
  canto fixo.

## O que o jogo já tem, e o que falta

Lado a lado, item por item. "Fase" aponta para o `PROVA_VISUAL.md` quando a
tarefa já está prevista lá.

| Item | Vídeo | Jogo hoje | Distância | Fase |
| --- | --- | --- | --- | --- |
| Câmera: distância e altura | ~3,3 m, ~1,5 m, abaixo do capacete | 6,4 m, 2,25 m, acima | **Grande** | nova |
| Câmera: giro com a inclinação | nenhum | 20% | média | nova |
| Câmera: FOV com a velocidade | constante | +16° no talo | média | nova |
| Piloto na tela | ~53% da altura (4:3) | ~29% | **grande** (decorre da câmera) | nova |
| Inclinação: pico numa curva suave | ~25° | até 38° | ok | — |
| Inclinação: entrada lenta, saída seca, *overshoot* | sim | só a diferença de taxa | pequena | nova |
| Suspensão / vibração | tremor miúdo | nenhuma | média | nova |
| Roda borrada em alta | sim | roda com desenho, girando | pequena | nova |
| Postura do piloto | sentado, cotovelos abertos | deita com a velocidade | pequena | nova |
| Roupa | camiseta, bermuda, tênis | jaqueta | decisão | nova |
| Sombra dura e azulada | sim | sim (P2) | ok | P2 ✔ |
| Asfalto texturizado | sim | sim (P4a) | ok | P4a ✔ |
| Faixa de pedestres | duas em 6 s | nenhuma | média | P4 |
| Calçada larga | 5–8 m | 2,2 m | **grande** | nova |
| Objetos na calçada | 8 tipos | só poste-caixa | **grande** | P4b + nova |
| Coisas por cima da pista | árvore, semáforo, braço de poste | nada | grande | nova |
| Fachada contínua com térreo vivo | sim | caixa | grande | P4b |
| Outdoor luminoso | sim | não | média | P4b |
| Trânsito com modelo | sim | caixa | grande | P4c |
| Trânsito rápido e denso, corredor de 1 m | sim | mais lento | média, de *feel* | F3 |
| Céu com nuvem | cúmulo | gradiente liso | média | P4 (`ceu_nuvens`) |
| Paleta saturada, *bloom* | sim | sim (P3) | ok | P3 ✔ |
| Borrão radial com máscara | forte | nenhum | **grande** | P7 |
| HUD de arcade nos quatro cantos | sim | fonte padrão, magra | grande | P8 |

## Próximos passos

Em ordem de **retorno sobre a pergunta do protótipo**, não de beleza. Os
primeiros mexem no *feel* e são baratos. Os últimos são arte e dependem dos
primeiros estarem fechados, pela mesma lógica que pôs o greybox antes da arte.

### 1. Câmera perto e baixa — sessão de F3, sem código

Os sliders existem: `cam_distance`, `cam_height`, `cam_fov_speed_gain` e
`cam_lean_follow`. Partir dos números da seção *A câmera* e **jogar**.

É o passo de maior retorno do documento inteiro: o vídeo inteiro está
enquadrado assim, e nenhum outro item da lista fica igual com a câmera onde
está hoje. Fazer antes de qualquer arte, porque a câmera decide o que a arte
precisa mostrar (de perto, o detalhe do piloto pesa mais; o do fundo, menos).

**O que cuidar:** a mira (14 m à frente, 1,2 m de altura) está cravada em
`_alvos()`, e não é slider. Se a câmera baixa pedir mira mais alta, vira
parâmetro no `BikeTuning`. A prova visual muda de cara, então a P0 e o
`baseline_visual.json` andam no mesmo commit, com o motivo.

*Aceite:* numa sessão de jogo, o corredor entre dois carros **parece mais
apertado** e o que vem à frente continua legível a 180 km/h.

### 2. A moto viva — vibração, inclinação com mola, roda borrada

- Vibração miúda no `Entregador`, amarrada à velocidade.
- Roda trocando para o anel liso acima de ~15 m/s.
- Inclinação com mola (retorno ~3× mais rápido que a entrada e *overshoot*
  pequeno) no `player_bike.gd`. **Este item muda o `selftest`**, e o baseline
  anda com justificativa.
- A cabeça desfazendo ~20% do *roll*.

*Aceite:* jogando, a troca de direção no corredor tem peso. A moto deita, volta
e assenta, em vez de deslizar de um ângulo para outro.

### 3. Borrão radial com máscara de profundidade (P7)

O vídeo é a prova de que é este o efeito, e não as linhas de velocidade. Ele
também é o que mais compensa a falta de detalhe do cenário: o que está borrado
não precisa ter detalhe.

*Aceite:* o da P7. A 180 km/h a periferia borra e o piloto fica nítido.

### 4. A calçada larga e povoada

- Calçada desenhada até a fachada (~6 m), separando limite andável de largura
  visual.
- Palmeira, árvore de copa, lixeira, poste de dois braços e pedestre, como
  *billboard* em `MultiMesh`.
- **Algo por cima da pista:** copa de árvore debruçada, braço de semáforo.
- Faixa de pedestres, com o teste de cintilação.

*Aceite:* algo passa ao lado a cada 0,3–0,5 s, e o `fps` (`dev.py fps`) não
regride além do orçamento.

### 5. Prédios com térreo vivo e outdoor (P4b), trânsito com modelo (P4c), céu com nuvem

O que já está no manifesto da P4, agora com a forma vista no vídeo: fachada
contínua, toldo, outdoor luminoso, cúmulo.

### 6. HUD (P8)

Os quatro cantos, legenda em degradê amarelo-laranja, valor branco com
contorno e barras segmentadas. Antes de desenhar, decidir o conteúdo (ver
*A HUD*).

### 7. A roupa do entregador

Camiseta, bermuda e tênis no lugar da jaqueta, em `arte/entregador.py`, com a
cor decidida. É barato depois que a câmera estiver perto, e só faz sentido
depois disso: a 29% da tela, a diferença entre jaqueta e camiseta mal aparece.

## O que este vídeo não muda

Os invariantes do `CLAUDE.md` continuam todos de pé. Nenhum item acima pede
para quebrar um deles:

- **Chão sem colisor.** A calçada larga é desenho. O limite andável continua
  analítico.
- **Só o jogador roda física.** Vibração, suspensão e roda borrada são pose no
  `Entregador`. Pedestre e árvore são *billboard* sem lógica.
- **HUD dentro do SubViewport**, inclusive a HUD nova.
- **Semente fixa no banco de provas.** Vibração com ruído precisa vir de fonte
  determinística, como a fase do tempo de física, nunca de `randf()` solto.
  Hoje nenhuma medida depende da pose, e deve continuar assim.

E o que continua fora de escopo: semáforo com lógica, chuva, noite, áudio,
marca real.

## Perguntas em aberto

Decisões de design que o vídeo levanta e que o código não responde:

1. **Quanto de pixel?** O vídeo é "HD saturado com HUD de arcade". O jogo
   está em 640×360 com dither (P1, P3). Seguir a direção do pixel, que é o
   `DIRECAO_VISUAL.md`, ou puxar para o look do vídeo, mais liso, com o pixel
   só na HUD? Muda a P5 (cadência de 12 fps) e o quanto investir em detalhe
   de textura.
2. **A cor da roupa e da bag.** A roupa do vídeo lê melhor como entregador.
   As cores do vídeo são de um app real. Que combinação é do RushFood?
3. **A HUD fala de volta (`LAP`) ou de entrega?** A corrida do jogo é rota de
   A a B com prazo.
4. **Rio ou cidade genérica?** O vídeo começa no Rio e termina numa cidade
   qualquer. O `DIRECAO_VISUAL.md` fala de "leitura de Rio" (pilar 9). A
   proposta deste documento é Rio com ritmo de *downtown*, mas a decisão é de
   quem define o jogo.
5. **Quão apertado é o corredor?** O vídeo passa a menos de 1 m dos carros.
   Isso é *feel* puro, e o banco de provas não mede: é sessão de jogo.

## Apêndice — as medidas, quadro a quadro

Saída de `mede.py`, a cada três quadros. `cx` é o centro da bag (o centro da
tela é 320), `pneu_x` é o ponto de contato do pneu, e `incl` é a inclinação
em graus (positivo = topo para a direita). As linhas marcadas com † foram
descartadas: o detector pegou um carro ou a sombra.

| Quadro | t (s) | cx | pneu_x | incl |
| --- | --- | --- | --- | --- |
| 001 | 0,00 | 325 | 342 | −5,6 |
| 013 | 0,50 | 308 | 333 | −8,2 |
| 025 | 1,00 | 312 | 320 | −2,6 |
| 037 | 1,50 | 306 | 314 | −2,8 |
| 049 | 2,00 | 321 | 319 | +0,5 |
| 055 | 2,25 | 340 | 321 | +6,4 |
| 061 | 2,50 | 353 | 314 | +12,7 |
| 070 | 2,88 | 329 | 301 | +9,7 |
| 073† | 3,00 | — | — | — |
| 079 | 3,25 | 326 | 286 | +14,0 |
| 085 | 3,50 | 332 | 273 | +21,4 |
| 088 | 3,63 | 343 | 275 | +24,8 |
| 094 | 3,88 | 348 | 274 | +26,0 |
| 100 | 4,13 | 335 | 291 | +16,0 |
| 109 | 4,50 | 333 | 283 | +18,6 |
| 112 | 4,63 | 330 | 270 | +20,9 |
| 121 | 5,00 | 336 | 285 | +16,9 |
| 124 | 5,13 | 309 | 299 | +3,6 |
| 130† | 5,38 | — | — | — |
| 133 | 5,50 | 307 | 329 | −7,8 |
| 139 | 5,75 | 319 | 338 | −6,8 |
| 145 | 6,00 | 324 | 336 | −4,2 |

O topo da bag fica entre y=170 e y=182 do quadro 25 em diante. Esses ±6 px
incluem o efeito da própria inclinação, então a oscilação vertical de verdade
é menor. É daí que sai a leitura de que a suspensão não trabalha de forma
visível.
