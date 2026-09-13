class_name RivalBike
extends AnimatableBody3D
## Motoboy rival. Parametrico na curva, igual ao transito - so o jogador roda
## fisica de verdade.
##
## Ele prova dois pilares ao mesmo tempo. O combate lateral: encostar, socar, e
## principalmente ser socado pra dentro de um carro parado. E a corrida: ele
## tem ritmo proprio, ultrapassa o transito e cruza a linha de chegada com
## tempo registrado. Rival que so acompanha o jogador nao e adversario, e
## cenario que anda junto.

signal went_down
signal hit_player

enum State { RACING, STAGGERED, DOWN }

## O que o rival tenta fazer enquanto esta de pe.
##
## Separado de `State` de proposito: cair e levantar acontece por cima de
## qualquer intencao, e misturar os dois faria "cair atacando" precisar de um
## estado proprio. FOLLOW segue a pista, OVERTAKE abre caminho quando a frente
## fecha, ATTACK briga com quem esta emparelhado.
enum Mode { FOLLOW, OVERTAKE, ATTACK }

const SIZE := Vector3(0.75, 1.75, 2.1)

var track: RoadTrack
var tuning: BikeTuning
var world_tuning: WorldTuning
var world: Node  ## Quem sabe onde estao os carros parados.
var player: PlayerBike

var offset: float = 0.0
var lateral: float = 0.0
var speed: float = 0.0
var state: State = State.RACING
var mode: Mode = Mode.FOLLOW
var state_timer: float = 0.0
var bag_color: Color = Color(0.3, 0.8, 0.4)
## Fracao do teto de velocidade que ele busca por conta propria. E o que
## transforma quatro rivais iguais num pelotao com ordem de chegada.
var pace: float = 0.65
var finish_offset: float = INF  ## Onde a linha de chegada esta, em metros.
var finish_time: float = -1.0  ## Segundos ate cruzar, -1 enquanto corre.
var race_time: float = 0.0

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


func setup(
	a_track: RoadTrack,
	a_tuning: BikeTuning,
	a_world_tuning: WorldTuning,
	a_world: Node,
	a_player: PlayerBike,
	color: Color,
	seed_value: int
) -> void:
	track = a_track
	tuning = a_tuning
	world_tuning = a_world_tuning
	world = a_world
	player = a_player
	bag_color = color
	_rng.seed = seed_value
	var bag: Node = _visual.get_node_or_null("Bag")
	if bag is MeshInstance3D:
		(bag as MeshInstance3D).material_override = Greybox.material(color)


## Poe o rival na largada e zera a corrida dele.
##
## Ritmo e agressividade sao sorteados AQUI, e nao no setup, pra o slider do F3
## valer na proxima largada: o pelotao e o que se ajusta entre uma corrida e
## outra, e ter que reabrir o jogo pra testar um numero mata a iteracao.
func reset_race(at_offset: float, at_lateral: float, a_finish_offset: float) -> void:
	offset = at_offset
	lateral = at_lateral
	_target_lateral = at_lateral
	finish_offset = a_finish_offset
	finish_time = -1.0
	race_time = 0.0
	state = State.RACING
	mode = Mode.FOLLOW
	state_timer = 0.0
	_punch_timer = -1.0
	_punch_cooldown = 0.0
	_hitbox.monitoring = false
	_lean = 0.0
	pace = _rng.randf_range(world_tuning.rival_pace_min, world_tuning.rival_pace_max)
	speed = tuning.max_speed * pace * 0.6
	_aggression = _rng.randf_range(0.35, 0.95)
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
				# Levanta abaixo do proprio ritmo: a queda tem que custar
				# posicao, senao derrubar rival vira so um efeito bonito.
				speed = tuning.max_speed * pace * 0.6
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
	if finish_time >= 0.0:
		_coast_out(delta)
		return

	# Progresso do jogador na AVENIDA, e nao o offset cru dele: quando ele
	# corta por um atalho, o offset passa a ser medido numa curva que o rival
	# nem conhece, e o rubber band perseguiria um numero sem sentido.
	var duel: bool = world.player_on_route() if world.has_method("player_on_route") else true
	var player_at: float = (
		world.player_progress() if world.has_method("player_progress") else player.track_offset
	)
	var gap := player_at - offset

	mode = _pick_mode(duel, gap)

	# Ritmo proprio primeiro, rubber band por cima.
	#
	# O ritmo e o que faz disto uma corrida: sem ele o rival so acompanha o
	# jogador, ninguem ganha nem perde, e a ordem de chegada e sempre a mesma.
	# O band existe pra o pelotao nao sumir de vista - e por isso ele e
	# assimetrico, puxando quem ficou pra tras (+12 m/s) com mais forca do que
	# segura quem abriu (-6 m/s). Segurar o lider tanto quanto se empurra o
	# lanterna e o que faz o jogador sentir que a corrida esta encenada.
	var pace_speed := tuning.max_speed * pace
	if mode == Mode.OVERTAKE:
		pace_speed *= 1.06  # o arranque de quem esta saindo de tras do carro
	var band := clampf(gap * world_tuning.rival_rubber_band, -6.0, 12.0)
	var target_speed := clampf(pace_speed + band, tuning.max_speed * 0.35, tuning.max_speed * 1.08)
	speed = move_toward(speed, target_speed, 18.0 * delta)

	# Pra onde ir depende da intencao, mas o filtro do transito vale pra todas:
	# rival que entra debaixo de um carro parado pra brigar nao e agressivo, e
	# quebrado.
	var want := _target_lateral
	var span := 20.0 + speed * 0.6
	match mode:
		Mode.ATTACK:
			want = _alongside_lateral()
		Mode.OVERTAKE:
			# Janela maior: a decisao de mudar de faixa precisa sair antes de o
			# carro da frente virar parede.
			want = lateral
			span = 26.0 + speed * 0.9
		Mode.FOLLOW:
			want = _target_lateral
			# Rival agressivo perto do jogador vai BUSCAR briga, mesmo sem estar
			# emparelhado ainda. Sem isto ele corre a corrida inteira na faixa
			# dele e o combate lateral - que e um pilar - so acontece por acaso,
			# quando as duas rotas se cruzam sozinhas.
			if duel and absf(gap) < 12.0 and _aggression > 0.5:
				want = _alongside_lateral()
	if world.has_method("free_lateral"):
		want = world.free_lateral(offset, want, span, self)
	_target_lateral = clampf(want, -RoadTrack.half_width() + 1.0, RoadTrack.half_width() - 1.0)

	var move := _target_lateral - lateral
	var lateral_speed := clampf(move * 3.0, -9.0, 9.0)
	lateral += lateral_speed * delta
	_lean = lerpf(
		_lean,
		clampf(-lateral_speed / 9.0, -1.0, 1.0) * deg_to_rad(tuning.max_lean),
		1.0 - exp(-8.0 * delta)
	)

	if mode == Mode.ATTACK and _punch_cooldown <= 0.0:
		var side_gap := player.track_lateral - lateral
		if absf(side_gap) < tuning.punch_range + 1.0 and _rng.randf() < _aggression:
			_punch_side = int(signf(side_gap))
			_punch_timer = tuning.punch_cooldown
			_punch_cooldown = tuning.punch_cooldown / maxf(_aggression, 0.2)


