class_name TrafficLight
extends Node3D
## Semaforo: para o transito num ponto fixo da pista.
##
## Existe pra criar a parede que o corredor resolve. Fila parada e o unico
## momento em que o jogador escolhe entre frear com todo mundo (seguro, lento)
## ou entrar no vao entre as filas (rapido, caro se errar) - e essa escolha e
## o jogo.
##
## Estatico na curva: sabe seu offset e nunca se move, entao a transform e
## calculada uma vez no setup e esquecida.

enum Phase { GREEN, YELLOW, RED }

const POLE := Vector3(0.32, 5.8, 0.32)
const BAR_THICK: float = 0.3
## Lampada grande de proposito. A 320x180, 0.5 m a 120 m de distancia nao chega
## a um pixel - o sinal so serve se o jogador ler a cor antes de decidir frear.
const LAMP: float = 0.8
const LAMP_GAP: float = 0.95
## Onde a fila para, em metros antes do cruzamento.
const STOP_MARGIN: float = 5.0

const RED_ON := Color(1.0, 0.28, 0.22)
const YELLOW_ON := Color(1.0, 0.78, 0.22)
const GREEN_ON := Color(0.36, 1.0, 0.5)
## Lampada apagada nao some: vira caixa escura, senao a silhueta do semaforo
## muda de forma a cada troca de fase e o olho perde a referencia.
const LAMP_OFF := Color(0.14, 0.14, 0.17)

var track: RoadTrack
var tuning: WorldTuning
var offset: float = 0.0
var phase: Phase = Phase.GREEN

## Faixa que este vermelho NAO segura, sorteada a cada ciclo.
##
## Sem ela a fila fecha as quatro faixas e o semaforo vira um muro: a 50 m/s a
## unica resposta possivel seria parar, e parar nao e o jogo. Com uma faixa
## vazia o vermelho continua sendo perigo, mas perigo que se atravessa - e como
## ela muda de ciclo pra ciclo, ninguem decora "e sempre a da direita".
var free_lane: int = 0

var _timer: float = 0.0
var _rng := RandomNumberGenerator.new()
var _lamps: Array[MeshInstance3D] = []


func setup(a_track: RoadTrack, a_offset: float, a_tuning: WorldTuning, seed_value: int) -> void:
	track = a_track
	offset = a_offset
	tuning = a_tuning
	_rng.seed = seed_value

	# Fase inicial sorteada: semaforo sincronizado na pista inteira entrega que
	# tem um relogio so por tras de todos eles.
	phase = [Phase.GREEN, Phase.YELLOW, Phase.RED][_rng.randi() % 3] as Phase
	_timer = _duration(phase) * _rng.randf()
	free_lane = _rng.randi_range(0, RoadTrack.LANE_COUNT - 1)

	_build()
	_paint()
	global_transform = track.transform_at(offset, 0.0)


## Onde a fila para. O carro mira aqui, nao no poste.
func stop_offset() -> float:
	return offset - STOP_MARGIN


## Amarelo ja segura. Carro de transito anda a 7 m/s: acelerar pra passar seria
## uma decisao de piloto, e este carro nao e pilotado.
func stopping() -> bool:
	return phase != Phase.GREEN


## Indice da faixa mais proxima de uma lateral qualquer.
static func lane_of(lateral: float) -> int:
	var index := int(round(lateral / RoadTrack.LANE_WIDTH + float(RoadTrack.LANE_COUNT - 1) * 0.5))
	return clampi(index, 0, RoadTrack.LANE_COUNT - 1)


## Este semaforo segura quem esta nesta lateral?
func holds(lateral: float) -> bool:
	return lane_of(lateral) != free_lane


## Centro da faixa segurada mais proxima - pra onde vai quem estava na livre.
func held_lateral_near(lateral: float) -> float:
	var lane := lane_of(lateral)
	for step in range(1, RoadTrack.LANE_COUNT):
		for dir: int in [-1, 1]:
			var candidate := lane + step * dir
			if candidate >= 0 and candidate < RoadTrack.LANE_COUNT and candidate != free_lane:
				return RoadTrack.lane_center(candidate)
	return RoadTrack.lane_center(lane)


func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	match phase:
		Phase.GREEN:
			phase = Phase.YELLOW
			# A faixa livre e sorteada aqui, no amarelo: quem esta nela ainda
			# tem o amarelo inteiro pra sair antes da fila fechar.
			free_lane = _rng.randi_range(0, RoadTrack.LANE_COUNT - 1)
		Phase.YELLOW:
			phase = Phase.RED
		Phase.RED:
			phase = Phase.GREEN
	# Duracao lida do tuning a cada troca, e nao guardada no setup: e assim que
	# o slider do F3 vale com o jogo andando.
	_timer = _duration(phase)
	_paint()


func _duration(of_phase: Phase) -> float:
	match of_phase:
		Phase.YELLOW:
			return tuning.light_yellow_time
		Phase.RED:
			return tuning.light_red_time
		_:
			return tuning.light_green_time


func _build() -> void:
	var edge := RoadTrack.sidewalk_limit() + 0.5

	for side: float in [-1.0, 1.0]:
		var pole := Greybox.box(POLE, Color(0.5, 0.49, 0.46))
		pole.position = Vector3(edge * side, POLE.y * 0.5, 0.0)
		add_child(pole)

	var bar := Greybox.box(Vector3(edge * 2.0, BAR_THICK, BAR_THICK), Color(0.45, 0.44, 0.42))
	bar.position = Vector3(0.0, POLE.y - BAR_THICK, 0.0)
	add_child(bar)

	var caixa := Greybox.box(
		Vector3(LAMP + 0.3, LAMP_GAP * 3.0 + 0.2, LAMP * 0.6), Color(0.2, 0.2, 0.23)
	)
	caixa.position = Vector3(0.0, POLE.y - BAR_THICK - LAMP_GAP * 1.6, 0.0)
	add_child(caixa)

	for i in range(3):
		var lamp := Greybox.box(Vector3(LAMP, LAMP, LAMP * 0.9), LAMP_OFF, true)
		lamp.position = caixa.position + Vector3(0.0, LAMP_GAP * (1.0 - float(i)), 0.15)
		add_child(lamp)
		_lamps.append(lamp)

	# Faixa de retencao pintada no asfalto: sem ela o jogador ve a fila parada
	# mas nao ve ONDE ela para, e o vao entre as filas parece surgir do nada.
	var line := Greybox.box(Vector3(RoadTrack.half_width() * 2.0, 0.05, 0.5), Color(0.9, 0.88, 0.7))
	line.position = Vector3(0.0, 0.04, STOP_MARGIN)
	add_child(line)


func _paint() -> void:
	var on := [RED_ON, YELLOW_ON, GREEN_ON]
	var lit := 0 if phase == Phase.RED else (1 if phase == Phase.YELLOW else 2)
	for i in range(_lamps.size()):
		var color: Color = on[i] if i == lit else LAMP_OFF
		_lamps[i].material_override = Greybox.material(color, i == lit)
