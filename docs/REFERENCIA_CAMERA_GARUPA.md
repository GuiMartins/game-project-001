# Referência de câmera: a filmagem de garupa

Descrição medida de um segundo vídeo de referência, desta vez **só da
câmera**: onde ela está, para onde olha, como anda, como treme e o que ela faz
com o piloto na tela. O objetivo é especificar uma câmera nova, a
**`GARUPA`**, que entra como mais uma opção no ciclo do `F2` (e na tela de
configurações), ao lado de `PERSEGUICAO`, `CAPACETE` e `DIAGNOSTICO`. Ela não
substitui a perseguição, e o banco de provas continua rodando na perseguição.

O primeiro vídeo ([REFERENCIA_VIDEO.md](REFERENCIA_VIDEO.md)) tem uma câmera
de *game*: alta o bastante, rígida, horizonte travado. Este tem uma câmera de
**gente filmando**: perto, baixa, ultra-angular, viva. São duas linguagens
diferentes, e por isso viram dois modos, e não um ajuste no mesmo.

Este documento é **descrição e proposta**, não plano aprovado. Os números da
proposta são ponto de partida para o F3, e a medida que decide é jogar.

## Onde estão os arquivos

| Arquivo | O que é |
| --- | --- |
| `docs/referencias/video_02.mp4` | O vídeo original, intacto |
| `docs/referencias/video_02/folha.png` | 44 quadros, um a cada 0,5 s: o vídeo inteiro numa imagem |
| `docs/referencias/video_02/tempo_1.png` … `tempo_4.png` | Quadros maiores, com o tempo escrito: 0–5,5 s, 6–11,5 s, 12–17,5 s, 18–21,8 s |
| `docs/referencias/video_02/grade_1.png` … `grade_3.png` | Quadros-chave com grade de 10%, de onde saíram as posições na tela |
| `docs/referencias/video_02/tampa_de_bueiro.png` | 10,3–10,8 s: a única coisa redonda que passa embaixo da lente (ver *O tremor*) |
| `docs/referencias/video_02/fluxo.py` | Mede giro e tremor da câmera quadro a quadro pelo fundo |
| `docs/referencias/video_02/folha.py`, `grade.py` | Geram as folhas acima |

Tudo vai por Git LFS, como o `video_01`.

## O que o vídeo é, e o que ele não é

**Ficha técnica:** 21,85 s, 655 quadros a 30 fps, **720×1280 (9:16, em pé)**,
VP9 com transferência HLG (vídeo de celular em HDR). Áudio AAC, não analisado:
este documento é só câmera.

**O que mostra:** uma moto vermelha de rua dando **grau** (empinando) numa rua
de bairro em ladeira, com piloto e garupa. O piloto fica em pé na pedaleira e
estica uma perna para trás e para o lado. A câmera persegue a moto o tempo
todo, de muito perto. É o plano típico de vídeo de grau: alguém na garupa de
**outra moto**, filmando com o celular na lente **0,5×**.

**É gerado por IA.** Os sinais, que **não podem virar requisito**:

- **As pessoas trocam.** Até ~3 s há uma pessoa só na moto, de capacete com
  rosa. A partir de 4 s são duas, e o capacete rosa passou para a garupa.
- **A sinalização muda de lado.** A linha amarela do centro aparece à direita
  da câmera entre 7 e 18 s, e no fim (20,6 s em diante) vira uma linha dupla
  bem no meio do quadro, sem a câmera ter atravessado nada.
- **A câmera atravessa a perna.** Entre 19,6 e 20,3 s o chinelo do piloto
  ocupa um terço da tela, a uns 30 cm da lente. Uma moto de verdade naquela
  posição bateria na perna.
- **O carro branco** de 20,3 s surge rente à direita sem ter sido visto antes.

O que se aproveita é a **linguagem da câmera**: posição, lente, enquadramento,
como ela respira e treme. É isso que dá o *feel* de "tô na rua do lado dele".

## Como foi medido

Três ferramentas, cada uma com a sua precisão:

1. **Posição na tela, a olho, com grade de 10%** (`grade_*.png`). Topo do
   capacete, contato do pneu traseiro com o chão, ponto de fuga da rua. Erro
   de **±2%** da altura da tela.
