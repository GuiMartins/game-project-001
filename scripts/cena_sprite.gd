class_name CenaSprite
extends Node3D
## O sprite dentro do jogo de verdade: o mesmo `AtorSprite` e o mesmo
## `PedestreSprite`, com o mesmo shader, de pe em asfalto e visto por uma
## camera que se orbita. E aqui que aparece o que a folha em 2D nao mostra: a
## troca de angulo dos pedestres, o sprite colado na pista, o tamanho de um ao
## lado do outro.
##
## Com a hora e a paleta ligadas a cena usa o mesmo ceu, sol, tonemap, LUT e
## quantizacao com dither do jogo (`Relogio`, `Hora`, `paleta.gdshader`), e com
## a velocidade ligada o mundo corre embaixo dele na cadencia que o jogo usa.
## Sem isso, o sprite que parece bom parado treme ou desliza na estrada.

const ASFALTO: Texture2D = preload("res://assets/visual/asfalto_albedo.png")
const CEU: Shader = preload("res://scripts/ceu.gdshader")
const PALETA: Shader = preload("res://scripts/paleta.gdshader")
## Onde a camera olha: a altura do peito, para o sprite ficar centrado.
const ALVO := Vector3(0.0, 0.9, 0.0)
## A camera do jogo (`BikeTuning`): 4,5 m atras, a 1,2 m de altura, lente de 50.
const CAMERA_DO_JOGO_DISTANCIA: float = 4.5
const CAMERA_DO_JOGO_ALTURA: float = 1.2
const CAMERA_DO_JOGO_FOV: float = 50.0
## Um ciclo de passada por segundo, a 1,0 de velocidade: e o ritmo do `Pessoa`.
const CICLOS_POR_SEGUNDO: float = 1.0
## Quanto dura, em segundos, uma volta do desembarque e do voo: o jogo solta a
## pessoa no estado e aqui ela repete, para dar tempo de olhar.
const DURACAO_DESEMBARQUE: float = 2.5
const DURACAO_VOO: float = 1.0
## Afastamento entre os cinco do elenco, em metros.
const ESPACO_ELENCO: float = 1.1
## Quantos metros a textura do asfalto cobre, e de quantos em quantos metros ha
## um poste correndo ao lado: sem referencia a velocidade nao se ve.
const METROS_DA_TEXTURA: float = 3.0
const ESPACO_DOS_POSTES: float = 9.0
const POSTES: int = 14

var yaw_graus: float = 0.0:
	set(valor):
		yaw_graus = valor
		_posiciona_camera()
var distancia: float = 4.0:
	set(valor):
		distancia = clampf(valor, 1.5, 20.0)
		_posiciona_camera()
var elevacao_graus: float = 12.0:
	set(valor):
		elevacao_graus = clampf(valor, -10.0, 80.0)
		_posiciona_camera()
var fov: float = 40.0:
	set(valor):
		fov = valor
		_camera.fov = valor
var pausado: bool = false
var velocidade_animacao: float = 1.0
## Metros por segundo que o chao corre embaixo do sprite; 0 e parado.
var velocidade_da_pista: float = 0.0
## Poses por segundo, como a `Cadencia` do jogo; 0 e uma por quadro.
var cadencia_hz: float = 0.0:
	set(valor):
		cadencia_hz = valor
		if _moto != null:
			_moto.cadencia.hz = valor
## O elenco inteiro lado a lado, para comparar tamanho e passada.
var elenco: bool = false:
	set(valor):
		elenco = valor
		_monta()
var regua: bool = true:
	set(valor):
		regua = valor
		if _regua != null:
			_regua.visible = valor
## A hora do jogo, de 0 (meio-dia) a 1 (noite fechada), pelo `Relogio`.
var hora: float = 0.0:
	set(valor):
		hora = clampf(valor, 0.0, 1.0)
		if is_node_ready():
			_relogio_do_dia.fixar(hora)
## A quantizacao com dither do jogo por cima de tudo.
var paleta: bool = false:
	set(valor):
		paleta = valor
		if _tela_da_paleta != null:
			_tela_da_paleta.visible = valor
## Da moto.
var inclinacao_graus: float = 0.0
var modelo_moto: int = Entregador.Modelo.CG_160:
	set(valor):
		modelo_moto = clampi(valor, 0, Entregador.CENAS.size() - 1)
		_monta()
## Do voo: quanto o corpo gira, em radianos, e da queda: se ainda desliza.
var giro: float = 0.0
var movendo: bool = true

var _item: CatalogoSprites.Item
var _camera := Camera3D.new()
var _ambiente := Environment.new()
var _sol := DirectionalLight3D.new()
var _ceu := ShaderMaterial.new()
var _relogio_do_dia := Relogio.new()
var _tela_da_paleta: ColorRect
var _chao_material: StandardMaterial3D
var _regua: Node3D
var _postes: Node3D
var _sujeitos := Node3D.new()
var _tempo: float = 0.0
var _fase: float = 0.0
var _rolado: float = 0.0
var _moto: Entregador
var _pessoas: Array[PedestreSprite] = []
var _avatar: int = 0


