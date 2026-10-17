extends GdUnitTestSuite
## O que acende quando a corrida anoitece: poste, farol, lanterna, janela.
##
## Nada disto aparece no banco de provas, que mede o meio-dia, e quase nada
## aparece nos shots: uma luz que nao acende e so um quadro mais escuro. E o
## que quebra quando alguem mexe na paleta de um gerador de arte e a cor do
## farol anda um tom - o shader deixa de achar a lente, e a moto vira um vulto.


func _modelos() -> Array[int]:
	var todos: Array[int] = []
	for i in Entregador.CENAS.size():
		todos.append(i)
	return todos


func _luzes(raiz: Node) -> Array[SpotLight3D]:
	var achadas: Array[SpotLight3D] = []
	for no in raiz.find_children("*", "SpotLight3D", true, false):
		achadas.append(no as SpotLight3D)
	return achadas


## Para onde o cone aponta, no mundo.
func _mira(luz: SpotLight3D) -> Vector3:
	return -luz.global_basis.z.normalized()


func test_a_luz_acende_na_rampa_e_apaga_de_volta() -> void:
	var luz: SpotLight3D = auto_free(LuzDaNoite.spot(Color.WHITE, 4.0, 20.0, 30.0, 0.5))
	assert_bool(luz.visible).is_false()
	assert_bool(luz.is_in_group(Relogio.GRUPO)).is_true()
	Relogio.acender_uma(luz, 0.4)
	assert_bool(luz.visible).is_false()
	Relogio.acender_uma(luz, 0.5 + Relogio.RAMPA * 0.5)
	assert_bool(luz.visible).is_true()
	assert_float(luz.light_energy).is_equal_approx(2.0, 1e-4)
	Relogio.acender_uma(luz, 1.0)
	assert_float(luz.light_energy).is_equal_approx(4.0, 1e-4)
	# Sem sombra: e o que deixa ter uma por poste.
	assert_bool(luz.shadow_enabled).is_false()
	Relogio.acender_uma(luz, 0.0)
	assert_bool(luz.visible).is_false()


func test_o_farol_da_moto_e_achado_pela_cor_e_so_ele() -> void:
	# O shader acha farol e lanterna pela cor pintada, fora da mascara. As duas
	# cores tem de existir na textura, e nenhuma outra celula fora da mascara
	# pode cair na tolerancia dele (3%), senao ela acende junto.
	var albedo := Image.load_from_file(
		ProjectSettings.globalize_path("res://assets/entregador/entregador_albedo.png")
	)
	var mascara := Image.load_from_file(
		ProjectSettings.globalize_path("res://assets/entregador/entregador_mascara.png")
	)
	var achou := {"farol": 0, "lanterna": 0, "intrusa": 0}
	for y in range(16, albedo.get_height(), 32):
		for x in range(16, albedo.get_width(), 32):
			var m := mascara.get_pixel(x, y)
			if maxf(m.r, maxf(m.g, m.b)) > 0.05:
				continue
			var cor := albedo.get_pixel(x, y)
			var no_farol := _perto(cor, FarolDaMoto.FAROL_FABRICA)
			var na_lanterna := _perto(cor, FarolDaMoto.LANTERNA_FABRICA)
			if no_farol and _igual(cor, FarolDaMoto.FAROL_FABRICA):
				achou["farol"] += 1
			elif na_lanterna and _igual(cor, FarolDaMoto.LANTERNA_FABRICA):
				achou["lanterna"] += 1
			elif no_farol or na_lanterna:
				achou["intrusa"] += 1
	assert_int(achou["farol"]).is_equal(1)
	assert_int(achou["lanterna"]).is_equal(1)
	assert_int(achou["intrusa"]).is_equal(0)