2. **Giro e tremor pelo fluxo óptico** (`fluxo.py`). Rastreia ~130 pontos por
   quadro nas bordas e no topo, onde o piloto quase nunca está, e ajusta uma
   similaridade com RANSAC. O giro entre quadros é bom (±0,1°). O
   deslocamento mistura tremor com a paralaxe da moto andando para a frente:
   serve para o **tremor** (o que varia rápido), não para a trajetória.
3. **Altura, distância e lente pela geometria.** Com o horizonte, o topo do
   capacete e o contato do pneu na tela, a razão das distâncias ao horizonte
   dá a altura da câmera, sem depender da lente. A distância e a lente saem
   de cruzar isso com a largura do capacete. Precisão aqui é **ordem de
   grandeza**: a rua é ladeira (o ponto de fuga fica acima do horizonte de
   verdade), a lente distorce, e é IA.

Uma tentativa de segmentar o piloto automaticamente pela roupa escura não
segurou (a calça é azul-marinho e o asfalto à sombra cai na mesma faixa), e
ficou de fora.

Para refazer, com o ffmpeg e `pip install opencv-python-headless numpy pillow`:

```bash
ffmpeg -i docs/referencias/video_02.mp4 -vf scale=360:640 quadros/%03d.png
python docs/referencias/video_02/fluxo.py quadros > fluxo.csv
python docs/referencias/video_02/grade.py quadros grade.png 7.5,9,12,14,16
```

## Linha do tempo da câmera

Posições na tela em **% da altura a partir do topo** (o vídeo é em pé).
"Contato" é onde o pneu traseiro toca o chão.

| Tempo | Distância (lente → pneu traseiro) | Lado | Piloto na tela | O que a câmera faz |
| --- | --- | --- | --- | --- |
| **0–3 s** | ~3–4 m | Direita, rente ao meio-fio | 15–19% da altura (capacete 33%, contato 52%) | Perseguição "longe". A câmera anda colada na calçada: mato, placa e lixeira passam a meio metro da lente, borrados, pela borda direita |
| **3–5,5 s** | De ~3,5 m para ~1 m | Da direita para o centro | Cresce de 19% para 56% | **Aproximação**, ~1,2 m/s de fechamento. A câmera rola ±12° no caminho |
| **5,5–7 s** | ~1 m | Centro | 55–60% | Atrás e um pouco abaixo do banco. A moto começa a empinar |
| **7–19,5 s** | ~0,8–1,3 m | **Três quartos**, a ~20–25° do eixo da moto | **55–76%** (capacete 1–17%, contato 72–80%) | O plano principal: 12 s segurando. Tamanho respira ±15%, giro de ±5°, tremor contínuo |
| **19,5–20,6 s** | ~0,5 m da perna | Cruza para a direita | — | Passagem rente: o pé enche a tela e um carro passa a 1 m pela direita |
| **20,6–21,8 s** | ~1 m | Centro, atrás | ~62% | Fim, linha dupla amarela no meio do quadro |

A coreografia não é aleatória: **longe → aproxima → segura de três quartos →
troca de lado → centro**. Trocas a cada 2 a 12 s, cada uma levando ~1 s.

## A câmera, item a item

### O modelo mental: um cinegrafista na garupa de outra moto

Tudo o que segue sai disto, e é por isso que o modo se chama `GARUPA`. A
câmera **não é presa na moto do jogador**. Ela é segurada por alguém em outro
veículo, que:

- **tem a sua própria velocidade**, e por isso fica para trás quando o piloto
  acelera e encosta quando ele freia;
- **anda na rua**, e por isso a altura dela segue o chão embaixo **dela**, e
  não o da moto, e ela não sai da pista;
- **escolhe um lado** para não ficar atrás da roda, e troca de lado de vez em
  quando;
- **inclina nas curvas** junto com a moto dele, e por isso o horizonte gira um
  pouco;
- **segura o celular na mão**, e por isso a imagem treme num ritmo de corpo
  (2 a 5 Hz), e não num chiado de motor;
- **mira no piloto**, não na rua: o piloto fica no meio, a rua vai para onde
  der.

