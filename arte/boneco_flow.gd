extends SceneTree
## Folhas de pose do boneco, para dar de referencia ao Google Flow.
##
##     python tools/dev.py boneco
##
## O Flow desenha bem quem e a pessoa (a folha de personagem) e mal o que ela
## esta fazendo e de que lado. Esta folha cobre o segundo: o `Pessoa` do proprio
## jogo, posado pelo mesmo codigo que o anima, num boneco cinza sem rosto nem
## roupa, em grade fixa. A pose da referencia e a do jogo, e nao uma
## aproximacao feita em outro programa.
##
## Cada folha e uma grade: uma linha por angulo, uma coluna por quadro, o chao
## na mesma altura em toda celula. O Flow nao respeita a grade ao pixel, mas
## segue a ordem e a pose, e o recorte (`arte/sprites_flow.gd`) acha cada
## desenho pelos vaos entre eles, sem depender da grade.
##
## Roda com tela: o renderizador do `--headless` e um dummy, e sai tudo preto.

## Tamanho de uma celula, em pixels. 192 px por metro: um adulto de 1,75 m
## ocupa uns 340 dos 400, e sobra margem para o balanco do braco de lado.
const CELULA := Vector2i(288, 400)
## Metros que cabem na altura da celula, e quanto do fundo fica abaixo dos pes.
const ALTURA_M: float = 2.08
const FOLGA_PES: float = 0.12
## Quadros do ciclo de andar: dois passos em oito poses, uma a cada 45 graus da
## fase. E o que o Flow aguenta numa tira sem perder a pessoa de vista.
const QUADROS_ANDANDO: int = 8
const VERDE := Color(0.0, 1.0, 0.0)
const PASTA: String = "res://arte/flow/referencia/"

## Os angulos, na ordem das linhas. O giro e em volta de Y: 0 olha para -Z (de
## costas para a camera) e 180 para +Z (de frente). O lado olha para a direita,
## como nas folhas de personagem; o esquerdo sai espelhando no recorte.
const ANGULOS: Array[Array] = [
	["frente", 180.0],
	["tres_quartos_frente", -135.0],
	["lado", -90.0],
	["tres_quartos_costas", -45.0],
	["costas", 0.0],
]

var _vp: SubViewport
var _pessoa: Pessoa


func _initialize() -> void:
	_vp = SubViewport.new()
	_vp.size = CELULA
	_vp.own_world_3d = true
	# Sem MSAA e sem suavizacao: a borda do boneco e o que o Flow vai ler, e
	# meio-tom no contorno vira halo na folha dele.
	_vp.msaa_3d = Viewport.MSAA_DISABLED
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = VERDE
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.74, 0.78)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)

	# Luz de frente e de cima, a mesma de qualquer angulo: a folha de personagem
	# pede "luz chapada", e o boneco que muda de sombra a cada angulo ensina o
	# Flow a mudar tambem.
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-40.0, 0.0, 0.0)
	sol.light_energy = 0.9
	_vp.add_child(sol)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = ALTURA_M
	cam.position = Vector3(0.0, ALTURA_M / 2.0 - FOLGA_PES, 6.0)
	_vp.add_child(cam)

	_pessoa = Pessoa.new()
	_vp.add_child(_pessoa)
	# A pose e do script, nao do relogio do jogo: sem isto o `_physics_process`
	# refaz a pose por cima a cada passo.
	_pessoa.set_physics_process(false)

	_roda.call_deferred()


func _roda() -> void:
	DirAccess.make_dir_recursive_absolute(PASTA)
	# O `_ready` da pessoa, que monta as malhas, so roda depois do `_initialize`.
	await process_frame
	_pinta_de_cinza()
	_poe_nariz()
	await _folha_andando()
	quit()


## O ciclo de andar do jogo (`Pessoa._pose_andando`), do primeiro quadro com a
## perna de tras ate o oitavo, que fecha o ciclo antes de repetir.
func _folha_andando() -> void:
	var folha := _folha_vazia(QUADROS_ANDANDO, ANGULOS.size())
	for linha in ANGULOS.size():
		_pessoa._rumo = deg_to_rad(ANGULOS[linha][1])
		for coluna in QUADROS_ANDANDO:
			_pessoa._fase = TAU * float(coluna) / float(QUADROS_ANDANDO)
			_pessoa._pose_andando()
			_pessoa._aplica()
			await _quadro(folha, coluna, linha)
	_salva(folha, "andando")


## Pinta o quadro atual e cola na folha.
func _quadro(folha: Image, coluna: int, linha: int) -> void:
	# O primeiro quadro depois de mexer na cena pode sair com a pose antiga.
	for i in 3:
		await process_frame
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	folha.blit_rect(img, Rect2i(Vector2i.ZERO, CELULA), Vector2i(coluna, linha) * CELULA)


func _folha_vazia(colunas: int, linhas: int) -> Image:
	var img := Image.create(colunas * CELULA.x, linhas * CELULA.y, false, Image.FORMAT_RGB8)
	img.fill(VERDE)
	return img


func _salva(folha: Image, nome: String) -> void:
	var caminho := PASTA + nome + ".png"
	var erro := folha.save_png(caminho)
	assert(erro == OK, "nao salvou " + caminho)
	print("+ ", ProjectSettings.globalize_path(caminho), "  ", folha.get_size())


## Cinza liso, sem roupa nem pele: um manequim. Tres tons, e nao um, para o
## tronco, os bracos e as pernas se lerem separados no angulo de lado, onde um
## cinza so funde o braco da frente com o corpo.
func _pinta_de_cinza() -> void:
	for malha: MeshInstance3D in _pessoa._malhas:
		for s in malha.mesh.get_surface_count():
			var nome := malha.mesh.surface_get_material(s).resource_name
			var mat := StandardMaterial3D.new()
			mat.albedo_color = _tom(nome)
			mat.roughness = 1.0
			malha.set_surface_override_material(s, mat)


## O boneco do jogo tem a mesma cabeca na frente e atras: o cabelo e uma tampa
## no alto, sem nuca. Sem um sinal de qual lado e a frente, a folha de costas e
## a de frente saem iguais, e o Flow desenha as duas de frente. Uma ponta no
## rosto (so desta folha, o jogo nao a tem) diz para onde ele olha.
func _poe_nariz() -> void:
	var nariz := MeshInstance3D.new()
	var caixa := BoxMesh.new()
	caixa.size = Vector3(0.05, 0.05, 0.09)
	nariz.mesh = caixa
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _tom("pele")
	mat.roughness = 1.0
	nariz.material_override = mat
	# Relativo ao no do tronco, que fica no quadril (0,92 m): a cabeca esta a
	# 1,64 m do chao e olha para -Z.
	nariz.position = Vector3(0.0, 1.64 - 0.92 - 0.02, -0.13)
	_pessoa._no_tronco.add_child(nariz)


func _tom(material: String) -> Color:
	match material:
		"pele":
			return Color(0.82, 0.82, 0.84)
		"roupa":
			return Color(0.55, 0.57, 0.62)
	return Color(0.38, 0.40, 0.44)
