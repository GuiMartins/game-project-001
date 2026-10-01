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
   longitudinal, a onda da calcada e longa. Detalhe longitudinal parece rastro
   de velocidade em vez de piscar - e e o que o borrao da P7 vai esticar mais.
2. **Contraste alto so no que e grande.** Grao fino tem amplitude baixa, para
   o mipmap engolir de longe sem deixar padrao; quem tem contraste e a marca de
   pneu, que tem um palmo de largura.
3. **O periodo do tile ao longo da pista e longo** (6,6 m no asfalto, 4,4 m na
   calcada): a repeticao do proprio tile fica bem acima de 1,7 m.

O mapeamento esta em `road_track.gd`: no asfalto o U cobre uma faixa de
rolamento (3,3 m) e o V 6,6 m; na calcada o U vai do meio-fio (U = 0) ate a
borda de fora, e o V cobre 4,4 m. A cor de base e neutra e um pouco escura de
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
# 128x256: U sao os 2,2 m da calcada (58 px/m), do meio-fio (U = 0) para fora; V
# sao 4,4 m (58 px/m). Texel quadrado, e 4,4 m de periodo ao longo da pista.

CALCADA_U = 128
CALCADA_V = 256
# Meio-fio: 20 cm de concreto. Sem junta transversal (regra 1): a de verdade
# vem a cada metro, e a cada metro e exatamente o periodo que pisca.
MEIO_FIO = 12
MEIO_FIO_COR = (178, 174, 166)
# Pedra portuguesa: pedrinhas de ~5 cm, 3x3 texels com rejunte de 1.
PEDRA = 4
CREME = (198, 189, 170)
PRETA = (92, 90, 88)
REJUNTE = -34
# A onda de Copacabana, correndo ao longo da pista. Um comprimento de onda por
# tile (4,4 m): a 180 km/h a onda passa de lado a lado em mais de 5 quadros,
# entao ela desliza em vez de tremer.
ONDA_CENTRO = 0.6
ONDA_AMPLITUDE = 0.2
ONDA_LARGURA = 0.11


def calcada(rng):
    tom = [Ruido(rng, 2, 4), Ruido(rng, 4, 8)]
    pixels = [0] * (CALCADA_U * CALCADA_V * 3)
    jitter = {}
    for y in range(CALCADA_V):
        v = y / CALCADA_V
        for x in range(CALCADA_U):
            k = (y * CALCADA_U + x) * 3
            u = (x + 0.5) / CALCADA_U
            if x < MEIO_FIO:
                cor = list(MEIO_FIO_COR)
                # Aresta de cima pega sol; o pe do meio-fio, no lado do
                # asfalto, e sombra. Le como degrau sem geometria nenhuma.
                ajuste = 14 if x < 2 else (-10 if x == MEIO_FIO - 1 else 0)
                ajuste += (rng.random() - 0.5) * 6
                cor = [c + ajuste for c in cor]
            else:
                # Fileiras alternadas meia pedra, como a pedra assentada a mao.
                linha = y // PEDRA
                desloca = (PEDRA // 2) if linha % 2 else 0
                coluna = (x - MEIO_FIO + desloca) // PEDRA
                chave = (linha, coluna)
                if chave not in jitter:
                    jitter[chave] = (rng.random() - 0.5) * 18
                # A onda e decidida por pedra, nao por texel: a borda da faixa
                # preta segue as pedras, serrilhada, como na calcada.
                cu = (MEIO_FIO + coluna * PEDRA - desloca + PEDRA / 2) / CALCADA_U
                cv = (linha * PEDRA + PEDRA / 2) / CALCADA_V
                onda = ONDA_CENTRO + ONDA_AMPLITUDE * math.sin(2 * math.pi * cv)
                base = PRETA if abs(cu - onda) < ONDA_LARGURA else CREME
                ajuste = jitter[chave] + (fbm(tom, u, v) - 0.5) * 14
                rejunte = (x - MEIO_FIO + desloca) % PEDRA == PEDRA - 1 or y % PEDRA == PEDRA - 1
                if rejunte:
                    ajuste += REJUNTE * (0.6 if base is PRETA else 1.0)
                cor = [c + ajuste for c in base]
            pixels[k : k + 3] = [_limita(c) for c in cor]
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
