class_name PlayerBike
extends CharacterBody3D
## A moto do jogador. Este arquivo e o prototipo.
##
## Tudo mais aqui existe pra dar contexto a estas ~200 linhas: se acelerar,
## inclinar e bater nao estiver gostoso, arte nenhuma salva o projeto.
##
## O modelo em uma frase: o input controla a INCLINACAO, e a inclinacao e que
## controla a curva. Voce precisa se comprometer com um lado antes de virar, e
## precisa endireitar antes de flicar pro outro. E dai que sai o peso.

signal crashed(reason: String)
signal scraped(intensity: float)
signal punch_landed(target: Node3D)
signal took_hit
signal obstaculo_quebrado(intensidade: float)

enum State { RIDING, STAGGERED, CRASHED }

## O script do autoload `Controls`, para a funcao estatica: pelo nome do
## autoload o arquivo nao compila sem ele (ver `_analogico`).
const CONTROLES := preload("res://scripts/controls.gd")
const SIZE := Vector3(0.75, 1.75, 2.1)
const GRAVITY: float = 26.0
## A cor do jogador: o vermelho da bag das T-poses e das folhas do sprite
## (`Entregador.BAG_FABRICA`), e nenhum rival de `World.RIVAL_COLORS` chega
## perto dela. Foi laranja do primeiro cubo de greybox ate a roupa da V21.
const COR := Color(0.82, 0.12, 0.10)
## Quanto da velocidade de aproximacao volta como tranco, numa batida que nao
## derruba. Na traseira de um carro voce fica com a velocidade dele menos isto:
## sem o tranco, encostar no para-choque so freava, e frear nao e bater.
## Patinada da largada (`_patina`, 0..1). Cheia em ~1,5 s de gas aberto na
## contagem; larga recuperando em ~1,3 s. Com tracao zerada a moto perde 60%
## da forca e um terco da aderencia lateral: sai mole e rabeando, mas sai.
const PATINA_SOBE: float = 0.65
const PATINA_DESCE_PARADA: float = 1.6
const PATINA_RECUPERA: float = 0.75
const PATINA_PERDA_DE_FORCA: float = 0.6
const PATINA_PERDA_DE_GRIP: float = 0.7
## Guinada de rabeada em rad/s com a patina cheia, e a frequencia dela.
const PATINA_RABEADA: float = 0.9
const PATINA_RABEADA_HZ: float = 7.0
## m/s de derrapada que a roda girando em falso mostra a patina cheia.
const PATINA_FUMACA: float = 7.0

const QUIQUE: float = 0.3
## Segundos sem pilotar depois do quique. Curto: e o guidao que sacode na mao,
## nao a pancada de rival, que tira 0,7 s.
const TEMPO_DO_QUIQUE: float = 0.25
## Abaixo desta aproximacao (m/s) a batida e encostar, e nao bater. Ja nao havia
## diferenca: encostar no para-choque zerava a velocidade e sacudia o guidao
## 0,25 s, e a moto com o gas a fundo repetia isso para sempre. A agilidade
## depende da velocidade, entao parada contra o carro ela nao virava nunca
## (V31). Encostar tira o embalo, nao o controle.
const ENCOSTO: float = 5.0
## Metros por segundo que a moto escorrega ao longo do que a prendeu, no lado
## em que o jogador esta guiando.
const DESLIZE_PRESO: float = 4.5
## Segundos em que uma quina ou um quique nao se repete. O contato dura alguns
## passos de fisica, e cada um deles cobrava o tranco inteiro de novo.
const RESPIRO_DO_IMPACTO: float = 0.3
## Desaceleracao da moto deitada arrastando no asfalto, em m/s^2. Mais que o
## atrito de verdade de proposito: deslizar 40 m numa queda a 100 km/h e fiel,
## e e tambem a camera indo embora com a moto enquanto o jogador espera.
const ATRITO_DO_TOMBO: float = 12.0
## Quanto da velocidade que sobra depois da batida vira deslize. O resto foi
## para a lataria.
const DESLIZE: float = 0.5
## Semente das quedas. Fixa pelo mesmo motivo da do `World`: o banco de provas
## compara corridas, e a mesma batida tem que cair igual nas duas.
const SEMENTE_DA_QUEDA: int = 20260831

var tuning: BikeTuning
var track: RoadTrack

var state: State = State.RIDING:
	set(valor):
		state = valor
		# O banco e a largada tambem podem repor o estado diretamente.
		collision_layer = 0 if valor == State.CRASHED else Layers.PLAYER
var state_timer: float = 0.0

var speed: float = 0.0  ## Escalar, m/s, sempre >= 0.
var heading: float = 0.0  ## Guinada no mundo, radianos.
var lean: float = 0.0  ## Inclinacao atual, radianos. + = direita.
## A inclinacao que aparece: moto, piloto e camera (V05b). A `lean` e a da
## fisica, e a guinada sai dela com a tecla crua; esta segue o pedido em rampa
## e deita aos poucos, como o video. As duas na mesma mola: soltar e
## contra-inclinar continuam iguais nas duas, so a entrada da tecla difere.
var lean_visual: float = 0.0
var track_offset: float = 0.0  ## Metros percorridos ao longo da curva.
var track_lateral: float = 0.0
var adrenaline: float = 0.0  ## 0..100, enche com raspada, gasta com boost.
var boosting: bool = false
var airborne: bool = false
## Quanto a roda escorrega de lado, em m/s: a diferenca entre para onde a moto
## aponta e para onde ela vai (`_integrate`). E o que acende a fumaca.
var derrapada: float = 0.0
## Moto segurada no grid durante a contagem: o motor responde ao gas e a roda
## patina, mas ela nao sai do lugar. O mundo inteiro segue rodando.
var largada_travada: bool = false
## True quando a moto aponta pro lado contrario da pista. Sem aviso, o jogador
## capota, se levanta virado e passa dez segundos sem entender o que houve.
var wrong_way: bool = false
## Desligado pelo banco de provas pra medir aceleracao e curva sem a calcada
## nem o fim do mundo no meio. Em jogo isso e sempre true.
var road_bounds_enabled: bool = true
## Idem: o banco mede a MOTO, e 0-100 medido numa ladeira mede a ladeira.
var slope_enabled: bool = true
## Preenchido pelo World: dado um offset e uma preferencia, devolve uma lateral
## sem carro parado. O jogador sozinho nao ve o transito inteiro.
var find_clear_lateral: Callable = Callable()

