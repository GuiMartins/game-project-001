#!/usr/bin/env python3
"""Ponto de entrada unico do projeto: acha (ou baixa) o Godot e roda as tarefas.

Existe por um motivo so: o banco de provas e o portao de qualidade deste
repositorio, e ate agora ele so rodava no CI, porque `godot` nao esta no PATH
da maioria das maquinas e ninguem sabe qual versao usar. Quem chega no projeto
- pessoa ou agente - precisa de UM comando que funcione sem adivinhar nada.

    python tools/dev.py doctor     # onde esta o Godot e qual versao
    python tools/dev.py setup      # baixa Godot + export templates fixados
    python tools/dev.py selftest   # importa e roda o banco de provas
    python tools/dev.py run        # abre o jogo
    python tools/dev.py export     # exporta as tres plataformas
    python tools/dev.py versao patch  # sobe a versao: o merge dela publica
    python tools/dev.py changelog  # o que mudou desde a release anterior

A versao vem de `.godot-version`, que e a fonte unica: o CI le o mesmo arquivo.
Bumpar a engine e editar uma linha, nao cacar constantes em tres workflows.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import pathlib
import platform
import re
import shutil
import subprocess
import sys
import urllib.request
import zipfile

PROJECT = pathlib.Path(__file__).resolve().parent.parent
VERSION_FILE = PROJECT / ".godot-version"
# Fora do versionamento de proposito (ver .gitignore): e cache de maquina,
# nao conteudo do projeto.
DEV_DIR = PROJECT / ".dev"
PROJECT_NAME = "RushFood - Prototipo"


def godot_version() -> str:
    return VERSION_FILE.read_text(encoding="utf-8").strip()


def godot_data_dir() -> pathlib.Path:
    """Pasta de dados do Godot no sistema (export_templates, app_userdata).

    Cada plataforma tem a sua, e errar essa e o motivo classico de "o export
    falha dizendo que falta template" com o template baixado.
    """
    home = pathlib.Path.home()
    if sys.platform == "win32":
        base = os.environ.get("APPDATA")
        return (pathlib.Path(base) if base else home / "AppData/Roaming") / "Godot"
    if sys.platform == "darwin":
        return home / "Library/Application Support/Godot"
    base = os.environ.get("XDG_DATA_HOME")
    return (pathlib.Path(base) if base else home / ".local/share") / "godot"


def godot_user_data() -> pathlib.Path:
    """Onde o jogo grava o override do painel F3 (user://)."""
    return godot_data_dir() / "app_userdata" / PROJECT_NAME


def _download_names(version: str) -> tuple[str, str]:
    """(nome do zip no release, caminho do binario dentro dele)."""
    machine = platform.machine().lower()
    if sys.platform == "win32":
        arch = "win_arm64" if machine in ("arm64", "aarch64") else "win64"
        return (f"Godot_v{version}-stable_{arch}.exe.zip",
                f"Godot_v{version}-stable_{arch}.exe")
    if sys.platform == "darwin":
        return (f"Godot_v{version}-stable_macos.universal.zip",
                "Godot.app/Contents/MacOS/Godot")
    arch = "arm64" if machine in ("arm64", "aarch64") else "x86_64"
    return (f"Godot_v{version}-stable_linux.{arch}.zip",
            f"Godot_v{version}-stable_linux.{arch}")


def managed_binary(version: str) -> pathlib.Path:
    _, inner = _download_names(version)
    return DEV_DIR / "godot" / version / inner


def _version_matches(binary: pathlib.Path, version: str) -> bool:
    try:
        out = subprocess.run([str(binary), "--version"], capture_output=True,
                             text=True, timeout=60).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return False
    return out.startswith(version)


def _console_variant(binary: pathlib.Path) -> pathlib.Path:
    """No Windows, a variante _console.exe do mesmo zip - ou o proprio binario.

    O `.exe` padrao do Godot no Windows e GUI-subsystem: ele NAO se anexa ao
    console de quem chamou, entao com a saida redirecionada - que e como todo
    script de CI e todo agente roda comando - o banco de provas devolve codigo
    0 e nenhuma linha. O relatorio existe e ninguem ve.

    Isso e pior que falhar: um agente le "passou" sem os numeros, e numa
    regressao le "falhou" sem saber qual verificacao caiu. O `_console.exe`
    vem no mesmo zip justamente pra isso e so faz sentido nos comandos
    headless; pro `run` a janela de console a mais seria ruido.
    """
    if sys.platform != "win32" or binary.suffix.lower() != ".exe":
        return binary
    console = binary.with_name(f"{binary.stem}_console.exe")
    return console if console.is_file() else binary


def find_godot(version: str, *, quiet: bool = False) -> pathlib.Path | None:
    """GODOT_BIN > instalacao gerenciada em .dev/ > PATH.

    O PATH vem por ultimo e com aviso: rodar o banco de provas numa engine
    diferente da fixada produz um numero que nao da pra comparar com o do CI,
    que e justamente para o que o banco de provas serve.
    """
    env = os.environ.get("GODOT_BIN")
    if env:
        path = pathlib.Path(env)
        if path.is_file():
            return path
        print(f"! GODOT_BIN aponta pra {path}, que nao existe", file=sys.stderr)

    managed = managed_binary(version)
    if managed.is_file():
        return managed

    which = shutil.which("godot") or shutil.which("godot4")
    if which:
        path = pathlib.Path(which)
        if not quiet and not _version_matches(path, version):
            print(f"! {path} nao e a versao fixada ({version}). "
                  "Rode `python tools/dev.py setup` pra instalar a certa.",
                  file=sys.stderr)
        return path
    return None


def require_godot(version: str) -> pathlib.Path:
    binary = find_godot(version)
    if binary is None:
        sys.exit("Godot nao encontrado. Rode `python tools/dev.py setup` "
                 "(baixa a versao fixada) ou aponte GODOT_BIN pro seu binario.")
    return binary


def _fetch(url: str, dest: pathlib.Path) -> None:
    print(f"  baixando {url}")
    dest.parent.mkdir(parents=True, exist_ok=True)
    with urllib.request.urlopen(url) as response, dest.open("wb") as out:
        shutil.copyfileobj(response, out)


def _fail(message: str) -> int:
    print(f"! {message}", file=sys.stderr)
    return 1


def write_text_lf(path: pathlib.Path, text: str) -> None:
    """Grava sempre com LF, em qualquer sistema.

    `Path.write_text` no modo texto traduz \\n pro fim de linha do sistema, e
    no Windows isso reescreve o arquivo INTEIRO em CRLF. Como o .gitattributes
    deste repo manda LF, a primeira vez que alguem roda uma ferramenta no
    Windows o diff sai com 100% das linhas mudadas e a mudanca de verdade some
    no meio. Toda escrita em arquivo versionado passa por aqui.
    """
    path.write_text(text, encoding="utf-8", newline="\n")


def cmd_setup(args: argparse.Namespace) -> int:
    """Baixa a engine e os export templates fixados, nas pastas que o Godot espera."""
    version = godot_version()
    base = f"https://github.com/godotengine/godot/releases/download/{version}-stable"
    zip_name, inner = _download_names(version)

    target = DEV_DIR / "godot" / version
    binary = target / inner
    if binary.is_file():
        print(f"= engine ja instalada: {binary}")
    else:
        archive = DEV_DIR / "cache" / zip_name
        if not archive.is_file():
            _fetch(f"{base}/{zip_name}", archive)
        print(f"  extraindo em {target}")
        with zipfile.ZipFile(archive) as zf:
            zf.extractall(target)
        if not binary.is_file():
            return _fail(f"o zip nao trouxe {inner}")
        binary.chmod(0o755)
        print(f"+ engine: {binary}")

    ensure_venv()

    # Os templates so fazem falta no `export`, e sao ~1 GB. Ficam atras de uma
    # flag pra quem so quer rodar o banco de provas nao pagar por eles.
    if args.skip_templates:
        print("  templates pulados (--skip-templates); `export` vai pedir por eles")
        return 0

    version_dir = godot_data_dir() / "export_templates" / f"{version}.stable"
    if version_dir.is_dir() and any(version_dir.iterdir()):
        print(f"= export templates ja instalados em {version_dir}")
        return 0

    tpz = DEV_DIR / "cache" / f"Godot_v{version}-stable_export_templates.tpz"
    if not tpz.is_file():
        _fetch(f"{base}/Godot_v{version}-stable_export_templates.tpz", tpz)
    staging = DEV_DIR / "cache" / "templates"
    if staging.exists():
        shutil.rmtree(staging)
    with zipfile.ZipFile(tpz) as zf:
        zf.extractall(staging)
    # O nome da pasta sai do version.txt do pacote, nao de um palpite: 4.7.2
    # vira "4.7.2.stable", mas um beta viraria outra coisa.
    label = (staging / "templates" / "version.txt").read_text(encoding="utf-8").strip()
    dest = godot_data_dir() / "export_templates" / label
    dest.mkdir(parents=True, exist_ok=True)
    for item in (staging / "templates").iterdir():
        shutil.move(str(item), str(dest / item.name))
    shutil.rmtree(staging)
    print(f"+ export templates: {dest}")
    return 0


def venv_bin(name: str) -> pathlib.Path:
    """Caminho de um executavel dentro do venv de ferramentas."""
    folder = "Scripts" if sys.platform == "win32" else "bin"
    suffix = ".exe" if sys.platform == "win32" else ""
    return DEV_DIR / "venv" / folder / f"{name}{suffix}"


def ensure_venv(*, quiet: bool = False) -> pathlib.Path:
    """Cria .dev/venv e instala tools/requirements.txt se preciso.

    Em venv proprio, e nao no Python do sistema, por dois motivos: ninguem
    precisa de permissao de administrador pra contribuir, e a versao do linter
    passa a ser a mesma em todas as maquinas e no CI - linter que muda de
    opiniao entre duas maquinas gera diff que ninguem pediu.
    """
    requirements = PROJECT / "tools" / "requirements.txt"
    stamp = DEV_DIR / "venv" / ".requirements-sha"
    # sha256 e nao hash(): o hash embutido do Python e randomizado por
    # processo, entao o carimbo nunca bateria e o venv reinstalaria sempre.
    current = hashlib.sha256(requirements.read_bytes()).hexdigest()
    python = venv_bin("python")

    if python.is_file() and stamp.is_file() and stamp.read_text(encoding="utf-8") == current:
        return python

    if not python.is_file():
        if not quiet:
            print(f"  criando venv em {DEV_DIR / 'venv'}")
        # --clear porque "nao tem python" nao quer dizer "nao tem venv". O
        # cache do CI guarda o .dev inteiro, e um venv criado com um Python que
        # o runner ja nao tem volta com o bin/python apontando para o nada:
        # `is_file()` diz que nao existe, e o `venv` por cima dele morre com
        # Errno 2 tentando usar esse mesmo link. Foi o que reprovou o Ubuntu
        # quando o setup-python passou para a 3.12.15.
        subprocess.run(
            [sys.executable, "-m", "venv", "--clear", str(DEV_DIR / "venv")], check=True
        )
    if not quiet:
        print("  instalando tools/requirements.txt")
    subprocess.run([str(python), "-m", "pip", "install", "--quiet", "--upgrade", "pip"],
                   check=True)
    subprocess.run([str(python), "-m", "pip", "install", "--quiet", "-r", str(requirements)],
                   check=True)
    stamp.write_text(current, encoding="utf-8")
    return python


def _gd_files() -> list[str]:
    """Todo .gd do repositorio. O addons/ fica de fora: e codigo de terceiro.

    Quem decide o que e do repositorio e o git, nao a arvore de pastas: uma
    worktree de outra sessao em .claude/worktrees/ e ignorada pelo git, mas o
    rglob entrava nela, o lint reprovava por arquivo alheio e o format
    reescrevia o trabalho de outra pessoa. O --others pega o .gd novo que
    ainda nao levou git add, que e justamente o que se quer lintar; o
    --exclude-standard deixa o ignorado de fora. O -z evita que o git ponha
    entre aspas caminho com acento.

    Sem git (fonte baixada em zip, git fora do PATH), cai no rglob pulando
    toda pasta oculta, que e onde moram .git, .godot, .dev e .claude.
    """
    try:
        out = subprocess.run(
            ["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard", "--",
             "*.gd"], cwd=PROJECT, capture_output=True, check=True)
        names = [pathlib.Path(n) for n in out.stdout.decode("utf-8").split("\0") if n]
    except (OSError, subprocess.SubprocessError):
        names = [p.relative_to(PROJECT) for p in PROJECT.rglob("*.gd")]
        names = [p for p in names if not any(part.startswith(".") for part in p.parts)]
    # O ls-files --cached ainda lista o arquivo apagado e nao commitado.
    return sorted(str(p) for p in names
                  if p.parts[0] != "addons" and (PROJECT / p).is_file())


def cmd_lint(_: argparse.Namespace) -> int:
    ensure_venv(quiet=True)
    files = _gd_files()
    print(f"$ gdlint ({len(files)} arquivos)")
    return subprocess.run([str(venv_bin("gdlint")), *files], cwd=PROJECT).returncode


def normalize_line_endings(files: list[str]) -> int:
    """Converte CRLF pra LF nos arquivos dados. Devolve quantos mudaram.

    O gdformat grava com o fim de linha do sistema: rodado no Windows, ele
    reescreve todo .gd em CRLF contra o .gitattributes deste repo, e o commit
    de formatacao sai com o dobro de ruido. Normalizar depois dele e mais
    simples que ensinar a ferramenta.
    """
    changed = 0
    for name in files:
        path = PROJECT / name
        raw = path.read_bytes()
        if b"\r\n" in raw:
            path.write_bytes(raw.replace(b"\r\n", b"\n"))
            changed += 1
    return changed


def cmd_format(args: argparse.Namespace) -> int:
    ensure_venv(quiet=True)
    files = _gd_files()
    flags = ["--check"] if args.check else []
    print(f"$ gdformat {' '.join(flags)} ({len(files)} arquivos)")
    code = subprocess.run([str(venv_bin("gdformat")), *flags, *files],
                          cwd=PROJECT).returncode
    if not args.check:
        fixed = normalize_line_endings(files)
        if fixed:
            print(f"  fim de linha normalizado pra LF em {fixed} arquivo(s)")
    return code


def cmd_doctor(_: argparse.Namespace) -> int:
    version = godot_version()
    print(f"versao fixada (.godot-version)   {version}")
    binary = find_godot(version, quiet=True)
    if binary is None:
        print("engine                           NAO ENCONTRADA")
        print("\nrode: python tools/dev.py setup")
        return 1
    try:
        found = subprocess.run([str(binary), "--version"], capture_output=True,
                               text=True, timeout=60).stdout.strip()
    except (OSError, subprocess.SubprocessError) as exc:
        print(f"engine                           {binary}")
        return _fail(f"nao executou: {exc}")
    templates = godot_data_dir() / "export_templates" / f"{version}.stable"
    user_dir = godot_user_data()
    print(f"engine                           {binary}")
    print(f"versao instalada                 {found}")
    print(f"export templates                 "
          f"{templates if templates.is_dir() else 'ausentes (so o export precisa)'}")
    print(f"tuning local (user://)           "
          f"{user_dir if user_dir.is_dir() else 'nenhum - rodando nos defaults do repo'}")
    if not found.startswith(version):
        return _fail("a engine instalada nao e a fixada - os numeros do banco "
                     "de provas deixam de ser comparaveis com os do CI.")
    return 0


# O que o Godot imprime quando algo deu errado e ele seguiu em frente: erro do
# motor, de script e o `push_error`. Aviso (WARNING) fica de fora - o import
# do CI e o driver de video sem GPU emitem os seus, e nenhum indica jogo errado.
_LINHA_DE_ERRO = re.compile(rb"^\s*(SCRIPT |USER )?ERROR:")


def _godot(binary: pathlib.Path, *extra: str, vigia_erros: bool = False) -> int:
    """Roda o Godot no projeto. Comando headless usa a variante de console.

    Com `vigia_erros`, uma rodada que imprimiu ERROR reprova mesmo que o
    processo saia com 0. O Godot nao para no erro: ele loga e continua. O
    selftest ja passou verde com 4316 "Basis must be normalized" na saida, um
    por pe por passo de fisica, e o primeiro a ver foi quem abriu o jogo a mao.
    Erro que nao reprova nada vira paisagem, e o proximo, o que importa, chega
    escondido no meio dele.
    """
    if "--headless" in extra:
        binary = _console_variant(binary)
    cmd = [str(binary), "--path", str(PROJECT), *extra]
    print(f"$ {' '.join(cmd)}", flush=True)
    if not vigia_erros:
        return subprocess.run(cmd).returncode

    # Bytes, e nao texto: a saida passa adiante intacta, sem depender de o
    # console do Windows saber codificar o que o Godot escreveu.
    erros: list[str] = []
    with subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT) as proc:
        assert proc.stdout is not None
        for linha in proc.stdout:
            sys.stdout.buffer.write(linha)
            sys.stdout.buffer.flush()
            if _LINHA_DE_ERRO.match(linha):
                erros.append(linha.decode("utf-8", "replace").strip())
    if proc.returncode != 0 or not erros:
        return proc.returncode
    # Distinto pelo texto sem os numeros: o mesmo erro a cada passo muda so a
    # matriz que ele imprime, e listar mil variacoes dele esconde o segundo.
    distintos = list({re.sub(r"-?\d[\d.]*", "#", e): e for e in erros}.values())
    print(f"\n! o Godot imprimiu {len(erros)} linha(s) de ERROR "
          f"({len(distintos)} distinta(s)). Rodou ate o fim, mas reprova:")
    for erro in distintos[:5]:
        print(f"  {erro[:200]}")
    return 1


