class_name Placa
extends RefCounted
## A placa Mercosul de moto: a faixa azul de "BRASIL" e os sete caracteres.
##
## Moto leva placa de duas linhas, 200 x 170 mm: três letras em cima e, embaixo,
## número, letra e dois números (`ABC` / `1D23`). É o que se lê atrás de uma moto
## de verdade, e o que faz a traseira parecer moto brasileira e não placa
## genérica. A chapa branca é a do modelo (`arte/*.py`); aqui só entra o texto,
## no nó `Placa` que toda moto tem.

const LARGURA: float = 0.20
const ALTURA: float = 0.17
## A faixa azul ocupa o topo, como na placa real (~19 % da altura).
const FAIXA: float = 0.032
const AZUL := Color(0.05, 0.22, 0.58)
const TINTA := Color(0.08, 0.08, 0.09)
## A placa real tem 3 mm de moldura; sem ela o texto encosta na borda.
const MOLDURA: float = 0.004
## Metros por pixel do Label3D. Define o `font_size` (altura / isto, ~100 px
## na linha de caracteres): nítido a 2 m sem pesar, porque a fonte vira textura.
const PIXEL_SIZE: float = 0.0006
## Mesma inclinação da chapa no modelo (`rot_x` de `arte/*.py`); o nó é vazio
## sem rotação, por convenção do gerador, então ela entra aqui.
const INCLINACAO: float = -12.0

const LETRAS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
const DIGITOS := "0123456789"


## A placa ("ABC1D23") de quem mora em `no`. Sai do caminho do nó na árvore, e
## não de um sorteio solto: a mesma moto tem sempre a mesma placa, trocando de
## modelo ou não, e a regressão visual não ganha ruído.
static func do_no(no: Node) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(no.get_path()))
	return _sortear(rng)


static func _sortear(rng: RandomNumberGenerator) -> String:
	var placa := ""
	for i in 3:
		placa += LETRAS[rng.randi_range(0, LETRAS.length() - 1)]
	placa += DIGITOS[rng.randi_range(0, DIGITOS.length() - 1)]
	placa += LETRAS[rng.randi_range(0, LETRAS.length() - 1)]
	for i in 2:
		placa += DIGITOS[rng.randi_range(0, DIGITOS.length() - 1)]
	return placa


## Escreve `texto` ("ABC1D23") no nó `Placa` do modelo. Sem o nó, não faz nada:
## o teste de cada moto é que cobra o nó, e não o jogo em plena corrida.
static func escrever(raiz: Node3D, texto: String) -> void:
	var ancora := raiz.find_child("Placa", true, false) as Node3D
	if ancora == null:
		return
	for velho in ancora.get_children():
		velho.free()
	ancora.rotation_degrees.x = INCLINACAO

	var topo := ALTURA * 0.5
	var faixa := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(LARGURA - 2.0 * MOLDURA, FAIXA)
	faixa.mesh = quad
	faixa.material_override = _material(AZUL)
	faixa.position = Vector3(0.0, topo - MOLDURA - FAIXA * 0.5, 0.0)
	ancora.add_child(faixa)

	ancora.add_child(_rotulo("BRASIL", 0.020, Color.WHITE, topo - MOLDURA - FAIXA * 0.5))
	# As duas linhas dividem o que sobra abaixo da faixa.
	var livre := ALTURA - FAIXA - 2.0 * MOLDURA
	var meio := topo - MOLDURA - FAIXA - livre * 0.5
	ancora.add_child(_rotulo(texto.substr(0, 3), 0.058, TINTA, meio + livre * 0.25))
	ancora.add_child(_rotulo(texto.substr(3), 0.058, TINTA, meio - livre * 0.25))


static func _material(cor: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = cor
	m.roughness = 0.9
	return m


## Um texto de `altura` metros, centrado em `y`. Um fio à frente da faixa e da
## chapa para não brigar com eles no z-buffer a distância.
static func _rotulo(texto: String, altura: float, cor: Color, y: float) -> Label3D:
	var rotulo := Label3D.new()
	rotulo.text = texto
	rotulo.modulate = cor
	rotulo.pixel_size = PIXEL_SIZE
	rotulo.font_size = roundi(altura / PIXEL_SIZE)
	rotulo.outline_size = 0
	rotulo.shaded = true
	rotulo.double_sided = false
	rotulo.position = Vector3(0.0, y, 0.001)
	return rotulo
