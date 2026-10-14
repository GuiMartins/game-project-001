class_name Estrago
extends Node3D
## O que a moto solta quando apanha (V24): faisca da raspada e da carenagem
## arrastando no tombo, poeira da queda, fogo na moto caida que chegou rapido
## e o estalo do soco em quem levou.
##
## Mora no corpo de toda moto, jogador e rival, no chao embaixo do centro, como
## a `Derrapagem` mora embaixo do eixo traseiro. Quem diz o que aconteceu e o
## corpo: `faisca` na raspada, `cair` na queda, `impacto` no soco que acertou,
## e `atualizar` a cada passo com o estado (caido ou nao, e quanto desliza).
##
## As regras de particula em pixel do `DIRECAO_VISUAL.md`, *Particulas*:
## cadencia travada em 12, a do ator; borda dura (recorte) onde a forma importa
## - faisca, chama, estalo - e alfa macio so na poeira, onde a suavidade e o
## efeito; poucas e grandes. Nada aqui entra em medida do banco de provas.
##
## **A faisca quica no chao sem o chao ter colisor.** O
## `GPUParticlesCollisionHeightField3D` enxergaria a pista (ele rasteriza a
## geometria desenhada, nao os corpos), mas com `follow_camera_enabled` ele
## re-renderiza o campo de altura todo quadro, e e a unica linha da secao de
## particulas com risco de orcamento. Aqui vai a alternativa desenhada la: uma
## caixa de colisao de particula, rasa, com o topo no chao embaixo da moto.
## Faisca vive menos de meio segundo e nao sai de 6 m da moto, e o chao nesse
## raio e plano o bastante. A caixa so existe para particula: a fisica nao a
## enxerga, e o invariante do chao continua inteiro.

## Fracao de `BikeTuning.max_speed` a partir da qual a queda pega fogo: 0,5 sao
## 26 m/s, uns 94 km/h. Fogo em toda queda vira cenario de toda queda; o tombo
## de quem encostou devagar so levanta poeira.
const FOGO: float = 0.5
## Deslize, em m/s, em que a moto deitada para de soltar faisca: abaixo disso
## ela esta parando, e arrastar devagar nao acende metal.
const DESLIZE_MINIMO: float = 3.0
## Deslize em que a faisca do arrasto chega no cheio.
const DESLIZE_CHEIO: float = 15.0
## Quanto dura a faisca de uma raspada, de leve a cheia: um tranco, nao um
## esmeril.
const RASPADA := Vector2(0.12, 0.35)
## A cadencia do ator (`WorldTuning.ator_cadencia`), a mesma da fumaca de pneu.
const CADENCIA: int = 12
## A luz do fogo: laranja de chama, alcance de uma faixa e meia para cada lado.
## E ela que vende o fogo, nao a chama (`DIRECAO_VISUAL.md`): de noite pinta o
## asfalto em volta da moto, e de dia ainda acende a lataria do carro do lado.
const COR_DO_FOGO := Color(1.0, 0.55, 0.18)
const FOGO_ENERGIA: float = 3.0
const FOGO_ALCANCE: float = 6.0
## Segundos para o fogo pegar e para a luz apagar depois que a moto levanta.
const FOGO_PEGA: float = 0.4
## A poeira da queda: cor de terra e asfalto moido, mais escura que a fumaca de
## pneu, que e branca. As duas saem do mesmo flipbook (`Derrapagem.nuvem`).
const COR_DA_POEIRA := Color(0.66, 0.60, 0.52)
const LADO: int = 16
const QUADROS: int = 4

static var _textura_da_chama: ImageTexture
static var _textura_do_estalo: ImageTexture

var _faisca: GPUParticles3D
var _poeira: GPUParticles3D
var _chama: GPUParticles3D
var _estalo: GPUParticles3D
var _luz: OmniLight3D
## Quanto falta da faisca da ultima raspada, em segundos.
var _raspando: float = 0.0
## Esta queda pegou fogo. Desliga quando a moto levanta.
var _pegou_fogo: bool = false
## De 0 a 1: o fogo pegando e apagando, que a luz segue.
var _fogo: float = 0.0
var _relogio_da_luz: float = 0.0
var _passo_da_luz: int = -1
var _tremor: float = 1.0


