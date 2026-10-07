"""Gerador do transito: hatch, seda, SUV, taxi e onibus, com gente dentro.

Roda dentro do Blender (5.2+), igual ao entregador:

    blender --background --factory-startup --python arte/carros.py

Apaga a cena, monta os cinco, salva `arte/carros.blend` e exporta
`assets/carros/carros.glb` mais as duas texturas. Mesma receita, mesmo `.glb`,
byte a byte: este script e a fonte, o resto e build.

| no        | comprimento x largura x altura | de onde vem                              |
| --------- | ------------------------------ | ---------------------------------------- |
| `Hatch`   | 3,90 x 1,72 x 1,45 m           | o compacto de duas portas, Gol e Onix     |
| `Seda`    | 4,40 x 1,74 x 1,46 m           | o seda prata e branco das referencias     |
| `SUV`     | 4,30 x 1,80 x 1,66 m           | o SUV escuro do video 1                   |
| `Taxi`    | 4,40 x 1,74 x 1,60 m           | o seda com a faixa azul e o luminoso do Rio |
| `Onibus`  | 12,2 x 2,50 x 3,30 m           | o urbano de piso alto, porta a direita    |

Convencoes, as mesmas do `entregador.py` e pelos mesmos motivos:

- **Metro, Z para cima, frente em +Y.** O glTF poe +Y em -Z, a frente de um
  `Node3D`. Direita e +X nos dois lados da exportacao.
- **Origem no chao, no meio do carro.** O colisor do `traffic_car.gd` sai do
  AABB da `Lataria`, entao a caixa de bater e a lataria que se ve.
- **Toda rotacao e identidade, a origem de cada peca e a articulacao.** Porta
  gira em volta da dobradica, roda em volta do eixo, volante em volta da
  coluna. O `carro.gd` anima tudo por transformacao de no, sem clipe.

O que da para animar, e por onde:

    Hatch | Seda | SUV | Taxi | Onibus
      Carroceria        a massa suspensa: arfa, mergulha e rola em volta daqui
        Lataria         casco, vidro fixo, interior, luzes. O colisor sai dela
        Volante         gira em volta da reta Volante -> Coluna
          Coluna
        Motorista       o quadril, sentado
          Tronco
            Cabeca
            Braco_E/D -> Antebraco_E/D -> Mao_E/D   IK ate o aro do volante
          Pernas
        Passageiro(s)   estatico
        Porta_DE/DD/TE/TD   giram em Y na dobradica, para fora (carros)
        Folha_1A/1B/2A/2B   giram em Y na dobradica, para dentro (onibus)
        Retrovisores    so no onibus: as orelhas, fora do colisor
      Roda_DE/DD/TE/TD  nao suspensas: giram em X; as dianteiras estercam em Y

As rodas sao filhas do carro, e nao da carroceria, de proposito: e a
carroceria que se mexe em cima delas. Mergulho na freada e rolagem na troca de
faixa so leem porque o vao entre o pneu e o paralama muda.

**O vidro e um segundo material.** Toda face pintada de `vidro` sai com o
material `vidro`, e o jogo troca so essa superficie por um shader
transparente. E por isso que o interior existe: banco, painel e motorista sao
vistos pelo vidro, e a porta aberta mostra a perna de quem esta dirigindo.
"""

import math
import os

import bmesh
import bpy
from mathutils import Matrix, Vector

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLEND = os.path.join(RAIZ, "arte", "carros.blend")
SAIDA = os.path.join(RAIZ, "assets", "carros")

# --- Paleta ------------------------------------------------------------------
#
# Mesmo esquema do entregador: celulas chapadas de 32 px, uma textura so, e a
# mascara no mesmo UV. A mascara aqui carrega tres coisas:
#
# - R = pintura da lataria. E o que deixa o mesmo seda ser prata, branco ou
#   preto, e o taxi ser amarelo, sem um modelo por cor.
# - G = o que acende ou troca de cor por carro, em sextos: 1 pele, 2 camisa do
#   motorista, 3 camisa do passageiro, 4 seta esquerda, 5 seta direita,
#   6 lanterna. Degrau e nao canal porque so ha tres canais, e a seta da
#   esquerda precisa piscar sem a da direita.
# - B = sempre aceso: o luminoso do taxi e o letreiro do onibus.

TEXTURA = 256
CELULA = 32

PINTURA = (1.0, 0.0, 0.0)
NADA = (0.0, 0.0, 0.0)
ACESO = (0.0, 0.0, 1.0)


def degrau(k: int) -> tuple:
    return (0.0, k / 6.0, 0.0)


PELE, CAMISA, CAMISA2, SETA_E, SETA_D, LANTERNA = (degrau(k) for k in range(1, 7))

# nome: (albedo em sRGB, mascara)
PALETA = {
    # Prata de fabrica: a cor mais comum da frota brasileira, e a que sobra
    # quando o mundo nao pinta (no `.blend`, por exemplo).
    "pintura": ((0.66, 0.67, 0.70), PINTURA),
    # Soleira e frisos: a mesma pintura um tom abaixo, para a lateral nao virar
    # uma chapa so a 30 m.
    "pintura_sombra": ((0.46, 0.47, 0.50), PINTURA),
    "preto": ((0.05, 0.05, 0.06), NADA),
    "plastico": ((0.13, 0.13, 0.14), NADA),
    "forro": ((0.22, 0.21, 0.20), NADA),
    "banco": ((0.10, 0.10, 0.11), NADA),
    "painel": ((0.07, 0.07, 0.08), NADA),
    "pneu": ((0.045, 0.045, 0.05), NADA),
    "aro": ((0.58, 0.59, 0.61), NADA),
    "aro_vazado": ((0.10, 0.10, 0.11), NADA),
    "cromo": ((0.82, 0.83, 0.84), NADA),
    "farol": ((0.90, 0.92, 0.92), NADA),
    "re": ((0.86, 0.86, 0.84), NADA),
    "lanterna": ((0.70, 0.05, 0.04), LANTERNA),
    "seta_e": ((0.95, 0.52, 0.06), SETA_E),
    "seta_d": ((0.95, 0.52, 0.06), SETA_D),
    # Placa Mercosul: branca com a tarja azul em cima.
    "placa": ((0.93, 0.93, 0.92), NADA),
    "placa_tarja": ((0.10, 0.22, 0.58), NADA),
    # A celula que o vidro usa. O shader do vidro nao le a textura, mas o
    # `.blend` le, e e o que faz o carro abrir com vidro escuro e nao prata.
    "vidro": ((0.10, 0.12, 0.14), NADA),
    "pele": ((0.60, 0.42, 0.31), PELE),
    "camisa": ((0.82, 0.82, 0.80), CAMISA),
    "camisa2": ((0.32, 0.46, 0.68), CAMISA2),
    "calca": ((0.15, 0.17, 0.23), NADA),
    "cabelo": ((0.07, 0.05, 0.04), NADA),
    "sapato": ((0.09, 0.08, 0.07), NADA),
    # O taxi do Rio: amarelo (a pintura), faixa azul na lateral e o luminoso.
    "faixa_taxi": ((0.06, 0.24, 0.66), NADA),
    "luminoso": ((0.98, 0.96, 0.86), ACESO),
    # Onibus: a pintura e a cor do consorcio, o resto e fixo.
    "branco": ((0.90, 0.90, 0.88), NADA),
    "letreiro": ((0.04, 0.04, 0.05), NADA),
    "letreiro_led": ((1.00, 0.60, 0.08), ACESO),
    "piso": ((0.18, 0.18, 0.19), NADA),
    "corrimao": ((0.96, 0.74, 0.08), NADA),
    "banco_onibus": ((0.16, 0.24, 0.46), NADA),
    # Os passageiros do onibus, que nao trocam de cor: sao dez, e de longe o
    # que se le e gente na janela, nao a roupa de cada um.
    "roupa_1": ((0.75, 0.20, 0.18), NADA),
    "roupa_2": ((0.20, 0.50, 0.32), NADA),
    "roupa_3": ((0.90, 0.80, 0.30), NADA),
    "roupa_4": ((0.85, 0.85, 0.82), NADA),
    "roupa_5": ((0.18, 0.20, 0.30), NADA),
    "pele_clara": ((0.80, 0.62, 0.50), NADA),
    "pele_media": ((0.62, 0.44, 0.32), NADA),
    "pele_escura": ((0.36, 0.24, 0.17), NADA),
}
CELULAS = {nome: i for i, nome in enumerate(PALETA)}

# Aresta mais aberta que isto fica dura. O anel do casco tem quinas de 45
# graus, que alisam e fazem a lataria ler como chapa curva; a caixa de 90 graus
# continua caixa.
ANGULO_DURO = math.radians(50.0)

Z = Vector((0.0, 0.0, 1.0))


