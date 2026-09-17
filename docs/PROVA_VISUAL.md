# A prova visual

Plano executável para responder **uma** pergunta, do mesmo jeito que o
protótipo greybox respondeu a dele:

> Botando luz, paleta, textura, ator e partícula neste motor, a tela fica
> parecida com as referências — ou não fica?

Não é o plano de produção da arte do jogo. É o **menor caminho até a resposta**,
e a resposta pode ser não. Se for não, é melhor saber depois de duas semanas de
prova do que depois de seis meses de pipeline.

Leia [DIRECAO_VISUAL.md](DIRECAO_VISUAL.md) antes: ele é o estudo que sustenta
cada escolha aqui e traz as contas. Este documento não repete as contas, ele
executa as conclusões.

## O critério de pronto

**Um print do jogo ao lado da imagem 1, e a pergunta "isso é o mesmo jogo?"
respondida com sim por alguém que não trabalhou nele.**

É subjetivo, e é assim mesmo — "está gostoso?" também é, e o `PROTOTIPO.md`
convive com isso há meses. O que dá para tornar objetivo é o **quadro**: a
comparação tem que ser sempre o mesmo instante da mesma pista com a mesma
câmera, senão "melhorou?" vira discussão sobre qual print foi mais sortudo.

Por isso a tarefa **P0** existe e vem antes de qualquer pixel.

Três perguntas auxiliares, essas sim objetivas, que a prova também responde:

| Pergunta | Como se responde |
| --- | --- |
| Cabe no orçamento de quadro? | `dev.py fps`, p50 e p95 |
| O portão visual sobrevive? | variância medida em 4 rodadas iguais |
| O CI sobrevive? | tempo do job `regressao-visual` |

## O recorte

Uma prova é uma fatia, não um andar inteiro. O que **entra**:

- **Um trecho de pista**, sempre o mesmo, escolhido por ter reta, curva e
  ladeira no campo de visão.
- **Uma hora do dia**: meio-dia de sol duro. É o que as quatro referências
  mostram e é o caso mais fácil de iluminação que existe.
- **Um ator**, o jogador. Rivais herdam o mesmo rig com paleta trocada — isso
  já é o plano do `world.gd`, não é atalho da prova.
- **Cenário suficiente para o quadro**: prédio, poste, muro com mural, placa
  verde, calçada. Não a cidade.

O que **não** entra, e por quê:

| Fora | Por quê |
| --- | --- |
| Animação do ator | Uma pose parada já responde "lê como digitalizado?". A cadência de 12 fps entra na P5 só se a pose passar |
| Rivais com arte própria | Mesmo rig, paleta trocada. Se a troca de paleta falhar, isso aparece na P5 |
| Menu, resultado, pausa | Já existem e não estão em questão |
| Noite, chuva, asfalto molhado | Outro sistema de luz inteiro |
| Áudio | Metade do impacto, e assunto de outro documento |
| Otimização | Medir sim, otimizar não. Otimizar antes de saber se presta é gastar duas vezes |

## Manifesto de assets

Tudo o que precisa ser produzido, com formato fechado. Um asset sem formato
definido é um asset que vai ser refeito.

**Regras que valem para todos os PNG:**

- **RGBA8 sem compressão com perda.** No `.import`: `compress/mode=0`.
- **Sem VRAM compression.** Ver a armadilha logo abaixo — esta é a que estraga
  tudo em silêncio.
- **Sem antialias na silhueta.** Borda dura é o pilar 2 inteiro.
- **Potência de dois** nas dimensões, para mipmap se comportar.
- Versionados em **Git LFS**, que o `.gitattributes` já roteia.

### Mundo — texturas

Todas *tileable* (emendam consigo mesmas) salvo indicação.

| Arquivo | Dimensão | Canais | O que é |
| --- | --- | --- | --- |
| `asfalto_albedo.png` | 256×256 | RGB | Grão do asfalto, cinza médio dessaturado. A cor forte vem do LUT, não daqui |
| `asfalto_normal.png` | 256×256 | RGB (normal tangente) | Relevo sutil. Forte demais vira lixa a 640×360 |
| `calcada_albedo.png` | 128×128 | RGB | Pedra portuguesa. É o detalhe que diz "Rio" mais barato que existe |
| `guardrail_albedo.png` | 64×64 | RGB | Metal galvanizado, tile horizontal |
| `predio_fachada.png` | 512×512 | RGB | Atlas de 4 fachadas de 256×256. Janelas em fileira, tile vertical |
| `mural_atlas.png` | 512×512 | RGBA | Atlas de 4 grafites de 256×256. Alfa recorta a forma |
| `placa_verde.png` | 256×128 | RGBA | Placa de rodovia com texto. Nomes de via reais são livres — não são marca |
| `container_albedo.png` | 128×128 | RGB | Contêiner portuário, tile horizontal |

