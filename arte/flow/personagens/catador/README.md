# Catador — produção em andamento

Pedido: outro personagem brasileiro, cabelo comprido, boné genérico, bermuda
e chinelo, camisa vermelha e preta listrada **sem escudo, logo, texto ou número**.
Postura pouco curvada, expressão travessa de malucão, passo arrastado e braço
livre alternando gestos de assustar e sobressaltos. A outra mão puxa **um só
sacão preto**, maior que o da primeira referência.

Escopo autorizado: caminhada e atropelamento (voo + caída). Não produzir susto
isolado nem desembarque. O saco deve estourar no impacto e espalhar dezenas de
latinhas e garrafas PET. O efeito será separado dos atlas do corpo, para os
objetos poderem voar pelo cenário; **ainda não foi implementado**.

## Estado e bloqueio

**Não integrado ao jogo. Não é um personagem concluído.**

O Flow recusou a 13ª submissão com:

> Falha Você chegou ao limite de uso. Tente de novo mais tarde.

A mesma tela mostrou “Não há créditos suficientes para realizar esta ação”.
Não houve compra/upgrade, novas tentativas após o bloqueio, automação ou
processo em background esperando créditos. Retomar geração depende de saldo
na conta. O teto disponível desta sessão era 104 créditos; custo nominal dos
12 vídeos concluídos: **51** (1 × 7 + 11 × 4). Débito/saldo final da conta não
foi confirmado; a submissão recusada não é contada como vídeo entregue.

## Fontes e identidade

Projeto: <https://flow.google.com/project/34c8ac4e-0e2c-4998-b1fe-58532676c9a5>.
Imagem: Nano Banana 2.1, 16:9, x1, custo mostrado zero. Foram feitas quatro
versões da referência, preservadas em `originais/turnaround*.jpg`, com os
prompts reais de cada revisão. A referência final é `turnaround.jpg`.

Vídeo: Omni 1.1 Flash, Elementos, 16:9, x1, 4 segundos. Piloto lateral em
720p (7 créditos); demais clipes em 360p (4 créditos). URLs, parâmetros e
SHA-256 estão em `personagem.json`; índices e aprovações permanecem vazios
até a seleção/conferência final. Não presumir aprovação pelo simples download.

O cabelo comprido, o saco na mão e os gestos são exceções de design pedidas
pelo usuário. O saco pode trocar de mão no espelho: não há mão dominante
canônica. O escudo foi removido por pedido posterior; prompts das revisões
antigas continuam preservados como histórico, não como instrução atual.

## Conferência feita e próximos passos

- Turnaround final: camisa sem marca e um saco legível na lateral.
- Piloto lateral: identidade e saco únicos; passo curto/arrastado, mão em
  garra, avanço e recuo do braço livre. Prévia normal/espelhada em
  `conferencia/piloto-lateral-espelho.gif` usa o clipe inteiro amostrado, não
  representa ainda o ciclo final de oito quadros.
- Caminhada frontal e traseira: fontes e contatos examinados; selecionar o
  ciclo e conferir escala, fase e loop junto às demais vistas.
- Caminhada 3/4 frontal: reprovada, saiu perfil. Caminhada 3/4 traseira:
  reprovada, começa diagonal e gira para perfil. Os dois clipes estão
  identificados como `tentativa-01`; refazer com referência dedicada ao ângulo.
- Voo lateral: tem horizontal e inversão completa. Caída lateral: impacto,
  deslize e repouso de bruços. Selecionar quadros e calibrar pela pose inicial.
- Outros três voos e duas caídas foram baixados com hashes; ainda precisam
  da conferência completa e seleção.
- Caída 3/4 frontal: ausente, geração recusada por créditos.
- Montar e aprovar os três atlas, integrar apenas os estados autorizados,
  implementar o estouro e conferir as ações nos dois sentidos no jogo.

O montador foi preparado para escopo explícito de caminhada/atropelamento e
célula de caminhada mais larga (256 px), preservando a escala física de 1,68 m.
O ator do jogo ainda precisa receber essa largura ao integrar o personagem.
O padrão de conclusão continua exigindo cinco ações quando não há escopo
reduzido explícito. O conjunto de atropelamento continua exigindo a caída.

Validação deste checkpoint: 393 testes unitários, selftest e lint passaram;
13 testes Python do pipeline passaram. Nenhum baseline foi alterado.
Não foi rodada prova gráfica de integração deste personagem, pois ela ainda
não existe. Esta branch preserva produção parcial, não uma entrega jogável.
