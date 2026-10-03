"""Quadros lado a lado com grade de 10% da tela, para ler posicao a olho.

Uso: python grade.py <pasta_de_quadros> <saida.png> 0,3,4
Linhas magenta: altura (numero = % a partir do topo). Ciano: largura.
"""

import sys

from PIL import Image, ImageDraw, ImageFont

pasta, saida = sys.argv[1], sys.argv[2]
tempos = [float(x) for x in sys.argv[3].split(",")]
fonte = ImageFont.load_default(size=16)
quadros = []
for t in tempos:
    im = Image.open(f"{pasta}/{int(round(t * 30)) + 1:03d}.png").convert("RGB")
    d = ImageDraw.Draw(im)
    for k in range(1, 10):
        y, x = im.height * k // 10, im.width * k // 10
        d.line([(0, y), (im.width, y)], fill=(255, 0, 255))
        d.text((2, y - 16), str(k * 10), fill=(255, 0, 255), font=fonte)
        d.line([(x, 0), (x, im.height)], fill=(0, 255, 255))
    d.rectangle([0, 0, 70, 22], fill=(0, 0, 0))
    d.text((4, 2), f"{t:.1f}s", fill=(255, 255, 0), font=fonte)
    quadros.append(im)
w, h = quadros[0].size
folha = Image.new("RGB", (w * len(quadros), h))
for i, im in enumerate(quadros):
    folha.paste(im, (i * w, 0))
folha.save(saida)
