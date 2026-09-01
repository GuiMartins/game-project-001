extends Node
## Banco de provas headless do modelo da moto.
##
## `godot --headless -- --selftest` roda o jogo de verdade (mesma fisica, mesmo
## caminho de input, via Input.action_press) e imprime as medidas que decidem se
## o feel esta no lugar: 0-100, freada, raio de curva, tempo de inclinacao,
## janela do soco.
##
## Existe porque "esta gostoso?" e subjetivo, mas "0-100 em 9 segundos" nao e -
## e da pra pegar uma regressao de tuning sem abrir o jogo.

const KMH: float = 3.6

var _main: Node
var _player: PlayerBike
var _world: World
var _tuning: BikeTuning

var _phase: int = 0
var _t: float = 0.0
var _report: Array[String] = []
var _failures: Array[String] = []

# Medidas coletadas.
var _t_to_100: float = -1.0
var _top_speed: float = 0.0
var _brake_from: float = 0.0
var _brake_time: float = 0.0
var _brake_distance: float = 0.0
var _lean_rise_time: float = -1.0
var _yaw_rate: float = 0.0
var _turn_radius: float = 0.0
var _saved_assist: float = 0.0
var _punch_frames: int = 0
var _punch_seen: bool = false
var _rng := RandomNumberGenerator.new()
var _trace: bool = OS.has_environment("RUSHFOOD_SELFTEST_TRACE")
var _trace_next: float = 0.0
## Pasta pra despejar PNGs da corrida. So pra inspecao visual do prototipo.
var _shots_dir: String = OS.get_environment("RUSHFOOD_SELFTEST_SHOTS")
var _shots_next: float = 0.0
var _shots_taken: int = 0
var _heading_at_mark: float = 0.0
var _lateral_at_mark: float = 0.0
var _speed_at_mark: float = 0.0


func setup(main: Node) -> void:
	_main = main
	_world = main.get("world")
	_player = _world.player
	_tuning = main.get("tuning")
	# Semente fixa: o numero do relatorio precisa ser comparavel entre rodadas,
	# senao "regrediu" e "deu azar" viram a mesma coisa.
	_rng.seed = 4242
	_bench_begin()
	if not _shots_dir.is_empty():
		# Modo foto: pula o banco de provas e vai direto pra corrida.
		_phase = 5
	print("\n=== RUSHFOOD SELFTEST ===")
	print("tuning: %s" % _main.get("tuning_source"))
	print("pista: %.0f m | transito: %d | rivais: %d" % [
		_world.track.length, _world.traffic.size(), _world.rivals.size()])


func _physics_process(delta: float) -> void:
	_t += delta
	match _phase:
		0: _phase_accel(delta)
		1: _phase_brake(delta)
		2: _phase_lean(delta)
		3: _phase_turn(delta)
		4: _phase_punch(delta)
		5: _phase_freerun(delta)


func _next_phase() -> void:
	_phase += 1
	_t = 0.0
	_release_all()


## O banco mede a MOTO, nao a pista. Sem isolar, a primeira raspada em
## guard-rail contamina a medida de 0-100 e o numero deixa de significar algo.
func _bench_begin() -> void:
	_player.road_bounds_enabled = false
	_player.collision_mask = 0
	for car in _world.traffic:
		car.offset += 9000.0
	for rival in _world.rivals:
		rival.offset += 9000.0
	_player.place_on_track(20.0, 0.0, 0.0)


func _bench_end() -> void:
	_player.road_bounds_enabled = true
	_player.collision_mask = Layers.WORLD | Layers.RIVAL
	_player.place_on_track(40.0, RoadTrack.corridor_center(1), 20.0)
	_world.scatter_traffic_ahead(_player.track_offset)
	for rival in _world.rivals:
		rival.offset = _player.track_offset + 15.0 + _rng.randf() * 40.0


func _release_all() -> void:
	for a: String in ["ride_throttle", "ride_brake", "ride_left", "ride_right", "ride_boost",
			"hit_left", "hit_right"]:
		if Input.is_action_pressed(a):
			Input.action_release(a)


