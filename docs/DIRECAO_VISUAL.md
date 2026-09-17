# Direção visual

Como sair do greybox e chegar no look das referências: Road Rash com sprites
digitalizados, mas com a iluminação, a sombra e as partículas que 1994 não
tinha.

Este documento é **estudo de direcionamento**, não plano aprovado. Ele responde
três perguntas — *dá pra fazer no Godot?*, *como?*, *o que isso quebra?* — e
deixa cada decisão com o número que a sustenta, para que quem for implementar
(pessoa ou IA) não precise redescobrir a conta.

Tudo o que ele afirma sobre a engine foi **verificado rodando o Godot 4.7.2**,
a versão fixada em `.godot-version`. O apêndice A lista o que foi conferido e
como. Onde não deu pra confirmar, está escrito *a confirmar* e com o teste que
confirma.

Pré-requisito de leitura: [PROTOTIPO.md](PROTOTIPO.md), especialmente a seção
"O que **não** está aqui" — este documento é a continuação dela, e corrige uma
das suas premissas.

## O que as referências são, e o que elas não são

As quatro imagens são **quadros gerados por IA a partir de base fotográfica**,
não capturas de jogo. Isso não as desqualifica como referência — elas
comunicam a intenção melhor que qualquer texto — mas três coisas nelas não são
transponíveis, e confundir alvo com referência é o jeito mais rápido de gastar
seis meses perseguindo o impossível:

- **O fundo é foto, não geometria.** Cada prédio, cada mural, cada pessoa na
  calçada tem detalhe por pixel porque *é* uma foto. Em tempo real isso é
  geometria, textura e orçamento de draw call. O que dá pra igualar é a
  **densidade percebida** — quanta coisa entra no quadro — não o detalhe.
- **O borrão é pintado.** Nas imagens ele é perfeito: forte na periferia, zero
  no piloto, coerente com a direção de cada objeto. Em tempo real isso é um
  passe de pós-processamento com custo e com artefato. Dá pra chegar perto.
  Idêntico, não.
- **Nenhuma delas precisa do quadro seguinte.** Uma imagem estática pode ter
  ruído, dithering e serrilhado arbitrários. Num jogo a 60 Hz, qualquer coisa
  que não seja estável entre quadros vira cintilação — e cintilação é o modo
  de falha nº 1 de pixel art em 3D. Metade das decisões deste documento existe
  por causa disso.

E uma observação de escopo que o contrato já cobre: a imagem 4 tem **logo de
app real** na bag. Está fora. `PROTOTIPO.md` fecha com "nada de nome, logo ou
cor exata de app real", e a referência não muda isso — o que se copia dela é o
enquadramento e a leitura, não a marca.

## Os nove pilares do look

Leitura das imagens, cada uma traduzida para o que ela é tecnicamente. A coluna
"estado" diz o que o protótipo já tem.

| # | O que a imagem faz | O que é, tecnicamente | Estado |
| --- | --- | --- | --- |
| 1 | Câmera baixa, atrás, piloto centralizado ocupando ~⅓ da altura | Perseguição por posição com atraso, FOV que abre com a velocidade | **já existe** (`chase_camera.gd`) |
| 2 | Piloto e moto lidos como foto, não como desenho | Sprite digitalizado: fonte fotográfica ou renderizada offline, quantizada, com borda dura | falta |
| 3 | Sol duro, céu azul saturado, sombra de contato sob cada veículo | Uma `DirectionalLight3D` com sombra ligada + ambiente vindo do céu | sol existe, **sombra desligada** |
| 4 | Periferia borrada, faixas da pista esticadas em risco | Borrão radial em pós-processamento, mascarado por profundidade | falta |
| 5 | Fumaça, faísca, poeira, fogo | `GPUParticles3D` com flipbook e escala de tempo travada | falta |
| 6 | Nuvens com bandas e dithering visíveis | Céu procedural com textura de cobertura + debanding desligado de propósito | falta (fundo é cor chapada) |
| 7 | HUD gorda, com contorno, barras segmentadas em degradê | Fonte bitmap + `ColorRect`s dentro do mesmo SubViewport | existe, mas magra e sem estilo |
| 8 | Cor alta, contraste alto, paleta coerente entre tudo | LUT de correção de cor no `Environment` | falta |
| 9 | Placa verde, mural, ônibus, palmeira, contêiner — leitura de Rio | Conteúdo, não tecnologia | falta |

Os pilares 2, 3 e 4 são os que **decidem** se a imagem lê como a referência.
Os outros polem. Se for preciso escolher, é nessa ordem.

## A pergunta que decide tudo: resolução

Este é o ponto onde o estudo bate de frente com um número do contrato, e é
melhor bater cedo.

**320×180 não cabe um sprite digitalizado.** Não é opinião, é aritmética. A
câmera do projeto está a 6,55 m da moto com FOV entre 50° (parado) e 66° (no
talo). Com a moto+piloto medindo 1,75 m de altura:

| resolução interna | moto parada | moto no talo | rival a 25 m |
| --- | --- | --- | --- |
| **320×180** (hoje) | 52 px | 37 px | 14 px |
| 480×270 | 77 px | 56 px | 20 px |
| **640×360** | 103 px | 74 px | 27 px |
| 960×540 | 155 px | 111 px | 41 px |

A 37 px de altura, o piloto tem uns 12 px de tronco. Não cabe a dobra da
jaqueta, não cabe o capacete separado da cabeça, não cabe a alça da bag — e
essas três coisas são exatamente o que faz um sprite ler como *foto* em vez de
como *boneco*. A 320×180 o caminho honesto seria pixel art desenhada à mão, que
é um look legítimo e **não é o que as referências pedem**.

Na casa dos 100 px o sprite tem detalhe suficiente para o olho classificar a
fonte como fotográfica. É a faixa em que os digitalizados clássicos operavam, e
é o que 640×360 entrega.

### Por que 640×360 e não 480×270 ou 960×540

Porque o upscale precisa ser inteiro, e não é só o `stretch_shrink` que conta.
A escala total é `stretch_shrink` × a escala do `canvas_items` da janela. Medido
contra o viewport de projeto de 1280×720:

| base | janela 1280 | 1600 | 1920 | 2560 | 3840 |
| --- | --- | --- | --- | --- | --- |
| 320×180 | 4× | 5× | 6× | 8× | 12× |
| 480×270 | 2,67× | 3,33× | 4× | 5,33× | 8× |
| **640×360** | **2×** | 2,5× | **3×** | **4×** | **6×** |
| 960×540 | 1,33× | 1,67× | 2× | 2,67× | 4× |

480×270 e 960×540 são fracionários nas resoluções mais comuns — pixel de
tamanhos diferentes na mesma tela, que é o defeito que o comentário de
`main.gd` já nomeia. 640×360 só perde 1600×900.

