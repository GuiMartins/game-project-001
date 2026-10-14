class_name Derrapagem
extends Node3D
## Fumaca de pneu e marca no asfalto, quando a roda traseira escorrega de lado.
##
## Mora no corpo da moto, no chao embaixo do eixo traseiro, e nao no `Visual`:
## a fumaca sai de onde o pneu toca o asfalto, e o pneu nao sobe com a
## inclinacao. Quem diz quanto a moto escorrega e o corpo, a cada passo
## (`atualizar`): no jogador e a derrapada da fisica; o rival e parametrico na
## curva e nao escorrega, entao manda zero, e o no fica pronto para quando
## escorregar.
##
## As regras de particula em pixel do `DIRECAO_VISUAL.md`, *Particulas*: fumaca
## com alfa macio (a suavidade e o efeito), flipbook e nao escala, poucas e
## grandes, e cadencia travada em 12, a mesma do ator (V22). Nada aqui entra
## em medida do banco de provas.

## Derrapada lateral, em m/s, em que a fumaca comeca. Medido no piloto
## automatico da `corrida`: em curva normal a roda escorrega de 1 a 3,5 m/s, e
## so a curva forcada no limite ou a pancada de lado passam de 4. Abaixo disso
## toda curva fumacaria, e fumaca em toda curva e ruido, nao aviso.
const LIMIAR: float = 4.0
## Derrapada em que a fumaca e a marca chegam no cheio.
const CHEIO: float = 10.0
## Metros entre um pedaco de marca e o proximo. Mais curto que isso a 50 m/s e
## um `Decal` novo por quadro; mais longo, a marca vira tracejado na curva.
const PEDACO: float = 0.8
## Quantos pedacos de marca existem ao mesmo tempo. O mais velho e reciclado:
## 40 pedacos sao 32 m de borracha, mais do que a camera ve atras da moto.
const MARCAS: int = 40
## Segundos ate a marca sumir. Marca que fica para sempre enche a pista de
## risco onde ninguem esta derrapando, e a pista e uma volta so.
const VIDA_DA_MARCA: float = 6.0
## Largura da marca: o pneu traseiro de moto de rua, com folga para o pixel.
const LARGURA_DA_MARCA: float = 0.16
## Fumaca em quadros por segundo: a cadencia do ator (`WorldTuning.ator_cadencia`).
const CADENCIA: int = 12
## Onde fica o pneu traseiro no corpo, em metros atras do centro (+Z e para
## tras). Um numero so para as tres motos: o entre-eixos muda poucos
## centimetros de uma para outra, e a nuvem tem um metro.
const EIXO_TRASEIRO: float = 0.65
## Quadros do flipbook, do sopro denso ao fiapo.
const QUADROS: int = 4
const LADO: int = 32

static var _textura_da_fumaca: ImageTexture
static var _textura_da_marca: ImageTexture

var _fumaca: GPUParticles3D
## Os pedacos de marca moram fora da moto, no mundo: ficam onde ela passou.
var _marcas: Node3D
var _proxima: int = 0
var _idades: Array[float] = []
## Onde comecou o pedaco de marca que esta sendo desenhado; sem marca, NAN.
var _inicio := Vector3(NAN, NAN, NAN)


func _ready() -> void:
	_fumaca = GPUParticles3D.new()
	_fumaca.amount = 24
	_fumaca.lifetime = 0.9
	_fumaca.fixed_fps = CADENCIA
	# Sem interpolar: com ela o `fixed_fps` vira so economia, e a fumaca anda
	# lisa entre os quadros. O degrau e o ponto.
	_fumaca.interpolate = false
	_fumaca.local_coords = false
	_fumaca.emitting = false
	_fumaca.visibility_aabb = AABB(Vector3(-4.0, -1.0, -4.0), Vector3(8.0, 5.0, 8.0))
	_fumaca.process_material = _processo()
	_fumaca.draw_pass_1 = _quad()
	add_child(_fumaca)

	_marcas = Node3D.new()
	_marcas.top_level = true
	add_child(_marcas)
	for i in MARCAS:
		var marca := Decal.new()
		marca.texture_albedo = _marca()
		marca.size = Vector3(LARGURA_DA_MARCA, 0.4, PEDACO)
		marca.distance_fade_enabled = true
		marca.distance_fade_begin = 40.0
		marca.distance_fade_length = 20.0
		marca.visible = false
		_marcas.add_child(marca)
		_idades.append(VIDA_DA_MARCA)


## Um passo. `derrapada` em m/s, lateral; zero no ar, caido ou parado.
func atualizar(delta: float, derrapada: float) -> void:
	var forca := clampf((derrapada - LIMIAR) / (CHEIO - LIMIAR), 0.0, 1.0)
	_fumaca.emitting = forca > 0.0
	_fumaca.amount_ratio = lerpf(0.35, 1.0, forca)
	_envelhece(delta)
	if forca <= 0.0:
		_inicio = Vector3(NAN, NAN, NAN)
		return
	var aqui := global_position
	if is_nan(_inicio.x) or _inicio.distance_to(aqui) > PEDACO * 4.0:
		# Teleporte ou primeira marca: comeca daqui, sem riscar o caminho.
		_inicio = aqui
		return
	if _inicio.distance_to(aqui) >= PEDACO:
		_risca(_inicio, aqui, forca)
		_inicio = aqui


## Quantos pedacos de marca estao no asfalto agora.
func marcas_visiveis() -> int:
	var n := 0
	for marca in _marcas.get_children():
		if (marca as Decal).visible:
			n += 1
	return n


func emitindo() -> bool:
	return _fumaca.emitting


