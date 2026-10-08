"""Gerador da Honda XRE 300 e de quem pilota, na mesma arvore de nos da CG.

Roda dentro do Blender (5.2+), como o `arte/entregador.py`:

    blender --background --factory-startup --python arte/xre300.py

Salva `arte/xre300.blend` e exporta `assets/entregador/xre300.glb`. As
texturas sao as da CG, regravadas iguais: a paleta e uma so.

A XRE e a outra moto da entrega brasileira: a de quem roda na rua esburacada,
na periferia e na estrada de terra do fim da rota. Do lado da CG ela le
diferente ja de longe, e e isso que justifica um segundo modelo: alta, roda
dianteira aro 21 bem maior que a traseira, paralama alto longe do pneu,
mascara com bolha em cima do farol, banco reto e comprido e protetor de mao
no guidao largo.

Medidas da ficha da XRE 300: entre eixos de 1,417 m, banco a 0,86 m, pneus
90/90-21 e 120/80-18, caster de 27,5 graus, 2,17 m de comprimento. O resto e o
que a camera de tras enxerga a 6 m, com a mesma regra da CG: silhueta e massa
de cor, nada de detalhe que nao sobreviva a 100 px de altura.

**A arvore e a mesma da CG, no por no** (ver o topo do `arte/entregador.py`),
e e esse o contrato com o `entregador.gd`: tudo o que ele anima - roda, garfo,
balanca, mola, maos e pes no IK, o tombo e o voo - acha o mesmo nome aqui. As
diferencas que importam para a animacao:

- **Roda de raio diferente na frente e atras.** O ator le o raio e a altura do
  eixo de cada roda do proprio modelo, e nao de uma constante.
- **Monoamortecedor Pro-Link, e nao dois.** O `Amortecedor_E` e a `Mola_E`
  sao o mono, no meio da moto; o `_D` sao vazios no mesmo lugar, para o ator
  achar os quatro nos que ele espera sem uma excecao por modelo.
- **Paralama dianteiro na mesa, e nao na bainha.** Na XRE ele nao acompanha a
  roda: fica alto, e a roda sobe e desce por baixo dele. E filho da `Direcao`.
"""

import math
import os
import sys

from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import entregador as e  # noqa: E402
from entregador import Peca, vazio  # noqa: E402

# --- Ficha -------------------------------------------------------------------
#
# O entre eixos fica em 1,42 m, simetrico em volta da origem, que e o centro
# da moto no chao. A moto inteira tem 2,15 m: cabe na caixa de 2,1 m do corpo
# fisico com 2 cm de pneu de cada lado, que de tras ninguem mede.

RAIO_FRENTE = 0.35  # 90/90-21: 533 mm de aro e 81 mm de pneu de cada lado
RAIO_TRAS = 0.325  # 120/80-18
EIXO_DIANTEIRO = Vector((0.0, 0.71, RAIO_FRENTE))
EIXO_TRASEIRO = Vector((0.0, -0.71, RAIO_TRAS))

CASTER = math.radians(27.5)
GARFO = 0.80
DIR_GARFO = Vector((0.0, math.sin(CASTER), -math.cos(CASTER)))
CABECA_GARFO = EIXO_DIANTEIRO - DIR_GARFO * GARFO
GARFO_X = 0.095

# Guidao largo e alto, de trilha: 0,83 m de ponta a ponta. A pegada fica a
# frente da mesa, e nao atras como na CG - o piloto da XRE vai mais aberto e
# com o cotovelo para fora.
MANOPLA = Vector((0.35, 0.26, 1.19))

BALANCA_PIVO = Vector((0.0, -0.14, 0.50))
# O mono: preso embaixo do banco, descendo quase reto ate o link em cima da
# balanca. Escondido pelas tampas laterais, aparece no vao acima do motor.
MONO_CIMA = Vector((0.0, -0.20, 0.84))
MONO_BAIXO = Vector((0.0, -0.33, 0.50))
PEDALEIRA = Vector((0.20, -0.04, 0.40))

# O piloto: banco 6 cm mais alto que o da CG, e o torso quase reto - 10 graus,
# que e o que se faz sentado em moto de trilha com o guidao no peito.
QUADRIL = Vector((0.0, -0.20, 1.00))
INCLINACAO_TORSO = math.radians(10.0)


def no_garfo(d: float, x: float = 0.0) -> Vector:
    """Ponto do garfo a `d` metros da mesa de cima, descendo para o eixo."""
    return CABECA_GARFO + DIR_GARFO * d + Vector((x, 0.0, 0.0))


