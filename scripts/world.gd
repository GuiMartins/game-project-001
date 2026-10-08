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

## A semente do mundo. Fixa: pista, cenario, transito e rivais saem dela, e e o
## que faz o banco de provas medir a mesma corrida toda vez.
const SEMENTE: int = 20260831

## O LUT de cor do dia (`arte/paleta.py`), importado como `Texture3D`.
const LUT_DIA: Texture3D = preload("res://assets/visual/lut_dia.png")

## A cor de cada rival: bag e moto nela, jaqueta num tom escuro dela (ver
## `Entregador.pintar`). Todos sao o mesmo modelo, e e a cor que separa um do
## outro de longe. Nenhuma encosta no laranja do jogador (`PlayerBike.COR`).
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

## Folga lateral, da lataria ao centro da moto, que ainda conta como raspada.
## Com o carro de 1,8 m do greybox isso era 2,6 m centro a centro.
const NEAR_MISS_LATERAL: float = 1.70
## Piso da janela: meia largura da moto (0.38) e dois dedos. Abaixo disso nao
## foi raspada, foi batida - e batida ja tem o proprio efeito.
const NEAR_MISS_MIN_LATERAL: float = 0.40
## Quanto alem da ponta do carro a moto ainda conta como passando por ele.
const NEAR_MISS_ALONG: float = 0.40
## Folga minima, em metros, entre um carro trocando de faixa e quem ja esta na
## faixa de destino, mais 1,5 s da diferenca de velocidade: e o tempo da troca
## ate a lataria chegar na faixa nova.
const FOLGA_TROCA: float = 2.0
const FOLGA_TROCA_TEMPO: float = 1.5
## O carro do greybox: 4,4 x 1,8 m. As distancias de `path_clearance` - o vao
## de seguir (`traffic_follow_gap`), os 4 m de emparelhado e os 1,6 m de faixa
## - foram afinadas com ele. O que um modelo tem a mais ou a menos que isso
## entra como correcao, e a regra continua a mesma para o hatch e o onibus.
const MEIO_CARRO: float = 2.2
const MEIA_LARGURA_CARRO: float = 0.9
## Meia largura da moto, para a conta de quem pilota: rival e piloto
## automatico. Do `PlayerBike.SIZE`, o mesmo do `RivalBike`.
const MEIA_MOTO: float = 0.375
## Sobra minima entre a moto e a lataria para o corredor contar como aberto.
##
## Era um numero so, 1,6 m centro a centro, afinado para o carro de 1,8 m: com
## o corredor a 1,65 m do centro da faixa, sobravam 5 cm. Qualquer carro mais
## largo - o SUV com a moldura, 1,9 m - fechava o corredor na cabeca da IA, e
## rival que acha tudo fechado escolhe mal e bate: as quedas no transito
## dobraram sem onibus nenhum. 15 cm e a sobra que a moto de 0,75 m tem, de
## cada lado, entre um onibus e um seda.
const FOLGA_MOTO: float = 0.15
## Raio de curva para a margem dos carros compridos, em metros: o mais fechado
## que a pista faz em velocidade de corrida (o banco de provas mede 78 m no
## talo).
##
## O carro e uma caixa reta, e a pista curva: numa curva de raio R, a ponta de
## uma caixa de comprimento L sai L^2/8R da faixa - 3 cm no seda, 24 cm no
## onibus. Quem pensa em faixa, o rival, raspava na ponta do onibus achando
## que passava com folga. A margem entra na conta dele como largura a mais.
##
## Por que margem, e nao o colisor seguindo a curva: em gomos, a moto recebia
## varias colisoes do mesmo onibus por quadro, numa ordem que muda de sistema
## para sistema, e o banco de provas do Linux media outra corrida.
const RAIO_DE_CURVA: float = 80.0
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


