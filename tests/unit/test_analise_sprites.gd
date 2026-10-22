extends GdUnitTestSuite
## A analise das folhas (`AnaliseSprites`): a borda, e o que sobe do aviso de
## um quadro para o de varias pessoas.
##
## A conferencia de pose e de movimento depende de a referencia ter acertado e
## de o Flow ter copiado, entao o que se fixa aqui e o que nao depende de
## opiniao: a borda suja e defeito, e a folha entregue tem de estar limpa.

const LADO: int = 40


func _corpo(cor: Color = Color(0.8, 0.5, 0.4, 1.0)) -> Image:
	var imagem := Image.create_empty(LADO, LADO, false, Image.FORMAT_RGBA8)
	imagem.fill_rect(Rect2i(10, 5, 20, 30), cor)
	return imagem


func test_corpo_limpo_nao_tem_defeito_de_borda() -> void:
	var imagem := _corpo()
	var medida := AnaliseSprites.medir_borda(imagem, imagem.get_used_rect())
	assert_float(medida["semi"]).is_equal(0.0)
	assert_float(medida["verde"]).is_equal(0.0)
	assert_int(medida["graos"]).is_equal(0)


func test_meio_tom_na_borda_e_acusado() -> void:
	var imagem := _corpo()
	for y in range(5, 35):
		imagem.set_pixel(10, y, Color(0.8, 0.5, 0.4, 0.5))
	var medida := AnaliseSprites.medir_borda(imagem, imagem.get_used_rect())
	assert_float(medida["semi"]).is_greater(AnaliseSprites.SEMITRANSPARENTE)


func test_franja_verde_do_chroma_key_e_acusada() -> void:
	var imagem := _corpo()
	for y in range(5, 35):
		imagem.set_pixel(10, y, Color(0.3, 0.9, 0.3, 1.0))
	var medida := AnaliseSprites.medir_borda(imagem, imagem.get_used_rect())
	assert_float(medida["verde"]).is_greater(AnaliseSprites.BORDA_VERDE)


func test_verde_no_meio_do_corpo_nao_e_franja() -> void:
	# Um vestido verde: o verde mora dentro, e so a borda conta.
	var imagem := _corpo()
	imagem.fill_rect(Rect2i(14, 12, 12, 12), Color(0.2, 0.8, 0.2, 1.0))
	var medida := AnaliseSprites.medir_borda(imagem, imagem.get_used_rect())
	assert_float(medida["verde"]).is_less_equal(AnaliseSprites.BORDA_VERDE)


func test_grao_solto_fora_do_corpo_e_contado() -> void:
	var imagem := _corpo()
	imagem.set_pixel(2, 2, Color.WHITE)
	imagem.set_pixel(37, 3, Color.WHITE)
	imagem.set_pixel(3, 37, Color.WHITE)
	imagem.set_pixel(36, 36, Color.WHITE)
	var medida := AnaliseSprites.medir_borda(imagem, imagem.get_used_rect())
	assert_int(medida["graos"]).is_equal(4)


func test_folha_em_branco_nao_quebra_a_medida() -> void:
	var imagem := Image.create_empty(LADO, LADO, false, Image.FORMAT_RGBA8)
	var medida := AnaliseSprites.medir_borda(imagem, Rect2i())
	assert_int(medida["graos"]).is_equal(0)


func test_nenhuma_folha_entregue_tem_borda_suja() -> void:
	# O recorte do Flow fecha a borda em corte duro: se alguma folha nova vier
	# com meio-tom ou franja verde, o shader do sprite pinta o halo no jogo.
	for item in CatalogoSprites.varrer():
		AnaliseSprites.analisar(item)
		for aviso in item.avisos_analise:
			(
				assert_bool(aviso.begins_with("borda:"))
				. override_failure_message("%s: %s" % [item.id, aviso])
				. is_false()
			)


func test_analisar_duas_vezes_nao_dobra_os_avisos() -> void:
	var item := CatalogoSprites.varrer()[1]
	AnaliseSprites.analisar(item)
	var primeiro := item.avisos_analise.size()
	AnaliseSprites.analisar(item)
	assert_int(item.avisos_analise.size()).is_equal(primeiro)


func test_cada_folha_de_pedestre_ganha_a_nota_de_semelhanca_com_a_referencia() -> void:
	for item in CatalogoSprites.varrer():
		if item.tipo != CatalogoSprites.Tipo.PEDESTRE:
			continue
		AnaliseSprites.analisar(item)
		if item.animacao == "andando" and item.linhas == 4:
			# Dividir a referencia de cinco angulos em quatro compara vistas erradas.
			assert_int(item.iou_referencia.size()).is_equal(0)
			assert_object(item.referencia).is_null()
		else:
			assert_int(item.iou_referencia.size()).is_equal(item.quadros())
			assert_object(item.referencia).is_not_null()


func test_o_mesmo_quadro_em_tres_pessoas_vira_suspeita_da_referencia() -> void:
	var itens: Array[CatalogoSprites.Item] = []
	for i in 5:
		var item := CatalogoSprites.Item.new()
		item.id = "pessoa%d_susto" % i
		item.tipo = CatalogoSprites.Tipo.PEDESTRE
		item.animacao = "susto"
		item.colunas = 6
		item.linhas = 3
		if i < 3:
			item.anota(4, 2, "so 20% da referencia")
		itens.append(item)
	var suspeitas := CatalogoSprites.recorrentes(itens)
	assert_int(suspeitas.size()).is_equal(1)
	assert_str(suspeitas[0]).contains("quadro 5/3")
	assert_str(suspeitas[0]).contains("3 de 5")


func test_duas_pessoas_no_mesmo_quadro_ainda_e_problema_da_pessoa() -> void:
	var itens: Array[CatalogoSprites.Item] = []
	for i in 5:
		var item := CatalogoSprites.Item.new()
		item.tipo = CatalogoSprites.Tipo.PEDESTRE
		item.animacao = "susto"
		item.colunas = 6
		item.linhas = 3
		if i < 2:
			item.anota(4, 2, "so 20% da referencia")
		itens.append(item)
	assert_int(CatalogoSprites.recorrentes(itens).size()).is_equal(0)


func test_nota_de_borda_nao_conta_como_defeito_de_pose() -> void:
	var itens: Array[CatalogoSprites.Item] = []
	for i in 5:
		var item := CatalogoSprites.Item.new()
		item.tipo = CatalogoSprites.Tipo.PEDESTRE
		item.animacao = "susto"
		item.colunas = 6
		item.linhas = 3
		item.anota(4, 2, "4% da borda com franja verde")
		itens.append(item)
	assert_int(CatalogoSprites.recorrentes(itens).size()).is_equal(0)