### Mundo — modelos

| Arquivo | Orçamento | Formato | Nota |
| --- | --- | --- | --- |
| `carro.glb` | ~300 tris, 3 variantes | glTF binário | Substitui a caixa do `traffic_car.gd`. Uma textura compartilhada |
| `carro_atlas.png` | 256×256 | RGB | As 3 variantes e a máscara de cor de lataria no mesmo atlas |
| `onibus.glb` | ~400 tris | glTF binário | Aparece em 3 das 4 referências. Barato e caracteriza |

glTF binário (`.glb`) porque o Godot importa nativamente, é um arquivo só, e
não arrasta caminho de textura quebrado entre sistemas operacionais.

### Céu e paleta

| Arquivo | Dimensão | Canais | O que é |
| --- | --- | --- | --- |
| `ceu_nuvens.png` | 2048×1024 | RGBA | Panorama equirretangular para `sky_cover`. Alfa é a cobertura. **Já sai dithered** — a banda é o produto, não o defeito |
| `lut_dia.png` | 256×16 | RGB | LUT de cor: 16 fatias de 16×16, importada como `Texture3D` |
| `bayer4.png` | 4×4 | R | Matriz de dithering ordenado para o passe final |

`Environment.adjustment_color_correction` aceita `Texture2D` **ou** `Texture3D`
(verificado). O `Texture3D` é o menos ambíguo. **A conferir na primeira
importação: a orientação das fatias.** É o tipo de coisa que sai espelhada e
ninguém nota até reparar que só os tons médios estão errados.

### Partículas

Flipbooks em grade, consumidos por `BILLBOARD_PARTICLES` com
`particles_anim_h_frames` / `_v_frames`.

| Arquivo | Dimensão | Grade | Nota |
| --- | --- | --- | --- |
| `fumaca_flipbook.png` | 256×128 | 4×2, quadros de 64² | Alfa macio — é o único lugar onde macio é certo |
| `fogo_flipbook.png` | 256×128 | 4×2, quadros de 64² | Serve de albedo **e** de emissão |
| `poeira_flipbook.png` | 128×32 | 4×1, quadros de 32² | Mais opaca e mais terrosa que a fumaça |
| `faisca.png` | 8×8 | — | Núcleo branco. A cor vem do `color_ramp`, não da textura |
| `marca_pneu.png` | 32×128 | — | Para `Decal`. **Não pode ser `AtlasTexture`** — o `Decal` recusa (verificado) |

### O ator

Rota B, que é a recomendada pelo estudo: modelo 3D em tempo real, digitalizado
pelo pós-processamento.

| Arquivo | Orçamento | Formato | Nota |
| --- | --- | --- | --- |
| `entregador.glb` | 800–1500 tris | glTF binário | Piloto + moto + bag, **uma pose parada**. Sem rig na prova |
| `entregador_albedo.png` | 256×256 | RGB | Pintado, não fotografado. A "cara de foto" vem da luz e do LUT |
| `entregador_mascara.png` | 256×256 | RGB | R = bag, G = jaqueta, B = moto. É a troca de paleta dos rivais |

Se a rota A for escolhida em vez desta, o manifesto muda para dois atlas de
4096×4096 (albedo e normal) mais a máscara, saídos do lote do Blender — e a
matriz de quadros está dimensionada no `DIRECAO_VISUAL.md`. **A prova não
precisa dessa decisão fechada**: ela testa a rota B, que é a mais barata de
montar, e se o resultado não convencer, a rota A continua disponível com tudo o
mais já pronto.

### HUD

| Arquivo | Formato | Nota |
| --- | --- | --- |
| `fonte_hud.ttf` | TTF pixel-perfect | Caminho de menor atrito. `FontFile` com `antialiasing`, `hinting` e `subpixel_positioning` **desligados** |
| `fonte_hud.fnt` + `.png` | BMFont | Alternativa, via `FontFile.load_bitmap_font()` (verificado). Só se o TTF não der pixel exato |

Escolher **um** dos dois. A fonte precisa de duas medidas legíveis a 640×360:
uma grande para número (velocidade, posição) e uma pequena para legenda.

### As referências

