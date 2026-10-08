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

## Ele foi ao chao. `pelo_jogador` diz se um soco do jogador responde pela
## queda - e o que separa conquista de acidente de transito. Ver
## `CREDITO_DO_SOCO`.
signal went_down(pelo_jogador: bool)
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

## Segundos em que um soco do jogador continua respondendo pela queda do rival.
##
## O golpe do Road Rash nao derruba: ele EMPURRA pra dentro de alguma coisa. O
## empurrao sai no frame do soco, mas a lataria pode estar alguns metros
## adiante, e o rival ainda passa `punch_stagger` (0,7 s de fabrica) sem
## governar a moto. 1,5 s cobre o cambaleio inteiro com folga pra ele chegar no
## carro, e e curto o bastante pra nao creditar ao jogador uma queda que
## aconteceu meia avenida depois, quando o rival ja tinha voltado a correr.
const CREDITO_DO_SOCO: float = 1.5

## Distancia centro a centro acima da qual um "encostou" do sensor e mentira.
##
## O Area3D responde com o estado do ULTIMO passo de fisica, e num passo em que
## todo mundo acabou de ser reposicionado - a largada, o R, o teleporte de
## +9000 m do banco de provas - esse estado descreve um mundo que nao existe
## mais: os corpos ainda estavam na origem, todos sobrepostos. Sem este filtro
## os cinco rivais capotavam no primeiro frame de toda corrida, contra carros
## que estavam a 150 m dali.
##
## 4,5 m e folga em cima do encosto real: meia diagonal do sensor (0,95 m) mais
## meio carro (2,2 m) da 3,4 m, e um frame de aproximacao a 33 m/s soma 0,55 m.
## Contra carro do transito o meio carro e o do modelo (`_alcance`): com os
## 4,5 m fixos, a ponta do onibus de 12 m ficava a 6 m do centro dele, e o
## rival atravessava a traseira do onibus sem cair.
const WIPEOUT_ALCANCE: float = 4.5

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
## Este soco ja acertou. Desligar a hitbox no acerto nao bastava: o passo
## seguinte religava ela, ainda dentro da janela ativa, e um soco so acertava o
## jogador tres vezes, um passo de fisica sim, outro nao.
var _punch_landed: bool = false
## Segundos que faltam medindo o jogador antes do proximo soco; -1 = nao esta
## mirando. Ver `_aim_punch`.
var _punch_delay: float = -1.0
var _aggression: float = 0.5
## Segundos que faltam pro soco do jogador parar de responder pela queda.
var _credito_jogador: float = 0.0
var _rng := RandomNumberGenerator.new()
var _visual: Node3D
var _ator: Entregador
## Se ele esta acelerando neste passo. So a pose le.
var _acelerador: float = 0.0
## Para que lado ele tomba na queda: o lado em que estava inclinado.
var _lado_queda: float = -1.0
var _hitbox: Area3D
var _sensor: Area3D
var _lean: float = 0.0


func _ready() -> void:
	sync_to_physics = true
	collision_layer = Layers.RIVAL
	collision_mask = 0

	add_child(Greybox.box_shape(SIZE))

	# No chao, como o do jogador: a moto inclina em volta do pneu.
	_visual = Node3D.new()
	_visual.position = Vector3(0.0, -SIZE.y * 0.5, 0.0)
	add_child(_visual)
	_ator = Entregador.new()
	_visual.add_child(_ator)
	_ator.pintar(bag_color)

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
	# Mesmo ator, paleta trocada: cada rival e uma cor, da bag a moto.
	_ator.pintar(color)
	# E a moto sorteada, uma vez so: rival e gente, e gente nao troca de moto
	# entre uma corrida e outra. Sorteio num gerador a parte, e com semente
	# derivada, e nao a mesma: tirar do `_rng` mudaria o ritmo e a agressividade
	# de todo o pelotao, e a mesma semente crua faria a moto andar junto com o
	# ritmo - toda XRE seria a do rival mais lento.
	var sorteio := RandomNumberGenerator.new()
	sorteio.seed = hash([seed_value, "moto"])
	_ator.trocar_modelo(sorteio.randi() % Entregador.CENAS.size())


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
	_punch_delay = -1.0
	_credito_jogador = 0.0
	_hitbox.monitoring = false
	_lean = 0.0
	pace = _rng.randf_range(world_tuning.rival_pace_min, world_tuning.rival_pace_max)
	speed = tuning.max_speed * pace * 0.6
	_aggression = _rng.randf_range(
		world_tuning.rival_aggression_min,
		maxf(world_tuning.rival_aggression_max, world_tuning.rival_aggression_min)
	)
	_apply_transform()


