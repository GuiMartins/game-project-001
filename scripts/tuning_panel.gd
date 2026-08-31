extends CanvasLayer
class_name TuningPanel
## Painel de ajuste ao vivo (F3), em resolucao nativa.
##
## O prototipo tem uma semana pra responder "acelerar, inclinar e bater esta
## gostoso?". Recompilar entre cada palpite mata a iteracao. Aqui os valores
## mudam com a moto andando e sobrevivem ao fechar o jogo.

var tuning: BikeTuning
var _rows: Array[Dictionary] = []
var _status: Label


func setup(a_tuning: BikeTuning) -> void:
	tuning = a_tuning
	layer = 20
	visible = false

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	panel.offset_right = 430
	add_child(panel)

	var scroll := ScrollContainer.new()
	panel.add_child(scroll)

	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(410, 0)
	scroll.add_child(column)

	var title := Label.new()
	title.text = "TUNING  (F3 fecha)"
	title.add_theme_font_size_override("font_size", 16)
	column.add_child(title)

	var buttons := HBoxContainer.new()
	column.add_child(buttons)
	var save_button := Button.new()
	save_button.text = "Salvar"
	save_button.pressed.connect(_on_save)
	buttons.add_child(save_button)
	var reset_button := Button.new()
	reset_button.text = "Restaurar padrao"
	reset_button.pressed.connect(_on_reset)
	buttons.add_child(reset_button)

	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 11)
	_status.text = "editando em memoria"
	column.add_child(_status)

	for prop: Dictionary in tuning.get_property_list():
		if not (prop["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		if prop["hint"] != PROPERTY_HINT_RANGE:
			continue
		_add_row(column, prop)


func _add_row(parent: Control, prop: Dictionary) -> void:
	var parts := String(prop["hint_string"]).split(",")
	if parts.size() < 2:
		return
	var prop_name := String(prop["name"])

	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	parent.add_child(row)

	var header := HBoxContainer.new()
	row.add_child(header)
	var name_label := Label.new()
	name_label.text = prop_name
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.custom_minimum_size = Vector2(230, 0)
	header.add_child(name_label)
	var value_label := Label.new()
	value_label.add_theme_font_size_override("font_size", 12)
	header.add_child(value_label)

	var slider := HSlider.new()
	slider.min_value = parts[0].to_float()
	slider.max_value = parts[1].to_float()
	slider.step = parts[2].to_float() if parts.size() > 2 else 0.01
	slider.value = float(tuning.get(prop_name))
	slider.custom_minimum_size = Vector2(400, 16)
	row.add_child(slider)

	value_label.text = "%.3f" % slider.value
	slider.value_changed.connect(func(v: float) -> void:
		tuning.set(prop_name, v)
		value_label.text = "%.3f" % v
		_status.text = "editando em memoria (nao salvo)"
	)

	_rows.append({"name": prop_name, "slider": slider, "value": value_label})


func refresh() -> void:
	for row: Dictionary in _rows:
		var slider: HSlider = row["slider"]
		var value: float = float(tuning.get(String(row["name"])))
		slider.set_value_no_signal(value)
		(row["value"] as Label).text = "%.3f" % value


func _on_save() -> void:
	tuning.save()
	_status.text = "salvo em %s" % BikeTuning.SAVE_PATH


func _on_reset() -> void:
	tuning.reset_to_default()
	refresh()
	_status.text = "voltou pro padrao (nao salvo)"


func toggle() -> void:
	visible = not visible
	if visible:
		refresh()
