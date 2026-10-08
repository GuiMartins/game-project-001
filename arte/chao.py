"""Gerador das texturas do chao: asfalto e calcada.

Roda com o Python do sistema, sem dependencia:

    python arte/chao.py

Grava `assets/visual/asfalto_albedo.png` e `assets/visual/calcada_albedo.png`.
Gerado, e nao pintado, pelo mesmo motivo do LUT e do entregador: a receita em
numero da para revisar em diff, e o sorteio tem semente, entao regerar sem
mudar a receita da o mesmo arquivo.

A regra que manda em tudo aqui: **o chao e visto passando a 180 km/h.**

A 50 m/s e 60 quadros por segundo a moto anda 0,83 m por quadro. Qualquer
desenho que se repete ao longo da pista com periodo menor que o dobro disso,
1,7 m, nao parece mais andar: ele pisca, ou anda para tras, como a roda da
diligencia no cinema. Junta transversal de calcada a cada metro, faixa de
zebra, rachadura atravessada - tudo isso vira chuvisco em velocidade. Dai
tres regras, que valem para as duas texturas:

1. **Detalhe fino corre ao longo da pista, nunca atravessado.** O grao do
   asfalto e quatro vezes mais comprido que largo, a marca de pneu e uma faixa
   longitudinal, a junta da calcada corre junto com ela. Detalhe longitudinal parece rastro
   de velocidade em vez de piscar - e e o que o borrao da P7 vai esticar mais.
2. **Contraste alto so no que e grande.** Grao fino tem amplitude baixa, para
   o mipmap engolir de longe sem deixar padrao; quem tem contraste e a marca de
   pneu, que tem um palmo de largura.
3. **O periodo do tile ao longo da pista e longo** (6,6 m no asfalto, 4,4 m na
   calcada): a repeticao do proprio tile fica bem acima de 1,7 m.

O mapeamento esta em `road_track.gd`: no asfalto o U cobre uma faixa de
rolamento (3,3 m) e o V 6,6 m; na calcada o U cobre 2,2 m e repete do
meio-fio ate a fachada, e o V cobre 4,4 m. A cor de base e neutra e um pouco escura de
proposito: quem da a cor de meio-dia e o LUT (`arte/paleta.py`), como em todo o
resto do mundo.
"""

import math
import os
import random

from _png import grava

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PASTA = os.path.join(RAIZ, "assets", "visual")

SEMENTE = 20260831


# --- Ruido que emenda consigo mesmo --------------------------------------------


class Ruido:
    """Value noise numa grade que da a volta: o tile emenda nas quatro bordas."""

    def __init__(self, rng, celulas_x, celulas_y):
        self.cx = celulas_x
        self.cy = celulas_y
        self.grade = [[rng.random() for _ in range(celulas_x)] for _ in range(celulas_y)]

    def em(self, u, v):
        """u, v em [0, 1). Devolve 0..1."""
        x = u * self.cx
        y = v * self.cy
        x0 = int(math.floor(x))
        y0 = int(math.floor(y))
        fx = x - x0
        fy = y - y0
        fx = fx * fx * (3 - 2 * fx)
        fy = fy * fy * (3 - 2 * fy)
        g = self.grade
        a = g[y0 % self.cy][x0 % self.cx]
        b = g[y0 % self.cy][(x0 + 1) % self.cx]
        c = g[(y0 + 1) % self.cy][x0 % self.cx]
        d = g[(y0 + 1) % self.cy][(x0 + 1) % self.cx]
        return (a + (b - a) * fx) * (1 - fy) + (c + (d - c) * fx) * fy


def fbm(oitavas, u, v):
    total = 0.0
    peso = 0.0
    amp = 1.0
    for r in oitavas:
        total += r.em(u, v) * amp
        peso += amp
        amp *= 0.5
    return total / peso


def _limita(c):
    return max(0, min(255, int(round(c))))


# --- Asfalto -------------------------------------------------------------------
#
# 256x256: U e uma faixa de 3,3 m (78 px/m), V sao 6,6 m (39 px/m). O texel ja
# sai duas vezes mais comprido que largo so pelo mapeamento.

ASFALTO = 256
ASFALTO_BASE = 104
# Grao: a brita. Amplitude baixa (regra 2) e cada grao ocupa 1x2 texels, que
# com o mapeamento da 1,3 cm x 5 cm: quatro vezes mais comprido que largo.
GRAO = 15
# Pedrinha clara ou escura solta no asfalto. E o que faz o grao ler como
# brita, e nao como chiado de TV.
PEDRA_CLARA = (0.04, 34)
PEDRA_ESCURA = (0.03, -22)
# Remendo e desgaste: manchas grandes, de metro, quase sem contraste.
REMENDO = 12
# Onde a roda dos carros passa, a 0,8 m do centro da faixa: o asfalto fica
# mais escuro e liso. Centro em U = 0,5 +/- 0,8 / 3,3.
TRILHA_U = (0.258, 0.742)
TRILHA_LARGURA = 0.1
TRILHA = -24
# O pingo de oleo no meio da faixa, de carro parado no transito.
OLEO_LARGURA = 0.035
OLEO = -14
# Perto da faixa pintada ninguem roda: sobra poeira, um pouco mais claro.
POEIRA = 10


