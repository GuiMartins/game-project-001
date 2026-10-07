class_name BikeTuning
extends Resource
## Todas as constantes de "feel" da moto num lugar so.
##
## O objetivo do prototipo e descobrir os valores certos aqui. O painel de
## tuning (F3) edita este recurso ao vivo e salva em user://tuning.tres, entao
## uma sessao de ajuste sobrevive ao fechar o jogo.

const SAVE_PATH: String = "user://tuning.tres"

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
## Velocidade de APROXIMACAO (m/s) abaixo da qual nunca capota, so quica.
##
## E a diferenca entre as duas velocidades, nao a da moto: a 100 km/h na
## traseira de um carro a 25 km/h voce chega a 75, e nao a 100. Ja foi a
## velocidade da moto, 16 m/s, e com ela toda encostada no transito acima de
## 58 km/h derrubava - quase toda batida. 22 m/s sao 80 km/h de diferenca: so
## cai quem chega muito mais rapido que o que esta na frente.
@export_range(2.0, 40.0, 0.5) var crash_min_speed: float = 22.0
## Abaixo desta fracao da moto em cima da lataria, a batida e na quina.
##
## Pegar o canto de um carro desvia a moto em vez de derrubar. A caixa de
## colisao da a normal da FACE que entrou, e na quina essa face costuma ser a
## traseira: sem esta regra, raspar o para-choque com o guidao valia o mesmo que
## entrar de frente no porta-malas. Fracao, e nao metros: o poste e mais fino
## que a moto, e em metros todo poste seria quina.
@export_range(0.0, 1.0, 0.05) var corner_fraction: float = 0.6
## Maior desvio (graus) que uma quina da na moto, quando ela chega a
## `crash_min_speed`. Parece pouco, mas a assistencia de alinhamento leva quase
## um segundo para desfazer: a 126 km/h, 8 graus sao uns 4 m de lado - uma
## faixa. Com 18 eram quase 9, e a quina jogava a moto em cima do carro do lado.
@export_range(0.0, 45.0, 1.0) var corner_deflect: float = 8.0
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
## Empurrao lateral aplicado no alvo, em m/s. Vale pros dois lados: no rival
## vira 0,14 s disso de deslocamento (15 -> 2,1 m, dois tercos de faixa), e no
## jogador vira velocidade lateral. Era 7,5, e o 1 m que isso dava so jogava o
## rival no carro se o carro ja estivesse encostado nele - o golpe do Road Rash
## e empurrar alguem do corredor pra dentro da faixa do lado.
@export_range(1.0, 20.0, 0.25) var punch_shove: float = 15.0
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
## Era 16: abrir a lente encolhe a moto, e de 50 a 66 graus ela perdia mais de
## um quarto do tamanho no talo - lia como a camera se afastando. O video de
## referencia nao encolhe nada a 128 km/h (docs/REFERENCIA_VIDEO.md); 8 deixa
## um pingo de velocidade na borda da tela e a moto do mesmo tamanho a olho.
@export_range(0.0, 40.0, 0.5) var cam_fov_speed_gain: float = 8.0
## Metros a mais de distancia na velocidade maxima. Zero = distancia fixa.
## Existe para testar no F3 um respiro pequeno na aceleracao; o atraso de
## posicao que fazia isso sozinho chegava a 7 m e foi o que se tirou.
@export_range(0.0, 3.0, 0.1) var cam_recuo: float = 0.0
## Quanto da inclinacao da moto a camera copia (0 = fixa, 1 = acompanha tudo).
## Era 0.3: a 38 graus de inclinacao a camera girava 11, e na entrada de curva
## isso pesava mais que a propria curva.
@export_range(0.0, 1.0, 0.02) var cam_lean_follow: float = 0.2
## Quao rapido o giro da camera alcanca a inclinacao da moto (1/s).
##
## A moto inclina na velocidade do polegar; a camera nao pode. Copiando direto,
## cada correcao pequena de trajetoria - que inclina a moto pra la e pra ca
## varias vezes por segundo - virava a tela balancando. Atrasada, ela deixa
## passar a curva de verdade, que segura a inclinacao, e engole o tremor: a
## 2.5, uma correcao de 3 Hz chega na camera com um oitavo da amplitude.
@export_range(0.5, 20.0, 0.25) var cam_lean_rate: float = 2.5

## --- Camera garupa --------------------------------------------------------
## O modo GARUPA do F2: um cinegrafista em outra moto, colado no jogador. Os
## numeros de partida e o porque de cada um estao em
## docs/REFERENCIA_CAMERA_GARUPA.md; a medida que decide e jogar.
@export_group("Camera garupa")

## Da lente ao contato do pneu traseiro, em metros de pista. No video e 1 m; a
## tela aqui e deitada, e a 1 m com 80 graus de FOV o capacete sai pelo topo.
@export_range(0.8, 4.0, 0.05) var garupa_distancia: float = 1.5
## Mais perto que isto, nunca - nem freando no talo. A camera dentro da moto e
## o erro mais visivel deste modo, e o video de referencia comete.
@export_range(0.5, 2.0, 0.05) var garupa_distancia_min: float = 0.9
## Altura da lente sobre o chao embaixo dela, em metros. Na cintura do piloto:
## poe o horizonte a ~37% do topo, como no video.
@export_range(0.6, 2.0, 0.05) var garupa_altura: float = 1.25
## Altura da mira sobre o contato traseiro, em metros: o banco. Mais alto sobe
## o piloto na tela e desce o horizonte.
@export_range(0.4, 1.4, 0.05) var garupa_mira_altura: float = 0.85
## FOV vertical, em graus, fixo. Da ~112 na horizontal em 16:9. Sem abrir com
## a velocidade: aqui ela vem da proximidade, e FOV abrindo a um metro do
## piloto encolhe ele justo quando deveria pesar.
@export_range(60.0, 100.0, 1.0) var garupa_fov: float = 80.0
## Quanto a camera fica de lado, em metros: tres quartos a ~21 graus. E o que
## deixa o fundo da rua aparecer ao lado do piloto. Zero = sempre atras.
@export_range(0.0, 1.5, 0.05) var garupa_lado: float = 0.7
## Aceleracao do cinegrafista, m/s^2. Menor que a do jogador (16): no talo ele
## fica para tras e volta pela aproximacao - e o que faz a distancia respirar.
@export_range(4.0, 30.0, 0.5) var garupa_acel: float = 10.0
## Freio do cinegrafista, m/s^2. Menor que o do jogador (30): na freada a
## camera encosta, ate a trava de `garupa_distancia_min`.
@export_range(5.0, 40.0, 0.5) var garupa_freio: float = 20.0
## Velocidade maxima de fechamento, m/s. Faz a aproximacao lenta da abertura
## do video (~1,2 m/s ali) em vez de um teletransporte.
@export_range(0.5, 10.0, 0.25) var garupa_aproximacao: float = 2.5
## Fracao da inclinacao do jogador que vai para o horizonte. A 38 graus de
## inclinacao da ~11 de giro, os picos de 10-15 graus do video. E maior que o
## `cam_lean_follow` da perseguicao (0,2): aqui a camera e de gente, e gira.
@export_range(0.0, 0.6, 0.02) var garupa_giro: float = 0.3
## Tremor eficaz, em graus, de banda (2-12 Hz). O video tem 0,5-0,8; a 0,6
## sao 2-3 pixels de tremor continuo, e isso cansa antes de vender numa
## corrida de minutos. O valor do video fica perto do teto do slider. Zero
## desliga, para quem enjoa.
@export_range(0.0, 1.0, 0.05) var garupa_tremor: float = 0.3

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
