"""Gerador do entregador: moto e piloto como pecas separadas.

Roda dentro do Blender (5.2+), e nao fora dele:

    blender --background --factory-startup --python arte/entregador.py

ou colado no editor de texto do Blender. Apaga a cena atual, monta o modelo,
salva `arte/entregador.blend` e exporta `assets/entregador/entregador.glb`
mais as duas texturas. `--factory-startup` deixa de fora os add-ons e as
preferencias de quem roda: mesma entrada, mesmo `.glb`, byte a byte.

Este script e a fonte; o `.blend` e o `.glb` sao build. Pela mesma razao que o
`baseline.json` e gerado e revisado em vez de digitado: geometria descrita em
numeros da pra revisar em diff, e um `.blend` binario nao.

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
- **Sem rig.** O `PROVA_VISUAL.md` pede pose parada na prova. Peca rigida
  presa na articulacao e o jeito dos jogos da epoca, anima por transformacao
  de no, e vira rig depois sem refazer malha se a prova pedir.

A moto e o piloto sao arvores separadas por tres motivos: a queda (o piloto
voa, a moto desliza, cada um com a sua fisica), o soco (o torso gira sem
arrastar o guidao) e a troca de paleta dos rivais, que pinta piloto e moto
independentemente.

O que da para animar, e por onde:

    Entregador
      Moto
        Moto_Corpo
        Roda_Traseira      gira em X; o pivo e o eixo
        Direcao            esterca em volta da reta Direcao -> Roda_Dianteira
          Roda_Dianteira   gira em X
      Piloto               o quadril; solta da moto inteiro na queda
        Tronco             deita e levanta o torso em volta do quadril
          Cabeca, Bag
          Braco_E/D -> Antebraco_E/D -> Mao_E/D
        Coxa_E/D -> Canela_E/D -> Pe_E/D

As duas cadeias de membro sao feitas para IK de dois ossos, que e o que poe a
mao na manopla quando o guidao vira e o pe no chao quando a moto para. Nada
precisa ser medido a parte: a posicao de cada filho e o osso do pai.
`Canela.position` e a coxa, `Pe.position` e a canela, e o comprimento de cada
uma e o tamanho desse vetor. Abrir e fechar o joelho e o mesmo IK com o pe
parado na pedaleira e o polo correndo de lado.
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
}
CELULAS = {nome: i for i, nome in enumerate(PALETA)}

# Aresta mais aberta que isto fica dura. Pega o 90 graus das caixas e deixa
# macio o tubo de 6 lados (60 graus) e a esfera de 8 gomos (45 graus): membro e
# pneu leem como redondos, carenagem le como chapa.
ANGULO_DURO = math.radians(65.0)


def uv_da_celula(i: int) -> tuple:
    por_linha = TEXTURA // CELULA
    return ((i % por_linha + 0.5) / por_linha, (i // por_linha + 0.5) / por_linha)


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

    def tubo(self, a, b, raio_a, raio_b, cor, lados=6, leque=False) -> set:
        """Tronco de cone de `a` a `b`. Devolve as faces, para pintura parcial.

        `leque` fecha as pontas com triangulos saindo do centro, em vez de um
        poligono so: e o que deixa pintar o aro da roda em fatias.
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

    def esfera(self, centro, raios, cor, gomos=8, aneis=6, viseira=None) -> None:
        """Esfera achatada; `viseira` pinta a faixa da frente, na altura do olho.

        Viseira pintada nas faces da propria esfera, e nao uma placa colada na
        frente: placa reta numa esfera de 8 gomos sobra pelos lados e o capacete
        vira oculos de realidade virtual.
        """
        verts = bmesh.ops.create_uvsphere(
            self.bm, u_segments=gomos, v_segments=aneis, radius=1.0
        )["verts"]
        self._pinta(verts, cor)
        if viseira is not None:
            for face in {f for v in verts for f in v.link_faces}:
                meio = face.calc_center_median()
                if meio.y > 0.5 and 0.05 < meio.z < 0.45:
                    face[self.cor] = CELULAS[viseira]
        m = Matrix.Translation(Vector(centro)) @ Matrix.Diagonal((*raios, 1.0))
        bmesh.ops.transform(self.bm, matrix=m, verts=verts)

    def paralama(self, eixo, raio, largura, de, ate, cor, gomos=2) -> None:
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
            self.caixa(centro, (largura, comprimento, 0.025), cor, rot_x=math.degrees(fi) - 90.0)

    def roda(self, centro, raio, largura, cor_pneu="pneu") -> None:
        """Pneu de 12 lados com o aro saltado dos dois lados.

        O aro e um cilindro mais largo que o pneu: as tampas dele aparecem como
        o disco da roda visto de lado. Pintado em oito fatias alternadas, que
        fazem o papel dos raios: disco de cor lisa girando e igual a disco
        parado, e a roda girar e metade da leitura de velocidade.
        """
        c = Vector(centro)
        x = Vector((largura * 0.5, 0.0, 0.0))
        self.tubo(c - x, c + x, raio, raio, cor_pneu, lados=12)
        xa = Vector((largura * 0.5 + 0.01, 0.0, 0.0))
        aro = self.tubo(c - xa, c + xa, raio * 0.58, raio * 0.58, "aro", lados=8, leque=True)
        for face in aro:
            meio = face.calc_center_median()
            if abs(abs(meio.x - c.x) - xa.x) > 1e-4:
                continue  # lateral do aro, nao tampa
            angulo = math.atan2(meio.z - c.z, meio.y - c.y) % math.tau
            if int(angulo // (math.tau / 8)) % 2 == 0:
                face[self.cor] = CELULAS["metal"]
        xc = Vector((largura * 0.5 + 0.025, 0.0, 0.0))
        self.tubo(c - xc, c + xc, raio * 0.16, raio * 0.16, "metal", lados=6)

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


# --- O modelo ----------------------------------------------------------------
#
# Medidas de uma 150-160 cilindradas de rua, a moto de entrega brasileira: entre
# eixos de 1,30 m, roda de 0,60 m, banco a ~0,80 m. Tudo cabe na caixa de
# 0,75 x 1,75 x 2,1 m do corpo fisico (`SIZE` no `player_bike.gd`), que e o que
# o jogador ja aprendeu a ler como "onde a moto esta".

EIXO_DIANTEIRO = Vector((0.0, 0.66, 0.30))
EIXO_TRASEIRO = Vector((0.0, -0.66, 0.30))
RAIO_RODA = 0.30
CABECA_GARFO = Vector((0.0, 0.47, 0.98))  # onde o garfo encontra o quadro
GUIDAO = (0.0, 0.40, 1.08)
MANOPLA_X = 0.31

# O piloto: torso deitado 30 graus para a frente, que e postura de quem anda de
# moto de rua no corredor, nao de esportiva nem de chopper.
QUADRIL = Vector((0.0, -0.26, 0.96))
INCLINACAO_TORSO = math.radians(30.0)
TORSO = 0.50
BRACO, ANTEBRACO = 0.30, 0.29
COXA, CANELA = 0.45, 0.45
PEDALEIRA = (0.20, -0.02, 0.36)


def moto(material, colecao, raiz) -> None:
    base = vazio("Moto", (0.0, 0.0, 0.0), colecao, raiz)

    corpo = Peca("Moto_Corpo", (0.0, 0.0, 0.0))
    # Motor e cabecote: o volume cinza que diz "moto de rua" e nao "scooter".
    corpo.caixa((0.0, 0.06, 0.40), (0.26, 0.36, 0.28), "motor")
    corpo.caixa((0.0, 0.16, 0.60), (0.20, 0.18, 0.16), "motor", rot_x=-20.0)
    corpo.caixa((0.0, -0.10, 0.48), (0.30, 0.16, 0.16), "preto")  # carter/cambio
    # Quadro: tubo do garfo ao motor e do garfo ao banco.
    corpo.tubo(CABECA_GARFO, (0.0, 0.22, 0.52), 0.03, 0.03, "preto")
    corpo.tubo(CABECA_GARFO, (0.0, -0.30, 0.80), 0.025, 0.025, "preto")
    # Tanque: afunila para cima, e a peca de cor mais vista de tras.
    corpo.caixa((0.0, 0.20, 0.92), (0.28, 0.44, 0.20), "pintura", rot_x=4.0, topo=(0.22, 0.36))
    corpo.caixa((0.0, 0.02, 0.84), (0.20, 0.10, 0.08), "pintura_escura")
    # Tampas laterais e rabeta.
    corpo.caixa((0.0, -0.20, 0.70), (0.27, 0.26, 0.18), "pintura")
    corpo.caixa((0.0, -0.66, 0.82), (0.20, 0.36, 0.10), "pintura", rot_x=-8.0, topo=(0.16, 0.30))
    corpo.caixa((0.0, -0.86, 0.79), (0.12, 0.04, 0.06), "lanterna")
    # Banco: preto, longo, de dois lugares.
    corpo.caixa((0.0, -0.30, 0.86), (0.26, 0.62, 0.08), "preto", rot_x=-3.0, topo=(0.24, 0.58))
    # Paralama traseiro, do fim da rabeta descendo atras da roda, e a placa
    # pendurada nele. O bloco de cima fecha o vao entre a rabeta e o paralama,
    # que de lado lia como uma peca solta no ar.
    corpo.caixa((0.0, -0.74, 0.715), (0.14, 0.24, 0.11), "preto")
    corpo.paralama(EIXO_TRASEIRO, RAIO_RODA + 0.06, 0.14, 95.0, 145.0, "preto")
    corpo.caixa((0.0, -0.975, 0.45), (0.20, 0.015, 0.12), "placa", rot_x=-12.0)
    # Balanca e amortecedores, um de cada lado.
    for lado in (-1.0, 1.0):
        corpo.tubo((lado * 0.10, -0.08, 0.36), (lado * 0.10, -0.66, 0.30), 0.025, 0.02, "preto")
        corpo.tubo((lado * 0.12, -0.56, 0.33), (lado * 0.12, -0.44, 0.80), 0.03, 0.025, "metal")
        corpo.caixa((lado * 0.19, -0.02, 0.33), (0.08, 0.04, 0.025), "preto")  # pedaleira
    # Escapamento do lado direito: o cano desce do cabecote e corre para tras.
    corpo.tubo((0.07, 0.20, 0.50), (0.13, 0.05, 0.26), 0.025, 0.025, "metal")
    corpo.tubo((0.13, 0.05, 0.26), (0.15, -0.30, 0.32), 0.025, 0.03, "metal")
    corpo.tubo((0.15, -0.30, 0.34), (0.17, -0.78, 0.46), 0.05, 0.045, "metal")
    corpo.objeto(material, colecao, base)

    roda_tras = Peca("Roda_Traseira", EIXO_TRASEIRO)
    roda_tras.roda(EIXO_TRASEIRO, RAIO_RODA, 0.11)
    roda_tras.objeto(material, colecao, base)

    # Direcao: garfo, farol, guidao e retrovisores giram juntos. O pivo e a
    # cabeca do garfo, e a roda dianteira e filha dela.
    direcao = Peca("Direcao", CABECA_GARFO)
    for lado in (-1.0, 1.0):
        direcao.tubo((lado * 0.08, 0.50, 1.02), (lado * 0.08, 0.66, 0.30), 0.028, 0.024, "metal")
    direcao.caixa((0.0, 0.50, 0.98), (0.22, 0.08, 0.05), "preto")  # mesa do garfo
    direcao.tubo((0.0, 0.56, 0.90), (0.0, 0.68, 0.90), 0.09, 0.085, "preto", lados=8)
    direcao.tubo((0.0, 0.68, 0.90), (0.0, 0.70, 0.90), 0.075, 0.075, "farol", lados=8)
    direcao.caixa((0.0, 0.52, 1.05), (0.12, 0.06, 0.06), "preto")  # painel
    direcao.tubo(
        (-MANOPLA_X - 0.04, GUIDAO[1], GUIDAO[2]),
        (MANOPLA_X + 0.04, GUIDAO[1], GUIDAO[2]),
        0.014,
        0.014,
        "preto",
    )
    direcao.tubo((0.0, 0.47, 1.02), (0.0, GUIDAO[1], GUIDAO[2]), 0.02, 0.02, "preto")
    for lado in (-1.0, 1.0):
        # Retrovisor: na silhueta de tras, e o que faz o guidao existir.
        direcao.tubo(
            (lado * 0.24, GUIDAO[1], GUIDAO[2]),
            (lado * 0.30, 0.42, 1.28),
            0.008,
            0.008,
            "preto",
            lados=4,
        )
        direcao.caixa((lado * 0.31, 0.42, 1.31), (0.10, 0.02, 0.06), "preto")
    # Paralama dianteiro: gira com o guidao, por isso mora na direcao.
    direcao.paralama(EIXO_DIANTEIRO, RAIO_RODA + 0.04, 0.13, 40.0, 120.0, "pintura")
    obj_direcao = direcao.objeto(material, colecao, base)

    roda_frente = Peca("Roda_Dianteira", EIXO_DIANTEIRO)
    roda_frente.roda(EIXO_DIANTEIRO, RAIO_RODA, 0.09)
    roda_frente.objeto(material, colecao, obj_direcao)


def piloto(material, colecao, raiz) -> None:
    base = vazio("Piloto", QUADRIL, colecao, raiz)

    eixo = Vector((0.0, math.sin(INCLINACAO_TORSO), math.cos(INCLINACAO_TORSO)))
    costas = Vector((0.0, -math.cos(INCLINACAO_TORSO), math.sin(INCLINACAO_TORSO)))
    pescoco = QUADRIL + eixo * TORSO
    rot = -math.degrees(INCLINACAO_TORSO)

    tronco = Peca("Tronco", QUADRIL)
    tronco.caixa(QUADRIL + Vector((0.0, -0.02, 0.0)), (0.32, 0.24, 0.16), "calca")
    tronco.caixa(
        QUADRIL + eixo * (TORSO * 0.5),
        (0.30, 0.22, TORSO),
        "jaqueta",
        rot_x=rot,
        topo=(0.38, 0.22),
    )
    # Faixa refletiva na jaqueta, na altura do peito: e equipamento obrigatorio
    # de motofrete, e uma linha clara que ajuda a ler a inclinacao do torso.
    tronco.caixa(
        QUADRIL + eixo * (TORSO * 0.62),
        (0.36, 0.225, 0.04),
        "jaqueta_faixa",
        rot_x=rot,
    )
    obj_tronco = tronco.objeto(material, colecao, base)

    cabeca = Peca("Cabeca", pescoco)
    cabeca.tubo(pescoco - eixo * 0.02, pescoco + eixo * 0.08, 0.07, 0.06, "jaqueta")
    centro_capacete = pescoco + Vector((0.0, 0.05, 0.15))
    cabeca.esfera(centro_capacete, (0.135, 0.155, 0.14), "capacete", viseira="viseira")
    cabeca.objeto(material, colecao, obj_tronco)

    # A bag termica, nas costas e presa ao tronco: quando o piloto cai, ela vai
    # junto, e e o maior bloco de cor do personagem visto de tras.
    #
    # A borda de cima para abaixo do pescoco de proposito. A camera de jogo fica
    # 2,25 m acima e 6,4 m atras: com a bag ate a nuca, o capacete some atras
    # dela e o personagem vira uma caixa laranja andando sozinha.
    altura_bag = TORSO * 0.54
    centro_bag = QUADRIL + eixo * altura_bag + costas * 0.28
    bag = Peca("Bag", QUADRIL + eixo * altura_bag + costas * 0.11)
    bag.caixa(centro_bag, (0.46, 0.34, 0.42), "bag", rot_x=rot)
    bag.caixa(centro_bag + eixo * 0.215, (0.47, 0.35, 0.03), "bag_tampa", rot_x=rot)
    bag.caixa(centro_bag + costas * 0.17, (0.38, 0.012, 0.05), "bag_faixa", rot_x=rot)
    bag.objeto(material, colecao, obj_tronco)

    for lado, sufixo in ((-1.0, "E"), (1.0, "D")):
        ombro = pescoco - eixo * 0.07 + Vector((lado * 0.19, 0.0, 0.0))
        mao = Vector((lado * MANOPLA_X, GUIDAO[1] - 0.02, GUIDAO[2]))
        cotovelo = ik_dois_ossos(ombro, mao, BRACO, ANTEBRACO, (lado * 1.0, -0.3, -1.0))

        braco = Peca("Braco_" + sufixo, ombro)
        braco.esfera(ombro, (0.075, 0.075, 0.075), "jaqueta", gomos=6, aneis=4)
        braco.tubo(ombro, cotovelo, 0.06, 0.05, "jaqueta")
        obj_braco = braco.objeto(material, colecao, obj_tronco)

        antebraco = Peca("Antebraco_" + sufixo, cotovelo)
        # Rotula: sem ela, o cotovelo dobrado abre um vao entre os dois tubos.
        antebraco.esfera(cotovelo, (0.052, 0.052, 0.052), "jaqueta", gomos=6, aneis=4)
        antebraco.tubo(cotovelo, mao, 0.05, 0.04, "jaqueta")
        obj_antebraco = antebraco.objeto(material, colecao, obj_braco)

        # A mao e peca a parte, com o pivo na manopla: e o alvo do IK quando o
        # guidao vira, e a ponta que fecha a cadeia Braco -> Antebraco -> Mao.
        luva = Peca("Mao_" + sufixo, mao)
        luva.caixa(mao, (0.08, 0.09, 0.07), "luva")
        luva.objeto(material, colecao, obj_antebraco)

        quadril = QUADRIL + Vector((lado * 0.11, 0.0, -0.03))
        tornozelo = Vector((lado * PEDALEIRA[0], PEDALEIRA[1] - 0.04, PEDALEIRA[2] + 0.06))
        # Joelho para a frente e quase sem abrir: piloto de rua aperta o tanque
        # com os joelhos. Aberto, de tras le como sapo em cima de scooter.
        joelho = ik_dois_ossos(quadril, tornozelo, COXA, CANELA, (lado * 0.15, 1.0, 0.3))

        coxa = Peca("Coxa_" + sufixo, quadril)
        coxa.tubo(quadril, joelho, 0.08, 0.065, "calca")
        obj_coxa = coxa.objeto(material, colecao, base)

        canela = Peca("Canela_" + sufixo, joelho)
        canela.esfera(joelho, (0.066, 0.066, 0.066), "calca", gomos=6, aneis=4)
        canela.tubo(joelho, tornozelo, 0.06, 0.05, "calca")
        obj_canela = canela.objeto(material, colecao, obj_coxa)

        # O pe e peca a parte, com o pivo no tornozelo: no chao ele fica
        # paralelo ao asfalto enquanto a canela inclina.
        pe = Peca("Pe_" + sufixo, tornozelo)
        pe.caixa(tornozelo + Vector((0.0, 0.05, -0.03)), (0.10, 0.22, 0.09), "bota")
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
