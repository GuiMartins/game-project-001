# Migração para 2D

Levantamento de 19/10/2026: tudo o que falta desenhar, recortar e escrever
para o jogo não ter mais nada de 3D, pista e prédios inclusive. A fila segue a
ordem de execução: primeiro o que destrava, depois o que vem do Flow.

## Por que, e o que já se decidiu

O Road Rash da referência é sprite sobre pista, e o experimento de sprite
(`AtorSprite`, `PedestreSprite`, `docs/PROTOTIPO.md`, *O entregador em
sprite*) mostrou que o sprite lê melhor que os blocos 3D. Só que hoje ele é
uma capa: o modelo 3D continua montado embaixo, lança a sombra e assume no
tombo, e o mundo em volta é malha, luz e `GPUParticles3D`.

O alvo é **pseudo-3D em `Node2D`**, projeção por segmento, como no Road Rash
e no OutRun. Isso inverte a decisão "Mundo 3D real, não pseudo-3D por
scanlines" do `PROTOTIPO.md`. Curva e ladeira continuam de graça, porque o
projetor por segmento também as faz. O que se perde é a geometria livre:
tudo o que aparece na tela precisa estar desenhado no ângulo em que aparece.

Decisões tomadas com o Guilherme:

| Pergunta | Resposta | O que isso custa |
| --- | --- | --- |
| Até onde vai o 2D? | Tudo, até pista e prédios | Renderizador novo; prédio vira textura de parede |
| De onde sai a arte? | Toda do Flow, com referência gerada pelos modelos 3D | Os `.blend` ficam em `arte/` até a última folha |
| Quais câmeras ficam? | Perseguição, capacete e garupa | A garupa vê a moto de 3/4: três ângulos em vez de um |
| Que feel vira quadro? | Tombo e piloto voando, porta abrindo, pé no chão e guidão, golpe recebido | Os blocos maiores da moto e do carro |
| As três motos têm desenho próprio? | Sim: CG, XRE e PCX | O atlas do piloto triplica |

## Convenções de toda folha

- **Linhas de ângulo** são as do pedestre: frente, 3/4 frente, lado, 3/4
  costas e costas. O lado esquerdo sai por espelho. O ônibus é a exceção: a
  porta é só do lado direito, e espelhado ela trocaria de lado.
- **Cor por cor-chave.** O prompt pede a parte que muda de cor numa cor
  pura, e o shader recolore, como já faz o vermelho da bag
  (`sprite.gdshaderinc`). Sem isso seriam nove folhas por carro, uma por
  pintura, e o Flow não desenha o mesmo carro nove vezes igual.
- **Luz não é desenho.** Lanterna, freio, seta, farol, janela, lente de poste
  e painel de mupi são coordenadas no `.json` da folha, e o shader acende o
  brilho por cima. Uma camada de luz pedida ao Flow nunca cai no mesmo pixel
  da folha de base. Na fachada o vidro vem em ciano puro, e o recorte acha as
  janelas pela cor.
- **Âncora e escala no `.json`**: o ponto do pé (ou da base) e
  `pixels_por_metro`, como o `sprites_pedestres.gd` já grava. Sem medida
  comum o sprite muda de tamanho na troca de folha, que é o S03 a S05 da
  [auditoria](AUDITORIA_SPRITES.md).
- **Grade dita no prompt** (linhas × colunas), e o recorte reprova folha com
  grade errada. Foi assim que a leva de 18/10 pegou as seis folhas tortas.

## Fila

**"Faz a próxima tarefa" = o primeiro item `[ ]` desta fila**, de cima para
baixo (👤 pergunta ao Guilherme antes). Desde 23/10/2026 ela substitui a
`BACKLOG_VISUAL.md` nessa função. Ao fechar, marca `[x]` com data e PR no
mesmo PR da tarefa, com uma linha de resultado. A V27 (o veredito) espera a
2D93.

### Ferramenta

