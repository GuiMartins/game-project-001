"""Gerador do entregador: uma Honda CG 160 e quem pilota, como pecas separadas.

Roda dentro do Blender (5.2+), e nao fora dele:

    blender --background --factory-startup --python arte/entregador.py

ou colado no editor de texto do Blender. Apaga a cena atual, monta o modelo,
salva `arte/entregador.blend` e exporta `assets/entregador/entregador.glb`
mais as duas texturas. `--factory-startup` deixa de fora os add-ons e as
preferencias de quem roda: mesma entrada, mesmo `.glb`, byte a byte.

Este script e a fonte; o `.blend` e o `.glb` sao build. Pela mesma razao que o
`baseline.json` e gerado e revisado em vez de digitado: geometria descrita em
numeros da pra revisar em diff, e um `.blend` binario nao.

A moto e a CG 160 porque e ela a moto de entrega brasileira: monocilindro
arrefecido a ar, quadro de tubo, garfo telescopico, balanca com dois
amortecedores, protetor de perna e bagageiro. As medidas sao da ficha tecnica
da Titan (entre eixos de 1,31 m, roda aro 18, banco a 0,80 m, caster de 27
graus); o resto e o que a camera de tras enxerga a 6 m.

Convencoes, todas escolhidas pelo que o Godot espera do outro lado:

- **Metro, Z para cima, frente em +Y.** O exportador glTF converte +Y do
  Blender em -Z, que e a frente de um `Node3D` no Godot. Modelar de frente
  para -Y (a vista "Front" do Blender) poe a moto andando de re no jogo.
- **Origem no chao, embaixo do centro da moto.** E o ponto de contato que a
  moto inclina em volta. O corpo fisico do `player_bike.gd` tem a origem no
  meio da capsula de 1,75 m, entao no Godot o modelo entra 0,875 m abaixo.
- **Toda rotacao e identidade.** Cada peca guarda so translacao em relacao ao
  pai, e a origem dela fica na articulacao. No Godot, girar o no `Antebraco_D`
  dobra o cotovelo, sem conta de matriz nenhuma.
- **Sem rig.** Peca rigida presa na articulacao e o jeito dos jogos da epoca,
  anima por transformacao de no, e vira rig depois sem refazer malha.

A moto e o piloto sao arvores separadas por tres motivos: a queda (o piloto
voa, a moto tomba, cada um com a sua fisica), o soco (o torso gira e o braco
solta sem arrastar o guidao) e a troca de paleta dos rivais, que pinta piloto
e moto independentemente.

O que da para animar, e por onde:

    Entregador
      Moto                 tomba na queda
        Suspenso           a massa suspensa: arfa e mergulha em cima das rodas
          Moto_Corpo       quadro, motor, tanque, banco, escapamento
          Amortecedor_E/D  corpo do amortecedor; aponta para a Mola
          Direcao          esterca em volta da reta Direcao -> Garfo
            Garfo          as bainhas: deslizam ao longo do garfo
              Roda_Dianteira   gira em X
          Balanca          gira em X em volta do pivo, no quadro
            Roda_Traseira  gira em X
            Mola_E/D       a mola: aponta para o Amortecedor e encolhe
      Piloto               o quadril; anda com o Suspenso, solta na queda
        Tronco             deita, gira e rola o torso em volta do quadril
          Cabeca, Bag
          Braco_E/D -> Antebraco_E/D -> Mao_E/D
        Coxa_E/D -> Canela_E/D -> Pe_E/D

**As rodas nunca saem do chao; quem se mexe e o resto.** O `entregador.gd`
decide quanto a frente e a traseira afundam, e daí a altura do garfo e o
angulo da balanca saem de conta, para cada roda continuar tocando o asfalto.
Por isso o garfo e duas pecas (o tubo cromado fica na `Direcao`, a bainha
desliza por fora dele) e o amortecedor tambem (o corpo preso no quadro, a mola
presa na balanca, cada um mirando no outro).

As duas cadeias de membro sao feitas para IK de dois ossos, que e o que poe a
mao na manopla quando o guidao vira, o pe no chao quando a moto para e o soco
no lado de quem apanha. Nada precisa ser medido a parte: a posicao de cada
filho e o osso do pai. `Canela.position` e a coxa, `Pe.position` e a canela,
e o comprimento de cada uma e o tamanho desse vetor.
"""

import math
import os

import bmesh
import bpy
from mathutils import Matrix, Vector

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLEND = os.path.join(RAIZ, "arte", "entregador.blend")
SAIDA = os.path.join(RAIZ, "assets", "entregador")

# --- Paleta ------------------------------------------------------------------
#
# Uma textura so, em celulas de cor chapada, e cada face aponta o UV para o
# centro da sua celula. A 100 px de altura nao cabe pintura: o que se le e
# silhueta e massa de cor, e a "cara de foto" vem da luz e do LUT. Celula de
# 32 px sobrevive ate o mip 5 (8x8, um pixel por celula) sem uma cor vazar na
# vizinha, e e o mip que um rival a 70 m usa.
#
# A mascara usa o mesmo UV: R = bag, G = jaqueta, B = pintura da moto. E o que
# deixa os cinco rivais do `world.gd` serem o mesmo modelo com paleta trocada.

TEXTURA = 256
CELULA = 32

BAG, JAQUETA, MOTO = (1, 0, 0), (0, 1, 0), (0, 0, 1)
NADA = (0, 0, 0)

# nome: (albedo em sRGB, mascara)
PALETA = {
    "pintura": ((0.70, 0.11, 0.09), MOTO),
    "pintura_escura": ((0.42, 0.06, 0.05), MOTO),
    "preto": ((0.07, 0.07, 0.08), NADA),
    "pneu": ((0.04, 0.04, 0.045), NADA),
    "aro": ((0.30, 0.31, 0.33), NADA),
    "metal": ((0.62, 0.63, 0.65), NADA),
    "motor": ((0.34, 0.35, 0.37), NADA),
    "farol": ((0.98, 0.96, 0.82), NADA),
    "lanterna": ((0.85, 0.08, 0.06), NADA),
    "placa": ((0.86, 0.86, 0.84), NADA),
    "jaqueta": ((0.20, 0.25, 0.34), JAQUETA),
    "jaqueta_faixa": ((0.80, 0.82, 0.80), NADA),
    "calca": ((0.13, 0.17, 0.28), NADA),
    "bota": ((0.10, 0.09, 0.08), NADA),
    "luva": ((0.06, 0.06, 0.06), NADA),
    "capacete": ((0.92, 0.92, 0.90), NADA),
    "viseira": ((0.05, 0.06, 0.08), NADA),
    # A bag do jogador e laranja no greybox (`player_bike.gd`). Mantida, porque
    # e ela que separa o jogador dos rivais desde o primeiro cubo.
    "bag": ((0.95, 0.42, 0.15), BAG),
    "bag_tampa": ((0.70, 0.28, 0.09), BAG),
    "bag_faixa": ((0.85, 0.85, 0.80), NADA),
    # Da CG em diante. Novas no fim, para as celulas antigas nao mudarem de
    # lugar e o UV de quem ja existia continuar apontando para a mesma cor.
    "cromado": ((0.80, 0.81, 0.83), NADA),
    "aleta": ((0.52, 0.53, 0.55), NADA),
    "pisca": ((0.95, 0.55, 0.08), NADA),
    "painel": ((0.10, 0.16, 0.20), NADA),
    "grafismo": ((0.88, 0.88, 0.86), NADA),
    "borracha": ((0.12, 0.12, 0.12), NADA),
}
CELULAS = {nome: i for i, nome in enumerate(PALETA)}

