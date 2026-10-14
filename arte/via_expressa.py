"""Gerador das texturas do kit de via expressa (V11b): murais, concreto e cerca.

Roda com o Python do sistema, sem dependencia:

    python arte/via_expressa.py

Grava em `assets/via_expressa/`:

- `murais_albedo.png`: o atlas de paineis do muro e do pilar, 4x4 paineis de
  128x64. Cada modulo de muro (8 m) e cada face de pilar sorteia um painel,
  entao a mesma receita veste qualquer trecho, de qualquer comprimento: nunca
  um mural unico pintado para casar com o quadro da `03_viaduto`.
- `concreto_albedo.png`: concreto manchado, do tabuleiro, da mureta, do topo
  do muro e do pilar. Tile de 4 m.
- `cerca_albedo.png`: a tela de alambrado, com furo (RGBA). Tile de 1 m.

O geometria nao mora aqui: muro, mureta, cerca e tabuleiro seguem a curva e a
rampa da pista, entao saem do `scripts/via_expressa.gd`, extrudados na
`RoadTrack` como o meio-fio. Aqui so o que e pintado.

O que as referencias pedem, e a regra de cada coisa:

- **Mural e figura grande, de contorno escuro** (`03_viaduto`, `04_vertical`):
  folha tropical, flor, bicho, rosto, onda. O muro passa a 2 m da moto, e a
  128 km/h so le forma de metro; detalhe de palmo vira chuvisco. Por isso a
  figura tem de 1 a 4 m e o contorno tem 1 texel (12 cm).
- **Grafite e letra de bolha sobre concreto**, com escorrido: e o que ocupa o
  muro entre um mural e outro, e o pichado do muro de pedra da `02`.
- **Sujeira de baixo para cima**: o pe do muro escurece, como o da `04`.

Cor viva de proposito: quem acerta o clima da tela e o LUT (`arte/paleta.py`).
"""

import math
import os
import random

from _png import grava

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PASTA = os.path.join(RAIZ, "assets", "via_expressa")

SEMENTE = 20260831

# O painel: 128x64 para um modulo de muro de 8 m por 4 a 5,5 m de altura. Da
# 16 texels por metro ao longo do muro, que a 2 m da camera, a 640x360, e
# perto de um texel por pixel: o mural chega pixelado como o resto do mundo.
PAINEL = (128, 64)
GRADE = (4, 4)

PRETO = (32, 26, 36)
BRANCO = (236, 232, 222)
CONCRETO = (150, 146, 136)

# A paleta dos murais das referencias: rosa, magenta, turquesa, azul, amarelo,
# laranja, verde de folha, roxo e creme.
CORES = {
    "rosa": (236, 120, 160),
    "magenta": (200, 60, 140),
    "turquesa": (40, 160, 160),
    "azul": (56, 96, 196),
    "celeste": (110, 180, 230),
    "amarelo": (250, 204, 64),
    "laranja": (240, 128, 52),
    "verde": (72, 160, 72),
    "musgo": (40, 110, 60),
    "roxo": (128, 84, 180),
    "creme": (236, 220, 184),
    "vermelho": (210, 56, 50),
}

# Os paineis do atlas, na ordem: o que cada um pinta. Tropical e grafite sao
# a maioria, como no muro da `04`; o liso sujo e o respiro entre um e outro.
PAINEIS = [
    "tropical",
    "tropical",
    "tropical",
    "tropical",
    "bicho",
    "rosto",
    "bicho",
    "onda",
    "grafite",
    "grafite",
    "grafite",
    "tropical",
    "rosto",
    "onda",
    "grafite",
    "sujo",
]


class Tela:
    """Um painel em pintura: a cor e, para o contorno, qual figura e de quem."""

    def __init__(self, largura, altura, fundo):
        self.w = largura
        self.h = altura
        self.cor = [[fundo] * largura for _ in range(altura)]
        self.dono = [[0] * largura for _ in range(altura)]
        self.proximo = 1

    def figura(self):
        self.proximo += 1
        return self.proximo

    def pinta(self, x, y, cor, dono):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.cor[y][x] = cor
            self.dono[y][x] = dono

    def contorno(self):
        """Escurece a borda de cada figura: o traco de 1 texel das referencias.

        Desenha na figura de cima, a que cobriu a outra, para o traco nao
        comer o fundo em volta.
        """
        borda = []
        for y in range(self.h):
            for x in range(self.w):
                d = self.dono[y][x]
                if d <= 1:
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < self.w and 0 <= ny < self.h and self.dono[ny][nx] < d:
                        borda.append((x, y))
                        break
        for x, y in borda:
            self.cor[y][x] = PRETO