- [x] **2D01** — **Referência para qualquer modelo.** O `dev.py boneco` só
  posa o `Pessoa`. Generalizar para a moto (três ângulos, cada pose da
  tabela), o carro (modelo × ângulo × porta), o prop (um ângulo) e a fachada
  (ortográfica, de frente e de lado), em manequim cinza sobre verde,
  determinístico como a S01. (22/10/2026: `dev.py boneco [moto|carro|prop|
  fachada|tudo]`, todos pela bancada `arte/boneco_cena.gd`; a da pessoa saiu
  byte a byte igual. Cada folha sai com um `.json` do lado, com grade, célula,
  `pixels_por_metro` e o ponto do pé, que é o que o 2D02 vai ler. A
  "empinada" do 2D10 é a moto inteira girada 30° em volta do pneu de trás: o
  modelo 3D não tem empinada, só o sprite. Hatch, SUV, baú e van não têm
  passageiro no modelo e saem com uma coluna na base; o ônibus ganha as duas
  linhas do lado da porta e, nas folhas, só os quadros de abertura.)
- [x] **2D02** — **Um recorte para todas as folhas.** Juntar o
  `sprites_flow.gd` e o `sprites_pedestres.gd` num recorte guiado por ficha:
  grade, âncora, `pixels_por_metro`, espelho, cor-chave e coordenadas de luz.
  Folha nova entra com uma ficha, e não com um script.
  (22/10/2026: `arte/recorte_de_folha.gd` é a única cópia de tirar o verde,
  achar os desenhos pelos vãos, escalar, ancorar e colar com borda dura;
  `sprites_flow.gd` e `sprites_pedestres.gd` chamam a biblioteca e saem
  byte a byte iguais. `dev.py recortar [nome]` recorta pela ficha em
  `arte/flow/fichas/` (campos no README de lá) e repassa as luzes ao `.json` do
  atlas. Ficam à parte o corte dos props, que usa outro fundo e uma imagem por
  prop, e as regras próprias do piloto e do pedestre.)
- [x] **2D03** — **Um shader de sprite.** Recolorir pela cor-chave, acender as
  luzes da ficha com a hora (`noite`) e escolher a linha de ângulo pela
  guinada em relação à câmera. Hoje isso está repartido entre
  `ator_sprite.gdshaderinc` e `pedestre_sprite.gdshader`.
  (23/10/2026: `scripts/sprite.gdshader` (e `sprite_foco.gdshader`, com o
  stencil do foco) substitui os quatro; o piloto é `angulos = 4`, uma linha só,
  com `recolore`, e a pessoa e a multidão seguem como eram. Uma cena de teste
  com piloto e pessoas de dia e de noite sai byte a byte igual à de antes. As
  luzes são `SpriteLuzes`: a ficha diz o ponto, o raio e a cor, o shader acende
  o brilho por cima, e só o freio acende de dia. Provado numa folha de teste,
  de dia e de noite. A lente do poste (2D50) já está na ficha dele; ligar o
  poste em sprite no mundo é outro passo.)
- [x] **2D04** — **O testador vê tudo.** `CatalogoSprites.Tipo` ganha carro,
  prop e fachada, e a análise mede pé, altura e ângulo deles como já mede os
  da moto e do pedestre.
  (23/10/2026: o catálogo varre também `assets/sprites/carros`, `props` e
  `fachadas` (pasta que ainda não existe não atrapalha). Carro e fachada leem a
  ficha de grade do recorte; o prop lê `tamanho` e `angulo`. Cada um é medido
  em pé constante por linha, altura desenhada contra `altura_m × px/m` (10%) e
  rótulo de ângulo conhecido. O prop não acusa "encosta na borda", porque a
  célula dele é a caixa do desenho. Os seis props de hoje passam limpos; carro
  e fachada ficaram provados com folha sintética, já que ainda não há arte. A
  cena do testador mostra os três parados, na escala da ficha, com o pé no
  chão.)
