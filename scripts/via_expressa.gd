class_name ViaExpressa
extends RefCounted
## O trecho de via expressa (V11b): muro com mural, mureta, cerca e o viaduto
## passando por cima de parte dele. A `Cidade` sorteia onde ele cai, como
## sorteia o largo e o corredor; aqui so se monta.
##
## Dois perfis de borda, um de cada lado da pista:
##
## - **Fechado** (`04_vertical`, a direita): grama ao pe de um muro alto de
##   mural, com alambrado e arame em cima.
## - **Aberto** (`03_viaduto`, a esquerda): mureta de concreto, a faixa dos
##   pilares e um muro mais baixo no fundo. E o lado do viaduto: o tabuleiro
##   sai de la e cobre a pista ate passar do eixo.
##
## A metade da pista do lado aberto e a mao contraria, com o transito dela
## (`Contramao`) e a faixa dupla amarela no meio (`RoadTrack.pintar`). Ela nao
## comeca nem acaba no meio do quarteirao: nasce da rua da esquina da saida e
## entra na rua da esquina da entrada (`Cidade.esquinas_das_expressas`),
## virando nas duas pelo chanfro da quina.
##
## Tudo segue a curva e a rampa da `RoadTrack`, extrudado em `(offset,
## lateral)` como o meio-fio: nada aqui e uma peca posta num ponto da pista,
## e os numeros sao parametro. O chao continua sem colisor (o invariante);
## muro, mureta e pilar tem colisor de parede, como a fachada.
##
## O acostamento (`RoadTrack.SHOULDER`) fica inteiro dos dois lados: e a
## valvula de escape do transito fechado, e na via expressa ele e o unico
## lugar para fugir. Muro e mureta comecam depois dele.

const MURAIS: Texture2D = preload("res://assets/via_expressa/murais_albedo.png")
const CONCRETO: Texture2D = preload("res://assets/via_expressa/concreto_albedo.png")
const CERCA: Texture2D = preload("res://assets/via_expressa/cerca_albedo.png")
## O atlas de `arte/via_expressa.py`: 4x4 paineis de 128x64.
const ATLAS := Vector2i(4, 4)
const ATLAS_TEXELS := Vector2i(512, 256)
## Um painel cobre um modulo de muro: 8 m, 16 texels por metro. E tambem o
## passo dos colisores do muro, e do sorteio de painel.
const MODULO: float = 8.0
## A malha anda de 4 em 4 m, como a da pista (`RoadTrack.MESH_STEP`): e o que
## segue a curva sem quebrar a fachada do muro em facetas visiveis.
const PASSO: float = 4.0
## O tile do concreto, em metros.
const CONCRETO_TILE: float = 4.0

## Lado fechado. O muro comeca 1 m depois do acostamento, com a faixa de grama
## na frente; 5,5 m de muro e 2,2 de alambrado fecham o quadro pela direita
## como na `04`, mais alto que a camera e baixo o bastante para o ceu
## aparecer por cima.
const MURO_ALTO := Vector3(1.0, 5.5, 0.4)
const CERCA_ALTURA: float = 2.2
const CERCA_POSTE_PASSO: float = 3.0
## O arame farpado: uma aba de tela tombada para fora da pista, no topo.
const ARAME: float = 0.6

## Lado aberto. A mureta de 90 cm encosta no acostamento: e ela que separa a
## pista da faixa dos pilares, como na `03`. O muro baixo fecha o mundo antes
## do fim do chao (`RoadTrack.GROUND`), que de outro modo apareceria cortado.
const MURETA := Vector3(0.3, 0.9, 0.6)
const MURETA_TOPO: float = 0.2
const MURO_BAIXO := Vector3(12.5, 4.0, 0.4)