**E 1600×900 tem conserto:** `display/window/stretch/scale_mode` existe no
Godot 4.7 e hoje está em `fractional`. Em `integer` a engine força escala
inteira e põe tarja preta na sobra. A troca é barra preta em janela de tamanho
esquisito contra pixel irregular — e num jogo cujo ponto é o pixel, a barra
ganha.

**Custo de GPU:** 640×360 são 230.400 pixels contra 57.600. Quatro vezes mais
fragmentos. Em qualquer GPU dos últimos dez anos isso é irrelevante no
orçamento. **No CI não é** — ver a seção de riscos.

### Recomendação

**640×360, com `scale_mode = integer`.** Sem isso, o pilar 2 não fecha, e sem o
pilar 2 não existe "look de digitalizado", existe "greybox com sombra".

O que muda em código está listado na seção "O que isto mexe no contrato".

## Sprite digitalizado: as três rotas

"Digitalizado" não é um arquivo, é uma **procedência**. O que faz um sprite do
Mortal Kombat parecer digitalizado não é a resolução — é o fato de o valor e a
cor virem de uma fonte de alta fidelidade (foto, no caso dele; render offline,
no caso do Road Rash do 3DO e do Donkey Kong Country) e depois serem
achatados numa paleta pequena, com a borda **sem antialiasing**.

Cinco propriedades produzem o efeito. Vale listá-las porque qualquer uma das
três rotas abaixo precisa entregar as cinco:

1. **Fonte de alta fidelidade.** Muitas cores próximas, brilho especular real,
   dobra de tecido real.
2. **Quantização a uma paleta pequena.** É o passo que cria a "cara de época".
3. **Borda dura.** Silhueta sem meio-tom. Um pixel é do personagem ou é do
   fundo.
4. **Iluminação embutida.** O sprite traz a própria luz — e é exatamente daí
   que vem o descasamento clássico com a cena. Como consertar isso é o assunto
   da seção de iluminação.
5. **Cadência baixa.** Animação em 10–12 quadros por segundo. Sprite
   digitalizado a 60 fps deixa de ler como sprite e passa a ler como 3D — a
   trepidação **é** o look.

### As rotas

| | A. Folha pré-renderizada | B. 3D em tempo real + shader "digitalizador" | C. Híbrido |
| --- | --- | --- | --- |
| Como | Blender renderiza N ângulos × N poses, vira atlas | Modelo low-poly na cena, pós-processo quantiza e endurece a borda | 3D para os atores, sprite para o cenário |
| Teto de qualidade | O do renderizador offline: ray tracing, subsurface, o que quiser | O do Forward+ em 640×360 | os dois |
| Luz dinâmica no ator | Só com normal map junto (ver abaixo) | De graça e correta | de graça nos atores |
| Ângulos | Matriz de quadros; ângulo intermediário não existe | Qualquer ângulo | qualquer ângulo |
| Iterar no visual | Re-render do lote inteiro | Instantâneo | instantâneo no ator |
| Custo por quadro | Quase zero | Contagem de triângulo + passe de pós | médio |
| VRAM | Alta (ver conta) | Baixa | média |
| Risco principal | Matriz explodir; descasamento de luz | Ler como "3D com filtro" em vez de digitalizado | duas linhas de produção |

**Recomendação: C, com os atores na rota B.**

O raciocínio, e ele é contraintuitivo o bastante para merecer estar escrito: a
rota A é a *autêntica*, mas o que a torna autêntica — luz congelada no quadro,
ângulos discretos — é precisamente o que briga com o que o pedido tem de
moderno. Sombra dinâmica, fogo que ilumina o piloto, faísca refletida na
lataria: nada disso alcança um sprite pré-renderizado sem trabalho extra
considerável.

A rota B entrega as cinco propriedades se — e só se — o pós-processamento for
feito com disciplina:

- **Fonte de alta fidelidade** vem do próprio Forward+: sombra, oclusão,
  especular. Em 640×360 é fidelidade de sobra.
- **Quantização** vem do LUT em `Environment.adjustment_color_correction` mais
  um passe final de dither ordenado.
- **Borda dura** vem de MSAA desligado (já está) e de nenhum filtro linear no
  upscale (já está).
- **Iluminação embutida** deixa de ser necessária, porque a luz é real.
- **Cadência baixa** vem de travar a animação do ator em 12 fps, mesmo com a
  física a 60 Hz. Este é o item que quase sempre é esquecido e é o que mais
  entrega o look.

A rota A continua sendo a certa para o que é **numeroso e estático**: pedestre
na calçada, palmeira, placa, poste, contêiner. Centenas de instâncias, sempre
vistas de longe, nenhuma precisando de luz dinâmica. `MultiMeshInstance3D` com
quads billboard resolve isso num draw call.

### Se a rota A for escolhida para os atores mesmo assim

É uma decisão defensável — é o caminho mais fiel, e o teto de qualidade da
arte é maior. Nesse caso a matriz precisa ser dimensionada antes de o primeiro
quadro ser renderizado, porque ela é o que decide se o pipeline é viável:

- **Guinada relativa à câmera:** a câmera vive atrás, então não são 360°. Com
  `cam_follow = 7.0` e a moto guinando até 35,8 °/s, o atraso da câmera fica
  na casa de 5°; rival cortando na frente em `OVERTAKE` abre mais. **±60° em
  passos de 15° = 9 ângulos, 5 renderizados** (o resto é espelho).
- **Inclinação:** 5 passos (0, ±20°, ±40°), **3 renderizados**.
- **Base andando reto:** 5 × 3 = **15 poses**.
- **Estados:** empinando, socando esquerda, socando direita, cambaleando,
  caindo, no chão. Com 3 a 6 quadros cada, ~20 quadros × 5 guinadas = **100**.
- **Total: ~150 quadros por rig.**

A 160×160 px por quadro, um atlas de 4096×4096 cabe **625 quadros** — o rig
inteiro sobra numa folha. Com o canal de normal, duas folhas. Em RGBA8 sem
compressão são ~67 MB; com compressão VRAM, uma fração disso.

Os cinco rivais **não** multiplicam nada: `world.gd` já declara "mesmo rig,
paleta trocada" em `RIVAL_COLORS`. Basta renderizar um passe de máscara
(bag no vermelho, jaqueta no verde, moto no azul) e trocar a cor no shader.

### Correção a uma premissa do PROTOTIPO.md

`PROTOTIPO.md` diz hoje:

> Quando entrarem, entram como `Sprite3D` com `billboard = Y-Billboard`,
> `texture_filter = Nearest` e `alpha_cut = Discard` em todos.

