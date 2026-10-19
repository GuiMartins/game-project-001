class_name JogoSprite
extends Node3D
## O playground do testador de sprites: um trecho reto de pista, com calcada, um
## carro parado e a chegada, onde se joga com o sprite no lugar de so olhar para
## ele.
##
## Quem anda de verdade e o que o jogo tem: a `Pessoa` (que o jogador conduz
## com as setas ou WASD), o `PlayerBike` (os mesmos controles e a mesma fisica
## da corrida) e o `Carro` que deixa alguem descer. Nada disto e copia: sao as
## classes do jogo, instanciadas soltas. O que o playground acrescenta sao os
## botoes de situacao (atropelar, passar uma moto, sair do carro, largada), cada
## um chamando a funcao que o jogo ja chama.
##
## Tudo na reta de -Z, como a pista dos testes: a frente da moto, da pessoa e do
## carro e -Z.

## Um aviso do que acabou de acontecer, para o texto da tela.
signal evento(texto: String)
## Quem e a pessoa conduzida mudou, para a barra de botoes acompanhar.
signal avatar_alterado(indice: int)

enum Ator { PESSOA, MOTO }

const COMPRIMENTO: float = 1500.0
const PASSO_DA_CURVA: float = 12.0
## Onde cada coisa fica, em metros contados do inicio da pista (a moto nasce no
## zero, de frente para -Z).
const PESSOA_EM: float = 40.0
const CARRO_EM: float = 60.0
const CHEGADA_EM: float = 450.0
const LARGADA_EM: float = 9.0
## Velocidade de quem anda, e de quem corre (Shift), em m/s.
const CAMINHAR: float = 1.4
const CORRER: float = 3.4
## Quando a porta do carro bate, em segundos: o mesmo ritmo do `TrafficCar`.
const PORTA_FECHA_EM: float = 2.5
## A fiscal da largada ergue as bandeiras por tres segundos e sai de cena logo
## depois (`main.gd`).
const LARGADA_DURA: float = 3.35
## Quanto da pista a calcada cobre ao lado do asfalto, em metros, e quanto
## alem da borda ela comeca.
const LARGURA_DA_CALCADA: float = 5.0
## A camisa de cada pessoa em 3D, que o sprite nao usa: com o modelo, e ela que
## separa uma da outra.
const CAMISAS: Array[Color] = [
	Color(0.9, 0.9, 0.85),
	Color(1.0, 0.45, 0.1),
	Color(0.15, 0.55, 0.9),
	Color(0.9, 0.9, 0.95),
	Color(0.85, 0.85, 0.9),
]

## Quem os controles conduzem. A outra moto ou pessoa fica parada onde esta.
var ator: int = Ator.PESSOA:
	set(valor):
		ator = valor
		if is_node_ready():
			_troca_o_ator()
## Sprite ou modelo 3D em todo ator, e quantas poses por segundo (0 e liso).
var sprite: bool = true:
	set(valor):
		sprite = valor
		_aplica_ao_ator()
var cadencia_hz: float = 12.0:
	set(valor):
		cadencia_hz = valor
		_aplica_ao_ator()
## Qual das cinco pessoas e a controlada (`PedestreSprite`).
var avatar: int = PedestreSprite.PRAIA:
	set(valor):
		avatar = valor
		avatar_alterado.emit(valor)
		if is_node_ready():
			nova_pessoa()
var modelo_moto: int = Entregador.Modelo.CG_160:
	set(valor):
		modelo_moto = valor
		if moto != null:
			moto.usar_modelo(valor)
## A camera que segue a pessoa: em volta dela, como a do turntable. A da moto
## e a do jogo (`ChaseCamera`).
var camera_yaw_graus: float = 0.0
var camera_distancia: float = 5.5
var camera_elevacao_graus: float = 14.0
## Se o tempo corre mais devagar, para ver o voo e o desembarque.
var camera_lenta: bool = false:
	set(valor):
		camera_lenta = valor
		Engine.time_scale = 0.25 if valor else 1.0

