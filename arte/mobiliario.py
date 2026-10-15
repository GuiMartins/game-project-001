"""Gerador do mobiliario da calcada: cacamba, mupi e placa de curva.

Roda dentro do Blender (5.2+), igual aos outros:

    blender --background --factory-startup --python arte/mobiliario.py

Apaga a cena, monta as pecas, salva `arte/mobiliario.blend` e exporta
`assets/mobiliario/mobiliario.glb`. Mesma receita, mesmo `.glb`.

Cada peca e um bloco de cor que marca distancia na calcada (V17), tirado das
referencias:

- **Cacamba** (`01_centro`, `video_01/t1.0s`): a caixa de entulho de obra,
  encostada no meio-fio. Vermelho de tijolo, e nao laranja: a bag do jogador
  e a coisa mais saturada da tela, e uma caixa laranja do tamanho dela na
  calcada seria um segundo entregador.
- **Mupi** (`01_centro`, a esquerda): o painel de ponto de onibus, aceso,
  com uma foto. Acende como o outdoor (glow da V12), so que na altura do olho.
- **PlacaEsquerda** e **PlacaDireita** (`video_01/t2.0s`, `t3.0s`): o losango
  amarelo de curva, com a seta. Dois modelos, e nao um espelhado: escala
  negativa vira o winding, e o Godot descarta a face sem avisar.
- **PlacaMaoDupla**: o mesmo losango, com as duas setas do sentido duplo de
  circulacao do CTB - a da esquerda para baixo, a da direita para cima. Fica
  antes da via expressa, onde metade da pista vira mao contraria.

Convencoes, as mesmas do `poste.py`:

- **Metro, Z para cima, a frente em +Y.** O exportador glTF poe +Y em -Z: no
  Godot a peca "olha" para -Z. O mupi e a placa encaram quem vem pela pista;
  a cacamba fica de comprido ao longo dela.
- **Origem no chao, no centro da planta.**
"""

import math
import os

import bmesh
import bpy
from mathutils import Vector

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLEND = os.path.join(RAIZ, "arte", "mobiliario.blend")
SAIDA = os.path.join(RAIZ, "assets", "mobiliario")

# sRGB. (nome, cor, brilho): brilho acima de zero acende, e a 3 passa do limiar
# do glow (`world.gd`), como a tela do outdoor.
MATERIAIS = [
    ("cacamba", (0.66, 0.24, 0.16), 0.0),
    ("entulho", (0.52, 0.46, 0.40), 0.0),
    ("ferro", (0.20, 0.21, 0.22), 0.0),
    ("aluminio", (0.70, 0.72, 0.74), 0.0),
    ("mupi_luz", (0.80, 0.90, 0.98), 3.0),
    ("mupi_foto", (0.98, 0.62, 0.20), 3.0),
    ("mupi_foto_2", (0.30, 0.70, 0.40), 3.0),
    ("amarelo", (0.98, 0.80, 0.10), 0.0),
    ("preto", (0.08, 0.08, 0.08), 0.0),
]
M = {nome: i for i, (nome, _, _) in enumerate(MATERIAIS)}


class Peca:
    def __init__(self, nome: str) -> None:
        self.nome = nome
        self.bm = bmesh.new()

    def caixa(self, centro, tamanho, material) -> None:
        verts = bmesh.ops.create_cube(self.bm, size=1.0)["verts"]
        for v in verts:
            v.co = Vector(centro) + Vector((v.co.x * tamanho[0], v.co.y * tamanho[1], v.co.z * tamanho[2]))
        for face in {f for v in verts for f in v.link_faces}:
            face.material_index = M[material]
            face.smooth = False

    def face(self, pontos, normal, material) -> None:
        verts = [self.bm.verts.new(Vector(p)) for p in pontos]
        f = self.bm.faces.new(verts)
        f.normal_update()
        if f.normal.dot(Vector(normal)) < 0.0:
            f.normal_flip()
        f.material_index = M[material]
        f.smooth = False

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


