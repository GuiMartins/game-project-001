# Folhas de pose para o Google Flow

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
