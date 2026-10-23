# Criação de personagens e sprites no Gemini / Google Flow

Para criar outro personagem do início à integração no jogo, siga primeiro o
[procedimento de produção](../../../docs/PERSONAGENS.md). As regras de design
abaixo valem tanto para esse fluxo por vídeo quanto para refações por folha.

## Regra principal: desenhar para espelhar

Novos personagens e refações devem permitir reaproveitar uma animação para os
dois lados por espelhamento horizontal. O pipeline de pedestres já faz isso:
gera o lado direito e obtém o esquerdo por espelho. O desenho do personagem
não pode exigir uma segunda geração só para preservar um detalhe lateral.

Esta regra vale para o **design**, não para a pose: braços e pernas alternam
normalmente na caminhada. Frente e costas continuam sendo vistas distintas;
espelhar a frente não produz as costas. A simetria também não substitui poses
ou ações diferentes.

### O que pode e o que não pode

| Elemento | Regra e motivo |
| --- | --- |
| Roupa | Mesma manga, cor, comprimento e acabamento nos dois lados. Proibidos camisa ou toalha num ombro, manga única e peça amarrada de lado: trocariam de lado no espelho. |
| Bolsas e objetos | Sem bolsa lateral, sacola, ferramenta na mão ou alça diagonal. Se necessário à identidade, usar mochila centralizada, com duas alças iguais e desenho simples. |
| Cabelo e cabeça | Cabelo curto ou preso ao centro; boné e capacete simples e centralizados. Sem trança lateral, franja marcadamente lateral ou enfeite de um lado só. |
| Detalhes pessoais | Sem tatuagem, cicatriz, brinco, relógio, pulseira, bolso destacado ou joelheira exclusivos de um lado. Não estabelecer mão dominante como traço do personagem. |
| Estampas | Preferir áreas grandes de cor lisa. Sem texto, números, letras, logos, símbolos direcionais ou estampas complexas: invertem no espelho ou variam entre quadros. |
| Pontas e peças soltas | Sem lenço, cordão pendurado, corrente, franja de roupa ou cabelo longo solto. Cada peça móvel cria outra continuidade para a IA manter. |
| Materiais | Preferir roupa opaca e fosca. Sem transparência, reflexos de espelho ou brilho forte que mude a aparência entre quadros. |
| Luz | Frontal, difusa e neutra, sem destaque de um lado e sem sombra projetada incorporada ao sprite. O espelho não deve inverter uma luz lateral evidente. |

A identidade vem da silhueta, idade aparente, porte, rosto, tom de pele,
penteado simples e combinação de cores. Personagens podem ser diferentes sem
acumular acessórios. Uma bolsa lateral indispensável exige redesenhar o
conceito antes de produzir as animações; não abrir uma série extra de folhas
para contornar o problema.

### Processo obrigatório

1. **Definir a identidade.** Descrever corpo, cabelo, roupas e cores de forma
   curta e inequívoca. Remover tudo que viole a tabela antes de gerar imagens.
2. **Gerar e aprovar o turnaround.** Frente, perfil direito e costas, mesma
   pessoa, roupa, proporções, escala e iluminação. Inspecionar também uma
   cópia espelhada do perfil: deve funcionar como o perfil esquerdo sem
   corrigir acessórios, letras ou roupa.
3. **Testar a caminhada.** Usar o turnaround aprovado e, no fluxo por folhas,
   a folha de poses. No fluxo por vídeo, manter câmera fixa, caminhada no
   lugar e um ângulo por vídeo, conforme a [receita do experimento](../sem_referencia/README.md).
   Conferir o ciclo normal e espelhado antes de produzir as outras ações.
   Reprovar mudança de identidade, escala, roupa, ângulo ou anatomia.
4. **Produzir as demais ações.** Reutilizar o mesmo turnaround aprovado em
   todas elas. Não pedir ao modelo que reinvente o personagem a cada folha.
   Manter a grade e os ângulos previstos pelo pipeline; não gerar esquerda
   adicional para resolver assimetria.
5. **Validar a folha e o atlas.** Conferir contagem e ordem dos quadros,
   silhuetas separadas e completas, fundo uniforme, continuidade das poses e
   escala estável. A caminhada precisa fechar o ciclo; queda e voo precisam
   mostrar o corpo deitado ou girando conforme a referência, não em pé.
6. **Conferir no jogo.** Examinar animações nos dois sentidos e nas vistas de
   frente, perfil e costas. Aprovar na escala de uso, não só no JPG ampliado.

