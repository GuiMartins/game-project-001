# Testes

Três camadas, e nenhuma substitui a outra.

| Camada | Comando | Tempo | Pega o quê |
| --- | --- | --- | --- |
| Unitários | `python tools/dev.py test` | ~4 s | Lógica pura: pontuação, geometria de faixa, prazo |
| Banco de provas | `python tools/dev.py selftest` | ~15 s | A moto e o mundo rodando de verdade |
| Baseline | (dentro do selftest) | — | O número *andou*, mesmo continuando na faixa jogável |
| Regressão visual | `python tools/dev.py shots` | ~90 s | A tela ficou errada por inteiro |
| Regressão visual de noite | `python tools/dev.py shots --noite` | ~90 s | A noite ficou errada por inteiro: tudo apagado, tudo aceso |
| Testador de sprites | `python tools/dev.py sprites-ver` | interativo | Folha com defeito: pé que escorrega, altura que muda, quadro cortado ou em branco. Os olhos fazem o resto |

## Unitários (GdUnit4)

`tests/unit/`. Testam o que não precisa de cena nem de física: `RaceRun` é
`RefCounted` puro — prazo, estilo, estrelas e a ordenação do pelotão — e as
estáticas de `RoadTrack` são geometria.

A exceção é `test_rival_autoria.gd`, que põe um `RivalBike` na árvore (é o
`_ready` dele que monta o sensor de acidente) e avança o relógio chamando
`_physics_process` na mão. Continua sendo unitário pelo que importa: roda em
milissegundos, não depende de mundo nem de trânsito, e a regra que ele mede —
por quanto tempo um soco responde pela queda do rival — é a diferença entre
derrubar rival ser conquista ou ser acidente de trânsito.

A outra é `test_entregador.gd`, que põe o modelo na árvore e avança a pose na
mão. O que ele guarda não aparece em nenhum outro lugar: a física anda igual com
a roda girando para trás, o pé enterrado no asfalto ou a mão a um palmo do
guidão, e a regressão visual só pega a tela errada por inteiro. Os casos são
sinal (roda, tombo), alcance (pé no chão, mão na manopla com o guidão virado),
direção (joelho que fecha com a velocidade) e a sincronia entre as cores de
`Entregador` e a textura que o `arte/entregador.py` escreve.

`test_carro.gd` faz o mesmo com os carros do trânsito: monta cada modelo na
árvore e avança a pose na mão. Sinal (roda para a frente, nariz que mergulha
na freada e sobe na arrancada, rolagem para fora da troca de faixa, volante
virando para o lado da roda), alcance (mãos no aro com o volante virado,
cabeça de quem dirige dentro da cabine), sentido (porta de carro abre para
fora, folha de ônibus dobra para dentro), luz (lanterna na freada, alerta
encostado) e as cores de fábrica contra a textura do `arte/carros.py`.

E `test_chase_camera.gd` põe uma moto e a câmera na árvore para medir o giro
da câmera, que o banco de provas nem vê — ele roda sem câmera. Inclinação
segurada chega inteira; correção de polegar, três vezes por segundo, chega
com menos de 40% — com a câmera copiando a inclinação direto, ele reprova.

E `test_camera_garupa.gd` dirige o cinegrafista do modo `GARUPA`
(`CameraGarupa`, `RefCounted`) sem árvore, numa reta montada à mão, e só põe a
câmera de verdade na árvore para o pino. O banco de provas e a prova visual
rodam na perseguição, então nada deste modo aparece em outro lugar: a
distância que converge, respira e nunca atravessa a moto (nem freando, nem na
queda), a aproximação lenta, a troca de lado suave e reproduzível pela
semente, o desvio de carro, o giro que segue a curva e não o polegar, o tremor
de banda (não ruído branco) e a roda traseira parada no meio da tela.

Existem por uma razão específica: há uma classe de erro que o banco de provas
não pega, e é justamente a que se introduz sem perceber. "Só aumentei um pouco
o multiplicador do combo" não move nenhuma das dez medidas do banco — e o
combo é o que faz o corredor seduzir.

