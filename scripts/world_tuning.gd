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

@export_group("Semaforo")

## Espacamento minimo entre semaforos na pista, em metros.
##
## Vale na construcao da pista: muda no R, nao ao vivo. Semaforo e geometria
## fixa da rota, e trocar de lugar com a moto andando faria a fila que voce ja
## estava lendo mudar de sentido no meio da freada.
@export_range(80.0, 1200.0, 10.0) var light_gap_min: float = 260.0
## Espacamento maximo entre semaforos na pista, em metros.
@export_range(120.0, 2000.0, 10.0) var light_gap_max: float = 520.0

## Quanto tempo o sinal fica verde, em segundos.
@export_range(2.0, 60.0, 0.5) var light_green_time: float = 14.0
## Quanto tempo o sinal fica amarelo, em segundos.
@export_range(0.5, 8.0, 0.5) var light_yellow_time: float = 2.5
## Quanto tempo o sinal fica vermelho, em segundos.
##
## E este numero que decide o tamanho da fila: cada segundo de vermelho e mais
## um carro parado. Alto demais e o cruzamento vira estacionamento.
@export_range(1.0, 40.0, 0.5) var light_red_time: float = 9.0

@export_group("Engarrafamento")

## Distancia minima de pista entre um engarrafamento e o proximo, em metros.
@export_range(100.0, 3000.0, 20.0) var jam_gap_min: float = 480.0
## Distancia maxima de pista entre um engarrafamento e o proximo, em metros.
##
## Junto com o minimo, define o ritmo: engarrafamento e o momento em que a
## pista some e so o corredor sobra. Frequente demais e o corredor deixa de ser
## a excecao e vira o jogo inteiro.
@export_range(200.0, 6000.0, 20.0) var jam_gap_max: float = 1300.0

## Fracao da frota que um engarrafamento consome.
##
## Diferente do semaforo, aqui as quatro faixas SAO ocupadas de proposito - o
## engarrafamento e a parede completa, e o unico caminho e o vao entre as
## filas. Por isso ele come tantos carros: parede pela metade nao para
## ninguem. Em 0 nao ha engarrafamento nenhum.
@export_range(0.0, 1.0, 0.05) var jam_share: float = 0.5

## Velocidade em que a fila presa rasteja, em m/s.
##
## Fila 100% imovel vira cenario. Um metro por segundo ja e o bastante pro vao
## respirar - abrir e fechar - enquanto o jogador se decide a entrar nele.
@export_range(0.0, 4.0, 0.1) var jam_creep: float = 1.4

## Distancia entre as fileiras do engarrafamento, em metros.
##
## Comprimento do carro (4,4) mais o vao de para-choque. E o outro lado do
## corredor: este numero e o vao longitudinal, `traffic_follow_gap` e o da
## fila que ainda anda.
@export_range(5.0, 14.0, 0.1) var jam_row_gap: float = 6.4

@export_group("Bifurcacao")

## Quantos atalhos a rota tenta abrir. Vale no R, junto com a pista.
##
## Atalho e a corda de uma curva grande: sai da avenida, corta reto e devolve
## voce la na frente. Nao ha lugar garantido pra todos - a rota so aceita a
## corda onde ela economiza pista de verdade, entao pedir 6 pode entregar 3.
@export_range(0, 6, 1) var branch_count: int = 2

## Carros parados largados dentro de cada atalho.
##
## E o preco do atalho. Sem eles a escolha nao existe: pista mais curta e
## vazia seria sempre a resposta certa, e escolha com resposta certa nao e
## escolha. Com eles o atalho e mais curto E mais apertado.
@export_range(0, 12, 1) var branch_obstacles: int = 4

## Quanto o jogador precisa estar pro lado da boca pra entrar no atalho, em
## metros do eixo da pista.
##
## Nao e o meio da pista: quem passa a 20 cm do eixo nao escolheu nada, e uma
## bifurcacao que voce toma sem querer e uma bifurcacao que voce xinga. Dois
## metros e meia faixa - da pra ver na tela de que lado voce esta.
@export_range(0.0, 6.0, 0.1) var fork_commit: float = 2.0

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
