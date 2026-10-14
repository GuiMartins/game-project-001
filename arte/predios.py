"""Gerador dos predios: cinco modelos de rua carioca, de alturas e larguras diferentes.

Roda dentro do Blender (5.2+), igual ao entregador:

    blender --background --factory-startup --python arte/predios.py

Apaga a cena, monta os cinco, salva `arte/predios.blend` e exporta
`assets/predios/predios.glb` mais as duas texturas. Mesma receita, mesmo
`.glb`, byte a byte: este script e a fonte, o resto e build.

Os cinco, do mais baixo ao mais alto, cada um tirado de um pedaco das
referencias:

| no           | largura x fundo x altura | de onde vem                                  |
| ------------ | ------------------------ | -------------------------------------------- |
| `Sobrado`    | 10 x 11 x 12,8 m         | o casario do Centro: loja nas portas em arco, |
|              |                          | sacada em cima                                |
| `Comercio`   | 13 x 10 x 18,8 m         | loja com toldo embaixo, apartamento em cima,  |
|              |                          | empena cega lisa, outdoor no telhado          |
| `Deco`       | 14 x 12 x 29,8 m         | o art deco de Copacabana: torreao no meio,    |
|              |                          | friso vertical passando do telhado, loja,     |
|              |                          | outdoor em bandeira sobre a calcada           |
| `Escritorio` | 12 x 12 x 43,5 m         | a torre de vidro azul do fundo da avenida     |
| `Torre`      | 15 x 13 x 58,8 m         | o residencial de concreto com varanda corrida |
|              |                          | e loja embaixo, dos dois lados da portaria    |

Fora os cinco, a obra (V17a): `ObraEsqueleto*` e `ObraFachada*` sao a `Torre` com
0 e 8 andares prontos, cada uma com lona `Laranja` ou `Azul` sobre o andaime, e `GuindasteMastro`, `GuindasteLanca`, `GuindasteTopo` e
`GuindasteGancho` sao as pecas repetiveis do guindaste (ver `guindaste.gd`).

Todo predio de rua tem loja com toldo no terreo: e o que passa na altura do
olho, e a faixa de cor saturada que da ritmo a fachada (REFERENCIA_VIDEO.md,
"Os predios"). So o `Escritorio` nao tem: a torre de vidro e do fundo, e
banco no terreo de torre e portaria, nao vitrine.

As medidas da tabela sao do corpo. O outdoor fica fora delas: o do `Comercio`
sobe a 23 m, e a bandeira do `Deco` avanca 3,5 m sobre a calcada.

Convencoes, as mesmas do `entregador.py` e pelos mesmos motivos:

- **Metro, Z para cima, fachada em +Y.** O exportador glTF poe +Y em -Z, que
  e a frente de um `Node3D`: no Godot o predio "olha" para -Z, e quem o
  coloca so precisa apontar -Z para a pista.
- **Origem no chao, no centro da planta.** O `predio.gd` le o fundo de cada
  um no AABB da malha para afastar o predio da calcada sem numero repetido.
- **Fachada, dois lados e telhado; os fundos sao parede lisa.** A camera anda
  na avenida: ve a frente chegando, um lado passando e nunca as costas.

O que **nao** e geometria: tijolo, reboco, sujeira. A 640x360 uma janela de
1,4 m a 30 m ocupa uns 12 px - o que se le e o ritmo das janelas, a sombra da
varanda e o bloco de cor. Detalhe por pixel e foto, e foto o DIRECAO_VISUAL.md
ja descartou. Por isso cada janela e vidro sobre moldura sobre parede, com um
peitoril que joga sombra: e a sombra de 12 cm que faz a fachada ter fundo.
"""

import math
import os
import random
import zlib

import bmesh
import bpy
from mathutils import Matrix, Vector

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLEND = os.path.join(RAIZ, "arte", "predios.blend")
SAIDA = os.path.join(RAIZ, "assets", "predios")

# A mesma do mundo (`World.SEMENTE`): qual vidro reflete o ceu e onde tem ar
# condicionado saem dela, e regerar da o mesmo modelo.
SEMENTE = 20260831

# --- Paleta ------------------------------------------------------------------
#
# Mesmo esquema do entregador: uma textura de celulas chapadas, e cada face
# aponta o UV para o centro da sua. Celula de 32 px aguenta ate o mip 5, que e
# o que um predio a 150 m usa.
#
# A mascara usa o mesmo UV. R = pintura da parede, G = toldo e faixa do
# letreiro. E o que deixa o mesmo `Sobrado` ser amarelo, rosa ou azul ao longo
# da avenida, como no Centro, sem um modelo por cor.
#
# B e o que acende, em dois degraus: 1 e o fundo da tela do outdoor, que acende
# e leva a cor sorteada; 0,4 e a "foto" por cima dele, que acende na propria
# cor. Um canal so para os dois porque a tela inteira e luz - nao existe
# tingido apagado.

TEXTURA = 256
CELULA = 32

PAREDE, LOJA = (1, 0, 0), (0, 1, 0)
TELA, LUZ = (0, 0, 1), (0, 0, 0.4)
NADA = (0, 0, 0)

# nome: (albedo em sRGB, mascara)
PALETA = {
    # A pintura de fabrica e creme: o tom de reboco mais comum do Rio, e o que
    # sobra quando o mundo nao pinta (no `.blend`, por exemplo).
    "pintura": ((0.86, 0.78, 0.60), PAREDE),
    "pintura_sombra": ((0.66, 0.58, 0.43), PAREDE),
    "friso": ((0.93, 0.92, 0.88), NADA),
    "concreto": ((0.60, 0.59, 0.56), NADA),
    "concreto_escuro": ((0.36, 0.36, 0.35), NADA),
    "granito": ((0.20, 0.19, 0.19), NADA),
    "caixilho": ((0.17, 0.18, 0.20), NADA),
    "aluminio": ((0.70, 0.72, 0.74), NADA),
    # Vidro de apartamento: escuro, e alguns refletindo o ceu. Sem o claro a
    # fachada vira grade de buracos pretos.
    "vidro": ((0.13, 0.17, 0.22), NADA),
    "vidro_ceu": ((0.46, 0.60, 0.74), NADA),
    "cortina": ((0.78, 0.74, 0.64), NADA),
    # Pele de vidro do escritorio: azul, e o azul claro e o reflexo do ceu.
    "pele": ((0.16, 0.32, 0.52), NADA),
    "pele_ceu": ((0.50, 0.68, 0.86), NADA),
    "vitrine": ((0.10, 0.12, 0.14), NADA),
    "madeira": ((0.34, 0.20, 0.12), NADA),
    "persiana": ((0.17, 0.36, 0.28), NADA),
    "grade": ((0.10, 0.10, 0.11), NADA),
    "telha": ((0.64, 0.29, 0.17), NADA),
    "telha_escura": ((0.46, 0.20, 0.12), NADA),
    "toldo": ((0.15, 0.35, 0.68), LOJA),
    "toldo_listra": ((0.90, 0.90, 0.88), NADA),
    "letreiro": ((0.94, 0.92, 0.84), NADA),
    "porta_aco": ((0.52, 0.54, 0.56), NADA),
    "ar_condicionado": ((0.84, 0.84, 0.82), NADA),
    "caixa_dagua": ((0.48, 0.52, 0.56), NADA),
    # O fundo da tela do outdoor. Ciano de fabrica, que o `predio.gd` troca
    # pela cor sorteada; o titulo branco e a foto por cima nao trocam.
    "tela": ((0.20, 0.70, 0.95), TELA),
    "tela_luz": ((0.97, 0.97, 0.94), LUZ),
    # A "foto" do anuncio (V13a): areia, mar, ceu, gente e produto, cada um na
    # sua cor e acesos na propria cor. Nas referencias o outdoor e foto
    # colorida (`video_01/t3.0s`, o mupi da `01_centro`), e de longe foto e
    # tres ou quatro manchas de cor viva. Nenhuma vermelha: vermelho aceso na
    # altura da rua e lanterna de freio.
    "foto_ceu": ((0.45, 0.74, 0.96), LUZ),
    "foto_mar": ((0.08, 0.56, 0.64), LUZ),
    "foto_areia": ((0.96, 0.84, 0.58), LUZ),
    "foto_pele": ((0.84, 0.58, 0.40), LUZ),
    "foto_verde": ((0.22, 0.70, 0.30), LUZ),
    "foto_laranja": ((0.98, 0.56, 0.12), LUZ),
    "foto_amarelo": ((0.99, 0.88, 0.24), LUZ),
    "foto_roxo": ((0.52, 0.30, 0.86), LUZ),
    "foto_escuro": ((0.14, 0.16, 0.24), LUZ),
    # O amarelo do guindaste de torre (V17a): `04_vertical` e `03_viaduto`.
    # Fica no fim da paleta para nenhuma outra celula mudar de lugar.
    "guindaste": ((0.96, 0.74, 0.06), NADA),
    # A lona que enrola o andaime da obra, laranja ou azul (referencia: obra
    # com tela de protecao no Rio). Cor propria, e nao a mascara da loja: a
    # lona e de um dos dois tons, e nao de qualquer um do sorteio dos toldos.
    "lona_laranja": ((0.96, 0.46, 0.08), NADA),
    "lona_azul": ((0.12, 0.38, 0.86), NADA),
}
CELULAS = {nome: i for i, nome in enumerate(PALETA)}

