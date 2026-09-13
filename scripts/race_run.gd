class_name RaceRun
extends RefCounted
## A corrida de entregadores: posicao, prazo, estilo, estrelas.
##
## O jogo e essencialmente uma CORRIDA - quem decide o resultado e a posicao na
## chegada, e quem decide o fim e a linha, nao o cronometro. O prazo e o estilo
## continuam pesando porque chegar em primeiro arrastando a moto nao e entrega
## de entregador: eles modulam a nota, nunca a classificacao.
##
## Existiu aqui uma "integridade da bag" em porcentagem, que caia a cada queda,
## raspada e pancada. Saiu porque media a mesma coisa que o resto do painel ja
## media - quem cai e apanha tambem chega tarde e sem estilo - e cobrava por
## isso uma barra permanente na HUD de 320x180, onde nao sobra espaco pra
## numero redundante. O custo de raspar virou estilo, que e onde ele ja doia.

enum Phase { RACING, FINISHED }

## Estilo perdido numa raspada de intensidade cheia.
const STYLE_LOSS_SCRAPE: float = 25.0

## Segundos por metro que o prazo concede. 0.055 s/m ~ 65 km/h de media exigida:
## da pra entregar dirigindo limpo, mas 5 estrelas exige o corredor.
const SECONDS_PER_METER: float = 0.055

## Base da chave de ordenacao de quem ja cruzou a linha.
##
## Qualquer valor acima do comprimento da rota serve: quem terminou vem sempre
## na frente de quem ainda corre, e entre os que terminaram ganha quem cruzou
## primeiro. Ordenar corredor que chegou junto com corredor em pista sem isto
## exige duas listas e duas comparacoes - uma chave so cabe num teste unitario.
const FINISHED_KEY_BASE: float = 100000.0

## Teto de nota de quem estourou o prazo.
##
## Atraso nao apaga a corrida ganha - 4 estrelas e que ele apaga. Cinco
## estrelas e entrega perfeita, e entrega perfeita tem hora.
const LATE_SCORE_CAP: float = 58.0

var phase: int = Phase.RACING
## Onde a linha de chegada esta, em metros de rota. E o mesmo numero pro
## jogador e pros rivais: linha diferente por corredor e placar que mente.
var distance_total: float = 0.0
var distance_done: float = 0.0
var time_left: float = 0.0
var time_total: float = 0.0
var elapsed: float = 0.0
var finish_time: float = -1.0  ## Segundos ate cruzar a linha, -1 enquanto corre.
var position: int = 1  ## Colocacao no pelotao, 1 = lider.
var racers: int = 1  ## Quantos correm, jogador incluido.
var overtakes: int = 0  ## Posicoes ganhas ao longo da corrida.
var late: bool = false  ## Estourou o prazo. Custa estrela, nao encerra a corrida.
var style: float = 0.0  ## Pontos de estilo (corredor, rival derrubado).
var near_misses: int = 0
var crashes: int = 0
var rivals_downed: int = 0
var combo: int = 0
var combo_timer: float = 0.0


func start(finish_distance: float, racer_count: int = 1) -> void:
	distance_total = finish_distance
	distance_done = 0.0
	time_total = finish_distance * SECONDS_PER_METER
	time_left = time_total
	elapsed = 0.0
	finish_time = -1.0
	position = racer_count
	racers = maxi(racer_count, 1)
	overtakes = 0
	late = false
	style = 0.0
	near_misses = 0
	crashes = 0
	rivals_downed = 0
	combo = 0
	combo_timer = 0.0
	phase = Phase.RACING


func tick(delta: float, offset_on_track: float) -> void:
	if phase != Phase.RACING:
		return
	distance_done = clampf(offset_on_track, 0.0, distance_total)
	elapsed += delta
	time_left -= delta

	combo_timer = maxf(combo_timer - delta, 0.0)
	if combo_timer <= 0.0:
		combo = 0

	if time_left <= 0.0:
		time_left = 0.0
		late = true

	# `distance_done` e grampeado em `distance_total`, entao a igualdade so
	# acontece quando a moto passou da linha - nao precisa de margem.
	if distance_done >= distance_total:
		finish_time = elapsed
		phase = Phase.FINISHED


