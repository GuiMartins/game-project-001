extends GdUnitTestSuite
## O projetor por segmento (`ProjetorPista`): reta, curva e rampa da pista de
## verdade viram posicao de tela do jeito que o pseudo-3D promete.


## Uma pista de teste: `subida` metros por metro e `giro` radianos por metro
## (+ esquerda, como a pista de verdade), com 1000 m.
func _pista(subida: float, giro: float) -> RoadTrack:
	var pista := RoadTrack.new()
	pista.curve = Curve3D.new()
	var rumo := 0.0
	var pos := Vector3.ZERO
	pista.curve.add_point(pos)
	for i in 250:
		rumo += giro * 4.0
		pos += Vector3(sin(rumo), subida, cos(rumo)) * 4.0
		pista.curve.add_point(pos)
	pista.length = pista.curve.get_baked_length()
	auto_free(pista)
	return pista


func _projeta(pista: RoadTrack, lateral: float = 0.0) -> ProjetorPista:
	var projetor := ProjetorPista.new()
	projetor.projetar(pista, 100.0, lateral)
	return projetor


func test_reta_plana_fica_no_centro_e_sobe_para_o_horizonte() -> void:
	var projetor := _projeta(_pista(0.0, 0.0))
	assert_int(projetor.amostras.size()).is_greater(50)
	var anterior: ProjetorPista.Amostra = null
	for a: ProjetorPista.Amostra in projetor.amostras:
		assert_float(a.tela_x).is_equal_approx(projetor.centro_x, 0.01)
		if anterior != null:
			assert_float(a.tela_y).is_less(anterior.tela_y)
			assert_float(a.escala).is_less(anterior.escala)
		anterior = a
	# O que esta no fim da visao encosta no horizonte, sem passar dele.
	assert_float(anterior.tela_y).is_greater(projetor.horizonte_y)
	assert_float(anterior.tela_y).is_less(projetor.horizonte_y + 5.0)


func test_camera_a_direita_do_eixo_empurra_a_pista_para_a_esquerda() -> void:
	var centrada := _projeta(_pista(0.0, 0.0), 0.0)
	var a_direita := _projeta(_pista(0.0, 0.0), 2.0)
	assert_float(a_direita.amostras[0].tela_x).is_less(centrada.amostras[0].tela_x)


func test_curva_a_esquerda_leva_a_pista_para_a_esquerda_e_a_direita_para_a_direita() -> void:
	var esquerda := _projeta(_pista(0.0, deg_to_rad(0.3)))
	var direita := _projeta(_pista(0.0, deg_to_rad(-0.3)))
	assert_float(esquerda.amostras.back().tela_x).is_less(esquerda.centro_x - 20.0)
	assert_float(direita.amostras.back().tela_x).is_greater(direita.centro_x + 20.0)


func test_curva_forte_nao_dobra_a_pista_sobre_si_mesma() -> void:
	# 0,6 grau por metro e o maximo da pista; sem o ganho e o limite, o Z recuaria.
	var projetor := _projeta(_pista(0.0, deg_to_rad(0.6)))
	var anterior := 0.0
	for a: ProjetorPista.Amostra in projetor.amostras:
		assert_float(a.z).is_greater(anterior)
		anterior = a.z


func test_a_rampa_sobe_na_tela_e_a_descida_desce() -> void:
	var plana := _projeta(_pista(0.0, 0.0)).amostras.back() as ProjetorPista.Amostra
	var sobe := _projeta(_pista(0.08, 0.0)).amostras.back() as ProjetorPista.Amostra
	var desce := _projeta(_pista(-0.08, 0.0)).amostras.back() as ProjetorPista.Amostra
	assert_float(sobe.tela_y).is_less(plana.tela_y)
	assert_float(desce.tela_y).is_greater(plana.tela_y)


func test_o_ponto_cai_no_eixo_da_amostra_e_o_lateral_anda_em_metros() -> void:
	var projetor := _projeta(_pista(0.0, 0.0))
	var a: ProjetorPista.Amostra = projetor.amostras[10]
	var no_eixo := projetor.ponto(a.o, 0.0)
	assert_float(no_eixo.x).is_equal_approx(a.tela_x, 0.01)
	assert_float(no_eixo.y).is_equal_approx(a.tela_y, 0.01)
	var a_direita := projetor.ponto(a.o, 3.0)
	assert_float(a_direita.x - no_eixo.x).is_equal_approx(3.0 * a.escala, 0.01)


func test_ponto_fora_da_visao_devolve_zero() -> void:
	var projetor := _projeta(_pista(0.0, 0.0))
	assert_vector(projetor.ponto(0.0, 0.0)).is_equal(Vector3.ZERO)
	assert_vector(projetor.ponto(5000.0, 0.0)).is_equal(Vector3.ZERO)


func test_a_linha_de_tela_devolve_um_metro_de_pista_entre_as_duas_amostras() -> void:
	var projetor := _projeta(_pista(0.0, 0.0))
	var a: ProjetorPista.Amostra = projetor.amostras[5]
	var b: ProjetorPista.Amostra = projetor.amostras[6]
	var meio := (a.tela_y + b.tela_y) * 0.5
	var p := ProjetorPista.na_linha(a, b, meio)
	assert_float(p.x).is_between(a.o, b.o)
	# Perspectiva: o meio da linha na tela esta mais perto do que o meio do
	# metro, porque o perto ocupa mais linhas.
	assert_float(p.x).is_less((a.o + b.o) * 0.5)


func test_as_amostras_caem_em_multiplos_do_passo_para_a_pista_nao_andar_junto() -> void:
	var projetor := ProjetorPista.new()
	var pista := _pista(0.0, 0.0)
	projetor.projetar(pista, 100.3, 0.0)
	for a: ProjetorPista.Amostra in projetor.amostras.slice(1):
		assert_float(fposmod(a.o, ProjetorPista.PASSO)).is_equal_approx(0.0, 0.001)
