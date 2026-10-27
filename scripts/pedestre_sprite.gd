class_name PedestreSprite
extends MeshInstance3D
## O desenho de uma `Pessoa`. A mesma folha e o mesmo shader tambem servem aos
## `MultiMesh` da calcada; so o relogio e o quadro mudam de dono.

const SHADER: Shader = preload("res://scripts/sprite.gdshader")
const ANDANDO: Array[Texture2D] = [
	preload("res://assets/sprites/pedestres/vovo_andando.png"),
	preload("res://assets/sprites/pedestres/obra_andando.png"),
	preload("res://assets/sprites/pedestres/praia_andando.png"),
	preload("res://assets/sprites/pedestres/adolescente_andando.png"),
	preload("res://assets/sprites/pedestres/escritorio_andando.png"),
	preload("res://assets/sprites/pedestres/moletom_andando.png"),
	preload("res://assets/sprites/pedestres/executivo_andando.png"),
	preload("res://assets/sprites/pedestres/mendigo_andando.png"),
]
const PRAIA: int = 2
## Elenco aprovado apenas para andar: outras poses conservam a propria identidade.
const APENAS_CAMINHADA: Array[int] = [6]
## A moca de moletom so tem a folha de andar por enquanto: nas outras poses ela
## conserva o escritorio na posicao 5 ate haver o susto, a queda, o voo e o
## desembarque dela. Ver `da_pose`.
## Altura da celula da folha de andar. Quantas linhas a folha tem sai da altura da
## imagem: 4 (sem 3/4 costas), 5 (frente, 3/4, lado, 3/4 costas, costas, com o lado esquerdo
## espelhado) ou 8, com o lado esquerdo desenhado de verdade. A de 8 existe para
## quem tem algo de um lado so (uma bolsa a tiracolo), que trocaria de ombro no
## espelho.
const ALTURA_CELULA_ANDANDO: int = 200
const LINHAS_DOIS_LADOS: int = 8
## As cinco listas mantem o indice de cada pessoa. O moletom conserva o
## escritorio na posicao 5; o executivo conserva sua caminhada na 6.
const ESCRITORIO_SUSTO: Texture2D = preload("res://assets/sprites/pedestres/escritorio_susto.png")
const ESCRITORIO_DESEMBARCANDO: Texture2D = preload(
	"res://assets/sprites/pedestres/escritorio_desembarcando.png"
)
const ESCRITORIO_VOANDO: Texture2D = preload("res://assets/sprites/pedestres/escritorio_voando.png")
const ESCRITORIO_CAIDA: Texture2D = preload("res://assets/sprites/pedestres/escritorio_caida.png")
const SUSTO: Array[Texture2D] = [
	preload("res://assets/sprites/pedestres/vovo_susto.png"),
	preload("res://assets/sprites/pedestres/obra_susto.png"),
	preload("res://assets/sprites/pedestres/praia_susto.png"),
	preload("res://assets/sprites/pedestres/adolescente_susto.png"),
	ESCRITORIO_SUSTO,
	ESCRITORIO_SUSTO,
	ANDANDO[6],
	preload("res://assets/sprites/pedestres/mendigo_susto.png"),
]
const DESEMBARCANDO: Array[Texture2D] = [
	preload("res://assets/sprites/pedestres/vovo_desembarcando.png"),
	preload("res://assets/sprites/pedestres/obra_desembarcando.png"),
	preload("res://assets/sprites/pedestres/praia_desembarcando.png"),
	preload("res://assets/sprites/pedestres/adolescente_desembarcando.png"),
	ESCRITORIO_DESEMBARCANDO,
	ESCRITORIO_DESEMBARCANDO,
	ANDANDO[6],
	preload("res://assets/sprites/pedestres/mendigo_desembarcando.png"),
]
const VOANDO: Array[Texture2D] = [
	preload("res://assets/sprites/pedestres/vovo_voando.png"),
	preload("res://assets/sprites/pedestres/obra_voando.png"),
	preload("res://assets/sprites/pedestres/praia_voando.png"),
	preload("res://assets/sprites/pedestres/adolescente_voando.png"),
	ESCRITORIO_VOANDO,
	ESCRITORIO_VOANDO,
	ANDANDO[6],
	preload("res://assets/sprites/pedestres/mendigo_voando.png"),
]
const CAIDA: Array[Texture2D] = [
	preload("res://assets/sprites/pedestres/vovo_caida.png"),
	preload("res://assets/sprites/pedestres/obra_caida.png"),
	preload("res://assets/sprites/pedestres/praia_caida.png"),
	preload("res://assets/sprites/pedestres/adolescente_caida.png"),
	ESCRITORIO_CAIDA,
	ESCRITORIO_CAIDA,
	ANDANDO[6],
	preload("res://assets/sprites/pedestres/mendigo_caida.png"),
]
## O fiscal da bandeira da chegada: 3 linhas (frente, 3/4 frente, lado) por 8
## quadros do aceno, o mesmo arranjo do susto. A haste e o pano quadriculado
## estao no desenho, e o ciclo e o da varrida que o `Chegada` ja tinha.
const FISCAL_BANDEIRA: Texture2D = preload("res://assets/sprites/pedestres/fiscal_bandeira.png")
const FISCAL_CELULA := Vector2i(340, 370)
const FISCAL_PE := Vector2i(170, 360)
const CICLO_DA_BANDEIRA: float = 1.65
const PPM: float = 100.0

