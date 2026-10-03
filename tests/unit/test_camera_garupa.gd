extends GdUnitTestSuite
## O cinegrafista do modo GARUPA (`CameraGarupa`), dirigido sem arvore.
##
## O banco de provas nao roda camera e a prova visual roda na perseguicao:
## nada do que este modo faz aparece em outro lugar. O que se mede aqui e o
## que faz a filmagem de garupa ser ela, e nao uma perseguicao colada - a
## distancia que respira mas nunca atravessa a moto, a aproximacao lenta, e a
## roda traseira parada na tela (docs/REFERENCIA_CAMERA_GARUPA.md, "Testes").

const PASSO: float = 1.0 / 60.0


## Uma reta de 2 km para -Z: a pista mais simples em que `point()` funciona.
## Sem `build()`: o cinegrafista so amostra a curva, e nao precisa de malha.
func _reta() -> RoadTrack:
	var pista: RoadTrack = auto_free(RoadTrack.new())
	pista.curve = Curve3D.new()
	pista.curve.add_point(Vector3.ZERO)
	pista.curve.add_point(Vector3(0.0, 0.0, -2000.0))
	pista.length = pista.curve.get_baked_length()
	return pista


## O jogador na reta, a `s` metros (do contato traseiro) e `l` do eixo.
func _leitura(s: float, velocidade: float, l: float = 0.0) -> CameraGarupa.Leitura:
	var leitura := CameraGarupa.Leitura.new()
	leitura.s = s
	leitura.l = l
	leitura.velocidade = velocidade
	leitura.contato = Vector3(l, 0.0, -s)
	leitura.frente = Vector3.FORWARD
	return leitura


func test_cruzeiro_converge() -> void:
	var tuning := BikeTuning.new()
	var garupa := CameraGarupa.new(tuning, _reta())
	var s := 50.0
	garupa.reiniciar(_leitura(s, 40.0))
	for i in int(4.0 / PASSO):
		s += 40.0 * PASSO
		garupa.passo(PASSO, _leitura(s, 40.0))
	assert_float(garupa.distancia()).is_equal_approx(tuning.garupa_distancia, 0.05)


func test_freada_nao_atravessa() -> void:
	var tuning := BikeTuning.new()
	var garupa := CameraGarupa.new(tuning, _reta())
	var s := 50.0
	var v := 50.0
	garupa.encaixar(_leitura(s, v))
	var menor := INF
	# Freada do jogador (30) mais forte que a do cinegrafista (20): sem a trava
	# rigida, ele entraria na moto.
	for i in int(3.0 / PASSO):
		v = maxf(v - 30.0 * PASSO, 0.0)
		s += v * PASSO
		garupa.passo(PASSO, _leitura(s, v))
		menor = minf(menor, garupa.distancia())
	assert_float(menor).is_greater_equal(tuning.garupa_distancia_min - 0.0001)


func test_aceleracao_afasta_e_volta() -> void:
	var tuning := BikeTuning.new()
	var garupa := CameraGarupa.new(tuning, _reta())
	var s := 50.0
	var v := 20.0
	garupa.encaixar(_leitura(s, v))
	var maior := 0.0
	# Dois segundos no talo, com a curva de aceleracao da moto
	# (`PlayerBike._update_speed`): forte embaixo, morre perto do teto.
	for i in int(2.0 / PASSO):
		var folga := clampf(1.0 - v / tuning.max_speed, 0.0, 1.0)
		v += tuning.accel * pow(folga, tuning.accel_falloff) * PASSO
		s += v * PASSO
		garupa.passo(PASSO, _leitura(s, v))
		maior = maxf(maior, garupa.distancia())
	# Respira: o cinegrafista acelera menos que a moto e fica para tras.
	assert_float(maior).is_greater(tuning.garupa_distancia + 0.02)
	for i in int(4.0 / PASSO):
		s += v * PASSO
		garupa.passo(PASSO, _leitura(s, v))
	assert_float(garupa.distancia()).is_equal_approx(tuning.garupa_distancia, 0.05)


