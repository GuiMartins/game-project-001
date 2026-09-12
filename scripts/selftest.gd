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

## Nome de cada fase, na ordem em que rodam. Serve pro `--fase <nome>`:
## quem esta iterando em curva nao precisa esperar os 45 s da corrida
## solta, e ciclo curto e o que decide se o teste e rodado ou pulado.
const PHASE_NAMES: PackedStringArray = [
	"aceleracao",
	"freada",
	"inclinacao",
	"curva",
	"soco",
	"calcada",
	"combate",
	"bifurcacao",
	"corrida"
]

var _main: Node
var _player: PlayerBike
var _world: World
var _tuning: BikeTuning

## Ultima fase a rodar. Por padrao, todas.
var _stop_after: int = PHASE_NAMES.size() - 1
var _phase: int = 0
var _t: float = 0.0
var _report: Array[String] = []
var _failures: Array[String] = []
## As mesmas medidas do relatorio, em forma de maquina. O baseline
## versionado compara contra isto - prosa em markdown nao diz se o numero
## andou, so diz qual ele era no dia em que alguem escreveu o markdown.
var _metrics: Dictionary = {}

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
var _asphalt_speed: float = 0.0
var _sidewalk_speed: float = 0.0
var _max_lateral: float = 0.0
var _rival_lateral_before: float = 0.0
var _rival_shove: float = 0.0
var _rival_staggered: bool = false
var _punch_thrown: bool = false
var _max_waiting: int = 0
var _fork_entered: bool = false
var _fork_time: float = -1.0
var _fork_backstep: float = 0.0
var _last_progress: float = 0.0
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
	_read_phase_arg()
	print("\n=== RUSHFOOD SELFTEST ===")
	print("tuning: %s" % _main.get("tuning_source"))
	print(
		(
			"pista: %.0f m | transito: %d | rivais: %d | semaforos: %d | atalhos: %d"
			% [
				_world.track.length,
				_world.traffic.size(),
				_world.rivals.size(),
				_world.lights.size(),
				_world.branches.size()
			]
		)
	)
	_measure_relief()


## Perfil da pista: a rampa mais forte e o desnivel entre o ponto mais alto e
## o mais baixo. Pista que "amanheceu plana" e regressao silenciosa - o jogo
## continua rodando, so fica sem uma das coisas que o torna uma cidade.
func _measure_relief() -> void:
	var steepest := 0.0
	var lowest := INF
	var highest := -INF
	var o := 0.0
	while o < _world.track.length:
		steepest = maxf(steepest, absf(_world.track.grade_at(o)))
		var y := _world.track.sample_position(o).y
		lowest = minf(lowest, y)
		highest = maxf(highest, y)
		o += 5.0
	_metric("relevo_rampa_max_pct", steepest * 100.0)
	_metric("relevo_desnivel_m", highest - lowest)
	_report.append(
		(
			"relevo               rampa max %.0f%%, desnivel %.0f m"
			% [steepest * 100.0, highest - lowest]
		)
	)
	_check(steepest > 0.05, "a pista saiu plana: sem ladeira nao ha subida nem descida pra sentir")
	# Margem sobre o teto: as tangentes suavizadas passam um pouco por cima do
	# valor sorteado, e isso e esperado.
	_check(
		steepest < RoadTrack.MAX_GRADE * 1.4,
		"rampa de %.0f%% - acima disso a moto sobe empinada e desce voando" % (steepest * 100.0)
	)


func _physics_process(delta: float) -> void:
	_t += delta
	match _phase:
		0:
			_phase_accel(delta)
		1:
			_phase_brake(delta)
		2:
			_phase_lean(delta)
		3:
			_phase_turn(delta)
		4:
			_phase_punch(delta)
		5:
			_phase_sidewalk(delta)
		6:
			_phase_combat(delta)
		7:
			_phase_fork(delta)
		8:
			_phase_freerun(delta)


func _next_phase() -> void:
	_phase += 1
	_t = 0.0
	_release_all()
	if _phase > _stop_after:
		_finish()