As três propriedades estão certas e continuam valendo. O **nó** está errado
para o que este documento pede, e a razão é concreta: `Sprite3D` não expõe
normal map. Verificado — `BaseMaterial3D` tem `normal_enabled` e
`normal_texture`, mas o material interno do `Sprite3D` não os alcança, e
`material_override` num `Sprite3D` desmonta o tratamento de quadro do próprio
nó.

O veículo correto é **`MeshInstance3D` + `QuadMesh` + `StandardMaterial3D`**,
com `billboard_mode = BILLBOARD_FIXED_Y`, `transparency =
TRANSPARENCY_ALPHA_SCISSOR`, `texture_filter = NEAREST_WITH_MIPMAPS`, e o
quadro do atlas escolhido por `uv1_scale` / `uv1_offset`. Tudo verificado como
existente. Isso dá normal map, controle de sombra por `cast_shadow` e shader
próprio quando precisar — as três coisas que o `Sprite3D` nega.

**`NEAREST_WITH_MIPMAPS`, e não `NEAREST` puro.** O sprite é desenhado para
~100 px na distância nominal, mas um rival a 70 m ocupa 10 px: uma minificação
de 10×. Amostragem nearest sem mipmap nessa razão é cintilação garantida a
cada quadro, e cintilação é o que denuncia pixel art falsa. O mipmap custa um
pouco de nitidez ao longe, onde ninguém está olhando.

## O pipeline de produção do sprite

Só vale para a rota A (e para o cenário da rota C). Registrado porque a
reprodutibilidade dele é o que decide se a arte é versionável ou vira pasta de
PNG que ninguém sabe regerar.

**O princípio: o `.blend` é a fonte, o PNG é build.** Do mesmo jeito que
`tests/baseline.json` é gerado e revisado, não digitado.

```
arte/
  rigs/entregador.blend        <- fonte, versionada (LFS)
  render.py                    <- script Blender: varre a matriz, salva EXR
  paleta.png                   <- a paleta alvo, versionada
tools/dev.py sprites           <- novo comando: render + empacota + importa
assets/sprites/*.png           <- build. Versionado? ver abaixo.
```

Quatro requisitos que o script de render precisa cumprir, e cada um já custou
caro em algum projeto:

1. **Câmera ortográfica e distância fixa.** Perspectiva no render offline
   briga com a perspectiva da cena em tempo real, e o sprite "incha" ao virar.
2. **A luz-chave do render tem que ser a mesma do jogo.** O sol do
   `world.gd` está em `rotation_degrees = (-42, 38, 0)`. Render com outra
   direção de luz produz o descasamento clássico — o sprite iluminado da
   esquerda numa cena iluminada da direita.
3. **Sai mais de um canal.** Albedo, normal (em espaço de tela) e máscara de
   paleta, do mesmo lote, com o mesmo enquadramento. São três renders, não um.
4. **Determinismo.** Semente fixa, sem denoiser adaptativo, sem sampling
   variável. Mesma entrada, mesmo PNG — senão todo re-render vira diff de
   arquivo inteiro e a revisão morre.

**Versionar o PNG?** Recomendação: **sim, em Git LFS**, apesar de ser build. A
razão é o CI: a regressão visual precisa dos sprites para rodar, e fazer o CI
executar Blender a cada push é trocar 90 s por dezenas de minutos.

Isso já está pronto e ninguém percebeu: o `.gitattributes` deste repositório já
roteia `*.png`, `*.exr` e `*.blend` por LFS. A infraestrutura da arte foi
montada antes da arte.

## Iluminação

O que existe hoje em `world.gd::_build_environment` é o mínimo para enxergar
caixa: fundo de cor chapada, ambiente de cor chapada, um sol **sem sombra**,
neblina exponencial segurando o horizonte.

O que as referências pedem é uma coisa só, repetida: **um sol duro, e o resto
é consequência dele.** Céu azul saturado devolvendo luz fria na sombra,
asfalto quente no sol, sombra de contato preta e curta sob cada veículo. Não é
uma cena complexa de iluminação — é uma cena de meio-dia, que é o caso mais
fácil que existe.

### O que ligar, em ordem de retorno

| Ordem | O quê | Onde | Por que primeiro |
| --- | --- | --- | --- |
| 1 | Sombra do sol | `DirectionalLight3D.shadow_enabled` | É o pilar 3 inteiro. Sem sombra de contato, todo veículo flutua |
| 2 | Ambiente vindo do céu | `Environment.ambient_light_source = AMBIENT_SOURCE_SKY` | A sombra fica azul em vez de cinza, e é isso que faz a cena ler como "sol do Rio" |
| 3 | Tonemap + LUT | `tonemap_mode`, `adjustment_color_correction` | É o passo que cria a paleta, e paleta é metade do look |
| 4 | Glow | `glow_enabled`, `glow_hdr_threshold` | Faísca, farol, placa refletindo. Sem glow a faísca é um pixel laranja |
| 5 | SSAO | `ssao_enabled` | Escurece o encontro do pneu com o chão. Sutil, e o primeiro a cortar se o orçamento apertar |
| 6 | Neblina aérea | `fog_aerial_perspective`, `fog_sun_scatter` | Dá profundidade ao fundo sem custo de geometria |

Todas verificadas como existentes no 4.7.2 (apêndice A).

### O que **não** ligar, e por quê

Esta lista importa tanto quanto a de cima, porque são as opções que parecem
óbvias e custam caro:

- **SDFGI.** É iluminação global para cena majoritariamente estática. Nossa
  pista tem 3,2 km, o trânsito é reciclado em volta do jogador e o cenário é
  gerado por sorteio. SDFGI passaria a corrida inteira revalidando cascatas.
  O ganho — bounce indireto — é irrelevante numa cena de sol a pino.
- **VoxelGI / LightmapGI.** Mesma razão, agravada: exigem passo de bake, e não
  há nada estático para bakear.
- **Reflexos de tela (SSR).** Só pagam em asfalto molhado, que `PROTOTIPO.md`
  já pôs fora de escopo.
- **Neblina volumétrica.** Bonita, e cara, e a neblina exponencial que já
  existe resolve o problema real (esconder o fim do mundo). Fica como opção
  para a fase de noite, se ela existir.
- **TAA.** `Viewport.use_taa` existe e **não pode ser ligado**: TAA é média
  temporal, e média temporal em 640×360 com upscale nearest é exatamente o
  borrão que o projeto inteiro existe para evitar.

### Os três números da sombra

Sombra direcional tem três parâmetros que decidem se ela parece sombra ou
parece bug, e nenhum dos três tem valor óbvio:

- **`directional_shadow_max_distance`.** A neblina já apaga o mundo; a sombra
  não precisa ir mais longe que ela. Ponto de partida: **70 m**, casando com
  `fog_density = 0.0045`. Além disso, sombra desperdiçada.
