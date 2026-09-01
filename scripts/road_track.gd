extends Node3D
class_name RoadTrack
## Pista como geometria 3D real, gerada a partir de uma Curve3D.
##
## Decisao de arquitetura (ver docs/PROTOTIPO.md): o mundo e 3D de verdade, nao
## pseudo-3D por scanlines. Ladeira, curva e salto saem de graca da curva.
##
## O chao NAO tem colisor. Altura e direcao sao amostradas analiticamente da
## curva - a 50 m/s um CharacterBody3D atravessaria um trimesh. Colisores
## existem so pro que importa: carros, postes e guard-rail.

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

var curve: Curve3D
var length: float = 0.0
## Este trecho e um atalho, e nao a rota principal.
##
## Muda so o desenho: atalho sobe 4 cm e nao tem acostamento. Ele nasce colado
## na pista principal na boca da bifurcacao, e duas superficies exatamente na
## mesma altura piscam (z-fighting) em vez de uma passar por cima da outra.
var is_shortcut: bool = false

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


## Constroi um atalho: a corda entre dois pontos da pista principal.
##
## Bifurcacao de Road Rash e isto e nada mais: onde a avenida faz a volta, sai
## uma rua que corta reto e devolve voce la na frente. Nao ha level design
## nenhum aqui - a geometria da rota e que diz onde valeu a pena cortar, e o
## `World` so aceita a corda quando ela economiza pista de verdade.
##
## As tangentes das pontas sao as da propria pista, entao a boca e a
## reentrada sao continuas: o atalho nasce apontando pra onde a avenida estava
## indo e chega apontando pra onde ela vai. E o que permite trocar a moto de
## pista sem teleporte nenhum.
func build_shortcut(main: RoadTrack, from_offset: float, to_offset: float) -> void:
	is_shortcut = true
	curve = Curve3D.new()
	curve.bake_interval = 1.0

	var p0 := main.sample_position(from_offset)
	var p3 := main.sample_position(to_offset)
	var f0 := -main.sample_basis(from_offset).z
	var f1 := -main.sample_basis(to_offset).z
	# 0.34 da distancia entre as pontas: menos que isso faz a corda sair de
	# lado da avenida como se fosse uma esquina; mais que isso e a corda
	# abracar a curva que ela deveria estar cortando.
	var pull := p0.distance_to(p3) * 0.34
	var p1 := p0 + f0 * pull
	var p2 := p3 - f1 * pull

	var steps := maxi(int(p0.distance_to(p3) / 10.0), 8)
	var points: Array[Vector3] = []
	for i in range(steps + 1):
		points.append(_bezier(p0, p1, p2, p3, float(i) / float(steps)))

	_follow_terrain(points, main, from_offset, to_offset)
	for point_at: Vector3 in points:
		curve.add_point(point_at)

	_smooth_tangents()
	length = curve.get_baked_length()
	_build_mesh()


## Cola a altura do atalho no terreno da avenida.
##
## Sem isto o atalho e uma ponte: o Bezier interpola a altura entre as duas
## pontas em linha reta, enquanto o terreno em volta sobe e desce com a
## avenida. Medido, dava 1,7 m de diferenca - e como o carpete de chao da
## avenida tem 43 m de cada lado do eixo, ele passava POR CIMA do atalho. O
## jogador via a moto afundar no chao no meio da rua.
##
## A altura vem do ponto da avenida mais proximo de cada ponto do atalho, e nao
## do progresso ao longo dele: numa corda cortando uma curva fechada, o pedaco
## de avenida mais perto nao e o que esta na mesma fracao do caminho.
func _follow_terrain(points: Array[Vector3], main: RoadTrack,
		from_offset: float, to_offset: float) -> void:
	for i in range(points.size()):
		var best := INF
		var at := from_offset - 60.0
		while at < to_offset + 60.0:
			var candidate := main.sample_position(at)
			var flat := Vector2(candidate.x - points[i].x, candidate.z - points[i].z)
			if flat.length_squared() < best:
				best = flat.length_squared()
				points[i].y = candidate.y
			at += 3.0

	# O ponto mais proximo pula quando a corda passa perto de dois pedacos da
	# mesma curva, e pulo na altura vira degrau na pista. Tres passadas de
	# media movel resolvem, com as pontas presas: elas TEM que encostar na
	# avenida, senao a boca e a reentrada ganham degrau.
	for pass_index in range(3):
		var smoothed := points.duplicate()
		for i in range(1, points.size() - 1):
			smoothed[i].y = points[i - 1].y * 0.25 + points[i].y * 0.5 + points[i + 1].y * 0.25
		for i in range(1, points.size() - 1):
			points[i] = smoothed[i]