func setup(a_tuning: BikeTuning, a_world_tuning: WorldTuning, world_seed: int = SEMENTE) -> void:
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
	# Meio-dia de sol duro: e o que as referencias mostram, e o caso mais facil
	# de iluminacao que existe. Um sol, e o resto e consequencia dele.
	var ceu := ProceduralSkyMaterial.new()
	ceu.sky_top_color = Color(0.16, 0.38, 0.82)
	ceu.sky_horizon_color = Color(0.62, 0.74, 0.88)
	ceu.ground_horizon_color = Color(0.55, 0.6, 0.62)
	ceu.ground_bottom_color = Color(0.24, 0.26, 0.25)
	# Desligado de proposito: debanding e dither de sub-pixel para ESCONDER a
	# banda do degrade, e aqui a banda e o sotaque de epoca.
	ceu.use_debanding = false
	var sky := Sky.new()
	sky.sky_material = ceu

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	# A luz ambiente vem do CEU, e nao de uma cor escolhida: a sombra fica azul
	# porque o ceu e azul. E a diferenca entre cena iluminada e cena pintada.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.5
	# Metade do ceu, metade cinza neutro. So com o ceu, a sombra de um predio no
	# asfalto saia azul royal: na sombra a unica luz e a do ceu, e o LUT ainda
	# satura por cima. A sombra continua fria, so que fria de cinza.
	env.ambient_light_sky_contribution = 0.5
	env.ambient_light_color = Color(0.62, 0.63, 0.65)
	# Neblina segurando o horizonte: em pixel grosso o fade e o que da
	# profundidade, e de quebra esconde o fim do mundo sem precisar de LOD. Na
	# cor do horizonte, para o predio do fundo sumir no ceu e nao num cinza.
	env.fog_enabled = true
	env.fog_light_color = ceu.sky_horizon_color
	env.fog_density = 0.0045
	env.fog_aerial_perspective = 0.5
	env.fog_sky_affect = 0.0
	# Tonemap antes do LUT, que e o ultimo passo do Environment: o sol de
	# meio-dia estoura o branco em linear, e o filmic devolve o alto sem
	# achatar a sombra.
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	# A paleta: o LUT e o ponto unico onde o clima da tela se ajusta. Gerado
	# por `arte/paleta.py`. Depois dele so vem a quantizacao com dither, que e
	# do `main.gd` e e o ultimo passe de todos.
	env.adjustment_enabled = true
	env.adjustment_color_correction = LUT_DIA

	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42.0, 38.0, 0.0)
	sun.light_energy = 2.0
	sun.light_color = Color(1.0, 0.96, 0.88)
	# Sombra de contato e o que poe veiculo no chao: sem ela, tudo flutua. Os
	# numeros dela, do DIRECAO_VISUAL.md:
	# - 250 m de alcance. Eram 70, contando que a neblina apagava o mundo dali
	#   em diante - so que a 70 m ela cobre 27%, e com predio de 58 m a sombra
	#   acabava numa linha bem no meio da avenida. A 250 m a neblina ja cobre
	#   dois tercos, e o `shadow_fade_start` padrao (0,8) dissolve a sombra de
	#   200 m em diante em vez de cortar;
	# - quatro divisoes, com a primeira em 7,5 m: e o mesmo tamanho da primeira
	#   divisao dos 70 m antigos (10% de 70), entao a sombra do pneu nao perde
	#   resolucao. As outras vao a 25 m e 75 m, onde moram carro e predio;
	# - divisoes misturadas na emenda: com quatro, a troca de resolucao vira
	#   uma linha andando no asfalto junto com a camera;
	# - bias baixo, porque 7,5 m num quarto do atlas de 4096 e densidade de
	#   sobra, e bias alto descola a sombra do pneu (peter-panning).
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 250.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_split_1 = 0.03
	sun.directional_shadow_split_2 = 0.1
	sun.directional_shadow_split_3 = 0.3
	sun.directional_shadow_blend_splits = true
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 0.8
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
			# Os tres sorteios sao os mesmos da caixa do greybox, na mesma ordem:
			# mexer neles mudaria o transito e os rivais, que vem do mesmo
			# gerador. So o que se faz com eles mudou.
			var h := _rng.randf_range(6.0, 26.0)
			var w := _rng.randf_range(6.0, 14.0)
			var shade := _rng.randf_range(0.2, 0.42)
			var tipo := _tipo_de_predio(h)
			var building := Predio.criar(tipo, (w - 6.0) / 8.0, (shade - 0.2) / 0.22)
			props.add_child(building)
			# A fachada (-Z) olha para a pista, e a ponta dela fica a 6 m do
			# acostamento. Base 1 m abaixo da pista: o terreno cai depois do
			# acostamento, e na rampa o predio nao pode ficar com o pe no ar.
			var lateral := (edge + 6.0 + Predio.frente(tipo)) * side
			var base := track.transform_at(o, lateral)
			building.global_transform = Transform3D(
				Basis.looking_at(base.basis.x * -side, Vector3.UP), base.origin + Vector3.DOWN
			)
		o += _rng.randf_range(16.0, 30.0)


