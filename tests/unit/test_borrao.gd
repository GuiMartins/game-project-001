extends GdUnitTestSuite
## O borrao de velocidade: quanto borra e para onde.
##
## O shader nao roda no teste (headless nao desenha), e a regressao visual so
## pega a tela errada por inteiro. O que da para errar sem ninguem ver e a
## conta de jogo em volta dele: borrao parado, boost sem teto, ou o ponto de
## fuga do lado trocado - a guinada ja inverteu o jogo uma vez.


func test_parado_e_devagar_nao_borra() -> void:
	assert_float(Borrao.intensidade(0.0, 52.0)).is_equal(0.0)
	assert_float(Borrao.intensidade(52.0 * Borrao.INICIO, 52.0)).is_equal(0.0)


func test_cresce_com_a_velocidade_e_vale_um_na_maxima() -> void:
	var meio := Borrao.intensidade(52.0 * 0.65, 52.0)
	assert_float(meio).is_between(0.1, 0.9)
	assert_float(Borrao.intensidade(52.0, 52.0)).is_equal_approx(1.0, 0.001)


## A 128 km/h, a velocidade de todas as referencias, o borrao ja tem de estar
## perto do inteiro (V08a): com a curva reta ele ficava em 55%, e o asfalto
## saia nitido onde a referencia e so risco.
func test_cruzeiro_ja_risca() -> void:
	var tuning := BikeTuning.new()
	assert_float(Borrao.intensidade(128.0 / 3.6, tuning.max_speed)).is_greater(0.65)


func test_o_boost_passa_do_maximo_e_satura() -> void:
	var tuning := BikeTuning.new()
	var boost := Borrao.intensidade(52.0 * tuning.boost_speed_mult, 52.0)
	assert_float(boost).is_greater(1.0)
	assert_float(Borrao.intensidade(52.0 * 3.0, 52.0)).is_equal(Borrao.SATURA)


func _cena() -> Array:
	var moto: PlayerBike = auto_free(PlayerBike.new())
	add_child(moto)
	# Na origem olhando para -Z, o padrao do Godot.
	var camera: Camera3D = auto_free(Camera3D.new())
	add_child(camera)
	return [camera, moto]


func test_indo_para_onde_a_lente_olha_a_fuga_e_o_centro() -> void:
	var partes := _cena()
	var moto: PlayerBike = partes[1]
	moto.heading = PI
	var fuga := Borrao.fuga(partes[0], moto)
	assert_float(fuga.x).is_equal_approx(0.5, 0.001)
	assert_float(fuga.y).is_equal_approx(0.5, 0.001)


func test_guinada_positiva_leva_a_fuga_para_a_esquerda() -> void:
	var partes := _cena()
	var moto: PlayerBike = partes[1]
	moto.heading = PI + 0.2
	assert_float(Borrao.fuga(partes[0], moto).x).is_less(0.45)


func test_moto_vindo_para_a_camera_nao_joga_a_fuga_para_fora() -> void:
	var partes := _cena()
	var moto: PlayerBike = partes[1]
	moto.heading = 0.0
	assert_vector(Borrao.fuga(partes[0], moto)).is_equal(Vector2(0.5, 0.5))


func _ator(modelo: int = Entregador.Modelo.CG_160) -> Entregador:
	var ator: Entregador = auto_free(Entregador.new())
	ator.modelo = modelo
	add_child(ator)
	return ator


## Toda malha do piloto da camera leva a marca que o borrao respeita - a do
## modelo e o disco da roda lisa -, em toda moto, e a moto trocada nasce
## marcada. Malha sem marca borra junto com a rua, e o piloto, que nas
## referencias e a unica coisa nitida do quadro, sai com um pedaco sujo.
func test_o_foco_marca_toda_malha_de_toda_moto() -> void:
	for modelo in Entregador.CENAS.size():
		var ator := _ator(modelo)
		ator.foco = true
		ator.trocar_modelo((modelo + 1) % Entregador.CENAS.size())
		var malhas := ator.find_children("*", "MeshInstance3D", true, false)
		assert_int(malhas.size()).is_greater(10)
		var discos := 0
		for malha: MeshInstance3D in malhas:
			assert_object(malha.material_overlay).is_not_null()
			if malha.name == "Disco":
				discos += 1
		assert_int(discos).is_equal(2)
		ator.foco = false
		for malha: MeshInstance3D in malhas:
			assert_object(malha.material_overlay).is_null()


func test_rival_nasce_sem_a_marca() -> void:
	var ator := _ator()
	for malha: MeshInstance3D in ator.find_children("*", "MeshInstance3D", true, false):
		assert_object(malha.material_overlay).is_null()