Rodar um arquivo só:

```bash
python tools/dev.py test tests/unit/test_race_run.gd
```

GdUnit4 6.2.1 vive em `addons/`, versionado. A compatibilidade com Godot 4.7.2
não é declarada por eles (a documentação vai até 4.7.1): foi verificada
rodando. Se um dia o bump da engine quebrar o framework, é aqui que aparece.

## Banco de provas

`scripts/selftest.gd`. Roda o jogo de verdade — mesma física, mesmo caminho de
input, via `Input.action_press` — contra entradas sintéticas, e mede.

Roda com **semente fixa** e nos **defaults do repositório**, ignorando o
que você salvou no F3. Isso é deliberado: a semente já era fixa para o número
ser comparável, mas enquanto o tuning salvo entrava, bastava alguém clicar em
Salvar para "regrediu" e "você mexeu num slider ontem" virarem a mesma coisa.
Para medir os seus ajustes: `--user-tuning`.

A semente mora em `World.setup` (20260831) e os rivais herdam dela — o banco de
provas não sorteia nada por conta própria. Ele já teve uma semente só dele
(4242), que ficou sem uso no dia em que a largada passou a ser o grid do
`World`; um gerador parado ao lado do que realmente decide o sorteio é o tipo
de coisa que faz alguém procurar variação no lugar errado.

### Fases

Dez, nesta ordem: `aceleracao`, `freada`, `inclinacao`, `curva`, `soco`,
`calcada`, `combate`, `corrida`, `disputa`, `batida`.

```bash
python tools/dev.py selftest --fase curva    # 32 s em vez de 110 s
```

`--fase` roda **da primeira até a pedida** e para ali. As fases não são
independentes — a freada precisa da velocidade que a aceleração construiu —
então pular para o meio mediria outra coisa. O que se ganha é não pagar os
45 s de corrida solta para conferir um ajuste de curva.

As quatro últimas fases não medem a moto, medem o **mundo**: "a calçada virou
a linha rápida", "o soco parou de empurrar o rival" e "ninguém mais cruza a
linha de chegada" são regressões que não travam nada. O jogo continua rodando
lindamente sem elas, e ninguém percebe até jogar a fase inteira.

`corrida` também mede **quantos socos o piloto automático toma** nos 45 s. A
medida vale zero hoje, e é de propósito: o piloto não briga, então sem rival
vindo atrás dele ninguém encosta. Ela existe porque a decisão de socar do rival
já rodou por frame, e a essa altura o piloto atravessava a corrida apanhando —
com o comportamento antigo restaurado pelos sliders a mesma rodada mede quatro.

`corrida` também conta **quantos rivais foram ao chão**, separando os que o
jogador derrubou dos que se espatifaram sozinhos. O piloto automático não soca,
então o primeiro número tem que ser **zero** — e essa asserção é a rede embaixo
da regra de autoria: enquanto rival no chão pagava estilo e adrenalina sem
perguntar quem derrubou, ficar parado na largada rendia boost cheio e um quinto
da nota. O segundo número é calibragem: se o pelotão voltar a se espatifar
sozinho, ele salta.

Junto do baseline vai um `FREERUN_HITS_MAX` no código, e os dois não são
redundantes: o baseline aponta que o número **andou**, o `_check` aponta que ele
andou para o lado que importa — e continua valendo depois que alguém atualizar o
baseline, que é justamente quando uma regressão de agressividade passaria batida.

`combate` mede o empurrão do soco do jogador no rival emparelhado, e **só
enquanto ele cambaleia**: de volta a RACING, a IA dele volta a dirigir, e o que
ele andar de lado dali em diante é perseguição. Já mediu errado duas vezes. Na
primeira contava qualquer deslocamento e passava sem o soco acertar; na segunda
o rival chegava caído das fases anteriores, o soco "acertava" sem empurrar, e
os 3,3 m do baseline eram ele indo embora ao levantar. Mora em
`scripts/selftest_combate.gd`, pelo mesmo limite de linhas da `batida`.

