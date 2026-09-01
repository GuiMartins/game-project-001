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
## Semaforos em ordem de offset. Geometria fixa da pista, nao entram na
## reciclagem do transito.
var lights: Array[TrafficLight] = []
## Atalhos abertos nesta rota, em ordem de boca.
var branches: Array[RouteBranch] = []

## Quantos engarrafamentos se formaram nesta corrida. Existe pro banco de
## provas: "o engarrafamento parou de nascer" e o tipo de regressao que passa
## despercebida porque o jogo continua rodando lindamente sem ele.
var jams_formed: int = 0

var _rng := RandomNumberGenerator.new()
var _spawn_cursor: float = 0.0
## Offset do jogador a partir do qual o proximo engarrafamento se forma.
var _jam_due: float = 0.0
## Trecho ocupado pelo engarrafamento ativo, pra o reciclador nao soltar carro
## dentro dele.
var _jam_from: float = 0.0
var _jam_to: float = 0.0
## Atalho em que o jogador esta agora, ou null se ele esta na avenida.
var _on_branch: RouteBranch = null
## Progresso do frame passado, pra saber quando a boca de um atalho ficou pra
## tras. Comparar posicao com posicao perderia a boca em qualquer frame em que
## a moto andasse mais que a largura dela.
var _last_progress: float = 0.0

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
		# No atalho nao ha frota pra consultar, e os offsets sao de outra curva.
		if _on_branch != null:
			return preferred
		return free_lateral(at_offset, preferred, 30.0, player)

	camera = ChaseCamera.new()
	camera.name = "Camera"
	add_child(camera)
	camera.setup(tuning, player)
	camera.current = true

	_build_lights()
	_build_branches()
	_spawn_traffic()
	_spawn_rivals()
	_arm_jam()
	_last_progress = player.track_offset

	run.start(track.length - 30.0)


func restart() -> void:
	for car in traffic:
		car.queue_free()
	traffic.clear()
	for rival in rivals:
		rival.queue_free()
	rivals.clear()

	_on_branch = null
	player.setup(tuning, track, 12.0)
	player.speed = 0.0
	player.adrenaline = 0.0
	player.state = PlayerBike.State.RIDING
	_spawn_cursor = 0.0
	# Semaforo e sorteado junto com a pista, entao o R e a unica hora em que os
	# sliders de espacamento tem como valer.
	_build_lights()
	_build_branches()
	_spawn_traffic()
	_spawn_rivals()
	_arm_jam()
	_last_progress = player.track_offset
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


## Espalha semaforos pela rota inteira.
##
## De uma vez, na construcao: sao poucas dezenas de nos estaticos na pista de
## 3200 m, e reciclar semaforo como se recicla carro faria o mesmo cruzamento
## mudar de fase toda vez que o jogador voltasse a olhar pra ele.
func _build_lights() -> void:
	for light in lights:
		light.queue_free()
	lights.clear()

	var gap_max := maxf(world_tuning.light_gap_min, world_tuning.light_gap_max)
	var o := _rng.randf_range(world_tuning.light_gap_min, gap_max)
	while o < track.length - 80.0:
		var light := TrafficLight.new()
		light.name = "Light%d" % lights.size()
		add_child(light)
		light.setup(track, o, world_tuning, _rng.randi())
		lights.append(light)
		o += _rng.randf_range(world_tuning.light_gap_min, gap_max)


## Proximo semaforo a frente de `from_offset`, ou null se a rota acabou.
##
## Varredura linear numa lista de algumas dezenas, chamada por carro por frame.
## Um indice por carro seria mais rapido no papel e mais caro de manter: o
## carro e reciclado pra frente e pra tras o tempo todo.
func light_ahead(from_offset: float) -> TrafficLight:
	for light in lights:
		if light.offset >= from_offset:
			return light
	return null