## Registra a colocacao deste frame e devolve quantas posicoes mudaram
## (positivo = ultrapassou). Quem chamou avisa o jogador - a HUD precisa saber
## que a posicao mudou no instante em que muda, e nao no fim.
func update_position(new_position: int) -> int:
	if phase != Phase.RACING or new_position == position:
		return 0
	var gained := position - new_position
	position = new_position
	if gained > 0:
		overtakes += gained
	return gained


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
	style = maxf(style - 40.0, 0.0)


## Raspou de verdade num carro - encostou, nao passou perto.
##
## O piso de 0.2 na intensidade e o que separa raspar de passar no corredor:
## quem encostou de leve ainda encostou, e o `register_near_miss` e que paga
## por passar perto sem tocar.
func register_scrape(intensity: float) -> void:
	style = maxf(style - STYLE_LOSS_SCRAPE * clampf(intensity, 0.2, 1.0), 0.0)


func register_hit_taken() -> void:
	combo = 0


func register_rival_down() -> void:
	rivals_downed += 1
	style += 150.0


## Chave de ordenacao de um corredor: quanto maior, mais na frente.
## `finish_time` negativo quer dizer que ele ainda esta na pista.
static func rank_key(progress: float, a_finish_time: float) -> float:
	if a_finish_time < 0.0:
		return progress
	return FINISHED_KEY_BASE - a_finish_time


## Colocacao (1 = lider) de `mine` no meio das chaves de todo mundo, a dele
## inclusa. Empate divide a posicao em vez de sumir com um dos dois.
static func position_of(mine: float, all_keys: Array[float]) -> int:
	var ahead := 0
	for key: float in all_keys:
		if key > mine:
			ahead += 1
	return ahead + 1


## Estrelas de 1 a 5, como na avaliacao do app.
##
## A posicao pesa metade: e ela que diz se voce ganhou a corrida. O resto e o
## entregador dentro do piloto - chegou no prazo, chegou pelo corredor.
##
## Os 20 pontos da bag foram redistribuidos quando ela saiu: 10 pro prazo e 10
## pro estilo. Guardar a metade da posicao intacta e o que mantem a frase acima
## verdadeira; jogar os 20 pontos todos num lado so mudaria em silencio o que a
## nota esta perguntando.
func stars() -> int:
	var podium := 1.0
	if racers > 1:
		podium = clampf(1.0 - float(position - 1) / float(racers - 1), 0.0, 1.0)
	var time_frac := clampf(time_left / maxf(time_total, 0.01), 0.0, 1.0)
	var score := podium * 50.0 + time_frac * 30.0 + clampf(style / 2500.0, 0.0, 1.0) * 20.0
	if late:
		score = minf(score, LATE_SCORE_CAP)
	if score >= 82.0:
		return 5
	if score >= 62.0:
		return 4
	if score >= 42.0:
		return 3
	if score >= 22.0:
		return 2
	return 1


## Colocacao em texto pra HUD e relatorio: "3/6".
##
## Sem o ordinal de proposito - "3o/6" a 320x180 le como "30/6", e o unico
## numero que o jogador olha o tempo todo nao pode ser ambiguo.
func position_text() -> String:
	return "%d/%d" % [position, racers]


func summary() -> String:
	var lines: Array[String] = []
	lines.append("%do LUGAR de %d" % [position, racers])
	lines.append("%s" % "*".repeat(stars()))
	if phase == Phase.FINISHED:
		lines.append("tempo           %5.1fs" % finish_time)
	if late:
		lines.append("prazo           ESTOUROU")
	else:
		lines.append("prazo           %5.1fs" % time_left)
	lines.append("estilo          %5.0f" % style)
	lines.append("ultrapassagens  %5d" % overtakes)
	lines.append("corredor        %5d" % near_misses)
	lines.append("rivais no chao  %5d" % rivals_downed)
	lines.append("quedas          %5d" % crashes)
	return "\n".join(lines)
