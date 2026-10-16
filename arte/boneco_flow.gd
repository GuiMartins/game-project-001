extends SceneTree
## Folhas de pose do boneco, para dar de referencia ao Google Flow.
##
##     python tools/dev.py boneco
##
## O Flow desenha bem quem e a pessoa (a folha de personagem) e mal o que ela
## esta fazendo e de que lado. Estas folhas cobrem o segundo: o `Pessoa` do
## proprio jogo, posado pelo mesmo codigo que o anima, num boneco cinza sem
## rosto nem roupa, em grade fixa. A pose da referencia e a do jogo, e nao uma
## aproximacao feita em outro programa.
##
## Cada folha e uma grade: uma linha por angulo, uma coluna por quadro. O Flow
## nao respeita a grade ao pixel, mas segue a ordem e a pose, e o recorte
## (`arte/sprites_flow.gd`) acha cada desenho pelos vaos entre eles, sem
## depender da grade.
##
## A escala e a mesma em todas as folhas (`PPM`), e so o tamanho da celula muda:
## o susto precisa de mais ar por cima, o voo e a queda de mais largura. Assim a
## pessoa tem o mesmo tamanho em qualquer folha, e o pipeline nao precisa
## adivinhar.
##
## Roda com tela: o renderizador do `--headless` e um dummy, e sai tudo preto.

## Pixels por metro: um adulto de 1,75 m ocupa uns 340 dos 400 de uma celula de
## pe, e sobra margem para o balanco do braco.
const PPM: float = 192.0
## Metros abaixo dos pes que a celula guarda, para o chao nao ser a borda.
const FOLGA_PES: float = 0.12
const VERDE := Color(0.0, 1.0, 0.0)
const PASTA: String = "res://arte/flow/referencia/"
## A pessoa em pe, em quadros de movimento: um ciclo de dois passos em oito
## poses, uma a cada 45 graus da fase. E o que o Flow aguenta numa tira sem
## perder a pessoa de vista.
const QUADROS_ANDANDO: int = 8

## O giro e em volta de Y: 0 olha para -Z (de costas para a camera) e 180 para
## +Z (de frente). O lado olha para a direita, como nas folhas de personagem; o
## esquerdo sai espelhando no recorte.
const ANGULOS_CINCO: Array[Array] = [
	["frente", 180.0],
	["tres_quartos_frente", -135.0],
	["lado", -90.0],
	["tres_quartos_costas", -45.0],
	["costas", 0.0],
]
## Quem se assusta olha o perigo, que vem de frente: sem os de costas.
const ANGULOS_FRENTE: Array[Array] = [
	["frente", 180.0],
	["tres_quartos_frente", -135.0],
	["lado", -90.0],
]
## A direcao em que voa ou desliza: para a direita, para longe da camera (como
## a moto o pega, de trás), em diagonal para longe e para perto.
const ANGULOS_VOO: Array[Array] = [
	["lado", -90.0],
	["tres_quartos_costas", -45.0],
	["costas", 0.0],
	["tres_quartos_frente", -135.0],
]
## O carro visto de lado, de tres quartos pela frente e por tras, e de frente,
## sempre com a porta do lado +X (a que o desembarque usa) virada para a
## camera. De costas puro nao entra: o encosto do banco esconde quem esta nele,
## e a referencia sairia sem pessoa.
const ANGULOS_CARRO: Array[Array] = [
	["carro_de_lado", -90.0],
	["carro_tres_quartos_frente", -135.0],
	["carro_tres_quartos_costas", -45.0],
	["carro_de_frente", 180.0],
]