## Qual dos quatro predios cabe na altura sorteada. A faixa de cada um e a
## proporcao dele na avenida: um quarto de sobrado, o grosso de predio baixo
## de comercio, e torre so de vez em quando - torre demais fecha o ceu, e o
## ceu e metade da leitura de velocidade.
static func _tipo_de_predio(altura: float) -> Predio.Tipo:
	if altura < 11.0:
		return Predio.Tipo.SOBRADO
	if altura < 19.0:
		return Predio.Tipo.COMERCIO
	if altura < 23.0:
		return Predio.Tipo.ESCRITORIO
	return Predio.Tipo.TORRE


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
##
## Um sorteio so para os dois tipos de porta, como era quando havia um tipo:
## sorteio a mais aqui empurraria todo o resto da corrida do banco de provas.
func _place_car(car: TrafficCar, at_offset: float) -> void:
	if _rng.randf() < world_tuning.parked_chance:
		var curb := 0 if _rng.randf() < 0.5 else RoadTrack.LANE_COUNT - 1
		var sorteio := _rng.randf()
		var porta := TrafficCar.Porta.NENHUMA
		if sorteio < world_tuning.door_open_chance:
			porta = TrafficCar.Porta.ABERTA
		elif sorteio < world_tuning.door_open_chance + world_tuning.door_ambush_chance:
			porta = TrafficCar.Porta.NA_CARA
		car.recycle(at_offset, RoadTrack.lane_center(curb), true, porta)
	else:
		car.recycle(at_offset, _pick_lane(), false)
	_desencosta(car)


## Empurra para a frente o carro que nasceu em cima de outro na mesma faixa.
##
## Com caixa de 4,4 m e espacamento minimo de 5 m isso quase nao acontecia, e
## quando acontecia eram dois carros andando e o de tras freava ate soltar. Com
## onibus de 12 m e carro encostado - que nunca anda - vira um carro dentro do
## outro para sempre. Para a frente, e sem sorteio: o sorteio do mundo continua
## o mesmo, so a posicao anda.
func _desencosta(car: TrafficCar) -> void:
	for tentativa in 8:
		var empurra := 0.0
		for outro in traffic:
			if outro == car:
				continue
			var largura := outro.meia_largura() + car.meia_largura() + 0.3
			if absf(outro.lateral - car.lateral) >= largura:
				continue
			# Nao basta nao nascer encostado: o de tras precisa de chao para
			# frear ate a velocidade do da frente, senao entra nele logo depois.
			var juntos := outro.meio_comprimento() + car.meio_comprimento() + 0.5
			var na_frente := juntos + _frenagem(outro.speed - car.speed)
			var atras := juntos + _frenagem(car.speed - outro.speed)
			var d := car.offset - outro.offset
			if (d >= 0.0 and d < na_frente) or (d < 0.0 and -d < atras):
				empurra = maxf(empurra, outro.offset + na_frente - car.offset)
		if empurra <= 0.0:
			return
		car.posicionar(car.offset + empurra)


## Metros que um carro do transito precisa para tirar `fecha` m/s de
## diferenca, freando no talo, mais o atraso da consulta a pista
## (`TrafficCar.PROBE_EVERY`, ~0,07 s) com folga.
func _frenagem(fecha: float) -> float:
	if fecha <= 0.0:
		return 0.0
	return fecha * fecha / (2.0 * world_tuning.traffic_brake) + fecha * 0.2


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
		var meio := car.meio_comprimento()
		if along < -(meio + 6.8):
			car.near_missed = false
			continue
		if car.near_missed or absf(along) > meio + NEAR_MISS_ALONG:
			continue
		var side := absf(car.lateral - player.track_lateral) - car.meia_largura()
		# Perto o bastante pra assustar, longe o bastante pra nao ser colisao.
		if side > NEAR_MISS_MIN_LATERAL and side < NEAR_MISS_LATERAL:
			car.near_missed = true
			run.register_near_miss()
			player.add_adrenaline(tuning.boost_gain_near_miss)


## Distancia livre a frente numa dada lateral, a partir de `from_offset`.
## Devolve `span` quando nao ha nada no caminho.
## `exclude` tira um carro da conta - e como o proprio carro pergunta quanta
## pista tem a frente sem se enxergar parado a zero metro de si mesmo.
##
## `emparelhado` conta o carro ao lado, ate 4 m atras, como bloqueio. Sem ele,
## so conta quem esta a frente.
func path_clearance(
	from_offset: float, span: float, lateral: float, exclude: Node = null, emparelhado: bool = true
) -> float:
	var nearest := span
	# Carro perguntando: o que ele tem de nariz a mais que o padrao come pista.
	var proprio := 0.0
	if exclude is TrafficCar:
		proprio = (exclude as TrafficCar).meio_comprimento() - MEIO_CARRO
	for car in traffic:
		if car == exclude:
			continue
		var a_mais := car.meio_comprimento() - MEIO_CARRO
		var gap := car.offset - from_offset - a_mais - proprio
		# -4 m atras: um carro emparelhado ainda bloqueia a faixa. Contado da
		# frente dele, porque o onibus emparelha com o centro 8 m atras.
		if car.offset + car.meio_comprimento() - from_offset < MEIO_CARRO - 4.0 or gap > span:
			continue
		if not emparelhado and car.offset < from_offset:
			continue
		if absf(car.lateral - lateral) < _faixa_de(car, exclude):
			nearest = minf(nearest, maxf(gap, 0.0))
	return nearest


