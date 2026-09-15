class_name World
extends Node3D
## Monta o mundo e arbitra as regras que precisam ver todo mundo ao mesmo
## tempo: colocacao na corrida, raspada no corredor, socos que acertaram,
## reciclagem do transito.

signal run_finished
signal event_logged(text: String, color: Color)

const ROUTE_LENGTH: float = 3200.0

## Metros antes do fim da curva onde a linha de chegada fica. A curva termina
## com as tangentes suavizadas num ponto so, e chegar exatamente nele poria a
## moto num trecho onde a amostragem ja esta grampeada.
const FINISH_MARGIN: float = 30.0

## Cor da bag de cada rival. E o unico jeito de distinguir um do outro no
## greybox - e ja e o plano de arte: mesmo rig, paleta trocada.
const RIVAL_COLORS: Array[Color] = [
	Color(0.25, 0.85, 0.45),
	Color(0.95, 0.85, 0.2),
	Color(0.6, 0.35, 0.95),
	Color(0.2, 0.75, 0.95),
	Color(0.95, 0.35, 0.45),
]

## Quanto tempo a HUD fica sem anunciar outra mudanca de posicao, em segundos.
## Dois corredores emparelhados trocam de lugar varias vezes por segundo, e sem
## isto o aviso vira estroboscopio em cima da pista.
const POSITION_EVENT_COOLDOWN: float = 1.2

## Distancia lateral (centro a centro) que ainda conta como raspada.
const NEAR_MISS_LATERAL: float = 2.6
## Piso da janela: meia largura do carro (0.90) + meia largura da moto (0.38).
## Abaixo disso nao foi raspada, foi batida - e batida ja tem o proprio efeito.
const NEAR_MISS_MIN_LATERAL: float = 1.30
## Abaixo desta velocidade passar entre carros nao e coragem, e manobra.
const NEAR_MISS_MIN_SPEED: float = 17.0

var tuning: BikeTuning
var world_tuning: WorldTuning
var track: RoadTrack
var player: PlayerBike
var camera: ChaseCamera
var run := RaceRun.new()

var traffic: Array[TrafficCar] = []
var rivals: Array[RivalBike] = []
var _rng := RandomNumberGenerator.new()
var _spawn_cursor: float = 0.0
var _position_event_timer: float = 0.0


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
	_sync_rival_pool()
	start_race()


func restart() -> void:
	# A frota de rivais so se reconcilia entre corridas: rival tem estado de IA,
	# e trocar o pelotao no meio faria o placar mentir.
	_sync_rival_pool()
	start_race()
	event_logged.emit("nova corrida", Color(0.7, 0.9, 1.0))


## Larga a corrida com o grid comecando em `grid_offset` metros de rota.
##
## O grid tem endereco proprio porque o banco de provas precisa largar perto da
## linha de chegada pra medir a chegada sem pagar os 3 km inteiros - e medir a
## chegada e o unico jeito de saber se a ordem de chegada existe.
func start_race(grid_offset: float = 0.0, at_speed: float = 0.0) -> void:
	run.start(track.length - FINISH_MARGIN, rivals.size() + 1)
	var slot := grid_slot(rivals.size(), grid_offset)
	player.place_on_track(slot.x, slot.y, at_speed)
	player.adrenaline = 0.0
	for i in rivals.size():
		var rival_slot := grid_slot(i, grid_offset)
		rivals[i].reset_race(rival_slot.x, rival_slot.y, run.distance_total)
	_position_event_timer = 0.0
	scatter_traffic_ahead(player.track_offset)