## Cada folha: nome, colunas, os angulos das linhas, e a celula em metros
## (largura, altura) com a altura do centro da camera.
const FOLHAS: Array[Dictionary] = [
	{
		"nome": "parada",
		"colunas": 4,
		"angulos": ANGULOS_CINCO,
		"celula": Vector2(1.5, 2.08),
		"centro": 0.92,
	},
	{
		"nome": "andando",
		"colunas": QUADROS_ANDANDO,
		"angulos": ANGULOS_CINCO,
		"celula": Vector2(1.5, 2.08),
		"centro": 0.92,
	},
	{
		"nome": "susto",
		"colunas": 6,
		"angulos": ANGULOS_FRENTE,
		"celula": Vector2(1.8, 2.4),
		"centro": 1.08,
	},
	{
		"nome": "voando",
		"colunas": 8,
		"angulos": ANGULOS_VOO,
		"celula": Vector2(2.8, 2.8),
		"centro": 1.6,
	},
	{
		"nome": "caida",
		"colunas": 3,
		"angulos": ANGULOS_VOO,
		"celula": Vector2(2.6, 1.4),
		"centro": 0.58,
	},
	{
		"nome": "desembarcando",
		"colunas": 8,
		"angulos": ANGULOS_CARRO,
		"celula": Vector2(2.0, 2.08),
		"centro": 0.92,
	},
]
## Instantes do `Pessoa._assusta` que viram quadros: arma, sobe, topo, desce,
## cai e olha. O pulo dura 0,5 s e depois ele fica olhando.
const TEMPOS_SUSTO: Array[float] = [0.0, 0.12, 0.25, 0.38, 0.5, 0.8]
## Instantes do `Pessoa._desembarca` (porta de 2 s): sentado, gira, poe os pes
## para fora, levanta, anda para tras, empurra a porta.
const TEMPOS_DESEMBARQUE: Array[float] = [0.0, 0.35, 0.6, 0.85, 1.1, 1.45, 1.85, 2.2]
const FECHA_EM: float = 2.0
## Instantes do `_voa` que viram quadros: o giro do corpo dividido em oito, o
## sacudir dos membros pelo relogio do voo.
const QUADROS_VOO: int = 8

var _vp: SubViewport
var _cam: Camera3D
var _pessoa: Pessoa
var _banco: Node3D


func _initialize() -> void:
	_vp = SubViewport.new()
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

	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_vp.add_child(_cam)

	_banco = _monta_banco()
	_vp.add_child(_banco)

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
	for folha in FOLHAS:
		await _faz_folha(folha)
	quit()


func _faz_folha(folha: Dictionary) -> void:
	var celula_m: Vector2 = folha["celula"]
	var celula := Vector2i(roundi(celula_m.x * PPM), roundi(celula_m.y * PPM))
	var colunas: int = folha["colunas"]
	var angulos: Array = folha["angulos"]
	_vp.size = celula
	_cam.size = celula_m.y
	_cam.position = Vector3(0.0, folha["centro"], 6.0)
	var img := Image.create(colunas * celula.x, angulos.size() * celula.y, false, Image.FORMAT_RGB8)
	img.fill(VERDE)
	for linha in angulos.size():
		for coluna in colunas:
			_zera()
			_posa(folha["nome"], coluna, colunas, angulos[linha])
			_pessoa._aplica()
			await _quadro(img, coluna, linha, celula)
	var caminho: String = PASTA + folha["nome"] + ".png"
	var erro := img.save_png(caminho)
	assert(erro == OK, "nao salvou " + caminho)
	print("+ ", ProjectSettings.globalize_path(caminho), "  ", img.get_size())


## Pessoa de pe, parada, no meio da cena, antes de cada quadro: o que o quadro
## anterior deixou (corpo girado, altura, banco) nao pode vazar para o seguinte.
func _zera() -> void:
	_pessoa.position = Vector3.ZERO
	_pessoa._rumo = 0.0
	_pessoa._corpo = Basis.IDENTITY
	_pessoa._pose_de_pe()
	_banco.visible = false


## A pose do quadro `coluna`, no angulo `angulo` ([nome, giro em graus]). Cada
## uma chama o mesmo codigo que anima o jogo; o que o jogo decide por tempo,
## aqui se decide pelo quadro.
func _posa(folha: String, coluna: int, colunas: int, angulo: Array) -> void:
	var giro: float = deg_to_rad(angulo[1])
	match folha:
		"parada":
			_pessoa._rumo = giro
			_pessoa._relogio = float(coluna) / float(colunas) * _pessoa._ritmo
			_pessoa._fica()
		"andando":
			_pessoa._rumo = giro
			_pessoa._fase = TAU * float(coluna) / float(colunas)
			_pessoa._pose_andando()
		"susto":
			_pessoa._rumo = giro
			_pessoa._relogio = TEMPOS_SUSTO[coluna]
			_pessoa._susto_de = Vector3.ZERO
			_pessoa._susto_para = Vector3.ZERO
			_pessoa._assusta()
		"voando":
			_voa(giro, coluna)
		"caida":
			_cai(giro, coluna)
		"desembarcando":
			_desembarca(giro, TEMPOS_DESEMBARQUE[coluna])