def cacamba() -> Peca:
    """Caixa de 2,4 x 1,4 x 1 m, mais larga em cima, com o entulho aparecendo.

    De comprido no X, que no Godot corre ao longo da pista.
    """
    p = Peca("Cacamba")
    baixo, cima, h = (1.0, 0.55), (1.2, 0.7), 1.0
    b = [(-baixo[0], -baixo[1], 0.05), (baixo[0], -baixo[1], 0.05), (baixo[0], baixo[1], 0.05), (-baixo[0], baixo[1], 0.05)]
    t = [(-cima[0], -cima[1], h), (cima[0], -cima[1], h), (cima[0], cima[1], h), (-cima[0], cima[1], h)]
    for i in range(4):
        j = (i + 1) % 4
        meio = Vector(b[i]) + Vector(b[j])
        p.face([b[i], b[j], t[j], t[i]], (meio.x, meio.y, 0.0), "cacamba")
    # O entulho, um pouco abaixo da borda, e a borda dobrada por cima dela.
    p.face([(x * 0.95, y * 0.95, h - 0.12) for x, y, _ in t], (0, 0, 1), "entulho")
    p.caixa((0, 0, h), (cima[0] * 2 + 0.06, cima[1] * 2 + 0.06, 0.06), "cacamba")
    # Pes de ferro: a cacamba fica um palmo acima do chao.
    for sx in (-0.8, 0.8):
        p.caixa((sx, 0.0, 0.03), (0.12, baixo[1] * 2, 0.06), "ferro")
    return p


def mupi() -> Peca:
    """Painel de 1,3 x 1,9 m sobre o pe, aceso dos dois lados, encarando a pista.

    Fino no X; as duas telas olham para +Y e -Y, que no Godot e quem vem e
    quem ja passou.
    """
    p = Peca("Mupi")
    W, H, base = 1.3, 1.9, 0.35
    p.caixa((0, 0, base + H * 0.5), (W + 0.14, 0.22, H + 0.14), "aluminio")
    p.caixa((0, 0, base * 0.5), (W * 0.6, 0.18, base), "aluminio")
    for lado in (1.0, -1.0):
        y = lado * 0.115
        z0, z1 = base, base + H

        def placa(x0, x1, za, zb, material, fora) -> None:
            yy = y + lado * fora
            p.face([(x0, yy, za), (x1, yy, za), (x1, yy, zb), (x0, yy, zb)], (0, lado, 0), material)

        hw = W * 0.5
        placa(-hw, hw, z0, z1, "mupi_luz", 0.002)
        # A foto: um bloco de cor e uma faixa de outra, como o outdoor de longe.
        placa(-hw + 0.12, hw - 0.12, z0 + 0.65, z1 - 0.15, "mupi_foto", 0.004)
        placa(-hw + 0.12, hw - 0.12, z0 + 0.25, z0 + 0.5, "mupi_foto_2", 0.004)
    return p