var _vertical_speed: float = 0.0
## 0..1, o quanto a roda traseira perdeu tracao. Sobe com o gas aberto na
## contagem e, solto o grid, decai sozinho: quem acelerou tudo sem parar larga
## rabeando, quem esperou com o gas fechado larga limpo.
var _patina: float = 0.0
## Velocidade angular da inclinacao, rad/s: a metade da mola que nao aparece.
var _lean_vel: float = 0.0
## O pedido de inclinacao depois da rampa do teclado, -1 a 1. So o visual le.
var _pedido_de_inclinacao: float = 0.0
var _lean_visual_vel: float = 0.0
## A mola da inclinacao da moto montada. Nasce na CG, a moto do ator recem-criado.
var _fisica := FisicaDaMoto.new()
var _punch_timer: float = -1.0
var _punch_side: int = 0  ## -1 esquerda, +1 direita, 0 nenhum.
## Este soco ja acertou. Desligar a hitbox no acerto nao bastava: o passo
## seguinte religava ela, ainda dentro da janela ativa, e um soco so emitia
## `punch_landed` quatro vezes, empurrando o rival quatro vezes.
var _punch_landed: bool = false
var _hitboxes: Dictionary = {}
var _visual: Node3D
var _ator: Entregador
var _derrapagem: Derrapagem
var _chama_do_nitro: ChamaDoNitro
var _estrago: Estrago
## O que o polegar pediu neste passo. So a pose le: a fisica recebe o input
## direto em `_ride`.
var _acelerador: float = 0.0
var _freio: float = 0.0
var _esterco: float = 0.0
## Para que lado a moto tomba na queda: -1 esquerda, 1 direita.
var _lado_queda: float = 1.0
## Quanto a moto gira deitada no chao, em radianos. Positivo gira para a
## esquerda, como a guinada.
var _giro_queda: float = 0.0
## A velocidade horizontal antes do `move_and_slide`. Depois dele, a componente
## contra a parede ja foi cortada, e e justamente ela que mede a batida.
var _antes_da_batida: Vector3 = Vector3.ZERO
var _respiro_do_impacto: float = 0.0
## O guidao pedido neste passo, para o deslize de quem esta preso.
var _guidao: float = 0.0
var _rng_queda := RandomNumberGenerator.new()
var _last_road_y: float = 0.0
var _crash_recover_offset: float = 0.0
var _off_road: bool = false
var _crash_grace: float = 0.0


func _ready() -> void:
	# Quem esta na rua pula da frente dela (`Pessoa`).
	add_to_group(Pessoa.GRUPO_MOTOS)
	collision_layer = Layers.PLAYER
	collision_mask = Layers.WORLD | Layers.RIVAL
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING

	add_child(Greybox.box_shape(SIZE))

	# O visual e um no separado do corpo fisico: a moto inclina, a capsula de
	# colisao nao. Ele fica no chao, e nao no centro da capsula: a moto inclina
	# em volta do pneu no asfalto. Em volta do centro, nos 38 graus de fabrica
	# as rodas escorregariam 54 cm para fora da curva.
	_visual = Node3D.new()
	_visual.name = "Visual"
	_visual.position = Vector3(0.0, -SIZE.y * 0.5, 0.0)
	add_child(_visual)
	_ator = Entregador.new()
	_visual.add_child(_ator)
	_ator.pintar(COR)
	_derrapagem = Derrapagem.new()
	_derrapagem.position = Vector3(0.0, -SIZE.y * 0.5, Derrapagem.EIXO_TRASEIRO)
	add_child(_derrapagem)
	_chama_do_nitro = ChamaDoNitro.new()
	add_child(_chama_do_nitro)
	_chama_do_nitro.usar_modelo(_ator.modelo, -SIZE.y * 0.5)
	_estrago = Estrago.new()
	_estrago.position = Vector3(0.0, -SIZE.y * 0.5, 0.0)
	add_child(_estrago)
	# Os sinais ja chegam com o que o efeito precisa: a raspada com a
	# intensidade, o soco com quem levou.
	scraped.connect(_estrago.faisca)
	punch_landed.connect(func(alvo: Node3D) -> void: _estrago.impacto(alvo.global_position))

	_hitboxes[-1] = _make_hitbox(-1)
	_hitboxes[1] = _make_hitbox(1)
	_rng_queda.seed = SEMENTE_DA_QUEDA


## Este e o corredor que a camera segue: o borrao de velocidade nao passa nele.
func marcar_foco() -> void:
	_ator.foco = true


## Monta a moto `modelo` (um `Entregador.Modelo`), com a mola da inclinacao
## dela. O resto da fisica e o mesmo em todas (ver `FisicaDaMoto`).
func usar_modelo(modelo: int) -> void:
	_ator.trocar_modelo(modelo)
	_fisica = FisicaDaMoto.de(modelo)
	_chama_do_nitro.usar_modelo(modelo, -SIZE.y * 0.5)