## O banco mede a MOTO, nao a pista. Sem isolar, a primeira raspada em
## guard-rail contamina a medida de 0-100 e o numero deixa de significar algo.
func _bench_begin() -> void:
	_player.road_bounds_enabled = false
	# 0-100 medido numa ladeira mede a ladeira. A elevacao entra de volta na
	# corrida solta, que e onde a pergunta e "da pra jogar isto?".
	_player.slope_enabled = false
	_player.collision_mask = 0
	for car in _world.traffic:
		car.offset += 9000.0
	for rival in _world.rivals:
		rival.offset += 9000.0
	_player.place_on_track(20.0, 0.0, 0.0)


func _bench_end() -> void:
	_player.road_bounds_enabled = true
	_player.slope_enabled = true
	_player.collision_mask = Layers.WORLD | Layers.RIVAL
	_player.place_on_track(40.0, RoadTrack.corridor_center(1), 20.0)
	_world.scatter_traffic_ahead(_player.track_offset)
	for rival in _world.rivals:
		rival.offset = _player.track_offset + 15.0 + _rng.randf() * 40.0


func _release_all() -> void:
	for a: String in [
		"ride_throttle",
		"ride_brake",
		"ride_left",
		"ride_right",
		"ride_boost",
		"hit_left",
		"hit_right"
	]:
		if Input.is_action_pressed(a):
			Input.action_release(a)


## Fase 0 - aceleracao ------------------------------------------------------
func _phase_accel(_delta: float) -> void:
	Input.action_press("ride_throttle")
	if _t_to_100 < 0.0 and _player.speed * KMH >= 100.0:
		_t_to_100 = _t
	_top_speed = maxf(_top_speed, _player.speed)
	if _t >= 22.0:
		_metric("aceleracao_0_100_s", _t_to_100)
		_report.append("0-100 km/h          %.2f s" % _t_to_100)
		_metric("velocidade_22s_kmh", _top_speed * KMH)
		_report.append(
			(
				"velocidade em 22s   %.1f km/h  (teto do tuning %.1f)"
				% [_top_speed * KMH, _tuning.max_speed * KMH]
			)
		)
		_check(
			_t_to_100 > 0.0 and _t_to_100 < 9.0,
			"0-100 em %.2fs: acima de 9s a moto nao parece uma moto" % _t_to_100
		)
		_check(
			_top_speed >= _tuning.max_speed * 0.86,
			(
				"so chegou a %.0f%% do teto em 22s - a cauda da curva de aceleracao esta morta"
				% (100.0 * _top_speed / _tuning.max_speed)
			)
		)
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
		_metric("freada_tempo_s", _brake_time)
		_metric("freada_distancia_m", _brake_distance)
		_report.append(
			(
				"freada %.0f km/h -> 0   %.2f s / %.0f m"
				% [_brake_from * KMH, _brake_time, _brake_distance]
			)
		)
		_check(
			_brake_time < 6.0, "freada de %.2fs e longa demais pro ritmo do corredor" % _brake_time
		)
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
		_metric("inclinacao_0_90_s", _lean_rise_time)
		_report.append("inclinacao 0->90%%    %.2f s" % _lean_rise_time)
		_check(
			_lean_rise_time > 0.05,
			"a moto assume a inclinacao maxima instantaneamente - nao tem peso nenhum"
		)
		_check(
			_lean_rise_time > 0.0 and _lean_rise_time < 1.2,
			"demora %.2fs pra inclinar: nesse tempo o corredor ja fechou" % _lean_rise_time
		)
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
		_metric("guinada_graus_s", _yaw_rate)
		_metric("raio_curva_m", _turn_radius)
		_report.append(
			"a %.0f km/h: %.1f graus/s, raio %.0f m" % [mean_speed * KMH, _yaw_rate, _turn_radius]
		)
		# Inclinar pra DIREITA tem que mover a moto pra direita na pista. Parece
		# obvio e nao e: em Godot guinada positiva gira pra esquerda, e o erro
		# de sinal passa despercebido porque a assistencia de alinhamento
		# disfarca ate a moto encostar no guard-rail.
		var drift := _player.track_lateral - _lateral_at_mark
		_check(
			drift > 1.0,
			(
				"inclinou pra direita e a moto foi %.1f m pra ESQUERDA - sinal da guinada invertido"
				% -drift
			)
		)
		_check(_yaw_rate > 1.0, "a moto praticamente nao vira no talo")
		_check(
			_turn_radius < 260.0,
			"raio de %.0fm no talo: a moto nao consegue seguir a propria pista" % _turn_radius
		)
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
		_metric("soco_janela_s", _punch_frames / 60.0)
		_report.append(
			"hitbox do soco       %.3f s aberta (tuning pede %.3f)" % [window, _tuning.punch_active]
		)
		_check(_punch_frames > 0, "a hitbox do soco nunca abriu")
		_check(
			absf(window - _tuning.punch_active) < 0.05,
			"janela medida (%.3fs) nao bate com o tuning (%.3fs)" % [window, _tuning.punch_active]
		)
		_next_phase()


