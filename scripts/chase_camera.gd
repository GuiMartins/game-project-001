class_name ChaseCamera
extends Camera3D
## Camera baixa, lente longa, sempre atras.
##
## Nao e so estetica: a camera fixa atras e o que corta ~60% do sprite sheet
## quando a arte pre-renderizada chegar (so vistas traseiras e 3/4). Mudar isso
## depois custa caro, entao ja fica travado no prototipo.

## GARUPA logo depois de CHASE: no F2 a camera nova fica a um toque do padrao.
enum Mode { CHASE, GARUPA, HOOD, DEBUG_FREE }

var tuning: BikeTuning
var target: PlayerBike
var mode: int = Mode.CHASE

## Onde a camera e a mira estao EM RELACAO a moto, suavizados. Persegue o
## deslocamento, e nao a posicao no mundo: ver `_process`.
var _offset: Vector3
var _mira_offset: Vector3
## Altura da moto, suavizada. Separada do deslocamento para a ladeira e o
## quique continuarem chegando amortecidos na camera.
var _altura: float
## Giro atual da camera em volta do eixo de visao, em radianos.
var _roll: float = 0.0
var _shake: float = 0.0
var _rng := RandomNumberGenerator.new()
## O cinegrafista do modo GARUPA. Nasce na primeira vez que o modo roda: a
## pista so existe depois do `setup` da moto.
var _garupa: CameraGarupa


func setup(a_tuning: BikeTuning, a_target: PlayerBike) -> void:
	tuning = a_tuning
	target = a_target
	near = 0.1
	far = 800.0
	_offset = Vector3(0, 3, 8)
	_mira_offset = Vector3.ZERO
	_altura = a_target.global_position.y
	_roll = 0.0


func cycle_mode() -> void:
	mode = (mode + 1) % Mode.size()
	# Entrando na garupa, o cinegrafista larga do longe e encosta: a troca de
	# modo vira a abertura do video, e nao um corte para um estado velho.
	if _na_garupa():
		_garupa.reiniciar(CameraGarupa.ler(target, _transito()))


## Nome do modo atual, pra tela de configuracoes. Mora aqui e nao la porque o
## nome e do enum: quem acrescentar um modo mexe num arquivo so.
func mode_name() -> String:
	match mode:
		Mode.GARUPA:
			return "GARUPA"
		Mode.HOOD:
			return "CAPACETE"
		Mode.DEBUG_FREE:
			return "DIAGNOSTICO"
	return "PERSEGUICAO"


func add_shake(amount: float) -> void:
	_shake = minf(_shake + amount, 1.0)


func _process(delta: float) -> void:
	if target == null or tuning == null:
		return

	if _na_garupa():
		var pose := _garupa.passo(delta, CameraGarupa.ler(target, _transito()))
		pose.origin += _tremor_de_batida(delta)
		_aplica_garupa(pose)
		return

	var alvo := _alvos()
	# A camera persegue o DESLOCAMENTO em relacao a moto, nao a posicao no
	# mundo. Perseguindo a posicao, o atraso cresce com a velocidade (v / k): a
	# 52 m/s com `cam_follow` 7 eram 7,4 m a mais, a camera ia de 6,4 m para
	# quase 14 m no talo e a moto encolhia para menos da metade na tela.
	# Assim a distancia e a do slider em qualquer velocidade, e o atraso fica
	# so onde ele serve: o deslocamento gira atrasado na curva, e a moto ainda
	# "escapa" da camera na saida dela.
	var t := 1.0 - exp(-tuning.cam_follow * delta)
	var moto := target.global_position
	_offset = _offset.lerp(alvo[0] - moto, t)
	_mira_offset = _mira_offset.lerp(alvo[1] - moto, t)
	_altura = lerpf(_altura, moto.y, t)

	var pos := _base() + _offset + _tremor_de_batida(delta)

	# O giro PERSEGUE a inclinacao em vez de copia-la: ver `cam_lean_rate`.
	var roll_alvo := -target.lean * tuning.cam_lean_follow
	_roll = lerpf(_roll, roll_alvo, 1.0 - exp(-tuning.cam_lean_rate * delta))
	_aplica(pos)


