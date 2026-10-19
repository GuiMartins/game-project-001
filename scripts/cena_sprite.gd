class_name CenaSprite
extends Node3D
## O sprite dentro do jogo de verdade: o mesmo `AtorSprite` e o mesmo
## `PedestreSprite`, com o mesmo shader, de pe em asfalto e visto por uma
## camera que se orbita. E aqui que aparece o que a folha em 2D nao mostra: a
## troca de angulo, o sprite colado na pista, o tamanho de um ao lado do outro.

const ASFALTO: Texture2D = preload("res://assets/visual/asfalto_albedo.png")
## Onde a camera olha: a altura do peito, para o sprite ficar centrado.
const ALVO := Vector3(0.0, 0.9, 0.0)
const CEU_DIA := Color(0.55, 0.66, 0.82)
const CEU_NOITE := Color(0.03, 0.04, 0.08)
## Um ciclo de passada por segundo, a 1,0 de velocidade: e o ritmo do `Pessoa`.
const CICLOS_POR_SEGUNDO: float = 1.0
## Quanto dura, em segundos, uma volta do desembarque e do voo: o jogo solta a
## pessoa no estado e aqui ela repete, para dar tempo de olhar.
const DURACAO_DESEMBARQUE: float = 2.5
const DURACAO_VOO: float = 1.0
## Afastamento entre os cinco do elenco, em metros.
const ESPACO_ELENCO: float = 1.1

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
var pausado: bool = false
var velocidade_animacao: float = 1.0
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
## De 0 (meio-dia) a 1 (noite fechada), o mesmo `noite` global do jogo.
var noite: float = 0.0:
	set(valor):
		noite = clampf(valor, 0.0, 1.0)
		_aplica_noite()
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
var _regua: Node3D
var _sujeitos := Node3D.new()
var _relogio: float = 0.0
var _fase: float = 0.0
var _moto: Entregador
var _pessoas: Array[PedestreSprite] = []
var _avatar: int = 0


func _ready() -> void:
	_ambiente.background_mode = Environment.BG_COLOR
	_ambiente.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_ambiente.ambient_light_color = Color.WHITE
	var mundo := WorldEnvironment.new()
	mundo.environment = _ambiente
	add_child(mundo)
	_sol.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	_sol.shadow_enabled = true
	add_child(_sol)
	add_child(_chao())
	_regua = _monta_regua()
	_regua.visible = regua
	add_child(_regua)
	add_child(_sujeitos)
	_camera.fov = 40.0
	_camera.current = true
	add_child(_camera)
	_posiciona_camera()
	_aplica_noite()


func _exit_tree() -> void:
	# O global e do projeto inteiro: nao deixa a noite do testador para o jogo.
	RenderingServer.global_shader_parameter_set(&"noite", 0.0)


## Poe `item` em cena. Folha que nao e de pedestre nem de moto fica vazia.
func mostrar(item: CatalogoSprites.Item) -> void:
	_item = item
	_avatar = _avatar_do(item)
	_relogio = 0.0
	_fase = 0.0
	_monta()


func soco(lado: int) -> void:
	if _moto != null:
		_moto.socar(lado, 0.15, 0.1, 0.45)


func _process(delta: float) -> void:
	if _item == null:
		return
	var passo := 0.0 if pausado else delta * velocidade_animacao
	_relogio += passo
	_fase = wrapf(_fase + passo * TAU * CICLOS_POR_SEGUNDO, 0.0, TAU)
	if _moto != null:
		_moto.atualizar(passo, 12.0, 0.5, 0.0, false, 1.0, deg_to_rad(inclinacao_graus))
	_posa_pessoas()


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
	for i in _pessoas.size():
		var avatar := i if elenco else _avatar
		_pessoas[i].posar(estado, _fase, _relogio_do_estado(estado), giro, rapidez, avatar)


## O relogio de cada estado dá a volta na duracao da propria animacao: o jogo
## poe a pessoa no estado e solta, e aqui ela repete para dar tempo de olhar.
func _relogio_do_estado(estado: int) -> float:
	match estado:
		Pessoa.Estado.SUSTO:
			return fmod(_relogio, Pessoa.SUSTO_DURA + Pessoa.SUSTO_OLHA)
		Pessoa.Estado.DESEMBARCANDO:
			return fmod(_relogio, DURACAO_DESEMBARQUE)
		Pessoa.Estado.VOANDO:
			return fmod(_relogio, DURACAO_VOO)
	return _relogio


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


func _aplica_noite() -> void:
	if not is_node_ready():
		return
	RenderingServer.global_shader_parameter_set(&"noite", noite)
	_ambiente.background_color = CEU_DIA.lerp(CEU_NOITE, noite)
	_ambiente.ambient_light_energy = lerpf(0.9, 0.15, noite)
	_sol.light_energy = lerpf(1.0, 0.05, noite)


func _chao() -> MeshInstance3D:
	var plano := PlaneMesh.new()
	plano.size = Vector2(60.0, 60.0)
	var material := StandardMaterial3D.new()
	material.albedo_texture = ASFALTO
	material.uv1_scale = Vector3(20.0, 20.0, 1.0)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC
	plano.material = material
	var chao := MeshInstance3D.new()
	chao.mesh = plano
	return chao


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
