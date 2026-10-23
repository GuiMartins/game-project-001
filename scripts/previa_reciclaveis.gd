class_name PreviaReciclaveis
extends Control
## Bancada inteiramente 2D para conferir o efeito enquanto os atlas do catador
## estao em producao. Usa a mesma instancia reutilizavel que recebera o impacto.


class Chao:
	extends Node2D

	func _ready() -> void:
		get_viewport().size_changed.connect(queue_redraw)

	func _draw() -> void:
		var tamanho := get_viewport_rect().size
		draw_rect(Rect2(Vector2.ZERO, tamanho), Color("34373b"))
		# Pouco contraste: o lixo claro e o saco preto precisam ler no asfalto.
		for y in range(0, int(tamanho.y), 12):
			for x in range(0, int(tamanho.x), 17):
				var desloca := (y * 7 + x * 3) % 11
				draw_rect(Rect2(x + desloca, y, 2.0, 1.0), Color("42454a"))
		for x in range(0, int(tamanho.x), 100):
			draw_rect(Rect2(x, tamanho.y * 0.84, 54.0, 5.0), Color("ccc8ab"))


var efeito := SacoReciclaveis.new()
var _viewport := SubViewport.new()
var _tempo: float = 0.0
var _aguardando: bool = true
var _rapidez: float = 1.0
var _impulso := Vector2(180.0, -15.0)
var _status := Label.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var fundo := ColorRect.new()
	fundo.color = Color("181b20")
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	var coluna := VBoxContainer.new()
	coluna.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(coluna)
	var barra := HBoxContainer.new()
	coluna.add_child(barra)
	barra.add_child(PecasDeUi.rotulo("Saco de reciclaveis — 2D"))
	barra.add_child(PecasDeUi.botao("Estourar de novo", reiniciar))
	barra.add_child(PecasDeUi.botao("Impacto da esquerda", func() -> void: _direcao(1.0)))
	barra.add_child(PecasDeUi.botao("Impacto da direita", func() -> void: _direcao(-1.0)))
	var lenta := CheckButton.new()
	lenta.text = "Camera lenta"
	lenta.toggled.connect(func(ligado: bool) -> void: _rapidez = 0.25 if ligado else 1.0)
	barra.add_child(lenta)
	barra.add_child(PecasDeUi.botao("Fechar", queue_free))
	coluna.add_child(_status)
	var contentor := SubViewportContainer.new()
	contentor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	contentor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	contentor.stretch = true
	contentor.stretch_shrink = TestadorSprites.ENCOLHE_DO_JOGO
	coluna.add_child(contentor)
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	contentor.add_child(_viewport)
	_viewport.add_child(Chao.new())
	_viewport.add_child(efeito)
	reiniciar.call_deferred()


func reiniciar() -> void:
	efeito.reiniciar(_viewport.get_visible_rect().size * Vector2(0.5, 0.72))
	_tempo = 0.0
	_aguardando = true
	_status.text = "Um saco fechado; o impacto espalha 20 latinhas, 20 garrafas PET e 10 retalhos."


func estourar() -> void:
	_aguardando = false
	efeito.estourar(_impulso)
	# A velocidade da previa e local: nao muda Engine.time_scale do jogo.
	efeito.set_physics_process(false)
	_status.text = "40 reciclaveis: voo, giro, quique e deslize."


func _process(delta: float) -> void:
	_tempo += delta * _rapidez
	if _aguardando and _tempo >= 0.65:
		estourar()
	if not _aguardando:
		efeito.avancar(delta * _rapidez)


func _direcao(lado: float) -> void:
	_impulso.x = absf(_impulso.x) * lado
	reiniciar()
