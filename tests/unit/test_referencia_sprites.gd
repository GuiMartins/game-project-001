extends GdUnitTestSuite
## A referencia 3D que foi ao Flow (`ReferenciaSprites`): se carrega, se bate
## com a grade dos atlas, e o que ela mesma tem de errado.
##
## O estado conhecido esta fixado de proposito. A referencia da queda e cortada
## pela propria grade (o braco do boneco passa da celula), e isso e a hipotese
## mais forte de por que as folhas de queda saem diferentes dela. O dia que
## alguem refizer a referencia sem o corte, o teste muda junto.

const FOLHAS: Array[Array] = [
	["andando", 8, 5], ["caida", 3, 4], ["desembarcando", 8, 4], ["susto", 6, 3], ["voando", 8, 4]
]


func test_toda_animacao_tem_referencia_na_grade_do_atlas() -> void:
	for folha in FOLHAS:
		var ref := ReferenciaSprites.de(folha[0], folha[1], folha[2])
		assert_object(ref).is_not_null()
		assert_int(ref.silhuetas.size()).is_equal(folha[1] * folha[2])


func test_nenhum_quadro_da_referencia_esta_vazio() -> void:
	for folha in FOLHAS:
		var ref := ReferenciaSprites.de(folha[0], folha[1], folha[2])
		for silhueta in ref.silhuetas:
			assert_bool(silhueta.vazia()).is_false()


func test_o_verde_sai_e_o_boneco_fica() -> void:
	var ref := ReferenciaSprites.de("andando", 8, 5)
	var celula := ref.celula_imagem(0, 0)
	# O canto da celula e fundo, e o tronco tem corpo (o meio da caixa pode cair
	# no vao entre as pernas).
	assert_float(celula.get_pixel(1, 1).a).is_equal(0.0)
	var caixa := ref.silhueta(0, 0).caixa
	var tronco := Vector2i(caixa.get_center().x, caixa.position.y + int(caixa.size.y * 0.3))
	assert_float(celula.get_pixel(tronco.x, tronco.y).a).is_equal(1.0)


func test_a_referencia_e_lida_uma_vez() -> void:
	assert_object(ReferenciaSprites.de("susto", 6, 3)).is_same(ReferenciaSprites.de("susto", 6, 3))


func test_animacao_sem_folha_de_referencia_devolve_nada() -> void:
	assert_object(ReferenciaSprites.de("nao_existe", 4, 4)).is_null()


func test_o_ciclo_de_andar_da_referencia_abre_a_perna_onde_a_folha_manda() -> void:
	var ref := ReferenciaSprites.de("andando", 8, 5)
	for aviso in ref.avisos:
		assert_str(aviso).not_contains("passada")


func test_a_referencia_da_queda_e_cortada_pela_grade() -> void:
	var ref := ReferenciaSprites.de("caida", 3, 4)
	var cortada := false
	for aviso in ref.avisos:
		cortada = cortada or aviso.contains("encosta na borda")
	assert_bool(cortada).is_true()


func test_as_outras_referencias_nao_tem_defeito_que_se_meca() -> void:
	for animacao: String in ["andando", "desembarcando", "susto", "voando"]:
		var folha: Array = FOLHAS.filter(func(f: Array) -> bool: return f[0] == animacao)[0]
		var ref := ReferenciaSprites.de(animacao, folha[1], folha[2])
		assert_array(Array(ref.avisos)).override_failure_message(animacao).is_empty()