Copiar só os números (distância, FOV) sem esse modelo dá uma câmera de
perseguição colada, e não esta. O que faz o vídeo ser o vídeo é a câmera ter
**inércia própria** e **mira firme**.

### A lente: ultra-angular, com barril

- **Ultra-angular.** O piloto a ~1 m cobre 60–75% da altura de um quadro em
  pé, e o chão aparece até ~0,4 m da lente na borda de baixo. Cruzando a
  geometria (ver *Como foi medido*), a lente fica entre **95° e 115° na
  vertical do vídeo em pé**, o que bate com a 0,5× de celular: ~120° na
  diagonal, ~81° × 113° em 9:16.
- **Distorção de barril visível.** Postes e fios perto da borda **curvam**
  (0,5 s, 7,0 s, 12,0 s, 18,0 s). Linhas retas no centro continuam retas.
  É o que diferencia "celular 0,5×" de "FOV alto de jogo", que estica a borda
  em vez de curvá-la.
- **FOV constante.** Lente física, sem zoom. A velocidade aparece pela
  proximidade, não pelo FOV abrindo.

### A altura: no quadril, abaixo do capacete

O **horizonte fica em 33–37% do topo** em todo o plano principal, e passa na
altura da cintura do piloto. O capacete fica bem acima do horizonte: **a
câmera está abaixo da cabeça**, como no vídeo 1, só que bem mais.

Pela razão das distâncias ao horizonte, a lente fica a **~1,2 m do chão**
(0,0 s: capacete 5% acima do horizonte, contato 14% abaixo; com o capacete a
~1,6 m, a câmera fica a 1,6 × 14/19 ≈ 1,2 m). No plano principal o piloto
está em pé na pedaleira, e o mesmo cálculo dá 1,2–1,3 m.

A câmera **aponta para baixo**, ~12–16°: o horizonte acima do centro e o
banco da moto no centro do quadro. É esse olhar de cima para baixo, de perto,
que faz o chão ocupar o terço de baixo inteiro.

### A distância: um metro

No plano principal, a lente fica a **~0,8–1,3 m** do pneu traseiro. A perna
esticada do piloto, de ~1 m, chega a encostar na câmera (19,6–20,3 s), o que
confirma a ordem de grandeza. Na abertura, "longe" é só ~3,5 m.

O efeito de estar a um metro não é só o piloto grande. É a **perspectiva
forçada**: o pneu traseiro e a pedaleira ficam enormes perto do capacete, a
perna que vem na direção da lente fica gigante, e qualquer coisa que passa ao
lado (o carro de 20,3 s, a placa de 1,5 s) atravessa a tela em 3 ou 4 quadros.

### O enquadramento: a roda traseira é o pino

A medida mais útil do vídeo. Em todos os quadros do plano principal:

| | Na tela (vídeo em pé) |
| --- | --- |
| Contato do pneu traseiro | **x = 50–55%**, y = 72–80% |
| Topo do capacete | y = 1–17% |
| Centro do quadro | cai no **banco**, na altura do quadril da garupa |
| Horizonte | y = 33–37% |

O **contato do pneu traseiro é o ponto mais estável da tela**: fica numa faixa
de ±3% na horizontal pelos 12 s do plano principal. O tronco do piloto não:
ele balança de um lado para o outro com a inclinação e a empinada. Ou seja, a
câmera **mira num ponto que não inclina com a moto** — a vertical que sobe do
pneu traseiro até a altura do banco —, e a inclinação aparece inteira como o
tronco tombando por cima de uma roda que não sai do lugar.

É o mesmo achado do vídeo 1 (a moto pivota no contato), levado ao extremo.

O piloto também é **cortado** pelas bordas sem cerimônia: perna para fora da
direita, capacete encostando no topo (9,0 s). A câmera prioriza o tronco e a
roda, e aceita perder as pontas.

### O lado: três quartos, e troca

No plano principal, o ponto de fuga da rua fica a **20–30% da largura**, à
esquerda do centro, enquanto a moto fica no meio. A câmera não está atrás da
moto: está **de lado, a ~20–25° do eixo dela**, mirando nela. O eixo da moto
cruza a tela em diagonal, com a frente apontando para o fundo da rua.