## A mesma cor, com o arredondamento de 8 bits do PNG.
func _igual(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.004 and absf(a.g - b.g) < 0.004 and absf(a.b - b.b) < 0.004


## A tolerancia do shader e em linear; aqui, com folga, em sRGB.
func _perto(a: Color, b: Color) -> bool:
	var la := a.srgb_to_linear()
	var lb := b.srgb_to_linear()
	return Vector3(la.r - lb.r, la.g - lb.g, la.b - lb.b).length() < 0.03


func test_toda_moto_tem_farol_na_frente_mirando_o_chao() -> void:
	for modelo in _modelos():
		var ator: Entregador = auto_free(Entregador.new())
		ator.modelo = modelo
		add_child(ator)
		var luzes := _luzes(ator)
		assert_int(luzes.size()).is_equal(1)
		var luz := luzes[0]
		# De dia, apagado.
		assert_bool(luz.visible).is_false()
		var em := ator.to_local(luz.global_position)
		assert_float(em.y).is_between(0.7, 1.1)
		# A frente da moto e -Z, e o farol fica la, perto da roda da frente.
		assert_float(em.z).is_less(-0.3)
		var mira := ator.global_basis.inverse() * _mira(luz)
		assert_float(mira.z).is_less(-0.9)
		assert_float(mira.y).is_less(0.0)


func test_trocar_de_moto_nao_deixa_farol_velho_para_tras() -> void:
	var ator: Entregador = auto_free(Entregador.new())
	add_child(ator)
	for modelo in _modelos():
		ator.trocar_modelo(modelo)
	assert_int(_luzes(ator).size()).is_equal(1)


func test_o_farol_do_carro_tem_marca_so_de_noite() -> void:
	# Meio no B e "so de noite"; 1 e o luminoso do taxi, aceso sempre. Farol
	# marcado com 1 acenderia de dia.
	var albedo := Image.load_from_file(
		ProjectSettings.globalize_path("res://assets/carros/carros_albedo.png")
	)
	var mascara := Image.load_from_file(
		ProjectSettings.globalize_path("res://assets/carros/carros_mascara.png")
	)
	var faroes := 0
	for y in range(16, albedo.get_height(), 32):
		for x in range(16, albedo.get_width(), 32):
			var b := mascara.get_pixel(x, y).b
			if b > 0.25 and b < 0.75:
				faroes += 1
				var cor := albedo.get_pixel(x, y)
				assert_float(cor.get_luminance()).is_greater(0.8)
	assert_int(faroes).is_equal(1)


func test_todo_carro_tem_um_farol_na_frente() -> void:
	for modelo: int in Carro.Modelo.values():
		var carro: Carro = auto_free(Carro.new())
		add_child(carro)
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		carro.montar(modelo, rng)
		var luzes := _luzes(carro)
		assert_int(luzes.size()).is_equal(1)
		var em := carro.to_local(luzes[0].global_position)
		# Na ponta da lataria, que e -Z.
		assert_float(em.z).is_equal_approx(carro.caixa().position.z, 0.3)
		assert_float((carro.global_basis.inverse() * _mira(luzes[0])).z).is_less(-0.9)


func test_o_poste_acende_as_duas_cabecas_para_baixo() -> void:
	var corpo: StaticBody3D = auto_free(Poste.criar(Vector3(40, 0, 12), Vector3.LEFT))
	add_child(corpo)
	var luzes := _luzes(corpo)
	assert_int(luzes.size()).is_equal(2)
	var mi := corpo.get_child(0) as MeshInstance3D
	var quando: float = mi.get_instance_shader_parameter(&"limiar")
	assert_float(quando).is_between(Poste.ACENDE_DE, Poste.ACENDE_ATE)
	for luz in luzes:
		# Lente e luz sao a mesma lampada: acendem no mesmo escuro.
		assert_float(float(luz.get_meta(&"limiar"))).is_equal(quando)
		assert_float(luz.global_position.y).is_between(9.0, 10.5)
		assert_float(_mira(luz).y).is_less(-0.99)
	assert_object(mi.get_surface_override_material(Poste.SUPERFICIE_LENTE)).is_same(Poste.lente())


func test_janela_e_vitrine_vem_marcadas_no_segundo_uv() -> void:
	# O exportador do glTF vira o V: se a conta em `arte/predios.py` deixar de
	# desvirar, a parede inteira chega marcada como vitrine e acende.
	for tipo: int in Predio.Tipo.values():
		var arrays := Predio.malha(tipo).surface_get_arrays(0)
		var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
		assert_int(uv2.size()).is_greater(0)
		var conta := {"nada": 0, "janela": 0}
		for luz in uv2:
			if luz.y < 0.25:
				conta["nada"] += 1
			elif luz.y < 0.75:
				conta["janela"] += 1
		# Muito mais parede que vidro, e todo predio tem janela.
		assert_int(conta["janela"]).is_greater(0)
		assert_int(conta["nada"]).is_greater(conta["janela"])
