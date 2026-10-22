# Criar outro personagem no Gemini / Flow

Este é o ponto de entrada para qualquer sessão que receba um pedido como
"cria outro personagem" ou "faz mais um NPC". O agente executa o processo
inteiro: prepara, gera, baixa, seleciona quadros, monta, confere e integra.
O usuário descreve a ideia; não precisa conhecer prompts, grades ou scripts.

## Escopo padrão e decisões já tomadas

Um personagem completo é um **pedestre** com identidade própria nas cinco
animações: `andando`, `susto`, `desembarcando`, `voando` e `caida`. Um pedido
explicitamente limitado à caminhada continua limitado à caminhada, mas não
pode ser entregue como personagem completo. Pilotos/motos têm outro ator e
outro atlas; não aplicar este formato a eles.

- Aplicar as [regras de design espelhável](../arte/flow/referencia/README.md).
  Simplificar acessórios assimétricos antes de gerar. Identidade por corpo,
  rosto, cabelo simples e cores. Se a ideia não trouxer esses detalhes, o
  agente escolhe uma combinação distinta dos NPCs existentes e segue.
- Gerar um turnaround e depois vídeos de uma pessoa por ação e vista, sem
  manequim 3D. Não gerar o lado esquerdo: o shader espelha o direito. Frente
  e costas exigem imagens próprias.
- Usar ID curto, minúsculo e sem sublinhado (ex.: `feirante`). O catálogo
  separa ID e animação pelo primeiro `_`. Altura padrão de 1,75 m quando não
  especificada; o limite de 1,90 m mantém a pessoa dentro das células atuais.
- Preservar o turnaround aprovado como única referência de identidade de
  todos os vídeos. Nenhum novo rosto, roupa ou acessório entre as ações.
- O agente faz escolhas técnicas e conferências. Só pede intervenção pessoal
  para login, 2FA/CAPTCHA ou uma decisão de produto/orçamento que realmente
  falte. Não entregar ao usuário seleção de quadros, JSON ou programação.

## Modelo e créditos: verificar antes de gerar

