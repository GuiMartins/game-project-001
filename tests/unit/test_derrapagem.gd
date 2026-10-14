extends GdUnitTestSuite
## Fumaca e marca de pneu (`Derrapagem`): derrapou, fumacou e marcou; andou
## reto, nada.

const PASSO: float = 1.0 / 60.0


func _derrapagem() -> Derrapagem:
	var d: Derrapagem = auto_free(Derrapagem.new())
	add_child(d)
	return d


## Anda `metros` para a frente a 30 m/s, escorregando `derrapada`.
func _anda(d: Derrapagem, metros: float, derrapada: float) -> void:
	for i in int(metros / 30.0 / PASSO):
		d.position.z -= 30.0 * PASSO
		d.atualizar(PASSO, derrapada)


func test_andando_reto_nao_fumaca_nem_marca() -> void:
	var d := _derrapagem()
	# Curva normal escorrega ate 3,5 m/s: abaixo do limiar, nada.
	_anda(d, 30.0, 3.5)
	assert_bool(d.emitindo()).is_false()
	assert_int(d.marcas_visiveis()).is_equal(0)


func test_derrapando_fumaca_e_marca_e_para_quando_volta_a_aderir() -> void:
	var d := _derrapagem()
	_anda(d, 10.0, 8.0)
	assert_bool(d.emitindo()).is_true()
	# Dez metros em pedacos de pelo menos 0,8 - a 30 m/s o passo e de 0,5, e
	# o pedaco sai de 1 m: uma marca por metro, menos o primeiro, que so marca
	# onde comecou.
	assert_int(d.marcas_visiveis()).is_between(8, 10)
	_anda(d, 10.0, 0.0)
	assert_bool(d.emitindo()).is_false()
	assert_int(d.marcas_visiveis()).is_between(8, 10)


func test_a_marca_some_com_o_tempo() -> void:
	var d := _derrapagem()
	_anda(d, 10.0, 8.0)
	for i in int((Derrapagem.VIDA_DA_MARCA + 0.1) / PASSO):
		d.atualizar(PASSO, 0.0)
	assert_int(d.marcas_visiveis()).is_equal(0)


func test_teleporte_nao_risca_o_caminho() -> void:
	var d := _derrapagem()
	_anda(d, 5.0, 8.0)
	var antes := d.marcas_visiveis()
	# O respawn leva a moto 30 m para tras num passo: nenhuma marca de 30 m.
	d.position.z += 30.0
	d.atualizar(PASSO, 8.0)
	assert_int(d.marcas_visiveis()).is_equal(antes)
