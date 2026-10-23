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
const SHADER: Shader = preload("res://scripts/sprite.gdshader")
const SHADER_FOCO: Shader = preload("res://scripts/sprite_foco.gdshader")

## As medidas do atlas, as mesmas de `arte/sprites_flow.gd`: quantos quadros,
## o tamanho de cada celula, onde fica o pe do pneu traseiro nela e a altura
## do piloto que pilota reto, em pixels. Mudou la, muda aqui.
const QUADROS: int = 12
const CELULA := Vector2(192.0, 160.0)
const PE := Vector2(96.0, 156.0)
const ALTURA_PX: float = 120.0

## Os cinco quadros da curva, de deitado para a esquerda a deitado para a
## direita.
const RETO: int = 2
## Quantos graus cada quadro da curva desenha a moto deitada, + direita,
## medidos no atlas pelo recorte (`arte/sprites_flow.gd`, `inclinacao`), que
## imprime estes numeros; o teste confere que batem. Mudou o atlas, muda aqui.
##
## Medido, e nao suposto: ate a auditoria (`docs/AUDITORIA_SPRITES.md`, S04)
## o ator supunha 15 e 30 graus, e as folhas desenham 11 e 28. Na troca do
## reto para o primeiro deitado a moto na tela voltava 3 graus, e quem
## oscilava perto dos 7,5 tremia entre os dois quadros.
const INCLINACOES: Array[float] = [-27.8, -11.0, -1.0, 10.8, 27.6]
## Graus que o quadro novo tem de estar mais perto que o atual para tomar o
## lugar dele. Sem folga, a moto que oscila na fronteira entre dois quadros
## pisca de um para o outro a cada pose; o giro do quad cobre a diferenca, e a
## inclinacao na tela continua a da moto.
const FOLGA_DA_TROCA: float = 2.0
## Os tres quadros do soco por lado (arma, estica, recolhe), -1 esquerda.
## O quadro da empinada, e a partir de quanta frente erguida (0..1) ele toma o
## lugar do reto: no meio da subida o desenho ja le como empinada.
const EMPINANDO: int = 11
const EMPINA_DO_QUADRO: float = 0.5
## Quanto o quadro da empinada desenha a moto deitada para a direita: a IA
## nao a deixou reta, e o quad desfaz a diferenca girando em volta do pneu,
## como na curva. Medido no eixo guidao-pneu do desenho.
const EMPINANDO_GRAUS: float = 4.5
const SOCO: Dictionary[int, Array] = {-1: [5, 6, 7], 1: [8, 9, 10]}
## Quanto o afundamento da suspensao e exagerado no sprite. Na escala real, os
## 4 cm de garfo da freada sao 3 px de piloto: existem, mas nao se veem, e o
## sprite parado num quadro so le como recorte colado na pista.
##
## O sprite inteiro desce, e nao encolhe: ate a S03 da auditoria o quad
## achatava na vertical com 2,5 de exagero, a altura oscilava 5% a cada
## lombada, e o piloto parecia crescer e diminuir. Quique de Road Rash e o
## desenho todo descendo e subindo, do mesmo tamanho.
const GINGA: float = 1.5

var _material := ShaderMaterial.new()
## O modelo que este sprite substitui agora, e se o sprite estava na tela.
var _modelo: Node3D
var _na_tela: bool = false
## O quadro da curva na tela, que so troca com folga (`FOLGA_DA_TROCA`).
var _curva: int = RETO


func _init() -> void:
	name = "Sprite"
	_material.shader = SHADER
	_material.set_shader_parameter("atlas", ATLAS)
	_material.set_shader_parameter("colunas", QUADROS)
	_material.set_shader_parameter("linhas", 1)
	_material.set_shader_parameter("quadro", RETO)
	# Uma linha so, vista de tras, e a bag e a camiseta trocam de cor.
	_material.set_shader_parameter("angulos", 4)
	_material.set_shader_parameter("recolore", 1.0)
	_material.set_shader_parameter("celula_px", CELULA)
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


## O quadro deste passo, e o quanto ele gira, desliza e afunda.
##
## `inclinacao` em radianos, positiva para a direita; `soco_lado` -1 ou 1, e
## `soco_fase` 0 armando, 1 esticado, 2 recolhendo, ou -1 sem soco. `ginga` e
## o que o corpo faz por cima da moto, do mesmo estado que posa o modelo 3D:
## rolagem em radianos (+ direita), deslize lateral e afundamento, em metros.
func posar(
	inclinacao: float, soco_lado: int, soco_fase: int, ginga: Vector3, empina: float = 0.0
) -> void:
	if not _na_tela:
		return
	_curva = quadro_da_curva(rad_to_deg(inclinacao), _curva)
	var quadro := _curva
	var desenhado := deg_to_rad(INCLINACOES[_curva])
	if empina >= EMPINA_DO_QUADRO:
		# Frente no ar, vista de tras: um quadro so, reto, que a rolagem da
		# curva ainda inclina por cima. Soco nao entra: ninguem soca empinado.
		quadro = EMPINANDO
		desenhado = deg_to_rad(EMPINANDO_GRAUS)
	elif soco_fase >= 0:
		# O soco e desenhado com a moto em pe; quem deita e o quad inteiro.
		quadro = SOCO[-1 if soco_lado < 0 else 1][clampi(soco_fase, 0, 2)]
		desenhado = 0.0
	_material.set_shader_parameter("quadro", quadro)
	# O quadro desenha a inclinacao de uns poucos angulos, e o resto o quad
	# gira na mao, em volta do pneu: entre dois quadros a moto continua
	# deitando, e passa do ultimo. Sem isto a curva anda aos saltos.
	_material.set_shader_parameter("giro", inclinacao - desenhado + ginga.x)
	_material.set_shader_parameter("desvio", ginga.y)
	_material.set_shader_parameter("afunda", ginga.z * GINGA)


## O quadro da curva para `graus` de inclinacao (+ direita), saindo de `atual`:
## o de inclinacao desenhada mais perto, mas so se ganhar do atual por mais
## que a `FOLGA_DA_TROCA`.
static func quadro_da_curva(graus: float, atual: int) -> int:
	var melhor := atual
	var distancia := absf(graus - INCLINACOES[atual]) - FOLGA_DA_TROCA
	for i in INCLINACOES.size():
		var d := absf(graus - INCLINACOES[i])
		if d < distancia:
			melhor = i
			distancia = d
	return melhor