- **`directional_shadow_mode`.** `SHADOW_PARALLEL_2_SPLITS` deve bastar com
  70 m de alcance. 4 splits é gasto sem retorno numa cena onde tudo o que
  importa está nos primeiros 20 m.
- **`shadow_normal_bias` / `shadow_bias`.** É aqui que aparece o acne e o
  *peter-panning* (a sombra descolando do pé do objeto). Com o atlas
  direcional em 4096 (já é o padrão do projeto, verificado) sobre 70 m, a
  densidade é alta e o bias pode ser baixo.

E uma armadilha específica deste projeto: **a pista não deve projetar sombra.**
Ela é plana, não tem nada para projetar, e é o mesh maior da cena. `RoadMesh`
e o terreno vão com `cast_shadow = SHADOW_CASTING_SETTING_OFF`; prédios,
postes, carros e atores vão com `ON`. Isso é `GeometryInstance3D.cast_shadow`,
verificado.

### Como o sprite recebe luz (o problema clássico)

Se a rota A for escolhida, este é o problema que decide se ela funciona. Um
quad com albedo pré-renderizado é uma figurinha: a luz da cena não sabe onde
está o ombro do piloto, então o personagem fica chapado enquanto o mundo em
volta tem volume — e o olho pega isso em meio segundo.

Solução, e ela é conhecida: **renderizar o normal map junto com o albedo**, no
mesmo lote e no mesmo enquadramento. `StandardMaterial3D.normal_texture`
existe e funciona em quad billboard (verificado). Com o normal, o Forward+
ilumina o sprite por pixel como se fosse geometria: o fogo do lado ilumina o
lado certo do piloto, a sombra do prédio escurece ele junto com o resto.

Duas ressalvas honestas:

- O normal de um billboard gira com o billboard, então ele mente quando o
  ângulo da câmera foge muito do ângulo em que foi renderizado. Com ±60° de
  matriz, o erro fica dentro do tolerável.
- Continua faltando **auto-sombra projetada** (o braço não escurece o tronco).
  Isso já vem baked no albedo do render, e é o único jeito.

Na rota B nada disto é necessário — é o argumento mais forte a favor dela.

## Partículas

É a parte do pedido com resposta mais direta: **o Godot já tem tudo, e o
gatilho de quase todo efeito já existe como número no código.** O trabalho aqui
é quase inteiramente de bom gosto, não de engenharia.

### O catálogo

| Efeito | Gatilho — e ele já existe | Nó | O parâmetro que decide |
| --- | --- | --- | --- |
| **Fumaça de pneu** | `player_bike.gd::_integrate`: `(desired - horizontal).length()` já é a derrapada, e o `PROTOTIPO.md` já a nomeia assim | `GPUParticles3D` no eixo traseiro | limiar de derrapada que liga a emissão |
| **Poeira / terra** | `_off_road` e o teto de velocidade da calçada | idem, cor amostrada do terreno | taxa em função da velocidade |
| **Faísca** | sinal `scraped(intensity)` — já chega com a intensidade pronta | `GPUParticles3D` com `trail_enabled` | emissão alta + vida curta + glow |
| **Fumaça de escapamento** | contínua; engrossa em `boosting` | `GPUParticles3D` de taxa baixa | `amount_ratio` amarrado ao acelerador |
| **Poeira de queda** | sinal `crashed(reason)` | `one_shot` + `explosiveness = 1.0` | raio, e o fato de ser único |
| **Fogo** | moto no chão (`State.CRASHED`), barril de cenário | `GPUParticles3D` flipbook **+ `OmniLight3D` pulsante** | a luz. É ela que vende, não a chama |
| **Impacto do soco** | sinal `punch_landed(target)` | `one_shot` curto | 4 ou 5 partículas. Mais que isso vira pó |
| **Marca de derrapagem** | mesma derrapada da fumaça | `Decal` no asfalto | tempo de vida e `distance_fade` |

Nenhuma linha dessa tabela pede uma medida nova. Essa é a observação
importante: **o protótipo já calculou tudo o que as partículas precisam
saber**, porque calcular a derrapada e a raspada era necessário para o *feel*
muito antes de ser necessário para o efeito.

### As quatro regras que fazem partícula caber em pixel

Partícula é a coisa mais fácil de errar num jogo de resolução baixa, porque o
padrão da engine é feito para 1080p e lê como VFX moderno — macio, translúcido,
contínuo. Isso denuncia a grade na hora.

1. **Cadência travada.** `GPUParticles3D.fixed_fps` em 12–15. O mesmo
   argumento da animação do sprite: partícula a 60 fps num mundo que se move em
   degraus é a pista mais óbvia de que há 3D por baixo. Verificado como
   existente.
2. **Borda dura onde a forma importa.** Faísca, pedra e detrito vão com
   `TRANSPARENCY_ALPHA_SCISSOR` e `TEXTURE_FILTER_NEAREST`. Alpha suave fica
   só onde a suavidade **é** o efeito: fumaça e poeira.
3. **Contagem baixa.** Em 640×360 uma partícula ocupa poucos pixels; cem delas
   viram um borrão cinza sem forma. Vinte partículas grandes leem melhor que
   duzentas pequenas — e é também o que as referências mostram.
4. **Flipbook, não escala.** Fumaça que só cresce lê como esfera inchando.
   `BILLBOARD_PARTICLES` com `particles_anim_h_frames` / `_v_frames` roda uma
   sequência desenhada. Todas verificadas.

### Partícula que bate no chão, num mundo sem colisor de chão

Aqui há um encontro com um invariante do contrato que merece estar escrito,
porque a leitura ingênua leva alguém a quebrá-lo.

Faísca que atravessa o asfalto e poeira que some dentro da pista estragam o
efeito. O reflexo natural é "então põe colisor na pista" — e isso violaria
frontalmente o invariante *o chão não tem colisor*, que existe porque a 50 m/s
um `CharacterBody3D` atravessa trimesh.

**Provavelmente não é preciso.** `GPUParticlesCollisionHeightField3D` existe no
4.7.2 — isso está **verificado** — e o mecanismo dele é construir um campo de
altura a partir da **geometria desenhada**, não de corpos de física. Se for
isso mesmo, ele enxerga o `RoadMesh` sem que o `RoadMesh` tenha colisor, que é
exatamente o que se quer.

A distinção importa e é a razão de a frase estar hedged: o que foi conferido
rodando a engine é que a **classe e as propriedades existem**. Que ela leia
mesh sem colisor é leitura do mecanismo, não medição — e por isso está na lista
de confirmar logo abaixo, com o teste.

