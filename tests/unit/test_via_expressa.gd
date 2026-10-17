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
	# Perto dela, so a rua da esquina de cada ponta.
	var esquinas := Cidade.esquinas_das_expressas(_track.expressas)
	for e in _track.expressas:
		var perto := Vector2(e.x - Cidade.ESQUINA_FOLGA, e.y + Cidade.ESQUINA_FOLGA)
		for c in _track.cruzamentos:
			if c.x > perto.x and c.x < perto.y:
				assert_array(esquinas).contains([c])
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


func test_a_mao_contraria_vem_de_uma_rua_e_vai_para_outra() -> void:
	# Mao contraria que nasce e morre no meio do quarteirao nao e rua. Cada
	# ponta encosta numa transversal, so do lado do viaduto: a boca da rua
	# acaba onde a expressa comeca, e comeca onde ela acaba. Ali nao ha zebra.
	for e in _track.expressas:
		var entrada := Vector2(e.x - Cidade.RUA_LARGURA * 0.5, e.z)
		var saida := Vector2(e.y + Cidade.RUA_LARGURA * 0.5, e.z)
		assert_array(_track.cruzamentos).contains([entrada, saida])
		assert_float(entrada.x + _track.boca).is_equal_approx(e.x, 0.01)
		assert_float(saida.x - _track.boca).is_equal_approx(e.y, 0.01)
		assert_bool(_track.e_esquina(entrada) and _track.e_esquina(saida)).is_true()


func test_a_mao_contraria_e_sempre_a_esquerda() -> void:
	# Aqui se anda pela direita: quem vem de frente vem pela esquerda.
	for e in _track.expressas:
		assert_float(e.z).is_equal(Cidade.LADO_ESQUERDA)


func test_metade_da_pista_e_mao_contraria() -> void:
	# A pista tem a mesma largura dentro e fora da expressa: dentro, a metade
	# do lado do viaduto e mao contraria, e quem escolhe faixa fica na outra -
	# ja no zebrado antes da rua da esquina.
	for e in _track.expressas:
		var meio := (e.x + e.y) * 0.5
		var lado_dela := RoadTrack.lane_center(0) * -e.z
		assert_bool(_track.na_contramao(meio, lado_dela)).is_true()
		assert_bool(_track.na_contramao(meio, -lado_dela)).is_false()
		for o: float in [meio, e.x - _track.boca * 2.0 - 1.0]:
			var mao := _track.mao_entre(o, o)
			assert_bool(mao.x <= -lado_dela and -lado_dela <= mao.y).is_true()
			assert_bool(mao.x <= lado_dela and lado_dela <= mao.y).is_false()
		# Longe dela, a pista inteira.
		var antes := e.x - _track.boca * 2.0 - RoadTrack.ZEBRADO - 50.0
		assert_vector(_track.mao_entre(antes, antes)).is_equal(
			Vector2(-RoadTrack.half_width(), RoadTrack.half_width())
		)


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


func test_a_segunda_separa_as_maos_com_pilares() -> void:
	# A primeira expressa separa as maos so com tinta: a moto atravessa o eixo.
	# A segunda, com mureta e os pilares do viaduto no meio: nao atravessa.
	var espaco := _track.get_world_3d().direct_space_state
	assert_int(_track.expressas.size()).is_greater_equal(2)
	for i in 2:
		var e := _track.expressas[i]
		var o := (e.x + e.y) * 0.5
		var de := _track.point(o, 2.0) + Vector3.UP * 0.5
		var ate := _track.point(o, -2.0) + Vector3.UP * 0.5
		var raio := PhysicsRayQueryParameters3D.create(de, ate, Layers.WORLD)
		await get_tree().physics_frame
		assert_bool(espaco.intersect_ray(raio).is_empty()).is_equal(i == 0)
		assert_bool(_track.pilares_no_meio[i]).is_equal(i == 1)
	# E quem escolhe faixa fica mais longe do eixo onde ha pilar.
	var meio_1 := (_track.expressas[1].x + _track.expressas[1].y) * 0.5
	var meio_0 := (_track.expressas[0].x + _track.expressas[0].y) * 0.5
	var com_pilar := _track.mao_entre(meio_1, meio_1)
	var com_tinta := _track.mao_entre(meio_0, meio_0)
	assert_float(absf(com_pilar.x) + absf(com_pilar.y)).is_greater(0.0)
	assert_float(minf(absf(com_pilar.x), absf(com_pilar.y))).is_greater(
		minf(absf(com_tinta.x), absf(com_tinta.y))
	)


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
	# pista, e a borda de fora vai alem dos pilares.
	var bordas := ViaExpressa.bordas_do_viaduto(250.0, v, Cidade.LADO_ESQUERDA)
	assert_float(bordas.x).is_greater(0.0)
	var pilar := RoadTrack.sidewalk_limit() + ViaExpressa.PILAR_AFASTAMENTO + ViaExpressa.PILAR.x
	assert_float(bordas.y).is_less(-pilar)
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
