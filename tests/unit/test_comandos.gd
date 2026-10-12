extends GdUnitTestSuite
## Maos e pes nos comandos: o pulso no gas, os dedos nas manetes, a bota nos
## pedais e a troca de marcha de mentira. Nada disto aparece no banco de
## provas, e um sinal trocado aqui e piloto acelerando com o pulso ao contrario.

const PASSO: float = 1.0 / 60.0


func _ator(modelo: int) -> Entregador:
	var ator: Entregador = auto_free(Entregador.new())
	ator.modelo = modelo
	add_child(ator)
	return ator


func _modelos() -> Array[int]:
	var todos: Array[int] = []
	for i in Entregador.CENAS.size():
		todos.append(i)
	return todos


func _comandos(marchas: int) -> Comandos:
	var c := Comandos.new()
	c._marchas = marchas
	return c


func test_o_gas_torce_o_pulso_direito_e_a_freada_fecha() -> void:
	var c := _comandos(5)
	for i in 60:
		c.passo(PASSO, 20.0, 1.0, 0.0, false)
	assert_float(c.torcao()).is_greater(Comandos.TORCAO * 0.95)
	# So o direito: a esquerda nao tem acelerador.
	assert_bool(c.pulso(0).is_equal_approx(Basis.IDENTITY)).is_true()
	# O topo da manopla vai para tras (+Z): e o gas abrindo, e nao fechando.
	assert_float((c.pulso(1) * Vector3.UP).z).is_greater(0.5)
	for i in 30:
		c.passo(PASSO, 20.0, 1.0, 1.0, false)
	assert_float(c.torcao()).is_less(0.0)


func test_a_freada_puxa_a_manete_e_pisa_no_pedal() -> void:
	var c := _comandos(5)
	for i in 30:
		c.passo(PASSO, 20.0, 0.0, 1.0, false)
	assert_float(c.manete(1)).is_greater(0.9)
	assert_float(c.manete(0)).is_equal(0.0)
	assert_float(c.pedal_freio()).is_greater(0.5)
	# A bota desce o bico junto com o pedal.
	assert_float((c.bota(1) * Vector3.FORWARD).y).is_less(-0.1)
	# Soltou o freio, a manete volta: embalar nao e frear.
	for i in 60:
		c.passo(PASSO, 20.0, 0.0, 0.0, false)
	assert_float(c.manete(1)).is_less(0.05)


func test_na_automatica_os_dois_freios_sao_de_mao() -> void:
	var c := _comandos(0)
	for i in 30:
		c.passo(PASSO, 20.0, 0.0, 1.0, false)
	assert_float(c.manete(0)).is_greater(0.9)
	assert_float(c.manete(1)).is_greater(0.9)
	assert_float(c.pedal_freio()).is_equal(0.0)


func test_acelerando_sobe_todas_as_marchas_e_freando_desce() -> void:
	for marchas: int in [5, 0]:
		var c := _comandos(marchas)
		var v := 0.0
		var trocas := 0
		var trocando := false
		while v < Comandos.TETO:
			v += 8.0 * PASSO
			c.passo(PASSO, v, 1.0, 0.0, false)
			if c.trocando() and not trocando:
				trocas += 1
				# Na troca o piloto puxa a embreagem e alivia o gas.
				assert_float(c.manete(0)).is_less(0.5)
			trocando = c.trocando()
		assert_int(trocas).is_equal(maxi(marchas - 1, 0))
		while v > 1.0:
			v -= 10.0 * PASSO
			c.passo(PASSO, v, 0.0, 0.5, false)
		for i in 60:
			c.passo(PASSO, 0.0, 0.0, 0.0, false)
		assert_int(c.marcha()).is_equal(1 if marchas > 0 else 0)


func test_moto_que_nasce_andando_nao_sai_trocando() -> void:
	var c := _comandos(5)
	for i in 30:
		c.passo(PASSO, 40.0, 1.0, 0.0, false)
		assert_bool(c.trocando()).is_false()
	assert_int(c.marcha()).is_equal(5)


func test_soltar_o_gas_em_alta_nao_puxa_a_manete() -> void:
	var ator := _ator(Entregador.Modelo.CG_160)
	var v := 45.0
	for i in 120:
		# O arrasto a 45 m/s tira mais de 5 m/s2, sem ninguem frear.
		v -= 6.0 * PASSO
		ator.atualizar(PASSO, v, 0.0, 0.0, false)
	assert_float(ator._comandos.manete(1)).is_equal(0.0)
	assert_float(ator._comandos.torcao()).is_equal_approx(0.0, 0.5)


func test_toda_moto_tem_as_marchas_na_ficha() -> void:
	assert_int(FichaDaMoto.de(Entregador.Modelo.CG_160).marchas).is_equal(5)
	assert_int(FichaDaMoto.de(Entregador.Modelo.XRE_300).marchas).is_equal(5)
	assert_int(FichaDaMoto.de(Entregador.Modelo.PCX_160).marchas).is_equal(0)


func test_a_manete_vem_para_a_manopla_e_os_dedos_vao_junto() -> void:
	for modelo in _modelos():
		var ator := _ator(modelo)
		var manete := ator.find_child("Manete_D", true, false) as Node3D
		var dedos := ator.find_child("Dedos_D", true, false) as Node3D
		for i in 30:
			ator.atualizar(PASSO, 20.0, 0.0, 0.0, false)
		# No espaco do guidao: na freada o garfo mergulha e leva tudo junto.
		var ponta := manete.transform * Vector3(0.1, 0.0, 0.0)
		# Freio cheio, com a velocidade caindo junto.
		var v := 20.0
		for i in 20:
			v -= 20.0 * PASSO
			ator.atualizar(PASSO, v, 0.0, 0.0, false, 1.0, 0.0, 0.0, 1.0)
		var puxada := manete.transform * Vector3(0.1, 0.0, 0.0)
		# A ponta veio para tras, para a manopla.
		assert_float(puxada.z - ponta.z).is_greater(0.02)
		# E os dedos estao em cima dela, e nao parados onde ela estava.
		var na_manete := manete.global_transform * ator._comandos._dedos_na_manete[1]
		assert_float(dedos.global_position.distance_to(na_manete.origin)).is_less(0.005)


func test_com_o_gas_cheio_os_dedos_largam_a_manete() -> void:
	for modelo in _modelos():
		var ator := _ator(modelo)
		var manete := ator.find_child("Manete_D", true, false) as Node3D
		var dedos := ator.find_child("Dedos_D", true, false) as Node3D
		for i in 60:
			ator.atualizar(PASSO, 20.0, 1.0, 0.0, false)
		var mao := dedos.get_parent() as Node3D
		var na_mao := mao.global_transform * ator._comandos._repouso[dedos]
		assert_float(dedos.global_position.distance_to(na_mao.origin)).is_less(0.005)
		var na_manete := manete.global_transform * ator._comandos._dedos_na_manete[1]
		var ponta := dedos.global_transform * Comandos.PONTA
		assert_float(ponta.distance_to(na_manete * Comandos.PONTA)).is_greater(0.03)
