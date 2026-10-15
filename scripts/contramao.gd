class_name Contramao
extends Node3D
## O transito da mao contraria de uma via expressa: carros vindo de frente,
## do outro lado da mureta. E o que faz a pista ao lado ler como rua - vazia,
## ela era asfalto pintado - e, de noite, o farol vindo de frente e o
## referencial de velocidade mais forte que existe: a diferenca e a soma.
##
## O caminho nao comeca nem acaba no meio do quarteirao. O carro sai do
## predio do fundo da rua da esquina da saida (como de uma garagem), desce a
## rua, vira numa curva na mao contraria, passa a expressa inteira e vira na
## rua da esquina da entrada, ate entrar no predio do fundo dela. Atras da
## fachada ele nao se desenha: e la que ele nasce e some.
##
## Parametrico, como o transito da avenida: cada carro sabe onde esta no
## caminho e nunca se projeta em nada (so o jogador roda fisica). Tem colisor
## da lataria, porque na boca das ruas da esquina a moto alcanca ele. Sai de um
## gerador proprio, e nao do `World`: o transito e os rivais do banco de provas
## saem iguais com ou sem ele.

## Cruzeiro de cada carro, m/s: 40 a 58 km/h, a velocidade de quem vai embora
## da expressa. Contra a moto a 180, a diferenca passa de 230 km/h.
const CRUZEIRO := Vector2(11.0, 16.0)
## O limite na curva da esquina: a 6 m/s, num raio de 6 m
## (`ViaExpressa.ESQUINA_RAIO`), sao 6 m/s2 de lateral.
const NA_CURVA: float = 6.0
## Os mesmos do carro da avenida (`TrafficCar.ACCEL`, `BRAKE`).
const ACELERA: float = 2.2
const FREIO: float = 4.5
## Para-choque a para-choque, parado na fila da curva.
const FOLGA: float = 3.0
## Entre um carro e o seguinte na largada, e na saida da garagem, em metros.
## Com 25 a 60 m sao uns oito por faixa numa expressa de 400 m: rua com
## movimento, e nao engarrafamento - fila parada atras da mureta nao vem de
## frente.
const ESPACO := Vector2(25.0, 60.0)
## De quanto em quanto o caminho e amostrado, em metros de pista.
const PASSO: float = 1.0
## Quanto antes da curva o carro liga a seta.
const SETA_ANTES: float = 20.0
## Quanto o caminho entra no predio do fundo da rua, alem da fachada. A
## fachada fica 2 m antes do fim da rua (`Cidade._monta_ruas`); o carro nasce
## 7 m atras dela, e o onibus, de 12 m, ainda cabe inteiro la dentro.
const NA_GARAGEM: float = 5.0
const FACHADA: float = NA_GARAGEM + 2.0
## Sem moto a menos disto do caminho, os carros andam mas nao se desenham nem
## se posam. Sao uns trinta carros por corrida, cada um com o farol dele, e
## de noite isso custava 1 ms no p50 e 3 no p95 do `fps --hora 1` com a
## expressa do outro lado da cidade. A 300 m o carro e um ou dois pixels
## dentro da neblina.
const LONGE: float = 300.0

var track: RoadTrack
## `[de, ate, lado]`, como o `RoadTrack.expressas`.
var expressa: Vector3
var semente: int = 0

var _rng := RandomNumberGenerator.new()
var _caminhos: Array[Caminho] = []
var _carros: Array[Veiculo] = []
var _garagem: Array[Veiculo] = []
var _proximo: float = 0.0
## Ate aqui (em `s`, igual nas duas faixas) os carros sao uma fila so: a rua
## da saida tem uma faixa para quem desce, e a mao contraria tem duas.
var _divide: float = 0.0
## Daqui para o fim (em metros que faltam) e a fila unica da rua da entrada.
var _junta: float = 0.0
var _perto: bool = true


