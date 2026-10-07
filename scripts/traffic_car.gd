class_name TrafficCar
extends AnimatableBody3D
## Carro do transito. Parametrico na curva: sabe seu proprio offset e nunca
## precisa se projetar na pista.
##
## E o carro que cria o corredor. Ele anda devagar, muda de faixa sem olhar,
## abre a porta na sua cara, para no sinal e empaca no engarrafamento - e cada
## uma dessas coisas e um jeito diferente de fechar a pista e deixar so o vao.
##
## Este no e o carro na pista: onde esta, a que velocidade, quando abre a
## porta. O modelo e tudo o que se mexe dentro dele - roda, mola, luz, quem
## dirige - moram no `Carro`, filho dele.

## Emitido quando a porta abre, pra HUD/audio avisarem o jogador.
signal door_opened

## Quanto de cada modelo sai na rua, na ordem do `Carro.Modelo`: hatch, seda,
## SUV, taxi e onibus. Carro de passeio e o grosso; taxi e onibus sao o que da
## cara de cidade, e um em sete e onibus porque ele e parede de 12 m - mais que
## isso e o corredor virar fila de onibus.
const FROTA: Array[float] = [0.25, 0.25, 0.18, 0.18, 0.14]

## Mistura na semente do carro para sortear o modelo e as cores. Sorteio a
## parte de proposito: tirar o modelo do `_rng` mudaria a hora de cada troca de
## faixa e cada porta, e o banco de provas mediria outra corrida.
const SEMENTE_VISUAL: int = 0x5EED

## Comprimento maximo de um gomo do colisor, em metros. Acima disto a lataria
## vira gomos que seguem a curva da pista.
##
## Caixa reta de 12 m numa curva de raio 100 m sai 15 cm da faixa na ponta, e
## quem pensa em faixa - o rival, o piloto automatico - raspa nela achando que
## passou com folga. O carro de passeio cabe num gomo so.
const GOMO_MAX: float = 5.0

## Valores de fallback, usados so pelo carro que nao pertence a frota - o que
## fica largado dentro de um atalho. Esse nunca dirige, entao ele nunca leu
## slider nenhum. Quem esta na avenida usa o WorldTuning, que sai no F3.
const ACCEL: float = 2.2
const BRAKE: float = 4.5
const FOLLOW_GAP: float = 6.2

## De quantos em quantos frames o carro reconsulta a pista a frente.
##
## A consulta varre a frota inteira, entao ela custa N por carro por frame - N
## ao quadrado no mundo. Medido, com uma fila de 90 m em cena isso dava 4,7 ms
## por frame, mais de um quarto do orcamento a 60 Hz, so pra carro nao entrar
## em carro.
##
## Entre uma consulta e outra o vao e descontado pelo que o proprio carro
## andou. E a hipotese conservadora - supoe o carro da frente parado -, entao
## errar pra menos aqui freia cedo demais, nunca tarde demais.
const PROBE_EVERY: int = 4

var track: RoadTrack
var offset: float = 0.0
var lateral: float = 0.0
var speed: float = 0.0
## Velocidade que este carro busca quando a pista esta livre.
var cruise_speed: float = 0.0
## Encostado no meio-fio: parado, numa das faixas da ponta. So quem esta
## encostado pode abrir porta.
var parked: bool = false
## Preso num engarrafamento: no meio da pista, andando a passo, sem trocar de
## faixa. Diferente de `parked`, que e carro estacionado no meio-fio.
## Marcado quando o jogador ja pontuou a raspada neste carro, pra nao contar duas vezes.
var near_missed: bool = false
## Este carro esta comprometido com uma parada no vermelho.

## Quem sabe onde estao os outros carros e os semaforos.
##
## Untyped de proposito: o World ja conhece o TrafficCar, e tipar a volta
## fecharia um ciclo entre os dois class_name.
var world: Node
## Sliders do F3. Null no carro largado num atalho, que e obstaculo fixo e
## nunca dirige - por isso todo uso aqui cai nos const acima quando falta.
var world_tuning: WorldTuning

