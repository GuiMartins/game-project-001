# Fichas de recorte

Uma ficha por folha do Flow. `python3 tools/dev.py recortar [nome]` lê
`<nome>.json` desta pasta, recorta a folha de `fonte` e grava o atlas e a ficha
dele em `saida` (`.png` e `.json`). Folha nova entra com uma ficha, e não com um
script: o recorte é o mesmo de `arte/recorte_de_folha.gd`, que o piloto
(`sprites_flow.gd`) e os pedestres (`sprites_pedestres.gd`) também usam.

| Campo | O que diz |
| --- | --- |
| `fonte` | A imagem do Flow, `res://arte/flow/...jpg`, em fundo verde. |
| `saida` | O prefixo do que sai, sem extensão: `res://assets/sprites/...`. |
| `linhas` | O nome de cada linha (ângulo ou pose). O tamanho é o da grade. |
| `colunas` | Desenhos por linha. O Flow erra a conta: se a folha não bate com a grade, o recorte reprova e diz o que achou. |
| `celula` | `[largura, altura]` de cada quadro do atlas, em pixels. |
| `pe_y` | Onde fica o chão na célula, de cima para baixo. O x do pé é o meio. |
| `altura_m`, `pixels_por_metro` | O tamanho real do que se desenha e a medida comum de todas as folhas. Sem ela o sprite muda de tamanho na troca de folha. |
| `escala` | A medida que não muda com a pose: `altura` (mediana), `altura_alta` (quartil de cima, para quem se senta), `coluna_zero` (o primeiro quadro) ou `comprimento` (largura do corpo deitado; pede `medir_linhas`). |
| `ancora_x` | `tronco` (o terço de cima do desenho, que não anda com a perna) ou `centro`. |
| `ancora_y` | `pes` (o ponto mais baixo no chão), `chao` (a linha do chão da linha da folha; quem pula fica acima) ou `centro`. |
| `vao`, `area_minima` | O que separa dois desenhos, em pixels da folha, e o que é sujeira do JPEG. |
| `margem_verde` | Opcional, 40: quanto o verde passa os outros canais para ser fundo (cor-chave). |
| `espelho` | Opcional: o lado esquerdo sai por espelho do direito. Vai para o `.json` do atlas. |
| `luzes` | Opcional: `{"nome", "linha", "coluna", "ponto": [x, y]}` em pixels da célula, e opcionais `raio` (px, 6), `cor` ([r, g, b]) e `so_de_noite` (verdadeiro: o farol e a lente de poste; o freio é falso). O `sprite.gdshader` acende o brilho por cima (`SpriteLuzes`). O recorte só confere que o ponto cai na célula e o repassa. |

| `por_manchas` | Opcional. `true` separa as figuras de uma linha pelo verde entre elas (figuras que se sobrepõem na horizontal), e `"folha"` acha todas na folha inteira e as agrupa em linhas (linhas que se encostam na vertical). |
| `descarta_linhas` | Opcional: `[indice, ...]` de linhas que o Flow acrescentou e que não pertencem à grade (a folha da porta do hatch veio com duas linhas de costas); saem antes da conferência da contagem. |
| `espelha_quadros` | Opcional: `[[linha, coluna], ...]` de quadros que o Flow desenhou virados para a esquerda; o recorte os vira. A moto de toda folha aponta para a direita. |
| `placa` | Opcional, só para moto: acha a chapa branca em cada quadro de costas e de 3/4 de costas, deixa-a lisa e grava o quadrilátero no `.json` do atlas (`PlacaSprite`, 2D16). |

Luz não é desenho: lanterna, farol, lente e janela são coordenadas aqui, e não
uma camada pedida ao Flow, que nunca cai no mesmo pixel da folha de base.

O que ainda não é ficha: a regra própria do piloto (ângulo desenhado,
`sprites_flow.gd`) e dos pedestres (a ordem da passada e os reparos de quadro,
`sprites_pedestres.gd`). Esses chamam a biblioteca e acrescentam só a regra.
Os props (`sprites_props.gd`) têm outro corte de fundo e uma imagem por prop,
e seguem à parte.
