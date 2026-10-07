class_name Carro
extends Node3D
## O carro do transito por dentro: os modelos de `assets/carros`, posados a cada
## passo de fisica pelo movimento que o `TrafficCar` faz.
##
## O `TrafficCar` sabe onde o carro esta e a que velocidade anda; este no cuida
## do que isso faz com o carro: roda girando, roda estercando, carroceria
## mergulhando na freada e rolando na troca de faixa, porta abrindo, lanterna
## acendendo, seta piscando e o motorista com as maos no volante.
##
## Nada aqui e clipe de animacao, pela mesma razao do `Entregador`: pose lida do
## estado nao desencontra da fisica. A roda gira na velocidade em que o carro
## anda, a lanterna acende no passo em que ele freia, e a carroceria mergulha
## porque desacelerou - nao porque um clipe mandou.
##
## Varios destes sinais sao aviso para o jogador, e nao enfeite: a lanterna que
## acende diz que o carro da frente vai parar, a seta e a carroceria que rola
## dizem que ele vai fechar o corredor, e o pisca-alerta diz que esta encostado
## - e encostado e quem pode abrir a porta.

enum Modelo { HATCH, SEDA, SUV, TAXI, ONIBUS }

const CENA: PackedScene = preload("res://assets/carros/carros.glb")
const SHADER: Shader = preload("res://scripts/carro.gdshader")
const SHADER_VIDRO: Shader = preload("res://scripts/vidro.gdshader")
const ALBEDO: Texture2D = preload("res://assets/carros/carros_albedo.png")
const MASCARA: Texture2D = preload("res://assets/carros/carros_mascara.png")
## Na ordem do `Modelo`.
const NOS: Array[String] = ["Hatch", "Seda", "SUV", "Taxi", "Onibus"]

## A cor pintada na textura em cada troca: a celula mais clara sob ela em
## `PALETA`, no `arte/carros.py`. O `test_carro.gd` le a textura e reprova se
## as duas divergirem.
const PINTURA_FABRICA := Color(0.66, 0.67, 0.70)
const PELE_FABRICA := Color(0.60, 0.42, 0.31)
const CAMISA_FABRICA := Color(0.82, 0.82, 0.80)
const CAMISA2_FABRICA := Color(0.32, 0.46, 0.68)

## A frota da rua brasileira: prata, branco e preto sao quase tudo, e o resto e
## o que sobra para separar um carro do outro no corredor. Repetido de
## proposito: e a proporcao da rua, e nao uma lista de cores possiveis.
const PINTURAS: Array[Color] = [
	Color(0.66, 0.67, 0.70),
	Color(0.66, 0.67, 0.70),
	Color(0.90, 0.90, 0.88),
	Color(0.90, 0.90, 0.88),
	Color(0.11, 0.11, 0.12),
	Color(0.34, 0.35, 0.38),
	Color(0.62, 0.11, 0.09),
	Color(0.16, 0.25, 0.44),
	Color(0.70, 0.64, 0.52),
]
## O amarelo do taxi do Rio. Nao sai do sorteio: taxi de outra cor e outro carro.
const AMARELO_TAXI := Color(0.97, 0.78, 0.07)
## As cores dos consorcios de onibus do Rio.
const PINTURAS_ONIBUS: Array[Color] = [
	Color(0.16, 0.52, 0.30),
	Color(0.15, 0.36, 0.70),
	Color(0.93, 0.52, 0.12),
	Color(0.92, 0.76, 0.12),
]
const CAMISAS: Array[Color] = [
	Color(0.82, 0.82, 0.80),
	Color(0.12, 0.13, 0.16),
	Color(0.32, 0.46, 0.68),
	Color(0.62, 0.16, 0.14),
	Color(0.26, 0.50, 0.34),
	Color(0.90, 0.74, 0.30),
]
const PELES: Array[Color] = [
	Color(0.80, 0.62, 0.50),
	Color(0.66, 0.47, 0.35),
	Color(0.52, 0.36, 0.25),
	Color(0.36, 0.24, 0.17),
]

