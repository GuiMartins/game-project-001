class_name PedestreSprite
extends MeshInstance3D
## O desenho de uma `Pessoa`. A mesma folha e o mesmo shader tambem servem aos
## `MultiMesh` da calcada; so o relogio e o quadro mudam de dono.

const SHADER: Shader = preload("res://scripts/pedestre_sprite.gdshader")
const ANDANDO: Array[Texture2D] = [
	preload("res://assets/sprites/pedestres/vovo_andando.png"),
	preload("res://assets/sprites/pedestres/obra_andando.png"),
	preload("res://assets/sprites/pedestres/praia_andando.png"),
	preload("res://assets/sprites/pedestres/adolescente_andando.png"),
	preload("res://assets/sprites/pedestres/escritorio_andando.png"),
]
const PRAIA: int = 2
const SUSTO: Array[Texture2D] = [
	preload("res://assets/sprites/pedestres/vovo_susto.png"),
	preload("res://assets/sprites/pedestres/obra_susto.png"),
	preload("res://assets/sprites/pedestres/praia_susto.png"),
	preload("res://assets/sprites/pedestres/adolescente_susto.png"),
	preload("res://assets/sprites/pedestres/escritorio_susto.png"),
]
const DESEMBARCANDO: Array[Texture2D] = [
	preload("res://assets/sprites/pedestres/vovo_desembarcando.png"),
	preload("res://assets/sprites/pedestres/obra_desembarcando.png"),
	preload("res://assets/sprites/pedestres/praia_desembarcando.png"),
	preload("res://assets/sprites/pedestres/adolescente_desembarcando.png"),
	preload("res://assets/sprites/pedestres/escritorio_desembarcando.png"),
]
const VOANDO: Array[Texture2D] = [
	preload("res://assets/sprites/pedestres/vovo_voando.png"),
	preload("res://assets/sprites/pedestres/obra_voando.png"),
	preload("res://assets/sprites/pedestres/praia_voando.png"),
	preload("res://assets/sprites/pedestres/adolescente_voando.png"),
	preload("res://assets/sprites/pedestres/escritorio_voando.png"),
]
const CAIDA: Array[Texture2D] = [
	preload("res://assets/sprites/pedestres/vovo_caida.png"),
	preload("res://assets/sprites/pedestres/obra_caida.png"),
	preload("res://assets/sprites/pedestres/praia_caida.png"),
	preload("res://assets/sprites/pedestres/adolescente_caida.png"),
	preload("res://assets/sprites/pedestres/escritorio_caida.png"),
]
const PPM: float = 100.0

var _material := ShaderMaterial.new()
var _quadro := QuadMesh.new()


func _init() -> void:
	name = "Sprite"
	_material.shader = SHADER
	material_override = _material
	mesh = _quadro
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false
	_configurar(ANDANDO[PRAIA], Vector2i(160, 200), Vector2i(80, 196), 8, 5, 0)


## Um material por atlas: todos os quads da mesma pessoa compartilham o desenho.
static func material_do_atlas(atlas: Texture2D) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter(&"atlas", atlas)
	mat.set_shader_parameter(&"colunas", 8)
	mat.set_shader_parameter(&"linhas", 5)
	mat.set_shader_parameter(&"multidao", true)
	return mat


static func malha_da_multidao(atlas: Texture2D) -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(160.0, 200.0) / PPM
	quad.center_offset = Vector3(0.0, 0.96, 0.0)
	quad.material = material_do_atlas(atlas)
	return quad


func posar(
	estado: Pessoa.Estado, fase: float, relogio: float, giro: float, rapidez: float, avatar: int
) -> void:
	if not visible:
		return
	var atlas: Texture2D = ANDANDO[avatar]
	var celula := Vector2i(160, 200)
	var pe := Vector2i(80, 196)
	var colunas := 8
	var linhas := 5
	var angulos := 0
	var quadro := 0
	position.y = 0.0
	match estado:
		Pessoa.Estado.ANDANDO:
			quadro = posmod(floori(fase / TAU * 8.0), 8)
		Pessoa.Estado.SUSTO:
			atlas = SUSTO[avatar]
			celula = Vector2i(224, 224)
			pe = Vector2i(112, 220)
			colunas = 6
			linhas = 3
			angulos = 1
			quadro = mini(floori(relogio / (Pessoa.SUSTO_DURA + Pessoa.SUSTO_OLHA) * 6.0), 5)
		Pessoa.Estado.SENTADA, Pessoa.Estado.DESEMBARCANDO:
			atlas = DESEMBARCANDO[avatar]
			celula = Vector2i(256, 208)
			pe = Vector2i(128, 204)
			linhas = 4
			angulos = 2
			if estado == Pessoa.Estado.DESEMBARCANDO:
				quadro = mini(floori(relogio / 2.5 * 8.0), 7)
		Pessoa.Estado.VOANDO:
			atlas = VOANDO[avatar]
			celula = Vector2i(240, 240)
			pe = Vector2i(120, 120)
			linhas = 4
			angulos = 3
			quadro = posmod(floori(relogio * 8.0), 8)
			position.y = Pessoa.PIVO.y
		Pessoa.Estado.CAIDA:
			atlas = CAIDA[avatar]
			celula = Vector2i(224, 112)
			pe = Vector2i(112, 108)
			colunas = 3
			linhas = 4
			angulos = 3
			quadro = 1 if rapidez > 0.1 else 2
			position.y = Pessoa.PIVO.y
	_configurar(atlas, celula, pe, colunas, linhas, angulos)
	_material.set_shader_parameter(&"quadro", quadro)
	_material.set_shader_parameter(&"giro", giro if estado == Pessoa.Estado.VOANDO else 0.0)


func _configurar(
	atlas: Texture2D, celula: Vector2i, pe: Vector2i, colunas: int, linhas: int, angulos: int
) -> void:
	if _material.get_shader_parameter(&"atlas") != atlas:
		_material.set_shader_parameter(&"atlas", atlas)
		_quadro.size = Vector2(celula) / PPM
		_quadro.center_offset = Vector3(
			(float(celula.x) * 0.5 - pe.x) / PPM, (pe.y - float(celula.y) * 0.5) / PPM, 0.0
		)
		_material.set_shader_parameter(&"colunas", colunas)
		_material.set_shader_parameter(&"linhas", linhas)
		_material.set_shader_parameter(&"angulos", angulos)
