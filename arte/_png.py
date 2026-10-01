"""Gravador de PNG RGB8 sem dependencia, compartilhado pelos geradores de arte.

Sem carimbo de data nem metadado de programa, entao a mesma receita sempre da
o mesmo arquivo, byte a byte: um asset regerado sem mudanca de receita nao
aparece no diff, e um que aparece mudou de verdade.
"""

import os
import struct
import zlib


def grava(caminho, largura, altura, pixels):
    """`pixels` e uma lista plana de inteiros 0-255, RGB, linha a linha.

    Cabecalho, um bloco de dados comprimido e o fim: o minimo.
    """

    def bloco(tipo, dados):
        corpo = tipo + dados
        return struct.pack(">I", len(dados)) + corpo + struct.pack(">I", zlib.crc32(corpo))

    linhas = b"".join(
        b"\x00" + bytes(pixels[y * largura * 3 : (y + 1) * largura * 3]) for y in range(altura)
    )
    os.makedirs(os.path.dirname(caminho), exist_ok=True)
    with open(caminho, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(bloco(b"IHDR", struct.pack(">IIBBBBB", largura, altura, 8, 2, 0, 0, 0)))
        f.write(bloco(b"IDAT", zlib.compress(linhas, 9)))
        f.write(bloco(b"IEND", b""))
