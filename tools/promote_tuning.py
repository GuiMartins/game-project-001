#!/usr/bin/env python3
"""Promove o tuning salvo no jogo (user://*.tres) para os defaults dos .gd.

O botao Salvar do painel F3 grava um override local, fora do repositorio. Os
defaults de verdade sao os literais `= 52.0` nos @export_range. Este script
fecha essa distancia: le o que voce salvou jogando e reescreve os defaults.

Uso:
    python3 tools/promote_tuning.py            # mostra o que mudaria
    python3 tools/promote_tuning.py --apply    # grava nos .gd
    python3 tools/promote_tuning.py --apply --clear-user   # e zera o override

Sem --apply nao escreve nada.
"""
from __future__ import annotations

import argparse
import pathlib
import re
import sys

# A pasta do user:// e a forma de gravar saem do dev.py, que e quem conhece as
# convencoes de cada sistema. Antes daqui, este script so achava o user:// no
# macOS - no Windows e no Linux ele dizia "nada salvo" com o arquivo no lugar.
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from dev import PROJECT, godot_user_data, write_text_lf  # noqa: E402

DEFAULT_USER_DIR = godot_user_data()

# @export_range(20.0, 90.0, 0.5) var max_speed: float = 52.0
EXPORT_LINE = re.compile(
    r"^(?P<head>@export_range\((?P<args>[^)]*)\)\s+var\s+(?P<name>\w+)\s*:\s*"
    r"(?P<type>\w+)\s*=\s*)(?P<value>[^\s#]+)(?P<tail>.*)$"
)


def parse_tres(path: pathlib.Path) -> tuple[pathlib.Path | None, dict[str, str]]:
    """Devolve (script .gd alvo, {propriedade: literal}) de um .tres salvo."""
    script_path: pathlib.Path | None = None
    values: dict[str, str] = {}
    in_resource = False
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line.startswith("[ext_resource"):
            m = re.search(r'path="res://([^"]+)"', line)
            if m:
                script_path = PROJECT / m.group(1)
        elif line.startswith("[resource]"):
            in_resource = True
        elif in_resource and "=" in line and not line.startswith("["):
            key, _, raw = line.partition("=")
            key, raw = key.strip(), raw.strip()
            # `script = ExtResource("1_x")` nao e um parametro de tuning.
            if key and not raw.startswith("ExtResource"):
                values[key] = raw
    return script_path, values


def format_value(raw: str, step_text: str, gd_type: str) -> str:
    """Arredonda pro passo do slider, pra o default nao virar 0.41999998688."""
    try:
        number = float(raw)
    except ValueError:
        return raw
    if gd_type == "int":
        return str(int(round(number)))
    decimals = 3
    try:
        step = float(step_text)
        if step > 0:
            for d in range(5):
                scaled = step * (10.0**d)
                if abs(scaled - round(scaled)) < 1e-9:
                    decimals = d
                    break
            else:
                decimals = 4
    except ValueError:
        pass
    # Float em GDScript precisa de ponto decimal, senao vira int.
    return f"{number:.{max(decimals, 1)}f}"


def promote(script_path: pathlib.Path, values: dict[str, str]) -> tuple[str, list[tuple[str, str, str]]]:
    lines = script_path.read_text(encoding="utf-8").splitlines(keepends=True)
    changes: list[tuple[str, str, str]] = []
    for i, line in enumerate(lines):
        m = EXPORT_LINE.match(line.rstrip("\n"))
        if not m or m.group("name") not in values:
            continue
        name = m.group("name")
        args = [a.strip() for a in m.group("args").split(",")]
        step_text = args[2] if len(args) > 2 else "0.01"
        old = m.group("value")
        new = format_value(values[name], step_text, m.group("type"))
        if old == new:
            continue
        changes.append((name, old, new))
        lines[i] = f"{m.group('head')}{new}{m.group('tail')}\n"
    return "".join(lines), changes


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--apply", action="store_true", help="grava nos .gd")
    ap.add_argument("--clear-user", action="store_true",
                    help="apaga o override depois de promover")
    ap.add_argument("--user-dir", type=pathlib.Path, default=DEFAULT_USER_DIR)
    args = ap.parse_args()

    saved = sorted(args.user_dir.glob("*.tres"))
    if not saved:
        print(f"nada salvo em {args.user_dir}")
        print("abra o jogo, ajuste com F3 e clique em Salvar primeiro.")
        return 1

    total = 0
    for tres in saved:
        script_path, values = parse_tres(tres)
        if script_path is None or not script_path.exists():
            print(f"! {tres.name}: nao achei o script alvo, pulando")
            continue
        text, changes = promote(script_path, values)
        rel = script_path.relative_to(PROJECT)
        if not changes:
            print(f"= {rel}: nada a promover")
            continue
        total += len(changes)
        print(f"\n{rel}  ({len(changes)} parametro(s))")
        for name, old, new in changes:
            print(f"    {name:<26} {old:>10}  ->  {new}")
        if args.apply:
            write_text_lf(script_path, text)

    if total == 0:
        print("\nos defaults ja sao os valores salvos.")
        return 0

    if args.apply:
        print(f"\ngravado: {total} default(s) atualizado(s).")
        if args.clear_user:
            for tres in saved:
                tres.unlink()
            print("override local apagado - o jogo agora roda nos defaults novos.")
        print("rode o banco de provas antes de commitar:")
        print("  python tools/dev.py selftest")
    else:
        print(f"\n{total} default(s) mudariam. rode com --apply pra gravar.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
