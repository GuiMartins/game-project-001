extends Resource
class_name BikeTuning
## Todas as constantes de "feel" da moto num lugar so.
##
## O objetivo do prototipo e descobrir os valores certos aqui. O painel de
## tuning (F3) edita este recurso ao vivo e salva em user://tuning.tres, entao
## uma sessao de ajuste sobrevive ao fechar o jogo.

## --- Velocidade -----------------------------------------------------------
@export_group("Velocidade")

## Velocidade maxima sem boost, em m/s. 55 m/s ~ 198 km/h.
@export_range(20.0, 90.0, 0.5) var max_speed: float = 52.0
## Aceleracao base em m/s^2. A aceleracao real cai conforme a velocidade sobe.
@export_range(2.0, 40.0, 0.5) var accel: float = 16.0
## Expoente da curva de aceleracao. >1 = empurrao forte embaixo, morre em cima.
@export_range(0.5, 4.0, 0.05) var accel_falloff: float = 1.25
## Desaceleracao do freio em m/s^2.
@export_range(5.0, 60.0, 0.5) var brake: float = 30.0
## Freio motor (soltar o acelerador) em m/s^2, constante.
@export_range(0.0, 20.0, 0.25) var engine_brake: float = 3.0
## Arrasto quadratico, SO quando o acelerador esta solto.
##
## De proposito ele nao entra com o gas aberto: assim `max_speed` e literalmente
## a velocidade maxima, e nao um numero que interage com o arrasto e vira
## outro. Slider que mente e slider que ninguem consegue ajustar.
@export_range(0.0, 0.02, 0.0005) var drag: float = 0.0015

## Quanto a ladeira puxa, em m/s^2 por 100% de inclinacao.
##
## Sem isto a elevacao e so desenho: a moto sobe uma rampa de 12% no mesmo
## ritmo que anda na reta, e a unica coisa que a ladeira faz e mexer a camera.
## Com isto a subida cobra o gas que voce nao tinha e a descida devolve
## velocidade de graca - que e o que faz escolher a rota de baixo significar
## alguma coisa.
##
## Em 16, uma rampa de 10% tira 1,6 m/s^2 - um decimo da aceleracao da moto,
## sensivel sem transformar ladeira em parede.
@export_range(0.0, 60.0, 0.5) var slope_pull: float = 16.0

## --- Boost / adrenalina ---------------------------------------------------
@export_group("Boost / adrenalina")

## Multiplicador de velocidade maxima com boost ativo.
@export_range(1.0, 1.8, 0.01) var boost_speed_mult: float = 1.28
## Aceleracao extra com boost ativo, em m/s^2.
@export_range(0.0, 30.0, 0.5) var boost_accel: float = 12.0
## Adrenalina gasta por segundo de boost (barra vai de 0 a 100).
@export_range(5.0, 100.0, 1.0) var boost_drain: float = 34.0
## Adrenalina ganha por raspada (near miss) no corredor.
@export_range(1.0, 30.0, 0.5) var boost_gain_near_miss: float = 7.0

## --- Inclinacao e curva ---------------------------------------------------
@export_group("Inclinacao e curva")

## Inclinacao maxima da moto, em graus.
@export_range(10.0, 60.0, 1.0) var max_lean: float = 38.0
## Quao rapido a moto assume a inclinacao pedida (1/s). Baixo = pesada.
@export_range(1.0, 20.0, 0.25) var lean_rate: float = 7.0
## Quao rapido a moto volta pra vertical quando o input solta (1/s).
@export_range(1.0, 20.0, 0.25) var lean_return_rate: float = 9.0
## Guinada maxima em graus/s, na velocidade de melhor agilidade.
@export_range(20.0, 200.0, 1.0) var turn_rate: float = 78.0
## Velocidade (m/s) em que a moto atinge agilidade total. Abaixo disso ela
## responde menos - e o que impede o jogador de "andar de lado" parado.
@export_range(1.0, 30.0, 0.5) var turn_ramp_speed: float = 9.0
## Fracao da agilidade que sobra na velocidade maxima. Baixo = estavel em cima.
@export_range(0.1, 1.0, 0.02) var turn_high_speed_factor: float = 0.42
## Aderencia lateral (1/s). Alto = anda no trilho, baixo = derrapa e escorrega.
@export_range(1.0, 30.0, 0.25) var grip: float = 9.5
## Assistencia que puxa a moto de volta pro sentido da pista (1/s). Zero = so o
## jogador guia. Sem um pingo disso, um curvao a 180 km/h vira briga com o
## controle em vez de briga com o transito - e o transito e o jogo.
@export_range(0.0, 6.0, 0.05) var align_assist: float = 1.15

