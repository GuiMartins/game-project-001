extends Node3D
class_name World
## Monta o mundo e arbitra as regras que precisam ver todo mundo ao mesmo
## tempo: raspada no corredor, socos que acertaram, reciclagem do transito.

const ROUTE_LENGTH: float = 3200.0

## Distancia lateral (centro a centro) que ainda conta como raspada.
const NEAR_MISS_LATERAL: float = 2.6
## Piso da janela: meia largura do carro (0.95) + meia largura da moto (0.38).
## Abaixo disso nao foi raspada, foi batida - e batida ja tem o proprio efeito.
const NEAR_MISS_MIN_LATERAL: float = 1.35
## Abaixo desta velocidade passar entre carros nao e coragem, e manobra.
const NEAR_MISS_MIN_SPEED: float = 17.0

var tuning: BikeTuning
var world_tuning: WorldTuning
var track: RoadTrack
var player: PlayerBike
var camera: ChaseCamera
var run := DeliveryRun.new()

var traffic: Array[TrafficCar] = []
var rivals: Array[RivalBike] = []

var _rng := RandomNumberGenerator.new()
var _spawn_cursor: float = 0.0

signal run_finished
signal event_logged(text: String, color: Color)


func setup(a_tuning: BikeTuning, a_world_tuning: WorldTuning, world_seed: int = 20260831) -> void:
	tuning = a_tuning
	world_tuning = a_world_tuning
	_rng.seed = world_seed

	_build_environment()

	track = RoadTrack.new()
	track.name = "Track"
	add_child(track)
	track.build(ROUTE_LENGTH, _rng)

	_build_scenery()

	player = PlayerBike.new()
	player.name = "Player"
	add_child(player)
	player.setup(tuning, track, 12.0)
	player.crashed.connect(_on_player_crashed)
	player.scraped.connect(_on_player_scraped)
	player.punch_landed.connect(_on_player_punch_landed)
	player.took_hit.connect(_on_player_took_hit)
	player.find_clear_lateral = func(at_offset: float, preferred: float) -> float:
		return free_lateral(at_offset, preferred, 30.0, player)

	camera = ChaseCamera.new()
	camera.name = "Camera"
	add_child(camera)
	camera.setup(tuning, player)
	camera.current = true

	_spawn_traffic()
	_spawn_rivals()

	run.start(track.length - 30.0)


func restart() -> void:
	for car in traffic:
		car.queue_free()
	traffic.clear()
	for rival in rivals:
		rival.queue_free()
	rivals.clear()

	player.setup(tuning, track, 12.0)
	player.speed = 0.0
	player.adrenaline = 0.0
	player.state = PlayerBike.State.RIDING
	_spawn_cursor = 0.0
	_spawn_traffic()
	_spawn_rivals()
	run.start(track.length - 30.0)
	event_logged.emit("nova corrida", Color(0.7, 0.9, 1.0))


## --- Construcao -----------------------------------------------------------

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.11, 0.12, 0.19)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.48, 0.62)
	env.ambient_light_energy = 1.05
	# Neblina segurando o horizonte: a 320x180 o fade e o que da profundidade,
	# e de quebra esconde o fim do mundo sem precisar de LOD.
	env.fog_enabled = true
	env.fog_light_color = Color(0.13, 0.14, 0.22)
	env.fog_density = 0.0045
	env.fog_sky_affect = 0.0

	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42.0, 38.0, 0.0)
	sun.light_energy = 1.1
	sun.light_color = Color(1.0, 0.94, 0.85)
	sun.shadow_enabled = false
	add_child(sun)


func _build_scenery() -> void:
	# Postes e predios sao o referencial de velocidade. Sem nada passando do
	# lado, 180 km/h e 60 km/h parecem a mesma coisa.
	var props := Node3D.new()
	props.name = "Scenery"
	add_child(props)

	var edge := RoadTrack.half_width() + RoadTrack.SHOULDER

	var o := 30.0
	while o < track.length - 10.0:
		var side := 1.0 if _rng.randf() < 0.5 else -1.0
		var pole := StaticBody3D.new()
		pole.collision_layer = Layers.WORLD
		pole.collision_mask = 0
		var pole_size := Vector3(0.35, 6.0, 0.35)
		pole.add_child(Greybox.box(pole_size, Color(0.62, 0.6, 0.55)))
		pole.add_child(Greybox.box_shape(pole_size))
		props.add_child(pole)
		pole.global_position = track.point(o, edge * side + 0.8 * side) + Vector3.UP * 3.0
		o += _rng.randf_range(18.0, 34.0)

	o = 12.0
	while o < track.length:
		for side: float in [-1.0, 1.0]:
			if _rng.randf() < 0.35:
				continue
			var h := _rng.randf_range(6.0, 26.0)
			var w := _rng.randf_range(6.0, 14.0)
			var shade := _rng.randf_range(0.2, 0.42)
			var building := Greybox.box(Vector3(w, h, w), Color(shade, shade * 0.97, shade * 1.15))
			props.add_child(building)
			building.global_position = track.point(o, (edge + 6.0 + w * 0.5) * side) + Vector3.UP * (h * 0.5 - 1.0)
		o += _rng.randf_range(16.0, 30.0)


