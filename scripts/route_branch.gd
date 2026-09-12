extends RefCounted
class_name RouteBranch
## Uma bifurcacao: o atalho que sai da avenida em `from_offset` e devolve o
## jogador em `to_offset`.
##
## Existe pra manter uma coisa so honesta: o jogador corre por OUTRA pista,
## mas a corrida continua sendo medida na avenida. Sem essa traducao, cortar
## caminho zeraria o cronometro (offsets de curvas diferentes nao se comparam)
## ou, pior, faria o atalho parecer mais longo que a volta.

## A pista do atalho. Nasce e morre com a rota.
var road: RoadTrack
## Onde a boca fica na avenida, em metros.
var from_offset: float = 0.0
## Onde o atalho devolve o jogador na avenida, em metros.
var to_offset: float = 0.0
## Lado da avenida em que a boca abre: -1 esquerda, +1 direita.
var side: float = 1.0


## Quantos metros de AVENIDA valem os `branch_offset` metros ja corridos aqui.
##
## E daqui que sai o premio: o atalho e mais curto que o trecho que ele
## substitui, entao cada metro rodado dentro dele avanca mais de um metro de
## rota. O jogador nao ve a conta - ele ve o "faltam X m" cair mais rapido, que
## e exatamente o que ele foi buscar ao entrar.
func progress_at(branch_offset: float) -> float:
	var done := clampf(branch_offset / maxf(road.length, 0.01), 0.0, 1.0)
	return lerpf(from_offset, to_offset, done)


## Quanto de pista o atalho economiza, em metros.
func saving() -> float:
	return (to_offset - from_offset) - road.length
