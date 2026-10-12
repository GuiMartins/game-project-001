class_name FisicaDaMoto
extends RefCounted
## O que muda na fisica de uma moto para outra: so a mola da inclinacao.
##
## Multiplicadores sobre o `BikeTuning`, e nao valores absolutos: o F3 continua
## valendo para as tres motos. Com numero absoluto por moto, mexer no
## `lean_freq` so mudaria a CG, e quem testasse na PCX ia achar o slider morto.
##
## A CG e 1: e a moto em que a mola da V05 foi afinada, e a do banco de provas.
## Velocidade, aceleracao e curva sao as mesmas nas tres, de proposito (V05a do
## backlog visual): a escolha da moto muda o jeito de trocar de lado no
## corredor, nao quem ganha a corrida.

## Multiplica `lean_freq`: quao rapido a moto deita.
var deitar: float = 1.0
## Multiplica `lean_return_freq`: quao rapido ela levanta.
var voltar: float = 1.0
## Multiplica `lean_return_damping`. Abaixo de 1 passa mais do zero na volta.
var amortecer: float = 1.0


func _init(a_deitar: float = 1.0, a_voltar: float = 1.0, a_amortecer: float = 1.0) -> void:
	deitar = a_deitar
	voltar = a_voltar
	amortecer = a_amortecer


## A fisica do `modelo` (um `Entregador.Modelo`).
static func de(modelo: int) -> FisicaDaMoto:
	match modelo:
		Entregador.Modelo.PCX_160:
			# Roda de 14" e 13" e entre-eixos curto: pouca inercia para virar. Deita
			# 0->90% em ~0,4 s contra 0,52 da CG, e volta tao nervosa quanto
			# deita - 0,36 de amortecimento passa ~30% do zero (7 graus saindo
			# de 25), ainda acima do ~0,3 em que ela comeca a quicar.
			return FisicaDaMoto.new(1.3, 1.3, 0.8)
		Entregador.Modelo.XRE_300:
			# Alta e de roda 21": centro de massa longe do chao e roda grande
			# girando, que segura a moto em pe. Deita em ~0,64 s e volta
			# assentada, passando so 2,5 graus do zero (4,6 na CG).
			return FisicaDaMoto.new(0.8, 0.85, 1.25)
	return FisicaDaMoto.new()
