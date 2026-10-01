extends GdUnitTestSuite
## Os predios: quatro tamanhos, fachada para o lado certo e a cor de fabrica.
##
## Nada disto aparece no banco de provas - predio nao tem colisor - e a
## regressao visual so pega a tela errada por inteiro. Um eixo trocado no
## exportador poe a fachada inteira de costas para a pista, e o jogo continua
## rodando, so que olhando para a parede dos fundos.


func test_quatro_alturas_do_mais_baixo_ao_mais_alto() -> void:
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
	var fabrica: Array[Color] = [Predio.PINTURA_FABRICA, Predio.LOJA_FABRICA]
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