static func _bezier(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var u := 1.0 - t
	return p0 * (u * u * u) + p1 * (3.0 * u * u * t) + p2 * (3.0 * u * t * t) + p3 * (t * t * t)


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


## Inclinacao da pista no ponto, em altura por metro percorrido.
## Positivo sobe, negativo desce.
func grade_at(offset: float) -> float:
	return -sample_basis(offset).z.y


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
	var forward := (b - a)
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
	var b := sample_basis(best_offset)
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


## Ate onde da pra andar, contando a calcada.
##
## O acostamento ja e uma faixa visualmente distinta no mesh e o terreno cai
## 0.35 m logo depois dele - entao o limite cai num lugar que o jogador ve.
## Antes o guard-rail ficava em half_width + SHOULDER*0.6, no MEIO do
## acostamento: parede invisivel no meio de uma coisa com cara de andavel.
static func sidewalk_limit() -> float:
	return half_width() + SHOULDER


## --- Mesh -----------------------------------------------------------------

func _build_mesh() -> void:
	var mesh := ArrayMesh.new()
	var road_w := half_width()

	var asphalt := SurfaceTool.new()
	asphalt.begin(Mesh.PRIMITIVE_TRIANGLES)
	var shoulder := SurfaceTool.new()
	shoulder.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ground := SurfaceTool.new()
	ground.begin(Mesh.PRIMITIVE_TRIANGLES)
	var paint := SurfaceTool.new()
	paint.begin(Mesh.PRIMITIVE_TRIANGLES)

	# O atalho sobe 4 cm e dispensa o acostamento. Os 4 cm resolvem o
	# z-fighting com a avenida na boca da bifurcacao, onde as duas pistas se
	# sobrepoem; sem acostamento, a unica coisa que o atalho pinta por cima da
	# avenida e asfalto sobre asfalto, que ninguem enxerga. O terreno dele fica
	# 35 cm abaixo, entao some sozinho debaixo da avenida.
	var lift := 0.04 if is_shortcut else 0.0
	var edge := road_w if is_shortcut else road_w + SHOULDER
	# Carpete curto no atalho. O da avenida tem 34 m de cada lado e ja cobre o
	# terreno em volta; o do atalho existe so pra ele nao flutuar no vazio
	# quando corta longe demais. Largo, ele e que passaria por cima da avenida.
	var carpet := 12.0 if is_shortcut else GROUND

	var steps := int(length / MESH_STEP)
	for i in range(steps):
		var o0 := float(i) * MESH_STEP
		var o1 := minf(o0 + MESH_STEP, length)
		_quad(asphalt, o0, o1, -road_w, road_w, lift)
		if not is_shortcut:
			_quad(shoulder, o0, o1, -road_w - SHOULDER, -road_w)
			_quad(shoulder, o0, o1, road_w, road_w + SHOULDER)
		_quad(ground, o0, o1, -edge - carpet, -edge, lift - 0.35)
		_quad(ground, o0, o1, edge, edge + carpet, lift - 0.35)

		# Faixas divisorias tracejadas: alem de ler a pista, elas sao a
		# referencia visual do corredor entre as filas de carro.
		if i % 3 != 2:
			for lane in range(1, LANE_COUNT):
				var x := lane_center(lane) - LANE_WIDTH * 0.5
				_quad(paint, o0, o1 - 1.2, x - 0.16, x + 0.16, lift + 0.03)
		_quad(paint, o0, o1, -road_w - 0.28, -road_w + 0.04, lift + 0.03)
		_quad(paint, o0, o1, road_w - 0.04, road_w + 0.28, lift + 0.03)

	# O asfalto tem que ficar claramente mais claro que o fundo, senao a pista
	# desaparece contra o ceu e o jogador nao ve pra onde esta indo.
	_commit(ground, mesh, _flat_material(Color(0.13, 0.15, 0.13)))
	# Atalho e rua de bairro, nao avenida: asfalto mais escuro. E a unica pista
	# do jogador, a 320x180 e de longe, de que aquela boca leva pra outro
	# lugar.
	_commit(asphalt, mesh, _flat_material(
		Color(0.23, 0.23, 0.27) if is_shortcut else Color(0.29, 0.29, 0.33)))
	if not is_shortcut:
		_commit(shoulder, mesh, _flat_material(Color(0.19, 0.18, 0.17)))
	_commit(paint, mesh, _flat_material(Color(0.88, 0.86, 0.68)))

	_asphalt_mesh = MeshInstance3D.new()
	_asphalt_mesh.name = "RoadMesh"
	_asphalt_mesh.mesh = mesh
	_asphalt_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_asphalt_mesh)
	if OS.has_environment("RUSHFOOD_SELFTEST_TRACE") or OS.has_environment("RUSHFOOD_SELFTEST_SHOTS"):
		print("  malha da pista: %d superficies, aabb=%s" % [mesh.get_surface_count(), mesh.get_aabb()])
		for i in range(mesh.get_surface_count()):
			print("    superficie %d: %d vertices, material=%s" % [
				i, mesh.surface_get_array_len(i), mesh.surface_get_material(i)])


func _quad(st: SurfaceTool, o0: float, o1: float, x0: float, x1: float, lift: float = 0.0) -> void:
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
	for v: Vector3 in [a, c, b, a, d, c]:
		st.set_normal(n)
		st.add_vertex(v)


func _commit(st: SurfaceTool, mesh: ArrayMesh, mat: Material) -> void:
	st.commit(mesh)
	mesh.surface_set_material(mesh.get_surface_count() - 1, mat)


func _flat_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	# Sprite3D billboard vem depois; quando vier, alpha_cut = DISCARD em todos
	# eles, senao o depth sorting quebra e o entregador some atras do carro
	# errado (ver docs/PROTOTIPO.md).
	return mat