def roda_raiada(p: Peca, centro, raio, largura, altura, raios=18) -> None:
    """Roda raiada: pneu de trilha, aro fino e os raios cruzados.

    Raio de arame de verdade, e nao disco: e o vazado que gira, e roda raiada
    e metade da cara de moto de trilha. Os raios saem alternados das duas
    flanges do cubo, como na roda de verdade - de tras isso le como a roda em
    "V", e nao como uma tabua.
    """
    c = Vector(centro)
    # Expoente menor que o da CG: o pneu de cravo tem ombro quadrado.
    p.anel(c, raio, largura, altura, "pneu", expoente=3.4)
    aro = raio - altura + 0.008
    p.anel(c, aro, largura * 0.62, 0.02, "aro", perfil=4, expoente=4.0)
    x = Vector((0.06, 0.0, 0.0))
    p.tubo(c - x, c + x, 0.04, 0.04, "motor", lados=10)
    for k in range(raios):
        a = math.tau * k / raios
        lado = 1.0 if k % 2 else -1.0
        cubo = c + Vector((lado * 0.045, math.cos(a + 0.35) * 0.035, math.sin(a + 0.35) * 0.035))
        ponta = c + Vector((0.0, math.cos(a), math.sin(a))) * (aro - 0.012)
        p.tubo(cubo, ponta, 0.0045, 0.0045, "metal", lados=3)


