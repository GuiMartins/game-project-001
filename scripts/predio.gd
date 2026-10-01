class_name Predio
extends RefCounted
## Os quatro predios de `arte/predios.py`, prontos para espalhar na avenida.
##
## Cada predio na rua e um `MeshInstance3D` com a malha e o material
## compartilhados: o `.glb` e aberto uma vez so, e o que muda de um predio
## para o outro e a cor, passada por instancia. Por isso nada aqui instancia a
## cena do `.glb` por predio - seriam centenas de arvores de no para mostrar
## quatro malhas.
##
## O modelo olha para -Z (a fachada). Quem coloca so precisa apontar -Z para a
## pista, e afastar o predio pelo `frente`, que ja conta toldo, varanda e
## marquise.

## Do mais baixo ao mais alto. A ordem e a do `NOS` e e contrato com o
## `world.gd`, que escolhe o tipo pela altura sorteada.
enum Tipo { SOBRADO, COMERCIO, ESCRITORIO, TORRE }

const CENA: PackedScene = preload("res://assets/predios/predios.glb")
const SHADER: Shader = preload("res://scripts/predio.gdshader")
const ALBEDO: Texture2D = preload("res://assets/predios/predios_albedo.png")
const MASCARA: Texture2D = preload("res://assets/predios/predios_mascara.png")
const NOS: Array[String] = ["Sobrado", "Comercio", "Escritorio", "Torre"]

## A cor pintada na textura em cada canal da mascara: a celula mais clara sob
## ele em `PALETA`, no `arte/predios.py`. O `test_predio.gd` le a textura e
## reprova se as duas divergirem.
const PINTURA_FABRICA := Color(0.86, 0.78, 0.60)
const LOJA_FABRICA := Color(0.15, 0.35, 0.68)

## As cores de parede da avenida. Tons de reboco do Centro e da Zona Norte:
## claros e um pouco sujos. Cor cheia aqui brigaria com a bag, que tem que ser
## a coisa mais saturada da tela; o LUT do dia ja satura o resto.
const PINTURAS: Array[Color] = [
	Color(0.86, 0.78, 0.60),
	Color(0.92, 0.78, 0.40),
	Color(0.90, 0.62, 0.54),
	Color(0.60, 0.74, 0.82),
	Color(0.64, 0.80, 0.70),
	Color(0.92, 0.90, 0.86),
	Color(0.80, 0.60, 0.40),
	Color(0.72, 0.71, 0.68),
]

## As cores de toldo e letreiro. Aqui pode saturar: loja quer ser vista.
const LOJAS: Array[Color] = [
	Color(0.15, 0.35, 0.68),
	Color(0.75, 0.14, 0.12),
	Color(0.12, 0.52, 0.30),
	Color(0.95, 0.70, 0.10),
	Color(0.90, 0.42, 0.10),
]

static var _malhas: Array[Mesh] = []
static var _material: ShaderMaterial


## Um predio pronto para pendurar no mundo. `pintura` e `loja` de 0 a 1
## escolhem nas listas acima - sao fracoes de sorteio, e nao indices, para o
## `world.gd` nao ter que saber quantas cores existem.
static func criar(tipo: Tipo, pintura: float, loja: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = NOS[tipo]
	mi.mesh = malha(tipo)
	mi.material_override = _material_compartilhado()
	mi.set_instance_shader_parameter("pintura", _escolhe(PINTURAS, pintura))
	mi.set_instance_shader_parameter("loja", _escolhe(LOJAS, loja))
	return mi


static func malha(tipo: Tipo) -> Mesh:
	if _malhas.is_empty():
		var cena := CENA.instantiate()
		for nome in NOS:
			var no := cena.find_child(nome, true, false) as MeshInstance3D
			assert(no != null, "predios.glb sem o no %s" % nome)
			_malhas.append(no.mesh)
		cena.free()
	return _malhas[tipo]


## Da origem do predio ate a ponta mais avancada da fachada, em metros.
static func frente(tipo: Tipo) -> float:
	return -malha(tipo).get_aabb().position.z


static func _escolhe(cores: Array[Color], fracao: float) -> Color:
	return cores[clampi(int(fracao * cores.size()), 0, cores.size() - 1)]


static func _material_compartilhado() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = SHADER
		_material.set_shader_parameter("albedo", ALBEDO)
		_material.set_shader_parameter("mascara", MASCARA)
		_material.set_shader_parameter("pintura_fabrica", PINTURA_FABRICA)
		_material.set_shader_parameter("loja_fabrica", LOJA_FABRICA)
	return _material
