class_name GaleriaSprites
extends ScrollContainer
## As folhas como miniaturas, uma fileira por pessoa: o primeiro quadro de cada
## folha no lugar do nome, e o nome da animacao embaixo. A analise marca em
## laranja as que tem aviso.
##
## Os botoes sao montados uma vez; filtrar e marcar so mexem no que ja existe,
## entao a analise em segundo plano atualiza a galeria sem ela piscar.

## A folha foi escolhida (clique), ou escolhida para comparar (botao direito).
signal escolhida(item: CatalogoSprites.Item)
signal comparada(item: CatalogoSprites.Item)

const MINIATURA := Vector2(82, 100)
const COR_DO_AVISO := Color(1.0, 0.8, 0.3)

## Folha -> o botao da miniatura dela; pessoa -> seu cabecalho e sua fileira.
var _miniaturas: Dictionary = {}
var _cabecalhos: Dictionary = {}


func montar(itens: Array[CatalogoSprites.Item]) -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var galeria := VBoxContainer.new()
	galeria.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(galeria)
	var grupo := ButtonGroup.new()
	var dono := ""
	var fluxo: HFlowContainer = null
	for item in itens:
		if item.grupo != dono:
			dono = item.grupo
			var cabecalho := Label.new()
			cabecalho.text = item.grupo
			cabecalho.modulate = Color(1, 1, 1, 0.75)
			galeria.add_child(cabecalho)
			fluxo = HFlowContainer.new()
			galeria.add_child(fluxo)
			_cabecalhos[item.grupo] = [cabecalho, fluxo]
		fluxo.add_child(_miniatura(item, grupo))


## Mostra so as folhas de `visiveis`, e esconde a pessoa que ficou sem nenhuma.
func mostrar(visiveis: Array[CatalogoSprites.Item]) -> void:
	var com_folha: Dictionary = {}
	for item: CatalogoSprites.Item in _miniaturas:
		var passa := visiveis.has(item)
		(_miniaturas[item] as Button).visible = passa
		if passa:
			com_folha[item.grupo] = true
	for grupo: String in _cabecalhos:
		for no: Control in _cabecalhos[grupo]:
			no.visible = com_folha.has(grupo)


## Marca em laranja, com "!" e os avisos na dica, as folhas que tem aviso.
func marcar_avisos() -> void:
	for item: CatalogoSprites.Item in _miniaturas:
		var botao: Button = _miniaturas[item]
		var tem := item.tem_aviso()
		var nome := botao.get_meta(&"nome") as Label
		nome.text = ("! " if tem else "") + item.animacao
		if tem:
			nome.add_theme_color_override("font_color", COR_DO_AVISO)
		else:
			nome.remove_theme_color_override("font_color")
		botao.tooltip_text = item.id
		if tem:
			botao.tooltip_text += "\n" + "\n".join(item.todos_os_avisos())


## Marca a folha aberta, sem disparar a escolha, e rola ate ela: a aberta por
## argumento ou pelas setas pode estar fora da vista.
func marcar(aberta: CatalogoSprites.Item) -> void:
	for item: CatalogoSprites.Item in _miniaturas:
		(_miniaturas[item] as Button).set_pressed_no_signal(item == aberta)
	ensure_control_visible.call_deferred(_miniaturas[aberta] as Control)


func _miniatura(item: CatalogoSprites.Item, grupo: ButtonGroup) -> Button:
	var icone: Texture2D = null
	if item.celula != Vector2i.ZERO:
		# A moto de frente e reta; o resto, o primeiro quadro.
		var quadro := AtorSprite.RETO if item.tipo == CatalogoSprites.Tipo.MOTO else 0
		icone = recorte(item, quadro, 0)
	var botao := botao_com_icone(icone, item.animacao, MINIATURA)
	botao.button_group = grupo
	botao.tooltip_text = item.id
	botao.pressed.connect(escolhida.emit.bind(item))
	botao.gui_input.connect(
		func(evento: InputEvent) -> void:
			var clique := evento as InputEventMouseButton
			if clique != null and clique.pressed and clique.button_index == MOUSE_BUTTON_RIGHT:
				comparada.emit(item)
	)
	_miniaturas[item] = botao
	return botao


## Um botao de marcar com a imagem em cima e o nome embaixo, o nome sempre na
## mesma altura. No `Button` o texto fica logo abaixo do icone, e icone de
## quadro baixo (a queda, deitada) puxava o nome para o meio do botao.
static func botao_com_icone(icone: Texture2D, texto: String, tamanho: Vector2) -> Button:
	var botao := Button.new()
	botao.toggle_mode = true
	botao.custom_minimum_size = tamanho
	botao.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var coluna := VBoxContainer.new()
	coluna.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 4)
	coluna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	botao.add_child(coluna)
	var imagem := TextureRect.new()
	imagem.texture = icone
	imagem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	imagem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	imagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	imagem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coluna.add_child(imagem)
	var nome := Label.new()
	nome.text = texto
	nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nome.add_theme_font_size_override("font_size", 9)
	nome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coluna.add_child(nome)
	botao.set_meta(&"nome", nome)
	return botao


## O quadro (`coluna`, `linha`) de `item` como textura, sem copiar a imagem.
static func recorte(item: CatalogoSprites.Item, coluna: int, linha: int) -> Texture2D:
	var corte := AtlasTexture.new()
	corte.atlas = item.textura()
	corte.region = Rect2(Vector2(coluna, linha) * Vector2(item.celula), Vector2(item.celula))
	return corte
