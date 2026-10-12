extends GdUnitTestSuite
## A mola da inclinacao: deita sem passar do pedido, volta seca e passa do zero.
##
## O banco de provas so mede o 0->90% da entrada. A volta, a contra-inclinacao
## e o teto ficam aqui: sao o que separa mola de `lerp`, e nenhum deles muda
## raio de curva nem tempo de volta, entao regredir neles nao acenderia nada.

const PASSO: float = 1.0 / 60.0


## Roda a mola por `segundos` atras de `alvo`, partindo de `inicio` parado.
## Devolve [final, menor, maior, tempo ate 90% do caminho].
func _rodar(tuning: BikeTuning, inicio: float, alvo: float, segundos: float) -> Array:
	var estado := Vector2(inicio, 0.0)
	var menor := inicio
	var maior := inicio
	var t90 := -1.0
	for i in int(segundos / PASSO):
		estado = PlayerBike.passo_da_inclinacao(estado.x, estado.y, alvo, PASSO, tuning)
		menor = minf(menor, estado.x)
		maior = maxf(maior, estado.x)
		if t90 < 0.0 and absf(estado.x - inicio) >= 0.9 * absf(alvo - inicio):
			t90 = float(i + 1) * PASSO
	return [estado.x, menor, maior, t90]


func test_deitar_nao_passa_do_pedido() -> void:
	var tuning := BikeTuning.new()
	var alvo := deg_to_rad(tuning.max_lean) * 0.6
	var r := _rodar(tuning, 0.0, alvo, 2.0)
	assert_float(r[2]).is_less_equal(alvo + 1e-4)
	assert_float(r[0]).is_equal_approx(alvo, deg_to_rad(0.1))


func test_soltar_passa_do_zero_e_assenta() -> void:
	var tuning := BikeTuning.new()
	var r := _rodar(tuning, deg_to_rad(25.0), 0.0, 2.0)
	# A contra-inclinacao do video e de 4-8 graus saindo de ~17-25.
	assert_float(rad_to_deg(-r[1])).is_between(3.0, 8.0)
	assert_float(absf(r[0])).is_less(deg_to_rad(0.1))


func test_voltar_e_mais_rapido_que_deitar() -> void:
	var tuning := BikeTuning.new()
	var teto := deg_to_rad(tuning.max_lean)
	var deitar: float = _rodar(tuning, 0.0, teto, 2.0)[3]
	var voltar: float = _rodar(tuning, teto, 0.0, 2.0)[3]
	# O video deita em ~1 s e levanta em 0,2-0,4 s: umas tres vezes.
	assert_float(deitar / voltar).is_greater(2.5)


func test_troca_de_lado_nao_passa_do_teto() -> void:
	var tuning := BikeTuning.new()
	var teto := deg_to_rad(tuning.max_lean)
	# Solta de um lado e, no meio da contra-inclinacao, pede o outro inteiro:
	# a mola critica entra com embalo e passaria do teto sem o corte.
	var estado := Vector2(-teto, 0.0)
	var maior := 0.0
	for i in int(0.12 / PASSO):
		estado = PlayerBike.passo_da_inclinacao(estado.x, estado.y, 0.0, PASSO, tuning)
	for i in int(2.0 / PASSO):
		estado = PlayerBike.passo_da_inclinacao(estado.x, estado.y, teto, PASSO, tuning)
		maior = maxf(maior, estado.x)
	assert_float(maior).is_less_equal(teto + 1e-5)
