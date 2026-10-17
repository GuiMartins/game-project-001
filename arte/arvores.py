"""Gerador das arvores da avenida: a palmeira e a arvore de copa larga.

Roda dentro do Blender (5.2+), igual aos outros:

    blender --background --factory-startup --python arte/arvores.py

Apaga a cena, monta as duas, salva `arte/arvores.blend` e exporta
`assets/arvores/arvores.glb`. Mesma receita, mesmo `.glb`.

As duas sao do video e das paradas (V16):

- **Palmeira** (`01_centro`, `video_01/t1.0s`): fuste fino e um pouco torto
  de uns 9 m, e um tufo de folhas compridas caindo em arco. Vai em grupo de
  duas ou tres na faixa de servico.
- **Copa** (`video_01/t2.0s`, `t3.0s`): tronco curto e uma copa redonda e
  larga, de uns 8 m, debrucada sobre a pista. E ela que poe a moto para
  passar **por baixo** de alguma coisa, o item 4 de "Como o video vende
  velocidade": a copa risca o topo da tela e escurece o quadro por um
  instante.

Convencoes, as mesmas do `poste.py`:

- **Metro, Z para cima, a pista em +Y.** O exportador glTF poe +Y em -Z: no
  Godot a arvore "olha" para -Z, e quem a planta aponta -Z para a pista. A
  copa se debruca para +Y.
- **Origem no chao, no eixo do tronco.** O tronco desce meio metro abaixo dela,
  para a arvore nao ficar com o pe no ar onde a calcada sobe.

Folha e bloco, nao folha: a 640x360 uma copa a 30 m tem uns 40 px, e o que se
le e a silhueta e duas manchas de verde, a do sol e a da sombra. Por isso a
copa e um cacho de bolas de vinte faces, em dois verdes, sem textura.
"""

import math
import os
import random

import bmesh
import bpy
from mathutils import Matrix, Vector

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLEND = os.path.join(RAIZ, "arte", "arvores.blend")
SAIDA = os.path.join(RAIZ, "assets", "arvores")

# A mesma do mundo (`World.SEMENTE`): onde cai cada bola da copa e o giro de
# cada folha da palmeira.
SEMENTE = 20260831

# sRGB, como nos outros geradores. Dois verdes na copa: a bola que pega sol e
# a de baixo, e e a diferenca entre as duas que da volume sem textura. Nenhum
# verde saturado demais: o LUT do dia ja satura.
TRONCO = (0.38, 0.29, 0.22)
CAULE = (0.56, 0.49, 0.39)
FOLHA = (0.24, 0.48, 0.18)
FOLHA_SOL = (0.38, 0.62, 0.22)
PALMA = (0.30, 0.56, 0.20)

Z = Vector((0.0, 0.0, 1.0))


