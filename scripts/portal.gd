class_name Portal
extends RefCounted
## O que passa por cima da pista nos cruzamentos (V18): o semaforo suspenso no
## braco e o portico da placa verde, os dois das referencias (`02_praca_maua`,
## `03_viaduto`, `04_vertical`, `video_01/t2.0s` e `t3.0s`).
##
## **So cenario.** Semaforo com logica saiu do prototipo de proposito
## (`PROTOTIPO.md`, "O que nao esta aqui"): o foco da avenida fica sempre no
## verde, como o do poste de esquina. O que ele faz e o mesmo do braco do
## poste da V15: passar por cima da camera, que e um referencial de velocidade
## que o chao nao da.
##
## Os dois ficam do lado direito, na mao de quem vem, e o braco atravessa por
## cima das faixas. O no de cada um tem a base da pista naquele ponto: X para a
## direita, Z para tras, de onde vem o jogador.

## Do eixo da avenida ao pe do poste, do lado direito: meio metro depois do
## meio-fio, na linha do poste de luz.
const LATERAL: float = RoadTrack.LANE_WIDTH * RoadTrack.LANE_COUNT * 0.5 + 0.9
## A altura do braco do semaforo. Acima do onibus (3,2 m) com folga, e baixo o
## bastante para riscar o topo da tela quando a camera passa por baixo.
const BRACO_SEMAFORO: float = 6.0
## Meio metro alem do eixo, para continuar cobrindo o corredor quando a
## largura das faixas mudar junto com a distancia do poste ao centro.
const BRACO_COMPRIMENTO: float = LATERAL + 0.5
## O portico da placa e mais alto: a placa pendurada embaixo dele tem 2,6 m.
const BRACO_PLACA: float = 7.4
const PLACA := Vector2(5.4, 2.6)
## A faixa azul de baixo, como na referencia: o destino da saida.
const FAIXA_AZUL: float = 0.85
const VERDE := Color(0.05, 0.42, 0.22)
const AZUL := Color(0.08, 0.24, 0.62)
## A chapa de advertencia: o mesmo amarelo da placa de curva do `mobiliario.py`.
const AMARELO := Color(0.95, 0.75, 0.10)
## Nomes de via e de bairro do Rio: lugar e livre, marca nao (V18). Uma placa
## por cruzamento alternado, na ordem, e a lista da a volta.
const DESTINOS: Array[Array] = [
	["Av. Rio Branco", "Centro", "Pça. Mauá"],
	["Linha Vermelha", "Av. Brasil", "Rodoviária"],
	["Av. Pres. Vargas", "Candelária", "Aterro"],
	["Túnel Rebouças", "Lagoa", "Zona Sul"],
]

## O colisor do poste: so o fuste, como o do poste de luz. Braco e placa
## ficam acima de qualquer cabeca.
const COLISOR := Vector3(0.4, 6.0, 0.4)


## O semaforo suspenso com o pe em `onde`: poste, braco por cima da pista e
## dois focos verdes encarando quem vem. `mat` sao os materiais do semaforo da
## `Cidade`, os mesmos do de esquina.
static func semaforo(onde: Transform3D, mat: Dictionary) -> Node3D:
	var raiz := _poste(onde, BRACO_SEMAFORO, mat)
	for k in 2:
		var foco := Greybox.box(Vector3(0.36, 1.0, 0.26), Color.BLACK)
		foco.material_override = mat["caixa"]
		raiz.add_child(foco)
		# Pendurado no braco: um sobre a faixa da direita, outro mais para o
		# meio, como o portal do video.
		foco.position = Vector3(-3.0 - k * 4.5, BRACO_SEMAFORO - 0.65, 0.0)
		var cores: Array[String] = ["vermelho", "amarelo", "verde"]
		for i in cores.size():
			var luz := Greybox.box(Vector3(0.22, 0.22, 0.06), Color.BLACK)
			luz.material_override = mat[cores[i] + ("_aceso" if cores[i] == "verde" else "")]
			foco.add_child(luz)
			# +Z do no e de onde vem o jogador: a luz fica na face de la.
			luz.position = Vector3(0.0, 0.3 - 0.3 * float(i), 0.14)
	return raiz


## O portico com a placa verde e azul pendurada sobre as faixas da direita.
static func placa(onde: Transform3D, mat: Dictionary, destinos: Array) -> Node3D:
	var raiz := _poste(onde, BRACO_PLACA, mat)
	var centro := Vector3(-4.6, BRACO_PLACA - 0.2 - PLACA.y * 0.5, 0.0)
	var verde_alto := PLACA.y - FAIXA_AZUL
	_chapa(raiz, centro + Vector3(0, FAIXA_AZUL * 0.5, 0), Vector2(PLACA.x, verde_alto), VERDE)
	_chapa(raiz, centro + Vector3(0, -verde_alto * 0.5, 0), Vector2(PLACA.x, FAIXA_AZUL), AZUL)
	# O filete branco entre o verde e o azul e a seta: o que le de longe,
	# antes do texto.
	var topo := centro.y + PLACA.y * 0.5
	var filete := Greybox.box(Vector3(PLACA.x - 0.2, 0.05, 0.02), Color.WHITE)
	raiz.add_child(filete)
	filete.position = Vector3(centro.x, topo - verde_alto, 0.08)
	var seta := Greybox.box(Vector3(0.12, 0.9, 0.02), Color.WHITE)
	raiz.add_child(seta)
	seta.position = Vector3(centro.x - PLACA.x * 0.5 + 0.45, topo - verde_alto * 0.5, 0.08)
	var linhas: Array[String] = [destinos[0], destinos[1]]
	for i in linhas.size():
		_texto(raiz, linhas[i], Vector3(centro.x + 0.3, topo - 0.42 - i * 0.78, 0.09), 72)
	var embaixo := Vector3(centro.x + 0.3, centro.y - PLACA.y * 0.5 + FAIXA_AZUL * 0.5, 0.09)
	_texto(raiz, "↑ " + String(destinos[2]), embaixo, 60)
	return raiz


## O aviso de que metade da pista vai virar mao contraria, no mesmo portico
## da placa verde: chapa amarela de advertencia, letra preta, por cima da
## pista. O losango da calcada sozinho passava batido a 180 km/h; a chapa de
## 5 m em cima da faixa e o que se le chegando. `metros` e ate a rua da
## esquina, onde a contramao comeca.
static func mao_dupla(onde: Transform3D, mat: Dictionary, metros: int) -> Node3D:
	var raiz := _poste(onde, BRACO_PLACA, mat)
	var centro := Vector3(-4.6, BRACO_PLACA - 0.2 - PLACA.y * 0.5, 0.0)
	_chapa(raiz, centro, PLACA, Color.BLACK)
	_chapa(raiz, centro + Vector3(0, 0, 0.02), PLACA - Vector2(0.16, 0.16), AMARELO)
	var preto := Color(0.05, 0.05, 0.05)
	_texto(raiz, "MÃO DUPLA", centro + Vector3(0.0, 0.4, 0.09), 96, preto)
	_texto(raiz, "A %d m" % metros, centro + Vector3(0.0, -0.6, 0.09), 72, preto)
	return raiz


static func _poste(onde: Transform3D, altura: float, mat: Dictionary) -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "Portal"
	raiz.transform = onde
	var fuste := Greybox.box(Vector3(0.24, altura + 0.3, 0.24), Color.BLACK)
	fuste.material_override = mat["poste"]
	raiz.add_child(fuste)
	fuste.position = Vector3.UP * (altura + 0.3) * 0.5
	var braco := Greybox.box(Vector3(BRACO_COMPRIMENTO, 0.18, 0.18), Color.BLACK)
	braco.material_override = mat["poste"]
	raiz.add_child(braco)
	braco.position = Vector3(-BRACO_COMPRIMENTO * 0.5, altura, 0.0)
	Quebravel.com_colisor(raiz, COLISOR)
	return raiz


## Chapa da placa, com a face pintada para +Z e o verso cinza.
static func _chapa(raiz: Node3D, centro: Vector3, tamanho: Vector2, cor: Color) -> void:
	var chapa := Greybox.box(Vector3(tamanho.x, tamanho.y, 0.1), cor)
	raiz.add_child(chapa)
	chapa.position = centro


## Texto branco colado na placa, lido de +Z. Sem sombra e sem luz: e tinta
## refletiva, e a placa no contraluz ficaria ilegivel. Recorte por alfa, e nao
## mistura, para nao brigar na ordem de desenho com o vidro dos carros.
static func _texto(
	raiz: Node3D, texto: String, onde: Vector3, tamanho: int, cor: Color = Color.WHITE
) -> void:
	var rotulo := Label3D.new()
	rotulo.text = texto
	rotulo.font_size = tamanho
	rotulo.pixel_size = 0.01
	rotulo.outline_size = 0
	rotulo.modulate = cor
	rotulo.shaded = false
	rotulo.double_sided = false
	rotulo.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	rotulo.position = onde
	raiz.add_child(rotulo)