func _ready() -> void:
	_monta_ambiente()
	add_child(_chao())
	_regua = _monta_regua()
	_regua.visible = regua
	add_child(_regua)
	_postes = _monta_postes()
	add_child(_postes)
	add_child(_sujeitos)
	_camera.fov = fov
	_camera.current = true
	add_child(_camera)
	_posiciona_camera()
	_monta_paleta()
	add_child(_relogio_do_dia)
	_relogio_do_dia.montar(_ambiente, _sol, _ceu)
	_relogio_do_dia.fixar(hora)


func _exit_tree() -> void:
	# O global e do projeto inteiro: nao deixa a noite do testador para o jogo.
	RenderingServer.global_shader_parameter_set(&"noite", 0.0)
	Relogio.escuro = 0.0


## Poe `item` em cena. Folha que nao e de pedestre nem de moto fica vazia.
func mostrar(item: CatalogoSprites.Item) -> void:
	_item = item
	_avatar = _avatar_do(item)
	_tempo = 0.0
	_fase = 0.0
	_monta()


func soco(lado: int) -> void:
	if _moto != null:
		_moto.socar(lado, 0.15, 0.1, 0.45)


## A camera do jogo: atras, baixa, com a mesma lente.
func camera_do_jogo() -> void:
	yaw_graus = 0.0
	distancia = CAMERA_DO_JOGO_DISTANCIA
	elevacao_graus = rad_to_deg(asin((CAMERA_DO_JOGO_ALTURA - ALVO.y) / CAMERA_DO_JOGO_DISTANCIA))
	fov = CAMERA_DO_JOGO_FOV


func _process(delta: float) -> void:
	if _item == null:
		return
	var passo := 0.0 if pausado else delta * velocidade_animacao
	_tempo += passo
	_fase = wrapf(_fase + passo * TAU * CICLOS_POR_SEGUNDO, 0.0, TAU)
	_corre_a_pista(delta)
	if _moto != null:
		_moto.atualizar(
			passo,
			maxf(velocidade_da_pista, 12.0),
			0.5,
			0.0,
			false,
			1.0,
			deg_to_rad(inclinacao_graus)
		)
	_posa_pessoas()


## O chao anda para tras e os postes vem para a camera: a moto e a pessoa ficam
## no lugar, como na tela do jogo, onde a camera segue o corpo.
func _corre_a_pista(delta: float) -> void:
	if pausado or velocidade_da_pista <= 0.0:
		return
	_rolado += velocidade_da_pista * delta
	_chao_material.uv1_offset = Vector3(0.0, _rolado / METROS_DA_TEXTURA, 0.0)
	for poste in _postes.get_children():
		poste.position.z += velocidade_da_pista * delta
		if poste.position.z > 6.0:
			poste.position.z -= ESPACO_DOS_POSTES * POSTES


func _monta() -> void:
	if not is_node_ready():
		return
	for filho in _sujeitos.get_children():
		filho.queue_free()
		_sujeitos.remove_child(filho)
	_moto = null
	_pessoas.clear()
	if _item == null:
		return
	if _item.tipo == CatalogoSprites.Tipo.MOTO:
		_moto = Entregador.new()
		_moto.modelo = modelo_moto
		_sujeitos.add_child(_moto)
		_moto.sprite = true
		_moto.cadencia.hz = cadencia_hz
		return
	var quantos := PedestreSprite.ANDANDO.size() if elenco else 1
	for i in quantos:
		var pessoa := PedestreSprite.new()
		pessoa.visible = true
		pessoa.position.x = (i - (quantos - 1) * 0.5) * ESPACO_ELENCO if elenco else 0.0
		_sujeitos.add_child(pessoa)
		_pessoas.append(pessoa)
	_posa_pessoas()


func _posa_pessoas() -> void:
	var estado := _estado_de(_item)
	var rapidez := 1.0 if movendo else 0.0
	# A pose pula na cadencia e o relogio anda liso, como o `Pessoa` faz: a
	# fase e o tempo que chegam ao desenho sao os da ultima pose.
	var tempo := _tempo
	var fase := _fase
	if cadencia_hz > 0.0:
		var periodo := 1.0 / cadencia_hz
		tempo = floorf(_tempo / periodo) * periodo
		fase = (
			floorf(_fase / TAU * CICLOS_POR_SEGUNDO * cadencia_hz)
			/ (cadencia_hz * CICLOS_POR_SEGUNDO)
			* TAU
		)
	for i in _pessoas.size():
		var avatar := i if elenco else _avatar
		_pessoas[i].posar(estado, fase, _tempo_do_estado(estado, tempo), giro, rapidez, avatar)


