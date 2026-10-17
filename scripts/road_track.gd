class_name RoadTrack
extends Node3D
## Pista como geometria 3D real, gerada a partir de uma Curve3D.
##
## Decisao de arquitetura (ver docs/PROTOTIPO.md): o mundo e 3D de verdade, nao
## pseudo-3D por scanlines. Ladeira, curva e salto saem de graca da curva.
##
## O chao NAO tem colisor. Altura e direcao sao amostradas analiticamente da
## curva - a 50 m/s um CharacterBody3D atravessaria um trimesh. Colisores
## existem so pro que importa: carros, postes, semaforos e predios.

## O grupo da pista, para quem precisa da altura do chao sem ter quem a passe.
const GRUPO: StringName = &"pista"
## Rampa mais forte que a pista chega a ter, em altura por metro percorrido.
## 0.14 e ladeira de bairro alto: ingreme o bastante pra a moto perder folego
## subindo e ganhar de graca descendo, longe o bastante de virar parede.
const MAX_GRADE: float = 0.14
## Quanto da rampa nova a pista assume por passo de 12 m.
##
## E este numero que decide se a crista da ladeira e um respiro ou um salto: a
## moto herda a subida da pista ao chegar no topo (ver _integrate no
## player_bike), entao rampa que troca de sinal em poucos metros cospe a moto
## no ar. Alto demais e a pista vira serra e a moto passa a corrida voando.
const GRADE_BLEND: float = 0.3

## 4,3 m deixam 0,875 m de cada lado da moto entre carros de 1,8 m.
## Mesmo com 3,8 m o corredor ainda exigia precisao demais ao jogar.
const LANE_WIDTH: float = 4.3
const LANE_COUNT: int = 4
const SHOULDER: float = 2.2
## Terreno plano de cada lado. Sem ele o mundo vira uma fita flutuando no
## vazio - a pista some contra o fundo e o jogador perde a nocao de onde esta.
const GROUND: float = 34.0

## Espacamento da amostragem ao gerar o mesh, em metros.
const MESH_STEP: float = 4.0

## Texturas do chao, geradas por `arte/chao.py`. Os comprimentos de tile ao
## longo da pista sao os da receita de la, e mudar um sem o outro estica o
## desenho: o grao do asfalto foi feito para 6,6 m e a onda da calcada para
## 4,4 m. Os dois ficam bem acima de 1,7 m, que e o dobro do que a moto anda
## num quadro a 180 km/h - abaixo disso o desenho pisca em vez de passar.
const ASFALTO: Texture2D = preload("res://assets/visual/asfalto_albedo.png")
const ASFALTO_TILE: float = 6.6
const CALCADA: Texture2D = preload("res://assets/visual/calcada_albedo.png")
const CALCADA_TILE: float = 4.4
## Quanto da calcada cabe num tile de lado, em metros.
const CALCADA_LARGURA: float = 2.2
## O meio-fio, 20 cm de concreto mais claro que a pedra.
const MEIO_FIO: float = 0.2
const COR_MEIO_FIO := Color(0.70, 0.68, 0.65)
## Altura do meio-fio (V09a). Era 3 cm, so uma tira pintada, e a calcada lia
## no nivel da pista. Nas referencias e um degrau de guia de verdade, com a
## face na sombra. So visual: a calcada continua no nivel do asfalto para a
## fisica (o chao nao tem colisor), e a moto que sobe nela atravessa 15 cm de
## concreto num quadro, rapido demais para o olho.
const ALTURA_MEIO_FIO: float = 0.15
## A face do meio-fio virada para a pista: a sombra embaixo da guia que separa
## pista de calcada nas referencias (`video_01/t5.0s`) sem precisar da linha
## de bordo.
const COR_FACE_MEIO_FIO := Color(0.36, 0.35, 0.34)
## A tira de servico depois do andavel, com os postes (que ficam a 0,8 m).
const FAIXA_SERVICO: float = 1.6

