extends GdUnitTestSuite
## O carro do transito por dentro: roda, mola, porta, luz e quem dirige.
##
## Nada disto aparece no banco de provas: a fisica do transito e a mesma com a
## roda girando para tras, a carroceria mergulhando na aceleracao ou a porta
## abrindo para dentro do banco. E o mesmo tipo de erro que o `test_entregador`
## caca - um sinal trocado que so se ve parando para olhar o carro de perto.

const PASSO: float = 1.0 / 60.0


func _carro(modelo: Carro.Modelo = Carro.Modelo.SEDA) -> Carro:
	var carro: Carro = auto_free(Carro.new())
	add_child(carro)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	carro.montar(modelo, rng)
	return carro


func _anda(
	carro: Carro,
	segundos: float,
	velocidade: float,
	lateral: float = 0.0,
	encostado: bool = false,
	seta: int = 0
) -> void:
	for i in int(segundos / PASSO):
		carro.atualizar(PASSO, velocidade, lateral, encostado, seta)


## A freada: `de` m/s ate `ate` m/s com a aceleracao dada, em m/s2.
func _muda(carro: Carro, de: float, ate: float, aceleracao: float) -> void:
	var v := de
	while not is_equal_approx(v, ate):
		v = move_toward(v, ate, absf(aceleracao) * PASSO)
		carro.atualizar(PASSO, v, 0.0, false, 0)


func _no(carro: Carro, nome: String) -> Node3D:
	return carro.find_child(nome, true, false) as Node3D


func _pos(carro: Carro, nome: String) -> Vector3:
	return carro.to_local(_no(carro, nome).global_position)


func test_cinco_modelos_do_menor_ao_onibus() -> void:
	var comprimentos: Array[float] = []
	for modelo: int in Carro.Modelo.values():
		var caixa := _carro(modelo).caixa()
		comprimentos.append(caixa.size.z)
		# No chao, no meio: o colisor sai daqui e bate onde se ve.
		assert_float(caixa.position.y).is_between(0.1, 0.45)
		assert_float(caixa.get_center().x).is_equal_approx(0.0, 0.02)
		assert_float(caixa.get_center().z).is_equal_approx(0.0, 0.15)
	assert_float(comprimentos[Carro.Modelo.HATCH]).is_less(comprimentos[Carro.Modelo.SEDA])
	assert_float(comprimentos[Carro.Modelo.ONIBUS]).is_greater(11.0)
	# O taxi e o seda com o luminoso: mais alto que ele.
	var taxi := _carro(Carro.Modelo.TAXI).caixa().size.y
	assert_float(taxi).is_greater(_carro(Carro.Modelo.SEDA).caixa().size.y + 0.1)


func test_roda_gira_para_a_frente() -> void:
	var carro := _carro()
	carro.atualizar(PASSO, 10.0, 0.0, false, 0)
	for nome: String in ["Roda_DE", "Roda_TD"]:
		var topo := _no(carro, nome).global_basis * Vector3.UP
		# A frente e -Z. Rodando para a frente, o topo da roda vai para la.
		assert_float(topo.z).is_less(0.0)


func test_freada_mergulha_o_nariz_e_acende_a_lanterna() -> void:
	var carro := _carro()
	_anda(carro, 2.0, 12.0)
	var lanterna: Vector3 = _no(carro, "Lataria").get_instance_shader_parameter("luzes")
	assert_float(lanterna.x).is_equal(0.0)
	_muda(carro, 12.0, 6.0, -4.5)
	var nariz := _no(carro, "Carroceria").global_basis * Vector3.FORWARD
	assert_float(nariz.y).is_less(-0.01)
	lanterna = _no(carro, "Lataria").get_instance_shader_parameter("luzes")
	assert_float(lanterna.x).is_equal(1.0)


func test_arrancada_levanta_o_nariz() -> void:
	var carro := _carro()
	_muda(carro, 0.0, 6.0, 2.5)
	var nariz := _no(carro, "Carroceria").global_basis * Vector3.FORWARD
	assert_float(nariz.y).is_greater(0.005)


func test_troca_de_faixa_guina_esterca_e_rola_para_fora() -> void:
	var carro := _carro()
	_anda(carro, 1.0, 6.0)
	# Comecando a ir para a direita: meio segundo de troca.
	_anda(carro, 0.4, 6.0, 1.6, false, 1)
	var frente := _no(carro, "Carroceria").global_basis * Vector3.FORWARD
	assert_float(frente.x).is_greater(0.02)
	# O eixo da roda, e nao a frente dela, que gira junto com o pneu. Estercada
	# para a direita, a ponta de fora do eixo vai para tras.
	var eixo := _no(carro, "Roda_DD").global_basis * Vector3.RIGHT
	var lado := _no(carro, "Carroceria").global_basis * Vector3.RIGHT
	assert_float(eixo.z).is_greater(lado.z + 0.02)
	# Puxado para a direita, o carro deita para a esquerda: o lado de fora do
	# movimento sobe.
	var direita := _no(carro, "Carroceria").global_basis * Vector3.RIGHT
	assert_float(direita.y).is_greater(0.005)