func _ready() -> void:
	_faisca = _particulas(28, 0.4, _processo_da_faisca(), _risco())
	_faisca.position = Vector3.UP * 0.3
	_faisca.collision_base_size = 0.02
	add_child(_faisca)

	_poeira = _particulas(10, 1.0, _processo_da_poeira(), _quad(Derrapagem.nuvem(), 1.1, true))
	_poeira.one_shot = true
	_poeira.explosiveness = 1.0
	add_child(_poeira)

	_chama = _particulas(
		10, 0.55, _processo_da_chama(), _quad(_chama_textura(), 0.7, false, QUADROS)
	)
	_chama.position = Vector3.UP * 0.25
	# A chama vai com a moto, e nao fica onde nasceu: a moto caida ainda
	# desliza, e solta no mundo o fogo virava uma fileira de labaredas no
	# asfalto, uma atras da outra, que lia como pipoca.
	_chama.local_coords = true
	add_child(_chama)

	# O estalo do soco nasce em quem levou, e nao em quem bateu: fica fora da
	# moto, posto no alvo a cada soco.
	_estalo = _particulas(5, 0.25, _processo_do_estalo(), _quad(_estalo_textura(), 0.35, false))
	_estalo.one_shot = true
	_estalo.explosiveness = 1.0
	_estalo.top_level = true
	add_child(_estalo)

	_luz = OmniLight3D.new()
	_luz.name = "Fogo"
	_luz.light_color = COR_DO_FOGO
	_luz.omni_range = FOGO_ALCANCE
	_luz.omni_attenuation = 1.4
	_luz.shadow_enabled = false
	_luz.light_bake_mode = Light3D.BAKE_DISABLED
	_luz.distance_fade_enabled = true
	_luz.distance_fade_begin = 50.0
	_luz.distance_fade_length = 20.0
	_luz.position = Vector3.UP * 0.8
	_luz.visible = false
	add_child(_luz)

	var chao := GPUParticlesCollisionBox3D.new()
	chao.size = Vector3(12.0, 1.0, 12.0)
	chao.position = Vector3.DOWN * 0.5
	add_child(chao)


## Um passo. `caido` liga e desliga o fogo; `deslize` e quanto a moto deitada
## ainda arrasta no asfalto, em m/s (zero em pe).
func atualizar(delta: float, caido: bool, deslize: float) -> void:
	_raspando = maxf(_raspando - delta, 0.0)
	var arrasto := clampf((deslize - DESLIZE_MINIMO) / (DESLIZE_CHEIO - DESLIZE_MINIMO), 0.0, 1.0)
	var arrastando := caido and arrasto > 0.0
	_faisca.emitting = _raspando > 0.0 or arrastando
	_faisca.amount_ratio = lerpf(0.6, 1.0, arrasto)

	if not caido:
		_pegou_fogo = false
	_chama.emitting = _pegou_fogo
	var alvo := 1.0 if _pegou_fogo else 0.0
	_fogo = move_toward(_fogo, alvo, delta / FOGO_PEGA)
	_tremula(delta)


## Raspou em alguma coisa: `intensidade` de 0 a 1, a do sinal `scraped`.
func faisca(intensidade: float) -> void:
	_raspando = maxf(_raspando, lerpf(RASPADA.x, RASPADA.y, clampf(intensidade, 0.0, 1.0)))


## Caiu. `forca` e a velocidade na hora, como fracao do teto: a poeira cresce
## com ela, e acima de `FOGO` a moto pega fogo ate levantar.
func cair(forca: float) -> void:
	_poeira.amount_ratio = lerpf(0.5, 1.0, clampf(forca, 0.0, 1.0))
	_poeira.restart()
	_pegou_fogo = forca >= FOGO


## O soco acertou quem esta em `onde`, no mundo.
func impacto(onde: Vector3) -> void:
	_estalo.global_position = onde
	_estalo.restart()


func emitindo_faisca() -> bool:
	return _faisca.emitting


func pegou_fogo() -> bool:
	return _chama.emitting


func luz_acesa() -> bool:
	return _luz.visible


## A luz pulsa na cadencia da chama, em degrau, e nao lisa: a chama troca de
## quadro 12 vezes por segundo, e a luz tremendo a 60 descolaria dela. O
## sorteio de cada quadro e um hash do numero do quadro, para o mesmo fogo
## tremer igual em toda rodada.
func _tremula(delta: float) -> void:
	_luz.visible = _fogo > 0.0
	if not _luz.visible:
		return
	_relogio_da_luz += delta
	var passo := int(_relogio_da_luz * CADENCIA)
	if passo != _passo_da_luz:
		_passo_da_luz = passo
		_tremor = fposmod(sin(float(passo) * 12.9898) * 43758.5453, 1.0)
	_luz.light_energy = FOGO_ENERGIA * _fogo * lerpf(0.6, 1.0, _tremor)


