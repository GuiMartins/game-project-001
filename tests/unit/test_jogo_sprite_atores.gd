extends GdUnitTestSuite
## O playground do testador (`JogoSprite`), a segunda parte: o desenho em todo
## ator, a moto jogavel, a largada e as cameras. A primeira, em
## `test_jogo_sprite.gd`, e a da pessoa: andar, atropelo, susto e o carro.

const PASSO: float = 1.0 / 60.0

var _jogo: JogoSprite


func before_test() -> void:
	_jogo = auto_free(JogoSprite.new())
	add_child(_jogo)
	# A fisica anda a mao, passo a passo, para o teste nao depender de relogio.
	_jogo.set_physics_process(false)
	_jogo.pessoa.set_physics_process(false)


func _roda_a_pessoa(passos: int, pessoa: Pessoa = null) -> void:
	var alvo := pessoa if pessoa != null else _jogo.pessoa
	for i in passos:
		alvo._physics_process(PASSO)


func test_trocar_o_desenho_vale_para_todo_ator() -> void:
	_jogo.sprite = false
	_jogo.cadencia_hz = 15.0
	assert_float(_jogo.pessoa.cadencia).is_equal(15.0)
	_jogo.sprite = true
	_jogo.passar_uma_moto(25.0, 3.0)
	for no in _jogo.get_children():
		if no is MotoFantasma:
			assert_bool((no as MotoFantasma).sprite).is_true()


func test_a_moto_jogavel_acelera_pela_pista() -> void:
	_jogo.ator = JogoSprite.Ator.MOTO
	_jogo.moto.set_physics_process(false)
	var z_inicial := _jogo.moto.global_position.z
	Input.action_press("ride_throttle")
	for i in 180:
		_jogo.moto._physics_process(PASSO)
	Input.action_release("ride_throttle")
	assert_float(_jogo.moto.speed).is_greater(10.0)
	# So o sentido, e nao a distancia: o `move_and_slide` chamado fora de um quadro
	# de fisica anda com o delta do quadro de *processo*, que no CI (sem tela, quadro
	# de meio milissegundo) e uns 30 vezes menor que 1/60. A moto andou 1,4 m numa
	# corrida de 180 passos no Ubuntu e 5 m ou mais no resto; a velocidade acima ja
	# cobre o "acelera".
	assert_float(_jogo.moto.global_position.z).is_less(z_inicial - 0.05)


func test_so_um_ator_responde_aos_controles() -> void:
	assert_bool(_jogo.moto.is_physics_processing()).is_false()
	_jogo.ator = JogoSprite.Ator.MOTO
	assert_bool(_jogo.moto.is_physics_processing()).is_true()
	_jogo.ator = JogoSprite.Ator.PESSOA
	assert_bool(_jogo.moto.is_physics_processing()).is_false()


func test_a_moto_volta_ao_inicio_parada() -> void:
	_jogo.moto.place_on_track(300.0, 0.0, 30.0)
	_jogo.reiniciar_a_moto()
	assert_float(_jogo.moto.speed).is_equal(0.0)
	assert_float(_jogo.moto.track_offset).is_equal(0.0)


func test_a_largada_poe_a_fiscal_na_frente_da_moto_e_depois_a_tira() -> void:
	_jogo.largada()
	assert_object(_jogo.fiscal).is_not_null()
	assert_float(_jogo.fiscal.position.z).is_equal_approx(-JogoSprite.LARGADA_EM, 0.5)
	for i in int((JogoSprite.LARGADA_DURA + 0.5) / PASSO):
		_jogo._physics_process(PASSO)
	assert_int(_jogo.fiscal.estado).is_equal(Pessoa.Estado.ANDANDO)


func test_o_playground_so_acende_a_camera_do_ator_conduzido() -> void:
	_jogo.ator = JogoSprite.Ator.MOTO
	assert_bool(_jogo._camera_da_moto.current).is_true()
	_jogo.ator = JogoSprite.Ator.PESSOA
	assert_bool(_jogo._camera_da_pessoa.current).is_true()