## Ate que distancia lateral, centro a centro, `car` atrapalha quem pergunta.
##
## Rival ve a conta fisica - lataria, moto e a sobra minima -, porque ele
## anda na lateral exata que escolhe: e parametrico, nao tem guidao para errar.
## O resto segue a regra de sempre, afinada para o carro de 1,8 m e corrigida
## pela largura: o carro, que so precisa saber quem segue quem na faixa, e o
## piloto automatico do banco de provas, que pilota uma moto de verdade e
## precisa da margem para o erro dela.
func _faixa_de(car: TrafficCar, quem: Node) -> float:
	if quem is RivalBike:
		return _meia_largura_na_curva(car) + MEIA_MOTO + FOLGA_MOTO
	var outro := 0.0
	if quem is TrafficCar:
		outro = (quem as TrafficCar).meia_largura() - MEIA_LARGURA_CARRO
	return 1.6 + car.meia_largura() - MEIA_LARGURA_CARRO + outro


## Meia largura de `car` contando o quanto a ponta dele sai da faixa na curva
## mais fechada (ver `RAIO_DE_CURVA`).
static func _meia_largura_na_curva(car: TrafficCar) -> float:
	var comprimento := car.meio_comprimento() * 2.0
	return car.meia_largura() + comprimento * comprimento / (8.0 * RAIO_DE_CURVA)


## O meio do vao de verdade no corredor `corredor`, olhando `span` a frente.
##
## O corredor e o meio entre duas faixas, e com dois carros de 1,8 m dos lados
## o vao livre fica centrado nele. Com um onibus de 2,5 m de um lado, o vao
## anda 18 cm para o outro: mirar no meio das faixas e mirar a 2 cm do
## onibus. Sem carro largo por perto, isto devolve o proprio corredor.
func _meio_do_vao(from_offset: float, span: float, corredor: float) -> float:
	var esquerda := corredor - RoadTrack.LANE_WIDTH * 0.5 + MEIA_LARGURA_CARRO
	var direita := corredor + RoadTrack.LANE_WIDTH * 0.5 - MEIA_LARGURA_CARRO
	for car in traffic:
		var lado := car.lateral - corredor
		# So os vizinhos do corredor. Quem esta em cima dele fecha o corredor
		# pelo `path_clearance`, e nao tem lado.
		if absf(lado) >= RoadTrack.LANE_WIDTH or absf(lado) < car.meia_largura():
			continue
		var ao_longo := car.offset - from_offset
		if ao_longo > span + car.meio_comprimento() or ao_longo < -car.meio_comprimento() - 2.0:
			continue
		var meia := _meia_largura_na_curva(car)
		if lado < 0.0:
			esquerda = maxf(esquerda, car.lateral + meia)
		else:
			direita = minf(direita, car.lateral - meia)
	return (esquerda + direita) * 0.5


## Algum carro ocupa o ponto `(offset, lateral)` de pista, para um corpo de
## meia medida `meio` (x = meia largura, z = meio comprimento)?
func ocupado(offset: float, lateral: float, meio: Vector3) -> bool:
	for car in traffic:
		if (
			absf(car.offset - offset) < car.meio_comprimento() + meio.z
			and absf(car.lateral - lateral) < car.meia_largura() + meio.x
		):
			return true
	return false


## A faixa em `lateral` esta livre para `car` entrar?
##
## Conta quem esta nela e quem esta indo para ela: dois carros escolhendo a
## mesma faixa do meio no mesmo instante e o caso classico. A folga cresce com
## a diferenca de velocidade - o de tras mais rapido chega antes de a troca
## acabar.
func faixa_livre(car: TrafficCar, lateral: float) -> bool:
	for outro in traffic:
		if outro == car:
			continue
		var largura := outro.meia_largura() + car.meia_largura() + 0.3
		if absf(outro.lateral - lateral) >= largura and absf(outro.destino() - lateral) >= largura:
			continue
		var frente := outro.offset - car.offset
		var fecha := car.speed - outro.speed if frente > 0.0 else outro.speed - car.speed
		var folga := (
			outro.meio_comprimento()
			+ car.meio_comprimento()
			+ FOLGA_TROCA
			+ maxf(fecha, 0.0) * FOLGA_TROCA_TEMPO
		)
		if absf(frente) < folga:
			return false
	return true


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
				RoadTrack.lane_center(lane)
				if i == 0
				else _meio_do_vao(from_offset, span, RoadTrack.corridor_center(lane))
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