## A pintura da avenida. Branco de tinta de rua, que puxa um pouco para o
## quente: branco puro, com o sol de meio-dia, estoura antes do LUT.
const TINTA := Color(0.90, 0.89, 0.84)
## Linha de bordo: 20 cm, a 10 cm do meio-fio (o CTB pede de 10 a 30 cm). Mais
## para dentro ela vira mais uma faixa; colada, briga com o meio-fio.
const BORDO_LARGURA: float = 0.2
const BORDO_RECUO: float = 0.1
## A faixa de pedestres zebrada, como a do CTB: listras ao longo da pista, de
## lado a lado. O periodo e lateral, e nao ao longo: quem passa por cima ve
## cada listra como uma barra de 4 m, e a regra do `arte/chao.py` (nada fino
## atravessado com periodo menor que 1,7 m) nao chega a valer. 50 cm de tinta
## e 70 de asfalto fecham 11 listras nas quatro faixas, sem sobra no meio-fio;
## o periodo real e de ~1 m, e o 1,2 m segura a listra la longe com mais de
## um pixel.
const ZEBRA_COMPRIMENTO: float = 4.0
const ZEBRA_LISTRA: float = 0.5
const ZEBRA_PERIODO: float = 1.2
## Da zebra ate a esquina: o pedestre atravessa na calcada, nao na boca da rua.
const ZEBRA_ESQUINA: float = 1.0
## Linha de retencao: 50 cm de largura, 1,6 m antes da zebra (o minimo do CTB).
## E a unica coisa fina atravessada na pista, e passa uma vez so: sem periodo,
## nao tem com o que piscar.
const RETENCAO_LARGURA: float = 0.5
const RETENCAO_RECUO: float = 1.6
## Na via expressa a metade da pista do lado do viaduto e a mao contraria, e a
## divisao e a faixa dupla amarela do CTB (sentidos opostos): duas linhas de
## 12 cm com 12 cm entre elas. Amarelo puxado para o ocre, porque o puro
## estoura no LUT do meio-dia.
const AMARELO := Color(0.88, 0.70, 0.20)
const DUPLA_LARGURA: float = 0.12
const DUPLA_VAO: float = 0.12
## Onde as faixas da corrida do lado do viaduto acabam, antes da rua da
## esquina: um zebrado em cunha, que nasce no meio-fio e chega no meio da
## pista na boca da rua. 40 m sao quase 3 s a 50 km/h, o que o transito leva
## para passar duas faixas para o lado (1,6 m/s de lateral). As listras a cada
## 3 m, acima dos 1,7 m que nao piscam a 180 km/h.
const ZEBRADO: float = 40.0
const ZEBRADO_PASSO: float = 3.0
const ZEBRADO_LISTRA: float = 0.5
## Quem escolhe faixa na expressa fica a isto da faixa dupla: o meio da faixa
## de dentro e o corredor das duas, e nao em cima da tinta.
const FOLGA_DA_DUPLA: float = 0.8
## Com os pilares no meio (1,2 m), quem escolhe faixa fica mais longe: o
## corredor entre as duas faixas de dentro e onde o pilar esta.
const FOLGA_DOS_PILARES: float = 1.4
## O chanfro da quina entre a rua da esquina e a expressa, no meio-fio: e por
## ele que a mao contraria vira, e sem ele a faixa de fora passava por cima
## da calcada. 5 m e raio de esquina de rua de cidade.
const ESQUINA_RAIO: float = 5.0

var curve: Curve3D
var length: float = 0.0
## Ate onde vai a pista sem o `extra` do `build`: o que o mundo sorteia do
## gerador dele (poste, os sorteios de greybox) para aqui, para o transito e os
## rivais continuarem saindo dele iguais.
var comprimento_da_avenida: float = 0.0
## Onde a pista e via expressa (V11b), como a `Cidade` sorteou: `[de, ate,
## lado]`, com o `lado` do viaduto e do perfil aberto. Quem anda na calcada e
## quem atravessa a rua precisa saber: ali nao ha calcada nem travessia.
var expressas: Array[Vector3] = []
## Para cada expressa, se as maos se separam por mureta e pilares no eixo da
## pista (`Cidade.PILARES_NO_MEIO`), e nao pela faixa dupla.
var pilares_no_meio: Array[bool] = []
## Onde a avenida e cruzada, como a `Cidade` sorteou: `[offset, lados]`, com os
## lados no sinal do `Cidade.LADO_*`. E dele que sai onde a pintura abre.
var cruzamentos: Array[Vector2] = []
## Meia largura da boca das ruas que cruzam, no meio-fio da avenida.
var boca: float = 0.0
## O nome da avenida e o de cada trecho de via expressa, na ordem de
## `expressas`, como a `Cidade` deu. E o que o GPS escreve embaixo do mapa.
var nome: String = ""
var nomes_das_expressas: Array[String] = []

var _asphalt_mesh: MeshInstance3D
var _pintura: MeshInstance3D


