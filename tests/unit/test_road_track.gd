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


func test_corredor_deixa_folga_para_a_moto() -> void:
	# Carros de 1,8 m ladeando a moto de 0,75 m precisam deixar margem para
	# corrigir a trajetoria; a rodada jogada pediu ao menos 0,75 m por lado.
	var folga_por_lado := (RoadTrack.LANE_WIDTH - 1.8 - PlayerBike.SIZE.x) * 0.5
	assert_float(folga_por_lado).is_greater_equal(0.75)


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


## As faixas a mais da via expressa (V37). A avenida de quatro e as faixas que
## ja existiam tem que ficar onde estavam: o alargamento so soma do lado de
## fora, e some nas pontas.
func test_alargamento_zero_nas_pontas_e_cheio_no_miolo() -> void:
	var de := 1000.0
	var ate := 1600.0
	assert_float(RoadTrack.alargamento(de, de, ate)).is_equal(0.0)
	assert_float(RoadTrack.alargamento(ate, de, ate)).is_equal(0.0)
	var meio := RoadTrack.alargamento((de + ate) * 0.5, de, ate)
	assert_float(meio).is_equal(RoadTrack.EXPRESSA_EXTRA)
	# Sem degrau: cresce sem nunca andar mais que uma faixa em 10 m.
	var o := de
	while o < de + RoadTrack.EXPRESSA_RAMPA:
		var passo := RoadTrack.alargamento(o + 1.0, de, ate) - RoadTrack.alargamento(o, de, ate)
		assert_float(passo).is_between(0.0, RoadTrack.LANE_WIDTH * 0.1)
		o += 1.0


func test_expressa_so_aumenta_o_limite_do_lado_fechado_e_so_no_miolo() -> void:
	var pista := RoadTrack.new()
	pista.expressas = [Vector3(1000.0, 1600.0, -1.0)]
	pista.boca = 5.0
	var hw := RoadTrack.half_width()
	var miolo := pista.mao_entre(1200.0, 1300.0)
	assert_float(miolo.y).is_equal_approx(hw + RoadTrack.EXPRESSA_EXTRA, 0.001)
	# O lado da mao contraria e as faixas de dentro nao se mexem.
	assert_float(miolo.x).is_equal_approx(RoadTrack.FOLGA_DA_DUPLA, 0.001)
	# Janela que pega a rampa: de volta a pista de quatro.
	assert_float(pista.mao_entre(1000.0, 1100.0).y).is_equal_approx(hw, 0.001)
	# Fora da expressa nada muda.
	var fora := pista.mao_entre(100.0, 200.0)
	assert_float(fora.y).is_equal_approx(hw, 0.001)
	assert_float(fora.x).is_equal_approx(-hw, 0.001)
	pista.free()