## Fase 0 - aceleracao ------------------------------------------------------
func _phase_accel(_delta: float) -> void:
	Input.action_press("ride_throttle")
	if _t_to_100 < 0.0 and _player.speed * KMH >= 100.0:
		_t_to_100 = _t
	_top_speed = maxf(_top_speed, _player.speed)
	if _t >= 22.0:
		_report.append("0-100 km/h          %.2f s" % _t_to_100)
		_report.append("velocidade em 22s   %.1f km/h  (teto do tuning %.1f)" % [
			_top_speed * KMH, _tuning.max_speed * KMH])
		_check(_t_to_100 > 0.0 and _t_to_100 < 9.0,
			"0-100 em %.2fs: acima de 9s a moto nao parece uma moto" % _t_to_100)
		_check(_top_speed >= _tuning.max_speed * 0.86,
			"so chegou a %.0f%% do teto em 22s - a cauda da curva de aceleracao esta morta" % (
				100.0 * _top_speed / _tuning.max_speed))
		_brake_from = _player.speed
		_next_phase()


## Fase 1 - frenagem -------------------------------------------------------
func _phase_brake(delta: float) -> void:
	if _t < 0.02:
		_brake_from = _player.speed
	Input.action_press("ride_brake")
	_brake_distance += _player.speed * delta
	_brake_time = _t
	if _player.speed < 1.0 or _t > 12.0:
		_report.append("freada %.0f km/h -> 0   %.2f s / %.0f m" % [
			_brake_from * KMH, _brake_time, _brake_distance])
		_check(_brake_time < 6.0, "freada de %.2fs e longa demais pro ritmo do corredor" % _brake_time)
		_next_phase()


## Fase 2 - resposta da inclinacao -----------------------------------------
func _phase_lean(_delta: float) -> void:
	if _t < 0.02:
		_player.place_on_track(_player.track_offset + 20.0, 0.0, 30.0)
	if _t < 1.5:
		Input.action_press("ride_throttle")
		return
	_release_all()
	Input.action_press("ride_throttle")
	Input.action_press("ride_right")
	var target := deg_to_rad(_tuning.max_lean)
	if _lean_rise_time < 0.0 and _player.lean >= target * 0.9:
		_lean_rise_time = _t - 1.5
	if _t >= 4.0:
		_report.append("inclinacao 0->90%%    %.2f s" % _lean_rise_time)
		_check(_lean_rise_time > 0.05,
			"a moto assume a inclinacao maxima instantaneamente - nao tem peso nenhum")
		_check(_lean_rise_time > 0.0 and _lean_rise_time < 1.2,
			"demora %.2fs pra inclinar: nesse tempo o corredor ja fechou" % _lean_rise_time)
		_next_phase()


## Fase 3 - raio de curva (com a assistencia desligada) --------------------
func _phase_turn(_delta: float) -> void:
	if _t < 0.05:
		_saved_assist = _tuning.align_assist
		_tuning.align_assist = 0.0
		_player.place_on_track(_player.track_offset + 20.0, 0.0, _tuning.max_speed * 0.9)
	Input.action_press("ride_throttle")
	Input.action_press("ride_right")
	# Espera a inclinacao assentar antes de comecar a contar.
	if _t >= 1.5 and _t < 1.5 + _delta:
		_heading_at_mark = _player.heading
		_speed_at_mark = _player.speed
		_lateral_at_mark = _player.track_lateral
	if _t >= 3.5:
		# Guinada real integrada pela fisica, nao a formula recalculada aqui -
		# senao o teste so confirma a si mesmo.
		_yaw_rate = rad_to_deg(absf(wrapf(_player.heading - _heading_at_mark, -PI, PI))) / 2.0
		var mean_speed := (_speed_at_mark + _player.speed) * 0.5
		_turn_radius = mean_speed / maxf(deg_to_rad(_yaw_rate), 0.0001)
		_report.append("a %.0f km/h: %.1f graus/s, raio %.0f m" % [
			mean_speed * KMH, _yaw_rate, _turn_radius])
		# Inclinar pra DIREITA tem que mover a moto pra direita na pista. Parece
		# obvio e nao e: em Godot guinada positiva gira pra esquerda, e o erro
		# de sinal passa despercebido porque a assistencia de alinhamento
		# disfarca ate a moto encostar no guard-rail.
		var drift := _player.track_lateral - _lateral_at_mark
		_check(drift > 1.0,
			"inclinou pra direita e a moto foi %.1f m pra ESQUERDA - sinal da guinada invertido"
			% -drift)
		_check(_yaw_rate > 1.0, "a moto praticamente nao vira no talo")
		_check(_turn_radius < 260.0,
			"raio de %.0fm no talo: a moto nao consegue seguir a propria pista" % _turn_radius)
		_tuning.align_assist = _saved_assist
		_next_phase()


