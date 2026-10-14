extends GdUnitTestSuite
## A cadencia travada do ator (`Cadencia`): a pose espera a vez, o estado nao.
##
## Fora do `test_entregador.gd` porque aquele ja tem o maximo de testes que o
## gdlint aceita numa suite.

const PASSO: float = 1.0 / 60.0


func test_o_liso_posa_todo_passo() -> void:
	var c: Cadencia = auto_free(Cadencia.new())
	for i in 10:
		assert_bool(c.vez(PASSO)).is_true()


func test_passo_que_nao_divide_o_periodo_mantem_a_media() -> void:
	var c: Cadencia = auto_free(Cadencia.new())
	c.hz = 12.0
	var poses := 0
	# 144 Hz: o periodo de 1/12 s nao e multiplo do passo.
	for i in 144 * 10:
		if c.vez(1.0 / 144.0):
			poses += 1
	assert_int(poses).is_between(119, 121)


func _ator(modelo: int) -> Entregador:
	var ator: Entregador = auto_free(Entregador.new())
	ator.modelo = modelo
	add_child(ator)
	return ator


func _no(ator: Entregador, nome: String) -> Node3D:
	return ator.find_child(nome, true, false) as Node3D


func test_a_cadencia_travada_segura_a_pose_e_nao_o_estado() -> void:
	for modelo in Entregador.CENAS.size():
		var liso := _ator(modelo)
		var travado := _ator(modelo)
		travado.cadencia.hz = 12.0
		var roda_lisa := _no(liso, "Roda_Traseira")
		var roda := _no(travado, "Roda_Traseira")
		var poses := 0
		var anterior := roda.rotation.x
		for i in 60:
			liso.atualizar(PASSO, 10.0, 1.0, 0.0, false)
			travado.atualizar(PASSO, 10.0, 1.0, 0.0, false)
			if roda.rotation.x != anterior:
				poses += 1
				anterior = roda.rotation.x
				# Quando a pose sai, sai a do estado de agora, igual a do liso:
				# a roda nao perdeu os passos em que a tela esperou.
				assert_float(roda.rotation.x).is_equal_approx(roda_lisa.rotation.x, 0.0001)
		# 60 passos de 1/60 s a 12 Hz: uma pose a cada cinco.
		assert_int(poses).is_equal(12)


func test_travado_a_inclinacao_do_corpo_espera_a_pose() -> void:
	var visual: Node3D = auto_free(Node3D.new())
	add_child(visual)
	var ator := Entregador.new()
	visual.add_child(ator)
	ator.cadencia.hz = 12.0
	var giros: Array[float] = []
	for i in 10:
		# O corpo inclina liso, um pouco a cada passo, como o `Visual`.
		visual.rotation.z = -0.02 * (i + 1)
		ator.atualizar(PASSO, 10.0, 1.0, 0.0, false)
		await get_tree().process_frame
		giros.append(ator.global_basis.get_euler().z)
	# Dez passos a 12 Hz: duas poses, e o giro so muda nelas.
	var trocas := 0
	for i in range(1, giros.size()):
		if not is_equal_approx(giros[i], giros[i - 1]):
			trocas += 1
	assert_int(trocas).is_less_equal(2)
	ator.cadencia.hz = 0.0
	await get_tree().process_frame
	# Destravado, volta a acompanhar o corpo na hora.
	assert_float(ator.global_basis.get_euler().z).is_equal_approx(-0.2, 0.0001)