## --- Impacto --------------------------------------------------------------
@export_group("Impacto")

## Acima deste angulo (graus) entre a moto e a superficie batida, e capotagem.
@export_range(10.0, 80.0, 1.0) var crash_angle: float = 38.0
## Abaixo desta velocidade (m/s) nunca capota, so raspa.
@export_range(2.0, 40.0, 0.5) var crash_min_speed: float = 16.0
## Fracao da velocidade perdida ao raspar em carro/guard-rail.
@export_range(0.0, 1.0, 0.01) var scrape_speed_loss: float = 0.16
## Desaceleracao continua (m/s^2) enquanto raspa no guard-rail.
@export_range(0.0, 40.0, 0.5) var rail_friction: float = 16.0
## Segundos parado depois de capotar.
@export_range(0.5, 5.0, 0.1) var crash_recover_time: float = 1.9

## --- Combate --------------------------------------------------------------
@export_group("Combate")

## Alcance lateral do soco, em metros.
@export_range(0.8, 4.0, 0.05) var punch_range: float = 1.9
## Atraso entre apertar e a hitbox abrir, em segundos.
@export_range(0.0, 0.4, 0.01) var punch_windup: float = 0.09
## Tempo que a hitbox fica aberta, em segundos.
@export_range(0.03, 0.4, 0.01) var punch_active: float = 0.13
## Tempo total ate poder socar de novo, em segundos.
@export_range(0.1, 1.5, 0.05) var punch_cooldown: float = 0.45
## Empurrao lateral aplicado no alvo, em m/s.
@export_range(1.0, 20.0, 0.25) var punch_shove: float = 7.5
## Segundos que o alvo fica sem controle depois de apanhar.
@export_range(0.1, 2.0, 0.05) var punch_stagger: float = 0.7

## --- Camera ---------------------------------------------------------------
@export_group("Camera")

## Distancia da camera atras da moto, em metros.
@export_range(2.0, 14.0, 0.1) var cam_distance: float = 6.4
## Altura da camera, em metros.
@export_range(0.5, 6.0, 0.1) var cam_height: float = 2.25
## Quao rapido a camera persegue a moto (1/s). Baixo = solta, alto = grudada.
@export_range(1.0, 30.0, 0.25) var cam_follow: float = 7.0
## FOV parado, em graus. O texto de arquitetura pede ~50 (lente longa).
@export_range(30.0, 90.0, 1.0) var cam_fov: float = 50.0
## Quantos graus de FOV a mais na velocidade maxima (sensacao de velocidade).
@export_range(0.0, 40.0, 0.5) var cam_fov_speed_gain: float = 16.0
## Quanto da inclinacao da moto a camera copia (0 = fixa, 1 = acompanha tudo).
@export_range(0.0, 1.0, 0.02) var cam_lean_follow: float = 0.3

## --- Calcada ---------------------------------------------------------------
@export_group("Calcada")

## Teto de velocidade na calcada, como fracao da maxima.
##
## A calcada e valvula de escape quando o transito fecha: da pra fugir por ali,
## mas custa tempo. Se o preco for baixo demais ela vira a linha otima e o
## jogador nunca mais entra no transito - que e o jogo. Alto demais e ela vira
## a parede que ja era antes, so que mais longe.
@export_range(0.2, 1.0, 0.01) var sidewalk_speed_factor: float = 0.55

## Quao rapido a moto e puxada pro teto ao subir na calcada, em m/s^2.
## Alto demais vira freada de parede; baixo demais e de graca.
@export_range(1.0, 60.0, 0.5) var sidewalk_drag: float = 22.0


const SAVE_PATH: String = "user://tuning.tres"


static func load_or_default() -> BikeTuning:
	if ResourceLoader.exists(SAVE_PATH):
		var res: Resource = ResourceLoader.load(SAVE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
		if res is BikeTuning:
			return res as BikeTuning
	return BikeTuning.new()


func save() -> void:
	ResourceSaver.save(self, SAVE_PATH)


func reset_to_default() -> void:
	var fresh := BikeTuning.new()
	for prop: Dictionary in get_property_list():
		if prop["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
			set(prop["name"], fresh.get(prop["name"]))