## Um caminho, de uma garagem a outra, pela faixa `faixa` da mao contraria.
class Caminho:
	var pontos := PackedVector3Array()
	var normais := PackedVector3Array()
	## O limite de velocidade em cada ponto.
	var limite := PackedFloat32Array()
	## A distancia, ao longo do caminho, de cada ponto.
	var s := PackedFloat32Array()
	var comprimento: float = 0.0
	## Em que trecho do caminho comecam a curva da saida e a da entrada.
	var curva_saida: float = 0.0
	var curva_entrada: float = 0.0

	## Posicao, normal e frente em `d` metros do caminho.
	func em(d: float) -> Transform3D:
		var i := clampi(s.bsearch(d) - 1, 0, pontos.size() - 2)
		var t := clampf((d - s[i]) / maxf(s[i + 1] - s[i], 0.001), 0.0, 1.0)
		var p := pontos[i].lerp(pontos[i + 1], t)
		var frente := (pontos[i + 1] - pontos[i]).normalized()
		var cima := normais[i].lerp(normais[i + 1], t).normalized()
		return Transform3D(Basis.looking_at(frente, cima), p)

	## O menor limite de velocidade dos proximos metros, ja descontada a
	## freada ate ele.
	func limite_a_frente(d: float, alcance: float) -> float:
		var i := clampi(s.bsearch(d), 0, pontos.size() - 1)
		var melhor := INF
		while i < pontos.size() and s[i] < d + alcance:
			if limite[i] < INF:
				melhor = minf(melhor, sqrt(limite[i] * limite[i] + 2.0 * FREIO * (s[i] - d)))
			i += 1
		return melhor


class Veiculo:
	var corpo: AnimatableBody3D
	var carro: Carro
	var faixa: int = 0
	## Metros andados no caminho.
	var s: float = 0.0
	var v: float = 0.0
	var cruzeiro: float = 0.0
	var meio: float = 2.2


## A mao contraria da `expressa` de `track`, com o transito dela.
static func criar(a_track: RoadTrack, a_expressa: Vector3, a_semente: int) -> Contramao:
	var c := Contramao.new()
	c.name = "Contramao"
	c.track = a_track
	c.expressa = a_expressa
	c.semente = a_semente
	return c


## O eixo de cada faixa da mao contraria, em lateral sem sinal: a de dentro,
## colada nos pilares, e a de fora, colada no muro baixo.
static func eixos() -> Array[float]:
	var x := RoadTrack.sidewalk_limit() + ViaExpressa.PISTA_AO_LADO.x
	var faixa := (ViaExpressa.PISTA_AO_LADO.y - ViaExpressa.PISTA_AO_LADO.x) * 0.5
	return [x + faixa * 0.5, x + faixa * 1.5]


func _ready() -> void:
	add_to_group(&"contramao")
	_monta_caminhos()
	reiniciar()


## Largada nova, transito novo: a mesma semente poe os mesmos carros nos
## mesmos lugares, como o resto do mundo na largada.
func reiniciar() -> void:
	_rng.seed = semente
	for v in _carros:
		_guarda(v)
	_carros.clear()
	for faixa in _caminhos.size():
		var c := _caminhos[faixa]
		var s := _divide + _rng.randf_range(0.0, ESPACO.y)
		while s < c.comprimento - _junta:
			_solta(faixa, s)
			s += _rng.randf_range(ESPACO.x, ESPACO.y)
	_proximo = _rng.randf_range(ESPACO.x, ESPACO.y)
	_posa(0.0)


func _physics_process(delta: float) -> void:
	_perto = _moto_perto()
	visible = _perto
	for v in _carros:
		var c := _caminhos[v.faixa]
		var alvo := minf(v.cruzeiro, c.limite_a_frente(v.s, 25.0))
		var vao := _vao(v)
		if vao < INF:
			alvo = minf(alvo, sqrt(maxf(0.0, 2.0 * FREIO * (vao - FOLGA))))
		v.v = minf(v.v + ACELERA * delta, alvo)
		v.s += v.v * delta
	# Quem chegou na garagem do fim sai; quem esta na do comeco espera vaga.
	for v: Veiculo in _carros.duplicate():
		if v.s >= _caminhos[v.faixa].comprimento:
			_carros.erase(v)
			_guarda(v)
	var ultimo := INF
	for v in _carros:
		ultimo = minf(ultimo, v.s)
	if ultimo > _proximo:
		_solta(_rng.randi_range(0, _caminhos.size() - 1), 0.0)
		_proximo = _rng.randf_range(ESPACO.x, ESPACO.y)
	_posa(delta)