# Aresta mais aberta que isto fica dura. Pega o 90 graus das caixas e deixa
# macio o tubo de 6 lados (60 graus) e a esfera de 8 gomos (45 graus): membro e
# pneu leem como redondos, carenagem le como chapa.
ANGULO_DURO = math.radians(65.0)


def uv_da_celula(i: int) -> tuple:
    por_linha = TEXTURA // CELULA
    return ((i % por_linha + 0.5) / por_linha, (i // por_linha + 0.5) / por_linha)


def superelipse(angulo: float, expoente: float) -> tuple:
    """Ponto do contorno `|x|^n + |y|^n = 1`: 2 e elipse, 4 ja e caixa macia.

    E a secao de tudo que e moldado - tanque, banco, rabeta, pneu. Plastico
    injetado e chapa estampada nao tem nem a quina da caixa nem a bolha da
    elipse, e o expoente e o que escolhe onde ficar entre as duas.
    """
    c, s = math.cos(angulo), math.sin(angulo)
    e = 2.0 / expoente
    return (math.copysign(abs(c) ** e, c), math.copysign(abs(s) ** e, s))


# --- Construcao de malha -----------------------------------------------------


class Peca:
    """Uma malha em construcao, escrita em coordenadas de mundo.

    Cada primitiva entra no mesmo bmesh com a cor gravada por face. So no fim a
    malha e transladada para que a origem caia no pivo, a articulacao.
    """

    def __init__(self, nome: str, pivo: tuple) -> None:
        self.nome = nome
        self.pivo = Vector(pivo)
        self.bm = bmesh.new()
        self.cor = self.bm.faces.layers.int.new("cor")

    def _pinta(self, verts: list, cor: str) -> None:
        for face in {f for v in verts for f in v.link_faces}:
            face[self.cor] = CELULAS[cor]

    def _face(self, verts: list, cor: str) -> None:
        self.bm.faces.new(verts)[self.cor] = CELULAS[cor]

    def caixa(self, centro, tamanho, cor, rot_x=0.0, topo=None) -> None:
        """Caixa; `topo` = (largura, comprimento) da face de cima, para afunilar."""
        verts = bmesh.ops.create_cube(self.bm, size=1.0)["verts"]
        sx, sy, sz = tamanho
        for v in verts:
            if topo is not None and v.co.z > 0.0:
                v.co.x *= topo[0]
                v.co.y *= topo[1]
            else:
                v.co.x *= sx
                v.co.y *= sy
            v.co.z *= sz
        m = Matrix.Translation(Vector(centro)) @ Matrix.Rotation(math.radians(rot_x), 4, "X")
        bmesh.ops.transform(self.bm, matrix=m, verts=verts)
        self._pinta(verts, cor)

    def barra(self, a, b, largura, espessura, cor) -> None:
        """Caixa de `a` a `b`, com os dois pontos no mesmo X.

        E a balanca, a corrente, a pedaleira: peca de secao retangular que
        corre num plano lateral da moto.
        """
        a, b = Vector(a), Vector(b)
        d = b - a
        comprimento = math.hypot(d.y, d.z)
        angulo = math.degrees(math.atan2(d.z, d.y))
        self.caixa((a + b) * 0.5, (largura, comprimento, espessura), cor, rot_x=angulo)

    def tubo(self, a, b, raio_a, raio_b, cor, lados=6, leque=False) -> set:
        """Tronco de cone de `a` a `b`. Devolve as faces, para pintura parcial.

        `leque` fecha as pontas com triangulos saindo do centro, em vez de um
        poligono so.
        """
        a, b = Vector(a), Vector(b)
        eixo = b - a
        verts = bmesh.ops.create_cone(
            self.bm,
            cap_ends=True,
            cap_tris=leque,
            segments=lados,
            radius1=raio_a,
            radius2=raio_b,
            depth=eixo.length,
        )["verts"]
        giro = Vector((0.0, 0.0, 1.0)).rotation_difference(eixo.normalized())
        m = Matrix.Translation((a + b) * 0.5) @ giro.to_matrix().to_4x4()
        bmesh.ops.transform(self.bm, matrix=m, verts=verts)
        self._pinta(verts, cor)
        return {f for v in verts for f in v.link_faces}

    def caminho(self, pontos, raio, cor, lados=6) -> None:
        """Tubo dobrado: segmentos retos com uma esfera em cada dobra.

        Sem a esfera, toda dobra abre uma cunha vazia do lado de fora da curva,
        e e na curva que o olho para - o protetor de perna, o escapamento.
        """
        pontos = [Vector(p) for p in pontos]
        for a, b in zip(pontos, pontos[1:]):
            self.tubo(a, b, raio, raio, cor, lados=lados)
        for p in pontos[1:-1]:
            self.esfera(p, (raio, raio, raio), cor, gomos=lados, aneis=4)

    def esfera(self, centro, raios, cor, gomos=8, aneis=6, viseira=None) -> None:
        """Esfera achatada; `viseira` pinta a faixa da frente, na altura do olho.

        Viseira pintada nas faces da propria esfera, e nao uma placa colada na
        frente: placa reta numa esfera sobra pelos lados e o capacete vira
        oculos de realidade virtual.
        """
        verts = bmesh.ops.create_uvsphere(
            self.bm, u_segments=gomos, v_segments=aneis, radius=1.0
        )["verts"]
        self._pinta(verts, cor)
        if viseira is not None:
            for face in {f for v in verts for f in v.link_faces}:
                meio = face.calc_center_median()
                if meio.y > 0.45 and -0.05 < meio.z < 0.42 and abs(meio.x) < 0.8:
                    face[self.cor] = CELULAS[viseira]
        m = Matrix.Translation(Vector(centro)) @ Matrix.Diagonal((*raios, 1.0))
        bmesh.ops.transform(self.bm, matrix=m, verts=verts)

    def casco(self, secoes, cor, eixo="y", expoente=2.5, gomos=12, matriz=None) -> None:
        """Casca fechada passando por secoes superelipticas.

        Com `eixo="y"` cada secao e `(y, z_centro, largura, altura)`, e o casco
        corre de tras para a frente: tanque, banco, rabeta. Com `eixo="z"` e
        `(z, y_centro, largura, profundidade)`, de baixo para cima: torso e bag.
        `matriz` move o casco pronto, que e como o torso inclina.
        """
        aneis = []
        for t, centro, largura, altura in secoes:
            anel = []
            for j in range(gomos):
                sx, sz = superelipse(math.tau * j / gomos, expoente)
                if eixo == "y":
                    co = (largura * 0.5 * sx, t, centro + altura * 0.5 * sz)
                else:
                    co = (largura * 0.5 * sx, centro + altura * 0.5 * sz, t)
                anel.append(self.bm.verts.new(co))
            aneis.append(anel)
        for a, b in zip(aneis, aneis[1:]):
            for j in range(gomos):
                k = (j + 1) % gomos
                self._face([a[j], a[k], b[k], b[j]], cor)
        self._face(aneis[0], cor)
        self._face(list(reversed(aneis[-1])), cor)
        if matriz is not None:
            bmesh.ops.transform(self.bm, matrix=matriz, verts=[v for a in aneis for v in a])

    def anel(self, centro, raio, largura, altura, cor, gomos=20, perfil=8, expoente=2.6):
        """Toro em volta do eixo X: pneu e aro.

        `raio` e o de fora; a secao tem `largura` por `altura`. Pneu cilindrico
        (o tubo de 12 lados de antes) le como rolo de pintura de lado e como
        tijolo de tras; a secao arredondada e o que faz a moto inclinar em cima
        do ombro do pneu.
        """
        c = Vector(centro)
        meio = raio - altura * 0.5
        voltas = []
        for i in range(gomos):
            fi = math.tau * i / gomos
            volta = []
            for j in range(perfil):
                sx, sz = superelipse(math.tau * j / perfil, expoente)
                r = meio + altura * 0.5 * sz
                co = (c.x + largura * 0.5 * sx, c.y + r * math.cos(fi), c.z + r * math.sin(fi))
                volta.append(self.bm.verts.new(co))
            voltas.append(volta)
        for i in range(gomos):
            a, b = voltas[i], voltas[(i + 1) % gomos]
            for j in range(perfil):
                k = (j + 1) % perfil
                self._face([a[j], b[j], b[k], a[k]], cor)

    def mola(self, a, b, raio, espiras, fio, cor, passos=5) -> None:
        """Helice de `a` a `b`. No jogo a peca encolhe ao longo do eixo.

        Mola e o que separa amortecedor de cano: um tubo liso que encurta le
        como peca entrando em outra, e a espira apertando le como suspensao.
        """
        a, b = Vector(a), Vector(b)
        eixo = b - a
        giro = Vector((0.0, 0.0, 1.0)).rotation_difference(eixo.normalized())
        n = espiras * passos
        pontos = []
        for k in range(n + 1):
            t = k / n
            ang = math.tau * espiras * t
            local = Vector((raio * math.cos(ang), raio * math.sin(ang), eixo.length * t))
            pontos.append(a + giro @ local)
        for p, q in zip(pontos, pontos[1:]):
            self.tubo(p, q, fio, fio, cor, lados=4)

    def paralama(self, eixo, raio, largura, de, ate, cor, gomos=3) -> None:
        """Arco de placas em volta da roda, de `de` a `ate` graus.

        Angulo medido a partir da frente (+Y) subindo para +Z: 90 e o topo da
        roda. Placa reta paralela ao pneu, e nao uma tabua so: a tabua le como
        algo flutuando na frente da moto.
        """
        passo = (ate - de) / gomos
        comprimento = 2.0 * raio * math.tan(math.radians(passo) * 0.5) + 0.01
        for i in range(gomos):
            fi = math.radians(de + passo * (i + 0.5))
            centro = Vector(eixo) + Vector((0.0, math.cos(fi), math.sin(fi))) * raio
            self.caixa(centro, (largura, comprimento, 0.02), cor, rot_x=math.degrees(fi) - 90.0)

    def roda(self, centro, raio, largura, altura, raios=5) -> None:
        """Roda de liga da CG: pneu de secao redonda, aro e cinco raios.

        Raio de verdade, e nao fatia pintada: entre eles se ve o outro lado, e
        e esse vazado que gira. Disco liso girando e igual a disco parado, e a
        roda girar e metade da leitura de velocidade.
        """
        c = Vector(centro)
        self.anel(c, raio, largura, altura, "pneu")
        aro = raio - altura + 0.006
        self.anel(c, aro, largura * 0.75, 0.024, "aro", perfil=4, expoente=4.0)
        x = Vector((0.055, 0.0, 0.0))
        self.tubo(c - x, c + x, 0.045, 0.045, "motor", lados=10)
        de, ate = 0.04, aro - 0.018
        for k in range(raios):
            a = math.tau * k / raios + 0.3
            meio = c + Vector((0.0, math.cos(a), math.sin(a))) * (de + ate) * 0.5
            self.caixa(meio, (0.022, ate - de, 0.03), "aro", rot_x=math.degrees(a))

    def objeto(self, material, colecao, pai=None) -> bpy.types.Object:
        bm = self.bm
        bmesh.ops.translate(bm, vec=-self.pivo, verts=bm.verts)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        # Triangulado aqui, com metodo fixo, e com as faces em ordem canonica.
        # A esfera do bmesh sai com as faces numa ordem que muda de uma
        # execucao para outra, e o exportador repassa isso para o indice: o
        # mesmo modelo virava um .glb diferente a cada regeracao, e todo diff
        # de arte vinha com ruido de arquivo inteiro.
        bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method="FIXED", ngon_method="EAR_CLIP")
        # `BMElemSeq.sort` so aceita chave numerica: ordena fora e passa o posto.
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
            face.smooth = True
        for aresta in bm.edges:
            if not aresta.is_manifold or aresta.calc_face_angle(math.pi) > ANGULO_DURO:
                aresta.smooth = False
        bm.faces.layers.int.remove(self.cor)

        malha = bpy.data.meshes.new(self.nome)
        bm.to_mesh(malha)
        bm.free()
        malha.materials.append(material)

        obj = bpy.data.objects.new(self.nome, malha)
        colecao.objects.link(obj)
        anexa(obj, self.pivo, pai)
        return obj


def vazio(nome, pivo, colecao, pai=None) -> bpy.types.Object:
    obj = bpy.data.objects.new(nome, None)
    obj.empty_display_type = "PLAIN_AXES"
    obj.empty_display_size = 0.15
    colecao.objects.link(obj)
    anexa(obj, Vector(pivo), pai)
    return obj


def anexa(obj, pivo, pai) -> None:
    # Translacao pura relativa ao pai, sem matrix_parent_inverse: e o que faz
    # o no no Godot ter a transformacao local que a gente le aqui.
    obj.parent = pai
    obj.location = pivo - mundo(pai)


def mundo(obj) -> Vector:
    # Soma as translacoes subindo a arvore em vez de ler `matrix_world`, que so
    # e recalculado quando o depsgraph roda e vem zerado em objeto recem-criado.
    # Vale porque nenhuma peca tem rotacao nem escala.
    pos = Vector()
    while obj is not None:
        pos += obj.location
        obj = obj.parent
    return pos


def ik_dois_ossos(raiz, alvo, l1, l2, polo) -> Vector:
    """Onde fica o cotovelo (ou o joelho) entre `raiz` e `alvo`.

    `polo` diz para que lado a articulacao dobra. Se o alvo estiver fora do
    alcance, o membro estica reto em vez de quebrar.
    """
    raiz, alvo, polo = Vector(raiz), Vector(alvo), Vector(polo)
    d = alvo - raiz
    dist = min(d.length, l1 + l2 - 1e-4)
    eixo = d.normalized()
    a = (l1 * l1 - l2 * l2 + dist * dist) / (2.0 * dist)
    h = math.sqrt(max(l1 * l1 - a * a, 0.0))
    lado = (polo - eixo * polo.dot(eixo)).normalized()
    return raiz + eixo * a + lado * h


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
    # Celula sem uso fica preta e opaca: magenta seria mais visivel, mas
    # sangraria no mip mais baixo e tingiria a moto inteira a 70 m.
    for k in range(3, len(px), 4):
        px[k] = 1.0
    img.pixels = px
    img.filepath_raw = os.path.join(SAIDA, nome + ".png")
    img.file_format = "PNG"
    img.save()
    # Embutida no .blend, para ele abrir certo em qualquer maquina sem
    # caminho absoluto deste disco dentro dele.
    img.pack()
    return img


def material(albedo) -> bpy.types.Material:
    mat = bpy.data.materials.new("entregador")
    if mat.node_tree is None:
        mat.use_nodes = True  # antes do 5.0 o material nascia sem nos
    # Exporta como face de um lado so, igual ao Godot desenha: normal virada
    # aparece como buraco ja no Blender, em vez de so no jogo.
    mat.use_backface_culling = True
    nos = mat.node_tree.nodes
    bsdf = next(n for n in nos if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Roughness"].default_value = 0.85
    tex = nos.new("ShaderNodeTexImage")
    tex.image = albedo
    # Closest: a celula e cor chapada, interpolar so mistura a vizinha.
    tex.interpolation = "Closest"
    mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    return mat


# --- A CG --------------------------------------------------------------------
#
# Ficha da CG 160 Titan: entre eixos 1,31 m, pneus 80/100-18 e 90/90-18 (0,62 m
# de diametro), caster de 27 graus, banco a 0,80 m. Tudo cabe na caixa de
# 0,75 x 1,75 x 2,1 m do corpo fisico (`SIZE` no `player_bike.gd`), que e o que
# o jogador ja aprendeu a ler como "onde a moto esta".
#
# O entre eixos fica em 1,32 m e nao 1,31 de proposito: o `camera_garupa.gd`
# mede a distancia do cinegrafista a partir do eixo traseiro em 0,66 m.

RAIO_RODA = 0.31
EIXO_DIANTEIRO = Vector((0.0, 0.66, RAIO_RODA))
EIXO_TRASEIRO = Vector((0.0, -0.66, RAIO_RODA))

# Garfo: inclinado 27 graus, 0,76 m da mesa de cima ao eixo. A direcao gira em
# volta desta reta, e a bainha corre ao longo dela.
CASTER = math.radians(27.0)
GARFO = 0.76
DIR_GARFO = Vector((0.0, math.sin(CASTER), -math.cos(CASTER)))  # da mesa para o eixo
CABECA_GARFO = EIXO_DIANTEIRO - DIR_GARFO * GARFO
GARFO_X = 0.085

# Guidao tubular alto, de moto de trabalho: a manopla fica atras e acima da
# mesa, e e isso que deixa o piloto da CG sentado quase reto.
MANOPLA = Vector((0.30, 0.20, 1.075))

BALANCA_PIVO = Vector((0.0, -0.12, 0.42))
AMORTECEDOR_BAIXO = Vector((0.115, -0.56, 0.355))
AMORTECEDOR_CIMA = Vector((0.125, -0.47, 0.80))
PEDALEIRA = Vector((0.19, -0.03, 0.33))

# O piloto: torso a 14 graus da vertical, que e como se senta numa CG -
# guidao alto, pedaleira embaixo do quadril. A postura de 30 graus de antes era
# de moto de rua esportivada, e na CG empurrava o capacete para cima do painel.
QUADRIL = Vector((0.0, -0.24, 0.93))
INCLINACAO_TORSO = math.radians(14.0)
TORSO = 0.50
BRACO, ANTEBRACO = 0.30, 0.28
COXA, CANELA = 0.44, 0.44


def no_garfo(d: float, x: float = 0.0) -> Vector:
    """Ponto do garfo a `d` metros da mesa de cima, descendo para o eixo."""
    return CABECA_GARFO + DIR_GARFO * d + Vector((x, 0.0, 0.0))


def corpo(material, colecao, pai) -> None:
    c = Peca("Moto_Corpo", (0.0, 0.0, 0.0))

    # Quadro: o tubo da coluna de direcao, a espinha que desce para o pivo da
    # balanca e o berco na frente do motor. Quase todo escondido; o que
    # aparece e o tubo preto entre o tanque e o motor, que de lado diz "quadro
    # de tubo" e nao "scooter de plastico".
    c.tubo(no_garfo(-0.02), no_garfo(0.17), 0.032, 0.032, "preto", lados=8)
    c.caminho(
        [no_garfo(0.05), (0.0, 0.05, 0.86), (0.0, -0.10, 0.70), (0.0, -0.13, 0.46)], 0.026, "preto"
    )
    c.caminho([no_garfo(0.15), (0.0, 0.30, 0.66), (0.0, 0.26, 0.52)], 0.024, "preto")
    for lado in (-1.0, 1.0):
        c.caminho(
            [(lado * 0.07, -0.08, 0.74), (lado * 0.10, -0.45, 0.78), (lado * 0.08, -0.86, 0.80)],
            0.014,
            "preto",
        )
        c.caixa((lado * 0.105, -0.12, 0.45), (0.02, 0.12, 0.14), "preto")  # placa do pivo
        # Suporte de cima do amortecedor, preso no quadro.
        c.caixa(AMORTECEDOR_CIMA + Vector((lado * 0.012, 0.0, 0.0)), (0.02, 0.05, 0.05), "preto")

    # Motor: carter, tampas laterais e o cilindro inclinado com as aletas. E o
    # volume cinza que diz "moto de rua" e nao "scooter", e a aleta e a cara da
    # CG - motor arrefecido a ar e o que todo motoboy reconhece.
    c.casco(
        [
            (0.19, 0.40, 0.16, 0.14),
            (0.15, 0.40, 0.24, 0.24),
            (-0.10, 0.40, 0.24, 0.24),
            (-0.15, 0.41, 0.18, 0.18),
        ],
        "motor",
        expoente=3.0,
        gomos=10,
    )
    c.tubo((-0.12, 0.00, 0.40), (-0.155, 0.00, 0.40), 0.10, 0.095, "motor", lados=12)
    c.tubo((0.12, 0.07, 0.41), (0.155, 0.07, 0.41), 0.105, 0.10, "motor", lados=12)
    c.caixa((-0.13, -0.08, 0.43), (0.04, 0.10, 0.10), "preto")  # tampa do pinhao
    eixo_cil = Vector((0.0, math.sin(math.radians(15.0)), math.cos(math.radians(15.0))))
    base_cil = Vector((0.0, 0.15, 0.50))
    c.tubo(base_cil, base_cil + eixo_cil * 0.22, 0.058, 0.055, "preto", lados=8)
    for k in range(6):
        c.caixa(base_cil + eixo_cil * (0.035 + 0.028 * k), (0.19, 0.16, 0.009), "aleta", rot_x=-15.0)
    c.caixa(base_cil + eixo_cil * 0.235, (0.19, 0.16, 0.06), "motor", rot_x=-15.0)
    c.caixa(base_cil + eixo_cil * 0.285, (0.13, 0.11, 0.05), "preto", rot_x=-15.0)
    c.caixa((0.0, 0.05, 0.66), (0.09, 0.09, 0.07), "preto")  # corpo de borboleta
    # Pedais: cambio na esquerda, freio na direita.
    c.barra((-0.16, -0.02, 0.36), (-0.17, 0.14, 0.33), 0.02, 0.015, "preto")
    c.barra((0.16, -0.02, 0.34), (0.16, 0.13, 0.31), 0.02, 0.015, "preto")

    # Protetor de perna, o "mata-cachorro": de fabrica nao vem, mas em moto de
    # entrega e quase uniforme. Ele alarga a silhueta na altura do joelho, que
    # e o que a camera de tras ve passando entre dois carros.
    for lado in (-1.0, 1.0):
        c.caminho(
            [
                (lado * 0.04, 0.30, 0.80),
                (lado * 0.21, 0.28, 0.66),
                (lado * 0.23, 0.24, 0.44),
                (lado * 0.12, 0.14, 0.30),
            ],
            0.014,
            "preto",
        )

    # Pedaleiras do piloto e da garupa.
    for lado in (-1.0, 1.0):
        p = Vector((lado * PEDALEIRA.x, PEDALEIRA.y, PEDALEIRA.z))
        c.caixa(p, (0.10, 0.04, 0.03), "borracha")
        c.barra(p + Vector((-lado * 0.05, 0.0, 0.0)), (lado * 0.10, -0.06, 0.40), 0.02, 0.02, "preto")
        c.caixa((lado * 0.17, -0.42, 0.44), (0.07, 0.03, 0.025), "borracha")

    # Escapamento do lado direito: o cano desce do cabecote, passa por baixo
    # do motor e sobe para o silencioso, com o protetor de calor preto por
    # cima e a ponteira cromada.
    c.caminho(
        [
            (0.03, 0.27, 0.60),
            (0.06, 0.30, 0.44),
            (0.10, 0.22, 0.27),
            (0.15, 0.02, 0.26),
            (0.17, -0.26, 0.31),
        ],
        0.022,
        "metal",
    )
    c.tubo((0.17, -0.24, 0.30), (0.19, -0.78, 0.46), 0.052, 0.046, "metal", lados=10)
    c.tubo((0.19, -0.78, 0.46), (0.192, -0.83, 0.475), 0.03, 0.03, "cromado", lados=8)
    c.barra((0.225, -0.30, 0.37), (0.235, -0.62, 0.46), 0.012, 0.06, "preto")

    # Tanque: largo na frente, estreito atras, com o vinco do joelho. A secao
    # e quase caixa (expoente 2,8): tanque estampado tem quina, mas mole.
    c.casco(
        [
            (-0.15, 0.885, 0.18, 0.07),
            (-0.10, 0.895, 0.25, 0.12),
            (0.00, 0.915, 0.32, 0.20),
            (0.12, 0.925, 0.36, 0.25),
            (0.25, 0.925, 0.34, 0.24),
            (0.33, 0.93, 0.22, 0.14),
        ],
        "pintura",
        expoente=2.8,
        gomos=14,
    )
    for lado in (-1.0, 1.0):
        # O grafismo da lateral: a faixa clara que diz "Titan" sem dizer.
        c.caixa((lado * 0.168, 0.14, 0.955), (0.012, 0.24, 0.035), "grafismo", rot_x=6.0)
        c.caixa((lado * 0.156, 0.02, 0.86), (0.012, 0.16, 0.05), "pintura_escura")
    c.tubo((0.0, 0.17, 1.035), (0.0, 0.17, 1.055), 0.04, 0.035, "cromado", lados=10)

    # Banco de dois lugares, com o degrau da garupa.
    c.casco(
        [
            (-0.86, 0.825, 0.16, 0.05),
            (-0.80, 0.835, 0.23, 0.08),
            (-0.58, 0.835, 0.27, 0.09),
            (-0.46, 0.80, 0.29, 0.07),
            (-0.28, 0.79, 0.30, 0.08),
            (-0.12, 0.81, 0.24, 0.07),
            (0.00, 0.83, 0.15, 0.05),
        ],
        "preto",
        expoente=3.0,
    )

    # Tampas laterais e rabeta, na cor da moto.
    c.casco(
        [
            (-0.38, 0.715, 0.22, 0.08),
            (-0.34, 0.705, 0.26, 0.12),
            (-0.18, 0.70, 0.26, 0.14),
            (-0.13, 0.71, 0.20, 0.09),
        ],
        "pintura",
        expoente=3.0,
        gomos=10,
    )
    c.casco(
        [
            (-0.94, 0.785, 0.12, 0.05),
            (-0.84, 0.775, 0.18, 0.08),
            (-0.60, 0.765, 0.25, 0.10),
            (-0.40, 0.745, 0.26, 0.10),
        ],
        "pintura",
        expoente=3.0,
        gomos=10,
    )
    c.caixa((0.0, -0.945, 0.79), (0.11, 0.025, 0.045), "lanterna")
    # Caixa do filtro de ar, no vao entre a tampa lateral e o motor.
    c.caixa((0.0, -0.24, 0.58), (0.22, 0.22, 0.14), "preto")

    # Bagageiro: alca da garupa com a grade em cima. Em moto de entrega ele
    # nunca falta, e e a silhueta que separa CG de trabalho de CG de passeio.
    for lado in (-1.0, 1.0):
        c.caminho(
            [(lado * 0.12, -0.44, 0.80), (lado * 0.13, -0.50, 0.88), (lado * 0.12, -0.90, 0.89)],
            0.012,
            "preto",
        )
    c.tubo((-0.12, -0.90, 0.89), (0.12, -0.90, 0.89), 0.012, 0.012, "preto")
    c.caixa((0.0, -0.72, 0.89), (0.22, 0.30, 0.012), "preto")

    # Paralama traseiro, suporte e placa, e os piscas de tras.
    c.paralama(EIXO_TRASEIRO, RAIO_RODA + 0.075, 0.12, 95.0, 145.0, "preto")
    c.caminho([(0.0, -0.90, 0.75), (0.0, -0.98, 0.62)], 0.015, "preto")
    c.caixa((0.0, -0.995, 0.54), (0.20, 0.012, 0.13), "placa", rot_x=-12.0)
    for lado in (-1.0, 1.0):
        c.tubo((lado * 0.06, -0.92, 0.73), (lado * 0.17, -0.93, 0.73), 0.008, 0.008, "preto", lados=4)
        c.caixa((lado * 0.195, -0.935, 0.73), (0.05, 0.06, 0.035), "pisca")

    c.objeto(material, colecao, pai)


def direcao(material, colecao, pai) -> bpy.types.Object:
    """Mesa, tubos cromados, farol, painel, guidao e retrovisores."""
    d = Peca("Direcao", CABECA_GARFO)
    for lado in (-1.0, 1.0):
        # O tubo vai ate dentro da bainha: com o garfo esticado a bainha desce
        # 4 cm, e o cromado nao pode aparecer saindo do nada.
        d.tubo(no_garfo(-0.03, lado * GARFO_X), no_garfo(0.46, lado * GARFO_X), 0.017, 0.017, "cromado", lados=8)
    d.caixa(no_garfo(0.0), (0.25, 0.07, 0.03), "preto", rot_x=27.0)  # mesa de cima
    d.caixa(no_garfo(0.15), (0.25, 0.07, 0.035), "preto", rot_x=27.0)  # mesa de baixo

    # Carenagem do farol: o bico trapezoidal da Titan, com o farol de frente e
    # o painel digital em cima.
    d.casco(
        [
            (0.34, 0.935, 0.24, 0.20),
            (0.42, 0.925, 0.23, 0.19),
            (0.475, 0.915, 0.19, 0.15),
        ],
        "pintura",
        expoente=3.5,
        gomos=10,
    )
    d.caixa((0.0, 0.482, 0.912), (0.16, 0.012, 0.11), "farol", rot_x=8.0)
    d.caixa((0.0, 0.34, 1.035), (0.20, 0.10, 0.05), "preto", rot_x=-12.0)
    d.caixa((0.0, 0.335, 1.062), (0.15, 0.07, 0.008), "painel", rot_x=-25.0)
    for lado in (-1.0, 1.0):
        d.tubo((lado * 0.10, 0.42, 0.89), (lado * 0.17, 0.43, 0.89), 0.008, 0.008, "preto", lados=4)
        d.caixa((lado * 0.195, 0.44, 0.89), (0.05, 0.06, 0.035), "pisca")

    # Guidao: tubo dobrado, com a pegada da manopla para tras.
    m = MANOPLA
    d.caminho(
        [
            (-m.x - 0.05, m.y - 0.012, m.z),
            (-0.22, 0.24, 1.07),
            (-0.07, 0.29, 1.05),
            (0.07, 0.29, 1.05),
            (0.22, 0.24, 1.07),
            (m.x + 0.05, m.y - 0.012, m.z),
        ],
        0.011,
        "preto",
    )
    d.caixa((0.0, 0.30, 1.025), (0.08, 0.04, 0.05), "preto")  # pontes
    for lado in (-1.0, 1.0):
        d.tubo((lado * (m.x - 0.065), m.y + 0.005, m.z), (lado * (m.x + 0.06), m.y - 0.01, m.z), 0.018, 0.018, "borracha", lados=8)
        d.caixa((lado * 0.215, 0.22, 1.075), (0.045, 0.05, 0.045), "preto")  # punho de comando
        d.barra((lado * 0.25, 0.25, 1.085), (lado * 0.36, 0.25, 1.075), 0.012, 0.012, "metal")  # manete
        # Retrovisor: na silhueta de tras, e o que faz o guidao existir.
        d.tubo((lado * 0.21, 0.24, 1.08), (lado * 0.27, 0.22, 1.30), 0.007, 0.007, "preto", lados=4)
        d.caixa((lado * 0.29, 0.22, 1.32), (0.11, 0.025, 0.07), "preto")
        d.caixa((lado * 0.29, 0.206, 1.32), (0.09, 0.004, 0.055), "cromado")
    return d.objeto(material, colecao, pai)


def garfo(material, colecao, pai) -> bpy.types.Object:
    """As bainhas, o paralama, a pinca do freio: o que sobe e desce com a roda."""
    g = Peca("Garfo", EIXO_DIANTEIRO)
    for lado in (-1.0, 1.0):
        g.tubo(no_garfo(0.38, lado * GARFO_X), no_garfo(0.79, lado * GARFO_X), 0.025, 0.024, "motor", lados=8)
        g.tubo(no_garfo(0.375, lado * GARFO_X), no_garfo(0.385, lado * GARFO_X), 0.027, 0.027, "preto", lados=8)
    # Paralama dianteiro, colado no pneu: e da bainha, e nao da direcao, porque
    # na CG ele sobe junto com a roda.
    g.paralama(EIXO_DIANTEIRO, RAIO_RODA + 0.03, 0.10, 45.0, 150.0, "pintura", gomos=4)
    g.caixa(EIXO_DIANTEIRO + Vector((-0.085, -0.075, 0.075)), (0.04, 0.08, 0.07), "preto")
    g.tubo(EIXO_DIANTEIRO + Vector((-0.11, 0.0, 0.0)), EIXO_DIANTEIRO + Vector((0.11, 0.0, 0.0)), 0.012, 0.012, "metal")
    return g.objeto(material, colecao, pai)


def balanca(material, colecao, pai) -> bpy.types.Object:
    """Balanca de tubo retangular, corrente na esquerda e cubo do eixo."""
    b = Peca("Balanca", BALANCA_PIVO)
    for lado in (-1.0, 1.0):
        b.barra(
            BALANCA_PIVO + Vector((lado * 0.105, 0.0, 0.0)),
            EIXO_TRASEIRO + Vector((lado * 0.105, 0.0, 0.0)),
            0.03,
            0.05,
            "preto",
        )
        b.caixa(EIXO_TRASEIRO + Vector((lado * 0.11, -0.02, 0.0)), (0.035, 0.08, 0.035), "metal")
        # Orelha de baixo do amortecedor.
        b.caixa(Vector((lado * 0.105, AMORTECEDOR_BAIXO.y, AMORTECEDOR_BAIXO.z)), (0.025, 0.05, 0.05), "preto")
    b.tubo(BALANCA_PIVO + Vector((-0.12, 0.0, 0.0)), BALANCA_PIVO + Vector((0.12, 0.0, 0.0)), 0.025, 0.025, "preto", lados=8)
    b.barra((0.0, -0.28, 0.395), (0.0, -0.34, 0.385), 0.20, 0.03, "preto")
    # Corrente, do pinhao (r = 4,5 cm, perto do pivo) a coroa (r = 10 cm):
    # duas retas, e o protetor preto em cima da de cima.
    x = -0.125
    for topo in (1.0, -1.0):
        b.barra(
            (x, -0.04, 0.42 + 0.045 * topo),
            (x, EIXO_TRASEIRO.y, EIXO_TRASEIRO.z + 0.10 * topo),
            0.012,
            0.012,
            "preto",
        )
    b.barra((x - 0.005, -0.08, 0.49), (x - 0.005, -0.56, 0.44), 0.03, 0.035, "preto")
    return b.objeto(material, colecao, pai)


def amortecedores(material, colecao, suspenso, obj_balanca) -> None:
    """Corpo preso no quadro, mola presa na balanca, um mirando no outro."""
    for lado, sufixo in ((-1.0, "E"), (1.0, "D")):
        cima = Vector((lado * AMORTECEDOR_CIMA.x, AMORTECEDOR_CIMA.y, AMORTECEDOR_CIMA.z))
        baixo = Vector((lado * AMORTECEDOR_BAIXO.x, AMORTECEDOR_BAIXO.y, AMORTECEDOR_BAIXO.z))
        eixo = (baixo - cima).normalized()

        a = Peca("Amortecedor_" + sufixo, cima)
        a.tubo(cima - Vector((0.018, 0.0, 0.0)), cima + Vector((0.018, 0.0, 0.0)), 0.018, 0.018, "preto", lados=6)
        a.tubo(cima, cima + eixo * 0.05, 0.036, 0.036, "preto", lados=8)
        a.tubo(cima + eixo * 0.05, cima + eixo * 0.20, 0.024, 0.024, "preto", lados=8)
        a.objeto(material, colecao, suspenso)

        m = Peca("Mola_" + sufixo, baixo)
        m.tubo(baixo - Vector((0.016, 0.0, 0.0)), baixo + Vector((0.016, 0.0, 0.0)), 0.017, 0.017, "preto", lados=6)
        m.tubo(baixo, baixo - eixo * 0.30, 0.009, 0.009, "cromado", lados=6)
        m.tubo(baixo - eixo * 0.03, baixo - eixo * 0.05, 0.036, 0.036, "preto", lados=8)
        m.mola(baixo - eixo * 0.05, cima + eixo * 0.06, 0.032, 7, 0.0065, "metal")
        m.objeto(material, colecao, obj_balanca)


def moto(material, colecao, raiz) -> None:
    base = vazio("Moto", (0.0, 0.0, 0.0), colecao, raiz)
    suspenso = vazio("Suspenso", (0.0, 0.0, 0.0), colecao, base)
    corpo(material, colecao, suspenso)

    obj_direcao = direcao(material, colecao, suspenso)
    obj_garfo = garfo(material, colecao, obj_direcao)
    roda_frente = Peca("Roda_Dianteira", EIXO_DIANTEIRO)
    roda_frente.roda(EIXO_DIANTEIRO, RAIO_RODA, 0.085, 0.08)
    # Disco de 240 mm do lado esquerdo: gira com a roda, a pinca fica no garfo.
    x = Vector((0.004, 0.0, 0.0))
    disco = EIXO_DIANTEIRO + Vector((-0.072, 0.0, 0.0))
    roda_frente.tubo(disco - x, disco + x, 0.12, 0.12, "cromado", lados=16)
    roda_frente.objeto(material, colecao, obj_garfo)

    obj_balanca = balanca(material, colecao, suspenso)
    roda_tras = Peca("Roda_Traseira", EIXO_TRASEIRO)
    roda_tras.roda(EIXO_TRASEIRO, RAIO_RODA, 0.095, 0.085)
    # Tambor do freio na direita, coroa na esquerda.
    roda_tras.tubo(EIXO_TRASEIRO + Vector((0.02, 0.0, 0.0)), EIXO_TRASEIRO + Vector((0.075, 0.0, 0.0)), 0.075, 0.07, "motor", lados=12)
    roda_tras.tubo(EIXO_TRASEIRO + Vector((-0.13, 0.0, 0.0)), EIXO_TRASEIRO + Vector((-0.12, 0.0, 0.0)), 0.10, 0.10, "preto", lados=16)
    roda_tras.objeto(material, colecao, obj_balanca)

    amortecedores(material, colecao, suspenso, obj_balanca)


# --- O piloto ----------------------------------------------------------------


def piloto(material, colecao, raiz) -> None:
    base = vazio("Piloto", QUADRIL, colecao, raiz)

    eixo = Vector((0.0, math.sin(INCLINACAO_TORSO), math.cos(INCLINACAO_TORSO)))
    costas = Vector((0.0, -math.cos(INCLINACAO_TORSO), math.sin(INCLINACAO_TORSO)))
    pescoco = QUADRIL + eixo * TORSO
    rot = -math.degrees(INCLINACAO_TORSO)
    no_torso = Matrix.Translation(QUADRIL) @ Matrix.Rotation(-INCLINACAO_TORSO, 4, "X")

    tronco = Peca("Tronco", QUADRIL)
    # Quadril e torso moldados, de baixo para cima: cintura mais fina que o
    # peito, ombro largo, e o peito um pouco a frente da coluna.
    tronco.casco(
        [(-0.09, -0.02, 0.26, 0.18), (0.0, -0.02, 0.33, 0.22), (0.08, -0.01, 0.31, 0.20)],
        "calca",
        eixo="z",
        expoente=2.4,
        gomos=10,
        matriz=no_torso,
    )
    tronco.casco(
        [
            (0.06, -0.01, 0.31, 0.20),
            (0.20, 0.0, 0.33, 0.21),
            (0.34, 0.015, 0.39, 0.23),
            (0.43, 0.005, 0.42, 0.21),
            (0.49, -0.01, 0.30, 0.15),
        ],
        "jaqueta",
        eixo="z",
        expoente=2.4,
        gomos=12,
        matriz=no_torso,
    )
    # Faixa refletiva na jaqueta, na altura do peito: e equipamento obrigatorio
    # de motofrete, e uma linha clara que ajuda a ler a inclinacao do torso.
    tronco.caixa(QUADRIL + eixo * (TORSO * 0.62), (0.40, 0.235, 0.035), "jaqueta_faixa", rot_x=rot)
    obj_tronco = tronco.objeto(material, colecao, base)

    cabeca = Peca("Cabeca", pescoco)
    cabeca.tubo(pescoco - eixo * 0.03, pescoco + eixo * 0.08, 0.065, 0.055, "jaqueta", lados=8)
    centro_capacete = pescoco + Vector((0.0, 0.03, 0.15))
    cabeca.esfera(
        centro_capacete, (0.135, 0.155, 0.145), "capacete", gomos=12, aneis=8, viseira="viseira"
    )
    cabeca.objeto(material, colecao, obj_tronco)

    # A bag termica, nas costas e presa ao tronco: quando o piloto cai, ela vai
    # junto, e e o maior bloco de cor do personagem visto de tras.
    #
    # A borda de cima para abaixo do pescoco de proposito. A camera de jogo fica
    # 2,25 m acima e 6,4 m atras: com a bag ate a nuca, o capacete some atras
    # dela e o personagem vira uma caixa laranja andando sozinha.
    altura_bag = TORSO * 0.52
    centro_bag = QUADRIL + eixo * altura_bag + costas * 0.27
    na_bag = Matrix.Translation(centro_bag) @ Matrix.Rotation(-INCLINACAO_TORSO, 4, "X")
    bag = Peca("Bag", QUADRIL + eixo * altura_bag + costas * 0.11)
    bag.casco(
        [(-0.21, 0.0, 0.44, 0.32), (0.19, 0.0, 0.44, 0.32)],
        "bag",
        eixo="z",
        expoente=7.0,
        gomos=16,
        matriz=na_bag,
    )
    bag.casco(
        [(0.19, 0.0, 0.45, 0.33), (0.225, 0.0, 0.45, 0.33)],
        "bag_tampa",
        eixo="z",
        expoente=7.0,
        gomos=16,
        matriz=na_bag,
    )
    bag.caixa(centro_bag + costas * 0.16, (0.36, 0.012, 0.05), "bag_faixa", rot_x=rot)
    bag.objeto(material, colecao, obj_tronco)

    for lado, sufixo in ((-1.0, "E"), (1.0, "D")):
        ombro = pescoco - eixo * 0.065 + Vector((lado * 0.19, 0.0, 0.0))
        mao = Vector((lado * MANOPLA.x, MANOPLA.y, MANOPLA.z))
        cotovelo = ik_dois_ossos(ombro, mao, BRACO, ANTEBRACO, (lado * 1.0, -0.3, -1.0))

        braco = Peca("Braco_" + sufixo, ombro)
        braco.esfera(ombro, (0.075, 0.075, 0.075), "jaqueta", gomos=8, aneis=5)
        braco.tubo(ombro, cotovelo, 0.058, 0.048, "jaqueta", lados=8)
        obj_braco = braco.objeto(material, colecao, obj_tronco)

        antebraco = Peca("Antebraco_" + sufixo, cotovelo)
        # Rotula: sem ela, o cotovelo dobrado abre um vao entre os dois tubos.
        antebraco.esfera(cotovelo, (0.05, 0.05, 0.05), "jaqueta", gomos=8, aneis=5)
        antebraco.tubo(cotovelo, mao, 0.047, 0.036, "jaqueta", lados=8)
        obj_antebraco = antebraco.objeto(material, colecao, obj_braco)

        # A mao e peca a parte, com o pivo na manopla: e o alvo do IK quando o
        # guidao vira, e a ponta que fecha a cadeia Braco -> Antebraco -> Mao.
        luva = Peca("Mao_" + sufixo, mao)
        luva.caixa(mao + Vector((0.0, 0.01, 0.005)), (0.08, 0.09, 0.075), "luva")
        luva.caixa(mao + Vector((-lado * 0.035, 0.03, 0.02)), (0.03, 0.05, 0.03), "luva")
        luva.objeto(material, colecao, obj_antebraco)

        quadril = QUADRIL + Vector((lado * 0.11, 0.0, -0.03))
        tornozelo = Vector((lado * PEDALEIRA.x, PEDALEIRA.y - 0.04, PEDALEIRA.z + 0.07))
        # Joelho para a frente e quase sem abrir: piloto de rua aperta o tanque
        # com os joelhos. Aberto, de tras le como sapo em cima de scooter.
        joelho = ik_dois_ossos(quadril, tornozelo, COXA, CANELA, (lado * 0.35, 1.0, 0.3))

        coxa = Peca("Coxa_" + sufixo, quadril)
        coxa.tubo(quadril, joelho, 0.085, 0.065, "calca", lados=8)
        obj_coxa = coxa.objeto(material, colecao, base)

        canela = Peca("Canela_" + sufixo, joelho)
        canela.esfera(joelho, (0.066, 0.066, 0.066), "calca", gomos=8, aneis=5)
        canela.tubo(joelho, tornozelo, 0.058, 0.045, "calca", lados=8)
        obj_canela = canela.objeto(material, colecao, obj_coxa)

        # O pe e peca a parte, com o pivo no tornozelo: no chao ele fica
        # paralelo ao asfalto enquanto a canela inclina. Bota de cano: o cano
        # cobre o tornozelo, o solado passa da pedaleira para a frente.
        pe = Peca("Pe_" + sufixo, tornozelo)
        pe.tubo(tornozelo + Vector((0.0, 0.0, 0.09)), tornozelo - Vector((0.0, 0.0, 0.03)), 0.05, 0.052, "bota", lados=8)
        pe.caixa(tornozelo + Vector((0.0, 0.055, -0.035)), (0.10, 0.24, 0.08), "bota", topo=(0.09, 0.18))
        pe.objeto(material, colecao, obj_canela)


# --- Execucao ----------------------------------------------------------------


def limpa_cena() -> None:
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj)
    for colecao in (bpy.data.meshes, bpy.data.materials, bpy.data.images, bpy.data.collections):
        for item in list(colecao):
            colecao.remove(item)


def conta_tris(raiz) -> int:
    total = 0
    for obj in [raiz, *raiz.children_recursive]:
        if obj.type == "MESH":
            total += sum(len(p.vertices) - 2 for p in obj.data.polygons)
    return total


def main() -> None:
    os.makedirs(SAIDA, exist_ok=True)
    limpa_cena()

    colecao = bpy.data.collections.new("Entregador")
    bpy.context.scene.collection.children.link(colecao)

    albedo = textura("entregador_albedo", 0, "sRGB")
    textura("entregador_mascara", 1, "Non-Color")
    mat = material(albedo)

    raiz = vazio("Entregador", (0.0, 0.0, 0.0), colecao)
    moto(mat, colecao, raiz)
    piloto(mat, colecao, raiz)

    # `bpy.data.objects`, e nao `view_layer.objects`: a view layer ainda guarda
    # vaga vazia dos objetos que `limpa_cena` acabou de apagar.
    arvore = {raiz, *raiz.children_recursive}
    for obj in bpy.data.objects:
        obj.select_set(obj in arvore)
    bpy.context.view_layer.objects.active = raiz

    bpy.ops.wm.save_as_mainfile(filepath=BLEND, relative_remap=True)
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(SAIDA, "entregador.glb"),
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
    print("entregador: %d tris" % conta_tris(raiz))


main()