## Suspensao: frequencia natural em Hz, por modelo. 1,2 a 1,4 Hz e carro de
## passeio de verdade; o onibus, com 12 m e mola de ar, balanca devagar.
const FREQUENCIA: Array[float] = [1.4, 1.3, 1.15, 1.3, 0.85]
## Fracao do amortecimento critico. Abaixo de 1 a carroceria passa do ponto e
## volta, e e esse "balanco" depois da freada que le como mola.
const AMORTECIMENTO: Array[float] = [0.35, 0.35, 0.3, 0.35, 0.28]
## Graus de mergulho por m/s2 de freada (negativo e o nariz descendo). Real
## seria uns 0,35; mais que isso aqui porque o carro e visto de tras, a 20 m,
## e e o mergulho que diz "o da frente esta freando" antes da distancia dizer.
const MERGULHO: Array[float] = [0.6, 0.55, 0.65, 0.55, 0.45]
## Graus de rolagem por m/s2 de aceleracao lateral. SUV e onibus, com o centro
## de massa alto, rolam mais - e e a rolagem que anuncia a troca de faixa.
const ROLAGEM: Array[float] = [1.3, 1.2, 1.7, 1.2, 2.0]
## Quantas voltas de volante por volta de roda.
const DIRECAO: Array[float] = [14.0, 15.0, 15.0, 15.0, 20.0]
## Guinada maxima da carroceria na troca de faixa, em graus. O colisor nao gira
## junto, entao isto e o quanto a lataria pode sair da caixa de bater: no
## onibus de 12 m, 3 graus ja jogam a frente 30 cm para o lado.
const GUINADA_MAX: Array[float] = [8.0, 8.0, 8.0, 8.0, 3.0]
## Amplitude da irregularidade do asfalto em cada roda, em metros.
const ASFALTO: float = 0.006

## Porta de carro: abre ate isto, em graus, e e a dobradica que segura.
const PORTA_ABERTA: float = 68.0
## Folha de porta de onibus: dobra quase inteira para dentro.
const FOLHA_ABERTA: float = 85.0
## A partir de que fracao da abertura a porta conta como obstaculo: a fresta
## de uma porta comecando a abrir nao derruba ninguem.
const PORTA_BATE: float = 0.15

## Pisca de seta e alerta: 1,4 Hz, o ritmo do rele de carro.
const PISCA: float = 1.4
## Aceleracao, em m/s2, abaixo da qual a lanterna acende: freio de verdade, e
## nao o carro so tirando o pe.
const FREIO: float = -0.6

static var _moldes: Array[PackedScene] = []
static var _material: ShaderMaterial
static var _material_vidro: ShaderMaterial
static var _sufixo := RegEx.create_from_string("_\\d{3}$")

var modelo: Modelo = Modelo.SEDA

var _raiz: Node3D
var _carroceria: Node3D
var _lataria: MeshInstance3D
var _malhas: Array[MeshInstance3D] = []
var _repouso: Dictionary[Node3D, Transform3D] = {}
## DE, DD, TE, TD: as duas primeiras estercam.
var _rodas: Array[Node3D] = []
var _raio: float = 0.3
var _entre_eixos: float = 2.5
var _bitola: float = 1.5
## Onde fica o eixo traseiro: e em volta dele que o carro guina.
var _eixo_traseiro: float = 1.3
var _volante: Node3D
var _eixo_volante := Vector3.FORWARD
var _tronco: Node3D
var _cabeca: Node3D
## [braco, antebraco, mao] de cada lado, esquerdo e direito.
var _bracos: Array[Array] = []
## Onde cada mao segura o aro, no espaco do volante.
var _pegas: Array[Vector3] = []
## Portas que abrem para fora, e o lado de cada uma (-1 esquerda, 1 direita).
var _portas: Array[Node3D] = []
var _folhas: Array[Node3D] = []
## Angulo e velocidade angular de cada porta e folha, em radianos.
var _angulo: Dictionary[Node3D, float] = {}
var _giro_porta: Dictionary[Node3D, float] = {}
var _sinal_porta: Dictionary[Node3D, float] = {}
## A porta escolhida para abrir, ou nenhuma.
var _porta_ativa: Node3D
var _abrindo: bool = false