class Peca:
    """Uma malha em construcao, com o material gravado por face."""

    def __init__(self, nome: str) -> None:
        self.nome = nome
        self.bm = bmesh.new()

    def _face(self, verts, fora, material, liso=False) -> None:
        """Poligono virado para longe de `fora` - o ponto de dentro."""
        f = self.bm.faces.new(verts)
        f.normal_update()
        if f.normal.dot(f.calc_center_median() - fora) < 0.0:
            f.normal_flip()
        f.material_index = material
        f.smooth = liso

    def tronco(self, pontos, raios, lados, material) -> None:
        """Tubo ao longo de `pontos`, com o raio de cada anel, fechado no topo."""
        pts = [Vector(p) for p in pontos]
        aneis = []
        for k, p in enumerate(pts):
            ante = pts[max(k - 1, 0)]
            depois = pts[min(k + 1, len(pts) - 1)]
            t = (depois - ante).normalized()
            u = t.cross(Vector((1.0, 0.0, 0.0)))
            if u.length < 1e-6:
                u = Vector((0.0, 1.0, 0.0))
            u.normalize()
            v = t.cross(u).normalized()
            r = raios[k]
            aneis.append(
                [
                    self.bm.verts.new(
                        p + u * (r * math.cos(math.tau * i / lados)) + v * (r * math.sin(math.tau * i / lados))
                    )
                    for i in range(lados)
                ]
            )
        for k in range(len(aneis) - 1):
            meio = (pts[k] + pts[k + 1]) * 0.5
            for i in range(lados):
                j = (i + 1) % lados
                self._face([aneis[k][i], aneis[k][j], aneis[k + 1][j], aneis[k + 1][i]], meio, material, liso=True)
        topo = self.bm.verts.new(pts[-1] + (pts[-1] - pts[-2]).normalized() * 0.05)
        for i in range(lados):
            self._face([aneis[-1][i], aneis[-1][(i + 1) % lados], topo], pts[-2], material, liso=True)

    def bola(self, centro, raio, achata, material) -> None:
        """Bola de vinte faces, achatada na vertical: um tufo da copa."""
        verts = bmesh.ops.create_icosphere(self.bm, subdivisions=1, radius=raio)["verts"]
        m = Matrix.Translation(Vector(centro)) @ Matrix.Diagonal((1.0, 1.0, achata, 1.0))
        bmesh.ops.transform(self.bm, matrix=m, verts=verts)
        for face in {f for v in verts for f in v.link_faces}:
            face.material_index = material
            # Facetada de proposito: a quina de cada face pega o sol de um
            # jeito, e e isso que faz o cacho ler como folhagem e nao bexiga.
            face.smooth = False

    def folha(self, base, direcao, comprimento, largura, cai, material) -> None:
        """Folha de palmeira: uma tira em arco, larga no meio, fina nas pontas.

        Fica de face para cima e para baixo (o material nao descarta o verso):
        vista de baixo, que e de onde a camera a ve, ela continua la.
        """
        d = Vector(direcao).normalized()
        lado = Z.cross(d).normalized()
        b = Vector(base)
        n = 4
        esquerda, direita = [], []
        for k in range(n + 1):
            s = k / n
            meio = b + d * (comprimento * s) + Z * (0.5 * comprimento * s - cai * s * s)
            w = largura * (0.15 + math.sin(math.pi * s)) * 0.5
            esquerda.append(self.bm.verts.new(meio + lado * w))
            direita.append(self.bm.verts.new(meio - lado * w))
        for k in range(n):
            f = self.bm.faces.new([esquerda[k], direita[k], direita[k + 1], esquerda[k + 1]])
            f.normal_update()
            if f.normal.z < 0.0:
                f.normal_flip()
            f.material_index = material
            f.smooth = False

    def objeto(self, materiais, colecao, x) -> bpy.types.Object:
        bm = self.bm
        bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method="FIXED", ngon_method="EAR_CLIP")
        # Ordem canonica das faces, como nos outros geradores: o mesmo modelo
        # sai no mesmo .glb.
        bm.faces.index_update()
        posto = [0] * len(bm.faces)
        chave = lambda f: (*(round(c, 5) for c in f.calc_center_median()), f.material_index)  # noqa: E731
        for i, face in enumerate(sorted(bm.faces, key=chave)):
            posto[face.index] = i
        bm.faces.sort(key=lambda f: posto[f.index])

        malha = bpy.data.meshes.new(self.nome)
        bm.to_mesh(malha)
        bm.free()
        for mat in materiais:
            malha.materials.append(mat)
        obj = bpy.data.objects.new(self.nome, malha)
        obj.location.x = x
        colecao.objects.link(obj)
        return obj


# --- Copa --------------------------------------------------------------------
#
# Tronco de 4 m inclinado para a pista e a copa centrada 3 m para fora
# dele: plantada na faixa de servico, 3 m depois do meio-fio, a copa cobre a
# faixa da direita inteira. A base da copa fica a 4,5 m, acima de onibus e
# caminhao bau, e a camera (a 2,25 m) passa por baixo dela.

COPA_ALTURA = 7.0
COPA_SAIDA = 3.0


