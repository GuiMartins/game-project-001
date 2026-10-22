extends SceneTree
## Folhas de pose do carro, para dar de referencia ao Google Flow.
##
##     python tools/dev.py boneco carro
##
## O `Carro` do proprio jogo, em cinza sobre verde, um modelo por vez (hatch,
## seda, SUV, taxi, onibus, bau e van), com o que `MIGRACAO_2D.md` pede para
## cada um:
##
## - `<modelo>_base`: uma linha por angulo e duas colunas, sem e com
##   passageiro (so seda, taxi e onibus tem; nos outros, uma coluna);
## - `<modelo>_porta_N`: cada porta do lado da calcada (a +X, a que fica virada
##   para a camera de lado), em tres angulos e cinco quadros: abrindo em
##   quatro tempos e a porta amassada. O onibus tem as folhas da porta, que
##   dobram juntas, e por isso nao tem o quadro de amassada.
##
## A pintura, a roupa e a pele saem em cinza pelos mesmos parametros que o jogo
## sorteia: o que o desenho tem de cor-chave (pintura) e de luz (lanterna,
## farol) continua onde o jogo o poe.
##
## A escala e a mesma em todos os modelos (`PPM`) e so a celula muda, que
## acompanha o carro: o onibus tem 12 m, e o hatch, 4.
##
## Roda com tela: o renderizador do `--headless` e um dummy, e sai tudo preto.

const Cena := preload("res://arte/boneco_cena.gd")

const PASTA: String = "res://arte/flow/referencia/carro/"
## Menos que a pessoa e a moto: o onibus, de 12 m, ja passa de 1500 px de
## largura aqui, e o Flow nao ganha nada com mais.
const PPM: float = 128.0
## Folga em volta do carro na celula, em metros: a porta aberta, o retrovisor e o
## chao.
const FOLGA: float = Cena.FOLGA
## A camera fica longe o bastante para o onibus de lado a lado nao ficar para
## tras do plano de corte.
const DISTANCIA: float = 24.0
const SEMENTE: int = 20260831

const TOM_PINTURA := Color(0.62, 0.63, 0.66)
const TOM_CAMISA := Color(0.80, 0.81, 0.84)
const TOM_PELE := Color(0.82, 0.82, 0.84)
## O giro e em volta de Y: 0 olha para -Z (o carro visto de tras), 180 de
## frente, e -90 o lado +X, o da porta da calcada, virado para a camera.
const ANGULOS_CINCO: Array[Array] = [
	["frente", 180.0],
	["tres_quartos_frente", -135.0],
	["lado", -90.0],
	["tres_quartos_costas", -45.0],
	["costas", 0.0],
]
## O onibus nao espelha: a porta e so do lado direito, e espelhada trocaria de
## lado. As cinco linhas padrao saem do lado sem porta (+90), o que o espelho
## nao estraga, e o lado da porta ganha duas linhas proprias.
const ANGULOS_ONIBUS: Array[Array] = [
	["frente", 180.0],
	["tres_quartos_frente", 135.0],
	["lado", 90.0],
	["tres_quartos_costas", 45.0],
	["costas", 0.0],
	["lado_da_porta", -90.0],
	["tres_quartos_da_porta", -135.0],
]
const ANGULOS_PORTA: Array[Array] = [
	["lado", -90.0],
	["tres_quartos_frente", -135.0],
	["tres_quartos_costas", -45.0],
]
## Quanto da abertura de cada quadro da porta, e o quadro da amassada no fim.
const ABERTURAS: Array[float] = [0.25, 0.5, 0.75, 1.0]

var _cena := Cena.new()
var _giro: Node3D
var _carro: Carro
var _celula := Vector2.ZERO
var _centro: float = 0.0


func _initialize() -> void:
	root.add_child(_cena)
	_cena.monta(root)
	_giro = Node3D.new()
	_cena.vp.add_child(_giro)
	_roda.call_deferred()


func _roda() -> void:
	for modelo: int in Carro.Modelo.values():
		await process_frame
		_monta(modelo as Carro.Modelo)
		var nome: String = Carro.NOS[modelo].to_lower()
		await _faz_base(nome)
		await _faz_portas(nome)
	quit()