Isso tem uma consequência de jogo, e é a mais importante para nós: **o fundo
da rua fica visível ao lado do piloto**. Com a câmera bem atrás e o piloto
ocupando 60% da altura no meio, ele taparia exatamente o que vem pela frente.
De três quartos, o corredor aparece.

Os lados ao longo do vídeo: direita (0–4 s), centro (5,5–7 s), três quartos
(7–19,5 s), passagem pela direita (19,5–20,6 s), centro (20,6 s em diante).
**Cada troca leva ~1 s**, sem corte, em curva suave.

### A distância respira

O piloto varia de 55% a 76% da altura no plano principal: **±15% em torno da
média**, devagar (períodos de 2 a 4 s). É a moto da câmera ganhando e perdendo
uns 20 cm em relação à do piloto. Sem isso, a câmera parece um braço de metal
preso no banco.

### O giro: o horizonte não é travado

Diferente do vídeo 1, aqui **o horizonte gira**:

- **No plano principal: ±5°**, deriva lenta. Pelo fluxo, a mediana é de 0,1 a
  0,2° por quadro: **3 a 6°/s**.
- **Nas manobras: picos de 10 a 15°.** Na aproximação (3–4 s) a câmera rola
  ~25° de um lado e ~14° de volta em dois segundos.

O giro **não copia a inclinação da moto do piloto**. Ele é o da moto do
cinegrafista (que faz a mesma curva, com atraso) somado ao pulso de quem
segura. Na prática, uma fração da inclinação do piloto, atrasada, mais uma
deriva lenta.

### O tremor: de corpo, não de motor

Medido pelo fluxo no fundo, quadro a quadro, depois de tirar a deriva lenta
(média móvel de 9 quadros):

| Faixa | Fração da energia do tremor |
| --- | --- |
| < 2 Hz | ~5–10% |
| **2–5 Hz** | **~45%** |
| 5–10 Hz | ~30% |
| 10–15 Hz | ~15–20% |

A mesma distribuição nos três eixos (giro, horizontal, vertical). O tremor
dominante é de **2 a 5 Hz**: braço e corpo em cima de uma moto, não motor
(que seria uma linha fina acima de 30 Hz, nem visível a 30 fps).

**Amplitude:** desvio-padrão de 1,3–2,4 px por quadro numa imagem de 360 px
de largura, no plano principal. Convertendo pela lente, **~0,5–0,8° de giro
eficaz** a 3–4 Hz. É forte: a 640×360 e 80° de FOV, isso é **2 a 3 pixels**
de tremor na tela do jogo.

Picos isolados quando a câmera passa por cima de alguma coisa: a tampa de
bueiro de 10,5 s (`tampa_de_bueiro.png`) e a passagem de 19,5–20,6 s, onde o
desvio-padrão sobe para 7–9 px.

**Não é ruído branco.** O `add_shake` do jogo sorteia um deslocamento novo a
cada quadro (`randfn`), e isso lê como "câmera digital chacoalhando": energia
igual em todas as frequências até o limite do quadro. O tremor do vídeo é
**de banda**: tem ritmo.

### O borrão

O borrão do vídeo é **o efeito de estar perto**, não um filtro:

- O **terço de baixo** (asfalto a 0,4–1,5 m da lente) é risco puro, sempre.
- O que passa **rente à câmera** pelos lados (mato, placa, carro) vira borrão
  direcional na hora.
- O **piloto fica nítido**: anda na mesma velocidade da câmera.

É o borrão radial com máscara de profundidade da Fase 5 do
[DIRECAO_VISUAL.md](DIRECAO_VISUAL.md). Nesta câmera ele deixa de ser enfeite:
o asfalto a meio metro da lente, a 50 m/s, anda dezenas de pixels por quadro,
e a textura do chão sem borrão vai **piscar** (ver *Riscos*).

## Comparação com o que o jogo tem