func _physics_process(delta: float) -> void:
	if track == null or player == null:
		return

	_acelerador = 0.0
	_update_hitbox(delta)
	_punch_cooldown = maxf(_punch_cooldown - delta, 0.0)
	# Corre em qualquer estado: o rival socado passa o cambaleio inteiro sem
	# governar a moto, e e justamente ai que ele bate.
	_credito_jogador = maxf(_credito_jogador - delta, 0.0)

	match state:
		State.DOWN:
			state_timer -= delta
			speed = move_toward(speed, 0.0, 40.0 * delta)
			# Quem tomba e o ator; aqui so zera a inclinacao da curva.
			_visual.rotation = Vector3.ZERO
			if state_timer <= 0.0:
				state = State.RACING
				# Levanta abaixo do proprio ritmo: a queda tem que custar
				# posicao, senao derrubar rival vira so um efeito bonito.
				speed = tuning.max_speed * pace * 0.6
			_advance(delta)
		State.STAGGERED:
			state_timer -= delta
			if state_timer <= 0.0:
				state = State.RACING
			_advance(delta)
			_check_wipeout()
		State.RACING:
			_drive(delta)
			_advance(delta)
			_check_wipeout()

	# O esterco do rival e a propria inclinacao: ele nao tem polegar, e a
	# inclinacao ja e o que a IA decidiu fazer com a moto.
	_ator.atualizar(
		delta,
		speed,
		_acelerador,
		_lean / deg_to_rad(tuning.max_lean),
		state == State.DOWN,
		_lado_queda,
		_lean
	)


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
	_acelerador = 1.0 if target_speed > speed else 0.0
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
			#
			# O 0.5 e o gatilho da cacada, e ele mora ACIMA do meio do intervalo
			# sorteado de proposito: cacar e a excecao do pelotao, nao o padrao.
			# Com o intervalo de fabrica (0.1 a 0.55) sai mais ou menos um rival
			# briguento a cada dez.
			if duel and absf(gap) < world_tuning.rival_hunt_range and _aggression > 0.5:
				want = _alongside_lateral()
	if world.has_method("free_lateral"):
		want = world.free_lateral(offset, want, span, self)
	_target_lateral = clampf(want, -RoadTrack.half_width() + 1.0, RoadTrack.half_width() - 1.0)

	var move := _target_lateral - lateral
	var lateral_speed := clampf(move * 3.0, -9.0, 9.0)
	# O alvo e escolhido pela pista livre la na frente, e o caminho ate ele
	# pode cruzar um carro que esta do lado agora. Segura a lateral em vez de
	# deslizar para dentro dele: o carro fica para tras, e o caminho abre.
	if world.has_method("ocupado"):
		var proxima := lateral + lateral_speed * delta
		if (
			world.ocupado(offset, proxima, SIZE * 0.5)
			and not world.ocupado(offset, lateral, SIZE * 0.5)
		):
			lateral_speed = 0.0
	lateral += lateral_speed * delta
	_lean = lerpf(
		_lean,
		clampf(-lateral_speed / 9.0, -1.0, 1.0) * deg_to_rad(tuning.max_lean),
		1.0 - exp(-8.0 * delta)
	)

	if mode == Mode.ATTACK:
		_aim_punch(delta)
	else:
		# Saiu do duelo: a mira zera. Guardar o cronometro de um duelo antigo
		# faz o rival socar no instante em que voce reencosta, meia volta depois.
		_punch_delay = -1.0


