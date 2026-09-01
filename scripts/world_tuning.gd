extends Resource
class_name WorldTuning
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
