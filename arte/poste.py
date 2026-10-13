"""Gerador do poste de dois bracos da avenida.

Roda dentro do Blender (5.2+), igual aos outros:

    blender --background --factory-startup --python arte/poste.py

Apaga a cena, monta o poste, salva `arte/poste.blend` e exporta
`assets/poste/poste.glb`. Mesma receita, mesmo `.glb`.

O poste e o do video (REFERENCIA_VIDEO.md, "Como o video vende velocidade"):
ornamental, de ferro pintado, 9 m, com dois bracos em pescoco de cisne e uma
luminaria pendurada na ponta de cada um. Um braco vai por cima da pista e o
outro por cima da calcada. E o referencial de velocidade mais limpo do video
porque o braco passa **por cima** da camera: a coluna corre no canto da tela,
o braco risca o topo dela.

Convencoes, as mesmas do `predios.py`:

- **Metro, Z para cima, o braco da pista em +Y.** O exportador glTF poe +Y em
  -Z: no Godot o poste "olha" para -Z, e quem o coloca aponta -Z para a pista.
- **Origem no chao, no eixo da coluna.** O pedestal desce meio metro abaixo
  dela, para o poste nao ficar com o pe no ar onde a calcada sobe no meio-fio.

O que importa a 640x360 e a silhueta, nao o ornamento: o braco tem 14 cm de
grossura, o dobro do de verdade, porque o de verdade a 20 m da camera tem
menos de um pixel e pisca em vez de passar. Pelo mesmo motivo nao tem voluta
de ferro fundido - so o pedestal, o anel e a escora, que leem como "poste
antigo" ate de longe.
"""

import math
import os

import bmesh
import bpy
from mathutils import Vector

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLEND = os.path.join(RAIZ, "arte", "poste.blend")
SAIDA = os.path.join(RAIZ, "assets", "poste")

# Verde-garrafa quase preto, o do ferro pintado da orla. Escuro de proposito:
# contra o ceu claro e a fachada creme, e a silhueta que marca a passagem.
FERRO = (0.10, 0.15, 0.13)
# O globo da luminaria. Leitoso, e nao aceso: e dia, e o glow da V12 e so para
# o que e luz. Claro o bastante para a ponta do braco ser um ponto no ceu.
GLOBO = (0.86, 0.86, 0.80)

# Oito lados na coluna e no pedestal, seis no braco. Mais que isso nao aparece
# a 640x360, e o poste se repete a cada 25 m da avenida inteira.
LADOS_COLUNA = 8
LADOS_BRACO = 6

ALTURA = 9.0
# Onde os bracos saem da coluna, e o desenho de cada um em (para fora, altura):
# sobe saindo da coluna, faz a curva e cai na ponta, onde pendura a luminaria.
# A ponta fica a 2,6 m da coluna - com o poste a 0,8 m do meio-fio, o globo da
# pista fica sobre a faixa da direita, onde a moto anda.
BRACO = [(0.0, 7.4), (0.35, 7.85), (0.9, 8.3), (1.6, 8.55), (2.2, 8.5), (2.6, 8.3)]
RAIO_BRACO = 0.07


