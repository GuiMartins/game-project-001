class_name Quebravel
extends StaticBody3D
## Destroco com voo, giro e contato analitico com a pista, que nao tem colisor.

## Sai um pouco mais rapido que a moto para o impacto continuar visivel a frente.
const EMPURRAO: float = 1.2
const GRAVIDADE: float = 18.0
const RESTITUICAO: float = 0.3
const ATRITO: float = 12.0
## Subpassos seguram as pontas do poste comprido no primeiro quique.
const SUBPASSOS: int = 8

var visual: Node3D
var quebrado: bool = false
var _inicial: Transform3D
var _pivo := Vector3.ZERO
var _centro := Vector3.ZERO
var _vel := Vector3.ZERO
var _giro := Vector3.ZERO
var _corpo := Basis.IDENTITY
var _inercia_inversa := Vector3.ONE
var _pontas := PackedVector3Array()
var _pista: RoadTrack
var _dica: float = 0.0
var _chao: float = 0.0
var _repouso: float = 0.0


## Fuste de semaforo ou portico, cujo desenho mora no no pai.
static func com_colisor(raiz: Node3D, tamanho: Vector3) -> Quebravel:
	var corpo := Quebravel.new()
	corpo.visual = raiz
	corpo.collision_layer = Layers.WORLD
	corpo.collision_mask = 0
	var forma := Greybox.box_shape(tamanho)
	forma.position = Vector3.UP * tamanho.y * 0.5
	corpo.add_child(forma)
	raiz.add_child(corpo)
	return corpo


func _ready() -> void:
	if visual == null:
		visual = self
	add_to_group(&"quebraveis")
	set_physics_process(false)


func quebrar(velocidade: Vector3) -> void:
	if quebrado:
		return
	quebrado = true
	set_deferred("collision_layer", 0)
	_inicial = visual.transform
	_chao = visual.global_position.y
	_medir()
	_corpo = visual.global_basis.orthonormalized()
	_centro = visual.to_global(_pivo)
	var frente := Vector3(velocidade.x, 0.0, velocidade.z)
	var rapidez := frente.length()
	frente = frente.normalized() if rapidez > 0.01 else Vector3.FORWARD
	_vel = frente * clampf(rapidez * EMPURRAO, 12.0, 75.0)
	_vel.y = 5.5 + minf(rapidez * 0.07, 3.5)
	_giro = Vector3.UP.cross(frente) * 2.4 + Vector3.UP * 0.45
	_pista = get_tree().get_first_node_in_group(RoadTrack.GRUPO) as RoadTrack
	if _pista != null:
		_dica = _pista.curve.get_closest_offset(_pista.to_local(_centro))
	_repouso = 0.0
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	var solo := Vector3(_centro.x, _chao, _centro.z)
	var normal := Vector3.UP
	if is_instance_valid(_pista):
		var proj := _pista.project(_pista.to_local(_centro), _dica)
		_dica = proj.x
		solo = _pista.to_global(_pista.point(proj.x, proj.y))
		normal = (_pista.global_basis * _pista.sample_basis(proj.x).y).normalized()
	for _passo in SUBPASSOS:
		_voar(delta / SUBPASSOS, solo, normal)
	visual.global_transform = Transform3D(_corpo, _centro - _corpo * _pivo)
	# O contato de uma haste fina treme alguns milimetros; isso ja e repouso visual.
	if _vel.length_squared() < 0.16 and _giro.length_squared() < 0.25:
		_repouso += delta
		if _repouso > 0.5:
			set_physics_process(false)
	else:
		_repouso = 0.0


func _voar(delta: float, solo: Vector3, normal: Vector3) -> void:
	_vel.y -= GRAVIDADE * delta
	_centro += _vel * delta
	var giro := _giro.length()
	if giro > 0.001:
		_corpo = (Basis(_giro / giro, giro * delta) * _corpo).orthonormalized()
	var fundo := INF
	var contato := Vector3.ZERO
	for ponta in _pontas:
		var raio := _corpo * ponta
		var altura := (_centro + raio - solo).dot(normal)
		if altura < fundo:
			fundo = altura
			contato = raio
	if fundo >= 0.0:
		return
	_centro -= normal * fundo
	var chegando := (_vel + _giro.cross(contato)).dot(normal)
	if chegando < 0.0:
		var torque := _inverter_inercia(contato.cross(normal))
		var quique := RESTITUICAO if chegando < -2.0 else 0.0
		var impulso := -(1.0 + quique) * chegando / (1.0 + torque.cross(contato).dot(normal))
		_vel += normal * impulso
		_giro += torque * impulso
	var plano := _vel - normal * _vel.dot(normal)
	_vel -= plano.limit_length(ATRITO * delta)
	_giro *= exp(-3.0 * delta)


func _inverter_inercia(torque: Vector3) -> Vector3:
	return _corpo * ((_corpo.transposed() * torque) * _inercia_inversa)


## As malhas completas entram na medida: a chapa e os bracos tambem tocam o chao.
func _medir() -> void:
	var caixa := AABB()
	var primeira := true
	for no: Node in visual.find_children("*", "MeshInstance3D", true, false):
		var malha := no as MeshInstance3D
		var local := visual.global_transform.affine_inverse() * malha.global_transform
		var limite := local * malha.get_aabb()
		caixa = limite if primeira else caixa.merge(limite)
		primeira = false
	if primeira:
		caixa = AABB(Vector3(-0.2, 0, -0.2), Vector3(0.4, 2.6, 0.4))
	_pivo = caixa.get_center()
	_pontas.clear()
	for i in 8:
		_pontas.append(caixa.get_endpoint(i) - _pivo)
	var tamanho := caixa.size
	_inercia_inversa = Vector3(
		12.0 / maxf(tamanho.y * tamanho.y + tamanho.z * tamanho.z, 0.01),
		12.0 / maxf(tamanho.x * tamanho.x + tamanho.z * tamanho.z, 0.01),
		12.0 / maxf(tamanho.x * tamanho.x + tamanho.y * tamanho.y, 0.01)
	)


func reiniciar() -> void:
	if not quebrado:
		return
	set_physics_process(false)
	quebrado = false
	visual.transform = _inicial
	visual.visible = true
	set_deferred("collision_layer", Layers.WORLD)
