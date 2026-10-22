# NPC por vídeo no Flow: moça de moletom

Para **criar outro personagem**, use [docs/PERSONAGENS.md](../../../docs/PERSONAGENS.md)
e `python3 tools/dev.py personagem`. Esta pasta preserva a receita histórica
da moça, incluindo seu formato de oito linhas e suas limitações.

Receita do experimento de 19–20/10/2026, recuperada do Flow em 21/10/2026.
A sexta pessoa do jogo foi gerada sem manequim 3D: turnaround por texto,
um vídeo de caminhada por ângulo e montagem local do atlas.

**Reprodução verificada:** os MP4 preservados nesta pasta, processados pelo
montador corrigido, produzem o mesmo atlas do jogo, com **zero pixels
RGBA diferentes** (1280 × 1600). Não é necessário acessar o Flow para refazer
o atlas. Gerar novos vídeos com os mesmos prompts é uma operação generativa
e não garante os mesmos pixels.

## Fontes preservadas

- [Projeto no Flow: out. 19 - 20:40](https://flow.google.com/project/3352bd67-4bd7-4758-9981-18be32310d75).
- [PROMPTS.md](PROMPTS.md): os 15 prompts completos, transcritos do histórico
  por **Reutilizar comando**, com links para cada recurso. Inclui dois
  turnarounds, cinco tentativas de folha por imagem e oito vídeos.
- [originais/](originais/): oito MP4 e dois JPG, sem recompressão, versionados
  em Git LFS. Os dois vídeos de três quartos com sufixo `_esq` são preservados
  como histórico, mas não entram na montagem atual.
- [manifesto.json](originais/manifesto.json): SHA-256, tamanho, link de origem
  e metadados técnicos dos dez arquivos, além do hash RGBA do atlas esperado.
- [montar_folha.py](montar_folha.py): código de recorte, seleção do ciclo,
  alinhamento e montagem.
- [Atlas do jogo](../../../assets/sprites/pedestres/moletom_andando.png) e
  [ficha JSON](../../../assets/sprites/pedestres/moletom_andando.json).

![Turnaround usado nos vídeos](originais/turnaround.jpg)

`turnaround.jpg` corresponde ao recurso **Woman character design sheet**
(`720f76df-0465-410e-8382-32ab71e67b7a`). A prévia do **Elemento** anexado ao
vídeo foi conferida visualmente contra este JPG. O outro resultado do mesmo
prompt, **Woman character design sheet views**, está preservado como
`turnaround_alternativo.jpg`; não deve ser confundido com a referência usada.

A exportação do projeto pelo menu **Mais opções → Baixar projeto** contém os
15 resultados de mídia em ZIP, mas não traz um manifesto de prompts. Por isso
os textos foram recuperados separadamente na interface. Não foi feita nenhuma
nova geração durante a recuperação.

## Refazer o atlas a partir dos vídeos salvos

Comandos a partir da raiz do repositório, em macOS/zsh. O script também aceita
caminhos absolutos e não depende do diretório de onde é executado.

Pré-requisitos: Python 3.12, FFmpeg no PATH e os objetos do Git LFS baixados.
A verificação usou Pillow 12.3.0, NumPy 2.3.5 e FFmpeg 9.0.2; conferir o
FFmpeg instalado com `ffmpeg -version` antes de comparar outra máquina.

```bash
git lfs pull --include='arte/flow/sem_referencia/originais/**,assets/sprites/pedestres/moletom_andando.png'
python3 -m venv .dev/venv-flow
.dev/venv-flow/bin/python3 -m pip install Pillow==12.3.0 numpy==2.3.5
.dev/venv-flow/bin/python3 arte/flow/sem_referencia/montar_folha.py \
  arte/flow/sem_referencia/originais \
  .dev/flow-moletom/reproduzido.png
```

O primeiro argumento é a **pasta dos MP4**, não a pasta de cache. Os nomes
precisam ser `frente.mp4`, `tres_quartos_frente.mp4`, `lado.mp4`,
`tres_quartos_costas.mp4`, `costas.mp4` e `lado_esq.mp4`. O script valida os
arquivos antes de começar. Os outros dois MP4 são dispensáveis para montar.

O cache padrão fica em `.dev/flow-moletom/`, na raiz deste repositório. Para
usar outro, passe `--cache /caminho/do/cache`. Cada vídeo tem um diretório
identificado pelo nome e SHA-256; substituir o vídeo não reutiliza quadros do
arquivo anterior. Cache e saída são gerados localmente, fora do versionamento.
Para auditar a extração do zero, use uma pasta de cache nova.

Compare o resultado sem substituir o atlas do jogo:

```bash
.dev/venv-flow/bin/python3 - <<'PY'
from pathlib import Path
import hashlib
import json
from PIL import Image

base = Path('arte/flow/sem_referencia')
manifesto = json.loads((base / 'originais/manifesto.json').read_text())
for recurso in manifesto['recursos']:
    arquivo = base / recurso['arquivo']
    assert hashlib.sha256(arquivo.read_bytes()).hexdigest() == recurso['sha256'], arquivo
novo = Image.open('.dev/flow-moletom/reproduzido.png').convert('RGBA')
atual = Image.open('assets/sprites/pedestres/moletom_andando.png').convert('RGBA')
assert novo.size == atual.size == tuple(manifesto['atlas']['dimensoes'])
assert novo.tobytes() == atual.tobytes(), 'O atlas mudou'
assert hashlib.sha256(novo.tobytes()).hexdigest() == manifesto['atlas']['sha256_rgba']
print('Fontes verificadas; atlas idêntico pixel por pixel.')
PY
```

Para visualizar a folha no testador:

```bash
python3 tools/dev.py sprites-ver --sprite moletom_andando
```

## Repetir a geração no Flow

1. Abrir o projeto pelo link acima. Para recuperar um texto, abrir a mídia,
   mostrar o histórico e escolher **Reutilizar comando**. O campo de edição
   mostra o texto completo, mesmo quando a prévia do histórico está truncada.
2. Para reconstruir a identidade, usar o prompt `turnaround` de
   [PROMPTS.md](PROMPTS.md), sem imagens de manequim. Para reproduzir o
   experimento com a identidade original, usar diretamente o JPG salvo.
3. Anexar **somente `originais/turnaround.jpg` como referência de personagem**
   a cada vídeo. Não usar o JPG alternativo nem as tentativas de folha como
   guia de pose. Usar os prompts completos de cada vista, começando por
   `lado`, depois `frente`, `costas` e os dois três quartos. Os pedidos `_esq`
   estão registrados para documentar a tentativa de preservar a bolsa.
4. Manter uma pessoa por vídeo, caminhada no lugar, corpo inteiro, câmera
   fixa, escala e chão constantes, fundo verde, sem cortes nem texto. Estes
   requisitos estão escritos nos prompts; conferir o resultado, pois a IA
   não os respeitou integralmente nas direções à esquerda.
5. Baixar **720p — Tamanho original**, renomear pelo ângulo e guardar numa
   pasta própria. Os arquivos recuperados têm imagem H.264 de 1280 × 720,
   24 fps, 240 quadros, cerca de 10 segundos e uma faixa AAC. O pedido de
   ausência de som não eliminou a faixa de áudio; o montador a ignora.
6. Montar com o script apontado para essa pasta e conferir o ciclo no
   testador, nos dois sentidos. Usar o manifesto existente só para comparar
   os originais; vídeos novos terão outros hashes.

**Limite do histórico recuperado:** a ficha do turnaround alternativo mostra
criação em 19/10/2026, **Nano Banana 2.1**, proporção **16:9**. A interface de
edição dos vídeos mostra hoje **Omni 1.1 Flash**, mas isso é o seletor atual
para editar, não comprova o modelo que gerou os MP4 em outubro. O modelo
original dos vídeos, seed e demais parâmetros internos não foram expostos no
histórico consultado e não são presumidos nesta receita. Para obter
exatamente o resultado aprovado, usar os arquivos preservados. A duração,
resolução e taxa acima foram medidas nos downloads, não inferidas do seletor.

## O que o montador realmente faz

Extrai todos os quadros com FFmpeg. Para achar um ciclo, compara imagens RGB
reduzidas a 160 × 90: busca o par mais parecido, com início a partir do índice
20 e período entre 28 e 40 quadros. Seleciona oito índices equidistantes do
ciclo; os índices abaixo são baseados em zero. Os arquivos extraídos pelo
FFmpeg começam em `f001.png`, portanto o índice 149 corresponde a `f150.png`.

| Vídeo | Início | Período | Índices selecionados |
| --- | --- | --- | --- |
| `frente` | 149 | 38 | 149, 154, 158, 163, 168, 173, 178, 182 |
| `tres_quartos_frente` | 181 | 34 | 181, 185, 190, 194, 198, 202, 206, 211 |
| `lado` | 138 | 38 | 138, 143, 148, 152, 157, 162, 166, 171 |
| `tres_quartos_costas` | 126 | 37 | 126, 131, 135, 140, 144, 149, 154, 158 |
| `costas` | 85 | 32 | 85, 89, 93, 97, 101, 105, 109, 113 |
| `lado_esq` | 166 | 32 | 166, 170, 174, 178, 182, 186, 190, 194 |

Remove o verde pela dominância do canal G e reduz sua contaminação nas bordas.
A escala sai da mediana da altura do corpo amostrada a cada oito quadros,
normalizada para 175 pixels; não é recalculada pela altura de cada pose.
Centraliza pelo centro horizontal dos 40% superiores do corpo e coloca o pé
mais baixo de cada quadro em `(80, 196)`. Redimensiona com Lanczos e corta o
alfa em 128 para obter borda dura. Cada célula mede 160 × 200; a folha final
é de oito linhas e oito colunas, com este mapeamento:

| Linha (índice zero) | Vista no atlas | Vídeo de origem | Espelho horizontal |
| --- | --- | --- | --- |
| 0 | Frente | `frente.mp4` | Não |
| 1 | Três quartos de frente | `tres_quartos_frente.mp4` | Não |
| 2 | Perfil | `lado.mp4` | Não |
| 3 | Três quartos de costas | `tres_quartos_costas.mp4` | Não |
| 4 | Costas | `costas.mp4` | Não |
| 5 | Três quartos de costas esquerdo | `tres_quartos_costas.mp4` | Sim |
| 6 | Perfil esquerdo | `lado_esq.mp4` | Sim |
| 7 | Três quartos de frente esquerdo | `tres_quartos_frente.mp4` | Sim |

A ficha JSON permanece a já versionada: altura 1,75 m, 100 pixels por metro,
oito colunas e oito vistas. O montador gera o PNG, não essa ficha. O shader
usa as oito linhas explícitas; isso **não** significa oito direções geradas
corretamente pela IA. O PNG já contém os espelhos nas três últimas linhas.

## Limitações do experimento e regra para personagens novos

As cinco tentativas de folhas por imagem não deram um ciclo confiável: houve
erros de contagem, separação e continuidade. Estão em `PROMPTS.md` para
registrar a decisão de usar vídeo; não são necessárias para refazer o atlas.

Os três vídeos pedidos para a esquerda saíram virados para a direita. Tocar
o ciclo ao contrário foi uma correção intermediária, substituída pelo
espelhamento no commit `bbfacf9` (PR #144). Não inverter a ordem temporal
para "corrigir" a direção: isso mascara o movimento errado.

A bolsa continua trocando de lado nos três quartos espelhados. O perfil
`lado_esq`, espelhado, preserva a leitura da bolsa no lado distante, mas não
resolve as outras vistas. Esta limitação é do desenho e está preservada no
resultado histórico; a recuperação não redesenhou a personagem.

Ela só tem animação própria de **andar**. Susto, queda, voo e desembarque
continuam usando a pessoa de escritório como fallback no jogo.

Para novas gerações e refações, aplicar as
[regras de personagens espelháveis](../referencia/README.md): simplificar e
aprovar o personagem e seu espelho antes da caminhada. Usar cinco ângulos com
reaproveitamento dos lados, sem bolsa lateral ou outros detalhes assimétricos.
O montador desta pasta preserva o formato histórico de oito linhas da moça;
não é um conversor genérico de qualquer personagem ou taxa de quadros. Seu
intervalo de busca de ciclo foi calibrado para estes vídeos de 24 fps.