`disputa` é a mais nova e a mais barata pelo que cobre: larga o grid a 260 m da
chegada em vez de pagar os 4 km da rota, e é a única prova de que a corrida
**termina**. Além de medir a colocação final, ela confere que quem cruzou a
linha antes do jogador está na frente dele no resultado — se a ordenação do
pelotão quebrar, o jogo continua rodando e o placar passa a mentir em silêncio.

`batida` é a última de propósito: ela mexe no trânsito e nos rivais à mão, e
depois dela não sobra corrida para contaminar. Monta quatro batidas a 15 m, uma
de cada vez, com o resto do mundo longe, e confere o desfecho de cada uma —
traseira de carro lento a 72 km/h **quica**, carro parado a 126 km/h
**derruba**, quina a 126 km/h **desvia** e traseira de moto a 126 km/h
**quica**. A corrida solta conta quedas, mas não diz quais; foi olhando só a
contagem que "toda batida derruba" passou despercebido. Mora em
`scripts/selftest_batida.gd` porque o `selftest.gd` já encostava no limite de
mil linhas do gdlint.

## Baseline

`tests/baseline.json` guarda o que cada medida vale hoje, com tolerância por
métrica. O `selftest` compara e imprime o delta.

Ele existe porque as asserções do banco de provas dizem apenas que a medida
caiu na **faixa jogável**, e a faixa é larga de propósito: o 0-100 passa de
2,75 s a 8,99 s sem reclamar. Andar de 2,75 para 3,40 é outra moto, e passava
calado.

Contagens inteiras e pequenas (quedas, raspadas) têm tolerância maior: uma
unidade já é muito por cento.

Quando estoura, há dois desfechos honestos: ou a mudança era o objetivo, e o
novo valor entra no **mesmo commit** com o motivo escrito; ou é regressão.
Atualizar baseline para silenciar falha que não se entendeu transforma a rede
em enfeite.

As medidas da última rodada ficam em `.dev/metricas.json` — é de lá que se
copiam os valores novos.

### Número por sistema

Cada sistema é determinístico sozinho: a mesma máquina repete a corrida até a
última casa. Entre sistemas, não. Seno e cosseno saem da libm de cada um, e o
Linux arredonda diferente do macOS e do Windows. Quase sempre isso some, mas
num contato longo da física (a moto raspando a lateral de um carro por vários
quadros) 8 mm de diferença num quadro separam a corrida solta inteira. Foi o
que aconteceu no PR das portas: macOS e Windows bateram com o baseline, e o
Linux terminou 86 m à frente, nas duas rodadas.

`valores_por_sistema` no `baseline.json` sobrepõe `valores` só no sistema que
roda (`linux`, `macos`, `windows`). Afrouxar a tolerância resolveria também,
mas afrouxaria nos três, e a regressão de verdade passaria calada junto.

O número de um sistema que você não tem sai do CI: o `selftest` reprovado no CI
imprime as medidas inteiras no log. Só entra o que diverge de verdade, e entrada
que voltou a ficar igual a `valores` sai.

Commit que só mexe em markdown e em `docs/` não roda as provas: o job
`mudancas` do `ci.yml` olha o que mudou, e os jobs pesados pulam. Os checks
obrigatórios continuam reportando (pulado conta como verde), então o PR de
texto entra em um minuto. Qualquer outro arquivo, inclusive o próprio
workflow, roda tudo.

## Onde **não** há rede

Saber disto faz parte do contrato. Nenhum destes é pego por nada automatizado:

- **"Está gostoso?"** Os números dizem que a moto é sã, não que ela é boa. Só
  o polegar decide isso, e o painel F3 existe para essa sessão.
- **"Encostar num rival é uma escolha?"** Meio coberto, e vale saber de que
  metade. A fase `corrida` pega o caso grosseiro — rival que volta a bater por
  proximidade faz a contagem de pancadas saltar. O que ela **não** pega é o
  ajuste fino: 0,9 s de mira antes do soco é aviso suficiente ou é tempo demais
  para reagir? Isso é polegar, e é no F3 que se decide.
