"""Gerador da Honda PCX 160 e de quem pilota, na mesma arvore de nos da CG.

Roda dentro do Blender (5.2+), como o `arte/entregador.py`:

    blender --background --factory-startup --python arte/pcx160.py

Salva `arte/pcx160.blend` e exporta `assets/entregador/pcx160.glb`. As
texturas sao as da CG, regravadas iguais: a paleta e uma so.

A PCX e a scooter da entrega de app: automatica, economica, com o porta-treco
embaixo do banco e o assoalho onde vai a sacola que nao coube na bag. Do lado
da CG e da XRE ela le diferente ja de longe, e e isso que justifica um terceiro
modelo: roda pequena, a carenagem inteira na cor da moto, o escudo de frente
com o farol em V, o assoalho reto onde o pe descansa e o piloto sentado
reto, de joelho alto, sem tanque entre as pernas.

Medidas da ficha da PCX 160: entre eixos de 1,313 m, banco a 0,764 m, pneus
110/70-14 e 130/70-13, caster de 26,5 graus, 1,935 m de comprimento. O resto e
o que a camera de tras enxerga a 6 m, com a mesma regra da CG: silhueta e
massa de cor, nada de detalhe que nao sobreviva a 100 px de altura.

**A arvore e a mesma da CG, no por no** (ver o topo do `arte/entregador.py` e
do `arte/xre300.py`), e e esse o contrato com o `entregador.gd`. O que muda
de sentido em cada no, numa scooter:

- **A `Balanca` e o motor.** Scooter tem motor oscilante: motor, variador
  (CVT), filtro de ar e escapamento sao uma peca so, presa no quadro por um
  pivo na frente e carregando o eixo traseiro atras. Tudo isso balanca junto
  com a roda, e e por isso que o escapamento mora aqui e nao no corpo.
- **A `Pedaleira` e o assoalho.** O pe do piloto nao vai num pino: vai
  apoiado no piso, a frente do quadril. O IK nao sabe a diferenca.
- **O escudo e o farol sao do corpo, e nao da direcao.** Na PCX o farol fica
  na carenagem de frente, parada; o que esterca e so a capa do guidao com o
  painel.
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
# O entre eixos fica em 1,32 m, como o da CG, e nao 1,313: o
# `camera_garupa.gd` mede a distancia do cinegrafista a partir do eixo
# traseiro em 0,66 m, e 7 mm de diferenca nao valem um caso a parte.

RAIO_FRENTE = 0.255  # 110/70-14: 178 mm de aro e 77 mm de pneu
RAIO_TRAS = 0.256  # 130/70-13: 165 mm de aro e 91 mm de pneu
EIXO_DIANTEIRO = Vector((0.0, 0.66, RAIO_FRENTE))
EIXO_TRASEIRO = Vector((0.0, -0.66, RAIO_TRAS))

CASTER = math.radians(26.5)
GARFO = 0.72
DIR_GARFO = Vector((0.0, math.sin(CASTER), -math.cos(CASTER)))
CABECA_GARFO = EIXO_DIANTEIRO - DIR_GARFO * GARFO
# Pneu de 110 mm: a bainha a 8,5 cm do meio passa com 5 mm de folga.
GARFO_X = 0.085

# Guidao alto e perto do peito, embaixo da capa: e a pegada de quem anda
# sentado reto, com o cotovelo baixo. Perto de verdade: 3 cm mais para a frente
# e o braco estica inteiro, e com o guidao no batente a mao de fora solta da
# manopla.
MANOPLA = Vector((0.33, 0.19, 1.03))

# Pivo do motor oscilante, no quadro, logo atras do assoalho.
BALANCA_PIVO = Vector((0.0, -0.10, 0.36))
# Dois amortecedores, um em cada lado da roda: o da esquerda em cima da caixa
# do variador, o da direita no braco do motor. Deitados para a frente, como
# na PCX, com o pe atras do eixo.
AMORTECEDOR_CIMA = Vector((0.135, -0.56, 0.66))
AMORTECEDOR_BAIXO = Vector((0.135, -0.72, 0.31))
# Onde a bota apoia no assoalho. O piso fica 5 mm abaixo disto (a sola da bota
# do `piloto` passa da pedaleira esse tanto).
PEDALEIRA = Vector((0.165, 0.17, 0.305))
PISO = PEDALEIRA.z - 0.005

# O piloto: banco 4 cm mais baixo que o da CG e o torso a 4 graus, quase de
# pe - em scooter nao se deita atras do painel, se senta como numa cadeira.
QUADRIL = Vector((0.0, -0.22, 0.875))
INCLINACAO_TORSO = math.radians(4.0)


def no_garfo(d: float, x: float = 0.0) -> Vector:
    """Ponto do garfo a `d` metros da mesa de cima, descendo para o eixo."""
    return CABECA_GARFO + DIR_GARFO * d + Vector((x, 0.0, 0.0))


def corpo(material, colecao, pai) -> None:
    c = Peca("Moto_Corpo", (0.0, 0.0, 0.0))

    # Escudo de frente, de baixo para cima: a base estreita colada no
    # assoalho, o bico que se projeta na altura do farol e o topo que recua
    # para baixo da capa do guidao. E a massa de cor que diz "scooter" de
    # qualquer angulo, e o que esconde o garfo inteiro.
    c.casco(
        [
            (PISO, 0.30, 0.30, 0.14),
            (0.45, 0.33, 0.40, 0.20),
            (0.62, 0.38, 0.48, 0.28),
            (0.80, 0.42, 0.50, 0.32),
            (0.90, 0.41, 0.46, 0.30),
            (0.97, 0.37, 0.36, 0.20),
        ],
        "pintura",
        eixo="z",
        expoente=2.6,
        gomos=14,
    )
    # Farol em V: duas laminas de LED que descem para o meio do bico. O V e a
    # cara da PCX de frente, e e o que a camera de garupa ve passar.
    for lado in (-1.0, 1.0):
        c.tubo((lado * 0.02, 0.588, 0.80), (lado * 0.17, 0.555, 0.875), 0.024, 0.024, "farol", lados=4)
        c.tubo((lado * 0.05, 0.583, 0.85), (lado * 0.16, 0.555, 0.90), 0.008, 0.008, "farol", lados=4)
        c.caixa((lado * 0.215, 0.53, 0.84), (0.05, 0.05, 0.035), "pisca")
    # Bolha fume curta em cima do bico.
    c.caixa((0.0, 0.48, 1.02), (0.30, 0.012, 0.12), "viseira", rot_x=-35.0)

    # Assoalho: o piso de borracha dos dois lados e o tunel no meio, que na
    # PCX e alto (e ali dentro que passa o quadro). A saia preta embaixo
    # fecha a vista de lado.
    c.caixa((0.0, 0.08, PISO - 0.035), (0.42, 0.50, 0.07), "pintura")
    for lado in (-1.0, 1.0):
        c.caixa((lado * 0.15, 0.10, PISO), (0.12, 0.40, 0.008), "borracha")
    c.caixa((0.0, 0.07, 0.205), (0.36, 0.52, 0.07), "preto")
    c.casco(
        [
            (-0.12, 0.47, 0.13, 0.22),
            (0.05, 0.42, 0.15, 0.20),
            (0.22, 0.42, 0.13, 0.20),
            (0.30, 0.44, 0.10, 0.20),
        ],
        "pintura",
        expoente=2.4,
        gomos=10,
    )

    # Carenagem de baixo do banco, subindo para a rabeta: o volume que cobre
    # o motor e o porta-treco. Descola da roda de tras com folga para a mola
    # afundar 7 cm.
    c.casco(
        [
            (-0.10, 0.52, 0.30, 0.42),
            (-0.18, 0.585, 0.34, 0.30),
            (-0.40, 0.62, 0.36, 0.25),
            (-0.62, 0.69, 0.30, 0.20),
            (-0.86, 0.75, 0.20, 0.12),
            (-0.97, 0.775, 0.10, 0.06),
        ],
        "pintura",
        expoente=2.6,
        gomos=14,
    )
    # O friso preto na lateral, da frente do banco ate a rabeta: a linha que
    # parte a carenagem em duas e da a cara de PCX de lado.
    for lado in (-1.0, 1.0):
        c.caixa((lado * 0.172, -0.30, 0.60), (0.012, 0.36, 0.04), "pintura_escura", rot_x=8.0)
        c.caixa((lado * 0.16, -0.52, 0.66), (0.012, 0.20, 0.025), "grafismo", rot_x=12.0)
    c.caixa((0.0, -0.978, 0.765), (0.13, 0.025, 0.04), "lanterna", rot_x=15.0)

    # Banco de dois andares, o da garupa mais alto.
    c.casco(
        [
            (-0.08, 0.73, 0.20, 0.04),
            (-0.16, 0.745, 0.30, 0.06),
            (-0.38, 0.745, 0.34, 0.06),
            (-0.52, 0.775, 0.32, 0.07),
            (-0.74, 0.79, 0.28, 0.06),
            (-0.86, 0.795, 0.20, 0.04),
        ],
        "preto",
        expoente=3.0,
    )

    # Bagageiro: em PCX de entrega e o primeiro acessorio. A grade fica acima
    # da rabeta, onde a alca da garupa ja estaria.
    for lado in (-1.0, 1.0):
        c.caminho(
            [(lado * 0.12, -0.56, 0.78), (lado * 0.13, -0.62, 0.85), (lado * 0.11, -0.98, 0.86)],
            0.012,
            "preto",
        )
    c.tubo((-0.11, -0.98, 0.86), (0.11, -0.98, 0.86), 0.012, 0.012, "preto")
    c.caixa((0.0, -0.80, 0.86), (0.22, 0.30, 0.012), "preto")

    # Paralama de tras, suporte e placa pendurados embaixo da rabeta, e os
    # piscas na ponta.
    c.paralama(EIXO_TRASEIRO, RAIO_TRAS + 0.09, 0.14, 100.0, 150.0, "preto")
    c.caminho([(0.0, -0.92, 0.70), (0.0, -0.99, 0.58)], 0.015, "preto")
    c.caixa((0.0, -1.0, 0.52), (0.20, 0.012, 0.13), "placa", rot_x=-12.0)
    for lado in (-1.0, 1.0):
        c.caixa((lado * 0.10, -0.955, 0.735), (0.05, 0.05, 0.03), "pisca")

    # Suporte de cima dos amortecedores, preso no quadro por dentro da
    # carenagem.
    for lado in (-1.0, 1.0):
        cima = Vector((lado * AMORTECEDOR_CIMA.x, AMORTECEDOR_CIMA.y, AMORTECEDOR_CIMA.z))
        c.caixa(cima + Vector((-lado * 0.012, 0.0, 0.0)), (0.02, 0.05, 0.05), "preto")
        # A placa do pivo do motor, no fim do tunel.
        c.caixa((lado * 0.09, -0.10, 0.37), (0.02, 0.10, 0.12), "preto")

    c.objeto(material, colecao, pai)


def direcao(material, colecao, pai):
    """Tubos do garfo, a capa do guidao com o painel, manoplas e retrovisores."""
    d = Peca("Direcao", CABECA_GARFO)
    for lado in (-1.0, 1.0):
        # O tubo vai ate dentro da bainha: o escudo esconde o de cima, e com o
        # garfo esticado a bainha desce e o cromado nao pode aparecer solto.
        d.tubo(no_garfo(-0.03, lado * GARFO_X), no_garfo(0.42, lado * GARFO_X), 0.016, 0.016, "cromado", lados=8)
    d.caixa(no_garfo(0.0), (0.22, 0.07, 0.03), "preto", rot_x=26.5)  # mesa
    # Coluna da mesa ate o guidao, dentro da capa.
    d.tubo(no_garfo(-0.02), (0.0, 0.30, 1.0), 0.02, 0.02, "preto", lados=6)

    # Capa do guidao: a peca larga na cor da moto que vira com ele, com o
    # painel digital no meio. Esconde o tubo do guidao inteiro, so as pontas
    # saem dela.
    d.casco(
        [
            (0.15, 1.025, 0.22, 0.06),
            (0.22, 1.035, 0.52, 0.10),
            (0.33, 1.03, 0.50, 0.11),
            (0.40, 1.01, 0.26, 0.07),
        ],
        "pintura",
        expoente=2.8,
        gomos=12,
    )
    d.caixa((0.0, 0.27, 1.088), (0.20, 0.10, 0.012), "painel", rot_x=-18.0)
    d.caixa((0.0, 0.27, 1.08), (0.24, 0.13, 0.02), "preto", rot_x=-18.0)

    m = MANOPLA
    for lado in (-1.0, 1.0):
        d.tubo((lado * 0.24, m.y + 0.01, m.z), (lado * (m.x - 0.065), m.y, m.z), 0.012, 0.012, "preto", lados=6)
        d.tubo((lado * (m.x - 0.065), m.y, m.z), (lado * (m.x + 0.06), m.y - 0.01, m.z), 0.018, 0.018, "borracha", lados=8)
        d.caixa((lado * 0.25, m.y, m.z), (0.045, 0.05, 0.045), "preto")  # punho de comando
        # Scooter tem manete dos dois lados: freio na frente e freio atras.
        d.barra((lado * 0.27, m.y + 0.04, m.z + 0.01), (lado * 0.39, m.y + 0.04, m.z), 0.012, 0.012, "metal")
        # Retrovisor: sai da capa, alto e aberto.
        d.tubo((lado * 0.22, 0.25, 1.06), (lado * 0.29, 0.24, 1.26), 0.007, 0.007, "preto", lados=4)
        d.caixa((lado * 0.31, 0.24, 1.28), (0.12, 0.025, 0.07), "preto")
        d.caixa((lado * 0.31, 0.226, 1.28), (0.10, 0.004, 0.055), "cromado")
    return d.objeto(material, colecao, pai)


def garfo(material, colecao, pai):
    """As bainhas, o paralama e a pinca: o que sobe e desce com a roda."""
    g = Peca("Garfo", EIXO_DIANTEIRO)
    for lado in (-1.0, 1.0):
        g.tubo(no_garfo(0.36, lado * GARFO_X), no_garfo(0.75, lado * GARFO_X), 0.025, 0.024, "motor", lados=8)
        g.tubo(no_garfo(0.355, lado * GARFO_X), no_garfo(0.365, lado * GARFO_X), 0.027, 0.027, "preto", lados=8)
    # Paralama na cor da moto, colado no pneu: na PCX ele e da bainha e sobe
    # junto com a roda.
    g.paralama(EIXO_DIANTEIRO, RAIO_FRENTE + 0.03, 0.13, 40.0, 150.0, "pintura", gomos=4)
    g.caixa(EIXO_DIANTEIRO + Vector((-0.085, -0.07, 0.07)), (0.04, 0.08, 0.07), "preto")
    g.tubo(EIXO_DIANTEIRO + Vector((-0.11, 0.0, 0.0)), EIXO_DIANTEIRO + Vector((0.11, 0.0, 0.0)), 0.012, 0.012, "metal")
    return g.objeto(material, colecao, pai)


def balanca(material, colecao, pai):
    """O motor oscilante: bloco, cilindro, variador, filtro e escapamento."""
    b = Peca("Balanca", BALANCA_PIVO)
    b.tubo(BALANCA_PIVO + Vector((-0.11, 0.0, 0.0)), BALANCA_PIVO + Vector((0.11, 0.0, 0.0)), 0.025, 0.025, "preto", lados=8)
    # O link do pivo, que liga o quadro ao bloco.
    for lado in (-1.0, 1.0):
        b.barra(BALANCA_PIVO + Vector((lado * 0.07, 0.0, 0.0)), (lado * 0.07, -0.20, 0.30), 0.025, 0.04, "preto")

    # Bloco e cilindro deitado para a frente, embaixo do assoalho: o motor de
    # scooter fica baixo, e e por isso que de lado so se ve a tampa.
    b.casco(
        [
            (-0.14, 0.27, 0.14, 0.14),
            (-0.20, 0.27, 0.22, 0.20),
            (-0.40, 0.28, 0.22, 0.20),
            (-0.44, 0.29, 0.14, 0.14),
        ],
        "motor",
        expoente=3.0,
        gomos=10,
    )
    b.tubo((0.0, -0.14, 0.26), (0.0, 0.02, 0.22), 0.06, 0.055, "preto", lados=8)
    for k in range(4):
        b.caixa((0.0, -0.11 + 0.035 * k, 0.25 - 0.009 * k), (0.15, 0.009, 0.15), "aleta", rot_x=-14.0)

    # Caixa do variador: a peca comprida do lado esquerdo, do bloco ate o eixo,
    # com a tampa cinza e o filtro de ar preto em cima. E o lado da PCX que
    # todo motoboy conhece.
    nesse_lado = Matrix.Translation(Vector((-0.115, 0.0, 0.0)))
    b.casco(
        [
            (-0.16, 0.30, 0.07, 0.18),
            (-0.24, 0.30, 0.09, 0.22),
            (-0.58, 0.27, 0.09, 0.17),
            (-0.70, 0.26, 0.08, 0.13),
            (-0.75, 0.26, 0.05, 0.08),
        ],
        "motor",
        expoente=3.0,
        gomos=10,
        matriz=nesse_lado,
    )
    b.caixa((-0.162, -0.40, 0.30), (0.012, 0.26, 0.10), "aleta")
    b.casco(
        [(-0.20, 0.43, 0.10, 0.08), (-0.30, 0.45, 0.12, 0.10), (-0.52, 0.42, 0.10, 0.08)],
        "preto",
        expoente=3.0,
        gomos=8,
        matriz=Matrix.Translation(Vector((-0.10, 0.0, 0.0))),
    )
    # Orelha de baixo do amortecedor esquerdo, na tampa do variador.
    b.caixa((-AMORTECEDOR_BAIXO.x, AMORTECEDOR_BAIXO.y, AMORTECEDOR_BAIXO.z), (0.03, 0.05, 0.05), "preto")

    # Braco da direita: segura o eixo do outro lado e o amortecedor direito.
    b.barra((0.105, -0.40, 0.30), (0.105, EIXO_TRASEIRO.y, EIXO_TRASEIRO.z), 0.03, 0.05, "preto")
    b.barra((0.11, EIXO_TRASEIRO.y, EIXO_TRASEIRO.z), (0.12, AMORTECEDOR_BAIXO.y, AMORTECEDOR_BAIXO.z), 0.03, 0.04, "preto")
    b.caixa(EIXO_TRASEIRO + Vector((0.11, 0.0, 0.0)), (0.035, 0.06, 0.06), "metal")

    # Escapamento do lado direito: o cano sai do cabecote embaixo do
    # assoalho, passa por baixo do motor e sobe para o silencioso, que na
    # scooter balanca junto com o motor. Por fora do amortecedor.
    b.caminho(
        [
            (0.0, 0.0, 0.17),
            (0.08, -0.12, 0.16),
            (0.17, -0.26, 0.20),
            (0.21, -0.36, 0.27),
        ],
        0.02,
        "metal",
    )
    b.tubo((0.21, -0.34, 0.26), (0.225, -0.76, 0.38), 0.058, 0.05, "metal", lados=10)
    b.tubo((0.225, -0.76, 0.38), (0.227, -0.81, 0.395), 0.03, 0.03, "cromado", lados=8)
    b.barra((0.265, -0.38, 0.30), (0.272, -0.70, 0.38), 0.012, 0.075, "preto")
    return b.objeto(material, colecao, pai)


def moto(material, colecao, raiz) -> None:
    base = vazio("Moto", (0.0, 0.0, 0.0), colecao, raiz)
    suspenso = vazio("Suspenso", (0.0, 0.0, 0.0), colecao, base)
    corpo(material, colecao, suspenso)

    obj_direcao = direcao(material, colecao, suspenso)
    obj_garfo = garfo(material, colecao, obj_direcao)
    roda_frente = Peca("Roda_Dianteira", EIXO_DIANTEIRO)
    roda_frente.roda(EIXO_DIANTEIRO, RAIO_FRENTE, 0.11, 0.077)
    # Disco de 220 mm do lado esquerdo.
    x = Vector((0.004, 0.0, 0.0))
    disco = EIXO_DIANTEIRO + Vector((-0.068, 0.0, 0.0))
    roda_frente.tubo(disco - x, disco + x, 0.11, 0.11, "cromado", lados=14)
    roda_frente.objeto(material, colecao, obj_garfo)

    obj_balanca = balanca(material, colecao, suspenso)
    roda_tras = Peca("Roda_Traseira", EIXO_TRASEIRO)
    roda_tras.roda(EIXO_TRASEIRO, RAIO_TRAS, 0.13, 0.09)
    # Tambor do freio, do lado do variador.
    roda_tras.tubo(EIXO_TRASEIRO + Vector((-0.075, 0.0, 0.0)), EIXO_TRASEIRO + Vector((-0.02, 0.0, 0.0)), 0.07, 0.075, "motor", lados=12)
    roda_tras.objeto(material, colecao, obj_balanca)

    for lado, sufixo in ((-1.0, "E"), (1.0, "D")):
        cima = Vector((lado * AMORTECEDOR_CIMA.x, AMORTECEDOR_CIMA.y, AMORTECEDOR_CIMA.z))
        baixo = Vector((lado * AMORTECEDOR_BAIXO.x, AMORTECEDOR_BAIXO.y, AMORTECEDOR_BAIXO.z))
        e.amortecedor(material, colecao, suspenso, obj_balanca, sufixo, cima, baixo, mola=(0.03, 6, 0.006))


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


e.gera("pcx160", monta)