## O tabuleiro: 7 m de vao livre, 1,6 m de viga. Do lado aberto ele vai ate
## 10,5 m depois do acostamento e, do outro, passa 1 m do eixo: cobre as duas
## faixas do lado dele, e a sombra cai na pista, que e o que a `03` mostra.
const VIADUTO_ALTURA: float = 7.0
const VIADUTO_ESPESSURA: float = 1.6
const VIADUTO_FORA: float = 10.5
const VIADUTO_DENTRO: float = 1.0
## O viaduto nao comeca nem acaba no ar: nos primeiros e nos ultimos 60 m ele
## chega e vai embora de lado, por cima do muro baixo, ate 40 m para fora.
## Tabuleiro cortado a 7 m de altura, de frente para a moto, le como cenario.
const VIADUTO_CURVA: float = 60.0
const VIADUTO_LONGE: float = 40.0
## O pilar: largo ao longo da pista, como os da `03`, para o mural caber nele.
const PILAR := Vector2(1.2, 3.0)
const PILAR_AFASTAMENTO: float = 1.5
const PILAR_PASSO: float = 24.0

## A placa de mao dupla, dos dois lados da avenida, antes do zebrado que
## fecha as faixas do lado da mao contraria: 40 m antes dele, quase 1 s a
## 180 km/h, e a 1,4 m do meio-fio, como a placa de curva.
const MAO_DUPLA_ANTES: float = 40.0

const COR_ACOSTAMENTO := Color(0.56, 0.55, 0.53)
const COR_CANTEIRO := Color(0.47, 0.46, 0.44)
const COR_FERRO := Color(0.24, 0.25, 0.25)
## A barriga do tabuleiro, so um pouco mais escura que a viga: quem escurece
## ela e a sombra, porque so a luz do ceu chega ali. Com 0,62 ela saia preta
## na prova, e a da `03` e cinza esverdeado, com o limo aparecendo.
const COR_BARRIGA := Color(0.80, 0.80, 0.77)
const COR_MURETA := Color(0.95, 0.94, 0.91)


## Monta o trecho de `de` a `ate` em `props`. `lado` e o sinal do lado aberto
## (`Cidade.LADO_*`); `viaduto` e onde corre o tabuleiro, ou `Vector2.ZERO`
## para trecho sem ele. Os paineis saem de `rng`.
static func montar(
	track: RoadTrack,
	de: float,
	ate: float,
	lado: float,
	viaduto: Vector2,
	rng: RandomNumberGenerator,
	props: Node3D
) -> void:
	var raiz := Node3D.new()
	raiz.name = "ViaExpressa"
	props.add_child(raiz)
	var corpo := StaticBody3D.new()
	corpo.collision_layer = Layers.WORLD
	corpo.collision_mask = 0
	raiz.add_child(corpo)

	var mural := _nova()
	var concreto := _nova()
	var ferro := _nova()
	var chao := {
		"acostamento": _nova(),
		"canteiro": _nova(),
		"grama": _nova(),
		"asfalto": _nova(),
	}
	var tela := _nova()

	var edge := RoadTrack.sidewalk_limit()
	var fechado := -lado
	# Lado fechado: grama, muro alto, alambrado.
	_chao(chao["acostamento"], track, de, ate, fechado, RoadTrack.half_width(), edge)
	_chao(chao["grama"], track, de, ate, fechado, edge, edge + MURO_ALTO.x)
	var x_alto := edge + MURO_ALTO.x
	_muro(mural, concreto, corpo, track, de, ate, fechado, x_alto, MURO_ALTO, rng)
	_cerca(tela, ferro, track, de, ate, fechado, x_alto + MURO_ALTO.z * 0.5, MURO_ALTO.y)
	# Lado aberto: mureta, canteiro dos pilares e muro baixo. A mao contraria
	# e a metade da pista do lado dele, e o acostamento e o dela.
	_chao(chao["acostamento"], track, de, ate, lado, RoadTrack.half_width(), edge)
	_chao(chao["canteiro"], track, de, ate, lado, edge, edge + MURO_BAIXO.x)
	# A quina de cada ponta e chanfrada (`RoadTrack.ESQUINA_RAIO`): e por ela
	# que a mao contraria vira para a rua da esquina. A mureta recua ate onde
	# o chanfro deixa.
	_chanfro(chao["asfalto"], track, de, 1.0, lado)
	_chanfro(chao["asfalto"], track, ate, -1.0, lado)
	var recuo := recuo_da_mureta()
	_mureta(concreto, corpo, track, de + recuo, ate - recuo, lado)
	_muro(mural, concreto, corpo, track, de, ate, lado, edge + MURO_BAIXO.x, MURO_BAIXO, rng)

	var malha := ArrayMesh.new()
	_commit(mural, malha, RoadTrack.material_texturizado(MURAIS))
	_commit(concreto, malha, _concreto(COR_MURETA))
	_commit(ferro, malha, RoadTrack.material_liso(COR_FERRO))
	_instancia(raiz, "Muros", malha, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)

	var piso := ArrayMesh.new()
	_commit(chao["acostamento"], piso, RoadTrack.material_liso(COR_ACOSTAMENTO))
	_commit(chao["canteiro"], piso, RoadTrack.material_liso(COR_CANTEIRO))
	_commit(chao["grama"], piso, RoadTrack.material_liso(Cidade.COR_GRAMA))
	_commit(chao["asfalto"], piso, RoadTrack.material_texturizado(RoadTrack.ASFALTO))
	_instancia(raiz, "Piso", piso, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)

	var alambrado := ArrayMesh.new()
	_commit(tela, alambrado, _material_da_cerca())
	_instancia(raiz, "Cerca", alambrado, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)

	if viaduto != Vector2.ZERO:
		_viaduto(raiz, corpo, track, viaduto, lado, rng)


