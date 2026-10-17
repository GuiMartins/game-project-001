extends GdUnitTestSuite
## So o mobiliario preso ao chao cede; a cacamba e o mupi seguem obstaculos.


func test_poste_e_placas_quebram_e_voltam_na_proxima_largada() -> void:
	var poste: Quebravel = auto_free(Poste.criar(Vector3.ZERO, Vector3.FORWARD))
	add_child(poste)
	var placa: StaticBody3D = auto_free(
		Mobiliario.criar(Mobiliario.Tipo.PLACA_ESQUERDA, Vector3(2, 0, 0), Vector3.FORWARD)
	)
	add_child(placa)
	assert_bool(placa is Quebravel).is_true()
	for objeto: Quebravel in [poste, placa as Quebravel]:
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
	moto.scraped.connect(func(_intensidade: float) -> void: penalidades[0] += 1)
	moto.crashed.connect(func(_motivo: String) -> void: penalidades[0] += 1)
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