func _risca(de: Vector3, ate: Vector3, forca: float) -> void:
	var marca := _marcas.get_child(_proxima) as Decal
	_idades[_proxima] = 0.0
	_proxima = (_proxima + 1) % MARCAS
	var meio := (de + ate) * 0.5
	var ao_longo := ate - de
	ao_longo.y = 0.0
	marca.global_transform = Transform3D(Basis.looking_at(ao_longo.normalized(), Vector3.UP), meio)
	marca.size.z = ao_longo.length() + 0.05
	marca.modulate.a = lerpf(0.5, 1.0, forca)
	marca.set_meta("alfa", marca.modulate.a)
	marca.visible = true


## A marca desbota no ultimo terco da vida, em vez de sumir de uma vez.
func _envelhece(delta: float) -> void:
	for i in MARCAS:
		if _idades[i] >= VIDA_DA_MARCA:
			continue
		_idades[i] += delta
		var marca := _marcas.get_child(i) as Decal
		var resto := clampf((VIDA_DA_MARCA - _idades[i]) / (VIDA_DA_MARCA / 3.0), 0.0, 1.0)
		marca.modulate.a = float(marca.get_meta("alfa", 1.0)) * resto
		marca.visible = _idades[i] < VIDA_DA_MARCA


func _processo() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(0.1, 0.05, 0.15)
	# O quad nasce centrado no ponto de emissao: no chao, metade dele ficava
	# enterrada no asfalto, e a nuvem lia como meia-lua.
	m.emission_shape_offset = Vector3(0.0, 0.35, 0.0)
	m.direction = Vector3.UP
	m.spread = 50.0
	m.initial_velocity_min = 0.6
	m.initial_velocity_max = 1.6
	# Sobe devagar e para: fumaca de pneu fica rente ao chao, e nao vira chamine.
	m.gravity = Vector3(0.0, 0.5, 0.0)
	m.damping_min = 4.0
	m.damping_max = 6.0
	# Quase todo o embalo da moto, que o ar vai comendo (`damping`): parada no
	# ar, a nuvem ficava 3 m para tras a cada quadro da cadencia a 120 km/h, e
	# a camera, que vem logo atras, nunca a via. Assim ela nasce no pneu e vai
	# ficando para tras aos poucos, que e o rastro.
	m.inherit_velocity_ratio = 0.9
	m.scale_min = 0.8
	m.scale_max = 1.2
	m.angle_min = -180.0
	m.angle_max = 180.0
	# Um flipbook por vida, do primeiro quadro ao ultimo.
	m.anim_speed_min = 1.0
	m.anim_speed_max = 1.0
	return m


func _quad() -> QuadMesh:
	var mat := StandardMaterial3D.new()
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.particles_anim_h_frames = QUADROS
	mat.particles_anim_v_frames = 1
	mat.particles_anim_loop = false
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Sem luz: a fumaca e clara contra o asfalto em qualquer lado da pista, e
	# o sol nao a escurece de costas.
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = nuvem()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.1, 1.1)
	quad.material = mat
	return quad


## O flipbook gerado aqui, e nao pintado: quatro sopros lado a lado, cada um
## maior e mais ralo que o anterior, com a borda roida no fim. Sem sorteio: os
## tufos estao em posicao fixa, e o mesmo codigo da o mesmo desenho. A poeira
## da queda (`Estrago`) e a mesma nuvem, tingida de terra.
static func nuvem() -> ImageTexture:
	if _textura_da_fumaca != null:
		return _textura_da_fumaca
	var img := Image.create(LADO * QUADROS, LADO, false, Image.FORMAT_RGBA8)
	var tufos: Array[Vector3] = [
		Vector3(0.0, 0.0, 1.0),
		Vector3(-0.35, 0.15, 0.7),
		Vector3(0.3, 0.2, 0.75),
		Vector3(0.1, -0.3, 0.65),
		Vector3(-0.2, -0.25, 0.6),
	]
	for q in QUADROS:
		var t := float(q) / float(QUADROS - 1)
		var raio := lerpf(0.4, 0.62, t)
		var opaco := lerpf(0.85, 0.35, t)
		for y in LADO:
			for x in LADO:
				var p := (Vector2(x, y) + Vector2(0.5, 0.5)) / float(LADO) * 2.0 - Vector2.ONE
				var densidade := 0.0
				for tufo in tufos:
					var d := p.distance_to(Vector2(tufo.x, tufo.y) * lerpf(1.0, 1.3, t))
					densidade = maxf(densidade, 1.0 - d / (raio * tufo.z * 1.6))
				# A borda roida: um xadrez fino que come a borda mais e mais.
				var roido := 0.15 * t * float((x + y * 3) % 4 == 0)
				var a := clampf(densidade * 1.8 - roido, 0.0, 1.0) * opaco
				var cinza := lerpf(0.92, 0.78, t) - 0.08 * (p.y * 0.5 + 0.5)
				img.set_pixel(q * LADO + x, y, Color(cinza, cinza, cinza * 1.02, a))
	_textura_da_fumaca = ImageTexture.create_from_image(img)
	return _textura_da_fumaca


## A marca: borracha escura, mais forte no meio do pneu e com risco ao longo,
## a mesma regra do asfalto (`arte/chao.py`): detalhe corre ao longo da pista.
static func _marca() -> ImageTexture:
	if _textura_da_marca != null:
		return _textura_da_marca
	var img := Image.create(8, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 8:
			var meio := 1.0 - absf(float(x) - 3.5) / 4.0
			var risco := 0.85 if x % 3 == 1 else 1.0
			img.set_pixel(x, y, Color(0.04, 0.04, 0.045, clampf(meio * 1.4, 0.0, 0.8) * risco))
	_textura_da_marca = ImageTexture.create_from_image(img)
	return _textura_da_marca
