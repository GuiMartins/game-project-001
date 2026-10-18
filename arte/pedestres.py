"""Gerador dos pedestres: gente parada e gente andando, para a calcada.

Roda dentro do Blender (5.2+), igual aos outros:

    blender --background --factory-startup --python arte/pedestres.py

Apaga a cena, monta as duas poses, salva `arte/pedestres.blend` e exporta
`assets/pedestres/pedestres.glb`. Mesma receita, mesmo `.glb`.

Textura de vida nos dois lados da avenida (V19; `01_centro`, `02_praca_maua`,
`video_01/t1.0s`, `t3.0s`). Sem logica nenhuma, e ninguem atravessa a pista:
sao centenas, e o `Pedestres` os desenha num `MultiMesh`.

Uma malha so, de pe e parada: quem anima e o `pedestres.gdshader`, no
vertice, porque `MultiMesh` nao tem esqueleto. Para ele saber o que gira em
volta do quadril e o que gira em volta do ombro, cada peca leva o numero dela
no U da UV (`PARTES`). Pela geometria nao da: a barra da camisa desce abaixo
do quadril, e a mao, abaixo dela.

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
# A parte de cada peca, no U da UV, em oitavos: dentro de [0, 1] para a
# compressao de malha do Godot nao mexer, e longe o bastante um do outro para
# o shader arredondar sem erro. Tem de bater com o `pedestres.gdshader`.
PARTES = {"corpo": 0, "perna_esq": 1, "perna_dir": 2, "braco_esq": 3, "braco_dir": 4}


class Peca:
    def __init__(self, nome: str) -> None:
        self.nome = nome
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("parte")

    def caixa(self, centro, tamanho, material, parte="corpo", giro_x=0.0, pivo=None) -> None:
        verts = bmesh.ops.create_cube(self.bm, size=1.0)["verts"]
        for v in verts:
            v.co = Vector((v.co.x * tamanho[0], v.co.y * tamanho[1], v.co.z * tamanho[2]))
        m = Matrix.Translation(Vector(centro))
        if giro_x:
            # Gira em torno do pivo (quadril, ombro): perna e braco balancando.
            p = Vector(pivo)
            m = Matrix.Translation(p) @ Matrix.Rotation(giro_x, 4, "X") @ Matrix.Translation(Vector(centro) - p)
        bmesh.ops.transform(self.bm, matrix=m, verts=verts)
        self._pinta({f for v in verts for f in v.link_faces}, material, parte)

    def _pinta(self, faces, material, parte) -> None:
        for face in faces:
            face.material_index = M[material]
            face.smooth = False
            for loop in face.loops:
                loop[self.uv].uv = (PARTES[parte] / 8.0, 0.0)

    def cabeca(self, centro) -> None:
        verts = bmesh.ops.create_icosphere(self.bm, subdivisions=1, radius=0.12)["verts"]
        bmesh.ops.transform(self.bm, matrix=Matrix.Translation(Vector(centro)), verts=verts)
        self._pinta({f for v in verts for f in v.link_faces}, "pele", "corpo")

    def objeto(self, materiais, colecao, x, pai=None, origem=(0.0, 0.0, 0.0)) -> bpy.types.Object:
        """`origem` e a articulacao, em metros da pessoa: a malha e levada para
        ela ficar na origem do objeto, e o objeto vai para ela dentro do `pai`."""
        bm = self.bm
        origem = Vector(origem)
        bmesh.ops.translate(bm, vec=-origem, verts=bm.verts[:])
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
        obj.location = origem + Vector((x, 0.0, 0.0))
        if pai is not None:
            obj.parent = pai
            obj.location = origem - Vector(pai["origem"])
        obj["origem"] = origem
        colecao.objects.link(obj)
        return obj


def pessoa(nome: str, passo: float) -> Peca:
    """Uma pessoa de 1,72 m. `passo` e o balanco de perna e braco, em radianos:
    zero e parado, de pe. O jogo usa so a de pe; o balanco e do shader. Os
    pivos (quadril 0,92, ombro 1,42) estao copiados la."""
    p = Peca(nome)
    quadril, ombro = 0.92, 1.42
    for lado, nome in ((-1.0, "esq"), (1.0, "dir")):
        giro = passo * lado
        perna, braco = "perna_" + nome, "braco_" + nome
        q, o = (0, 0, quadril), (0, 0, ombro)
        p.caixa((lado * 0.1, 0.0, quadril * 0.5), (0.14, 0.16, quadril), "calca", perna, giro, q)
        p.caixa((lado * 0.1, 0.05, 0.04), (0.13, 0.26, 0.08), "cabelo", perna, giro, q)
        p.caixa((lado * 0.27, 0.0, ombro - 0.3), (0.1, 0.11, 0.6), "pele", braco, -giro * 0.8, o)
        p.caixa((lado * 0.27, 0.0, ombro - 0.08), (0.12, 0.13, 0.18), "roupa", braco, -giro * 0.8, o)
    p.caixa((0.0, 0.0, (quadril + ombro) * 0.5 + 0.02), (0.44, 0.22, ombro - quadril + 0.08), "roupa")
    p.caixa((0.0, 0.0, ombro + 0.06), (0.1, 0.1, 0.1), "pele")
    p.cabeca((0.0, 0.01, ombro + 0.22))
    p.caixa((0.0, -0.02, ombro + 0.3), (0.22, 0.22, 0.08), "cabelo")
    return p


# Joelho da articulada. Na de pe ele nao existe: a perna e uma caixa so.
JOELHO = 0.48


def articulada(materiais, colecao, x, fiscal=False) -> bpy.types.Object:
    """A mesma pessoa em pecas, cada uma com a origem na articulacao, para o
    `Pessoa` do jogo posar no codigo: atravessar a rua, sair do carro, pular
    da frente da moto. O `MultiMesh` nao serve para isso, e sao poucas.

        Articulada          vazio, no chao entre os pes
          Quadril           vazio, no quadril: sobe e desce ao sentar
            Tronco          camisa, pescoco e cabeca; tomba para a frente
              Braco_E/D     no ombro
            Coxa_E/D        no quadril de cada lado
              Canela_E/D    no joelho, com o sapato
    """
    raiz = bpy.data.objects.new("Articulada", None)
    raiz.location.x = x
    raiz["origem"] = Vector((0.0, 0.0, 0.0))
    colecao.objects.link(raiz)
    quadril, ombro = 0.92, 1.42
    q = bpy.data.objects.new("Quadril", None)
    q.parent = raiz
    q.location = (0.0, 0.0, quadril)
    q["origem"] = Vector((0.0, 0.0, quadril))
    colecao.objects.link(q)

    t = Peca("Tronco")
    if fiscal:
        # Silhueta provisoria da mulher adulta: cintura marcada, top ajustado
        # e cabelo comprido. O sprite definitivo vira outra etapa.
        t.caixa((0.0, 0.0, 1.04), (0.30, 0.20, 0.22), "roupa")
        t.caixa((0.0, 0.01, 1.29), (0.37, 0.25, 0.30), "roupa")
        t.caixa((0.0, 0.0, 0.94), (0.40, 0.24, 0.16), "calca")
    else:
        t.caixa((0.0, 0.0, (quadril + ombro) * 0.5 + 0.02), (0.44, 0.22, ombro - quadril + 0.08), "roupa")
    t.caixa((0.0, 0.0, ombro + 0.06), (0.1, 0.1, 0.1), "pele")
    t.cabeca((0.0, 0.01, ombro + 0.22))
    t.caixa((0.0, -0.02, ombro + 0.3), (0.22, 0.22, 0.08), "cabelo")
    if fiscal:
        t.caixa((0.0, -0.09, 1.49), (0.26, 0.17, 0.38), "cabelo")
    tronco = t.objeto(materiais, colecao, 0.0, q, (0.0, 0.0, quadril))
    for lado, nome in ((-1.0, "E"), (1.0, "D")):
        b = Peca("Braco_" + nome)
        b.caixa((lado * 0.27, 0.0, ombro - 0.3), (0.1, 0.11, 0.6), "pele")
        if not fiscal:
            b.caixa((lado * 0.27, 0.0, ombro - 0.08), (0.12, 0.13, 0.18), "roupa")
        b.objeto(materiais, colecao, 0.0, tronco, (lado * 0.27, 0.0, ombro))
        c = Peca("Coxa_" + nome)
        c.caixa((lado * 0.1, 0.0, (quadril + JOELHO) * 0.5), (0.16 if fiscal else 0.14, 0.18 if fiscal else 0.16, quadril - JOELHO), "pele" if fiscal else "calca")
        if fiscal:
            c.caixa((lado * 0.1, 0.0, 0.85), (0.19, 0.23, 0.20), "calca")
        coxa = c.objeto(materiais, colecao, 0.0, q, (lado * 0.1, 0.0, quadril))
        k = Peca("Canela_" + nome)
        k.caixa((lado * 0.1, 0.0, JOELHO * 0.5), (0.13, 0.15, JOELHO), "pele" if fiscal else "calca")
        k.caixa((lado * 0.1, 0.05, 0.04), (0.13, 0.26, 0.08), "cabelo")
        k.objeto(materiais, colecao, 0.0, coxa, (lado * 0.1, 0.0, JOELHO))
    return raiz


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
    objetos = [pessoa("Pessoa", 0.0).objeto(materiais, colecao, 0.0)]
    raiz = articulada(materiais, colecao, 1.5)
    objetos += [raiz, *raiz.children_recursive]
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
        if obj.type != "MESH":
            continue
        dims = obj.dimensions
        print("%s: %d tris, %.1f x %.1f x %.1f m" % (obj.name, len(obj.data.polygons), dims.x, dims.y, dims.z))

    # Cena propria para manter a pessoa comum e seu MultiMesh identicos.
    limpa_cena()
    colecao = bpy.data.collections.new("Fiscal")
    bpy.context.scene.collection.children.link(colecao)
    materiais = [material(*m) for m in MATERIAIS]
    articulada(materiais, colecao, 0.0, fiscal=True)
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(SAIDA, "fiscal.glb"),
        export_format="GLB", export_yup=True, export_apply=False,
        export_animations=False, export_cameras=False, export_lights=False,
        export_all_vertex_colors=False, export_extras=False,
    )


main()
