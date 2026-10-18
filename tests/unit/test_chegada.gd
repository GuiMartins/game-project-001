extends GdUnitTestSuite
## A linha desenhada precisa continuar coincidindo com o fim real da corrida.


func test_fiscal_segura_bandeira_e_acena_com_o_braco() -> void:
	var pista: RoadTrack = auto_free(RoadTrack.new())
	add_child(pista)
	var rng := RandomNumberGenerator.new()
	rng.seed = World.SEMENTE
	pista.build(500.0, rng)
	var chegada: Chegada = auto_free(Chegada.new())
	add_child(chegada)
	var fim := pista.length - World.FINISH_MARGIN
	chegada.montar(pista, fim)
	assert_vector(chegada.global_position).is_equal(pista.sample_position(fim))
	var fiscal := chegada.find_child("FiscalDaBandeira", true, false) as Pessoa
	assert_object(fiscal).is_not_null()
	assert_vector(fiscal.global_position).is_equal_approx(
		pista.point(fim + Chegada.COMPRIMENTO * 0.5 + 2.0, 0.0), Vector3.ONE * 0.001
	)
	var braco := fiscal.find_child("Braco_E", true, false) as Node3D
	var antes := braco.rotation
	fiscal._physics_process(0.3)
	assert_bool(braco.rotation.is_equal_approx(antes)).is_false()
	# A haste segue a mao, em vez de flutuar ao lado de uma pessoa parada.
	assert_object(braco.get_node("BandeiraQuadriculada")).is_not_null()
	var tecido := braco.get_node("BandeiraQuadriculada/Tecido") as MeshInstance3D
	assert_object(tecido.material_override).is_instanceof(ShaderMaterial)
	assert_int((tecido.mesh as PlaneMesh).subdivide_width).is_greater(20)


func test_chegada_retira_zebra_e_retencao_sem_apagar_cruzamento() -> void:
	var pista: RoadTrack = auto_free(RoadTrack.new())
	add_child(pista)
	var rng := RandomNumberGenerator.new()
	rng.seed = World.SEMENTE
	pista.build(500.0, rng)
	var ruas: Array[Vector2] = [Vector2(200.0, 0.0)]
	pista.pintar(ruas, 8.0)
	var antes: int = pista._pintura.mesh.surface_get_array_len(0)
	pista.chegada_desde = 100.0
	pista.pintar(ruas, 8.0)
	assert_int(pista._pintura.mesh.surface_get_array_len(0)).is_less(antes)
	assert_int(pista.cruzamentos.size()).is_equal(1)


func test_mede_traseira_tambem_com_moto_atravessada() -> void:
	(
		assert_float(Chegada.recuo_traseira(Basis.IDENTITY, PlayerBike.SIZE, Basis.IDENTITY))
		. is_equal_approx(1.05, 0.001)
	)
	var de_lado := Basis(Vector3.UP, PI * 0.5)
	assert_float(Chegada.recuo_traseira(de_lado, PlayerBike.SIZE, Basis.IDENTITY)).is_equal_approx(
		0.375, 0.001
	)