## Fase 5 - calcada: a valvula de escape quando o transito fecha ----------
##
## Existia um buraco de cobertura aqui, e ele estava escrito no PROTOTIPO.md:
## o piloto automatico da corrida solta nunca sobe na calcada, porque
## `free_lateral` so considera centros de faixa e de corredor. Entao "a parede
## invisivel voltou pro meio do acostamento" e "o teto de velocidade sumiu"
## eram regressoes que nenhum numero pegava - so o polegar, jogando.
func _phase_sidewalk(_delta: float) -> void:
	if _t < 0.02:
		# Limites ligados: e justamente a parede que esta sendo medida. A ladeira
		# fica de fora - medir velocidade numa subida mede a subida.
		_player.road_bounds_enabled = true
		_player.slope_enabled = false
		_player.place_on_track(200.0, RoadTrack.lane_center(RoadTrack.LANE_COUNT - 1), 20.0)

	Input.action_press("ride_throttle")

	if _t < 6.0:
		# Primeiro trecho: no asfalto, pra ter com o que comparar depois.
		_set_action("ride_right", false)
		_asphalt_speed = maxf(_asphalt_speed, _player.speed)
		return

	# Segundo trecho: encosta pra fora ate subir na calcada e achar a parede.
	_set_action("ride_right", true)
	# Velocidade ESTABILIZADA, nao o pico: ao subir, a moto ainda esta sendo
	# puxada pro teto pelo sidewalk_drag, e medir o transiente mediria a
	# descida da curva em vez do patamar em que ela para.
	if absf(_player.track_lateral) > RoadTrack.half_width() and _t > 12.0:
		_sidewalk_speed = _player.speed
	_max_lateral = maxf(_max_lateral, absf(_player.track_lateral))

	if _t >= 16.0:
		_metric("calcada_velocidade_asfalto_ms", _asphalt_speed)
		_metric("calcada_velocidade_calcada_ms", _sidewalk_speed)
		_metric("calcada_lateral_max_m", _max_lateral)
		_report.append(
			(
				"calcada              %.1f m/s no asfalto, %.1f m/s na calcada, parede em %.2f m"
				% [_asphalt_speed, _sidewalk_speed, _max_lateral]
			)
		)
		_check(
			_sidewalk_speed > 1.0,
			"a moto nao chegou a andar na calcada - ou nao subiu, ou parou de andar la"
		)
		# A calcada e grama do Mario Kart: da pra fugir por ela, mas custa tempo.
		# Se nao custar, ela vira a linha rapida e o corredor morre - e o
		# corredor e o jogo. O teto e uma regra declarada no tuning, entao e
		# contra ela que se mede, nao contra um numero escolhido aqui.
		var cap := _tuning.max_speed * _tuning.sidewalk_speed_factor
		_check(
			_sidewalk_speed <= cap + 1.5,
			(
				"calcada a %.1f m/s com teto de %.1f: o sidewalk_speed_factor parou de valer"
				% [_sidewalk_speed, cap]
			)
		)
		_check(
			_sidewalk_speed < _asphalt_speed,
			(
				"calcada a %.1f m/s contra %.1f no asfalto: fugir por ela nao custa nada"
				% [_sidewalk_speed, _asphalt_speed]
			)
		)
		# A parede nao pode vazar nem ficar aquem: aquem e parede invisivel no
		# meio de uma coisa com cara de andavel.
		_check(
			absf(_max_lateral - RoadTrack.sidewalk_limit()) < 0.2,
			(
				"a moto parou em %.2f m e o limite andavel e %.2f m"
				% [_max_lateral, RoadTrack.sidewalk_limit()]
			)
		)
		_next_phase()