func _spawn_traffic() -> void:
	for i in range(world_tuning.traffic_count):
		var car := TrafficCar.new()
		add_child(car)
		car.setup(track, 0.0, 0.0, _rng.randi())
		traffic.append(car)
	scatter_traffic_ahead(0.0)


## Espalha a frota inteira a frente de `from_offset` com o espacamento padrao.
## Usado no inicio da corrida e pelo banco de provas - o espacamento e o unico
## numero que decide se o corredor e passavel ou uma parede.
func scatter_traffic_ahead(from_offset: float) -> void:
	_spawn_cursor = from_offset + 60.0
	for car in traffic:
		_place_car(car, _spawn_cursor)
		_spawn_cursor += _rng.randf_range(
			world_tuning.traffic_gap_min,
			maxf(world_tuning.traffic_gap_min, world_tuning.traffic_gap_max))


func _pick_lane() -> float:
	return RoadTrack.lane_center(_rng.randi_range(0, RoadTrack.LANE_COUNT - 1))


## Sorteia como o carro entra: encostado no meio-fio ou no fluxo.
##
## So encostado abre porta - e nem todo encostado abre. Se encostar fosse
## sinonimo de porta, a faixa da ponta viraria regra decorada em vez de aposta,
## e o jogador aprenderia a nunca chegar perto em vez de calcular o risco.
func _place_car(car: TrafficCar, at_offset: float) -> void:
	if _rng.randf() < world_tuning.parked_chance:
		var curb := 0 if _rng.randf() < 0.5 else RoadTrack.LANE_COUNT - 1
		car.recycle(at_offset, RoadTrack.lane_center(curb), true,
			_rng.randf() < world_tuning.door_chance)
	else:
		car.recycle(at_offset, _pick_lane(), false, false)


func _spawn_rivals() -> void:
	const COLORS: Array[Color] = [
		Color(0.25, 0.85, 0.45),
		Color(0.95, 0.85, 0.2),
		Color(0.6, 0.35, 0.95),
		Color(0.2, 0.75, 0.95),
	]
	for i in range(world_tuning.rival_count):
		var rival := RivalBike.new()
		add_child(rival)
		rival.setup(track, tuning, self, player, 20.0 + float(i) * 9.0, COLORS[i % COLORS.size()], _rng.randi())
		rival.went_down.connect(_on_rival_down.bind(rival))
		rivals.append(rival)


## --- Regras que precisam da visao geral -----------------------------------

func _physics_process(delta: float) -> void:
	if player == null or track == null:
		return

	run.tick(delta, player.track_offset)
	_sync_traffic_pool()
	_recycle_traffic()
	_score_corridor()

	if run.phase != DeliveryRun.Phase.RIDING:
		set_physics_process(false)
		run_finished.emit()


## Reconcilia o tamanho da frota com o tuning.
##
## Sem isto o slider de traffic_count so valeria no R, e ajustar densidade e
## exatamente o tipo de coisa que voce precisa sentir com a moto andando -
## que e a razao do painel F3 existir.
func _sync_traffic_pool() -> void:
	var want: int = world_tuning.traffic_count
	if traffic.size() == want:
		return
	while traffic.size() > want:
		var leaving: TrafficCar = traffic.pop_back()
		leaving.queue_free()
	while traffic.size() < want:
		var arriving := TrafficCar.new()
		add_child(arriving)
		arriving.setup(track, 0.0, 0.0, _rng.randi())
		# Entra pela frente, fora de vista - carro que aparece do nada no meio
		# da tela e carro que o jogador nao teve chance de desviar.
		_place_car(arriving, player.track_offset + world_tuning.traffic_ahead)
		traffic.append(arriving)


