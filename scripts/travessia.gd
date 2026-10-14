class_name Travessia
extends Node3D
## Quem atravessa a rua: na zebra das transversais, onde a fila esta parada
## no vermelho, e fora da faixa, na avenida, entre os carros.
##
## Quatro de cada cinco atravessam na zebra, que e o que a gente faz quando o
## sinal fecha para o carro. Na avenida o sinal nunca fecha - e o jogador que
## passa -, entao quem atravessa ali e o quinto, o que atravessa onde da: vai
## de faixa em faixa, espera na linha o carro passar e, se um entra na faixa
## dele, pula de volta. Ninguem e atropelado: a moto que vem passa por um
## pulo (`Pessoa`), e o carro, que nao ve gente, nunca encontra ninguem na
## frente.
##
## Pouca gente, de proposito. Uma transversal em tres tem alguem na zebra quando
## o jogador passa, e uma travessia fora da faixa para cada quatro na zebra:
## gente atravessando em todo cruzamento vira enfeite, e enfeite que se repete
## deixa de ser cidade.
##
## Ninguem existe antes de o jogador chegar perto: cada travessia e um ponto da
## pista sorteado na montagem, e a `Pessoa` so nasce a `ANTES` metros dele e
## some quando ele passa. Sem colisor, sem nada que o banco de provas meca, e
## com sorteio proprio, para nao mexer no do mundo.

enum Tipo { ZEBRA, FORA }

## Chance de uma boca de transversal ter alguem na zebra.
const NA_ZEBRA: float = 0.35
## Travessias fora da faixa para cada uma na zebra: o 20% contra 80%.
const FORA_POR_ZEBRA: float = 0.25
## A quantos metros a frente do jogador a travessia comeca, e a quantos
## metros atras ela some. 120 m a 40 m/s e 3 s: da tempo de estar no meio
## quando a moto passa.
const ANTES: float = 120.0
## Fora da faixa nasce mais perto: no meio da avenida, uma faixa leva uns 2 s, e
## nascida a 120 m ela ja tinha chegado do outro lado quando a moto passava.
const ANTES_FORA: float = 70.0
const DEPOIS: float = 30.0
## Mais que isto ao mesmo tempo e a cidade toda atravessando.
const MAX_ATIVAS: int = 4
## Folga de tempo que quem atravessa fora da faixa quer para cruzar uma faixa
## inteira, alem do tempo de andar. E gente com pressa, nao suicida.
const FOLGA: float = 1.0
## Carro chegando em menos que isto na faixa em que ela esta: pula.
const PERIGO: float = 1.1
## Contra moto ela arrisca: so espera a que chega em menos que isto. Esperar a
## moto com a folga do carro era nunca atravessar na frente do jogador, que e
## justamente quem precisa ver - e e para isso que existe o pulo.
const ARRISCA_MOTO: float = 1.2
## Meia largura e meio comprimento de moto, para a conta da faixa livre.
const MOTO := Vector2(0.4, 1.05)


class Evento:
	var tipo: Tipo = Tipo.ZEBRA
	var offset: float = 0.0
	## Lado da avenida da transversal (ZEBRA) ou de onde parte (FORA).
	var lado: float = 1.0
	var gente: Array[Pessoa] = []
	var ativo: bool = false
	var feito: bool = false
	## FORA: as linhas onde se espera, em lateral, e em qual delas esta.
	var linhas: Array[float] = []
	var na_linha: int = 0
	var indo: bool = false


## Untyped de proposito, como no `TrafficCar`: o `World` ja conhece a
## `Travessia`, e tipar a volta fecharia um ciclo entre os dois.
var world: Node
var track: RoadTrack
var eventos: Array[Evento] = []
var _rng := RandomNumberGenerator.new()
var _ultimo_offset: float = -INF


func setup(a_world: Node, a_track: RoadTrack, semente: int) -> void:
	world = a_world
	track = a_track
	_rng.seed = semente
	eventos = planejar(track, _rng)


## Onde vai haver travessia, na ordem da pista. Separado para o teste contar.
static func planejar(a_track: RoadTrack, rng: RandomNumberGenerator) -> Array[Evento]:
	var lista: Array[Evento] = []
	var zebras := 0
	for c in a_track.cruzamentos:
		for lado: float in [-1.0, 1.0]:
			if not (c.y == Cidade.LADO_AMBOS or c.y == lado):
				continue
			if rng.randf() >= NA_ZEBRA:
				continue
			var e := Evento.new()
			e.tipo = Tipo.ZEBRA
			e.offset = c.x
			e.lado = lado
			lista.append(e)
			zebras += 1
	var fora := roundi(zebras * FORA_POR_ZEBRA)
	var tentativas := 0
	while fora > 0 and tentativas < 200:
		tentativas += 1
		var o := rng.randf_range(80.0, a_track.length - 80.0)
		# Longe da zebra e da boca da rua: fora da faixa e fora da faixa.
		var perto := false
		for c in a_track.cruzamentos:
			if absf(o - c.x) < 25.0:
				perto = true
		if perto:
			continue
		var e := Evento.new()
		e.tipo = Tipo.FORA
		e.offset = o
		e.lado = -1.0 if rng.randf() < 0.5 else 1.0
		lista.append(e)
		fora -= 1
	lista.sort_custom(func(a: Evento, b: Evento) -> bool: return a.offset < b.offset)
	return lista