def asfalto(rng):
    remendo = [Ruido(rng, 4, 2), Ruido(rng, 8, 4), Ruido(rng, 16, 8)]
    # A trilha de pneu nao e continua: some e volta ao longo da pista. A grade
    # e larga em U e curta em V para a variacao ser ao longo do comprimento.
    falha = [Ruido(rng, 2, 6), Ruido(rng, 4, 12)]
    gotas = [Ruido(rng, 2, 10), Ruido(rng, 4, 20)]
    grao = [[rng.random() for _ in range(ASFALTO)] for _ in range(ASFALTO // 2)]
    pedra = [[rng.random() for _ in range(ASFALTO)] for _ in range(ASFALTO // 2)]

    pixels = [0] * (ASFALTO * ASFALTO * 3)
    for y in range(ASFALTO):
        v = y / ASFALTO
        for x in range(ASFALTO):
            u = (x + 0.5) / ASFALTO
            val = ASFALTO_BASE
            val += (fbm(remendo, u, v) - 0.5) * 2 * REMENDO

            # Triangular, e nao uniforme: a maioria dos graos fica perto da base
            # e so alguns se destacam, como numa brita de verdade.
            g = grao[y // 2][x]
            val += (g + grao[y // 2][(x + 1) % ASFALTO] - 1.0) * GRAO
            p = pedra[y // 2][x]
            if p < PEDRA_CLARA[0]:
                val += PEDRA_CLARA[1]
            elif p > 1.0 - PEDRA_ESCURA[0]:
                val += PEDRA_ESCURA[1]

            presenca = 0.45 + 0.55 * fbm(falha, u, v)
            for centro in TRILHA_U:
                d = (u - centro) / TRILHA_LARGURA
                val += TRILHA * math.exp(-d * d) * presenca
            d = (u - 0.5) / OLEO_LARGURA
            val += OLEO * math.exp(-d * d) * max(0.0, fbm(gotas, u, v) * 2.2 - 1.0)

            borda = min(u, 1.0 - u)
            val += POEIRA * max(0.0, 1.0 - borda / 0.12)

            # Quase neutro, com um fio de azul: asfalto puxando para o quente
            # vira terra depois do LUT, que ja esquenta a luz.
            k = (y * ASFALTO + x) * 3
            pixels[k] = _limita(val)
            pixels[k + 1] = _limita(val)
            pixels[k + 2] = _limita(val + 2)
    return pixels


# --- Calcada -------------------------------------------------------------------
#
# 128x256: U sao 2,2 m de calcada (58 px/m) e V sao 4,4 m (58 px/m). Texel
# quadrado, e o tile repete nos dois eixos: a calcada vai do meio-fio ate a
# fachada, e o meio-fio e geometria propria no `road_track.gd`.
#
# Cimentado, e nao pedra portuguesa. A onda de Copacabana e calcadao de praia;
# a calcada de avenida das referencias (`docs/referencias/video_01`) e lisa,
# clara, sem desenho - quem da o ritmo nela e o que esta em cima: poste,
# arvore, gente.

CALCADA_U = 128
CALCADA_V = 256
CIMENTO = (168, 164, 156)
# Manchas de metro, de chuva e de sujeira: quase sem contraste (regra 2).
MANCHA = 16
# Grao do cimento: 1x3 texels, comprido ao longo da pista (regra 1).
GRAO_CIMENTO = 7
# Junta de dilatacao so longitudinal, uma por tile (2,2 m). A transversal de
# verdade vem a cada 1,5 m, e 1,5 m e exatamente o periodo que pisca.
JUNTA = -26
# Chiclete e pingo de oleo: pontos escuros soltos, o que faz o liso ler como
# chao pisado, e nao como plastico.
PINGO = (0.012, -30)


def calcada(rng):
    mancha = [Ruido(rng, 2, 4), Ruido(rng, 4, 8), Ruido(rng, 8, 16)]
    grao = [[rng.random() for _ in range(CALCADA_U)] for _ in range(CALCADA_V // 3 + 1)]
    pingo = [[rng.random() for _ in range(CALCADA_U // 2)] for _ in range(CALCADA_V // 2)]
    pixels = [0] * (CALCADA_U * CALCADA_V * 3)
    for y in range(CALCADA_V):
        v = y / CALCADA_V
        for x in range(CALCADA_U):
            k = (y * CALCADA_U + x) * 3
            u = (x + 0.5) / CALCADA_U
            ajuste = (fbm(mancha, u, v) - 0.5) * 2 * MANCHA
            ajuste += (grao[y // 3][x] - 0.5) * GRAO_CIMENTO
            if pingo[y // 2][x // 2] < PINGO[0]:
                ajuste += PINGO[1]
            if x == 0:
                ajuste += JUNTA
            elif x == 1:
                # A borda da placa do lado de la pega sol.
                ajuste += 8
            pixels[k : k + 3] = [_limita(c + ajuste) for c in CIMENTO]
    return pixels


def _media(pixels):
    return sum(pixels) / len(pixels)


def main():
    rng = random.Random(SEMENTE)
    px = asfalto(rng)
    caminho = os.path.join(PASTA, "asfalto_albedo.png")
    grava(caminho, ASFALTO, ASFALTO, px)
    print("asfalto: %s (media %.0f)" % (caminho, _media(px)))

    px = calcada(rng)
    caminho = os.path.join(PASTA, "calcada_albedo.png")
    grava(caminho, CALCADA_U, CALCADA_V, px)
    print("calcada: %s (media %.0f)" % (caminho, _media(px)))


main()
