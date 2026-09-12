extends GdUnitTestSuite
## Geometria da pista: faixas, corredores e o limite da calcada.
##
## Sao funcoes estaticas puras, e o que elas devolvem e a definicao de onde o
## corredor fica. Mexer em LANE_WIDTH ou SHOULDER sem perceber o efeito aqui e
## mexer no pilar do jogo - e o banco de provas nao pega, porque o piloto
## automatico so mira centros de faixa e nunca sobe na calcada.


func test_faixas_sao_simetricas_em_torno_do_eixo() -> void:
	# Quatro faixas: as duas de fora tem que estar a mesma distancia do eixo,
	# uma pra cada lado. Se nao estiverem, a pista esta torta em relacao a
	# curva e toda medida lateral passa a mentir.
	var esquerda := RoadTrack.lane_center(0)
	var direita := RoadTrack.lane_center(RoadTrack.LANE_COUNT - 1)
	assert_float(esquerda).is_equal_approx(-direita, 0.0001)
	assert_float(esquerda).is_less(0.0)


func test_faixas_ficam_a_uma_largura_de_distancia() -> void:
	for i in RoadTrack.LANE_COUNT - 1:
		var passo := RoadTrack.lane_center(i + 1) - RoadTrack.lane_center(i)
		assert_float(passo).is_equal_approx(RoadTrack.LANE_WIDTH, 0.0001)


func test_corredor_fica_no_meio_de_duas_faixas() -> void:
	for i in RoadTrack.LANE_COUNT - 1:
		var meio := (RoadTrack.lane_center(i) + RoadTrack.lane_center(i + 1)) * 0.5
		assert_float(RoadTrack.corridor_center(i)).is_equal_approx(meio, 0.0001)


func test_toda_faixa_cabe_dentro_do_asfalto() -> void:
	var limite := RoadTrack.half_width()
	for i in RoadTrack.LANE_COUNT:
		var centro := RoadTrack.lane_center(i)
		# A faixa inteira, nao so o centro: borda de fora dentro do asfalto.
		assert_float(absf(centro) + RoadTrack.LANE_WIDTH * 0.5).is_less_equal(limite + 0.0001)


func test_calcada_comeca_onde_o_asfalto_acaba() -> void:
	# O limite andavel coincide com onde o terreno cai 0.35 m, que o jogador
	# ve. Enquanto era half_width + SHOULDER*0.6, a parede invisivel ficava no
	# meio do acostamento - uma coisa com cara de andavel que nao era.
	assert_float(RoadTrack.sidewalk_limit()).is_equal_approx(
		RoadTrack.half_width() + RoadTrack.SHOULDER, 0.0001
	)
	assert_float(RoadTrack.sidewalk_limit()).is_greater(RoadTrack.half_width())


func test_sobra_espaco_de_moto_na_calcada() -> void:
	# A moto tem 0.75 m de largura. Se a faixa de calcada nao comportar ela com
	# folga, a valvula de escape do transito fechado deixa de existir.
	var largura_calcada := RoadTrack.sidewalk_limit() - RoadTrack.half_width()
	assert_float(largura_calcada).is_greater(0.75 * 1.5)


func test_rampa_maxima_e_jogavel() -> void:
	# 14% cobra gas na subida e devolve na descida. Acima de ~20% a moto sobe
	# empinada e desce voando, e a ladeira deixa de ser tempero.
	assert_float(RoadTrack.MAX_GRADE).is_greater(0.05)
	assert_float(RoadTrack.MAX_GRADE).is_less_equal(0.2)