def _import_antes(binary: pathlib.Path) -> int:
    """Reimporta o projeto. Roda antes de QUALQUER comando que abra o jogo.

    Um `class_name` novo so entra no cache de classes globais pelo scan do
    editor. Sem ele, o headless trava sem imprimir nada, e o jogo com tela
    abre num "Parse Error: Cannot infer the type" que aponta pro arquivo
    errado - o que usa a classe, nao o que a declara. Ninguem liga esse erro
    a um cache, e o caminho curto ate ele e trivial: trocar de branch, ou
    rodar qualquer coisa num worktree que nao conhece a classe.
    """
    return _godot(binary, "--headless", "--import")


def cmd_import(_: argparse.Namespace) -> int:
    return _import_antes(require_godot(godot_version()))


BASELINE = PROJECT / "tests" / "baseline.json"
METRICS_OUT = DEV_DIR / "metricas.json"


def _compare(medido: dict, dados: dict) -> tuple[int, list[str]]:
    """Compara medidas com um baseline. Devolve (quantas estouraram, relatorio).

    Serve aos dois baselines - o numerico e o visual - porque a regra e a
    mesma: valor esperado, tolerancia por metrica, e o delta impresso mesmo
    quando passa, pra quem le ver o numero andando antes de ele estourar.
    """
    padrao: float = dados.get("tolerancia_padrao_pct", 2.0)
    especiais: dict = dados.get("tolerancias_pct", {})
    esperado: dict = dados.get("valores", {})

    estouros = 0
    linhas: list[str] = []
    for chave in sorted(esperado):
        if chave not in medido:
            linhas.append(f"  ! {chave}: nao foi medido nesta rodada")
            estouros += 1
            continue
        antes = float(esperado[chave])
        agora = float(medido[chave])
        limite = float(especiais.get(chave, padrao))
        # Metrica que vale zero no baseline nao tem percentual: compara direto.
        delta_pct = (agora - antes) / antes * 100.0 if antes else (0.0 if agora == antes else 100.0)
        if abs(delta_pct) > limite:
            estouros += 1
            linhas.append(f"  ! {chave}: {antes:g} -> {agora:g} "
                          f"({delta_pct:+.1f}%, tolera {limite:g}%)")
        elif abs(delta_pct) > 0.05:
            linhas.append(f"    {chave}: {antes:g} -> {agora:g} ({delta_pct:+.1f}%)")

    if not linhas:
        linhas.append("  todas as medidas dentro do baseline, sem variacao")
    return estouros, linhas


