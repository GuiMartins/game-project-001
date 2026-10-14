extends GdUnitTestSuite
## A via expressa (V11b): soma pista, nao tem rua nem gente, e o que bate tem
## colisor.
##
## O muro e a mureta sao o que segura a moto na borda dela. Sem colisor o jogo
## continua rodando e a moto atravessa o mural - e o banco de provas, que roda
## no centro das faixas, nunca chega perto.

const SEMENTE: int = 20260831

var _track: RoadTrack
var _props: Node3D
var _cidade: Cidade


func before_test() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEMENTE
	var extra := RandomNumberGenerator.new()
	extra.seed = 5
	_track = auto_free(RoadTrack.new())
	add_child(_track)
	_track.build(3200.0, rng, Cidade.extra_de_expressas(SEMENTE), extra)
	_props = auto_free(Node3D.new())
	add_child(_props)
	_cidade = Cidade.new(_track)
	var rua := RandomNumberGenerator.new()
	rua.seed = SEMENTE
	_cidade.montar(rua, _props)


func test_a_expressa_soma_pista_e_nao_mexe_na_avenida() -> void:
	# A pista a mais sai de outro gerador: os primeiros 3,2 km sao os mesmos
	# com ou sem ela, e o gerador do mundo sai no mesmo estado, que e de onde
	# vem o transito do banco de provas.
	var rng := RandomNumberGenerator.new()
	rng.seed = SEMENTE
	var sem: RoadTrack = auto_free(RoadTrack.new())
	sem.build(3200.0, rng)
	var depois_sem := rng.randi()
	rng.seed = SEMENTE
	var extra := RandomNumberGenerator.new()
	extra.seed = 5
	var com: RoadTrack = auto_free(RoadTrack.new())
	com.build(3200.0, rng, 800.0, extra)
	assert_int(rng.randi()).is_equal(depois_sem)
	assert_float(com.length).is_greater(sem.length + 700.0)
	assert_float(com.comprimento_da_avenida).is_equal_approx(sem.length, 1.0)
	for o: float in [100.0, 1500.0, 3000.0]:
		assert_float(com.sample_position(o).distance_to(sem.sample_position(o))).is_less(0.5)


func test_toda_expressa_do_plano_entra_na_corrida() -> void:
	var plano := Cidade.plano_de_expressas(SEMENTE)
	assert_int(_track.expressas.size()).is_equal(plano.size())
	for i in plano.size():
		var e := _track.expressas[i]
		assert_float(e.y - e.x).is_equal_approx(plano[i], 0.01)
		assert_float(e.y).is_less(_track.length)


func test_na_expressa_nao_tem_rua_nem_gente() -> void:
	for e in _track.expressas:
		for c in _track.cruzamentos:
			(
				assert_bool(c.x > e.x - Cidade.EXPRESSA_FOLGA and c.x < e.y + Cidade.EXPRESSA_FOLGA)
				. is_false()
			)
	var rua := RandomNumberGenerator.new()
	rua.seed = SEMENTE
	var gente := Pedestres.posicoes(_track, _track.cruzamentos, rua)
	for e in _track.expressas:
		# O eixo da expressa, menos as pontas, onde a calcada da avenida chega.
		var eixo: Array[Vector3] = []
		var o := e.x + 15.0
		while o < e.y - 15.0:
			eixo.append(_track.sample_position(o))
			o += 5.0
		for pose: Array in gente:
			for quem: Array in pose:
				var onde := (quem[0] as Transform3D).origin
				for p in eixo:
					assert_float(onde.distance_to(p)).is_greater(Cidade.RECUO_FACHADA + 9.0)


func test_muro_e_mureta_seguram_a_moto() -> void:
	# Do acostamento para fora, na altura da moto, tem parede dos dois lados
	# no meio de cada expressa.
	var espaco := _track.get_world_3d().direct_space_state
	for e in _track.expressas:
		var o := (e.x + e.y) * 0.5
		for side: float in [-1.0, 1.0]:
			var de := _track.point(o, side * RoadTrack.half_width()) + Vector3.UP * 0.5
			var ate := _track.point(o, side * (RoadTrack.sidewalk_limit() + 3.0)) + Vector3.UP * 0.5
			var raio := PhysicsRayQueryParameters3D.create(de, ate, Layers.WORLD)
			await get_tree().physics_frame
			assert_bool(espaco.intersect_ray(raio).is_empty()).is_false()


func test_o_acostamento_fica_livre() -> void:
	# O acostamento e a fuga do transito fechado: muro e mureta comecam depois.
	assert_float(ViaExpressa.MURETA.x - ViaExpressa.MURETA.z * 0.5).is_greater_equal(0.0)
	assert_float(ViaExpressa.MURO_ALTO.x).is_greater(0.0)


func test_viaduto_chega_de_lado_e_passa_por_cima_da_pista() -> void:
	var v := Vector2(100.0, 400.0)
	assert_float(ViaExpressa.desvio_do_viaduto(v.x, v)).is_equal_approx(
		ViaExpressa.VIADUTO_LONGE, 0.01
	)
	assert_float(ViaExpressa.desvio_do_viaduto(250.0, v)).is_equal_approx(0.0, 0.01)
	# No meio, pela esquerda, a borda de dentro passa do eixo: a sombra cai na
	# pista, e a borda de fora vai alem dos pilares, sobre a pista de servico.
	var bordas := ViaExpressa.bordas_do_viaduto(250.0, v, Cidade.LADO_ESQUERDA)
	assert_float(bordas.x).is_greater(0.0)
	assert_float(bordas.y).is_less(-(RoadTrack.sidewalk_limit() + ViaExpressa.PISTA_AO_LADO.x))
	# A placa verde de 7,4 m nao pode ficar embaixo do tabuleiro de 7.
	var e := Vector3(0.0, 400.0, Cidade.LADO_ESQUERDA)
	var desvio := ViaExpressa.desvio_do_viaduto(Cidade.EXPRESSA_PLACA, Cidade.viaduto_de(e))
	var ponta_do_braco := Portal.BRACO_COMPRIMENTO - Portal.LATERAL
	assert_float(desvio - ViaExpressa.VIADUTO_DENTRO).is_greater(ponta_do_braco + 1.0)


func test_poste_nao_fura_o_viaduto() -> void:
	for e in _track.expressas:
		var v := Cidade.viaduto_de(e)
		var meio := (v.x + v.y) * 0.5
		assert_bool(Cidade.sob_viaduto(_track, meio, e.z)).is_true()
		assert_bool(Cidade.sob_viaduto(_track, meio, -e.z)).is_false()


func test_painel_fica_dentro_da_sua_celula() -> void:
	for painel in ViaExpressa.ATLAS.x * ViaExpressa.ATLAS.y:
		var a := ViaExpressa.uv_do_painel(painel, 0.0, 0.0)
		var b := ViaExpressa.uv_do_painel(painel, 1.0, 1.0)
		var celula := Vector2(painel % ViaExpressa.ATLAS.x, painel / ViaExpressa.ATLAS.x)
		assert_float(a.x * ViaExpressa.ATLAS.x).is_greater(celula.x)
		assert_float(b.x * ViaExpressa.ATLAS.x).is_less(celula.x + 1.0)
		assert_float(a.y * ViaExpressa.ATLAS.y).is_greater(celula.y)
		assert_float(b.y * ViaExpressa.ATLAS.y).is_less(celula.y + 1.0)