func test_volante_vira_para_o_lado_e_as_maos_vao_junto() -> void:
	var carro := _carro()
	var volante := _no(carro, "Volante")
	var pegas: Array[Vector3] = []
	for lado: String in ["E", "D"]:
		pegas.append(volante.to_local(_no(carro, "Mao_" + lado).global_position))
	var topo := volante.to_local(volante.global_position + volante.global_basis * Vector3.UP)
	_anda(carro, 1.0, 6.0)
	_anda(carro, 0.4, 6.0, 1.6, false, 1)
	# Virando a direita, o topo do aro vai para a direita do motorista.
	var topo_agora := volante.global_basis * topo.normalized()
	var direita := _no(carro, "Carroceria").global_basis * Vector3.RIGHT
	assert_float(topo_agora.dot(direita)).is_greater(0.05)
	for i in 2:
		var mao := _no(carro, "Mao_" + ["E", "D"][i]).global_position
		assert_float(mao.distance_to(volante.to_global(pegas[i]))).is_less(0.01)


func test_porta_abre_para_fora_e_fecha() -> void:
	for lado: int in [-1, 1]:
		var carro := _carro()
		var meia := carro.caixa().size.x * 0.5
		carro.abrir_porta(lado)
		var porta := carro.porta_ativa()
		assert_object(porta).is_not_null()
		_anda(carro, 1.5, 0.0, 0.0, true)
		assert_float(carro.abertura()).is_greater(0.9)
		# A ponta de tras da porta saiu para o lado dela, longe da lataria.
		var ponta := carro.to_local(porta.to_global(Vector3(0.0, 0.5, porta.get_aabb().end.z)))
		assert_float(ponta.x * float(lado)).is_greater(meia + 0.5)
		carro.fechar_portas()
		_anda(carro, 1.5, 0.0, 0.0, true)
		assert_float(carro.abertura()).is_less(0.01)


func test_folha_do_onibus_dobra_para_dentro() -> void:
	var onibus := _carro(Carro.Modelo.ONIBUS)
	var folhas: Array[String] = ["Folha_1A", "Folha_1B", "Folha_2A", "Folha_2B"]
	var antes: Array[float] = []
	for nome in folhas:
		var folha := _no(onibus, nome) as MeshInstance3D
		antes.append(onibus.to_local(folha.to_global(folha.get_aabb().get_center())).x)
	onibus.abrir_porta(1)
	_anda(onibus, 2.0, 0.0, 0.0, true)
	for i in folhas.size():
		var folha := _no(onibus, folhas[i]) as MeshInstance3D
		var agora := onibus.to_local(folha.to_global(folha.get_aabb().get_center())).x
		assert_float(agora).is_less(antes[i] - 0.15)
	# Porta de onibus dobra para dentro: nao ha o que bater no corredor.
	assert_object(onibus.porta_ativa()).is_null()


func test_encostado_pisca_alerta() -> void:
	var carro := _carro()
	var acendeu := Vector2.ZERO
	for i in 60:
		carro.atualizar(PASSO, 0.0, 0.0, true, 0)
		var luzes: Vector3 = _no(carro, "Lataria").get_instance_shader_parameter("luzes")
		acendeu += Vector2(luzes.y, luzes.z)
		# Pisca-alerta: as duas juntas, sempre.
		assert_float(luzes.y).is_equal(luzes.z)
	assert_float(acendeu.x).is_greater(0.0)


func test_vidro_e_transparente() -> void:
	for modelo: int in Carro.Modelo.values():
		var lataria := _no(_carro(modelo), "Lataria") as MeshInstance3D
		var tem_vidro := false
		for s in lataria.mesh.get_surface_count():
			var material := lataria.get_surface_override_material(s) as ShaderMaterial
			tem_vidro = tem_vidro or material.shader == Carro.SHADER_VIDRO
		assert_bool(tem_vidro).is_true()


func test_motorista_dentro_da_cabine() -> void:
	for modelo: int in Carro.Modelo.values():
		var carro := _carro(modelo)
		var caixa := carro.caixa()
		var cabeca := _pos(carro, "Cabeca")
		assert_bool(caixa.grow(-0.05).has_point(cabeca)).is_true()
		# Do lado esquerdo, como no Brasil.
		assert_float(cabeca.x).is_less(-0.2)


func test_cores_de_fabrica_batem_com_a_textura() -> void:
	# Le o PNG que o gerador escreveu, nao a textura importada: e ele que o
	# `arte/carros.py` regera quando a paleta muda.
	var albedo := Image.load_from_file(
		ProjectSettings.globalize_path("res://assets/carros/carros_albedo.png")
	)
	var mascara := Image.load_from_file(
		ProjectSettings.globalize_path("res://assets/carros/carros_mascara.png")
	)
	# A pintura e a celula mais clara sob o canal R; pele e camisas, a unica
	# sob o seu degrau do canal G.
	var mais_clara := Color.BLACK
	var por_degrau: Dictionary[int, Color] = {}
	for y in range(4, albedo.get_height(), 8):
		for x in range(4, albedo.get_width(), 8):
			var cor := albedo.get_pixel(x, y)
			var m := mascara.get_pixel(x, y)
			if m.r > 0.5 and cor.get_luminance() > mais_clara.get_luminance():
				mais_clara = cor
			var degrau := roundi(m.g * 6.0)
			if degrau >= 1 and degrau <= 3:
				por_degrau[degrau] = cor
	var esperado: Array[Color] = [
		Carro.PINTURA_FABRICA,
		Carro.PELE_FABRICA,
		Carro.CAMISA_FABRICA,
		Carro.CAMISA2_FABRICA,
	]
	var lido: Array[Color] = [mais_clara, por_degrau[1], por_degrau[2], por_degrau[3]]
	for i in esperado.size():
		assert_float(lido[i].r).is_equal_approx(esperado[i].r, 0.01)
		assert_float(lido[i].g).is_equal_approx(esperado[i].g, 0.01)
		assert_float(lido[i].b).is_equal_approx(esperado[i].b, 0.01)