def _sistema() -> str:
    """O nome do sistema como o `valores_por_sistema` do baseline usa."""
    if sys.platform == "win32":
        return "windows"
    if sys.platform == "darwin":
        return "macos"
    return "linux"


def compare_baseline(medido: dict) -> tuple[int, list[str]]:
    """O baseline numerico do banco de provas.

    Existe pra responder "o numero andou?" sem ninguem lembrar qual era o de
    ontem: a asercao do selftest so diz que o valor caiu dentro da faixa
    jogavel, que e larga de proposito. Andar de 2.75 s pra 3.40 s no 0-100
    passa nela e mesmo assim e outra moto.

    `valores_por_sistema` sobrepoe `valores` no sistema que roda. Cada sistema
    e deterministico sozinho, mas seno e cosseno saem da libm de cada um, e a
    ultima casa decimal diferente num contato longo da fisica separa a corrida
    solta inteira. Tolerancia mais larga esconderia regressao de verdade nos
    tres; numero por sistema mantem a comparacao exata em cada um.
    """
    if not BASELINE.is_file():
        return 0, ["  (sem tests/baseline.json - nada pra comparar)"]
    dados = json.loads(BASELINE.read_text(encoding="utf-8"))
    proprios: dict = dados.get("valores_por_sistema", {}).get(_sistema(), {})
    dados["valores"] = {**dados.get("valores", {}), **proprios}
    estouros, linhas = _compare(medido, dados)
    if proprios:
        linhas.insert(0, f"  ({len(proprios)} valor(es) proprio(s) de {_sistema()})")
    return estouros, linhas


