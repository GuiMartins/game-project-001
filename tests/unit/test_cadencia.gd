extends GdUnitTestSuite
## A cadencia travada do ator (`Cadencia`): a pose espera a vez, o estado nao.
##
## Fora do `test_entregador.gd` porque aquele ja tem o maximo de testes que o
## gdlint aceita numa suite.

const PASSO: float = 1.0 / 60.0


func test_o_liso_posa_todo_passo() -> void:
	var c := Cadencia.new()
	for i in 10:
		assert_bool(c.vez(PASSO)).is_true()


func test_passo_que_nao_divide_o_periodo_mantem_a_media() -> void:
	var c := Cadencia.new()
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