def copa(rng) -> Peca:
    p = Peca("Copa")
    topo = Vector((0.0, COPA_SAIDA * 0.6, 4.2))
    p.tronco(
        [(0.0, 0.0, -0.5), (0.0, 0.0, 1.5), (0.0, COPA_SAIDA * 0.2, 3.0), topo],
        [0.28, 0.24, 0.2, 0.16],
        7,
        0,
    )
    # Dois galhos abrindo do topo do tronco: e o que se ve por baixo da copa.
    for lado in (-1.0, 1.0):
        ponta = topo + Vector((lado * 1.6, 0.6, 1.4))
        p.tronco([topo, (topo + ponta) * 0.5 + Vector((0, 0, 0.2)), ponta], [0.13, 0.1, 0.06], 5, 0)
    centro = Vector((0.0, COPA_SAIDA, COPA_ALTURA))
    # Sorteio so na posicao, nunca no numero de bolas.
    # Cheia e redonda, e nao guarda-chuva: um primeiro jeito, com uma bola so
    # em cima e um anel achatado em volta, saiu rala como cogumelo ao lado da
    # `t2.0s`. Sao tres andares: o miolo, um anel largo embaixo, na sombra, e
    # um anel menor em cima, no sol.
    p.bola(centro + Vector((0.0, 0.0, 0.8)), 3.0, 0.85, 2)
    for i in range(7):
        a = math.tau * i / 7 + rng.uniform(-0.3, 0.3)
        r = rng.uniform(2.4, 3.0)
        onde = centro + Vector((math.cos(a) * r, math.sin(a) * r * 0.85, rng.uniform(-0.6, 0.3)))
        p.bola(onde, rng.uniform(1.9, 2.4), 0.85, 1)
    for i in range(4):
        a = math.tau * (i + 0.5) / 4 + rng.uniform(-0.3, 0.3)
        onde = centro + Vector((math.cos(a) * 1.7, math.sin(a) * 1.5, 2.0 + rng.uniform(-0.2, 0.3)))
        p.bola(onde, rng.uniform(1.6, 2.0), 0.85, 2)
    return p


# --- Palmeira ----------------------------------------------------------------
#
# Palmeira imperial de avenida: fuste liso de 9 m, um pouco torto, e onze
# folhas de 3,6 m caindo em arco. O tufo fica todo acima do braco do poste do
# lado da calcada, que esta a 10 m: a 8,8 m ele passaria por dentro.

PALMEIRA_ALTURA = 9.2


def palmeira(rng) -> Peca:
    p = Peca("Palmeira")
    torto = Vector((rng.uniform(-0.4, 0.4), rng.uniform(0.0, 0.5), 0.0))
    pontos = [Vector((0.0, 0.0, -0.5))]
    raios = [0.24]
    for k in range(1, 6):
        s = k / 5
        pontos.append(Vector((0.0, 0.0, PALMEIRA_ALTURA * s)) + torto * (s * s))
        raios.append(0.22 - 0.08 * s)
    p.tronco(pontos, raios, 7, 3)
    topo = pontos[-1]
    # O palmito: o pescoco verde de onde as folhas saem.
    p.bola(topo + Vector((0.0, 0.0, 0.3)), 0.35, 1.6, 4)
    for i in range(11):
        a = math.tau * i / 11 + rng.uniform(-0.15, 0.15)
        d = Vector((math.cos(a), math.sin(a), 0.0))
        p.folha(topo + Z * 0.5, d, rng.uniform(3.2, 4.0), 1.3, rng.uniform(2.6, 3.4), 4)
    return p


def material(nome, cor, dupla=False) -> bpy.types.Material:
    mat = bpy.data.materials.new(nome)
    if mat.node_tree is None:
        mat.use_nodes = True
    mat.use_backface_culling = not dupla
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    linear = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in cor]
    bsdf.inputs["Base Color"].default_value = (*linear, 1.0)
    bsdf.inputs["Roughness"].default_value = 1.0
    bsdf.inputs["Metallic"].default_value = 0.0
    return mat


def limpa_cena() -> None:
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj)
    for colecao in (bpy.data.meshes, bpy.data.materials, bpy.data.images, bpy.data.collections):
        for item in list(colecao):
            colecao.remove(item)


def main() -> None:
    os.makedirs(SAIDA, exist_ok=True)
    limpa_cena()
    colecao = bpy.data.collections.new("Arvores")
    bpy.context.scene.collection.children.link(colecao)

    # Mesma ordem de material nas duas: o indice gravado na face e o mesmo.
    materiais = [
        material("tronco", TRONCO),
        material("folha", FOLHA),
        material("folha_sol", FOLHA_SOL),
        material("caule", CAULE),
        material("palma", PALMA, dupla=True),
    ]
    objetos = [
        copa(random.Random(SEMENTE)).objeto(materiais, colecao, 0.0),
        palmeira(random.Random(SEMENTE + 1)).objeto(materiais, colecao, 12.0),
    ]
    for o in bpy.data.objects:
        o.select_set(o in objetos)
    bpy.context.view_layer.objects.active = objetos[0]

    bpy.ops.wm.save_as_mainfile(filepath=BLEND, relative_remap=True)
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(SAIDA, "arvores.glb"),
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
        dims = obj.dimensions
        print("%s: %d tris, %.1f x %.1f x %.1f m" % (obj.name, len(obj.data.polygons), dims.x, dims.y, dims.z))


main()
