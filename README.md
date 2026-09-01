# RushFood — protótipo

Protótipo *greybox* de um jogo estilo Road Rash com entregadores de app.
Godot 4.4, mundo 3D real renderizado num `SubViewport` de 320×180.

Ele existe para responder uma pergunta e só uma: **acelerar, inclinar, se
enfiar no corredor e bater está gostoso?** Nada de arte, áudio ou menu até
essa resposta ser sim.

## Rodar

Abra a pasta no editor do Godot 4.4+ e dê play, ou:

```sh
godot --path .
```

## Controles

| Tecla | Ação |
| --- | --- |
| `W` / `↑` | acelerar |
| `S` / `↓` | frear |
| `A` `D` / `←` `→` | inclinar (é a inclinação que faz a moto virar) |
| `Shift` | boost (gasta adrenalina) |
| `Q` / `E` | soco pra esquerda / direita |
| `R` | reiniciar a corrida |
| `F1` | liga/desliga o pixel de 320×180 |
| `F2` | alterna câmera (perseguição / capacete / diagnóstico) |
| `F3` | painel de tuning (abre em janela separada) |

Controle de videogame também funciona: stick esquerdo inclina, `A`/`B`
aceleram e freiam, `X`/`Y` socam.

## Ajustar o feel

`F3` abre um painel com dois blocos de sliders, editáveis com a moto andando:
**MOTO** (`scripts/bike_tuning.gd`, o feel) e **MUNDO**
(`scripts/world_tuning.gd`, densidade do trânsito e rivais).

Ele abre em **janela separada do sistema**, não por cima do jogo — arraste pro
lado ou pro segundo monitor e ajuste vendo o efeito. A posição e o tamanho onde
você largar ficam guardados pra próxima sessão. Fecha no `F3` ou no X.

**Salvar** grava em `user://`, que é um override *local*: sobrevive a fechar o
jogo, mas não vai pro git nem pro executável. Quando os valores estiverem bons,
promova para os defaults do repositório:

```sh
python3 tools/promote_tuning.py          # mostra o que mudaria
python3 tools/promote_tuning.py --apply --clear-user
```

`--clear-user` apaga o override depois de promover, então o jogo passa a rodar
nos defaults novos de verdade em vez de continuar vendo o seu por cima.

## Release

Todo merge na `master` dispara [uma pipeline](.github/workflows/release.yml) que
roda o banco de provas, exporta as três plataformas e publica uma release no
GitHub:

| Arquivo | Plataforma |
| --- | --- |
| `RushFood-windows.zip` | Windows x86_64 |
| `RushFood-linux.zip` | Linux x86_64 |
| `RushFood-macos.zip` | macOS universal (Intel e Apple Silicon) |

A tag sai de `config/version` no `project.godot`. **Bump essa versão antes de
merjar**; sem bump, a release existente é substituída em vez de nascer uma nova.

Se o banco de provas falhar, nada é publicado — binário quebrado no ar é pior
que release atrasada.

Nenhum binário é assinado, então Windows e macOS reclamam na primeira abertura.
O [docs/INSTALAR.txt](docs/INSTALAR.txt) vai dentro de cada zip explicando como
passar. Assinar de verdade exige certificado pago (e conta de desenvolvedor
Apple), que não se justifica num protótipo.

Pushes em qualquer outra branch rodam só o banco de provas
([ci.yml](.github/workflows/ci.yml)), pra a `develop` não chegar quebrada no dia
da release.

## Banco de provas

```sh
godot --headless --path . -- --selftest
```

Roda a moto de verdade contra entradas sintéticas e mede 0–100, freada, tempo
de inclinação, raio de curva e a janela do soco; falha com código de saída 1 se
algum número sair da faixa jogável.

Roda sempre nos **defaults do repositório**, ignorando o que você salvou no F3 —
senão o número deixa de ser comparável entre rodadas. Para medir os seus
ajustes, acrescente `--selftest-user`. Detalhes e números atuais em
[docs/PROTOTIPO.md](docs/PROTOTIPO.md).

Variáveis de ambiente úteis: `RUSHFOOD_SELFTEST_TRACE=1` imprime a telemetria
da corrida solta segundo a segundo; `RUSHFOOD_SELFTEST_SHOTS=<pasta>` pula o
banco e despeja PNGs da corrida.
