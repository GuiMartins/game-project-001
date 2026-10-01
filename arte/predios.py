"""Gerador dos predios: quatro modelos de rua carioca, de alturas e larguras diferentes.

Roda dentro do Blender (5.2+), igual ao entregador:

    blender --background --factory-startup --python arte/predios.py

Apaga a cena, monta os quatro, salva `arte/predios.blend` e exporta
`assets/predios/predios.glb` mais as duas texturas. Mesma receita, mesmo
`.glb`, byte a byte: este script e a fonte, o resto e build.

Os quatro, do mais baixo ao mais alto, cada um tirado de um pedaco das
referencias:

| no           | largura x fundo x altura | de onde vem                                  |
| ------------ | ------------------------ | -------------------------------------------- |
| `Sobrado`    | 10 x 11 x 12,8 m         | o casario do Centro: portas em arco, sacada   |
| `Comercio`   | 13 x 10 x 18,8 m         | loja com toldo embaixo, apartamento em cima,  |
|              |                          | empena cega com mural                         |
| `Escritorio` | 12 x 12 x 43,5 m         | a torre de vidro azul do fundo da avenida     |
| `Torre`      | 15 x 13 x 58,8 m         | o residencial de concreto com varanda corrida |

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

import bmesh
import bpy
from mathutils import Matrix, Vector

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLEND = os.path.join(RAIZ, "arte", "predios.blend")
SAIDA = os.path.join(RAIZ, "assets", "predios")

# A mesma do mundo (`World.SEMENTE`): qual vidro reflete o ceu, onde tem ar
# condicionado e o desenho do mural saem dela, e regerar da o mesmo modelo.
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

TEXTURA = 256
CELULA = 32

PAREDE, LOJA = (1, 0, 0), (0, 1, 0)
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
    # O mural da empena. Cor cheia de proposito: e a unica coisa do mundo que
    # pode competir com a bag em saturacao, e fica longe da pista.
    "mural_rosa": ((0.90, 0.38, 0.62), NADA),
    "mural_verde": ((0.16, 0.62, 0.40), NADA),
    "mural_amarelo": ((0.97, 0.78, 0.18), NADA),
    "mural_azul": ((0.20, 0.48, 0.86), NADA),
    "mural_laranja": ((0.95, 0.48, 0.16), NADA),
    "mural_roxo": ((0.48, 0.28, 0.70), NADA),
}
CELULAS = {nome: i for i, nome in enumerate(PALETA)}
MURAL = [nome for nome in PALETA if nome.startswith("mural_")]

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

    def caixa(self, centro, tamanho, cor, rot_x=0.0) -> None:
        verts = bmesh.ops.create_cube(self.bm, size=1.0)["verts"]
        for v in verts:
            v.co.x *= tamanho[0]
            v.co.y *= tamanho[1]
            v.co.z *= tamanho[2]
        m = Matrix.Translation(Vector(centro)) @ Matrix.Rotation(math.radians(rot_x), 4, "X")
        bmesh.ops.transform(self.bm, matrix=m, verts=verts)
        for face in {f for v in verts for f in v.link_faces}:
            face[self.cor] = CELULAS[cor]

    def face(self, pontos, normal, cor) -> None:
        """Poligono convexo, virado para `normal`."""
        verts = [self.bm.verts.new(Vector(p)) for p in pontos]
        f = self.bm.faces.new(verts)
        f.normal_update()
        if f.normal.dot(Vector(normal)) < 0.0:
            f.normal_flip()
        f[self.cor] = CELULAS[cor]

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

    def objeto(self, material, colecao, x_no_blend) -> bpy.types.Object:
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
        for face in bm.faces:
            ponto = uv_da_celula(face[self.cor])
            for loop in face.loops:
                loop[uv].uv = ponto
            # Predio e chapa: tudo duro. Liso, a quina vira degrade e a caixa
            # vira sabonete.
            face.smooth = False
        bm.faces.layers.int.remove(self.cor)

        malha = bpy.data.meshes.new(self.nome)
        bm.to_mesh(malha)
        bm.free()
        malha.materials.append(material)

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
        # Terreo: porta alta de madeira com bandeira em arco. O vao do meio e
        # loja, com vitrine no lugar da madeira.
        miolo = "vitrine" if i == 1 else "madeira"
        frente.placa(p, s, 1.6, 1.6, 3.2, miolo, CAMADA * 3)
        frente.arco(p, s, 3.2, 1.0, "friso", CAMADA * 2)
        frente.arco(p, s, 3.2, 0.8, miolo, CAMADA * 3)
        frente.placa(p, s, 1.65, 2.0, 3.3, "friso", CAMADA * 2)

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
# condicionado pendurado, e a empena cega pintada de mural (referencia 1).


def comercio(rng) -> Peca:
    p = Peca("Comercio")
    W, D = 13.0, 10.0
    LOJA_ALTURA, ANDAR, ANDARES = 4.4, 3.0, 4
    TOPO = LOJA_ALTURA + ANDAR * ANDARES
    p.caixa((0, 0, (TOPO + 1.0) * 0.5), (W, D, TOPO + 1.0), "pintura")
    p.caixa((0, 0, TOPO + 1.0), (W + 0.2, D + 0.2, 0.2), "friso")
    p.caixa((0, 0, LOJA_ALTURA * 0.5), (W + 0.06, D + 0.06, LOJA_ALTURA), "pintura_sombra")
    p.caixa((2.5, -1.5, TOPO + 2.2), (2.4, 2.4, 2.2), "caixa_dagua")

    frente, esquerda, direita = paredes(W, D)

    # Loja: duas vitrines e uma porta de aco de enrolar. As ranhuras da porta
    # sao horizontais e grossas: atravessadas na pista seriam chuvisco, mas
    # aqui correm junto com a pista, de lado.
    for s in (-4.1, 0.6):
        frente.placa(p, s, 1.6, 3.6, 3.0, "caixilho", CAMADA)
        frente.placa(p, s, 1.6, 3.3, 2.8, "vitrine", CAMADA * 2)
    frente.placa(p, 4.7, 1.6, 2.8, 3.2, "porta_aco", CAMADA)
    for k in range(5):
        frente.placa(p, 4.7, 0.4 + k * 0.6, 2.8, 0.08, "caixilho", CAMADA * 2)
    # Letreiro: placa clara com faixa na cor da loja. Sem texto - nome de loja
    # e marca, e marca o PROTOTIPO.md deixou de fora.
    frente.caixa(p, 0.0, 4.0, W - 0.6, 0.3, 0.8, "letreiro")
    frente.caixa(p, 0.0, 3.68, W - 0.6, 0.32, 0.16, "toldo")
    # Toldo listrado, caindo para a rua. Listra de 1,5 m: larga o bastante
    # para nao virar chuvisco quando passa no canto da tela.
    listras = 8
    largura_listra = (W - 1.0) / listras
    for k in range(listras):
        s = -(W - 1.0) * 0.5 + largura_listra * (k + 0.5)
        centro = frente.ponto(s, 3.05, 0.85)
        cor = "toldo" if k % 2 == 0 else "toldo_listra"
        p.caixa(centro, (largura_listra, 1.8, 0.06), cor, rot_x=-22.0)

    for andar in range(ANDARES):
        z = LOJA_ALTURA + andar * ANDAR
        frente.caixa(p, 0.0, z + 0.05, W + 0.1, 0.12, 0.2, "friso")
        for s in colunas(4, W, 0.6):
            frente.janela(p, s, z + 0.9, 1.5, 1.6, vidro_sorteado(rng, claro="cortina"), peitoril="friso")
            # Ar condicionado de janela: o volume que mais diz "Rio" numa
            # fachada, e uma sombrinha a mais.
            if rng.random() < 0.35:
                frente.caixa(p, s + 0.45, z + 0.55, 0.65, 0.45, 0.42, "ar_condicionado")

    # Empena cega: os dois lados sao mural, porque o lado que a camera ve
    # chegando depende de que lado da pista o predio cai.
    for lado in (esquerda, direita):
        mural(p, lado, rng, LOJA_ALTURA + 0.4, TOPO + 0.6)
    return p


def mural(p, parede, rng, z0, z1) -> None:
    """Grafite de formas grandes: fundo de uma cor e manchas por cima.

    Nada de desenho fino: a 640x360 o mural le como blocos de cor saturada, e
    e exatamente o que as referencias mostram de longe. Cada forma fica uma
    camada mais para fora que a anterior, para nao brigar no z-buffer.
    """
    meia = parede.largura * 0.5 - 0.4
    cores = MURAL[:]
    rng.shuffle(cores)
    parede.placa(p, 0.0, (z0 + z1) * 0.5, meia * 2.0, z1 - z0, cores[0], CAMADA)
    for k in range(7):
        cor = cores[1 + k % (len(cores) - 1)]
        raio = rng.uniform(1.2, 3.0)
        cs = rng.uniform(-meia + raio * 0.6, meia - raio * 0.6)
        cz = rng.uniform(z0 + raio * 0.6, z1 - raio * 0.6)
        lados = rng.choice((3, 4, 8))
        giro = rng.uniform(0.0, math.tau)
        pontos = []
        for i in range(lados):
            a = giro + math.tau * i / lados
            # Folha: o losango e esticado num eixo, o resto fica regular.
            esticado = 1.6 if lados == 4 and i % 2 == 0 else 1.0
            ds = math.cos(a) * raio * esticado
            dz = math.sin(a) * raio * esticado
            ds = max(-meia - cs, min(meia - cs, ds))
            dz = max(z0 - cz, min(z1 - cz, dz))
            pontos.append(parede.ponto(cs + ds, cz + dz, CAMADA * (2 + k)))
        p.face(pontos, parede.n, cor)


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


def torre(rng) -> Peca:
    p = Peca("Torre")
    W, D = 15.0, 13.0
    PILOTIS, ANDAR, ANDARES = 4.0, 3.0, 16
    TOPO = PILOTIS + ANDAR * ANDARES
    p.caixa((0, 0, PILOTIS * 0.5), (W - 2.0, D - 2.0, PILOTIS), "concreto_escuro")
    p.caixa((0, 0, PILOTIS + ANDAR * ANDARES * 0.5), (W, D, ANDAR * ANDARES), "pintura")
    p.caixa((0, 0, TOPO + 0.45), (W + 0.3, D + 0.3, 0.9), "friso")
    p.caixa((0, -1.5, TOPO + 2.4), (5.0, 4.0, 3.0), "concreto")
    p.caixa((0, -1.5, TOPO + 4.9), (3.2, 3.2, 2.0), "caixa_dagua")
    p.caixa((4.5, 2.0, TOPO + 2.9), (0.12, 0.12, 4.0), "grade")  # antena

    frente, esquerda, direita = paredes(W, D)
    # Pilotis: pilares nos cantos e no meio, e a portaria de vidro.
    for s in (-W * 0.5 + 0.4, -W / 6.0, W / 6.0, W * 0.5 - 0.4):
        frente.caixa(p, s, PILOTIS * 0.5, 0.8, 0.8, PILOTIS, "concreto", recuo=0.8)
    frente.placa(p, 0.0, 1.5, 3.0, 2.8, "vitrine", -1.0 + CAMADA)

    vaos_frente = colunas(5, W, 0.8)
    for andar in range(ANDARES):
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
    # muda o mural do comercio.
    x = 0.0
    objetos = []
    for i, fabrica in enumerate((sobrado, comercio, escritorio, torre)):
        peca = fabrica(random.Random(SEMENTE + i))
        obj = peca.objeto(mat, colecao, x)
        objetos.append(obj)
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
