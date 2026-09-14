# Contrato de operação

Como se trabalha neste repositório. Vale para pessoa e para IA — se um comando
aqui não funcionar na sua máquina, isso é um bug do contrato, não seu.

O projeto é um protótipo *greybox* de Road Rash com entregadores de app, em
Godot. Ele existe para responder **uma** pergunta: *acelerar, inclinar, se
enfiar no corredor e bater está gostoso?* Nada de arte, áudio ou menu até a
resposta ser sim. Contexto e decisões de design em [docs/PROTOTIPO.md](docs/PROTOTIPO.md).

Desenvolvido nos três sistemas — Windows, macOS e Linux. Toda ferramenta daqui
funciona nos três, e o CI roda nos três.

## Comandos

Tudo passa por `tools/dev.py`. Não invoque `godot` direto: o script resolve
qual binário usar, e no Windows escolhe a variante que não engole a saída.

| Comando | O que faz |
| --- | --- |
| `python tools/dev.py setup` | Baixa a engine fixada em `.godot-version`. Primeira coisa a rodar. |
| `python tools/dev.py doctor` | Diz onde está o Godot e se bate com a versão fixada. |
| `python tools/dev.py test` | Testes unitários (GdUnit4). ~4 s. |
| `python tools/dev.py selftest` | Banco de provas: roda a moto de verdade e compara com o baseline. ~110 s. |
| `python tools/dev.py selftest --fase curva` | Só até aquela fase. ~32 s, para iterar. |
| `python tools/dev.py shots` | Regressão visual: roda com tela e mede o frame. |
| `python tools/dev.py lint` / `format` | gdlint e gdformat. |
| `python tools/dev.py run` | Abre o jogo. |
| `python tools/dev.py export` | Exporta as três plataformas. |

Em muitas máquinas o executável é `python3`, e `python` simplesmente não
existe — vale para macOS, não só para Linux. Se o seu caso for esse, troque em
todos os comandos desta página.

E uma armadilha específica de quem roda comando com a saída redirecionada, que
é como todo CI e todo agente roda: com `python` inexistente e a saída num pipe
(`python tools/dev.py selftest | tail`), o código de saída passa a ser o do
**último** comando do pipe. O portão devolve **0** sem ter rodado nada. Sempre
`set -o pipefail` antes de encanar qualquer comando do portão — senão "passou"
e "nem existe" ficam indistinguíveis.

## O portão: o que rodar antes de dizer que terminou

```bash
python tools/dev.py test && python tools/dev.py selftest && python tools/dev.py lint
```

Os três precisam sair com código 0. **Não anuncie uma mudança como pronta sem
ter rodado isto** — e se não foi possível rodar, diga explicitamente que não
foi, em vez de deixar implícito que passou.

O `selftest` compara as medidas com [tests/baseline.json](tests/baseline.json).
Se algum número saiu da tolerância, só há dois desfechos honestos:

1. **A mudança era o objetivo.** O novo valor entra em `baseline.json` no
   **mesmo commit**, e a mensagem diz por que o número andou.
2. **Não era.** É regressão. Conserte.

Atualizar o baseline para silenciar uma falha que você não entendeu é a única
coisa aqui que transforma a rede de proteção em enfeite.

Detalhes de teste em [docs/TESTES.md](docs/TESTES.md); de ambiente e toolchain
em [docs/AMBIENTE.md](docs/AMBIENTE.md).

## Invariantes que não se quebram sem conversa

Cada um destes já custou um bug caro, e a maioria não dá erro no console — o
jogo continua rodando, só errado. Estão explicados em `docs/PROTOTIPO.md`.

- **O chão não tem colisor.** Altura e direção saem da amostragem analítica da
  curva. A 50 m/s um `CharacterBody3D` atravessa um trimesh de pista.
- **Só o jogador roda física.** Trânsito e rivais são paramétricos na curva.
- **Winding horário.** Godot descarta face anti-horária *sem avisar*: a pista
  inteira some e o mundo vira caixas flutuando.
- **`stretch_shrink`, nunca `SubViewport.size`.** Com `stretch` ligado o
  container sobrescreve o tamanho, e você renderiza em 1280×720 achando que
  está em 320×180.
- **A HUD mora dentro do SubViewport.** HUD nítida sobre mundo pixelado é o
  visual de remaster preguiçoso.
- **Semente fixa no banco de provas** — ela mora em `World.setup` (20260831) e
  os rivais herdam dela; o selftest não sorteia nada por conta própria. Ele
  também roda nos **defaults do repositório**, ignorando o `user://`. Sem os
  dois, "regrediu" e "você mexeu num slider ontem" viram a mesma coisa.
- **Guinada positiva gira para a esquerda** (Y para cima, mão direita). Já
  inverteu o jogo uma vez.

## Código

- **GDScript tipado, sempre.** `untyped_declaration` é **erro**, não aviso: o
  build quebra.
- **Formato é do gdformat.** Rode `python tools/dev.py format`; não discuta
  estilo em revisão.
- Ordem de declaração do guia oficial: `class_name`, `extends`, docstring,
  `signal`, `enum`, `const`, `@export`, `var`.