## Quanto o tabuleiro esta deslocado para fora em `o`: zero no meio, ate
## `VIADUTO_LONGE` nas pontas, numa curva em S. Positivo e para fora, no
## sinal do lado aberto.
static func desvio_do_viaduto(o: float, viaduto: Vector2) -> float:
	var dentro := minf(o - viaduto.x, viaduto.y - o)
	var t := clampf(dentro / VIADUTO_CURVA, 0.0, 1.0)
	return VIADUTO_LONGE * (1.0 - smoothstep(0.0, 1.0, t))


## As bordas do tabuleiro em `o`, em lateral da pista: `x` a de dentro (que
## passa do eixo) e `y` a de fora.
static func bordas_do_viaduto(o: float, viaduto: Vector2, lado: float) -> Vector2:
	var desvio := desvio_do_viaduto(o, viaduto)
	var dentro := -VIADUTO_DENTRO + desvio
	var fora := RoadTrack.sidewalk_limit() + VIADUTO_FORA + desvio
	return Vector2(dentro, fora) * lado


## Avisa, dos dois lados, que metade da pista vai virar mao contraria, antes
## da expressa `e`. Recua de 10 em 10 m ate sair da boca de alguma rua.
static func placas_de_mao_dupla(track: RoadTrack, e: Vector3, props: Node3D) -> void:
	var o := e.x - Cidade.RUA_LARGURA - RoadTrack.ZEBRADO - MAO_DUPLA_ANTES
	var lateral := RoadTrack.half_width() + 1.4
	for side: float in [-1.0, 1.0]:
		var aqui := o
		while aqui > 0.0 and Cidade.na_boca(track.cruzamentos, aqui, side):
			aqui -= 10.0
		var quem_vem := track.sample_basis(aqui).z
		var placa := Mobiliario.criar(
			Mobiliario.Tipo.PLACA_MAO_DUPLA, track.point(aqui, lateral * side), quem_vem
		)
		props.add_child(placa)


## O canto `(u, v)` de um painel do atlas, com `u` e `v` de 0 a 1 dentro dele.
## Meio texel para dentro, para o mipmap nao puxar a cor do vizinho na emenda.
static func uv_do_painel(painel: int, u: float, v: float) -> Vector2:
	var celula := Vector2(1.0 / ATLAS.x, 1.0 / ATLAS.y)
	var meio := Vector2(0.5 / ATLAS_TEXELS.x, 0.5 / ATLAS_TEXELS.y)
	var canto := Vector2(painel % ATLAS.x, painel / ATLAS.x) * celula
	return canto + meio + Vector2(u, v) * (celula - meio * 2.0)


## --- Pecas -----------------------------------------------------------------


