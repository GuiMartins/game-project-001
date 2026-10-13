class_name Predio
extends RefCounted
## Os cinco predios de `arte/predios.py`, prontos para espalhar na avenida.
##
## Cada predio na rua e um `MeshInstance3D` com a malha e o material
## compartilhados: o `.glb` e aberto uma vez so, e o que muda de um predio
## para o outro e a cor, passada por instancia. Por isso nada aqui instancia a
## cena do `.glb` por predio - seriam centenas de arvores de no para mostrar
## cinco malhas.
##
## O modelo olha para -Z (a fachada). Quem coloca so precisa apontar -Z para a
## pista, e afastar o predio pelo `frente`, que ja conta toldo, varanda e
## marquise - e nao o outdoor, que passa por cima da calcada.

## Do mais baixo ao mais alto. A ordem e a do `NOS` e e contrato com o
## `cidade.gd`, que escolhe o tipo pela altura sorteada.
enum Tipo { SOBRADO, COMERCIO, DECO, ESCRITORIO, TORRE }

const CENA: PackedScene = preload("res://assets/predios/predios.glb")
const SHADER: Shader = preload("res://scripts/predio.gdshader")
const ALBEDO: Texture2D = preload("res://assets/predios/predios_albedo.png")
const MASCARA: Texture2D = preload("res://assets/predios/predios_mascara.png")
const NOS: Array[String] = ["Sobrado", "Comercio", "Deco", "Escritorio", "Torre"]

## A cor pintada na textura em cada canal da mascara: a celula mais clara sob
## ele em `PALETA`, no `arte/predios.py`. O `test_predio.gd` le a textura e
## reprova se as duas divergirem.
const PINTURA_FABRICA := Color(0.86, 0.78, 0.60)
const LOJA_FABRICA := Color(0.15, 0.35, 0.68)
const TELA_FABRICA := Color(0.20, 0.70, 0.95)

## As cores de parede da avenida: pedra e reboco de pedra, bege, ocre e creme
## (V11a). Nas referencias o corredor e um canion dessa cor so (`video_01/t5.0s`,
## `01_centro`), e a cor viva mora no toldo e no outdoor. Ja foram tons pastel
## de Zona Norte - amarelo, rosa, azul, menta -, e a avenida lia como cenario
## de brinquedo. Cor cheia aqui tambem brigaria com a bag, que tem que ser a
## coisa mais saturada da tela.
const PINTURAS: Array[Color] = [
	Color(0.86, 0.78, 0.60),
	Color(0.82, 0.70, 0.52),
	Color(0.78, 0.62, 0.42),
	Color(0.90, 0.84, 0.72),
	Color(0.72, 0.64, 0.52),
	Color(0.84, 0.66, 0.46),
	Color(0.76, 0.72, 0.64),
	Color(0.92, 0.88, 0.80),
]

## As cores de toldo e letreiro. Aqui pode saturar: loja quer ser vista.
const LOJAS: Array[Color] = [
	Color(0.15, 0.35, 0.68),
	Color(0.75, 0.14, 0.12),
	Color(0.12, 0.52, 0.30),
	Color(0.95, 0.70, 0.10),
	Color(0.90, 0.42, 0.10),
]

## As cores da tela do outdoor. Cor de tela, e nao de tinta: mais pura que a da
## loja, porque o brilho do shader multiplica e o tonemap desbota o que tiver
## um pouco de cada canal. Nenhuma e vermelha: vermelho aceso na altura da rua
## e lanterna de freio, e o aviso do corredor fechando nao pode ter imitacao.
const TELAS: Array[Color] = [
	Color(0.20, 0.70, 0.95),
	Color(0.95, 0.20, 0.60),
	Color(0.98, 0.78, 0.10),
	Color(0.35, 0.85, 0.25),
	Color(0.55, 0.30, 0.95),
	Color(0.98, 0.50, 0.10),
]
## Do chao para cima, o que conta como "na rua" para o `frente`: toldo,
## marquise e a primeira varanda. Acima disso o que avanca passa por cima de
## quem anda, como a bandeira do outdoor do `Deco`, que comeca a 6 m.
const ALTURA_DA_RUA: float = 5.0

static var _malhas: Array[Mesh] = []
static var _frentes: Array[float] = []
static var _material: ShaderMaterial


## Um predio pronto para pendurar no mundo. `pintura` e `loja` de 0 a 1
## escolhem nas listas acima - sao fracoes de sorteio, e nao indices, para o
## `world.gd` nao ter que saber quantas cores existem.
##
## A tela do outdoor sai da mesma fracao da loja, embaralhada: mais um numero
## do sorteio da rua mudaria a cidade inteira dali para frente, e a prova
## visual deixaria de comparar o mesmo quarteirao.
static func criar(tipo: Tipo, pintura: float, loja: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = NOS[tipo]
	mi.mesh = malha(tipo)
	mi.material_override = _material_compartilhado()
	mi.set_instance_shader_parameter("pintura", _escolhe(PINTURAS, pintura))
	mi.set_instance_shader_parameter("loja", _escolhe(LOJAS, loja))
	mi.set_instance_shader_parameter("tela", _escolhe(TELAS, fposmod(loja * 7.0, 1.0)))
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


## Da origem do predio ate a ponta mais avancada da fachada na altura da rua,
## em metros. E o vertice, e nao o AABB: a caixa conta a bandeira do outdoor,
## e o `Deco` recuaria 2 m so por ter um painel a 6 m do chao.
static func frente(tipo: Tipo) -> float:
	if _frentes.is_empty():
		for t: int in Tipo.values():
			var vertices: PackedVector3Array = malha(t).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var ponta := 0.0
			for v in vertices:
				if v.y < ALTURA_DA_RUA:
					ponta = maxf(ponta, -v.z)
			_frentes.append(ponta)
	return _frentes[tipo]


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
		_material.set_shader_parameter("tela_fabrica", TELA_FABRICA)
	return _material