## Liga o desenho do fiscal da bandeira para quem esta parado; no atropelo ele
## cai no desenho do avatar, como qualquer pessoa.
var bandeira: bool = false

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
## A folha da pose do `avatar`. Caminhadas parciais conservam a propria arte;
## o fallback historico da moca de moletom continua sendo o escritorio.
static func da_pose(folhas: Array[Texture2D], avatar: int) -> Texture2D:
	if avatar in APENAS_CAMINHADA:
		return ANDANDO[avatar]
	return folhas[mini(avatar, folhas.size() - 1)]


static func material_do_atlas(atlas: Texture2D) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter(&"atlas", atlas)
	mat.set_shader_parameter(&"colunas", 8)
	var linhas := atlas.get_height() / ALTURA_CELULA_ANDANDO
	mat.set_shader_parameter(&"linhas", linhas)
	mat.set_shader_parameter(&"dois_lados", linhas == LINHAS_DOIS_LADOS)
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
	if bandeira and estado == Pessoa.Estado.PARADA:
		position.y = 0.0
		_configurar(FISCAL_BANDEIRA, FISCAL_CELULA, FISCAL_PE, 8, 3, 1)
		_material.set_shader_parameter(
			&"quadro", posmod(floori(relogio / CICLO_DA_BANDEIRA * 8.0), 8)
		)
		_material.set_shader_parameter(&"giro", 0.0)
		return
	var atlas: Texture2D = ANDANDO[avatar]
	var celula := Vector2i(160, ALTURA_CELULA_ANDANDO)
	var pe := Vector2i(80, 196)
	var colunas := 8
	var linhas := atlas.get_height() / ALTURA_CELULA_ANDANDO
	var angulos := 0
	var quadro := 0
	position.y = 0.0
	if avatar in APENAS_CAMINHADA:
		# A caminhada parcial nao empresta as reacoes de outro personagem.
		# O corpo continua na fisica; a arte fica num quadro da propria folha.
		if estado == Pessoa.Estado.ANDANDO:
			quadro = posmod(floori(fase / TAU * 8.0), 8)
		var no_ar := estado == Pessoa.Estado.VOANDO
		var no_chao := estado == Pessoa.Estado.CAIDA
		if no_ar or no_chao:
			pe = Vector2i(80, 100)
			position.y = Pessoa.PIVO.y
		_configurar(atlas, celula, pe, colunas, linhas, angulos)
		_material.set_shader_parameter(&"quadro", quadro)
		_material.set_shader_parameter(&"giro", giro if no_ar else PI / 2.0 if no_chao else 0.0)
		return
	match estado:
		Pessoa.Estado.ANDANDO:
			quadro = posmod(floori(fase / TAU * 8.0), 8)
		Pessoa.Estado.SUSTO:
			atlas = da_pose(SUSTO, avatar)
			celula = Vector2i(224, 224)
			pe = Vector2i(112, 220)
			colunas = 6
			linhas = 3
			angulos = 1
			quadro = mini(floori(relogio / (Pessoa.SUSTO_DURA + Pessoa.SUSTO_OLHA) * 6.0), 5)
		Pessoa.Estado.SENTADA, Pessoa.Estado.DESEMBARCANDO:
			atlas = da_pose(DESEMBARCANDO, avatar)
			celula = Vector2i(256, 208)
			pe = Vector2i(128, 204)
			linhas = 4
			angulos = 2
			if estado == Pessoa.Estado.DESEMBARCANDO:
				quadro = mini(floori(relogio / 2.5 * 8.0), 7)
		Pessoa.Estado.VOANDO:
			atlas = da_pose(VOANDO, avatar)
			celula = Vector2i(240, 240)
			pe = Vector2i(120, 120)
			linhas = 4
			angulos = 3
			quadro = posmod(floori(relogio * 8.0), 8)
			position.y = Pessoa.PIVO.y
		Pessoa.Estado.CAIDA:
			atlas = da_pose(CAIDA, avatar)
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
	if (
		_material.get_shader_parameter(&"atlas") != atlas
		or _quadro.center_offset.y != (pe.y - float(celula.y) * 0.5) / PPM
	):
		_material.set_shader_parameter(&"atlas", atlas)
		_quadro.size = Vector2(celula) / PPM
		_quadro.center_offset = Vector3(
			(float(celula.x) * 0.5 - pe.x) / PPM, (pe.y - float(celula.y) * 0.5) / PPM, 0.0
		)
		_material.set_shader_parameter(&"colunas", colunas)
		_material.set_shader_parameter(&"linhas", linhas)
		_material.set_shader_parameter(&"angulos", angulos)
		_material.set_shader_parameter(&"dois_lados", angulos == 0 and linhas == LINHAS_DOIS_LADOS)
