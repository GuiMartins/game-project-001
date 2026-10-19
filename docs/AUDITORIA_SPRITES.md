# Auditoria dos sprites

Levantamento de 18/10/2026, depois do playtest em sprite: o pedestre andando
"estranho", a moto "mudando de tamanho" e nada fluido. Cada item diz o que foi
medido, a causa e o que fazer. A ordem é a de execução: primeiro o que é
código e destrava o resto, depois o que precisa do Flow.

Como medir de novo:

- **Moto:** `godot --headless --path . --script res://.dev/mede_atlas.gd`
  (scratch, fora do git) ou ler os números que o `dev.py sprites` imprime: a
  inclinação desenhada e a altura de cada quadro.
- **Pedestres:** `python3 tools/dev.py sprites-pedestres` grava as folhas de
  conferência em `.dev/sprites_pedestres/` (atlas sobre cinza, com a linha do
  chão).

## A causa comum dos pedestres

As folhas de pose (`dev.py boneco`) que o Flow usa de referência saíam
**embaralhadas**, e diferentes a cada rodada. O `Pessoa` tem
`_physics_process`, e o Godot religa o processo de quem tem um ao entrar na
árvore: o `set_physics_process(false)` antes do `_ready` não valia. Entre a pose
do quadro e a captura a pessoa andava a fase e refazia a pose na cadência, e
cada coluna saía com a pose de um instante qualquer.

O Flow redesenhou exatamente isso. No ciclo de andar de lado, a passada era
junto, médio, aberto, junto, médio, junto, aberto, aberto, em vez de junto,
médio, aberto, médio, duas vezes; no susto, a pessoa pisca entre em pé e
pulando, em vez de subir e descer. Nenhum ajuste no recorte conserta isso: a
folha do Flow tem de ser refeita a partir da referência certa.

## Fila

### Ferramenta

- [x] **S01** — Folha de pose determinística. `boneco_flow.gd` desliga o
  processo da pessoa depois do `_ready` e espera o desenho
  (`frame_post_draw`), e não o quadro. Duas rodadas dão o mesmo PNG, byte a
  byte. As seis referências em `arte/flow/referencia/` foram regeradas.
- [x] **S02** — `dev.py boneco` reprovava sempre: o `PlayerBike` chamava o
  autoload `Controls` pelo nome, que não existe em `--script`. Agora o script
  vem por `preload` e o `analogico`, pelo caminho do nó.

### Moto

- [x] **S03** — **O sprite respira.** A suspensão encolhia o quad na vertical
  com 2,5× de exagero: `estica` oscilava entre 0,95 e 1,04 a cada lombada e
  freada, ±5% de altura, e é isto o "mudando de tamanho". Trocar a escala por
  deslocamento: o sprite inteiro desce e sobe com a suspensão, sem mudar de
  tamanho, como o quique do Road Rash.
- [x] **S04** — **A curva anda para trás na troca de quadro.** O `AtorSprite`
  supunha 15° e 30° de inclinação desenhada; as folhas desenham 11° e 28° (o
  reto, −1°). Na troca do reto para o primeiro deitado, a 7,5°, a inclinação
  na tela caía de 6,5° para 3,5°, e a moto oscilando perto disso tremia entre
  os dois. O recorte passa a medir a inclinação desenhada de cada quadro e
  gravar no atlas (`.json`); o ator escolhe o quadro mais próximo e gira só o
  resto, com folga na troca para não piscar na fronteira.
- [x] **S05** — **O soco cresce.** A folha de combate tem a câmera mais baixa:
  igualado pela área, o piloto que soca fica 4% a 6% mais alto que o reto (124
  a 127 px contra 120), e o capacete pula para cima a cada soco. Medir o soco
  pela altura do quadro de voltar a pilotar da própria folha, e não pela área.

### Pedestres

- [ ] **S06** 👤 — **Refazer as 25 folhas no Flow** a partir das referências
  novas (S01): cinco pessoas × andar, susto, desembarque, voo e queda. Precisa
  do login do Guilherme no Flow. O prompt e a ordem das imagens estão em
  `arte/flow/referencia/README.md`.
- [x] **S07** — **Ciclo de andar em ordem, mesmo com folha torta.** Enquanto
  S06 não vem (e para quando o Flow errar de novo): o recorte mede a abertura
  das pernas de cada quadro e reordena a linha no ciclo junto, médio, aberto,
  médio, duas vezes. Os dois mais fechados viram as passagens, os dois mais
  abertos os contatos.
- [x] **S08** — **Linhas viradas para o lado errado.** O adolescente andava de
  costas mostrando o rosto (a linha `costas` da folha saiu de frente): agora a
  de costas usa a de 3/4 de costas da folha, que já era costas pura, com o
  mesmo reparo do quadro 7. Fica para a S06: a 3/4 de costas do escritório é
  costas pura, e o operário vira o rosto em dois quadros dela.
- [ ] **S09** — **Susto, voo, queda e desembarque.** Todas embaralhadas pela
  mesma causa (S01): o susto pisca, o voo tem quadro minúsculo no meio
  (`obra`, costas, coluna 7), a queda de costas mostra o rosto, o desembarque
  muda de lado entre linhas. Só a S06 resolve; não há reordenação que salve.
