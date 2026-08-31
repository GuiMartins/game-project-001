extends AnimatableBody3D
class_name RivalBike
## Motoboy rival. Parametrico na curva, igual ao transito - so o jogador roda
## fisica de verdade.
##
## Ele existe pra provar o pilar do combate lateral: encostar, socar, e
## principalmente ser socado pra dentro de um carro parado. Se derrubar um
## rival num poste nao for satisfatorio, o combate nao esta pronto.

const SIZE := Vector3(0.75, 1.75, 2.1)

enum State { RACING, STAGGERED, DOWN }

var track: RoadTrack
var tuning: BikeTuning
var world: Node  ## Quem sabe onde estao os carros parados.
var player: PlayerBike

var offset: float = 0.0
var lateral: float = 0.0
var speed: float = 0.0
var state: State = State.RACING
var state_timer: float = 0.0
var bag_color: Color = Color(0.3, 0.8, 0.4)

var _target_lateral: float = 0.0
var _punch_cooldown: float = 0.0
var _punch_timer: float = -1.0
var _punch_side: int = 0
var _aggression: float = 0.5
var _rng := RandomNumberGenerator.new()
var _visual: Node3D
var _hitbox: Area3D
var _sensor: Area3D
var _lean: float = 0.0

signal went_down
signal hit_player


func _ready() -> void:
	sync_to_physics = true
	collision_layer = Layers.RIVAL
	collision_mask = 0

	add_child(Greybox.box_shape(SIZE))

	_visual = Node3D.new()
	add_child(_visual)
	var chassis := Greybox.box(Vector3(0.6, 0.75, SIZE.z), Color(0.28, 0.29, 0.35))
	chassis.position = Vector3(0.0, -0.5, 0.0)
	_visual.add_child(chassis)
	var rider := Greybox.box(Vector3(0.7, 1.0, 0.75), Color(0.62, 0.62, 0.66))
	rider.position = Vector3(0.0, 0.35, 0.2)
	_visual.add_child(rider)
	# Rivais se diferenciam so pela cor da bag - exatamente o plano de arte:
	# mesmo rig, paleta trocada.
	var bag := Greybox.box(Vector3(0.85, 0.8, 0.5), bag_color)
	bag.position = Vector3(0.0, 0.5, 0.72)
	bag.name = "Bag"
	_visual.add_child(bag)

	_hitbox = Area3D.new()
	_hitbox.collision_layer = Layers.RIVAL_HIT
	_hitbox.collision_mask = Layers.PLAYER
	_hitbox.monitoring = false
	_hitbox.add_child(Greybox.box_shape(Vector3(1.4, 1.0, 1.4)))
	add_child(_hitbox)

	# Sensor de acidente: se o rival encostar num carro parado, ele cai. E o
	# que transforma um soco bem colocado em vantagem de corrida.
	_sensor = Area3D.new()
	_sensor.collision_layer = 0
	_sensor.collision_mask = Layers.WORLD
	_sensor.add_child(Greybox.box_shape(SIZE * 0.9))
	add_child(_sensor)


func setup(a_track: RoadTrack, a_tuning: BikeTuning, a_world: Node, a_player: PlayerBike,
		start_offset: float, color: Color, seed_value: int) -> void:
	track = a_track
	tuning = a_tuning
	world = a_world
	player = a_player
	offset = start_offset
	bag_color = color
	_rng.seed = seed_value
	lateral = RoadTrack.corridor_center(_rng.randi_range(0, RoadTrack.LANE_COUNT - 2))
	_target_lateral = lateral
	speed = tuning.max_speed * 0.6
	_aggression = _rng.randf_range(0.35, 0.95)
	var bag: Node = _visual.get_node_or_null("Bag")
	if bag is MeshInstance3D:
		(bag as MeshInstance3D).material_override = Greybox.material(color)
	_apply_transform()


func _physics_process(delta: float) -> void:
	if track == null or player == null:
		return

	_update_hitbox(delta)
	_punch_cooldown = maxf(_punch_cooldown - delta, 0.0)

	match state:
		State.DOWN:
			state_timer -= delta
			speed = move_toward(speed, 0.0, 40.0 * delta)
			_visual.rotation = Vector3(0.0, 0.0, deg_to_rad(85.0))
			if state_timer <= 0.0:
				state = State.RACING
				speed = tuning.max_speed * 0.45
			_advance(delta)
			return
		State.STAGGERED:
			state_timer -= delta
			if state_timer <= 0.0:
				state = State.RACING
			_advance(delta)
			_check_wipeout()
			return
		State.RACING:
			_drive(delta)
			_advance(delta)
			_check_wipeout()