var _gap_cache: float = INF
var _probe_in: int = 0
var _target_lateral: float = 0.0
var _lane_change_timer: float = 0.0
var _door_timer: float = 0.0
var _door_open: bool = false
## Este carro chega a abrir a porta em algum momento? Sorteado ao encostar.
var _opens_door: bool = false
## De que lado a porta abre: -1 esquerda, 1 direita.
var _door_side: int = -1
var _rng := RandomNumberGenerator.new()
var _rng_visual := RandomNumberGenerator.new()
## O modelo, com tudo o que se mexe dentro dele.
var _carro: Carro
## A lataria em gomos ao longo do comprimento: um no carro, tres no onibus.
var _gomos: Array[CollisionShape3D] = []
## Quanto cada gomo esta a frente do carro, em metros de pista.
var _gomo_ao_longo: Array[float] = []
## Caixa da lataria, no espaco do carro: e o que conta de tamanho na pista
## (`meio_comprimento`, `meia_largura`).
var _caixa := AABB(Vector3(-0.9, 0.0, -2.2), Vector3(1.8, 1.5, 4.4))
## A porta aberta. Segue a porta do modelo enquanto ela gira.
var _door_shape: CollisionShape3D
var _lateral_antes: float = 0.0


func _ready() -> void:
	sync_to_physics = true
	collision_layer = Layers.WORLD
	collision_mask = 0

	_carro = Carro.new()
	_carro.name = "Carro"
	add_child(_carro)

	_gomos.append(Greybox.box_shape(Vector3.ONE))
	add_child(_gomos[0])
	_door_shape = Greybox.box_shape(Vector3.ONE)
	_door_shape.disabled = true
	add_child(_door_shape)


## Metade do comprimento da lataria, em metros de pista.
func meio_comprimento() -> float:
	return _caixa.size.z * 0.5


## Metade da largura da lataria, sem retrovisor.
func meia_largura() -> float:
	return _caixa.size.x * 0.5


func modelo() -> Carro.Modelo:
	return _carro.modelo


func setup(
	a_track: RoadTrack,
	a_offset: float,
	a_lateral: float,
	seed_value: int,
	a_parked: bool = false,
	a_opens_door: bool = false
) -> void:
	track = a_track
	_rng.seed = seed_value
	_rng_visual.seed = seed_value ^ SEMENTE_VISUAL
	_lane_change_timer = _rng.randf_range(3.0, 14.0)
	# Consulta desencontrada: se todos perguntassem no mesmo frame, economizar
	# tres frames em quatro so faria o pico ser quatro vezes maior.
	_probe_in = _rng.randi_range(1, PROBE_EVERY)
	_reset_at(a_offset, a_lateral, a_parked, a_opens_door)


## Sorteia o modelo pela `FROTA`, poe a lataria e o colisor no tamanho dele.
func _monta() -> void:
	var sorteio := _rng_visual.randf()
	var qual := 0
	while qual < FROTA.size() - 1 and sorteio >= FROTA[qual]:
		sorteio -= FROTA[qual]
		qual += 1
	_carro.montar(qual as Carro.Modelo, _rng_visual)
	_caixa = _carro.caixa()
	var n := maxi(1, ceili(_caixa.size.z / GOMO_MAX))
	while _gomos.size() < n:
		_gomos.append(Greybox.box_shape(Vector3.ONE))
		add_child(_gomos[-1])
	var comprimento := _caixa.size.z / float(n)
	_gomo_ao_longo.clear()
	for k in _gomos.size():
		_gomos[k].set_deferred("disabled", k >= n)
		if k >= n:
			continue
		# Uma fresta de 5 cm de sobreposicao entre gomos: emendados no fio, a
		# moto acharia a junta na curva.
		(_gomos[k].shape as BoxShape3D).size = Vector3(
			_caixa.size.x, _caixa.size.y, comprimento + 0.05
		)
		var z := _caixa.position.z + comprimento * (float(k) + 0.5)
		_gomos[k].position = Vector3(_caixa.get_center().x, _caixa.get_center().y, z)
		# Para a frente e -Z: o gomo de z negativo esta a frente na pista.
		_gomo_ao_longo.append(-z)