def placa(sentido: float) -> Peca:
    """Losango amarelo de 75 cm a 2,2 m do chao, com a seta para `sentido`.

    `sentido` e -1 para a esquerda e 1 para a direita, vista de frente (+Y).
    """
    p = Peca("PlacaEsquerda" if sentido < 0 else "PlacaDireita")
    p.caixa((0, -0.04, 1.3), (0.07, 0.07, 2.6), "ferro")
    c = Vector((0.0, 0.03, 2.6))
    r = 0.53
    losango = [c + Vector((0, 0, r)), c + Vector((r, 0, 0)), c + Vector((0, 0, -r)), c + Vector((-r, 0, 0))]
    p.face(losango, (0, 1, 0), "amarelo")
    p.face(losango, (0, -1, 0), "ferro")
    # A seta: haste de baixo e a ponta virada para o lado da curva. Seis
    # centimetros de grossura sao um pixel a 20 m, que e de onde ela se le.
    f = Vector((0.0, 0.006, 0.0))
    e = 0.06
    haste = [c + Vector((-e, 0, -0.28)), c + Vector((e, 0, -0.28)), c + Vector((e, 0, 0.05)), c + Vector((-e, 0, 0.05))]
    p.face([v + f for v in haste], (0, 1, 0), "preto")
    ponta = [
        c + Vector((-e, 0, 0.05 - e)),
        c + Vector((sentido * 0.2, 0, 0.05 - e)),
        c + Vector((sentido * 0.2, 0, 0.05 + e)),
        c + Vector((-e, 0, 0.05 + e)),
    ]
    p.face([v + f for v in ponta], (0, 1, 0), "preto")
    seta = [c + Vector((sentido * 0.32, 0, 0.05)), c + Vector((sentido * 0.17, 0, 0.2)), c + Vector((sentido * 0.17, 0, -0.1))]
    p.face([v + f for v in seta], (0, 1, 0), "preto")
    return p


def placa_mao_dupla() -> Peca:
    """O losango da placa de curva com as duas setas do sentido duplo.

    Aqui se anda pela direita: a seta da direita sobe (quem vai), a da
    esquerda desce (quem vem). As mesmas medidas da seta da curva, que se le a
    20 m.
    """
    p = Peca("PlacaMaoDupla")
    p.caixa((0, -0.04, 1.3), (0.07, 0.07, 2.6), "ferro")
    c = Vector((0.0, 0.03, 2.6))
    r = 0.53
    losango = [c + Vector((0, 0, r)), c + Vector((r, 0, 0)), c + Vector((0, 0, -r)), c + Vector((-r, 0, 0))]
    p.face(losango, (0, 1, 0), "amarelo")
    p.face(losango, (0, -1, 0), "ferro")
    f = Vector((0.0, 0.006, 0.0))
    e = 0.05
    for x, para in ((-0.13, -1.0), (0.13, 1.0)):
        m = c + Vector((x, 0, 0))
        base = m + Vector((0, 0, -para * 0.26))
        topo = m + Vector((0, 0, para * 0.12))
        haste = [base + Vector((-e, 0, 0)), base + Vector((e, 0, 0)), topo + Vector((e, 0, 0)), topo + Vector((-e, 0, 0))]
        p.face([v + f for v in haste], (0, 1, 0), "preto")
        ponta = m + Vector((0, 0, para * 0.27))
        asas = [ponta, topo + Vector((-0.12, 0, 0)), topo + Vector((0.12, 0, 0))]
        p.face([v + f for v in asas], (0, 1, 0), "preto")
    return p


def material(nome, cor, brilho) -> bpy.types.Material:
    mat = bpy.data.materials.new(nome)
    if mat.node_tree is None:
        mat.use_nodes = True
    mat.use_backface_culling = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    linear = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in cor]
    bsdf.inputs["Base Color"].default_value = (*linear, 1.0)
    bsdf.inputs["Roughness"].default_value = 1.0
    bsdf.inputs["Metallic"].default_value = 0.0
    if brilho > 0.0:
        bsdf.inputs["Emission Color"].default_value = (*linear, 1.0)
        bsdf.inputs["Emission Strength"].default_value = brilho
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
    colecao = bpy.data.collections.new("Mobiliario")
    bpy.context.scene.collection.children.link(colecao)
    materiais = [material(*m) for m in MATERIAIS]
    objetos = []
    for k, peca in enumerate((cacamba(), mupi(), placa(-1.0), placa(1.0), placa_mao_dupla())):
        objetos.append(peca.objeto(materiais, colecao, k * 4.0))
    for o in bpy.data.objects:
        o.select_set(o in objetos)
    bpy.context.view_layer.objects.active = objetos[0]

    bpy.ops.wm.save_as_mainfile(filepath=BLEND, relative_remap=True)
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(SAIDA, "mobiliario.glb"),
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
