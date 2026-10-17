"""Gerador do poste de dois bracos da avenida.

Roda dentro do Blender (5.2+), igual aos outros:

    blender --background --factory-startup --python arte/poste.py

Apaga a cena, monta o poste, salva `arte/poste.blend` e exporta
`assets/poste/poste.glb`. Mesma receita, mesmo `.glb`.

O poste e o do video (`docs/referencias/video_01/t1.0s.png`): fuste liso
cinza-chumbo ate uns 7 m, e dali dois bracos que sobem quase em pe e abrem em
curva ate ficar deitados a 10 m, como uma tulipa, com uma cabeca chata de LED
na ponta de cada um. Um braco vai por cima da pista e o outro por cima da
calcada. E o referencial de velocidade mais limpo do video porque o braco
passa **por cima** da camera: o fuste corre no canto da tela, o braco risca o
topo dela.

Convencoes, as mesmas do `predios.py`:

- **Metro, Z para cima, o braco da pista em +Y.** O exportador glTF poe +Y em
  -Z: no Godot o poste "olha" para -Z, e quem o coloca aponta -Z para a pista.
- **Origem no chao, no eixo do fuste.** A base desce meio metro abaixo dela,
  para o poste nao ficar com o pe no ar onde a calcada sobe no meio-fio.

O braco tem 12 cm de grossura, mais que o de verdade: o de verdade a 20 m da
camera fica abaixo de um pixel em 640x360 e pisca em vez de passar.
"""

import math
import os

import bmesh
import bpy
from mathutils import Vector

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLEND = os.path.join(RAIZ, "arte", "poste.blend")
SAIDA = os.path.join(RAIZ, "assets", "poste")

# Cinza-chumbo, o do aco pintado do video. Escuro contra o ceu claro: e a
# silhueta que marca a passagem.
FERRO = (0.20, 0.21, 0.22)
# A lente da cabeca de LED, por baixo. Clara e apagada: e dia, e o glow da V12
# e so para o que e luz.
LENTE = (0.82, 0.84, 0.82)

# Oito lados no fuste, seis no braco. Mais que isso nao aparece a 640x360, e o
# poste se repete a cada 25 m da avenida inteira.
LADOS_FUSTE = 8
LADOS_BRACO = 6

# Onde o fuste abre nos dois bracos.
GARFO = 6.8
# Cada braco e uma curva de Bezier quadratica em (para fora, altura): sai do
# garfo quase em pe, puxado pelo controle bem acima dele, e chega deitado na
# ponta. A ponta fica a 3,2 m do fuste - com o poste a 0,6 m do meio-fio, a
# cabeca da pista fica sobre a faixa da direita, por onde a moto passa.
BRACO_CONTROLE = (0.0, 9.7)
BRACO_PONTA = (3.2, 10.0)
RAIO_BRACO = 0.06
# A cabeca de LED: comprida no sentido do braco, chata e mais larga que ele.
CABECA = (0.75, 0.28, 0.12)


def bezier(a, b, c, t) -> tuple:
    u = 1.0 - t
    return tuple(u * u * a[k] + 2.0 * u * t * b[k] + t * t * c[k] for k in range(2))


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

    def caixa(self, centro, tamanho, material) -> None:
        verts = bmesh.ops.create_cube(self.bm, size=1.0)["verts"]
        for v in verts:
            v.co = Vector(centro) + Vector((v.co.x * tamanho[0], v.co.y * tamanho[1], v.co.z * tamanho[2]))
        for face in {f for v in verts for f in v.link_faces}:
            face.material_index = material
            # Caixa e chapa: quina dura, senao a cabeca vira sabonete.
            face.smooth = False

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
    # Base, fuste afinando ate o garfo e a tampa onde os bracos nascem.
    p.torno(
        (0, 0, 0),
        [
            (-0.5, 0.20),
            (0.45, 0.20),
            (0.45, 0.12),
            (GARFO, 0.08),
            (GARFO + 0.15, 0.08),
            (GARFO + 0.25, 0.0),
        ],
        LADOS_FUSTE,
        0,
    )
    for lado in (1.0, -1.0):
        curva = [bezier((0.0, GARFO), BRACO_CONTROLE, BRACO_PONTA, i / 10.0) for i in range(11)]
        p.tubo([(0.0, lado * y, z) for y, z in curva], RAIO_BRACO, LADOS_BRACO, 0)
        # A cabeca comeca um pouco antes da ponta, para o tubo morrer dentro
        # dela, e a lente fica colada por baixo.
        y, z = BRACO_PONTA
        meio = lado * (y - 0.15 + CABECA[0] * 0.5)
        p.caixa((0.0, meio, z), (CABECA[1], CABECA[0], CABECA[2]), 0)
        p.caixa((0.0, meio, z - CABECA[2] * 0.5 - 0.01), (CABECA[1] - 0.06, CABECA[0] - 0.1, 0.02), 1)
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

    obj = poste().objeto([material("ferro", FERRO), material("lente", LENTE)], colecao)
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
