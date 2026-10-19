extends GdUnitTestSuite
## As imagens que o testador exporta (`ExportaSprites`): o tamanho e o que
## vai dentro, para a comparacao poder ser mandada a quem desenha.


func _item(id: String) -> CatalogoSprites.Item:
	for item in CatalogoSprites.varrer():
		if item.id == id:
			return item
	return null


func test_o_quadro_sai_ampliado_em_pixel_inteiro() -> void:
	var item := _item("vovo_andando")
	var imagem := ExportaSprites.quadro(item, 2, 1, 4)
	assert_int(imagem.get_width()).is_equal(item.celula.x * 4)
	assert_int(imagem.get_height()).is_equal(item.celula.y * 4)


func test_a_comparacao_empilha_referencia_folha_e_sobreposicao_por_linha() -> void:
	var item := _item("vovo_andando")
	var imagem := ExportaSprites.comparacao(item)
	assert_object(imagem).is_not_null()
	# Tres faixas por linha de angulo, e uma coluna por quadro.
	assert_int(imagem.get_height()).is_equal(
		item.linhas * 3 * (imagem.get_height() / (item.linhas * 3))
	)
	assert_int(imagem.get_width() % item.colunas).is_equal(0)


func test_a_moto_nao_tem_referencia_gravada_para_comparar() -> void:
	assert_object(ExportaSprites.comparacao(_item("moto"))).is_null()


func test_a_folha_marcada_tem_o_tamanho_da_folha() -> void:
	var item := _item("vovo_susto")
	AnaliseSprites.analisar(item)
	var imagem := ExportaSprites.folha_marcada(item)
	assert_object(Vector2i(imagem.get_size())).is_equal(item.tamanho_imagem)


func test_cada_pessoa_da_folha_e_a_do_nome_do_arquivo() -> void:
	# Mapeia o grupo da folha para o indice que o `PedestreSprite` usa: errar
	# aqui poe a vovo no corpo do operario na cena.
	var vistos: Dictionary = {}
	for grupo: String in ["vovo", "obra", "praia", "adolescente", "escritorio"]:
		var item := _item("%s_andando" % grupo)
		var avatar := CenaSprite._avatar_do(item)
		assert_str(PedestreSprite.ANDANDO[avatar].resource_path).contains(grupo)
		vistos[avatar] = true
	assert_int(vistos.size()).is_equal(5)


func test_cada_animacao_vira_o_estado_certo_da_pessoa() -> void:
	var esperado := {
		"andando": Pessoa.Estado.ANDANDO,
		"susto": Pessoa.Estado.SUSTO,
		"desembarcando": Pessoa.Estado.DESEMBARCANDO,
		"voando": Pessoa.Estado.VOANDO,
		"caida": Pessoa.Estado.CAIDA,
	}
	for animacao: String in esperado:
		assert_int(CenaSprite._estado_de(_item("vovo_%s" % animacao))).is_equal(esperado[animacao])