## Abre atalhos onde a avenida faz volta grande.
##
## Procura, e nao autora: varre a rota atras de trechos em que a corda entre
## duas pontas e bem mais curta que a pista entre elas - que e a definicao
## geometrica de "aqui daria pra cortar". Onde a avenida ja e reta nao existe
## atalho, e insistir criaria uma rua paralela que nao economiza nada.
func _build_branches() -> void:
	for branch in branches:
		branch.road.queue_free()
	branches.clear()

	var cursor := 220.0
	while branches.size() < world_tuning.branch_count and cursor < track.length - 460.0:
		var span := _rng.randf_range(170.0, 340.0)
		var from_offset := cursor
		var to_offset := from_offset + span
		var chord := track.sample_position(from_offset).distance_to(
			track.sample_position(to_offset))
		# 14% de economia e o piso do que o jogador SENTE. Abaixo disso o
		# atalho e so uma rua diferente com o mesmo custo, e a escolha vira
		# decoracao.
		if chord > span * 0.86:
			cursor += 40.0
			continue

		var branch := _make_branch(from_offset, to_offset)
		if branch == null:
			cursor += 40.0
			continue
		branches.append(branch)
		cursor = to_offset + _rng.randf_range(240.0, 520.0)


func _make_branch(from_offset: float, to_offset: float) -> RouteBranch:
	var road := RoadTrack.new()
	road.name = "Shortcut%d" % branches.size()
	add_child(road)
	road.build_shortcut(track, from_offset, to_offset)

	# A corda pode sair mais longa que a promessa depois de virar curva de
	# verdade. Atalho que nao encurta e armadilha, entao ele nao nasce.
	if road.length > (to_offset - from_offset) * 0.93:
		road.queue_free()
		return null

	var branch := RouteBranch.new()
	branch.road = road
	branch.from_offset = from_offset
	branch.to_offset = to_offset
	# De que lado a boca abre: onde o meio do atalho cai em relacao ao eixo da
	# avenida. E o lado que o jogador precisa estar pra entrar.
	var middle := road.sample_position(road.length * 0.5)
	var on_main := track.project(middle, (from_offset + to_offset) * 0.5)
	branch.side = signf(on_main.y)
	if is_zero_approx(branch.side):
		branch.side = 1.0

	_build_fork_marks(branch)
	_litter_branch(branch)
	return branch


## Aviso na pista antes da boca: placa no lado que o atalho sai e chevrons
## pintados no asfalto.
##
## A 320x180 e a 180 km/h, uma bifurcacao sem aviso e uma bifurcacao que voce
## so descobre depois de ter passado dela. O aviso nao entrega o atalho de
## graca - so diz que ha uma escolha chegando, e de que lado ela e.
func _build_fork_marks(branch: RouteBranch) -> void:
	var lane := RoadTrack.lane_center(RoadTrack.LANE_COUNT - 1 if branch.side > 0.0 else 0)

	# Penduradas na pista do atalho, e nao no mundo: no R o atalho e refeito, e
	# marca orfa fica apontando pra uma boca que nao existe mais.
	for i in range(3):
		var at := branch.from_offset - 42.0 + float(i) * 14.0
		var chevron := Greybox.box(Vector3(2.4, 0.05, 1.1), Color(0.95, 0.78, 0.25))
		branch.road.add_child(chevron)
		chevron.global_transform = track.transform_at(at, lane)
		chevron.global_position += Vector3.UP * 0.05

	var post := Greybox.box(Vector3(0.24, 3.2, 0.24), Color(0.55, 0.54, 0.5))
	branch.road.add_child(post)
	post.global_position = track.point(branch.from_offset - 30.0,
		(RoadTrack.sidewalk_limit() + 0.7) * branch.side) + Vector3.UP * 1.6

	var panel := Greybox.box(Vector3(2.2, 1.3, 0.14), Color(0.95, 0.78, 0.25), true)
	branch.road.add_child(panel)
	panel.global_transform = track.transform_at(branch.from_offset - 30.0,
		(RoadTrack.sidewalk_limit() + 0.7) * branch.side)
	panel.global_position += Vector3.UP * 3.6