def cmd_selftest(args: argparse.Namespace) -> int:
    binary = require_godot(godot_version())
    code = _import_antes(binary)
    if code != 0:
        return code

    # --fixed-fps: sem ele o headless simula em tempo real (22 s de jogo = 26 s
    # de relogio) e o banco inteiro leva ~110 s. Com ele cada quadro avanca
    # 1/60 s o mais rapido que a maquina der, e a fisica ve o mesmo delta de
    # sempre, entao as medidas nao mudam. So vale headless: com tela o quadro
    # real e justamente o que se mede.
    extra = ["--headless", "--fixed-fps", "60", "--", "--selftest"]
    if args.user_tuning:
        extra.append("--selftest-user")
    if args.fase:
        extra += ["--fase", args.fase]

    METRICS_OUT.parent.mkdir(parents=True, exist_ok=True)
    if METRICS_OUT.exists():
        METRICS_OUT.unlink()
    os.environ["RUSHFOOD_SELFTEST_METRICS"] = str(METRICS_OUT)

    code = _godot(binary, *extra, vigia_erros=True)
    if code != 0 or not METRICS_OUT.is_file():
        return code

    # Rodada parcial mede um subconjunto: comparar so faz sentido no conjunto
    # inteiro, senao toda fase pulada vira "nao foi medido".
    if args.fase:
        return code

    medido = json.loads(METRICS_OUT.read_text(encoding="utf-8"))
    estouros, linhas = compare_baseline(medido)
    print("\n--- baseline ---")
    for linha in linhas:
        print(linha)
    if estouros:
        print(f"\n! {estouros} medida(s) fora do baseline.\n"
              f"  Se a mudanca era esperada, atualize {BASELINE.relative_to(PROJECT)} "
              f"no mesmo commit, dizendo no texto por que o numero andou.\n"
              f"  As medidas desta rodada estao em {METRICS_OUT.relative_to(PROJECT)}.")
        # No CI o arquivo morre com a maquina, e e de la que sai o numero de
        # um sistema que voce nao tem: vai inteiro pro log.
        if os.environ.get("CI"):
            print(f"\n--- medidas desta rodada ({_sistema()}) ---")
            print(json.dumps(medido, indent="\t", sort_keys=True))
        return 1
    print()
    return 0


def cmd_test(args: argparse.Namespace) -> int:
    """Testes unitarios do GdUnit4: logica pura, em segundos.

    O banco de provas roda a moto de verdade e leva 89 s; isto roda em 4 s e
    pega a classe de erro que ele nao pega - regra de pontuacao, geometria de
    faixa, prazo. Os dois existem, e nenhum substitui o outro.
    """
    binary = require_godot(godot_version())
    code = _import_antes(binary)
    if code != 0:
        return code
    # --ignoreHeadlessMode: o GdUnit4 recusa headless porque InputEvent nao
    # trafega ali. Nenhum teste daqui usa input - eles testam funcao pura -
    # e sem headless nao ha como rodar no CI.
    return _godot(binary, "--headless", "-s", "addons/gdUnit4/bin/GdUnitCmdTool.gd",
                  "--ignoreHeadlessMode", "-a", args.caminho, vigia_erros=True)


BASELINE_VISUAL = PROJECT / "tests" / "baseline_visual.json"
# A noite tem baseline proprio: luminancia e fracao de ceu de noite nao tem
# nada a ver com as do meio-dia, e um baseline so para as duas teria de
# tolerar tanto que nao pegaria nem a pista sumindo.
BASELINE_VISUAL_NOITE = PROJECT / "tests" / "baseline_visual_noite.json"


def _pede_hora(hora) -> None:
    """A corrida anoitece, mas medida nao: o jogo trava a hora no meio-dia
    quando mede. `--hora` pede outra, de 0 (meio-dia) a 1 (noite fechada), e
    chega ao jogo pelo RUSHFOOD_HORA (`main.gd`)."""
    if hora is None:
        os.environ.pop("RUSHFOOD_HORA", None)
        return
    if not 0.0 <= hora <= 1.0:
        raise SystemExit(f"--hora vai de 0 (meio-dia) a 1 (noite), e veio {hora}")
    os.environ["RUSHFOOD_HORA"] = f"{hora:g}"


def _pede_resolucao(resolucao) -> None:
    """Medida fica em 640x360, que e o mundo de todas as referencias. `--resolucao
    540` pede os 960x540 da tela grande (V30); chega ao jogo pelo
    RUSHFOOD_RESOLUCAO (`main.gd`)."""
    if resolucao is None:
        os.environ.pop("RUSHFOOD_RESOLUCAO", None)
        return
    os.environ["RUSHFOOD_RESOLUCAO"] = str(resolucao)


def cmd_shots(args: argparse.Namespace) -> int:
    """Regressao visual: roda o jogo COM tela e mede o que aparece nela.

    Nao roda headless de proposito - e nao e escolha, e limitacao: sob o driver
    dummy o viewport nao renderiza e saem zero PNGs, sem erro nenhum. Por isso
    isto e um comando a parte, e no CI um job a parte com xvfb.

    O que ele pega: a tela ficar errada por inteiro. O caso registrado no
    PROTOTIPO.md e a pista sumindo por backface culling - o Godot descartava as
    faces sem um erro no console e o mundo virava caixas flutuando. Nenhuma das
    dez medidas do banco de provas se mexia, porque todas medem fisica, e a
    fisica nao sabe que a pista sumiu.
    """
    binary = require_godot(godot_version())
    code = _import_antes(binary)
    if code != 0:
        return code

    _pede_hora(1.0 if args.noite else None)
    baseline = BASELINE_VISUAL_NOITE if args.noite else BASELINE_VISUAL
    padrao = DEV_DIR / ("shots_noite" if args.noite else "shots")
    out = pathlib.Path(args.out).resolve() if args.out else padrao
    out.mkdir(parents=True, exist_ok=True)
    for antigo in out.glob("*.png"):
        antigo.unlink()

    METRICS_OUT.parent.mkdir(parents=True, exist_ok=True)
    if METRICS_OUT.exists():
        METRICS_OUT.unlink()
    os.environ["RUSHFOOD_SELFTEST_SHOTS"] = str(out)
    os.environ["RUSHFOOD_SELFTEST_METRICS"] = str(METRICS_OUT)

    # Sem --headless: e o ponto todo do comando. Mas com audio dummy: o jogo
    # nao tem som, e o runner Linux do CI nao tem placa - o ALSA falha com um
    # ERROR que nao diz nada sobre o jogo e reprovaria toda rodada ali.
    code = _godot(binary, "--audio-driver", "Dummy", "--", "--selftest", vigia_erros=True)
    pngs = sorted(out.glob("*.png"))
    print(f"\n{len(pngs)} frame(s) em {out}")
    if code != 0:
        return code
    if not pngs:
        return _fail("nenhum frame foi capturado - ha display nesta sessao?")
    if not METRICS_OUT.is_file():
        return _fail("o jogo nao gravou as medidas")

    medido = json.loads(METRICS_OUT.read_text(encoding="utf-8"))
    visual = {k: v for k, v in medido.items() if k.startswith("visual_")}
    if args.update or not baseline.is_file():
        _write_visual_baseline(visual, baseline)
        return 0

    dados = json.loads(baseline.read_text(encoding="utf-8"))
    estouros, linhas = _compare(visual, dados)
    print("\n--- baseline visual ---")
    for linha in linhas:
        print(linha)
    if estouros:
        print(f"\n! {estouros} medida(s) de frame fora do baseline.\n"
              f"  Olhe os PNGs em {out} antes de decidir: se a tela mudou de "
              f"proposito, regrave com `--update`.")
        return 1
    print()
    return 0


