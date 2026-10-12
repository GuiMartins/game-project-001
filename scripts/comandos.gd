class_name Comandos
extends RefCounted
## As maos e os pes nos comandos: pulso no acelerador, dedos nas manetes, bota
## nos pedais, e a troca de marcha.
##
## Tudo sai do que o corpo manda - gas e freio pedidos, a velocidade - e nada
## da fisica: o jogador manda o polegar, o rival manda o que a IA decidiu.
## Gas e freio pedidos, e nao a aceleracao medida: medida, soltar o gas a
## 40 m/s (o arrasto passa de 5 m/s2), bater num carro ou subir na calcada
## puxavam a manete sem ninguem frear.
##
## A fisica nao tem cambio. A marcha e de mentira, contada pela velocidade em
## faixas que encurtam como as de uma caixa de verdade, e so existe para o
## piloto puxar a embreagem, aliviar o gas e mexer o pe na hora certa. Quantas
## marchas, e se tem embreagem, sai da `FichaDaMoto`: na automatica (0
## marchas) nao ha troca, e a manete da esquerda e o freio de tras.

## Quanto o pulso direito torce no gas cheio, em graus. E o que se le de tras:
## a mao rola para baixo em volta da manopla, quase em angulo reto com o
## antebraco.
const TORCAO: float = 65.0
## E o quanto ele volta, fechando o gas, na freada cheia.
const FECHA: float = 12.0
## Curso de cada peca no comando inteiro, em graus: a manete chega na manopla,
## o bico do pedal desce ou sobe um dedo, a bota acompanha.
const MANETE: float = 22.0
const PEDAL: float = 14.0
const BOTA: float = 18.0
## Quanto do freio vai no pe, na moto de cambio: o de tras freia menos.
const FREIO_NO_PE: float = 0.7
## Velocidade em que a ultima marcha acaba, em m/s: o `max_speed` do
## `BikeTuning`. O boost passa dele, e la a quinta so estica.
const TETO: float = 52.0
## Expoente das faixas: maior que 1 deixa as marchas de baixo curtas, como
## numa caixa de verdade. Na CG de 5 marchas, troca a 7, 16, 28 e 39 m/s.
const ESCALONAMENTO: float = 1.25
## Quanto abaixo da troca para cima a marcha desce, em m/s: sem folga, a moto
## no limite trocaria a cada quadro.
const FOLGA: float = 3.0
## Duracao da troca, em segundos: embreagem, pe e embreagem de novo.
const TEMPO_DA_TROCA: float = 0.32
## Gas minimo para subir marcha: quem so embala nao troca.
const GAS_PARA_SUBIR: float = 0.3
## Na reducao o piloto da um tapa no gas com a embreagem puxada.
const TAPA: float = 0.35
## Distancia, em metros, entre os dedos na manete solta e os dedos na mao em
## que eles largam a manete: a mao saiu da manopla (soco) ou torceu demais (gas
## cheio).
const LARGA := Vector2(0.02, 0.04)
## Meio dos dedos no espaco do no `Dedos`, cujo pivo fica 2 cm atras, perto da
## manopla. E aqui que se mede o quanto a mao se afastou: no pivo, o mesmo giro
## do pulso anda metade.
const PONTA := Vector3(0.0, 0.012, -0.02)

var _marchas: int = 0
var _marcha: int = 0
var _troca_t: float = -1.0
var _troca_sentido: float = 0.0
var _gas: float = 0.0
var _freio: float = 0.0
## Saidas do passo: graus do pulso direito, curso de cada manete (0 a 1), do
## pedal de freio (0 a 1) e do de cambio (-1 desce a 1 sobe).
var _torcao: float = 0.0
var _manete: Array[float] = [0.0, 0.0]
var _pedal_freio: float = 0.0
var _pedal_cambio: float = 0.0

var _manetes: Array[Node3D] = []
var _pedais: Array[Node3D] = []
var _dedos: Array[Node3D] = []
var _repouso: Dictionary[Node3D, Transform3D] = {}
## Dedos no espaco da manete em repouso: e por aqui que eles grudam nela.
var _dedos_na_manete: Array[Transform3D] = []


## Acha os nos de `modelo` (o `Entregador` do glb) e le a ficha da moto.
func montar(modelo: Node3D, ficha: FichaDaMoto) -> void:
	_marchas = ficha.marchas if ficha != null else 0
	_marcha = 0
	_troca_t = -1.0
	_manetes.clear()
	_pedais.clear()
	_dedos.clear()
	_repouso.clear()
	_dedos_na_manete.clear()
	for nome: String in ["Pedal_Cambio", "Pedal_Freio"]:
		_pedais.append(_acha(modelo, nome))
	for lado: String in ["E", "D"]:
		var manete := _acha(modelo, "Manete_" + lado)
		var dedos := _acha(modelo, "Dedos_" + lado)
		_manetes.append(manete)
		_dedos.append(dedos)
		# Em repouso nenhuma peca gira: a diferenca das posicoes basta.
		var entre := _posicao(dedos, modelo) - _posicao(manete, modelo)
		_dedos_na_manete.append(Transform3D(Basis.IDENTITY, entre))


