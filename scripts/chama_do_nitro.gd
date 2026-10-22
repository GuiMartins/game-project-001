class_name ChamaDoNitro
extends Node3D
## A chama azul no escape de uma moto, acesa so enquanto ela esta no boost: e o
## aviso de que o nitro esta queimando, de jogador ou de rival, em qualquer
## moto. Antes so a velocidade e o borrao diziam isso, e o Arthur nao viu.
##
## Mora no corpo da moto, como a `Derrapagem`, e quem diz se o boost esta ligado
## e quem anda a moto (`atualizar`). O que muda de uma moto para outra - onde
## fica o escape e quanto a chama cresce - sai da `FichaDaMoto`, e o corpo so
## chama `usar_modelo`. Nada aqui entra em medida do banco de provas.
##
## As regras de particula em pixel do `DIRECAO_VISUAL.md`: sem interpolar,
## cadencia travada na do ator, poucas e grandes, e a cor sai da textura e do
## gradiente, nunca de luz da cena (a chama e o que ilumina, e nao o que
## recebe luz).

## Quadros por segundo: a cadencia do ator (`WorldTuning.ator_cadencia`).
const CADENCIA: int = 12
## Quanto a chama leva para acender e para apagar, em segundos. Curto: o boost
## e um aperto de botao, e chama que demora a acender nao mostra que ligou.
const ACENDE_EM: float = 0.08
const APAGA_EM: float = 0.2
## Vida de uma particula. Com a velocidade abaixo, a chama tem uns 55 cm de
## comprimento na escala 1: o tamanho de um escapamento esportivo soltando
## nitro, e nao de um lancha-chamas.
const VIDA: float = 0.22
const VELOCIDADE := Vector2(2.2, 3.2)
## A ponta da chama e quase branca de tao quente; a borda, azul. O gradiente
## vai do nucleo a borda ao longo da vida da particula.
const COR_NUCLEO := Color(0.85, 0.95, 1.0, 1.0)
const COR_MEIO := Color(0.25, 0.55, 1.0, 0.9)
const COR_BORDA := Color(0.05, 0.2, 1.0, 0.0)
## A luz azul sob a moto, de noite: a mesma regra do fogo da V24 (sem sombra,
## some com a distancia). Alcance de uma faixa para cada lado.
const COR_DA_LUZ := Color(0.3, 0.55, 1.0)
const LUZ_ENERGIA: float = 2.5
const LUZ_ALCANCE: float = 4.5
## Do escuro da `Relogio` em que ela comeca a aparecer, o mesmo do farol.
const LUZ_LIMIAR: float = FarolDaMoto.LIMIAR

static var _textura: ImageTexture

var _chama: GPUParticles3D
var _luz: OmniLight3D
## De 0 a 1: a chama acendendo e apagando, que a luz segue.
var _acesa: float = 0.0
var _escala: float = 1.0


func _ready() -> void:
	_chama = GPUParticles3D.new()
	_chama.name = "Chama"
	_chama.amount = 10
	_chama.lifetime = VIDA
	_chama.fixed_fps = CADENCIA
	_chama.interpolate = false
	# Colada no escape: a chama acompanha a moto, nao fica no caminho que ela
	# fez. Fumaca deixa rastro; fogo de escape nao.
	_chama.local_coords = true
	_chama.emitting = false
	_chama.visibility_aabb = AABB(Vector3(-2.0, -2.0, -2.0), Vector3(4.0, 4.0, 4.0))
	_chama.process_material = _processo()
	_chama.draw_pass_1 = _quad()
	add_child(_chama)

	_luz = OmniLight3D.new()
	_luz.name = "LuzDoNitro"
	_luz.light_color = COR_DA_LUZ
	_luz.omni_range = LUZ_ALCANCE
	_luz.omni_attenuation = 1.4
	_luz.shadow_enabled = false
	_luz.light_bake_mode = Light3D.BAKE_DISABLED
	_luz.distance_fade_enabled = true
	_luz.distance_fade_begin = 50.0
	_luz.distance_fade_length = 20.0
	_luz.visible = false
	add_child(_luz)


## Poe o escape onde a `modelo` o tem (`FichaDaMoto.escape`) e a chama no
## tamanho dela. `chao_y` e o y do chao no corpo da moto.
func usar_modelo(modelo: int, chao_y: float) -> void:
	var ficha := FichaDaMoto.de(modelo)
	if ficha == null:
		return
	position = Vector3(ficha.escape.x, chao_y + ficha.escape.y, ficha.escape.z)
	_escala = ficha.chama
	if _chama != null:
		_chama.scale = Vector3.ONE * _escala
		_luz.position = Vector3(0.0, -ficha.escape.y + 0.3, 0.0)


## Um passo. `boost` e o nitro ligado; caido ou parado e quem chama que manda
## falso.
func atualizar(delta: float, boost: bool) -> void:
	var passo := delta / (ACENDE_EM if boost else APAGA_EM)
	_acesa = clampf(_acesa + (passo if boost else -passo), 0.0, 1.0)
	_chama.emitting = boost
	var noite := clampf((Relogio.escuro - LUZ_LIMIAR) / Relogio.RAMPA, 0.0, 1.0)
	var energia := LUZ_ENERGIA * _acesa * noite
	_luz.visible = energia > 0.0
	_luz.light_energy = energia


func emitindo() -> bool:
	return _chama.emitting


## A luz azul esta ligada agora?
func luz_acesa() -> bool:
	return _luz.visible


func _processo() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.03
	# +Z e para tras da moto.
	m.direction = Vector3(0.0, 0.0, 1.0)
	m.spread = 6.0
	m.initial_velocity_min = VELOCIDADE.x
	m.initial_velocity_max = VELOCIDADE.y
	m.gravity = Vector3.ZERO
	m.scale_min = 0.9
	m.scale_max = 1.2
	# Encolhe ate a ponta: a chama termina em bico.
	var curva := Curve.new()
	curva.add_point(Vector2(0.0, 0.7))
	curva.add_point(Vector2(0.25, 1.0))
	curva.add_point(Vector2(1.0, 0.15))
	var tex := CurveTexture.new()
	tex.curve = curva
	m.scale_curve = tex
	var gradiente := Gradient.new()
	gradiente.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	gradiente.colors = PackedColorArray([COR_NUCLEO, COR_MEIO, COR_BORDA])
	var rampa := GradientTexture1D.new()
	rampa.gradient = gradiente
	m.color_ramp = rampa
	return m


func _quad() -> QuadMesh:
	var mat := StandardMaterial3D.new()
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	# Soma luz em vez de cobrir: chama azul sobre asfalto escuro brilha, e
	# sobre o asfalto claro do meio-dia nao vira mancha.
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = gota()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.28, 0.28)
	quad.material = mat
	return quad


## Uma gota de fogo em 16x16, mais cheia no meio. O pixel e o ponto: nada de
## degrade macio, a borda e um degrau.
static func gota() -> ImageTexture:
	if _textura != null:
		return _textura
	var lado := 16
	var img := Image.create(lado, lado, false, Image.FORMAT_RGBA8)
	for y in lado:
		for x in lado:
			var p := (Vector2(x, y) + Vector2(0.5, 0.5)) / float(lado) * 2.0 - Vector2.ONE
			var d := p.length()
			var a := 1.0 if d < 0.55 else (0.55 if d < 0.9 else 0.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	_textura = ImageTexture.create_from_image(img)
	return _textura