def _write_visual_baseline(visual: dict, baseline: pathlib.Path) -> None:
    dados = {
        "_leia": ("O que a tela tem dentro, em proporcoes grosseiras. Nao e "
                  "comparacao pixel a pixel: driver e GPU mudam o ultimo bit de "
                  "quase todo pixel, e o teste falharia por motivo nenhum. Isto "
                  "pega a tela ficar ERRADA POR INTEIRO - a pista sumir, o mundo "
                  "apagar - que e o que nenhuma medida de fisica pega."),
        "_como_atualizar": ("python tools/dev.py shots%s --update, depois de olhar os PNGs."
                            % (" --noite" if baseline == BASELINE_VISUAL_NOITE else "")),
        # Tolerancia larga: a corrida e deterministica, mas o instante exato do
        # frame capturado depende de quando o render fecha, e a camera esta em
        # movimento. Estreitar isso troca regressao por alarme falso.
        #
        # Foi de 12% pra 20% quando o jogo virou corrida. A simulacao continua
        # deterministica - o que flutua e QUAL frame renderizado e capturado no
        # instante pedido, e com a camera tremendo numa queda dois frames de
        # atraso sao duas imagens bem diferentes. Medido com o MESMO codigo:
        # tres rodadas de CI deram +10.6%, +13.5% e +11.2%, e a propria maquina
        # que gravou o baseline deu +9.6% na rodada seguinte.
        #
        # Ou seja, 12% caia DENTRO do ruido e o portao virou cara ou coroa -
        # chegou a reprovar um commit que so mexeu em markdown. O que este teste
        # existe pra pegar mexe 46% e 48% (a pista sumindo por backface
        # culling), entao 20% continua com o dobro de margem sobre o pior caso
        # medido.
        "tolerancia_padrao_pct": 20.0,
        "tolerancias_pct": {"visual_frames": 0.0},
        "valores": {k: round(float(v), 6) for k, v in sorted(visual.items())},
    }
    write_text_lf(baseline,
                  json.dumps(dados, indent="\t", ensure_ascii=False) + "\n")
    print(f"+ baseline visual gravado em {baseline.relative_to(PROJECT)}:")
    for chave, valor in dados["valores"].items():
        print(f"    {chave}: {valor:g}")


PROVA_DIR = DEV_DIR / "prova"


def cmd_prova(args: argparse.Namespace) -> int:
    """O quadro congelado da prova visual: os mesmos cinco quadros, sempre.

    Mesma semente, mesmo trecho de pista, camera encaixada e mundo congelado
    antes do primeiro passo de fisica. Rodar duas vezes da o mesmo PNG - e o
    que faz "melhorou?" ter resposta, em vez de cada um comparar o print que
    calhou de tirar. Precisa de tela, pelo mesmo motivo do `shots`.
    """
    binary = require_godot(godot_version())
    code = _import_antes(binary)
    if code != 0:
        return code
    # Outra hora vai para outra pasta, para a do meio-dia continuar sendo a
    # de comparar antes e depois.
    _pede_hora(args.hora)
    _pede_resolucao(args.resolucao)
    pasta = PROVA_DIR if args.hora is None else PROVA_DIR / f"hora_{args.hora:g}"
    if args.resolucao is not None:
        pasta = pasta / f"res_{args.resolucao}"
    pasta.mkdir(parents=True, exist_ok=True)
    for antigo in pasta.glob("*.png"):
        antigo.unlink()
    os.environ["RUSHFOOD_PROVA_DIR"] = str(pasta)
    # O padrao e a perseguicao, e e contra ela que se compara visual. A garupa
    # e para mexer na propria garupa: sem quadro congelado, cada ajuste dela
    # vira "parece melhor" contra a lembranca de ontem.
    if args.garupa:
        os.environ["RUSHFOOD_PROVA_CAMERA"] = "garupa"
    if args.variantes:
        os.environ["RUSHFOOD_PROVA_VARIANTES"] = "1"
    if args.referencia or args.variantes:
        # Clone sem `git lfs pull` tem ponteiro de texto no lugar do PNG, e o
        # Godot so diria que nao leu a imagem - a folha sairia sem referencia
        # nenhuma, parecendo que funcionou.
        amostra = PROJECT / "docs" / "referencias" / "video_01" / "t0.0s.png"
        if not amostra.exists() or amostra.read_bytes()[:4] != b"\x89PNG":
            return _fail(f"{amostra.relative_to(PROJECT)} nao e PNG - rode `git lfs pull`")
        os.environ["RUSHFOOD_PROVA_REFERENCIA"] = "1"
    if args.kmh is not None:
        # Os quadros andando saem a 90 km/h; o borrao (V08) se julga a 180.
        os.environ["RUSHFOOD_PROVA_VELOCIDADE"] = str(args.kmh / 3.6)
    code = _godot(binary, "--", "--prova")
    pngs = sorted(pasta.glob("*.png"))
    if code != 0:
        return code
    if not pngs:
        return _fail("nenhum quadro foi salvo - ha display nesta sessao?")
    print(f"\n{len(pngs)} imagem(ns) em {pasta}")
    return 0


def cmd_fps(args: argparse.Namespace) -> int:
    """Tempo de quadro da corrida solta, com tela e sem vsync.

    Imprime mediana, p95 e o pior quadro. Nao compara com baseline: o numero
    depende da GPU de quem roda. Serve para comparar a mesma maquina antes e
    depois de uma mudanca de visual.
    """
    binary = require_godot(godot_version())
    code = _import_antes(binary)
    if code != 0:
        return code
    METRICS_OUT.parent.mkdir(parents=True, exist_ok=True)
    if METRICS_OUT.exists():
        METRICS_OUT.unlink()
    os.environ["RUSHFOOD_SELFTEST_METRICS"] = str(METRICS_OUT)
    # A noite tem uma luz por poste e por farol: e a hora de medir com `--hora 1`.
    _pede_hora(args.hora)
    _pede_resolucao(args.resolucao)
    # Sem --headless: sem tela nao ha quadro para medir.
    extra = ["--queda"] if args.queda else []
    return _godot(binary, "--", "--selftest", "--fps", *extra)


def cmd_run(_: argparse.Namespace) -> int:
    binary = require_godot(godot_version())
    code = _import_antes(binary)
    if code != 0:
        return code
    return _godot(binary)


def project_version() -> str:
    """A versao do JOGO (config/version), nao a da engine.

    E ela que nomeia a tag e a release. Fonte unica: project.godot.
    """
    for line in (PROJECT / "project.godot").read_text(encoding="utf-8").splitlines():
        if line.startswith("config/version="):
            return line.split("=", 1)[1].strip().strip('"')
    raise SystemExit("config/version nao encontrado em project.godot")


def sync_preset_version() -> bool:
    """Espelha config/version no export_presets.cfg. Devolve True se mudou.

    O bundle do macOS carrega a versao dentro dele, e o preset e o unico lugar
    onde ela cabe. Fazer isso aqui - e nao so no CI - fecha a unica fonte de
    divergencia possivel: bumpar o project.godot e esquecer o preset, ou o
    export local sair com versao diferente do export da pipeline.
    """
    version = project_version()
    path = PROJECT / "export_presets.cfg"
    original = path.read_text(encoding="utf-8")
    updated = re.sub(r'^(application/(?:short_)?version=)".*"$',
                     rf'\1"{version}"', original, flags=re.MULTILINE)
    if updated == original:
        return False
    write_text_lf(path, updated)
    print(f"  export_presets.cfg atualizado pra versao {version}")
    return True