- [ ] **2D05** 👤 — **Prova do projetor antes da arte.** Um pseudo-3D mínimo
  com a pista atual (curva e rampa do `RoadTrack` como dado), o asfalto e a
  calçada que já existem, e os sprites que já existem (CG e as cinco
  pessoas). São umas 80 gerações no Flow pela frente: a pergunta "o
  pseudo-3D está gostoso?" precisa de resposta antes delas.
  **Prova pronta (23/10/2026), falta o veredito do Guilherme**: `dev.py
  projetor` abre a pista de verdade (`RoadTrack`, semente 20260831) projetada
  por segmento (`ProjetorPista`, `TelaProjetor`): asfalto e calçada em
  perspectiva certa, linha a linha; faixas pintadas por código; fachadas como
  quadriláteros; poste, copa, palmeira, as pessoas e a CG (a curva escolhe o
  quadro). Setas pilotam, `--auto` pilota sozinho, `--captura` tira foto.
  O ganho da curva (`GANHO_CURVA`, 0,35) é o botão que mais muda o feel:
  contada inteira, a pista de 0,6°/m dobra sobre si mesma. Conhecido e
  deixado de fora: sem trânsito, colisão, luz de noite, borrão nem som; o
  asfalto não tem mipmap e cintila de longe. Só vira `[x]` quando ele jogar
  e disser que sim (ou não).

### Moto e piloto

Três linhas de ângulo (costas, 3/4 costas, lado), espelhadas. Uma ficha por
moto: `cg`, `xre`, `pcx`.

| Folha | Quadros por linha | Por moto |
| --- | --- | --- |
| Pilotando: inclinação −28°, −11°, 0°, 11°, 28° | 5 | 15 |
| Parado e lento: pé no chão, guidão esquerda, guidão direita, no ar | 4 | 12 |
| Combate: soco, 3 quadros × 2 lados | 6 | 18 |
| Golpe recebido: 2 quadros × 2 lados | 4 | 12 |
| Tombo: a moto deitando (só de costas) | 4 | 4 |
| Moto caída no chão, sem piloto, girando (5 linhas × 1) | 1 | 5 |

- [x] **2D10** — CG: pilotando e parado (uma folha, 3 × 9).
  (23/10/2026: saíram **duas** folhas, `cg_pilotando` (3 × 5) e `cg_parado`
  (3 × 4), em `assets/sprites/moto/`, porque o recorte lê uma fonte por ficha e
  o Flow erra mais a conta com 9 colunas do que com 4 ou 5; as duas fichas
  são irmãs, na mesma celula (270 × 240, 100 px/m, chão em y = 220). Cada uma
  saiu de uma geração e passou o recorte de primeira; a de parado precisou de
  uma edição para a moto sair escura como a outra (a primeira veio
  vermelha). Receita e prompts em `arte/flow/referencia/README.md`, *Moto*.
  O catálogo as vê como `MOTO_FOLHA`, sem aviso.)
- [x] **2D11** — CG: combate e golpe (uma folha, 3 × 10).
  (23/10/2026: de novo duas folhas, `cg_combate` (3 × 6) e `cg_golpe` (3 × 4),
  em `assets/sprites/moto/`, pelo mesmo motivo da 2D10. A de combate precisou
  de uma segunda geração: na primeira o Flow copiou as 5 colunas da folha que
  eu dei de identidade e entregou 3 × 5. Trocando a identidade pelo
  turnaround, e com "SIX columns (not five)" no prompt, veio 3 × 6. O recorte
  precisou de `vao` 8 (e não 24), porque as motos de lado se encostam. O golpe
  recebido é sutil, como na referência 3D: o piloto recua e vira a cabeça, e
  a diferença entre os quadros de cada lado é pequena. Julgar no jogo.)
- [ ] **2D12** — CG: tombo e caída (uma folha, 9 quadros).
- [ ] **2D13** — XRE: as três folhas do 2D10 a 2D12.
- [ ] **2D14** — PCX: as três folhas. Na scooter o pé no chão sai do
  assoalho, e não da pedaleira.
- [ ] **2D15** — **O piloto solto**, igual nas três motos: voando (4 × 8) e
  caído (4 × 3), como as folhas do pedestre.
- [ ] **2D16** — **Placa por código.** O texto Mercosul de cada moto
  (`placa.gd`) desenhado sobre um retângulo da ficha, e não na folha.

Fica fora do desenho, por ser deslocamento ou rotação do sprite inteiro ou
por não aparecer a 640×360: roda girando e roda borrada, mola, garfo e
balança, joelho e cabeça seguindo a curva, manete e pedal.

