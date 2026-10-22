extends GdUnitTestSuite
## A chama azul do nitro (`ChamaDoNitro`): acende so no boost, em toda moto, e a
## luz azul so existe de noite.

const PASSO: float = 1.0 / 60.0


func _chama(modelo: int) -> ChamaDoNitro:
	var c: ChamaDoNitro = auto_free(ChamaDoNitro.new())
	add_child(c)
	c.usar_modelo(modelo, -0.875)
	return c


func after_test() -> void:
	Relogio.escuro = 0.0


func test_so_acende_durante_o_boost_em_todas_as_motos() -> void:
	for modelo in Entregador.CENAS.size():
		var c := _chama(modelo)
		for i in 30:
			c.atualizar(PASSO, false)
		assert_bool(c.emitindo()).is_false()
		for i in 30:
			c.atualizar(PASSO, true)
		assert_bool(c.emitindo()).is_true()
		for i in 30:
			c.atualizar(PASSO, false)
		assert_bool(c.emitindo()).is_false()


func test_a_luz_azul_so_de_noite() -> void:
	var c := _chama(Entregador.Modelo.CG_160)
	Relogio.escuro = 0.0
	for i in 30:
		c.atualizar(PASSO, true)
	assert_bool(c.luz_acesa()).is_false()
	Relogio.escuro = 1.0
	for i in 30:
		c.atualizar(PASSO, true)
	assert_bool(c.luz_acesa()).is_true()
	for i in 60:
		c.atualizar(PASSO, false)
	assert_bool(c.luz_acesa()).is_false()


func test_cada_moto_solta_a_chama_do_escape_dela() -> void:
	# O escape sai da ficha, e fica atras do centro (+Z) e acima do chao.
	var vistos := {}
	for modelo in Entregador.CENAS.size():
		var ficha := FichaDaMoto.de(modelo)
		assert_float(ficha.escape.z).is_between(0.6, 1.2)
		assert_float(ficha.escape.y).is_between(0.15, 0.7)
		assert_float(ficha.chama).is_between(0.5, 2.0)
		var c := _chama(modelo)
		assert_float(c.position.z).is_equal_approx(ficha.escape.z, 0.001)
		vistos[ficha.escape] = true
	assert_int(vistos.size()).is_greater(1)