func modelo() -> int:
	return _ator.modelo


## Desenha este corredor em sprite em vez do modelo 3D (`WorldTuning.ator_sprite`).
func usar_sprite(ligado: bool) -> void:
	_ator.sprite = ligado


## Poses do ator por segundo (`WorldTuning.ator_cadencia`); 0 e liso.
func usar_cadencia(hz: float) -> void:
	_ator.cadencia.hz = hz


func _make_hitbox(side: int) -> Area3D:
	var area := Area3D.new()
	area.name = "Hit%s" % ("L" if side < 0 else "R")
	area.collision_layer = Layers.PLAYER_HIT
	area.collision_mask = Layers.WORLD | Layers.RIVAL
	area.monitoring = false
	var shape := Greybox.box_shape(Vector3(1.4, 1.0, 1.4))
	area.add_child(shape)
	add_child(area)
	return area


func setup(a_tuning: BikeTuning, a_track: RoadTrack, start_offset: float) -> void:
	tuning = a_tuning
	track = a_track
	track_offset = start_offset
	track_lateral = RoadTrack.corridor_center(1)
	var t := track.transform_at(track_offset, track_lateral)
	heading = atan2(-t.basis.z.x, -t.basis.z.z)
	global_position = t.origin + Vector3.UP * (SIZE.y * 0.5)
	rotation = Vector3(0.0, heading + PI, 0.0)
	_last_road_y = t.origin.y
	_crash_recover_offset = start_offset


## Troca a pista de referencia sem mexer na moto.
##
## Bifurcacao nao teleporta ninguem: as duas curvas se encostam na boca e na
## reentrada, entao o que muda e so em qual delas o offset e a lateral passam a
## ser medidos. O palpite de offset e obrigatorio - project() e busca local, e
## sem ele a moto reprojetaria no pedaco errado da curva nova.
func switch_track(new_track: RoadTrack, offset_hint: float) -> void:
	track = new_track
	var projected := new_track.project(global_position, offset_hint)
	track_offset = projected.x
	track_lateral = projected.y
	_crash_recover_offset = maxf(track_offset - 6.0, 0.0)
	_last_road_y = track.point(track_offset, track_lateral).y + SIZE.y * 0.5


func _physics_process(delta: float) -> void:
	if track == null:
		return

	_crash_grace = maxf(_crash_grace - delta, 0.0)
	_respiro_do_impacto = maxf(_respiro_do_impacto - delta, 0.0)
	# Hitboxes sempre correm, ate durante o stagger - o soco ja saiu.
	_update_hitboxes(delta)

	_acelerador = 0.0
	_freio = 0.0
	_esterco = 0.0
	match state:
		State.CRASHED:
			_process_crashed(delta)
		State.STAGGERED:
			state_timer -= delta
			if state_timer <= 0.0:
				state = State.RIDING
			_pedido_de_inclinacao = 0.0
			_ride(delta, 0.0, 0.0, 0.0)
		State.RIDING:
			var steer := CONTROLES.steer_axis()
			# A rampa e da arte, nao da curva: com ela na fisica a moto virava
			# pouco e a direcao ficava dura. O analogico passa direto, porque o
			# polegar ja dosa.
			if _analogico():
				_pedido_de_inclinacao = steer
			else:
				_pedido_de_inclinacao = rampa_do_pedido(
					_pedido_de_inclinacao, steer, delta, tuning.lean_input_ramp
				)
			var throttle := Input.get_action_strength("ride_throttle")
			var brake := Input.get_action_strength("ride_brake")
			if largada_travada:
				_segura_no_grid(delta, throttle)
			else:
				# Decai devagar: a tracao volta enquanto a moto ja anda.
				_patina = move_toward(_patina, 0.0, PATINA_RECUPERA * delta)
				_ride(delta, steer, throttle, brake)
			_try_punch()
			_acelerador = throttle
			_freio = brake
			_esterco = _pedido_de_inclinacao

	# Caido, a moto desliza: a velocidade que o ator recebe e a do deslize, e e
	# dela que ele desconta o voo do piloto, como no rival.
	var velocidade := speed
	if state == State.CRASHED:
		velocidade = velocity.dot(Vector3(sin(heading), 0.0, cos(heading)))
	_ator.atualizar(
		delta,
		velocidade,
		_acelerador,
		_esterco,
		state == State.CRASHED,
		_lado_queda,
		lean_visual,
		_giro_queda,
		_freio
	)
	# No ar e caida a roda nao esta no asfalto: o que desliza no tombo e a
	# carenagem, e isso e faisca (V24), nao fumaca.
	var no_asfalto := state != State.CRASHED and not airborne
	_derrapagem.atualizar(delta, derrapada if no_asfalto else 0.0)
	_chama_do_nitro.atualizar(delta, boosting)
	var caida := state == State.CRASHED
	_estrago.atualizar(delta, caida, Vector2(velocity.x, velocity.z).length() if caida else 0.0)


## --- Nucleo do feel -------------------------------------------------------


## Se o ultimo pedido veio do stick (`Controls.analogico`). Procurado pelo
## caminho, e nao pelo nome do autoload: as ferramentas que rodam com
## `--script` (`arte/boneco_flow.gd`) carregam a `Pessoa`, que puxa este
## arquivo, sem autoload nenhum, e o nome solto nao compila.
func _analogico() -> bool:
	var controles := get_node_or_null(^"/root/Controls")
	return controles != null and bool(controles.get(&"analogico"))