def cmd_versao(args: argparse.Namespace) -> int:
    """Mostra ou sobe a versao do jogo. Subir a versao e o que publica.

    O PR que muda o `config/version` vira release quando entra na master: o
    release.yml cria a tag e publica. Por isso o bump e um comando, e nao uma
    edicao a mao - ele valida o formato e espelha no preset do macOS, e quem
    revisa o PR ve exatamente duas linhas mudando.
    """
    atual = project_version()
    if args.nova is None:
        print(atual)
        return 0
    nova = args.nova
    if nova == "patch":
        maior, menor, patch = (int(p) for p in atual.split("."))
        nova = f"{maior}.{menor}.{patch + 1}"
    if not re.fullmatch(r"\d+\.\d+\.\d+", nova):
        return _fail(f"versao {nova!r} nao e X.Y.Z")
    if tuple(int(p) for p in nova.split(".")) <= tuple(int(p) for p in atual.split(".")):
        return _fail(f"{nova} nao e maior que a atual ({atual}): a tag ja existiria")
    path = PROJECT / "project.godot"
    texto = path.read_text(encoding="utf-8")
    write_text_lf(path, re.sub(r'^config/version=".*"$', f'config/version="{nova}"',
                               texto, flags=re.MULTILINE))
    sync_preset_version()
    print(f"{atual} -> {nova}. Commit, PR para a master, e o merge publica a v{nova}.")
    return 0


# O que cada tipo de commit vira no corpo da release. Quem baixa o zip quer
# saber o que mudou na corrida, nao que o CI ganhou um cache: novidade,
# correcao e desempenho ficam a vista, o resto vai para um bloco recolhido.
# Classifica pelo tipo do conventional, e nao pelo emoji, porque o mesmo
# emoji chega com e sem o seletor de variacao (U+FE0F) conforme o teclado.
SECOES_CHANGELOG = (
    ("Novidades", ("feat",)),
    ("Correções", ("fix",)),
    ("Desempenho", ("perf",)),
)
ASSUNTO_CONVENCIONAL = re.compile(r"^(?:\S+\s+)?(\w+)(?:\([^)]*\))?!?:\s*(.+)$")


def _git(*args: str) -> str:
    return subprocess.run(["git", *args], cwd=PROJECT, check=True,
                          capture_output=True, text=True, encoding="utf-8").stdout


def tag_anterior(tag: str) -> str | None:
    """A ultima tag de versao alcancavel do HEAD, sem contar a propria `tag`.

    Na pipeline o HEAD e o commit do merge: no push para a master a tag nova
    ainda nao existe, e no push de tag ela aponta para o proprio HEAD. Os dois
    casos caem aqui sem `if`, porque a tag nova e descartada pelo nome.
    """
    def chave(nome: str) -> tuple[int, ...]:
        return tuple(int(p) for p in nome[1:].split("."))

    tags = [t for t in _git("tag", "--merged", "HEAD", "--list", "v*").split()
            if re.fullmatch(r"v\d+\.\d+\.\d+", t) and t != tag]
    return max(tags, key=chave) if tags else None


def changelog(tag: str) -> str:
    """O markdown do que mudou desde a release anterior, agrupado por tipo.

    `--first-parent` porque a master so recebe squash: cada commit dela e um
    PR, e o assunto ja traz o `(#N)` que o GitHub transforma em link. Sem
    isso, os merges de antes do squash despejariam os commits internos de
    cada branch na lista.
    """
    anterior = tag_anterior(tag)
    faixa = f"{anterior}..HEAD" if anterior else "HEAD"
    secoes: dict[str, list[str]] = {nome: [] for nome, _ in SECOES_CHANGELOG}
    por_dentro: list[str] = []
    for assunto in _git("log", "--first-parent", "--format=%s", faixa).splitlines():
        casou = ASSUNTO_CONVENCIONAL.match(assunto)
        tipo, texto = (casou.group(1), casou.group(2)) if casou else ("", assunto)
        # O commit do bump e a propria release: lista-lo seria dizer
        # "esta versao trouxe esta versao".
        if tipo == "chore" and re.match(r"(sobe a )?vers[aã]o", texto, re.IGNORECASE):
            continue
        linha = f"- {texto[:1].upper()}{texto[1:]}"
        destino = next((nome for nome, tipos in SECOES_CHANGELOG if tipo in tipos), None)
        (secoes[destino] if destino else por_dentro).append(linha)

    partes: list[str] = []
    for nome, linhas in secoes.items():
        if linhas:
            partes.append(f"### {nome}\n\n" + "\n".join(linhas))
    if por_dentro:
        partes.append("<details>\n<summary>Por dentro do projeto</summary>\n\n"
                      + "\n".join(por_dentro) + "\n\n</details>")
    if not partes:
        partes.append("Nenhuma mudança desde a release anterior.")
    repo = os.environ.get("GITHUB_REPOSITORY")
    if anterior and repo:
        servidor = os.environ.get("GITHUB_SERVER_URL", "https://github.com")
        partes.append(f"Diff completo: [{anterior}...{tag}]({servidor}/{repo}/compare/"
                      f"{anterior}...{tag})")
    return "\n\n".join(partes) + "\n"


def cmd_changelog(args: argparse.Namespace) -> int:
    tag = args.tag or f"v{project_version()}"
    sys.stdout.write(changelog(tag))
    return 0


def cmd_sprites(_: argparse.Namespace) -> int:
    """Recorta as folhas do Google Flow (`arte/flow/`) no atlas do ator.

    Roda no Godot fixado, e nao em Python: o Python do sistema nao le JPEG sem
    Pillow, e o Godot ja esta em toda maquina que roda o jogo.
    """
    binary = require_godot(godot_version())
    folha = PROJECT / "arte" / "flow" / "pilotando_a.jpg"
    if not folha.exists() or folha.read_bytes()[:2] != b"\xff\xd8":
        return _fail(f"{folha.relative_to(PROJECT)} nao e JPEG - rode `git lfs pull`")
    code = _godot(binary, "--headless", "--script", "res://arte/sprites_flow.gd",
                  vigia_erros=True)
    if code != 0:
        return code
    return _import_antes(binary)


def cmd_sprites_pedestres(_: argparse.Namespace) -> int:
    """Recorta as folhas de pedestre do Google Flow (`arte/flow/pedestres/`).

    Gera `assets/sprites/pedestres/<pessoa>.png` e `.json`, e as folhas de
    conferencia em `.dev/sprites_pedestres/`. Mesmo motivo do `sprites`: roda no
    Godot, porque o Python do sistema nao le JPEG sem Pillow.
    """
    binary = require_godot(godot_version())
    folha = PROJECT / "arte" / "flow" / "pedestres" / "vovo_andando.jpg"
    if not folha.exists() or folha.read_bytes()[:2] != b"\xff\xd8":
        return _fail(f"{folha.relative_to(PROJECT)} nao e JPEG - rode `git lfs pull`")
    code = _import_antes(binary)
    if code != 0:
        return code
    code = _godot(binary, "--headless", "--script", "res://arte/sprites_pedestres.gd",
                  vigia_erros=True)
    if code != 0:
        return code
    return _import_antes(binary)


def cmd_sprites_props(_: argparse.Namespace) -> int:
    """Recorta os props do Google Flow (`arte/flow/props/`): arvore, poste e placa.

    Gera `assets/sprites/props/<prop>.png` e `.json`. Roda no Godot, pelo mesmo
    motivo do `sprites-pedestres`.
    """
    binary = require_godot(godot_version())
    code = _import_antes(binary)
    if code != 0:
        return code
    code = _godot(binary, "--headless", "--script", "res://arte/sprites_props.gd",
                  vigia_erros=True)
    if code != 0:
        return code
    return _import_antes(binary)


