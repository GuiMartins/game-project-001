class_name ProvaProjetor
extends Node
## A janela da prova do projetor (`dev.py projetor`): a `TelaProjetor` de
## 640 x 360 num `SubViewport` ampliado em pixel inteiro, como o jogo faz
## (`stretch_shrink`, e nunca `SubViewport.size`: com `stretch` ligado o
## container sobrescreve o tamanho).
##
## `--auto` pilota sozinho, e `--captura=<arquivo.png>` salva a tela depois de
## `--espera=<s>` segundos e sai; `--vel=<m/s>` baixa o teto de velocidade, para conferir sem olhar.

const AMPLIACAO: int = 3

var _tela := TelaProjetor.new()


func _ready() -> void:
	var args := _argumentos()
	_tela.automatico = args.has("auto")
	if args.has("vel"):
		_tela.teto = float(args["vel"])
	var recipiente := SubViewportContainer.new()
	recipiente.stretch = true
	recipiente.stretch_shrink = AMPLIACAO
	recipiente.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	recipiente.set_anchors_preset(Control.PRESET_FULL_RECT)
	var viewport := SubViewport.new()
	viewport.handle_input_locally = false
	viewport.add_child(_tela)
	recipiente.add_child(viewport)
	var camada := CanvasLayer.new()
	camada.add_child(recipiente)
	add_child(camada)
	if args.has("captura"):
		_captura_e_sai.call_deferred(String(args["captura"]), float(args.get("espera", 2.0)))


func _unhandled_key_input(evento: InputEvent) -> void:
	var tecla := evento as InputEventKey
	if tecla != null and tecla.pressed and tecla.keycode == KEY_ESCAPE:
		get_tree().quit()


func _captura_e_sai(caminho: String, espera: float) -> void:
	await get_tree().create_timer(espera).timeout
	await RenderingServer.frame_post_draw
	var imagem := get_viewport().get_texture().get_image()
	var erro := imagem.save_png(caminho)
	print("captura: ", caminho, " (", error_string(erro), ")")
	get_tree().quit(0 if erro == OK else 1)


static func _argumentos() -> Dictionary:
	var args: Dictionary = {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--"):
			var partes := arg.trim_prefix("--").split("=", true, 1)
			args[partes[0]] = partes[1] if partes.size() > 1 else true
	return args