func _ride(delta: float, steer: float, throttle: float, brake: float) -> void:
	_guidao = steer
	_update_lean(delta, steer)
	_update_speed(delta, throttle, brake)
	_update_heading(delta)
	_integrate(delta)
	_resolve_collisions()
	_clamp_to_road()


## Na contagem a moto fica parada, mas o gas conta: cada segundo de acelerador
## aberto gasta tracao, e a patinada dura ate depois do sinal. Sem gas ela
## recupera rapido, e esse e o incentivo para esperar o "VAI!".
func _segura_no_grid(delta: float, throttle: float) -> void:
	var taxa := PATINA_SOBE if throttle > 0.1 else -PATINA_DESCE_PARADA
	_patina = clampf(_patina + taxa * delta, 0.0, 1.0)
	speed = 0.0
	velocity = Vector3.ZERO
	boosting = false
	# A fumaca da roda girando em falso: o `Derrapagem` le este numero.
	derrapada = _patina * PATINA_FUMACA


func _update_lean(delta: float, steer: float) -> void:
	var maximo := deg_to_rad(tuning.max_lean)
	var passo := passo_da_inclinacao(lean, _lean_vel, steer * maximo, delta, tuning, _fisica)
	lean = passo.x
	_lean_vel = passo.y
	passo = passo_da_inclinacao(
		lean_visual, _lean_visual_vel, _pedido_de_inclinacao * maximo, delta, tuning, _fisica
	)
	lean_visual = passo.x
	_lean_visual_vel = passo.y


## O pedido de inclinacao da tecla, em rampa: sobe ate `cru` a 1/`tempo` por
## segundo e cai seco. Soltar ou trocar de lado parte do zero na hora - a
## volta e a contra-inclinacao sao da mola, e a rampa so atrasaria a saida que
## a V05 acertou. So a `lean_visual` le: na fisica a rampa atrasava o
## deslocamento na pista e a direcao ficava dura. Estatica para o teste medir
## sem montar a moto.
static func rampa_do_pedido(pedido: float, cru: float, delta: float, tempo: float) -> float:
	if tempo <= 0.0:
		return cru
	if cru * pedido <= 0.0:
		pedido = 0.0
	if absf(cru) <= absf(pedido):
		return cru
	return move_toward(pedido, cru, delta / tempo)


## Um passo da mola da inclinacao: devolve (angulo, velocidade angular).
##
## Inclinar custa mais que endireitar: a moto cai facil pro lado e volta
## sozinha. Duas molas separadas, e nao uma, e o que da a sensacao de peso. A
## de deitar e critica; a de voltar passa do zero e assenta. Estatica para o
## teste unitario medir a mola sem montar a moto, e para o rival andar na mola
## da moto dele. Sem `moto`, e a CG.
static func passo_da_inclinacao(
	angulo: float, vel: float, alvo: float, delta: float, t: BikeTuning, moto: FisicaDaMoto = null
) -> Vector2:
	if moto == null:
		moto = FisicaDaMoto.new()
	# `alvo * angulo < 0`, e nao `signf` diferente: com o alvo no zero, o sinal
	# dele (0) difere do de qualquer angulo, e a contra-inclinacao trocava para
	# a mola critica bem na hora de passar do zero.
	var deitando := absf(alvo) > absf(angulo) or alvo * angulo < 0.0
	var w := t.lean_freq * moto.deitar if deitando else t.lean_return_freq * moto.voltar
	var zeta := 1.0 if deitando else t.lean_return_damping * moto.amortecer
	# Euler semi-implicito: estavel enquanto w * delta < 2. O slider para em
	# 40 rad/s, e a PCX multiplica por 1,3: 52 rad/s, 0,87 a 60 Hz.
	vel += (w * w * (alvo - angulo) - 2.0 * zeta * w * vel) * delta
	angulo += vel * delta
	# A mola critica entrando com embalo (saindo de uma contra-inclinacao, por
	# exemplo) ainda passa do alvo uma vez. No teto isso seria passar de
	# `max_lean`, que e a promessa do slider.
	var teto := deg_to_rad(t.max_lean)
	if absf(angulo) > teto:
		angulo = signf(angulo) * teto
		vel = 0.0
	return Vector2(angulo, vel)


func _update_speed(delta: float, throttle: float, brake: float) -> void:
	boosting = Input.is_action_pressed("ride_boost") and adrenaline > 0.0 and state == State.RIDING
	var top := tuning.max_speed * (tuning.boost_speed_mult if boosting else 1.0)

	if boosting:
		adrenaline = maxf(adrenaline - tuning.boost_drain * delta, 0.0)

	if throttle > 0.0:
		# Aceleracao cai conforme se aproxima do teto: empurrao forte na saida,
		# ultimos 20 km/h custam caro. E o que faz o boost valer alguma coisa.
		var headroom := clampf(1.0 - speed / maxf(top, 0.01), 0.0, 1.0)
		var power := tuning.accel * pow(headroom, tuning.accel_falloff)
		if boosting:
			power += tuning.boost_accel
		power *= 1.0 - PATINA_PERDA_DE_FORCA * _patina
		speed += power * throttle * delta
	else:
		speed -= (tuning.engine_brake + tuning.drag * speed * speed) * delta

	if brake > 0.0:
		speed -= tuning.brake * brake * delta

	# A ladeira entra como aceleracao, nao como teto: subir come o gas que voce
	# nao tinha sobrando e descer devolve. Mexer no teto em vez disso faria
	# `max_speed` deixar de ser a velocidade maxima, e slider que mente e
	# slider que ninguem consegue ajustar.
	if slope_enabled:
		speed -= tuning.slope_pull * track.grade_at(track_offset) * delta

	speed = maxf(speed, 0.0)
	if speed > top:
		# Sair do boost desacelera, nao teleporta a velocidade pra baixo.
		speed = maxf(speed - 14.0 * delta, top)