E o problema óbvio seguinte — um campo de altura fixo não cobre 3,2 km de rota
— já vem resolvido: o nó tem **`follow_camera_enabled`** (verificado). O campo
anda com a câmera.

Duas coisas a confirmar na prática, e o teste de cada uma:

- **Que o campo realmente pega mesh sem colisor.** Teste: ligar a colisão numa
  emissão de faísca sobre a pista e ver se elas quicam. Se não quicarem, a
  alternativa sem invariante ferido é um `GPUParticlesCollisionBox3D` fino
  seguindo o jogador na altura amostrada da curva — a altura já é conhecida
  analiticamente por `track.point()`.
- **O custo do re-render do campo por quadro** com `follow_camera_enabled`.
  É a única linha desta seção com risco real de orçamento.

O invariante fica intacto, e vale registrar o porquê para quem vier depois:
**a partícula colide com o que é desenhado, não com o que é simulado.**

## Velocidade: o borrão

Nas quatro referências, o que comunica velocidade não é a geometria — é o
**borrão**. Periferia esticada, faixas viradas risco, táxi amarelo à esquerda
sem forma nenhuma. Tire o borrão e sobra uma foto de moto parada.

**O Godot 4.7.2 não tem motion blur embutido.** Verificado: `Environment` não
tem `motion_blur_enabled` nem equivalente. Então é código nosso, e há dois
caminhos:

| | `ColorRect` com shader dentro do SubViewport | `CompositorEffect` |
| --- | --- | --- |
| O que é | Um quad 2D em `CanvasLayer` abaixo da HUD, lendo `hint_screen_texture` e `hint_depth_texture` | Passe customizado dentro do pipeline 3D |
| Linguagem | Shader do Godot | Compute shader + `RenderingDevice` |
| Acesso | Cor e profundidade do quadro | Qualquer buffer, em qualquer estágio |
| Portabilidade | Todos os renderizadores | Só Forward+/Mobile (Vulkan) |
| Esforço | Baixo | Alto |

**Recomendação: `ColorRect` com shader.** Ele alcança cor *e* profundidade, que
é tudo o que um borrão radial precisa, e é testável sem infraestrutura nova. O
`CompositorEffect` fica guardado para o dia em que fizer falta um buffer que o
2D não vê — vetor de movimento por objeto, por exemplo.

O efeito tem três ingredientes, e o terceiro é o que separa "parece velocidade"
de "parece sujeira na tela":

1. **Borrão radial** a partir do centro da tela, com força crescendo com o raio.
   6 a 10 amostras bastam em 640×360.
2. **Força amarrada à velocidade**, não constante. Um `uniform` alimentado por
   `player.speed / tuning.max_speed`. O boost empurra além de 1,0 — e aí o
   efeito satura de propósito, que é o que faz o boost *parecer* boost.
3. **Máscara por profundidade.** O piloto **não** borra. Nas referências ele é
   a única coisa nítida do quadro, e é isso que faz o olho ancorar nele. Sem a
   máscara, o resultado é uma tela inteira suja.

Há ainda um truque barato que o gênero usa e que combina com a resolução:
**linhas de velocidade** — riscos radiais desenhados por cima, aparecendo só
acima de certa velocidade. Custa quase nada e lê a 640×360 melhor do que
qualquer borrão. Vale testar antes de investir no shader, aliás: pode ser que
resolva sozinho.

E metade do trabalho já está feita: `cam_fov_speed_gain = 16.0` já abre a lente
com a velocidade, que é o outro meio da linguagem.

### Ordem dos passes, e por que ela importa

O passe de quantização de paleta tem que ser o **último de todos**. Neblina,
glow e tonemap produzem valores intermediários entre as cores da paleta; se a
quantização rodar antes deles, eles reintroduzem os tons que ela acabou de
tirar e a paleta deixa de ser paleta.

Dentro do `Environment` a ordem é da engine e não se escolhe: o glow opera no
buffer HDR, **antes** do tonemap, e os `adjustment_*` — inclusive o LUT — são a
última coisa que ele faz. Isso é conveniente: significa que o LUT de paleta já
nasce depois do glow sem ninguém precisar arranjar nada.

O que é nosso é o que vem depois:

```
mundo 3D (640x360)
  -> sombra, SSAO                 <- Environment
  -> neblina                      <- Environment
  -> glow (em HDR)                <- Environment
  -> tonemap                      <- Environment
  -> LUT de cor (adjustment)      <- Environment, e ja e o ultimo passo dele
  -> borrao radial                <- nosso: ColorRect com shader
  -> quantizacao + dither         <- nosso: ColorRect com shader (POR ULTIMO)
  -> HUD                          <- CanvasLayer dentro do mesmo SubViewport
  -> upscale inteiro por nearest  <- SubViewportContainer
```

A HUD entra depois da quantização de propósito: ela já é desenhada em cores
escolhidas à mão, e passá-la pelo dither só suja o texto.

Dois `ColorRect` em sequência precisam de duas camadas — o segundo lê o
resultado do primeiro por `hint_screen_texture`, e para isso o primeiro já tem
que ter sido desenhado. Na prática são dois `CanvasLayer` com `layer` crescente,
e a HUD (`layer = 10`, hoje) acima dos dois.

## Céu, paleta e dithering

O fundo hoje é `BG_COLOR` chapado. As referências têm céu azul saturado com
nuvem visivelmente em bandas — e a banda é intencional, é o sotaque de época.

**`ProceduralSkyMaterial`** dá o gradiente e tem duas propriedades que servem
direto (verificadas): `sky_cover`, que aceita uma textura de nuvem — é onde
entra uma nuvem desenhada e já dithered — e `use_debanding`, que **fica
desligado**. Debanding é dither de sub-pixel para *esconder* banda; aqui a
banda é o produto.

Ligar o céu tem um efeito colateral que é, na verdade, o principal ganho:
`AMBIENT_SOURCE_SKY` passa a tirar a luz ambiente **do céu**. A sombra fica
azul porque o céu é azul, sem ninguém escolher uma cor de sombra à mão. É a
diferença entre uma cena iluminada e uma cena pintada.

**A paleta** vem do LUT em `Environment.adjustment_color_correction`, que
aceita uma textura (verificado). É um arquivo de arte, não de código — e é o
ponto único onde o "clima" da fase se ajusta. Uma fase de fim de tarde é outro
LUT, não outro shader.

**O dither** fecha o look. Um padrão de Bayer 4×4 aplicado antes da
quantização transforma banda em textura, e a 640×360 com upscale 3× o padrão é
visível — que é a intenção. Duas regras, e ambas são armadilhas conhecidas:

- O padrão é indexado pela coordenada **do pixel do SubViewport**, nunca pela
  coordenada de tela. Se ele for indexado em tela, o dither não escala com o
  upscale e some.
