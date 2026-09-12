class_name WorldTuning
extends Resource
## Constantes do transito e dos rivais.
##
## Separado de BikeTuning de proposito: aquele arquivo responde "a moto esta
## gostosa?", este responde "o corredor esta passavel?". Sao duas perguntas
## diferentes, e misturar os sliders faz voce ajustar uma achando que ajusta
## a outra.

const SAVE_PATH: String = "user://world_tuning.tres"

@export_group("Transito")

## Quantos carros existem ao mesmo tempo. ESTE e o numero da densidade.
##
## Os carros nao sao criados e destruidos: sao reciclados pra viver sempre na
## janela [-traffic_behind, +traffic_ahead] em volta do jogador. Entao a
## densidade real e count / (ahead + behind). Com 36 carros numa janela de
## 490 m da um carro a cada 13,6 m de pista, espalhados nas 4 faixas.
@export_range(0, 120, 1) var traffic_count: int = 20

## Espacamento minimo entre carros na largada, em metros.
@export_range(3.0, 60.0, 0.5) var traffic_gap_min: float = 5.0
## Espacamento maximo entre carros na largada, em metros.
##
## So vale na largada e no R. Depois disso quem manda na densidade e o
## traffic_count com a janela - por isso mexer so aqui parece nao fazer nada
## depois dos primeiros segundos.
@export_range(4.0, 90.0, 0.5) var traffic_gap_max: float = 16.0

## Quao a frente do jogador um carro reciclado reaparece, em metros.
## Aumentar isto sem mexer no count espalha a mesma frota num trecho maior.
@export_range(80.0, 800.0, 10.0) var traffic_ahead: float = 420.0
## Quantos metros atras do jogador o carro e recolhido pra reciclagem.
@export_range(20.0, 200.0, 5.0) var traffic_behind: float = 30.0

## Velocidade de cruzeiro mais alta que um carro do fluxo assume, em m/s.
##
## 7 m/s e 25 km/h: transito de marginal em hora de pico. E o numero que decide
## se o corredor e um tunel que anda ou uma parede que voce ultrapassa - alto
## demais e os carros somem no retrovisor, zero e a avenida vira
## estacionamento permanente.
@export_range(0.0, 25.0, 0.5) var traffic_speed: float = 7.0

## Aceleracao do carro do transito, em m/s^2.
@export_range(0.5, 12.0, 0.1) var traffic_accel: float = 2.2
## Frenagem do carro do transito, em m/s^2.
##
## Maior que a aceleracao de proposito: carro que reage devagar a fila entra
## dentro do carro da frente, e duas caixas se atravessando a 320x180 le como
## bug, nao como transito.
@export_range(1.0, 25.0, 0.1) var traffic_brake: float = 4.5
## Distancia centro a centro que o carro guarda do carro da frente, em metros.
##
## O carro tem 4,4 m, entao abaixo de 5 eles se encavalam. E este numero que
## decide o comprimento da fila do semaforo.
@export_range(5.0, 24.0, 0.1) var traffic_follow_gap: float = 6.2

## Fracao dos carros que entra encostada no meio-fio, parada.
##
## Encostado quer dizer parado numa das faixas da ponta - a da esquerda ou a
## da direita, sorteada. So carro encostado pode abrir porta: carro andando no
## meio da pista abrindo porta e bug com cara de recurso.
##
## Tambem e o numero que decide se as faixas da ponta valem a pena. Alto
## demais e elas viram parede, e o jogo perde duas das quatro faixas.
@export_range(0.0, 1.0, 0.05) var parked_chance: float = 0.3

## Fracao dos carros encostados que chega a abrir a porta em algum momento.
##
## Abaixo de 1.0 encostar nao e sinonimo de perigo, e ai a faixa da ponta vira
## uma aposta em vez de uma regra decorada. O lado que a porta abre tambem e
## sorteado - pra pista ou pra calcada.
@export_range(0.0, 1.0, 0.05) var door_chance: float = 0.6

@export_group("Rivais")

## Quantos rivais correm junto. Muda na proxima corrida (R), nao ao vivo:
## rival tem estado de IA e trocar no meio faria o placar mentir.
@export_range(0, 12, 1) var rival_count: int = 4


static func load_or_default() -> WorldTuning:
	if ResourceLoader.exists(SAVE_PATH):
		var res: Resource = ResourceLoader.load(SAVE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
		if res is WorldTuning:
			return res as WorldTuning
	return WorldTuning.new()


func save() -> void:
	ResourceSaver.save(self, SAVE_PATH)


func reset_to_default() -> void:
	var fresh := WorldTuning.new()
	for prop: Dictionary in get_property_list():
		if prop["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
			set(prop["name"], fresh.get(prop["name"]))