func _particulas(
	quantas: int, vida: float, processo: ParticleProcessMaterial, malha: Mesh
) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = quantas
	p.lifetime = vida
	p.fixed_fps = CADENCIA
	# Sem interpolar, como a fumaca de pneu: o degrau e o ponto.
	p.interpolate = false
	p.local_coords = false
	p.emitting = false
	p.visibility_aabb = AABB(Vector3(-6.0, -1.0, -6.0), Vector3(12.0, 6.0, 12.0))
	p.process_material = processo
	p.draw_pass_1 = malha
	return p


## Faisca: sai para tras e para cima do ponto que arrasta, com metade do embalo
## da moto, cai e quica no chao. Amarela nascendo e vermelha morrendo, acima
## do limiar do glow (`world.gd`, 2,2) enquanto esta quente.
func _processo_da_faisca() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(0.25, 0.05, 0.3)
	# +Z e para tras, no corpo das duas motos.
	m.direction = Vector3(0.0, 0.7, 1.0)
	m.spread = 35.0
	m.initial_velocity_min = 3.0
	m.initial_velocity_max = 7.0
	m.inherit_velocity_ratio = 0.5
	m.gravity = Vector3(0.0, -14.0, 0.0)
	m.collision_mode = ParticleProcessMaterial.COLLISION_RIGID
	m.collision_bounce = 0.35
	m.collision_friction = 0.3
	# O risco aponta para onde a faisca vai: e o que separa faisca de
	# pipoca. Ponto solto, de qualquer tamanho, le como confete.
	m.particle_flag_align_y = true
	m.scale_min = 0.6
	m.scale_max = 1.0
	m.color_ramp = _rampa(
		[Color(5.0, 4.2, 1.6), Color(4.0, 1.8, 0.4), Color(1.2, 0.25, 0.05)], [0.0, 0.4, 1.0]
	)
	return m


## Poeira: um anel que abre rente ao chao e sobe pouco, com o embalo do tombo.
## Dez nuvens de pouco mais de um metro: com 14 de 1,5 m a poeira do rival
## caido escondia o carro em que ele bateu, e o carro e o que conta a queda.
func _processo_da_poeira() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.4
	# Como na fumaca de pneu: o quad nasce centrado, e no chao meia nuvem
	# ficaria enterrada.
	m.emission_shape_offset = Vector3(0.0, 0.4, 0.0)
	m.direction = Vector3.UP
	m.spread = 85.0
	m.initial_velocity_min = 1.5
	m.initial_velocity_max = 3.5
	m.inherit_velocity_ratio = 0.5
	m.gravity = Vector3(0.0, 0.3, 0.0)
	m.damping_min = 3.0
	m.damping_max = 5.0
	m.scale_min = 0.8
	m.scale_max = 1.4
	m.angle_min = -180.0
	m.angle_max = 180.0
	m.anim_speed_min = 1.0
	m.anim_speed_max = 1.0
	m.color = COR_DA_POEIRA
	return m


## Chama: sobe da moto, sem embalo nenhum (a moto caida ja parou ou esta
## parando), e cada uma roda o flipbook inteiro, da labareda ao fiapo.
func _processo_da_chama() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(0.3, 0.1, 0.6)
	m.direction = Vector3.UP
	m.spread = 12.0
	m.initial_velocity_min = 0.8
	m.initial_velocity_max = 1.6
	m.gravity = Vector3(0.0, 1.5, 0.0)
	m.scale_min = 0.7
	m.scale_max = 1.3
	m.anim_speed_min = 1.0
	m.anim_speed_max = 1.0
	# A textura ja tem a cor; isto so a empurra acima do limiar do glow, no
	# miolo, que e onde ela e quase branca.
	m.color = Color(2.6, 2.6, 2.6)
	return m


## Estalo: cinco lascas brancas abrindo em todas as direcoes, sem gravidade, e
## somem antes de cair. Mais que cinco vira po (`DIRECAO_VISUAL.md`).
func _processo_do_estalo() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3.UP
	m.spread = 180.0
	m.initial_velocity_min = 3.0
	m.initial_velocity_max = 5.0
	m.gravity = Vector3.ZERO
	m.damping_min = 8.0
	m.damping_max = 10.0
	m.scale_min = 0.8
	m.scale_max = 1.2
	m.angle_min = -45.0
	m.angle_max = 45.0
	m.color_ramp = _rampa([Color(3.0, 3.0, 2.6), Color(1.0, 0.85, 0.4)], [0.0, 1.0])
	return m


static func _rampa(cores: Array[Color], pontos: Array[float]) -> GradientTexture1D:
	var g := Gradient.new()
	g.colors = PackedColorArray(cores)
	g.offsets = PackedFloat32Array(pontos)
	var t := GradientTexture1D.new()
	t.gradient = g
	t.use_hdr = true
	return t