Fundo de recorte não pode aparecer na roupa ou nos acessórios. Usar verde
puro só quando o personagem não tiver verde; caso contrário, escolher o fundo
alternativo e conferir a compatibilidade com o recortador antes da produção.
O recortador atual de pedestres remove verde: mudar apenas o prompt não basta.

### Bloco obrigatório nos prompts de personagem e animação

Somar ao pedido de identidade ou ao prompt de poses abaixo. Em refações,
primeiro aprovar uma referência já simplificada: uma imagem antiga com bolsa
lateral contradiz este bloco.

```text
Design for horizontal mirroring: the right-facing animation will also be
used facing left by flipping the image. Keep the character's design
bilaterally symmetric, while allowing natural asymmetric walking poses.
Use simple solid-color opaque matte clothes, matching sleeves and shoes,
and short or centrally tied hair. No one-sided accessories, shoulder-draped
clothes, side bags, crossbody straps, handheld props, watches, unilateral
markings, side ponytails, text, letters, numbers, logos or directional
symbols. If a backpack is specified, keep it centered with two matching
straps and no dangling parts. Use soft neutral frontal studio lighting,
no strong side lighting, no cast or ground shadows. Preserve the approved
character's face, proportions, clothes and colors in every frame and view.
Front and back are distinct views; mirroring must only supply the opposite
horizontal direction, never replace a required back view.
```

## Folhas de pose

Geradas por `python tools/dev.py boneco` (`arte/boneco_flow.gd`): o `Pessoa` do
jogo, posado pelo mesmo código que o anima, num manequim cinza. São referência
de **pose e ângulo**; quem a pessoa é vem da folha de personagem (turnaround).

Suba duas imagens no Flow, nesta ordem: **1) a folha de pose, 2) o turnaround
do personagem**.

**Folhas de antes de 18/10/2026 vieram de referência embaralhada.** O
`_physics_process` do `Pessoa` seguia rodando durante a captura, e cada coluna
saía com a pose de um instante qualquer: o ciclo de andar abria e fechava fora
de ritmo e o susto piscava. As 25 folhas de `arte/flow/pedestres/` foram
refeitas nesse dia a partir das referências certas (`docs/AUDITORIA_SPRITES.md`,
S06), com o prompt da seção *Leva de 18/10/2026*, abaixo. A referência hoje é
determinística: rodar `dev.py boneco` duas vezes dá o mesmo PNG.

## Prompt genérico

```
Image 1 is a pose reference sheet: a grid of gray mannequin figures on a green background. Image 2 is a character turnaround sheet (front, side, back) of the person to draw.

Redraw the grid of Image 1 exactly: same number of rows and columns, same order, same pose in every cell, same camera angle in every cell, same cell layout and same scale. Replace each gray mannequin with the character from Image 2, keeping face, hair, skin tone, body proportions, clothes, colors and accessories identical in every single cell, as if it were the same real person photographed in each pose.

The mannequin is only a pose guide: do not copy its blocky shapes, its gray color or its flat clothing. Limbs must look like a real person's limbs, with natural thickness and clothing that folds and moves with the pose. The small nose on the mannequin only marks which way it faces: where the nose is visible, draw the face; where it is not, draw the back of the head. Use Image 2 for the correct view of each side.

Style: photorealistic person posterized to a small flat color palette, like a digitized 1990s arcade game sprite (Road Rash 3DO, Mortal Kombat digitized actors). NOT pixel art, no visible square pixels. Hard clean edges, no soft gradients, no blur, no glow. Flat even studio lighting from the front-top, identical in every cell, no cast shadows, no ground shadow.

Background: plain solid pure green (#00FF00), with no grid lines, no cell borders, no text, no labels, no watermark. Keep clear green space between figures so no two figures touch or overlap.

The output must have exactly R rows and C columns.
```

Troque `R` e `C` pelo tamanho da folha. Personagem de fundo cinza: troque o
verde por `light flat gray (#C8C8C8)`.

## Por folha

| Folha | Linhas × colunas | Acrescente ao prompt |
| --- | --- | --- |
| `parada` | 5 × 4 | Só o balanço de peso: quase não muda de um quadro para outro. |
| `andando` | 5 × 8 | Ciclo de dois passos; frente e costas quase não mostram a perna. |
| `susto` | 3 × 6 | Pulo de susto: o corpo sai do chão, os pés podem ficar no ar. |
| `voando` | 4 × 8 | Corpo girando solto no ar, de cabeça para baixo em alguns quadros. Não é para ficar em pé. |
| `caida` | 4 × 3 | Deitado de bruços no chão, cabeça para a direita na primeira linha. |
| `desembarcando` | 4 × 8 | O bloco escuro é o banco do carro: desenhe um banco de carro comum no lugar. Do quadro 4 em diante a pessoa já está de pé e o banco some. |