## Fase 6 - combate: o soco que derruba rival ----------------------------
##
## O pilar do combate lateral era o unico "jogavel" do PROTOTIPO.md sem uma
## medida sequer. Isto mede a cadeia inteira, do jeito que o jogador a usa:
## hitbox do soco -> punch_landed -> World -> receive_hit -> empurrao lateral.
func _phase_combat(_delta: float) -> void:
	var rival: RivalBike = _world.rivals[0] if not _world.rivals.is_empty() else null
	if rival == null:
		_report.append("combate              nenhum rival na rota")
		_check(false, "nenhum rival existe - o pilar do combate nao tem como ser medido")
		_next_phase()
		return

	if _t < 0.02:
		_player.road_bounds_enabled = false
		_player.collision_mask = Layers.WORLD | Layers.RIVAL
		_player.place_on_track(400.0, RoadTrack.lane_center(1), 26.0)
		# O rival entra na faixa da direita, emparelhado: e a situacao em que o
		# combate acontece de verdade, lado a lado no meio do transito.
		rival.offset = _player.track_offset + 0.6
		rival.lateral = RoadTrack.lane_center(2)
		rival.speed = _player.speed
		_rival_lateral_before = rival.lateral
		if not rival.went_down.is_connected(_on_rival_down):
			rival.went_down.connect(_on_rival_down)

	# Segura o rival colado enquanto a janela do soco nao abriu: o que esta
	# sendo medido e o efeito do soco, nao a perseguicao.
	rival.offset = _player.track_offset + 0.6
	rival.speed = _player.speed
	_set_action("ride_throttle", true)

	if _t > 0.4 and not _punch_thrown:
		_punch_thrown = true
		Input.action_press("hit_right")
	elif _punch_thrown:
		_set_action("hit_right", false)

	if rival.state == RivalBike.State.STAGGERED or rival.state == RivalBike.State.DOWN:
		_rival_staggered = true
	_rival_shove = maxf(_rival_shove, absf(rival.lateral - _rival_lateral_before))

	if _t >= 3.0:
		_metric("combate_empurrao_m", _rival_shove)
		_report.append(
			(
				"combate              rival empurrado %.2f m, %s"
				% [_rival_shove, "cambaleou" if _rival_staggered else "NAO reagiu"]
			)
		)
		_check(
			_rival_staggered, "o soco acertou e o rival nao cambaleou - a cadeia do combate quebrou"
		)
		# O empurrao e o combate: sem deslocamento lateral nao da pra jogar o
		# rival dentro de um carro parado, que e o golpe do Road Rash.
		_check(
			_rival_shove > 0.1,
			"o rival mal saiu do lugar (%.2f m): o soco vira cosmetico" % _rival_shove
		)
		_next_phase()