## Onde o corredor `index` larga: fila dupla, corredores alternados, o de
## indice mais alto no fundo do grid.
##
## O jogador recebe sempre o ULTIMO indice, ou seja, larga em ultimo. E de
## proposito: numa corrida em que voce ja comeca na frente, a primeira coisa
## que o jogo ensina e que a posicao nao depende de voce.
func grid_slot(index: int, base: float) -> Vector2:
	var row := index / 2
	var column := index % 2
	var forward := base + 26.0 - float(row) * 7.0
	return Vector2(maxf(forward, 4.0), RoadTrack.corridor_center(0 if column == 0 else 2))


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
		var at := track.point(o, edge * side + 0.8 * side) + Vector3.UP * 3.0
		o += _rng.randf_range(18.0, 34.0)
		var pole := StaticBody3D.new()
		pole.collision_layer = Layers.WORLD
		pole.collision_mask = 0
		var pole_size := Vector3(0.35, 6.0, 0.35)
		pole.add_child(Greybox.box(pole_size, Color(0.62, 0.6, 0.55)))
		pole.add_child(Greybox.box_shape(pole_size))
		props.add_child(pole)
		pole.global_position = at

	o = 12.0
	while o < track.length:
		for side: float in [-1.0, 1.0]:
			if _rng.randf() < 0.35:
				continue
			var h := _rng.randf_range(6.0, 26.0)
			var w := _rng.randf_range(6.0, 14.0)
			var at := track.point(o, (edge + 6.0 + w * 0.5) * side) + Vector3.UP * (h * 0.5 - 1.0)
			var shade := _rng.randf_range(0.2, 0.42)
			var building := Greybox.box(Vector3(w, h, w), Color(shade, shade * 0.97, shade * 1.15))
			props.add_child(building)
			building.global_position = at
		o += _rng.randf_range(16.0, 30.0)


## Quanto o jogador ja andou da rota, em metros. E daqui que sai a colocacao -
## e por isso que rival e HUD perguntam a pista, e nao a moto.
func player_progress() -> float:
	return player.track_offset


## O jogador esta na avenida, e nao cortando caminho?
func player_on_route() -> bool:
	return true


func _spawn_traffic() -> void:
	for i in range(world_tuning.traffic_count):
		var car := TrafficCar.new()
		car.world = self
		car.world_tuning = world_tuning
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
			maxf(world_tuning.traffic_gap_min, world_tuning.traffic_gap_max)
		)


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
		car.recycle(
			at_offset, RoadTrack.lane_center(curb), true, _rng.randf() < world_tuning.door_chance
		)
	else:
		car.recycle(at_offset, _pick_lane(), false, false)


## Reconcilia a frota de rivais com o tuning, sem mexer em quem ja existe.
func _sync_rival_pool() -> void:
	while rivals.size() > world_tuning.rival_count:
		var leaving: RivalBike = rivals.pop_back()
		leaving.queue_free()
	while rivals.size() < world_tuning.rival_count:
		var rival := RivalBike.new()
		add_child(rival)
		rival.setup(
			track,
			tuning,
			world_tuning,
			self,
			player,
			RIVAL_COLORS[rivals.size() % RIVAL_COLORS.size()],
			_rng.randi()
		)
		rival.went_down.connect(_on_rival_down.bind(rival))
		rivals.append(rival)


## --- Regras que precisam da visao geral -----------------------------------


func _physics_process(delta: float) -> void:
	if player == null or track == null:
		return

	# A colocacao vem ANTES do tick: e o tick que pode cruzar a linha, e a
	# posicao que ele congelar no resultado tem que ser a deste frame.
	_position_event_timer = maxf(_position_event_timer - delta, 0.0)
	_update_standings()
	run.tick(delta, player_progress())
	_sync_traffic_pool()
	_recycle_traffic()
	_score_corridor()

	if run.phase != RaceRun.Phase.RACING:
		set_physics_process(false)
		run_finished.emit()


## Quem esta em que lugar.
##
## A chave de cada corredor mistura progresso e tempo de chegada num numero so
## (ver RaceRun.rank_key): sem ela, comparar quem ja cruzou a linha com quem
## ainda corre precisaria de dois casos em cada comparacao, e o empate entre
## dois que terminaram sairia pela ordem da lista.
func _update_standings() -> void:
	var keys: Array[float] = [RaceRun.rank_key(player_progress(), run.finish_time)]
	for rival in rivals:
		keys.append(RaceRun.rank_key(rival.offset, rival.finish_time))
	var moved := run.update_position(RaceRun.position_of(keys[0], keys))
	if moved == 0 or _position_event_timer > 0.0:
		return
	_position_event_timer = POSITION_EVENT_COOLDOWN
	if moved > 0:
		event_logged.emit("ultrapassou - %s" % run.position_text(), Color(0.6, 1.0, 0.6))
	else:
		event_logged.emit("perdeu posicao - %s" % run.position_text(), Color(1.0, 0.6, 0.4))


