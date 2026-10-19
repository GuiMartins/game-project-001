class_name AmbienteSprite
extends Node3D
## O ceu, o sol, o tonemap, o LUT e a quantizacao do jogo, para o testador
## de sprites: o mesmo que o `World` monta, sem pista, transito nem corrida.
##
## Serve a `CenaSprite` (o sprite girando) e a `JogoSprite` (o sprite jogavel).
## O que muda com a hora o `Relogio` aplica; a paleta e o passe de tela que o
## `main.gd` poe por cima do 3D.

const CEU: Shader = preload("res://scripts/ceu.gdshader")
const PALETA: Shader = preload("res://scripts/paleta.gdshader")

## A hora do jogo, de 0 (meio-dia) a 1 (noite fechada), pelo `Relogio`.
var hora: float = 0.0:
	set(valor):
		hora = clampf(valor, 0.0, 1.0)
		if is_node_ready():
			_relogio.fixar(hora)
## A quantizacao com dither do jogo por cima de tudo.
var paleta: bool = false:
	set(valor):
		paleta = valor
		if _tela_da_paleta != null:
			_tela_da_paleta.visible = valor

var _ambiente := Environment.new()
var _sol := DirectionalLight3D.new()
var _ceu := ShaderMaterial.new()
var _relogio := Relogio.new()
var _tela_da_paleta: ColorRect


func _ready() -> void:
	_ceu.shader = CEU
	var ceu := Sky.new()
	ceu.sky_material = _ceu
	_ambiente.background_mode = Environment.BG_SKY
	_ambiente.sky = ceu
	_ambiente.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_ambiente.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_ambiente.tonemap_white = 6.0
	_ambiente.adjustment_enabled = true
	var mundo := WorldEnvironment.new()
	mundo.environment = _ambiente
	add_child(mundo)
	_sol.shadow_enabled = true
	add_child(_sol)
	_monta_paleta()
	add_child(_relogio)
	_relogio.montar(_ambiente, _sol, _ceu)
	_relogio.fixar(hora)


func _exit_tree() -> void:
	# O global e do projeto inteiro: nao deixa a noite do testador para o jogo.
	RenderingServer.global_shader_parameter_set(&"noite", 0.0)
	Relogio.escuro = 0.0


## A quantizacao do jogo, no mesmo lugar: um passe de tela por cima do 3D.
func _monta_paleta() -> void:
	var camada := CanvasLayer.new()
	camada.layer = 5
	get_viewport().add_child.call_deferred(camada)
	_tela_da_paleta = ColorRect.new()
	_tela_da_paleta.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tela_da_paleta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = PALETA
	_tela_da_paleta.material = material
	_tela_da_paleta.visible = paleta
	camada.add_child(_tela_da_paleta)