## Larga carros parados dentro do atalho.
##
## Eles nao entram na frota reciclada de proposito: sao obstaculos fixos da
## rua, e nao transito. Ficam onde estao, inclusive quando o jogador passa por
## ali pela segunda vez.
func _litter_branch(branch: RouteBranch) -> void:
	var usable := branch.road.length - 60.0
	if usable <= 0.0:
		return
	for i in range(world_tuning.branch_obstacles):
		var car := TrafficCar.new()
		branch.road.add_child(car)
		car.setup(branch.road, 30.0 + _rng.randf() * usable, _pick_lane(),
			_rng.randi(), true, _rng.randf() < world_tuning.door_chance)


## Onde o jogador esta NA ROTA, sempre em metros da avenida.
##
## Dentro do atalho o offset da moto e medido na curva do atalho, que comeca em
## zero e nao tem nada a ver com a quilometragem da entrega. Tudo que fala de
## progresso - cronometro, reciclagem do transito, engarrafamento - pergunta
## aqui, e nao pro jogador.
func player_progress() -> float:
	if _on_branch == null:
		return player.track_offset
	return _on_branch.progress_at(player.track_offset)


## O jogador esta na avenida, e nao cortando caminho?
func player_on_route() -> bool:
	return _on_branch == null


## Decide em que pista a moto esta. Roda antes de qualquer coisa que use
## progresso, senao o frame da troca conta duas vezes ou nenhuma.
func _update_route() -> void:
	# O banco de provas mede a moto com os limites da pista desligados: nesse
	# modo ela atravessa a boca de qualquer bifurcacao de lado, sem ter
	# escolhido entrar, e a medida sairia da geometria do atalho.
	if not player.road_bounds_enabled:
		return

	if _on_branch != null:
		# Chegou no fim do atalho: a curva termina encostada na avenida, entao
		# a volta e so trocar a referencia - a moto nao se mexe.
		if player.track_offset >= _on_branch.road.length - 1.0:
			var back := _on_branch.to_offset
			_on_branch = null
			player.switch_track(track, back)
			event_logged.emit("de volta na avenida", Color(0.7, 0.9, 1.0))
	else:
		var progress := player_progress()
		for branch in branches:
			if _last_progress >= branch.from_offset or progress < branch.from_offset:
				continue
			# Cruzou a boca: entra quem estava do lado dela. Quem passou pelo
			# meio ou pelo outro lado segue na avenida sem nem perceber.
			if signf(player.track_lateral) == branch.side \
					and absf(player.track_lateral) >= world_tuning.fork_commit:
				_on_branch = branch
				player.switch_track(branch.road,
					maxf(player.track_offset - branch.from_offset, 0.0))
				event_logged.emit("atalho: -%.0f m" % branch.saving(),
					Color(1.0, 0.85, 0.4))
			break

	_last_progress = player_progress()


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

	_update_route()
	run.tick(delta, player_progress())
	_sync_traffic_pool()
	_maybe_jam()
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
		arriving.world = self
		arriving.world_tuning = world_tuning
		add_child(arriving)
		arriving.setup(track, 0.0, 0.0, _rng.randi())
		# Entra pela frente, fora de vista - carro que aparece do nada no meio
		# da tela e carro que o jogador nao teve chance de desviar.
		_place_car(arriving, player_progress() + world_tuning.traffic_ahead)
		traffic.append(arriving)


func _recycle_traffic() -> void:
	var progress := player_progress()
	var front := progress + world_tuning.traffic_ahead
	for car in traffic:
		if car.offset < progress - world_tuning.traffic_behind:
			_place_car(car, _clear_of_jam(front + _rng.randf_range(0.0, 14.0)))


## --- Engarrafamento -------------------------------------------------------

## Marca daqui a quantos metros a pista trava de novo.
func _arm_jam() -> void:
	_jam_from = 0.0
	_jam_to = 0.0
	jams_formed = 0
	_jam_due = player_progress() + _rng.randf_range(
		world_tuning.jam_gap_min,
		maxf(world_tuning.jam_gap_min, world_tuning.jam_gap_max))


func _maybe_jam() -> void:
	if player_progress() < _jam_due:
		return
	_form_jam()
	_jam_due = player_progress() + _rng.randf_range(
		world_tuning.jam_gap_min,
		maxf(world_tuning.jam_gap_min, world_tuning.jam_gap_max))


