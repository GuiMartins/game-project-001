class_name ProvaDeBatida
extends RefCounted
## A fase `batida` do banco de provas: o que cada tipo de batida vira.
##
## A corrida solta mede quantas quedas houve, mas nao QUAIS. E a regra mudou de
## "acima de 58 km/h e de frente, cai" para quatro desfechos, e cada um tem um
## caso que o desmente: a traseira de um carro lento quica, o carro parado a
## 126 km/h derruba, a quina desvia e a moto nunca derruba. Monta os quatro,
## um de cada vez, longe de todo o resto, e confere.
##
## Arquivo proprio porque o `Selftest` ja passava das mil linhas, e estas
## quatro montagens nao dividem nada com as outras fases alem do mundo.

## Os jeitos de bater, na ordem. O ultimo nao e uma batida: e o que vem depois
## dela, a moto encostada no carro e o jogador pedindo para sair.
const BATIDAS: PackedStringArray = ["traseira", "parado", "quina", "moto", "preso"]
## Segundos de cada batida: chegar, bater e ver no que deu.
const TEMPO_DA_BATIDA: float = 1.6
## O `preso` ganha mais: o que se mede e quanto demora a sair, e a prova tem de
## deixar a moto presa tempo bastante para reprovar.
const TEMPO_DO_PRESO: float = 4.0
## Quanto tempo, no maximo, a moto leva para deixar o carro depois de pedir o
## desvio. O Arthur ficou parado ate desistir (V31); um segundo ainda e tranco.
const SAIDA_MAXIMA: float = 1.0
const KMH: float = 3.6

var _mundo: World
var _moto: PlayerBike
var _batida: int = -1
var _batida_t: float = 0.0
var _batida_caiu: bool = false
var _batida_v0: float = 0.0
var _batida_lateral0: float = 0.0
var _batida_obstaculo: Node3D
## Segundos ate a moto sair do carro no `preso`; -1 enquanto nao saiu.
var _preso_saiu_em: float = -1.0
var _relato: PackedStringArray = []
## As medidas, falhas e linhas de relatorio do `Selftest`. Sao as dele, por
## referencia: a prova escreve direto, como qualquer outra fase.
var _medidas: Dictionary
var _falhas: Array[String]
var _relatorio: Array[String]


func _init(
	mundo: World,
	moto: PlayerBike,
	medidas: Dictionary,
	falhas: Array[String],
	relatorio: Array[String]
) -> void:
	_mundo = mundo
	_moto = moto
	_medidas = medidas
	_falhas = falhas
	_relatorio = relatorio


## Um passo de fisica. Devolve true quando as quatro batidas terminaram.
func passo(delta: float) -> bool:
	if _batida < 0:
		# A disputa terminou a corrida, e a tela de resultado congela a arvore
		# inteira do mundo. Descongela os filhos - moto, carro, rival - e deixa
		# so o `World` parado: e ele que reciclaria o carro da prova para longe
		# no meio dela.
		_mundo.process_mode = Node.PROCESS_MODE_INHERIT
		_mundo.set_physics_process(false)
		_moto.slope_enabled = false
		_moto.road_bounds_enabled = true
		_moto.collision_mask = Layers.WORLD | Layers.RIVAL
		_batida = 0
		_monta_batida()

	_batida_t += delta
	_batida_caiu = _batida_caiu or _moto.state == PlayerBike.State.CRASHED
	if BATIDAS[_batida] == "preso":
		_pilota_o_preso()
	else:
		_segura_faixa()
	if _batida_t < _tempo_da_batida():
		return false

	_confere_batida()
	_batida += 1
	if _batida < BATIDAS.size():
		_monta_batida()
		return false
	_relatorio.append("batida               " + ", ".join(_relato))
	return true


func _tempo_da_batida() -> float:
	return TEMPO_DO_PRESO if BATIDAS[_batida] == "preso" else TEMPO_DA_BATIDA