## `extra` metros de pista a mais depois dos `total_length`, sorteados de
## `rng_extra`: e o que a via expressa soma a corrida (V11b). Gerador separado
## para os primeiros `total_length` metros sairem identicos com ou sem ela, e
## para o `rng` sair daqui no mesmo estado: transito e rivais vem dele depois,
## e o banco de provas tem baseline deles.
func build(
	total_length: float,
	rng: RandomNumberGenerator,
	extra: float = 0.0,
	rng_extra: RandomNumberGenerator = null
) -> void:
	# Quem nao e parametrico na curva e precisa do chao - o corpo que voa no
	# atropelo (`Pessoa`) - acha a pista por aqui.
	add_to_group(GRUPO)
	curve = Curve3D.new()
	curve.bake_interval = 1.0

	# A pista e uma sequencia de trechos com curvatura e inclinacao sorteadas:
	# marginal reta e rapida, ladeira, curvao de orla. Fica variado o bastante
	# pra testar o feel sem virar level design de verdade.
	var pos := Vector3.ZERO
	var heading := 0.0
	var pitch := 0.0
	curve.add_point(pos)

	var travelled := 0.0
	var segment_left := 0.0
	var hill_left := 0.0
	var turn_per_m := 0.0
	var climb_per_m := 0.0
	var step := 12.0

	var avenida_pontos := 0
	while travelled < total_length + extra:
		var gerador := rng if travelled < total_length else rng_extra
		if travelled < total_length:
			avenida_pontos += 1
		if segment_left <= 0.0:
			segment_left = gerador.randf_range(90.0, 260.0)
			var kind := gerador.randi() % 10
			if kind < 3:
				turn_per_m = 0.0  # reta de marginal
			elif kind < 8:
				turn_per_m = (
					gerador.randf_range(0.12, 0.45) * (1.0 if gerador.randf() < 0.5 else -1.0)
				)
			else:
				# Teto de 0.6 graus/m nao e estetico: a 52 m/s isso da 31 graus/s de
				# guinada exigida, logo abaixo do que a moto entrega no talo. Curvao
				# passa raspando sem frear - qualquer coisa acima disso e injusto.
				turn_per_m = (
					gerador.randf_range(0.45, 0.6) * (1.0 if gerador.randf() < 0.5 else -1.0)
				)

		# A ladeira tem trecho PROPRIO, mais curto que o da curva.
		#
		# Antes ela era sorteada junto com a curvatura, e o resultado era que
		# toda subida comecava exatamente onde comecava uma curva: a pista
		# inteira tinha o mesmo ritmo. Separados, sobe no meio do curvao e
		# empina na reta - e o relevo deixa de ser decorativo.
		if hill_left <= 0.0:
			hill_left = gerador.randf_range(70.0, 200.0)
			climb_per_m = _pick_grade(gerador, pos.y)

		heading += deg_to_rad(turn_per_m) * step
		pitch = lerpf(pitch, climb_per_m, GRADE_BLEND)
		pos += Vector3(sin(heading), pitch, cos(heading)) * step
		curve.add_point(pos)
		travelled += step
		segment_left -= step
		hill_left -= step

	# Suaviza os cantos: sem tangentes a curva vira poligonal e a moto "engasga".
	_smooth_tangents()
	length = curve.get_baked_length()
	comprimento_da_avenida = length
	if extra > 0.0:
		comprimento_da_avenida = curve.get_closest_offset(curve.get_point_position(avenida_pontos))

	_build_mesh()


func build_surface() -> void:
	_build_mesh()


func grade_at(offset: float) -> float:
	return -sample_basis(offset).z.y


## Sorteia a rampa do proximo trecho: plano, ladeira mansa ou ladeira de valer.
##
## `altitude` puxa o sorteio de volta pro nivel do mar. Sem essa correcao a
## sequencia de sinais e um passeio aleatorio e a rota de 3 km termina 200 m
## acima ou abaixo de onde comecou - a cidade inteira ladeira abaixo, o que le
## como bug de geracao mesmo estando "certo".
static func _pick_grade(rng: RandomNumberGenerator, altitude: float) -> float:
	var kind := rng.randf()
	if kind < 0.3:
		return 0.0  # trecho plano: sem ele nao ha contraste, so montanha-russa
	var bias := clampf(-altitude / 70.0, -0.45, 0.45)
	var up := rng.randf() < 0.5 + bias * 0.5
	var steep := kind > 0.82
	var size := rng.randf_range(0.075, MAX_GRADE) if steep else rng.randf_range(0.025, 0.075)
	return size if up else -size


func _smooth_tangents() -> void:
	var count := curve.point_count
	for i in range(count):
		var prev := curve.get_point_position(maxi(i - 1, 0))
		var next := curve.get_point_position(mini(i + 1, count - 1))
		var tangent := (next - prev) * 0.25
		curve.set_point_in(i, -tangent)
		curve.set_point_out(i, tangent)


## --- Amostragem -----------------------------------------------------------


func sample_position(offset: float) -> Vector3:
	return curve.sample_baked(clampf(offset, 0.0, length), true)


