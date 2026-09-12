class_name DeliveryRun
extends RefCounted
## O loop de entrega: cronometro, integridade da bag, estilo, estrelas.
##
## Pilar de validacao: a corrida precisa ter uma pergunta a cada segundo -
## "arrisco o corredor pra ganhar 3 segundos, ou vou pela faixa limpa?". Se a
## resposta for sempre a mesma, o loop nao esta pronto.

enum Phase { RIDING, DELIVERED, FAILED }

const BAG_LOSS_CRASH: float = 14.0
const BAG_LOSS_SCRAPE: float = 3.0
const BAG_LOSS_HIT: float = 6.0

## Segundos por metro que o prazo concede. 0.055 s/m ~ 65 km/h de media exigida:
## da pra entregar dirigindo limpo, mas 5 estrelas exige o corredor.
const SECONDS_PER_METER: float = 0.055

var phase: int = Phase.RIDING
var distance_total: float = 0.0
var distance_done: float = 0.0
var time_left: float = 0.0
var time_total: float = 0.0
var bag: float = 100.0  ## Integridade da comida, 0..100.
var style: float = 0.0  ## Pontos de estilo (corredor, rival derrubado).
var near_misses: int = 0
var crashes: int = 0
var rivals_downed: int = 0
var combo: int = 0
var combo_timer: float = 0.0


func start(total_distance: float) -> void:
	distance_total = total_distance
	distance_done = 0.0
	time_total = total_distance * SECONDS_PER_METER
	time_left = time_total
	bag = 100.0
	style = 0.0
	near_misses = 0
	crashes = 0
	rivals_downed = 0
	combo = 0
	combo_timer = 0.0
	phase = Phase.RIDING


func tick(delta: float, offset_on_track: float) -> void:
	if phase != Phase.RIDING:
		return
	distance_done = clampf(offset_on_track, 0.0, distance_total)
	time_left -= delta

	combo_timer = maxf(combo_timer - delta, 0.0)
	if combo_timer <= 0.0:
		combo = 0

	if distance_done >= distance_total - 1.0:
		phase = Phase.DELIVERED
	elif time_left <= 0.0:
		time_left = 0.0
		phase = Phase.FAILED


func register_near_miss() -> void:
	combo += 1
	combo_timer = 2.2
	# O combo multiplica ate 8x: passar por dez carros de uma vez tem que valer
	# muito mais que dez raspadas separadas, senao o corredor nao seduz.
	style += 10.0 * float(mini(combo, 8))
	near_misses += 1


func register_crash() -> void:
	crashes += 1
	combo = 0
	combo_timer = 0.0
	bag = maxf(bag - BAG_LOSS_CRASH, 0.0)
	style = maxf(style - 40.0, 0.0)


func register_scrape(intensity: float) -> void:
	bag = maxf(bag - BAG_LOSS_SCRAPE * clampf(intensity, 0.2, 1.0), 0.0)


func register_hit_taken() -> void:
	bag = maxf(bag - BAG_LOSS_HIT, 0.0)
	combo = 0


func register_rival_down() -> void:
	rivals_downed += 1
	style += 150.0


## Estrelas de 1 a 5, como na avaliacao do app.
func stars() -> int:
	if phase == Phase.FAILED:
		return 1
	var time_frac := clampf(time_left / maxf(time_total, 0.01), 0.0, 1.0)
	var score := time_frac * 55.0 + (bag / 100.0) * 30.0 + clampf(style / 2500.0, 0.0, 1.0) * 15.0
	if score >= 82.0:
		return 5
	if score >= 62.0:
		return 4
	if score >= 42.0:
		return 3
	if score >= 22.0:
		return 2
	return 1


func summary() -> String:
	var lines: Array[String] = []
	lines.append("ENTREGUE" if phase == Phase.DELIVERED else "ATRASOU")
	lines.append("%s" % "*".repeat(stars()))
	lines.append("tempo restante  %5.1fs" % time_left)
	lines.append("bag             %5.0f%%" % bag)
	lines.append("estilo          %5.0f" % style)
	lines.append("corredor        %5d" % near_misses)
	lines.append("rivais no chao  %5d" % rivals_downed)
	lines.append("quedas          %5d" % crashes)
	return "\n".join(lines)