# --- Luz de noite --------------------------------------------------------------
#
# A corrida anoitece (`scripts/hora.gd`), e de noite janela e vitrine acendem.
# Quais, e quando, quem decide e o shader, por janela e por predio: cada face
# de vidro leva no segundo UV (`Luz`) uma semente propria e o que ela e - meio
# para janela de andar, 1 para vitrine de loja, 0 para o resto. O mesmo modelo
# se repete pela avenida, e a semente de cada janela somada a posicao do
# predio faz cada copia acender um desenho diferente.
#
# A semente sai de um gerador so da luz, e nao do `rng` do predio: tirar
# numero dele mudaria qual vidro reflete o ceu na avenida inteira.
JANELA, VITRINE = 0.5, 1.0
# A lona do andaime (V17a) vai num material proprio, com alpha: as faces de
# `LONA` saem na segunda superficie da malha, e o jogo so troca o material da
# primeira. Xadrez de pixel furado era ruido: a lona tem de ser pano colorido
# por onde se ve o andaime, e isso e mistura de cor, nao furo.
LONA = ("lona_laranja", "lona_azul")
LONA_ALFA = 0.62
ACENDE = {
    "vidro": JANELA,
    "vidro_ceu": JANELA,
    "cortina": JANELA,
    "pele_ceu": JANELA,
    "vitrine": VITRINE,
}

# Quanto cada camada pintada na parede fica na frente da anterior. Menos que
# isso a 150 m e z-fighting: a janela pisca atras da parede.
CAMADA = 0.03


