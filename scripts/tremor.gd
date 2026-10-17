class_name Tremor
extends RefCounted
## O tremor miudo da moto andando: quanto a frente e a traseira afundam a cada
## passo, por cima da suspensao.
##
## Deterministico de proposito, sem `randf`: a fase sai so do tempo de fisica e
## da velocidade, e a prova visual congelada sai igual em toda maquina.

## Metros de pico no cruzeiro.
##
## O tremor curto que o `ASFALTO` do `Entregador` deixa de fora: motor,
## corrente e junta de asfalto. E o que faz a moto do video ler como veiculo e
## nao como peca colada no chao (topo da bag em +-3 px, uns 2 cm).
## Cresce com o quadrado da velocidade: parado e devagar a moto e firme.
const PICO: float = 0.012
## Velocidade, em m/s, em que o tremor chega ao pico: o cruzeiro do jogo.
const CHEIO: float = 35.0
## Frequencia do tremor, em Hz, de devagar a rapido: o giro do motor sobe com
## a marcha, e 8 a 15 Hz e a faixa que a mola nao engole e o olho ainda ve a
## 60 quadros (quatro amostras por ciclo no pior caso).
const HZ := Vector2(8.0, 15.0)

## Fase, em ciclos. Integrada, e nao `tempo * frequencia`: a frequencia muda
## com a velocidade, e o produto pularia de fase a cada passo.
var _fase: float = 0.0
var _impacto: float = 0.0
var _tempo_impacto: float = 0.0


## Afunda a frente por um instante sem mudar a velocidade nem a direcao da moto.
func impacto(forca: float) -> void:
	_impacto = maxf(_impacto, clampf(forca, 0.0, 1.0))
	_tempo_impacto = 0.0


## Duas senoides fora de fase, a traseira um pouco mais forte (e onde esta o
## motor): soma de frequencias que nao se dividem nao repete o desenho, e o
## tremor nao le como mola balancando.
func passo(delta: float, v: float, caido: bool) -> Vector2:
	_tempo_impacto += delta
	var tranco := _impacto * exp(-18.0 * _tempo_impacto) * sin(32.0 * _tempo_impacto)
	if caido:
		_impacto = 0.0
		tranco = 0.0
	var k := clampf(v / CHEIO, 0.0, 1.0)
	_fase = fmod(_fase + lerpf(HZ.x, HZ.y, k) * delta, 1000.0)
	var amplitude := 0.0 if caido else PICO * k * k
	var a := TAU * _fase
	return (
		(
			Vector2(
				0.6 * sin(a) + 0.4 * sin(a * 1.618 + 0.7),
				0.7 * sin(a + 1.9) + 0.3 * sin(a * 2.414 + 0.3),
			)
			* amplitude
		)
		+ Vector2(0.1, 0.025) * tranco
	)
