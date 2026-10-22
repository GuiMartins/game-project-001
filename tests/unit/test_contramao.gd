extends GdUnitTestSuite
## A mao contraria da via expressa: vem de frente, nasce e some atras da
## fachada do predio do fundo das ruas da esquina, e anda sem um carro entrar
## no outro - inclusive onde as duas faixas viram uma so, na rua.
##
## Nenhum erro aparece se a fila travar ou dois carros se encavalarem na
## curva: o jogo continua rodando, com um onibus parado no meio da rua para
## sempre. Por isso o transito roda aqui por minuto e meio, nos dois lados.

const SEMENTE: int = 20260831
const PASSO: float = 1.0 / 60.0

var _track: RoadTrack


func before_test() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEMENTE
	_track = auto_free(RoadTrack.new())
	add_child(_track)
	_track.build(3200.0, rng)


func _contramao(lado: float) -> Contramao:
	var c: Contramao = auto_free(Contramao.criar(_track, Vector3(700.0, 1100.0, lado), 7))
	add_child(c)
	# O teste dirige o passo: o relogio da arvore nao entra na conta.
	c.set_physics_process(false)
	return c


## Onde o carro esta no caminho. Nao a posicao do corpo: com
## `sync_to_physics` ela so chega no proximo passo da fisica, e aqui o teste
## anda minutos num quadro so.
func _onde(c: Contramao, v: Contramao.Veiculo) -> Transform3D:
	return c._caminhos[v.faixa].em(v.s)


## `(offset, lateral)` de `p`. O `project` busca so em volta do palpite, e o
## palpite sai de uma varredura de 10 em 10 m.
func _na_pista(p: Vector3) -> Vector2:
	var palpite := 0.0
	var melhor := INF
	var o := 600.0
	while o < 1200.0:
		var d := _track.sample_position(o).distance_to(p)
		if d < melhor:
			melhor = d
			palpite = o
		o += 10.0
	return _track.project(p, palpite)


func _lados() -> Array[float]:
	return [Cidade.LADO_ESQUERDA, Cidade.LADO_DIREITA]


func test_ninguem_entra_em_ninguem_e_a_fila_nao_trava() -> void:
	for lado in _lados():
		var c := _contramao(lado)
		var no_comeco: Array = c._carros.duplicate()
		assert_int(no_comeco.size()).is_greater(8)
		var chegaram := {}
		var mais_perto := INF
		for i in int(90.0 / PASSO):
			c._physics_process(PASSO)
			for v: Contramao.Veiculo in c._garagem:
				chegaram[v] = true
			for a in c._carros.size():
				var pa := _onde(c, c._carros[a]).origin
				for b in range(a + 1, c._carros.size()):
					mais_perto = minf(mais_perto, pa.distance_to(_onde(c, c._carros[b]).origin))
		# Faixa vizinha fica a 3,5 m; menos que isso e lataria dentro de lataria.
		assert_float(mais_perto).is_greater(3.0)
		# Todo carro que estava na expressa na largada chegou na garagem da
		# entrada: a expressa tem 400 m e nao ha fila que segure 90 s.
		for v: Contramao.Veiculo in no_comeco:
			assert_bool(chegaram.has(v)).is_true()


func test_vem_de_frente() -> void:
	for lado in _lados():
		var c := _contramao(lado)
		for v: Contramao.Veiculo in c._carros:
			var t := _onde(c, v)
			var onde := _na_pista(t.origin)
			if onde.x > 720.0 and onde.x < 1080.0:
				var frente := -t.basis.z
				var da_pista := -_track.sample_basis(onde.x).z
				assert_float(frente.dot(da_pista)).is_less(-0.95)
				# Na metade da pista do lado do viaduto.
				assert_float(onde.y * lado).is_between(0.5, RoadTrack.half_width() - 0.5)


func test_nasce_e_some_atras_da_fachada() -> void:
	# Onde o carro aparece e some, ele esta inteiro atras da fachada do predio
	# do fundo da rua da esquina: e la que ele nasce, e nao do nada.
	var fachada := RoadTrack.half_width() + Cidade.RUA_COMPRIMENTO - 2.0
	for lado in _lados():
		var c := _contramao(lado)
		for caminho: Contramao.Caminho in c._caminhos:
			for d: float in [0.0, caminho.comprimento]:
				var p := caminho.em(d).origin
				var onde := _na_pista(p)
				assert_float(absf(onde.y)).is_greater(fachada + 4.0)


func test_a_largada_repete_o_transito() -> void:
	var c := _contramao(Cidade.LADO_ESQUERDA)
	for i in 300:
		c._physics_process(PASSO)
	c.reiniciar()
	var antes: Array[Vector3] = []
	for v: Contramao.Veiculo in c._carros:
		antes.append(_onde(c, v).origin)
	for i in 300:
		c._physics_process(PASSO)
	c.reiniciar()
	assert_int(c._carros.size()).is_equal(antes.size())
	for i in antes.size():
		assert_vector(_onde(c, c._carros[i]).origin).is_equal_approx(antes[i], Vector3.ONE * 0.01)


func test_trafego_zero_esvazia_e_a_mudanca_vale_ao_vivo() -> void:
	# O slider de trafego do F3 manda na mao contraria tambem, e sem reiniciar:
	# o Arthur pos 0 e o sentido contrario seguiu cheio.
	var c := _contramao(Cidade.LADO_ESQUERDA)
	var cheio := c._carros.size()
	assert_int(cheio).is_greater(0)
	c.ajustar_densidade(0.0)
	assert_int(c._carros.size()).is_equal(0)
	# Nem nasce carro novo enquanto o slider esta em zero.
	for i in 1200:
		c._physics_process(PASSO)
	assert_int(c._carros.size()).is_equal(0)
	c.ajustar_densidade(1.0)
	for i in 1200:
		c._physics_process(PASSO)
	assert_int(c._carros.size()).is_greater(0)


func test_metade_do_slider_deixa_metade_dos_carros() -> void:
	var c := _contramao(Cidade.LADO_DIREITA)
	var cheio := c._carros.size()
	c.ajustar_densidade(0.5)
	assert_int(c._carros.size()).is_equal(ceili(cheio * 0.5))
	# E a largada nova respeita o slider em vez de voltar ao cheio.
	c.reiniciar()
	assert_int(c._carros.size()).is_equal(ceili(cheio * 0.5))


func test_fracao_do_transito_chega_ao_cheio_no_valor_de_fabrica() -> void:
	var t := WorldTuning.new()
	assert_float(t.fracao_do_transito()).is_equal(1.0)
	t.traffic_count = 0
	assert_float(t.fracao_do_transito()).is_equal(0.0)
	t.traffic_count = 120
	assert_float(t.fracao_do_transito()).is_equal(1.0)
	t.traffic_count = WorldTuning.TRAFFIC_COUNT_CHEIO / 2
	assert_float(t.fracao_do_transito()).is_between(0.4, 0.6)