## Trava um trecho da pista: fileiras cheias, as quatro faixas ocupadas.
##
## O engarrafamento e o oposto do semaforo. La sobra sempre uma faixa vazia,
## porque a fila e temporaria e o jogador nao escolheu estar nela; aqui a pista
## acaba de verdade e a unica passagem e o vao entre as filas. E a hora em que
## o jogo cobra o pilar: ou voce entra no corredor, ou voce anda a 5 km/h atras
## de um Corolla.
##
## Os carros nao sao criados: sao os que ja estavam mais longe a frente, que a
## neblina esconde. Assim o engarrafamento nasce montado, fora de vista, em vez
## de aparecer fileira por fileira na cara do jogador.
func _form_jam() -> void:
	var rows := int(float(traffic.size()) * world_tuning.jam_share) / RoadTrack.LANE_COUNT
	if rows < 1:
		return

	var progress := player_progress()
	var pool: Array[TrafficCar] = []
	for car in traffic:
		# So carro que ja esta na janela do jogador. O banco de provas estaciona
		# a frota inteira a 9 km daqui pra medir a moto isolada, e arrastar ela
		# de volta faria um engarrafamento nascer no meio da medicao.
		if car.offset <= progress + world_tuning.traffic_ahead * 1.5:
			pool.append(car)
	pool.sort_custom(func(a: TrafficCar, b: TrafficCar) -> bool: return a.offset > b.offset)

	_jam_from = progress + world_tuning.traffic_ahead
	_jam_to = _jam_from + float(rows - 1) * world_tuning.jam_row_gap

	jams_formed += 1
	var i := 0
	for row in range(rows):
		for lane in range(RoadTrack.LANE_COUNT):
			if i >= pool.size():
				return
			var car: TrafficCar = pool[i]
			i += 1
			# Fileira nao e regua: o desalinho e o que faz a fila parecer
			# transito em vez de estacionamento pintado no chao. Lateral mexe
			# pouco de proposito - e ela que decide se o vao ainda cabe a moto.
			car.jam_at(
				_jam_from + float(row) * world_tuning.jam_row_gap + _rng.randf_range(-1.1, 1.1),
				RoadTrack.lane_center(lane) + _rng.randf_range(-0.25, 0.25))


## Empurra um carro reciclado pra fora do engarrafamento ativo.
##
## O reciclador solta carro sempre no mesmo ponto la na frente, que e
## exatamente onde o engarrafamento acabou de se formar. Sem isto, carro novo
## nasce atravessado dentro da fila.
func _clear_of_jam(at_offset: float) -> float:
	if _jam_to <= player_progress():
		return at_offset
	if at_offset < _jam_from - 10.0 or at_offset > _jam_to + 10.0:
		return at_offset
	return _jam_to + 10.0 + _rng.randf_range(0.0, 14.0)


## Raspada no corredor: passar rente a um carro parado, rapido.
##
## Este e o pilar que o tema entrega de graca. A pontuacao existe pra medir se
## o jogador esta sendo puxado pra dentro do transito - se ele so anda pela
## faixa vazia, o jogo nao esta funcionando.
func _score_corridor() -> void:
	if player.state != PlayerBike.State.RIDING or player.speed < NEAR_MISS_MIN_SPEED:
		return
	# Dentro do atalho a moto corre por outra curva: o transito da avenida esta
	# a dezenas de metros dali, mas os offsets ainda se parecem. Sem esta
	# guarda o jogador ganharia raspada em carro que nao chegou a ver.
	if _on_branch != null:
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
func path_clearance(from_offset: float, span: float, lateral: float,
		exclude: Node = null) -> float:
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
func free_lateral(from_offset: float, preferred: float, span: float = 45.0, asker: Node = null) -> float:
	var best := preferred
	var best_score := -INF
	for lane in range(RoadTrack.LANE_COUNT):
		for i in range(2):
			var candidate := RoadTrack.lane_center(lane) if i == 0 else RoadTrack.corridor_center(lane)
			if absf(candidate) > RoadTrack.half_width() - 0.8:
				continue
			# Pista livre manda; mudar de faixa custa pouco, mas custa.
			var score := path_clearance(from_offset, span, candidate, asker) - absf(candidate - preferred) * 0.6
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
