extends GdUnitTestSuite
## Poste, semaforo, portico e placa amassam e ficam de pe; a cacamba e o mupi
## seguem obstaculos. E o jogador que cai, se chegou rapido.


func test_cacamba_e_mupi_continuam_solidos() -> void:
	for tipo: Mobiliario.Tipo in [Mobiliario.Tipo.CACAMBA, Mobiliario.Tipo.MUPI]:
		var objeto: StaticBody3D = auto_free(Mobiliario.criar(tipo, Vector3.ZERO, Vector3.FORWARD))
		assert_bool(objeto is Amassavel).is_false()


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
		# Devagar so encosta e nao marca; rapido, amassa.
		assert_bool(poste.amassado > 0.0).is_equal(caso[1])
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


func test_tudo_que_e_fixo_amassa_igual_e_volta_na_largada() -> void:
	# Poste, placa, semaforo e portico: uma classe so, para nenhum voar enquanto
	# o vizinho fica parado.
	var raiz: Node3D = auto_free(Node3D.new())
	add_child(raiz)
	raiz.add_child(Greybox.box(Vector3(0.2, 4.0, 0.2), Color.BLACK))
	var semaforo := Amassavel.com_colisor(raiz, Vector3(0.4, 4.4, 0.4))
	var placa: Amassavel = auto_free(
		Mobiliario.criar(Mobiliario.Tipo.PLACA_ESQUERDA, Vector3(2, 0, 0), Vector3.FORWARD)
	)
	add_child(placa)
	var poste: Amassavel = auto_free(Poste.criar(Vector3(4, 0, 0), Vector3.LEFT))
	add_child(poste)
	for peca: Amassavel in [semaforo, placa, poste]:
		var pe := peca.global_position
		assert_bool(peca.amassar(0.8, Vector3.FORWARD * 30.0)).is_true()
		assert_float(peca.amassado).is_equal(0.8)
		# Segunda batida na mesma largada nao e a primeira.
		assert_bool(peca.amassar(0.9, Vector3.FORWARD * 30.0)).is_false()
		assert_vector(peca.global_position).is_equal(pe)
		peca.reiniciar()
		assert_float(peca.amassado).is_equal(0.0)


func test_encosto_nao_amassa() -> void:
	var poste: Amassavel = auto_free(Poste.criar(Vector3.ZERO, Vector3.LEFT))
	add_child(poste)
	assert_bool(poste.amassar(0.01, Vector3.FORWARD)).is_false()
	assert_float(poste.amassado).is_equal(0.0)
