"""Folha de quadros com o tempo escrito em cada um.

Uso: python folha.py <pasta_de_quadros> <saida.png> 0,0.5,1 [escala]
Os quadros sao os do ffmpeg a 30 fps (001.png = 0,0 s), em 360x640.
"""

import sys

from PIL import Image, ImageDraw, ImageFont

pasta, saida = sys.argv[1], sys.argv[2]
tempos = [float(x) for x in sys.argv[3].split(",")]
escala = float(sys.argv[4]) if len(sys.argv) > 4 else 0.75
quadros = []
for t in tempos:
    im = Image.open(f"{pasta}/{int(round(t * 30)) + 1:03d}.png").convert("RGB")
    im = im.resize((int(im.width * escala), int(im.height * escala)))
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 90, 28], fill=(0, 0, 0))
    d.text((4, 2), f"{t:.1f}s", fill=(255, 255, 0), font=ImageFont.load_default(size=22))
    quadros.append(im)
w, h = quadros[0].size
colunas = min(6, len(quadros))
linhas = (len(quadros) + colunas - 1) // colunas
folha = Image.new("RGB", (w * colunas, h * linhas))
for i, im in enumerate(quadros):
    folha.paste(im, ((i % colunas) * w, (i // colunas) * h))
folha.save(saida)