func _drive(delta: float) -> void:
	var gap := player.track_offset - offset

	# Rubber band: o rival persegue o jogador em vez de correr sozinho. Num
	# prototipo de combate, o rival tem que estar do lado - nao 200m na frente.
	var target_speed := player.speed + clampf(gap * 0.35, -10.0, 14.0)
	target_speed = clampf(target_speed, tuning.max_speed * 0.35, tuning.max_speed * 1.05)
	speed = move_toward(speed, target_speed, 18.0 * delta)

	# Escolhe um corredor livre, preferindo o do jogador quando esta perto o
	# bastante pra brigar.
	var want := _target_lateral
	if absf(gap) < 14.0:
		want = player.track_lateral + signf(lateral - player.track_lateral) * 1.7 * (1.0 - _aggression)
	if world.has_method("free_lateral"):
		want = world.free_lateral(offset, want, 20.0 + speed * 0.6, self)
	_target_lateral = clampf(want, -RoadTrack.half_width() + 1.0, RoadTrack.half_width() - 1.0)

	var move := (_target_lateral - lateral)
	var lateral_speed := clampf(move * 3.0, -9.0, 9.0)
	lateral += lateral_speed * delta
	_lean = lerpf(_lean, clampf(-lateral_speed / 9.0, -1.0, 1.0) * deg_to_rad(tuning.max_lean), 1.0 - exp(-8.0 * delta))

	# Ataca quando esta emparelhado.
	if _punch_cooldown <= 0.0 and absf(gap) < 2.2:
		var side_gap := player.track_lateral - lateral
		if absf(side_gap) < tuning.punch_range + 1.0 and _rng.randf() < _aggression:
			_punch_side = int(signf(side_gap))
			_punch_timer = tuning.punch_cooldown
			_punch_cooldown = tuning.punch_cooldown / maxf(_aggression, 0.2)


func _advance(delta: float) -> void:
	offset += speed * delta
	_apply_transform()


func _apply_transform() -> void:
	var t := track.transform_at(offset, lateral)
	t.origin += t.basis.y * (SIZE.y * 0.5)
	global_transform = t
	if state != State.DOWN:
		_visual.rotation = Vector3(0.0, 0.0, -_lean)


func _update_hitbox(delta: float) -> void:
	if _punch_timer <= 0.0:
		return
	_punch_timer -= delta
	var elapsed := tuning.punch_cooldown - _punch_timer
	_hitbox.position = Vector3(tuning.punch_range * float(_punch_side), 0.0, 0.0)
	var active := elapsed >= tuning.punch_windup and elapsed < tuning.punch_windup + tuning.punch_active
	_hitbox.monitoring = active
	if not active:
		return
	for body: Node3D in _hitbox.get_overlapping_bodies():
		if body is PlayerBike:
			(body as PlayerBike).receive_hit(_punch_side, tuning.punch_shove, tuning.punch_stagger)
			hit_player.emit()
			_hitbox.monitoring = false
			return


func _check_wipeout() -> void:
	if state == State.DOWN:
		return
	if _sensor.get_overlapping_bodies().is_empty():
		return
	_go_down()


func _go_down() -> void:
	state = State.DOWN
	state_timer = 2.6
	_punch_timer = -1.0
	_hitbox.monitoring = false
	went_down.emit()


## Chamado quando o jogador acerta este rival.
func receive_hit(from_side: int, shove: float, stagger: float) -> void:
	if state == State.DOWN:
		return
	state = State.STAGGERED
	state_timer = stagger
	# O empurrao move o rival LATERALMENTE na pista. Se do outro lado tiver um
	# carro parado, ele vai direto pra dentro - esse e o combate do Road Rash.
	lateral += float(from_side) * shove * 0.14
	_target_lateral = lateral
	speed *= 0.85
	_lean = deg_to_rad(tuning.max_lean) * float(from_side) * 0.9
	_apply_transform()
	_check_wipeout()