func test_aproximacao_e_lenta() -> void:
	var tuning := BikeTuning.new()
	var garupa := CameraGarupa.new(tuning, _reta())
	var s := 50.0
	garupa.encaixar(_leitura(s, 30.0))
	garupa.s_c = s - 8.0
	var antes := garupa.distancia()
	var pior := 0.0
	for i in int(5.0 / PASSO):
		s += 30.0 * PASSO
		garupa.passo(PASSO, _leitura(s, 30.0))
		pior = maxf(pior, (antes - garupa.distancia()) / PASSO)
		antes = garupa.distancia()
	assert_float(pior).is_less_equal(tuning.garupa_aproximacao + 0.001)
	# E chega: lenta, nao parada.
	assert_float(garupa.distancia()).is_less(3.0)


func test_queda_recua_e_volta_pela_abertura() -> void:
	var tuning := BikeTuning.new()
	var garupa := CameraGarupa.new(tuning, _reta())
	var s := 50.0
	garupa.encaixar(_leitura(s, 40.0))
	# A moto para na hora; o cinegrafista nao entra nela e recua para o longe.
	var caido := _leitura(s, 0.0)
	caido.caido = true
	for i in int(3.0 / PASSO):
		garupa.passo(PASSO, caido)
		assert_float(garupa.distancia()).is_greater_equal(tuning.garupa_distancia_min - 0.0001)
	assert_float(garupa.distancia()).is_equal_approx(CameraGarupa.DISTANCIA_LONGE, 0.3)
	# O respawn poe a moto 6 m para tras: o cinegrafista larga de novo do longe,
	# e nao fica na frente dela.
	garupa.passo(PASSO, _leitura(s - 6.0, 12.0))
	assert_float(garupa.distancia()).is_greater(tuning.garupa_distancia)


## O pino: com a camera de verdade, a roda traseira nao sai do meio da tela
## enquanto a moto deita de um lado para o outro. O tronco tomba por cima dela.
func test_pino_no_pneu_traseiro() -> void:
	var tuning := BikeTuning.new()
	var pista := _reta()
	var moto: PlayerBike = auto_free(PlayerBike.new())
	add_child(moto)
	moto.setup(tuning, pista, 100.0)
	# Parada: fora da arvore de fisica a moto nao anda, e com velocidade o
	# cinegrafista encostaria nela achando que ela foge.
	var camera: ChaseCamera = auto_free(ChaseCamera.new())
	add_child(camera)
	camera.setup(tuning, moto)
	camera.cycle_mode()
	assert_str(camera.mode_name()).is_equal("GARUPA")
	camera.encaixar()
	var largura := float(camera.get_viewport().get_visible_rect().size.x)
	var pior := 0.0
	for i in int(4.0 / PASSO):
		moto.lean = deg_to_rad(30.0) * sin(TAU * float(i) * PASSO)
		camera._process(PASSO)
		var contato := CameraGarupa.ler(moto).contato
		var x := camera.unproject_position(contato).x / largura
		pior = maxf(pior, absf(x - 0.5))
	assert_float(pior).is_less(0.04)


func test_f2_cicla_os_quatro_modos() -> void:
	var tuning := BikeTuning.new()
	var moto: PlayerBike = auto_free(PlayerBike.new())
	add_child(moto)
	var camera: ChaseCamera = auto_free(ChaseCamera.new())
	add_child(camera)
	camera.setup(tuning, moto)
	var nomes: Array[String] = []
	for i in 5:
		nomes.append(camera.mode_name())
		camera.cycle_mode()
	assert_array(nomes).is_equal(
		["PERSEGUICAO", "GARUPA", "CAPACETE", "DIAGNOSTICO", "PERSEGUICAO"]
	)