def corpo(material, colecao, pai) -> None:
    c = Peca("Moto_Corpo", (0.0, 0.0, 0.0))

    # Quadro de berco semiduplo: o tubo de baixo desce da coluna, passa na
    # frente do motor e se abre em dois por baixo dele. E o que diz "trilha"
    # de lado: o motor fica pendurado DENTRO do quadro, e nao embaixo dele.
    c.tubo(no_garfo(-0.03), no_garfo(0.17), 0.035, 0.035, "preto", lados=8)
    c.caminho([no_garfo(0.04), (0.0, 0.05, 0.94), (0.0, -0.14, 0.84), (0.0, -0.16, 0.55)], 0.028, "preto")
    c.caminho([no_garfo(0.15), (0.0, 0.32, 0.62), (0.0, 0.28, 0.40)], 0.024, "preto")
    for lado in (-1.0, 1.0):
        c.caminho(
            [(0.0, 0.28, 0.40), (lado * 0.07, 0.20, 0.30), (lado * 0.07, -0.08, 0.30), (lado * 0.08, -0.16, 0.48)],
            0.02,
            "preto",
        )
        # Subquadro do banco, ate a rabeta.
        c.caminho(
            [(lado * 0.06, -0.12, 0.82), (lado * 0.09, -0.50, 0.84), (lado * 0.07, -0.90, 0.86)],
            0.014,
            "preto",
        )
        c.barra((lado * 0.07, -0.16, 0.52), (lado * 0.08, -0.50, 0.82), 0.02, 0.02, "preto")
        c.caixa((lado * 0.105, -0.14, 0.50), (0.02, 0.12, 0.15), "preto")  # placa do pivo
    # Suporte de cima do mono, no cruzamento do subquadro.
    c.caixa(MONO_CIMA + Vector((0.0, 0.0, 0.02)), (0.10, 0.05, 0.04), "preto")

    # Motor: monocilindro de 291 cc arrefecido a ar, quase vertical, alto do
    # chao (25 cm de vao livre) e com o protetor de carter embaixo.
    c.casco(
        [
            (0.21, 0.46, 0.15, 0.14),
            (0.16, 0.46, 0.24, 0.24),
            (-0.10, 0.46, 0.24, 0.24),
            (-0.15, 0.47, 0.17, 0.18),
        ],
        "motor",
        expoente=3.0,
        gomos=10,
    )
    c.tubo((-0.12, 0.02, 0.46), (-0.155, 0.02, 0.46), 0.10, 0.095, "motor", lados=12)
    c.tubo((0.12, 0.08, 0.47), (0.155, 0.08, 0.47), 0.105, 0.10, "motor", lados=12)
    c.caixa((-0.13, -0.08, 0.49), (0.04, 0.10, 0.10), "preto")  # tampa do pinhao
    eixo_cil = Vector((0.0, math.sin(math.radians(10.0)), math.cos(math.radians(10.0))))
    base_cil = Vector((0.0, 0.14, 0.57))
    c.tubo(base_cil, base_cil + eixo_cil * 0.22, 0.06, 0.057, "preto", lados=8)
    for k in range(6):
        c.caixa(base_cil + eixo_cil * (0.035 + 0.028 * k), (0.20, 0.17, 0.009), "aleta", rot_x=-10.0)
    c.caixa(base_cil + eixo_cil * 0.235, (0.20, 0.17, 0.06), "motor", rot_x=-10.0)
    c.caixa(base_cil + eixo_cil * 0.285, (0.14, 0.12, 0.05), "preto", rot_x=-10.0)
    c.caixa((0.0, 0.02, 0.74), (0.09, 0.09, 0.07), "preto")  # corpo de borboleta
    # Protetor de carter: a placa por baixo do motor, que e o que bate na pedra.
    c.caixa((0.0, 0.10, 0.31), (0.20, 0.36, 0.015), "metal", rot_x=-6.0)
    c.caixa((0.0, 0.29, 0.37), (0.18, 0.10, 0.015), "metal", rot_x=-55.0)
    # Pedais: cambio na esquerda, freio na direita.
    c.barra((-0.16, -0.03, 0.42), (-0.17, 0.13, 0.39), 0.02, 0.015, "preto")
    c.barra((0.16, -0.03, 0.40), (0.16, 0.12, 0.37), 0.02, 0.015, "preto")

    # Pedaleiras do piloto (de trilha, de metal serrilhado) e da garupa.
    for lado in (-1.0, 1.0):
        p = Vector((lado * PEDALEIRA.x, PEDALEIRA.y, PEDALEIRA.z))
        c.caixa(p, (0.10, 0.05, 0.025), "metal")
        c.barra(p + Vector((-lado * 0.05, 0.0, 0.0)), (lado * 0.10, -0.08, 0.47), 0.02, 0.02, "preto")
        c.caixa((lado * 0.17, -0.46, 0.53), (0.07, 0.03, 0.025), "borracha")
        c.barra((lado * 0.13, -0.46, 0.53), (lado * 0.09, -0.36, 0.70), 0.02, 0.02, "preto")

    # Escapamento do lado direito: o cano desce do cabecote, contorna o motor
    # por fora e sobe para o silencioso alto, colado na rabeta - na XRE ele
    # fica acima da pedaleira da garupa, longe da lama.
    c.caminho(
        [
            (0.03, 0.28, 0.68),
            (0.08, 0.32, 0.52),
            (0.14, 0.22, 0.36),
            (0.17, 0.00, 0.36),
            (0.18, -0.26, 0.58),
        ],
        0.022,
        "metal",
    )
    c.tubo((0.18, -0.24, 0.57), (0.19, -0.78, 0.72), 0.058, 0.05, "metal", lados=10)
    c.tubo((0.19, -0.78, 0.72), (0.192, -0.84, 0.74), 0.032, 0.032, "cromado", lados=8)
    c.barra((0.235, -0.30, 0.62), (0.245, -0.62, 0.70), 0.012, 0.07, "preto")

    # Tanque: estreito em cima, entre os joelhos, e as "asas" na cor da moto
    # abrindo para a frente e para baixo. A asa e a peca que separa XRE de CG
    # vista de tras: ela alarga a moto na altura do joelho como o protetor de
    # perna da CG, so que em cor.
    c.casco(
        [
            (-0.14, 0.95, 0.16, 0.06),
            (-0.08, 0.96, 0.24, 0.12),
            (0.04, 0.98, 0.28, 0.18),
            (0.18, 0.99, 0.30, 0.20),
            (0.30, 0.985, 0.24, 0.16),
            (0.36, 0.98, 0.14, 0.10),
        ],
        "pintura",
        expoente=2.8,
        gomos=14,
    )
    c.tubo((0.0, 0.16, 1.085), (0.0, 0.16, 1.10), 0.038, 0.034, "preto", lados=10)
    for lado in (-1.0, 1.0):
        # A asa: placa grossa, inclinada para fora, do tanque ate a frente do
        # motor. Com o grafismo claro em cima, que diz "XRE" sem dizer.
        c.casco(
            [
                (0.02, 0.86, 0.04, 0.16),
                (0.16, 0.83, 0.05, 0.26),
                (0.30, 0.80, 0.05, 0.28),
                (0.38, 0.79, 0.03, 0.18),
            ],
            "pintura",
            expoente=3.5,
            gomos=8,
            matriz=_lateral(lado, 0.15),
        )
        c.caixa((lado * 0.175, 0.22, 0.86), (0.012, 0.22, 0.04), "grafismo", rot_x=-14.0)
        c.caixa((lado * 0.168, 0.10, 0.76), (0.012, 0.16, 0.05), "pintura_escura", rot_x=-14.0)

    # Banco reto e comprido, alto e estreito: o degrau da CG nao existe, e o
    # piloto senta onde quiser. Preto, como sai de fabrica.
    c.casco(
        [
            (-0.88, 0.905, 0.14, 0.04),
            (-0.80, 0.905, 0.21, 0.07),
            (-0.55, 0.895, 0.25, 0.08),
            (-0.30, 0.895, 0.28, 0.08),
            (-0.10, 0.92, 0.25, 0.08),
            (0.02, 0.96, 0.17, 0.06),
            (0.06, 0.985, 0.10, 0.03),
        ],
        "preto",
        expoente=3.2,
    )

    # Tampas laterais embaixo do banco, em branco de numero de prova, e a
    # rabeta fina e alta na cor da moto, com a lanterna.
    for lado in (-1.0, 1.0):
        c.caixa((lado * 0.13, -0.32, 0.79), (0.02, 0.34, 0.13), "grafismo", rot_x=-6.0)
        c.caixa((lado * 0.122, -0.30, 0.70), (0.02, 0.22, 0.06), "pintura_escura", rot_x=-6.0)
    c.casco(
        [
            (-1.04, 0.875, 0.06, 0.03),
            (-0.98, 0.865, 0.12, 0.06),
            (-0.80, 0.855, 0.20, 0.07),
            (-0.60, 0.845, 0.23, 0.07),
        ],
        "pintura",
        expoente=3.0,
        gomos=10,
    )
    c.caixa((0.0, -1.01, 0.855), (0.08, 0.03, 0.04), "lanterna", rot_x=20.0)
    # Caixa do filtro de ar, no vao entre as tampas.
    c.caixa((0.0, -0.36, 0.70), (0.20, 0.24, 0.13), "preto")

    # Bagageiro: na XRE de entrega e acessorio de primeira semana. A grade fica
    # em cima da rabeta, na altura do banco, e e o que a bag termica do piloto
    # tapa de tras.
    for lado in (-1.0, 1.0):
        c.caminho(
            [(lado * 0.11, -0.52, 0.88), (lado * 0.12, -0.58, 0.93), (lado * 0.10, -0.98, 0.93)],
            0.011,
            "preto",
        )
    c.tubo((-0.10, -0.98, 0.93), (0.10, -0.98, 0.93), 0.011, 0.011, "preto")
    c.caixa((0.0, -0.78, 0.93), (0.20, 0.34, 0.012), "preto")

    # Paralama traseiro curto e o suporte da placa pendurado, com os piscas.
    c.paralama(EIXO_TRASEIRO, RAIO_TRAS + 0.10, 0.12, 105.0, 140.0, "preto")
    c.caminho([(0.0, -0.96, 0.82), (0.0, -1.06, 0.70)], 0.015, "preto")
    c.caixa((0.0, -1.07, 0.63), (0.20, 0.012, 0.13), "placa", rot_x=-12.0)
    for lado in (-1.0, 1.0):
        c.tubo((lado * 0.04, -1.00, 0.80), (lado * 0.14, -1.01, 0.80), 0.008, 0.008, "preto", lados=4)
        c.caixa((lado * 0.165, -1.015, 0.80), (0.05, 0.06, 0.035), "pisca")

    c.objeto(material, colecao, pai)