func _monta_batida() -> void:
	_batida_t = 0.0
	_preso_saiu_em = -1.0
	_batida_caiu = false
	# Nada mais na pista: o que se mede e esta batida, e nao a de quem passou.
	for car in _mundo.traffic:
		car.posicionar(car.offset + 9000.0)
	for rival in _mundo.rivals:
		rival.offset += 9000.0
	# A batida pode cair na via expressa, e a mao contraria vem de frente.
	_mundo.get_tree().call_group(&"contramao", &"esvaziar")

	var em := 400.0 + 150.0 * float(_batida)
	var faixa := RoadTrack.lane_center(1)
	var carro: TrafficCar = _mundo.traffic[0]
	# A chegada mais longa muda quantas vezes este carro foi reciclado na
	# disputa. Reciclar novamente aqui sorteava outra lataria: a prova de
	# colisao acabava medindo um modelo diferente conforme a fase anterior.
	if BATIDAS[_batida] != "moto":
		carro.setup(_mundo.track, em + 15.0, faixa, World.SEMENTE, BATIDAS[_batida] != "traseira")
	var lateral := faixa
	var velocidade := 35.0  # 126 km/h
	match BATIDAS[_batida]:
		"traseira":
			# 72 km/h num carro a 25: 47 km/h de aproximacao, longe de cair.
			carro.cruise_speed = 7.0
			carro.speed = 7.0
			# Sem troca de faixa no meio da prova: o timer vem do sorteio da
			# corrida inteira, e pode estar a um passo de zerar.
			carro.set("_lane_change_timer", 60.0)
			velocidade = 20.0
			_batida_obstaculo = carro
		"parado":
			_batida_obstaculo = carro
		"quina":
			# Um quarto da moto em cima da lataria: o guidao pega o canto.
			lateral = faixa + carro.meia_largura() + PlayerBike.SIZE.x * 0.25
			_batida_obstaculo = carro
		"preso":
			# Parado e encostado na traseira: e o instante depois da batida, com
			# o jogador de dedo no gas e no guidao. Sem velocidade nenhuma, o
			# que se mede e a saida, e nao a batida.
			velocidade = 0.0
			_batida_obstaculo = carro
		"moto":
			# Rival parado no meio da faixa. Congelado: ele correria embora, e o
			# que se mede e o pior caso, 126 km/h de aproximacao numa moto.
			var rival: RivalBike = _mundo.rivals[0]
			rival.set_physics_process(false)
			rival.offset = em + 15.0
			rival.lateral = faixa
			rival.speed = 0.0
			var t := _moto.track.transform_at(rival.offset, rival.lateral)
			t.origin += t.basis.y * (RivalBike.SIZE.y * 0.5)
			rival.global_transform = t
			_batida_obstaculo = rival
	var posicao := em
	if BATIDAS[_batida] == "preso":
		posicao = carro.offset - carro.meio_comprimento() - PlayerBike.SIZE.z * 0.5 - 0.05
	_moto.place_on_track(posicao, lateral, velocidade)
	_batida_v0 = velocidade
	_batida_lateral0 = lateral


## Mantem a moto na lateral em que ela nasceu ate chegar no obstaculo.
##
## Sem isso a curva leva a moto: sem inclinar ela anda reto, a pista vira por
## baixo, e em 15 m a quina vira batida cheia. Solta a 5 m do contato, para nao
## brigar com o desvio que a propria batida da.
func _segura_faixa() -> void:
	var obstaculo: float = _batida_obstaculo.get("offset")
	var antes := obstaculo - _moto.track_offset > 3.3 + 5.0
	var steer := 0.0
	if antes and _moto.state == PlayerBike.State.RIDING:
		var basis := _moto.track.sample_basis(_moto.track_offset)
		var road_heading := atan2((-basis.z).x, (-basis.z).z)
		steer = -wrapf(road_heading - _moto.heading, -PI, PI) * 4.0
		steer += (_batida_lateral0 - _moto.track_lateral) * 0.8
	_set_action("ride_right", steer > 0.02)
	_set_action("ride_left", steer < -0.02)