## Fase 4 - janela do soco -------------------------------------------------
func _phase_punch(_delta: float) -> void:
	if _t < 0.02:
		_player.punch_landed.connect(func(_target: Node3D) -> void: _punch_seen = true)
		Input.action_press("hit_right")
		return
	if _t < 0.06:
		return
	if Input.is_action_pressed("hit_right"):
		Input.action_release("hit_right")
	var area: Area3D = _player.get_node("HitR")
	if area.monitoring:
		_punch_frames += 1
	if _t >= _tuning.punch_cooldown + 0.2:
		var window := float(_punch_frames) / 60.0
		_report.append("hitbox do soco       %.3f s aberta (tuning pede %.3f)" % [
			window, _tuning.punch_active])
		_check(_punch_frames > 0, "a hitbox do soco nunca abriu")
		_check(absf(window - _tuning.punch_active) < 0.05,
			"janela medida (%.3fs) nao bate com o tuning (%.3fs)" % [window, _tuning.punch_active])
		_next_phase()


## Fase 5 - corrida solta: le a pista de verdade ---------------------------
func _phase_freerun(_delta: float) -> void:
	if _t < 0.02:
		_bench_end()
		_world.run.start(_world.track.length - 30.0)
	# Piloto automatico: mira o corredor livre mais proximo, exatamente com a
	# mesma consulta que a IA dos rivais usa. Nao joga bonito, mas se nem ele
	# atravessa o transito, a densidade esta injogavel pra qualquer um.
	var basis := _player.track.sample_basis(_player.track_offset)
	var road_heading := atan2((-basis.z).x, (-basis.z).z)
	var lookahead := 22.0 + _player.speed * 0.9
	var want := _world.free_lateral(_player.track_offset, _player.track_lateral, lookahead)
	# steer > 0 pede inclinacao pra direita. Guinada positiva gira pra esquerda,
	# entao o erro de alinhamento entra com sinal trocado.
	var steer := -wrapf(road_heading - _player.heading, -PI, PI)
	steer += clampf((want - _player.track_lateral) * 0.12, -0.35, 0.35)

	# Freia quando o vao a frente acabou. Sem isso o teste so mede se da pra
	# desviar, e nao se da pra JOGAR o corredor - desviar e frear e o par.
	# Gas e freio sao exclusivos: apertar os dois junto so faz o bot patinar.
	var clearance := _world.path_clearance(_player.track_offset, lookahead, want)
	var braking := clearance < _player.speed * 0.55
	_set_action("ride_brake", braking)
	_set_action("ride_throttle", not braking)
	_set_action("ride_right", steer > 0.02)
	_set_action("ride_left", steer < -0.02)

	if not _shots_dir.is_empty() and _t >= _shots_next:
		_shots_next += 2.5
		_capture("%s/rushfood_%02d.png" % [_shots_dir, _shots_taken])
		_shots_taken += 1
		# Alterna perseguicao / capacete / camera alta de diagnostico.
		_world.camera.cycle_mode()

	if _trace and _t >= _trace_next:
		_trace_next += 1.0
		print("  t=%4.1f  off=%7.1f  lat=%6.2f  v=%6.1f km/h  y=%6.2f  estado=%d  quedas=%d" % [
			_t, _player.track_offset, _player.track_lateral, _player.speed * KMH,
			_player.global_position.y, _player.state, _world.run.crashes])

	if not is_finite(_player.global_position.x) or not is_finite(_player.speed):
		_check(false, "posicao ou velocidade viraram NaN")
		_finish()
		return

	if _t >= 45.0 or _world.run.phase != DeliveryRun.Phase.RIDING:
		_report.append("corrida solta 45s    %.0f m percorridos, %d raspadas, %d quedas" % [
			_world.run.distance_done, _world.run.near_misses, _world.run.crashes])
		_check(_world.run.distance_done > 700.0,
			"so andou %.0fm em 45s - o piloto automatico nao consegue atravessar o transito"
			% _world.run.distance_done)
		_check(_player.global_position.y > -50.0, "a moto caiu pra fora do mundo")
		_finish()


func _set_action(action_name: String, pressed: bool) -> void:
	if pressed and not Input.is_action_pressed(action_name):
		Input.action_press(action_name)
	elif not pressed and Input.is_action_pressed(action_name):
		Input.action_release(action_name)


func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(path)


## --- Relatorio ------------------------------------------------------------

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	set_physics_process(false)
	print("\n--- medidas ---")
	for line: String in _report:
		print("  " + line)
	if _failures.is_empty():
		print("\n--- OK: %d verificacoes passaram ---\n" % _report.size())
		get_tree().quit(0)
	else:
		print("\n--- %d PROBLEMAS ---" % _failures.size())
		for line: String in _failures:
			print("  ! " + line)
		print("")
		get_tree().quit(1)