var _rng := RandomNumberGenerator.new()
var _giro: float = 0.0
var _esterco: float = 0.0
var _guinada: float = 0.0
var _rumo_anterior: float = 0.0
var _pos_anterior := Vector3.ZERO
var _tem_anterior: bool = false
var _v_anterior: float = 0.0
var _a_long: float = 0.0
var _a_lat: float = 0.0
var _freio: float = 0.0
## Mola da carroceria: arfagem (m), mergulho e rolagem (rad), e as velocidades.
var _mola := Vector3.ZERO
var _mola_v := Vector3.ZERO
var _rodado: float = 0.0
var _fase_asfalto: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _relogio: float = 0.0
var _fase_pisca: float = 0.0
var _luzes := Vector3(-1.0, -1.0, -1.0)
var _olhar: float = 0.0
var _olhar_alvo: float = 0.0
var _olhar_em: float = 3.0
var _tronco_lado: float = 0.0


## Instancia o modelo e sorteia quem e quem dentro dele. `rng` e do carro, e
## tudo que sai dele aqui e visual: nada que o banco de provas mede.
func montar(a_modelo: Modelo, rng: RandomNumberGenerator) -> void:
	if _raiz == null or a_modelo != modelo:
		modelo = a_modelo
		_instancia()
	_rng.seed = rng.randi()
	var pintura: Color
	match modelo:
		Modelo.TAXI:
			pintura = AMARELO_TAXI
		Modelo.ONIBUS:
			pintura = PINTURAS_ONIBUS[rng.randi() % PINTURAS_ONIBUS.size()]
		_:
			pintura = PINTURAS[rng.randi() % PINTURAS.size()]
	var camisa := CAMISAS[rng.randi() % CAMISAS.size()]
	var camisa2 := CAMISAS[rng.randi() % CAMISAS.size()]
	var pele := PELES[rng.randi() % PELES.size()]
	for malha in _malhas:
		malha.set_instance_shader_parameter("pintura", pintura)
		malha.set_instance_shader_parameter("camisa", camisa)
		malha.set_instance_shader_parameter("camisa2", camisa2)
		malha.set_instance_shader_parameter("pele", pele)
	# Taxi quase sempre com passageiro; seda as vezes; onibus sempre cheio.
	var passageiro := _no_opcional("Passageiro")
	if passageiro != null:
		passageiro.visible = rng.randf() < (0.7 if modelo == Modelo.TAXI else 0.35)
	_fase_pisca = rng.randf()
	for i in 4:
		_fase_asfalto[i] = rng.randf() * TAU
	fechar_portas(true)
	reiniciar()


## Esquece o movimento anterior. Para depois de qualquer teletransporte: sem
## isto, a reciclagem 400 m para a frente vira uma aceleracao de 24 mil m/s2.
func reiniciar() -> void:
	_tem_anterior = false
	_mola = Vector3.ZERO
	_mola_v = Vector3.ZERO
	_a_long = 0.0
	_a_lat = 0.0
	_guinada = 0.0
	_esterco = 0.0


## A caixa da lataria em repouso, no espaco deste no. E dela que sai o colisor:
## bate onde se ve.
func caixa() -> AABB:
	return (_repouso[_carroceria] * _repouso[_lataria]) * _lataria.get_aabb()


## Escolhe uma porta do lado `lado` (-1 esquerda, 1 direita) e comeca a abrir.
##
## No onibus sao as folhas, dos dois vaos, e o lado nao importa: porta de
## onibus e sempre na calcada. Na direita, que e a calcada do Rio.
func abrir_porta(lado: int) -> void:
	_abrindo = true
	if modelo == Modelo.ONIBUS:
		_porta_ativa = null
		return
	var candidatas: Array[Node3D] = []
	for porta in _portas:
		if signf(_sinal_porta[porta]) == float(signi(lado)):
			candidatas.append(porta)
	# A da frente primeiro: e quem dirige que mais abre porta na rua.
	_porta_ativa = candidatas[0] if candidatas.size() == 1 or _rng.randf() < 0.7 else candidatas[1]


