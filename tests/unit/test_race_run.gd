extends GdUnitTestSuite
## Regras da corrida, testadas sem abrir o jogo.
##
## RaceRun e RefCounted puro: colocacao, prazo, bag, combo e estrelas nao
## dependem de cena, fisica nem pista. O banco de provas roda a moto de verdade
## e leva ~100 s; estas regras cabem em milissegundos, e sao justamente as que
## uma IA mexe sem perceber o efeito - "so aumentei um pouco o multiplicador".


func _corrida(distancia: float = 1000.0, pilotos: int = 6) -> RaceRun:
	var corrida := RaceRun.new()
	corrida.start(distancia, pilotos)
	return corrida


func test_prazo_sai_da_distancia() -> void:
	var corrida := _corrida(1000.0)
	# 0.055 s/m exige ~65 km/h de media: da pra entregar dirigindo limpo.
	assert_float(corrida.time_total).is_equal_approx(55.0, 0.001)
	assert_float(corrida.time_left).is_equal_approx(55.0, 0.001)
	assert_int(corrida.phase).is_equal(RaceRun.Phase.RACING)
	# Largada em ultimo: a posicao so melhora quando alguem for ultrapassado.
	assert_int(corrida.position).is_equal(6)
	assert_int(corrida.racers).is_equal(6)


func test_cruzar_a_linha_encerra_a_corrida() -> void:
	var corrida := _corrida(1000.0)
	corrida.tick(1.0, 1000.0)
	assert_int(corrida.phase).is_equal(RaceRun.Phase.FINISHED)
	assert_float(corrida.finish_time).is_equal_approx(1.0, 0.001)


func test_estourar_o_prazo_nao_encerra_a_corrida() -> void:
	# Numa corrida quem decide o fim e a linha de chegada. O prazo estourado
	# cobra estrelas; parar a corrida no cronometro tiraria do jogador a
	# unica coisa que ainda estava em disputa, que e a posicao.
	var corrida := _corrida(1000.0)
	corrida.tick(999.0, 10.0)
	assert_int(corrida.phase).is_equal(RaceRun.Phase.RACING)
	assert_bool(corrida.late).is_true()
	assert_float(corrida.time_left).is_equal(0.0)


func test_atraso_limita_a_nota_mesmo_vencendo() -> void:
	var corrida := _corrida(1000.0)
	corrida.tick(999.0, 10.0)  # estourou o prazo
	corrida.update_position(1)
	corrida.tick(1.0, 1000.0)
	# Primeiro lugar com a bag inteira, mas atrasado: no maximo tres estrelas.
	assert_int(corrida.stars()).is_equal(3)


func test_posicao_conta_ultrapassagem_so_pra_frente() -> void:
	var corrida := _corrida()
	assert_int(corrida.update_position(4)).is_equal(2)
	assert_int(corrida.overtakes).is_equal(2)
	# Ser ultrapassado devolve a posicao, mas nao desconta o que ja foi feito.
	assert_int(corrida.update_position(5)).is_equal(-1)
	assert_int(corrida.overtakes).is_equal(2)
	assert_int(corrida.position).is_equal(5)


func test_quem_cruzou_a_linha_fica_na_frente_de_quem_ainda_corre() -> void:
	var chegou := RaceRun.rank_key(3200.0, 71.2)
	var quase := RaceRun.rank_key(3199.0, -1.0)
	assert_float(chegou).is_greater(quase)
	# Entre os que chegaram, ganha quem cruzou primeiro.
	var chegou_depois := RaceRun.rank_key(3200.0, 71.3)
	assert_float(chegou).is_greater(chegou_depois)


func test_colocacao_conta_quem_esta_na_frente() -> void:
	var chaves: Array[float] = [1200.0, 980.0, 1310.0, 1010.0]
	assert_int(RaceRun.position_of(1310.0, chaves)).is_equal(1)
	assert_int(RaceRun.position_of(1010.0, chaves)).is_equal(3)
	assert_int(RaceRun.position_of(980.0, chaves)).is_equal(4)


func test_vencer_limpo_e_no_prazo_da_cinco_estrelas() -> void:
	var corrida := _corrida(1000.0)
	corrida.update_position(1)
	corrida.tick(5.0, 1000.0)  # chegou gastando 5 s dos 55
	corrida.style = 2500.0
	assert_int(corrida.stars()).is_equal(5)


func test_chegar_em_ultimo_nao_da_cinco_estrelas() -> void:
	# Mesma corrida perfeita da de cima, so que em ultimo: a posicao pesa
	# metade da nota, senao o jogo deixa de ser uma corrida.
	var corrida := _corrida(1000.0)
	corrida.tick(5.0, 1000.0)
	corrida.style = 2500.0
	assert_int(corrida.stars()).is_less(5)


func test_combo_multiplica_ate_oito() -> void:
	var corrida := _corrida()
	# Passar por dez carros de uma vez tem que valer muito mais que dez
	# raspadas separadas, senao o corredor nao seduz - e o corredor e o jogo.
	for i in 3:
		corrida.register_near_miss()
	assert_float(corrida.style).is_equal_approx(10.0 + 20.0 + 30.0, 0.001)

	var sozinho := _corrida()
	sozinho.register_near_miss()
	assert_float(sozinho.style).is_equal_approx(10.0, 0.001)
	assert_int(sozinho.combo).is_equal(1)


func test_combo_para_de_crescer_em_oito() -> void:
	var corrida := _corrida()
	for i in 12:
		corrida.register_near_miss()
	# 1+2+...+8 = 36, e da nona em diante continua valendo 8.
	var esperado := 10.0 * (36.0 + 4.0 * 8.0)
	assert_float(corrida.style).is_equal_approx(esperado, 0.001)
	assert_int(corrida.near_misses).is_equal(12)


func test_combo_expira_sozinho() -> void:
	var corrida := _corrida()
	corrida.register_near_miss()
	corrida.register_near_miss()
	assert_int(corrida.combo).is_equal(2)
	corrida.tick(3.0, 10.0)  # janela do combo e 2.2 s
	assert_int(corrida.combo).is_equal(0)


func test_queda_zera_o_combo_e_come_a_bag() -> void:
	var corrida := _corrida()
	corrida.register_near_miss()
	corrida.register_near_miss()
	corrida.register_crash()
	assert_int(corrida.combo).is_equal(0)
	assert_float(corrida.bag).is_equal_approx(100.0 - RaceRun.BAG_LOSS_CRASH, 0.001)
	assert_int(corrida.crashes).is_equal(1)


func test_bag_nunca_fica_negativa() -> void:
	var corrida := _corrida()
	for i in 20:
		corrida.register_crash()
	assert_float(corrida.bag).is_equal(0.0)
	# Estilo tambem tem piso: cair muito nao deixa a nota abaixo de zero.
	assert_float(corrida.style).is_greater_equal(0.0)


func test_raspada_cobra_proporcional_a_intensidade() -> void:
	var leve := _corrida()
	leve.register_scrape(0.2)
	var forte := _corrida()
	forte.register_scrape(1.0)
	assert_float(forte.bag).is_less(leve.bag)
	# A intensidade e grampeada em 0.2..1.0: raspada de raspao ainda custa.
	var raspao := _corrida()
	raspao.register_scrape(0.0)
	assert_float(raspao.bag).is_equal_approx(leve.bag, 0.001)


func test_rival_derrubado_vale_estilo() -> void:
	var corrida := _corrida()
	corrida.register_rival_down()
	assert_int(corrida.rivals_downed).is_equal(1)
	assert_float(corrida.style).is_equal_approx(150.0, 0.001)