## Metros livres ate a lataria do carro da frente, ou INF. Na rua da saida e na
## da entrada a fila e uma so, das duas faixas; na expressa, cada faixa a sua.
func _vao(v: Veiculo) -> float:
	var falta := _caminhos[v.faixa].comprimento - v.s
	var melhor := INF
	for o in _carros:
		if o == v:
			continue
		var d := INF
		if v.s < _divide:
			if o.s > v.s and (o.s < _divide or o.faixa == v.faixa):
				d = o.s - v.s
		else:
			var falta_o := _caminhos[o.faixa].comprimento - o.s
			if falta < _junta:
				if falta_o < falta and (falta_o < _junta or o.faixa == v.faixa):
					d = falta - falta_o
			elif o.faixa == v.faixa and o.s > v.s:
				d = o.s - v.s
		melhor = minf(melhor, d - v.meio - o.meio)
	return melhor


func _posa(delta: float) -> void:
	for v in _carros:
		var c := _caminhos[v.faixa]
		# Aparece quando o para-choque passa da fachada, e some quando a
		# traseira entra nela: o resto do tempo, o predio tapa.
		var dentro := v.s > FACHADA - v.meio and v.s < c.comprimento - FACHADA + v.meio
		v.corpo.visible = dentro
		v.corpo.global_transform = c.em(v.s)
		if delta > 0.0 and _perto:
			v.carro.atualizar(delta, v.v, 0.0, false, _seta(v, c))


## A seta acende antes de cada curva, para o lado dela. As duas curvas viram
## para o mesmo lado: quem vem de frente na expressa tem a rua a direita
## quando a expressa esta a esquerda da moto.
func _seta(v: Veiculo, c: Caminho) -> int:
	var antes_saida := v.s > c.curva_saida - SETA_ANTES and v.s < c.curva_saida + 5.0
	var antes_entrada := v.s > c.curva_entrada - SETA_ANTES and v.s < c.curva_entrada + 5.0
	if antes_saida or antes_entrada:
		return int(-expressa.z)
	return 0


func _solta(faixa: int, s: float) -> void:
	var v: Veiculo
	if _garagem.is_empty():
		v = _novo()
	else:
		v = _garagem.pop_back()
	v.faixa = faixa
	v.s = s
	v.cruzeiro = _rng.randf_range(CRUZEIRO.x, CRUZEIRO.y)
	v.v = v.cruzeiro if s > 0.0 else NA_CURVA
	(v.corpo.get_child(1) as CollisionShape3D).set_deferred("disabled", false)
	v.corpo.global_transform = _caminhos[faixa].em(s)
	v.carro.reiniciar()
	_carros.append(v)


func _guarda(v: Veiculo) -> void:
	v.corpo.visible = false
	(v.corpo.get_child(1) as CollisionShape3D).set_deferred("disabled", true)
	_garagem.append(v)


## Carro novo, da frota da avenida. O modelo e as cores saem de um gerador
## que so ele usa: o da largada nao muda com quantos carros ja foram feitos.
func _novo() -> Veiculo:
	var v := Veiculo.new()
	v.corpo = AnimatableBody3D.new()
	v.corpo.sync_to_physics = true
	v.corpo.collision_layer = Layers.WORLD
	v.corpo.collision_mask = 0
	add_child(v.corpo)
	v.carro = Carro.new()
	v.carro.name = "Carro"
	v.corpo.add_child(v.carro)
	var visual := RandomNumberGenerator.new()
	visual.seed = hash([semente, _carros.size() + _garagem.size(), TrafficCar.SEMENTE_VISUAL])
	var sorteio := visual.randf()
	var modelo := 0
	var soma := 0.0
	for i in TrafficCar.FROTA.size():
		soma += TrafficCar.FROTA[i]
		if sorteio < soma:
			modelo = i
			break
	v.carro.montar(modelo as Carro.Modelo, visual)
	var caixa := v.carro.caixa()
	v.meio = caixa.size.z * 0.5
	var forma := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = caixa.size
	forma.shape = box
	forma.position = caixa.get_center()
	v.corpo.add_child(forma)
	return v


