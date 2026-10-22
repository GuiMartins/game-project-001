extends SceneTree
## Folhas de pose da moto e do piloto, para dar de referencia ao Google Flow.
##
##     python tools/dev.py boneco moto
##
## O `Entregador` do proprio jogo, posado pelo mesmo codigo que o anima, em
## manequim cinza sobre verde. As folhas sao as da tabela de `MIGRACAO_2D.md`
## (Moto e piloto), uma por moto: CG, XRE e PCX saem do mesmo roteiro, e o que
## muda de uma para outra vem do modelo, e nao de um `if` aqui.
##
## Tres linhas de angulo (costas, tres quartos de costas e lado, para a
## direita; o esquerdo sai por espelho), exceto o tombo, que so existe de costas,
## e a moto caida, que mostra os cinco angulos de um desenho so.
##
## Roda com tela: o renderizador do `--headless` e um dummy, e sai tudo preto.

const Cena := preload("res://arte/boneco_cena.gd")

const PASTA: String = "res://arte/flow/referencia/moto/"
const PPM: float = Cena.PPM_PESSOA
## A moto tem 2,1 m e o piloto chega a 1,95 m na XRE, que e a mais alta; 0,2 m
## abaixo do pe guardam o chao, e 0,5 m de lado a mais do que a moto, a
## inclinacao de 28 graus.
const CELULA := Vector2(2.7, 2.4)
const CENTRO: float = 1.0
## A moto deitada e o piloto caido so tem uns 0,8 m de altura: celula baixa e
## larga, com o centro rente ao chao. O piloto voando precisa do contrario, ar
## em volta para a cambalhota, e e a celula do pedestre voando.
const CELULA_CAIDA := Vector2(3.2, 1.4)
const CENTRO_CAIDA: float = 0.5
const CELULA_VOO := Vector2(2.8, 2.8)
const CENTRO_VOO: float = 1.6
const CELULA_CAIDO := Vector2(2.6, 1.4)
const CENTRO_CAIDO: float = 0.58
## Quanto a moto tombada se afasta, de lado, do ponto em que o `Entregador` a
## deixa: ele a gira em volta do pe (`QUEDA_PIVO`), e ela deitada ocupa de 0,3 a
## 1,3 m para o lado do tombo. Sem recentrar, ela sai da celula.
const RECENTRA_TOMBO: float = 0.6
## Cinzas: a moto escura e o piloto claro se separam, e a cabeca (o capacete)
## ainda mais clara que o corpo mostra para onde ele olha. A bag, mais
## escura, e o que diz que o angulo e o de costas.
const TOM_MOTO := Color(0.46, 0.48, 0.52)
const TOM_RODA := Color(0.20, 0.21, 0.23)
const TOM_PILOTO := Color(0.80, 0.81, 0.84)
const TOM_CABECA := Color(0.92, 0.92, 0.94)
const TOM_BAG := Color(0.60, 0.62, 0.66)

## O giro e em volta de Y: 0 olha para -Z (a moto vista de tras) e -90 para a
## direita. O mesmo sentido das folhas do pedestre.
const ANGULOS_TRES: Array[Array] = [
	["costas", 0.0],
	["tres_quartos_costas", -45.0],
	["lado", -90.0],
]
const ANGULOS_COSTAS: Array[Array] = [["costas", 0.0]]
const ANGULOS_CINCO: Array[Array] = [
	["frente", 180.0],
	["tres_quartos_frente", -135.0],
	["lado", -90.0],
	["tres_quartos_costas", -45.0],
	["costas", 0.0],
]
## O piloto solto voa para a direita, para longe da camera e em diagonal para
## perto, como o pedestre.
const ANGULOS_VOO: Array[Array] = [
	["lado", -90.0],
	["tres_quartos_costas", -45.0],
	["costas", 0.0],
	["tres_quartos_frente", -135.0],
]

## Inclinacao da moto na curva, em graus, positiva para a direita: o curso da
## `PlayerBike` (28) e o meio do caminho.
const INCLINACOES: Array[float] = [-28.0, -11.0, 0.0, 11.0, 28.0]
## Parado e lento: pe no chao, guidao para a esquerda, para a direita e a
## empinada. A empinada nao existe no modelo 3D (so no sprite); aqui e a moto
## inteira girada em volta do pneu de tras, 30 graus.
const EMPINADA: float = 30.0
## O tempo do soco: o da hitbox do jogador (`punch_*` do `PlayerBike`).
const SOCO_PREPARO: float = 0.2
const SOCO_ATIVO: float = 0.2
const SOCO_TOTAL: float = 0.7
## Instantes dos tres quadros: armado, braco esticado e recolhendo.
const TEMPOS_SOCO: Array[float] = [0.2, 0.36, 0.55]
## Golpe recebido: quanto depois da pancada sai cada quadro, em passos de 1/60 s.
const PASSOS_GOLPE: Array[int] = [5, 14]
## Quanto a moto ja tombou em cada quadro do tombo (0 em pe, 1 deitada).
const QUEDAS: Array[float] = [0.25, 0.5, 0.75, 1.0]
## Quadros do piloto voando: a cambalhota dividida em oito.
const QUADROS_VOO: int = 8

