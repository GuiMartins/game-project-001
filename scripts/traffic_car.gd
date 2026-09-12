class_name TrafficCar
extends AnimatableBody3D
## Carro do transito. Parametrico na curva: sabe seu proprio offset e nunca
## precisa se projetar na pista.
##
## E o carro que cria o corredor. Ele anda devagar, muda de faixa sem olhar,
## abre a porta na sua cara, para no sinal e empaca no engarrafamento - e cada
## uma dessas coisas e um jeito diferente de fechar a pista e deixar so o vao.

## Emitido quando a porta abre, pra HUD/audio avisarem o jogador.
signal door_opened

## 1,80 de largura, e nao 1,90: com faixa de 3,30 isso e a diferenca entre
## 1,40 e 1,50 de vao entre duas colunas de carro. Parece pouco e nao e - a
## moto tem 0,75, entao o vao util por lado passou de 32 pra 37 cm.
const SIZE := Vector3(1.8, 1.5, 4.4)
const DOOR_SIZE := Vector3(1.1, 1.0, 1.6)

## Greybox com cor, nao greybox cinza. A 320x180 duas caixas cinzas coladas nao
## se separam, e o corredor deixa de ser legivel.
const CAR_COLORS: Array[Color] = [
	Color(0.62, 0.64, 0.70),
	Color(0.72, 0.45, 0.40),
	Color(0.40, 0.52, 0.68),
	Color(0.75, 0.72, 0.55),
	Color(0.45, 0.60, 0.52),
	Color(0.55, 0.50, 0.62),
]

## Valores de fallback, usados so pelo carro que nao pertence a frota - o que
## fica largado dentro de um atalho. Esse nunca dirige, entao ele nunca leu
## slider nenhum. Quem esta na avenida usa o WorldTuning, que sai no F3.
const ACCEL: float = 2.2
const BRAKE: float = 4.5
const FOLLOW_GAP: float = 6.2

## De quantos em quantos frames o carro reconsulta a pista a frente.
##
## A consulta varre a frota inteira, entao ela custa N por carro por frame - N
## ao quadrado no mundo. Medido, com uma fila de 90 m em cena isso dava 4,7 ms
## por frame, mais de um quarto do orcamento a 60 Hz, so pra carro nao entrar
## em carro.
##
## Entre uma consulta e outra o vao e descontado pelo que o proprio carro
## andou. E a hipotese conservadora - supoe o carro da frente parado -, entao
## errar pra menos aqui freia cedo demais, nunca tarde demais.
const PROBE_EVERY: int = 4

var track: RoadTrack
var offset: float = 0.0
var lateral: float = 0.0
var speed: float = 0.0
## Velocidade que este carro busca quando a pista esta livre.
var cruise_speed: float = 0.0
## Encostado no meio-fio: parado, numa das faixas da ponta. So quem esta
## encostado pode abrir porta.
var parked: bool = false
## Preso num engarrafamento: no meio da pista, andando a passo, sem trocar de
## faixa. Diferente de `parked`, que e carro estacionado no meio-fio.
## Marcado quando o jogador ja pontuou a raspada neste carro, pra nao contar duas vezes.
var near_missed: bool = false
## Este carro esta comprometido com uma parada no vermelho.

## Quem sabe onde estao os outros carros e os semaforos.
##
## Untyped de proposito: o World ja conhece o TrafficCar, e tipar a volta
## fecharia um ciclo entre os dois class_name.
var world: Node
## Sliders do F3. Null no carro largado num atalho, que e obstaculo fixo e
## nunca dirige - por isso todo uso aqui cai nos const acima quando falta.
var world_tuning: WorldTuning

var _gap_cache: float = INF
var _probe_in: int = 0
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


func setup(
	a_track: RoadTrack,
	a_offset: float,
	a_lateral: float,
	seed_value: int,
	a_parked: bool = false,
	a_opens_door: bool = false
) -> void:
	track = a_track
	_rng.seed = seed_value
	_lane_change_timer = _rng.randf_range(3.0, 14.0)
	# Consulta desencontrada: se todos perguntassem no mesmo frame, economizar
	# tres frames em quatro so faria o pico ser quatro vezes maior.
	_probe_in = _rng.randi_range(1, PROBE_EVERY)
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

	if parked:
		speed = 0.0
	else:
		_drive(delta)

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


## Ajusta a velocidade ao que a pista permite: o carro da frente na mesma
## faixa e o que decide, e e isso que impede dois carros de ocuparem o mesmo
## metro de asfalto.
func _drive(delta: float) -> void:
	var want := cruise_speed

	var gap: float = world_tuning.traffic_follow_gap if world_tuning != null else FOLLOW_GAP
	_probe_in -= 1
	if _probe_in <= 0:
		_probe_in = PROBE_EVERY
		_gap_cache = _gap_ahead(gap)
	else:
		_gap_cache -= speed * delta
	want = minf(want, _approach_speed(_gap_cache - gap))

	var accel: float = world_tuning.traffic_accel if world_tuning != null else ACCEL
	var rate := accel if want > speed else _brake()
	speed = move_toward(speed, maxf(want, 0.0), rate * delta)


func _brake() -> float:
	return world_tuning.traffic_brake if world_tuning != null else BRAKE


## Velocidade maxima pra ainda parar em `distance` metros freando no talo.
func _approach_speed(distance: float) -> float:
	return sqrt(2.0 * _brake() * maxf(distance, 0.0))


## Pista livre a frente na faixa deste carro.
func _gap_ahead(follow_gap: float) -> float:
	if world == null or not world.has_method("path_clearance"):
		return INF
	return world.path_clearance(offset, follow_gap + 24.0, lateral, self)


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
func recycle(
	a_offset: float, a_lateral: float, a_parked: bool = false, a_opens_door: bool = false
) -> void:
	_reset_at(a_offset, a_lateral, a_parked, a_opens_door)


## Estado comum entre nascer e ser reciclado.
func _reset_at(a_offset: float, a_lateral: float, a_parked: bool, a_opens_door: bool) -> void:
	offset = a_offset
	lateral = a_lateral
	_target_lateral = a_lateral
	parked = a_parked
	# Transito de marginal em hora de pico: quase parado, e ai que ta a graca.
	# Encostado e parado de verdade - zero, nao "quase".
	if a_parked:
		cruise_speed = 0.0
	else:
		cruise_speed = _rng.randf_range(
			0.0, world_tuning.traffic_speed if world_tuning != null else 7.0
		)
	speed = cruise_speed
	_gap_cache = INF
	_opens_door = a_parked and a_opens_door
	near_missed = false
	_set_door(false)
	_place_door(-1 if _rng.randf() < 0.5 else 1)
	_door_timer = _rng.randf_range(6.0, 30.0)
	_apply_transform()
