# RushFood — protótipo

Protótipo *greybox* de um jogo estilo Road Rash com entregadores de app.
Godot (versão fixada em [`.godot-version`](.godot-version)), mundo 3D real
renderizado num `SubViewport` de 320×180. Desenvolvido em Windows, macOS e
Linux; o CI roda nos três.

**Vai mexer no código?** O contrato de operação está em
[CLAUDE.md](CLAUDE.md) — comandos, o portão de qualidade, e os invariantes que
não se quebram sem conversa.

É uma **corrida**: seis motos na pista, e quem decide o resultado é a posição
na chegada. O trânsito flui em quatro faixas, muda de faixa sem olhar e abre
porta de carro encostado. A pista tem curva e **ladeira** de até 14%, que cobra
gás na subida e devolve na descida. O corredor entre os carros é o jogo — e o
prazo e a bag da entrega pesam na nota final, nunca na classificação.

Ele existe para responder uma pergunta e só uma: **acelerar, inclinar, se
enfiar no corredor e bater está gostoso?** Nada de arte, áudio ou menu até
essa resposta ser sim.

O briefing original, escrito antes de existir uma linha de código, está
congelado em [docs/GDD.md](docs/GDD.md). Onde ele já não bate com o que foi
construído, a seção Deriva diz o que mudou e por quê.

## Rodar

Só é preciso ter Python 3.10+. A engine o script baixa:

```sh
python tools/dev.py setup
python tools/dev.py run
```

Ou abra a pasta no editor do Godot e dê play. Detalhes de ambiente em
[docs/AMBIENTE.md](docs/AMBIENTE.md).

O jogo abre num menu: **JOGAR**, **CONFIGURACOES** (pixel, câmera e o painel de
tuning) e **SAIR**. A corrida termina numa tela de resultado que oferece correr
de novo ou voltar. `ESC` no meio da corrida congela e abre o menu.

## Controles

| Tecla | Ação |
| --- | --- |
| `W` / `↑` | acelerar |
| `S` / `↓` | frear |
| `A` `D` / `←` `→` | inclinar (é a inclinação que faz a moto virar) |
| `Shift` | boost (gasta adrenalina) |
| `Q` / `E` | soco pra esquerda / direita |
| `R` | reiniciar a corrida |
| `ESC` | menu (congela a corrida; `CONTINUAR` devolve ela do jeito que estava) |
| `ENTER` / setas | navegar o menu |
| `1` ou `F1` | liga/desliga o pixel de 320×180 |
| `2` ou `F2` | alterna câmera (perseguição / capacete / diagnóstico) |
| `3` ou `F3` | painel de tuning (abre em janela separada) |

No macOS as teclas de função são do sistema (brilho, Mission Control), então
`F1`–`F3` só chegam no jogo com `Fn` segurado. Use `1`, `2` e `3`.

Controle de videogame também funciona: stick esquerdo inclina, `A`/`B`
aceleram e freiam, `X`/`Y` socam.

## Ajustar o feel

`F3` abre um painel com dois blocos de sliders, editáveis com a moto andando:
**MOTO** (`scripts/bike_tuning.gd`, o feel) e **MUNDO**
(`scripts/world_tuning.gd`, trânsito e rivais).

O que **não** tem slider, de propósito: a forma da pista em si — curvatura
máxima e rampa máxima (`MAX_GRADE`). A pista é gerada uma vez no boot e o `R`
não a refaz, então slider ali mentiria. São constantes documentadas em
`road_track.gd`.

Ele abre em **janela separada do sistema**, não por cima do jogo — arraste pro
lado ou pro segundo monitor e ajuste vendo o efeito. A posição e o tamanho onde
você largar ficam guardados pra próxima sessão. Fecha no `F3` ou no X.

**Salvar** grava em `user://`, que é um override *local*: sobrevive a fechar o
jogo, mas não vai pro git nem pro executável. Quando os valores estiverem bons,
promova para os defaults do repositório:

```sh
python tools/promote_tuning.py           # mostra o que mudaria
python tools/promote_tuning.py --apply --clear-user
```

`--clear-user` apaga o override depois de promover, então o jogo passa a rodar
nos defaults novos de verdade em vez de continuar vendo o seu por cima.

## Release

Publicar é ato deliberado: a release sai de uma **tag**, não de um merge.
[A pipeline](.github/workflows/release.yml) roda o banco de provas, exporta as
três plataformas e publica no GitHub:

| Arquivo | Plataforma |
| --- | --- |
| `RushFood-windows.zip` | Windows x86_64 |
| `RushFood-linux.zip` | Linux x86_64 |
| `RushFood-macos.zip` | macOS universal (Intel e Apple Silicon) |

```sh
git tag v0.0.3 && git push origin v0.0.3
```

A tag precisa bater com `config/version` no `project.godot` — único lugar pra
mexer, a pipeline injeta essa versão no bundle do macOS na hora do export. Se
os dois discordarem, a pipeline recusa antes de publicar qualquer coisa.

Merge na `master` **não** publica nada: com IA operando no repositório, merge
que distribui binário é um botão sem trava.

Se o banco de provas falhar, nada é publicado — binário quebrado no ar é pior
que release atrasada.

Nenhum binário é assinado, então Windows e macOS reclamam na primeira abertura.
O [docs/INSTALAR.txt](docs/INSTALAR.txt) vai dentro de cada zip explicando como
passar. Assinar de verdade exige certificado pago (e conta de desenvolvedor
Apple), que não se justifica num protótipo.

Todo push roda [ci.yml](.github/workflows/ci.yml): lint, formatação e a
bateria de testes nos **três sistemas operacionais**, pra a `develop` não
chegar quebrada no dia da release — e pra bug de plataforma aparecer no dia em
que nasce.

## Testes

```sh
python tools/dev.py test       # unitários, ~4 s
python tools/dev.py selftest   # banco de provas, ~110 s
```

O banco de provas roda a moto de verdade contra entradas sintéticas e mede
0–100, freada, tempo de inclinação, raio de curva, a janela do soco e a chegada
da corrida; falha com código 1 se algum número sair da faixa jogável **ou** se
ele andar mais do que `tests/baseline.json` tolera.

Roda sempre nos **defaults do repositório**, ignorando o que você salvou no F3 —
senão o número deixa de ser comparável entre rodadas. Para medir os seus
ajustes, `--user-tuning`.

Iterando em algo específico, dá pra parar antes da corrida solta:

```sh
python tools/dev.py selftest --fase curva    # 32 s em vez de 110 s
```

Detalhes, camadas e os buracos conhecidos de cobertura em
[docs/TESTES.md](docs/TESTES.md); os números atuais e o que eles significam em
[docs/PROTOTIPO.md](docs/PROTOTIPO.md).