func _recycle_traffic() -> void:
	var front := player.track_offset + world_tuning.traffic_ahead
	for car in traffic:
		if car.offset < player.track_offset - world_tuning.traffic_behind:
			_place_car(car, front + _rng.randf_range(0.0, 14.0))


## Raspada no corredor: passar rente a um carro parado, rapido.
##
## Este e o pilar que o tema entrega de graca. A pontuacao existe pra medir se
## o jogador esta sendo puxado pra dentro do transito - se ele so anda pela
## faixa vazia, o jogo nao esta funcionando.
func _score_corridor() -> void:
	if player.state != PlayerBike.State.RIDING or player.speed < NEAR_MISS_MIN_SPEED:
		return
	for car in traffic:
		var along := car.offset - player.track_offset
		if along < -9.0:
			car.near_missed = false
			continue
		if car.near_missed or absf(along) > 2.6:
			continue
		var side := absf(car.lateral - player.track_lateral)
		# Perto o bastante pra assustar, longe o bastante pra nao ser colisao.
		if side > NEAR_MISS_MIN_LATERAL and side < NEAR_MISS_LATERAL:
			car.near_missed = true
			run.register_near_miss()
			player.add_adrenaline(tuning.boost_gain_near_miss)


## Distancia livre a frente numa dada lateral, a partir de `from_offset`.
## Devolve `span` quando nao ha nada no caminho.
func path_clearance(from_offset: float, span: float, lateral: float) -> float:
	var nearest := span
	for car in traffic:
		var gap := car.offset - from_offset
		# -4 m atras: um carro emparelhado ainda bloqueia a faixa.
		if gap < -4.0 or gap > span:
			continue
		if absf(car.lateral - lateral) < 1.6:
			nearest = minf(nearest, maxf(gap, 0.0))
	return nearest


## Melhor lateral pra seguir: a que tem mais pista livre a frente, com desempate
## pela proximidade da lateral atual.
##
## Precisa varrer o INTERVALO inteiro ate `span`, e nao uma janela em volta de
## um ponto la na frente - um carro a 5 m de distancia nao pode ser invisivel
## so porque a IA esta olhando pra 38 m.
func free_lateral(from_offset: float, preferred: float, span: float = 45.0, _asker: Node = null) -> float:
	var best := preferred
	var best_score := -INF
	for lane in range(RoadTrack.LANE_COUNT):
		for i in range(2):
			var candidate := RoadTrack.lane_center(lane) if i == 0 else RoadTrack.corridor_center(lane)
			if absf(candidate) > RoadTrack.half_width() - 0.8:
				continue
			# Pista livre manda; mudar de faixa custa pouco, mas custa.
			var score := path_clearance(from_offset, span, candidate) - absf(candidate - preferred) * 0.6
			# Motoboy anda no corredor, nao na faixa. O bonus faz a IA jogar o
			# jogo que o tema pede, em vez de virar um carro de duas rodas.
			if i == 1:
				score += 3.0
			if score > best_score:
				best_score = score
				best = candidate
	return best


## --- Reacoes --------------------------------------------------------------

func _on_player_crashed(reason: String) -> void:
	run.register_crash()
	camera.add_shake(1.0)
	event_logged.emit("capotou: %s" % reason, Color(1.0, 0.4, 0.35))


func _on_player_scraped(intensity: float) -> void:
	run.register_scrape(intensity)
	camera.add_shake(clampf(intensity, 0.1, 0.5))


func _on_player_took_hit() -> void:
	run.register_hit_taken()
	camera.add_shake(0.5)
	event_logged.emit("tomou pancada", Color(1.0, 0.6, 0.3))


func _on_player_punch_landed(target: Node3D) -> void:
	if target is RivalBike:
		var rival := target as RivalBike
		var side := signf(rival.lateral - player.track_lateral)
		if is_zero_approx(side):
			side = 1.0
		rival.receive_hit(int(side), tuning.punch_shove, tuning.punch_stagger)
		event_logged.emit("acertou o rival", Color(0.6, 1.0, 0.6))
	else:
		event_logged.emit("socou lataria", Color(0.8, 0.8, 0.8))


func _on_rival_down(rival: RivalBike) -> void:
	run.register_rival_down()
	player.add_adrenaline(20.0)
	event_logged.emit("rival no chao", Color(0.5, 1.0, 0.7))
