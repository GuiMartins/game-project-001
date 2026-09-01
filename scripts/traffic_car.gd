extends AnimatableBody3D
class_name TrafficCar
## Carro do transito parado. Parametrico na curva: sabe seu proprio offset e
## nunca precisa se projetar na pista.
##
## E o carro que cria o corredor. Ele anda devagar, muda de faixa sem olhar e
## abre a porta na sua cara - as tres coisas que fazem o corredor valer a pena.

const SIZE := Vector3(1.9, 1.5, 4.4)
const DOOR_SIZE := Vector3(1.1, 1.0, 1.6)

## Greybox com cor, nao greybox cinza. A 320x180 duas caixas cinzas coladas nao
## se separam, e o corredor deixa de ser legivel.
const CAR_COLORS: Array[Color] = [
	Color(0.62, 0.64, 0.70), Color(0.72, 0.45, 0.40), Color(0.40, 0.52, 0.68),
	Color(0.75, 0.72, 0.55), Color(0.45, 0.60, 0.52), Color(0.55, 0.50, 0.62),
]

var track: RoadTrack
var offset: float = 0.0
var lateral: float = 0.0
var speed: float = 0.0
## Encostado no meio-fio: parado, numa das faixas da ponta. So quem esta
## encostado pode abrir porta.
var parked: bool = false
## Marcado quando o jogador ja pontuou a raspada neste carro, pra nao contar duas vezes.
var near_missed: bool = false

var _target_lateral: float = 0.0
var _lane_change_timer: float = 0.0
var _door_timer: float = 0.0
var _door_open: bool = false
## Este carro chega a abrir a porta em algum momento? Sorteado ao encostar.
var _opens_door: bool = false
var _rng := RandomNumberGenerator.new()
var _door_mesh: MeshInstance3D
var _door_shape: CollisionShape3D
var _body_mesh: MeshInstance3D

## Emitido quando a porta abre, pra HUD/audio avisarem o jogador.
signal door_opened


func _ready() -> void:
	sync_to_physics = true
	collision_layer = Layers.WORLD
	collision_mask = 0

	_body_mesh = Greybox.box(SIZE, CAR_COLORS[randi() % CAR_COLORS.size()])
	add_child(_body_mesh)
	var cs := Greybox.box_shape(SIZE)
	add_child(cs)

	# Teto mais claro: a 320x180 a leitura de silhueta e tudo.
	var roof := Greybox.box(Vector3(SIZE.x * 0.82, 0.7, SIZE.z * 0.5), Color(0.72, 0.73, 0.78))
	roof.position = Vector3(0.0, SIZE.y * 0.5 + 0.3, -0.2)
	add_child(roof)

	_door_mesh = Greybox.box(DOOR_SIZE, Color(0.85, 0.35, 0.2), true)
	_door_mesh.visible = false
	add_child(_door_mesh)

	_door_shape = Greybox.box_shape(DOOR_SIZE)
	_door_shape.disabled = true
	add_child(_door_shape)
	_place_door(-1)


func setup(a_track: RoadTrack, a_offset: float, a_lateral: float, seed_value: int,
		a_parked: bool = false, a_opens_door: bool = false) -> void:
	track = a_track
	_rng.seed = seed_value
	_lane_change_timer = _rng.randf_range(3.0, 14.0)
	_reset_at(a_offset, a_lateral, a_parked, a_opens_door)


## Poe a porta de um dos lados do carro.
##
## Pista ou calcada, tanto faz - o que importa e voce nao poder decorar de que
## lado ela vem. Porta previsivel deixa de ser susto e vira pedagio.
func _place_door(side: int) -> void:
	var at := Vector3(float(side) * (SIZE.x + DOOR_SIZE.x) * 0.5, -0.1, 0.2)
	_door_mesh.position = at
	_door_shape.position = at


func _physics_process(delta: float) -> void:
	if track == null:
		return

	offset += speed * delta
	lateral = move_toward(lateral, _target_lateral, 1.6 * delta)

	# Encostado nao muda de faixa: esta estacionado, nao no fluxo.
	if not parked:
		_lane_change_timer -= delta
		if _lane_change_timer <= 0.0:
			_lane_change_timer = _rng.randf_range(4.0, 16.0)
			# Muda de faixa: o corredor que estava aberto fecha, outro abre.
			var dir := 1.0 if _rng.randf() < 0.5 else -1.0
			var candidate := _target_lateral + RoadTrack.LANE_WIDTH * dir
			var limit := RoadTrack.half_width() - RoadTrack.LANE_WIDTH * 0.5
			if absf(candidate) <= limit:
				_target_lateral = candidate

	# `_opens_door` so e verdade em carro encostado, entao carro em movimento
	# nunca chega aqui.
	if _opens_door:
		_door_timer -= delta
		if _door_timer <= 0.0:
			if _door_open:
				_set_door(false)
				_door_timer = _rng.randf_range(10.0, 35.0)
			else:
				_set_door(true)
				_door_timer = _rng.randf_range(2.0, 4.0)

	_apply_transform()


func _apply_transform() -> void:
	var t := track.transform_at(offset, lateral)
	t.origin += t.basis.y * (SIZE.y * 0.5)
	global_transform = t


func _set_door(open: bool) -> void:
	_door_open = open
	_door_mesh.visible = open
	_door_shape.set_deferred("disabled", not open)
	if open:
		door_opened.emit()


## Reposiciona o carro mais a frente em vez de instanciar outro.
func recycle(a_offset: float, a_lateral: float, a_parked: bool = false,
		a_opens_door: bool = false) -> void:
	_reset_at(a_offset, a_lateral, a_parked, a_opens_door)


## Estado comum entre nascer e ser reciclado.
func _reset_at(a_offset: float, a_lateral: float, a_parked: bool,
		a_opens_door: bool) -> void:
	offset = a_offset
	lateral = a_lateral
	_target_lateral = a_lateral
	parked = a_parked
	# Transito de marginal em hora de pico: quase parado, e ai que ta a graca.
	# Encostado e parado de verdade - zero, nao "quase".
	speed = 0.0 if parked else _rng.randf_range(0.0, 7.0)
	_opens_door = a_parked and a_opens_door
	near_missed = false
	_set_door(false)
	_place_door(-1 if _rng.randf() < 0.5 else 1)
	_door_timer = _rng.randf_range(6.0, 30.0)
	_apply_transform()