## Se alguma moto, jogador ou rival, esta a menos de `LONGE` do caminho. Pela
## moto, e nao pela camera: a prova poe a camera no lugar so depois dos passos
## de fisica, e a moto ja esta la desde a largada.
func _moto_perto() -> bool:
	var c := _caminhos[0]
	for no in get_tree().get_nodes_in_group(Pessoa.GRUPO_MOTOS):
		var onde := (no as Node3D).global_position
		var i := 0
		while i < c.pontos.size():
			if c.pontos[i].distance_to(onde) < LONGE:
				return true
			i += 20
	return false


## As duas faixas, cada uma de uma garagem a outra. Tudo em `(offset, lateral
## sem sinal)`, como a `ViaExpressa`: o caminho segue a curva e a rampa da
## pista sem saber delas, e o lado so entra no fim, no sinal da lateral.
func _monta_caminhos() -> void:
	var de := expressa.x
	var ate := expressa.y
	var lado := expressa.z
	var meia_rua := Cidade.RUA_LARGURA * 0.5
	var r := ViaExpressa.ESQUINA_RAIO
	# Aqui se anda pela direita. Na rua da saida quem desce para a avenida
	# esta na metade dela do lado de tras da pista se a expressa e a esquerda,
	# e do lado da frente se e a direita; na da entrada, o contrario.
	var desce := ate + meia_rua + meia_rua * 0.5 * lado
	var sobe := de - meia_rua - meia_rua * 0.5 * lado
	var fundo := RoadTrack.half_width() + Cidade.RUA_COMPRIMENTO + NA_GARAGEM
	var faixas := eixos()
	for eixo in faixas:
		var c := Caminho.new()
		var trechos: Array[Array] = []
		trechos.append([_reta(Vector2(desce, fundo), Vector2(desce, eixo + r)), INF])
		var centro := Vector2(desce - r, eixo + r)
		trechos.append([_arco(centro, Vector2(1, 0), Vector2(0, -1)), NA_CURVA])
		trechos.append([_reta(Vector2(desce - r, eixo), Vector2(sobe + r, eixo)), INF])
		centro = Vector2(sobe + r, eixo + r)
		trechos.append([_arco(centro, Vector2(0, -1), Vector2(-1, 0)), NA_CURVA])
		trechos.append([_reta(Vector2(sobe, eixo + r), Vector2(sobe, fundo)), INF])
		var anterior := Vector3.INF
		for k in trechos.size():
			if k == 1:
				c.curva_saida = c.comprimento
			elif k == 3:
				c.curva_entrada = c.comprimento
			var pontos: PackedVector2Array = trechos[k][0]
			var limite: float = trechos[k][1]
			for q in pontos:
				var p := track.point(q.x, q.y * lado) + Vector3.UP * 0.06
				if anterior != Vector3.INF:
					if p.distance_to(anterior) < 0.01:
						continue
					c.comprimento += p.distance_to(anterior)
				anterior = p
				c.pontos.append(p)
				c.normais.append(track.sample_basis(q.x).y)
				c.limite.append(limite)
				c.s.append(c.comprimento)
		_caminhos.append(c)
	# A fila unica vai da garagem ate a faixa de dentro sair da curva da
	# saida, e da faixa de dentro chegar 15 m antes da curva da entrada ate a
	# garagem: e ali que uma faixa cruza a frente da outra.
	var dentro := _caminhos[0]
	_divide = dentro.curva_saida + PI * 0.5 * r + 3.0
	_junta = dentro.comprimento - dentro.curva_entrada + 15.0


static func _reta(a: Vector2, b: Vector2) -> PackedVector2Array:
	var pontos := PackedVector2Array()
	var n := maxi(1, ceili(a.distance_to(b) / PASSO))
	for i in n + 1:
		pontos.append(a.lerp(b, float(i) / n))
	return pontos


## Um quarto de volta de raio `ESQUINA_RAIO` em torno de `centro`, de
## `centro + de * r` a `centro + ate * r`.
static func _arco(centro: Vector2, de: Vector2, ate: Vector2) -> PackedVector2Array:
	var r := ViaExpressa.ESQUINA_RAIO
	var pontos := PackedVector2Array()
	var n := 12
	for i in n + 1:
		var t := float(i) / n * PI * 0.5
		pontos.append(centro + (de * cos(t) + ate * sin(t)) * r)
	return pontos
