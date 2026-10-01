"""Gerador do LUT de cor do dia: `assets/visual/lut_dia.png`.

Roda com o Python do sistema, sem dependencia:

    python arte/paleta.py            # o LUT do dia
    python arte/paleta.py --neutro   # o LUT identidade, para conferir a importacao

O LUT e o ponto unico onde o "clima" da tela se ajusta (DIRECAO_VISUAL.md,
"Ceu, paleta e dithering"): uma fase de fim de tarde e outro LUT, nao outro
shader. Ele e gerado, e nao pintado num editor, pelo mesmo motivo do modelo do
entregador: a receita em numero da para revisar em diff, e uma curva arrastada
a mao num programa de imagem nao.

Formato, o do manifesto do PROVA_VISUAL.md: 256x16, dezesseis fatias de 16x16
lado a lado. A fatia e o azul; dentro dela, x e o vermelho e y e o verde. O
Godot importa como `Texture3D` (`slices/horizontal=16` no `.import`) e o
`Environment.adjustment_color_correction` amostra com a cor da tela: u = r,
v = g, w = b. O `--neutro` existe porque esta orientacao e o tipo de coisa que
sai espelhada sem ninguem notar - com o LUT identidade, a tela tem que sair
igual a de sem LUT.
"""

import os
import struct
import sys
import zlib

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SAIDA = os.path.join(RAIZ, "assets", "visual", "lut_dia.png")

N = 16

# --- A receita do dia ---------------------------------------------------------
#
# O que as referencias tem em comum: cor alta, contraste alto, sombra fria e
# sol quente. Cada numero e um empurrao pequeno, porque eles se somam e o LUT
# entra depois do tonemap, que ja comprimiu o alto.

# Saturacao: 1 e neutro. O greybox e acinzentado de proposito, e e aqui que
# ele ganha a cor de meio-dia.
SATURACAO = 1.2
# Contraste: a forca da curva em S em volta do cinza medio.
CONTRASTE = 0.22
# Divisao de tom: quanto a sombra puxa para o azul e a luz para o amarelo.
# E o que separa "sol do Rio" de "dia nublado", e o motivo de a sombra azul do
# ceu (AMBIENT_SOURCE_SKY) nao virar cinza no fim da cadeia.
SOMBRA_FRIA = (-0.01, 0.0, 0.025)
LUZ_QUENTE = (0.04, 0.015, -0.035)


def _luma(r, g, b):
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def _curva_s(x):
    # Smoothstep misturado com a reta: forca 0 e identidade.
    s = x * x * (3.0 - 2.0 * x)
    return x + (s - x) * CONTRASTE * 2.0


def dia(r, g, b):
    y = _luma(r, g, b)
    r, g, b = (y + (c - y) * SATURACAO for c in (r, g, b))
    r, g, b = (_curva_s(min(max(c, 0.0), 1.0)) for c in (r, g, b))
    # Peso da sombra cai com a luz; o da luz sobe. No meio-tom, quase nada.
    peso_sombra = max(0.0, 1.0 - y * 2.0)
    peso_luz = max(0.0, y * 2.0 - 1.0)
    r, g, b = (
        c + s * peso_sombra + q * peso_luz for c, s, q in zip((r, g, b), SOMBRA_FRIA, LUZ_QUENTE)
    )
    return tuple(min(max(c, 0.0), 1.0) for c in (r, g, b))


def neutro(r, g, b):
    return (r, g, b)


# --- PNG sem dependencia ------------------------------------------------------


def _png(caminho, largura, altura, pixels):
    """Grava RGB8. Cabecalho, um bloco de dados comprimido e o fim: o minimo.

    Sem carimbo de data nem metadado de programa, entao a mesma receita sempre
    da o mesmo arquivo, byte a byte.
    """

    def bloco(tipo, dados):
        corpo = tipo + dados
        return struct.pack(">I", len(dados)) + corpo + struct.pack(">I", zlib.crc32(corpo))

    linhas = b"".join(
        b"\x00" + bytes(pixels[y * largura * 3 : (y + 1) * largura * 3]) for y in range(altura)
    )
    with open(caminho, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(bloco(b"IHDR", struct.pack(">IIBBBBB", largura, altura, 8, 2, 0, 0, 0)))
        f.write(bloco(b"IDAT", zlib.compress(linhas, 9)))
        f.write(bloco(b"IEND", b""))


def main():
    receita = neutro if "--neutro" in sys.argv else dia
    largura, altura = N * N, N
    pixels = [0] * (largura * altura * 3)
    for azul in range(N):
        for verde in range(N):
            for vermelho in range(N):
                cor = receita(vermelho / (N - 1), verde / (N - 1), azul / (N - 1))
                k = (verde * largura + azul * N + vermelho) * 3
                pixels[k : k + 3] = [round(c * 255) for c in cor]
    os.makedirs(os.path.dirname(SAIDA), exist_ok=True)
    _png(SAIDA, largura, altura, pixels)
    print("lut: %s (%s)" % (SAIDA, receita.__name__))


main()