def cmd_recortar(args: argparse.Namespace) -> int:
    """Recorta as folhas do Flow pela ficha delas (`arte/flow/fichas/<nome>.json`).

    Sem nome recorta todas. Folha nova entra com uma ficha, e nao com um script;
    ver `arte/recortar.gd`. Roda no Godot, pelo mesmo motivo do `sprites-pedestres`.
    """
    binary = require_godot(godot_version())
    code = _import_antes(binary)
    if code != 0:
        return code
    code = _godot(binary, "--headless", "--script", "res://arte/recortar.gd",
                  *(["--", *args.fichas] if args.fichas else []), vigia_erros=True)
    if code != 0:
        return code
    return _import_antes(binary)


def cmd_personagem(args: argparse.Namespace) -> int:
    """O fluxo por video usa um ambiente isolado, sem depender do Python da maquina."""
    ambiente = DEV_DIR / "venv-flow"
    python = ambiente / ("Scripts/python.exe" if sys.platform == "win32" else "bin/python3")
    if args.argumentos == ["setup"]:
        code = subprocess.call([sys.executable, "-m", "venv", str(ambiente)])
        if code != 0:
            return code
        return subprocess.call([str(python), "-m", "pip", "install", "Pillow==12.3.0", "numpy==2.3.5"])
    if args.argumentos == ["testar"]:
        if not python.exists():
            return _fail("rode primeiro: python3 tools/dev.py personagem setup")
        return subprocess.call([str(python), "-m", "unittest", "discover", "-s", str(PROJECT / "tools"),
                                "-p", "test_personagem.py", "-v"])
    return subprocess.call([str(python) if python.exists() else sys.executable,
                            str(PROJECT / "arte/flow/personagem.py"), *args.argumentos])


def cmd_sprites_ver(args: argparse.Namespace) -> int:
    """Abre o testador de sprites: todas as folhas do projeto, em 2D e em cena.

    Com tela, como o `run`. `--sprite` abre numa folha, `--cena` no modo 3D e
    `--captura` salva a tela num PNG e sai, para conferir sem olhar.
    """
    binary = require_godot(godot_version())
    code = _import_antes(binary)
    if code != 0:
        return code
    extra: list[str] = []
    if args.sprite:
        extra.append(f"--sprite={args.sprite}")
    if args.cena:
        extra.append("--cena")
    if args.gira:
        extra.append("--gira")
    if args.jogar:
        extra.append("--jogar")
    if args.vista:
        extra.append(f"--vista={args.vista}")
    if args.quadro:
        extra.append(f"--quadro={args.quadro}")
    if args.linha:
        extra.append(f"--linha={args.linha}")
    if args.captura:
        extra.append(f"--captura={pathlib.Path(args.captura).resolve()}")
    return _godot(binary, "res://scenes/sprites.tscn", "--", *extra)


def cmd_projetor(args: argparse.Namespace) -> int:
    """Abre a prova do projetor 2D (2D05): a pista de verdade em pseudo-3D.

    Com tela, como o `run`. Setas ou WASD pilotam. `--auto` pilota sozinho e
    `--captura` salva a tela num PNG e sai, para conferir sem olhar.
    """
    binary = require_godot(godot_version())
    code = _import_antes(binary)
    if code != 0:
        return code
    extra: list[str] = []
    if args.auto:
        extra.append("--auto")
    if args.vel is not None:
        extra.append(f"--vel={args.vel}")
    if args.captura:
        extra.append(f"--captura={pathlib.Path(args.captura).resolve()}")
        extra.append(f"--espera={args.espera}")
    return _godot(binary, "res://scenes/projetor.tscn", "--", *extra)


def cmd_sprites_relatorio(_: argparse.Namespace) -> int:
    """O relatorio dos sprites, sem janela: `.dev/sprites_relatorio/relatorio.md`.

    Analisa cada folha (movimento, borda, comparacao com a referencia 3D) e
    grava, para as que tem quadro marcado, a folha marcada e a comparacao em
    imagem. Reprova (codigo 1) so por defeito de borda; pose e movimento
    informam.
    """
    binary = require_godot(godot_version())
    code = _import_antes(binary)
    if code != 0:
        return code
    return _godot(binary, "--headless", "--script", "res://scripts/relatorio_sprites.gd",
                  vigia_erros=True)


# Alvo do `boneco` -> script que gera as folhas. Todos passam pela bancada de
# `arte/boneco_cena.gd` e saem em `arte/flow/referencia/`.
BONECOS = {
    "pessoa": "boneco_flow.gd",
    "moto": "boneco_moto.gd",
    "carro": "boneco_carro.gd",
    "prop": "boneco_prop.gd",
    "fachada": "boneco_fachada.gd",
}


def cmd_boneco(args: argparse.Namespace) -> int:
    """Gera as folhas de pose de referencia (`arte/flow/referencia/`) para o Flow.

    Cada alvo posa o modelo do proprio jogo em manequim cinza sobre verde:
    `pessoa` (o padrao), `moto`, `carro`, `prop` e `fachada`, ou `tudo`.
    Precisa de tela: o renderizador do `--headless` e um dummy e sai tudo preto.
    """
    binary = require_godot(godot_version())
    code = _import_antes(binary)
    if code != 0:
        return code
    alvos = list(BONECOS) if args.alvo == "tudo" else [args.alvo]
    for alvo in alvos:
        code = _godot(binary, "--script", f"res://arte/{BONECOS[alvo]}", vigia_erros=True)
        if code != 0:
            return code
    return 0


# Preset -> arquivo que ele tem de gerar. O jogo e o testador de sprites ("o
# editor") saem do mesmo projeto: o do editor liga a feature `sprites`, que
# troca a cena inicial e o nome (ver `run/main_scene.sprites` no project.godot).
EXPORTS_JOGO = (("Windows Desktop", "export/windows/RushFood.exe"),
                ("Linux", "export/linux/RushFood.x86_64"),
                ("macOS", "export/macos/RushFood.zip"))
EXPORTS_EDITOR = (("Sprites - Windows", "export/sprites/windows/RushFoodSprites.exe"),
                  ("Sprites - Linux", "export/sprites/linux/RushFoodSprites.x86_64"),
                  ("Sprites - macOS", "export/sprites/macos/RushFoodSprites.zip"))


