extends GdUnitTestSuite
## O playground do testador (`JogoSprite`): a pessoa que se conduz, o atropelo, o
## susto, a saida do carro e a moto jogavel.
##
## Cada um chama a classe do jogo (`Pessoa`, `Carro`, `PlayerBike`), entao o que
## se fixa aqui e a cola: que o botao faz o que o nome diz, e que um estado nao
## fica preso (quem foi atropelada precisa poder levantar).

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


func test_a_pessoa_nasce_de_pe_no_meio_da_pista() -> void:
	assert_int(_jogo.pessoa.estado).is_equal(Pessoa.Estado.PARADA)
	assert_float(_jogo.pessoa.position.z).is_equal(-JogoSprite.PESSOA_EM)


func test_w_leva_a_pessoa_para_a_frente_da_camera() -> void:
	var antes := _jogo.pessoa.position
	for i in 120:
		_jogo.mover(Vector2(0.0, 1.0))
		_roda_a_pessoa(1)
	assert_int(_jogo.pessoa.estado).is_equal(Pessoa.Estado.ANDANDO)
	# A camera olha para -Z: frente e -Z.
	assert_float(_jogo.pessoa.position.z).is_less(antes.z - 2.0)
	assert_float(absf(_jogo.pessoa.position.x - antes.x)).is_less(0.1)


func test_d_leva_para_a_direita_da_camera() -> void:
	var antes := _jogo.pessoa.position
	for i in 60:
		_jogo.mover(Vector2(1.0, 0.0))
		_roda_a_pessoa(1)
	assert_float(_jogo.pessoa.position.x).is_greater(antes.x + 1.0)


func test_a_camera_girada_gira_o_que_e_frente() -> void:
	_jogo.camera_yaw_graus = 90.0
	var antes := _jogo.pessoa.position
	for i in 60:
		_jogo.mover(Vector2(0.0, 1.0))
		_roda_a_pessoa(1)
	# Com a camera em +X olhando para -X, a frente dela e -X.
	assert_float(_jogo.pessoa.position.x).is_less(antes.x - 1.0)


func test_correr_anda_mais_que_caminhar() -> void:
	var a := JogoSprite.new()
	auto_free(a)
	add_child(a)
	a.set_physics_process(false)
	a.pessoa.set_physics_process(false)
	for i in 60:
		_jogo.mover(Vector2(0.0, 1.0), false)
		_roda_a_pessoa(1)
		a.mover(Vector2(0.0, 1.0), true)
		a.pessoa._physics_process(PASSO)
	assert_float(a.pessoa.position.z).is_less(_jogo.pessoa.position.z)


func test_soltar_a_tecla_para_a_pessoa() -> void:
	for i in 30:
		_jogo.mover(Vector2(0.0, 1.0))
		_roda_a_pessoa(1)
	_jogo.mover(Vector2.ZERO)
	_roda_a_pessoa(1)
	assert_int(_jogo.pessoa.estado).is_equal(Pessoa.Estado.PARADA)


func test_atropelar_faz_a_pessoa_voar_e_cair() -> void:
	_jogo.atropelar(25.0)
	assert_int(_jogo.pessoa.estado).is_equal(Pessoa.Estado.VOANDO)
	_roda_a_pessoa(400)
	assert_int(_jogo.pessoa.estado).is_equal(Pessoa.Estado.CAIDA)
	# Para a frente da moto, que vem de tras: -Z.
	assert_float(_jogo.pessoa.position.z).is_less(-JogoSprite.PESSOA_EM - 3.0)


func test_atropelada_nao_anda_ate_levantar() -> void:
	_jogo.atropelar(25.0)
	_roda_a_pessoa(400)
	_jogo.mover(Vector2(0.0, 1.0))
	assert_int(_jogo.pessoa.estado).is_equal(Pessoa.Estado.CAIDA)
	_jogo.nova_pessoa()
	assert_int(_jogo.pessoa.estado).is_equal(Pessoa.Estado.PARADA)
	assert_float(_jogo.pessoa.position.z).is_equal(-JogoSprite.PESSOA_EM)


func test_a_moto_que_passa_de_raspao_assusta_e_nao_atropela() -> void:
	_jogo.passar_uma_moto(25.0, 1.0)
	var fantasma: MotoFantasma = null
	for no in _jogo.get_children():
		if no is MotoFantasma:
			fantasma = no
	assert_object(fantasma).is_not_null()
	var assustou := false
	for i in 300:
		fantasma._physics_process(PASSO)
		_roda_a_pessoa(1)
		assustou = assustou or _jogo.pessoa.estado == Pessoa.Estado.SUSTO
	assert_bool(assustou).is_true()
	assert_int(_jogo.pessoa.estado).is_not_equal(Pessoa.Estado.CAIDA)


func test_a_moto_de_longe_nao_mexe_com_ela() -> void:
	_jogo.passar_uma_moto(25.0, 4.0)
	var fantasma: MotoFantasma = null
	for no in _jogo.get_children():
		if no is MotoFantasma:
			fantasma = no
	for i in 300:
		fantasma._physics_process(PASSO)
		_roda_a_pessoa(1)
		assert_int(_jogo.pessoa.estado).is_equal(Pessoa.Estado.PARADA)


func test_sair_do_carro_pela_calcada_chega_a_calcada() -> void:
	_jogo.sair_do_carro(1)
	var pessoa := _jogo.quem_desceu()
	assert_object(pessoa).is_not_null()
	pessoa.set_physics_process(false)
	for i in 600:
		_jogo.carro.atualizar(PASSO, 0.0, 0.0, true, 0)
		_roda_a_pessoa(1, pessoa)
	# Em X do carro: a calcada fica a direita dele, alem da borda do asfalto.
	var x_no_mundo := _jogo.carro.to_global(pessoa.position).x
	assert_float(x_no_mundo).is_greater(RoadTrack.half_width())


func test_sair_do_carro_do_lado_da_rua_contorna_a_traseira() -> void:
	_jogo.sair_do_carro(-1)
	var pessoa := _jogo.quem_desceu()
	pessoa.set_physics_process(false)
	var passou_por_tras := false
	for i in 900:
		_jogo.carro.atualizar(PASSO, 0.0, 0.0, true, 0)
		_roda_a_pessoa(1, pessoa)
		passou_por_tras = passou_por_tras or pessoa.position.z > _jogo.carro.caixa().end.z
	assert_bool(passou_por_tras).is_true()


func test_sair_do_carro_duas_vezes_refaz_o_carro_e_ninguem_fica_preso() -> void:
	_jogo.sair_do_carro(1)
	var primeiro := _jogo.carro
	_jogo.sair_do_carro(1)
	assert_object(_jogo.carro).is_not_same(primeiro)
	assert_object(_jogo.quem_desceu()).is_not_null()


func test_a_pessoa_do_carro_segue_o_sprite_e_a_cadencia() -> void:
	_jogo.sprite = false
	_jogo.cadencia_hz = 8.0
	_jogo.sair_do_carro(1)
	var desceu := _jogo.quem_desceu()
	assert_float(desceu.cadencia).is_equal(8.0)
