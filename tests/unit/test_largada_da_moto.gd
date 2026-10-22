extends GdUnitTestSuite
## A largada dos rivais: o sorteio depende da agressividade, e o que e comum
## ao jogador e ao rival (a pose empinada) mora em `LargadaDaMoto`.


func test_sorte_baixa_patina_e_sorte_alta_larga_normal() -> void:
	assert_int(LargadaDaMoto.resultado_do_rival(0.0, 0.3)).is_equal(LargadaDaMoto.Resultado.PATINA)
	assert_int(LargadaDaMoto.resultado_do_rival(0.99, 0.3)).is_equal(LargadaDaMoto.Resultado.NORMAL)


func test_agressivo_patina_mais() -> void:
	# A mesma sorte: o calmo escapa da patinada, o agressivo nao.
	var sorte := 0.25
	assert_int(LargadaDaMoto.resultado_do_rival(sorte, 0.1)).is_equal(
		LargadaDaMoto.Resultado.EMPINA
	)
	assert_int(LargadaDaMoto.resultado_do_rival(sorte, 0.55)).is_equal(
		LargadaDaMoto.Resultado.PATINA
	)


func test_empinada_ergue_o_nariz_em_torno_do_eixo_traseiro() -> void:
	var visual: Node3D = auto_free(Node3D.new())
	LargadaDaMoto.posa_o_visual(visual, 1.0, 0.0, 0.875, 0.65)
	# O eixo traseiro, no chao, nao sai do lugar; o nariz (-Z) sobe.
	var eixo := visual.transform * Vector3(0.0, 0.0, 0.65)
	assert_vector(eixo).is_equal_approx(Vector3(0.0, -0.875, 0.65), Vector3.ONE * 0.001)
	var nariz := visual.transform * Vector3(0.0, 0.0, -1.0)
	assert_float(nariz.y).is_greater(-0.875)
