"""Gerador dos pedestres: gente parada e gente andando, para a calcada.

Roda dentro do Blender (5.2+), igual aos outros:

    blender --background --factory-startup --python arte/pedestres.py

Apaga a cena, monta as duas poses, salva `arte/pedestres.blend` e exporta
`assets/pedestres/pedestres.glb`. Mesma receita, mesmo `.glb`.

Textura de vida nos dois lados da avenida (V19; `01_centro`, `02_praca_maua`,
`video_01/t1.0s`, `t3.0s`). Sem logica nenhuma, e ninguem atravessa a pista:
sao centenas, e o `Pedestres` os desenha num `MultiMesh` por pose.

A 640x360 uma pessoa a 20 m tem uns 20 px de altura: o que se le e a camisa,
uma mancha de cor na altura do peito, a cabeca e as pernas escuras. Por isso
sao caixas, e a camisa e uma superficie propria (`roupa`), branca, que o
Godot pinta por instancia - cem pessoas, uma malha.

Convencoes, as do resto: metro, Z para cima, a frente em +Y (que no Godot e
-Z), origem no chao entre os pes.
"""

import os

import bmesh
import bpy
from mathutils import Matrix, Vector

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLEND = os.path.join(RAIZ, "arte", "pedestres.blend")
SAIDA = os.path.join(RAIZ, "assets", "pedestres")

# sRGB. A roupa e branca: e ela que leva a cor de cada pessoa no Godot.
MATERIAIS = [
    ("pele", (0.62, 0.42, 0.30)),
    ("calca", (0.18, 0.22, 0.32)),
    ("cabelo", (0.10, 0.08, 0.07)),
    ("roupa", (1.0, 1.0, 1.0)),
]
M = {nome: i for i, (nome, _) in enumerate(MATERIAIS)}


class Peca:
    def __init__(self, nome: str) -> None:
        self.nome = nome
        self.bm = bmesh.new()

    def caixa(self, centro, tamanho, material, giro_x=0.0, pivo=None) -> None:
        verts = bmesh.ops.create_cube(self.bm, size=1.0)["verts"]
        for v in verts:
            v.co = Vector((v.co.x * tamanho[0], v.co.y * tamanho[1], v.co.z * tamanho[2]))
        m = Matrix.Translation(Vector(centro))
        if giro_x:
            # Gira em torno do pivo (quadril, ombro): perna e braco balancando.
            p = Vector(pivo)
            m = Matrix.Translation(p) @ Matrix.Rotation(giro_x, 4, "X") @ Matrix.Translation(Vector(centro) - p)
        bmesh.ops.transform(self.bm, matrix=m, verts=verts)
        for face in {f for v in verts for f in v.link_faces}:
            face.material_index = M[material]
            face.smooth = False

    def cabeca(self, centro) -> None:
        verts = bmesh.ops.create_icosphere(self.bm, subdivisions=1, radius=0.12)["verts"]
        bmesh.ops.transform(self.bm, matrix=Matrix.Translation(Vector(centro)), verts=verts)
        for face in {f for v in verts for f in v.link_faces}:
            face.material_index = M["pele"]
            face.smooth = False

    def objeto(self, materiais, colecao, x) -> bpy.types.Object:
        bm = self.bm
        bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method="FIXED", ngon_method="EAR_CLIP")
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


def pessoa(nome: str, passo: float) -> Peca:
    """Uma pessoa de 1,72 m. `passo` e o balanco de perna e braco, em radianos:
    zero e parado, de pe."""
    p = Peca(nome)
    quadril, ombro = 0.92, 1.42
    for lado in (-1.0, 1.0):
        giro = passo * lado
        p.caixa((lado * 0.1, 0.0, quadril * 0.5), (0.14, 0.16, quadril), "calca", giro, (0, 0, quadril))
        p.caixa((lado * 0.1, 0.05, 0.04), (0.13, 0.26, 0.08), "cabelo", giro, (0, 0, quadril))
        p.caixa((lado * 0.27, 0.0, ombro - 0.3), (0.1, 0.11, 0.6), "pele", -giro * 0.8, (0, 0, ombro))
        p.caixa((lado * 0.27, 0.0, ombro - 0.08), (0.12, 0.13, 0.18), "roupa", -giro * 0.8, (0, 0, ombro))
    p.caixa((0.0, 0.0, (quadril + ombro) * 0.5 + 0.02), (0.44, 0.22, ombro - quadril + 0.08), "roupa")
    p.caixa((0.0, 0.0, ombro + 0.06), (0.1, 0.1, 0.1), "pele")
    p.cabeca((0.0, 0.01, ombro + 0.22))
    p.caixa((0.0, -0.02, ombro + 0.3), (0.22, 0.22, 0.08), "cabelo")
    return p


def material(nome, cor) -> bpy.types.Material:
    mat = bpy.data.materials.new(nome)
    if mat.node_tree is None:
        mat.use_nodes = True
    mat.use_backface_culling = True
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
    colecao = bpy.data.collections.new("Pedestres")
    bpy.context.scene.collection.children.link(colecao)
    materiais = [material(*m) for m in MATERIAIS]
    objetos = [
        pessoa("Parado", 0.0).objeto(materiais, colecao, 0.0),
        pessoa("Andando", 0.35).objeto(materiais, colecao, 1.5),
    ]
    for o in bpy.data.objects:
        o.select_set(o in objetos)
    bpy.context.view_layer.objects.active = objetos[0]

    bpy.ops.wm.save_as_mainfile(filepath=BLEND, relative_remap=True)
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(SAIDA, "pedestres.glb"),
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