| | `PERSEGUICAO` hoje | Vídeo 2 (medido) | `GARUPA` proposta |
| --- | --- | --- | --- |
| Distância atrás | 6,4 m | ~1 m (0,8–1,3) | **1,5 m** |
| Altura | 2,25 m (acima do capacete) | ~1,2 m (cintura) | **1,25 m** |
| Mira | 14 m à frente, 1,2 m de altura | o banco | **o banco: contato + 0,3 m à frente, 0,85 m de altura** |
| FOV vertical | 50°, abre até 66° | ~95–115° (em pé) | **80°**, fixo |
| Distorção | nenhuma | barril visível | opcional, fase 5 |
| Lateral | atrás | três quartos, ~20–25° | **±0,7 m** de lado (~21°) |
| Distância varia? | não (só o atraso de `cam_follow`) | ±15%, devagar | sim, por inércia própria |
| Giro | 20% da inclinação | ±5°, picos de 15° | **30% da inclinação** + deriva |
| Tremor em cruzeiro | nenhum | 0,5–0,8° a 2–5 Hz | **0,3°** de partida, de banda |
| Horizonte na tela | ~46% | 33–37% | **~37%** |
| Piloto na tela | ~29% da altura | 55–76% | **~57%** |

## A proposta: a câmera `GARUPA`

### Retrato para paisagem

O vídeo é em pé e o jogo é deitado. Não dá para copiar a lente: o FOV do
Godot é vertical (`keep_aspect` padrão), e a vertical do jogo é o lado
**curto**. Os 113° verticais do vídeo, num quadro 16:9, viram uma lente de
olho de peixe.

A conta que interessa é a do **enquadramento**: piloto ocupando mais da
metade da altura, horizonte em ~35%, pneu embaixo. Com o conjunto moto +
piloto de ~1,75 m e o capacete ~0,5 m à frente do eixo traseiro:

| Parâmetro | Valor | Resultado na tela (640×360) |
| --- | --- | --- |
| Lente → contato do pneu traseiro | 1,5 m | contato em y ≈ **81%** |
| Altura da lente | 1,25 m | horizonte em y ≈ **37%** |
| Mira | contato + 0,3 m à frente + 0,85 m acima | inclina a câmera ~12,5° para baixo |
| FOV vertical | 80° | horizontal ≈ **112°** em 16:9; capacete em y ≈ **24%** |

O piloto fica com ~57% da altura e ~12% da largura: uma coluna no meio, com
**muito mundo dos dois lados**. É a vantagem do deitado sobre o vídeo, e é
por isso que a distância sobe de 1 m para 1,5 m: a um metro, com 80°, o
capacete sai pelo topo.

A conta, para quem for mexer no F3: a altura na tela de um ponto a
`frente` metros à frente da lente e `dy` acima dela é
`0,5 − tan(atan(dy / frente) + inclinação) / (2·tan(fov/2))`, com
`inclinação = atan((altura − 0,85) / (distância + 0,3))`.

### Onde mora

- **`scripts/chase_camera.gd`**: ganha `Mode.GARUPA` no enum, logo depois de
  `CHASE`, e o nome `"GARUPA"` em `mode_name()`. O `F2` passa a ciclar
  quatro modos. O `cycle_mode()` usa `% 3` fixo e precisa virar
  `% Mode.size()`.
- **`scripts/camera_garupa.gd`** (novo): `class_name CameraGarupa extends
  RefCounted`, com o estado do cinegrafista (distância, velocidade, lado,
  giro, fase do tremor) e uma função `passo(delta) -> Transform3D`. Separado
  porque é uma simulação com estado próprio, e porque fica testável sem
  câmera, sem árvore e sem tela. O `ChaseCamera` só aplica o resultado.
- **`scripts/bike_tuning.gd`**: grupo novo `"Camera garupa"`, com os sliders
  da tabela abaixo.

Nada disso mexe no `PlayerBike` nem no `World`: a câmera **lê** `speed`,
`lean`, `track_offset`, `track_lateral` e `state` do jogador, e a pista pelo
`RoadTrack.point()`. O invariante *só o jogador roda física* fica intacto: o
cinegrafista é paramétrico na curva, como o trânsito.

### O modelo: um veículo em coordenadas de pista

O cinegrafista vive em `(s, l)` da pista: `s` é o quanto andou, `l` é a
posição lateral. Igual ao trânsito, e pelo mesmo motivo: andar na curva é
grátis, e assim ele nunca sai da rua nem fura o chão.

A cada quadro:

1. **Distância (longitudinal).** O cinegrafista tem a sua velocidade `v_c`.
   Ele quer ficar a `garupa_distancia` atrás do pneu traseiro do jogador:

   ```
   folga      = (s_jogador − s_c) − garupa_distancia
   v_desejada = v_jogador + clamp(folga · 1,2, −∞, garupa_aproximacao)
   v_c       += clamp(v_desejada − v_c, −garupa_freio·dt, +garupa_acel·dt)
   s_c       += v_c · dt
   ```

   Com `garupa_acel` menor que a aceleração do jogador (10 contra 16 m/s²),
   a câmera **fica para trás no talo** e volta quando a moto estabiliza: é a
   respiração de ±15%. O `garupa_aproximacao` (2,5 m/s) faz a aproximação
   lenta da abertura do vídeo, em vez de um teletransporte. Duas travas
   rígidas: **nunca a menos de `garupa_distancia_min` (0,9 m)** — se
   precisar, freia na hora, sem a rampa —, e nunca a mais de 12 m.

2. **Lado (lateral).** O alvo lateral é `l_jogador + lado · garupa_lado`,
   com `lado` em {−1, 0, +1}. O `l_c` persegue o alvo com taxa de 3/s
   (~0,33 s): solto o bastante para a moto escorregar na tela no corredor,
   firme o bastante para o pneu não sair da faixa central.
   - **Troca de lado** a cada 6–12 s, sorteado com um RNG próprio semeado da
     semente do mundo, para ser reproduzível. Probabilidade de 2/3 para o
     outro lado e 1/3 para o centro, que dura só 2–3 s. A troca leva
     **1,2 s** com `smoothstep` no `lado`, nunca um degrau.
   - **Trava de pista:** `|l_c| ≤ RoadTrack.sidewalk_limit() − 0,4`. Se o
     lado escolhido cai fora, troca.
   - **Carro no caminho:** se um carro do trânsito vai ocupar o ponto da
     câmera (a menos de 1,2 m na lateral, entre a câmera e o jogador), troca
     de lado na hora. Se os dois lados estão ocupados, vai para o centro e
     recua 1 m. A câmera **nunca** entra numa caixa de carro: com
     `near = 0,1`, a tela viraria o interior do carro.

3. **Posição.** `RoadTrack.point(s_c, l_c)` + altura `garupa_altura` acima do
   chão **no ponto da câmera**. Na crista de uma ladeira a câmera sobe e
   desce no seu tempo, não no da moto, e a moto some e volta no horizonte.
   Isso é *feel* e é de graça.

4. **Mira.** Direto, **sem suavização**: o ponto
   `contato_traseiro + frente_da_moto · 0,3 + Vector3.UP · 0,85`, com o
   *para cima* do **mundo**, e não o da moto. É o pino do enquadramento: a
   roda fica parada na tela e o tronco tomba por cima dela. Toda a suavização
   mora na posição, nunca na mira. É o contrário do `PERSEGUICAO`, que
   suaviza as duas.

5. **FOV.** `garupa_fov` fixo. **Sem** `cam_fov_speed_gain`: no vídeo a
   velocidade vem da proximidade, e FOV abrindo a um metro do piloto faz ele
   encolher e afastar justo quando deveria pesar.

6. **Giro.** `giro_alvo = −lean_jogador · garupa_giro + deriva(t)`,
   perseguido com taxa de 2/s (reaproveita a lógica do `cam_lean_rate`, que
   já filtra o tremor do polegar). A `deriva(t)` é a soma de duas senoides
   lentas (0,23 Hz e 0,41 Hz, amplitudes 1,5° e 1°): ±2,5° de "a mão não é
   tripé". Com `max_lean = 38°` e `garupa_giro = 0,3`, o pico fica em ~11°,
   que bate com os picos de 10–15° do vídeo.

7. **Tremor.** Soma de senoides de frequências que não se repetem juntas,
   uma por banda medida, em três eixos (guinada, arfagem, giro), com fases
   diferentes por eixo:

   | Frequência | Amplitude relativa |
   | --- | --- |
   | 2,7 Hz | 1,0 |
   | 4,3 Hz | 0,8 |
   | 7,1 Hz | 0,5 |
   | 11,9 Hz | 0,3 |

   Escala total `garupa_tremor` (graus), vezes `clampf(speed / 30, 0,3, 1,3)`:
   parado quase não treme, no talo treme mais. Mais 1 cm de sobe-e-desce na
   posição, nas mesmas frequências. O `add_shake` de batida continua valendo
   por cima, sem mudança.

   **Por que 0,3° e não 0,6°:** o vídeo dura 22 s, a corrida dura minutos. A
   0,6° são 2–3 pixels de tremor contínuo, e isso cansa antes de vender. O
   valor do vídeo fica como teto do slider.