## Reconcilia o tamanho da frota com o tuning.
##
## Sem isto o slider de traffic_count so valeria no R, e ajustar densidade e
## exatamente o tipo de coisa que voce precisa sentir com a moto andando -
## que e a razao do painel F3 existir.
func _sync_traffic_pool() -> void:
	var want: int = world_tuning.traffic_count
	var flow: Array[TrafficCar] = traffic.duplicate()
	if flow.size() == want:
		return
	while flow.size() > want:
		var leaving: TrafficCar = flow.pop_back()
		traffic.erase(leaving)
		leaving.queue_free()
	while flow.size() < want:
		var arriving := TrafficCar.new()
		arriving.world = self
		arriving.world_tuning = world_tuning
		add_child(arriving)
		arriving.setup(track, 0.0, 0.0, _rng.randi())
		# Entra pela frente, fora de vista - carro que aparece do nada no meio
		# da tela e carro que o jogador nao teve chance de desviar.
		_place_car(arriving, player_progress() + world_tuning.traffic_ahead)
		traffic.append(arriving)
		flow.append(arriving)


func _recycle_traffic() -> void:
	var progress := player_progress()
	var front := progress + world_tuning.traffic_ahead
	for car in traffic:
		if car.offset < progress - world_tuning.traffic_behind:
			_place_car(car, front + _rng.randf_range(0.0, 14.0))


## Raspada: passar perto de um carro sem bater. E a metrica que diz se o
## corredor esta puxando o jogador pra dentro do transito - se ela cai a zero,
## o jogador esta fugindo do jogo em vez de joga-lo.
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
## `exclude` tira um carro da conta - e como o proprio carro pergunta quanta
## pista tem a frente sem se enxergar parado a zero metro de si mesmo.
func path_clearance(from_offset: float, span: float, lateral: float, exclude: Node = null) -> float:
	var nearest := span
	for car in traffic:
		if car == exclude:
			continue
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
func free_lateral(
	from_offset: float, preferred: float, span: float = 45.0, asker: Node = null
) -> float:
	var best := preferred
	var best_score := -INF
	for lane in range(RoadTrack.LANE_COUNT):
		for i in range(2):
			var candidate := (
				RoadTrack.lane_center(lane) if i == 0 else RoadTrack.corridor_center(lane)
			)
			if absf(candidate) > RoadTrack.half_width() - 0.8:
				continue
			# Pista livre manda; mudar de faixa custa pouco, mas custa.
			var score := (
				path_clearance(from_offset, span, candidate, asker)
				- absf(candidate - preferred) * 0.6
			)
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


## Um rival foi ao chao. So paga quem derrubou.
##
## Pagava sempre, e a conta de ficar PARADO na largada era esta: em dois
## segundos os cinco rivais se espatifavam sozinhos no transito, e o jogador
## terminava com a adrenalina cheia e 750 de estilo - um quinto da nota - sem
## ter acelerado. Derrubar rival e o pilar do combate, e pilar que acontece
## sozinho deixa de ser pilar.
##
## A queda alheia continua valendo o que sempre valeu de verdade: a posicao que
## ele perde, que e sua de graca. O que ela nao paga mais e estilo e boost - e o
## aviso cinza na HUD e o que diz ao jogador que a diferenca existe.
func _on_rival_down(pelo_jogador: bool, _rival: RivalBike) -> void:
	if not pelo_jogador:
		run.register_rival_fell()
		event_logged.emit("rival caiu sozinho", Color(0.62, 0.66, 0.74))
		return
	run.register_rival_down()
	player.add_adrenaline(20.0)
	event_logged.emit("rival no chao", Color(0.5, 1.0, 0.7))