## Um muro de `x` (lateral sem sinal) para fora, com a face de mural virada
## para a pista. `medidas` e `[afastamento, altura, espessura]`.
static func _muro(
	mural: SurfaceTool,
	concreto: SurfaceTool,
	corpo: StaticBody3D,
	track: RoadTrack,
	de: float,
	ate: float,
	lado: float,
	x: float,
	medidas: Vector3,
	rng: RandomNumberGenerator
) -> void:
	var altura := medidas.y
	var tras := x + medidas.z
	var m0 := de
	while m0 < ate - 0.1:
		var m1 := minf(m0 + MODULO, ate)
		var painel := rng.randi_range(0, ATLAS.x * ATLAS.y - 1)
		var o0 := m0
		while o0 < m1 - 0.01:
			var o1 := minf(o0 + PASSO, m1)
			var u0 := (o0 - m0) / MODULO
			var u1 := (o1 - m0) / MODULO
			var para_a_pista := -track.sample_basis((o0 + o1) * 0.5).x * lado
			# A base enterra meio metro: na rampa o pe do muro nao fica no ar.
			_quad(
				mural,
				[
					_p(track, o0, x * lado, -0.5),
					_p(track, o1, x * lado, -0.5),
					_p(track, o1, x * lado, altura),
					_p(track, o0, x * lado, altura),
				],
				[
					uv_do_painel(painel, u0, 1.0),
					uv_do_painel(painel, u1, 1.0),
					uv_do_painel(painel, u1, 0.0),
					uv_do_painel(painel, u0, 0.0),
				],
				para_a_pista
			)
			_tampa(concreto, track, o0, o1, x * lado, tras * lado, altura)
			o0 = o1
		_parede(corpo, track, (m0 + m1) * 0.5, m1 - m0, lado * (x + tras) * 0.5, medidas.z, altura)
		m0 = m1
	# A cabeca do muro nas duas pontas: quem chega pelo corredor ve a quina.
	for ponta: float in [de, ate]:
		var frente := track.sample_basis(ponta).z * (1.0 if ponta == de else -1.0)
		_quad(
			concreto,
			[
				_p(track, ponta, x * lado, -0.5),
				_p(track, ponta, tras * lado, -0.5),
				_p(track, ponta, tras * lado, altura),
				_p(track, ponta, x * lado, altura),
			],
			_uv_concreto(
				[Vector2(x, 0), Vector2(tras, 0), Vector2(tras, altura), Vector2(x, altura)]
			),
			frente
		)


## A mureta New Jersey simplificada: trapezio de 60 cm na base e 20 no topo.
static func _mureta(
	concreto: SurfaceTool, corpo: StaticBody3D, track: RoadTrack, de: float, ate: float, lado: float
) -> void:
	var meio := RoadTrack.sidewalk_limit() + MURETA.x
	var h := MURETA.y
	# O perfil, de dentro para fora: pe, ombro, ombro, pe.
	var perfil: Array[Vector2] = [
		Vector2(meio - MURETA.z * 0.5, 0.0),
		Vector2(meio - MURETA_TOPO * 0.5, h),
		Vector2(meio + MURETA_TOPO * 0.5, h),
		Vector2(meio + MURETA.z * 0.5, 0.0),
	]
	var o0 := de
	while o0 < ate - 0.01:
		var o1 := minf(o0 + PASSO, ate)
		var b := track.sample_basis((o0 + o1) * 0.5)
		for i in 3:
			var a := perfil[i]
			var c := perfil[i + 1]
			# A normal de cada face sai do perfil: para dentro, para cima, para fora.
			var n2 := Vector2(c.y - a.y, -(c.x - a.x))
			if n2.dot((a + c) * 0.5 - Vector2(meio, h * 0.4)) < 0.0:
				n2 = -n2
			var normal := (b.x * lado * n2.x + Vector3.UP * n2.y).normalized()
			_quad(
				concreto,
				[
					_p(track, o0, a.x * lado, a.y),
					_p(track, o1, a.x * lado, a.y),
					_p(track, o1, c.x * lado, c.y),
					_p(track, o0, c.x * lado, c.y),
				],
				[
					Vector2(o0, a.x + a.y) / CONCRETO_TILE,
					Vector2(o1, a.x + a.y) / CONCRETO_TILE,
					Vector2(o1, c.x + c.y) / CONCRETO_TILE,
					Vector2(o0, c.x + c.y) / CONCRETO_TILE,
				],
				normal
			)
		o0 = o1
	# A cabeca nas duas pontas, de frente para a rua da esquina: aberta, a
	# mureta era uma casca oca vista de quem vem pela transversal.
	for ponta: float in [de, ate]:
		var frente := track.sample_basis(ponta).z * (1.0 if ponta == de else -1.0)
		var cantos: Array[Vector3] = []
		var uvs: Array[Vector2] = []
		for p in perfil:
			cantos.append(_p(track, ponta, p.x * lado, p.y))
			uvs.append(Vector2(p.x, p.y) / CONCRETO_TILE)
		_quad(concreto, cantos, uvs, frente)
	var m0 := de
	while m0 < ate - 0.1:
		var m1 := minf(m0 + MODULO, ate)
		_parede(corpo, track, (m0 + m1) * 0.5, m1 - m0, lado * meio, MURETA.z, h)
		m0 = m1