## Fecha o que estiver aberto. `ja` bate a porta sem animar, para reciclar.
func fechar_portas(ja: bool = false) -> void:
	_abrindo = false
	if not ja:
		return
	for porta: Node3D in _angulo:
		_angulo[porta] = 0.0
		_giro_porta[porta] = 0.0
		porta.transform = _repouso[porta]
	_porta_ativa = null


## A porta que abre para fora e o quanto ela esta aberta, de 0 a 1. E o que o
## `TrafficCar` usa para ligar o colisor dela.
func porta_ativa() -> MeshInstance3D:
	return _porta_ativa as MeshInstance3D


func abertura() -> float:
	if _porta_ativa == null:
		return 0.0
	return _angulo[_porta_ativa] / deg_to_rad(PORTA_ABERTA)


## Um passo de pose. `velocidade` em m/s para a frente; `lateral` em m/s para a
## direita; `encostado` liga o pisca-alerta; `seta` e -1, 0 ou 1.
func atualizar(delta: float, velocidade: float, lateral: float, encostado: bool, seta: int) -> void:
	if _raiz == null or delta <= 0.0:
		return
	_relogio += delta
	var i: int = modelo

	# Rumo da pista, para a curva. Guinada positiva gira para a esquerda.
	var frente := -global_basis.z
	var rumo := atan2(-frente.x, -frente.z)
	var curva := 0.0
	var a_long := 0.0
	if _tem_anterior and global_position.distance_to(_pos_anterior) < 10.0:
		curva = clampf(wrapf(rumo - _rumo_anterior, -PI, PI) / delta, -1.5, 1.5)
		a_long = (velocidade - _v_anterior) / delta
	_tem_anterior = true
	_rumo_anterior = rumo
	_pos_anterior = global_position
	_v_anterior = velocidade

	# Guinada da troca de faixa: o nariz aponta para onde o carro vai. Ela e
	# suavizada, e e ela - e nao a lateral, que o `TrafficCar` liga a 1,6 m/s
	# num passo so - que diz quanto o carro esta virando.
	var guinada_max := deg_to_rad(GUINADA_MAX[i])
	var guinada_alvo := clampf(
		-atan2(lateral, maxf(absf(velocidade), 1.5)), -guinada_max, guinada_max
	)
	var guinada_antes := _guinada
	_guinada = lerpf(_guinada, guinada_alvo, 1.0 - exp(-delta / 0.25))
	var giro_total := curva + (_guinada - guinada_antes) / delta
	# Virando para a esquerda, a aceleracao centripeta e para a esquerda, -X.
	var a_lat := -velocidade * giro_total

	# Filtro de 0,15 s: o carro do transito troca de velocidade em degrau, e
	# a mola leria cada degrau como um coice.
	var filtro := 1.0 - exp(-delta / 0.15)
	_a_long = lerpf(_a_long, clampf(a_long, -9.0, 6.0), filtro)
	_a_lat = lerpf(_a_lat, clampf(a_lat, -6.0, 6.0), filtro)
	# A lanterna nao filtra: acende no passo em que o carro freia.
	_freio = 1.0 if a_long < FREIO or (absf(velocidade) < 0.3 and not encostado) else 0.0
	var esterco_alvo := clampf(
		atan(_entre_eixos * giro_total / maxf(absf(velocidade), 1.0)), -0.6, 0.6
	)
	_esterco = lerpf(_esterco, esterco_alvo, 1.0 - exp(-delta / 0.12))
	_giro = wrapf(_giro + velocidade / _raio * delta, 0.0, TAU)
	_rodado += absf(velocidade) * delta

	_suspensao(delta, i, velocidade)
	_anima_portas(delta)
	_posa(delta, i, seta)
	_acende(seta, encostado)


