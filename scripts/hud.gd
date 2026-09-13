class_name Hud
extends CanvasLayer
## HUD desenhada DENTRO do SubViewport de 320x180.
##
## De proposito: se a interface renderizar em resolucao nativa e o mundo em
## 320x180, o resultado e aquele visual meio-termo de remaster preguicoso. Texto
## pequeno e serrilhado faz parte do look.

const W: int = 320
const H: int = 180

var run: RaceRun
var player: PlayerBike

var _timer_label: Label
var _distance_label: Label
var _position_label: Label
var _speed_label: Label
var _stars_label: Label
var _combo_label: Label
var _event_label: Label
var _wrong_way_label: Label
var _adrenaline_fill: ColorRect
var _end_panel: Control
var _end_text: Label
var _hint_label: Label

var _event_time: float = 0.0
var _position_flash: float = 0.0
var _combo_flash: float = 0.0
var _hint_time: float = 0.0
var _last_position: int = 0


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_timer_label = _label(root, Vector2(6, 4), 16, Color(1, 1, 1))
	_distance_label = _label(root, Vector2(7, 22), 8, Color(0.72, 0.78, 0.9))

	# A colocacao mora no topo, no meio, e e o maior numero da tela depois da
	# velocidade: o jogo e uma corrida, e a pergunta que o jogador faz o tempo
	# todo e "em que lugar eu estou?".
	_position_label = _label(root, Vector2(W * 0.5 - 40.0, 2), 16, Color(1, 1, 1))
	_position_label.size = Vector2(80, 20)
	_position_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var position_caption := _label(root, Vector2(W * 0.5 - 40.0, 20), 8, Color(0.7, 0.75, 0.85))
	position_caption.size = Vector2(80, 10)
	position_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	position_caption.text = "POSICAO"

	_stars_label = _label(root, Vector2(W - 70, 4), 16, Color(1.0, 0.85, 0.25))
	_stars_label.size = Vector2(64, 20)
	_stars_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	_speed_label = _label(root, Vector2(6, H - 26), 16, Color(1, 1, 1))
	_label(root, Vector2(46, H - 14), 8, Color(0.7, 0.75, 0.85)).text = "km/h"

	_adrenaline_fill = _bar(root, Rect2(W - 68, H - 12, 62, 6), Color(0.3, 0.85, 1.0))
	_label(root, Vector2(W - 68, H - 24), 8, Color(0.5, 0.8, 0.95)).text = "ADRENALINA"

	_combo_label = _label(root, Vector2(0, 52), 16, Color(1.0, 0.9, 0.4))
	_combo_label.size = Vector2(W, 20)
	_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_event_label = _label(root, Vector2(0, 76), 8, Color(1, 1, 1))
	_event_label.size = Vector2(W, 12)
	_event_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_wrong_way_label = _label(root, Vector2(0, 34), 16, Color(1.0, 0.35, 0.3))
	_wrong_way_label.size = Vector2(W, 20)
	_wrong_way_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wrong_way_label.text = "CONTRAMAO"
	_wrong_way_label.visible = false

	_hint_label = _label(root, Vector2(6, H - 42), 8, Color(0.45, 0.5, 0.6))
	_hint_label.text = "WASD  Q/E soco  SHIFT boost  1 pixel  2 camera  3 tuning  R reinicia"

	# Carimbo de versao, e se isto e o executavel ou o projeto rodando da
	# fonte. Existe porque "continua igual" e "voce esta abrindo o build
	# antigo" sao indistinguiveis sem ele, e ja custaram uma rodada de teste.
	var stamp := _label(root, Vector2(W - 96, H - 10), 8, Color(0.35, 0.38, 0.48))
	stamp.text = (
		"v%s %s"
		% [
			ProjectSettings.get_setting("application/config/version", "?"),
			"build" if OS.has_feature("template") else "fonte"
		]
	)

	_end_panel = Control.new()
	_end_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_end_panel.visible = false
	_end_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_end_panel)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.05, 0.09, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_end_panel.add_child(dim)
	_end_text = _label(_end_panel, Vector2(0, 26), 8, Color(1, 1, 1))
	_end_text.size = Vector2(W, H - 40)
	_end_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _label(parent: Control, pos: Vector2, size: int, color: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	# Contorno preto: sem ele o texto claro some no asfalto claro do meio-dia.
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _bar(parent: Control, rect: Rect2, color: Color) -> ColorRect:
	var back := ColorRect.new()
	back.position = rect.position
	back.size = rect.size
	back.color = Color(0, 0, 0, 0.55)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(back)
	var fill := ColorRect.new()
	fill.position = rect.position
	fill.size = rect.size
	fill.color = color
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(fill)
	return fill


func bind(a_run: RaceRun, a_player: PlayerBike) -> void:
	run = a_run
	player = a_player
	_end_panel.visible = false
	# A lista de teclas some depois da largada: no meio do transito ela vira
	# ruido em cima da pista.
	_hint_time = 7.0
	_last_position = a_run.position


func show_event(text: String, color: Color) -> void:
	_event_label.text = text
	_event_label.add_theme_color_override("font_color", color)
	_event_time = 1.6


func show_result(text: String) -> void:
	_end_text.text = text
	_end_panel.visible = true


func _process(delta: float) -> void:
	if run == null or player == null:
		return

	_timer_label.text = "%d:%04.1f" % [int(run.time_left / 60.0), fmod(run.time_left, 60.0)]
	_timer_label.add_theme_color_override(
		"font_color", Color(1.0, 0.35, 0.3) if run.time_left < 15.0 else Color(1, 1, 1)
	)
	if run.late:
		_timer_label.text = "ATRASADO"
	_distance_label.text = "%.0f m restantes" % maxf(run.distance_total - run.distance_done, 0.0)

	# Pisca por um instante na troca de posicao. O aviso de texto some em 1,6 s,
	# e sem o pisca a unica coisa que marca uma ultrapassagem e um numero que
	# muda no canto sem ninguem olhar.
	if run.position != _last_position:
		_position_flash = 0.6
		_last_position = run.position
	_position_flash = maxf(_position_flash - delta, 0.0)
	_position_label.text = run.position_text()
	_position_label.add_theme_color_override(
		"font_color", Color(1.0, 0.9, 0.4) if _position_flash > 0.0 else Color(1, 1, 1)
	)

	_speed_label.text = "%3.0f" % player.speed_kmh()
	_stars_label.text = "*".repeat(run.stars())
	_adrenaline_fill.size.x = 62.0 * (player.adrenaline / 100.0)
	_adrenaline_fill.color = Color(1.0, 0.9, 0.3) if player.boosting else Color(0.3, 0.85, 1.0)

	if run.combo >= 2:
		_combo_flash = 0.35
		_combo_label.text = "CORREDOR x%d" % run.combo
	_combo_flash = maxf(_combo_flash - delta, 0.0)
	_combo_label.visible = _combo_flash > 0.0

	_event_time = maxf(_event_time - delta, 0.0)
	_event_label.visible = _event_time > 0.0
	_wrong_way_label.visible = player.wrong_way
	_hint_time = maxf(_hint_time - delta, 0.0)
	_hint_label.visible = _hint_time > 0.0