## O corpo no ar, como `Pessoa._voa`: cambalhota para a frente (o eixo e o
## `UP x frente` do `atropelar`), bracos e pernas soltos. O relogio do voo e o
## do quadro, e nao o real, para a folha sair igual toda vez.
func _voa(rumo: float, coluna: int) -> void:
	var p := _pessoa
	var frente := Vector3(-sin(rumo), 0.0, -cos(rumo))
	var eixo := Vector3.UP.cross(frente).normalized()
	var eixo_local := Basis(Vector3.UP, rumo).inverse() * eixo
	var t := float(coluna) * 0.08
	p._rumo = rumo
	p._corpo = Basis(eixo_local.normalized(), TAU * float(coluna) / float(QUADROS_VOO))
	# O corpo gira em volta de `PIVO`; o pivo vai para o meio da celula.
	p.position = Vector3(0.0, 1.6 - Pessoa.PIVO.y, 0.0)
	p._altura = Pessoa.QUADRIL
	p._tronco = -0.2
	for i in 2:
		var f := PI * float(i)
		p._braco[i] = 1.8 + 0.8 * sin(t * 13.0 + f)
		p._abre[i] = 1.0 + 0.3 * sin(t * 9.0 + f)
		p._coxa[i] = 0.6 * sin(t * 11.0 + f)
		p._joelho[i] = 0.7 + 0.4 * sin(t * 7.0 + f)


## Deitado de bruços, com a cabeca para onde ia, como `Pessoa._voa` o deixa ao
## segundo quique. O jogo so tem esta pose; as tres colunas variam o
## braco e a perna do jeito que o corpo cairia, e nao inventam deitado de
## costas.
func _cai(rumo: float, coluna: int) -> void:
	var p := _pessoa
	p._rumo = rumo
	p._corpo = Basis(Vector3.RIGHT, -PI * 0.5)
	p.position = Vector3(0.0, Pessoa.DEITADO - Pessoa.PIVO.y, 0.0)
	p._pose_deitada()
	match coluna:
		1:
			p._braco = [0.9, 0.2]
			p._abre = [0.8, 1.2]
			p._coxa = [0.1, -0.3]
			p._joelho = [0.2, 0.6]
		2:
			p._braco = [-0.2, 0.7]
			p._abre = [1.3, 0.4]
			p._coxa = [-0.2, 0.3]
			p._joelho = [0.7, 0.1]


## Sair do carro, no espaco do carro (`Pessoa.desembarcar`): o carro e que gira
## para a camera, e a pessoa gira junto com ele. A porta e a do lado +X, a que
## fica virada para a camera nas vistas de lado e de tres quartos.
func _desembarca(carro: float, t: float) -> void:
	var p := _pessoa
	p._assento = Vector3.ZERO
	p._altura_banco = 0.5
	p._lado = 1.0
	p._meia_largura = 0.9
	p._fecha_em = FECHA_EM
	p._relogio = t
	p._fase = 0.0
	p._desembarca()
	# So a pose conta: o quanto o corpo andou para os lados e sai da celula.
	p.position = Vector3.ZERO
	p._rumo += carro
	_banco_do_carro(carro)
	# O banco some quando a pessoa ja esta de pe, e nao fica como um bloco no
	# meio da caminhada para tras.
	_banco.visible = t < 0.85


## O banco do carro, para o boneco sentado nao boiar. A frente do carro e -Z; o
## quadril fica na origem, a coxa vai para a frente, o encosto atras.
func _banco_do_carro(carro: float) -> void:
	_banco.rotation = Vector3(0.0, carro, 0.0)
	_banco.visible = true


func _monta_banco() -> Node3D:
	var banco := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.28, 0.29, 0.32)
	mat.roughness = 1.0
	var assento := MeshInstance3D.new()
	var caixa := BoxMesh.new()
	caixa.size = Vector3(0.6, 0.46, 0.8)
	assento.mesh = caixa
	assento.material_override = mat
	assento.position = Vector3(0.0, 0.23, -0.2)
	banco.add_child(assento)
	var encosto := MeshInstance3D.new()
	var costas := BoxMesh.new()
	costas.size = Vector3(0.6, 0.55, 0.1)
	encosto.mesh = costas
	encosto.material_override = mat
	encosto.position = Vector3(0.0, 0.7, 0.22)
	banco.add_child(encosto)
	return banco


## Pinta o quadro atual e cola na folha.
func _quadro(folha: Image, coluna: int, linha: int, celula: Vector2i) -> void:
	# O primeiro quadro depois de mexer na cena pode sair com a pose antiga.
	for i in 3:
		await process_frame
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	folha.blit_rect(img, Rect2i(Vector2i.ZERO, celula), Vector2i(coluna, linha) * celula)


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