func _physics_process(delta: float) -> void:
	if track == null:
		return

	if parked:
		speed = 0.0
	else:
		_drive(delta)

	offset += speed * delta
	lateral = move_toward(lateral, _target_lateral, 1.6 * delta)

	# Encostado nao muda de faixa: esta estacionado, nao no fluxo.
	if not parked:
		_lane_change_timer -= delta
		if _lane_change_timer <= 0.0:
			_lane_change_timer = _rng.randf_range(4.0, 16.0)
			# Muda de faixa: o corredor que estava aberto fecha, outro abre.
			var dir := 1.0 if _rng.randf() < 0.5 else -1.0
			var candidate := _target_lateral + RoadTrack.LANE_WIDTH * dir
			var limit := RoadTrack.half_width() - RoadTrack.LANE_WIDTH * 0.5
			# Sem olhar para a moto, que e o susto do corredor; olhando para os
			# outros carros, que e o que impede um de entrar no outro. Faixa
			# ocupada e troca cancelada, e o sorteio da proxima ja saiu acima.
			if absf(candidate) <= limit and _faixa_livre(candidate):
				_target_lateral = candidate

	# `_opens_door` so e verdade em carro encostado, entao carro em movimento
	# nunca chega aqui.
	if _opens_door:
		_door_timer -= delta
		if _door_timer <= 0.0:
			if _door_open:
				_set_door(false)
				_door_timer = _rng.randf_range(10.0, 35.0)
			else:
				_set_door(true)
				_door_timer = _rng.randf_range(2.0, 4.0)

	_apply_transform()
	_pose(delta)


## Passa o movimento deste passo para o modelo, e poe o colisor da porta onde a
## porta do modelo esta.
func _pose(delta: float) -> void:
	var lateral_speed := (lateral - _lateral_antes) / delta
	_lateral_antes = lateral
	# A seta acende durante a troca, e nao antes: o transito daqui muda de
	# faixa sem avisar, e e esse o susto que faz o corredor fechar. Ela diz
	# "esta vindo", nao "vai vir".
	var falta := _target_lateral - lateral
	var seta := 0 if parked or absf(falta) < 0.05 else int(signf(falta))
	_carro.atualizar(delta, speed, lateral_speed, parked, seta)

	var porta := _carro.porta_ativa()
	var bate := porta != null and _carro.abertura() > Carro.PORTA_BATE
	if bate:
		var caixa := porta.get_aabb()
		var no_corpo := global_transform.affine_inverse() * porta.global_transform
		_door_shape.transform = no_corpo * Transform3D(Basis.IDENTITY, caixa.get_center())
		(_door_shape.shape as BoxShape3D).size = caixa.size
	if _door_shape.disabled == bate:
		_door_shape.set_deferred("disabled", not bate)


## Ajusta a velocidade ao que a pista permite: o carro da frente na mesma
## faixa e o que decide, e e isso que impede dois carros de ocuparem o mesmo
## metro de asfalto.
func _drive(delta: float) -> void:
	var want := cruise_speed

	var gap: float = world_tuning.traffic_follow_gap if world_tuning != null else FOLLOW_GAP
	_probe_in -= 1
	if _probe_in <= 0:
		_probe_in = PROBE_EVERY
		_gap_cache = _gap_ahead(gap)
	else:
		_gap_cache -= speed * delta
	want = minf(want, _approach_speed(_gap_cache - gap))

	var accel: float = world_tuning.traffic_accel if world_tuning != null else ACCEL
	var rate := accel if want > speed else _brake()
	speed = move_toward(speed, maxf(want, 0.0), rate * delta)


func _brake() -> float:
	return world_tuning.traffic_brake if world_tuning != null else BRAKE


## Velocidade maxima pra ainda parar em `distance` metros freando no talo.
func _approach_speed(distance: float) -> float:
	return sqrt(2.0 * _brake() * maxf(distance, 0.0))


