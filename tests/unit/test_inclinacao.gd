extends GdUnitTestSuite
## A mola da inclinacao: deita sem passar do pedido, volta seca e passa do zero.
##
## O banco de provas so mede o 0->90% da entrada. A volta, a contra-inclinacao
## e o teto ficam aqui: sao o que separa mola de `lerp`, e nenhum deles muda
## raio de curva nem tempo de volta, entao regredir neles nao acenderia nada.
## O banco tambem so roda a CG: a PCX e a XRE (V05a) so tem rede aqui.

const PASSO: float = 1.0 / 60.0


## Roda a mola por `segundos` atras de `alvo`, partindo de `inicio` parado.
## Devolve [final, menor, maior, tempo ate 90% do caminho].
func _rodar(
	tuning: BikeTuning, inicio: float, alvo: float, segundos: float, moto: FisicaDaMoto = null
) -> Array:
	var estado := Vector2(inicio, 0.0)
	var menor := inicio
	var maior := inicio
	var t90 := -1.0
	for i in int(segundos / PASSO):
		estado = PlayerBike.passo_da_inclinacao(estado.x, estado.y, alvo, PASSO, tuning, moto)
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
	for modelo in Entregador.CENAS.size():
		var moto := FisicaDaMoto.de(modelo)
		# Solta de um lado e, no meio da contra-inclinacao, pede o outro
		# inteiro: a mola critica entra com embalo e passaria do teto sem o
		# corte.
		var estado := Vector2(-teto, 0.0)
		var maior := 0.0
		for i in int(0.12 / PASSO):
			estado = PlayerBike.passo_da_inclinacao(estado.x, estado.y, 0.0, PASSO, tuning, moto)
		for i in int(2.0 / PASSO):
			estado = PlayerBike.passo_da_inclinacao(estado.x, estado.y, teto, PASSO, tuning, moto)
			maior = maxf(maior, estado.x)
		assert_float(maior).override_failure_message(Entregador.NOMES[modelo]).is_less_equal(
			teto + 1e-5
		)


## O aceite da V05a e dizer de olho fechado qual moto e pela troca de lado. A
## ficha da hoje 0,42 / 0,5 / 0,65 s; os 10% de folga pegam uma ficha errada
## que encoste uma moto na outra, sem reprovar a ficha corrigida de um ano.
func test_pcx_deita_mais_rapido_e_xre_mais_devagar() -> void:
	var tuning := BikeTuning.new()
	var teto := deg_to_rad(tuning.max_lean)
	var cg: float = _rodar(tuning, 0.0, teto, 2.0, FisicaDaMoto.de(Entregador.Modelo.CG_160))[3]
	var pcx: float = _rodar(tuning, 0.0, teto, 2.0, FisicaDaMoto.de(Entregador.Modelo.PCX_160))[3]
	var xre: float = _rodar(tuning, 0.0, teto, 2.0, FisicaDaMoto.de(Entregador.Modelo.XRE_300))[3]
	assert_float(pcx).is_less(cg * 0.9)
	assert_float(xre).is_greater(cg * 1.1)


## A volta tambem separa as tres: a PCX passa mais do zero (6,6 graus), a XRE
## assenta (2,0). Nenhuma passa da faixa do video (8) nem fica sem passar.
func test_contra_inclinacao_por_moto() -> void:
	var tuning := BikeTuning.new()
	var passou: Array[float] = []
	for modelo in Entregador.CENAS.size():
		var moto := FisicaDaMoto.de(modelo)
		var r := _rodar(tuning, deg_to_rad(25.0), 0.0, 2.0, moto)
		var graus := rad_to_deg(-float(r[1]))
		passou.append(graus)
		assert_float(graus).override_failure_message(Entregador.NOMES[modelo]).is_between(1.0, 8.0)
		assert_float(absf(r[0])).is_less(deg_to_rad(0.1))
		# Voltar continua bem mais rapido que deitar em todas.
		var teto := deg_to_rad(tuning.max_lean)
		var deitar: float = _rodar(tuning, 0.0, teto, 2.0, moto)[3]
		var voltar: float = _rodar(tuning, teto, 0.0, 2.0, moto)[3]
		assert_float(deitar / voltar).override_failure_message(Entregador.NOMES[modelo]).is_greater(
			2.0
		)
	var pcx := passou[Entregador.Modelo.PCX_160]
	var cg := passou[Entregador.Modelo.CG_160]
	var xre := passou[Entregador.Modelo.XRE_300]
	assert_float(pcx).is_greater(cg + 1.0)
	assert_float(xre).is_less(cg - 1.0)


## Moto nova so nasce calibrada se tiver ficha. Sem ela, `FisicaDaMoto.de`
## cai na CG calado, e ninguem percebe que a moto nova anda igual.
func test_toda_moto_tem_ficha() -> void:
	for modelo in Entregador.CENAS.size():
		(
			assert_object(FichaDaMoto.de(modelo))
			. override_failure_message("%s sem ficha" % Entregador.NOMES[modelo])
			. is_not_null()
		)


func test_diametro_do_pneu_pela_lateral() -> void:
	# 21" = 533,4 mm de aro, mais duas paredes de 90 x 90%.
	assert_float(FichaDaMoto.diametro_mm("90/90-21")).is_equal_approx(695.4, 0.01)


func test_cg_e_a_referencia() -> void:
	var cg := FisicaDaMoto.de(Entregador.Modelo.CG_160)
	assert_float(cg.deitar).is_equal_approx(1.0, 1e-6)
	assert_float(cg.voltar).is_equal_approx(1.0, 1e-6)
	assert_float(cg.amortecer).is_equal_approx(1.0, 1e-6)
