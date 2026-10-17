extends GdUnitTestSuite
## O GPS da HUD (V25a): o mapa gira com a moto, e o nome sai da pista.

var _track: RoadTrack


func before_test() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260831
	_track = auto_free(RoadTrack.new())
	add_child(_track)
	_track.build(3200.0, rng)
	var props: Node3D = auto_free(Node3D.new())
	add_child(props)
	Cidade.new(_track).montar(rng, props)


## Heading-up: o que esta na frente da moto fica em cima da seta, e o que esta
## a direita fica a direita, para qualquer rumo.
func test_o_mapa_gira_com_a_moto() -> void:
	var centro := Vector2(36, 47)
	for rumo: float in [0.0, 0.7, PI * 0.5, 2.5, -1.2]:
		var frente := Vector3(sin(rumo), 0.0, cos(rumo))
		var direita := frente.cross(Vector3.UP)
		var moto := Vector3(100.0, 3.0, -40.0)
		var adiante := Gps.no_mapa(moto + frente * 24.0, moto, frente, direita, centro)
		assert_vector(adiante).is_equal_approx(centro + Vector2(0, -10), Vector2(0.01, 0.01))
		var ao_lado := Gps.no_mapa(moto + direita * 24.0, moto, frente, direita, centro)
		assert_vector(ao_lado).is_equal_approx(centro + Vector2(10, 0), Vector2(0.01, 0.01))


func test_a_avenida_tem_nome_e_a_expressa_tem_o_dela() -> void:
	assert_array(Cidade.AVENIDAS).contains([_track.nome])
	assert_int(_track.nomes_das_expressas.size()).is_equal(_track.expressas.size())
	assert_int(_track.expressas.size()).is_greater(0)
	var e := _track.expressas[0]
	assert_str(_track.nome_em((e.x + e.y) * 0.5)).is_equal(_track.nomes_das_expressas[0])
	assert_str(_track.nome_em(e.x - 30.0)).is_equal(_track.nome)
	assert_array(Cidade.VIAS_EXPRESSAS).contains([_track.nomes_das_expressas[0]])


## A placa verde aponta para outras vias: a avenida em que o jogador esta nao
## pode ser destino dela.
func test_nome_nenhum_e_destino_da_placa_verde() -> void:
	var destinos: Array[String] = []
	for linha: Array in Portal.DESTINOS:
		for d: String in linha:
			destinos.append(d.to_upper())
	for nome: String in Cidade.AVENIDAS + Cidade.VIAS_EXPRESSAS:
		assert_bool(destinos.has(nome)).override_failure_message(nome).is_false()


func test_o_mapa_acompanha_a_moto_na_pista() -> void:
	var moto: Node3D = auto_free(Node3D.new())
	add_child(moto)
	moto.global_transform = _track.transform_at(0.0, 2.0)
	var gps: Gps = auto_free(Gps.new())
	add_child(gps)
	gps.ligar(_track, moto)
	# A busca e local (`RoadTrack.project`): o palpite anda quadro a quadro,
	# como a moto anda. A 180 km/h sao 0,8 m por quadro; aqui, 4.
	var o := 0.0
	while o < 600.0:
		o += 4.0
		moto.global_transform = _track.transform_at(o, 2.0)
		gps._process(0.016)
	assert_float(gps.progresso).is_equal_approx(600.0, 1.0)