func _update_heading(delta: float) -> void:
	# A guinada vem da INCLINACAO, nunca do input direto.
	var lean_frac := lean / deg_to_rad(tuning.max_lean)

	# Agilidade em funcao da velocidade: quase nula parado (moto nao anda de
	# lado), maxima em velocidade media, reduzida no talo.
	var low := clampf(speed / tuning.turn_ramp_speed, 0.0, 1.0)
	var high := lerpf(
		1.0, tuning.turn_high_speed_factor, clampf(speed / tuning.max_speed, 0.0, 1.0)
	)
	var agility := low * high

	# MENOS: em Godot (Y pra cima, mao direita) guinada positiva gira pra
	# esquerda. Com `forward = (sin h, 0, cos h)`, dforward/dh = -right.
	heading -= deg_to_rad(tuning.turn_rate) * lean_frac * agility * delta
	# A traseira sem tracao varre de um lado ao outro, e some com a patina.
	if _patina > 0.0:
		var tempo := Time.get_ticks_msec() * 0.001
		heading += sin(tempo * PATINA_RABEADA_HZ * TAU) * PATINA_RABEADA * _patina * delta

	var road_fwd := -track.sample_basis(track_offset).z
	var road_heading := atan2(road_fwd.x, road_fwd.z)
	var diff := wrapf(road_heading - heading, -PI, PI)
	wrong_way = absf(diff) > deg_to_rad(105.0)

	# Assistencia de alinhamento: puxa a moto pro sentido da pista.
	if tuning.align_assist > 0.0 and speed > 1.0:
		heading += diff * (1.0 - exp(-tuning.align_assist * delta)) * (1.0 - 0.5 * _patina)

	# O corpo fisico gira junto: a capsula de colisao e as hitboxes de soco sao
	# filhas dele. Sem isso a moto colide como um bloco alinhado ao mundo e o
	# soco sai pro lado errado quando a pista curva.
	rotation = Vector3(0.0, heading + PI, 0.0)


func _integrate(delta: float) -> void:
	var forward := Vector3(sin(heading), 0.0, cos(heading))
	var desired := forward * speed

	# A velocidade real persegue a desejada em vez de virar ela. A diferenca e
	# a derrapada: quanto menor a aderencia, mais a moto escorrega pra fora.
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	# So o de lado: o de frente e a moto ganhando embalo, nao escorregando.
	var escorrega := desired - horizontal
	derrapada = (escorrega - forward * escorrega.dot(forward)).length()
	var grip := tuning.grip * (1.0 - PATINA_PERDA_DE_GRIP * _patina)
	horizontal = horizontal.lerp(desired, 1.0 - exp(-grip * delta))
	derrapada = maxf(derrapada, _patina * PATINA_FUMACA * clampf(speed / 6.0, 0.0, 1.0))

	var projected := track.project(global_position, track_offset)
	track_offset = projected.x
	track_lateral = projected.y

	var road_y := track.point(track_offset, track_lateral).y + SIZE.y * 0.5
	var road_climb := (road_y - _last_road_y) / maxf(delta, 0.0001)
	_last_road_y = road_y

	if not airborne:
		var impulso := FisicaDaMoto.impulso_de_rampa(self, horizontal * delta, speed)
		if impulso > 0.0:
			_vertical_speed = maxf(road_climb, 0.0) + impulso
	_vertical_speed -= GRAVITY * delta
	var next_y := global_position.y + _vertical_speed * delta
	if next_y <= road_y:
		# No chao: cola na pista e herda a subida dela. Na crista de uma
		# ladeira isso vira velocidade vertical de sobra - e o salto sai de
		# graca, sem nenhum codigo de rampa.
		#
		# Herda TAMBEM a descida. Ja foi `maxf(road_climb, 0.0)`: na ladeira
		# abaixo a moto pousava com vertical zero, a pista fugia por baixo e
		# ela caia em queda livre ate alcancar, pousava, zerava de novo - 40 cm
		# de quique a cada 12 m enquanto durasse a descida. Com o sinal
		# inteiro, so decola onde a crista curva mais forte que a gravidade.
		airborne = false
		_vertical_speed = road_climb
		velocity = Vector3(
			horizontal.x, (road_y - global_position.y) / maxf(delta, 0.0001), horizontal.z
		)
	else:
		airborne = true
		velocity = Vector3(horizontal.x, _vertical_speed, horizontal.z)

	_antes_da_batida = Vector3(velocity.x, 0.0, velocity.z)
	move_and_slide()
	velocity.y = 0.0

	_visual.rotation = Vector3(0.0, 0.0, -lean_visual)


## --- Impacto --------------------------------------------------------------