func _suspensao(delta: float, i: int, velocidade: float) -> void:
	# Asfalto: cada roda le a irregularidade no ponto onde esta, e a carroceria
	# filtra pela mola. So anda com o carro andando.
	var rodas: Array[float] = []
	var pisa := clampf(absf(velocidade) / 8.0, 0.0, 1.0)
	for k in 4:
		var d := _rodado + (0.0 if k < 2 else _entre_eixos) + _fase_asfalto[k]
		rodas.append(ASFALTO * pisa * (0.6 * sin(d * 1.7 + _fase_asfalto[k]) + 0.4 * sin(d * 4.3)))
		_rodas[k].position = _repouso[_rodas[k]].origin + Vector3.UP * rodas[k]
	var frente := (rodas[0] + rodas[1]) * 0.5
	var tras := (rodas[2] + rodas[3]) * 0.5
	var esquerda := (rodas[0] + rodas[2]) * 0.5
	var direita := (rodas[1] + rodas[3]) * 0.5

	var alvo := Vector3(
		(frente + tras) * 0.5,
		deg_to_rad(MERGULHO[i]) * _a_long + (frente - tras) / _entre_eixos,
		deg_to_rad(ROLAGEM[i]) * _a_lat + (direita - esquerda) / _bitola
	)
	var w := TAU * FREQUENCIA[i]
	var zeta := AMORTECIMENTO[i]
	_mola_v += (w * w * (alvo - _mola) - 2.0 * zeta * w * _mola_v) * delta
	_mola += _mola_v * delta
	_mola.y = clampf(_mola.y, -0.08, 0.08)
	_mola.z = clampf(_mola.z, -0.1, 0.1)

	# Guinada em volta do eixo traseiro, que e como carro vira.
	var pivo := Vector3(0.0, 0.0, _eixo_traseiro)
	var guina := Basis(Vector3.UP, _guinada)
	_raiz.transform = Transform3D(guina, pivo - guina * pivo)
	# Mergulho positivo levanta o nariz (-Z); rolagem positiva levanta a
	# direita (+X), deitando a carroceria para a esquerda.
	var repouso := _repouso[_carroceria]
	_carroceria.transform = Transform3D(
		Basis.from_euler(Vector3(_mola.y, 0.0, _mola.z)), repouso.origin + Vector3.UP * _mola.x
	)

	for k in 4:
		var roda := _rodas[k]
		var esterca := _esterco if k < 2 else 0.0
		# Rodando para a frente, o topo da roda vai para -Z: rotacao negativa em X.
		roda.basis = Basis(Vector3.UP, esterca) * Basis(Vector3.RIGHT, -_giro)


func _anima_portas(delta: float) -> void:
	for porta: Node3D in _angulo:
		var folha := _folhas.has(porta)
		var abre := _abrindo and (folha or porta == _porta_ativa)
		var maximo := deg_to_rad(FOLHA_ABERTA if folha else PORTA_ABERTA)
		var alvo := maximo if abre else 0.0
		var angulo := _angulo[porta]
		var giro := _giro_porta[porta]
		# Porta de carro e mola fraca: abre passando um pouco do ponto e volta,
		# o tranco do limitador. Folha de onibus e pneumatica, sem tranco.
		var k := 30.0 if folha else (38.0 if abre else 70.0)
		var c := 11.0 if folha else (5.5 if abre else 3.0)
		giro += (k * (alvo - angulo) - c * giro) * delta
		angulo += giro * delta
		if angulo <= 0.0:
			# Bateu. A porta de carro balanca a carroceria quando fecha.
			if not folha and giro < -1.5:
				_mola_v.x -= 0.05
				_mola_v.z += 0.08 * _sinal_porta[porta]
			angulo = 0.0
			giro = 0.0
		angulo = minf(angulo, maximo * 1.08)
		_angulo[porta] = angulo
		_giro_porta[porta] = giro
		var repouso := _repouso[porta]
		porta.transform = Transform3D(
			Basis(Vector3.UP, angulo * _sinal_porta[porta]) * repouso.basis, repouso.origin
		)


