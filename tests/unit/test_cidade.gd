extends GdUnitTestSuite
## A cidade em volta da avenida: o que bate tem colisor, e a rua transversal
## abre um vao na fileira de predios.
##
## A moto so encontra predio, semaforo e carro parado pelo colisor. Sem ele o
## jogo continua rodando e a moto atravessa a fachada - e o banco de provas so
## passa perto de um trecho de calcada.

var _track: RoadTrack
var _props: Node3D
var _cidade: Cidade


func before_test() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260831
	_track = auto_free(RoadTrack.new())
	add_child(_track)
	_track.build(800.0, rng)
	_props = auto_free(Node3D.new())
	add_child(_props)
	_cidade = Cidade.new(_track)
	_cidade.montar(rng, _props)


func _e_predio(no: Node) -> bool:
	if not (no is MeshInstance3D):
		return false
	for tipo: int in Predio.Tipo.values():
		if (no as MeshInstance3D).mesh == Predio.malha(tipo):
			return true
	return false


func _colisor_do_mundo(no: Node) -> bool:
	for filho in no.get_children():
		if filho is StaticBody3D and (filho as StaticBody3D).collision_layer == Layers.WORLD:
			return true
	return false


func test_tudo_que_bate_tem_colisor() -> void:
	var contagem := {"predio": 0, "carro": 0, "semaforo": 0}
	for no in _props.get_children():
		if _e_predio(no):
			assert_bool(_colisor_do_mundo(no)).override_failure_message(no.name).is_true()
			contagem["predio"] += 1
		elif no is Carro:
			assert_bool(_colisor_do_mundo(no)).is_true()
			contagem["carro"] += 1
		elif no.name.contains("Semaforo"):
			assert_bool(_colisor_do_mundo(no)).is_true()
			contagem["semaforo"] += 1
	# 800 m de avenida dos dois lados: dezenas de predios, e ao menos uma rua
	# com fila no vermelho. Zero aqui e a cidade que parou de ser montada.
	assert_int(contagem["predio"]).is_greater(60)
	assert_int(contagem["carro"]).is_greater(0)
	assert_int(contagem["semaforo"]).is_greater(0)


func test_o_colisor_do_predio_fica_atras_da_fachada() -> void:
	# A caixa e o corpo, e nao o toldo: ela comeca atras da ponta da fachada e
	# vai ate os fundos.
	for no in _props.get_children():
		if not _e_predio(no):
			continue
		var mi := no as MeshInstance3D
		var caixa := mi.mesh.get_aabb()
		for filho in mi.get_children():
			var forma := (filho as StaticBody3D).get_child(0) as CollisionShape3D
			var frente := forma.position.z - (forma.shape as BoxShape3D).size.z * 0.5
			assert_float(frente).is_greater_equal(caixa.position.z)
			(
				assert_float(forma.position.z + (forma.shape as BoxShape3D).size.z * 0.5)
				. is_equal_approx(caixa.end.z, 0.01)
			)
		return
