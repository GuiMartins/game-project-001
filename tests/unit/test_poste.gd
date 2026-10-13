extends GdUnitTestSuite
## O poste de dois bracos: braco da pista para o lado certo e o colisor de antes.
##
## O colisor e o que o combate usa, e o banco de provas so pega a pancada se um
## rival for parar num poste naquela semente. Um eixo trocado no exportador poe
## o braco da pista por cima da fachada, e o jogo continua rodando.


func test_a_base_fica_no_chao_e_os_bracos_a_dez_metros() -> void:
	var caixa := Poste.malha().get_aabb()
	# A base desce meio metro, para nao ficar com o pe no ar no meio-fio.
	assert_float(caixa.position.y).is_equal_approx(-0.5, 0.01)
	assert_float(caixa.end.y).is_between(9.8, 10.5)


func test_o_braco_da_pista_chega_na_faixa_da_direita() -> void:
	# E para isso que o poste existe: o braco passar por cima da camera. Se a
	# cabeca nao alcancar a faixa de fora, ele volta a ser so um risco no canto.
	var ponta := Poste.LATERAL + Poste.malha().get_aabb().position.z
	assert_float(ponta).is_less(RoadTrack.lane_center(RoadTrack.LANE_COUNT - 1) + 1.0)
	assert_float(Poste.LATERAL).is_greater(RoadTrack.half_width() + 0.3)


func test_os_bracos_saem_para_frente_e_para_tras() -> void:
	# Os dois bracos ficam no plano YZ do modelo: e -Z que aponta para a pista.
	var caixa := Poste.malha().get_aabb()
	assert_float(caixa.size.x).is_less(1.0)
	assert_float(-caixa.position.z).is_greater(2.5)
	assert_float(caixa.end.z).is_greater(2.5)


func test_o_braco_da_pista_aponta_para_onde_mandaram() -> void:
	var corpo: StaticBody3D = auto_free(Poste.criar(Vector3(5, 0, 0), Vector3.LEFT))
	var mi := corpo.get_child(0) as MeshInstance3D
	assert_vector(mi.basis * Vector3.FORWARD).is_equal_approx(Vector3.LEFT, Vector3.ONE * 1e-4)


func test_o_colisor_e_o_da_caixa_e_nao_gira() -> void:
	# Mesma caixa de 0,35 x 6 m do greybox, de pe no chao e nos eixos do mundo:
	# e com ela que o banco de provas mede o rival jogado no poste.
	var corpo: StaticBody3D = auto_free(Poste.criar(Vector3.ZERO, Vector3(1, 0, 1)))
	assert_int(corpo.collision_layer).is_equal(Layers.WORLD)
	assert_that(corpo.basis).is_equal(Basis.IDENTITY)
	var forma := corpo.get_child(1) as CollisionShape3D
	assert_vector((forma.shape as BoxShape3D).size).is_equal(Vector3(0.35, 6.0, 0.35))
	assert_vector(forma.position).is_equal(Vector3(0, 3, 0))