## O alambrado em cima do muro, na linha do meio dele, os postes de ferro a
## cada 3 m, e a aba de arame tombada para fora no topo.
static func _cerca(
	tela: SurfaceTool,
	ferro: SurfaceTool,
	track: RoadTrack,
	de: float,
	ate: float,
	lado: float,
	x: float,
	base: float
) -> void:
	var topo := base + CERCA_ALTURA
	var o0 := de
	while o0 < ate - 0.01:
		var o1 := minf(o0 + PASSO, ate)
		var para_a_pista := -track.sample_basis((o0 + o1) * 0.5).x * lado
		# A tela tem um metro de tile, nas duas direcoes; o arame da aba vai
		# para fora da pista, subindo, como o da `04`.
		_quad(
			tela,
			[
				_p(track, o0, x * lado, base),
				_p(track, o1, x * lado, base),
				_p(track, o1, x * lado, topo),
				_p(track, o0, x * lado, topo),
			],
			[Vector2(o0, CERCA_ALTURA), Vector2(o1, CERCA_ALTURA), Vector2(o1, 0), Vector2(o0, 0)],
			para_a_pista
		)
		var fora := (x + ARAME * 0.7) * lado
		_quad(
			tela,
			[
				_p(track, o0, x * lado, topo),
				_p(track, o1, x * lado, topo),
				_p(track, o1, fora, topo + ARAME * 0.7),
				_p(track, o0, fora, topo + ARAME * 0.7),
			],
			[Vector2(o0, ARAME), Vector2(o1, ARAME), Vector2(o1, 0), Vector2(o0, 0)],
			para_a_pista
		)
		o0 = o1
	var o := de + CERCA_POSTE_PASSO * 0.5
	while o < ate:
		var para_a_pista := -track.sample_basis(o).x * lado
		var ao_longo := -track.sample_basis(o).z
		var pe := _p(track, o, x * lado, base)
		var cantos: Array[Vector3] = [
			pe - ao_longo * 0.05,
			pe + ao_longo * 0.05,
			pe + ao_longo * 0.05 + Vector3.UP * (CERCA_ALTURA + 0.1),
			pe - ao_longo * 0.05 + Vector3.UP * (CERCA_ALTURA + 0.1),
		]
		# Deslocado 2 cm para a pista, para nao brigar com a tela no depth.
		for i in cantos.size():
			cantos[i] += para_a_pista * 0.02
		_quad(ferro, cantos, [], para_a_pista)
		o += CERCA_POSTE_PASSO