- O padrão tem que estar **fixo na tela**, não no mundo. Dither fixo no mundo
  rasteja quando a câmera anda, e a esse efeito se dá o nome de "chuvisco".

## HUD

A HUD das referências é o mesmo vocabulário nas quatro imagens: legenda pequena
em amarelo, número grande em branco, contorno preto duro, barra segmentada em
degradê verde→amarelo→vermelho, tudo ancorado nos quatro cantos.

A HUD atual (`hud.gd`) já está no lugar certo — dentro do SubViewport, que é o
invariante que importa — mas é magra: fonte padrão do Godot, sem contorno, e
com todas as posições em números cravados para 320×180.

O que muda:

- **`W`/`H` de 320/180 para 640/360**, e cada posição junto. São ~25 constantes
  em `hud.gd`. Melhor que multiplicar tudo por 2 é **reposicionar**: com 4× a
  área, o layout das referências (quatro cantos, centro vazio) fica viável, e
  hoje ele não é.
- **Fonte bitmap.** `FontFile` com `antialiasing` e `hinting` desligados,
  `subpixel_positioning` desligado (todas verificadas). Fonte vetorial com
  antialiasing num jogo pixelado é o mesmo erro de HUD nítida sobre mundo
  pixelado, só que dentro da HUD.
- **Contorno.** `LabelSettings` tem contorno; é o que dá a legibilidade sobre o
  asfalto claro.
- **Barra segmentada.** Não é uma `ProgressBar`: é um `ColorRect` por segmento,
  ou um shader de uma linha. Segmento discreto é o que faz a barra ler como
  medidor de arcade em vez de barra de carregamento.

Uma nota de conteúdo: as referências mostram **POS**, **LAP**, **SPEED** e
**TIME**. O protótipo tem posição, velocidade, tempo, estrelas, adrenaline e
combo — mais informação do que as referências carregam. Isso não é defeito
(o jogo tem mecânicas que a imagem não tem), mas vale a pergunta na hora de
redesenhar: o que pode virar efeito em vez de número? Adrenaline, por exemplo,
lê melhor como distorção na borda da tela do que como barra.

## O que isto custa por frame

Não há número medido aqui, e inventar um seria pior do que não ter. O que dá
pra dizer com honestidade:

- **A conta de pixel é confortável.** 640×360 são 230 mil fragmentos. Sombra,
  SSAO e dois passes de pós nesse tamanho não chegam perto de segurar uma GPU
  integrada moderna.
- **A conta de desenho é a incerta.** Ela não depende da resolução, e sim de
  quantos prédios, postes, pedestres, carros, rivais e emissores existem ao
  mesmo tempo. É aí que o orçamento aperta, e é o que precisa ser medido.

Este projeto tem uma cultura de medir em vez de achar, e o visual não deveria
ser exceção. **Proposta: um comando `python tools/dev.py fps`** que roda a
corrida solta por N segundos com tela e reporta tempo de quadro — p50, p95 e o
pior — do mesmo jeito que o `selftest` reporta física.

Sem ele, "ficou pesado?" vira discussão de impressão, e impressão sobre
performance é quase sempre errada. Com ele, o orçamento vira mais uma linha do
`baseline.json`.

## O que isto mexe no contrato

Nada aqui é decisão tomada. A lista existe para que a decisão seja tomada
sabendo o preço.

### Invariantes que **não** mudam

Vale começar por eles, porque a leitura apressada deste documento sugeriria
quebrar dois: o colisor do chão, por causa da colisão de partícula, e a HUD
dentro do SubViewport, porque com 4× de área a tentação de desenhar a interface
em resolução nativa volta. Nenhum dos dois precisa cair.

- **O chão continua sem colisor.** A colisão de partícula usa campo de altura
  sobre geometria visual, não corpo de física. Ninguém precisa de trimesh de
  pista.
- **Só o jogador continua rodando física.** Partícula é visual e roda na GPU.
- **A HUD continua dentro do SubViewport.** A resolução muda; o princípio, não.
- **Winding horário continua obrigatório** — e passa a valer duas vezes, porque
  face descartada não projeta sombra. Um mesh com winding errado agora some
  *e* perde a sombra.
- **`stretch_shrink`, nunca `SubViewport.size`.** Continua idêntico, só com
  valor 2 em vez de 4.
- **Semente fixa e defaults do repositório no banco de provas.** Partículas são
  não determinísticas por natureza, e por isso **nenhuma medida pode depender
  delas**. Hoje nenhuma depende.

### O que muda de verdade

| O quê | Onde | Tamanho |
| --- | --- | --- |
| `PIXEL_SHRINK` de 4 para 2 | `scripts/main.gd` | 1 linha |
| `scale_mode = integer` | `project.godot` | 1 linha |
| Layout da HUD | `scripts/hud.gd` | ~25 posições, e vale redesenhar em vez de multiplicar |
| Sombra, céu, LUT, glow | `scripts/world.gd::_build_environment` | seção inteira |
| `cast_shadow` por mesh | `road_track.gd`, `greybox.gd`, `world.gd` | 1 linha em cada construtor |
| Baseline visual | `tests/baseline_visual.json` | as 4 medidas mudam — atualização legítima, no mesmo commit, com o motivo |
| O número "320×180" escrito em prosa | **13 arquivos** (lista abaixo) | comentários e documento |

