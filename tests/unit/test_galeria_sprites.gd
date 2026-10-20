extends GdUnitTestSuite
## A galeria de miniaturas (`GaleriaSprites`): uma por folha, o filtro que
## esconde sem refazer e o nome sempre na mesma altura do botao.

## As folhas sao as mesmas da galeria: o filtro compara objeto, e nao nome.
var _itens: Array[CatalogoSprites.Item] = []


func _galeria() -> GaleriaSprites:
	_itens = CatalogoSprites.varrer()
	var galeria: GaleriaSprites = auto_free(GaleriaSprites.new())
	add_child(galeria)
	galeria.montar(_itens)
	return galeria


func _visiveis(galeria: GaleriaSprites) -> int:
	var n := 0
	for botao: Node in galeria.find_children("*", "Button", true, false):
		n += 1 if (botao as Button).visible else 0
	return n


func test_ha_uma_miniatura_por_folha() -> void:
	var galeria := _galeria()
	assert_int(galeria.find_children("*", "Button", true, false).size()).is_equal(27)


func test_mostrar_esconde_o_resto_e_a_pessoa_sem_folha() -> void:
	var galeria := _galeria()
	var so_vovo: Array[CatalogoSprites.Item] = []
	for item in _itens:
		if item.grupo == "Vovo":
			so_vovo.append(item)
	galeria.mostrar(so_vovo)
	assert_int(_visiveis(galeria)).is_equal(5)
	# Os filhos diretos da galeria sao, alternados, o cabecalho e a fileira.
	var cabecalhos_visiveis := 0
	for no in galeria.get_child(0).get_children():
		if no is Label and (no as Label).visible:
			cabecalhos_visiveis += 1
	assert_int(cabecalhos_visiveis).is_equal(1)


func test_o_nome_e_sempre_o_ultimo_filho_do_botao() -> void:
	# Icone alto (de pe) ou baixo (deitado): o nome fica embaixo, na mesma ordem.
	for textura: Texture2D in [null, GaleriaSprites.recorte(CatalogoSprites.varrer()[1], 0, 0)]:
		var botao := GaleriaSprites.botao_com_icone(textura, "nome", Vector2(80, 100))
		auto_free(botao)
		var coluna := botao.get_child(0)
		assert_object(coluna.get_child(coluna.get_child_count() - 1)).is_same(
			botao.get_meta(&"nome")
		)


func test_clique_direito_pede_para_comparar() -> void:
	var galeria := _galeria()
	var pedidos: Array = []
	galeria.comparada.connect(func(item: CatalogoSprites.Item) -> void: pedidos.append(item))
	var botao := galeria.find_children("*", "Button", true, false)[3] as Button
	var evento := InputEventMouseButton.new()
	evento.button_index = MOUSE_BUTTON_RIGHT
	evento.pressed = true
	botao.gui_input.emit(evento)
	assert_int(pedidos.size()).is_equal(1)