## O tabuleiro e os pilares. Malha propria, com sombra dos dois lados: so a
## barriga e as vigas sao desenhadas (o topo ninguem ve da pista), e a sombra
## precisa sair delas mesmo com a face de cima faltando.
static func _viaduto(
	raiz: Node3D,
	corpo: StaticBody3D,
	track: RoadTrack,
	viaduto: Vector2,
	lado: float,
	rng: RandomNumberGenerator
) -> void:
	var barriga := _nova()
	var viga := _nova()
	var mural := _nova()
	var h0 := VIADUTO_ALTURA
	var h1 := VIADUTO_ALTURA + VIADUTO_ESPESSURA
	var o0 := viaduto.x
	while o0 < viaduto.y - 0.01:
		var o1 := minf(o0 + PASSO, viaduto.y)
		var a := bordas_do_viaduto(o0, viaduto, lado)
		var b := bordas_do_viaduto(o1, viaduto, lado)
		var lateral := track.sample_basis((o0 + o1) * 0.5).x
		_quad(
			barriga,
			[
				_p(track, o0, a.x, h0),
				_p(track, o1, b.x, h0),
				_p(track, o1, b.y, h0),
				_p(track, o0, a.y, h0)
			],
			[
				Vector2(o0, a.x) / CONCRETO_TILE,
				Vector2(o1, b.x) / CONCRETO_TILE,
				Vector2(o1, b.y) / CONCRETO_TILE,
				Vector2(o0, a.y) / CONCRETO_TILE,
			],
			Vector3.DOWN
		)
		# As duas vigas de borda: a de dentro olha para o lado fechado, a de
		# fora para longe da pista.
		for k in 2:
			var xa := a.x if k == 0 else a.y
			var xb := b.x if k == 0 else b.y
			_quad(
				viga,
				[
					_p(track, o0, xa, h0),
					_p(track, o1, xb, h0),
					_p(track, o1, xb, h1),
					_p(track, o0, xa, h1)
				],
				_uv_concreto([Vector2(o0, h0), Vector2(o1, h0), Vector2(o1, h1), Vector2(o0, h1)]),
				lateral * lado * (-1.0 if k == 0 else 1.0)
			)
		o0 = o1
	# As cabecas nas pontas, la longe, fora do mundo.
	for ponta: float in [viaduto.x, viaduto.y]:
		var bordas := bordas_do_viaduto(ponta, viaduto, lado)
		var frente := track.sample_basis(ponta).z * (1.0 if ponta == viaduto.x else -1.0)
		_quad(
			viga,
			[
				_p(track, ponta, bordas.x, h0),
				_p(track, ponta, bordas.y, h0),
				_p(track, ponta, bordas.y, h1),
				_p(track, ponta, bordas.x, h1),
			],
			_uv_concreto(
				[Vector2(0, h0), Vector2(bordas.y, h0), Vector2(bordas.y, h1), Vector2(0, h1)]
			),
			frente
		)
	_pilares(mural, viga, corpo, track, viaduto, lado, rng)

	var malha := ArrayMesh.new()
	_commit(barriga, malha, _concreto(COR_BARRIGA))
	_commit(viga, malha, _concreto(Color.WHITE))
	_commit(mural, malha, RoadTrack.material_texturizado(MURAIS))
	_instancia(raiz, "Viaduto", malha, GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED)


## Um pilar a cada `PILAR_PASSO` embaixo do tabuleiro, entre a mureta e a pista
## de servico. Onde o tabuleiro vai embora de lado, o pilar acompanha, menos
## em cima da pista de servico e do muro, e alem do fim do chao.
static func _pilares(
	mural: SurfaceTool,
	concreto: SurfaceTool,
	corpo: StaticBody3D,
	track: RoadTrack,
	viaduto: Vector2,
	lado: float,
	rng: RandomNumberGenerator
) -> void:
	var edge := RoadTrack.sidewalk_limit()
	var o := viaduto.x + PILAR_PASSO * 0.5
	while o < viaduto.y:
		var x := edge + PILAR_AFASTAMENTO + desvio_do_viaduto(o, viaduto)
		var no_caminho := absf(x - edge - MURO_BAIXO.x) < 1.0
		if not no_caminho and x < RoadTrack.limite_do_mundo() - 1.0:
			_pilar(mural, concreto, corpo, track, o, x * lado, rng.randi_range(0, 15))
		o += PILAR_PASSO