## Esquece quem estava atravessando: a corrida recomecou.
func reiniciar() -> void:
	for e in eventos:
		_some(e)
		e.feito = false
	_ultimo_offset = -INF


func _physics_process(_delta: float) -> void:
	if world == null or track == null:
		return
	var jogador: PlayerBike = world.get("player")
	if jogador == null:
		return
	var aqui := jogador.track_offset
	# Voltou para tras (o banco de provas reposiciona a moto): recomeca.
	if aqui < _ultimo_offset - 50.0:
		reiniciar()
	_ultimo_offset = aqui
	var ativas := 0
	for e in eventos:
		if e.ativo:
			ativas += 1
	for e in eventos:
		if e.ativo:
			if aqui > e.offset + DEPOIS:
				_some(e)
				e.feito = true
			elif e.tipo == Tipo.FORA:
				_conduz(e)
		elif not e.feito and ativas < MAX_ATIVAS:
			var antes := ANTES_FORA if e.tipo == Tipo.FORA else ANTES
			if aqui >= e.offset - antes and aqui < e.offset - 20.0:
				_comeca(e)
				ativas += 1


func _some(e: Evento) -> void:
	for p in e.gente:
		p.queue_free()
	e.gente.clear()
	e.ativo = false


func _comeca(e: Evento) -> void:
	e.ativo = true
	if e.tipo == Tipo.ZEBRA:
		_comeca_zebra(e)
	else:
		_comeca_fora(e)


func _nova() -> Pessoa:
	var p := Pessoa.new()
	add_child(p)
	p.sortear(_rng)
	p.vestir(Pedestres.CAMISAS[_rng.randi_range(0, Pedestres.CAMISAS.size() - 1)])
	return p


## Atravessa a zebra da transversal, da esquina de um lado a do outro, e segue
## um pouco pela calcada. A geometria e a do `Cidade._monta_ruas`: a zebra fica
## a `ZEBRA_ESQUINA` do asfalto da avenida, e a rua 9 cm acima da calcada.
func _comeca_zebra(e: Evento) -> void:
	var meio := Cidade.RUA_LARGURA * 0.5
	var beira := RoadTrack.half_width() * e.lado
	var a := track.point(e.offset - meio, beira)
	var b := track.point(e.offset + meio, beira)
	var d := track.sample_basis(e.offset).x * e.lado
	d.y = 0.0
	d = d.normalized()
	var r := (b - a).normalized()
	var acima := Vector3.UP * 0.09
	var quantos := 2 if _rng.randf() < 0.3 else 1
	for i in quantos:
		# Lado a lado na faixa, ou um atras do outro.
		var fundo := RoadTrack.ZEBRA_ESQUINA + RoadTrack.ZEBRA_COMPRIMENTO * 0.5
		fundo += _rng.randf_range(-1.2, 1.2)
		var pontos := PackedVector3Array(
			[
				a + d * fundo - r * 1.4,
				a + d * fundo + acima,
				b + d * fundo + acima,
				b + d * fundo + r * 1.4,
			]
		)
		if _rng.randf() < 0.5:
			pontos.reverse()
		# Do outro lado, segue pela calcada da transversal, para a esquina.
		var fim := pontos[pontos.size() - 1]
		pontos.append(fim + (fim - pontos[pontos.size() - 2]).normalized() * 5.6)
		# Ja no meio do caminho: quando o jogador chega, ela esta na rua.
		var inicio := _rng.randf_range(0.0, 0.55)
		var p := _nova()
		_poe_no_caminho(p, pontos, inicio)
		e.gente.append(p)


## Coloca `p` a fracao `inicio` do comprimento de `pontos` e manda seguir.
func _poe_no_caminho(p: Pessoa, pontos: PackedVector3Array, inicio: float) -> void:
	var total := 0.0
	for i in pontos.size() - 1:
		total += pontos[i].distance_to(pontos[i + 1])
	var falta := total * inicio
	var i := 0
	var lugar := pontos[0]
	while i < pontos.size() - 1:
		var trecho := pontos[i].distance_to(pontos[i + 1])
		if falta <= trecho:
			lugar = pontos[i].lerp(pontos[i + 1], falta / maxf(trecho, 0.001))
			break
		falta -= trecho
		i += 1
	var d := pontos[mini(i + 1, pontos.size() - 1)] - lugar
	p.colocar(lugar, atan2(-d.x, -d.z))
	p.ir(pontos.slice(i + 1))