## O quad de cada efeito, sempre de frente para a camera, sem luz (a faisca e
## a chama sao a luz) e com o filtro mais proximo. `macio` e a poeira: alfa de
## verdade e o flipbook da `Derrapagem`. O resto e recorte, borda dura;
## `quadros` e o flipbook da chama.
func _quad(textura: Texture2D, tamanho: float, macio: bool, quadros: int = 1) -> QuadMesh:
	var mat := StandardMaterial3D.new()
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = textura
	if macio:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.particles_anim_h_frames = Derrapagem.QUADROS
		mat.particles_anim_v_frames = 1
		mat.particles_anim_loop = false
	else:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold = 0.5
		mat.particles_anim_h_frames = quadros
		mat.particles_anim_v_frames = 1
		mat.particles_anim_loop = false
	var quad := QuadMesh.new()
	quad.size = Vector2(tamanho, tamanho)
	quad.material = mat
	return quad


## A faisca: um risco de 2,5 cm por 25 cm ao longo de Y, que o
## `particle_flag_align_y` deita na direcao da velocidade. Duas fitas em cruz,
## e nao um quad virado para a camera: o billboard gira o quad para a tela e
## perde a direcao, e uma fita so some quando vista de lado. Sem textura: a cor
## vem toda da rampa.
func _risco() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var meia := 0.0125
	var comprida := 0.125
	for lado: Vector3 in [Vector3.RIGHT, Vector3.BACK]:
		var a := -lado * meia + Vector3.DOWN * comprida
		var b := lado * meia + Vector3.DOWN * comprida
		var c := lado * meia + Vector3.UP * comprida
		var d := -lado * meia + Vector3.UP * comprida
		for v: Vector3 in [a, b, c, a, c, d]:
			st.add_vertex(v)
	var malha := st.commit()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	# As duas faces: a fita gira com a faisca, e qualquer lado pode estar
	# virado para a camera.
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	malha.surface_set_material(0, mat)
	return malha


## O estalo: uma estrela de quatro pontas, como o "pow" de quadrinho em pixel.
static func _estalo_textura() -> ImageTexture:
	if _textura_do_estalo != null:
		return _textura_do_estalo
	var img := Image.create(LADO, LADO, false, Image.FORMAT_RGBA8)
	for y in LADO:
		for x in LADO:
			var p := (Vector2(x, y) + Vector2(0.5, 0.5)) / float(LADO) * 2.0 - Vector2.ONE
			# Quatro pontas: a estrela e onde |x|*|y| e pequeno perto do centro.
			var dentro := absf(p.x) * absf(p.y) * 6.0 + p.length() * 0.55 < 0.5
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, 1.0 if dentro else 0.0))
	_textura_do_estalo = ImageTexture.create_from_image(img)
	return _textura_do_estalo


## A chama em quatro quadros, gerada aqui como a fumaca de pneu: uma gota que
## afina para cima, branca no miolo, laranja e vermelha na borda, cada quadro
## mais curta e mais torta, ate o fiapo. Sem sorteio: o mesmo codigo da o
## mesmo desenho.
static func _chama_textura() -> ImageTexture:
	if _textura_da_chama != null:
		return _textura_da_chama
	var img := Image.create(LADO * QUADROS, LADO, false, Image.FORMAT_RGBA8)
	for q in QUADROS:
		var t := float(q) / float(QUADROS - 1)
		var altura := lerpf(1.0, 0.55, t)
		var largura := lerpf(0.75, 0.45, t)
		var torto := 0.25 * sin(float(q) * 2.1)
		for y in LADO:
			for x in LADO:
				# `v` de 0 (base) a 1 (topo da chama); `u` de -1 a 1.
				var v := (float(LADO - 1 - y) + 0.5) / float(LADO) / altura
				var u := (float(x) + 0.5) / float(LADO) * 2.0 - 1.0
				u -= torto * v * v
				var meia := largura * sqrt(maxf(1.0 - v, 0.0)) * minf(v * 4.0 + 0.3, 1.0)
				var densidade := 1.0 - absf(u) / maxf(meia, 0.001) if v <= 1.0 else 0.0
				var cor := Color(0.0, 0.0, 0.0, 0.0)
				if densidade > 0.55 and v < 0.6:
					cor = Color(1.0, 0.95, 0.65)
				elif densidade > 0.25:
					cor = Color(1.0, 0.62, 0.12)
				elif densidade > 0.0:
					cor = Color(0.85, 0.22, 0.05)
				img.set_pixel(q * LADO + x, y, cor)
	_textura_da_chama = ImageTexture.create_from_image(img)
	return _textura_da_chama