- **"Derrubar rival com o soco paga certo?"** Meio coberto. O unitário prova a
  regra da autoria (socou credita, não encostou não credita, o crédito expira)
  e a `corrida` prova que ninguém ganha estilo sem socar. O que **não** tem
  teste é o caminho inteiro do lado que paga — soco derruba de fato e o placar
  soma os 150 —, porque encaixar o rival numa lataria de propósito custaria uma
  fase inteira do banco. E 1,5 s de crédito é um número de polegar: ele cobre o
  cambaleio com folga, mas ninguém mediu se é o corte certo.
- **"A pose do entregador convence?"** Os unitários provam que a roda gira
  para o lado certo e que mão e pé chegam onde devem. Se o joelho abre o
  quanto devia, se o tronco deita o bastante e se o tombo lê como queda é
  olho, e foi conferido em captura, não em teste.
- **"O carro convence?"** Os unitários provam o sentido de cada movimento —
  roda, mola, porta, volante —, não a medida. Se o mergulho de 0,55° por m/s²
  lê como freada a 20 m, se a rolagem anuncia a troca de faixa a tempo e se o
  vidro deixa ver quem dirige sem virar buraco é olho, conferido em captura.
- **"A corrida está disputada?"** O banco prova que ela termina e que o placar
  bate com a ordem de chegada. Se o pelotão está no ritmo certo é outra
  pergunta, e o piloto automático não serve de referência: ele faz uns 24 m/s
  de média contra os 29–37 m/s nominais dos rivais, então termina em último por
  ser ruim, não por o jogo ser difícil.

## Regressão visual

```bash
python tools/dev.py shots
```

Roda o jogo **com tela** — e isso não é escolha, é limitação: em headless o
viewport não renderiza e saem zero PNGs, sem erro nenhum. Por isso é um
comando à parte, e no CI um job à parte com `xvfb`.

**Feche o jogo antes.** Com uma janela do jogo aberta (`dev.py run`), a
`prova` salvou dois quadros e parou ali, sem erro e sem sair: o processo fica
vivo esperando um quadro que não vem, e quem roda com a saída num pipe só vê o
comando não terminar. Visto na V14 com a `prova`; `shots` e `fps` passam pelo
mesmo caminho de render com tela, então valem a mesma regra. Um Godot rodando
`selftest` em outra worktree, headless, não atrapalha.

Ele existe para pegar o que nenhuma medida de física pega: **a tela ficar
errada por inteiro**. O caso registrado no `PROTOTIPO.md` é a pista saindo com
winding anti-horário — o Godot descartava as faces sem um erro no console e o
mundo virava caixas flutuando no vazio. Nenhum dos números do banco de provas
se mexia, porque todos medem física, e a física não sabe que a pista sumiu.

**Não é comparação pixel a pixel**, e não pode ser: driver, GPU e versão de
Mesa mudam o último bit de quase todo pixel, e o teste falharia por motivo
nenhum. O que se compara são três proporções grosseiras da imagem, amostradas
de 4 em 4 pixels:

| medida | o que denuncia |
| --- | --- |
| `visual_fracao_ceu` | quanto da tela é céu, ou seja, onde **não** há mundo |
| `visual_luminancia` | a cena apagar ou estourar |
| `visual_familias_de_cor` | elementos sumindo da cena |

Verificado com o bug de verdade: escondendo o mesh da pista, `fracao_ceu` cai
48,6% e `luminancia` 46,4% — muito além da tolerância. Com a pista de volta, as
três ficam abaixo de 1% de variação.

**Céu é o que o céu de referência diz que é.** Até a P2 da prova visual o fundo
era uma cor chapada, e céu era "pixel parecido com a cor de fundo". Com céu de
verdade o fundo é um degradê, e depois de tonemap, LUT e dither nenhuma cor fixa
diz mais o que é céu. Agora, antes do primeiro quadro, o banco captura o mesmo
quadro com a câmera sem desenhar geometria (`cull_mask = 0`): só o céu, passando
pelo mesmo pós-processamento. Céu é o pixel igual ao dessa referência na mesma
posição. Pista sumida vira céu de novo, porque o céu também desenha o chão
abaixo do horizonte.