| Arquivo | Nota |
| --- | --- |
| `docs/referencias/*.png` | **As quatro imagens entram no repositório.** A prova compara contra elas; comparação contra arquivo que mora no chat de alguém não é reproduzível |

**Pendente, e é a única linha do manifesto que não pode ser produzida por quem
executa o plano:** as quatro imagens chegaram anexadas numa conversa, não como
arquivo no disco. Elas precisam ser salvas em `docs/referencias/` por quem as
tem. Até isso acontecer, a P9 não tem contra o quê comparar — e o critério de
pronto deste plano inteiro depende delas.

Nomear `01_centro.png`, `02_praca_maua.png`, `03_viaduto.png`,
`04_vertical.png`, para que o texto possa citar uma imagem específica sem
ambiguidade.

## A armadilha de importação que estraga tudo em silêncio

Verificado no `icon.svg.import` deste repositório: o padrão do Godot é
**`detect_3d/compress_to=1`**.

O que isso faz: no instante em que uma textura é usada num material 3D pela
primeira vez, o editor a **reimporta sozinho** com compressão VRAM. Em arte
com borda dura isso produz artefato de bloco justamente na borda — e a borda
dura é o pilar 2 inteiro. Ninguém é avisado, o arquivo fonte não muda, e o
sintoma é "o sprite ficou sujo e eu não mexi nele".

Para toda textura de arte deste projeto:

```
compress/mode=0            # Lossless
detect_3d/compress_to=0    # Desabilitado - a linha que importa
mipmaps/generate=true      # SIM: sprite ao longe cintila sem mipmap
process/fix_alpha_border=true
```

Dois desses contrariam o instinto e merecem a justificativa:

- **`mipmaps/generate=true`** parece errado em pixel art, e é certo aqui: um
  rival a 70 m ocupa 10 px de um sprite desenhado para 100. Sem mipmap isso
  cintila a cada quadro, e cintilação denuncia pixel art falsa mais rápido que
  qualquer borrão. A nitidez que se perde é ao longe, onde ninguém olha.
- **`fix_alpha_border=true`** (que já é o padrão) vaza cor para dentro do pixel
  transparente. Sem isso, o alfa-scissor deixa auréola escura em volta da
  silhueta.

O filtro (`NEAREST_WITH_MIPMAPS`) é propriedade do **material**, não da
importação. Confundir os dois é a segunda armadilha da mesma família.

## As tarefas

Ordem por dois critérios: o que não precisa de asset vem antes do que precisa,
e o que pode invalidar as outras vem antes das outras.

Cada tarefa tem **aceite verificável**. Nenhuma está pronta sem ele.

### P0 — Congelar o quadro de comparação

**Sem asset.** Um comando `python tools/dev.py prova` que renderiza um conjunto
fixo de quadros para `.dev/prova/`: mesma semente, mesmo trecho de pista, mesma
posição de câmera, mesmo instante — com o trânsito em posição determinística e
não onde ele calhou de estar.

Por que primeiro: sem quadro congelado, toda comparação é contra um print
diferente, e "melhorou?" deixa de ter resposta. É o mesmo raciocínio que fez o
banco de provas fixar a semente.

Sai junto o `dev.py fps`, que o `DIRECAO_VISUAL.md` já propõe como Fase 0.

*Aceite:* rodar duas vezes seguidas produz PNGs visualmente idênticos, e o
comando roda nos três sistemas.

### P1 — Resolução

**Sem asset.** `PIXEL_SHRINK = 2`, `scale_mode = integer`, HUD reposicionada
para 640×360, os treze arquivos de prosa revisados, baseline visual atualizado
no mesmo commit com o motivo.

*Aceite:* portão verde; `fps` registrado; janela em 1600×900 com tarja em vez
de pixel irregular.

### P2 — Luz, sombra e céu

**Sem asset** (`ProceduralSkyMaterial` é procedural; a textura de nuvem entra na
P4). Sombra do sol com `max_distance` casando com a neblina, `cast_shadow` por
mesh, ambiente vindo do céu.

Vale notar o que se ganha de graça: com `AMBIENT_SOURCE_SKY`, a sombra fica
azul porque o céu é azul, sem ninguém escolher cor de sombra.

**Junto, e não depois: medir o novo piso de ruído do portão visual**, quatro
rodadas do mesmo código, do jeito que foi feito quando a tolerância subiu de
12% para 20%. Se a variância comeu a margem, decidir aqui — e não no dia em que
o portão reprovar um commit de markdown.