def _mistura(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def _escurece(c, f):
    return tuple(int(round(v * f)) for v in c)


def _sorteia_cores(rng, n):
    nomes = list(CORES)
    rng.shuffle(nomes)
    return [CORES[nome] for nome in nomes[:n]]


# --- Figuras -------------------------------------------------------------------


def folha(tela, rng, cx, cy, comprimento, largura, angulo, cor):
    """Folha de bananeira: elipse de ponta, com a nervura e os veios mais escuros."""
    dono = tela.figura()
    veio = _escurece(cor, 0.72)
    ca, sa = math.cos(angulo), math.sin(angulo)
    raio = int(comprimento) + 2
    for y in range(int(cy) - raio, int(cy) + raio):
        for x in range(int(cx) - raio, int(cx) + raio):
            dx, dy = x - cx, y - cy
            u = dx * ca + dy * sa
            v = -dx * sa + dy * ca
            t = (u + comprimento * 0.5) / comprimento
            if not 0.0 <= t <= 1.0:
                continue
            meia = largura * math.sin(math.pi * t) ** 0.8
            if abs(v) > meia:
                continue
            c = cor
            # A nervura do meio e os veios em diagonal, de metro em metro: e o
            # que faz a mancha verde ler como folha de longe.
            if abs(v) < 0.7 or (int(u * 0.55 + abs(v) * 0.55) % 3 == 0 and abs(v) > 1.5):
                c = veio
            tela.pinta(x, y, c, dono)


def disco(tela, cx, cy, raio, cor, dono=None):
    dono = dono or tela.figura()
    for y in range(int(cy - raio) - 1, int(cy + raio) + 2):
        for x in range(int(cx - raio) - 1, int(cx + raio) + 2):
            if (x - cx) ** 2 + (y - cy) ** 2 <= raio * raio:
                tela.pinta(x, y, cor, dono)
    return dono


def flor(tela, rng, cx, cy, raio, petala, miolo):
    n = rng.randint(5, 7)
    giro = rng.uniform(0, math.pi)
    dono = tela.figura()
    for i in range(n):
        a = giro + i * 2 * math.pi / n
        disco(tela, cx + math.cos(a) * raio * 0.6, cy + math.sin(a) * raio * 0.6, raio * 0.5, petala, dono)
    disco(tela, cx, cy, raio * 0.35, miolo)


def olho(tela, cx, cy, raio):
    disco(tela, cx, cy, raio, BRANCO)
    disco(tela, cx + raio * 0.2, cy, raio * 0.5, PRETO)


def tropical(tela, rng):
    """Folhagem que tapa o painel inteiro, com flor por cima: o muro da `04`."""
    fundo, *verdes = _sorteia_cores(rng, 3)
    for y in range(tela.h):
        for x in range(tela.w):
            tela.cor[y][x] = _mistura(fundo, BRANCO, 0.15 * y / tela.h)
    verdes = [CORES["verde"], CORES["musgo"], CORES["turquesa"]] + verdes
    for _ in range(rng.randint(16, 22)):
        folha(
            tela,
            rng,
            rng.uniform(0, tela.w),
            rng.uniform(0, tela.h),
            rng.uniform(26, 48),
            rng.uniform(6, 11),
            rng.uniform(0, math.pi),
            rng.choice(verdes),
        )
    for _ in range(rng.randint(2, 4)):
        petala = rng.choice([CORES["rosa"], CORES["magenta"], CORES["amarelo"], CORES["laranja"]])
        flor(tela, rng, rng.uniform(10, tela.w - 10), rng.uniform(10, tela.h - 10), rng.uniform(7, 12), petala, CORES["amarelo"])


def bicho(tela, rng):
    """Bicho de mural: corpo de bolhas, olho grande, bico ou boca. Le como a
    arara do pilar da `03` e a criatura rosa da `04` sem ser nenhuma das duas."""
    fundo, corpo, asa = _sorteia_cores(rng, 3)
    for y in range(tela.h):
        for x in range(tela.w):
            tela.cor[y][x] = _mistura(fundo, CORES["celeste"], 0.3 * x / tela.w)
    for _ in range(4):
        folha(tela, rng, rng.uniform(0, tela.w), rng.uniform(0, tela.h), rng.uniform(20, 34), 6, rng.uniform(0, math.pi), CORES["verde"])
    cx = rng.uniform(44, 84)
    cy = rng.uniform(28, 36)
    dono = tela.figura()
    for i in range(6):
        disco(tela, cx - 22 + i * 8, cy + math.sin(i * 0.9) * 4, 13 - abs(i - 2) * 1.6, corpo, dono)
    folha(tela, rng, cx - 6, cy + 6, 38, 9, rng.uniform(-0.5, 0.5), asa)
    olho(tela, cx + 16, cy - 6, 5)
    bico = tela.figura()
    for y in range(int(cy) - 4, int(cy) + 6):
        for x in range(int(cx) + 24, int(cx) + 36):
            if abs(y - cy - 1) < (cx + 36 - x) * 0.45:
                tela.pinta(x, y, CORES["amarelo"], bico)


def rosto(tela, rng):
    """Rosto grande de frente, de cor chapada: o pilar da `03` e o "RIO E
    NOSSO" da coroa. Olho, boca e cabelo; o resto e a cor."""
    fundo, pele, cabelo = _sorteia_cores(rng, 3)
    for y in range(tela.h):
        for x in range(tela.w):
            tela.cor[y][x] = fundo if (x // 16 + y // 16) % 2 else _escurece(fundo, 0.9)
    cx = rng.uniform(48, 80)
    cy = 34
    juba = tela.figura()
    for i in range(9):
        a = math.pi + i * math.pi / 8
        disco(tela, cx + math.cos(a) * 24, cy + math.sin(a) * 22, 9, cabelo, juba)
    disco(tela, cx, cy, 22, pele)
    for lado in (-1, 1):
        disco(tela, cx + lado * 9, cy - 5, 5, BRANCO)
        disco(tela, cx + lado * 9 + 1, cy - 5, 2.6, PRETO)
    boca = tela.figura()
    for y in range(int(cy) + 6, int(cy) + 14):
        for x in range(int(cx) - 10, int(cx) + 11):
            if ((x - cx) / 10.0) ** 2 + ((y - cy - 10) / 4.0) ** 2 <= 1.0:
                tela.pinta(x, y, CORES["vermelho"], boca)


def onda(tela, rng):
    """Faixas de onda em cor chapada com peixe: o mar do calcadao no muro."""
    cores = _sorteia_cores(rng, 4) + [CORES["azul"], CORES["turquesa"]]
    fase = rng.uniform(0, 6.28)
    for y in range(tela.h):
        for x in range(tela.w):
            k = int((y + 6 * math.sin(x * 0.08 + fase)) // 9)
            tela.cor[y][x] = cores[k % len(cores)]
            tela.dono[y][x] = 0
    for _ in range(rng.randint(2, 3)):
        cx, cy = rng.uniform(16, tela.w - 16), rng.uniform(14, tela.h - 14)
        cor = rng.choice(list(CORES.values()))
        folha(tela, rng, cx, cy, 30, 9, rng.uniform(-0.3, 0.3), cor)
        olho(tela, cx + 9, cy - 1, 2.5)


def _letra(tela, rng, x0, y0, w, h, cor):
    """Uma letra de bolha: bloco de canto redondo, inclinado, com um furo."""
    dono = tela.figura()
    torto = rng.uniform(-0.25, 0.25)
    for y in range(int(y0), int(y0 + h)):
        for x in range(int(x0 - h * 0.3), int(x0 + w + h * 0.3)):
            lx = x - x0 - (y - y0) * torto
            ly = y - y0
            dx = max(0.0, abs(lx - w / 2) - w / 2 + 4)
            dy = max(0.0, abs(ly - h / 2) - h / 2 + 4)
            if dx * dx + dy * dy <= 16:
                tela.pinta(x, y, cor, dono)
    # O furo da letra, que e o que separa letra de bolha de mancha.
    fx = x0 + w / 2 + rng.uniform(-2, 2)
    disco(tela, fx, y0 + h * 0.4, min(w, h) * 0.16, _escurece(cor, 0.45))
    # O brilho branco no canto, da lata.
    disco(tela, x0 + 4, y0 + 4, 1.5, BRANCO)


def grafite(tela, rng):
    """Letra de bolha com escorrido, sobre concreto sujo: o muro entre um mural
    e outro, e o pichado do muro de pedra da `02`."""
    _concreto(tela, rng)
    cor, sombra = _sorteia_cores(rng, 2)
    x = rng.uniform(4, 14)
    y = rng.uniform(14, 24)
    while x < tela.w - 24:
        w = rng.uniform(14, 22)
        h = rng.uniform(22, 30)
        # A sombra deslocada de cada letra, o 3D barato do grafite.
        _letra(tela, rng, x + 3, y + 3, w, h, sombra)
        _letra(tela, rng, x, y, w, h, cor)
        # Escorrido: tinta que desceu da letra ate quase o pe do muro.
        for _ in range(rng.randint(0, 2)):
            ex = int(x + rng.uniform(2, w))
            for ey in range(int(y + h), int(y + h + rng.uniform(4, 16))):
                tela.pinta(ex, ey, cor, 1)
        x += w + rng.uniform(1, 5)
        y += rng.uniform(-3, 3)
    _pichacao(tela, rng, 3)


def _concreto(tela, rng):
    for y in range(tela.h):
        for x in range(tela.w):
            n = rng.uniform(-8, 8) + 10 * math.sin(x * 0.09 + y * 0.02)
            tela.cor[y][x] = tuple(int(c + n) for c in CONCRETO)
            tela.dono[y][x] = 0


def _pichacao(tela, rng, quantas):
    """O rabisco preto de spray: traco fino em zigue-zague, sem contorno."""
    for _ in range(quantas):
        x = rng.uniform(4, tela.w - 30)
        y = rng.uniform(6, tela.h - 10)
        a = 0.0
        for _ in range(rng.randint(20, 40)):
            a += rng.uniform(-1.4, 1.4)
            x += math.cos(a) * 1.2 + 0.6
            y += math.sin(a) * 1.4
            tela.pinta(int(x), int(y), PRETO, 1)


def sujo(tela, rng):
    _concreto(tela, rng)
    _pichacao(tela, rng, 5)


def _sujeira(tela, rng):
    """O pe do muro escurece da chuva e da fuligem; manchas soltas pelo resto."""
    for y in range(tela.h):
        f = 1.0 - 0.32 * max(0.0, (y - tela.h * 0.72) / (tela.h * 0.28))
        for x in range(tela.w):
            c = tela.cor[y][x]
            g = f * (1.0 + rng.uniform(-0.04, 0.04))
            tela.cor[y][x] = tuple(max(0, min(255, int(v * g))) for v in c)


def murais(rng):
    w, h = PAINEL
    largura, altura = w * GRADE[0], h * GRADE[1]
    pixels = [0] * (largura * altura * 3)
    pintores = {
        "tropical": tropical,
        "bicho": bicho,
        "rosto": rosto,
        "onda": onda,
        "grafite": grafite,
        "sujo": sujo,
    }
    for i, tipo in enumerate(PAINEIS):
        tela = Tela(w, h, CONCRETO)
        pintores[tipo](tela, rng)
        tela.contorno()
        _sujeira(tela, rng)
        ox = (i % GRADE[0]) * w
        oy = (i // GRADE[0]) * h
        for y in range(h):
            for x in range(w):
                k = ((oy + y) * largura + ox + x) * 3
                pixels[k : k + 3] = tela.cor[y][x]
    return largura, altura, pixels


# --- Concreto e cerca ----------------------------------------------------------

CONCRETO_TAMANHO = 64


def concreto(rng):
    """Concreto de obra publica: cinza com mancha grande de umidade e o verde do
    limo escorrendo, como a barriga do tabuleiro da `03`. Mancha de metro, e nao
    grao: e visto de baixo, passando rapido."""
    n = CONCRETO_TAMANHO
    manchas = [(rng.uniform(0, n), rng.uniform(0, n), rng.uniform(6, 14)) for _ in range(9)]
    pixels = []
    for y in range(n):
        for x in range(n):
            v = 150 + rng.uniform(-6, 6)
            limo = 0.0
            for mx, my, r in manchas:
                # Distancia que da a volta: o tile emenda nas bordas.
                dx = min(abs(x - mx), n - abs(x - mx))
                dy = min(abs(y - my), n - abs(y - my))
                d = math.sqrt(dx * dx + dy * dy)
                if d < r:
                    limo = max(limo, 1.0 - d / r)
            v -= 26 * limo
            # Escorrido vertical: a fuligem desce reta.
            v -= 8 * (0.5 + 0.5 * math.sin(x * 0.7 + math.sin(x * 0.31) * 3))
            r_, g_, b_ = v, v - 2 + limo * 10, v - 8
            pixels += [max(0, min(255, int(c))) for c in (r_, g_, b_)]
    return n, n, pixels


CERCA_TAMANHO = 32


def cerca():
    """Alambrado: losango de arame a 45 graus, 4 losangos por metro. O furo e
    transparente; de longe o mipmap media arame e furo e a tela vira o veu
    cinza da `04`, que e o que ela e a 128 km/h."""
    n = CERCA_TAMANHO
    passo = n // 4
    pixels = []
    for y in range(n):
        for x in range(n):
            arame = (x + y) % passo == 0 or (x - y) % passo == 0
            pixels += [170, 174, 170, 235] if arame else [120, 124, 120, 0]
    return n, n, pixels


def main():
    rng = random.Random(SEMENTE)
    w, h, px = murais(rng)
    grava(os.path.join(PASTA, "murais_albedo.png"), w, h, px)
    print("murais: %dx%d, %d paineis" % (w, h, len(PAINEIS)))
    w, h, px = concreto(rng)
    grava(os.path.join(PASTA, "concreto_albedo.png"), w, h, px)
    w, h, px = cerca()
    grava(os.path.join(PASTA, "cerca_albedo.png"), w, h, px, canais=4)
    print("concreto e cerca em %s" % PASTA)


main()