## O relogio de cada estado da a volta na duracao da propria animacao.
func _tempo_do_estado(estado: int, tempo: float) -> float:
	match estado:
		Pessoa.Estado.SUSTO:
			return fmod(tempo, Pessoa.SUSTO_DURA + Pessoa.SUSTO_OLHA)
		Pessoa.Estado.DESEMBARCANDO:
			return fmod(tempo, DURACAO_DESEMBARQUE)
		Pessoa.Estado.VOANDO:
			return fmod(tempo, DURACAO_VOO)
	return tempo


static func _estado_de(item: CatalogoSprites.Item) -> int:
	match item.animacao:
		"susto":
			return Pessoa.Estado.SUSTO
		"desembarcando":
			return Pessoa.Estado.DESEMBARCANDO
		"voando":
			return Pessoa.Estado.VOANDO
		"caida":
			return Pessoa.Estado.CAIDA
	return Pessoa.Estado.ANDANDO


## Qual das cinco pessoas e a da folha: a ordem de `PedestreSprite.ANDANDO` e a
## que o jogo usa, e o nome do arquivo diz quem e cada uma.
static func _avatar_do(item: CatalogoSprites.Item) -> int:
	for i in PedestreSprite.ANDANDO.size():
		if PedestreSprite.ANDANDO[i].resource_path.get_file().begins_with(item.grupo.to_lower()):
			return i
	return 0


func _posiciona_camera() -> void:
	if not is_instance_valid(_camera):
		return
	var yaw := deg_to_rad(yaw_graus)
	var el := deg_to_rad(elevacao_graus)
	_camera.position = ALVO + distancia * Vector3(sin(yaw) * cos(el), sin(el), cos(yaw) * cos(el))
	_camera.look_at(ALVO)


## O ambiente do jogo (`World`): ceu em shader, tonemap filmic, LUT. O que muda
## com a hora o `Relogio` aplica.
func _monta_ambiente() -> void:
	_ceu.shader = CEU
	var ceu := Sky.new()
	ceu.sky_material = _ceu
	_ambiente.background_mode = Environment.BG_SKY
	_ambiente.sky = ceu
	_ambiente.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_ambiente.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_ambiente.tonemap_white = 6.0
	_ambiente.adjustment_enabled = true
	var mundo := WorldEnvironment.new()
	mundo.environment = _ambiente
	add_child(mundo)
	_sol.shadow_enabled = true
	add_child(_sol)


## A quantizacao do jogo, no mesmo lugar: um passe de tela por cima do 3D.
func _monta_paleta() -> void:
	var viewport := get_viewport()
	var camada := CanvasLayer.new()
	camada.layer = 5
	viewport.add_child.call_deferred(camada)
	_tela_da_paleta = ColorRect.new()
	_tela_da_paleta.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tela_da_paleta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = PALETA
	_tela_da_paleta.material = material
	_tela_da_paleta.visible = paleta
	camada.add_child(_tela_da_paleta)


func _chao() -> MeshInstance3D:
	var plano := PlaneMesh.new()
	plano.size = Vector2(60.0, 120.0)
	_chao_material = StandardMaterial3D.new()
	_chao_material.albedo_texture = ASFALTO
	_chao_material.uv1_scale = Vector3(60.0 / METROS_DA_TEXTURA, 120.0 / METROS_DA_TEXTURA, 1.0)
	_chao_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC
	plano.material = _chao_material
	var chao := MeshInstance3D.new()
	chao.mesh = plano
	chao.position.z = -40.0
	return chao


## Postes dos dois lados, de tras para a camera: a referencia de que a pista
## anda. Dois tracos de cada lado da faixa, e o resto e o sprite parado.
func _monta_postes() -> Node3D:
	var raiz := Node3D.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.55, 0.55, 0.6)
	var caixa := BoxMesh.new()
	caixa.size = Vector3(0.2, 3.0, 0.2)
	caixa.material = material
	for i in POSTES:
		for lado: float in [-1.0, 1.0]:
			var poste := MeshInstance3D.new()
			poste.mesh = caixa
			poste.position = Vector3(lado * 4.0, 1.5, -ESPACO_DOS_POSTES * i)
			raiz.add_child(poste)
	return raiz


## Um poste de 2 m ao lado, com um risco a cada meio metro: o tamanho real do
## sprite, sem confiar no olho.
func _monta_regua() -> Node3D:
	var raiz := Node3D.new()
	raiz.position = Vector3(1.2, 0.0, 0.0)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.85, 0.2)
	var poste := MeshInstance3D.new()
	var caixa := BoxMesh.new()
	caixa.size = Vector3(0.03, 2.0, 0.03)
	caixa.material = material
	poste.mesh = caixa
	poste.position.y = 1.0
	raiz.add_child(poste)
	for i in 5:
		var risco := MeshInstance3D.new()
		var barra := BoxMesh.new()
		barra.size = Vector3(0.25 if i % 2 == 0 else 0.14, 0.02, 0.02)
		barra.material = material
		risco.mesh = barra
		risco.position = Vector3(-0.1, i * 0.5, 0.0)
		raiz.add_child(risco)
	return raiz
