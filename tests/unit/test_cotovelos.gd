extends GdUnitTestSuite
## O braco que muda sozinho: relaxa de vez em quando, segura na curva e repete
## com a mesma semente, que e o que deixa a prova visual congelada igual.

const PASSO: float = 1.0 / 60.0


func test_o_cotovelo_relaxa_as_vezes_e_repete_com_a_mesma_semente() -> void:
	var a := Cotovelos.new()
	var b := Cotovelos.new()
	var c := Cotovelos.new()
	var onde := Vector3(1.0, 0.0, -40.0)
	var soma := 0.0
	var maximo := [0.0, 0.0]
	var diferente := false
	var passos := 60 * 60
	for i in passos:
		a.passo(PASSO, 20.0, 0.0, onde)
		b.passo(PASSO, 20.0, 0.0, onde)
		c.passo(PASSO, 20.0, 0.0, onde + Vector3(2.0, 0.0, 0.0))
		for lado in 2:
			# Mesma semente, mesmo braco: a prova visual congelada depende disto.
			assert_float(b.relaxado(lado)).is_equal(a.relaxado(lado))
			maximo[lado] = maxf(maximo[lado], a.relaxado(lado))
			soma += a.relaxado(lado)
			diferente = diferente or not is_equal_approx(c.relaxado(lado), a.relaxado(lado))
	# Num minuto de cruzeiro, cada braco desce ao menos uma vez...
	assert_float(maximo[0]).is_greater(0.5)
	assert_float(maximo[1]).is_greater(0.5)
	# ...mas a maior parte do tempo e o losango do video.
	assert_float(soma / (2.0 * passos)).is_less(0.35)
	# Dois pilotos lado a lado nao relaxam em uniao.
	assert_bool(diferente).is_true()


func test_na_curva_fechada_ninguem_solta_o_braco() -> void:
	var cotovelos := Cotovelos.new()
	for i in 600:
		cotovelos.passo(PASSO, 5.0, 0.0, Vector3.ZERO)
	for i in 120:
		cotovelos.passo(PASSO, 30.0, 0.6, Vector3.ZERO)
	for lado in 2:
		assert_float(cotovelos.relaxado(lado)).is_less(0.01)
		# E aberto e para fora dos dois lados, espelhado.
		var polo := cotovelos.polo(lado)
		assert_float(polo.x * (-1.0 if lado == 0 else 1.0)).is_greater(0.9)
