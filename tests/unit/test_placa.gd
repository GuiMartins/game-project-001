extends GdUnitTestSuite
## A placa Mercosul de moto: o formato e o nó onde ela é escrita em cada moto.

const FORMATO := "^[A-Z]{3}[0-9][A-Z][0-9]{2}$"


func _ator(modelo: int) -> Entregador:
	var ator: Entregador = auto_free(Entregador.new())
	ator.modelo = modelo
	add_child(ator)
	return ator


func test_toda_moto_sai_com_a_placa_escrita_atras() -> void:
	var formato := RegEx.create_from_string(FORMATO)
	for modelo in Entregador.CENAS.size():
		var ator := _ator(modelo)
		assert_bool(formato.search(Placa.do_no(ator)) != null).is_true()
		var ancora := ator.find_child("Placa", true, false) as Node3D
		assert_object(ancora).is_not_null()
		# Faixa + BRASIL + as duas linhas; e atras da moto (+Z no Godot).
		assert_int(ancora.get_child_count()).is_equal(4)
		assert_float(ancora.global_position.z).is_greater(0.5)


func test_a_placa_nao_muda_ao_trocar_de_moto() -> void:
	var ator := _ator(Entregador.Modelo.CG_160)
	var antes := Placa.do_no(ator)
	ator.trocar_modelo(Entregador.Modelo.PCX_160)
	assert_str(Placa.do_no(ator)).is_equal(antes)
	var ancora := ator.find_child("Placa", true, false) as Node3D
	assert_int(ancora.get_child_count()).is_equal(4)


func test_rivais_diferentes_tem_placas_diferentes() -> void:
	var a := _ator(Entregador.Modelo.CG_160)
	a.name = "RivalA"
	var b := _ator(Entregador.Modelo.CG_160)
	b.name = "RivalB"
	assert_str(Placa.do_no(a)).is_not_equal(Placa.do_no(b))