Esse último item é o achado desagradável, e é melhor saber antes: **320×180 não
é uma constante, é um número gravado em treze arquivos**, a maioria deles em
comentários que explicam *por que* algo é do jeito que é ("a 320×180 duas
caixas cinzas coladas não leem"). Trocar a resolução sem revisar esses
comentários deixa o repositório cheio de justificativa que virou mentira — e
justificativa mentirosa é pior que comentário ausente, porque é acreditada.

```bash
# a lista se regenera; nao confie na contagem abaixo sem rodar isto
grep -rln "320x180\|320×180" scripts/ docs/ tools/ project.godot CLAUDE.md README.md
```

Hoje: `scripts/hud.gd`, `main.gd`, `race_flow.gd`, `race_run.gd`,
`traffic_car.gd`, `world.gd`, `world_tuning.gd`, `project.godot`, `README.md`,
`CLAUDE.md`, `docs/PROTOTIPO.md`, `docs/GDD.md`, `docs/INSTALAR.txt`.

**E a contagem cresce sozinha.** Este documento nasceu dizendo nove; três dias
depois eram treze, porque entrou uma tela de menu e ela também justificou uma
decisão pelo tamanho da tela. Isso não é crítica a quem escreveu — é o
comportamento normal de um número que virou argumento. Só reforça a moral:
quanto mais tarde a resolução mudar, mais prosa haverá para revisar.

Nenhum deles muda a decisão. Mas o trabalho é "trocar a resolução **e** revisar
treze arquivos de prosa", não "trocar uma linha".

E um deles é o `CLAUDE.md`, que é acordo: **não se altera sem conversa.**

## Ordem de execução

Fases pensadas para serem pegas uma por vez, cada uma com critério de aceite
verificável e cada uma entregando algo visível sozinha. A ordem é por risco:
o que pode invalidar as outras vem antes.

O plano executável que sai desta lista — com manifesto de assets, formato de
cada arquivo e critério de abandono — está em
[PROVA_VISUAL.md](PROVA_VISUAL.md). Ele recorta um trecho de pista e uma hora
do dia para responder "dá ou não dá" antes de qualquer produção de arte em
escala.

**Fase 0 — medir o que existe.** Implementar `dev.py fps` e gravar o tempo de
quadro do greybox atual. Sem esta linha de base, nenhuma fase seguinte tem como
dizer se ficou cara.
*Aceite:* o comando roda nos três sistemas e imprime p50/p95.

**Fase 1 — resolução.** `PIXEL_SHRINK = 2`, `scale_mode = integer`, HUD
reposicionada, os nove arquivos de prosa revisados, baseline visual atualizado.
*Aceite:* o portão inteiro passa, o baseline visual novo vem no mesmo commit
com o motivo, e o `fps` não regrediu além do esperado por 4× de fragmentos.

**Fase 2 — iluminação e sombra.** Sombra do sol, céu procedural, ambiente do
céu, `cast_shadow` correto por mesh. Sem sprite ainda: é o greybox que ganha
sombra, e é proposital — assim dá para ver se a sombra funciona sem a arte
disfarçando.
*Aceite:* a moto tem sombra de contato que segue a ladeira; `fps` dentro do
orçamento; baseline visual atualizado.

**Fase 3 — paleta.** Tonemap, LUT, glow, dither. A fase mais barata e a de
maior retorno por hora: é ela que faz a tela ler como "jogo" em vez de "engine".
*Aceite:* a mesma cena, lado a lado, antes e depois.

**Fase 4 — partículas.** O catálogo inteiro, nos gatilhos que já existem.
Independente das fases de sprite — dá para rodar em paralelo.
*Aceite:* cada efeito dispara no evento certo; a colisão com o chão confirmada
ou substituída pela alternativa; `fps` dentro do orçamento com o pior caso
(queda no meio do trânsito).

**Fase 5 — borrão.** Shader radial com máscara de profundidade. Testar antes a
versão barata (linhas de velocidade): pode ser que ela baste.
*Aceite:* a 180 km/h o piloto está nítido e a periferia não.

**Fase 6 — o ator.** Aqui entra a decisão rota A / rota B, e só aqui: as cinco
fases anteriores valem para as duas. Começa por **um** ator — a moto do jogador
— e só depois os rivais.
*Aceite:* a moto lê como digitalizada em movimento, não em captura parada.
Captura parada engana; é preciso ver a cadência de 12 fps rodando.

**Fase 7 — cenário de Rio.** Placa, mural, ônibus, palmeira, contêiner,
viaduto. É conteúdo, e é o que mais aparece nas referências — mas depende de
todas as decisões acima estarem fechadas, senão é arte refeita.

Uma observação sobre a ordem, e ela contraria o instinto: **o sprite vem por
último**, apesar de ser o pilar mais visível. A razão é que sombra, paleta e
borrão mudam completamente a aparência do sprite, e arte produzida antes deles
é arte que vai ser refeita. É a mesma lógica que pôs o greybox antes da arte no
`PROTOTIPO.md`.

## O que fica de fora

Herdado do `PROTOTIPO.md` e confirmado aqui:

- **Chuva, noite, asfalto molhado e neon.** Cada um é um sistema de
  iluminação próprio. Depois que o de dia estiver fechado.
- **Shader de mundo curvo (SEGA curved world).** Bonito, e ortogonal a tudo
  aqui; entra quando entrar.
- **Áudio.** Metade da percepção de impacto, e assunto de outro documento.
- **Marca real.** Não entra em nenhuma fase.

E uma exclusão nova, específica deste documento:

- **Perseguir a imagem de referência pixel a pixel.** O alvo é a leitura em
  meio segundo, não o quadro. A referência tem detalhe fotográfico em cada
  prédio do fundo porque é foto. Gastar orçamento de geometria tentando igualar
  aquilo é a maneira mais confiável de ficar sem orçamento para o que importa,
  que é a moto.

## Riscos e perguntas em aberto

Em ordem de quanto podem doer.

**1. A regressão visual vira moeda de novo.** É o risco mais concreto, e o
repositório já passou por ele: o `CLAUDE.md` registra o caso do #10, com o limite
plantado no meio do ruído da própria medida.

Sombra, partícula e borrão **aumentam** a variância entre quadros. As três
medidas de `baseline_visual.json` (fração de céu, luminância, famílias de cor)
respondem a todas as três coisas novas. A tolerância de 20% foi calibrada
contra o ruído de hoje; depois destas fases, ela é um número sobre um mundo que
não existe mais.

Mitigação, e ela precisa vir **junto** com a Fase 2, não depois: medir o novo
piso de ruído com o mesmo código, rodando três ou quatro vezes, do mesmo jeito
que foi feito quando o limite subiu de 12% para 20%. Se a variância ficar alta
demais, a saída é um perfil de render sem efeitos só para o portão — o que tem
o seu próprio custo, porque aí o portão deixa de ver o que o jogador vê.

**2. O CI roda em software rendering.** O job `regressao-visual` usa
`LIBGL_ALWAYS_SOFTWARE=1` sobre `xvfb`, sem GPU, e leva ~90 s hoje. Quatro
vezes mais fragmentos, mais mapa de sombra, mais partícula — sob llvmpipe isso
não escala linearmente, escala mal. Há risco real de o job passar de 90 s para
vários minutos, ou de estourar.

Precisa ser medido cedo (Fase 1 já dá o primeiro sinal). Saídas possíveis:
capturar menos quadros, reduzir o perfil de qualidade só nesse job, ou aceitar
o tempo.

**3. O ator lê como "3D com filtro".** É o risco da rota B, e ele é subjetivo —
não há medida que o pegue. O único teste é o olho, em movimento, e por isso a
Fase 6 tem que ser avaliada rodando e não em captura.

**4. Cintilação.** Todo sistema de pixel art em 3D luta com isto, e ele aparece
em três lugares independentes: minificação de sprite (mitigado por mipmap),
borda de sombra em objeto que se move, e o padrão de dither se ele for
indexado errado. Nenhum dá erro; todos aparecem só em movimento.

**5. A resolução pode ainda não bastar.** 640×360 põe o piloto em ~100 px. Se
na prática ficar apertado, o próximo degrau com escala inteira em 1080p é
960×540 — e ele perde 720p. Este documento recomenda 640×360 pela conta de
escala inteira, não porque 100 px seja um alvo sagrado.

**Perguntas que este estudo não responde:**

- Rota A ou rota B para os atores? A recomendação é B, mas a decisão depende de
  quem vai fazer a arte e com qual ferramenta — e isso é informação que o
  código não tem.
- Quantos prédios cabem no quadro? Depende da Fase 0.
- A HUD deve seguir as referências (POS/LAP/SPEED/TIME) ou manter as mecânicas
  que o protótipo já tem (estrelas, adrenaline, combo)? É pergunta de design,
  não de técnica.

## Apêndice A — API do Godot 4.7.2 verificada

Tudo abaixo foi conferido rodando `ClassDB` na engine fixada em
`.godot-version` (4.7.2.stable.official), em setembro de 2026. O método:
`godot --headless --script` com um script que lista propriedades e enums reais.
Refazer a verificação num bump de engine é barato, e o motivo de registrar aqui
é que **afirmação sobre API envelhece**.

**Existe e serve:**

| Classe / propriedade | Para quê |
| --- | --- |
| `Compositor`, `CompositorEffect` | passes de pós customizados (caminho avançado) |
| `Decal` (+ `texture_normal`, `distance_fade_enabled`) | marca de pneu, poça, mancha |
| `GPUParticlesCollisionHeightField3D` (+ **`follow_camera_enabled`**) | partícula batendo no chão sem colisor de chão |
| `GPUParticles3D.fixed_fps`, `.trail_enabled`, `.amount_ratio`, `.sub_emitter` | cadência travada, rastro de faísca, densidade ao vivo |
| `ParticleProcessMaterial.collision_mode` (`RIGID`, `HIDE_ON_CONTACT`) | como a partícula reage ao chão |
| `ParticleProcessMaterial.turbulence_enabled`, `anim_offset_*`, `anim_speed_*` | fumaça com vida, flipbook |
| `BaseMaterial3D.particles_anim_h_frames` / `_v_frames` / `_loop` | flipbook de partícula |
| `BaseMaterial3D.billboard_mode` = `BILLBOARD_FIXED_Y` / `BILLBOARD_PARTICLES` | sprite de ator / de partícula |
| `BaseMaterial3D.normal_enabled`, `.normal_texture` | sprite pré-renderizado recebendo luz da cena |
| `BaseMaterial3D.uv1_scale`, `.uv1_offset` | escolher o quadro dentro do atlas |
| `BaseMaterial3D.transparency` = `TRANSPARENCY_ALPHA_SCISSOR` | borda dura |
| `BaseMaterial3D.texture_filter` = `NEAREST_WITH_MIPMAPS` | pixel sem cintilar ao longe |
| `GeometryInstance3D.cast_shadow` (`OFF`/`ON`/`DOUBLE_SIDED`/`SHADOWS_ONLY`) | pista sem projetar, ator projetando |
| `DirectionalLight3D.directional_shadow_mode`, `_max_distance`, `_blend_splits` | os três números da sombra |
| `Light3D.shadow_opacity`, `.shadow_blur`, `.light_projector` | dureza da sombra; projetor para luz de poste |
| `Environment.adjustment_color_correction` | LUT de paleta |
| `Environment.tonemap_mode` (`LINEAR`/`REINHARDT`/`FILMIC`/`ACES`/`AGX`) | curva antes da paleta |
| `Environment.glow_*` (+ `glow_map`) | faísca, farol, placa |
| `Environment.ssao_enabled`, `ssil_enabled` | oclusão de contato |
| `Environment.fog_aerial_perspective`, `fog_sun_scatter`, `fog_height` | profundidade sem geometria |
| `ProceduralSkyMaterial.sky_cover`, `.use_debanding` | nuvem desenhada; banda proposital |
| `Viewport.scaling_3d_mode` inclui `SCALING_3D_MODE_NEAREST` | alternativa ao SubViewportContainer, se um dia fizer falta |
| `FontFile.antialiasing`, `.hinting`, `.subpixel_positioning` | fonte bitmap de verdade |
| `display/window/stretch/scale_mode` (hoje `fractional`) | `integer` conserta 1600×900 |
| `rendering/lights_and_shadows/directional_shadow/size` = 4096 | já é o padrão do projeto |

**Não existe — e é a ausência que mais muda o plano:**

| | |
| --- | --- |
| `Environment.motion_blur_enabled` | **não existe no 4.7.2.** Motion blur é código nosso: `ColorRect` com shader lendo cor + profundidade, ou `CompositorEffect` |

**A confirmar rodando** (com o teste ao lado):

| | |
| --- | --- |
| `GPUParticlesCollisionHeightField3D` pegar mesh **sem** colisor | emitir faísca sobre o `RoadMesh` com colisão ligada e ver se quica |
| Custo de `follow_camera_enabled` por quadro | `dev.py fps` com e sem |
| Quad billboard com alpha scissor projetando sombra com a silhueta certa | ligar `cast_shadow = ON` num quad de teste e olhar a sombra |

## Apêndice B — as contas

Reproduzíveis, para quem quiser conferir em vez de acreditar.

**Tamanho do ator na tela.** Câmera em `cam_distance = 6.4`, `cam_height =
2.25`; centro da moto a 0,875 m do chão. Distância efetiva
`hypot(6.4, 2.25-0.875) = 6,55 m`. Altura visível `2 · d · tan(fov/2)`. Moto +
piloto = 1,75 m.

| FOV | campo visível | fração da tela | @180 | @270 | @360 | @540 |
| --- | --- | --- | --- | --- | --- | --- |
| 50° (parado) | 6,10 m | 28,7% | 52 px | 77 px | 103 px | 155 px |
| 58° (meio) | 7,26 m | 24,1% | 43 px | 65 px | 87 px | 130 px |
| 66° (talo) | 8,50 m | 20,6% | 37 px | 56 px | 74 px | 111 px |

**Rival a distância**, FOV 50°:

| distância | @180 | @360 |
| --- | --- | --- |
| 12 m | 28 px | 56 px |
| 25 m | 14 px | 27 px |
| 40 m | 8 px | 17 px |
| 70 m | 5 px | 10 px |

**Escala total do upscale** = `stretch_shrink` × escala do `canvas_items`
(janela ÷ 1280). Tabela completa na seção de resolução.

**Pixels:** 320×180 = 57.600. 640×360 = 230.400. Razão 4×.

**Atlas:** 4096×4096 ÷ (160×160) = **625 quadros**. A matriz estimada da rota A
é ~150 quadros por rig, então um rig inteiro cabe numa folha, com o normal map
numa segunda.
