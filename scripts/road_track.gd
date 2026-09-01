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
			climb_per_m = rng.randf_range(-0.055, 0.055)

		heading += deg_to_rad(turn_per_m) * step
		pitch = lerpf(pitch, climb_per_m, 0.25)
		pos += Vector3(sin(heading), pitch, cos(heading)) * step
		curve.add_point(pos)
		travelled += step
		segment_left -= step

	# Suaviza os cantos: sem tangentes a curva vira poligonal e a moto "engasga".
	_smooth_tangents()
	length = curve.get_baked_length()

	_build_mesh()


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

	var steps := int(length / MESH_STEP)
	for i in range(steps):
		var o0 := float(i) * MESH_STEP
		var o1 := minf(o0 + MESH_STEP, length)
		_quad(asphalt, o0, o1, -road_w, road_w)
		_quad(shoulder, o0, o1, -road_w - SHOULDER, -road_w)
		_quad(shoulder, o0, o1, road_w, road_w + SHOULDER)
		_quad(ground, o0, o1, -road_w - SHOULDER - GROUND, -road_w - SHOULDER, -0.35)
		_quad(ground, o0, o1, road_w + SHOULDER, road_w + SHOULDER + GROUND, -0.35)

		# Faixas divisorias tracejadas: alem de ler a pista, elas sao a
		# referencia visual do corredor entre as filas de carro.
		if i % 3 != 2:
			for lane in range(1, LANE_COUNT):
				var x := lane_center(lane) - LANE_WIDTH * 0.5
				_quad(paint, o0, o1 - 1.2, x - 0.16, x + 0.16, 0.03)
		_quad(paint, o0, o1, -road_w - 0.28, -road_w + 0.04, 0.03)
		_quad(paint, o0, o1, road_w - 0.04, road_w + 0.28, 0.03)

	# O asfalto tem que ficar claramente mais claro que o fundo, senao a pista
	# desaparece contra o ceu e o jogador nao ve pra onde esta indo.
	_commit(ground, mesh, _flat_material(Color(0.13, 0.15, 0.13)))
	_commit(asphalt, mesh, _flat_material(Color(0.29, 0.29, 0.33)))
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
