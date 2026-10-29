# Props no Flow: árvore, palmeira, poste e placas

Fonte dos sprites de `assets/sprites/props/` (2D50, 2D51 e 2D53 da
[fila 2D](../../../docs/MIGRACAO_2D.md)). Um `.jpg` por prop, de frente, em
verde `#00FF00`; `python3 tools/dev.py sprites-props` tira o verde, leva a
altura para a medida real e grava `.png` + `.json` (pé e `pixels_por_metro`).

## Receita

Projeto no Flow: <https://flow.google.com/project/a4e0a720-2ee4-4336-a527-c9e88cbdf0ce>,
imagem com Nano Banana 2.1, 1:1, tamanho original (1K).

**Anexar a referência visual (`docs/referencias/01_centro.png`) e dizer "o
mesmo estilo de render dela" é o que importa.** A primeira leva, só com
descrição ("16-bit pixel art"), saiu cartunesca e destoou do jogo, que é
*pixel realista* (render pintado, o pixel vem do `paleta.gdshader`); e a
segunda, "fotorrealista" sem referência, saiu recorte de foto. Com a imagem
anexa, cada prompt segue este molde, trocando só o objeto:

```text
Same reference image and same exact rendering style as the previous sprites.
Generate one image: <objeto, apontando onde ele aparece na referência>, isolated
as a game sprite, painterly photoreal slightly-pixelated 16-bit texture. Front
view at eye level, centered, whole object in frame with margin. No cast shadow,
no ground, no text. Background: uniform flat pure chroma-key green (#00FF00).
Aspect 1:1.
```

O recorte só entende verde puro: nada de verde-chroma na arte (folha de árvore
é segura, a franja do JPEG é tratada em `_limpar_borda`).

| Arquivo | Objeto | Altura real |
| --- | --- | --- |
| `copa.jpg` | árvore de copa larga (figueira/amendoeira) | 8 m |
| `palmeira.jpg` | palmeira-imperial | 11 m |
| `poste.jpg` | poste ornamental de dois braços, lente apagada | 8,5 m |
| `placa_curva.jpg` | losango amarelo, curva à esquerda; a da direita sai do espelho | 3,2 m |
| `placa_mao_dupla.jpg` | losango amarelo, duas setas opostas | 3,2 m |

| `cacamba.jpg` | caçamba de entulho, 3/4 | 1,8 m |
| `mupi.jpg` | mupi com o painel apagado (acende por coordenada) | 2,4 m |
| `semaforo.jpg` | semáforo de esquina, lâmpadas apagadas | 4 m |
| `portico_semaforo.jpg` | braço de semáforo suspenso | 7 m |
| `portico_placa.jpg` | pórtico da placa verde, sem texto; **fundo magenta** | 8 m |
| `chegada_arco.jpg` | arco da chegada, faixa branca em branco | 7 m |
| `chegada_barreira.jpg` | barreira de plástico vermelha e branca | 1 m |
| `canteiro.jpg` | canteiro da praça; **fundo magenta** | 2 m |

Objeto que é verde (a placa) ou cheio de planta (o canteiro) sai em magenta
`#FF00FF`: a ficha leva `"fundo": "magenta"` e o recorte troca de chave.

Upload de referência pela automação do Chrome: o botão "Enviar mídia" abre o
seletor nativo; intercepte `HTMLInputElement.prototype.click` para capturar o
`<input type=file>` e use `file_upload` nele.

No Flow o `+` do prompt abre a biblioteca: digitar `01_centro` na busca e clicar
no resultado anexa a referência, sem seletor nativo. O botão de baixar de cada
imagem grava em `~/Downloads`. O prompt é enviado com Enter.
