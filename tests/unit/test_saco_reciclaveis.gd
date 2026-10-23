extends GdUnitTestSuite
## O lixo e visual, mas precisa espalhar, quicar, parar e terminar sem crescer
## a cada impacto nem depender da taxa de quadros da bancada.


func _efeito() -> SacoReciclaveis:
	var efeito: SacoReciclaveis = auto_free(SacoReciclaveis.new())
	add_child(efeito)
	efeito.set_physics_process(false)
	return efeito


func test_estouro_espalha_latas_pet_e_retalhos_nos_dois_sentidos() -> void:
	var efeito := _efeito()
	efeito.estourar(Vector2(180.0, -15.0), 31)
	efeito.set_physics_process(false)
	var contagem: Array[int] = [0, 0, 0]
	var esquerda: Array[bool] = [false, false]
	var direita: Array[bool] = [false, false]
	for p in efeito._pecas:
		var categoria := mini(p.tipo / 2, 2)
		contagem[categoria] += 1
		if categoria < 2:
			esquerda[categoria] = esquerda[categoria] or p.velocidade.x < -20.0
			direita[categoria] = direita[categoria] or p.velocidade.x > 20.0
	assert_array(contagem).is_equal([20, 20, 10])
	assert_array(esquerda).is_equal([true, true])
	assert_array(direita).is_equal([true, true])
	assert_bool(efeito is Node2D).is_true()


func test_quica_desliza_para_e_termina_sem_repetir_impacto() -> void:
	var efeito := _efeito()
	efeito.estourar(Vector2(350.0, 0.0))
	efeito.set_physics_process(false)
	efeito.avancar(0.6)
	var tempo := efeito._tempo
	efeito.estourar(Vector2(-350.0, 0.0))
	assert_int(efeito._pecas.size()).is_equal(50)
	assert_float(efeito._tempo).is_equal(tempo)
	efeito.avancar(4.4)
	var quicaram := 0
	for p in efeito._pecas:
		if p.quicou:
			quicaram += 1
		assert_float(p.altura).is_equal_approx(0.0, 0.01)
		assert_float(p.velocidade.length()).is_less(1.0)
	assert_int(quicaram).is_equal(40)
	efeito.avancar(2.1)
	assert_bool(efeito._terminou).is_true()
	assert_int(efeito._pecas.size()).is_equal(0)
	assert_bool(efeito.is_physics_processing()).is_false()
	efeito.reiniciar(Vector2(20.0, 30.0))
	assert_int(efeito._pecas.size()).is_equal(0)
	assert_bool(efeito._estourou).is_false()
	assert_vector(efeito.position).is_equal(Vector2(20.0, 30.0))


func test_trajetoria_reproduzivel_com_passos_grandes_e_pequenos() -> void:
	var a := _efeito()
	var b := _efeito()
	a.estourar(Vector2(200.0, 0.0), 44)
	b.estourar(Vector2(200.0, 0.0), 44)
	a.set_physics_process(false)
	b.set_physics_process(false)
	a.avancar(1.0)
	for i in 120:
		b.avancar(1.0 / 120.0)
	for i in a._pecas.size():
		assert_float(a._pecas[i].altura).is_equal_approx(b._pecas[i].altura, 0.001)
		assert_float(a._pecas[i].chao.distance_to(b._pecas[i].chao)).is_less(0.001)