## O jogador do `preso`: gas a fundo e guidao para a direita, o tempo todo.
## Anota quando a moto deixou de estar na frente do carro, de lado ou por fora.
func _pilota_o_preso() -> void:
	_set_action("ride_throttle", true)
	_set_action("ride_right", true)
	var carro := _batida_obstaculo as TrafficCar
	var fora := _moto.track_lateral - carro.lateral > carro.meia_largura() + PlayerBike.SIZE.x * 0.5
	var passou := _moto.track_offset > carro.offset + carro.meio_comprimento()
	if _preso_saiu_em < 0.0 and (fora or passou):
		_preso_saiu_em = _batida_t


func _confere_batida() -> void:
	var nome := BATIDAS[_batida]
	_set_action("ride_throttle", false)
	var kmh := _batida_v0 * KMH
	match nome:
		"traseira":
			var carro := _batida_obstaculo as TrafficCar
			_medida("batida_traseira_kmh", _moto.speed * KMH)
			_relato.append("traseira %s a %.0f km/h" % ["CAIU" if _batida_caiu else "quicou", kmh])
			_confere(
				not _batida_caiu,
				(
					(
						"caiu na traseira de um carro a %.0f km/h vindo a %.0f: a queda voltou a"
						+ " olhar a velocidade da moto, e nao a de aproximacao"
					)
					% [carro.speed * KMH, kmh]
				)
			)
			_confere(
				_moto.track_offset < carro.offset,
				"a moto atravessou o carro em que bateu de traseira"
			)
			_confere(
				_moto.speed <= carro.speed + 1.0,
				(
					(
						"bateu na traseira e seguiu a %.0f km/h, mais rapido que o carro: bater"
						+ " virou frear"
					)
					% (_moto.speed * KMH)
				)
			)
		"parado":
			_relato.append(
				"carro parado %s a %.0f km/h" % ["caiu" if _batida_caiu else "NAO CAIU", kmh]
			)
			_confere(
				_batida_caiu, "entrou de frente num carro parado a %.0f km/h e ficou de pe" % kmh
			)
		"quina":
			var desvio := absf(_moto.track_lateral - _batida_lateral0)
			_medida("batida_quina_desvio_m", desvio)
			_relato.append(
				(
					"quina %s %.1f m a %.0f km/h"
					% ["CAIU depois de desviar" if _batida_caiu else "desviou", desvio, kmh]
				)
			)
			_confere(not _batida_caiu, "pegou a quina de um carro a %.0f km/h e caiu" % kmh)
			_confere(
				_moto.track_lateral > _batida_lateral0 + 0.3,
				(
					(
						"pegou a quina e a moto nao saiu para fora dela (%.2f m): a quina parou"
						+ " de desviar"
					)
					% (_moto.track_lateral - _batida_lateral0)
				)
			)
		"preso":
			var saiu := _preso_saiu_em if _preso_saiu_em >= 0.0 else TEMPO_DO_PRESO
			_medida("batida_preso_s", saiu)
			_relato.append(
				"preso %s" % ("saiu em %.2f s" % saiu if _preso_saiu_em >= 0.0 else "NAO SAIU")
			)
			_confere(
				_preso_saiu_em >= 0.0 and _preso_saiu_em <= SAIDA_MAXIMA,
				(
					(
						"encostada num carro, com gas e guidao pedindo o desvio, a moto levou %.2f s"
						+ " para sair (maximo %.1f s): ela fica presa"
					)
					% [saiu, SAIDA_MAXIMA]
				)
			)
		"moto":
			_relato.append("moto %s a %.0f km/h" % ["CAIU" if _batida_caiu else "quicou", kmh])
			_confere(
				not _batida_caiu,
				"bateu na traseira de um rival a %.0f km/h e caiu: moto nao derruba moto" % kmh
			)
			_batida_obstaculo.set_physics_process(true)


func _medida(chave: String, valor: float) -> void:
	_medidas[chave] = valor


func _confere(condicao: bool, mensagem: String) -> void:
	if not condicao:
		_falhas.append(mensagem)


func _set_action(nome: String, apertado: bool) -> void:
	if apertado and not Input.is_action_pressed(nome):
		Input.action_press(nome)
	elif not apertado and Input.is_action_pressed(nome):
		Input.action_release(nome)