## Pista livre a frente na faixa deste carro.
func _gap_ahead(follow_gap: float) -> float:
	if world == null or not world.has_method("path_clearance"):
		return INF
	var livre: float = world.path_clearance(offset, follow_gap + 24.0, lateral, self)
	# No meio da troca o carro ocupa as duas faixas, e o da frente na faixa
	# nova tambem e o da frente. So quem esta a frente: o que vem atras na
	# faixa nova e quem tem que frear, e contar ele aqui parava os dois.
	if not is_equal_approx(_target_lateral, lateral):
		livre = minf(
			livre, world.path_clearance(offset, follow_gap + 24.0, _target_lateral, self, false)
		)
	return livre


func _faixa_livre(alvo: float) -> bool:
	if world == null or not world.has_method("faixa_livre"):
		return true
	return world.faixa_livre(self, alvo)


## Este carro esta dentro de `outro`? Folga de 10 cm nas duas direcoes:
## encostar nao e sobrepor.
func sobrepoe(outro: TrafficCar) -> bool:
	var largura := meia_largura() + outro.meia_largura() - 0.1
	var comprimento := meio_comprimento() + outro.meio_comprimento() - 0.1
	return absf(lateral - outro.lateral) < largura and absf(offset - outro.offset) < comprimento


## Para onde o carro esta indo: a lateral da faixa de destino.
func destino() -> float:
	return _target_lateral


## A origem do carro e o chao, embaixo do meio dele: a lataria e o colisor ja
## estao em cima dela.
func _apply_transform() -> void:
	var t := track.transform_at(offset, lateral)
	global_transform = t
	if _gomo_ao_longo.size() < 2:
		return
	# Cada gomo no ponto da faixa onde ele esta, e nao na reta do carro.
	var inversa := t.affine_inverse()
	var altura := Vector3(_caixa.get_center().x, _caixa.get_center().y, 0.0)
	for k in _gomo_ao_longo.size():
		var no_gomo := track.transform_at(offset + _gomo_ao_longo[k], lateral)
		_gomos[k].transform = inversa * no_gomo.translated_local(altura)


## Leva o carro para outro `offset` sem mexer no resto. E o que o `World` usa
## para desencostar um carro que nasceu em cima de outro.
func posicionar(a_offset: float) -> void:
	offset = a_offset
	_apply_transform()
	_carro.reiniciar()


## Abre ou fecha. O colisor nao liga aqui: liga quando a porta do modelo ja
## abriu o bastante para bater (`Carro.PORTA_BATE`), e segue ela enquanto gira.
func _set_door(open: bool) -> void:
	_door_open = open
	if open:
		_carro.abrir_porta(_door_side)
		door_opened.emit()
	else:
		_carro.fechar_portas()


## Reposiciona o carro mais a frente em vez de instanciar outro.
func recycle(
	a_offset: float, a_lateral: float, a_parked: bool = false, a_opens_door: bool = false
) -> void:
	_reset_at(a_offset, a_lateral, a_parked, a_opens_door)


## Estado comum entre nascer e ser reciclado.
func _reset_at(a_offset: float, a_lateral: float, a_parked: bool, a_opens_door: bool) -> void:
	offset = a_offset
	lateral = a_lateral
	_target_lateral = a_lateral
	parked = a_parked
	# Transito de marginal em hora de pico: quase parado, e ai que ta a graca.
	# Encostado e parado de verdade - zero, nao "quase".
	if a_parked:
		cruise_speed = 0.0
	else:
		cruise_speed = _rng.randf_range(
			0.0, world_tuning.traffic_speed if world_tuning != null else 7.0
		)
	speed = cruise_speed
	_gap_cache = INF
	_opens_door = a_parked and a_opens_door
	near_missed = false
	_monta()
	_set_door(false)
	_door_shape.set_deferred("disabled", true)
	# Pista ou calcada, tanto faz - o que importa e voce nao poder decorar de
	# que lado ela vem. Porta previsivel deixa de ser susto e vira pedagio.
	_door_side = -1 if _rng.randf() < 0.5 else 1
	_door_timer = _rng.randf_range(6.0, 30.0)
	_lateral_antes = lateral
	_apply_transform()
	_carro.reiniciar()
