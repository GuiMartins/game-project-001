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
	var braco := fiscal.find_child("Braco_E", true, false) as Node3D
	var antes := braco.rotation
	fiscal._physics_process(0.3)
	assert_bool(braco.rotation.is_equal_approx(antes)).is_false()
	# A haste segue a mao, em vez de flutuar ao lado de uma pessoa parada.
	assert_object(braco.get_node("BandeiraQuadriculada")).is_not_null()
