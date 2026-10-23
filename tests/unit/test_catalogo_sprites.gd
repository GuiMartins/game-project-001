extends GdUnitTestSuite
## O catalogo dos sprites (`CatalogoSprites`): a varredura acha tudo o que o
## jogo usa, e a conferencia de cada folha contra a ficha dela.
##
## Os avisos conhecidos estao listados aqui de proposito: folha nova com aviso
## reprova, e a lista so cresce com justificativa. Sem isso o aviso vira
## paisagem na tela do testador, como erro de console que ninguem le.

## Folhas que o catalogo marca e que sao quadros recortados pela propria arte.
## Um quadro de queda ou de desembarque que encosta na celula e a pose
## esticada, nao defeito; o dia que alguem alargar a celula, sai daqui.
const AVISOS_CONHECIDOS: Array[String] = ["escritorio_caida", "obra_desembarcando"]

var _itens: Array[CatalogoSprites.Item] = []


func before_test() -> void:
	_itens = CatalogoSprites.varrer()


func _item(id: String) -> CatalogoSprites.Item:
	for item in _itens:
		if item.id == id:
			return item
	return null


func test_a_varredura_acha_a_moto_e_os_cinco_pedestres_em_cinco_animacoes() -> void:
	assert_object(_item("moto")).is_not_null()
	for pessoa: String in ["vovo", "obra", "praia", "adolescente", "escritorio", "mendigo"]:
		for animacao: String in ["andando", "caida", "desembarcando", "susto", "voando"]:
			assert_object(_item("%s_%s" % [pessoa, animacao])).is_not_null()
	# A moca de moletom so tem a folha de andar.
	assert_object(_item("moletom_andando")).is_not_null()
	assert_object(_item("executivo_andando")).is_not_null()
	assert_int(_itens.size()).is_equal(33)


func test_todo_pedestre_que_o_jogo_carrega_esta_no_catalogo() -> void:
	assert_int(BarraDoJogo.NOMES_DAS_PESSOAS.size()).is_equal(PedestreSprite.ANDANDO.size())
	for textura in PedestreSprite.ANDANDO:
		var id := textura.resource_path.get_file().get_basename()
		assert_object(_item(id)).is_not_null()


func test_a_moto_vem_do_atlas_do_ator() -> void:
	var moto := _item("moto")
	assert_int(moto.colunas).is_equal(AtorSprite.QUADROS)
	assert_vector(Vector2(moto.celula)).is_equal(AtorSprite.CELULA)
	assert_vector(Vector2(moto.tamanho_imagem)).is_equal(
		AtorSprite.CELULA * Vector2(AtorSprite.QUADROS, 1.0)
	)
	assert_int(moto.caixas.size()).is_equal(AtorSprite.QUADROS)


func test_toda_ficha_bate_com_a_imagem() -> void:
	for item in _itens:
		assert_vector(Vector2(item.tamanho_imagem)).is_equal(
			Vector2(item.colunas * item.celula.x, item.linhas * item.celula.y)
		)


func test_so_os_avisos_conhecidos_aparecem() -> void:
	var com_aviso: Array[String] = []
	for item in _itens:
		if not item.avisos.is_empty():
			com_aviso.append(item.id)
	com_aviso.sort()
	var esperado := AVISOS_CONHECIDOS.duplicate()
	esperado.sort()
	assert_array(com_aviso).is_equal(esperado)


func test_o_pe_que_caminha_nao_escorrega_na_ficha() -> void:
	for item in _itens:
		if item.animacao != "andando":
			continue
		for linha in item.linhas:
			for coluna in item.colunas:
				var uso := item.caixa(coluna, linha)
				assert_int(absi(uso.end.y - item.pe.y)).is_less_equal(
					CatalogoSprites.TOLERANCIA_PE_PX
				)


func test_ficha_sem_imagem_vira_aviso_e_nao_some() -> void:
	# O caminho de um id que nao existe: o item nasce com aviso, nao com excecao.
	var item := CatalogoSprites._pedestre("ninguem_andando")
	assert_bool(item.avisos.is_empty()).is_false()
