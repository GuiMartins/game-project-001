extends GdUnitTestSuite
## So o mobiliario preso ao chao cede; a cacamba e o mupi seguem obstaculos.


func test_placas_quebram_e_voltam_na_proxima_largada() -> void:
	var placa: StaticBody3D = auto_free(
		Mobiliario.criar(Mobiliario.Tipo.PLACA_ESQUERDA, Vector3(2, 0, 0), Vector3.FORWARD)
	)
	add_child(placa)
	assert_bool(placa is Quebravel).is_true()
	for objeto: Quebravel in [placa as Quebravel]:
		var rotacao := objeto.rotation
		objeto.quebrar(Vector3.FORWARD)
		assert_bool(objeto.quebrado).is_true()
		objeto.reiniciar()
		assert_bool(objeto.quebrado).is_false()
		assert_bool(objeto.visible).is_true()
		assert_vector(objeto.rotation).is_equal(rotacao)


func test_cacamba_e_mupi_continuam_solidos() -> void:
	for tipo: Mobiliario.Tipo in [Mobiliario.Tipo.CACAMBA, Mobiliario.Tipo.MUPI]:
		var objeto: StaticBody3D = auto_free(Mobiliario.criar(tipo, Vector3.ZERO, Vector3.FORWARD))
		assert_bool(objeto is Quebravel).is_false()


func test_jogador_quebra_sem_perder_velocidade_ou_cair() -> void:
	var pista: RoadTrack = auto_free(RoadTrack.new())
	add_child(pista)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260831
	pista.build(120.0, rng)
	var moto: PlayerBike = auto_free(PlayerBike.new())
	add_child(moto)
	moto.setup(BikeTuning.new(), pista, 12.0)
	moto.place_on_track(12.0, 0.0, 30.0)
	moto.set_physics_process(false)
	var penalidades: Array[int] = [0]
	var impactos: Array[int] = [0]
	moto.scraped.connect(func(_intensidade: float) -> void: penalidades[0] += 1)
	moto.crashed.connect(func(_motivo: String) -> void: penalidades[0] += 1)
	moto.obstaculo_quebrado.connect(func(_forca: float) -> void: impactos[0] += 1)
	var raiz: Node3D = auto_free(Node3D.new())
	add_child(raiz)
	raiz.global_position = pista.point(16.0, 0.0)
	var placa := Quebravel.com_colisor(raiz, Vector3(0.4, 2.6, 0.4))
	await get_tree().physics_frame
	for passo in 12:
		moto._integrate(1.0 / 60.0)
		moto._resolve_collisions()
		await get_tree().physics_frame
	assert_bool(placa.quebrado).is_true()
	assert_float(moto.speed).is_equal_approx(30.0, 0.01)
	assert_int(moto.state).is_equal(PlayerBike.State.RIDING)
	assert_int(penalidades[0]).is_equal(0)
	assert_int(impactos[0]).is_equal(1)


func test_poste_amassa_conforme_a_forca_e_fica_de_pe() -> void:
	# V34: o poste nao sai do lugar. A batida o amassa, mais forte quanto mais
	# forte ela for, e a largada nova o desamassa.
	var poste: Amassavel = auto_free(Poste.criar(Vector3(4.0, 0.0, 9.0), Vector3.LEFT))
	add_child(poste)
	var malha := poste.get_child(0) as MeshInstance3D
	var inicial := malha.transform
	var pe := poste.global_position
	var alto := inicial.origin + Vector3.UP * 6.0
	poste.amassar(0.3, Vector3.FORWARD * 20.0)
	assert_bool(malha.transform.is_equal_approx(inicial)).is_false()
	# O topo (6 m acima do pe) foi para onde a moto ia (-Z) e continua alto.
	var topo_fraco := malha.global_transform * (inicial.affine_inverse() * alto)
	assert_float(topo_fraco.z).is_less(pe.z - 0.5)
	poste.amassar(1.0, Vector3.FORWARD * 40.0)
	var topo_forte := malha.global_transform * (inicial.affine_inverse() * alto)
	assert_float(topo_forte.z).is_less(topo_fraco.z)
	assert_float(topo_forte.y).is_greater(4.5)
	# Batida mais fraca depois nao desamassa.
	poste.amassar(0.1, Vector3.FORWARD * 5.0)
	assert_float(poste.amassado).is_equal(1.0)
	assert_vector(poste.global_position).is_equal(pe)
	poste.reiniciar()
	assert_bool(malha.transform.is_equal_approx(inicial)).is_true()
	assert_float(poste.amassado).is_equal(0.0)


func test_jogador_cai_no_poste_a_toda_velocidade_e_nao_a_baixa() -> void:
	var pista: RoadTrack = auto_free(RoadTrack.new())
	add_child(pista)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260831
	pista.build(120.0, rng)
	for caso: Array in [[40.0, true], [6.0, false]]:
		var moto: PlayerBike = auto_free(PlayerBike.new())
		add_child(moto)
		moto.setup(BikeTuning.new(), pista, 12.0)
		moto.place_on_track(12.0, 0.0, caso[0])
		moto.set_physics_process(false)
		var poste: Amassavel = auto_free(Poste.criar(pista.point(16.0, 0.0), Vector3.LEFT))
		add_child(poste)
		await get_tree().physics_frame
		for passo in 40:
			moto._integrate(1.0 / 60.0)
			moto._resolve_collisions()
			await get_tree().physics_frame
		assert_bool(poste.amassado > 0.0).is_true()
		assert_bool(moto.state == PlayerBike.State.CRASHED).is_equal(caso[1])


func test_tranco_e_curto_e_so_mexe_na_moto_atingida_em_todos_os_modelos() -> void:
	for modelo in Entregador.CENAS.size():
		var atingida: Entregador = auto_free(Entregador.new())
		var intacta: Entregador = auto_free(Entregador.new())
		atingida.modelo = modelo
		intacta.modelo = modelo
		add_child(atingida)
		add_child(intacta)
		atingida.impacto(0.7)
		atingida.atualizar(1.0 / 60.0, 0.0, 0.0, 0.0, false)
		intacta.atualizar(1.0 / 60.0, 0.0, 0.0, 0.0, false)
		assert_float(atingida._treme.x).is_greater(0.01)
		assert_vector(intacta._treme).is_equal(Vector2.ZERO)
		for _passo in 60:
			atingida.atualizar(1.0 / 60.0, 0.0, 0.0, 0.0, false)
		assert_float(atingida._treme.length()).is_less(0.0001)


func test_placa_para_de_simular_depois_de_assentar() -> void:
	for hz: float in [60.0, 120.0]:
		var placa: Quebravel = auto_free(
			Mobiliario.criar(Mobiliario.Tipo.PLACA_DIREITA, Vector3.ZERO, Vector3.FORWARD)
		)
		for objeto: Quebravel in [placa]:
			add_child(objeto)
			objeto.quebrar(Vector3.FORWARD * 35.0)
			for _passo in int(20.0 * hz):
				if objeto.is_physics_processing():
					objeto._physics_process(1.0 / hz)
			assert_bool(objeto.is_physics_processing()).is_false()
			assert_bool(objeto.visible).is_true()