def uv_da_celula(i: int) -> tuple:
    por_linha = TEXTURA // CELULA
    return ((i % por_linha + 0.5) / por_linha, (i // por_linha + 0.5) / por_linha)


# --- Construcao de malha -----------------------------------------------------

Z = Vector((0.0, 0.0, 1.0))


class Peca:
    """Uma malha em construcao, com a cor gravada por face.

    Diferente do entregador, nada aqui recalcula normal no fim: placa solta na
    parede nao tem "dentro", e o recalculo vira metade das janelas para a
    parede. Cada primitiva ja nasce com a face para fora.
    """

    def __init__(self, nome: str) -> None:
        self.nome = nome
        self.bm = bmesh.new()
        self.cor = self.bm.faces.layers.int.new("cor")
        self.luz = self.bm.faces.layers.float.new("luz")
        self.sorteio_da_luz = random.Random(zlib.crc32(nome.encode()))

    def _acende(self, face, cor) -> None:
        if cor in ACENDE:
            # Nunca zero: zero e "nao acende".
            face[self.luz] = 0.001 + self.sorteio_da_luz.random() * 0.998

    def caixa(self, centro, tamanho, cor, rot_x=0.0, rot_y=0.0, rot_z=0.0) -> None:
        verts = bmesh.ops.create_cube(self.bm, size=1.0)["verts"]
        for v in verts:
            v.co.x *= tamanho[0]
            v.co.y *= tamanho[1]
            v.co.z *= tamanho[2]
        m = (
            Matrix.Translation(Vector(centro))
            @ Matrix.Rotation(math.radians(rot_z), 4, "Z")
            @ Matrix.Rotation(math.radians(rot_y), 4, "Y")
            @ Matrix.Rotation(math.radians(rot_x), 4, "X")
        )
        bmesh.ops.transform(self.bm, matrix=m, verts=verts)
        for face in {f for v in verts for f in v.link_faces}:
            face[self.cor] = CELULAS[cor]
            self._acende(face, cor)

    def face(self, pontos, normal, cor) -> None:
        """Poligono convexo, virado para `normal`."""
        verts = [self.bm.verts.new(Vector(p)) for p in pontos]
        f = self.bm.faces.new(verts)
        f.normal_update()
        if f.normal.dot(Vector(normal)) < 0.0:
            f.normal_flip()
        f[self.cor] = CELULAS[cor]
        self._acende(f, cor)

    def telhado(self, centro, largura, fundo, altura, cor, cor_oitao) -> None:
        """Telhado de quatro aguas, com a cumeeira no lado comprido."""
        c = Vector(centro)
        hx, hy = largura * 0.5, fundo * 0.5
        topo = c + Z * altura
        b = [c + Vector(p) for p in ((-hx, -hy, 0), (hx, -hy, 0), (hx, hy, 0), (-hx, hy, 0))]
        if hx >= hy:
            r0, r1 = topo - Vector((hx - hy, 0, 0)), topo + Vector((hx - hy, 0, 0))
            self.face((b[0], b[1], r1, r0), (0, -1, 1), cor)
            self.face((b[2], b[3], r0, r1), (0, 1, 1), cor)
            self.face((b[3], b[0], r0), (-1, 0, 1), cor_oitao)
            self.face((b[1], b[2], r1), (1, 0, 1), cor_oitao)
        else:
            r0, r1 = topo - Vector((0, hy - hx, 0)), topo + Vector((0, hy - hx, 0))
            self.face((b[3], b[0], r0, r1), (-1, 0, 1), cor)
            self.face((b[1], b[2], r1, r0), (1, 0, 1), cor)
            self.face((b[0], b[1], r0), (0, -1, 1), cor_oitao)
            self.face((b[2], b[3], r1), (0, 1, 1), cor_oitao)

    def objeto(self, material, colecao, x_no_blend, material_lona=None) -> bpy.types.Object:
        bm = self.bm
        bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method="FIXED", ngon_method="EAR_CLIP")
        # Ordem canonica das faces, como no entregador: o mesmo modelo sai no
        # mesmo .glb, e diff de arte nao vem com ruido de arquivo inteiro.
        bm.faces.index_update()
        posto = [0] * len(bm.faces)
        chave = lambda f: (*(round(c, 5) for c in f.calc_center_median()), f[self.cor])  # noqa: E731
        for i, face in enumerate(sorted(bm.faces, key=chave)):
            posto[face.index] = i
        bm.faces.sort(key=lambda f: posto[f.index])

        uv = bm.loops.layers.uv.new("UVMap")
        uv_luz = bm.loops.layers.uv.new("Luz")
        nomes = list(PALETA)
        for face in bm.faces:
            ponto = uv_da_celula(face[self.cor])
            # O exportador do glTF vira o V (1 - v), e o jogo le como chega: o
            # tipo vai gravado de ponta-cabeca para chegar no shader do lado
            # certo. A semente vai no U, que ninguem mexe.
            luz = (face[self.luz], 1.0 - ACENDE.get(nomes[face[self.cor]], 0.0))
            for loop in face.loops:
                loop[uv].uv = ponto
                loop[uv_luz].uv = luz
            # Predio e chapa: tudo duro. Liso, a quina vira degrade e a caixa
            # vira sabonete.
            face.smooth = False
            if material_lona is not None and nomes[face[self.cor]] in LONA:
                face.material_index = 1
        bm.faces.layers.int.remove(self.cor)
        bm.faces.layers.float.remove(self.luz)

        malha = bpy.data.meshes.new(self.nome)
        bm.to_mesh(malha)
        bm.free()
        malha.materials.append(material)
        if material_lona is not None:
            malha.materials.append(material_lona)

        obj = bpy.data.objects.new(self.nome, malha)
        colecao.objects.link(obj)
        # Lado a lado no .blend, so para dar para olhar os quatro. O jogo usa
        # a malha, nao a posicao do no.
        obj.location = (x_no_blend, 0.0, 0.0)
        return obj


class Parede:
    """Um plano vertical do predio, para pendurar janela sem conta de eixo.

    `s` corre ao longo da parede, `z` sobe do chao e `fora` sai dela.
    """

    def __init__(self, base, u, normal, largura) -> None:
        self.base = Vector(base)
        self.u = Vector(u)
        self.n = Vector(normal)
        self.largura = largura

    def ponto(self, s, z, fora=0.0) -> Vector:
        return self.base + self.u * s + Z * z + self.n * fora

    def placa(self, peca, s, z, largura, altura, cor, fora) -> None:
        """Retangulo pintado na parede; `s` e `z` sao o centro."""
        c = self.ponto(s, z, fora)
        u = self.u * (largura * 0.5)
        v = Z * (altura * 0.5)
        peca.face((c - u - v, c + u - v, c + u + v, c - u + v), self.n, cor)

    def arco(self, peca, s, z, raio, cor, fora, gomos=6) -> None:
        """Meio disco em pe, com o centro na linha de nascenca do arco."""
        c = self.ponto(s, z, fora)
        pontos = [
            c + self.u * (raio * math.cos(math.pi * i / gomos)) + Z * (raio * math.sin(math.pi * i / gomos))
            for i in range(gomos + 1)
        ]
        peca.face(pontos, self.n, cor)

    def caixa(self, peca, s, z, largura, saliencia, altura, cor, recuo=0.0) -> None:
        """Caixa encostada na parede: `saliencia` e quanto ela sai para fora.

        Com `recuo`, ela entra na parede: e o pilar embaixo de um andar que
        avanca sobre a portaria.
        """
        centro = self.ponto(s, z, saliencia * 0.5 - recuo)
        tam = self.u * largura + self.n * saliencia
        peca.caixa(centro, (abs(tam.x), abs(tam.y), altura), cor)

    def janela(self, peca, s, z, largura, altura, vidro, moldura="caixilho", peitoril=None) -> None:
        """Moldura, vidro e peitoril; `z` e a base do vao.

        O peitoril sai 18 cm da parede: com o sol a 42 graus ele risca uma
        sombra embaixo de cada janela, e e isso que da fundo a fachada.
        """
        meio = z + altura * 0.5
        self.placa(peca, s, meio, largura + 0.2, altura + 0.2, moldura, CAMADA)
        self.placa(peca, s, meio, largura, altura, vidro, CAMADA * 2)
        if peitoril is not None:
            self.caixa(peca, s, z - 0.16, largura + 0.3, 0.18, 0.12, peitoril)


def paredes(largura, fundo) -> tuple:
    """Fachada (+Y), lado esquerdo (-X) e lado direito (+X), olhando de fora."""
    hx, hy = largura * 0.5, fundo * 0.5
    return (
        Parede((0, hy, 0), (-1, 0, 0), (0, 1, 0), largura),
        Parede((-hx, 0, 0), (0, -1, 0), (-1, 0, 0), fundo),
        Parede((hx, 0, 0), (0, 1, 0), (1, 0, 0), fundo),
    )


def colunas(n, largura, margem) -> list:
    """Centro de `n` vaos iguais ao longo de `largura`, deixando `margem` nas pontas."""
    passo = (largura - 2.0 * margem) / n
    return [-largura * 0.5 + margem + passo * (i + 0.5) for i in range(n)]


def vidro_sorteado(rng, claro="vidro_ceu", escuro="vidro", chance=0.3) -> str:
    return claro if rng.random() < chance else escuro


# --- Terreo ------------------------------------------------------------------
#
# A loja e o que todo predio de rua divide: vao, toldo e letreiro. Mora aqui,
# e nao copiada em cada predio, para o toldo do sobrado e o da torre lerem como
# a mesma rua - mesma inclinacao, mesma listra, mesma altura de cabeca.

# Quanto o toldo cai para a rua. Mais deitado some visto de lado; mais em pe
# vira parede colorida tapando a vitrine.
TOLDO_QUEDA = 22.0
# Listra de 1,5 m: larga o bastante para nao virar chuvisco quando passa no
# canto da tela. Toldo mais estreito que duas dessas sai liso.
TOLDO_LISTRA = 1.5


def toldo(p, parede, s, largura, z_topo, saida=1.8, fora=0.0) -> None:
    """Lona caindo para a rua, com a borda de cima em `z_topo`, na parede.

    So na fachada: a inclinacao gira em X, que e o eixo da parede da frente.
    """
    assert parede.n.y > 0.5, "toldo so na fachada"
    queda = math.radians(TOLDO_QUEDA)
    listras = max(1, round(largura / TOLDO_LISTRA))
    if listras > 1 and listras % 2 == 0:
        # Impar: as duas pontas na cor da loja, que e a que se ve de lado.
        listras += 1
    largura_listra = largura / listras
    for k in range(listras):
        ds = -largura * 0.5 + largura_listra * (k + 0.5)
        centro = parede.ponto(s + ds, z_topo - saida * 0.5 * math.sin(queda), fora + saida * 0.5 * math.cos(queda))
        cor = "toldo" if k % 2 == 0 else "toldo_listra"
        p.caixa(centro, (largura_listra, saida, 0.06), cor, rot_x=-TOLDO_QUEDA)


def letreiro(p, parede, s, largura, z, fora=0.0) -> None:
    """Placa clara com faixa na cor da loja; `z` e o centro da placa.

    Sem texto: nome de loja e marca, e marca o PROTOTIPO.md deixou de fora.
    """
    parede.caixa(p, s, z, largura, 0.3, 0.8, "letreiro", recuo=-fora)
    parede.caixa(p, s, z - 0.32, largura, 0.32, 0.16, "toldo", recuo=-fora)


def vao_de_loja(p, parede, s, largura, altura, porta_aco=False, fora=0.0) -> None:
    """Vitrine ou porta de aco de enrolar, do chao ate `altura`.

    As ranhuras da porta sao horizontais e grossas: atravessadas na pista
    seriam chuvisco, mas aqui correm junto com a pista, de lado.
    """
    meio = 0.1 + altura * 0.5
    if porta_aco:
        parede.placa(p, s, meio, largura, altura, "porta_aco", fora + CAMADA)
        for k in range(int(altura / 0.6)):
            parede.placa(p, s, 0.4 + k * 0.6, largura, 0.08, "caixilho", fora + CAMADA * 2)
    else:
        parede.placa(p, s, meio, largura + 0.3, altura + 0.2, "caixilho", fora + CAMADA)
        parede.placa(p, s, meio, largura, altura, "vitrine", fora + CAMADA * 2)


# --- Outdoor -----------------------------------------------------------------
#
# O painel luminoso do video (REFERENCIA_VIDEO.md, "Os predios"): moldura
# clara e uma foto colorida acesa, deitada como uma tela de TV (V13a; ja foi
# bandeira em pe, de uma cor so com disco e barras). Fica de **topo para a
# rua**, perpendicular a fachada: a camera anda rente a avenida e ve a fachada
# de raspao, entao painel colado nela some; de topo ele encara quem vem, como
# o de verdade, que e posto para o transito ler.
#
# Duas faces, cada uma com a sua foto: o predio cai dos dois lados da pista,
# e a face que encara a camera depende de qual.

OUTDOOR_MOLDURA = 0.25
OUTDOOR_ESPESSURA = 0.3


def outdoor(p, rng, centro, n, largura, altura) -> None:
    """Painel com o centro em `centro`, as duas telas para `n` e `-n`.

    `n` e horizontal; a largura corre no eixo deitado perpendicular a ele.
    """
    c, n = Vector(centro), Vector(n)
    u = Z.cross(n)
    tam = u * (largura + OUTDOOR_MOLDURA * 2.0) + n * OUTDOOR_ESPESSURA
    p.caixa(c, (abs(tam.x), abs(tam.y), altura + OUTDOOR_MOLDURA * 2.0), "friso")
    for lado in (1.0, -1.0):
        # `u` vira junto com a face: visto de fora, a foto le da esquerda
        # para a direita nas duas.
        face = Parede(c, u * lado, n * lado, largura)
        fora = OUTDOOR_ESPESSURA * 0.5
        face.placa(p, 0.0, 0.0, largura, altura, "tela", fora + CAMADA)
        foto(p, face, rng, largura, altura, fora + CAMADA * 2)


def foto(p, face, rng, largura, altura, fora) -> None:
    """O anuncio: uma foto inventada, de manchas grandes, sem texto nem marca.

    A 60 m um painel de 7 m tem uns 25 px, e o que sobra de qualquer foto e
    tres ou quatro manchas de cor - e o que a referencia mostra de longe. O
    fundo e a `tela`, que cada predio pinta de uma cor (`Predio.TELAS`): o
    mesmo modelo com a mesma foto nao repete igual ao longo da avenida. Tres
    fotos, sorteadas por face: praia, produto e gente.

    Cada mancha fica uma `CAMADA` adiante da anterior, como no mural que
    existia antes, para nao brigar no z-buffer.
    """
    hl, ha = largura * 0.5, altura * 0.5
    camada = [fora]

    def proxima() -> float:
        camada[0] += CAMADA
        return camada[0]

    def faixa(z0, z1, cor) -> None:
        face.placa(p, 0.0, (z0 + z1) * 0.5, largura, z1 - z0, cor, proxima())

    def disco(cs, cz, raio, cor, achata=1.0) -> None:
        f = proxima()
        pontos = [
            face.ponto(cs + raio * math.cos(a), cz + raio * achata * math.sin(a), f)
            for a in (math.tau * i / 12 for i in range(12))
        ]
        p.face(pontos, face.n, cor)

    def bloco(cs, cz, w, h, cor) -> None:
        face.placa(p, cs, cz, w, h, cor, proxima())

    # O lado da pessoa ou do produto: o titulo vai no outro.
    lado = rng.choice((-1.0, 1.0))
    tipo = rng.choice(("praia", "produto", "gente"))
    if tipo == "praia":
        # Ceu e a tela, mar no meio, areia embaixo, sol e um banhista.
        faixa(-ha * 0.15, ha * 0.15, "foto_mar")
        faixa(-ha, -ha * 0.15, "foto_areia")
        disco(-lado * hl * 0.55, ha * 0.55, ha * 0.28, "foto_amarelo")
        cs = lado * hl * 0.45
        disco(cs, ha * 0.28, ha * 0.2, "foto_pele")
        bloco(cs, -ha * 0.35, ha * 0.5, ha * 0.9, "foto_laranja")
    elif tipo == "produto":
        # O produto em pe sobre uma faixa de cor, e o titulo do outro lado.
        # Faixa, e nao a onda de disco: tudo tem de caber dentro da moldura.
        faixa(-ha, -ha * 0.45, "foto_amarelo")
        cs = lado * hl * 0.4
        bloco(cs, -ha * 0.05, hl * 0.35, ha * 1.3, "foto_escuro")
        bloco(cs, ha * 0.0, hl * 0.35, ha * 0.4, "foto_verde")
        disco(cs, ha * 0.72, hl * 0.12, "foto_escuro")
        bloco(-lado * hl * 0.45, ha * 0.35, hl * 0.75, ha * 0.3, "tela_luz")
        bloco(-lado * hl * 0.55, -ha * 0.15, hl * 0.55, ha * 0.18, "foto_laranja")
    else:
        # Gente: uma pessoa grande de um lado, sobre um fundo de duas cores.
        meia = (-hl, 0.0) if lado < 0 else (0.0, hl)
        bloco((meia[0] + meia[1]) * 0.5, 0.0, hl, altura, "foto_roxo")
        cs = lado * hl * 0.5
        bloco(cs, -ha * 0.55, hl * 0.6, ha * 0.9, "foto_amarelo")
        disco(cs, ha * 0.2, ha * 0.32, "foto_pele")
        disco(cs, ha * 0.42, ha * 0.3, "foto_escuro", achata=0.55)
        bloco(-lado * hl * 0.5, ha * 0.3, hl * 0.7, ha * 0.25, "tela_luz")
        bloco(-lado * hl * 0.55, -ha * 0.2, hl * 0.5, ha * 0.15, "foto_ceu")


# --- Sobrado -----------------------------------------------------------------
#
# O casario ecletico do Centro (referencia 2, lado direito): dois andares de pe
# direito alto, tres vaos marcados por pilastra branca, porta em arco embaixo,
# janela de sacada com persiana em cima, platibanda escondendo o telhado.


def sobrado(rng) -> Peca:
    p = Peca("Sobrado")
    W, D = 10.0, 11.0
    TERREO, SUPERIOR, PLATIBANDA = 4.6, 8.8, 10.4
    p.caixa((0, 0, PLATIBANDA * 0.5), (W, D, PLATIBANDA), "pintura")
    # Embasamento, cornija entre andares e cornija do topo: as tres linhas
    # horizontais que fazem o predio ler como "antigo" a qualquer distancia.
    p.caixa((0, 0, 0.4), (W + 0.12, D + 0.12, 0.8), "pintura_sombra")
    p.caixa((0, 0, TERREO), (W + 0.3, D + 0.3, 0.35), "friso")
    p.caixa((0, 0, SUPERIOR), (W + 0.5, D + 0.5, 0.45), "friso")
    p.caixa((0, 0, PLATIBANDA), (W + 0.3, D + 0.3, 0.25), "friso")
    # Telhado colonial atras da platibanda: so a cumeeira aparece da rua, mas
    # e ela que diz telha.
    p.telhado((0, 0, PLATIBANDA - 0.3), W - 0.8, D - 0.8, 2.6, "telha", "telha_escura")

    frente, esquerda, direita = paredes(W, D)
    vaos = colunas(3, W, 0.0)
    for s in (-W * 0.5 + 0.3, -W / 6.0, W / 6.0, W * 0.5 - 0.3):
        frente.caixa(p, s, (0.8 + SUPERIOR) * 0.5, 0.6, 0.2, SUPERIOR - 0.8, "friso")
    # Pinhas na platibanda, em cima de cada pilastra.
    for s in (-W * 0.5 + 0.3, -W / 6.0, W / 6.0, W * 0.5 - 0.3):
        frente.caixa(p, s, PLATIBANDA + 0.5, 0.4, 0.4, 0.8, "friso")

    for i, s in enumerate(vaos):
        # Terreo: porta alta com bandeira em arco. Dois vaos sao loja, com
        # vitrine ou porta de aco e um toldo liso logo abaixo da nascenca do
        # arco, que continua aparecendo por cima. O da ponta e a porta de
        # madeira da escada de quem mora em cima: o casario do Centro e assim,
        # e a madeira escura entre dois toldos e o que o separa do Comercio.
        miolo = ("vitrine", "porta_aco", "madeira")[i]
        frente.placa(p, s, 1.6, 1.6, 3.2, miolo, CAMADA * 3)
        frente.arco(p, s, 3.2, 1.0, "friso", CAMADA * 2)
        frente.arco(p, s, 3.2, 0.8, "vitrine" if miolo == "porta_aco" else miolo, CAMADA * 3)
        frente.placa(p, s, 1.65, 2.0, 3.3, "friso", CAMADA * 2)
        if miolo != "madeira":
            toldo(p, frente, s, 1.9, 3.25, saida=1.1, fora=0.2)

        # Superior: janela de sacada com bandeira, persiana aberta dos lados e
        # sacadinha de ferro.
        frente.placa(p, s, 6.55, 1.7, 2.7, "friso", CAMADA)
        frente.arco(p, s, 7.9, 0.85, "friso", CAMADA)
        frente.placa(p, s, 6.55, 1.3, 2.5, vidro_sorteado(rng), CAMADA * 2)
        frente.arco(p, s, 7.8, 0.65, vidro_sorteado(rng), CAMADA * 2)
        for lado in (-1.0, 1.0):
            frente.placa(p, s + lado * 1.25, 6.55, 0.62, 2.5, "persiana", CAMADA * 2)
        frente.caixa(p, s, 5.25, 2.0, 0.6, 0.15, "friso")
        sacada = frente.ponto(s, 5.75, 0.58)
        p.caixa(sacada, (2.0, 0.05, 0.85), "grade")

    for lado in (esquerda, direita):
        for s in colunas(2, D, 2.0):
            lado.janela(p, s, 5.6, 1.1, 2.0, vidro_sorteado(rng), moldura="friso", peitoril="friso")
    return p


# --- Comercio ----------------------------------------------------------------
#
# O predio misto de quatro andares que forra a avenida (referencia 2, lado
# esquerdo): loja embaixo com toldo e letreiro, apartamento em cima com ar
# condicionado pendurado, e a empena cega lisa.


def comercio(rng) -> Peca:
    p = Peca("Comercio")
    W, D = 13.0, 10.0
    LOJA_ALTURA, ANDAR, ANDARES = 4.4, 3.0, 4
    TOPO = LOJA_ALTURA + ANDAR * ANDARES
    p.caixa((0, 0, (TOPO + 1.0) * 0.5), (W, D, TOPO + 1.0), "pintura")
    cornija(p, W, D, TOPO + 1.0)
    p.caixa((0, 0, LOJA_ALTURA * 0.5), (W + 0.06, D + 0.06, LOJA_ALTURA), "pintura_sombra")
    p.caixa((2.5, -1.5, TOPO + 2.2), (2.4, 2.4, 2.2), "caixa_dagua")

    frente, esquerda, direita = paredes(W, D)

    # Loja: duas vitrines e uma porta de aco, debaixo de um letreiro e de um
    # toldo so, de ponta a ponta.
    for s in (-4.1, 0.6):
        vao_de_loja(p, frente, s, 3.3, 2.8)
    vao_de_loja(p, frente, 4.7, 2.8, 3.0, porta_aco=True)
    letreiro(p, frente, 0.0, W - 0.6, 4.0)
    toldo(p, frente, 0.0, W - 1.0, 3.39)

    for andar in range(ANDARES):
        z = LOJA_ALTURA + andar * ANDAR
        frente.caixa(p, 0.0, z + 0.05, W + 0.1, 0.12, 0.2, "friso")
        for s in colunas(4, W, 0.6):
            frente.janela(p, s, z + 0.9, 1.5, 1.6, vidro_sorteado(rng, claro="cortina"), peitoril="friso")
            # Ar condicionado de janela: o volume que mais diz "Rio" numa
            # fachada, e uma sombrinha a mais.
            if rng.random() < 0.35:
                frente.caixa(p, s + 0.45, z + 0.55, 0.65, 0.45, 0.42, "ar_condicionado")

    # Empena cega lisa, na cor da fachada. Ja foi mural (V11a): nas
    # referencias o grafite colorido so existe em muro de via expressa
    # (`03_viaduto`, `04_vertical`), e na avenida ele brigava com a bag e
    # puxava a rua para o pastel.

    # Outdoor de telhado, na ponta oposta a caixa d'agua, sobre dois pes de
    # ferro. 7 x 4 m, o 16:9 da referencia (`video_01/t3.0s`), encolhido para
    # caber no fundo de 10 m; um metro e meio de pe tira a tela de tras da
    # platibanda vista de baixo.
    PE, LARGURA, ALTURA = 1.5, 7.0, 4.0
    base = TOPO + 1.1
    centro = (-3.5, -0.3, base + PE + ALTURA * 0.5 + OUTDOOR_MOLDURA)
    outdoor(p, rng, centro, (1, 0, 0), LARGURA, ALTURA)
    for y in (-LARGURA * 0.3, LARGURA * 0.3):
        p.caixa((-3.5, centro[1] + y, base + PE * 0.5), (0.2, 0.2, PE), "grade")
    return p


def cornija(p, largura, fundo, z) -> None:
    """A cornija do topo: o beiral de pedra que fecha a fachada de cima.

    Nas referencias todo predio do corredor termina numa faixa saliente com
    sombra embaixo (`video_01/t5.0s`), e e ela que faz o bloco ler como pedra
    trabalhada e nao como caixa pintada. A sombra e uma faixa escura de
    verdade, e nao so a do sol: a 640x360 a sombra propria de 25 cm some
    quando o predio esta do lado da sombra. Sai so 25 cm de cada lado, porque
    o `cidade.gd` encosta um predio no outro pela caixa inteira, e cornija
    larga abriria vao na altura da rua.
    """
    p.caixa((0, 0, z - 0.25), (largura + 0.3, fundo + 0.3, 0.3), "pintura_sombra")
    p.caixa((0, 0, z + 0.1), (largura + 0.5, fundo + 0.5, 0.4), "friso")


# --- Deco --------------------------------------------------------------------
#
# O predio de apartamento art deco de Copacabana, dos anos 30 e 40: sete
# andares sobre loja, um torreao no meio da fachada que sobe alem do telhado,
# e as linhas horizontais ligando as janelas - a "linha de velocidade" do
# estilo. E o predio que mais diz Rio na rua, e o que faltava entre o Comercio
# de quatro andares e as torres.


def deco(rng) -> Peca:
    p = Peca("Deco")
    W, D = 14.0, 12.0
    LOJA_ALTURA, ANDAR, ANDARES = 4.4, 3.0, 7
    TOPO = LOJA_ALTURA + ANDAR * ANDARES
    PLATIBANDA = TOPO + 0.8
    TORREAO, SAIDA = 4.6, 0.7
    p.caixa((0, 0, PLATIBANDA * 0.5), (W, D, PLATIBANDA), "pintura")
    cornija(p, W, D, PLATIBANDA)
    # So 1 cm para fora da parede: a vitrine vai uma `CAMADA` adiante, e o
    # embasamento no mesmo plano dela piscaria.
    p.caixa((0, 0, LOJA_ALTURA * 0.5), (W + 0.02, D + 0.02, LOJA_ALTURA), "granito")
    p.caixa((-3.0, -2.0, PLATIBANDA + 1.2), (2.6, 2.6, 2.2), "caixa_dagua")

    frente, esquerda, direita = paredes(W, D)

    # Terreo: portaria no meio, com a moldura em degraus que e a assinatura
    # do estilo, e uma loja de cada lado com letreiro e toldo proprios.
    for k, (largura, cor) in enumerate(((3.4, "friso"), (2.8, "granito"), (2.0, "vitrine"))):
        altura = 3.6 - k * 0.4
        frente.placa(p, 0.0, altura * 0.5, largura, altura, cor, CAMADA * (k + 1))
    frente.caixa(p, 0.0, 3.85, 3.6, 1.6, 0.18, "concreto")
    for lado in (-1.0, 1.0):
        s = lado * 4.7
        vao_de_loja(p, frente, s, 3.8, 2.9, porta_aco=lado < 0.0 and rng.random() < 0.4)
        letreiro(p, frente, s, 4.4, 3.95)
        toldo(p, frente, s, 4.2, 3.35)

    # Torreao: a caixa saliente no meio, do primeiro andar ate acima da
    # platibanda, com janela corrida em cada andar e dois frisos verticais
    # que passam do topo. Visto de longe, e ele que faz o predio ser deco e
    # nao um Comercio mais alto.
    frente.caixa(p, 0.0, (LOJA_ALTURA + PLATIBANDA + 2.4) * 0.5, TORREAO, SAIDA, PLATIBANDA + 2.4 - LOJA_ALTURA, "pintura")
    torreao = Parede(frente.ponto(0.0, 0.0, SAIDA), frente.u, frente.n, TORREAO)
    for andar in range(ANDARES):
        z = LOJA_ALTURA + andar * ANDAR
        torreao.janela(p, 0.0, z + 0.8, 3.4, 1.5, vidro_sorteado(rng, chance=0.35))
        torreao.caixa(p, 0.0, z + 0.55, TORREAO, 0.14, 0.14, "friso")
    for s in (-1.4, 1.4):
        torreao.caixa(p, s, (LOJA_ALTURA + PLATIBANDA + 3.6) * 0.5, 0.3, 0.3, PLATIBANDA + 3.6 - LOJA_ALTURA, "friso")
    # Coroamento escalonado: dois degraus em cima do torreao.
    torreao.caixa(p, 0.0, PLATIBANDA + 2.6, TORREAO - 0.8, SAIDA - 0.1, 0.4, "friso", recuo=SAIDA - 0.05)
    torreao.caixa(p, 0.0, PLATIBANDA + 3.0, TORREAO - 2.0, SAIDA - 0.3, 0.4, "friso", recuo=SAIDA - 0.15)

    # Os dois lados do torreao: duas janelas por andar com peitoril, e a
    # sobrancelha corrida por cima delas, de quina a quina. A sombra de 10 cm
    # dela e a linha horizontal que o estilo inteiro repete.
    ala = (W - TORREAO) * 0.5
    for andar in range(ANDARES):
        z = LOJA_ALTURA + andar * ANDAR
        for lado in (-1.0, 1.0):
            meio = lado * (TORREAO + ala) * 0.5
            frente.caixa(p, meio, z + 2.55, ala, 0.12, 0.12, "friso")
            for ds in (-1.0, 1.0):
                s = meio + ds
                frente.janela(p, s, z + 0.9, 1.4, 1.5, vidro_sorteado(rng, claro="cortina"), peitoril="friso")
                if rng.random() < 0.25:
                    frente.caixa(p, s + 0.4, z + 0.55, 0.6, 0.42, 0.4, "ar_condicionado")
    for s in (-W * 0.5 + 0.25, W * 0.5 - 0.25):
        frente.caixa(p, s, (LOJA_ALTURA + PLATIBANDA) * 0.5, 0.5, 0.15, PLATIBANDA - LOJA_ALTURA, "friso")

    for lado in (esquerda, direita):
        for andar in range(ANDARES):
            z = LOJA_ALTURA + andar * ANDAR
            lado.caixa(p, 0.0, z + 2.55, D, 0.1, 0.12, "friso")
            for s in colunas(3, D, 1.2):
                lado.janela(p, s, z + 0.9, 1.2, 1.4, vidro_sorteado(rng, claro="cortina"), peitoril="friso")

    # Outdoor em bandeira, saindo da fachada entre as duas janelas da ala, no
    # primeiro andar: e o painel da esquerda da referencia, que passa por cima
    # da calcada. Deitado, 3,8 x 2,2 m (V13a; era 2,8 x 4,2 em pe): comeca a
    # 6 m do chao, acima do toldo e do caminhao bau, e sai 4,3 m - o
    # `predio.gd` afasta o predio so pelo que fica na altura da rua, e a
    # bandeira avanca sobre a calcada como a de verdade, sem chegar no poste,
    # que fica a 6 m da fachada. Vem por ultimo para o sorteio da foto nao
    # mexer no vidro.
    s, LARGURA, ALTURA, VAO = (TORREAO + ala) * 0.5, 3.8, 2.2, 0.25
    z = LOJA_ALTURA + 1.6 + OUTDOOR_MOLDURA + ALTURA * 0.5
    centro = frente.ponto(s, z, VAO + OUTDOOR_MOLDURA + LARGURA * 0.5)
    outdoor(p, rng, centro, (1, 0, 0), LARGURA, ALTURA)
    for dz in (-ALTURA * 0.35, ALTURA * 0.35):
        frente.caixa(p, s, z + dz, 0.16, VAO, 0.16, "grade")
    return p


# --- Escritorio --------------------------------------------------------------
#
# A torre de vidro azul do fundo da referencia 2: pele de vidro com montante
# de aluminio, faixa escura em cada laje, portaria recuada com marquise.


def escritorio(rng) -> Peca:
    p = Peca("Escritorio")
    W, D = 12.0, 12.0
    BASE, ANDAR, ANDARES = 5.0, 3.6, 10
    TOPO = BASE + ANDAR * ANDARES
    p.caixa((0, 0, BASE * 0.5), (W - 1.6, D - 1.6, BASE), "vitrine")
    p.caixa((0, 0, BASE + ANDAR * ANDARES * 0.5), (W, D, ANDAR * ANDARES), "pele")
    # Coroamento: casa de maquinas recuada e uma faixa de aluminio no topo.
    p.caixa((0, 0, TOPO + 0.3), (W + 0.2, D + 0.2, 0.6), "aluminio")
    p.caixa((0, -1.0, TOPO + 1.6), (W - 3.0, D - 4.0, 2.0), "concreto")

    frente, esquerda, direita = paredes(W, D)
    # Pilares da portaria e a marquise, que joga sombra na calcada.
    for s in colunas(4, W, 0.4):
        frente.caixa(p, s, BASE * 0.5, 0.7, 0.7, BASE, "granito", recuo=0.7)
    frente.caixa(p, 0.0, BASE - 0.25, W + 0.4, 2.2, 0.3, "aluminio")

    # Reflexo do ceu: uma faixa diagonal de vidro claro que atravessa a
    # fachada. Sorteio painel a painel vira xadrez; a diagonal le como o ceu
    # refletido num plano so, que e o que o vidro de verdade faz.
    for indice, parede in enumerate((frente, esquerda, direita)):
        vaos = 8
        largura_vao = parede.largura / vaos
        fase = rng.uniform(0.0, 9.0)
        for andar in range(ANDARES):
            z = BASE + andar * ANDAR
            for v in range(vaos):
                s = -parede.largura * 0.5 + largura_vao * (v + 0.5)
                diagonal = (andar * 0.9 - v * 1.3 + fase + indice * 2.0) % 9.0
                if diagonal < 2.6:
                    parede.placa(p, s, z + ANDAR * 0.55, largura_vao - 0.1, ANDAR - 0.7, "pele_ceu", CAMADA)
            parede.caixa(p, 0.0, z + 0.05, parede.largura + 0.1, 0.06, 0.6, "caixilho")
        for v in range(1, vaos):
            s = -parede.largura * 0.5 + largura_vao * v
            parede.caixa(p, s, BASE + ANDAR * ANDARES * 0.5, 0.12, 0.18, ANDAR * ANDARES, "aluminio")
    return p


# --- Torre -------------------------------------------------------------------
#
# O residencial alto da referencia 1: pilotis com portaria embaixo e vinte
# metros de varanda corrida empilhada. A varanda e o que faz a torre: cada
# laje saindo 1,2 m da fachada e uma faixa de sol com uma faixa de sombra
# embaixo, e dezesseis delas leem como "predio de apartamento" de qualquer
# distancia.


ANDARES_DA_TORRE = 16


def torre(rng, prontos=ANDARES_DA_TORRE, nome="Torre", lona=None) -> Peca:
    """O residencial de concreto. `prontos` e a fase de obra (V17a): quantos
    andares, de baixo para cima, ja tem fachada. Com todos, e a `Torre` de
    sempre, byte a byte; com menos, o resto fica no esqueleto - laje, pilar e
    o miolo do elevador -, e o topo perde cornija e caixa d'agua. E o mesmo
    gerador, e nao um modelo a parte, para a obra ter exatamente a planta, a
    altura e a loja do terreo da torre que ela vai virar.

    Com `lona`, a obra ganha andaime em volta, descendo ate a calcada, e
    lona na cor dada (V17a, segunda passada): so o ferro no topo fazia a obra
    parecer um predio com defeito no ultimo andar, e o que le "obra" no
    quadro e o corpo inteiro embrulhado.
    """
    p = Peca(nome)
    W, D = 15.0, 13.0
    PILOTIS, ANDAR, ANDARES = 4.0, 3.0, ANDARES_DA_TORRE
    TOPO = PILOTIS + ANDAR * ANDARES
    if prontos > 0:
        p.caixa((0, 0, PILOTIS * 0.5), (W - 2.0, D - 2.0, PILOTIS), "concreto_escuro")
        p.caixa((0, 0, PILOTIS + ANDAR * prontos * 0.5), (W, D, ANDAR * prontos), "pintura")
    if prontos == ANDARES:
        p.caixa((0, 0, TOPO + 0.45), (W, D, 0.9), "pintura")
        cornija(p, W, D, TOPO + 0.9)
        p.caixa((0, -1.5, TOPO + 2.4), (5.0, 4.0, 3.0), "concreto")
        p.caixa((0, -1.5, TOPO + 4.9), (3.2, 3.2, 2.0), "caixa_dagua")
        p.caixa((4.5, 2.0, TOPO + 2.9), (0.12, 0.12, 4.0), "grade")  # antena
    else:
        esqueleto(p, W, D, PILOTIS, ANDAR, ANDARES, prontos)
        if lona is not None:
            andaime_e_lona(p, rng, W, D, TOPO, lona)

    frente, esquerda, direita = paredes(W, D)
    # Pilotis: pilares nos cantos e no meio, a portaria de vidro e uma loja de
    # cada lado dela, no plano recuado. O toldo sai de baixo da primeira
    # varanda e passa um pouco da linha dos pilares: e o terreo de qualquer
    # predio alto de Copacabana.
    if prontos > 0:
        for s in (-W * 0.5 + 0.4, -W / 6.0, W / 6.0, W * 0.5 - 0.4):
            frente.caixa(p, s, PILOTIS * 0.5, 0.8, 0.8, PILOTIS, "concreto", recuo=0.8)
        frente.placa(p, 0.0, 1.5, 3.0, 2.8, "vitrine", -1.0 + CAMADA)
        for lado in (-1.0, 1.0):
            s = lado * (W / 6.0 + W * 0.5 - 0.4) * 0.5
            vao_de_loja(p, frente, s, 3.4, 2.9, porta_aco=lado > 0.0 and rng.random() < 0.5, fora=-1.0)
            letreiro(p, frente, s, 3.8, 3.6, fora=-1.0)
            toldo(p, frente, s, 3.8, 3.15, saida=1.9, fora=-1.0)

    vaos_frente = colunas(5, W, 0.8)
    for andar in range(prontos):
        z = PILOTIS + andar * ANDAR
        # Varanda corrida: laje, guarda-corpo cheio e a porta de vidro atras.
        frente.caixa(p, 0.0, z + 0.1, W - 0.6, 1.2, 0.2, "concreto")
        guarda = frente.ponto(0.0, z + 0.7, 1.15)
        p.caixa(guarda, (W - 0.6, 0.1, 1.0), "friso")
        for s in vaos_frente:
            frente.placa(p, s, z + 1.4, 2.0, 2.3, "caixilho", CAMADA)
            frente.placa(p, s, z + 1.4, 1.8, 2.1, vidro_sorteado(rng, chance=0.25), CAMADA * 2)
        for lado in (esquerda, direita):
            lado.caixa(p, 0.0, z + 0.05, D, 0.08, 0.22, "friso")
            for s in colunas(4, D, 1.0):
                lado.janela(p, s, z + 1.0, 1.2, 1.3, vidro_sorteado(rng, claro="cortina"), peitoril="friso")
    return p


# --- Obra e guindaste (V17a) -----------------------------------------------
#
# `04_vertical`: um predio de 20 andares no concreto cru, sem fachada, com dois
# guindastes de torre amarelos; `03_viaduto`: um guindaste ao fundo, atras do
# muro. E a silhueta que diz "cidade crescendo", e um marco alto que se ve de
# longe. O esqueleto e a `torre` com menos andares prontos; o guindaste sao
# pecas repetiveis, e quem decide a altura e o comprimento da lanca e o jogo.

GUINDASTE_TRECHO = 3.0
GUINDASTE_LANCA = 4.0
CONTRAPESO = 8.0


ANDAIME_FORA = 1.2


def andaime_e_lona(p, rng, W, D, TOPO, lona) -> None:
    """Andaime tubular na frente e nos dois lados, com lona por cima.

    O andaime sai 1,2 m da parede e a lona 8 cm alem dele, em paineis de uma
    baia por tres andares com falhas sorteadas: lona inteira vira caixa
    colorida, e as falhas deixam ver o concreto por tras. Os dois andares de
    cima ficam sem lona, que e como a obra real termina: a tela sobe atras do
    pedreiro. Sem tapume nem marquise na calcada: tampa de madeira de 2,4 m
    escondia o andaime do chao, que e justamente o que le "obra" de perto.
    """
    F = ANDAIME_FORA
    X0, Y0 = W * 0.5 + F, D * 0.5 + F
    ALTURA = TOPO + 2.0
    NIVEL = 4.0
    niveis = [2.0 + NIVEL * i for i in range(int((TOPO - 2.0) // NIVEL) + 1)]

    def espaco(a, b, n):
        return [a + (b - a) * i / (n - 1) for i in range(n)]

    frente_x = espaco(-X0, X0, 7)
    lado_y = espaco(-D * 0.5, Y0, 5)
    # Montantes: um tubo inteiro por prumada, do chao ate acima do topo.
    for x in frente_x:
        p.caixa((x, Y0, ALTURA * 0.5), (0.1, 0.1, ALTURA), "aluminio")
    for lado in (-1.0, 1.0):
        for y in lado_y[:-1]:
            p.caixa((lado * X0, y, ALTURA * 0.5), (0.1, 0.1, ALTURA), "aluminio")
    for z in niveis:
        # Travessas e o piso de tabua de cada nivel.
        p.caixa((0, Y0, z), (X0 * 2.0, 0.08, 0.08), "aluminio")
        p.caixa((0, D * 0.5 + F * 0.5, z - 0.06), (X0 * 2.0, F, 0.05), "madeira")
        for lado in (-1.0, 1.0):
            p.caixa((lado * X0, (Y0 - D * 0.5) * 0.5, z), (0.08, D + F, 0.08), "aluminio")
            p.caixa((lado * (W * 0.5 + F * 0.5), (Y0 - D * 0.5) * 0.5, z - 0.06), (F, D + F, 0.05), "madeira")
    # Diagonais, uma baia sim e outra nao, alternando o sentido.
    baia = frente_x[1] - frente_x[0]
    ang = math.degrees(math.atan2(baia, NIVEL))
    comprimento = math.hypot(baia, NIVEL) - 0.14
    for i, z in enumerate(niveis[:-1]):
        for b in range(len(frente_x) - 1):
            if (b + i) % 2 == 0:
                x = (frente_x[b] + frente_x[b + 1]) * 0.5
                p.caixa((x, Y0, z + NIVEL * 0.5), (0.06, 0.06, comprimento), "aluminio",
                        rot_y=ang if b % 2 == 0 else -ang)
    baia_y = lado_y[1] - lado_y[0]
    ang_y = math.degrees(math.atan2(baia_y, NIVEL))
    comp_y = math.hypot(baia_y, NIVEL) - 0.14
    for i, z in enumerate(niveis[:-1]):
        for b in range(len(lado_y) - 1):
            if (b + i) % 2 == 1:
                y = (lado_y[b] + lado_y[b + 1]) * 0.5
                for lado in (-1.0, 1.0):
                    p.caixa((lado * X0, y, z + NIVEL * 0.5), (0.06, 0.06, comp_y), "aluminio",
                            rot_x=ang_y if b % 2 == 0 else -ang_y)

    # Lona: paineis de uma baia por tres andares, com falhas.
    bloco = 9.0
    z = 2.0
    ate = TOPO - 2 * 3.0
    while z < ate:
        z1 = min(z + bloco, ate)
        for b in range(len(frente_x) - 1):
            if rng.random() < 0.18:
                continue
            origem = Vector((frente_x[b], Y0 + 0.08, z))
            painel_de_lona(p, rng, origem, Vector((frente_x[b + 1] - frente_x[b], 0, 0)), z1 - z, Vector((0, 1, 0)), lona)
        for lado in (-1.0, 1.0):
            for b in range(len(lado_y) - 1):
                if rng.random() < 0.18:
                    continue
                origem = Vector((lado * (X0 + 0.08), lado_y[b], z))
                painel_de_lona(p, rng, origem, Vector((0, lado_y[b + 1] - lado_y[b], 0)), z1 - z, Vector((lado, 0, 0)), lona)
        z = z1


LONA_GRADE = (6, 8)


def painel_de_lona(p, rng, origem, eixo_u, altura, normal, cor) -> None:
    """Um painel de lona amarrado nos quatro cantos, com barriga e dobra.

    Uma lona lisa e plana le como adesivo colado no andaime. Esta e uma malha
    de 6 x 8 quadros presa nas quatro bordas (deslocamento zero) que incha
    para fora no meio, como vento enchendo o pano, com dobras verticais por
    cima - o pano cai em pregas entre as amarras. O deslocamento e sempre para
    fora, para nunca entrar no andaime. As faces sao duras (o predio e chapa),
    e e a quina entre elas que da luz e sombra ao volume.
    """
    nu, nv = LONA_GRADE
    barriga = rng.uniform(0.15, 0.40)
    dobras = rng.choice((2, 3))
    fase = rng.uniform(0.0, math.tau)
    prega = rng.uniform(0.05, 0.10)

    def ponto(i, j):
        u, v = i / nu, j / nv
        borda = math.sin(math.pi * u) * math.sin(math.pi * v)
        fora = barriga * borda ** 0.8 + prega * math.sin(math.tau * dobras * u + fase) * borda
        return origem + eixo_u * u + Vector((0, 0, altura * v)) + normal * max(fora, 0.0)

    for i in range(nu):
        for j in range(nv):
            p.face((ponto(i, j), ponto(i + 1, j), ponto(i + 1, j + 1), ponto(i, j + 1)), normal, cor)


def esqueleto(p, W, D, PILOTIS, ANDAR, ANDARES, prontos) -> None:
    """Laje, pilar e o miolo do elevador dos andares que ainda nao tem fachada.

    O pilar so sobe ate a laje de cima, e cada laje tem um guarda-corpo de
    tela verde nas tres bordas: sao as duas coisas que a 640x360 separam
    esqueleto de obra de ruina - o resto e cinza sobre cinza.
    """
    xs = (-W * 0.5 + 0.5, -W / 6.0, W / 6.0, W * 0.5 - 0.5)
    ys = (-D * 0.5 + 0.5, 0.0, D * 0.5 - 0.5)
    TOPO = PILOTIS + ANDAR * ANDARES
    base = PILOTIS + ANDAR * prontos if prontos > 0 else 0.0
    if prontos == 0:
        # Sem andar pronto nao ha pilotis: o terreo tambem e so pilar e laje.
        for x in xs:
            for y in ys:
                p.caixa((x, y, (PILOTIS - 0.3) * 0.5), (0.7, 0.7, PILOTIS - 0.3), "concreto")
        p.caixa((0, 0, PILOTIS - 0.15), (W, D, 0.3), "concreto")
    for k in range(prontos, ANDARES):
        z = PILOTIS + k * ANDAR
        for x in xs:
            for y in ys:
                p.caixa((x, y, z + (ANDAR - 0.3) * 0.5), (0.7, 0.7, ANDAR - 0.3), "concreto")
        topo_da_laje = z + ANDAR
        p.caixa((0, 0, topo_da_laje - 0.15), (W, D, 0.3), "concreto")
        if k < ANDARES - 1:
            p.caixa((0, D * 0.5, topo_da_laje + 0.55), (W, 0.06, 1.1), "persiana")
            for lado in (-1.0, 1.0):
                p.caixa((lado * W * 0.5, 0, topo_da_laje + 0.55), (0.06, D, 1.1), "persiana")
    # O miolo sobe a frente da laje, para ler como "ja foi concretado".
    p.caixa((-3.0, 1.0, (base + TOPO + 3.0) * 0.5), (4.0, 5.0, TOPO + 3.0 - base), "concreto_escuro")
    # Ferro de espera no topo dos pilares.
    for x in xs:
        for y in ys:
            p.caixa((x, y, TOPO + 0.8), (0.1, 0.1, 1.6), "grade")


def mastro() -> Peca:
    """Um trecho do mastro do guindaste: 2 x 2 x 3 m, origem no pe.

    Quatro montantes e uma diagonal em cada face. Empilhado pelo jogo: a
    altura do guindaste e quantos trechos ele leva, e nao uma escala, que
    esticaria a treliça e mudaria a espessura do perfil.
    """
    p = Peca("GuindasteMastro")
    L, H = 2.0, GUINDASTE_TRECHO
    m = L * 0.5 - 0.08
    for x in (-m, m):
        for y in (-m, m):
            p.caixa((x, y, H * 0.5), (0.16, 0.16, H), "guindaste")
    diag = math.hypot(2 * m, H) - 0.14  # as pontas nao passam do trecho
    ang = math.degrees(math.atan2(2 * m, H))
    for y in (-m, m):
        p.caixa((0, y, H * 0.5), (0.08, 0.08, diag), "guindaste", rot_y=ang)
    for x in (-m, m):
        p.caixa((x, 0, H * 0.5), (0.08, 0.08, diag), "guindaste", rot_x=-ang)
    for z in (0.05, H - 0.05):
        for y in (-m, m):
            p.caixa((0, y, z), (2 * m, 0.1, 0.1), "guindaste")
        for x in (-m, m):
            p.caixa((x, 0, z), (0.1, 2 * m, 0.1), "guindaste")
    return p


def lanca() -> Peca:
    """Um trecho de lança: 4 m ao longo de +X, 1 m de altura, origem no pe."""
    p = Peca("GuindasteLanca")
    C = GUINDASTE_LANCA
    for y in (-0.5, 0.5):
        p.caixa((C * 0.5, y, 0.06), (C, 0.12, 0.12), "guindaste")
    p.caixa((C * 0.5, 0, 1.0), (C, 0.12, 0.12), "guindaste")
    diag = math.hypot(C * 0.5, 0.95) - 0.14  # as pontas nao passam do trecho
    ang = math.degrees(math.atan2(C * 0.5, 0.95))
    for y in (-0.25, 0.25):
        p.caixa((C * 0.25, y, 0.5), (0.07, 0.07, diag), "guindaste", rot_y=ang)
        p.caixa((C * 0.75, y, 0.5), (0.07, 0.07, diag), "guindaste", rot_y=-ang)
    return p


def topo_do_guindaste() -> Peca:
    """O que gira no alto do mastro: cabine, torre em A e a contra-lança.

    Origem no centro do mastro, na altura da junta. A lança sai para +X e a
    contra-lança para -X, com os blocos de concreto na ponta: sem eles o
    guindaste lê como gancho no ar.
    """
    p = Peca("GuindasteTopo")
    p.caixa((0, 0, 0.3), (2.2, 2.2, 0.6), "guindaste")
    p.caixa((1.6, -1.5, 1.4), (1.4, 1.6, 1.8), "vidro")
    apice, perna = 7.0, 1.0
    comprimento = math.hypot(perna, apice - 0.6)
    ang = math.degrees(math.atan2(perna, apice - 0.6))
    for lado, sinal in ((-1.0, 1.0), (1.0, -1.0)):
        p.caixa((lado * perna * 0.5, 0, 0.6 + (apice - 0.6) * 0.5), (0.2, 0.2, comprimento), "guindaste", rot_y=sinal * ang)
    p.caixa((0, 0, apice + 0.2), (0.4, 0.4, 0.4), "guindaste")
    # Contra-lança: duas longarinas e a ponta com contrapeso.
    for y in (-0.4, 0.4):
        p.caixa((-CONTRAPESO * 0.5, y, 0.1), (CONTRAPESO, 0.12, 0.12), "guindaste")
    p.caixa((-CONTRAPESO * 0.5, 0, 0.65), (CONTRAPESO, 0.12, 0.12), "guindaste")
    for i in range(3):
        p.caixa((-CONTRAPESO + 0.5 + i * 0.9, 0, -0.5), (0.8, 1.6, 1.0), "concreto_escuro")
    return p


def gancho() -> Peca:
    """Carrinho, cabo e moitao pendurados na lança: origem no carrinho."""
    p = Peca("GuindasteGancho")
    p.caixa((0, 0, -0.1), (0.8, 1.0, 0.3), "guindaste")
    p.caixa((0, 0, -4.0), (0.05, 0.05, 7.6), "grade")
    p.caixa((0, 0, -8.0), (0.5, 0.5, 0.6), "guindaste")
    return p


# --- Texturas ----------------------------------------------------------------


def textura(nome, canal, colorspace) -> bpy.types.Image:
    img = bpy.data.images.new(nome, TEXTURA, TEXTURA, alpha=False)
    img.colorspace_settings.name = colorspace
    px = [0.0] * (TEXTURA * TEXTURA * 4)
    por_linha = TEXTURA // CELULA
    for i, valores in enumerate(PALETA.values()):
        cor = valores[canal]
        cx, cy = (i % por_linha) * CELULA, (i // por_linha) * CELULA
        for y in range(cy, cy + CELULA):
            for x in range(cx, cx + CELULA):
                k = (y * TEXTURA + x) * 4
                px[k : k + 4] = (*cor, 1.0)
    for k in range(3, len(px), 4):
        px[k] = 1.0
    img.pixels = px
    img.filepath_raw = os.path.join(SAIDA, nome + ".png")
    img.file_format = "PNG"
    img.save()
    img.pack()
    return img


def material(albedo) -> bpy.types.Material:
    mat = bpy.data.materials.new("predios")
    if mat.node_tree is None:
        mat.use_nodes = True
    mat.use_backface_culling = True
    nos = mat.node_tree.nodes
    bsdf = next(n for n in nos if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Roughness"].default_value = 0.9
    tex = nos.new("ShaderNodeTexImage")
    tex.image = albedo
    tex.interpolation = "Closest"
    mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    return mat


def material_da_lona(nome, cor) -> bpy.types.Material:
    """Lona: cor lisa com alpha. Fosca e sem brilho, que pano nao reflete sol."""
    mat = bpy.data.materials.new(nome)
    if mat.node_tree is None:
        mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*cor, 1.0)
    bsdf.inputs["Roughness"].default_value = 1.0
    bsdf.inputs["Alpha"].default_value = LONA_ALFA
    for nome_enum in ("blend_method",):
        if hasattr(mat, nome_enum):
            try:
                setattr(mat, nome_enum, "BLEND")
            except (TypeError, AttributeError):
                pass
    mat.use_backface_culling = False
    return mat


# --- Execucao ----------------------------------------------------------------


def limpa_cena() -> None:
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj)
    for colecao in (bpy.data.meshes, bpy.data.materials, bpy.data.images, bpy.data.collections):
        for item in list(colecao):
            colecao.remove(item)


def main() -> None:
    assert len(PALETA) <= (TEXTURA // CELULA) ** 2, "paleta nao cabe na textura"
    os.makedirs(SAIDA, exist_ok=True)
    limpa_cena()

    colecao = bpy.data.collections.new("Predios")
    bpy.context.scene.collection.children.link(colecao)

    albedo = textura("predios_albedo", 0, "sRGB")
    textura("predios_mascara", 1, "Non-Color")
    mat = material(albedo)

    # Um sorteio por modelo, cada um com a sua semente: mexer no sobrado nao
    # muda o vidro do comercio. A semente e a da ordem em que o modelo nasceu,
    # e nao a posicao na lista: o Deco entrou no meio e ficou com a 4, para o
    # vidro do Escritorio e da Torre nao mudar com ele.
    x = 0.0
    objetos = []
    for fabrica, n in ((sobrado, 0), (comercio, 1), (deco, 4), (escritorio, 2), (torre, 3)):
        peca = fabrica(random.Random(SEMENTE + n))
        obj = peca.objeto(mat, colecao, x)
        objetos.append(obj)
        x += 22.0

    # A obra e o guindaste, com semente propria: nada do que veio antes muda.
    # O esqueleto fica na planta da `Torre` (so o corpo, sem a cornija), e a
    # meia-obra tem a metade de baixo vestida.
    # Quatro obras: esqueleto ou meia-obra, com lona laranja ou azul.
    for prontos, fase, n in ((0, "Esqueleto", 5), (ANDARES_DA_TORRE // 2, "Fachada", 6)):
        for lona, cor in (("Laranja", "lona_laranja"), ("Azul", "lona_azul")):
            nome = "Obra" + fase + lona
            peca = torre(random.Random(SEMENTE + n), prontos=prontos, nome=nome, lona=cor)
            mat_lona = material_da_lona(nome + "Lona", PALETA[cor][0])
            objetos.append(peca.objeto(mat, colecao, x, material_lona=mat_lona))
            x += 22.0
    for fabrica in (mastro, lanca, topo_do_guindaste, gancho):
        objetos.append(fabrica().objeto(mat, colecao, x))
        x += 22.0

    for obj in bpy.data.objects:
        obj.select_set(obj in objetos)
    bpy.context.view_layer.objects.active = objetos[0]

    bpy.ops.wm.save_as_mainfile(filepath=BLEND, relative_remap=True)
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(SAIDA, "predios.glb"),
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_apply=False,
        export_animations=False,
        export_cameras=False,
        export_lights=False,
        export_all_vertex_colors=False,
        export_extras=False,
    )
    for obj in objetos:
        tris = len(obj.data.polygons)
        dims = obj.dimensions
        print("%s: %d tris, %.1f x %.1f x %.1f m" % (obj.name, tris, dims.x, dims.y, dims.z))


main()