A linha de ângulos de cada folha está em `arte/boneco_flow.gd` (`FOLHAS`).

## Refação dos quatro NPCs

Registro histórico das folhas existentes, anterior às regras acima. Bolsas,
estampas e crachás descritos abaixo não são autorização para repeti-los em
novas gerações. Ao refazer esses personagens, simplificar e aprovar primeiro
o turnaround conforme o processo acima. As imagens existentes não foram
alteradas por esta definição de regras.

As 16 folhas de `vovo`, `obra`, `adolescente` e `escritorio` para `susto`,
`desembarcando`, `voando` e `caida` foram refeitas por edição de imagem. Em cada
uma, a folha `praia_<animacao>.jpg` serviu de referência para pose, enquadramento
e acabamento; a folha `<personagem>_andando.jpg` serviu de referência para a
identidade visual. Os JPGs finais estão em `arte/flow/pedestres/` e também foram
enviados ao projeto **NumFood NPCS** no Flow. O atlas transparente e o JSON de
cada animação são gerados com `python3 tools/dev.py sprites-pedestres` no macOS.

Prompt-base da refação (substituir os nomes entre colchetes):

```
Edit the existing [praia_animation] sprite sheet. Preserve its exact grid,
row and column order, individual poses, camera angles, figure spacing and
solid pure green (#00FF00) background. Replace the beach man in every cell
with the same [character] shown in [character_andando]. Keep the face, hair,
skin tone, body proportions, clothes, colors and accessories consistent in
every frame, including rear and upside-down views. Match the source sheet's
crisp, high-contrast, posterized photographic rendering: a digitized 1990s
arcade actor, clean hard silhouettes, no pixel blocks, blur, glow, cast
shadows, text, borders, cropped limbs or overlapping figures. Output exactly
the original number of rows and columns.
```

| ID | Identidade que deve persistir em todos os quadros |
| --- | --- |
| `vovo` | Cabelo branco curto, cardigan creme, vestido estampado, bolsa marrom e sandálias. |
| `obra` | Pele negra, capacete amarelo, camisa laranja, calça cinza e botas pretas. |
| `adolescente` | Boné vermelho para trás, camiseta branca, bermuda jeans, tênis pretos e mochila escura. |
| `escritorio` | Cabelo preto preso, blazer cinza, camisa branca, saia preta, sapatos pretos, bolsa e crachá. |

## Leva de 18/10/2026

Como as 25 folhas atuais foram feitas, no projeto **NumFood NPCS**, com Nano
Banana 2.1, uma imagem por vez:

- **Imagem 1:** a referência (subida como `ref2_<animacao>.png`).
- **Imagem 2:** a folha de andar antiga do personagem (`id_<pessoa>.jpg`), só
  pela identidade. O prompt diz para ignorar a pose dela; mesmo assim, numa
  folha de queda ela vazou como figuras de pé, meio transparentes. Refeita com
  a folha de voo nova do mesmo personagem como identidade, saiu limpa.
- **Proporção:** 1:1 no andar, 4:3 no susto e na queda, 16:9 no voo e no
  desembarque. Em 16:9 o susto saía com 8 colunas em vez de 6.