Total: cerca de 245 quadros em 11 folhas.

### Carros

Cinco linhas de ângulo, espelhadas. O ônibus ganha mais duas, lado e 3/4 do
lado da porta, e não espelha. Pintura por cor-chave, menos o táxi, que é
sempre amarelo.

| Modelo | Portas de um lado | Base (com e sem passageiro) | Portas (4 abrindo + amassada, em 3 ângulos) |
| --- | --- | --- | --- |
| Hatch | 1 | 10 | 15 |
| Sedã | 2 | 10 | 30 |
| SUV | 2 | 10 | 30 |
| Táxi | 2 | 10 | 30 |
| Ônibus | 2 folhas dobráveis, à direita | 14 | 30 |
| Baú | 1 | 10 | 15 |
| Van | 1 | 10 | 15 |

- [ ] **2D20** — Hatch: base e portas.
- [ ] **2D21** — Sedã.
- [ ] **2D22** — SUV.
- [ ] **2D23** — Táxi, com o luminoso aceso por coordenada.
- [ ] **2D24** — Ônibus, com o letreiro por coordenada.
- [ ] **2D25** — Baú.
- [ ] **2D26** — Van.
- [ ] **2D27** — **Luzes do carro na ficha**: lanterna, freio, seta esquerda
  e seta direita nos ângulos de costas, e farol nos de frente. O pisca-alerta
  são as duas setas.

Fica fora do desenho: a carroceria mergulhando e rolando (rotação e
deslocamento do sprite), a guinada de até 8° (fica no ângulo mais perto), o
esterço e o motorista olhando o retrovisor.

Total: cerca de 240 quadros em 10 a 14 folhas.

### Gente

As 25 folhas de hoje (cinco pessoas × andando, susto, desembarcando, voando e
caída) ficam.

- [ ] **2D30** — **Torcida da chegada acenando**: cinco pessoas × frente,
  3/4 frente e lado × 6 quadros. Hoje a `Chegada` força o 3D
  (`usar_sprite` é `false`).
- [ ] **2D31** — **Fiscal da bandeira**, com a quadriculada no desenho:
  3 × 8. A bandeira que ondula no shader (`bandeira.gdshader`) sai.
- [ ] **2D32** — **Fiscal da largada**, pessoa nova de colete laranja
  (`fiscal.glb`): o gesto de largada, andando, susto, voando e caída. Hoje
  ela é 3D durante o gesto e vira a pessoa da praia depois.
- [ ] **2D33** *(opcional)* — Parada, o balanço de quem espera: 5 × 4 por
  pessoa. A referência já existe (`arte/flow/referencia/parada.png`); hoje
  quem espera usa o primeiro quadro do andar.
- [ ] **2D34** *(opcional, V19a)* — Mais cinco pessoas. Mais de mil na
  calçada com cinco caras é o que mais vai aparecer como repetição.

Total obrigatório: cerca de 245 quadros em 11 folhas.

### Cenário

Prédio vira parede: um quad por segmento, com a fachada repetida na
horizontal, e não um sprite que gira.

- [ ] **2D40** — **Fachadas**: sobrado, comércio, deco, escritório e torre
  (`Predio.Tipo`), cada uma de frente e com a empena lateral, que é o que
  aparece na esquina. São 10 imagens, com o vidro em ciano para a janela
  acender de noite e parede, loja e tela em cor-chave.
- [ ] **2D41** — **Obra** (`Predio.Obra`): esqueleto e fachada, laranja e
  azul, de frente e de lado. São 8 imagens.
- [ ] **2D42** — **Guindaste**, uma ou duas alturas.
- [ ] **2D43** — **Fundo urbano**: duas faixas de skyline emendáveis, para o
  parallax que substitui a segunda fileira de prédios.
- [ ] **2D44** — **Marcos** (`marcos.gd`): igreja no morro, museu, torre de
  igreja e roda-gigante, com a roda à parte para girar. São 5 imagens.
- [ ] **2D45** — **O fundo da rua transversal**: a rua recuando entre
  fachadas, para o vão da esquina. Duas variações.
