extends GdUnitTestSuite
## As arvores da avenida: a copa tem de se debrucar para a pista, e o pe tem de
## ficar no chao. Os dois ja inverteram uma vez em outro modelo (o predio e o
## poste olham para -Z pelo mesmo motivo), e nenhum dos dois da erro.


func test_a_copa_se_debruca_para_menos_z() -> void:
	# O meio da copa fica para o lado de -Z, que quem planta aponta para a
	# pista: e o que poe a copa por cima da camera.
	var caixa := Arvore.malha(Arvore.Tipo.COPA).get_aabb()
	assert_float(caixa.get_center().z).is_less(-1.0)


func test_o_pe_fica_no_chao() -> void:
	for tipo: int in Arvore.Tipo.values():
		var caixa := Arvore.malha(tipo).get_aabb()
		assert_float(caixa.position.y).is_between(-0.6, 0.0)


func test_a_copa_passa_acima_da_camera() -> void:
	# A camera fica a 2,25 m e o onibus tem 3,2 m: abaixo disso a copa batia
	# no teto do onibus que passa embaixo dela.
	var malha := Arvore.malha(Arvore.Tipo.COPA)
	var mais_baixo_fora_do_tronco := INF
	for superficie in malha.get_surface_count():
		var arrays := malha.surface_get_arrays(superficie)
		for v: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
			if v.z < -2.0:
				mais_baixo_fora_do_tronco = minf(mais_baixo_fora_do_tronco, v.y)
	assert_float(mais_baixo_fora_do_tronco).is_greater(3.5)
