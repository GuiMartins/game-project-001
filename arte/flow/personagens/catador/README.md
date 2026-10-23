# Catador — produção em andamento

Pedido: outro personagem brasileiro, cabelo comprido, boné genérico, bermuda
e chinelo, camisa vermelha e preta listrada **sem escudo, logo, texto ou número**.
Postura pouco curvada, expressão travessa de malucão, passo arrastado e braço
livre alternando gestos de assustar e sobressaltos. A outra mão puxa **um só
sacão preto**, maior que o da primeira referência.

Escopo autorizado: caminhada e atropelamento (voo + caída). Não produzir susto
isolado nem desembarque. O saco deve estourar no impacto e espalhar dezenas de
latinhas e garrafas PET. O efeito é separado dos atlas do corpo, para os objetos poderem voar pelo
cenário; **já foi implementado em 2D e conferido na bancada**. Ainda falta
ligá-lo ao impacto do catador, que continua sem atlas aprovado.

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
  ligar o efeito de estouro já pronto e conferir as ações nos dois sentidos no jogo.

O montador foi preparado para escopo explícito de caminhada/atropelamento e
célula de caminhada mais larga (256 px), preservando a escala física de 1,68 m.
O ator do jogo ainda precisa receber essa largura ao integrar o personagem.
O padrão de conclusão continua exigindo cinco ações quando não há escopo
reduzido explícito. O conjunto de atropelamento continua exigindo a caída.

Validação deste checkpoint: 393 testes unitários, selftest e lint passaram;
13 testes Python do pipeline passaram. Nenhum baseline foi alterado.
Não foi rodada prova gráfica de integração deste personagem, pois ela ainda
não existe. Esta branch preserva produção parcial, não uma entrega jogável.

## Efeito de recicláveis — 2D

O botão **Reciclaveis 2D** do testador abre uma bancada de canvas com saco
fechado, estouro, impacto dos dois lados, repetição e câmera lenta local.
`SacoReciclaveis` é um `Node2D`; o viewport da bancada desabilita 3D. O SVG
`assets/sprites/efeitos/reciclaveis.svg` contém latas, PET com gargalo/tampa e
nervuras, saco fechado, duas metades rasgadas e retalho. Toda a arte é 2D,
desenhada em código, sem geração no Flow ou gasto de créditos.

São 20 latinhas, 20 garrafas PET e 10 retalhos. O impulso desloca o jato, com
dispersão radial irregular dos dois lados. Cada peça gira, sobe, quica,
desliza e para; as garrafas quicam mais que as latas. Sombras são elipses de
canvas. O efeito apaga entre 5,8 e 7 segundos, libera as peças e emite
`terminou`; o dono pode liberar ou reutilizar o emissor. Repetir o impacto no
mesmo saco não cria outro lote. O RNG é local e não interfere no trânsito.

Integração futura: criar `SacoReciclaveis` no canvas, chamar `reiniciar(ancora)`
e `estourar(impulso_2d, semente)` no impacto. Posição, escala e a projeção da
pista pertencem ao dono. Não há chamada no personagem por enquanto, nem foi
atribuído esse saco a outro NPC para simular que o catador está concluído.

`conferencia/efeito-0.35.png` mostra a bancada na resolução do jogo. O GIF
`efeito-saco-2d.gif` foi gravado pelo próprio Godot, com o render 3D desabilitado,
a 30 quadros/s, semente 17, impulso (180, -15), escala 1,4. Mostra o saco
fechado e a dispersão; o PNG do mesmo nome é um quadro durante o voo.
Os três testes de efeito conferem quantidade/tipos e direções, quique e
repouso, liberação, impacto único, reinício e reprodução entre passos de tempo.

Validação do efeito: **396 testes unitários**, **14 verificações do selftest**,
lint e `shots` (**19 quadros**, comparação visual aprovada), todos com saída 0.
Nenhum baseline alterado. O efeito foi conferido em render nativo 2D e a
bancada também foi capturada; integração com o catador continua pendente.

## Checklist para concluir o personagem

- [ ] Com saldo disponível no Flow, gerar referências dedicadas de 3/4 frente
  e 3/4 costas e refazer as duas caminhadas reprovadas, sem giro de câmera.
- [ ] Gerar a caída 3/4 frontal que foi recusada por falta de créditos.
- [ ] Conferir todos os clipes e escolher fases coerentes: caminhada de dois
  passos, rotação completa do voo e impacto/deslize/repouso de bruços.
- [ ] Preencher índices, quadro de escala e aprovações na ficha, preservando
  as tentativas e os prompts reais de novas gerações.
- [ ] Montar os três atlas, conferir espelho, escala, chão, loop e ausência de
  membros ou saco cortados; registrar hashes e concluir o escopo reduzido.
- [ ] Fazer o ator e a multidão respeitarem a caminhada com célula de 256 px,
  mantendo o corpo na escala correta e a âncora estável apesar do saco.
- [ ] Incluir o catador no elenco e no testador com identidade própria em
  caminhada, voo e caída; não habilitar desembarque nem emprestar susto de
  outro personagem.
- [ ] No impacto, retirar o saco fechado e disparar `SacoReciclaveis` na
  posição projetada correta. Acompanhar o movimento da câmera/pista em 2D,
  acertar escala/profundidade e liberar o emissor após `terminou`.
- [ ] Conferir caminhada e atropelamento integrados nos dois sentidos, com
  o saco estourando no momento do impacto e lixo legível na resolução do jogo.
- [ ] Repetir `personagem testar`, `test`, `selftest`, `lint` e `shots` após a
  integração, salvar evidências e atualizar este estado para concluído.

O efeito 2D e a bancada já estão prontos e testados. A falta de créditos
bloqueia a geração dos clipes restantes; nenhum processo fica aguardando saldo.
