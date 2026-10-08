extends GdUnitTestSuite
## A porta do carro encostado: quando abre, de que lado, e onde o onibus para.
##
## O banco de provas nao ve nada disto: o piloto automatico passa longe da
## faixa da ponta, e a porta na cara pode nao disparar uma vez sequer na
## corrida dele. Uma porta que abre tarde demais - em cima da moto, sem tempo
## de reacao - so aparece aqui.

const PASSO: float = 1.0 / 60.0
const MEIO_FIO_ESQUERDO: float = -4.95
const MEIO_FIO_DIREITO: float = 4.95


## O `TrafficCar` so pergunta ao mundo quem e o jogador.
class MundoFalso:
	extends Node
	var player: PlayerBike


var _mundo: MundoFalso
var _jogador: PlayerBike


func _reta() -> RoadTrack:
	var pista: RoadTrack = auto_free(RoadTrack.new())
	pista.curve = Curve3D.new()
	pista.curve.add_point(Vector3.ZERO)
	pista.curve.add_point(Vector3(0.0, 0.0, -2000.0))
	pista.length = pista.curve.get_baked_length()
	return pista


## Um carro encostado em `lateral`, a 500 m, do modelo pedido (ou de qualquer
## um que nao seja onibus). O modelo sai da semente, entao procura uma que sirva.
func _carro(porta: TrafficCar.Porta, lateral: float, onibus: bool = false) -> TrafficCar:
	var pista := _reta()
	_mundo = auto_free(MundoFalso.new())
	add_child(_mundo)
	_jogador = auto_free(PlayerBike.new())
	_mundo.add_child(_jogador)
	_jogador.setup(BikeTuning.new(), pista, 0.0)
	_jogador.set_physics_process(false)
	_mundo.player = _jogador
	for semente in 200:
		var carro: TrafficCar = auto_free(TrafficCar.new())
		carro.world = _mundo
		carro.world_tuning = WorldTuning.new()
		_mundo.add_child(carro)
		carro.set_physics_process(false)
		carro.setup(pista, 500.0, lateral, semente, true, porta)
		if (carro.modelo() == Carro.Modelo.ONIBUS) == onibus:
			return carro
	assert_bool(false).override_failure_message("nenhuma semente deu o modelo").is_true()
	return null


func _aberta(carro: TrafficCar) -> bool:
	return carro.get("_door_open")


## O jogador a `segundos` de alcancar a traseira do carro, a 40 m/s.
func _jogador_a(carro: TrafficCar, segundos: float, lateral: float) -> void:
	_jogador.speed = 40.0
	_jogador.track_lateral = lateral
	_jogador.track_offset = carro.offset - carro.meio_comprimento() - 40.0 * segundos


func test_onibus_encostado_na_esquerda_vai_para_a_direita() -> void:
	var onibus := _carro(TrafficCar.Porta.NENHUMA, MEIO_FIO_ESQUERDO, true)
	assert_float(onibus.lateral).is_equal_approx(MEIO_FIO_DIREITO, 0.01)
	# Carro de passeio encosta onde foi mandado.
	var carro := _carro(TrafficCar.Porta.NENHUMA, MEIO_FIO_ESQUERDO)
	assert_float(carro.lateral).is_equal_approx(MEIO_FIO_ESQUERDO, 0.01)


func test_porta_aberta_de_longe_abre_ao_encostar_e_fica() -> void:
	var carro := _carro(TrafficCar.Porta.ABERTA, MEIO_FIO_DIREITO)
	assert_bool(_aberta(carro)).is_true()
	_jogador_a(carro, 0.5, MEIO_FIO_DIREITO - 2.0)
	for i in int(20.0 / PASSO):
		carro._physics_process(PASSO)
	assert_bool(_aberta(carro)).is_true()


func test_porta_na_cara_espera_o_jogador_e_abre_do_lado_dele() -> void:
	var carro := _carro(TrafficCar.Porta.NA_CARA, MEIO_FIO_DIREITO)
	assert_bool(_aberta(carro)).is_false()
	# Longe: nada.
	_jogador_a(carro, 3.0, MEIO_FIO_DIREITO - 3.3)
	carro._physics_process(PASSO)
	assert_bool(_aberta(carro)).is_false()
	# Na janela, na faixa vizinha: abre para o lado da pista, onde ele esta.
	_jogador_a(carro, 0.7, MEIO_FIO_DIREITO - 3.3)
	carro._physics_process(PASSO)
	assert_bool(_aberta(carro)).is_true()
	assert_int(carro.get("_door_side")).is_equal(-1)
	# Fecha sozinha, e nao abre de novo.
	for i in int(5.0 / PASSO):
		carro._physics_process(PASSO)
	assert_bool(_aberta(carro)).is_false()
	_jogador_a(carro, 0.7, MEIO_FIO_DIREITO - 3.3)
	carro._physics_process(PASSO)
	assert_bool(_aberta(carro)).is_false()


func test_porta_na_cara_nao_abre_em_quem_entra_no_ultimo_instante() -> void:
	var carro := _carro(TrafficCar.Porta.NA_CARA, MEIO_FIO_DIREITO)
	# Do outro lado da pista enquanto a janela passa: nada.
	_jogador_a(carro, 0.7, MEIO_FIO_ESQUERDO)
	carro._physics_process(PASSO)
	assert_bool(_aberta(carro)).is_false()
	# Cruza para perto a 0,2 s do carro: tarde demais, e tiro, nao susto.
	_jogador_a(carro, 0.2, MEIO_FIO_DIREITO - 2.0)
	carro._physics_process(PASSO)
	assert_bool(_aberta(carro)).is_false()


func test_onibus_nao_abre_porta_na_cara() -> void:
	var onibus := _carro(TrafficCar.Porta.NA_CARA, MEIO_FIO_DIREITO, true)
	_jogador_a(onibus, 0.7, MEIO_FIO_DIREITO - 3.3)
	onibus._physics_process(PASSO)
	assert_bool(_aberta(onibus)).is_false()