- **Comentário explica *por quê*, não *o quê*.** É a convenção mais forte
  deste repositório: leia qualquer arquivo em `scripts/` antes de escrever.
  Número mágico sem justificativa ao lado é dívida.
- Tudo em português — código, comentário, commit, documento.

## Branches e release

`master` é estável. `develop` recebe o trabalho. Merge em `master` **não**
publica nada.

**Trabalho novo nasce em branch, e a branch vive no remoto desde o primeiro
commit.** Não espere ser mandado: ao começar qualquer tarefa, saia de `master`
para uma branch com nome do assunto, e conforme o trabalho fecha etapas, vá
commitando e **dando push** sem pedir autorização.

```bash
git switch -c corrida-por-posicao
# ... trabalho, portão, commit ...
git push -u origin corrida-por-posicao
```

Duas razões, e nenhuma é cerimônia. A primeira é que trabalho de IA que só
existe na máquina de quem rodou o agente é trabalho que some junto com a
sessão — e ninguém consegue ler o diff de algo que não foi empurrado. A segunda
é que aqui push não distribui nada: a release sai de tag, então a pior
consequência de uma branch empurrada é uma branch a mais no remoto.

O que **continua** precisando de aval: abrir PR, fazer merge, criar tag,
publicar release. Empurrar a branch é para o trabalho ficar visível; decidir
que ele entra é outra coisa.

**Merge exige check verde conferido — não basta o aval humano.** São duas
perguntas diferentes, e cada uma tem a sua resposta:

```bash
gh pr checks <n>                  # os testes passaram?
gh pr view <n> --json mergeable   # dá pra juntar sem conflito?
```

`mergeable` só fala de conflito de git, e é fácil ler `MERGEABLE` como
"liberado". Foi assim que o #9 entrou na `master` com o portão visual
reprovando.

Vermelho que **você acredita** ser instabilidade do portão não é exceção à
regra — é bug de portão. Conserte o portão primeiro, em PR próprio, e mergeie
em cima dele depois.

Foi o que o #10 fez. O limite da regressão visual estava plantado no meio do
ruído da própria medida: reprovava até commit que só mexia em markdown, e
enquanto existisse, nenhuma branch ficava verde de forma confiável. Portão que
reprova metade das entregas corretas deixa de ser rede e vira pedágio — e a
primeira coisa que se aprende com ele é a ignorar o vermelho.

Release sai de uma tag, que é ato deliberado e humano:

```bash
git tag v0.0.3 && git push origin v0.0.3
```

A tag precisa bater com `config/version` no `project.godot`, senão a pipeline
recusa. **Nunca crie tag nem publique release por conta própria.**

Commits em gitmoji + conventional, assunto imperativo em português:

```
✨ feat: porta de carro que só abre em quem está encostado
```

`✨ feat` · `🐛 fix` · `♻️ refactor` · `⚡️ perf` · `📝 docs` · `✅ test` ·
`👷 ci` · `🔧 chore` · `🎨 style` · `🔥 remove`

O corpo explica **por que**, e é onde entra a justificativa de um baseline que
mudou. Veja `git log`: as mensagens deste repositório são longas de propósito.

## Evoluindo este contrato

**Se você identificar algo que deveria estar nesta estrutura e não está —
pergunte ao usuário e, se ele autorizar, adicione.**

Vale para tudo: um invariante que você descobriu do jeito difícil, um comando
que faltava no `dev.py`, um buraco de cobertura, uma armadilha de plataforma,
uma convenção que estava só na cabeça de alguém. O contrato só continua
verdadeiro se quem esbarra no que falta o conserta.

Duas regras ao fazer isso:

- **Pergunte antes, não depois.** Proponha o que notou e o que faria; espere o
  aval. Este arquivo é acordo, e acordo não se altera sozinho.
- **Escreva o porquê, não só a regra.** Regra sem motivo é a primeira a ser
  ignorada quando incomoda.

Buracos conhecidos de cobertura estão em [docs/TESTES.md](docs/TESTES.md), e
saber onde **não** há rede faz parte do contrato.

## Onde está o quê

| Caminho | |
| --- | --- |
| `scripts/player_bike.gd` | O protótipo. Se algo é "o jogo", é este arquivo. |
| `scripts/world.gd` | Monta o mundo e arbitra o que precisa ver todo mundo. |
| `scripts/road_track.gd` | Geometria da pista: curva, rampa, faixas. |
| `scripts/selftest.gd` | O banco de provas. |
| `scripts/bike_tuning.gd`, `world_tuning.gd` | Os sliders do F3. |
| `tests/unit/` | Testes unitários. |
| `tests/baseline.json` | Os números esperados. |
| `tests/baseline_visual.json` | O que a tela tem dentro. |
| `tools/dev.py` | Todos os comandos. |
| `docs/PROTOTIPO.md` | Por que o jogo é assim. Leia antes de mexer no feel. |
| `docs/DIRECAO_VISUAL.md` | Como sair do greybox: resolução, sprite, luz, partícula. Leia antes de mexer no visual. |
