# Sprites sem referência 3D (experimento de 20/10/2026)

Personagem e ciclo de andar gerados no Flow **sem** boneco 3D de referência:
turnaround por texto, depois um vídeo por ângulo (câmera fixa, andando no lugar,
fundo verde), e `montar_folha.py` tira o verde, acha o ciclo e monta a folha.
Prompts e receita: ver o histórico do commit que trouxe esta pasta.

## Personagem novo: mantenha simples e simétrico

As regras completas para novas gerações e refações estão em
[Criação de personagens e sprites no Gemini / Google Flow](../referencia/README.md).
Elas valem também para este fluxo por vídeo: aprovar o personagem e seu
espelho antes da caminhada, e a caminhada antes das demais ações. Os oito
MP4 e as adaptações para a bolsa descritos abaixo são o histórico deste
experimento, não o padrão a repetir em personagens novos.

Evite o que complica o sprite. O que importa é o que **muda de um lado para o
outro** ou **mexe sozinho**:

- Acessório num lado só: bolsa a tiracolo, mochila de uma alça, relógio, fone
  de um ouvido, objeto na mão.
- Cabelo ou franja de lado, estampa e logo assimétricos.
- Tecido solto que balança (capuz, cachecol, saia comprida, casaco aberto).

*Por quê:* o shader do pedestre espelha o lado esquerdo a partir do direito.
Com a bolsa a tiracolo da moça de moletom, ela trocava de ombro a cada giro, e
a saída foi gerar os 8 ângulos reais (frente, três ângulos de cada lado e costas)
em vez de 5. Personagem simétrico fica com 5 ângulos espelhados.
Acessório simétrico (boné, óculos, mochila nas costas) pode.

## Como a folha nasce

`python3 montar_folha.py <pasta de trabalho> <saida.png>` com os oito MP4 na
mesma pasta (`frente`, `tres_quartos_frente`, `lado`, `tres_quartos_costas`,
`costas` e os `_esq`). Os MP4 não vão para o git (2 MB cada, fora do LFS):
são gerados no Flow, projeto "out. 19 - 20:40", com o turnaround da personagem
como única referência, e baixados em 720p.

- **Vídeo, não imagem.** O gerador de imagem desenha 8 poses independentes, erra
  a contagem e ignora o formato pedido (o Flow só faz proporções fixas, 16:9 no
  máximo). O vídeo dá o passo contínuo e o mesmo corpo do começo ao fim.
- **O Flow não vira para a esquerda.** Os três vídeos pedidos "virada para a
  esquerda" saíram com a pessoa virada para a **direita** (o passo prova: o pé de
  apoio desliza para a esquerda, como nos da direita). Usá-los nas linhas da
  esquerda fez a personagem andar para a esquerda de frente para a direita, e
  parecia moonwalk. Tocar o ciclo ao contrário (o primeiro conserto) escondia o
  sintoma sem consertar a causa. Hoje as linhas da esquerda são o **espelho** de
  vídeos virados para a direita (`LINHAS` em `montar_folha.py`). Para descobrir
  para onde a pessoa olha, não confie no prompt: olhe o quadro.
- **A bolsa só fica certa no perfil.** O `lado_esq` tem a bolsa no quadril longe
  da câmera (só a alça aparece); espelhado, ela continua no mesmo quadril. Nos
  três quartos da esquerda (espelho dos da direita) a bolsa troca de lado. Quem
  quiser os três quartos certos precisa de vídeo novo, ou de personagem sem bolsa.
- **8 linhas, não 5 espelhadas.** Com bolsa a tiracolo, o espelho trocava a
  bolsa de ombro a cada giro; a folha de 8 linhas desenha a esquerda de verdade
  (ver `PedestreSprite.LINHAS_DOIS_LADOS`).