const MOTOS: PackedStringArray = ["cg", "xre", "pcx"]

var _cena := Cena.new()
var _visual: Node3D
var _ent: Entregador
## Em que moto estamos e a folha em andamento, para a pose saber o que fazer.
var _folha: String = ""


func _initialize() -> void:
	root.add_child(_cena)
	_cena.monta(root)
	_visual = Node3D.new()
	_cena.vp.add_child(_visual)
	_ent = Entregador.new()
	_visual.add_child(_ent)
	_roda.call_deferred()


func _roda() -> void:
	# O `_ready` do ator, que monta as malhas, so roda depois do `_initialize`.
	await process_frame
	for i in MOTOS.size():
		_ent.trocar_modelo(i)
		_prepara_ator()
		var m: String = MOTOS[i]
		await _faz("%s_pilotando" % m, "pilotando", 5, ANGULOS_TRES)
		await _faz("%s_parado" % m, "parado", 4, ANGULOS_TRES)
		await _faz("%s_combate" % m, "combate", 6, ANGULOS_TRES)
		await _faz("%s_golpe" % m, "golpe", 4, ANGULOS_TRES)
		await _faz("%s_tombo" % m, "tombo", 4, ANGULOS_COSTAS)
		await _faz("%s_caida" % m, "caida", 1, ANGULOS_CINCO, CELULA_CAIDA, CENTRO_CAIDA)
		if i == 0:
			# O piloto solto e o mesmo nas tres motos (2D15): sai uma vez so.
			await _faz("piloto_voando", "voando", QUADROS_VOO, ANGULOS_VOO, CELULA_VOO, CENTRO_VOO)
			await _faz("piloto_caido", "caido", 3, ANGULOS_VOO, CELULA_CAIDO, CENTRO_CAIDO)
	quit()


func _faz(
	nome: String,
	folha: String,
	colunas: int,
	angulos: Array,
	celula: Vector2 = CELULA,
	centro: float = CENTRO
) -> void:
	_folha = folha
	var posa := func(linha: int, coluna: int) -> void:
		_zera()
		_posa(coluna, deg_to_rad(angulos[linha][1]))
		_ent._posa()
	await _cena.faz_folha(nome, PASTA, colunas, angulos.size(), celula, centro, PPM, posa)


## O que vale uma vez por moto: a cor, e a moto sem a bancada do jogo em volta.
func _prepara_ator() -> void:
	# O ator ainda e quem decide a cadencia e o sprite; aqui e a pose que manda.
	_ent.sprite = false
	# A `Cadencia` devolve o ator ao lugar dele no `Visual` a cada quadro, e
	# desfaria a empinada, que gira o ator inteiro em volta do pneu.
	_ent.cadencia.set_process(false)
	_pinta(_ent._modelo)


## Cinza por peca, e nao um so: sem isso o piloto sumia dentro da moto.
func _pinta(no: Node) -> void:
	if no is Label3D:
		# O texto da placa vai por codigo (2D16): o desenho a deixa em branco.
		(no as Label3D).visible = false
	if no is MeshInstance3D:
		var malha := no as MeshInstance3D
		var tom := TOM_MOTO
		if _e_filho_de(no, "Piloto"):
			tom = TOM_PILOTO
			if no.name == "Cabeca":
				tom = TOM_CABECA
			elif no.name == "Bag":
				tom = TOM_BAG
		elif (
			String(no.name).begins_with("Roda")
			or String(no.name).begins_with("Raios")
			or no.name == "Disco"
		):
			tom = TOM_RODA
		_cena.pinta(malha, tom)
	for filho in no.get_children():
		_pinta(filho)


func _e_filho_de(no: Node, nome: String) -> bool:
	var pai := no.get_parent()
	while pai != null:
		if pai.name == nome:
			return true
		pai = pai.get_parent()
	return false


## A moto parada e reta, antes de cada quadro: o que o quadro anterior deixou
## (inclinacao, soco, queda, voo) nao pode vazar para o seguinte.
func _zera() -> void:
	var e := _ent
	e._pe = 0.0
	e._esterco = 0.0
	# Andando: o piloto agachado, joelho fechado e peso a frente.
	e._aperto = 1.0
	e._deitado = 0.8
	e._inclinacao = 0.0
	e._empina = 0.0
	e._queda = 0.0
	e._girado = 0.0
	e._lado_queda = 1.0
	e._giro_queda = 0.0
	e._voando = false
	e._voo_t = 0.0
	e._no_chao_t = -1.0
	e._soco_t = -1.0
	e._soco_lado = 1
	e._massa = Vector3.ZERO
	e._massa_v = Vector3.ZERO
	e._pescoco = Vector2.ZERO
	e._pescoco_v = Vector2.ZERO
	e._bamboleio = 0.0
	e._susp = Vector2.ZERO
	e._susp_v = Vector2.ZERO
	e._treme = Vector2.ZERO
	e.position = Vector3.ZERO
	e.transform = Transform3D.IDENTITY
	_visual.transform = Transform3D.IDENTITY
	e._moto.visible = true
	e._piloto.visible = true


## A pose do quadro `coluna`, com a moto girada `giro` em volta de Y.
func _posa(coluna: int, giro: float) -> void:
	var inclinacao := 0.0
	match _folha:
		"pilotando":
			inclinacao = deg_to_rad(INCLINACOES[coluna])
			# O guidao acompanha a curva: para o lado em que a moto cai.
			var fracao := INCLINACOES[coluna] / INCLINACOES[INCLINACOES.size() - 1]
			_ent._esterco = fracao * Entregador.ESTERCO_RAPIDO
		"parado":
			_parado(coluna)
		"combate":
			_combate(coluna)
		"golpe":
			_golpe(coluna)
		"tombo":
			_ent._queda = QUEDAS[coluna]
			_ent._girado = 0.0
			_ent.position.x = -RECENTRA_TOMBO * QUEDAS[coluna]
		"caida":
			_caida(giro)
		"voando":
			_voa(coluna)
		"caido":
			_cai(coluna)
	_ent._inclinacao = inclinacao
	# A inclinacao e do `Visual` do corpo: em volta do eixo da moto, e por
	# dentro do giro. Positiva para a direita, rotacao negativa em Z.
	_visual.basis = Basis(Vector3.UP, giro) * Basis(Vector3.BACK, -inclinacao)


## Pe no chao, guidao esquerda, guidao direita e a empinada.
func _parado(coluna: int) -> void:
	var e := _ent
	e._pe = 1.0
	e._aperto = 0.0
	e._deitado = 0.0
	match coluna:
		1:
			e._esterco = -Entregador.ESTERCO_DEVAGAR
		2:
			e._esterco = Entregador.ESTERCO_DEVAGAR
		3:
			e._pe = 0.0
			e._aperto = 1.0
			# Em volta do pneu de tras: a frente sobe e o pneu continua no chao.
			var tras := e._no_relativo(e._rodas[0], e._moto)
			var ponto := Vector3(0.0, 0.0, tras.z)
			var giro := Basis(Vector3.RIGHT, deg_to_rad(EMPINADA))
			e.transform = Transform3D(giro, ponto - giro * ponto)


## Soco: armado, braco esticado e recolhendo, os tres para a esquerda e para a
## direita. As tres primeiras colunas sao as da direita (+1).
func _combate(coluna: int) -> void:
	var e := _ent
	e._soco_lado = 1 if coluna < 3 else -1
	e._soco_preparo = SOCO_PREPARO
	e._soco_ativo = SOCO_ATIVO
	e._soco_total = SOCO_TOTAL
	e._soco_t = TEMPOS_SOCO[coluna % 3]


## Levou um soco: dois instantes depois da pancada, para a direita e para a
## esquerda. A mola do tronco e a do pescoco andam a 60 Hz, como no jogo.
func _golpe(coluna: int) -> void:
	var e := _ent
	var lado := 1 if coluna < 2 else -1
	e.levar_golpe(lado)
	var dt := 1.0 / 60.0
	for i in PASSOS_GOLPE[coluna % 2]:
		e._corpo(dt)
		e._bamboleio *= exp(-dt / Entregador.BAMBOLEIO_TEMPO)
		e._relogio += dt


## A moto deitada de vez, sem piloto, vista de cada um dos cinco angulos.
func _caida(_giro: float) -> void:
	var e := _ent
	e._queda = 1.0
	e._girado = 1.0
	e._piloto.visible = false
	e.position.x = -RECENTRA_TOMBO


## O piloto no ar, sem a moto: cambalhota para a frente, bracos e pernas soltos.
func _voa(coluna: int) -> void:
	var e := _ent
	e._moto.visible = false
	e._voando = true
	e._voo_t = 0.3 + 0.08 * float(coluna)
	e._no_chao_t = -1.0
	var giro := Basis(Vector3.RIGHT, -TAU * float(coluna) / float(QUADROS_VOO))
	e._voo = Transform3D(giro, Vector3(0.0, 1.6, 0.0))


## O piloto deitado de bruços no asfalto, cabeca para onde ia. O jogo so tem
## esta pose; as tres colunas viram o corpo um pouco para cada lado.
func _cai(coluna: int) -> void:
	var e := _ent
	e._moto.visible = false
	e._voando = true
	e._voo_t = 1.0
	e._no_chao_t = 1.0
	var viragem := [0.0, 25.0, -25.0][coluna] as float
	var giro := Basis(Vector3.UP, deg_to_rad(viragem)) * Basis(Vector3.RIGHT, -PI * 0.5)
	e._voo = Transform3D(giro, Vector3(0.0, 0.3, 0.0))
