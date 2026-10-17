class_name Borrao
extends MeshInstance3D
## O borrao de velocidade (`borrao.gdshader`): o quad na frente da lente e o
## que ele precisa saber a cada quadro - quanto borrar e para onde.
##
## Filho da camera, para o quad nunca sair da frente dela. A conta do quanto
## e do para onde mora aqui, e nao no shader, porque e conta de jogo
## (velocidade, boost, rumo da moto) e o teste unitario alcanca.

## Fracao da velocidade maxima em que o borrao comeca. Abaixo disso, ~55 km/h
## na CG, a cidade passa devagar o bastante para o olho seguir, e borrar ali
## e so sujeira na tela.
const INICIO: float = 0.3
## Ate onde o boost empurra o borrao alem do da velocidade maxima. O boost
## passa de 1,0 (`boost_speed_mult`), e parar um pouco acima e de proposito:
## saturar e o que faz o boost parecer boost (DIRECAO_VISUAL.md), e deixar
## crescer sem teto borra a tela inteira por cima do corredor.
const SATURA: float = 1.25
## Expoente da curva entre o inicio e a maxima (V08a). Reta (1), a 128 km/h -
## a velocidade de todas as referencias - o borrao estava em 55% do inteiro, e
## o asfalto saia quase nitido onde a referencia ja e so risco. Abaixo de 1 a
## curva sobe cedo e achata no alto: em cruzeiro ja risca, e a diferenca para
## o boost continua vindo do `SATURA`.
const CURVA: float = 0.6
## Distancia a frente da moto do ponto que vira o ponto de fuga, em metros.
## Longe o bastante para estar no horizonte: e para la que tudo foge.
const HORIZONTE: float = 1000.0

var tuning: BikeTuning
var target: PlayerBike
var _material: ShaderMaterial


func setup(a_tuning: BikeTuning, a_target: PlayerBike) -> void:
	tuning = a_tuning
	target = a_target
	name = "Borrao"
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	mesh = quad
	# O vertex shader poe o quad na tela inteira, onde a malha estiver: sem
	# isto o motor o descartaria fora do frustum pelo AABB de 2x2 m.
	extra_cull_margin = 16384.0
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material = ShaderMaterial.new()
	_material.shader = preload("res://scripts/borrao.gdshader")
	# Logo depois do foco (`Entregador.foco`), que grava o stencil, e antes de
	# todo o resto do passe transparente: o vidro do carro, desenhado depois,
	# fica nitido por cima; desenhado antes, sumiria, porque a copia da tela
	# que o borrao le e tirada antes dos transparentes.
	_material.render_priority = Material.RENDER_PRIORITY_MIN + 1
	material_override = _material
	# Roda tambem com o mundo congelado: a prova visual congela o mundo e
	# fotografa a moto andando, e o borrao tem de sair no quadro.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	if target == null:
		return
	var camera := get_parent() as Camera3D
	_material.set_shader_parameter(
		"forca", tuning.borrao * intensidade(target.speed, tuning.max_speed)
	)
	if camera != null:
		_material.set_shader_parameter("fuga", fuga(camera, target))


## Quanto borra, de 0 a `SATURA`, pela fracao da velocidade maxima.
static func intensidade(velocidade: float, maxima: float) -> float:
	var fracao := velocidade / maxf(maxima, 1.0)
	var linear := maxf((fracao - INICIO) / (1.0 - INICIO), 0.0)
	return minf(pow(linear, CURVA), SATURA)


## O ponto de fuga do movimento na tela, em UV: para onde a moto vai, e nao o
## centro da lente. Atras da camera (capotada, camera de diagnostico) volta
## para o centro, que e o menos errado.
static func fuga(camera: Camera3D, moto: PlayerBike) -> Vector2:
	var rumo := Vector3(sin(moto.heading), 0.0, cos(moto.heading))
	var longe := camera.global_position + rumo * HORIZONTE
	if camera.is_position_behind(longe):
		return Vector2(0.5, 0.5)
	var tela := camera.get_viewport().get_visible_rect().size
	return camera.unproject_position(longe) / tela