## Base ortonormal da pista no ponto: forward (sentido da corrida), right, up.
func sample_basis(offset: float) -> Basis:
	var o := clampf(offset, 0.0, length)
	var a := sample_position(maxf(o - 0.5, 0.0))
	var b := sample_position(minf(o + 0.5, length))
	var forward := b - a
	if forward.length_squared() < 1e-8:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	var right := forward.cross(Vector3.UP)
	if right.length_squared() < 1e-8:
		right = Vector3.RIGHT
	right = right.normalized()
	var up := right.cross(forward).normalized()
	return Basis(right, up, -forward)


## Ponto do mundo a `offset` metros do inicio e `lateral` metros do eixo.
## lateral negativo = esquerda, positivo = direita.
func point(offset: float, lateral: float) -> Vector3:
	var b := sample_basis(offset)
	return sample_position(offset) + b.x * lateral


## Transform pronto pra posicionar um corpo na pista, olhando pra frente.
func transform_at(offset: float, lateral: float) -> Transform3D:
	var b := sample_basis(offset)
	return Transform3D(b, sample_position(offset) + b.x * lateral)


## Projeta uma posicao do mundo na curva, partindo de um palpite.
##
## Busca local em janela: O(1) por frame, ao contrario de get_closest_offset()
## que varre todos os pontos bakeados. So o jogador precisa disso - o resto do
## mundo e parametrico na curva e ja sabe seu proprio offset.
func project(world_pos: Vector3, hint_offset: float) -> Vector2:
	var best_offset := hint_offset
	var best_dist := INF

	for coarse in range(-10, 11):
		var o := hint_offset + float(coarse) * 1.5
		var d := sample_position(o).distance_squared_to(world_pos)
		if d < best_dist:
			best_dist = d
			best_offset = o

	for fine in range(-8, 9):
		var o := best_offset + float(fine) * 0.2
		var d := sample_position(o).distance_squared_to(world_pos)
		if d < best_dist:
			best_dist = d
			best_offset = o

	best_offset = clampf(best_offset, 0.0, length)
	# Um passo ao longo da tangente tira o degrau de 0.2 m da busca fina. Sem
	# ele o offset anda 0.6, 0.9, 0.7 m por frame a velocidade constante, e a
	# subida que o jogador deriva dele oscila o bastante pra quicar a moto
	# ate em ladeira mansa.
	var b := sample_basis(best_offset)
	var along := -(world_pos - sample_position(best_offset)).dot(b.z)
	best_offset = clampf(best_offset + along, 0.0, length)
	b = sample_basis(best_offset)
	var lateral := (world_pos - sample_position(best_offset)).dot(b.x)
	return Vector2(best_offset, lateral)


## A expressa cuja mao contraria ocupa `o`, ou `Vector3.ZERO`. Vai da boca da
## rua da esquina da entrada ate a da saida: e ali que os carros dela viram.
func contramao_em(o: float) -> Vector3:
	for e in expressas:
		if o >= e.x - 2.0 * boca and o <= e.y + 2.0 * boca:
			return e
	return Vector3.ZERO


## Se a lateral `l` em `o` e mao contraria.
func na_contramao(o: float, l: float) -> bool:
	var e := contramao_em(o)
	return e != Vector3.ZERO and l * e.z > 0.0


## Ate onde a corrida vai de lado entre `de` e `ate`: a pista inteira, ou so a
## metade dela se a janela pega uma mao contraria - com o zebrado antes, que
## ja fecha as faixas do lado dela. E o que o transito e os rivais perguntam
## antes de escolher faixa, olhando para a frente.
func mao_entre(de: float, ate: float) -> Vector2:
	var hw := half_width()
	for i in expressas.size():
		var e := expressas[i]
		if ate >= e.x - 2.0 * boca - ZEBRADO and de <= e.y + 2.0 * boca:
			var folga := FOLGA_DOS_PILARES if _com_pilares(i) else FOLGA_DA_DUPLA
			if e.z < 0.0:
				return Vector2(folga, hw)
			return Vector2(-hw, -folga)
	return Vector2(-hw, hw)


func _com_pilares(i: int) -> bool:
	return i < pilares_no_meio.size() and pilares_no_meio[i]


## Se o cruzamento `c` e a rua da esquina de uma expressa, por onde a mao
## contraria entra e sai (`Cidade.esquinas_das_expressas`). Ali nao ha zebra
## nem retencao: ninguem atravessa, e a avenida nao para.
func e_esquina(c: Vector2) -> bool:
	for e in expressas:
		if absf(c.x - (e.x - boca)) < 0.01 or absf(c.x - (e.y + boca)) < 0.01:
			return true
	return false


