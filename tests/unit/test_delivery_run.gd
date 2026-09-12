extends GdUnitTestSuite
## Regras do loop de entrega, testadas sem abrir o jogo.
##
## DeliveryRun e RefCounted puro: prazo, bag, combo e estrelas nao dependem de
## cena, fisica nem pista. O banco de provas roda a moto de verdade e leva
## 89 s; estas regras cabem em milissegundos, e sao justamente as que uma IA
## mexe sem perceber o efeito - "so aumentei um pouco o multiplicador".


func _corrida(distancia: float = 1000.0) -> DeliveryRun:
	var corrida := DeliveryRun.new()
	corrida.start(distancia)
	return corrida


func test_prazo_sai_da_distancia() -> void:
	var corrida := _corrida(1000.0)
	# 0.055 s/m exige ~65 km/h de media: da pra entregar dirigindo limpo.
	assert_float(corrida.time_total).is_equal_approx(55.0, 0.001)
	assert_float(corrida.time_left).is_equal_approx(55.0, 0.001)
	assert_int(corrida.phase).is_equal(DeliveryRun.Phase.RIDING)


func test_chegar_no_fim_entrega() -> void:
	var corrida := _corrida(1000.0)
	corrida.tick(1.0, 999.5)
	assert_int(corrida.phase).is_equal(DeliveryRun.Phase.DELIVERED)


func test_estourar_o_prazo_reprova() -> void:
	var corrida := _corrida(100.0)
	corrida.tick(999.0, 10.0)
	assert_int(corrida.phase).is_equal(DeliveryRun.Phase.FAILED)
	assert_float(corrida.time_left).is_equal(0.0)
	# Corrida reprovada e sempre uma estrela, por melhor que fosse ate ali.
	assert_int(corrida.stars()).is_equal(1)


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
	assert_float(corrida.bag).is_equal_approx(100.0 - DeliveryRun.BAG_LOSS_CRASH, 0.001)
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


func test_corrida_limpa_e_rapida_da_cinco_estrelas() -> void:
	var corrida := _corrida(1000.0)
	corrida.tick(5.0, 999.5)  # chegou gastando 5 s dos 55
	corrida.style = 2500.0
	assert_int(corrida.stars()).is_equal(5)


func test_chegar_no_sufoco_e_com_a_bag_destruida_nao_da_cinco() -> void:
	var corrida := _corrida(1000.0)
	corrida.tick(54.0, 999.5)
	corrida.bag = 10.0
	assert_int(corrida.stars()).is_less(3)


func test_rival_derrubado_vale_estilo() -> void:
	var corrida := _corrida()
	corrida.register_rival_down()
	assert_int(corrida.rivals_downed).is_equal(1)
	assert_float(corrida.style).is_equal_approx(150.0, 0.001)
