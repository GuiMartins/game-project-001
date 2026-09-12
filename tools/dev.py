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

A versao vem de `.godot-version`, que e a fonte unica: o CI le o mesmo arquivo.
Bumpar a engine e editar uma linha, nao cacar constantes em tres workflows.
"""
from __future__ import annotations

import argparse
import hashlib
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
        subprocess.run([sys.executable, "-m", "venv", str(DEV_DIR / "venv")], check=True)
    if not quiet:
        print("  instalando tools/requirements.txt")
    subprocess.run([str(python), "-m", "pip", "install", "--quiet", "--upgrade", "pip"],
                   check=True)
    subprocess.run([str(python), "-m", "pip", "install", "--quiet", "-r", str(requirements)],
                   check=True)
    stamp.write_text(current, encoding="utf-8")
    return python


def _gd_files() -> list[str]:
    """Todo .gd versionado. O addons/ fica de fora: e codigo de terceiro."""
    return sorted(str(p.relative_to(PROJECT)) for p in PROJECT.rglob("*.gd")
                  if "addons" not in p.parts and ".dev" not in p.parts)


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


def _godot(binary: pathlib.Path, *extra: str) -> int:
    """Roda o Godot no projeto. Comando headless usa a variante de console."""
    if "--headless" in extra:
        binary = _console_variant(binary)
    cmd = [str(binary), "--path", str(PROJECT), *extra]
    print(f"$ {' '.join(cmd)}")
    return subprocess.run(cmd).returncode


def cmd_import(_: argparse.Namespace) -> int:
    return _godot(require_godot(godot_version()), "--headless", "--import")


def cmd_selftest(args: argparse.Namespace) -> int:
    binary = require_godot(godot_version())
    # O import vem sempre antes: um class_name novo so entra no cache de
    # classes globais pelo scan do editor, e sem ele o Godot headless trava
    # sem imprimir nada.
    code = _godot(binary, "--headless", "--import")
    if code != 0:
        return code
    extra = ["--headless", "--", "--selftest"]
    if args.user_tuning:
        extra.append("--selftest-user")
    return _godot(binary, *extra)


def cmd_run(_: argparse.Namespace) -> int:
    return _godot(require_godot(godot_version()))


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


def cmd_export(_: argparse.Namespace) -> int:
    version = godot_version()
    binary = require_godot(version)
    if not (godot_data_dir() / "export_templates" / f"{version}.stable").is_dir():
        return _fail("export templates ausentes - rode `python tools/dev.py setup`")
    sync_preset_version()
    for preset, out in (("Windows Desktop", "export/windows/RushFood.exe"),
                        ("Linux", "export/linux/RushFood.x86_64"),
                        ("macOS", "export/macos/RushFood.zip")):
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
    sub.add_parser("run", help="abre o jogo")
    sub.add_parser("export", help="exporta as tres plataformas")
    sub.add_parser("lint", help="gdlint em todo .gd do projeto")
    p_fmt = sub.add_parser("format", help="gdformat em todo .gd do projeto")
    p_fmt.add_argument("--check", action="store_true",
                       help="so confere, nao reescreve (e o que o CI roda)")

    args = parser.parse_args()
    handler = {
        "doctor": cmd_doctor, "setup": cmd_setup, "import": cmd_import,
        "selftest": cmd_selftest, "run": cmd_run, "export": cmd_export,
        "lint": cmd_lint, "format": cmd_format,
    }[args.comando]
    return handler(args)


if __name__ == "__main__":
    sys.exit(main())