## Mira do soco: o rival mede o jogador antes de bater.
##
## Era um sorteio por frame - `randf() < _aggression` dentro do `_physics_process`
## - e isso, a 60 Hz, nao quer dizer "as vezes ele soca": com 0.5 de
## agressividade o soco saia em media no segundo frame dentro do alcance. Na
## pratica, emparelhar com um rival era apanhar, e o jogador nao tinha instante
## nenhum pra sair, socar primeiro ou aceitar a briga.
##
## Aqui o tempo e explicito. Ele precisa ficar colado por `rival_punch_delay`
## antes do primeiro soco, e sair do alcance no meio da mira cancela - o que
## transforma "chegou perto" em "ficou perto", que e uma escolha.
func _aim_punch(delta: float) -> void:
	if _punch_cooldown > 0.0:
		return
	var side_gap := player.track_lateral - lateral
	if absf(side_gap) > tuning.punch_range + 1.0:
		_punch_delay = -1.0
		return
	if _punch_delay < 0.0:
		# O briguento espera a metade do que o manso espera - a agressividade
		# encurta a mira em vez de sortear se ela existe.
		_punch_delay = world_tuning.rival_punch_delay * (1.0 - _aggression * 0.5)
	_punch_delay -= delta
	if _punch_delay > 0.0:
		return
	_punch_delay = -1.0
	_punch_side = int(signf(side_gap))
	_punch_timer = tuning.punch_cooldown
	_punch_landed = false
	_ator.socar(_punch_side, tuning.punch_windup, tuning.punch_active, tuning.punch_cooldown)
	# Respiro depois do soco, somado ao cooldown da hitbox. O cooldown era
	# DIVIDIDO pela agressividade, o que punha o rival briguento socando a cada
	# 0,47 s: numa briga que dura tres segundos isso e seis socos, e o jogador
	# staggered nao consegue responder a nenhum.
	_punch_cooldown = (
		tuning.punch_cooldown + world_tuning.rival_punch_rest * (1.0 - _aggression * 0.5)
	)


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
		not _punch_landed
		and elapsed >= tuning.punch_windup
		and elapsed < tuning.punch_windup + tuning.punch_active
	)
	_hitbox.monitoring = active
	if not active:
		return
	for body: Node3D in _hitbox.get_overlapping_bodies():
		if body is PlayerBike:
			(body as PlayerBike).receive_hit(
				_punch_side, world_tuning.rival_punch_shove, tuning.punch_stagger
			)
			hit_player.emit()
			_punch_landed = true
			_hitbox.monitoring = false
			return


func _check_wipeout() -> void:
	if state == State.DOWN:
		return
	for body: Node3D in _sensor.get_overlapping_bodies():
		if global_position.distance_to(body.global_position) <= _alcance(body):
			_go_down()
			return


func _alcance(body: Node3D) -> float:
	if body is TrafficCar:
		return WIPEOUT_ALCANCE + (body as TrafficCar).meio_comprimento() - World.MEIO_CARRO
	return WIPEOUT_ALCANCE


func _go_down() -> void:
	state = State.DOWN
	state_timer = 2.6
	_lado_queda = -1.0 if _lean <= 0.0 else 1.0
	_punch_timer = -1.0
	_punch_delay = -1.0
	_hitbox.monitoring = false
	went_down.emit(derrubado_pelo_jogador())
	# Gasta o credito na queda que ele pagou: o rival levanta em 2,6 s, e um
	# soco nao pode responder por duas quedas.
	_credito_jogador = 0.0


## Se este rival cair AGORA, a queda e do jogador?
##
## A pergunta existe como metodo, e nao como comparacao solta no `_go_down`,
## porque quem paga a queda esta do outro lado do sinal (ver `World`) e quem
## testa a regra nao tem como espiar um `_` privado.
func derrubado_pelo_jogador() -> bool:
	return _credito_jogador > 0.0


## Chamado quando o jogador acerta este rival.
func receive_hit(from_side: int, shove: float, stagger: float) -> void:
	if state == State.DOWN:
		return
	state = State.STAGGERED
	state_timer = stagger
	_punch_delay = -1.0
	# Este metodo so e chamado pelo soco do jogador (ver World). E aqui, e nao
	# no `_go_down`, que a autoria da queda nasce.
	_credito_jogador = CREDITO_DO_SOCO
	# O empurrao move o rival LATERALMENTE na pista. Se do outro lado tiver um
	# carro parado, ele vai direto pra dentro - esse e o combate do Road Rash.
	lateral += float(from_side) * shove * 0.14
	_target_lateral = lateral
	speed *= 0.85
	_ator.levar_golpe(from_side)
	_lean = deg_to_rad(tuning.max_lean) * float(from_side) * 0.9
	_apply_transform()
	_check_wipeout()