*Aceite:* a moto tem sombra de contato que acompanha a ladeira; variância
medida e registrada; tempo do job `regressao-visual` no CI anotado.

### P3 — Paleta

**Assets:** `lut_dia.png`, `bayer4.png`.

Tonemap, LUT e o passe de quantização + dither, nessa ordem e com o dither por
último. É a tarefa mais barata e a de maior retorno por hora do plano inteiro.

**Nenhuma textura de arte deve ser pintada antes desta tarefa.** Pintar antes
do LUT existir é corrigir cor à mão para o LUT corrigir de novo depois — e aí
não se sabe mais qual dos dois está errado.

*Aceite:* o mesmo quadro da P0, antes e depois, lado a lado.

### P4 — Textura no mundo

**Assets:** todo o bloco "Mundo — texturas", `carro.glb`, `onibus.glb`,
`ceu_nuvens.png`.

A pista deixa de ser cor chapada, os prédios ganham fachada, os muros ganham
mural, entram placa verde e contêiner. O trânsito troca caixa por modelo.

*Aceite:* o quadro da P0 tem densidade comparável à referência — não detalhe
comparável, que é foto, mas **quanta coisa entra no quadro**.

### P5 — O ator

**Assets:** `entregador.glb`, `entregador_albedo.png`,
`entregador_mascara.png`.

O ponto de troca já está nomeado no `PROTOTIPO.md`: o nó `Visual` de
`player_bike.gd` e `rival_bike.gd`. Uma pose parada basta para a pergunta.
Rivais entram pela máscara de paleta.

Se a pose convencer, ligar a cadência travada em 12 fps antes de julgar: é ela
que faz o ator ler como digitalizado em vez de como 3D, e ela não aparece em
print — só em movimento.

*Aceite:* julgado **rodando**, não em captura. Print de ator parado engana.

### P6 — Partículas

**Assets:** todo o bloco de partículas.

O catálogo do `DIRECAO_VISUAL.md`, nos gatilhos que já existem no código.
Aqui se confirma na prática se `GPUParticlesCollisionHeightField3D` enxerga
mesh sem colisor — e, se não enxergar, entra a alternativa já desenhada.

*Aceite:* cada efeito dispara no evento certo; `fps` medido no **pior caso**
(queda no meio do trânsito), não no caso bom.

### P7 — Borrão

**Sem asset.** Testar primeiro as linhas de velocidade, que custam quase nada.
Só investir no shader radial com máscara de profundidade se elas não
resolverem.

*Aceite:* a 180 km/h a periferia borra e o piloto continua nítido.

### P8 — HUD

**Assets:** a fonte escolhida.

Redesenhar para 640×360 seguindo o vocabulário das referências: legenda
pequena amarela, número grande branco, contorno duro, barra segmentada.

*Aceite:* legível a 640×360 sobre asfalto claro, que é o pior fundo.

### P9 — O veredito

Montar a folha de comparação: quadro do jogo ao lado da referência, e a
pergunta feita a alguém de fora.

*Aceite:* a resposta escrita neste documento, com a data. Sim ou não, as duas
são resultado.

## Quando parar

Critérios de abandono, definidos agora porque depois todo mundo está apaixonado
pelo trabalho já feito:

- **Se depois da P2 e da P3 a imagem não andou de forma óbvia**, o problema não
  é iluminação nem paleta — é densidade de cenário, e o plano está atacando a
  coisa errada. Parar e repensar antes de produzir um único asset da P4.
- **Se o `fps` na máquina de desenvolvimento não segurar 60 na P2**, a decisão
  de resolução volta à mesa antes de qualquer arte ser pintada.
- **Se a variância do portão visual comer a tolerância na P2**, resolver o
  portão em PR próprio antes de seguir. O `CLAUDE.md` é explícito: vermelho que
  se acredita ser instabilidade do portão é bug de portão, e conserta-se o
  portão primeiro.
- **Se a P5 não convencer nem na rota B nem na rota A**, a resposta da prova é
  *não*, e ela vale tanto quanto um sim.

## O que a prova não responde

- **Se o jogo inteiro fica assim.** Ela prova um trecho, uma hora do dia, um
  ator. Escala é outro problema, e um problema melhor de se ter.
- **Se a arte é boa.** Ela prova que a técnica alcança a referência. Se o mural
  é bonito é outra conversa.
- **Quanto tempo a produção inteira leva.** O que ela dá é a base para estimar,
  porque no fim dela existe um asset de cada tipo, com o tempo real de cada um
  anotado.