## O nome da via em `offset`: o do trecho de expressa, se cair num, e o da
## avenida no resto.
func nome_em(offset: float) -> String:
	for i in mini(expressas.size(), nomes_das_expressas.size()):
		if offset >= expressas[i].x and offset <= expressas[i].y:
			return nomes_das_expressas[i]
	return nome


## Centro da faixa `index` (0 = mais a esquerda), em metros do eixo.
static func lane_center(index: int) -> float:
	return (float(index) - float(LANE_COUNT - 1) * 0.5) * LANE_WIDTH


## Meio do corredor entre as faixas `index` e `index + 1`.
static func corridor_center(index: int) -> float:
	return lane_center(index) + LANE_WIDTH * 0.5


static func half_width() -> float:
	return float(LANE_COUNT) * LANE_WIDTH * 0.5


## Ate onde a calcada e livre: dali para fora vem a faixa de servico, a tira
## mais escura onde ficam os postes, e depois a fachada. A moto passa, mas e
## ali que mora o que derruba - e a camera de garupa, que nao tem colisor, nao
## passa.
static func sidewalk_limit() -> float:
	return half_width() + SHOULDER


## A unica parede analitica que sobrou: o fim do chao. Ate aqui quem segura a
## moto sao os colisores - predio, poste, carro parado. Ja foi o
## `sidewalk_limit`, um guard-rail invisivel na beira da calcada, e a rua
## virava um tubo: nao dava para bater na fachada nem entrar na transversal.
## Meio metro antes da borda, para a roda nao ficar pendurada no vazio.
static func limite_do_mundo() -> float:
	return half_width() + SHOULDER + GROUND - 0.5


## --- Mesh -----------------------------------------------------------------


func _build_mesh() -> void:
	var mesh := ArrayMesh.new()
	var road_w := half_width()

	var asphalt := SurfaceTool.new()
	asphalt.begin(Mesh.PRIMITIVE_TRIANGLES)
	var shoulder := SurfaceTool.new()
	shoulder.begin(Mesh.PRIMITIVE_TRIANGLES)
	var servico := SurfaceTool.new()
	servico.begin(Mesh.PRIMITIVE_TRIANGLES)

	var lift := 0.0
	var edge := road_w + SHOULDER
	var carpet := GROUND

	var steps := int(length / MESH_STEP)
	for i in range(steps):
		var o0 := float(i) * MESH_STEP
		var o1 := minf(o0 + MESH_STEP, length)
		# No asfalto o U conta faixas de rolamento: cada faixa e um tile inteiro,
		# entao a marca de pneu cai sempre onde a roda passa. Na calcada o U e 0
		# no meio-fio e 1 na borda de fora, dos dois lados.
		var faixas := road_w / LANE_WIDTH
		_quad(asphalt, o0, o1, -road_w, road_w, lift, Vector2(-faixas, faixas), ASFALTO_TILE)
		# Calcada do meio-fio ate o fim do terreno, sem grama: avenida de
		# cidade e pedra ate a fachada, e e debaixo dos predios e nas ruas que
		# cruzam que o resto aparece. Andavel continua so o `SHOULDER`.
		var fora := edge + carpet
		var tiles := (fora - road_w) / CALCADA_LARGURA
		_quad(shoulder, o0, o1, -fora, -road_w, 0.0, Vector2(tiles, 0), CALCADA_TILE)
		_quad(shoulder, o0, o1, road_w, fora, 0.0, Vector2(0, tiles), CALCADA_TILE)
		# Faixa de servico: onde moram os postes, e onde a moto para. Antes o
		# terreno caia ali e mostrava o limite; com pedra ate a fachada, e
		# esta tira que mostra.
		_quad(servico, o0, o1, -edge - FAIXA_SERVICO, -edge, 0.02)
		_quad(servico, o0, o1, edge, edge + FAIXA_SERVICO, 0.02)

	# O asfalto tem que ficar claramente mais claro que o fundo, senao a pista
	# desaparece e o jogador nao ve pra onde esta indo. Cores de meio-dia, e
	# neutras ou quentes de proposito: as de antes eram de noite, puxadas pro
	# azul, e com o ceu iluminando tudo de azul o asfalto virava violeta. A
	# calcada e pedra portuguesa clara.
	_commit(asphalt, mesh, material_texturizado(ASFALTO))
	_commit(shoulder, mesh, material_texturizado(CALCADA))
	_commit(servico, mesh, material_liso(Color(0.50, 0.49, 0.47)))

	_asphalt_mesh = MeshInstance3D.new()
	_asphalt_mesh.name = "RoadMesh"
	_asphalt_mesh.mesh = mesh
	_asphalt_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_asphalt_mesh)
	pintar(cruzamentos, boca)
	if (
		OS.has_environment("RUSHFOOD_SELFTEST_TRACE")
		or OS.has_environment("RUSHFOOD_SELFTEST_SHOTS")
	):
		print(
			(
				"  malha da pista: %d superficies, aabb=%s"
				% [mesh.get_surface_count(), mesh.get_aabb()]
			)
		)
		for i in range(mesh.get_surface_count()):
			print(
				(
					"    superficie %d: %d vertices, material=%s"
					% [i, mesh.surface_get_array_len(i), mesh.surface_get_material(i)]
				)
			)


