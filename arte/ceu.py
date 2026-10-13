"""Gerador das nuvens do ceu: `assets/visual/ceu_nuvens.png`.

Roda com o Python do sistema, sem dependencia:

    python arte/ceu.py

Gerado, e nao pintado, pelo mesmo motivo do LUT e do chao: a receita em
numero da para revisar em diff, e o sorteio tem semente.

O que as referencias tem: cumulo branco, gordo, de borda dura e base azulada,
numa faixa baixa logo acima dos predios - e em banda de cor visivel, que e o
sotaque de epoca do DIRECAO_VISUAL.md. Dai as tres regras daqui:

1. **Borda dura.** A cobertura (alfa) e 0 ou 1, sem degrade: nuvem fofa de
   borda lavada e o ceu de foto que o jogo nao quer.
2. **Tom em banda, e a banda ja dithered.** Quatro tons, da base azulada ao
   topo branco, e a passagem de um para o outro e um Bayer 4x4 na textura.
   A celula do Bayer tem 2x2 texels: a camera de perseguicao ve ~7 pixels por
   grau e a textura tem 5,7 texels por grau, entao um texel e quase um pixel
   da tela e o filtro linear o borraria em cinza. Com 2x2 a trama aparece, e
   como a textura e AMPLIADA na tela, e nunca reduzida, ela nao cintila com a
   camera girando - cintilar e o que textura reduzida faz.
3. **Faixa baixa.** A camera da V04 ve do horizonte ate ~20 graus, e entre
   predios a fresta de ceu e quase so a de baixo. Nuvem a 40 graus ninguem ve.

Formato: 2048x1024 equirretangular, o que o `ProceduralSkyMaterial.sky_cover`
amostra (`SKY_COORDS`): x e a longitude, y = 0 e o zenite, y = 512 o
horizonte. O Godot SOMA a cobertura ao gradiente (`sky += rgb * a`), e nao
pinta por cima. Por isso o rgb gravado aqui e a diferenca entre o tom que a
nuvem quer ter e o ceu daquela altura, e o ceu daquela altura e recalculado
aqui com as cores do `world.gd::_build_environment`. Mudou a cor do ceu la,
regere isto.
"""

import math
import os
import random

from _png import grava

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SAIDA = os.path.join(RAIZ, "assets", "visual", "ceu_nuvens.png")

LARGURA, ALTURA = 2048, 1024
SEMENTE = 20261012

# As cores do ceu, as mesmas do `world.gd`, e a curva padrao do
# ProceduralSkyMaterial (`sky_curve` = 0,15). Em sRGB, como la.
CEU_TOPO = (0.16, 0.38, 0.82)
CEU_HORIZONTE = (0.62, 0.74, 0.88)
CEU_CURVA = 0.15

# Os quatro tons da nuvem, em sRGB, do pe ao topo. A base e azulada porque e
# o ceu refletido por baixo; o topo passa um pouco do branco (o tonemap
# comprime) e fica abaixo do limiar 2,2 do glow, que e so do que e luz.
TONS = (
    (0.70, 0.78, 0.92),
    (0.84, 0.89, 0.97),
    (0.95, 0.97, 1.00),
    (1.06, 1.06, 1.04),
)
# Onde um tom vira o outro, no tom continuo de 0 a 1.
CORTES = (0.30, 0.52, 0.74)
# Largura da trama na passagem: com 0 a banda e seca; com muito, a nuvem vira
# chuvisco inteira.
TRAMA = 0.10

# A faixa das nuvens, em graus acima do horizonte. A base de cada uma cai
# entre os dois; o topo, pela altura dela. Comecou em 1,5-7 e a prova mostrou
# nuvem so de canto: na rua, o predio de 4-5 andares cobre ate ~8 graus, e a
# nuvem tem de passar por cima do telhado para ser vista.
BASE_MIN, BASE_MAX = 4.0, 11.0
# Quantas nuvens grandes, e quantas pequenas soltas um pouco mais alto. Com
# essas contas a faixa baixa fica coberta pela metade: nos quatro quadros da
# prova sempre ha nuvem, e sempre ha ceu azul entre elas.
GRANDES = 20
PEQUENAS = 18

BAYER = (0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5)


def _linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def _srgb(c):
    c = max(c, 0.0)
    return c * 12.92 if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055


def _ceu(elevacao):
    """O gradiente do ProceduralSkyMaterial naquela altura, em linear."""
    c = elevacao / 90.0
    t = min(max(1.0 - (1.0 - c) ** (1.0 / CEU_CURVA), 0.0), 1.0)
    return tuple(
        _linear(h) + (_linear(z) - _linear(h)) * t for h, z in zip(CEU_HORIZONTE, CEU_TOPO)
    )


