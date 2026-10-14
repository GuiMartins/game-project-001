class_name Cadencia
extends RefCounted
## Quando a pose do ator sai para a tela: a cada passo de fisica, ou travada
## em `hz` poses por segundo.
##
## A trava e o "digitalizado" do `DIRECAO_VISUAL.md`: a moto anda, inclina e
## chega a 60 Hz, e so o que acontece dentro dela - roda, guidao, joelho, soco,
## tombo - pula de pose em pose. Trava a pose e nao o estado: integrar a mola
## com passo de 1/12 s a faria explodir, e a roda perderia os passos em que a
## tela esperou. Quem chama segue integrando a cada passo e so pergunta se
## esta e a vez de posar. Por que o default e liso esta na V22 do
## `BACKLOG_VISUAL.md`.

## Poses por segundo; 0 e uma por passo, o liso.
var hz: float = 0.0
## Segundos desde a ultima pose.
var _desde: float = 0.0


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
	return true
