extends GdUnitTestSuite
## O rival tem tudo que o jogador tem: amassar o que amassa, raspar, desviar na
## quina, quicar, cair e usar o nitro, pelas mesmas regras (`ImpactoDeMoto`,
## `FisicaDaMoto`). Moto e piloto se escrevem para todos (CLAUDE.md).
##
## O ultimo teste e a trava: capacidade nova do jogador, anunciada por um
## sinal, nao entra sem alguem decidir se o rival a tem tambem.

## Sinais do `PlayerBike` que existem so por causa do jogador, e por que. Todo
## sinal novo tem de cair aqui ou ganhar o equivalente no `RivalBike`.
const SO_DO_JOGADOR: Dictionary = {
	"crashed": "pontuacao e camera do jogador; o rival avisa a queda em went_down",
	"scraped": "estilo e shake do jogador; o rival faz a faisca direto no Estrago",
	"punch_landed": "o mundo aplica o golpe no alvo; o rival acerta por hit_player",
	"took_hit": "estilo e shake do jogador; o rival leva o golpe em receive_hit",
	"obstaculo_quebrado": "shake da camera do jogador; o rival amassa e faisca direto",
}

## Estado e comportamento do `PlayerBike` que o `RivalBike` precisa ter com o
## mesmo nome.
const IGUAIS: PackedStringArray = [
	"adrenaline",
	"boosting",
	"speed",
	"state",
	"usar_sprite",
	"usar_cadencia",
	"receive_hit",
]


func _pista() -> RoadTrack:
	var pista: RoadTrack = auto_free(RoadTrack.new())
	pista.build(300.0, RandomNumberGenerator.new())
	return pista


func _rival(modelo: int = 0) -> RivalBike:
	var mundo: Node = auto_free(Node.new())
	var jogador: PlayerBike = auto_free(PlayerBike.new())
	var rival: RivalBike = auto_free(RivalBike.new())
	add_child(rival)
	rival.setup(_pista(), BikeTuning.new(), WorldTuning.new(), mundo, jogador, Color.WHITE, 1)
	rival.reset_race(40.0, 0.0, 1000.0)
	rival._ator.trocar_modelo(modelo)
	rival._fisica = FisicaDaMoto.de(modelo)
	return rival


## Um poste `a_frente` metros na frente do rival.
func _poste_na_frente(rival: RivalBike, a_frente: float) -> Amassavel:
	var frente := -rival.global_basis.z
	frente.y = 0.0
	var pe := rival.global_position + frente.normalized() * a_frente
	pe.y = rival.global_position.y - RivalBike.SIZE.y * 0.5
	var poste: Amassavel = auto_free(Poste.criar(pe, Vector3.LEFT))
	add_child(poste)
	return poste


func test_rival_amassa_e_cai_no_poste_a_toda_velocidade_em_todos_os_modelos() -> void:
	for modelo in Entregador.CENAS.size():
		var rival := _rival(modelo)
		rival.speed = rival.tuning.max_speed
		var poste := _poste_na_frente(rival, 1.0)
		assert_bool(rival._bate(poste)).is_true()
		assert_float(poste.amassado).is_greater(0.5)
		assert_int(rival.state).is_equal(RivalBike.State.DOWN)


func test_rival_devagar_encosta_no_poste_sem_amassar_nem_cair() -> void:
	for modelo in Entregador.CENAS.size():
		var rival := _rival(modelo)
		rival.speed = 1.0
		var poste := _poste_na_frente(rival, 1.0)
		rival._bate(poste)
		assert_float(poste.amassado).is_equal(0.0)
		assert_int(rival.state).is_not_equal(RivalBike.State.DOWN)


func test_batida_media_quica_em_vez_de_derrubar() -> void:
	# Abaixo de `crash_min_speed` o jogador quica; o rival tambem.
	var rival := _rival()
	rival.speed = rival.tuning.crash_min_speed * 0.8
	var poste := _poste_na_frente(rival, 1.0)
	rival._bate(poste)
	assert_int(rival.state).is_equal(RivalBike.State.STAGGERED)
	assert_float(rival.speed).is_less(rival.tuning.crash_min_speed * 0.8)