## Fase 7 - bifurcacao: entra no atalho e volta pra avenida ----------------
##
## Esta e a fase que existe por medo. Trocar a pista de referencia embaixo da
## moto e a coisa mais fragil que o mundo faz: erra o palpite do offset e a
## moto reprojeta a 200 m dali, erra a volta e a entrega nunca completa. Nada
## disso aparece jogando cinco minutos - so na vez em que voce pega o atalho.
func _phase_fork(_delta: float) -> void:
	if _world.branches.is_empty():
		_report.append("bifurcacao           a rota nao abriu nenhuma")
		_check(false, "nenhum atalho nasceu na rota - a busca pela corda parou de achar")
		_next_phase()
		return

	var branch: RouteBranch = _world.branches[0]
	if _t < 0.02:
		# Limites e ladeira de volta: sem os limites o mundo nem avalia a boca,
		# e e justamente isso que esta sendo medido. A colisao continua
		# desligada e o transito continua estacionado a 9 km daqui, pra a
		# medida ser sobre a bifurcacao e nao sobre o transito do dia.
		_player.road_bounds_enabled = true
		_player.slope_enabled = true
		_player.place_on_track(
			branch.from_offset - 70.0,
			RoadTrack.lane_center(RoadTrack.LANE_COUNT - 1 if branch.side > 0.0 else 0),
			30.0
		)
		_last_progress = _world.player_progress()

	# Piloto: segue o sentido da pista e se encosta no lado da boca ate entrar.
	var basis := _player.track.sample_basis(_player.track_offset)
	var road_heading := atan2((-basis.z).x, (-basis.z).z)
	var want := branch.side * 4.6 if _world.player_on_route() else 0.0
	var steer := -wrapf(road_heading - _player.heading, -PI, PI)
	steer += clampf((want - _player.track_lateral) * 0.09, -0.35, 0.35)
	_set_action("ride_throttle", true)
	_set_action("ride_right", steer > 0.02)
	_set_action("ride_left", steer < -0.02)

	# Progresso e a unica coisa que nao pode andar pra tras: o cronometro e a
	# reciclagem do transito leem dele.
	var progress: float = _world.player_progress()
	_fork_backstep = minf(_fork_backstep, progress - _last_progress)
	_last_progress = progress

	if not _world.player_on_route():
		_fork_entered = true
	elif _fork_entered and _fork_time < 0.0:
		_fork_time = _t

	if _fork_time > 0.0 or _t > 25.0:
		_check(
			(
				_world._branch_separation(branch.road, branch.from_offset, branch.to_offset)
				>= World.BRANCH_MIN_APART
			),
			"o atalho passa colado na avenida - na tela isso vira uma pista so, larga demais"
		)
		_metric("atalho_comprimento_m", branch.road.length)
		_metric("atalho_economia_m", branch.saving())
		_report.append(
			(
				"bifurcacao           atalho de %.0f m no lugar de %.0f m (-%.0f m)"
				% [branch.road.length, branch.to_offset - branch.from_offset, branch.saving()]
			)
		)
		_check(_fork_entered, "passou pela boca do atalho pelo lado certo e seguiu reto na avenida")
		_check(_fork_time > 0.0, "entrou no atalho e nao voltou pra avenida em 25s")
		_check(
			_fork_backstep > -2.0,
			"o progresso andou %.1f m pra TRAS na troca de pista" % -_fork_backstep
		)
		_next_phase()