var ambiente := AmbienteSprite.new()
var pista: RoadTrack
var pessoa: Pessoa
var moto: PlayerBike
var carro: Carro
var fiscal: Pessoa

var _camera_da_pessoa := Camera3D.new()
var _camera_da_moto: ChaseCamera
var _sangue := Node3D.new()
var _ultima_direcao := Vector3(0.0, 0.0, -1.0)
var _porta_t: float = -1.0
var _largada_t: float = -1.0
var _tem_pose_da_camera: bool = false


func _ready() -> void:
	add_child(ambiente)
	_sangue.name = "Sangue"
	_sangue.add_to_group(Sangue.GRUPO)
	add_child(_sangue)
	_monta_a_pista()
	var chegada := Chegada.new()
	add_child(chegada)
	chegada.montar(pista, CHEGADA_EM)
	_monta_a_moto()
	nova_pessoa()
	novo_carro()
	_camera_da_pessoa.fov = 50.0
	add_child(_camera_da_pessoa)
	_troca_o_ator()


func _exit_tree() -> void:
	# O tempo e do motor inteiro: nao deixa a camera lenta para o jogo.
	Engine.time_scale = 1.0


func _physics_process(delta: float) -> void:
	if ator == Ator.PESSOA:
		mover(_le_a_entrada(), Input.is_action_pressed("ride_boost"))
	_roda_o_carro(delta)
	_roda_a_largada(delta)
	_segue_a_pessoa(delta)


# --- os atores -------------------------------------------------------------


## Uma pessoa nova de pe no meio da pista, no lugar da que foi atropelada. Nova,
## e nao a mesma de pe: o corpo que voou guarda a rotacao do voo, e o `Pessoa`
## so a desfaz no proprio reinicio da torcida.
func nova_pessoa() -> void:
	if pessoa != null:
		remove_child(pessoa)
		pessoa.free()
	pessoa = Pessoa.new()
	pessoa.avatar = avatar
	add_child(pessoa)
	pessoa.vestir(CAMISAS[avatar % CAMISAS.size()])
	pessoa.colocar(Vector3(0.0, 0.0, -PESSOA_EM), 0.0)
	pessoa.estado = Pessoa.Estado.PARADA
	_aplica_ao_ator()
	_ultima_direcao = Vector3(0.0, 0.0, -1.0)
	_tem_pose_da_camera = false


## Um carro novo, com as portas fechadas e ninguem descendo.
func novo_carro() -> void:
	if carro != null:
		remove_child(carro)
		carro.free()
	carro = Carro.new()
	add_child(carro)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	carro.montar(Carro.Modelo.SEDA, rng)
	var onde := pista.transform_at(CARRO_EM, RoadTrack.lane_center(RoadTrack.LANE_COUNT - 1))
	carro.transform = onde
	_porta_t = -1.0


## A moto de volta ao comeco, parada e de pe.
func reiniciar_a_moto() -> void:
	moto.place_on_track(0.0, RoadTrack.corridor_center(1), 0.0)


# --- as situacoes ----------------------------------------------------------


## Anda para `direcao` (x para a direita da camera, y para a frente dela), ou
## fica parada se for zero. So quem esta de pe se mexe: quem pulou, voou ou
## desceu do carro termina o que estava fazendo.
func mover(direcao: Vector2, correr: bool = false) -> void:
	if pessoa == null or pessoa.estado not in [Pessoa.Estado.PARADA, Pessoa.Estado.ANDANDO]:
		return
	if direcao.length() < 0.1:
		if pessoa.estado == Pessoa.Estado.ANDANDO:
			pessoa.esperar(pessoa.position + _ultima_direcao)
		return
	var yaw := deg_to_rad(camera_yaw_graus)
	# A camera fica do lado de +Z de quem olha, no yaw zero: a frente dela e -Z.
	var frente := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var direita := Vector3(cos(yaw), 0.0, -sin(yaw))
	var mundo := (frente * direcao.y + direita * direcao.x).normalized()
	_ultima_direcao = mundo
	pessoa.velocidade = CORRER if correr else CAMINHAR
	# Um ponto sempre a frente: a pessoa nunca "chega" e o `Pessoa` segue andando
	# pelo mesmo caminho que usa na rua.
	pessoa.ir(PackedVector3Array([pessoa.position + mundo * 3.0]))