8. **Batida e queda.** Com o jogador em `State.CRASHED`, a velocidade
   desejada vai a zero, a câmera freia, para a ~4 m e mira no corpo. Na
   volta, a aproximação lenta do passo 1 refaz a abertura do vídeo sozinha.
   Na largada, a câmera nasce a 4 m e encosta nos primeiros segundos.

9. **`encaixar()`.** Precisa funcionar no modo novo: põe `s_c` e `l_c` no
   alvo, zera a velocidade relativa, tremor e deriva em zero. A prova visual
   continua comparável.

### Sliders (F3, grupo "Camera garupa")

| Slider | Partida | Faixa | Por quê |
| --- | --- | --- | --- |
| `garupa_distancia` | 1,5 m | 0,8–4,0 | Lente → pneu traseiro. 1 m no vídeo; 1,5 m porque a tela é deitada |
| `garupa_distancia_min` | 0,9 m | 0,5–2,0 | A câmera nunca entra na moto, nem freando no talo |
| `garupa_altura` | 1,25 m | 0,6–2,0 | Cintura do piloto: põe o horizonte em ~37% |
| `garupa_mira_altura` | 0,85 m | 0,4–1,4 | Banco. Mais alto sobe o piloto na tela |
| `garupa_fov` | 80° | 60–100 | Vertical. 112° na horizontal em 16:9 |
| `garupa_lado` | 0,7 m | 0,0–1,5 | Três quartos a ~21°. Zero = sempre atrás |
| `garupa_acel` | 10 m/s² | 4–30 | Menor que o do jogador: é o que faz respirar |
| `garupa_freio` | 20 m/s² | 5–40 | Menor que o do jogador: na freada a câmera encosta |
| `garupa_aproximacao` | 2,5 m/s | 0,5–10 | Velocidade máxima de fechamento |
| `garupa_giro` | 0,3 | 0,0–0,6 | Fração da inclinação no horizonte |
| `garupa_tremor` | 0,3° | 0,0–1,0 | 0,5–0,8° no vídeo |

Os valores de partida moram em `bike_tuning.gd`, com o porquê ao lado de cada
um, como os outros.

### O que não pode acontecer

- **A câmera dentro da moto, do piloto ou de um carro.** É o erro mais
  visível desta câmera, e o vídeo faz (19,6–20,3 s). Travas no passo 1 e no
  passo 2.
- **A câmera abaixo do chão.** A altura sai do chão no ponto dela, mas no
  fundo de um vale com a moto já subindo, a mira pode fazer a lente cortar o
  asfalto da frente. Trava: altura mínima de 0,5 m sobre o chão em `s_c` e
  em `s_c + 1`.
- **Ruído branco no tremor.** Ver o passo 7.
- **Mira suavizada.** O pneu passa a nadar na tela, e a câmera vira
  perseguição colada, que é outra coisa.
- **O `F2` quebrar.** Os quatro modos no ciclo e o nome certo na tela de
  configurações (`race_flow.gd` já pergunta o nome pelo `mode_name()`).

### Testes

O banco de provas **não roda câmera**, e a prova visual roda na perseguição:
**nenhum número de `baseline.json` nem de `baseline_visual.json` deve
andar.** Se andar, é bug. Os testes novos são unitários, em
`tests/unit/test_camera_garupa.gd`, contra o `CameraGarupa` sem árvore:

1. **Cruzeiro converge.** Jogador a 40 m/s constantes, em reta: depois de
   4 s a distância está em `garupa_distancia` ± 0,05 m.
2. **Freada não atravessa.** Jogador de 50 m/s a zero a 30 m/s²: a distância
   nunca fica abaixo de `garupa_distancia_min`.