def cmd_export(args: argparse.Namespace) -> int:
    version = godot_version()
    binary = require_godot(version)
    if not (godot_data_dir() / "export_templates" / f"{version}.stable").is_dir():
        return _fail("export templates ausentes - rode `python tools/dev.py setup`")
    sync_preset_version()
    alvos = {"jogo": EXPORTS_JOGO, "editor": EXPORTS_EDITOR,
             "tudo": EXPORTS_JOGO + EXPORTS_EDITOR}[args.so]
    for preset, out in alvos:
        artifact = PROJECT / out
        artifact.parent.mkdir(parents=True, exist_ok=True)
        _godot(binary, "--headless", "--export-release", preset)
        # O export do Godot nem sempre devolve codigo de erro numa falha;
        # arquivo ausente ou vazio aqui e a checagem de verdade.
        if not artifact.is_file() or artifact.stat().st_size == 0:
            return _fail(f"{preset}: {out} nao saiu")
        print(f"+ {out}  ({artifact.stat().st_size // 1024} KiB)")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="comando", required=True)

    sub.add_parser("doctor", help="diz onde esta o Godot e se bate com a versao fixada")
    p_setup = sub.add_parser("setup", help="baixa a engine e os templates fixados")
    p_setup.add_argument("--skip-templates", action="store_true",
                         help="so a engine (~100 MB em vez de ~1 GB)")
    sub.add_parser("import", help="importa os assets (obrigatorio apos criar class_name)")
    p_self = sub.add_parser("selftest", help="o portao: banco de provas headless")
    p_self.add_argument("--user-tuning", action="store_true",
                        help="mede os seus ajustes salvos em vez dos defaults do repo")
    p_self.add_argument("--fase", metavar="NOME",
                        help="roda so ate esta fase: aceleracao, freada, inclinacao, "
                             "curva, soco, bifurcacao, corrida")
    p_shots = sub.add_parser("shots", help="regressao visual: roda COM tela e mede o frame")
    p_shots.add_argument("--out", metavar="PASTA", help="onde gravar os PNGs")
    p_shots.add_argument("--noite", action="store_true",
                         help="a corrida de noite, contra o baseline_visual_noite.json")
    p_shots.add_argument("--update", action="store_true",
                         help="regrava o baseline visual (olhe os PNGs antes)")
    p_prova = sub.add_parser("prova",
                             help="prova visual: os mesmos quadros congelados, para comparar")
    p_prova.add_argument("--garupa", action="store_true",
                         help="os mesmos quadros pela camera GARUPA, e nao pela perseguicao")
    p_prova.add_argument("--referencia", action="store_true",
                         help="gera tambem comparacao.png: cada quadro ao lado da referencia")
    p_prova.add_argument("--variantes", action="store_true",
                         help="gera variantes.png: cada quadro com as variantes de trama "
                              "do passe de paleta e a referencia (V03a)")
    p_prova.add_argument("--hora", type=float, default=None,
                         help="hora travada, de 0 (meio-dia) a 1 (noite); vai para .dev/prova/hora_X")
    p_prova.add_argument("--resolucao", type=int, choices=(360, 540), default=None,
                         help="resolucao interna; vai para .dev/prova/res_N (padrao 360)")
    p_prova.add_argument("--kmh", type=float, default=None,
                         help="velocidade dos quadros andando (padrao 90 km/h)")
    p_fps = sub.add_parser("fps", help="tempo de quadro da corrida solta, com tela e sem vsync")
    p_fps.add_argument("--hora", type=float, default=None,
                       help="hora travada, de 0 (meio-dia) a 1 (noite)")
    p_fps.add_argument("--resolucao", type=int, choices=(360, 540), default=None,
                       help="resolucao interna (padrao 360)")
    p_fps.add_argument("--queda", action="store_true",
                       help="derruba jogador e rivais a cada 4 s: o pior caso das particulas")
    sub.add_parser("run", help="abre o jogo")
    p_exp = sub.add_parser("export", help="exporta as tres plataformas, do jogo e do editor de sprites")
    p_exp.add_argument("--so", choices=("tudo", "jogo", "editor"), default="tudo",
                       help="so o jogo, so o editor de sprites, ou os dois (padrao)")
    p_boneco = sub.add_parser("boneco", help="gera as folhas de pose de referencia para o Flow")
    p_boneco.add_argument("alvo", nargs="?", default="pessoa", choices=(*BONECOS, "tudo"),
                          help="o que posar (padrao: pessoa)")
    sub.add_parser("sprites-pedestres", help="recorta as folhas de pedestre do Flow em atlas por pessoa")
    p_recortar = sub.add_parser("recortar", help="recorta as folhas do Flow pela ficha (arte/flow/fichas/)")
    p_recortar.add_argument("fichas", nargs="*", metavar="ficha", help="nome da ficha (padrao: todas)")
    sub.add_parser("sprites-props", help="recorta os props do Flow (arvore, poste, placa) em sprites com ancora")
    sub.add_parser("sprites", help="recorta as folhas do Google Flow no atlas do ator")
    p_personagem = sub.add_parser("personagem", help="prepara, inspeciona e monta NPCs por video; ver docs/PERSONAGENS.md")
    p_personagem.add_argument("argumentos", nargs=argparse.REMAINDER)
    p_projetor = sub.add_parser("projetor", help="abre a prova do projetor 2D: a pista em pseudo-3D, jogavel")
    p_projetor.add_argument("--auto", action="store_true", help="pilota sozinho")
    p_projetor.add_argument("--vel", type=float, help="teto de velocidade em m/s (padrao: 58)")
    p_projetor.add_argument("--captura", help="salva a tela neste PNG e sai")
    p_projetor.add_argument("--espera", type=float, default=3.0, help="segundos antes da captura (padrao: 3)")
    sub.add_parser("sprites-relatorio", help="relatorio dos sprites em texto e imagem, sem janela")
    p_ver = sub.add_parser("sprites-ver", help="abre o testador: todas as folhas, em 2D e em cena")
    p_ver.add_argument("--sprite", help="id da folha para abrir (ex.: vovo_andando, moto)")
    p_ver.add_argument("--cena", action="store_true", help="abre no modo 3D")
    p_ver.add_argument("--gira", action="store_true", help="com a camera da cena girando sozinha")
    p_ver.add_argument("--jogar", action="store_true", help="abre no playground")
    p_ver.add_argument("--vista", choices=["quadro", "folha", "referencia", "base", "duas"],
                       help="vista da folha 2D")
    p_ver.add_argument("--quadro", type=int, help="quadro para abrir (de 1)")
    p_ver.add_argument("--linha", type=int, help="linha para abrir (de 1)")
    p_ver.add_argument("--captura", help="salva a tela neste PNG e sai")
    p_versao = sub.add_parser("versao", help="mostra ou sobe a versao; o merge da versao nova publica")
    p_versao.add_argument("nova", nargs="?", metavar="X.Y.Z|patch",
                          help="a versao nova, ou `patch` para subir o ultimo numero")
    p_changelog = sub.add_parser("changelog",
                                 help="o que mudou desde a release anterior, em markdown")
    p_changelog.add_argument("tag", nargs="?", metavar="vX.Y.Z",
                             help="a tag da release (padrao: a do config/version)")
    p_test = sub.add_parser("test", help="testes unitarios (GdUnit4), rapidos")
    p_test.add_argument("caminho", nargs="?", default="tests/unit",
                        help="pasta ou arquivo de teste (padrao: tests/unit)")
    sub.add_parser("lint", help="gdlint em todo .gd do projeto")
    p_fmt = sub.add_parser("format", help="gdformat em todo .gd do projeto")
    p_fmt.add_argument("--check", action="store_true",
                       help="so confere, nao reescreve (e o que o CI roda)")

    args = parser.parse_args()
    handler = {
        "doctor": cmd_doctor, "setup": cmd_setup, "import": cmd_import,
        "selftest": cmd_selftest, "run": cmd_run, "export": cmd_export,
        "lint": cmd_lint, "format": cmd_format, "test": cmd_test,
        "shots": cmd_shots,
        "prova": cmd_prova,
        "boneco": cmd_boneco,
        "sprites-pedestres": cmd_sprites_pedestres,
        "recortar": cmd_recortar,
        "sprites-props": cmd_sprites_props,
        "sprites": cmd_sprites,
        "personagem": cmd_personagem,
        "sprites-ver": cmd_sprites_ver,
        "projetor": cmd_projetor,
        "sprites-relatorio": cmd_sprites_relatorio,
        "versao": cmd_versao,
        "changelog": cmd_changelog,
        "fps": cmd_fps,
    }[args.comando]
    return handler(args)


if __name__ == "__main__":
    sys.exit(main())
