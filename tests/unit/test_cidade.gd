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
	for fase: int in Predio.Obra.values():
		if (no as MeshInstance3D).mesh == Predio.malha_obra(fase as Predio.Obra):
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


func test_largo_e_corredor_se_alternam() -> void:
	# Largo seguido de largo e so um largo mais comprido, e corredor seguido
	# de corredor e a avenida sem ritmo nenhum - que e o que era antes.
	var rua := RandomNumberGenerator.new()
	rua.seed = 7
	var trechos := _cidade._sorteia_trechos(rua)
	assert_int(trechos.size()).is_greater(2)
	assert_float(trechos[0].y).is_greater(0.0)
	for i in range(1, trechos.size()):
		assert_bool((trechos[i].y > 0.0) != (trechos[i - 1].y > 0.0)).is_true()
	assert_float(trechos[-1].x).is_greater_equal(_track.length)


func test_no_largo_so_predio_baixo() -> void:
	# Predio alto recuado e so um corredor mais longe: o que abre o quadro no
	# largo e o ceu por cima de sobrado e comercio.
	for h in range(int(Cidade.ALTURA_LARGO.x), int(Cidade.ALTURA_LARGO.y)):
		var tipo := Cidade._tipo_de_predio(float(h) + 0.99)
		assert_bool(tipo == Predio.Tipo.SOBRADO or tipo == Predio.Tipo.COMERCIO).is_true()


## O nome de cada peca da faixa de servico pela malha: o nome do no nao serve,
## porque o Godot troca nome repetido por `@StaticBody3D@12`.
func _peca(no: Node) -> String:
	for filho in no.get_children():
		if not (filho is MeshInstance3D):
			continue
		var malha := (filho as MeshInstance3D).mesh
		for tipo: int in Arvore.Tipo.values():
			if malha == Arvore.malha(tipo):
				return Arvore.NOS[tipo]
		for tipo: int in Mobiliario.Tipo.values():
			if malha == Mobiliario.malha(tipo):
				return Mobiliario.NOS[tipo]
	return ""


func test_faixa_de_servico_tem_de_tudo() -> void:
	# Arvore, cacamba e mupi saem do mesmo sorteio (V16, V17): se um deles
	# some, e o peso dele que zerou, e nada da erro. Numa pista do tamanho da
	# corrida, e nao nos 800 m dos outros testes: com 15% de chance cada, a
	# cacamba e o mupi podem faltar num trecho curto so por sorteio.
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260831
	var track: RoadTrack = auto_free(RoadTrack.new())
	add_child(track)
	track.build(3200.0, rng)
	var props: Node3D = auto_free(Node3D.new())
	add_child(props)
	Cidade.new(track).montar(rng, props)
	var contagem := {}
	for no in props.get_children():
		var nome := _peca(no)
		contagem[nome] = contagem.get(nome, 0) + 1
	print("faixa de servico em 3200 m: ", contagem)
	for nome: String in ["Copa", "Palmeira", "Cacamba", "Mupi"]:
		assert_int(contagem.get(nome, 0)).override_failure_message(nome).is_greater(0)


func test_placa_de_curva_fala_o_lado_da_curva() -> void:
	# Guinada positiva gira para a esquerda: e o invariante que ja inverteu o
	# jogo uma vez. A placa le o mesmo sinal.
	var placas := 0
	for no in _props.get_children():
		var nome := _peca(no)
		if not nome.begins_with("Placa"):
			continue
		placas += 1
		var corpo := no as Node3D
		# O `project` so busca perto de um palpite; aqui o palpite e a pista
		# inteira, metro a metro.
		var o := 0.0
		var perto := INF
		for k in int(_track.length):
			var d := _track.sample_position(float(k)).distance_squared_to(corpo.global_position)
			if d < perto:
				perto = d
				o = float(k)
		var giro := Cidade.giro_em(_track, o + Cidade.CURVA_AVISO)
		assert_bool((nome == "PlacaEsquerda") == (giro > 0.0)).is_true()
	print("placas de curva em 800 m: ", placas)