Verificado de novo, com o céu de meio-dia: escondendo a pista, `fracao_ceu`
sobe de 0,354 para 0,670 (+89%). A `luminancia` sozinha **não** pegaria mais
(−6%): com céu claro, pista sumida e pista no lugar têm brilho parecido. Quatro
rodadas do mesmo código na mesma máquina variaram menos de 1% nas três medidas.
O ruído de CI, que é o que obrigou a tolerância de 20%, se mede lá.

A medida mora em `scripts/medida_de_quadro.gd`, fora do banco: ele mede a moto,
ela mede a tela.

**A medida é do mundo, sem a HUD.** O pixel de HUD sai igual no quadro e no céu
de referência, e contava como céu: a HUD de arcade (V25) sozinha subia a
`fracao_ceu`. O banco esconde a HUD nos quadros medidos e salva o PNG no quadro
seguinte, com ela de volta e o mundo congelado.

A tolerância é larga (**20%**) de propósito: o CI roda em software rendering sem
GPU contra um baseline gravado numa máquina com GPU, e — o que pesa mais — o
instante do frame capturado flutua com a velocidade do render. Estreitar isso
troca regressão por alarme falso.

Ela era 12% e subiu quando o jogo virou corrida. A simulação continua
determinística: o que varia é **qual frame renderizado** é capturado no instante
pedido, e com a câmera tremendo numa queda dois frames de atraso são duas
imagens bem diferentes. Medido com o **mesmo código**: três rodadas de CI deram
+10,6%, +13,5% e +11,2%, e a própria máquina que gravou o baseline deu +9,6% na
rodada seguinte.

Ou seja, 12% caía **dentro do ruído** e o portão virou cara ou coroa — chegou a
reprovar um commit que só mexeu em markdown, e a mesma alteração passou na
rodada seguinte. Limite dentro da variação não é rede, é moeda. 20% deixa o
dobro de margem sobre o pior caso medido, e o bug de verdade move 46–48%.

Consequência honesta: este teste só promete pegar a tela ficando **errada por
inteiro**. Regressão visual sutil passa por ele, e ninguém deve contar com o
contrário.

Para atualizar: **olhe os PNGs primeiro**, depois `python tools/dev.py shots
--update`.

## A corrida solta depende do tempo acumulado

O trânsito evolui durante **todas** as fases, não só durante a corrida. Então
acrescentar uma fase antes dela muda os números da corrida sem nada no jogo ter
mudado: os carros estão em outro lugar quando ela começa.

Aconteceu ao acrescentar calçada e combate. As asserções passaram nos dois
casos — é o instante do encontro que mudou.

Consequência prática: **inserir fase antes da corrida obriga a regerar o
baseline**, e a justificativa é essa. Não é regressão.


## A noite

A corrida anoitece, mas toda medida roda ao meio-dia: o `main.gd` trava a hora
quando mede. O que cobre a noite:

- `tests/unit/test_hora.gd` confere que o meio-dia da `Hora` é o de antes,
  número por número. É o que segura o banco de provas e os shots.
- `tests/unit/test_noite.gd` confere que cada lâmpada é achada e aponta para o
  lugar certo: a cor do farol na paleta da moto, a marca do farol do carro, o
  segundo UV das janelas.
- `python tools/dev.py shots --noite` mede a corrida de noite contra o
  `tests/baseline_visual_noite.json`. Baseline próprio, porque luminância de
  noite não tem nada a ver com a do dia.

### O `fps` não é determinístico