## A tinta da avenida: tracejado, linha de bordo e, em cada cruzamento, zebra
## e linha de retencao. Malha propria, refeita quando a `Cidade` sorteia onde a
## avenida e cruzada: a pista e a cidade saem de geradores diferentes, e a
## pintura e o unico ponto onde uma depende da outra.
func pintar(a_cruzamentos: Array[Vector2], a_boca: float) -> void:
	cruzamentos = a_cruzamentos
	boca = a_boca
	if _pintura:
		_pintura.queue_free()
	var road_w := half_width()
	var tinta := SurfaceTool.new()
	tinta.begin(Mesh.PRIMITIVE_TRIANGLES)
	# O meio-fio mora aqui, e nao no `_build_mesh`, porque abre na boca das
	# ruas que cruzam, e so aqui se sabe onde elas estao. Com 3 cm ele podia
	# passar por cima da boca, que ninguem via; com 15 cm era um muro na
	# frente de quem sai da transversal.
	var curb := SurfaceTool.new()
	curb.begin(Mesh.PRIMITIVE_TRIANGLES)
	var face := SurfaceTool.new()
	face.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sem_meio_fio: Array[Array] = [[], []]

	# Onde cada pintura corrida abre. O tracejado para na retencao e volta do
	# outro lado do cruzamento, como manda o CTB; a linha de bordo abre na boca
	# da rua, do lado que ela chega, e na zebra, dos dois.
	var sem_tracejado: Array[Vector2] = []
	var sem_bordo: Array[Array] = [[], []]
	# Cada divisoria de faixa (1 a 3, da esquerda) abre onde a contramao pede.
	var sem_divisoria: Array[Array] = []
	for i in LANE_COUNT:
		var vazio: Array[Vector2] = []
		sem_divisoria.append(vazio)
	for c in cruzamentos:
		if e_esquina(c):
			continue
		var zebra_fim := c.x - boca - ZEBRA_ESQUINA
		var zebra_inicio := zebra_fim - ZEBRA_COMPRIMENTO
		var retencao := zebra_inicio - RETENCAO_RECUO - RETENCAO_LARGURA
		sem_tracejado.append(Vector2(retencao, c.x + boca))
		for k in 2:
			var side := -1.0 if k == 0 else 1.0
			var abre := c.y == 0.0 or c.y == side
			var fim := c.x + boca if abre else zebra_fim
			sem_bordo[k].append(Vector2(retencao, fim))
			if abre:
				sem_meio_fio[k].append(Vector2(c.x - boca, c.x + boca))
		for x in listras_da_zebra(road_w * 2.0):
			_quad(
				tinta, zebra_inicio, zebra_fim, x - ZEBRA_LISTRA * 0.5, x + ZEBRA_LISTRA * 0.5, 0.03
			)
		_quad(tinta, retencao, retencao + RETENCAO_LARGURA, -road_w, road_w, 0.03)

	var amarela := SurfaceTool.new()
	amarela.begin(Mesh.PRIMITIVE_TRIANGLES)
	for e in expressas:
		var k := 0 if e.z < 0.0 else 1
		var boca_entrada := e.x - 2.0 * boca
		var boca_saida := e.y + 2.0 * boca
		var zebrado := boca_entrada - ZEBRADO
		# O meio-fio e a linha de bordo abrem na boca da rua e no chanfro.
		for t: Vector2 in [
			Vector2(boca_entrada, e.x + ESQUINA_RAIO), Vector2(e.y - ESQUINA_RAIO, boca_saida)
		]:
			sem_meio_fio[k].append(t)
			sem_bordo[k].append(t)
		# O tracejado do meio vira faixa dupla na expressa, e some no zebrado e
		# nas bocas; o do lado da contramao some no zebrado e nas bocas, onde os
		# carros dela viram atravessando.
		sem_divisoria[2].append(Vector2(zebrado, boca_saida))
		var lado_dela := 1 if e.z < 0.0 else 3
		sem_divisoria[lado_dela].append(Vector2(zebrado, e.x))
		sem_divisoria[lado_dela].append(Vector2(e.y, boca_saida))
		_zebrado(tinta, zebrado, boca_entrada, e.z)

	var steps := int(length / MESH_STEP)
	for i in range(steps):
		var o0 := float(i) * MESH_STEP
		var o1 := minf(o0 + MESH_STEP, length)
		# Faixas divisorias tracejadas: alem de ler a pista, elas sao a
		# referencia visual do corredor entre as filas de carro.
		if i % 3 != 2 and _livre(o0, o1 - 1.2, sem_tracejado):
			for lane in range(1, LANE_COUNT):
				if not _livre(o0, o1 - 1.2, sem_divisoria[lane]):
					continue
				var x := lane_center(lane) - LANE_WIDTH * 0.5
				_quad(tinta, o0, o1 - 1.2, x - 0.16, x + 0.16, 0.03)
		for k in expressas.size():
			# Com os pilares no meio, a mureta e que separa: sem tinta embaixo.
			if _com_pilares(k):
				continue
			var e := expressas[k]
			var a := maxf(o0, e.x)
			var b := minf(o1, e.y)
			if a < b:
				var x := DUPLA_VAO * 0.5
				_quad(amarela, a, b, x, x + DUPLA_LARGURA, 0.03)
				_quad(amarela, a, b, -x - DUPLA_LARGURA, -x, 0.03)
		var dentro := road_w - BORDO_RECUO
		for t in _recorta(o0, o1, sem_bordo[0]):
			_quad(tinta, t.x, t.y, -dentro, -dentro + BORDO_LARGURA, 0.03)
		for t in _recorta(o0, o1, sem_bordo[1]):
			_quad(tinta, t.x, t.y, dentro - BORDO_LARGURA, dentro, 0.03)
		# O meio-fio e uma tira propria: na textura ele repetiria a cada tile.
		for k in 2:
			var side := -1.0 if k == 0 else 1.0
			var x0 := minf(side * road_w, side * (road_w + MEIO_FIO))
			for t in _recorta(o0, o1, sem_meio_fio[k]):
				_quad(curb, t.x, t.y, x0, x0 + MEIO_FIO, ALTURA_MEIO_FIO)
				_face(face, t.x, t.y, side * road_w, ALTURA_MEIO_FIO)

	var mesh := ArrayMesh.new()
	_commit(tinta, mesh, material_liso(TINTA))
	# Sem expressa a superficie amarela fica vazia, e vazia quebra o `ArrayMesh`.
	if not expressas.is_empty():
		_commit(amarela, mesh, material_liso(AMARELO))
	_commit(curb, mesh, material_liso(COR_MEIO_FIO))
	_commit(face, mesh, material_liso(COR_FACE_MEIO_FIO))
	_pintura = MeshInstance3D.new()
	_pintura.name = "Pintura"
	_pintura.mesh = mesh
	_pintura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_pintura)