3. **Aceleração afasta e volta.** Jogador acelerando no talo por 2 s: a
   distância passa de `garupa_distancia` (respira) e volta a ela em até 4 s
   depois que a velocidade estabiliza.
4. **Aproximação é lenta.** De 8 m de distância, a velocidade de fechamento
   nunca passa de `garupa_aproximacao`.
5. **O pino.** Com a câmera de verdade (`ChaseCamera` no modo novo), jogador
   inclinando ±30° a 1 Hz: `unproject_position` do contato traseiro fica em
   x = 50% ± 4% da tela o tempo todo.
6. **Troca de lado é suave.** Com o jogador parado na lateral, em nenhum
   quadro o `l_c` anda mais que `2 · garupa_lado · 1,5 / 1,2 · dt` (o pico da
   derivada do `smoothstep` numa troca de um lado ao outro), com 10% de
   folga.
7. **Tremor tem banda.** Com `garupa_tremor` = 1°, a variação entre dois
   quadros a 60 Hz nunca passa de ~0,6°. Ruído branco de mesma amplitude
   passaria.
8. **Mesma semente, mesma câmera.** Dois cinegrafistas com a mesma semente
   produzem a mesma sequência de lados.

### Ordem de entrega

Cada etapa é jogável sozinha e passa pelo portão.

1. **Geometria e inércia** (passos 1, 3, 4, 5, 9). É 70% do *feel*: perto,
   baixo, aberto, pino no pneu, respirando. Lado fixo à direita.
2. **Três quartos e troca de lado**, com as travas de pista e de carro
   (passo 2).
3. **Giro e tremor de banda** (passos 6 e 7).
4. **Borrão.** Primeiro o barato: um borrão vertical que cresce de y = 75%
   até a borda de baixo, só no modo `GARUPA` — nesta câmera o terço de baixo
   é sempre chão, e não precisa de profundidade. Depois, se a Fase 5 do
   `DIRECAO_VISUAL.md` andar, o radial com máscara serve aos dois modos.
5. **Barril, opcional.** Um passe de tela antes do `paleta.gdshader`, com
   `r_fonte = r · (1 + k·r²) / (1 + k)` (cantos parados, centro ampliado,
   retas curvando para fora), `k` entre 0,10 e 0,20. A ampliação no centro
   aumenta o piloto em `1 + k`: compensar com `garupa_fov` ou distância. Fica
   por último porque reamostra uma imagem de 640×360, e isso briga com o
   pixel (ver *Riscos*): só entra se a `prova` mostrar que não suja.

## Riscos

- **O piloto tapa a frente.** É o custo de jogo desta câmera, e o motivo do
  três quartos. Se mesmo de lado o corredor sumir atrás do piloto, as
  alavancas, nessa ordem: `garupa_lado` maior, `garupa_mira_altura` maior
  (piloto desce na tela), `garupa_distancia` maior.
- **O asfalto pisca.** A 50 m/s, o chão a meio metro da lente anda dezenas de
  pixels por quadro, e a textura `asfalto_albedo.png` com `ASFALTO_TILE =
  6,6` vai produzir *aliasing* e efeito estroboscópico na faixa de baixo. A
  etapa 4 (borrão da faixa de baixo) é o remédio. Se a etapa 1 sair antes
  dela, isso vai aparecer, e é esperado.
- **Enjoo.** Giro mais tremor mais câmera colada é a receita. Os dois
  sliders vão a zero, e o padrão de 0,3° de tremor já está abaixo do vídeo.
- **Barril e pixel.** Distorcer uma imagem de 640×360 com amostragem
  `nearest` faz pixel de tamanho irregular; com `linear`, borra antes da
  quantização. É por isso que o barril é a última etapa e é opcional. Sem
  ele, a lente é "FOV alto de jogo", e o que se perde é a curva dos postes
  na borda.
- **O sprite do futuro.** O `chase_camera.gd` abre dizendo que câmera fixa
  atrás corta ~60% do *sprite sheet* quando a arte pré-renderizada chegar.
  Três quartos a ~21° e câmera a 1,25 m de altura pedem vistas que esse
  *sheet* não teria. Enquanto o entregador for modelo 3D, isso não custa
  nada; se a arte virar sprite, o `GARUPA` é o primeiro modo a pagar.
