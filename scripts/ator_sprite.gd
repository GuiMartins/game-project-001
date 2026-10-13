class_name AtorSprite
extends MeshInstance3D
## O ator desenhado em sprite, no lugar do modelo 3D: o experimento de
## comparar o Road Rash de sprite com o que o jogo tem hoje.
##
## Os quadros sao recortados das folhas do Google Flow por
## `arte/sprites_flow.gd`, e a ordem deles no atlas e a de `QUADROS` la. Quem
## decide qual quadro mostrar e o `Entregador`, que ja sabe a inclinacao e o
## soco: este no so recebe o estado e escolhe a celula.
##
## O modelo 3D continua montado embaixo, invisivel para a camera e lancando a
## sombra (`SHADOWS_ONLY`): billboard nao tem silhueta para projetar no chao,
## e a sombra de contato e o pilar que faz o ator nao flutuar.

const ATLAS: Texture2D = preload("res://assets/sprites/entregador.png")
const SHADER: Shader = preload("res://scripts/ator_sprite.gdshader")
const SHADER_FOCO: Shader = preload("res://scripts/ator_sprite_foco.gdshader")

## As medidas do atlas, as mesmas de `arte/sprites_flow.gd`: quantos quadros,
## o tamanho de cada celula, onde fica o pe do pneu traseiro nela e a altura
## do piloto em pixels. Mudou la, muda aqui.
const QUADROS: int = 11
const CELULA := Vector2(176.0, 132.0)
const PE := Vector2(88.0, 128.0)
const ALTURA_PX: float = 120.0

## Os cinco quadros da curva, de deitado para a esquerda a deitado para a
## direita, e quantos graus de inclinacao separam um do outro. As folhas
## desenham perto de 15 e 30 graus; a moto deita ate 38, e passa do ultimo
## quadro deitada mais do que ele mostra.
const RETO: int = 2
const PASSO_DA_CURVA: float = 15.0
## Os tres quadros do soco por lado (arma, estica, recolhe), -1 esquerda.
const SOCO: Dictionary[int, Array] = {-1: [5, 6, 7], 1: [8, 9, 10]}

var _material := ShaderMaterial.new()
## O modelo que este sprite substitui agora, e se o sprite estava na tela.
var _modelo: Node3D
var _na_tela: bool = false


func _init() -> void:
	name = "Sprite"
	_material.shader = SHADER
	_material.set_shader_parameter("atlas", ATLAS)
	_material.set_shader_parameter("quadros", QUADROS)
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Nasce escondido: quem liga e o `Entregador`, so com o `sprite` ligado.
	visible = false
	mesh = QuadMesh.new()


## Dimensiona o quad pela altura de `modelo`, do asfalto ao topo do capacete
## no espaco de `ancestral`, com o pe do pneu traseiro `recuo` metros atras da
## origem.
##
## A altura vem do modelo montado, e nao de uma constante: a XRE e mais alta
## que a CG, e o sprite em cima dela tem de crescer junto.
func medir(modelo: Node3D, ancestral: Node3D, recuo: float) -> void:
	var topo := 0.0
	for malha: Node in modelo.find_children("*", "MeshInstance3D", true, false):
		var xform := Transform3D.IDENTITY
		var atual: Node = malha
		while atual != ancestral and atual is Node3D:
			xform = (atual as Node3D).transform * xform
			atual = atual.get_parent()
		topo = maxf(topo, (xform * (malha as MeshInstance3D).get_aabb()).end.y)
	var m := topo / ALTURA_PX
	var quad := mesh as QuadMesh
	quad.size = CELULA * m
	# O quad nasce centrado; o pe do pneu tem de cair na origem do no.
	quad.center_offset = Vector3((CELULA.x * 0.5 - PE.x) * m, (PE.y - CELULA.y * 0.5) * m, 0.0)
	position = Vector3(0.0, 0.0, recuo)


## Poe o sprite ou o `modelo` na tela.
##
## O modelo nao sai da arvore com o sprite ligado: so deixa de ser visto, e
## continua lancando a sombra. A sombra de cada malha so troca na virada, e
## nao a cada passo, porque sao umas sessenta malhas por ator; moto trocada e
## malha nova, que nasce lancando sombra normal, e conta como virada.
func mostrar(modelo: Node3D, na_tela: bool) -> void:
	if na_tela == _na_tela and modelo == _modelo:
		return
	_na_tela = na_tela
	_modelo = modelo
	visible = na_tela
	var sombra := (
		GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		if na_tela
		else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	)
	for malha: Node in modelo.find_children("*", "MeshInstance3D", true, false):
		(malha as MeshInstance3D).cast_shadow = sombra


func pintar(cor: Color) -> void:
	_material.set_shader_parameter("cor", cor)


func marcar_foco(sim: bool) -> void:
	_material.shader = SHADER_FOCO if sim else SHADER


## O quadro deste passo. `inclinacao` em radianos, positiva para a direita;
## `soco_lado` -1 ou 1, e `soco_fase` 0 armando, 1 esticado, 2 recolhendo, ou
## -1 sem soco.
func posar(inclinacao: float, soco_lado: int, soco_fase: int) -> void:
	if not _na_tela:
		return
	var quadro := RETO
	if soco_fase >= 0:
		quadro = SOCO[-1 if soco_lado < 0 else 1][clampi(soco_fase, 0, 2)]
	else:
		var passos := roundi(rad_to_deg(inclinacao) / PASSO_DA_CURVA)
		quadro = RETO + clampi(passos, -RETO, RETO)
	_material.set_shader_parameter("quadro", quadro)
