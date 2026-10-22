class_name HumorDaFaixa
extends RefCounted
## O humor de cada trecho da faixa de servico: bosque (pontos 2,5x mais juntos),
## deserto (2,5x mais afastados e sem arvore) ou normal. Sem isso o sorteio por
## ponto dava o mesmo ritmo, de duas em duas, a avenida inteira.

const COMPRIMENTO := Vector2(120.0, 320.0)
const BOSQUE: float = 0.3
const DESERTO: float = 0.3
const ESCALA: float = 2.5

var bosque: bool = false
var deserto: bool = false
var _ate: float = 0.0


## Sorteia um humor novo quando `o` passa do fim do trecho atual.
func avanca(o: float, rua: RandomNumberGenerator) -> void:
	if o < _ate:
		return
	var humor := rua.randf()
	bosque = humor < BOSQUE
	deserto = not bosque and humor < BOSQUE + DESERTO
	_ate = o + rua.randf_range(COMPRIMENTO.x, COMPRIMENTO.y)


## O passo ate o proximo ponto, ja ajustado ao humor.
func passo(base: float) -> float:
	if bosque:
		return base / ESCALA
	return base * ESCALA if deserto else base