## A moto pega a pessoa a `velocidade` (m/s), vindo de tras para a frente.
func atropelar(velocidade: float) -> void:
	pessoa.atropelar(Vector3(0.0, 0.0, -velocidade))
	evento.emit("atropelada a %d km/h" % roundi(velocidade * 3.6))


## Uma moto passa por onde a pessoa esta, `lateral` metros para o lado: zero e
## em cima dela, de 0,6 a 1,5 e o susto, e mais que isso passa de longe.
func passar_uma_moto(velocidade: float, lateral: float) -> void:
	var fantasma := MotoFantasma.new()
	fantasma.velocidade = velocidade
	fantasma.sprite = sprite
	fantasma.cadencia_hz = cadencia_hz
	fantasma.modelo = modelo_moto
	fantasma.position = pessoa.position + Vector3(lateral, 0.0, 70.0)
	fantasma.position.y = 0.0
	add_child(fantasma)
	evento.emit("moto a %d km/h passando a %.1f m" % [roundi(velocidade * 3.6), absf(lateral)])


## Abre a porta do lado `lado` (-1 esquerda, 1 direita) e alguem desce, como no
## `TrafficCar`: a porta abre, a pessoa sai, a porta bate e ela vai para a
## calcada. Do lado da rua ela contorna a traseira.
func sair_do_carro(lado: int) -> void:
	novo_carro()
	carro.abrir_porta(lado)
	var calcada := RoadTrack.half_width() + LARGURA_DA_CALCADA * 0.5
	carro.desembarcar(PORTA_FECHA_EM, calcada - carro.position.x)
	_porta_t = 0.0
	_aplica_ao_ator()
	evento.emit("saindo do carro pela porta %s" % ("da direita" if lado > 0 else "da esquerda"))


## Quem desceu do carro, ou null se ninguem desceu.
func quem_desceu() -> Pessoa:
	return carro.find_child("Desceu", false, false) as Pessoa if carro != null else null


## A fiscal da largada com as bandeiras: tres segundos de sinal, e depois ela
## sai para a calcada, como em `main.gd`.
func largada() -> void:
	if fiscal == null:
		fiscal = Pessoa.new()
		fiscal.cena_articulada = preload("res://assets/pedestres/fiscal.glb")
		fiscal.name = "FiscalDaLargada"
		add_child(fiscal)
		# A sequencia posa a fiscal na mao, e a fisica dela a desfaria.
		fiscal.vestir(Color(1.0, 0.65, 0.08))
	fiscal.set_physics_process(false)
	fiscal.estado = Pessoa.Estado.PARADA
	var frente := pista.sample_basis(LARGADA_EM)
	fiscal.colocar(pista.sample_position(LARGADA_EM), frente.get_euler().y + PI)
	fiscal.sinalizar_largada(0.0)
	_largada_t = 0.0
	evento.emit("largada")


## Apaga as manchas do chao.
func limpar_o_chao() -> void:
	for mancha in _sangue.get_children():
		mancha.free()


# --- por baixo -------------------------------------------------------------


func _le_a_entrada() -> Vector2:
	return Vector2(
		Input.get_axis("ride_left", "ride_right"), Input.get_axis("ride_brake", "ride_throttle")
	)


