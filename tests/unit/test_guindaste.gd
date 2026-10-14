extends GdUnitTestSuite
## O guindaste de torre: pecas repetidas, e a altura e o alcance sao quantos
## trechos entram. Escala esticaria a trelica; contar trecho nao.


func test_os_trechos_medem_o_que_o_codigo_diz() -> void:
	# O empilhamento confia nestas duas medidas. Se o gerador mudar o trecho e
	# elas nao, abre vao no mastro ou a lanca se sobrepoe - sem erro nenhum.
	var mastro := Predio.malha_da_peca("GuindasteMastro").get_aabb()
	assert_float(mastro.size.y).is_equal_approx(Guindaste.TRECHO_MASTRO, 0.01)
	assert_float(mastro.position.y).is_equal_approx(0.0, 0.01)
	var lanca := Predio.malha_da_peca("GuindasteLanca").get_aabb()
	assert_float(lanca.size.x).is_equal_approx(Guindaste.TRECHO_LANCA, 0.01)
	assert_float(lanca.position.x).is_equal_approx(0.0, 0.01)


func test_altura_e_alcance_sao_trechos_inteiros() -> void:
	var g: Node3D = auto_free(Guindaste.criar(15.0, 28.0, 0.0))
	var mastros := 0
	var topo: Node3D = null
	for filho: Node in g.get_children():
		if filho.name.begins_with("Mastro"):
			mastros += 1
		elif filho.name.begins_with("Topo"):
			topo = filho as Node3D
	assert_int(mastros).is_equal(5)
	assert_float(topo.position.y).is_equal(15.0)
	var secoes := 0
	for filho: Node in topo.get_children():
		if filho.name.begins_with("Lanca"):
			secoes += 1
	assert_int(secoes).is_equal(7)


func test_arredonda_para_cima_e_nunca_zera() -> void:
	var g: Node3D = auto_free(Guindaste.criar(10.0, 5.0, 0.0))
	var mastros := 0
	for filho: Node in g.get_children():
		if filho.name.begins_with("Mastro"):
			mastros += 1
	assert_int(mastros).is_equal(4)
	var pequeno: Node3D = auto_free(Guindaste.criar(0.1, 0.1, 0.0))
	assert_int(pequeno.get_child_count()).is_greater(1)


func test_o_giro_leva_so_o_topo() -> void:
	var g: Node3D = auto_free(Guindaste.criar(9.0, 8.0, 1.0))
	for filho: Node in g.get_children():
		if filho.name.begins_with("Topo"):
			assert_float((filho as Node3D).rotation.y).is_equal_approx(1.0, 0.001)
		else:
			assert_float((filho as Node3D).rotation.y).is_equal(0.0)


func test_a_altura_total_conta_a_torre_em_a() -> void:
	assert_float(Guindaste.altura_total(15.0)).is_greater(15.0 + 6.0)


func test_nao_projeta_sombra() -> void:
	var g: Node3D = auto_free(Guindaste.criar(9.0, 8.0, 0.0))
	for filho: Node in g.get_children():
		assert_int((filho as GeometryInstance3D).cast_shadow).is_equal(
			GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		)
