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
| `F3` | painel de tuning ao vivo |

Controle de videogame também funciona: stick esquerdo inclina, `A`/`B`
aceleram e freiam, `X`/`Y` socam.

## Ajustar o feel

`F3` abre um painel com todas as constantes da moto (`scripts/bike_tuning.gd`)
em sliders, editáveis com a moto andando. **Salvar** grava em
`user://tuning.tres` e a próxima sessão já abre com seus valores.

## Banco de provas

```sh
godot --headless --path . -- --selftest
```

Roda a moto de verdade contra entradas sintéticas e mede 0–100, freada, tempo
de inclinação, raio de curva e a janela do soco; falha com código de saída 1 se
algum número sair da faixa jogável. Detalhes e números atuais em
[docs/PROTOTIPO.md](docs/PROTOTIPO.md).

Variáveis de ambiente úteis: `RUSHFOOD_SELFTEST_TRACE=1` imprime a telemetria
da corrida solta segundo a segundo; `RUSHFOOD_SELFTEST_SHOTS=<pasta>` pula o
banco e despeja PNGs da corrida.