## Monta o carro `modelo` no lugar do anterior, parado, em cinza e centrado.
func _monta(modelo: Carro.Modelo) -> void:
	if _carro != null:
		_carro.free()
	_carro = Carro.new()
	_giro.add_child(_carro)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEMENTE
	_carro.montar(modelo, rng)
	for malha in _carro._malhas:
		malha.set_instance_shader_parameter("pintura", TOM_PINTURA)
		malha.set_instance_shader_parameter("camisa", TOM_CAMISA)
		malha.set_instance_shader_parameter("camisa2", TOM_CAMISA)
		malha.set_instance_shader_parameter("pele", TOM_PELE)
	# O farol de noite e luz do jogo, e a bancada ja tem a dela.
	_carro._farol.visible = false
	var caixa := _cena.caixa_de(_carro)
	# O carro gira em volta do meio dele, e nao da origem do modelo: sem isto a
	# celula teria de ser larga o bastante para a volta do onibus.
	_carro.position = Vector3(
		-(caixa.position.x + caixa.size.x * 0.5), 0.0, -(caixa.position.z + caixa.size.z * 0.5)
	)
	var diagonal := Vector2(caixa.size.x, caixa.size.z).length()
	_celula = Vector2(diagonal + 2.0 * FOLGA, caixa.end.y + 2.0 * FOLGA)
	_centro = _celula.y * 0.5 - FOLGA


func _faz_base(nome: String) -> void:
	var angulos: Array = ANGULOS_ONIBUS if _carro.modelo == Carro.Modelo.ONIBUS else ANGULOS_CINCO
	# So seda, taxi e onibus tem gente alem do motorista; nos outros a coluna
	# "com passageiro" seria igual a "sem", e a folha sai com uma coluna so.
	var passageiro := _carro._no_opcional("Passageiro")
	if passageiro == null:
		passageiro = _carro._no_opcional("Passageiros")
	var colunas := 1 if passageiro == null else 2
	var posa := func(linha: int, coluna: int) -> void:
		_giro.rotation.y = deg_to_rad(angulos[linha][1])
		if passageiro != null:
			passageiro.visible = coluna == 1
	await _cena.faz_folha(
		"%s_base" % nome, PASTA, colunas, angulos.size(), _celula, _centro, PPM, posa, DISTANCIA
	)


## Uma folha por porta do lado +X, ou uma so com as folhas do onibus.
func _faz_portas(nome: String) -> void:
	var onibus := _carro.modelo == Carro.Modelo.ONIBUS
	var portas: Array[Node3D] = []
	if onibus:
		portas = _carro._folhas.duplicate()
	else:
		for porta in _carro._portas:
			if _carro._sinal_porta[porta] > 0.0:
				portas.append(porta)
	if onibus:
		await _faz_porta("%s_porta" % nome, portas, true)
		return
	for i in portas.size():
		await _faz_porta("%s_porta_%d" % [nome, i + 1], [portas[i]] as Array[Node3D], false)


func _faz_porta(nome: String, portas: Array[Node3D], folhas: bool) -> void:
	var colunas := ABERTURAS.size() + (0 if folhas else 1)
	var posa := func(linha: int, coluna: int) -> void:
		_giro.rotation.y = deg_to_rad(ANGULOS_PORTA[linha][1])
		_abre(portas, coluna, folhas)
	await _cena.faz_folha(
		nome, PASTA, colunas, ANGULOS_PORTA.size(), _celula, _centro, PPM, posa, DISTANCIA
	)
	# De volta ao fechado para a folha da porta seguinte.
	_abre(portas, 0, folhas, true)


## Abre `portas` no quadro `coluna`: os quatro tempos da abertura e, no
## quinto, a porta amassada pela pancada, que passa do batente. `fecha` volta
## tudo ao fechado.
func _abre(portas: Array[Node3D], coluna: int, folhas: bool, fecha: bool = false) -> void:
	var c := _carro
	c._abrindo = not fecha
	c._porta_amassada = not fecha and not folhas and coluna == ABERTURAS.size()
	c._porta_ativa = null if folhas or fecha else portas[0]
	for porta: Node3D in c._angulo:
		c._angulo[porta] = 0.0
		c._giro_porta[porta] = 0.0
	if not fecha:
		for porta in portas:
			var maximo := Carro.FOLHA_ABERTA if folhas else Carro.PORTA_ABERTA
			var fracao := 1.0
			if c._porta_amassada:
				maximo = Carro.PORTA_AMASSADA
			else:
				fracao = ABERTURAS[coluna]
			c._angulo[porta] = deg_to_rad(maximo) * fracao
	# Delta zero: so aplica o angulo, sem andar a mola da porta.
	c._anima_portas(0.0)