## Uma reta de `COMPRIMENTO` metros para -Z, com a mesma malha de asfalto e as
## mesmas faixas da pista do jogo. Sem curva e sem ladeira: o que se testa e o
## sprite, e nao a pista.
func _monta_a_pista() -> void:
	pista = RoadTrack.new()
	pista.curve = Curve3D.new()
	pista.curve.bake_interval = 1.0
	for i in int(COMPRIMENTO / PASSO_DA_CURVA) + 1:
		pista.curve.add_point(Vector3(0.0, 0.0, -PASSO_DA_CURVA * i))
	pista.length = pista.curve.get_baked_length()
	pista.comprimento_da_avenida = pista.length
	pista.add_to_group(RoadTrack.GRUPO)
	add_child(pista)
	pista.build_surface()
	var calcada: Texture2D = load("res://assets/visual/calcada_albedo.png")
	var material := StandardMaterial3D.new()
	material.albedo_texture = calcada
	material.uv1_scale = Vector3(LARGURA_DA_CALCADA / 2.0, COMPRIMENTO / 2.0, 1.0)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC
	var plano := PlaneMesh.new()
	plano.size = Vector2(LARGURA_DA_CALCADA, COMPRIMENTO)
	plano.material = material
	for lado: float in [-1.0, 1.0]:
		var faixa := MeshInstance3D.new()
		faixa.mesh = plano
		faixa.position = Vector3(
			lado * (RoadTrack.half_width() + LARGURA_DA_CALCADA * 0.5), 0.01, -COMPRIMENTO * 0.5
		)
		add_child(faixa)


func _monta_a_moto() -> void:
	var tuning := BikeTuning.new()
	moto = PlayerBike.new()
	add_child(moto)
	moto.setup(tuning, pista, 0.0)
	moto.usar_modelo(modelo_moto)
	moto.marcar_foco()
	_camera_da_moto = ChaseCamera.new()
	add_child(_camera_da_moto)
	_camera_da_moto.setup(tuning, moto)


func _troca_o_ator() -> void:
	# A fisica da moto le os mesmos controles que a pessoa: so uma por vez.
	moto.set_physics_process(ator == Ator.MOTO)
	_camera_da_moto.current = ator == Ator.MOTO
	_camera_da_pessoa.current = ator == Ator.PESSOA
	_aplica_ao_ator()


## Sprite ou modelo e a cadencia em todo ator, do mesmo jeito que o `World`: em
## quem ja esta e em quem nasce depois (quem desce do carro).
func _aplica_ao_ator() -> void:
	if not is_node_ready():
		return
	if moto != null:
		moto.usar_sprite(sprite)
		moto.usar_cadencia(cadencia_hz)
	for no in get_tree().get_nodes_in_group(Pedestres.GRUPO_NOS):
		if no is Pessoa:
			(no as Pessoa).usar_sprite(sprite)
			(no as Pessoa).cadencia = cadencia_hz
	for no in get_children():
		if no is MotoFantasma:
			(no as MotoFantasma).usar(sprite, cadencia_hz)


func _roda_o_carro(delta: float) -> void:
	if carro == null:
		return
	carro.atualizar(delta, 0.0, 0.0, true, 0)
	if _porta_t < 0.0:
		return
	_porta_t += delta
	if _porta_t >= PORTA_FECHA_EM:
		carro.fechar_portas()
		_porta_t = -1.0


func _roda_a_largada(delta: float) -> void:
	if _largada_t < 0.0 or fiscal == null:
		return
	var antes := _largada_t
	_largada_t += delta
	if _largada_t < LARGADA_DURA:
		fiscal.sinalizar_largada(_largada_t)
	elif antes < LARGADA_DURA:
		# Depois do sinal ela libera o centro do grid e vai para a calcada.
		fiscal.velocidade = 3.5
		fiscal.ir(PackedVector3Array([pista.point(LARGADA_EM + 9.0, 8.0)]))
		fiscal.set_physics_process(true)
		_largada_t = -1.0


## A camera da pessoa: em volta dela, suave. A primeira vez vai direto, para
## nao atravessar a pista inteira desde a origem.
func _segue_a_pessoa(delta: float) -> void:
	var alvo := pessoa.global_position + Vector3(0.0, 0.9, 0.0)
	var yaw := deg_to_rad(camera_yaw_graus)
	var el := deg_to_rad(camera_elevacao_graus)
	var onde := alvo + camera_distancia * Vector3(sin(yaw) * cos(el), sin(el), cos(yaw) * cos(el))
	if _tem_pose_da_camera:
		onde = _camera_da_pessoa.global_position.lerp(onde, 1.0 - exp(-8.0 * delta))
	_tem_pose_da_camera = true
	_camera_da_pessoa.global_position = onde
	_camera_da_pessoa.look_at(alvo)
