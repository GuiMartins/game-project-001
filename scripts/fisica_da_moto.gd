class_name FisicaDaMoto
extends RefCounted
## O que muda na fisica de uma moto para outra: so a mola da inclinacao.
##
## Multiplicadores sobre o `BikeTuning`, e nao valores absolutos: o F3 continua
## valendo para as tres motos. Com numero absoluto por moto, mexer no
## `lean_freq` so mudaria a CG, e quem testasse na PCX ia achar o slider morto.
##
## Os multiplicadores saem da ficha tecnica (`FichaDaMoto`), comparada com a da
## CG: e a moto em que a mola da V05 foi afinada, e a do banco de provas, entao
## ela da 1 em tudo. Velocidade, aceleracao e curva sao as mesmas nas tres, de
## proposito (V05a do backlog visual): a escolha da moto muda o jeito de trocar
## de lado no corredor, nao quem ganha a corrida.

## Entregador de capacete, roupa e bag. Entra na massa que a moto tem de deitar:
## sem ele, a XRE pesaria 26% a mais que a CG, e com ele pesa 16%, que e o que
## se sente em cima dela.
const PILOTO_KG: float = 80.0
## Faixa da agilidade. Embaixo, uma moto lenta assim ja nao fecha o corredor a
## tempo. Em cima, o amortecimento da volta cairia abaixo de 0,3 (0,45 / 1,5),
## onde a moto fica quicando, e a mola do F3 no teto (40 rad/s) chegaria a
## 60 rad/s, 1 a 60 Hz, perto do limite do Euler (2).
const AGILIDADE_MIN: float = 0.65
const AGILIDADE_MAX: float = 1.5

## Multiplica `lean_freq`: quao rapido a moto deita.
var deitar: float = 1.0
## Multiplica `lean_return_freq`: quao rapido ela levanta.
var voltar: float = 1.0
## Multiplica `lean_return_damping`. Abaixo de 1 passa mais do zero na volta.
var amortecer: float = 1.0


## A fisica do `modelo` (um `Entregador.Modelo`). Moto sem ficha anda como a CG.
static func de(modelo: int) -> FisicaDaMoto:
	var ficha := FichaDaMoto.de(modelo)
	if ficha == null:
		return FisicaDaMoto.new()
	return da_ficha(ficha)


## A fisica de uma moto pela ficha dela.
static func da_ficha(ficha: FichaDaMoto) -> FisicaDaMoto:
	var fisica := FisicaDaMoto.new()
	var a := agilidade(ficha)
	# Um numero so move os tres, e e isso que deixa moto nova nascer certa: o
	# que faz a moto deitar rapido (pouca inercia) e o mesmo que a faz levantar
	# rapido e passar do zero, porque nada a segura em pe.
	fisica.deitar = a
	fisica.voltar = a
	fisica.amortecer = 1.0 / a
	return fisica


## Quao mais rapido que a CG a moto troca de lado: 1 e a CG, 1,2 leva 1/1,2 do
## tempo dela. O tempo de deitar cresce com quatro coisas da ficha:
##
## - **Altura do banco**, na raiz: pendulo invertido, que cai em sqrt(h/g).
## - **Massa com o piloto**, na raiz: o piloto empurra o guidao com a mesma
##   forca em qualquer moto, e mais massa e mais inercia para a mesma forca.
## - **Diametro das rodas**, direto: o giroscopio da roda, que segura a moto
##   em pe, cresce com o raio a mesma velocidade. E o que mais separa a PCX
##   (aro 14 e 13) da XRE (aro 21 e 18).
## - **Entre-eixos**, direto: para deitar, a moto contra-esterca e esconde a
##   frente debaixo dela, e entre-eixos longo e braco longo.
##
## E modelo de jogo, nao de dinamica veicular: cada termo tem o sentido certo e
## um expoente simples. A prova e que a PCX sai 1,21 e a XRE 0,76, onde a mao
## tinha posto 1,3 e 0,8 so de olho na moto.
static func agilidade(ficha: FichaDaMoto) -> float:
	var cg := FichaDaMoto.de(Entregador.Modelo.CG_160)
	var tempo := (
		sqrt(ficha.banco_mm / cg.banco_mm)
		* sqrt((ficha.peso_kg + PILOTO_KG) / (cg.peso_kg + PILOTO_KG))
		* (ficha.rodas_mm() / cg.rodas_mm())
		* (ficha.entre_eixos_mm / cg.entre_eixos_mm)
	)
	return clampf(1.0 / tempo, AGILIDADE_MIN, AGILIDADE_MAX)


## Varre o caminho deste passo: em alta velocidade o centro pode passar inteiro
## por cima do obstaculo entre dois quadros. O tombo ocupa uma faixa baixa e
## larga, em vez da caixa vertical de quem ainda esta pilotando.
static func impulso_de_rampa(moto: Node3D, deslocamento: Vector3, velocidade: float) -> float:
	if velocidade < 3.0:
		return 0.0
	for outra: Node3D in moto.get_tree().get_nodes_in_group(Pessoa.GRUPO_MOTOS):
		if outra == moto or not (outra is PlayerBike or outra is RivalBike):
			continue
		var caida: bool = (
			outra.state == PlayerBike.State.CRASHED
			if outra is PlayerBike
			else outra.state == RivalBike.State.DOWN
		)
		if not caida:
			continue
		var inicio := outra.to_local(moto.global_position)
		var fim := outra.to_local(moto.global_position + deslocamento)
		var ponto := Geometry2D.get_closest_point_to_segment(
			Vector2.ZERO, Vector2(inicio.x, inicio.z), Vector2(fim.x, fim.z)
		)
		if absf(ponto.x) > 1.15 or absf(ponto.y) > 1.4 or absf(inicio.y) > 0.65:
			continue
		# Garante tempo para ler o atropelo; nao acumula centenas de segundos
		# quando varios corredores passam juntos pelo mesmo tombo.
		outra.state_timer = minf(maxf(outra.state_timer, 1.5) + minf(velocidade * 0.02, 1.0), 6.0)
		# Com g=26, o teto de 5 m/s sobe menos de meio metro.
		return minf(velocidade * 0.12, 5.0)
	return 0.0