- **Contagem por extenso** no prompt ("exactly 6 figures in each row and 18
  figures in total, never more"). Sem isso o Flow acrescenta colunas.
- **Baixar em 2K** ("Baixar mídia", 2K): o 1K original é pequeno para os
  100 px/m do recorte.

O prompt, trocando a descrição do personagem e o miolo de cada animação:

```
Image 1 is a pose reference sheet: a grid of R*C gray mannequin figures on a
green background, R rows by C columns. Image 2 shows the character to draw
(<descrição>); use Image 2 ONLY for the identity, clothes, colors and
rendering style, and ignore its poses and its grid. Redraw the grid of Image 1
exactly: same R rows and C columns, exactly C figures in each row and R*C
figures in total, never more; same order, same pose in every cell, same camera
angle in every cell, same scale. <miolo da animação> The small nose on the
mannequin marks which way it faces: where the nose is visible draw the face,
where it is not visible draw the back of the head. Replace each mannequin with
the character from Image 2, identical in every cell, as if it were the same
real person photographed in each pose. Style: photorealistic person posterized
to a small flat color palette, like a digitized 1990s arcade game sprite (Road
Rash 3DO). NOT pixel art. Hard clean edges, no blur, no glow. Flat even studio
lighting from the front-top, identical in every cell, no cast shadows, no
ground shadow. Background: plain solid pure green (#00FF00), with no grid
lines, no borders, no text, no labels. Keep wide clear green space between
figures so no two figures touch or overlap. The output must have exactly R
rows and C columns: R*C figures.
```

O miolo de cada uma (o texto inteiro de cada prompt está no histórico do
projeto no Flow):

| Folha | Miolo |
| --- | --- |
| `andando` | Cada linha é um ângulo e um ciclo de dois passos em 8 quadros (junto, meio, aberto, meio, junto com o outro joelho, meio, aberto, meio); copiar a abertura e o joelho de cada boneco; linhas 4 e 5 nunca mostram o rosto. |
| `susto` | Pulo de susto em 6 quadros (em pé, sobe, topo, desce, aterrissa, olha); onde o boneco está no ar, o personagem está no ar na mesma altura. |
| `caida` | Deitado de bruços nas 12 células, nunca em pé, sentado ou de joelhos, e nenhuma pessoa de pé na imagem. |
| `voando` | Atropelado, girando no ar; só a coluna 1 está em pé; copiar a rotação de cada célula. |
| `desembarcando` | O bloco é um banco de carro; da coluna 5 em diante não há banco; "4 sentados e depois 4 em pé, nunca 9 por linha". |

O recorte (`dev.py sprites-pedestres`) confere a grade de todas e lista de uma
vez as que vieram com a contagem errada: refaça só essas.

## Moto (2D10 em diante)

As folhas da moto (`dev.py boneco moto`, `arte/flow/referencia/moto/`) saem do
Flow como as da pessoa, com duas diferenças. A **identidade** não é um
turnaround novo: é o do entregador que já existe no projeto *sprites from
reference* (`Delivery driver character...`, de frente, de lado e de costas),
e a moto é a CG. E o **fundo e a grade** são os mesmos, mas a contagem por
extenso importa mais: 5 colunas passam, 9 não.

Como a CG pilotando e parado foram feitas (23/10/2026), com Nano Banana 2.1,
16:9, x1, uma imagem por vez, baixadas em 2K:

- **Imagens:** o turnaround do entregador e a folha de pose do `boneco moto`
  (`cg_pilotando.png` ou `cg_parado.png`). A ordem entre elas não importa se o
  prompt as descreve pelo conteúdo ("a grid of gray mannequins" e "a turnaround
  of the delivery rider"), e não por "Image 1" e "Image 2".
- **Prompt:** o *Prompt genérico* acima, com a contagem por extenso (`exactly 5
  figures in each row and 15 figures in total`), o ângulo de cada linha
  (costas, 3/4 de costas, lado direito) e a inclinação ao longo da linha. Em
  `cg_parado`, a pose de cada coluna: pé no chão nas colunas 1 a 3 e empinada
  na 4. Diga que o bloco cinza sob o pé é só marcador de chão: sem isso o Flow o
  desenha.
- **Cor da moto:** diga a cor ("dark gunmetal gray and black"). Sem dizer, a
  moto muda de uma folha para outra: a de parado veio vermelha e foi corrigida
  com uma edição (a instrução de pintar a moto, mantendo grade e poses), que
  manteve a grade.
- **Ficha:** `arte/flow/fichas/cg_pilotando.json` e `cg_parado.json`
  (`dev.py recortar cg_pilotando cg_parado`): celula 270 x 240, `pe_y` 220,
  `altura_m` 1,5 a 100 px/m, `escala: altura`, `ancora_x: centro`,
  `ancora_y: chao` (a empinada tem o pneu da frente no ar; o chão é o da
  linha, e não o ponto mais baixo).
- **Como subir arquivo no Flow pelo Chrome:** o botão "Enviar mídia" abre o
  seletor nativo, que o agente não enxerga. Troque `HTMLInputElement.prototype
  .click` por uma função que anexa o `<input type=file>` ao `body` sem abrir o
  seletor, clique no botão, ache o campo e use `file_upload` nele.
- **Identidade: o turnaround, e não uma folha de grade pronta.** Na 2D11, dar
  de identidade a folha de 5 colunas da CG pilotando fez o Flow desenhar 5
  colunas também na de combate (que pedia 6). O turnaround, que não é grade, e
  o prompt dizendo a cor da moto não têm esse viés. Diga também o número de
  colunas por extenso e o que é cada grupo ("columns 1, 2 and 3 are the left
  arm punch").
- **`vao`:** as motos de lado quase se encostam na folha de 2K, e `vao` 24
  juntava duas (`[6, 6, 5]` em vez de 3 × 6). `cg_combate` e `cg_golpe` usam 8.