## `acelerador` e `freio` de 0 a 1, como pedidos neste passo.
func passo(delta: float, v: float, acelerador: float, freio: float, caido: bool) -> void:
	if caido:
		_gas = 0.0
		_freio = 0.0
		_troca_t = -1.0
	else:
		_freio = lerpf(_freio, clampf(freio, 0.0, 1.0), 1.0 - exp(-15.0 * delta))
		var gas := clampf(acelerador, 0.0, 1.0) * (1.0 - _freio)
		_gas = lerpf(_gas, gas, 1.0 - exp(-12.0 * delta))
		_cambio(delta, v)

	var troca := sin(PI * _troca_t / TEMPO_DA_TROCA) if _troca_t >= 0.0 else 0.0
	var gas_na_mao := _gas
	if _troca_sentido > 0.0:
		gas_na_mao *= 1.0 - troca
	else:
		gas_na_mao = maxf(gas_na_mao, TAPA * troca)
	_torcao = TORCAO * gas_na_mao - FECHA * _freio
	if _marchas > 0:
		_manete = [troca, _freio]
		_pedal_freio = _freio * FREIO_NO_PE
		_pedal_cambio = _troca_sentido * troca
	else:
		_manete = [_freio, _freio]
		_pedal_freio = 0.0
		_pedal_cambio = 0.0


## Giro do pulso do lado `i` (0 esquerdo, 1 direito), no espaco do guidao.
## Positivo em X leva o topo da manopla para tras: e o gas abrindo.
func pulso(i: int) -> Basis:
	if i == 0:
		return Basis.IDENTITY
	return Basis(Vector3.RIGHT, deg_to_rad(_torcao))


## Giro da bota do lado `i`, no espaco da moto. Positivo em X levanta o bico.
func bota(i: int) -> Basis:
	var curso := _pedal_cambio if i == 0 else -_pedal_freio
	return Basis(Vector3.RIGHT, deg_to_rad(BOTA * curso))


## Poe manetes, pedais e dedos. Depois do IK: os dedos leem onde a mao parou.
func posar() -> void:
	for i in 2:
		# A ponta da manete corre em X para fora; puxar leva ela para tras
		# (+Z), e isso e giro positivo em Y na esquerda e negativo na direita.
		var lado := -1.0 if i == 0 else 1.0
		var manete := _manetes[i]
		var puxa := Basis(Vector3.UP, -lado * deg_to_rad(MANETE * _manete[i]))
		manete.transform = Transform3D(puxa, _repouso[manete].origin)

		var dedos := _dedos[i]
		var mao := dedos.get_parent() as Node3D
		var na_mao := mao.global_transform * _repouso[dedos]
		var na_manete := manete.global_transform * _dedos_na_manete[i]
		# Largar ou nao se decide contra a manete solta: puxada, ela leva os
		# dedos 3 cm para tras, e isso nao e a mao saindo dela.
		var solta := manete.get_parent() as Node3D
		var na_solta := solta.global_transform * _repouso[manete] * _dedos_na_manete[i]
		var d := (na_mao * PONTA).distance_to(na_solta * PONTA)
		var fica := 1.0 - smoothstep(LARGA.x, LARGA.y, d)
		var giro := na_mao.basis.get_rotation_quaternion().slerp(
			na_manete.basis.get_rotation_quaternion(), fica
		)
		dedos.global_transform = Transform3D(
			Basis(giro), na_mao.origin.lerp(na_manete.origin, fica)
		)

	var cambio := _pedais[0]
	cambio.transform = Transform3D(
		Basis(Vector3.RIGHT, deg_to_rad(PEDAL * _pedal_cambio)), _repouso[cambio].origin
	)
	var freio := _pedais[1]
	freio.transform = Transform3D(
		Basis(Vector3.RIGHT, deg_to_rad(-PEDAL * _pedal_freio)), _repouso[freio].origin
	)


func marcha() -> int:
	return _marcha


func trocando() -> bool:
	return _troca_t >= 0.0


func torcao() -> float:
	return _torcao


func manete(i: int) -> float:
	return _manete[i]


func pedal_freio() -> float:
	return _pedal_freio


## Velocidade em que a marcha `k` acaba e entra a `k + 1`.
func limiar(k: int) -> float:
	return TETO * pow(float(k) / float(_marchas), ESCALONAMENTO)


func _cambio(delta: float, v: float) -> void:
	if _marchas == 0:
		return
	if _marcha == 0:
		# A primeira vez, a marcha ja e a da velocidade: largada, respawn e
		# moto que nasce andando nao saem trocando quatro marchas seguidas.
		_marcha = 1
		while _marcha < _marchas and v > limiar(_marcha):
			_marcha += 1
	if _troca_t >= 0.0:
		_troca_t += delta
		if _troca_t >= TEMPO_DA_TROCA:
			_troca_t = -1.0
		return
	if _marcha < _marchas and v > limiar(_marcha) and _gas > GAS_PARA_SUBIR:
		_troca(1)
	elif _marcha > 1 and v < limiar(_marcha - 1) - FOLGA:
		_troca(-1)


func _troca(sentido: int) -> void:
	_marcha += sentido
	_troca_sentido = float(sentido)
	_troca_t = 0.0


func _acha(modelo: Node3D, nome: String) -> Node3D:
	var achado := modelo.find_child(nome, true, false) as Node3D
	assert(achado != null, "modelo sem o no %s" % nome)
	_repouso[achado] = achado.transform
	return achado


## Posicao de repouso relativa a `ancestral`, somando translacoes: em repouso,
## nenhuma peca do gerador gira.
func _posicao(no: Node3D, ancestral: Node3D) -> Vector3:
	var pos := Vector3.ZERO
	var atual: Node = no
	while atual != ancestral:
		pos += (atual as Node3D).transform.origin
		atual = atual.get_parent()
	return pos