## Cada batida vira uma de quatro coisas, nesta ordem: raspada, quina, quique
## ou queda.
##
## Ja foi uma so pergunta - velocidade da moto acima de 58 km/h e angulo acima
## de 38 graus - e com ela quase toda batida derrubava. A velocidade que conta e
## a de aproximacao: na traseira de um carro a 25 km/h, a 100 voce chega a 75.
func _resolve_collisions() -> void:
	if speed < 0.5:
		return
	for i in range(get_slide_collision_count()):
		var col := get_slide_collision(i)
		var normal := col.get_normal()
		normal.y = 0.0
		if normal.length_squared() < 1e-6:
			continue
		normal = normal.normalized()

		var outro := col.get_collider()
		if outro is Amassavel:
			# Poste, semaforo e placa ficam de pe e levam a marca; quem cai, se
			# chegou rapido, e o jogador, pelo caminho de batida de qualquer
			# obstaculo fixo.
			var rapidez := _antes_da_batida.length()
			var de_frente := maxf(-_antes_da_batida.dot(normal), 0.0)
			# A velocidade toda conta, e nao so a componente contra a face: o
			# poste e fino, e quem o pega de raspao a 140 km/h o amassa do mesmo
			# jeito. De frente vale o dobro de uma raspada.
			var cheia := de_frente / maxf(rapidez, 0.01)
			var forca := clampf(rapidez / tuning.max_speed * lerpf(0.4, 1.0, cheia), 0.0, 1.0)
			if (outro as Amassavel).amassar(forca, _antes_da_batida):
				_estrago.faisca(maxf(forca, 0.25))
				_ator.impacto(maxf(forca, 0.25))
				obstaculo_quebrado.emit(maxf(forca, 0.25))
		var v_outro := _velocidade_de(outro)
		var relativa := _antes_da_batida - v_outro
		var chegada := maxf(-relativa.dot(normal), 0.0)
		if chegada < ENCOSTO:
			_desliza_preso(normal, get_physics_process_delta_time())
		var head_on := clampf(chegada / maxf(relativa.length(), 0.01), 0.0, 1.0)
		var incidence := rad_to_deg(asin(head_on))
		if outro is TrafficCar:
			var desvio_porta := (outro as TrafficCar).acertar_porta(
				col.get_collider_shape() as CollisionShape3D, chegada
			)
			if desvio_porta != Vector3.ZERO:
				if _respiro_do_impacto <= 0.0:
					_ricocheteia(desvio_porta, chegada)
				return

		if incidence <= tuning.crash_angle or _respiro_do_impacto > 0.0:
			_raspa(normal, head_on)
			continue

		var desvio := _quina(col, normal)
		if desvio != Vector3.ZERO:
			_ricocheteia(desvio, chegada)
		elif outro is RivalBike or chegada < tuning.crash_min_speed or _crash_grace > 0.0:
			# Moto nao derruba moto: o rival e da mesma altura, e na traseira
			# dele quem leva a pior e o seu guidao, nao o seu corpo.
			_quica(normal, v_outro, chegada)
		else:
			_crash("bateu de frente", normal, chegada)
		return


## Preso encostado em carro, placa ou predio, a moto escorrega ao longo da face
## para o lado em que o jogador guia. Ir "para o lado" de uma parede nao a
## desvia: a guinada depende de velocidade, e a parede a zera (V31).
func _desliza_preso(normal: Vector3, delta: float) -> void:
	if absf(_guidao) < 0.1:
		return
	var direita := Vector3(-cos(heading), 0.0, sin(heading))
	var tangente := Vector3.UP.cross(normal)
	if tangente.dot(direita) * _guidao < 0.0:
		tangente = -tangente
	move_and_collide(tangente.normalized() * DESLIZE_PRESO * absf(_guidao) * delta)


## Raspada: perde velocidade, ganha um empurrao pro lado e vai embora.
## Raspar tem que ser recuperavel, senao o corredor vira roleta.
func _raspa(normal: Vector3, head_on: float) -> void:
	speed *= 1.0 - tuning.scrape_speed_loss * maxf(head_on, 0.25)
	velocity += normal * 2.0
	scraped.emit(head_on)


## A velocidade do que foi batido, no mundo. Carro e rival andam na curva com
## um escalar so; poste e predio ficam parados.
func _velocidade_de(outro: Object) -> Vector3:
	if not (outro is Node3D) or not ("speed" in outro):
		return Vector3.ZERO
	var frente := -(outro as Node3D).global_basis.z
	frente.y = 0.0
	return frente.normalized() * float(outro.get("speed"))


## Para onde a quina joga a moto, ou zero se a batida pegou a face cheia.
##
## Mede quanto da moto ficou em cima da face batida, ao longo dela, como
## fracao da mais estreita das duas. O ponto de contato nao serve: face contra
## face, o Godot devolve um canto da area de contato, e esse canto e quase
## sempre a borda da lataria.
func _quina(col: KinematicCollision3D, normal: Vector3) -> Vector3:
	var forma := col.get_collider_shape() as CollisionShape3D
	if forma == null or not (forma.shape is BoxShape3D):
		return Vector3.ZERO
	var meia := (forma.shape as BoxShape3D).size * 0.5
	var eixos := forma.global_basis.orthonormalized()
	# A face batida e a da normal, e a moto corre ao longo da outra direcao.
	var ao_longo := eixos.x
	var meia_face := meia.x
	if absf(normal.dot(eixos.x)) > absf(normal.dot(eixos.z)):
		ao_longo = eixos.z
		meia_face = meia.z
	ao_longo.y = 0.0
	ao_longo = ao_longo.normalized()

	var centro := (global_position - forma.global_position).dot(ao_longo)
	var minha := (
		absf(global_basis.x.dot(ao_longo)) * SIZE.x * 0.5
		+ absf(global_basis.z.dot(ao_longo)) * SIZE.z * 0.5
	)
	var em_cima := minf(centro + minha, meia_face) - maxf(centro - minha, -meia_face)
	if em_cima >= tuning.corner_fraction * 2.0 * minf(minha, meia_face):
		return Vector3.ZERO
	return ao_longo * (1.0 if centro >= 0.0 else -1.0)


