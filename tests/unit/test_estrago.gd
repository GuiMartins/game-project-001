extends GdUnitTestSuite
## Faisca, poeira, fogo e estalo (`Estrago`): cada efeito no evento dele, e
## nada fora dele.

const PASSO: float = 1.0 / 60.0


func _estrago() -> Estrago:
	var e: Estrago = auto_free(Estrago.new())
	add_child(e)
	return e


func _passa(e: Estrago, segundos: float, caido: bool, deslize: float) -> void:
	for i in int(segundos / PASSO):
		e.atualizar(PASSO, caido, deslize)


func test_em_pe_e_sem_raspar_nao_solta_nada() -> void:
	var e := _estrago()
	_passa(e, 1.0, false, 0.0)
	assert_bool(e.emitindo_faisca()).is_false()
	assert_bool(e.pegou_fogo()).is_false()
	assert_bool(e.luz_acesa()).is_false()


func test_raspada_e_um_tranco_de_faisca() -> void:
	var e := _estrago()
	e.faisca(1.0)
	e.atualizar(PASSO, false, 0.0)
	assert_bool(e.emitindo_faisca()).is_true()
	_passa(e, Estrago.RASPADA.y + 0.05, false, 0.0)
	assert_bool(e.emitindo_faisca()).is_false()


func test_moto_deitada_arrastando_solta_faisca_ate_parar() -> void:
	var e := _estrago()
	e.cair(0.2)
	_passa(e, 0.2, true, 12.0)
	assert_bool(e.emitindo_faisca()).is_true()
	_passa(e, 0.2, true, Estrago.DESLIZE_MINIMO - 0.5)
	assert_bool(e.emitindo_faisca()).is_false()


func test_queda_devagar_nao_pega_fogo() -> void:
	var e := _estrago()
	e.cair(Estrago.FOGO - 0.1)
	_passa(e, 1.0, true, 0.0)
	assert_bool(e.pegou_fogo()).is_false()
	assert_bool(e.luz_acesa()).is_false()


func test_queda_rapida_pega_fogo_e_apaga_quando_levanta() -> void:
	var e := _estrago()
	e.cair(0.8)
	_passa(e, 1.0, true, 0.0)
	assert_bool(e.pegou_fogo()).is_true()
	assert_bool(e.luz_acesa()).is_true()
	_passa(e, Estrago.FOGO_PEGA + 0.1, false, 0.0)
	assert_bool(e.pegou_fogo()).is_false()
	assert_bool(e.luz_acesa()).is_false()


## O fogo e da queda, e nao da moto: a proxima queda, devagar, nao herda.
func test_a_proxima_queda_nao_herda_o_fogo() -> void:
	var e := _estrago()
	e.cair(0.9)
	_passa(e, 0.5, true, 0.0)
	_passa(e, 0.5, false, 0.0)
	e.cair(0.1)
	_passa(e, 1.0, true, 0.0)
	assert_bool(e.pegou_fogo()).is_false()