class Peca:
    """Uma malha em construcao, com o material gravado por face."""

    def __init__(self, nome: str) -> None:
        self.nome = nome
        self.bm = bmesh.new()

    def _face(self, verts, fora, material) -> None:
        """Poligono virado para longe de `fora` - o ponto de dentro."""
        f = self.bm.faces.new(verts)
        f.normal_update()
        if f.normal.dot(f.calc_center_median() - fora) < 0.0:
            f.normal_flip()
        f.material_index = material
        # Ferro redondo: liso. A quina so aparece onde ha degrau de raio, e
        # ali o anel e face propria.
        f.smooth = True

    def torno(self, centro, perfil, lados, material) -> None:
        """Solido de revolucao em torno do eixo vertical por `centro`.

        `perfil` e uma lista de (altura, raio) de baixo para cima. Raio zero
        fecha num ponto; dois pontos na mesma altura fazem um degrau.
        """
        c = Vector(centro)
        aneis = []
        for dz, r in perfil:
            if r == 0.0:
                aneis.append([self.bm.verts.new(c + Vector((0.0, 0.0, dz)))])
                continue
            aneis.append(
                [
                    self.bm.verts.new(
                        c
                        + Vector(
                            (
                                r * math.cos(2.0 * math.pi * i / lados),
                                r * math.sin(2.0 * math.pi * i / lados),
                                dz,
                            )
                        )
                    )
                    for i in range(lados)
                ]
            )
        for k in range(len(aneis) - 1):
            a, b = aneis[k], aneis[k + 1]
            eixo = c + Vector((0.0, 0.0, (perfil[k][0] + perfil[k + 1][0]) * 0.5))
            for i in range(lados):
                j = (i + 1) % lados
                if len(a) == 1:
                    verts = [a[0], b[i], b[j]]
                elif len(b) == 1:
                    verts = [a[i], a[j], b[0]]
                else:
                    verts = [a[i], a[j], b[j], b[i]]
                # O "dentro" de um degrau plano fica abaixo dele se o raio
                # encolhe subindo, e acima se cresce: e o lado do solido.
                if perfil[k][0] == perfil[k + 1][0]:
                    passo = 1.0 if perfil[k + 1][1] < perfil[k][1] else -1.0
                    eixo = c + Vector((0.0, 0.0, perfil[k][0] - passo * 0.1))
                self._face(verts, eixo, material)

    def tubo(self, pontos, raio, lados, material) -> None:
        """Tubo aberto ao longo de uma linha; as pontas ficam escondidas."""
        pts = [Vector(p) for p in pontos]
        aneis = []
        for k, p in enumerate(pts):
            ante = pts[max(k - 1, 0)]
            depois = pts[min(k + 1, len(pts) - 1)]
            t = (depois - ante).normalized()
            # O braco vive num plano vertical: o lado do anel e o eixo
            # horizontal desse plano, e o outro e perpendicular a ele e a `t`.
            u = t.cross(Vector((0.0, 0.0, 1.0)))
            if u.length < 1e-6:
                u = Vector((1.0, 0.0, 0.0))
            u.normalize()
            v = t.cross(u).normalized()
            aneis.append(
                [
                    self.bm.verts.new(
                        p
                        + u * (raio * math.cos(2.0 * math.pi * i / lados))
                        + v * (raio * math.sin(2.0 * math.pi * i / lados))
                    )
                    for i in range(lados)
                ]
            )
        for k in range(len(aneis) - 1):
            meio = (pts[k] + pts[k + 1]) * 0.5
            for i in range(lados):
                j = (i + 1) % lados
                self._face([aneis[k][i], aneis[k][j], aneis[k + 1][j], aneis[k + 1][i]], meio, material)

    def objeto(self, materiais, colecao) -> bpy.types.Object:
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
        colecao.objects.link(obj)
        return obj


def poste() -> Peca:
    p = Peca("Poste")
    # Pedestal, coluna afinando e o pinaculo. O anel a 3 m e o que o poste
    # antigo de verdade tem onde a coluna troca de grossura.
    p.torno(
        (0, 0, 0),
        [
            (-0.5, 0.30),
            (0.9, 0.30),
            (0.9, 0.22),
            (1.2, 0.15),
            (3.0, 0.13),
            (3.0, 0.17),
            (3.2, 0.17),
            (3.2, 0.12),
            (7.3, 0.09),
            (7.3, 0.14),
            (7.5, 0.14),
            (7.5, 0.08),
            (8.7, 0.07),
            (8.7, 0.12),
            (8.85, 0.12),
            (ALTURA, 0.0),
        ],
        LADOS_COLUNA,
        0,
    )
    for lado in (1.0, -1.0):
        braco = [(0.0, lado * y, z) for y, z in BRACO]
        p.tubo(braco, RAIO_BRACO, LADOS_BRACO, 0)
        # Escora: do anel de baixo da coluna ao meio do braco. E o triangulo
        # que faz o braco ler como ferro, e nao como galho.
        p.tubo([(0.0, 0.0, 6.4), (0.0, lado * 0.55, 7.2), (0.0, lado * 0.9, 8.3)], 0.04, LADOS_BRACO, 0)
        # Luminaria: o chapeu de ferro e o globo pendurado embaixo dele.
        y, z = BRACO[-1]
        ponta = (0.0, lado * y, z)
        p.torno(ponta, [(-0.12, 0.0), (-0.12, 0.30), (0.02, 0.10), (0.08, 0.0)], LADOS_COLUNA, 0)
        p.torno(ponta, [(-0.75, 0.0), (-0.6, 0.18), (-0.35, 0.22), (-0.12, 0.14), (-0.12, 0.0)], LADOS_COLUNA, 1)
    return p


def material(nome, cor) -> bpy.types.Material:
    mat = bpy.data.materials.new(nome)
    if mat.node_tree is None:
        mat.use_nodes = True
    mat.use_backface_culling = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    # As cores acima sao sRGB, como as dos outros geradores; o no quer linear.
    linear = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in cor]
    bsdf.inputs["Base Color"].default_value = (*linear, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.8
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
    colecao = bpy.data.collections.new("Poste")
    bpy.context.scene.collection.children.link(colecao)

    obj = poste().objeto([material("ferro", FERRO), material("globo", GLOBO)], colecao)
    for o in bpy.data.objects:
        o.select_set(o is obj)
    bpy.context.view_layer.objects.active = obj

    bpy.ops.wm.save_as_mainfile(filepath=BLEND, relative_remap=True)
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(SAIDA, "poste.glb"),
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
    dims = obj.dimensions
    print("%s: %d tris, %.1f x %.1f x %.1f m" % (obj.name, len(obj.data.polygons), dims.x, dims.y, dims.z))


main()
