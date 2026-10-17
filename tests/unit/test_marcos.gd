extends GdUnitTestSuite
## Os marcos do fundo (V14a): uma peca do catalogo no fim de cada reta, longe
## da pista e nunca a mesma duas vezes seguidas. Marco em cima da avenida, ou
## repetido na mesma tela, nao da erro nenhum - so estraga a vista.

const SEMENTE: int = 20260831

var _track: RoadTrack
var _props: Node3D
var _marcos: Array[Node3D]


func before_test() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEMENTE
	_track = auto_free(RoadTrack.new())
	add_child(_track)
	_track.build(3200.0, rng)
	_props = auto_free(Node3D.new())
	add_child(_props)
	_marcos = Marcos.montar(_track, SEMENTE, Marcos.rio(), _props)


func test_ha_marco_numa_corrida_inteira() -> void:
	assert_int(_marcos.size()).is_greater(1)


func test_cada_peca_do_catalogo_tem_forma_e_altura() -> void:
	for marco in Marcos.rio():
		var raiz := auto_free(Node3D.new()) as Node3D
		marco.construir.call(raiz)
		var caixa := AABB()
		for no in raiz.get_children():
			var mi := no as MeshInstance3D
			caixa = caixa.merge(mi.transform * mi.get_aabb())
		# Alto o bastante para aparecer por cima do corredor a 300 m, e com o
		# pe fundo para nao flutuar num vale.
		assert_float(caixa.end.y * marco.escala).is_greater(marco.altura * 0.8)
		assert_float(caixa.position.y).is_less(-Marcos.PE * 0.5)


func test_nenhum_marco_cai_em_cima_da_pista() -> void:
	for no in _marcos:
		var menor := INF
		var s := 0.0
		while s < _track.length:
			var q := _track.sample_position(s)
			menor = minf(menor, Vector2(no.position.x - q.x, no.position.z - q.z).length())
			s += 8.0
		assert_float(menor).is_greater(Marcos.FOLGA)


func test_nunca_a_mesma_peca_duas_vezes_seguidas() -> void:
	for i in range(1, _marcos.size()):
		assert_str(_marcos[i].name).is_not_equal(_marcos[i - 1].name)


func test_marcos_nao_tem_colisor() -> void:
	# Ficam alem do chao; colisor aqui so custaria broadphase.
	for no in _marcos:
		assert_bool(no is PhysicsBody3D).is_false()
		assert_int(no.find_children("*", "CollisionObject3D", true, false).size()).is_equal(0)


func test_a_semente_decide_o_lugar() -> void:
	var outro := auto_free(Node3D.new()) as Node3D
	add_child(outro)
	var de_novo := Marcos.montar(_track, SEMENTE, Marcos.rio(), outro)
	assert_int(de_novo.size()).is_equal(_marcos.size())
	for i in de_novo.size():
		assert_vector(de_novo[i].position).is_equal(_marcos[i].position)