O `dev.py fps` larga direto na corrida solta, com tela e sem vsync, e os
primeiros quadros pagam a compilação de shader: passam de 130 ms. Acima de oito
passos de física por quadro o Godot descarta o resto, e quantos ele descarta
depende de quanto o quadro demorou. Então a corrida do `fps` muda com qualquer
coisa que mexa no tempo de carga, mesmo sem tocar em física: na noite ela
passou a ter dois carros entrando um no outro, numa corrida que o `selftest`
headless não faz. O `selftest` segue determinístico, e é ele o portão. O que o
`fps` acusa de trânsito é pista para investigar, não regressão.

## Variáveis de ambiente

| Variável | |
| --- | --- |
| `RUSHFOOD_SELFTEST_TRACE=1` | Telemetria da corrida solta, segundo a segundo |
| `RUSHFOOD_SELFTEST_SHOTS=<pasta>` | Despeja PNGs durante a corrida (precisa de display) |
| `RUSHFOOD_SELFTEST_METRICS=<arquivo>` | Grava as medidas em JSON. O `dev.py` já faz isso. |
| `RUSHFOOD_HORA=<0 a 1>` | Trava a hora (0 meio-dia, 1 noite), mesmo medindo. O `--hora` do `dev.py` usa isto. |
| `GODOT_BIN=<caminho>` | Usa outro binário do Godot em vez do gerenciado |

## Testador de sprites

`python tools/dev.py sprites-ver` abre uma janela com todas as folhas de
`assets/sprites/` (a lista nasce da varredura da pasta, então folha nova
aparece sozinha). Cada uma abre em **Folha 2D** ou em **Cena 3D**, e uma
análise em segundo plano marca na lista as que têm aviso.

**Folha 2D**, em pixel inteiro, com cinco vistas:

- *Quadro*: grade, linha do chão, ponto do pé, régua na altura da ficha, caixa
  medida e as notas que a análise deixou naquele quadro;
- *Folha toda*: o atlas com os quadros problemáticos em vermelho (clique
  escolhe o quadro);
- *Referência 3D*: o quadro entregue ao lado do boneco 3D que foi ao Flow
  (`arte/flow/referencia/`) e a sobreposição das duas silhuetas, com o IoU. Na
  moto a referência é o próprio modelo 3D, fotografado ao vivo na mesma
  inclinação e no mesmo soco;
- *Antes e depois*: a base que se fixou (`fixar a folha de agora`, em
  `user://sprites_base/`), a folha de agora e o que mudou em magenta. Fixe antes
  de trocar o arquivo por uma leva nova do Flow;
- *Duas folhas*: o mesmo quadro de duas folhas no mesmo chão e na mesma escala.

**Cena 3D**: o `AtorSprite` e o `PedestreSprite` de verdade sobre asfalto, com
câmera orbitável (a troca de ângulo dos pedestres) ou a câmera do jogo, elenco
lado a lado, régua de 2 m, o chão correndo embaixo do sprite (`pista`), a
cadência de pose do jogo (24, 15, 12 ou 8 Hz), a hora do `Relogio` (céu, sol,
LUT), a paleta com dither e a resolução ÷3. Sem isso o sprite que parece bom
parado treme ou desliza na estrada.

O que a análise (`AnaliseSprites`) olha, por folha:

| Aviso | O que significa |
| --- | --- |
| `borda:` | Meio-tom, franja verde do chroma key ou pixel solto. O shader corta o alfa em 0,5, então vira degrau ou halo no jogo. **Defeito sem discussão.** |
| `referencia: pose longe` | O quadro parece muito menos com a referência que o resto da folha: o Flow não copiou a pose. |
| `angulo:` | O quadro parece mais com uma linha **não vizinha** da referência que com a própria: um ângulo no lugar do outro. Frente e costas têm a mesma silhueta; o que as separa é o rosto, e isso a análise não vê. |
| `escala:` | O quadro sai maior ou menor que a referência, em relação ao resto da linha. |
| `movimento:` | Quadro igual ao anterior onde a referência muda, salto que muda mais (treme) ou menos (trava) que o da referência, ciclo que não emenda, corpo que pula de lado, perna que não abre no passo. |
| `tamanho:` | A pessoa de pé não tem a altura da ficha. |

