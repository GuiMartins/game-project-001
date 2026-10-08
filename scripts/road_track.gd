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

const LANE_WIDTH: float = 3.3
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
## Quanto da calcada cabe num tile de lado: a junta longitudinal fica a cada 2,2 m.
const CALCADA_LARGURA: float = 2.2
## O meio-fio, 20 cm de concreto mais claro que o cimentado.
const MEIO_FIO: float = 0.2
## A tira de servico depois do andavel, com os postes (que ficam a 0,8 m).
const FAIXA_SERVICO: float = 1.6

var curve: Curve3D
var length: float = 0.0

var _asphalt_mesh: MeshInstance3D


func build(total_length: float, rng: RandomNumberGenerator) -> void:
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

	while travelled < total_length:
		if segment_left <= 0.0:
			segment_left = rng.randf_range(90.0, 260.0)
			var kind := rng.randi() % 10
			if kind < 3:
				turn_per_m = 0.0  # reta de marginal
			elif kind < 8:
				turn_per_m = rng.randf_range(0.12, 0.45) * (1.0 if rng.randf() < 0.5 else -1.0)
			else:
				# Teto de 0.6 graus/m nao e estetico: a 52 m/s isso da 31 graus/s de
				# guinada exigida, logo abaixo do que a moto entrega no talo. Curvao
				# passa raspando sem frear - qualquer coisa acima disso e injusto.
				turn_per_m = rng.randf_range(0.45, 0.6) * (1.0 if rng.randf() < 0.5 else -1.0)

		# A ladeira tem trecho PROPRIO, mais curto que o da curva.
		#
		# Antes ela era sorteada junto com a curvatura, e o resultado era que
		# toda subida comecava exatamente onde comecava uma curva: a pista
		# inteira tinha o mesmo ritmo. Separados, sobe no meio do curvao e
		# empina na reta - e o relevo deixa de ser decorativo.
		if hill_left <= 0.0:
			hill_left = rng.randf_range(70.0, 200.0)
			climb_per_m = _pick_grade(rng, pos.y)

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
	var curb := SurfaceTool.new()
	curb.begin(Mesh.PRIMITIVE_TRIANGLES)
	var servico := SurfaceTool.new()
	servico.begin(Mesh.PRIMITIVE_TRIANGLES)
	var paint := SurfaceTool.new()
	paint.begin(Mesh.PRIMITIVE_TRIANGLES)

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
		# cidade e cimento ate a fachada, e e debaixo dos predios e nas ruas que
		# cruzam que o resto aparece. Andavel continua so o `SHOULDER`.
		var fora := edge + carpet
		var tiles := (fora - road_w) / CALCADA_LARGURA
		_quad(shoulder, o0, o1, -fora, -road_w, 0.0, Vector2(tiles, 0), CALCADA_TILE)
		_quad(shoulder, o0, o1, road_w, fora, 0.0, Vector2(0, tiles), CALCADA_TILE)
		# O meio-fio e uma tira propria: na textura ele repetiria a cada tile.
		_quad(curb, o0, o1, -road_w - MEIO_FIO, -road_w, 0.03)
		_quad(curb, o0, o1, road_w, road_w + MEIO_FIO, 0.03)
		# Faixa de servico: onde moram os postes, e onde a moto para. Antes o
		# terreno caia ali e mostrava o limite; com cimento ate a fachada, e
		# esta tira que mostra.
		_quad(servico, o0, o1, -edge - FAIXA_SERVICO, -edge, 0.02)
		_quad(servico, o0, o1, edge, edge + FAIXA_SERVICO, 0.02)

		# Faixas divisorias tracejadas: alem de ler a pista, elas sao a
		# referencia visual do corredor entre as filas de carro.
		if i % 3 != 2:
			for lane in range(1, LANE_COUNT):
				var x := lane_center(lane) - LANE_WIDTH * 0.5
				_quad(paint, o0, o1 - 1.2, x - 0.16, x + 0.16, lift + 0.03)
		_quad(paint, o0, o1, -road_w - 0.28, -road_w + 0.04, lift + 0.03)
		_quad(paint, o0, o1, road_w - 0.04, road_w + 0.28, lift + 0.03)

	# O asfalto tem que ficar claramente mais claro que o fundo, senao a pista
	# desaparece e o jogador nao ve pra onde esta indo. Cores de meio-dia, e
	# neutras ou quentes de proposito: as de antes eram de noite, puxadas pro
	# azul, e com o ceu iluminando tudo de azul o asfalto virava violeta. A
	# calcada e cimento claro.
	_commit(asphalt, mesh, material_texturizado(ASFALTO))
	_commit(shoulder, mesh, material_texturizado(CALCADA))
	_commit(curb, mesh, material_liso(Color(0.70, 0.68, 0.65)))
	_commit(servico, mesh, material_liso(Color(0.50, 0.49, 0.47)))
	_commit(paint, mesh, material_liso(Color(0.88, 0.86, 0.68)))

	_asphalt_mesh = MeshInstance3D.new()
	_asphalt_mesh.name = "RoadMesh"
	_asphalt_mesh.mesh = mesh
	_asphalt_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_asphalt_mesh)
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
