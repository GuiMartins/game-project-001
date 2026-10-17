"""Gerador dos LUTs de cor de cada hora: `assets/visual/lut_<hora>.png`.

Roda com o Python do sistema, sem dependencia:

    python arte/paleta.py            # os quatro LUTs: dia, entardecer, crepusculo, noite
    python arte/paleta.py --neutro   # o LUT identidade no lugar do dia, para conferir a importacao

A corrida anoitece (`scripts/hora.gd`): larga ao meio-dia e cruza a linha de
noite. Cada hora-chave tem o seu LUT, e o `Relogio` mistura os dois vizinhos
conforme a hora anda. A receita e uma so, com quatro jogos de numeros: o que
muda da tarde para a noite e o empurrao, nao a conta.

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
import sys

from _png import grava

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PASTA = os.path.join(RAIZ, "assets", "visual")

N = 16

# --- As receitas -------------------------------------------------------------
#
# Cada numero e um empurrao pequeno, porque eles se somam e o LUT entra depois
# do tonemap, que ja comprimiu o alto. Os campos:
# - saturacao: 1 e neutro;
# - contraste: a forca da curva em S em volta do cinza medio;
# - sombra / luz: divisao de tom, quanto a sombra e a luz puxam em cada canal.
#
# O dia, o que as referencias tem em comum: cor alta, contraste alto, sombra
# fria e sol quente. O greybox e acinzentado de proposito, e e aqui que ele
# ganha a cor de meio-dia. A divisao de tom e o que separa "sol do Rio" de "dia
# nublado", e o motivo de a sombra azul do ceu (AMBIENT_SOURCE_SKY) nao virar
# cinza no fim da cadeia.
DIA = {
    "saturacao": 1.2,
    "contraste": 0.22,
    "sombra": (-0.01, 0.0, 0.025),
    "luz": (0.04, 0.015, -0.035),
}
# O entardecer: sol baixo e laranja. A luz puxa mais para o ambar que a do
# meio-dia, e a sombra fica violeta, que e a cor do ceu do lado oposto ao sol.
ENTARDECER = {
    "saturacao": 1.25,
    "contraste": 0.2,
    "sombra": (0.0, -0.01, 0.035),
    "luz": (0.06, 0.02, -0.05),
}
# O crepusculo: o sol ja foi, e o que sobra e a hora azul. Saturacao neutra,
# para o laranja do horizonte e o azul do resto nao virarem neon um contra o
# outro; a sombra azul e funda.
CREPUSCULO = {
    "saturacao": 1.0,
    "contraste": 0.16,
    "sombra": (-0.005, 0.0, 0.04),
    "luz": (0.04, 0.015, -0.03),
}
# A noite: pouca cor no escuro, que e como o olho ve, e as lampadas quentes
# por cima. Contraste baixo de proposito: a cena ja e quase toda sombra, e a
# curva em S esmagaria o asfalto iluminado pelo poste no mesmo preto do resto.
NOITE = {
    "saturacao": 0.85,
    "contraste": 0.1,
    "sombra": (-0.01, 0.0, 0.035),
    "luz": (0.05, 0.02, -0.04),
}
HORAS = {"dia": DIA, "entardecer": ENTARDECER, "crepusculo": CREPUSCULO, "noite": NOITE}


def _luma(r, g, b):
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def _curva_s(x, contraste):
    # Smoothstep misturado com a reta: forca 0 e identidade.
    s = x * x * (3.0 - 2.0 * x)
    return x + (s - x) * contraste * 2.0


def receita(hora):
    def cor(r, g, b):
        y = _luma(r, g, b)
        r, g, b = (y + (c - y) * hora["saturacao"] for c in (r, g, b))
        r, g, b = (_curva_s(min(max(c, 0.0), 1.0), hora["contraste"]) for c in (r, g, b))
        # Peso da sombra cai com a luz; o da luz sobe. No meio-tom, quase nada.
        peso_sombra = max(0.0, 1.0 - y * 2.0)
        peso_luz = max(0.0, y * 2.0 - 1.0)
        r, g, b = (
            c + s * peso_sombra + q * peso_luz
            for c, s, q in zip((r, g, b), hora["sombra"], hora["luz"])
        )
        return tuple(min(max(c, 0.0), 1.0) for c in (r, g, b))

    return cor


def neutro(r, g, b):
    return (r, g, b)


def grava_lut(caminho, cor):
    largura, altura = N * N, N
    pixels = [0] * (largura * altura * 3)
    for azul in range(N):
        for verde in range(N):
            for vermelho in range(N):
                c = cor(vermelho / (N - 1), verde / (N - 1), azul / (N - 1))
                k = (verde * largura + azul * N + vermelho) * 3
                pixels[k : k + 3] = [round(v * 255) for v in c]
    grava(caminho, largura, altura, pixels)
    print("lut: %s" % caminho)


def main():
    for nome, hora in HORAS.items():
        cor = neutro if nome == "dia" and "--neutro" in sys.argv else receita(hora)
        grava_lut(os.path.join(PASTA, "lut_%s.png" % nome), cor)


main()
