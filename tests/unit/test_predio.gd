extends GdUnitTestSuite
## Os predios: cinco tamanhos, fachada para o lado certo e a cor de fabrica.
##
## Nada disto aparece no banco de provas - predio nao tem colisor - e a
## regressao visual so pega a tela errada por inteiro. Um eixo trocado no
## exportador poe a fachada inteira de costas para a pista, e o jogo continua
## rodando, so que olhando para a parede dos fundos.


func test_alturas_do_mais_baixo_ao_mais_alto() -> void:
	var anterior := 0.0
	for tipo: int in Predio.Tipo.values():
		var altura := Predio.malha(tipo).get_aabb().size.y
		assert_float(altura).is_greater(anterior + 4.0)
		anterior = altura


func test_larguras_diferentes() -> void:
	var larguras: Array[float] = []
	for tipo: int in Predio.Tipo.values():
		var largura := snappedf(Predio.malha(tipo).get_aabb().size.x, 0.5)
		assert_bool(larguras.has(largura)).is_false()
		larguras.append(largura)


func test_a_fachada_olha_para_menos_z() -> void:
	# Toldo, sacada, marquise e varanda saem so da fachada. Se ela estiver em
	# -Z, e o lado de -Z que avanca mais a partir da origem.
	for tipo: int in Predio.Tipo.values():
		var caixa := Predio.malha(tipo).get_aabb()
		assert_float(Predio.frente(tipo)).is_greater(caixa.end.z + 0.3)


func test_o_outdoor_nao_afasta_o_predio() -> void:
	# A bandeira do `Deco` avanca 3,5 m da fachada, a 6 m do chao. Se o
	# `frente` voltar a ser o AABB, o predio recua 2 m e abre um buraco no
	# corredor - e o jogo continua rodando, so com a rua mais larga ali.
	var caixa := Predio.malha(Predio.Tipo.DECO).get_aabb()
	assert_float(Predio.frente(Predio.Tipo.DECO)).is_less(-caixa.position.z - 1.5)
	# E o toldo ainda conta: ele fica na altura da rua.
	for tipo: int in Predio.Tipo.values():
		assert_float(Predio.frente(tipo)).is_greater(1.0)


func test_tela_do_outdoor_nao_imita_lanterna() -> void:
	# Vermelho aceso na altura da rua e freio: e o aviso de que o corredor vai
	# fechar, e um outdoor vermelho do lado da pista o falsificaria.
	for cor in Predio.TELAS:
		var distancia := minf(cor.h, 1.0 - cor.h)
		assert_float(distancia).is_greater(0.05)


func test_a_base_fica_no_chao() -> void:
	for tipo: int in Predio.Tipo.values():
		assert_float(Predio.malha(tipo).get_aabb().position.y).is_equal_approx(0.0, 0.01)


func test_cores_de_fabrica_batem_com_a_textura() -> void:
	# Le o PNG que o gerador escreveu, nao a textura importada: e ele que o
	# `arte/predios.py` regera quando a paleta muda.
	var albedo := Image.load_from_file(
		ProjectSettings.globalize_path("res://assets/predios/predios_albedo.png")
	)
	var mascara := Image.load_from_file(
		ProjectSettings.globalize_path("res://assets/predios/predios_mascara.png")
	)
	var fabrica: Array[Color] = [Predio.PINTURA_FABRICA, Predio.LOJA_FABRICA, Predio.TELA_FABRICA]
	for canal in fabrica.size():
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


func test_a_obra_tem_a_planta_da_torre() -> void:
	# A obra entra no lugar da torre sem a `Cidade` mexer na conta de passo:
	# se a planta andar, abre vao ou encavala no corredor.
	var torre := Predio.malha(Predio.Tipo.TORRE).get_aabb()
	for fase: int in Predio.Obra.values():
		var obra := Predio.malha_obra(fase as Predio.Obra).get_aabb()
		# Planta da torre mais o andaime de 1,2 m de cada lado e a barriga da lona.
		assert_float(obra.size.x).is_between(torre.size.x, torre.size.x + 4.0)
		assert_float(obra.position.y).is_equal_approx(0.0, 0.01)
		assert_float(obra.size.y).is_greater(Predio.OBRA_LAJE_DO_TOPO)
		assert_float(obra.size.y).is_less(torre.size.y + 1.0)


func test_a_laje_do_topo_bate_com_o_gerador() -> void:
	# O guindaste pisa em `OBRA_LAJE_DO_TOPO`: no esqueleto, a laje ali tem
	# 0,3 m de espessura e nada acima dela alem do ferro e do miolo. Se a
	# altura dos andares mudar no `arte/predios.py`, o guindaste fica
	# flutuando ou enterrado - e o jogo continua rodando.
	var vertices: PackedVector3Array = (
		Predio.malha_obra(Predio.Obra.ESQUELETO_LARANJA).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	)
	var achou := false
	for v in vertices:
		if is_equal_approx(v.y, Predio.OBRA_LAJE_DO_TOPO) and absf(v.x) > 7.0:
			achou = true
	assert_bool(achou).is_true()