## O zebrado em cunha de `de` a `ate`, do lado `lado`: a linha que sai do
## meio-fio e chega no meio da pista, e as listras entre ela e o meio-fio.
func _zebrado(st: SurfaceTool, de: float, ate: float, lado: float) -> void:
	var hw := half_width() - BORDO_RECUO
	var o := de
	while o < ate - 0.01:
		var o1 := minf(o + 0.5, ate)
		var x := hw * (1.0 - ((o + o1) * 0.5 - de) / (ate - de))
		_quad(st, o, o1, minf(lado * x, lado * (x - 0.2)), maxf(lado * x, lado * (x - 0.2)), 0.03)
		o = o1
	o = de + ZEBRADO_PASSO
	while o < ate - ZEBRADO_LISTRA:
		var x := hw * (1.0 - (o - de) / (ate - de))
		_quad(st, o, o + ZEBRADO_LISTRA, minf(lado * x, lado * hw), maxf(lado * x, lado * hw), 0.03)
		o += ZEBRADO_PASSO


## Centro de cada listra de uma zebra que atravessa `largura` metros de rua,
## medido do meio dela. Simetrica: zebra que sobra mais de um lado que do outro
## parece pintada torta.
static func listras_da_zebra(largura: float) -> Array[float]:
	# Pelo menos 30 cm de asfalto entre a ultima listra e o meio-fio.
	var cabem := floori((largura - 0.6 + ZEBRA_PERIODO - ZEBRA_LISTRA) / ZEBRA_PERIODO)
	var meio := float(cabem - 1) * 0.5
	var centros: Array[float] = []
	for i in cabem:
		centros.append((float(i) - meio) * ZEBRA_PERIODO)
	return centros


