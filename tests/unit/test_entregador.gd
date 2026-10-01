extends GdUnitTestSuite
## O ator: a pose que sai da velocidade, do acelerador, do esterco e da queda.
##
## Nada disto aparece no banco de provas. A fisica anda igual com a roda
## girando para tras, o pe enterrado no asfalto ou a mao a um palmo do guidao, e
## a regressao visual so pega a tela errada por inteiro. E o tipo de erro que
## nasce de um sinal trocado - a mesma classe da guinada que ja inverteu o jogo
## uma vez - e que ninguem ve ate parar para olhar a moto de perto.

const PASSO: float = 1.0 / 60.0
const LADOS: Array[String] = ["E", "D"]


func _ator() -> Entregador:
	var ator: Entregador = auto_free(Entregador.new())
	add_child(ator)
	return ator


func _anda(
	ator: Entregador,
	segundos: float,
	velocidade: float,
	acelerador: float,
	esterco: float,
	caido: bool = false,
	lado: float = 1.0
) -> void:
	for i in int(segundos / PASSO):
		ator.atualizar(PASSO, velocidade, acelerador, esterco, caido, lado)


func _no(ator: Entregador, nome: String) -> Node3D:
	return ator.find_child(nome, true, false) as Node3D


func test_roda_gira_para_a_frente() -> void:
	var ator := _ator()
	# Um passo so: a 10 m/s a roda de 0,3 m gira meio radiano, longe de dar a
	# volta e enganar o sinal.
	ator.atualizar(PASSO, 10.0, 1.0, 0.0, false)
	var topo := _no(ator, "Roda_Traseira").global_basis * Vector3.UP
	# A frente e -Z. Rodando para a frente, o topo da roda vai para la.
	assert_float(topo.z).is_less(0.0)


func test_parado_o_pe_esquerdo_vai_ao_chao() -> void:
	var ator := _ator()
	_anda(ator, 1.0, 0.0, 0.0, 0.0)
	var pe := _no(ator, "Pe_E").global_position
	assert_float(pe.y).is_equal_approx(Entregador.PE_NO_CHAO.y, 0.01)
	assert_float(pe.x).is_equal_approx(Entregador.PE_NO_CHAO.x, 0.01)
	# O direito nao sai da pedaleira: so um pe desce.
	assert_float(_no(ator, "Pe_D").global_position.y).is_greater(0.3)


func test_andando_o_pe_volta_para_a_pedaleira() -> void:
	var ator := _ator()
	_anda(ator, 1.0, 0.0, 0.0, 0.0)
	_anda(ator, 1.0, 20.0, 1.0, 0.0)
	assert_float(_no(ator, "Pe_E").global_position.y).is_greater(0.3)


func test_as_maos_acompanham_o_guidao() -> void:
	var ator := _ator()
	# Em repouso cada mao esta na sua manopla. Guarda onde, no espaco do garfo.
	var direcao := _no(ator, "Direcao")
	var manoplas: Array[Vector3] = []
	for lado in LADOS:
		manoplas.append(direcao.to_local(_no(ator, "Mao_" + lado).global_position))

	# Devagar e com o esterco no batente: o caso em que o guidao mais vira.
	_anda(ator, 1.0, 2.0, 0.0, 1.0)
	var virou := rad_to_deg(direcao.basis.get_rotation_quaternion().get_angle())
	assert_float(virou).is_greater(10.0)
	for i in LADOS.size():
		var mao := _no(ator, "Mao_" + LADOS[i]).global_position
		var manopla := direcao.to_global(manoplas[i])
		assert_float(mao.distance_to(manopla)).is_less(0.01)


func test_joelho_abre_devagar_e_fecha_rapido() -> void:
	var ator := _ator()
	_anda(ator, 2.0, 3.0, 0.0, 0.0)
	var devagar := absf(_no(ator, "Canela_E").global_position.x)
	_anda(ator, 2.0, 30.0, 1.0, 0.0)
	var rapido := absf(_no(ator, "Canela_E").global_position.x)
	assert_float(devagar).is_greater(rapido + 0.05)


func test_a_queda_tomba_para_o_lado_pedido() -> void:
	for lado: float in [-1.0, 1.0]:
		var ator := _ator()
		_anda(ator, 1.0, 0.0, 0.0, 0.0, true, lado)
		var cabeca := _no(ator, "Cabeca").global_position
		assert_float(cabeca.x * lado).is_greater(1.0)
		assert_float(cabeca.y).is_less(0.6)
		if lado > 0.0:
			# Deitada para a direita, o lado esquerdo fica para cima - e o pe
			# esquerdo tem que ficar com ele, na pedaleira. Moto parada e caida
			# nao e moto parada esperando: se o pe descesse para o chao aqui,
			# ele atravessaria o asfalto pelo meio do tanque.
			assert_float(_no(ator, "Pe_E").global_position.y).is_greater(0.3)


func test_cores_de_fabrica_batem_com_a_textura() -> void:
	# Le o PNG que o gerador escreveu, nao a textura importada: e ele que o
	# `arte/entregador.py` regera quando a paleta muda.
	var albedo := Image.load_from_file(
		ProjectSettings.globalize_path("res://assets/entregador/entregador_albedo.png")
	)
	var mascara := Image.load_from_file(
		ProjectSettings.globalize_path("res://assets/entregador/entregador_mascara.png")
	)
	var fabrica: Array[Color] = [
		Entregador.BAG_FABRICA, Entregador.JAQUETA_FABRICA, Entregador.MOTO_FABRICA
	]
	for canal in 3:
		# A cor de fabrica de cada canal e a celula mais clara sob ele: a bag e
		# mais clara que a tampa dela, a pintura mais que o detalhe escuro.
		var mais_clara := Color.BLACK
		for y in range(4, albedo.get_height(), 8):
			for x in range(4, albedo.get_width(), 8):
				var cor := albedo.get_pixel(x, y)
				if mascara.get_pixel(x, y)[canal] < 0.5:
					continue
				if cor.get_luminance() > mais_clara.get_luminance():
					mais_clara = cor
		assert_float(mais_clara.r).is_equal_approx(fabrica[canal].r, 0.01)
		assert_float(mais_clara.g).is_equal_approx(fabrica[canal].g, 0.01)
		assert_float(mais_clara.b).is_equal_approx(fabrica[canal].b, 0.01)