Pose e movimento são **medidas contra a referência**, e não contra uma opinião:
pessoa e boneco nunca têm a mesma silhueta (roupa, cabelo, bolsa), então os
limites são folgados e o aviso diz o quanto passou. Aviso aqui pede um olhar,
não prova defeito.

**A referência também pode estar errada**, e esta é a parte que ninguém via. O
`ReferenciaSprites` confere a própria referência (boneco colado na borda da
célula, quadros iguais, perna que não abre no ciclo de andar), e o
`CatalogoSprites.recorrentes` soma: o mesmo quadro marcado em três das cinco
pessoas é suspeita da referência que elas dividem, não do Flow. Hoje a
referência da queda (`caida.png`) é **cortada pela grade da própria folha**: o
braço do boneco passa da célula, e é a hipótese mais forte de por que as folhas
de queda saem diferentes dela.

**Jogar** (a terceira aba): um trecho reto de pista com calçada, um carro parado e
a chegada, onde se joga com o sprite em vez de só olhar para ele. Quem anda é o
que o jogo tem, instanciado solto: a `Pessoa` (WASD ou setas, Shift corre), o
`PlayerBike` com os mesmos controles e a mesma física da corrida (W, S, A, D,
Shift, Q e E, R recomeça) e o `Carro` que deixa alguém descer. A galeria
escolhe quem é a pessoa e a barra troca quem se conduz, sprite ou 3D e a
cadência. Cada botão de situação chama a função que o jogo já chama:

| Botão | O que chama |
| --- | --- |
| Atropelar | `Pessoa.atropelar`, na velocidade do slider: voo, dois quiques, queda deitada e mancha no chão |
| Moto em cima dela, de raspão, de longe | uma `MotoFantasma` (só passa, no grupo das motos) pela `_olha_motos` da pessoa: ela pula (susto) |
| Sair do carro (calçada ou rua) | `Carro.abrir_porta` e `desembarcar`: a porta abre, a pessoa sai e a porta bate; do lado da rua ela contorna a traseira |
| Largada | a fiscal com as bandeiras (`sinalizar_largada`) e a saída para a calçada, como no `main.gd` |
| Levantar, moto no início, limpar manchas | refazem o ator e o chão |

Quem está de pé na frente de uma moto **pula**: "moto em cima dela" mostra o
susto, e não o atropelo. A pessoa só deixa de pular se acabou de pular (1 s),
está descendo do carro ou a moto aparece de repente; por isso há o botão
*Atropelar*. Para atropelar de verdade, conduza a moto até ela.

`python tools/dev.py sprites-relatorio` faz a mesma análise sem janela e grava,
em `.dev/sprites_relatorio/`, o `relatorio.md`, a folha marcada e a comparação
com a referência (referência, quadro e sobreposição empilhados por ângulo) das
folhas com aviso. Sai com 1 só por defeito de `borda:`. No testador, os botões
*Exportar* gravam o quadro ampliado, a folha marcada e a mesma comparação em
`.dev/sprites_export/`, para mandar de volta ao Flow ou a quem desenha.

Os testes (`test_silhueta`, `test_analise_sprites`, `test_referencia_sprites`,
`test_base_sprites`, `test_exporta_sprites`, `test_catalogo_sprites`,
`test_galeria_sprites`, `test_jogo_sprite` e `test_jogo_sprite_atores`) guardam o
que não depende de opinião: a conta da silhueta, a detecção de borda suja em
imagens sintéticas, **nenhuma folha entregue com borda suja**, a referência
carregando na grade dos atlas e o estado conhecido dela. O que o catálogo
**não** vê é o movimento a olho: se a passada parece errada, só a Cena mostra.

`sprites-ver` aceita `--sprite=<id>`, `--cena`, `--vista=<quadro|folha|
referencia|base|duas>`, `--quadro=<n>`, `--linha=<n>`, `--jogar`, `--evento=<atropelar|
susto|carro|carro_rua|largada>`, `--espera=<s>` e `--captura=arquivo.png`, que abre
direto naquela tela e salva, para conferir sem abrir a janela na mão.