- [ ] **2D46** — **Via expressa**: o pilar do viaduto. Muro, mureta e
  alambrado já têm textura (`assets/via_expressa/`) e viram parede.
- [ ] **2D47** — **Canteiro da praça.**

Pista, calçada e asfalto já existem (`assets/visual/`). Pintura, zebra,
meio-fio, faixa de serviço e o tabuleiro do viaduto são polígono desenhado
por código, sem arte.

### Props

Um ângulo só, de 3/4 de frente para quem vem, como no Road Rash. Quando um
prop quebra e voa, quem gira é o sprite inteiro.

- [x] **2D50** — Poste, com a lente acesa por coordenada. (22/10/2026: sprite em
  `assets/sprites/props/poste.png`, lente apagada; a coordenada da lente para o
  shader entrou com o 2D03, em `poste.json`.)
- [x] **2D51** — Árvore de copa e palmeira, com uma variação de cada. (22/10/2026:
  uma de cada, em `assets/sprites/props/`; a segunda variação fica para depois.)
- [ ] **2D52** — Caçamba e mupi, com o painel do mupi aceso por coordenada.
- [x] **2D53** — Placas: curva à esquerda, curva à direita (espelho), mão dupla.
  (22/10/2026, receita em `arte/flow/props/README.md`.)
- [ ] **2D54** — Semáforo de esquina, vermelho e verde por coordenada.
- [ ] **2D55** — Pórticos: semáforo suspenso, placa de destino (sem texto,
  que sai por código) e mão dupla.
- [ ] **2D56** — Chegada: o arco "CHEGADA" e a barreira.

Total de cenário e props: cerca de 46 imagens soltas.

### Efeitos, sem arte nova

- [ ] **2D60** — Faísca, poeira, fumaça de pneu, fogo e estalo do soco em
  `CPUParticles2D`, com os flipbooks que já são gerados em código
  (`Derrapagem.nuvem`).
- [ ] **2D61** — No chão da pista, como polígono do projetor: marca de pneu,
  sangue, poça de luz do poste e cone do farol. Hoje são `Decal` e
  `SpotLight3D`.
- [ ] **2D62** — Sombra: uma elipse sob cada ator. Hoje é o modelo 3D
  escondido que a projeta.
- [ ] **2D63** — Céu (`ceu.gdshader`) em `canvas_item`. LUT, neblina e
  tonemap saem do `Environment` e vão para o `paleta.gdshader` e para um
  tingimento por distância.
- [ ] **2D64** — Borrão de velocidade sem `depth`: a moto escapa do borrão
  pela ordem de desenho, e não pelo stencil.

### Remoção

- [ ] **2D90** 👤 — **Contrato.** Os invariantes do `CLAUDE.md` que deixam
  de existir (winding, `CharacterBody3D` contra trimesh, `SubViewport` em
  3D) e o `PROTOTIPO.md` reescritos. Mudar o contrato pede aval à parte.
- [ ] **2D91** — **Física em espaço de pista.** `CharacterBody3D`,
  `AnimatableBody3D` e o `Area3D` do soco viram sobreposição em (offset,
  lateral); colisor de prédio, poste e porta, idem; o `Quebravel` voa em
  espaço de pista. O `baseline.json` anda (batida, calçada, combate), com o
  porquê no commit.
- [ ] **2D92** — **Tirar os `.glb` e o `Entregador` 3D do jogo.** Os testes
  que dependem de modelo (perto de 30) são reescritos ou saem, e os
  `baseline_visual*.json` são refeitos.
- [ ] **2D93** — **Apagar os `.blend` e os geradores de `arte/`**, só depois
  da última folha: são eles que geram a referência que vai ao Flow.

## O total

| Bloco | Gerações no Flow | Quadros |
| --- | --- | --- |
| Moto e piloto | 11 folhas | ~245 |
| Carros | 10 a 14 folhas | ~240 |
| Gente, obrigatório | 11 folhas | ~245 |
| Cenário e props | ~46 imagens | ~46 |
| **Obrigatório** | **~80** | **~775** |
| Gente, opcional | +30 folhas | +750 |

A conta não inclui as refações: na leva de 18/10, seis de 25 folhas voltaram
ao Flow pelo menos uma vez.