## Lateral pra encostar no jogador: do lado em que ja esta, a uma distancia que
## o quanto mais agressivo, menor. Colar exatamente na lateral dele seria entrar
## por dentro da moto, e o que se quer e emparelhar.
func _alongside_lateral() -> float:
	var side := signf(lateral - player.track_lateral)
	if is_zero_approx(side):
		side = 1.0
	return player.track_lateral + side * 1.7 * (1.0 - _aggression)


## Decide a intencao do frame: brigar, ultrapassar ou so seguir.
##
## Emparelhar so faz sentido com os dois na mesma pista - fora disso o rival
## corre a corrida dele.
func _pick_mode(duel: bool, gap: float) -> Mode:
	if duel and absf(gap) < 2.6:
		if absf(player.track_lateral - lateral) < tuning.punch_range + 1.5:
			return Mode.ATTACK
	var span := 20.0 + speed * 0.9
	if world.has_method("path_clearance"):
		# Dois tercos da janela livre e o gatilho: esperar a faixa fechar de
		# vez faz o rival frear atras do carro em vez de contornar, e rival que
		# freia no transito nunca mais alcanca o pelotao.
		if world.path_clearance(offset, span, lateral, self) < span * 0.65:
			return Mode.OVERTAKE
	return Mode.FOLLOW


## Depois da linha de chegada, sai da pista e para.
##
## Nao e enfeite: o resto do pelotao ainda esta correndo, e um rival parado no
## meio da faixa depois de ganhar a corrida vira parede pra quem vem atras.
func _coast_out(delta: float) -> void:
	mode = Mode.FOLLOW
	speed = move_toward(speed, 0.0, 14.0 * delta)
	var side := 1.0 if lateral >= 0.0 else -1.0
	_target_lateral = side * (RoadTrack.half_width() + RoadTrack.SHOULDER * 0.5)
	lateral = move_toward(lateral, _target_lateral, 6.0 * delta)
	_lean = lerpf(_lean, 0.0, 1.0 - exp(-6.0 * delta))


func _advance(delta: float) -> void:
	if finish_time < 0.0:
		race_time += delta
	offset += speed * delta
	# O tempo de chegada e o que ordena quem ja cruzou a linha. Sem ele, dois
	# rivais que terminaram ficariam empatados pelo offset e a ordem de chegada
	# passaria a depender da ordem da lista.
	if finish_time < 0.0 and offset >= finish_offset:
		finish_time = race_time
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
	var active := (
		elapsed >= tuning.punch_windup and elapsed < tuning.punch_windup + tuning.punch_active
	)
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
