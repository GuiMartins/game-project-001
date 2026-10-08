# Ambiente e toolchain

O objetivo deste arquivo é que a mesma entrada produza a mesma saída em
Windows, macOS, Linux e no CI. Quando isso falha, é bug — e a seção final
registra os que já apareceram, porque vão voltar.

## Começar

É preciso ter **Python 3.10+** e o **Git LFS** instalado *antes* de clonar
(`git lfs install`, uma vez por máquina). O resto o script baixa.

Sem o LFS, o clone traz ponteiros de texto no lugar do modelo do entregador e
das texturas, e o jogo não abre. Ver a armadilha do `valid=false` abaixo: o
conserto não é só baixar os arquivos depois.

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

## Blender (só para mexer no modelo)

Jogar, testar e exportar não precisam de Blender: o jogo carrega o `.glb`
versionado. Ele só entra para mudar o entregador, os prédios ou os carros, e aí
o caminho é o script, não o `.blend`:

```bash
blender --background --factory-startup --python arte/entregador.py
blender --background --factory-startup --python arte/xre300.py
blender --background --factory-startup --python arte/pcx160.py
blender --background --factory-startup --python arte/predios.py
blender --background --factory-startup --python arte/carros.py
```

Testado no Blender 5.2. Cada script apaga a cena, monta o modelo e regrava o
seu `.blend` em `arte/` e a sua pasta em `assets/` (`entregador/`, `predios/`, `carros/`). A saída é reprodutível byte a
byte — mesma versão do Blender, mesmo `.glb` —, então regerar sem mudar nada
não gera diff. O `--factory-startup` existe para isso: deixa de fora os add-ons
e as preferências de quem roda.

## O LUT de cor

`assets/visual/lut_dia.png` é build de `arte/paleta.py`, que roda com o Python
do sistema, sem dependência:

```bash
python arte/paleta.py            # o LUT do dia
python arte/paleta.py --neutro   # o identidade, para conferir a importação
```

O PNG é importado como `Texture3D` (`importer="3d_texture"`,
`slices/horizontal=16` no `.import`). Se o Godot um dia o reimportar como
textura 2D, o `preload` do `world.gd` quebra com erro de tipo, e não com tela
estranha. Isso é bom.

## CI

| Workflow | Quando | O quê |
| --- | --- | --- |
| `ci.yml` | todo push e PR | lint + format, e testes nos três SOs |
| `release.yml` | tag `v*` | confere a tag, testa, exporta, publica |

A matrix não tem `fail-fast`: quando um sistema diverge, o que interessa é
saber quais outros divergiram junto.

O job `banco-de-provas` é um **agregador**, e é ele que as branches protegidas
exigem. Uma matrix nunca produz um check com um nome só — produz um por
sistema — então o agregador mantém o nome que a proteção espera e só passa
quando os três passam. Mexer nos nomes de job aqui quebra o push nas branches
protegidas: se isso acontecer, o sintoma é `Required status check
"banco-de-provas" is expected`.

A action de setup não baixa nada por conta própria — chama `tools/dev.py
setup`, o mesmo comando local. Enquanto eram dois caminhos, "passa aqui e
quebra lá" era questão de tempo.

Todo job que abre o jogo faz checkout **com Git LFS** (`lfs: true`): provas,
regressão visual e release. Os `.png` e `.glb` moram no LFS, e sem isso o
checkout traz o ponteiro de texto no lugar do arquivo. O Godot falha ao
importar e não derruba nada enquanto nenhuma cena usa o asset — o import sai
com código 0 —, então o buraco só aparece no dia em que uma cena usa, e só no
CI, porque na máquina de quem desenvolve o LFS está instalado. O job de
qualidade fica sem LFS: lint e format só leem `.gd`.

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

**Asset importado como ponteiro do LFS não se reimporta sozinho.** Clonar sem
o Git LFS traz o ponteiro de texto no lugar do `.glb`; o Godot falha ao
importar e grava `valid=false` no `.import`, que é versionado. Quando o arquivo
de verdade chega, ele **não** tenta de novo — nem com o conteúdo trocado, nem
com `dev.py import`. O conserto: apagar as linhas `valid=false` e `source_md5`
do `.import`, apagar `.godot/imported/<arquivo>-*` e rodar `python tools/dev.py
import`. E nunca commitar um `.import` com `valid=false`.

**O Godot importa `.blend` sozinho quando acha o Blender instalado.** Aqui o
`.blend` é fonte de trabalho e o jogo usa o `.glb`: importar os dois daria duas
cópias do mesmo modelo e, no CI, sem Blender, um erro. O `arte/.gdignore` tira
a pasta do scan.

**O `.glb` com textura embutida vira um PNG a mais.** O padrão do importador
extrai a textura para `<glb>_<imagem>.png` ao lado do arquivo, uma cópia que
ninguém pediu e que diverge da fonte na próxima regeração.
`gltf/embedded_image_handling=3` no `.import` deixa embutida. Pela mesma
família: todo PNG de arte leva `detect_3d/compress_to=0`, senão o editor o
recomprime em VRAM, com perda, no primeiro uso em 3D, sem avisar.

**A esfera do Blender muda a ordem das faces de uma execução para outra.** O
exportador repassava isso para o índice do `.glb`, e regerar o modelo sem
mexer em nada dava diff de arquivo inteiro. O `arte/entregador.py` triangula e
ordena as faces antes de exportar.