def _lateral(lado, x):
    """Leva a asa para o lado `lado`, a `x` metros do meio."""
    return Matrix.Translation(Vector((lado * x, 0.0, 0.0)))


def direcao(material, colecao, pai):
    """Mesa, tubos, mascara com bolha, paralama alto, guidao e protetores."""
    d = Peca("Direcao", CABECA_GARFO)
    for lado in (-1.0, 1.0):
        # Tubo cromado comprido: o garfo de 245 mm de curso, e ate dentro da
        # bainha com ela esticada.
        d.tubo(no_garfo(-0.03, lado * GARFO_X), no_garfo(0.50, lado * GARFO_X), 0.019, 0.019, "cromado", lados=8)
    d.caixa(no_garfo(0.0), (0.27, 0.08, 0.035), "preto", rot_x=27.5)  # mesa de cima
    d.caixa(no_garfo(0.17), (0.27, 0.08, 0.04), "preto", rot_x=27.5)  # mesa de baixo

    # Paralama alto, preso na mesa de baixo: a lamina comprida na cor da moto
    # passando 14 cm acima do pneu, que a roda sobe e desce por baixo.
    d.casco(
        [
            (0.30, 0.86, 0.10, 0.02),
            (0.44, 0.88, 0.15, 0.03),
            (0.66, 0.875, 0.16, 0.03),
            (0.84, 0.855, 0.14, 0.025),
            (0.95, 0.81, 0.09, 0.02),
        ],
        "pintura",
        expoente=2.4,
        gomos=10,
    )

    # Mascara do farol: o bico alto em volta do farol, a bolha fume em cima e
    # o painel escondido atras dela.
    d.casco(
        [
            (0.44, 1.05, 0.22, 0.26),
            (0.52, 1.04, 0.24, 0.24),
            (0.58, 1.02, 0.18, 0.18),
        ],
        "pintura",
        expoente=3.2,
        gomos=10,
    )
    d.caixa((0.0, 0.585, 1.02), (0.13, 0.012, 0.10), "farol", rot_x=12.0)
    d.caixa((0.0, 0.52, 1.20), (0.22, 0.012, 0.16), "viseira", rot_x=-28.0)  # bolha
    d.caixa((0.0, 0.44, 1.15), (0.16, 0.08, 0.05), "painel", rot_x=-20.0)
    for lado in (-1.0, 1.0):
        d.tubo((lado * 0.11, 0.52, 0.98), (lado * 0.18, 0.53, 0.98), 0.008, 0.008, "preto", lados=4)
        d.caixa((lado * 0.205, 0.54, 0.98), (0.05, 0.06, 0.035), "pisca")

    # Guidao: tubo largo e quase reto, nas torres em cima da mesa.
    m = MANOPLA
    d.caminho(
        [
            (-m.x - 0.06, m.y, m.z),
            (-0.24, 0.29, 1.17),
            (-0.08, 0.32, 1.14),
            (0.08, 0.32, 1.14),
            (0.24, 0.29, 1.17),
            (m.x + 0.06, m.y, m.z),
        ],
        0.012,
        "preto",
    )
    for lado in (-1.0, 1.0):
        d.tubo(no_garfo(-0.02, lado * 0.04), (lado * 0.04, 0.32, 1.14), 0.016, 0.016, "preto", lados=6)  # torre
        d.tubo((lado * (m.x - 0.065), m.y + 0.01, m.z), (lado * (m.x + 0.06), m.y - 0.01, m.z), 0.018, 0.018, "borracha", lados=8)
        d.caixa((lado * 0.25, 0.28, 1.19), (0.045, 0.05, 0.045), "preto")  # punho de comando
        d.barra((lado * 0.28, 0.32, 1.20), (lado * 0.40, 0.32, 1.19), 0.012, 0.012, "metal")  # manete
        # Protetor de mao: a concha preta na frente da manopla. De tras ela
        # alarga o guidao e le como "moto de trilha" antes de qualquer outra
        # peca.
        d.caminho(
            [(lado * 0.24, 0.31, 1.17), (lado * 0.30, 0.37, 1.20), (lado * 0.42, 0.34, 1.20), (lado * 0.44, 0.25, 1.19)],
            0.012,
            "preto",
        )
        d.caixa((lado * 0.36, 0.36, 1.21), (0.12, 0.012, 0.07), "preto", rot_x=-10.0)
        # Retrovisor de haste comprida.
        d.tubo((lado * 0.23, 0.28, 1.20), (lado * 0.30, 0.25, 1.42), 0.007, 0.007, "preto", lados=4)
        d.caixa((lado * 0.32, 0.25, 1.44), (0.10, 0.025, 0.065), "preto")
        d.caixa((lado * 0.32, 0.236, 1.44), (0.08, 0.004, 0.05), "cromado")
    return d.objeto(material, colecao, pai)


