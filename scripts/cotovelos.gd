class_name Cotovelos
extends RefCounted
## Para onde cada cotovelo dobra, mudando sozinho: o braco de quem pilota nao
## fica parado no losango a corrida inteira.
##
## A postura de base e a do video (V07): cotovelo para fora, a ponta mais larga
## da silhueta. De tempos em tempos um braco relaxa - desce e fecha junto do
## corpo -, as vezes os dois, e volta. Quando e quanto sai de um sorteio, e nao
## de um ciclo: senoide le como coreografia, e o que se quer e gente.
##
## Sorteado, mas com semente: a mesma semente da o mesmo braco no mesmo passo,
## e a prova visual congelada sai igual em toda rodada. Cada ator tem a sua, e
## dois pilotos lado a lado nao relaxam em uniao.

## Polo do IK aberto e relaxado, no espaco da moto, com x espelhado por lado.
## Aberto e quase so para fora; relaxado desce o cotovelo e cola no corpo.
const ABERTO := Vector3(1.0, -0.3, 0.3)
const RELAXADO := Vector3(0.3, -1.0, 0.15)
## Quanto tempo, em segundos, cada postura dura antes do proximo sorteio.
const TEMPO_ABERTO := Vector2(2.0, 7.0)
const TEMPO_RELAXADO := Vector2(0.6, 2.5)
## Chance de relaxar a cada sorteio, parado e no talo: em cruzeiro rapido o
## piloto segura o guidao; devagar, solta o braco.
const RELAXA_DEVAGAR: float = 0.6
const RELAXA_RAPIDO: float = 0.25
## Velocidade, em m/s, em que vale o `RELAXA_RAPIDO`.
const RAPIDO: float = 30.0
## Na curva fechada ninguem solta o braco: acima desta inclinacao, em
## radianos, o sorteio so da aberto, e quem estava relaxado volta.
const SEGURA_NA_CURVA: float = 0.35
## Chance de o outro braco relaxar junto: o ombro todo descansando.
const OS_DOIS: float = 0.3
## Taxa, por segundo, com que o braco anda para o alvo: ~0,4 s para assentar,
## devagar o bastante para ler como movimento e nao como troca de quadro.
const TAXA: float = 5.0

var _rng := RandomNumberGenerator.new()
## Por lado, esquerdo e direito: 0 aberto, 1 relaxado.
var _valor: Array[float] = [0.0, 0.0]
var _alvo: Array[float] = [0.0, 0.0]
var _falta: Array[float] = [0.0, 0.0]
var _semeado: bool = false


## `onde` e a posicao do ator, e so o primeiro passo a le: a semente sai de onde
## o piloto nasceu, que muda de um para outro e se repete entre rodadas.
func passo(delta: float, v: float, inclinacao: float, onde: Vector3) -> void:
	if not _semeado:
		semear(hash(onde.snappedf(0.1)))
	var segura := absf(inclinacao) > SEGURA_NA_CURVA
	var chance := lerpf(RELAXA_DEVAGAR, RELAXA_RAPIDO, clampf(v / RAPIDO, 0.0, 1.0))
	for i in 2:
		_falta[i] -= delta
		if segura:
			_alvo[i] = 0.0
		elif _falta[i] <= 0.0:
			_sorteia(i, chance)
		_valor[i] = lerpf(_valor[i], _alvo[i], 1.0 - exp(-TAXA * delta))


## O polo do lado `i` (0 esquerdo, 1 direito), no espaco da moto.
func polo(i: int) -> Vector3:
	var lado := Vector3(-1.0 if i == 0 else 1.0, 1.0, 1.0)
	return ABERTO.lerp(RELAXADO, _valor[i]) * lado


func relaxado(i: int) -> float:
	return _valor[i]


func semear(semente: int) -> void:
	_rng.seed = semente
	_semeado = true
	for i in 2:
		_falta[i] = _rng.randf_range(0.5, TEMPO_ABERTO.y)


func _sorteia(i: int, chance: float) -> void:
	if _alvo[i] < 0.5 and _rng.randf() < chance:
		_relaxa(i)
		var outro := 1 - i
		if _alvo[outro] < 0.5 and _rng.randf() < OS_DOIS:
			_relaxa(outro)
		return
	# Aberto, mas nunca no mesmo lugar: um pouco mais ou menos dobrado a cada
	# vez, que e o que o braco de verdade faz segurando o guidao.
	_alvo[i] = _rng.randf_range(0.0, 0.2)
	_falta[i] = _rng.randf_range(TEMPO_ABERTO.x, TEMPO_ABERTO.y)


func _relaxa(i: int) -> void:
	_alvo[i] = _rng.randf_range(0.6, 1.0)
	_falta[i] = _rng.randf_range(TEMPO_RELAXADO.x, TEMPO_RELAXADO.y)
