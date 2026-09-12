# Ambiente e toolchain

O objetivo deste arquivo é que a mesma entrada produza a mesma saída em
Windows, macOS, Linux e no CI. Quando isso falha, é bug — e a seção final
registra os que já apareceram, porque vão voltar.

## Começar

Só é preciso ter **Python 3.10+**. O resto o script baixa.

```bash
python tools/dev.py setup     # engine + ferramentas Python (~100 MB)
python tools/dev.py doctor    # confere
```

`setup` sem argumento também baixa os **export templates** (~1 GB), que só o
`export` usa. Para pular: `--skip-templates`.

Tudo o que ele baixa vai para `.dev/`, fora do versionamento. Apagar `.dev/` e
rodar `setup` de novo é sempre seguro.

## Versão da engine

`.godot-version` é a **fonte única**. O CI lê o mesmo arquivo; bumpar a engine
é editar uma linha.

Antes disso, a versão vivia em três lugares que discordavam: o README dizia
4.4, o `project.godot` declarava 4.4 e o CI rodava 4.7.2. O `config/features`
do `project.godot` continua dizendo 4.4 porque ali é *mínimo compatível*, não
versão de desenvolvimento.

Como o `dev.py` acha o Godot, nesta ordem:

1. `GODOT_BIN`, se apontar para um arquivo existente
2. A instalação gerenciada em `.dev/godot/<versão>/`
3. `godot` no PATH — **com aviso** se a versão não bater

O PATH vem por último de propósito: rodar o banco de provas numa engine
diferente da fixada produz um número que não dá para comparar com o do CI, que
é exatamente para o que ele serve.

## Ferramentas Python

`tools/requirements.txt`, instalado num venv em `.dev/venv` — nunca no Python
do sistema. Ninguém precisa de permissão de administrador para contribuir, e a
versão do linter passa a ser a mesma em todas as máquinas. Linter que muda de
opinião entre duas máquinas gera diff que ninguém pediu.

## CI

| Workflow | Quando | O quê |
| --- | --- | --- |
| `ci.yml` | todo push e PR | lint + format, e testes nos três SOs |
| `release.yml` | tag `v*` | confere a tag, testa, exporta, publica |

A matrix não tem `fail-fast`: quando um sistema diverge, o que interessa é
saber quais outros divergiram junto.

A action de setup não baixa nada por conta própria — chama `tools/dev.py
setup`, o mesmo comando local. Enquanto eram dois caminhos, "passa aqui e
quebra lá" era questão de tempo.

## Release

A tag é o gatilho, e precisa bater com `config/version` no `project.godot`:

```bash
# bump de config/version no project.godot, commit, merge em master
git tag v0.0.3 && git push origin v0.0.3
```

Nenhum binário é assinado, então Windows e macOS reclamam na primeira abertura;
`docs/INSTALAR.txt` vai dentro de cada zip explicando. Assinar de verdade exige
certificado pago e conta de desenvolvedor Apple, que não se justifica num
protótipo.

## Armadilhas de plataforma já encontradas

Todas custaram tempo e nenhuma dá erro claro.

**O `.exe` do Godot no Windows engole a saída.** O binário padrão é
GUI-subsystem: ele não se anexa ao console de quem chamou. Com a saída
redirecionada — que é como todo CI e todo agente roda comando — o banco de
provas devolvia **código 0 e nenhuma linha**. Pior que falhar: quem lê vê
"passou" sem os números, e numa regressão vê "falhou" sem saber qual
verificação caiu. O `_console.exe` vem no mesmo zip para isso, e o `dev.py`
usa ele em todo comando headless.

**`Path.write_text` grava CRLF no Windows.** Ele traduz `\n` para o fim de
linha do sistema, e o `.gitattributes` deste repo manda LF. A primeira
ferramenta rodada no Windows gerava diff de 100% das linhas, com a mudança de
verdade perdida no meio. Toda escrita em arquivo versionado passa por
`write_text_lf`.

**O gdformat também grava CRLF.** Mesma classe, ferramenta de terceiro: o
`dev.py` normaliza depois dele.

**Cada sistema tem sua pasta de dados do Godot.** `%APPDATA%\Godot`,
`~/Library/Application Support/Godot`, `~/.local/share/godot`. O
`promote_tuning.py` tinha o caminho do macOS fixo e dizia "nada salvo" nos
outros dois com o arquivo no lugar. Vive em `godot_data_dir()` agora.

**O import é obrigatório depois de criar um `class_name`.** Ele só entra no
cache de classes globais pelo scan do editor; sem isso o Godot headless trava
sem imprimir nada. O `dev.py` roda o import antes de testar, sempre.

**Screenshot não funciona em headless.** O driver dummy não rende: saem zero
PNGs, sem erro. Regressão visual precisa de display real.
