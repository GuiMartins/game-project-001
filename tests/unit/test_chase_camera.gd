extends GdUnitTestSuite
## O giro da camera: acompanha a curva, nao o tremor do polegar.
##
## A camera copiava a inclinacao da moto direto, e a moto inclina na
## velocidade do input. Cada correcao pequena de trajetoria virava a tela
## balancando, e nenhum numero do banco de provas pega isso - ele nem roda com
## camera. O que se mede aqui e o filtro: inclinacao segurada chega inteira,
## inclinacao que vai e volta varias vezes por segundo quase nao chega.

const PASSO: float = 1.0 / 60.0


func _camera() -> Array:
	var tuning := BikeTuning.new()
	# Na arvore: a camera le a posicao global da moto. Sem pista, a moto nao
	# roda fisica - so o `lean` que o teste escreve importa.
	var moto: PlayerBike = auto_free(PlayerBike.new())
	add_child(moto)
	var camera: ChaseCamera = auto_free(ChaseCamera.new())
	add_child(camera)
	camera.setup(tuning, moto)
	return [camera, moto, tuning]


## O giro da camera em volta do eixo de visao. A camera mira com o "cima" do
## mundo, entao sem giro o eixo X dela e horizontal: o quanto ele sobe e o giro.
func _giro(camera: ChaseCamera) -> float:
	var base := camera.global_basis
	return atan2(base.x.y, base.y.y)


func test_curva_segurada_chega_inteira() -> void:
	var partes := _camera()
	var camera: ChaseCamera = partes[0]
	var moto: PlayerBike = partes[1]
	var tuning: BikeTuning = partes[2]
	moto.lean = deg_to_rad(30.0)
	for i in int(3.0 / PASSO):
		camera._process(PASSO)
	var esperado := deg_to_rad(30.0) * tuning.cam_lean_follow
	assert_float(absf(_giro(camera))).is_equal_approx(esperado, deg_to_rad(0.2))


func test_correcao_rapida_quase_nao_chega() -> void:
	var partes := _camera()
	var camera: ChaseCamera = partes[0]
	var moto: PlayerBike = partes[1]
	var tuning: BikeTuning = partes[2]
	# Tres correcoes por segundo, de 30 graus pra cada lado: o polegar
	# acertando a moto no corredor.
	var pior := 0.0
	for i in int(2.0 / PASSO):
		moto.lean = deg_to_rad(30.0) * sin(TAU * 3.0 * float(i) * PASSO)
		camera._process(PASSO)
		if float(i) * PASSO > 1.0:
			pior = maxf(pior, absf(_giro(camera)))
	# Copiando direto, o pior giro seria a inclinacao inteira vezes o
	# `cam_lean_follow`. O filtro tem que tirar a maior parte disso.
	var copiando := deg_to_rad(30.0) * tuning.cam_lean_follow
	assert_float(pior).is_less(copiando * 0.4)
