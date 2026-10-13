class_name CeuComparacao
extends Node
## Comparacao das abordagens de nuvem da V14, trocadas ao vivo com o 5 (ou F5).
##
## Provisorio: existe para a decisao ser tomada jogando, e nao em quadro
## parado. Decidida, a pasta `scripts/comparacao/` e `assets/visual/comparacao/`
## saem inteiras, junto com a linha que cria isto no `world.gd`.

const NOMES: Array[String] = [
	"atual: textura com trama propria",
	"A: textura lisa, a paleta da tela faz a banda",
	"B: textura com trama, nuvens maiores e esparsas",
	"C: shader de ruido, andando com o vento",
	"D: nuvem como objeto no mundo, chega perto",
	"sem nuvem",
]
## Quantas nuvens-objeto existem em volta da camera.
const OBJETOS: int = 22

var _world: World
var _ceu: ProceduralSkyMaterial
var _sky: Sky
var _ruido := ShaderMaterial.new()
var _texturas: Array[Texture2D] = []
var _objetos: Array[MeshInstance3D] = []
var _rotulo := Label.new()
var _indice: int = 0
var _rng := RandomNumberGenerator.new()
var _espalhado: bool = false


func setup(world: World) -> void:
	_world = world
	for filho in world.get_children():
		if filho is WorldEnvironment:
			_sky = (filho as WorldEnvironment).environment.sky
	_ceu = _sky.sky_material as ProceduralSkyMaterial
	_ruido.shader = load("res://scripts/comparacao/ceu_ruido.gdshader")
	_texturas = [
		_ceu.sky_cover,
		load("res://assets/visual/comparacao/ceu_lisa.png"),
		load("res://assets/visual/comparacao/ceu_esparsa.png"),
	]
	_rng.seed = 7
	# Para conferir cada variante no quadro congelado da prova.
	if OS.has_environment("RUSHFOOD_CEU_VARIANTE"):
		_indice = int(OS.get_environment("RUSHFOOD_CEU_VARIANTE"))
	_cria_objetos()

	var camada := CanvasLayer.new()
	camada.layer = 11
	add_child(camada)
	_rotulo.position = Vector2(8, 40)
	_rotulo.add_theme_font_size_override("font_size", 12)
	_rotulo.add_theme_color_override("font_outline_color", Color.BLACK)
	_rotulo.add_theme_constant_override("outline_size", 4)
	camada.add_child(_rotulo)
	_aplica()


func _unhandled_input(event: InputEvent) -> void:
	var tecla := event as InputEventKey
	if tecla == null or not tecla.pressed or tecla.echo:
		return
	if tecla.physical_keycode in [KEY_5, KEY_F5]:
		_indice = (_indice + 1) % NOMES.size()
		_aplica()
	elif tecla.physical_keycode in [KEY_6, KEY_F6]:
		_indice = (_indice + NOMES.size() - 1) % NOMES.size()
		_aplica()


func _aplica() -> void:
	_sky.sky_material = _ruido if _indice == 3 else _ceu
	_ceu.sky_cover = _texturas[_indice] if _indice < 3 else null
	for o in _objetos:
		o.visible = _indice == 4
	_rotulo.text = "ceu [5/6]  %s" % NOMES[_indice]


func _process(_delta: float) -> void:
	if _indice != 4 or _world.camera == null:
		return
	var cam := _world.camera.global_position
	var frente := -_world.camera.global_basis.z
	if not _espalhado:
		# Espalhadas em volta, a distancias variadas: se todas nascessem a
		# 720 m, renasceriam juntas.
		_espalhado = true
		for o in _objetos:
			_posiciona(o, cam, frente, _rng.randf_range(420.0, 780.0), true)
	for o in _objetos:
		var d := Vector2(o.global_position.x - cam.x, o.global_position.z - cam.z).length()
		# Ficou perto demais ou saiu do `far` da camera (800 m): renasce longe,
		# de preferencia na frente, que e para onde a moto vai.
		if d < 380.0 or d > 790.0:
			_posiciona(o, cam, frente, 720.0)


func _cria_objetos() -> void:
	var folha: Texture2D = load("res://assets/visual/comparacao/nuvem_sprites.png")
	for i in OBJETOS:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_texture = folha
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		# Sem isto a neblina de 0,0045 apaga a nuvem inteira a 700 m.
		mat.disable_fog = true
		mat.uv1_scale = Vector3(0.5, 0.5, 1.0)
		mat.uv1_offset = Vector3(0.5 * float(i % 2), 0.5 * float((i / 2) % 2), 0.0)
		var quad := QuadMesh.new()
		var largura := _rng.randf_range(130.0, 240.0)
		quad.size = Vector2(largura, largura * 0.5)
		var o := MeshInstance3D.new()
		o.mesh = quad
		o.material_override = mat
		o.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(o)
		_objetos.append(o)


func _posiciona(
	o: MeshInstance3D, cam: Vector3, frente: Vector3, dist: float, qualquer: bool = false
) -> void:
	var base := atan2(frente.x, frente.z)
	var giro := _rng.randf_range(-PI, PI) if qualquer else _rng.randf_range(-1.2, 1.2)
	var ang := base + giro
	var elev := deg_to_rad(_rng.randf_range(5.0, 15.0))
	o.global_position = Vector3(
		cam.x + sin(ang) * dist, cam.y + tan(elev) * dist, cam.z + cos(ang) * dist
	)