def _cumulo(rng, lon, base, largura, altura):
    """Bolhas de um cumulo: (lon, elevacao, raio) em graus.

    Uma fileira de bolhas grandes cortadas pela base reta, mais alta no meio,
    e por cima um punhado de bolhas menores na borda de cima - e o que da a
    couve-flor. A base reta e o que separa cumulo de bolinha de algodao.
    """
    bolhas = []
    n = max(3, int(largura / (altura * 0.7)))
    for i in range(n):
        f = (i + 0.5) / n
        perfil = math.sin(math.pi * f) ** 0.7
        r = altura * (0.35 + 0.45 * perfil) * rng.uniform(0.85, 1.15)
        x = lon + (f - 0.5) * largura
        bolhas.append((x, base + r * 0.55, r))
    for _ in range(n * 2):
        x0, e0, r0 = rng.choice(bolhas)
        a = rng.uniform(0.15, 0.85) * math.pi
        r = r0 * rng.uniform(0.3, 0.55)
        bolhas.append((x0 + math.cos(a) * r0 * 0.8, e0 + math.sin(a) * r0 * 0.8, r))
    return bolhas, base


def _nuvens(rng):
    # Longitude estratificada: uma fatia de ceu por nuvem grande, com folga.
    # Sorteada solta, metade delas se empilhava num lado e o outro ficava
    # vazio - e a nuvem empilhada vira uma parede com a base de uma riscando
    # o meio da outra.
    nuvens = []
    fatia = 360.0 / GRANDES
    for i in range(GRANDES):
        largura = min(rng.uniform(8.0, 22.0), fatia * 0.85)
        altura = largura * rng.uniform(0.38, 0.55)
        base = rng.uniform(BASE_MIN, BASE_MAX)
        lon = (i + rng.uniform(0.3, 0.7)) * fatia
        nuvens.append(_cumulo(rng, lon, base, largura, altura))
    for _ in range(PEQUENAS):
        largura = rng.uniform(3.0, 8.0)
        base = rng.uniform(13.0, 21.0)
        nuvens.append(_cumulo(rng, rng.uniform(0, 360), base, largura, largura * 0.35))
    # As pequenas, mais altas, ficam ATRAS: desenhada por ultimo ganha, e a
    # pequena por cima cortava a grande com a base reta dela.
    return nuvens[GRANDES:] + nuvens[:GRANDES]


def main():
    rng = random.Random(SEMENTE)
    # Por texel: tom continuo (-1 = ceu limpo). Nuvem desenhada depois ganha
    # por cima, que e a mais perto na leitura de quem olha.
    tom = [-1.0] * (LARGURA * ALTURA)
    graus_por_texel = 360.0 / LARGURA
    for bolhas, base in _nuvens(rng):
        topo = max(e + r for _, e, r in bolhas)
        lon_min = min(x - r for x, _, r in bolhas)
        lon_max = max(x + r for x, _, r in bolhas)
        y0 = max(0, int((90.0 - topo) / graus_por_texel))
        y1 = min(ALTURA // 2, int((90.0 - base) / graus_por_texel) + 1)
        for y in range(y0, y1):
            elev = 90.0 - (y + 0.5) * graus_por_texel
            if elev < base:
                continue
            # Longitude encolhe com o cosseno da altura: perto do horizonte
            # quase nada, mas e o que deixa a bolha redonda e nao oval.
            esc = math.cos(math.radians(elev))
            for xi in range(int(lon_min / graus_por_texel), int(lon_max / graus_por_texel) + 1):
                lon = (xi + 0.5) * graus_por_texel
                melhor = None
                for bx, be, br in bolhas:
                    dx = (lon - bx) * esc
                    de = elev - be
                    d2 = dx * dx + de * de
                    if d2 < br * br:
                        # A normal da bolha mais por fora decide a luz: o
                        # alto de cada bolha clareia, o pe dela escurece.
                        ny = de / br
                        if melhor is None or ny > melhor:
                            melhor = ny
                if melhor is None:
                    continue
                altura_rel = (elev - base) / max(topo - base, 0.1)
                t = 0.55 * altura_rel + 0.45 * (0.5 + 0.5 * melhor)
                tom[y * LARGURA + xi % LARGURA] = min(max(t, 0.0), 1.0)

    tons_lin = [tuple(_linear(c) for c in tc) for tc in TONS]
    pixels = [0] * (LARGURA * ALTURA * 4)
    for y in range(ALTURA // 2):
        ceu = _ceu(90.0 - (y + 0.5) * graus_por_texel)
        for x in range(LARGURA):
            t = tom[y * LARGURA + x]
            if t < 0.0:
                continue
            limiar = (BAYER[((y // 2) % 4) * 4 + (x // 2) % 4] + 0.5) / 16.0 - 0.5
            t += limiar * TRAMA
            banda = sum(1 for c in CORTES if t >= c)
            k = (y * LARGURA + x) * 4
            pixels[k : k + 4] = [
                min(255, round(_srgb(alvo - fundo) * 255)) for alvo, fundo in zip(tons_lin[banda], ceu)
            ] + [255]
    grava(SAIDA, LARGURA, ALTURA, pixels, canais=4)
    # A faixa que a camera ve: do horizonte a 20 graus.
    y20 = int(70.0 / graus_por_texel)
    faixa = tom[y20 * LARGURA : (ALTURA // 2) * LARGURA]
    cobertas = sum(1 for t in faixa if t >= 0.0)
    print("nuvens: %s (%.0f%% de 0 a 20 graus coberto)" % (SAIDA, 100.0 * cobertas / len(faixa)))


main()