## Poe a camera direto onde a perseguicao terminaria, sem atraso nem tremor.
##
## Existe para o quadro congelado da prova visual (`scripts/prova.gd`): o
## atraso depende do tempo de cada quadro, e quadro que depende do relogio nao
## se compara com o de ontem.
func encaixar() -> void:
	_shake = 0.0
	if _na_garupa():
		_aplica_garupa(_garupa.encaixar(CameraGarupa.ler(target, _transito())))
		return
	var alvo := _alvos()
	_offset = alvo[0] - target.global_position
	_mira_offset = alvo[1] - target.global_position
	_altura = target.global_position.y
	_roll = -target.lean * tuning.cam_lean_follow
	_aplica(_base() + _offset)


## O tranco de batida (`add_shake`): vale em todos os modos, por cima do resto.
func _tremor_de_batida(delta: float) -> Vector3:
	if _shake <= 0.0:
		return Vector3.ZERO
	var tranco := (
		Vector3(_rng.randfn(0.0, 1.0), _rng.randfn(0.0, 1.0), _rng.randfn(0.0, 1.0)) * _shake * 0.35
	)
	_shake = maxf(_shake - delta * 1.6, 0.0)
	return tranco


## A garupa precisa da pista para andar; sem ela (moto fora de corrida, como
## no teste do giro) o modo cai na perseguicao.
func _na_garupa() -> bool:
	if mode != Mode.GARUPA or target == null or target.track == null:
		return false
	if _garupa == null or _garupa.track != target.track:
		_garupa = CameraGarupa.new(tuning, target.track, World.SEMENTE)
	return true


## Os carros do mundo, para o cinegrafista sair do caminho. A camera e filha do
## `World`, e le a frota direto dele, sem o mundo precisar saber da garupa.
func _transito() -> Array[TrafficCar]:
	var mundo := get_parent() as World
	if mundo == null:
		return []
	return mundo.traffic


func _aplica_garupa(pose: Transform3D) -> void:
	fov = tuning.garupa_fov
	global_transform = pose
	# A perseguicao continua de onde a garupa parou: saindo dela no F2, a
	# camera sai daqui, e nao de um ponto esquecido la atras na pista.
	_altura = target.global_position.y
	_offset = pose.origin - _base()
	_mira_offset = _garupa.mira - _base()


## A moto com a altura suavizada: a ancora de onde saem camera e mira.
func _base() -> Vector3:
	var moto := target.global_position
	return Vector3(moto.x, _altura, moto.z)


## Onde a camera quer estar e para onde quer olhar, sem suavizacao.
func _alvos() -> Array[Vector3]:
	var back := Vector3(-sin(target.heading), 0.0, -cos(target.heading))
	var distance := tuning.cam_distance + tuning.cam_recuo * _fracao_velocidade()
	var height := tuning.cam_height
	if mode == Mode.HOOD:
		distance = 0.2
		height = 1.15
	elif mode == Mode.DEBUG_FREE:
		distance = tuning.cam_distance * 2.6
		height = tuning.cam_height * 4.0
	# Mira longe: olhar 14 m a frente abaixa o horizonte e abre a pista. Mirar
	# em cima da moto so mostra o para-lama.
	return [
		target.global_position + back * distance + Vector3.UP * height,
		target.global_position - back * 14.0 + Vector3.UP * 1.2,
	]


func _aplica(pos: Vector3) -> void:
	fov = tuning.cam_fov + tuning.cam_fov_speed_gain * _fracao_velocidade()
	look_at_from_position(pos, _base() + _mira_offset, Vector3.UP)
	# Um pingo da inclinacao da moto na camera. Muito disso embrulha o estomago;
	# nada disso deixa a curva sem peso.
	rotate_object_local(Vector3.FORWARD, _roll)


func _fracao_velocidade() -> float:
	return clampf(target.speed / maxf(tuning.max_speed, 1.0), 0.0, 1.4)