static func _pilar(
	mural: SurfaceTool,
	concreto: SurfaceTool,
	corpo: StaticBody3D,
	track: RoadTrack,
	o: float,
	x: float,
	painel: int
) -> void:
	var b := track.sample_basis(o)
	var pe := track.point(o, x) + Vector3.DOWN * 0.5
	var h := VIADUTO_ALTURA + 0.5
	var direita := b.x * PILAR.x * 0.5
	var frente := -b.z * PILAR.y * 0.5
	var cima := Vector3.UP * h
	# As duas faces largas, as que olham para a pista e para longe dela, levam
	# meio painel cada: o mural sobe esticado, como pintado no pilar.
	for s: float in [-1.0, 1.0]:
		var face := pe + direita * s
		_quad(
			mural,
			[face - frente, face + frente, face + frente + cima, face - frente + cima],
			[
				uv_do_painel(painel, 0.25, 1.0),
				uv_do_painel(painel, 0.75, 1.0),
				uv_do_painel(painel, 0.75, 0.0),
				uv_do_painel(painel, 0.25, 0.0),
			],
			b.x * s
		)
		var ponta := pe + frente * s
		_quad(
			concreto,
			[ponta - direita, ponta + direita, ponta + direita + cima, ponta - direita + cima],
			_uv_concreto([Vector2(0, 0), Vector2(PILAR.x, 0), Vector2(PILAR.x, h), Vector2(0, h)]),
			-b.z * s
		)
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(PILAR.x, h, PILAR.y)
	forma.shape = caixa
	forma.transform = Transform3D(b, pe + cima * 0.5)
	corpo.add_child(forma)


## --- Chao ------------------------------------------------------------------


## Uma faixa de chao de `x0` a `x1` (lateral sem sinal) do lado `lado`, por
## cima da calcada da pista. Com `tile`, ganha UV de asfalto: U em faixas de
## rolamento, V em tiles percorridos, como na avenida.
static func _chao(
	st: SurfaceTool,
	track: RoadTrack,
	de: float,
	ate: float,
	lado: float,
	x0: float,
	x1: float,
	tile: float = 0.0
) -> void:
	# 4 cm acima da calcada: acima da faixa de servico (2 cm), que ela cobre.
	var lift := 0.04
	var o0 := de
	while o0 < ate - 0.01:
		var o1 := minf(o0 + PASSO, ate)
		var uvs: Array[Vector2] = []
		if tile > 0.0:
			var u0 := x0 / RoadTrack.LANE_WIDTH
			var u1 := x1 / RoadTrack.LANE_WIDTH
			uvs = [
				Vector2(u0, o0 / tile),
				Vector2(u0, o1 / tile),
				Vector2(u1, o1 / tile),
				Vector2(u1, o0 / tile),
			]
		_quad(
			st,
			[
				_p(track, o0, x0 * lado, lift),
				_p(track, o1, x0 * lado, lift),
				_p(track, o1, x1 * lado, lift),
				_p(track, o0, x1 * lado, lift),
			],
			uvs,
			Vector3.UP
		)
		o0 = o1


## O chanfro de asfalto na quina entre a rua da esquina e a expressa, em
## `ponta`: o quarto de canto entre o meio-fio da pista e o da rua, aparado
## pelo arco de `RoadTrack.ESQUINA_RAIO`. `para_dentro` e +1 se a expressa fica
## para a frente da ponta (a entrada) e -1 se fica para tras (a saida). 6 cm
## acima do chao, como a rua: cobre o acostamento e o canteiro da quina.
static func _chanfro(
	st: SurfaceTool, track: RoadTrack, ponta: float, para_dentro: float, lado: float
) -> void:
	var r := RoadTrack.ESQUINA_RAIO
	var borda := RoadTrack.half_width()
	var centro := Vector2(ponta + para_dentro * r, borda + r)
	var quina := Vector2(ponta, borda)
	var passos := 6
	for k in passos:
		var a := _no_arco(centro, para_dentro, float(k) / passos)
		var b := _no_arco(centro, para_dentro, float(k + 1) / passos)
		var cantos: Array[Vector3] = []
		var uvs: Array[Vector2] = []
		for q: Vector2 in [quina, a, b, b]:
			cantos.append(_p(track, q.x, q.y * lado, 0.06))
			uvs.append(Vector2(q.y / RoadTrack.LANE_WIDTH, q.x / RoadTrack.ASFALTO_TILE))
		_quad(st, cantos, uvs, Vector3.UP)


## Um ponto do arco do chanfro, de `t` 0 (na rua) a 1 (no meio-fio da pista),
## em `(offset, lateral sem sinal)`.
static func _no_arco(centro: Vector2, para_dentro: float, t: float) -> Vector2:
	var ang := t * PI * 0.5
	return centro + Vector2(-para_dentro * cos(ang), -sin(ang)) * RoadTrack.ESQUINA_RAIO


