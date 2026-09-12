# Testes

Três camadas, e nenhuma substitui a outra.

| Camada | Comando | Tempo | Pega o quê |
| --- | --- | --- | --- |
| Unitários | `python tools/dev.py test` | ~4 s | Lógica pura: pontuação, geometria de faixa, prazo |
| Banco de provas | `python tools/dev.py selftest` | ~89 s | A moto e o mundo rodando de verdade |
| Baseline | (dentro do selftest) | — | O número *andou*, mesmo continuando na faixa jogável |

## Unitários (GdUnit4)

`tests/unit/`. Testam o que não precisa de cena nem de física: `DeliveryRun` é
`RefCounted` puro, e as estáticas de `RoadTrack` são geometria.

Existem por uma razão específica: há uma classe de erro que o banco de provas
não pega, e é justamente a que se introduz sem perceber. "Só aumentei um pouco
o multiplicador do combo" não move nenhuma das dez medidas do banco — e o
combo é o que faz o corredor seduzir.

Rodar um arquivo só:

```bash
python tools/dev.py test tests/unit/test_delivery_run.gd
```

GdUnit4 6.2.1 vive em `addons/`, versionado. A compatibilidade com Godot 4.7.2
não é declarada por eles (a documentação vai até 4.7.1): foi verificada
rodando. Se um dia o bump da engine quebrar o framework, é aqui que aparece.

## Banco de provas

`scripts/selftest.gd`. Roda o jogo de verdade — mesma física, mesmo caminho de
input, via `Input.action_press` — contra entradas sintéticas, e mede.

Roda com **semente fixa** (4242) e nos **defaults do repositório**, ignorando o
que você salvou no F3. Isso é deliberado: a semente já era fixa para o número
ser comparável, mas enquanto o tuning salvo entrava, bastava alguém clicar em
Salvar para "regrediu" e "você mexeu num slider ontem" virarem a mesma coisa.
Para medir os seus ajustes: `--user-tuning`.

### Fases

Sete, nesta ordem: `aceleracao`, `freada`, `inclinacao`, `curva`, `soco`,
`bifurcacao`, `corrida`.

```bash
python tools/dev.py selftest --fase curva    # 32 s em vez de 89 s
```

`--fase` roda **da primeira até a pedida** e para ali. As fases não são
independentes — a freada precisa da velocidade que a aceleração construiu —
então pular para o meio mediria outra coisa. O que se ganha é não pagar os
45 s de corrida solta para conferir um ajuste de curva.

As três últimas fases não medem a moto, medem o **mundo**: "o engarrafamento
parou de nascer" e "o atalho virou um caminho mais longo" são regressões que
não travam nada. O jogo continua rodando lindamente sem elas, e ninguém percebe
até jogar a fase inteira.

## Baseline

`tests/baseline.json` guarda o que cada medida vale hoje, com tolerância por
métrica. O `selftest` compara e imprime o delta.

Ele existe porque as asserções do banco de provas dizem apenas que a medida
caiu na **faixa jogável**, e a faixa é larga de propósito: o 0-100 passa de
2,75 s a 8,99 s sem reclamar. Andar de 2,75 para 3,40 é outra moto, e passava
calado.

Contagens inteiras e pequenas (quedas, engarrafamentos) têm tolerância maior:
uma unidade já é muito por cento.

Quando estoura, há dois desfechos honestos: ou a mudança era o objetivo, e o
novo valor entra no **mesmo commit** com o motivo escrito; ou é regressão.
Atualizar baseline para silenciar falha que não se entendeu transforma a rede
em enfeite.

As medidas da última rodada ficam em `.dev/metricas.json` — é de lá que se
copiam os valores novos.

## Onde **não** há rede

Saber disto faz parte do contrato. Nenhum destes é pego por nada automatizado:

- **Raspada dentro do atalho.** Não pontua: a frota vive na avenida e os
  offsets das duas curvas se parecem sem querer dizer a mesma coisa.
- **Regressão visual.** `RUSHFOOD_SELFTEST_SHOTS=<pasta>` despeja PNGs da
  corrida, mas nada os compara — e **não funciona em headless**: sob o driver
  dummy o viewport não rende e saem zero arquivos. Precisa de display real.
- **"Está gostoso?"** Os números dizem que a moto é sã, não que ela é boa. Só
  o polegar decide isso, e o painel F3 existe para essa sessão.

## A corrida solta depende do tempo acumulado

Os semáforos e o trânsito evoluem durante **todas** as fases, não só durante a
corrida. Então acrescentar uma fase antes dela desloca o ciclo dos semáforos e
muda os números da corrida sem nada no jogo ter mudado.

Aconteceu ao acrescentar calçada e combate: 19 s a mais antes da corrida
fizeram "carros parados no vermelho" cair de 52 para 10. As asserções passaram
nos dois casos — é o instante do encontro com o semáforo que mudou, não o
semáforo.

Duas consequências práticas:

- **Inserir fase antes da corrida obriga a regerar o baseline**, e a
  justificativa é essa. Não é regressão.
- **`transito_parados_max` é a medida mais volátil do banco.** Ela responde ao
  instante em que a corrida começa. Para saber se o semáforo em si regrediu,
  `transito_engarrafamentos` e `jam_fila_m` são mais firmes.

## Variáveis de ambiente

| Variável | |
| --- | --- |
| `RUSHFOOD_SELFTEST_TRACE=1` | Telemetria da corrida solta, segundo a segundo |
| `RUSHFOOD_SELFTEST_SHOTS=<pasta>` | Despeja PNGs durante a corrida (precisa de display) |
| `RUSHFOOD_SELFTEST_METRICS=<arquivo>` | Grava as medidas em JSON. O `dev.py` já faz isso. |
| `GODOT_BIN=<caminho>` | Usa outro binário do Godot em vez do gerenciado |