def garfo(material, colecao, pai):
    """As bainhas e a pinca: o que sobe e desce com a roda."""
    g = Peca("Garfo", EIXO_DIANTEIRO)
    for lado in (-1.0, 1.0):
        g.tubo(no_garfo(0.42, lado * GARFO_X), no_garfo(0.83, lado * GARFO_X), 0.027, 0.025, "motor", lados=8)
        g.tubo(no_garfo(0.415, lado * GARFO_X), no_garfo(0.425, lado * GARFO_X), 0.029, 0.029, "preto", lados=8)
    # Pinca do disco, atras da bainha esquerda.
    g.caixa(EIXO_DIANTEIRO + Vector((-0.095, -0.09, 0.09)), (0.04, 0.09, 0.07), "preto")
    g.tubo(EIXO_DIANTEIRO + Vector((-0.12, 0.0, 0.0)), EIXO_DIANTEIRO + Vector((0.12, 0.0, 0.0)), 0.012, 0.012, "metal")
    return g.objeto(material, colecao, pai)


def balanca(material, colecao, pai):
    """Balanca de aluminio, corrente na esquerda e o link do mono em cima."""
    b = Peca("Balanca", BALANCA_PIVO)
    for lado in (-1.0, 1.0):
        b.barra(
            BALANCA_PIVO + Vector((lado * 0.10, 0.0, 0.0)),
            EIXO_TRASEIRO + Vector((lado * 0.10, 0.0, 0.0)),
            0.03,
            0.06,
            "aro",
        )
        b.caixa(EIXO_TRASEIRO + Vector((lado * 0.105, -0.02, 0.0)), (0.035, 0.08, 0.035), "metal")
    b.tubo(BALANCA_PIVO + Vector((-0.12, 0.0, 0.0)), BALANCA_PIVO + Vector((0.12, 0.0, 0.0)), 0.025, 0.025, "preto", lados=8)
    # A ponte que segura o pe do mono.
    b.caixa((0.0, MONO_BAIXO.y, MONO_BAIXO.z - 0.02), (0.20, 0.06, 0.04), "aro")
    x = -0.125
    for topo in (1.0, -1.0):
        b.barra(
            (x, -0.06, 0.50 + 0.045 * topo),
            (x, EIXO_TRASEIRO.y, EIXO_TRASEIRO.z + 0.10 * topo),
            0.012,
            0.012,
            "preto",
        )
    b.barra((x - 0.005, -0.10, 0.56), (x - 0.005, -0.58, 0.47), 0.03, 0.035, "preto")
    return b.objeto(material, colecao, pai)


