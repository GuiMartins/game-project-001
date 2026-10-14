class_name Cadencia
extends Node
## Quando a pose do ator sai para a tela: a cada passo de fisica, ou travada
## em `hz` poses por segundo.
##
## A trava e o "digitalizado" do `DIRECAO_VISUAL.md`: tudo o que o ator mostra
## pula de pose em pose - roda, guidao, joelho, soco, tombo e tambem a
## inclinacao e a virada da moto inteira -, e so o lugar dela na pista anda
## liso. A posicao fica de fora de proposito: a camera segue o corpo a 60 Hz,
## e a moto parada no lugar enquanto a camera anda tremeria na tela inteira.
##
## Trava a pose e nao o estado: integrar a mola com passo de 1/12 s a faria
## explodir, e a roda perderia os passos em que a tela esperou. Quem chama
## segue integrando a cada passo e so pergunta se esta e a vez de posar.
##
## Mora como filho do `Entregador`. A inclinacao e a guinada nao sao dele:
## quem inclina e o `Visual` do corpo, e quem vira e o proprio corpo. Por isso
## a trava segura a rotacao do ator no MUNDO, e no `_process`, depois de a
## fisica do quadro ter girado tudo por cima.

## Poses por segundo; 0 e uma por passo, o liso.
var hz: float = 0.0
## Segundos desde a ultima pose.
var _desde: float = 0.0
## Se houve pose desde o ultimo quadro, e o giro do ator no mundo nela.
var _posou: bool = true
var _giro := Basis.IDENTITY
## O transform do ator no pai, sem a trava: o lugar dele no `Visual`.
var _repouso := Transform3D.IDENTITY


func _ready() -> void:
	var ator := get_parent() as Node3D
	if ator != null:
		_repouso = ator.transform


func vez(delta: float) -> bool:
	if hz <= 0.0:
		return true
	var periodo := 1.0 / hz
	_desde += delta
	# A folga de um milesimo: 5 passos de 1/60 somados em float ficam um fio
	# abaixo de 1/12, e a pose sairia a cada 6.
	if _desde < periodo - 0.001:
		return false
	# Desconta o periodo em vez de zerar: com passo que nao divide o periodo, a
	# media continua sendo a cadencia pedida.
	_desde = clampf(_desde - periodo, 0.0, periodo)
	_posou = true
	return true


func _process(_delta: float) -> void:
	var ator := get_parent() as Node3D
	if ator == null:
		return
	if hz <= 0.0 or _posou:
		# Na pose (e no liso, sempre) o ator volta ao lugar dele no `Visual`, e
		# o giro de agora fica guardado para os quadros de espera.
		ator.transform = _repouso
		_giro = ator.global_basis
		_posou = false
	else:
		ator.global_basis = _giro