def uv_da_celula(i: int) -> tuple:
    por_linha = TEXTURA // CELULA
    return ((i % por_linha + 0.5) / por_linha, (i // por_linha + 0.5) / por_linha)


# --- Construcao de malha -----------------------------------------------------


class Peca:
    """Uma malha em construcao, em coordenadas de mundo, com a cor por face.

    Nada aqui recalcula normal no fim, como nos predios: vidro e placa solta
    nao tem "dentro", e o recalculo vira metade deles. Cada primitiva ja nasce
    com a face para fora.
    """

    def __init__(self, nome: str, pivo: tuple) -> None:
        self.nome = nome
        self.pivo = Vector(pivo)
        self.bm = bmesh.new()
        self.cor = self.bm.faces.layers.int.new("cor")

    def _pinta(self, faces, cor: str) -> None:
        for face in faces:
            face[self.cor] = CELULAS[cor]

    def face(self, pontos, cor, fora) -> bmesh.types.BMFace:
        """Poligono convexo, com a frente para o lado de `fora`."""
        verts = [self.bm.verts.new(Vector(p)) for p in pontos]
        f = self.bm.faces.new(verts)
        f.normal_update()
        if f.normal.dot(Vector(fora)) < 0.0:
            f.normal_flip()
        f[self.cor] = CELULAS[cor]
        return f

    def caixa(self, centro, tamanho, cor, rot_x=0.0, rot_z=0.0) -> None:
        verts = bmesh.ops.create_cube(self.bm, size=1.0)["verts"]
        for v in verts:
            v.co.x *= tamanho[0]
            v.co.y *= tamanho[1]
            v.co.z *= tamanho[2]
        m = (
            Matrix.Translation(Vector(centro))
            @ Matrix.Rotation(math.radians(rot_z), 4, "Z")
            @ Matrix.Rotation(math.radians(rot_x), 4, "X")
        )
        bmesh.ops.transform(self.bm, matrix=m, verts=verts)
        self._pinta({f for v in verts for f in v.link_faces}, cor)

    def tubo(self, a, b, raio_a, raio_b, cor, lados=6, leque=False) -> set:
        """Tronco de cone de `a` a `b`. Devolve as faces, para pintura parcial."""
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
        faces = {f for v in verts for f in v.link_faces}
        self._pinta(faces, cor)
        return faces

    def esfera(self, centro, raios, cor, gomos=8, aneis=6) -> set:
        verts = bmesh.ops.create_uvsphere(
            self.bm, u_segments=gomos, v_segments=aneis, radius=1.0
        )["verts"]
        m = Matrix.Translation(Vector(centro)) @ Matrix.Diagonal((*raios, 1.0))
        bmesh.ops.transform(self.bm, matrix=m, verts=verts)
        faces = {f for v in verts for f in v.link_faces}
        self._pinta(faces, cor)
        return faces

    def loft(self, secoes, cores, tampas=("pintura", "pintura")) -> None:
        """Casco: aneis iguais ao longo de Y, costurados em quads.

        `secoes` e uma lista de `(y, [(x, z), ...])`, todas com o mesmo numero
        de pontos e em ordem crescente de Y. `cores[i]` pinta a aresta `i` do
        anel ao longo do casco inteiro; pode ser funcao de `(y_medio)`, para a
        mesma aresta ser capo fora da cabine e forro dentro dela. `tampas`
        fecha as pontas; `None` deixa aberta.

        O anel e convexo, entao "para fora" e "para longe do centro do anel":
        e o que orienta cada quad sem recalcular normal da malha inteira.
        """
        aneis = []
        for y, pontos in secoes:
            aneis.append([self.bm.verts.new((x, y, z)) for x, z in pontos])
        n = len(aneis[0])
        ys = [s[0] for s in secoes]
        for k in range(len(aneis) - 1):
            a, b = aneis[k], aneis[k + 1]
            ya, yb = ys[k], ys[k + 1]
            centro = sum((v.co for v in a + b), Vector()) / (2 * n)
            for i in range(n):
                j = (i + 1) % n
                quad = [a[i], a[j], b[j], b[i]]
                f = self.bm.faces.new(quad)
                f.normal_update()
                meio = f.calc_center_median()
                fora = meio - Vector((centro.x, meio.y, centro.z))
                if f.normal.dot(fora) < 0.0:
                    f.normal_flip()
                cor = cores[i]
                if callable(cor):
                    cor = cor((ya + yb) * 0.5)
                f[self.cor] = CELULAS[cor]
        for anel, cor, sentido in ((aneis[0], tampas[0], -1.0), (aneis[-1], tampas[1], 1.0)):
            if cor is None:
                continue
            f = self.bm.faces.new(anel)
            f.normal_update()
            if f.normal.y * sentido < 0.0:
                f.normal_flip()
            f[self.cor] = CELULAS[cor]

    def placa(self, pontos, fora, espessura, cor, cor_verso=None) -> None:
        """Poligono convexo com espessura: chapa que se ve dos dois lados.

        Uma face so some quando vista por tras, e a coluna do carro e vista
        por tras toda vez que a camera olha pelo vidro do outro lado.
        """
        fora = Vector(fora).normalized()
        frente = [Vector(p) for p in pontos]
        verso = [p - fora * espessura for p in frente]
        self.face(frente, cor, fora)
        self.face(verso, cor_verso or cor, -fora)
        centro = sum(frente + verso, Vector()) / (2 * len(frente))
        n = len(frente)
        for i in range(n):
            j = (i + 1) % n
            quad = [frente[i], frente[j], verso[j], verso[i]]
            meio = sum(quad, Vector()) / 4.0
            self.face(quad, cor, meio - centro)

    def roda(self, centro, raio, largura, lado, cor_aro="aro", raios=5) -> None:
        """Pneu de 16 lados, aro raiado do lado de fora e cubo cromado.

        Os raios sao fatias do disco pintadas alternadas, como no entregador:
        disco liso girando e igual a disco parado, e a roda girar e metade da
        leitura de que o carro anda.
        """
        c = Vector(centro)
        x = Vector((largura * 0.5, 0.0, 0.0))
        self.tubo(c - x, c + x, raio, raio, "pneu", lados=16)
        fora = Vector((lado * (largura * 0.5 + 0.008), 0.0, 0.0))
        dentro = Vector((lado * largura * 0.1, 0.0, 0.0))
        aro = self.tubo(c + dentro, c + fora, raio * 0.66, raio * 0.66, cor_aro, lados=16, leque=True)
        fatias = raios * 2
        for face in aro:
            meio = face.calc_center_median()
            if abs((meio - c).x - fora.x) > 1e-4:
                continue  # lateral do aro ou tampa de dentro
            angulo = math.atan2(meio.z - c.z, meio.y - c.y) % math.tau
            if int(angulo // (math.tau / fatias)) % 2 == 1:
                face[self.cor] = CELULAS["aro_vazado"]
        cubo = Vector((lado * (largura * 0.5 + 0.02), 0.0, 0.0))
        self.tubo(c + fora * 0.5, c + cubo, raio * 0.16, raio * 0.12, "cromo", lados=8)

    def objeto(self, materiais, colecao, pai=None) -> bpy.types.Object:
        bm = self.bm
        bmesh.ops.translate(bm, vec=-self.pivo, verts=bm.verts)
        bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method="FIXED", ngon_method="EAR_CLIP")
        # Ordem canonica das faces, como no entregador: a esfera do bmesh sai
        # com as faces em ordem diferente a cada execucao, e o mesmo modelo
        # virava um .glb diferente a cada regeracao.
        bm.faces.index_update()
        posto = [0] * len(bm.faces)
        chave = lambda f: (*(round(c, 5) for c in f.calc_center_median()), f[self.cor])  # noqa: E731
        for i, face in enumerate(sorted(bm.faces, key=chave)):
            posto[face.index] = i
        bm.faces.sort(key=lambda f: posto[f.index])

        vidro = CELULAS["vidro"]
        tem_vidro = any(f[self.cor] == vidro for f in bm.faces)
        uv = bm.loops.layers.uv.new("UVMap")
        for face in bm.faces:
            ponto = uv_da_celula(face[self.cor])
            for loop in face.loops:
                loop[uv].uv = ponto
            face.smooth = face[self.cor] != vidro
            face.material_index = 1 if face[self.cor] == vidro else 0
        for aresta in bm.edges:
            if not aresta.is_manifold or aresta.calc_face_angle(math.pi) > ANGULO_DURO:
                aresta.smooth = False
        bm.faces.layers.int.remove(self.cor)

        malha = bpy.data.meshes.new(self.nome)
        bm.to_mesh(malha)
        bm.free()
        malha.materials.append(materiais[0])
        if tem_vidro:
            malha.materials.append(materiais[1])

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
    obj.location = Vector(pivo) - mundo(pai)


def mundo(obj) -> Vector:
    # Soma as translacoes subindo a arvore: `matrix_world` vem zerado em
    # objeto recem-criado, e nenhuma peca aqui tem rotacao nem escala.
    pos = Vector()
    while obj is not None:
        pos += obj.location
        obj = obj.parent
    return pos


def ik_dois_ossos(raiz, alvo, l1, l2, polo) -> Vector:
    """Onde fica o cotovelo (ou o joelho) entre `raiz` e `alvo`."""
    raiz, alvo, polo = Vector(raiz), Vector(alvo), Vector(polo)
    d = alvo - raiz
    dist = min(d.length, l1 + l2 - 1e-4)
    eixo = d.normalized()
    a = (l1 * l1 - l2 * l2 + dist * dist) / (2.0 * dist)
    h = math.sqrt(max(l1 * l1 - a * a, 0.0))
    lado = (polo - eixo * polo.dot(eixo)).normalized()
    return raiz + eixo * a + lado * h


def recorta(poligono, y_min, y_max) -> list:
    """O pedaco de um poligono convexo entre dois planos de Y.

    E como a janela lateral vira vidro de porta: o trapezio do lado da cabine,
    cortado na dobradica e na fresta da porta.
    """

    def corta(pontos, dentro, cruza):
        saida = []
        for i, p in enumerate(pontos):
            q = pontos[(i + 1) % len(pontos)]
            if dentro(p):
                saida.append(p)
            if dentro(p) != dentro(q):
                saida.append(cruza(p, q))
        return saida

    def no_plano(y):
        return lambda p, q: p.lerp(q, (y - p.y) / (q.y - p.y))

    pontos = [Vector(p) for p in poligono]
    pontos = corta(pontos, lambda p: p.y >= y_min, no_plano(y_min))
    pontos = corta(pontos, lambda p: p.y <= y_max, no_plano(y_max))
    return pontos


def interpola(chaves, y) -> float:
    """Linha quebrada por `(y, valor)`, em ordem crescente de Y."""
    if y <= chaves[0][0]:
        return chaves[0][1]
    for (ya, va), (yb, vb) in zip(chaves, chaves[1:]):
        if y <= yb:
            return va + (vb - va) * (y - ya) / (yb - ya)
    return chaves[-1][1]


# --- Gente -------------------------------------------------------------------
#
# Sentada, com pecas rigidas presas na articulacao, como o piloto. Medidas de
# adulto: tronco de 0,52 m do quadril ao pescoco, braco de 0,29 + 0,27, perna
# de 0,43 + 0,43.

TORSO = 0.52
BRACO, ANTEBRACO = 0.29, 0.27
COXA, CANELA = 0.43, 0.43


def pessoa(
    colecao,
    mats,
    pai,
    quadril,
    reclina,
    maos,
    pes,
    cores,
    nome="Motorista",
    articulada=True,
    unica=None,
):
    """Monta uma pessoa sentada; `maos` e `pes` sao os alvos, em mundo.

    Articulada, e uma arvore com o quadril em `nome`, pronta para o IK do
    `carro.gd`. Estatica, vira geometria na `unica` (o passageiro). `cores` e
    `(camisa, pele, calca, cabelo)`.
    """
    camisa, pele, calca, cabelo = cores
    quadril = Vector(quadril)
    rec = math.radians(reclina)
    eixo = Vector((0.0, -math.sin(rec), math.cos(rec)))
    pescoco = quadril + eixo * TORSO

    def peca(nome_peca, pivo):
        return unica if unica is not None else Peca(nome_peca, pivo)

    base = vazio(nome, quadril, colecao, pai) if articulada else None

    tronco = peca("Tronco", quadril)
    tronco.caixa(quadril + Vector((0.0, 0.03, 0.02)), (0.34, 0.26, 0.16), calca)
    tronco.caixa(quadril + eixo * (TORSO * 0.5), (0.36, 0.22, TORSO), camisa, rot_x=reclina)
    obj_tronco = tronco.objeto(mats, colecao, base) if articulada else None

    cabeca = peca("Cabeca", pescoco)
    cabeca.tubo(pescoco - eixo * 0.03, pescoco + eixo * 0.08, 0.055, 0.05, pele)
    centro = pescoco + Vector((0.0, 0.02, 0.15))
    cabeca.esfera(centro, (0.085, 0.10, 0.115), pele)
    # Cabelo: a calota de tras e de cima. E o que diz "nuca" a 20 m pelo vidro
    # traseiro, que e o angulo de quase toda a corrida.
    cabeca.esfera(centro + Vector((0.0, -0.022, 0.03)), (0.09, 0.095, 0.10), cabelo, gomos=8, aneis=5)
    if articulada:
        cabeca.objeto(mats, colecao, obj_tronco)

    for lado, sufixo, mao in ((-1.0, "E", maos[0]), (1.0, "D", maos[1])):
        ombro = pescoco - eixo * 0.07 + Vector((lado * 0.19, 0.0, 0.0))
        mao = Vector(mao)
        cotovelo = ik_dois_ossos(ombro, mao, BRACO, ANTEBRACO, (lado * 1.0, -0.2, -1.0))

        braco = peca("Braco_" + sufixo, ombro)
        braco.esfera(ombro, (0.065, 0.065, 0.065), camisa, gomos=6, aneis=4)
        # Manga curta ate a metade do braco: o resto e pele, e e o braco nu no
        # volante que diz "motorista" e nao "manequim".
        braco.tubo(ombro, ombro.lerp(cotovelo, 0.55), 0.058, 0.052, camisa)
        braco.tubo(ombro.lerp(cotovelo, 0.5), cotovelo, 0.042, 0.038, pele)
        obj_braco = braco.objeto(mats, colecao, obj_tronco) if articulada else None

        antebraco = peca("Antebraco_" + sufixo, cotovelo)
        antebraco.esfera(cotovelo, (0.04, 0.04, 0.04), pele, gomos=6, aneis=4)
        antebraco.tubo(cotovelo, mao, 0.038, 0.032, pele)
        obj_antebraco = antebraco.objeto(mats, colecao, obj_braco) if articulada else None

        luva = peca("Mao_" + sufixo, mao)
        luva.caixa(mao, (0.06, 0.09, 0.05), pele)
        if articulada:
            luva.objeto(mats, colecao, obj_antebraco)

    pernas = peca("Pernas", quadril)
    for lado, pe in ((-1.0, pes[0]), (1.0, pes[1])):
        q = quadril + Vector((lado * 0.10, 0.02, -0.02))
        tornozelo = Vector(pe)
        joelho = ik_dois_ossos(q, tornozelo, COXA, CANELA, (lado * 0.1, 1.0, 1.0))
        pernas.tubo(q, joelho, 0.075, 0.06, calca)
        pernas.esfera(joelho, (0.062, 0.062, 0.062), calca, gomos=6, aneis=4)
        pernas.tubo(joelho, tornozelo, 0.058, 0.045, calca)
        pernas.caixa(tornozelo + Vector((0.0, 0.06, -0.03)), (0.09, 0.24, 0.08), "sapato")
    if articulada:
        pernas.objeto(mats, colecao, base)


# --- Carro de passeio --------------------------------------------------------
#
# O casco e um loft de aneis de oito pontos ao longo do comprimento: fundo,
# chanfro de baixo, lateral, ombro e topo. Tres lofts, e nao um: frente, soleira
# e traseira. Entre a frente e a traseira, acima da soleira, nao ha casco - ha
# a cabine aberta, fechada pelas portas. E isso que faz a porta abrir para um
# banco e um motorista, e nao para um bloco.
#
# A caixa de roda e o fundo do anel subindo em semicirculo em volta do eixo.
# Isso abre um tunel de lado a lado, e o `chassi` tampa o meio dele: de fora so
# se ve o arco.


class Modelo:
    """As medidas de um carro de passeio. Tudo em metro, Y para a frente."""

    def __init__(self, **medidas) -> None:
        self.__dict__.update(medidas)


def arco(m, y) -> float:
    """Altura do fundo do casco em `y`: o vao livre, ou a caixa de roda."""
    fundo = m.fundo
    for ya in (m.eixo_d, m.eixo_t):
        d = abs(y - ya)
        if d < m.arco:
            fundo = max(fundo, m.raio + math.sqrt(m.arco * m.arco - d * d))
        elif d < m.arco + 0.03:
            # Rampa de 3 cm entre o arco e o fundo: duas secoes no mesmo Y
            # dariam face de area zero.
            fundo = max(fundo, m.raio + (m.fundo - m.raio) * (d - m.arco) / 0.03)
    return fundo


def estacoes(m, y0, y1, extra=()) -> list:
    """Onde cortar o casco entre `y0` e `y1`: as quinas do perfil e os arcos."""
    ys = {y0, y1}
    for y, _ in m.topo + m.largura:
        ys.add(y)
    for ya in (m.eixo_d, m.eixo_t):
        for k in range(7):
            ys.add(ya + m.arco * math.cos(math.pi * k / 6.0))
        ys.add(ya + m.arco + 0.03)
        ys.add(ya - m.arco - 0.03)
    ys.update(extra)
    return sorted(y for y in ys if y0 <= y <= y1)


def anel(hw, zb, zt) -> list:
    """Secao do casco: fundo, chanfro, lateral, ombro, topo e o espelho."""
    h = zt - zb
    cb = min(0.07, h * 0.3)
    ct = min(0.10, h * 0.3)
    return [
        (-(hw - 0.05), zb),
        (hw - 0.05, zb),
        (hw, zb + cb),
        (hw, zt - ct),
        (hw - 0.07, zt),
        (-(hw - 0.07), zt),
        (-hw, zt - ct),
        (-hw, zb + cb),
    ]


def casco(m, p, y0, y1, teto=None, cores=None, tampas=("pintura", "pintura")) -> None:
    """Um trecho do casco, de `y0` a `y1`, com o topo cortado em `teto`."""
    secoes = []
    for y in estacoes(m, y0, y1):
        zt = interpola(m.topo, y)
        if teto is not None:
            zt = min(zt, teto)
        secoes.append((y, anel(interpola(m.largura, y), arco(m, y), zt)))
    pintura = "pintura"
    cores = cores or ["plastico", pintura, pintura, pintura, pintura, pintura, pintura, pintura]
    p.loft(secoes, cores, tampas)


def cabine(m) -> dict:
    """Os quatro cantos do lado direito da estufa, e os dois do teto.

    O lado da cabine e um trapezio plano: a reta de baixo na linha de cintura,
    a de cima na borda do teto, inclinada para dentro (o "tumblehome"). Plano,
    o vidro da porta recortado dele continua plano, e a porta gira sem o vidro
    sair do lugar.
    """
    hb = m.hw - 0.075
    ht = m.hw - 0.22
    return {
        "a": Vector((hb, m.parabrisa, m.cintura)),
        "b": Vector((ht, m.teto_frente, m.teto)),
        "c": Vector((ht, m.teto_tras, m.teto)),
        "d": Vector((hb, m.vidro_tras, m.cintura)),
        "hb": hb,
        "ht": ht,
    }


def espelha(p) -> Vector:
    return Vector((-p.x, p.y, p.z))


def lado_x(v, lado) -> Vector:
    return Vector((v.x * lado, v.y, v.z))


def porta(m, colecao, mats, pai, nome, lado, y_frente, y_tras, retrovisor, faixa):
    """Uma porta: chapa, vidro, moldura, macaneta e (na da frente) o retrovisor.

    A dobradica e a quina da frente, rente a lataria. O pivo fica no chao,
    embaixo dela: e a reta vertical por ali que o `carro.gd` gira.
    """
    folga = 0.006
    y0, y1 = y_tras + folga, y_frente - folga
    hw = m.hw
    dentro = hw - 0.075
    p = Peca(nome, (lado * hw, y_frente, 0.0))

    zb, zt = m.soleira + 0.01, m.cintura

    def secao(y):
        # Chapa de 7,5 cm com a quina de cima chanfrada para dentro, para a
        # porta fechada continuar o ombro do casco.
        pontos = [(dentro, zb), (hw, zb), (hw, zt - 0.10), (hw - 0.06, zt), (dentro, zt)]
        return [(x * lado, z) for x, z in pontos]

    secoes = [(y, secao(y)) for y in (y0, y1)]
    cores = ["pintura_sombra", "pintura", "pintura", "preto", "forro"]
    p.loft(secoes, cores, ("pintura", "pintura"))
    # Forro: o painel de dentro, com o descansa-braco. E o que se ve pela porta
    # aberta e pelo vidro do outro lado.
    p.caixa(
        (lado * (dentro - 0.03), (y0 + y1) * 0.5, zb + (zt - zb) * 0.62),
        (0.06, (y1 - y0) * 0.7, 0.05),
        "plastico",
    )

    c = cabine(m)
    lado_cabine = [lado_x(c[k], lado) for k in "abcd"]
    vidro = recorta(lado_cabine, y0 + 0.03, y1 - 0.03)
    if vidro:
        fora = Vector((lado, 0.0, 0.0))
        p.face([v - fora * 0.012 for v in vidro], "vidro", fora)
        # Moldura de borracha em volta do vidro, menos a borda de baixo, que
        # some na cintura da porta.
        for i, a in enumerate(vidro):
            b = vidro[(i + 1) % len(vidro)]
            if abs(a.z - m.cintura) < 0.02 and abs(b.z - m.cintura) < 0.02:
                continue
            p.tubo(a, b, 0.018, 0.018, "preto", lados=4)

    # Macaneta: um risco escuro na altura da mao, perto da fresta de tras.
    p.caixa((lado * (hw + 0.008), y0 + 0.16, zt - 0.17), (0.02, 0.13, 0.035), "plastico")
    if faixa:
        # A faixa azul do taxi corre pela porta: e a mesma linha que corre pelo
        # paralama, e com a porta fechada as duas emendam.
        p.caixa((lado * (hw + 0.004), (y0 + y1) * 0.5, m.faixa_z), (0.01, y1 - y0, 0.09), "faixa_taxi")
    if retrovisor:
        base = Vector((lado * (hw - 0.02), y1 - 0.12, zt + 0.04))
        p.caixa(base + Vector((lado * 0.05, 0.0, 0.0)), (0.10, 0.06, 0.05), "plastico")
        p.caixa(base + Vector((lado * 0.15, -0.02, 0.04)), (0.16, 0.08, 0.11), "pintura")
        p.caixa(base + Vector((lado * 0.15, -0.065, 0.04)), (0.14, 0.012, 0.09), "cromo")
    return p.objeto(mats, colecao, pai)


def carro_de_passeio(m, colecao, mats) -> bpy.types.Object:
    raiz = vazio(m.nome, (0.0, 0.0, 0.0), colecao)
    carroceria = vazio("Carroceria", (0.0, 0.0, m.raio), colecao, raiz)
    p = Peca("Lataria", (0.0, 0.0, m.raio))

    portas = m.portas  # [(y_frente, y_tras), ...] do lado direito
    y_cabine0 = portas[-1][1]  # fim da ultima porta
    y_cabine1 = portas[0][0]  # dobradica da primeira

    # Dentro da cabine o topo do casco e forro (painel, prateleira, assoalho);
    # fora dela e capo e tampa do porta-malas.
    def topo(y):
        return "forro" if m.vidro_tras < y < m.parabrisa else "pintura"

    cores = ["plastico", "pintura", "pintura", "pintura", topo, "pintura", "pintura", "pintura"]
    casco(m, p, y_cabine1, m.comprimento * 0.5, cores=cores, tampas=("forro", "pintura"))
    casco(m, p, -m.comprimento * 0.5, y_cabine0, cores=cores, tampas=("pintura", "forro"))
    # Soleira: o casco ate a altura da porta. O topo dela e o assoalho.
    soleira = ["plastico", "pintura_sombra", "pintura_sombra", "pintura_sombra", "forro"]
    soleira += ["pintura_sombra", "pintura_sombra", "pintura_sombra"]
    casco(m, p, y_cabine0, y_cabine1, teto=m.soleira, cores=soleira, tampas=(None, None))

    # Chassi: tampa o tunel que a caixa de roda abre de lado a lado.
    miolo = m.hw - 0.30
    for ya in (m.eixo_d, m.eixo_t):
        p.caixa((0.0, ya, m.fundo + 0.25), (miolo * 2.0, m.arco * 2.2, 0.5), "preto")

    c = cabine(m)
    a, b, cc, d = c["a"], c["b"], c["c"], c["d"]
    # Para-brisa e vidro de tras: trapezios entre os dois lados da estufa.
    p.face([espelha(a), a, b, espelha(b)], "vidro", (0.0, 1.0, 0.6))
    p.face([espelha(d), d, cc, espelha(cc)], "vidro", (0.0, -1.0, 0.6))
    # Teto: uma chapa com espessura, e a borda de borracha em volta dos vidros.
    p.placa(
        [espelha(b), b, cc, espelha(cc)],
        (0.0, 0.0, 1.0),
        0.04,
        "pintura",
        "forro",
    )
    for x0, x1 in ((espelha(a), a), (espelha(d), d)):
        p.tubo(x0, x1, 0.02, 0.02, "preto", lados=4)
    # Grade do limpador: cobre a fresta entre o capo e o para-brisa.
    p.caixa((0.0, m.parabrisa + 0.04, m.cintura - 0.01), (c["hb"] * 2.0, 0.10, 0.03), "preto")

    for lado in (-1.0, 1.0):
        la, lb, lc, ld = (lado_x(v, lado) for v in (a, b, cc, d))
        # Colunas A e C: a A e pintura e acompanha o para-brisa; a C fecha o
        # pedaco da estufa atras do ultimo vidro.
        p.tubo(la, lb, 0.045, 0.04, "pintura", lados=6)
        p.tubo(ld, lc, 0.05, 0.045, "pintura", lados=6)
        for ya, yb, cor in m.estufa:
            pedaco = recorta([la, lb, lc, ld], ya, yb)
            if not pedaco:
                continue
            fora = Vector((lado, 0.0, 0.25))
            if cor == "vidro":
                p.face([v - Vector((lado * 0.012, 0.0, 0.0)) for v in pedaco], "vidro", fora)
            else:
                p.placa(pedaco, fora, 0.03, cor, "forro")
        # Coluna B, entre as portas e atras da ultima: preta, como na maioria
        # dos carros: some entre os vidros e deixa a estufa ler como faixa.
        for y_tras in [pt[1] for pt in portas]:
            ponto = recorta([la, lb, lc, ld], y_tras - 0.035, y_tras + 0.035)
            if ponto:
                base = Vector((lado * c["hb"], y_tras, m.cintura))
                topo_b = Vector((lado * c["ht"], y_tras, m.teto - 0.02))
                p.tubo(base, topo_b, 0.035, 0.03, "preto", lados=4)

    # Interior: painel, console, bancos.
    hb = c["hb"]
    p.caixa((0.0, m.parabrisa - 0.22, m.cintura - 0.05), (hb * 2.0 - 0.06, 0.40, 0.18), "painel")
    p.caixa((0.0, m.parabrisa - 0.48, m.soleira + 0.18), (0.20, 0.55, 0.32), "painel")
    for x in (-0.36, 0.36):
        y = m.banco
        p.caixa((x, y + 0.04, m.soleira + 0.16), (0.48, 0.50, 0.14), "banco")
        p.caixa((x, y - 0.25, m.soleira + 0.48), (0.48, 0.10, 0.62), "banco", rot_x=-14.0)
        p.caixa((x, y - 0.33, m.soleira + 0.88), (0.26, 0.08, 0.16), "banco", rot_x=-14.0)
    yb = m.banco_tras
    p.caixa((0.0, yb + 0.04, m.soleira + 0.14), (hb * 2.0 - 0.12, 0.46, 0.14), "banco")
    p.caixa((0.0, yb - 0.24, m.soleira + 0.44), (hb * 2.0 - 0.12, 0.10, 0.56), "banco", rot_x=-12.0)

    luzes(m, p)
    if m.taxi:
        taxi(m, p)
    if m.suv:
        suv(m, p)
    p.objeto(mats, colecao, carroceria)

    # Volante: o aro em volta do pivo, a coluna apontando para o painel.
    centro = Vector((-0.36, m.volante, m.cintura + 0.10))
    coluna = Vector((0.0, 1.0, -0.45)).normalized()
    volante = Peca("Volante", centro)
    aro_volante(volante, centro, coluna, 0.19)
    volante.tubo(centro, centro + coluna * 0.22, 0.025, 0.03, "painel")
    obj_volante = volante.objeto(mats, colecao, carroceria)
    vazio("Coluna", centro + coluna * 0.3, colecao, obj_volante)

    maos = [mao_no_aro(centro, coluna, 0.19, lado) for lado in (-1.0, 1.0)]
    quadril = Vector((-0.36, m.banco, m.soleira + 0.28))
    pes = [quadril + Vector((lado * 0.11 + 0.0, 0.78, -0.24)) for lado in (-1.0, 1.0)]
    pessoa(colecao, mats, carroceria, quadril, 18.0, maos, pes, ("camisa", "pele", "calca", "cabelo"))

    if m.passageiro is not None:
        x, y = m.passageiro
        q = Vector((x, y, m.soleira + 0.27))
        colo = [q + Vector((lado * 0.12, 0.26, 0.05)) for lado in (-1.0, 1.0)]
        pes_p = [q + Vector((lado * 0.13, 0.62, -0.24)) for lado in (-1.0, 1.0)]
        unica = Peca("Passageiro", q)
        pessoa(
            colecao,
            mats,
            carroceria,
            q,
            16.0,
            colo,
            pes_p,
            ("camisa2", "pele", "calca", "cabelo"),
            articulada=False,
            unica=unica,
        )
        unica.objeto(mats, colecao, carroceria)

    nomes = (("Porta_DD", "Porta_DE"), ("Porta_TD", "Porta_TE"))
    for i, (y_frente, y_tras) in enumerate(portas):
        for lado, nome in ((1.0, nomes[i][0]), (-1.0, nomes[i][1])):
            porta(m, colecao, mats, carroceria, nome, lado, y_frente, y_tras, i == 0, m.taxi)

    for nome, ya, lado in (
        ("Roda_DE", m.eixo_d, -1.0),
        ("Roda_DD", m.eixo_d, 1.0),
        ("Roda_TE", m.eixo_t, -1.0),
        ("Roda_TD", m.eixo_t, 1.0),
    ):
        x = lado * (m.hw - 0.06 - m.pneu * 0.5)
        r = Peca(nome, (x, ya, m.raio))
        r.roda((x, ya, m.raio), m.raio, m.pneu, lado, raios=m.raios)
        r.objeto(mats, colecao, raiz)
    return raiz


def aro_volante(p, centro, coluna, raio) -> None:
    """Aro de 12 gomos, tres raios e o cubo, no plano perpendicular a coluna."""
    u = Vector((1.0, 0.0, 0.0))
    v = coluna.cross(u).normalized()
    pontos = [centro + (u * math.cos(t) + v * math.sin(t)) * raio for t in (math.tau * k / 12 for k in range(12))]
    for i, a in enumerate(pontos):
        p.tubo(a, pontos[(i + 1) % 12], 0.02, 0.02, "painel", lados=4)
    for t in (0.0, math.pi, -math.pi * 0.5):
        p.tubo(centro, centro + (u * math.cos(t) + v * math.sin(t)) * raio, 0.012, 0.012, "painel", lados=4)
    p.tubo(centro - coluna * 0.02, centro + coluna * 0.04, 0.05, 0.05, "painel", lados=8)


def mao_no_aro(centro, coluna, raio, lado) -> Vector:
    """A mao em "dez para as duas": 60 graus do topo do aro, para cada lado."""
    u = Vector((1.0, 0.0, 0.0))
    v = coluna.cross(u).normalized()
    if v.z < 0.0:
        v = -v
    return centro + (u * (lado * math.sin(math.radians(60.0))) + v * math.cos(math.radians(60.0))) * raio


def luzes(m, p) -> None:
    """Farol, lanterna, seta, re, placa, grade e para-choque."""
    yf = m.comprimento * 0.5
    yt = -m.comprimento * 0.5
    hwf = interpola(m.largura, yf - 0.05)
    hwt = interpola(m.largura, yt + 0.05)
    zf = interpola(m.topo, yf - 0.05)
    zt = interpola(m.topo, yt + 0.05)
    for lado in (-1.0, 1.0):
        seta = "seta_e" if lado < 0.0 else "seta_d"
        # Frente: farol largo e baixo, a seta na quina.
        p.caixa((lado * (hwf - 0.24), yf - 0.01, zf - 0.11), (0.30, 0.06, 0.11), "farol")
        p.caixa((lado * (hwf - 0.06), yf - 0.04, zf - 0.11), (0.08, 0.08, 0.10), seta)
        # Repetidor da seta no paralama: e o que pisca para quem esta do lado.
        p.caixa((lado * (m.hw + 0.004), m.eixo_d - m.arco - 0.12, m.cintura - 0.18), (0.01, 0.07, 0.03), seta)
        # Tras: lanterna na quina, seta e re para dentro. A lanterna e a maior
        # mancha de cor que o jogador ve, e ela acende na freada.
        p.caixa((lado * (hwt - 0.17), yt + 0.01, zt - 0.10), (0.30, 0.06, 0.13), "lanterna")
        p.caixa((lado * (hwt - 0.38), yt + 0.01, zt - 0.10), (0.12, 0.06, 0.13), seta)
        p.caixa((lado * (hwt - 0.47), yt + 0.012, zt - 0.10), (0.06, 0.06, 0.13), "re")
    # Placas Mercosul, frente e tras, com a tarja azul.
    for y, z, sentido in ((yt, m.fundo + 0.30, -1.0), (yf, m.fundo + 0.20, 1.0)):
        p.caixa((0.0, y + sentido * 0.012, z), (0.40, 0.02, 0.13), "placa")
        p.caixa((0.0, y + sentido * 0.024, z + 0.05), (0.40, 0.006, 0.03), "placa_tarja")
    # Grade e o friso escuro do para-choque, frente e tras.
    p.caixa((0.0, yf - 0.01, zf - 0.22), (hwf * 1.1, 0.04, 0.10), "preto")
    p.caixa((0.0, yf - 0.03, m.fundo + 0.10), (hwf * 1.7, 0.06, 0.08), "plastico")
    p.caixa((0.0, yt + 0.03, m.fundo + 0.12), (hwt * 1.7, 0.06, 0.10), "plastico")


def taxi(m, p) -> None:
    """A faixa azul no paralama e no quarto traseiro, e o luminoso no teto."""
    y_frente = m.portas[0][0]
    y_tras = m.portas[-1][1]
    for lado in (-1.0, 1.0):
        x = lado * (m.hw + 0.004)
        # Ate onde a lateral ainda e reta: dali para a frente o casco fecha,
        # e a faixa ficaria boiando fora dele.
        fim_d = 1.70
        p.caixa((x, (y_frente + fim_d) * 0.5, m.faixa_z), (0.01, fim_d - y_frente, 0.09), "faixa_taxi")
        fim_t = -1.70
        p.caixa((x, (y_tras + fim_t) * 0.5, m.faixa_z), (0.01, y_tras - fim_t, 0.09), "faixa_taxi")
    y = (m.teto_frente + m.teto_tras) * 0.5 + 0.05
    p.caixa((0.0, y, m.teto + 0.03), (0.66, 0.24, 0.04), "preto")
    p.caixa((0.0, y, m.teto + 0.12), (0.60, 0.20, 0.14), "luminoso")
    p.caixa((0.0, y + 0.101, m.teto + 0.12), (0.40, 0.004, 0.06), "faixa_taxi")
    p.caixa((0.0, y - 0.101, m.teto + 0.12), (0.40, 0.004, 0.06), "faixa_taxi")


def suv(m, p) -> None:
    """Barras de teto e o plastico preto em volta das caixas de roda."""
    c = cabine(m)
    for lado in (-1.0, 1.0):
        x = lado * (c["ht"] - 0.05)
        a = Vector((x, m.teto_frente - 0.05, m.teto + 0.06))
        b = Vector((x, m.teto_tras + 0.02, m.teto + 0.06))
        p.tubo(a, b, 0.022, 0.022, "preto", lados=6)
        for y in (a.y, b.y):
            p.caixa((x, y, m.teto + 0.03), (0.04, 0.08, 0.05), "preto")
        # Moldura do arco: oito placas em volta de cada roda, saltadas da
        # lataria. E o que separa SUV de seda alto a 40 m.
        for ya in (m.eixo_d, m.eixo_t):
            for k in range(8):
                t0 = math.pi * k / 8.0
                t1 = math.pi * (k + 1) / 8.0
                r = m.arco + 0.04
                pa = Vector((lado * (m.hw + 0.01), ya + r * math.cos(t0), m.raio + r * math.sin(t0)))
                pb = Vector((lado * (m.hw + 0.01), ya + r * math.cos(t1), m.raio + r * math.sin(t1)))
                p.tubo(pa, pb, 0.04, 0.04, "plastico", lados=4)
        p.caixa((lado * (m.hw + 0.01), 0.0, m.fundo + 0.06), (0.03, m.eixo_d - m.eixo_t - 2 * m.arco, 0.10), "plastico")


# --- Os modelos --------------------------------------------------------------
#
# `topo` e o perfil de lado da lataria de baixo (capo, cintura, porta-malas), e
# `largura` a meia largura vista de cima, que fecha nas pontas para o carro nao
# ser um tijolo. As portas sao do lado direito, da frente para tras, e o lado
# esquerdo e o espelho. `estufa` diz o que preenche cada faixa de Y da lateral
# da cabine: vidro (o das portas mora nelas) ou chapa.


def hatch() -> Modelo:
    return Modelo(
        nome="Hatch",
        comprimento=3.90,
        hw=0.86,
        raio=0.29,
        pneu=0.18,
        raios=4,
        arco=0.35,
        fundo=0.19,
        eixo_d=1.17,
        eixo_t=-1.30,
        soleira=0.32,
        cintura=0.90,
        teto=1.45,
        parabrisa=0.70,
        teto_frente=-0.08,
        teto_tras=-1.46,
        vidro_tras=-1.84,
        topo=[(-1.95, 0.88), (-1.88, 0.97), (-1.10, 0.95), (0.62, 0.90), (1.60, 0.78), (1.90, 0.70), (1.95, 0.60)],
        largura=[(-1.95, 0.78), (-1.80, 0.85), (-1.40, 0.86), (1.40, 0.86), (1.80, 0.82), (1.95, 0.74)],
        # Duas portas longas: a do Gol de duas portas, a mais comum na rua e a
        # mais perigosa aberta - 1,2 m de chapa entrando no corredor.
        portas=[(0.62, -0.62)],
        estufa=[(-1.30, -0.65, "vidro"), (-9.0, -1.30, "pintura")],
        banco=-0.08,
        banco_tras=-1.05,
        volante=0.14,
        passageiro=None,
        taxi=False,
        suv=False,
        faixa_z=0.62,
    )


def seda(nome="Seda", taxi_=False) -> Modelo:
    return Modelo(
        nome=nome,
        comprimento=4.40,
        hw=0.87,
        raio=0.30,
        pneu=0.19,
        raios=5,
        arco=0.36,
        fundo=0.19,
        eixo_d=1.32,
        eixo_t=-1.30,
        soleira=0.32,
        cintura=0.92,
        teto=1.46,
        parabrisa=0.78,
        teto_frente=-0.05,
        teto_tras=-0.98,
        vidro_tras=-1.55,
        topo=[(-2.20, 0.84), (-2.10, 0.96), (-1.60, 0.98), (-0.93, 0.97), (0.74, 0.92), (1.70, 0.80), (2.10, 0.72), (2.20, 0.62)],
        largura=[(-2.20, 0.80), (-2.05, 0.86), (-1.70, 0.87), (1.70, 0.87), (2.05, 0.83), (2.20, 0.76)],
        portas=[(0.74, -0.27), (-0.27, -0.93)],
        estufa=[(-9.0, -0.93, "pintura")],
        banco=0.0,
        banco_tras=-0.78,
        volante=0.22,
        # O taxi leva gente no banco de tras, do lado da calcada: e o
        # passageiro que faz o taxi ser taxi pelo vidro de tras.
        passageiro=(0.38, -0.80) if taxi_ else (0.36, 0.0),
        taxi=taxi_,
        suv=False,
        faixa_z=0.74,
    )


def suv_() -> Modelo:
    return Modelo(
        nome="SUV",
        comprimento=4.30,
        hw=0.90,
        raio=0.34,
        pneu=0.22,
        raios=5,
        arco=0.41,
        fundo=0.26,
        eixo_d=1.30,
        eixo_t=-1.32,
        soleira=0.42,
        cintura=1.06,
        teto=1.66,
        parabrisa=0.74,
        teto_frente=0.0,
        teto_tras=-1.78,
        vidro_tras=-2.02,
        topo=[(-2.15, 1.00), (-2.06, 1.10), (-1.00, 1.08), (0.70, 1.06), (1.70, 0.96), (2.05, 0.88), (2.15, 0.76)],
        largura=[(-2.15, 0.82), (-2.00, 0.89), (-1.70, 0.90), (1.70, 0.90), (2.00, 0.86), (2.15, 0.78)],
        portas=[(0.72, -0.28), (-0.28, -0.88)],
        estufa=[(-1.62, -0.90, "vidro"), (-9.0, -1.62, "pintura")],
        banco=0.0,
        banco_tras=-0.80,
        volante=0.20,
        passageiro=None,
        taxi=False,
        suv=True,
        faixa_z=0.72,
    )


# --- Onibus ------------------------------------------------------------------
#
# O urbano de piso alto do Rio: 12,2 m, piso a 0,9 m com degrau na porta, faixa
# de janela de 1,25 m, porta dupla na frente do eixo dianteiro e outra antes do
# traseiro, sempre do lado direito. As portas sao folhas que dobram para
# dentro, e por isso nao tem colisor: aberta, ela entra no onibus, nao no
# corredor.

ONIBUS = Modelo(
    nome="Onibus",
    comprimento=12.2,
    hw=1.25,
    raio=0.50,
    arco=0.60,
    fundo=0.38,
    eixo_d=3.60,
    eixo_t=-2.40,
    piso=0.92,
    janela=(1.32, 2.52),
    teto=3.02,
    portas=[(5.58, 4.38), (-0.50, -1.70)],
)


def onibus(colecao, mats) -> bpy.types.Object:
    m = ONIBUS
    raiz = vazio(m.nome, (0.0, 0.0, 0.0), colecao)
    carroceria = vazio("Carroceria", (0.0, 0.0, 1.0), colecao, raiz)
    p = Peca("Lataria", (0.0, 0.0, 1.0))
    hw = m.hw
    yf, yt = m.comprimento * 0.5, -m.comprimento * 0.5
    j0, j1 = m.janela
    esp = 0.05

    def fundo(y):
        z = m.fundo
        for ya in (m.eixo_d, m.eixo_t):
            d = abs(y - ya)
            if d < m.arco:
                z = max(z, m.raio + math.sqrt(m.arco * m.arco - d * d))
            elif d < m.arco + 0.03:
                z = max(z, m.raio + (m.fundo - m.raio) * (d - m.arco) / 0.03)
        return z

    def painel(lado, y0, y1, z_topo):
        """A saia lateral, de `y0` a `y1`, com a caixa de roda recortada."""
        ys = {y0, y1}
        for ya in (m.eixo_d, m.eixo_t):
            for k in range(9):
                ys.add(ya + m.arco * math.cos(math.pi * k / 8.0))
            ys.update((ya + m.arco + 0.03, ya - m.arco - 0.03))
        secoes = []
        for y in sorted(v for v in ys if y0 <= v <= y1):
            zb = fundo(y)
            pontos = [(hw - esp, zb), (hw, zb), (hw, z_topo), (hw - esp, z_topo)]
            secoes.append((y, [(x * lado, z) for x, z in pontos]))
        p.loft(secoes, ["preto", "pintura", "branco", "forro"], ("pintura", "pintura"))

    vaos = {1.0: [(yt + 0.05, m.portas[1][1]), (m.portas[1][0], m.portas[0][1]), (m.portas[0][0], yf - 0.05)]}
    vaos[-1.0] = [(yt + 0.05, yf - 0.05)]
    for lado, trechos in vaos.items():
        for y0, y1 in trechos:
            painel(lado, y0, y1, j0)
            # Faixa de janela: vidro em vaos de ~1,4 m, coluna preta entre eles.
            n = max(1, round((y1 - y0) / 1.4))
            passo = (y1 - y0) / n
            x = lado * (hw - 0.025)
            for k in range(n):
                a, b = y0 + passo * k, y0 + passo * (k + 1)
                p.face([(x, a, j0), (x, b, j0), (x, b, j1), (x, a, j1)], "vidro", (lado, 0.0, 0.0))
            for k in range(n + 1):
                y = y0 + passo * k
                p.caixa((lado * (hw - 0.025), y, (j0 + j1) * 0.5), (0.06, 0.08, j1 - j0), "preto")
            # Friso branco na cintura e a faixa de cima, ate o teto.
            p.caixa((lado * (hw - 0.02), (y0 + y1) * 0.5, j0 - 0.02), (0.06, y1 - y0, 0.06), "branco")
        # A faixa de cima corre por cima das portas tambem.
        p.caixa((lado * (hw - 0.025), 0.0, (j1 + m.teto) * 0.5), (0.05, m.comprimento - 0.1, m.teto - j1), "pintura")

    # Teto, com a quina arredondada por um loft de quatro aneis.
    secoes = []
    for y in (yt + 0.04, yf - 0.06):
        secoes.append((y, [(-hw, m.teto - 0.04), (hw, m.teto - 0.04), (hw - 0.10, m.teto + 0.06), (-(hw - 0.10), m.teto + 0.06)]))
    p.loft(secoes, ["forro", "branco", "branco", "branco"], ("branco", "branco"))
    p.caixa((0.0, 0.6, m.teto + 0.17), (1.70, 2.20, 0.22), "branco")  # ar-condicionado
    p.caixa((0.0, 0.6, m.teto + 0.29), (1.50, 2.00, 0.03), "plastico")

    # Piso e degraus das portas.
    p.caixa((0.0, 0.0, m.piso - 0.04), (hw * 2.0 - 0.10, m.comprimento - 0.2, 0.08), "piso")
    for y0, y1 in [(b, a) for a, b in m.portas]:
        p.caixa((hw - 0.30, (y0 + y1) * 0.5, 0.62), (0.50, y1 - y0, 0.06), "piso")
        p.caixa((hw - 0.53, (y0 + y1) * 0.5, m.piso * 0.5 + 0.2), (0.04, y1 - y0, m.piso - 0.4), "plastico")

    # Frente: saia, para-choque, farol, para-brisa e o letreiro.
    frente_y = yf - 0.03
    p.caixa((0.0, frente_y, (m.fundo + 1.05) * 0.5), (hw * 2.0, 0.06, 1.05 - m.fundo), "pintura")
    p.caixa((0.0, yf + 0.02, m.fundo + 0.18), (hw * 2.0 + 0.02, 0.10, 0.30), "plastico")
    p.caixa((0.0, yf + 0.005, 0.80), (1.10, 0.03, 0.22), "preto")
    for lado in (-1.0, 1.0):
        seta = "seta_e" if lado < 0.0 else "seta_d"
        p.caixa((lado * (hw - 0.28), yf + 0.005, 0.80), (0.36, 0.04, 0.16), "farol")
        p.caixa((lado * (hw - 0.06), yf + 0.005, 0.80), (0.08, 0.05, 0.16), seta)
        # Coluna da frente, com a quina arredondada.
        p.tubo((lado * (hw - 0.05), yf - 0.05, 1.05), (lado * (hw - 0.05), yf - 0.15, m.teto), 0.06, 0.06, "pintura")
        p.caixa((lado * (hw + 0.004), m.eixo_d + m.arco + 0.15, 0.95), (0.01, 0.10, 0.05), seta)
    vidro_f = [(-hw + 0.07, yf - 0.05, 1.08), (hw - 0.07, yf - 0.05, 1.08), (hw - 0.07, yf - 0.14, 2.62), (-hw + 0.07, yf - 0.14, 2.62)]
    p.face(vidro_f, "vidro", (0.0, 1.0, 0.05))
    p.tubo((0.0, yf - 0.05, 1.08), (0.0, yf - 0.14, 2.62), 0.03, 0.03, "preto", lados=4)
    p.caixa((0.0, yf - 0.06, 1.05), (hw * 2.0, 0.10, 0.06), "preto")
    p.caixa((0.0, yf - 0.15, 2.82), (hw * 2.0 - 0.06, 0.06, 0.40), "pintura")
    p.caixa((0.0, yf - 0.115, 2.80), (1.90, 0.02, 0.28), "letreiro")
    p.caixa((0.0, yf - 0.105, 2.80), (1.50, 0.01, 0.10), "letreiro_led")

    # Tras: o painel do motor, o vidro alto, as lanternas em coluna.
    tras_y = yt + 0.03
    p.caixa((0.0, tras_y, (m.fundo + m.teto) * 0.5), (hw * 2.0, 0.06, m.teto - m.fundo), "pintura")
    # O vidro de tras fica na frente de uma placa preta: atras dele e o motor,
    # e vidro sobre a pintura sairia amarelo, nao escuro.
    p.caixa((0.0, yt - 0.003, 2.36), (hw * 2.0 - 0.28, 0.006, 0.74), "preto")
    vidro_t = [(-hw + 0.15, yt - 0.008, 2.0), (hw - 0.15, yt - 0.008, 2.0), (hw - 0.15, yt - 0.008, 2.72)]
    p.face(vidro_t + [(-hw + 0.15, yt - 0.008, 2.72)], "vidro", (0.0, -1.0, 0.0))
    p.caixa((0.0, yt - 0.005, 1.25), (1.30, 0.02, 0.50), "preto")  # grade do motor
    p.caixa((0.0, yt - 0.02, m.fundo + 0.16), (hw * 2.0 + 0.02, 0.08, 0.28), "plastico")
    p.caixa((0.0, yt - 0.01, 2.86), (0.70, 0.02, 0.18), "letreiro")
    p.caixa((0.0, yt - 0.02, 2.86), (0.50, 0.01, 0.08), "letreiro_led")
    for lado in (-1.0, 1.0):
        seta = "seta_e" if lado < 0.0 else "seta_d"
        x = lado * (hw - 0.12)
        p.caixa((x, yt - 0.01, 1.10), (0.16, 0.04, 0.42), "lanterna")
        p.caixa((x, yt - 0.01, 1.46), (0.16, 0.04, 0.20), seta)
        p.caixa((x, yt - 0.01, 0.80), (0.16, 0.04, 0.10), "re")
    p.caixa((0.0, yt - 0.035, 0.75), (0.40, 0.02, 0.13), "placa")
    p.caixa((0.0, yt - 0.047, 0.80), (0.40, 0.006, 0.03), "placa_tarja")

    # Chassi entre as rodas, para nao se ver o ceu por baixo.
    p.caixa((0.0, 0.0, 0.62), (hw * 2.0 - 0.7, m.comprimento - 1.2, 0.5), "preto")

    # Interior: bancos em pares dos dois lados do corredor, corrimao amarelo.
    fileiras = []
    y = 3.85
    while y > yt + 0.9:
        fileiras.append(y)
        y -= 0.80
    for lado in (-1.0, 1.0):
        for y in fileiras:
            # Do lado das portas, nada no vao delas, nem na catraca atras da
            # porta da frente.
            if lado > 0.0 and any(b - 0.6 < y < a + 0.25 for a, b in m.portas):
                continue
            x = lado * (hw - 0.50)
            p.caixa((x, y, m.piso + 0.44), (0.82, 0.42, 0.10), "banco_onibus")
            p.caixa((x, y - 0.22, m.piso + 0.78), (0.82, 0.08, 0.62), "banco_onibus", rot_x=-8.0)
        p.tubo((lado * 0.50, yt + 0.5, 2.35), (lado * 0.50, yf - 1.2, 2.35), 0.018, 0.018, "corrimao", lados=6)
    for y in (4.2, 1.8, -0.2, -2.2, -4.2):
        for lado in (-1.0, 1.0):
            p.tubo((lado * 0.50, y, m.piso), (lado * 0.50, y, 2.35), 0.018, 0.018, "corrimao", lados=6)
    # Painel do motorista, a catraca e a divisoria atras dele.
    p.caixa((-0.6, yf - 0.35, 1.35), (1.1, 0.40, 0.25), "painel")
    p.caixa((0.45, 4.05, 1.40), (0.10, 0.50, 0.95), "cromo")
    p.caixa((-0.70, 4.45, 1.50), (1.00, 0.05, 1.10), "plastico")
    p.objeto(mats, colecao, carroceria)

    # As orelhas de coelho: o retrovisor do onibus brasileiro, pendurado do
    # teto para a frente. Fora da lataria para nao entrar no colisor.
    orelhas = Peca("Retrovisores", (0.0, 0.0, 1.0))
    for lado in (-1.0, 1.0):
        a = Vector((lado * (hw - 0.10), yf - 0.20, m.teto - 0.10))
        b = Vector((lado * (hw + 0.10), yf + 0.40, m.teto - 0.25))
        c = Vector((lado * (hw + 0.12), yf + 0.50, 2.45))
        orelhas.tubo(a, b, 0.025, 0.025, "preto")
        orelhas.tubo(b, c, 0.025, 0.025, "preto")
        orelhas.caixa(c + Vector((0.0, 0.0, -0.18)), (0.12, 0.08, 0.40), "preto")
    orelhas.objeto(mats, colecao, carroceria)

    # Motorista: sentado alto, quase em pe, com o volante deitado.
    centro = Vector((-0.70, 5.45, 1.62))
    coluna = Vector((0.0, 0.33, -0.94)).normalized()
    volante = Peca("Volante", centro)
    aro_volante(volante, centro, coluna, 0.24)
    volante.tubo(centro, centro + coluna * 0.40, 0.03, 0.035, "painel")
    obj_volante = volante.objeto(mats, colecao, carroceria)
    vazio("Coluna", centro + coluna * 0.4, colecao, obj_volante)
    maos = [mao_no_aro(centro, coluna, 0.24, lado) for lado in (-1.0, 1.0)]
    quadril = Vector((-0.70, 5.15, m.piso + 0.50))
    p_banco = Peca("Banco_Motorista", quadril)
    p_banco.caixa(quadril + Vector((0.0, 0.05, -0.12)), (0.50, 0.50, 0.12), "banco")
    p_banco.caixa(quadril + Vector((0.0, -0.24, 0.30)), (0.50, 0.10, 0.70), "banco", rot_x=-6.0)
    p_banco.objeto(mats, colecao, carroceria)
    pes = [quadril + Vector((lado * 0.12, 0.62, -0.47)) for lado in (-1.0, 1.0)]
    pessoa(colecao, mats, carroceria, quadril, 6.0, maos, pes, ("camisa", "pele", "calca", "cabelo"))

    # Passageiros: sentados na janela, que e onde o vidro deixa ver.
    gente = Peca("Passageiros", (0.0, 0.0, 1.0))
    roupas = ["roupa_1", "roupa_2", "roupa_3", "roupa_4", "roupa_5"]
    peles = ["pele_media", "pele_clara", "pele_escura"]
    lugares = [(-1, 3.85), (1, 3.05), (-1, 2.25), (-1, 0.65), (1, 1.45), (-1, -0.95), (1, -2.55), (-1, -3.35), (1, -4.15), (-1, -4.95)]
    for k, (lado, y) in enumerate(lugares):
        q = Vector((lado * (hw - 0.30), y, m.piso + 0.58))
        colo = [q + Vector((s * 0.12, 0.26, 0.04)) for s in (-1.0, 1.0)]
        pes_p = [q + Vector((s * 0.13, 0.55, -0.52)) for s in (-1.0, 1.0)]
        cores = (roupas[k % len(roupas)], peles[k % len(peles)], "calca", "cabelo")
        pessoa(colecao, mats, carroceria, q, 8.0, colo, pes_p, cores, articulada=False, unica=gente)
    gente.objeto(mats, colecao, carroceria)

    # Folhas das portas: A na dobradica da frente, B na de tras, dobrando para
    # dentro e se encontrando no meio.
    for i, (y_frente, y_tras) in enumerate(m.portas):
        meio = (y_frente + y_tras) * 0.5
        for sufixo, dobradica, ponta in (("A", y_frente, meio), ("B", y_tras, meio)):
            x = hw - 0.04
            f = Peca("Folha_%d%s" % (i + 1, sufixo), (x, dobradica, 0.0))
            sentido = 1.0 if ponta > dobradica else -1.0
            a, b = dobradica + sentido * 0.01, ponta - sentido * 0.006
            y0, y1 = min(a, b), max(a, b)
            ym, largura = (y0 + y1) * 0.5, y1 - y0
            f.caixa((x, ym, 0.68), (0.04, largura, 0.56), "pintura")
            f.face([(x + 0.005, y0 + 0.05, 1.0), (x + 0.005, y1 - 0.05, 1.0), (x + 0.005, y1 - 0.05, 2.52), (x + 0.005, y0 + 0.05, 2.52)], "vidro", (1.0, 0.0, 0.0))
            for z in (0.96, 2.56):
                f.caixa((x, ym, z), (0.045, largura, 0.08), "preto")
            for y in (y0 + 0.025, y1 - 0.025):
                f.caixa((x, y, 1.76), (0.045, 0.05, 1.60), "preto")
            f.objeto(mats, colecao, carroceria)

    for nome, ya, lado, duplo in (
        ("Roda_DE", m.eixo_d, -1.0, False),
        ("Roda_DD", m.eixo_d, 1.0, False),
        ("Roda_TE", m.eixo_t, -1.0, True),
        ("Roda_TD", m.eixo_t, 1.0, True),
    ):
        x = lado * (hw - 0.20)
        r = Peca(nome, (x, ya, m.raio))
        r.roda((x, ya, m.raio), m.raio, 0.28, lado, raios=5)
        if duplo:
            # Rodado duplo atras: o segundo pneu, para dentro.
            xi = lado * (hw - 0.50)
            r.tubo((xi - 0.13, ya, m.raio), (xi + 0.13, ya, m.raio), m.raio, m.raio, "pneu", lados=16)
        r.objeto(mats, colecao, raiz)
    return raiz


# --- Texturas e materiais ----------------------------------------------------


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


def materiais(albedo) -> tuple:
    opaco = bpy.data.materials.new("carro")
    if opaco.node_tree is None:
        opaco.use_nodes = True
    opaco.use_backface_culling = True
    nos = opaco.node_tree.nodes
    bsdf = next(n for n in nos if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Roughness"].default_value = 0.6
    tex = nos.new("ShaderNodeTexImage")
    tex.image = albedo
    tex.interpolation = "Closest"
    opaco.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])

    # O vidro do `.blend`: so para olhar o modelo no Blender. O jogo troca este
    # material pelo `vidro.gdshader`, que e quem decide a transparencia.
    vidro = bpy.data.materials.new("vidro")
    if vidro.node_tree is None:
        vidro.use_nodes = True
    bsdf = next(n for n in vidro.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*PALETA["vidro"][0], 1.0)
    bsdf.inputs["Roughness"].default_value = 0.05
    bsdf.inputs["Alpha"].default_value = 0.35
    return opaco, vidro


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
    assert len(PALETA) <= (TEXTURA // CELULA) ** 2, "paleta nao cabe na textura"
    os.makedirs(SAIDA, exist_ok=True)
    limpa_cena()

    colecao = bpy.data.collections.new("Carros")
    bpy.context.scene.collection.children.link(colecao)

    albedo = textura("carros_albedo", 0, "sRGB")
    textura("carros_mascara", 1, "Non-Color")
    mats = materiais(albedo)

    raizes = [
        carro_de_passeio(hatch(), colecao, mats),
        carro_de_passeio(seda(), colecao, mats),
        carro_de_passeio(suv_(), colecao, mats),
        carro_de_passeio(seda("Taxi", taxi_=True), colecao, mats),
        onibus(colecao, mats),
    ]
    # Lado a lado no .blend, so para dar para olhar os cinco. O jogo acha cada
    # um pelo nome e zera a posicao.
    for i, raiz in enumerate(raizes):
        raiz.location.x = i * 4.0

    arvore = set()
    for raiz in raizes:
        arvore |= {raiz, *raiz.children_recursive}
    for obj in bpy.data.objects:
        obj.select_set(obj in arvore)
    bpy.context.view_layer.objects.active = raizes[0]

    bpy.ops.wm.save_as_mainfile(filepath=BLEND, relative_remap=True)
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(SAIDA, "carros.glb"),
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
    for raiz in raizes:
        print("%s: %d tris" % (raiz.name, conta_tris(raiz)))


main()