func _posa(delta: float, i: int, seta: int) -> void:
	var volante := -_esterco * DIRECAO[i]
	_volante.basis = Basis(_eixo_volante, clampf(volante, -2.2, 2.2))

	# Quem dirige e jogado pela inercia: para a frente na freada, para fora na
	# curva. Positivo em Z deita o tronco para a esquerda.
	var tronco_alvo := clampf(_a_lat * deg_to_rad(1.6), -0.14, 0.14)
	_tronco_lado = lerpf(_tronco_lado, tronco_alvo, 0.2)
	var porta_motorista := _porta_ativa != null and _porta_ativa.name == "Porta_DE"
	var vira := 0.4 if porta_motorista and _angulo[_porta_ativa] > 0.3 else 0.0
	_tronco.rotation = Vector3(
		clampf(_a_long * deg_to_rad(1.2), -0.12, 0.08) - _mola.y, vira, _tronco_lado - _mola.z
	)

	# Para onde olha: o espelho do lado da seta, a porta que abre, ou uma
	# olhadela de vez em quando - motorista parado como estatua le como boneco.
	_olhar_em -= delta
	if seta != 0:
		_olhar_alvo = -0.6 * float(seta)
	elif porta_motorista:
		_olhar_alvo = 0.5
	elif _olhar_em <= 0.0:
		if is_zero_approx(_olhar_alvo):
			_olhar_alvo = _rng.randf_range(-0.7, 0.7)
			_olhar_em = _rng.randf_range(0.6, 1.4)
		else:
			_olhar_alvo = 0.0
			_olhar_em = _rng.randf_range(2.5, 7.0)
	_olhar = lerpf(_olhar, _olhar_alvo, 0.12)
	_cabeca.rotation = Vector3(-_tronco.rotation.x, _olhar - _tronco.rotation.y, 0.0)

	var base := _carroceria.global_basis
	for k in 2:
		var braco: Array = _bracos[k]
		var mao: Node3D = braco[2]
		var alvo := _volante.global_transform * _pegas[k]
		var sinal := -1.0 if k == 0 else 1.0
		# Cotovelo para fora e para baixo, como quem segura um volante.
		var polo := base * Vector3(sinal, -1.0, 0.3)
		Ik.dois_ossos(
			braco[0], braco[1], _repouso[braco[1]].origin, _repouso[mao].origin, alvo, polo
		)
		mao.global_basis = _volante.global_basis


func _acende(seta: int, encostado: bool) -> void:
	var aceso := fposmod(_relogio * PISCA + _fase_pisca, 1.0) < 0.5
	var esquerda := aceso and (encostado or seta < 0)
	var direita := aceso and (encostado or seta > 0)
	var luzes := Vector3(_freio, 1.0 if esquerda else 0.0, 1.0 if direita else 0.0)
	# So a lataria tem luz, e so quando muda: sao vinte carros, e o parametro
	# por instancia e uma chamada ao servidor de renderizacao por no.
	if luzes != _luzes:
		_luzes = luzes
		_lataria.set_instance_shader_parameter("luzes", luzes)


func _instancia() -> void:
	if _raiz != null:
		_raiz.free()
	_malhas.clear()
	_repouso.clear()
	_rodas.clear()
	_bracos.clear()
	_pegas.clear()
	_portas.clear()
	_folhas.clear()
	_angulo.clear()
	_giro_porta.clear()
	_sinal_porta.clear()
	_porta_ativa = null
	_luzes = Vector3(-1.0, -1.0, -1.0)

	_raiz = molde(modelo).instantiate() as Node3D
	add_child(_raiz)
	_prepara(_raiz)
	_carroceria = _no("Carroceria")
	_lataria = _no("Lataria") as MeshInstance3D

	for nome: String in ["Roda_DE", "Roda_DD", "Roda_TE", "Roda_TD"]:
		_rodas.append(_no(nome))
	_raio = (_rodas[0] as MeshInstance3D).get_aabb().size.y * 0.5
	_entre_eixos = _rodas[2].position.z - _rodas[0].position.z
	_bitola = _rodas[1].position.x - _rodas[0].position.x
	_eixo_traseiro = _rodas[2].position.z

	_volante = _no("Volante")
	# O volante gira em volta da reta ate a coluna, e nao de um eixo fixo: no
	# carro ele e quase em pe, no onibus quase deitado.
	_eixo_volante = _no("Coluna").position.normalized()
	_tronco = _no("Tronco")
	_cabeca = _no("Cabeca")
	for lado: String in ["E", "D"]:
		var mao := _no("Mao_" + lado)
		_bracos.append([_no("Braco_" + lado), _no("Antebraco_" + lado), mao])
		_pegas.append(_repouso[_volante].affine_inverse() * _na_carroceria(mao).origin)

	for filho in _carroceria.get_children():
		var no := filho as Node3D
		if no.name.begins_with("Porta_"):
			_portas.append(no)
			# Para fora: a ponta de tras da porta vai para o lado dela.
			_sinal_porta[no] = signf(no.position.x)
		elif no.name.begins_with("Folha_"):
			_folhas.append(no)
			# Para dentro: a ponta da folha vai para o meio do onibus. Se a
			# folha se estende para tras (+Z), girar para dentro e girar no
			# sentido de levar +Z para -X, que e rotacao negativa em Y.
			var ponta := (no as MeshInstance3D).get_aabb().get_center().z
			_sinal_porta[no] = -signf(no.position.x) * signf(ponta)
		else:
			continue
		_angulo[no] = 0.0
		_giro_porta[no] = 0.0
	# A dianteira primeiro: `abrir_porta` prefere ela.
	_portas.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.position.z < b.position.z)


