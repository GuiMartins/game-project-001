extends Camera3D
class_name ChaseCamera
## Camera baixa, lente longa, sempre atras.
##
## Nao e so estetica: a camera fixa atras e o que corta ~60% do sprite sheet
## quando a arte pre-renderizada chegar (so vistas traseiras e 3/4). Mudar isso
## depois custa caro, entao ja fica travado no prototipo.

enum Mode { CHASE, HOOD, DEBUG_FREE }

var tuning: BikeTuning
var target: PlayerBike
var mode: int = Mode.CHASE

var _smoothed_position: Vector3
var _smoothed_look: Vector3
var _shake: float = 0.0
var _rng := RandomNumberGenerator.new()


func setup(a_tuning: BikeTuning, a_target: PlayerBike) -> void:
	tuning = a_tuning
	target = a_target
	near = 0.1
	far = 800.0
	_smoothed_position = a_target.global_position + Vector3(0, 3, 8)
	_smoothed_look = a_target.global_position


func cycle_mode() -> void:
	mode = (mode + 1) % 3


func add_shake(amount: float) -> void:
	_shake = minf(_shake + amount, 1.0)


func _process(delta: float) -> void:
	if target == null or tuning == null:
		return

	var speed_frac := clampf(target.speed / maxf(tuning.max_speed, 1.0), 0.0, 1.4)
	fov = tuning.cam_fov + tuning.cam_fov_speed_gain * speed_frac

	var heading := target.heading
	var back := Vector3(-sin(heading), 0.0, -cos(heading))
	var forward := -back

	var distance := tuning.cam_distance
	var height := tuning.cam_height
	if mode == Mode.HOOD:
		distance = 0.2
		height = 1.15
	elif mode == Mode.DEBUG_FREE:
		distance = tuning.cam_distance * 2.6
		height = tuning.cam_height * 4.0

	var desired := target.global_position + back * distance + Vector3.UP * height
	# A camera persegue por posicao, nao por rotacao rigida. O atraso e o que
	# faz a moto "escapar" da camera na saida de curva.
	var t := 1.0 - exp(-tuning.cam_follow * delta)
	_smoothed_position = _smoothed_position.lerp(desired, t)
	# Mira longe: olhar 14 m a frente abaixa o horizonte e abre a pista. Mirar
	# em cima da moto so mostra o para-lama.
	_smoothed_look = _smoothed_look.lerp(target.global_position + forward * 14.0 + Vector3.UP * 1.2, t)

	var pos := _smoothed_position
	if _shake > 0.0:
		pos += Vector3(_rng.randfn(0.0, 1.0), _rng.randfn(0.0, 1.0), _rng.randfn(0.0, 1.0)) * _shake * 0.35
		_shake = maxf(_shake - delta * 1.6, 0.0)

	look_at_from_position(pos, _smoothed_look, Vector3.UP)
	# Um pingo da inclinacao da moto na camera. Muito disso embrulha o estomago;
	# nada disso deixa a curva sem peso.
	rotate_object_local(Vector3.FORWARD, -target.lean * tuning.cam_lean_follow)
