extends CanvasLayer
class_name TuningPanel
## Painel de ajuste ao vivo (F3), em resolucao nativa.
##
## O prototipo tem uma semana pra responder "acelerar, inclinar e bater esta
## gostoso?". Recompilar entre cada palpite mata a iteracao. Aqui os valores
## mudam com a moto andando e sobrevivem ao fechar o jogo.
##
## Ele mora FORA do SubViewport de 320x180 de proposito: e ferramenta, nao
## jogo, e slider pixelado e slider que ninguem acerta.
##
## Mostra dois recursos: a moto (BikeTuning) e o mundo (WorldTuning). Sao
## perguntas diferentes - "a moto esta gostosa?" e "o corredor esta passavel?"
## - e o painel mantem elas visualmente separadas por isso.

const COLUMN_WIDTH: int = 540
const PANEL_WIDTH: int = 560
## Altura do slider. Generosa de proposito: 16px era certeiro demais pra pegar
## com o mouse, e errar o alvo no meio de uma volta e o que quebra a iteracao.
const SLIDER_HEIGHT: int = 26

var tuning: BikeTuning
var world_tuning: WorldTuning

var _resources: Array[Resource] = []
var _rows: Array[Dictionary] = []
var _status: Label


func setup(a_tuning: BikeTuning, a_world_tuning: WorldTuning) -> void:
	tuning = a_tuning
	world_tuning = a_world_tuning
	_resources = [a_tuning, a_world_tuning]
	layer = 20
	visible = false

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	panel.offset_right = PANEL_WIDTH
	add_child(panel)

	var scroll := ScrollContainer.new()
	panel.add_child(scroll)

	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(COLUMN_WIDTH, 0)
	scroll.add_child(column)

	var title := Label.new()
	title.text = "TUNING  (F3 fecha)"
	title.add_theme_font_size_override("font_size", 20)
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
	_status.add_theme_font_size_override("font_size", 13)
	_status.text = "editando em memoria"
	column.add_child(_status)

	_add_resource(column, "MOTO", a_tuning)
	_add_resource(column, "MUNDO", a_world_tuning)


func _add_resource(parent: Control, title: String, res: Resource) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 18)
	parent.add_child(spacer)

	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
	parent.add_child(label)
	parent.add_child(HSeparator.new())

	## Os grupos vem do @export_group no recurso, na mesma ordem do arquivo.
	## Sao dezenas de sliders - lista corrida vira sopa.
	for prop: Dictionary in res.get_property_list():
		var usage: int = int(prop["usage"])
		if usage & PROPERTY_USAGE_GROUP:
			_add_group_header(parent, String(prop["name"]))
			continue
		if not (usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		if prop["hint"] != PROPERTY_HINT_RANGE:
			continue
		_add_row(parent, res, prop)


func _add_group_header(parent: Control, text: String) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	parent.add_child(spacer)

	var label := Label.new()
	label.text = text.to_upper()
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.55, 0.82, 1.0))
	parent.add_child(label)


func _add_row(parent: Control, res: Resource, prop: Dictionary) -> void:
	var parts := String(prop["hint_string"]).split(",")
	if parts.size() < 2:
		return
	var prop_name := String(prop["name"])
	var step := parts[2].to_float() if parts.size() > 2 else 0.01
	var fmt := "%%.%df" % _decimals_for(step)

	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	parent.add_child(row)

	var header := HBoxContainer.new()
	row.add_child(header)
	var name_label := Label.new()
	name_label.text = prop_name
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.custom_minimum_size = Vector2(300, 0)
	header.add_child(name_label)
	var value_label := Label.new()
	value_label.add_theme_font_size_override("font_size", 15)
	header.add_child(value_label)

	var slider := HSlider.new()
	slider.min_value = parts[0].to_float()
	slider.max_value = parts[1].to_float()
	slider.step = step
	slider.value = float(res.get(prop_name))
	slider.custom_minimum_size = Vector2(COLUMN_WIDTH - 20, SLIDER_HEIGHT)
	row.add_child(slider)

	value_label.text = fmt % slider.value
	slider.value_changed.connect(func(v: float) -> void:
		res.set(prop_name, v)
		value_label.text = fmt % v
		_status.text = "editando em memoria (nao salvo)"
	)

	_rows.append({"name": prop_name, "res": res, "slider": slider,
		"value": value_label, "fmt": fmt})


## Casas decimais que o passo do slider realmente distingue.
##
## Antes era "%.3f" fixo, e `drag` (passo 0.0005) aparecia como 0.002 parado
## enquanto o slider andava: o numero mentia sobre o que estava mudando.
static func _decimals_for(step: float) -> int:
	if step <= 0.0:
		return 3
	for d: int in range(0, 5):
		var scaled: float = step * pow(10.0, d)
		if absf(scaled - round(scaled)) < 1e-9:
			return d
	return 4


func refresh() -> void:
	for row: Dictionary in _rows:
		var slider: HSlider = row["slider"]
		var res: Resource = row["res"]
		var value: float = float(res.get(String(row["name"])))
		slider.set_value_no_signal(value)
		(row["value"] as Label).text = String(row["fmt"]) % value


func _on_save() -> void:
	for res: Resource in _resources:
		res.call("save")
	_status.text = "salvo em user://"


func _on_reset() -> void:
	for res: Resource in _resources:
		res.call("reset_to_default")
	refresh()
	_status.text = "voltou pro padrao (nao salvo)"


func toggle() -> void:
	visible = not visible
	if visible:
		refresh()