Em **22/10/2026**, a tela **Settings → Configurações do agente** no
[Flow](https://flow.google.com/) mostrou os padrões de **geração**:
**Nano Banana 2.1** para imagens e **Omni 1.1 Flash** para vídeos, **16:9**, **x1**.
Esses são os pontos de partida para novos personagens. A consulta não gerou
mídia nem alterou as configurações da conta. Não confundir o seletor de edição
de uma mídia antiga com o modelo que a criou.

Em cada sessão, confirmar disponibilidade, modelo selecionado e custo na UI;
registrar os nomes exatos na ficha e os parâmetros por vídeo. Se o modelo foi
retirado, usar a opção equivalente disponível para imagem de referência e
animação, registrar a mudança e validar um piloto antes de produzir o lote.
Não presumir que o modelo histórico da moça de moletom foi identificado.

Usar o orçamento já autorizado naquela sessão. Quando não houver limite de
créditos, preparar identidade/prompts e estimar o custo do lote na UI antes de
pedir **uma única definição de orçamento**. Não comprar créditos/planos nem
usar quantidade x2/x4 por conveniência. Começar por um turnaround e um perfil
andando; só expandir depois da conferência. Uma tentativa adicional por clipe
reprovado, dentro do limite disponível; se continuar falhando, relatar o
problema concreto e parar, sem retries em background. Uma nova tentativa por
outro modelo também conta. Aprovar gasto não substitui a revisão visual.

## Preparar a ficha e os prompts

Todos os comandos passam por `tools/dev.py`. Na raiz do repo:

```bash
python3 tools/dev.py personagem setup
python3 tools/dev.py personagem preparar feirante \
  --descricao 'Adulto brasileiro, cabelo curto, camiseta azul lisa, calça cinza e tênis brancos iguais.' \
  --altura 1.75
```

`setup` cria `.dev/venv-flow` e instala Pillow 12.3.0 e NumPy 2.3.5; FFmpeg e
FFprobe devem estar no PATH. O agente instala/verifica essas dependências.
`preparar` usa apenas a biblioteca padrão e não precisa de acesso ao Flow.

A pasta `arte/flow/personagens/feirante/` nasce com:

- `personagem.json`: identidade, altura, modelos, fontes, aprovação e índices;
- `prompts/turnaround.txt` e 20 prompts de vídeo, já preenchidos com a ação,
  vista e restrições de design;
- `originais/`: destino dos JPG e MP4 sem recompressão, versionados pelo LFS.

O comando recusa sobrescrever uma pasta existente. Para testes locais, passar
`--pasta .dev/personagem-teste`. Não commitar um personagem de exemplo como
se fosse arte entregue. Os campos inicialmente vazios são preenchidos pelo
agente durante o trabalho, não pelo usuário. Os prompts são bases editáveis:
salvar neles o **texto realmente enviado**, incluindo cada alteração.

## Gerar, conferir e preservar

1. Criar um projeto separado no Flow, nomeado pelo ID do personagem, e salvar
   a URL em `geracao.projeto_url`. Registrar os modelos selecionados em
   `geracao.modelo_imagem` e `geracao.modelo_video` antes do primeiro lote.
2. Gerar o turnaround a partir do prompt preparado, baixar o original como
   `originais/turnaround.jpg`, salvar sua URL e SHA-256 em `turnaround`.
   Conferir frente, perfil e costas, e também o perfil espelhado. Não seguir
   com acessórios trocando de lado ou verde na roupa que o recorte apagaria.
3. Gerar o perfil de caminhada com esse JPG anexado. Baixar **Tamanho
   original**, preferencialmente 720p, com o nome que a ficha prevê. Conferir
   pés e direção de movimento: o pedido escrito não prova para onde olha.
4. Inspecionar os quadros e montar a caminhada de cinco vistas. Conferir
   também o espelho, fase do passo e escala. Só então produzir outras ações.
5. Para cada ação restante, gerar **primeiro o perfil** e conferir o movimento
   completo. Se aprovado, gerar as outras vistas dessa ação. Abaixo estão os
   estados que devem aparecer; não aceitar todos os quadros quase em pé.
6. Para cada clipe, salvar `url`, `modelo` exato, `sha256`, `parametros` reais
   (data, proporção, quantidade, resolução, fps, duração, seed se exposta) e o
   prompt efetivamente usado. Seed não exposta deve ser registrada como tal,
   sem inventar valor. Rejeitados ficam identificados como tentativas e não
   substituem o arquivo aprovado silenciosamente.

A ficha aceita taxas de quadros diferentes: os índices são da extração
nativa. O pipeline não presume 24 fps nem busca um ciclo de duração fixa.
Não rotacionar câmera ou inverter a ordem temporal para corrigir uma vista
errada. Gerar as vistas corretas e aproveitar os lados por espelhamento.

## Ações, seleção e ancoragem

| Ação | Vistas, na ordem das linhas | Quadros | Célula; pivô | Conferência obrigatória |
| --- | --- | --- | --- | --- |
| `andando` | frente, 3/4 frente, lado, 3/4 costas, costas | 8 | 160×200; 80,196 | Dois passos completos, sem deslocamento da pessoa pela tela; oito fases sem repetir o primeiro quadro no fim. |
| `susto` | frente, 3/4 frente, lado | 6 | 224×224; 112,220 | Preparação, salto com pés no ar, ápice, descida, aterrissagem e recuperação. O chão fica fixo. |
| `desembarcando` | carro de lado, 3/4 frente, 3/4 costas, de frente | 8 | 256×208; 128,204 | Começa sentado, sai lateralmente e termina de pé. Sem carro/banco pintado: o jogo já desenha o veículo. |
| `voando` | lado, 3/4 costas, costas, 3/4 frente | 8 | 240×240; 120,120 | Giro do corpo, incluindo horizontal e invertido; selecionar uma rotação coerente, sem fase final duplicada. O ator fornece a trajetória. |
| `caida` | lado, 3/4 costas, costas, 3/4 frente | 3 | 224×112; 112,108 | Três estados deitada de bruços: impacto, deslize e repouso. Não incluir o personagem em pé no atlas. |

Os prompts de susto, voo e caída pedem um momento inicial de pé para calibrar
escala; o de desembarque termina de pé. O agente marca `quadro_escala` nesse
momento, mesmo quando ele fica fora da sequência final. Em todas as vistas,
a escala é constante dentro do clipe, dada pela altura desse quadro e pela
altura em metros da ficha. Não usar a caixa de um corpo horizontal para medir
altura, nem redimensionar cada pose independentemente.

O pé é alinhado quadro a quadro na caminhada e na caída. Em susto e
desembarque, a linha do solo é a do quadro de calibração: o salto permanece
acima dela. No voo, o centro da caixa do corpo ocupa o pivô. O montador rejeita
silhueta cortada, quadro vazio, índice fora do vídeo ou corpo que não cabe na
célula; corrigir o clipe/seleção, nunca esconder membros cortados.

## Inspecionar e montar

```bash
python3 tools/dev.py personagem inspecionar \
  arte/flow/personagens/feirante/originais/andando_lado.mp4 \
  --saida .dev/feirante/andando_lado-contato.png
```

O contato mostra **todos os quadros numerados a partir de zero**. O JSON ao
lado registra quantidade, SHA-256 e metadados de FFprobe. A extração usa a taxa
nativa do vídeo; `f000001.png` corresponde ao índice 0. O cache só é reutilizado
se a extração terminou e pertence ao mesmo conteúdo.

O agente lê o contato, abre os quadros grandes quando necessário e preenche
`quadros` (índices estritamente crescentes, quantidade da tabela) e
`quadro_escala` em cada linha. Para caminhada/voo, selecionar fases de um ciclo
sem duplicar o ponto final; para as ações únicas, selecionar a progressão
completa. Os ciclos das várias vistas devem começar na mesma fase e ter o
mesmo sentido de giro. Marcar `aprovado: true` na fonte só depois da inspeção.

```bash
python3 tools/dev.py personagem validar \
  arte/flow/personagens/feirante/personagem.json --animacao andando
python3 tools/dev.py personagem montar \
  arte/flow/personagens/feirante/personagem.json --animacao andando \
  --saida .dev/feirante/atlas
```

Para montar o personagem completo, omitir `--animacao`. Saem cinco pares
`<id>_<animacao>.png` e `.json`, no formato já usado pelo ator, sempre com
espelhamento à esquerda. O script da moça de moletom continua preservado para
reprodução histórica, separado deste montador de novos personagens.

Após conferir cada atlas, registrar `aprovada: true` e `atlas_sha256` na
animação correspondente. Não marcar em lote sem olhar cada ação.

```bash
python3 tools/dev.py personagem concluir \
  arte/flow/personagens/feirante/personagem.json --atlas .dev/feirante/atlas
```

`concluir` exige as cinco animações, fontes e prompts preservados, metadados,
aprovação, hashes dos atlas e fichas compatíveis com o ator. Validação de
arquivos não reconhece rosto, pose ou direção: continua sendo responsabilidade
do agente examinar as imagens.

## Integrar e entregar

1. Copiar os cinco PNG/JSON aprovados para `assets/sprites/pedestres/` e rodar
   `python3 tools/dev.py import`. O testador descobre essas fichas sozinho.
2. Adicionar os cinco atlas em `scripts/pedestre_sprite.gd`, **na mesma posição
   de personagem** em `ANDANDO`, `SUSTO`, `DESEMBARCANDO`, `VOANDO` e `CAIDA`.
   Não basta adicionar à caminhada. A moça de moletom histórica tem só andar:
   preencher sua posição nas outras listas com o atlas de escritório que já
   era seu fallback, antes de acrescentar o personagem novo; preservar o
   comportamento existente. Conferir demais consumidores de `ANDANDO` e
   `da_pose` para não trocar a identidade entre estados.
3. Rodar `python3 tools/dev.py sprites-ver --sprite feirante_andando`,
   conferir as outras quatro fichas e testar o personagem no playground,
   nos dois sentidos e em todas as ações. Conferir frente/costas, espelho,
   contato dos pés, escala, transições e looping. Salvar evidências em
   `arte/flow/personagens/<id>/conferencia/` e registrar no README do personagem
   quais vistas/ações foram verificadas. O agente dirige o testador.
4. Rodar `python3 tools/dev.py personagem testar`, os testes de integração
   relevantes do ator e o portão completo: `test`, `selftest`, `lint`.
   Conferir Git LFS para JPG/MP4/PNG antes do commit e push da branch.
5. Entregar com link para o README/ficha do personagem, evidências, resultados
   de validação e limitações reais. Não declarar completo com fallback de
   outra pessoa, animação faltando, campo de geração vazio ou arte só no Flow.
   PR e auto-merge seguem o contrato do repo, sem publicar versão por conta.

## O que foi validado neste fluxo

- O experimento de caminhada tem [fontes, prompts e reprodução pixel a pixel](../arte/flow/sem_referencia/README.md).
- O montador novo tem testes automatizados de cinco formatos contra as fichas
  reais do jogo, escala, salto preservado, voo centralizado, corpo deitado,
  recusa de cortes/índices inválidos, extração real com FFmpeg, cache e bloqueio
  de conclusão com arte não aprovada ou alterada após a aprovação.
- Os prompts das demais ações são **bases de produção**, não prova de que
  qualquer modelo gerará a pose certa de primeira. O piloto e a conferência
  de cada ação fazem parte do trabalho da próxima sessão e são obrigatórios;
  a sessão não deve pedir ao usuário que invente o processo nem aceitar
  automaticamente o resultado só porque o comando passou.

Cada personagem novo mantém uma receita própria com os modelos e arquivos
reais. Assim mudanças do Flow não apagam a reprodutibilidade do que foi entregue.