## Quanto a mureta comeca depois da ponta da expressa: onde o arco do chanfro
## passa do pe de fora dela, mais um palmo.
static func recuo_da_mureta() -> float:
	var r := RoadTrack.ESQUINA_RAIO
	var pe := RoadTrack.sidewalk_limit() + MURETA.x + MURETA.z * 0.5
	var acima := RoadTrack.half_width() + r - pe
	if acima >= r:
		return 0.2
	return r - sqrt(r * r - acima * acima) + 0.2


## A tampa de concreto do muro, de `x` a `tras` (laterais com sinal).
static func _tampa(
	st: SurfaceTool, track: RoadTrack, o0: float, o1: float, x: float, tras: float, h: float
) -> void:
	_quad(
		st,
		[_p(track, o0, x, h), _p(track, o1, x, h), _p(track, o1, tras, h), _p(track, o0, tras, h)],
		_uv_concreto([Vector2(o0, x), Vector2(o1, x), Vector2(o1, tras), Vector2(o0, tras)]),
		Vector3.UP
	)


## --- Ferramentas -----------------------------------------------------------


## Ponto da pista a `o`, `x` de lateral e `h` acima do chao.
static func _p(track: RoadTrack, o: float, x: float, h: float) -> Vector3:
	return track.point(o, x) + Vector3.UP * h


## Colisor de parede, uma caixa `comprimento` x `altura` x `espessura` com o
## meio em `(o, x)`, girada com a pista.
static func _parede(
	corpo: StaticBody3D,
	track: RoadTrack,
	o: float,
	comprimento: float,
	x: float,
	espessura: float,
	altura: float
) -> void:
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(espessura, altura, comprimento)
	forma.shape = caixa
	forma.transform = Transform3D(track.sample_basis(o), _p(track, o, x, altura * 0.5))
	corpo.add_child(forma)


static func _uv_concreto(pontos: Array[Vector2]) -> Array[Vector2]:
	var uvs: Array[Vector2] = []
	for p in pontos:
		uvs.append(p / CONCRETO_TILE)
	return uvs


## Dois triangulos com os cantos em volta, na ordem, virados para `normal`.
## Godot descarta face anti-horaria sem avisar, e aqui a ordem depende do
## lado da pista e de para onde a peca olha: o winding e conferido pela
## normal, e nao confiado. A face e frontal quando o produto vetorial dos
## lados aponta contra a normal (horario visto de frente).
static func _quad(
	st: SurfaceTool, cantos: Array[Vector3], uvs: Array[Vector2], normal: Vector3
) -> void:
	for meio: int in [1, 2]:
		var b := meio
		var c := meio + 1
		var a := cantos[0]
		if (cantos[b] - a).cross(cantos[c] - a).dot(normal) > 0.0:
			b = meio + 1
			c = meio
		for i: int in [0, b, c]:
			st.set_normal(normal)
			if not uvs.is_empty():
				st.set_uv(uvs[i])
			st.add_vertex(cantos[i])


static func _nova() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


## Commita so se houver o que commitar: superficie vazia quebra o `ArrayMesh`.
static func _commit(st: SurfaceTool, malha: ArrayMesh, mat: Material) -> void:
	var antes := malha.get_surface_count()
	st.commit(malha)
	if malha.get_surface_count() > antes:
		malha.surface_set_material(antes, mat)


static func _instancia(
	raiz: Node3D, nome: String, malha: ArrayMesh, sombra: GeometryInstance3D.ShadowCastingSetting
) -> void:
	if malha.get_surface_count() == 0:
		return
	var mi := MeshInstance3D.new()
	mi.name = nome
	mi.mesh = malha
	mi.cast_shadow = sombra
	raiz.add_child(mi)


static func _concreto(cor: Color) -> StandardMaterial3D:
	var mat := RoadTrack.material_texturizado(CONCRETO)
	mat.albedo_color = cor
	return mat


## A tela do alambrado: furo transparente e os dois lados desenhados, porque
## quem passa ve a tela de frente e a aba de arame por baixo. Mistura de alfa,
## e nao recorte: de longe o mipmap media arame e furo num veu cinza, que e o
## que a `04` mostra; com recorte, a tela sumiria a 20 m.
static func _material_da_cerca() -> StandardMaterial3D:
	var mat := RoadTrack.material_texturizado(CERCA)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat
