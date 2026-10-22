extends SceneTree
## Folhas de referencia dos props de rua, para dar ao Google Flow.
##
##     python tools/dev.py boneco prop
##
## Poste, cacamba, mupi, as tres placas e o guindaste, cada um numa linha so,
## de tres quartos de frente, que e como o Road Rash mostra o que vem na
## direcao do jogador (`MIGRACAO_2D.md`, Props). Em cinza sobre verde: a cor,
## a lente acesa e o painel do mupi vem depois, por coordenada na ficha.
##
## Uma coluna por giro. Alem dos tres quartos de frente, o de lado e o de tres
## quartos de costas entram na folha para o Flow ver o objeto inteiro, mas o
## jogo so usa o primeiro.
##
## Roda com tela: o renderizador do `--headless` e um dummy, e sai tudo preto.

const Cena := preload("res://arte/boneco_cena.gd")

const PASTA: String = "res://arte/flow/referencia/prop/"
const PPM: float = 128.0
const TOM := Color(0.62, 0.63, 0.66)
## O modelo olha para -Z: 180 o poe de frente para a camera, e -135 de tres
## quartos, para a direita.
const GIROS: Array[float] = [-135.0, -90.0, -45.0]
## Altura e alcance do guindaste de referencia: o de uma obra de torre.
const GUINDASTE_ALTURA: float = 30.0
const GUINDASTE_LANCA: float = 20.0

var _cena := Cena.new()


func _initialize() -> void:
	root.add_child(_cena)
	_cena.monta(root)
	_roda.call_deferred()


func _roda() -> void:
	await process_frame
	await _faz("poste", _malha(Poste.malha()))
	await _faz("cacamba", _malha(Mobiliario.malha(Mobiliario.Tipo.CACAMBA)))
	await _faz("mupi", _malha(Mobiliario.malha(Mobiliario.Tipo.MUPI)))
	await _faz("placa_curva_esquerda", _malha(Mobiliario.malha(Mobiliario.Tipo.PLACA_ESQUERDA)))
	await _faz("placa_curva_direita", _malha(Mobiliario.malha(Mobiliario.Tipo.PLACA_DIREITA)))
	await _faz("placa_mao_dupla", _malha(Mobiliario.malha(Mobiliario.Tipo.PLACA_MAO_DUPLA)))
	await _faz("guindaste", Guindaste.criar(GUINDASTE_ALTURA, GUINDASTE_LANCA, 0.0))
	quit()


func _faz(nome: String, no: Node3D) -> void:
	_cena.pinta(no, TOM)
	await _cena.objeto(nome, PASTA, no, GIROS, PPM)


## Uma malha solta num no: sem material do jogo, que a bancada pinta de cinza.
func _malha(malha: Mesh) -> Node3D:
	var no := MeshInstance3D.new()
	no.mesh = malha
	return no
