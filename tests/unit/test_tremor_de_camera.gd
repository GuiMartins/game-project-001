extends GdUnitTestSuite
## A regra do tremor de câmera: some devagar, cresce com a velocidade, passa do
## slider só no boost e não existe na queda. Vale para toda câmera.


func test_devagar_e_parado_nao_treme() -> void:
	var tuning := BikeTuning.new()
	for v: float in [0.0, 5.0, tuning.max_speed * TremorDeCamera.COMECA_EM]:
		assert_float(TremorDeCamera.nivel(v, tuning)).is_equal(0.0)


func test_na_velocidade_maxima_vale_o_slider() -> void:
	var tuning := BikeTuning.new()
	assert_float(TremorDeCamera.nivel(tuning.max_speed, tuning)).is_equal_approx(1.0, 0.001)


func test_cresce_com_a_velocidade_sem_degrau() -> void:
	var tuning := BikeTuning.new()
	var antes := 0.0
	for i in 101:
		var v := tuning.max_speed * tuning.boost_speed_mult * float(i) / 100.0
		var agora := TremorDeCamera.nivel(v, tuning)
		assert_float(agora).is_greater_equal(antes)
		assert_float(agora - antes).is_less(0.08)
		antes = agora


func test_o_pico_e_no_boost_cheio() -> void:
	var tuning := BikeTuning.new()
	var cheio := tuning.max_speed * tuning.boost_speed_mult
	assert_float(TremorDeCamera.nivel(cheio, tuning)).is_equal_approx(
		TremorDeCamera.PICO_NO_BOOST, 0.001
	)
	assert_float(TremorDeCamera.nivel(cheio * 2.0, tuning)).is_equal_approx(
		TremorDeCamera.PICO_NO_BOOST, 0.001
	)


func test_caido_nao_treme() -> void:
	var tuning := BikeTuning.new()
	assert_float(TremorDeCamera.nivel(tuning.max_speed, tuning, true)).is_equal(0.0)