## Se `[a, b]` nao encosta em nenhum dos `buracos`.
static func _livre(a: float, b: float, buracos: Array[Vector2]) -> bool:
	for h in buracos:
		if a < h.y and b > h.x:
			return false
	return true


## O que sobra de `[a, b]` tirando os `buracos`, em trechos.
static func _recorta(a: float, b: float, buracos: Array) -> Array[Vector2]:
	var trechos: Array[Vector2] = [Vector2(a, b)]
	for h: Vector2 in buracos:
		var sobra: Array[Vector2] = []
		for t in trechos:
			if t.y <= h.x or t.x >= h.y:
				sobra.append(t)
				continue
			if t.x < h.x:
				sobra.append(Vector2(t.x, h.x))
			if t.y > h.y:
				sobra.append(Vector2(h.y, t.y))
		trechos = sobra
	return trechos


## `u` e o U nas bordas `x0` e `x1`; com `tile` maior que zero, o quad ganha UV,
## com V em tiles percorridos ao longo da pista.
func _quad(
	st: SurfaceTool,
	o0: float,
	o1: float,
	x0: float,
	x1: float,
	lift: float = 0.0,
	u: Vector2 = Vector2.ZERO,
	tile: float = 0.0
) -> void:
	var up := Vector3.UP * lift
	var a := point(o0, x0) + up
	var b := point(o0, x1) + up
	var c := point(o1, x1) + up
	var d := point(o1, x0) + up
	var n := (c - a).cross(d - b).normalized()
	if n.y < 0.0:
		n = -n
	# Ordem HORARIA vista de cima. Godot considera a face frontal a de winding
	# horario; com a ordem invertida a pista inteira e descartada pelo backface
	# culling e some da tela sem erro nenhum no console.
	var v0 := o0 / tile if tile > 0.0 else 0.0
	var v1 := o1 / tile if tile > 0.0 else 0.0
	var uvs: Array[Vector2] = [
		Vector2(u.x, v0),
		Vector2(u.y, v1),
		Vector2(u.y, v0),
		Vector2(u.x, v0),
		Vector2(u.x, v1),
		Vector2(u.y, v1)
	]
	var verts: Array[Vector3] = [a, c, b, a, d, c]
	for i in verts.size():
		st.set_normal(n)
		if tile > 0.0:
			st.set_uv(uvs[i])
		st.add_vertex(verts[i])


## Uma parede vertical ao longo da pista, do chao ate `altura`, na lateral `x`
## e virada para o meio da pista.
func _face(st: SurfaceTool, o0: float, o1: float, x: float, altura: float) -> void:
	var up := Vector3.UP * altura
	var a := point(o0, x)
	var b := point(o1, x)
	var c := b + up
	var d := a + up
	var para_dentro := -sample_basis((o0 + o1) * 0.5).x * signf(x)
	# Mesma ordem do `_quad` e mesma regra de winding, conferida contra a
	# normal que se quer, e nao deduzida: um sinal errado aqui e o meio-fio
	# sumindo pelo backface culling, sem erro nenhum.
	var verts: Array[Vector3] = [a, c, b, a, d, c]
	var chao := (point(o1, x + 1.0) - point(o0, x)).cross(point(o0, x + 1.0) - point(o0, x))
	var frente_do_quad := signf(chao.dot(Vector3.UP))
	if ((c - a).cross(b - a) * frente_do_quad).dot(para_dentro) < 0.0:
		verts = [a, b, c, a, c, d]
	for v in verts:
		st.set_normal(para_dentro)
		st.add_vertex(v)


func _commit(st: SurfaceTool, mesh: ArrayMesh, mat: Material) -> void:
	st.commit(mesh)
	mesh.surface_set_material(mesh.get_surface_count() - 1, mat)


static func material_texturizado(tex: Texture2D) -> StandardMaterial3D:
	var mat := material_liso(Color.WHITE)
	mat.albedo_texture = tex
	# Linear com mipmap e anisotropico, e nao "nearest": o chao e visto quase
	# de lado e passando rapido. Com nearest, cada texel pula de pixel em pixel
	# a cada quadro e o asfalto ferve; o mipmap anisotropico media o que ja e
	# menor que um pixel na tela. O pixelado vem da resolucao de 640x360 e da
	# quantizacao com dither, que pegam a imagem pronta - nao da textura.
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return mat


static func material_liso(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	# Sprite3D billboard vem depois; quando vier, alpha_cut = DISCARD em todos
	# eles, senao o depth sorting quebra e o entregador some atras do carro
	# errado (ver docs/PROTOTIPO.md).
	return mat