## Fora da faixa, na avenida: as linhas de espera sao a beira da calcada de
## onde sai, as divisas de faixa e a calcada do outro lado. Comeca ja numa
## das divisas, no meio da avenida, e quem conduz daqui
## em diante e o `_conduz`.
func _comeca_fora(e: Evento) -> void:
	var meia := RoadTrack.half_width()
	e.linhas.clear()
	e.linhas.append(e.lado * (meia + 0.35))
	# Da divisa mais perto de onde sai para a mais longe: com o sinal do lado,
	# a mesma conta serve para os dois.
	for i in range(RoadTrack.LANE_COUNT - 1, 0, -1):
		e.linhas.append(e.lado * (RoadTrack.lane_center(i) - RoadTrack.LANE_WIDTH * 0.5))
	e.linhas.append(-e.lado * (meia + 1.2))
	# Carro encostado bem ali e parede: anda um pouco ate achar o vao.
	for _i in 6:
		if _encostado_em(e.offset):
			e.offset += 7.0
	# Ja na avenida, numa das divisas de faixa: e o que se ve chegando.
	e.na_linha = _rng.randi_range(1, RoadTrack.LANE_COUNT - 1)
	e.indo = false
	var p := _nova()
	var aqui := track.point(e.offset, e.linhas[e.na_linha])
	var proxima := track.point(e.offset, e.linhas[e.na_linha + 1])
	var d := proxima - aqui
	p.colocar(aqui, atan2(-d.x, -d.z))
	e.gente.append(p)


func _encostado_em(o: float) -> bool:
	for car: TrafficCar in world.get("traffic"):
		if car.parked and absf(car.offset - o) < car.meio_comprimento() + 2.0:
			return true
	return false


## Um passo de quem atravessa fora da faixa: espera na linha a faixa da frente
## abrir, cruza, e pula de volta se um carro entra nela.
func _conduz(e: Evento) -> void:
	if e.gente.is_empty():
		return
	var p := e.gente[0]
	if p.estado == Pessoa.Estado.SUSTO or e.na_linha >= e.linhas.size() - 1:
		return
	var de := e.linhas[e.na_linha]
	var para := e.linhas[e.na_linha + 1]
	if p.estado == Pessoa.Estado.ANDANDO and e.indo:
		var lateral := _lateral_de(p, e.offset)
		var feito := absf(lateral - de) / maxf(absf(para - de), 0.01)
		if not _faixa_livre(e.offset, minf(de, para), maxf(de, para), PERIGO):
			# Mais perto de onde saiu, volta; ja passou da metade, corre para a
			# frente. Os dois sao um pulo, de frente para o carro.
			var volta := feito < 0.5
			e.indo = false
			if not volta:
				e.na_linha += 1
			p.pular_para(track.point(e.offset, de if volta else para))
		return
	if p.estado != Pessoa.Estado.PARADA:
		return
	if e.indo:
		# Chegou na linha seguinte.
		e.indo = false
		e.na_linha += 1
		if e.na_linha >= e.linhas.size() - 1:
			# Do outro lado: segue pela calcada.
			var adiante := e.offset + (6.0 if _rng.randf() < 0.5 else -6.0)
			p.ir(PackedVector3Array([track.point(adiante, e.linhas[e.na_linha])]))
		return
	var tempo := absf(para - de) / p.velocidade + FOLGA
	var alvo := track.point(e.offset, para)
	if _faixa_livre(e.offset, minf(de, para), maxf(de, para), tempo):
		e.indo = true
		p.ir(PackedVector3Array([alvo]))
	else:
		p.esperar(alvo)


func _lateral_de(p: Pessoa, o: float) -> float:
	return (p.position - track.sample_position(o)).dot(track.sample_basis(o).x)


## Nenhum veiculo vai passar no trecho `[de, ate]` de lateral, na altura `o`
## da pista, nos proximos `tempo` segundos. Todo mundo anda no sentido da
## pista, entao so quem vem de tras importa.
func _faixa_livre(o: float, de: float, ate: float, tempo: float) -> bool:
	for car: TrafficCar in world.get("traffic"):
		if not _livre_de(
			o,
			de,
			ate,
			tempo,
			car.offset,
			car.lateral,
			car.speed,
			car.meia_largura(),
			car.meio_comprimento()
		):
			return false
	var jogador: PlayerBike = world.get("player")
	var tempo_moto := minf(tempo, ARRISCA_MOTO)
	if not _livre_de(
		o,
		de,
		ate,
		tempo_moto,
		jogador.track_offset,
		jogador.track_lateral,
		jogador.speed,
		MOTO.x,
		MOTO.y
	):
		return false
	for rival: RivalBike in world.get("rivals"):
		if not _livre_de(
			o, de, ate, tempo_moto, rival.offset, rival.lateral, rival.speed, MOTO.x, MOTO.y
		):
			return false
	return true


static func _livre_de(
	o: float,
	de: float,
	ate: float,
	tempo: float,
	offset: float,
	lateral: float,
	speed: float,
	meia_largura: float,
	meio_comprimento: float
) -> bool:
	# A pessoa tem uns 30 cm de cada lado.
	if lateral + meia_largura < de + 0.3 or lateral - meia_largura > ate - 0.3:
		return true
	if offset - meio_comprimento > o + 0.6:
		return true
	var frente := offset + meio_comprimento
	if frente > o - 0.6:
		return false
	return (o - 0.6 - frente) / maxf(speed, 0.1) >= tempo