def moto(material, colecao, raiz) -> None:
    base = vazio("Moto", (0.0, 0.0, 0.0), colecao, raiz)
    suspenso = vazio("Suspenso", (0.0, 0.0, 0.0), colecao, base)
    corpo(material, colecao, suspenso)

    obj_direcao = direcao(material, colecao, suspenso)
    obj_garfo = garfo(material, colecao, obj_direcao)
    roda_frente = Peca("Roda_Dianteira", EIXO_DIANTEIRO)
    roda_raiada(roda_frente, EIXO_DIANTEIRO, RAIO_FRENTE, 0.085, 0.085)
    # Disco ondulado de 256 mm do lado esquerdo.
    x = Vector((0.004, 0.0, 0.0))
    disco = EIXO_DIANTEIRO + Vector((-0.075, 0.0, 0.0))
    roda_frente.tubo(disco - x, disco + x, 0.128, 0.128, "cromado", lados=12)
    roda_frente.objeto(material, colecao, obj_garfo)

    obj_balanca = balanca(material, colecao, suspenso)
    roda_tras = Peca("Roda_Traseira", EIXO_TRASEIRO)
    roda_raiada(roda_tras, EIXO_TRASEIRO, RAIO_TRAS, 0.12, 0.095)
    # Disco atras na direita, coroa na esquerda.
    roda_tras.tubo(EIXO_TRASEIRO + Vector((0.075, 0.0, 0.0)), EIXO_TRASEIRO + Vector((0.083, 0.0, 0.0)), 0.11, 0.11, "cromado", lados=12)
    roda_tras.tubo(EIXO_TRASEIRO + Vector((-0.13, 0.0, 0.0)), EIXO_TRASEIRO + Vector((-0.12, 0.0, 0.0)), 0.10, 0.10, "preto", lados=16)
    roda_tras.objeto(material, colecao, obj_balanca)

    # O mono e o par `_E`; o `_D` e vazio no mesmo lugar (ver o topo).
    e.amortecedor(material, colecao, suspenso, obj_balanca, "E", MONO_CIMA, MONO_BAIXO, mola=(0.042, 6, 0.008))
    vazio("Amortecedor_D", MONO_CIMA, colecao, suspenso)
    vazio("Mola_D", MONO_BAIXO, colecao, obj_balanca)


def monta(mat, colecao, raiz) -> None:
    moto(mat, colecao, raiz)
    e.piloto(
        mat,
        colecao,
        raiz,
        QUADRIL=QUADRIL,
        INCLINACAO_TORSO=INCLINACAO_TORSO,
        MANOPLA=MANOPLA,
        PEDALEIRA=PEDALEIRA,
    )


e.gera("xre300", monta)