## Pegou a quina: a moto desvia para fora dela e segue, mais lenta.
func _ricocheteia(desvio: Vector3, chegada: float) -> void:
	# Quanto mais rapido chegou, mais o canto torce o guidao.
	var forca := clampf(chegada / tuning.crash_min_speed, 0.25, 1.0)
	var frente := Vector3(sin(heading), 0.0, cos(heading))
	var nova := (frente + desvio * tan(deg_to_rad(tuning.corner_deflect * forca))).normalized()
	heading = atan2(nova.x, nova.z)
	rotation = Vector3(0.0, heading + PI, 0.0)
	speed *= 1.0 - tuning.scrape_speed_loss * (1.0 + forca)
	velocity = nova * speed + desvio * (1.0 + 1.5 * forca)
	_respiro_do_impacto = RESPIRO_DO_IMPACTO
	scraped.emit(forca)


## Bateu de frente sem chegar rapido o bastante para cair: fica com a
## velocidade do que estava na frente, menos o tranco, e o guidao sacode.
func _quica(normal: Vector3, v_outro: Vector3, chegada: float) -> void:
	if chegada < ENCOSTO:
		# Fica abaixo do limite de proposito: com o gas a fundo a velocidade
		# volta a subir entre dois passos, e passar de `ENCOSTO` por pouco
		# traria o quique inteiro de volta.
		speed = minf(speed, ENCOSTO * 0.8)
		var contra_leve := velocity.dot(normal)
		if contra_leve < 0.0:
			velocity -= normal * contra_leve
		return
	var frente := Vector3(sin(heading), 0.0, cos(heading))
	speed = minf(speed, maxf(v_outro.dot(frente) - chegada * QUIQUE, 0.0))
	var contra := velocity.dot(normal)
	if contra < 0.0:
		velocity -= normal * contra
	velocity += normal * chegada * QUIQUE
	state = State.STAGGERED
	state_timer = TEMPO_DO_QUIQUE
	_respiro_do_impacto = RESPIRO_DO_IMPACTO
	scraped.emit(clampf(chegada / tuning.crash_min_speed, 0.2, 1.0))


func _clamp_to_road() -> void:
	if not road_bounds_enabled:
		return
	# A calcada nao tem teto de velocidade desde que o pedestre passou a ter
	# atropelo: quem foge por ela paga no que encontra pela frente, e nao num
	# freio invisivel (`docs/PROTOTIPO.md`, "A calcada").
	var limit := RoadTrack.limite_do_mundo()
	if absf(track_lateral) <= limit:
		_off_road = false
		return

	# Fim do chao: em vez de um colisor por metro de pista, um empurrao
	# analitico. So chega aqui quem entrou numa rua e foi ate o fundo, ou
	# passou por tras dos predios.
	var outward := signf(track_lateral)
	var over := absf(track_lateral) - limit
	var basis := track.sample_basis(track_offset)
	global_position -= basis.x * outward * over
	track_lateral = outward * limit

	# Mata so a componente lateral pra fora. Cobrar velocidade a cada frame
	# encostado no rail prende a moto a 6 km/h e o jogador nunca mais sai de la.
	var lateral_speed := velocity.dot(basis.x)
	if lateral_speed * outward > 0.0:
		velocity -= basis.x * lateral_speed

	# Enquanto raspa, a borda freia. Nao pode ser de graca: se andar colado
	# nela for mais rapido e mais seguro que o corredor, o jogador nunca
	# entra no transito e o pilar do jogo morre. E tambem nao pode ser
	# multiplicativo por frame, senao prende a moto a 6 km/h pra sempre.
	speed = maxf(speed - tuning.rail_friction * get_physics_process_delta_time(), 0.0)
	if not _off_road:
		_off_road = true
		speed *= 1.0 - tuning.scrape_speed_loss * 0.8
		scraped.emit(0.5)


## `normal` aponta do que foi batido para a moto; `chegada` e a velocidade de
## aproximacao, em m/s.
func _crash(reason: String, normal: Vector3 = Vector3.ZERO, chegada: float = 0.0) -> void:
	state = State.CRASHED
	state_timer = tuning.crash_recover_time
	speed = 0.0
	adrenaline = 0.0

	# Cada queda cai de um jeito. Tomba para onde a batida empurrou, somado a
	# inclinacao que ela ja tinha, e gira no chao para longe do que bateu. O
	# sorteio so desempata a batida reta, que sem ele caia sempre igual: para
	# a direita, alinhada com a pista.
	var frente := Vector3(sin(heading), 0.0, cos(heading))
	var direita := frente.cross(Vector3.UP)
	var empurrao := normal.dot(direita)
	var tendencia := lean / deg_to_rad(tuning.max_lean) + empurrao * 1.5
	tendencia += _rng_queda.randf_range(-0.6, 0.6)
	_lado_queda = -1.0 if tendencia < 0.0 else 1.0
	_giro_queda = clampf(-empurrao * 1.4 + _rng_queda.randf_range(-0.7, 0.7), -1.3, 1.3)

	# O que sobra depois da lataria vira deslize: ao longo dela, mais um tanto
	# devolvido pela batida.
	var tangente := _antes_da_batida - normal * _antes_da_batida.dot(normal)
	velocity = tangente * DESLIZE + normal * chegada * QUIQUE * 0.5
	_estrago.cair(Vector2(_antes_da_batida.x, _antes_da_batida.z).length() / tuning.max_speed)
	crashed.emit(reason)