func test_empurrado_por_soco_cai_mesmo_devagar() -> void:
	# O combate do Road Rash: o soco empurra para dentro da lataria.
	var rival := _rival()
	rival.speed = 3.0
	rival.receive_hit(1, 7.5, 0.7)
	var poste := _poste_na_frente(rival, 1.0)
	rival._bate(poste)
	assert_int(rival.state).is_equal(RivalBike.State.DOWN)


func test_raspada_perde_velocidade_e_empurra_de_lado() -> void:
	var rival := _rival()
	rival.speed = 30.0
	var normal := rival.global_basis.x
	rival._raspa(normal, 0.5)
	assert_float(rival.speed).is_less(30.0)
	assert_float(absf(rival._empurrao)).is_greater(0.0)
	# O empurrao anda o rival de lado e se amortece sozinho.
	var antes := rival.lateral
	for i in 120:
		rival._advance(1.0 / 60.0)
	assert_float(absf(rival.lateral - antes)).is_greater(0.1)
	assert_float(absf(rival._empurrao)).is_less(0.05)


func test_rival_com_carga_abre_o_nitro_quando_fica_para_tras_e_gasta() -> void:
	for modelo in Entregador.CENAS.size():
		var rival := _rival(modelo)
		rival.ganhar_adrenalina(50.0)
		assert_bool(rival._quer_nitro(RivalBike.NITRO_ATRAS + 1.0)).is_true()
		assert_bool(rival._quer_nitro(RivalBike.NITRO_ALCANCOU + 1.0)).is_false()
		var sem_carga := _rival(modelo)
		assert_bool(sem_carga._quer_nitro(100.0)).is_false()


func test_nitro_do_rival_acelera_mais_e_gasta_a_carga() -> void:
	var com := _rival()
	var sem := _rival()
	# Os dois no mesmo ritmo; so um tem carga. O jogador esta longe a frente.
	com.world = auto_free(_MundoFalso.new(com.offset + 80.0))
	sem.world = com.world
	com.ganhar_adrenalina(100.0)
	for i in 60:
		com._drive(1.0 / 60.0)
		sem._drive(1.0 / 60.0)
	assert_bool(com.boosting).is_true()
	assert_float(com.speed).is_greater(sem.speed)
	assert_float(com.adrenaline).is_less(100.0)
	assert_float(com.adrenaline).is_equal_approx(100.0 - com.tuning.boost_drain, 1.0)


func test_o_nitro_e_as_regras_de_bater_sao_as_mesmas_do_jogador() -> void:
	var t := BikeTuning.new()
	assert_float(FisicaDaMoto.teto_de_velocidade(t, true)).is_equal(
		t.max_speed * t.boost_speed_mult
	)
	assert_float(FisicaDaMoto.teto_de_velocidade(t, false)).is_equal(t.max_speed)
	assert_float(FisicaDaMoto.carga_apos_nitro(t, 10.0, 10.0)).is_equal(0.0)
	assert_bool(ImpactoDeMoto.derruba(t.crash_min_speed, t, false)).is_true()
	assert_bool(ImpactoDeMoto.derruba(t.crash_min_speed, t, true)).is_false()
	assert_bool(ImpactoDeMoto.derruba(t.crash_min_speed - 1.0, t, false)).is_false()


func test_toda_capacidade_do_jogador_tem_dono_no_rival() -> void:
	var rival := _rival()
	var jogador: PlayerBike = auto_free(PlayerBike.new())
	for sinal: Dictionary in jogador.get_script().get_script_signal_list():
		var nome: String = sinal["name"]
		var no_rival := rival.has_signal(nome)
		var recado := "PlayerBike.%s e uma capacidade nova: o RivalBike a tem tambem? " % nome
		recado += "Se nao, ela entra em SO_DO_JOGADOR com o motivo."
		assert_bool(no_rival or SO_DO_JOGADOR.has(nome)).override_failure_message(recado).is_true()
	for nome in IGUAIS:
		var existe := nome in rival or rival.has_method(nome)
		assert_bool(existe).override_failure_message("RivalBike sem %s" % nome).is_true()


## O pouco que o rival pergunta ao mundo para pilotar.
class _MundoFalso:
	extends Node
	var _progresso: float

	func _init(progresso: float) -> void:
		_progresso = progresso

	func player_progress() -> float:
		return _progresso

	func player_on_route() -> bool:
		return true