func _prepara(no: Node) -> void:
	if no is Node3D:
		_repouso[no as Node3D] = (no as Node3D).transform
	if no is MeshInstance3D:
		var malha := no as MeshInstance3D
		_malhas.append(malha)
		for s in malha.mesh.get_surface_count():
			var vidro := malha.mesh.surface_get_material(s).resource_name == "vidro"
			malha.set_surface_override_material(s, _vidro() if vidro else _opaco())
	for filho in no.get_children():
		_prepara(filho)


## Transformacao de repouso de `no` no espaco da carroceria. Somada pelas
## transformacoes de repouso, e nao lida do global: o carro pode ainda nem
## estar na arvore quando monta.
func _na_carroceria(no: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var atual: Node3D = no
	while atual != _carroceria:
		t = _repouso[atual] * t
		atual = atual.get_parent() as Node3D
	return t


func _no(nome: String) -> Node3D:
	var achado := _no_opcional(nome)
	assert(achado != null, "carros.glb: %s sem o no %s" % [NOS[modelo], nome])
	return achado


func _no_opcional(nome: String) -> Node3D:
	return _raiz.find_child(nome, true, false) as Node3D


## O modelo pronto para instanciar. O `.glb` e aberto uma vez so; cada modelo
## vira uma cena propria, com os nomes limpos e a origem no lugar.
static func molde(qual: Modelo) -> PackedScene:
	if _moldes.is_empty():
		var cena := CENA.instantiate()
		for nome in NOS:
			var no := cena.find_child(nome, true, false) as Node3D
			assert(no != null, "carros.glb sem o modelo %s" % nome)
			no.get_parent().remove_child(no)
			# Lado a lado no `.blend` so para olhar; aqui cada um na origem.
			no.transform = Transform3D.IDENTITY
			_adota(no, no)
			var pacote := PackedScene.new()
			pacote.pack(no)
			_moldes.append(pacote)
			no.free()
		cena.free()
	return _moldes[qual]


## Poe `dono` como owner de toda a arvore e tira o sufixo que o Blender cola em
## nome repetido: os cinco modelos tem uma `Porta_DE`, e no `.blend` so a
## primeira fica com o nome limpo.
static func _adota(no: Node, dono: Node) -> void:
	if no != dono:
		no.owner = dono
		no.name = _sufixo.sub(no.name, "")
	for filho in no.get_children():
		_adota(filho, dono)


static func _opaco() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = SHADER
		_material.set_shader_parameter("albedo", ALBEDO)
		_material.set_shader_parameter("mascara", MASCARA)
		_material.set_shader_parameter("pintura_fabrica", PINTURA_FABRICA)
		_material.set_shader_parameter("pele_fabrica", PELE_FABRICA)
		_material.set_shader_parameter("camisa_fabrica", CAMISA_FABRICA)
		_material.set_shader_parameter("camisa2_fabrica", CAMISA2_FABRICA)
	return _material


static func _vidro() -> ShaderMaterial:
	if _material_vidro == null:
		_material_vidro = ShaderMaterial.new()
		_material_vidro.shader = SHADER_VIDRO
	return _material_vidro