func _process_crashed(delta: float) -> void:
	state_timer -= delta
	# Quem tomba a moto e o ator, em volta da lateral que bate no chao. Aqui so
	# zera a inclinacao da curva, senao o tombo soma com ela.
	_visual.rotation = Vector3.ZERO
	_desliza(delta)
	if state_timer > 0.0:
		return
	# Levanta onde a moto parou, e nao onde bateu: deslizou junto, volta junto.
	# Os 6 m para tras sao os mesmos de sempre - nascer encostado no que te
	# derrubou e cair de novo.
	_crash_recover_offset = maxf(track_offset - 6.0, 0.0)
	var lateral := clampf(
		track_lateral, -RoadTrack.half_width() + 1.0, RoadTrack.half_width() - 1.0
	)
	# Levantar a moto em cima do carro que acabou de te derrubar e o jeito mais
	# rapido de fazer o jogador largar o controle. Procura um vao antes.
	if find_clear_lateral.is_valid():
		lateral = find_clear_lateral.call(_crash_recover_offset + 12.0, lateral)
	place_on_track(_crash_recover_offset, lateral, 12.0)
	# Um respiro depois de levantar. Sem isso, cair ao lado de um carro que
	# anda a 5 km/h vira uma sequencia de quedas sem input nenhum no meio.
	_crash_grace = 1.2


## A moto deitada arrasta no asfalto ate parar, colada no chao e presa no fim
## do mundo, como em pe.
func _desliza(delta: float) -> void:
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	horizontal = horizontal.move_toward(Vector3.ZERO, ATRITO_DO_TOMBO * delta)
	var projected := track.project(global_position, track_offset)
	track_offset = projected.x
	track_lateral = projected.y
	var road_y := track.point(track_offset, track_lateral).y + SIZE.y * 0.5
	_last_road_y = road_y
	_vertical_speed = 0.0
	velocity = Vector3(
		horizontal.x, (road_y - global_position.y) / maxf(delta, 0.0001), horizontal.z
	)
	move_and_slide()
	velocity.y = 0.0

	var limit := RoadTrack.limite_do_mundo()
	if not road_bounds_enabled or absf(track_lateral) <= limit:
		return
	var outward := signf(track_lateral)
	var basis := track.sample_basis(track_offset)
	global_position -= basis.x * outward * (absf(track_lateral) - limit)
	track_lateral = outward * limit
	var lateral_speed := velocity.dot(basis.x)
	if lateral_speed * outward > 0.0:
		velocity -= basis.x * lateral_speed


## --- Combate --------------------------------------------------------------


func _try_punch() -> void:
	if _punch_timer > 0.0:
		return
	if Input.is_action_just_pressed("hit_left"):
		_start_punch(-1)
	elif Input.is_action_just_pressed("hit_right"):
		_start_punch(1)


func _start_punch(side: int) -> void:
	_punch_side = side
	_punch_timer = tuning.punch_cooldown
	_punch_landed = false
	_ator.socar(side, tuning.punch_windup, tuning.punch_active, tuning.punch_cooldown)


func _update_hitboxes(delta: float) -> void:
	if _punch_timer <= 0.0:
		return
	_punch_timer -= delta
	var elapsed := tuning.punch_cooldown - _punch_timer
	var area: Area3D = _hitboxes[_punch_side]
	area.position = Vector3(tuning.punch_range * float(_punch_side), 0.0, -0.2)

	var active := (
		not _punch_landed
		and elapsed >= tuning.punch_windup
		and elapsed < tuning.punch_windup + tuning.punch_active
	)
	if active and not area.monitoring:
		area.monitoring = true
	elif not active and area.monitoring:
		area.monitoring = false
		return

	if not active:
		return
	for body: Node3D in area.get_overlapping_bodies():
		if body == self:
			continue
		punch_landed.emit(body)
		# Um alvo por soco: acertar dois rivais com uma cotovelada e comico,
		# mas destroi a leitura do combate.
		_punch_landed = true
		area.monitoring = false
		return


## Recoloca a moto na pista, parada e alinhada. Usado no respawn e no banco.
func place_on_track(at_offset: float, at_lateral: float, at_speed: float) -> void:
	_patina = 0.0
	track_offset = clampf(at_offset, 0.0, track.length)
	track_lateral = at_lateral
	var t := track.transform_at(track_offset, track_lateral)
	global_position = t.origin + Vector3.UP * (SIZE.y * 0.5)
	heading = atan2(-t.basis.z.x, -t.basis.z.z)
	rotation = Vector3(0.0, heading + PI, 0.0)
	lean = 0.0
	_lean_vel = 0.0
	lean_visual = 0.0
	_lean_visual_vel = 0.0
	_pedido_de_inclinacao = 0.0
	speed = at_speed
	velocity = Vector3(sin(heading), 0.0, cos(heading)) * at_speed
	_vertical_speed = 0.0
	_last_road_y = global_position.y
	_crash_recover_offset = track_offset
	_off_road = false
	state = State.RIDING
	airborne = false
	state_timer = 0.0


## Chamado pelos rivais quando eles acertam o jogador.
func receive_hit(from_side: int, shove: float, stagger: float) -> void:
	if state == State.CRASHED:
		return
	state = State.STAGGERED
	state_timer = stagger
	var basis := track.sample_basis(track_offset)
	velocity += basis.x * float(from_side) * shove
	speed *= 0.88
	_ator.levar_golpe(from_side)
	took_hit.emit()


## Empurrao lateral sem stagger - usado pelo encostao de rival.
func shove(direction: Vector3, force: float) -> void:
	velocity += direction.normalized() * force


func add_adrenaline(amount: float) -> void:
	adrenaline = clampf(adrenaline + amount, 0.0, 100.0)


func speed_kmh() -> float:
	return speed * 3.6