func test_o_braco_do_portal_passa_por_cima_da_moto() -> void:
	# O aceite da V18: o braco do semaforo suspenso cobre as duas faixas da
	# direita, onde a moto anda, e fica acima do onibus.
	var meio := RoadTrack.LANE_WIDTH * RoadTrack.LANE_COUNT * 0.5
	var ponta := Portal.LATERAL - Portal.BRACO_COMPRIMENTO
	assert_float(ponta).is_less(meio - RoadTrack.LANE_WIDTH * 2.0)
	assert_float(Portal.BRACO_SEMAFORO - 1.2).is_greater(3.2)


func test_pedestres_na_calcada_e_ninguem_na_pista() -> void:
	# A V19: gente dos dois lados, e ninguem na pista nem no andavel, por onde
	# a moto foge. Le as posicoes, e nao o `MultiMesh`: sem tela ele nao guarda
	# o que recebe.
	var rua := RandomNumberGenerator.new()
	rua.seed = 3
	var onde := Pedestres.posicoes(_track, _track.cruzamentos, rua)
	var gente := 0
	var meio := RoadTrack.half_width() + RoadTrack.SHOULDER
	for pose: Array in onde:
		for pessoa: Array in pose:
			gente += 1
			var p := (pessoa[0] as Transform3D).origin
			var perto := INF
			for k in range(0, int(_track.length), 2):
				perto = minf(perto, _track.sample_position(float(k)).distance_to(p))
			assert_float(perto).is_greater(meio)
	assert_int(gente).is_greater(100)


func _obras() -> Array[MeshInstance3D]:
	var obras: Array[MeshInstance3D] = []
	for no in _props.get_children():
		if not (no is MeshInstance3D):
			continue
		for fase: int in Predio.Obra.values():
			if (no as MeshInstance3D).mesh == Predio.malha_obra(fase as Predio.Obra):
				obras.append(no as MeshInstance3D)
	return obras


func test_a_corrida_tem_obra_com_guindaste_em_cima() -> void:
	# O aceite da V17a: obra e guindaste aparecem na corrida. Uma torre em tres
	# vira obra, e a pista de teste tem dezenas de torres.
	var obras := _obras()
	assert_int(obras.size()).is_greater(0)
	for obra in obras:
		assert_bool(_colisor_do_mundo(obra)).is_true()
		var guindaste := obra.get_node_or_null("Guindaste") as Node3D
		assert_object(guindaste).is_not_null()
		# O pe do guindaste pisa na laje do topo, e nao no chao nem no ferro.
		assert_float(guindaste.position.y).is_equal(Predio.OBRA_LAJE_DO_TOPO)


func test_obra_so_no_lugar_de_torre() -> void:
	for tipo: int in Predio.Tipo.values():
		var fase := Cidade.fase_de_obra(20260831, tipo as Predio.Tipo, 120.0, 1.0)
		if tipo != Predio.Tipo.TORRE:
			assert_int(fase).is_equal(Cidade.SEM_OBRA)


func test_a_obra_e_estavel_por_predio() -> void:
	# Hash da semente e da posicao, e nao sorteio: perguntar duas vezes, ou
	# montar a cidade de novo, tem de dar a mesma obra no mesmo predio.
	var conta := 0
	for o in range(0, 3000, 17):
		var a := Cidade.fase_de_obra(20260831, Predio.Tipo.TORRE, float(o), -1.0)
		assert_int(Cidade.fase_de_obra(20260831, Predio.Tipo.TORRE, float(o), -1.0)).is_equal(a)
		if a != Cidade.SEM_OBRA:
			conta += 1
	# Uma em seis, com folga para a conta de hash nao cair certinha.
	var esperado := 3000.0 / 17.0 / Cidade.OBRA_UMA_EM
	assert_float(float(conta)).is_between(esperado * 0.5, esperado * 1.6)


func test_cada_expressa_tem_guindaste_atras_do_muro() -> void:
	var contagem := 0
	for no in _props.get_children():
		if no.name.begins_with("Guindaste"):
			contagem += 1
	assert_int(contagem).is_greater_equal(_cidade.expressas.size())
