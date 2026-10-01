"""Mede a moto em cada quadro do video pela bag vermelha e pelo pneu traseiro."""

import glob
import math
import os
import sys

from PIL import Image

pasta = sys.argv[1]
saida = []
for arq in sorted(glob.glob(os.path.join(pasta, "*.png"))):
    im = Image.open(arq).convert("RGB")
    w, h = im.size
    px = im.load()
    xs, ys = [], []
    for y in range(170, 380):
        for x in range(150, 500):
            r, g, b = px[x, y]
            if r > 150 and g < 70 and b < 70 and r - g > 110:
                xs.append(x)
                ys.append(y)
    if not xs:
        continue
    n = len(xs)
    cx = sum(xs) / n
    cy = sum(ys) / n
    topo = min(ys)
    base_bag = max(ys)
    # Pneu: linha mais baixa com pixel quase preto perto do eixo da bag.
    pneu_y, pneu_x = None, None
    for y in range(min(h - 1, 470), base_bag, -1):
        escuros = [
            x
            for x in range(int(cx) - 90, int(cx) + 90)
            if 0 <= x < w and sum(px[x, y]) / 3 < 38
        ]
        if len(escuros) >= 4:
            pneu_y = y
            pneu_x = sum(escuros) / len(escuros)
            break
    lean = None
    if pneu_y is not None:
        lean = math.degrees(math.atan2(cx - pneu_x, pneu_y - cy))
    saida.append((os.path.basename(arq), n, cx, cy, topo, pneu_y, pneu_x, lean))

print("quadro  area   cx     cy    topo  pneu_y  pneu_x  incl")
for q in saida:
    nome, n, cx, cy, topo, py_, pxx, lean = q
    print(
        f"{nome}  {n:5d} {cx:6.1f} {cy:6.1f} {topo:4d}  {py_ if py_ else -1:5}  "
        f"{pxx if pxx else -1:6.1f}  {lean if lean is not None else float('nan'):5.1f}"
    )
