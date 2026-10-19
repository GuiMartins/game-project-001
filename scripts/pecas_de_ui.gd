class_name PecasDeUi
extends RefCounted
## As pecas de interface que o testador de sprites repete: rotulo, caixa de
## marcar, slider e botoes lado a lado.
##
## Nenhum botao daqui toma o foco do teclado. Sem isso, o botao que acabou de
## ser clicado passa a receber a barra de espaco e as setas, e o playground
## (onde as setas conduzem a moto e a pessoa) viraria navegacao de menu.


static func rotulo(texto: String) -> Label:
	var item := Label.new()
	item.text = texto
	item.modulate = Color(1, 1, 1, 0.75)
	return item


static func botao(texto: String, ao_apertar: Callable) -> Button:
	var item := Button.new()
	item.text = texto
	item.focus_mode = Control.FOCUS_NONE
	item.pressed.connect(ao_apertar)
	return item


static func marcar(texto: String, ligado: bool, ao_mudar: Callable) -> CheckBox:
	var caixa := CheckBox.new()
	caixa.text = texto
	caixa.button_pressed = ligado
	caixa.focus_mode = Control.FOCUS_NONE
	caixa.toggled.connect(ao_mudar)
	return caixa


static func slider(
	minimo: float, maximo: float, passo: float, valor: float, ao_mudar: Callable
) -> HSlider:
	var item := HSlider.new()
	item.min_value = minimo
	item.max_value = maximo
	item.step = passo
	item.value = valor
	item.custom_minimum_size.x = 140
	item.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	item.focus_mode = Control.FOCUS_NONE
	item.value_changed.connect(ao_mudar)
	return item


## Botoes lado a lado, um sempre marcado: o que uma lista suspensa esconde atras
## de um clique, e que aqui se troca com um so.
static func segmentado(nomes: Array, marcado: int, ao_escolher: Callable) -> HBoxContainer:
	var caixa := HBoxContainer.new()
	caixa.add_theme_constant_override("separation", 0)
	var grupo := ButtonGroup.new()
	for i in nomes.size():
		var item := Button.new()
		item.text = nomes[i]
		item.toggle_mode = true
		item.button_group = grupo
		item.focus_mode = Control.FOCUS_NONE
		item.set_pressed_no_signal(i == marcado)
		item.pressed.connect(ao_escolher.bind(i))
		caixa.add_child(item)
	return caixa


## Marca o botao `indice` de um `segmentado` sem disparar a escolha.
static func marca_o_segmento(grupo: Control, indice: int) -> void:
	var botoes := grupo.get_children()
	for i in botoes.size():
		(botoes[i] as Button).set_pressed_no_signal(i == indice)
