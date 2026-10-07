class_name ProvaDeCombate
extends RefCounted
## A fase `combate` do banco de provas: o soco que empurra rival.
##
## O pilar do combate lateral era o unico "jogavel" do PROTOTIPO.md sem uma
## medida sequer. Isto mede a cadeia inteira, do jeito que o jogador a usa:
## hitbox do soco -> punch_landed -> World -> receive_hit -> empurrao lateral.
##
## Arquivo proprio pelo mesmo motivo da `ProvaDeBatida`: o `Selftest` encostou
## nas mil linhas do gdlint, e esta montagem so divide o mundo com as outras.

var _world: World
var _player: PlayerBike
var _tuning: BikeTuning
var _t: float = 0.0
var _rival_lateral_before: float = 0.0
var _rival_shove: float = 0.0
var _rival_staggered: bool = false
var _punch_thrown: bool = false
var _punch_connected: bool = false
## As medidas, falhas e linhas de relatorio do `Selftest`, por referencia.
var _metrics: Dictionary
var _failures: Array[String]
var _report: Array[String]


func _init(
	world: World,
	player: PlayerBike,
	tuning: BikeTuning,
	metrics: Dictionary,
	failures: Array[String],
	report: Array[String]
) -> void:
	_world = world
	_player = player
	_tuning = tuning
	_metrics = metrics
	_failures = failures
	_report = report


## Um passo de fisica. Devolve true quando a fase terminou.
func passo(delta: float) -> bool:
	_t += delta
	var rival: RivalBike = _world.rivals[0] if not _world.rivals.is_empty() else null
	if rival == null:
		_report.append("combate              nenhum rival na rota")
		_check(false, "nenhum rival existe - o pilar do combate nao tem como ser medido")
		return true

	if _t < 0.02:
		_player.road_bounds_enabled = false
		_player.collision_mask = Layers.WORLD | Layers.RIVAL
		_player.place_on_track(400.0, RoadTrack.lane_center(1), 26.0)
		# De pe, explicitamente. `place_on_track` recoloca a moto mas nao mexe
		# no estado, e a fase anterior termina com ela batendo na parede da
		# calcada - ou seja, chegando aqui capotada. `_try_punch` so roda em
		# RIDING, entao o soco nunca saia e o teste media um rival que nunca
		# foi socado.
		_player.state = PlayerBike.State.RIDING
		# Emparelhado a um alcance de soco de distancia - nao a uma faixa
		# inteira. Duas motos lado a lado no corredor ficam a pouco mais de um
		# metro; 3,3 m e o centro da faixa vizinha, e la o soco nao alcanca
		# ninguem. Sai do tuning pra o teste acompanhar quem mexer no alcance.
		rival.offset = _player.track_offset + 0.6
		rival.lateral = _player.track_lateral + _tuning.punch_range
		rival.speed = _player.speed
		if not rival.went_down.is_connected(_on_rival_down):
			rival.went_down.connect(_on_rival_down)
		if not _player.punch_landed.is_connected(_on_punch_landed):
			_player.punch_landed.connect(_on_punch_landed)

	# Segura o rival emparelhado ATE o soco sair - inclusive na lateral.
	#
	# Sem prender a lateral, a IA dele desvia sozinha e sai do alcance do soco,
	# e o teste passa a depender do humor do frame. Pior: o deslocamento que a
	# perseguicao dele produz parecia empurrao, entao a medida passava sem o
	# soco ter acertado. Foi o que aconteceu ao baixar a densidade do transito
	# - a medida era de correlacao, nao de causa.
	rival.offset = _player.track_offset + 0.6
	rival.speed = _player.speed
	if not _punch_connected:
		rival.lateral = _player.track_lateral + _tuning.punch_range
		_rival_lateral_before = rival.lateral
		# De pe, ate o soco sair. O `rivals[0]` chega das fases anteriores
		# caido, e mesmo levantado ele caia de novo no primeiro passo: a
		# lista do sensor de queda e de um passo de fisica atras, e nele o
		# rival ainda estava no fim da pista, onde `_bench_begin` empilhou o
		# transito. `receive_hit` ignora rival no chao, entao o soco acertava
		# e nao empurrava nada - e a medida registrava o rival indo embora
		# depois de levantar, 3,3 m que nao eram do soco.
		rival.state = RivalBike.State.RACING
		rival.state_timer = 0.0
	_set_action("ride_throttle", true)

	# Soca assim que o rival esta posicionado, e nao depois de meio segundo.
	#
	# A IA do rival entra em duelo com gap abaixo de 2,2 m, e o rival esta
	# emparelhado a um alcance de soco - ou seja, dentro dela. Esperando, ele
	# socava primeiro, o jogador ficava STAGGERED, e `_try_punch` so roda em
	# RIDING: o soco do jogador nunca saia e o teste media um rival que nunca
	# foi socado.
	#
	# Segura o botao por alguns frames antes de soltar, porque `_try_punch` le
	# `is_action_just_pressed` - so verdadeiro no processamento seguinte ao
	# press, entao soltar no frame de depois perde o soco.
	if _t > 0.06 and not _punch_thrown:
		_punch_thrown = true
		Input.action_press("hit_right")
	elif _punch_thrown and _t > 0.16:
		_set_action("hit_right", false)

	# Só conta depois de o soco ter ACERTADO, avisado pelo proprio sinal do
	# jogador. Antes disso, qualquer estado ou deslocamento do rival e coisa
	# dele, nao efeito do soco.
	#
	# E so enquanto ele cambaleia: de volta a RACING, a IA dele volta a
	# dirigir, e o que ele andar de lado dai em diante e perseguicao, nao
	# empurrao. Medindo os tres segundos inteiros, o numero subia para 7,5 m
	# com um empurrao de 1 m.
	if _punch_connected and rival.state != RivalBike.State.RACING:
		_rival_staggered = true
		_rival_shove = maxf(_rival_shove, absf(rival.lateral - _rival_lateral_before))

	if _t < 3.0:
		return false
	_metrics["combate_empurrao_m"] = _rival_shove
	_report.append(
		(
			"combate              soco %s, rival empurrado %.2f m, %s"
			% [
				"acertou" if _punch_connected else "ERROU",
				_rival_shove,
				"cambaleou" if _rival_staggered else "NAO reagiu"
			]
		)
	)
	_check(_punch_connected, "o soco passou pelo rival emparelhado sem acertar")
	_check(_rival_staggered, "o soco acertou e o rival nao cambaleou - a cadeia do combate quebrou")
	# O empurrao e o combate: sem deslocamento lateral nao da pra jogar o
	# rival dentro de um carro parado, que e o golpe do Road Rash.
	_check(
		_rival_shove > 0.1,
		"o rival mal saiu do lugar (%.2f m): o soco vira cosmetico" % _rival_shove
	)
	return true


## So pra a fase saber que o rival caiu de verdade.
func _on_rival_down(_pelo_jogador: bool) -> void:
	_rival_staggered = true


## O soco do jogador encostou em alguem. E a unica prova de causa que existe:
## dai pra frente, o que acontecer com o rival e efeito do soco.
func _on_punch_landed(target: Node3D) -> void:
	if target is RivalBike:
		_punch_connected = true


func _set_action(action_name: String, pressed: bool) -> void:
	if pressed and not Input.is_action_pressed(action_name):
		Input.action_press(action_name)
	elif not pressed and Input.is_action_pressed(action_name):
		Input.action_release(action_name)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