## Fase 8 - corrida solta: le a pista de verdade ---------------------------
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

	var waiting := 0
	for car in _world.traffic:
		if car.waiting:
			waiting += 1
	_max_waiting = maxi(_max_waiting, waiting)

	if not _shots_dir.is_empty() and _t >= _shots_next:
		_shots_next += 2.5
		_capture("%s/rushfood_%02d.png" % [_shots_dir, _shots_taken])
		_shots_taken += 1

	if _trace and _t >= _trace_next:
		_trace_next += 1.0
		print(
			(
				"  t=%4.1f  off=%7.1f  lat=%6.2f  v=%6.1f km/h  y=%6.2f  estado=%d  quedas=%d"
				% [
					_t,
					_player.track_offset,
					_player.track_lateral,
					_player.speed * KMH,
					_player.global_position.y,
					_player.state,
					_world.run.crashes
				]
			)
		)

	if not is_finite(_player.global_position.x) or not is_finite(_player.speed):
		_check(false, "posicao ou velocidade viraram NaN")
		_finish()
		return

	if _t >= 45.0 or _world.run.phase != DeliveryRun.Phase.RIDING:
		_metric("corrida_distancia_m", _world.run.distance_done)
		_metric("corrida_raspadas", _world.run.near_misses)
		_metric("corrida_quedas", _world.run.crashes)
		_report.append(
			(
				"corrida solta 45s    %.0f m percorridos, %d raspadas, %d quedas"
				% [_world.run.distance_done, _world.run.near_misses, _world.run.crashes]
			)
		)
		var rows := int(_world.world_tuning.jam_length / _world.world_tuning.jam_row_gap)
		var jam_length := float(rows) * _world.world_tuning.jam_row_gap
		var corridor := (
			RoadTrack.LANE_WIDTH * (1.0 + _world.world_tuning.jam_spread) - TrafficCar.SIZE.x
		)
		_metric("transito_parados_max", _max_waiting)
		_metric("transito_engarrafamentos", _world.jams_formed)
		_report.append(
			(
				"transito parando     %d carros no vermelho de uma vez, %d engarrafamentos"
				% [_max_waiting, _world.jams_formed]
			)
		)
		_metric("jam_fila_m", jam_length)
		_metric("jam_vao_m", corridor)
		_report.append(
			(
				"fila parada          %.0f m de fila, vao de %.2f m entre as colunas"
				% [jam_length, corridor]
			)
		)
		_check(_max_waiting > 0, "nenhum carro chegou a parar num semaforo em 45s")
		_check(_world.jams_formed > 0, "nenhum engarrafamento se formou em 45s")
		_check(
			jam_length >= 40.0,
			"fila de %.0f m: o jogador atravessa antes de perceber que era parede" % jam_length
		)
		# A moto tem 0,75 m. Com menos de 1,60 de vao sobram menos de 40 cm de
		# cada lado, e o corredor deixa de ser linha pra virar sorte.
		_check(
			corridor >= 1.6,
			"vao de %.2f m entre as colunas do engarrafamento: apertado demais" % corridor
		)
		_check(
			_world.run.distance_done > 700.0,
			(
				"so andou %.0fm em 45s - o piloto automatico nao consegue atravessar o transito"
				% _world.run.distance_done
			)
		)
		_check(_player.global_position.y > -50.0, "a moto caiu pra fora do mundo")
		_finish()


## Le `--fase <nome>` da linha de comando.
##
## Roda da primeira fase ate a pedida e para ali. As fases nao sao
## independentes - a freada precisa da velocidade que a aceleracao
## construiu - entao pular pro meio mediria outra coisa. O que se ganha e
## nao pagar os 45 s da corrida solta pra conferir um ajuste de curva.
func _read_phase_arg() -> void:
	var args := OS.get_cmdline_user_args()
	var pedida := ""
	for i: int in args.size():
		if args[i].begins_with("--fase="):
			pedida = args[i].substr(7)
		elif args[i] == "--fase" and i + 1 < args.size():
			pedida = args[i + 1]
	if pedida.is_empty():
		return
	var indice_fase := PHASE_NAMES.find(pedida)
	if indice_fase < 0:
		push_error("fase desconhecida: %s (use uma de %s)" % [pedida, PHASE_NAMES])
		get_tree().quit(2)
		return
	_stop_after = indice_fase
	print("fase: parando depois de '%s'" % pedida)


## So pra a fase de combate saber que o rival caiu de verdade.
func _on_rival_down() -> void:
	_rival_staggered = true


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


## Registra uma medida em forma de maquina, alem da linha de relatorio.
##
## O relatorio e pra pessoa ler; isto e pro baseline comparar. Enquanto o
## numero so existia como prosa, saber se ele andou dependia de alguem
## lembrar qual era o valor de ontem.
func _metric(chave: String, valor: float) -> void:
	_metrics[chave] = valor


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


## Despeja as medidas em JSON, se RUSHFOOD_SELFTEST_METRICS apontar um
## arquivo. E assim que o `dev.py baseline` compara uma rodada com a
## anterior sem depender de ninguem transcrever numero a mao.
func _write_metrics() -> void:
	var destino := OS.get_environment("RUSHFOOD_SELFTEST_METRICS")
	if destino.is_empty():
		return
	var arquivo := FileAccess.open(destino, FileAccess.WRITE)
	if arquivo == null:
		push_error("nao consegui gravar as metricas em %s" % destino)
		return
	arquivo.store_string(JSON.stringify(_metrics, "\t", true) + "\n")
	arquivo.close()


func _finish() -> void:
	set_physics_process(false)
	_write_metrics()
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
