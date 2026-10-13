extends GdUnitTestSuite
## O ator em sprite (`AtorSprite`): qual quadro sai do estado da moto, e o
## modelo 3D sumindo da camera sem levar a sombra junto.
##
## A regressao visual roda com o sprite desligado, que e o padrao; sem isto,
## um sinal trocado na inclinacao - o piloto deitando para fora da curva - so
## apareceria para quem ligasse o slider e olhasse.

const PASSO: float = 1.0 / 60.0


func _ator(modelo: int) -> Entregador:
	var ator: Entregador = auto_free(Entregador.new())
	ator.modelo = modelo
	add_child(ator)
	ator.sprite = true
	return ator


func _sprite(ator: Entregador) -> AtorSprite:
	return ator.find_child("Sprite", false, false) as AtorSprite


func _quadro(ator: Entregador) -> int:
	return (_sprite(ator).material_override as ShaderMaterial).get_shader_parameter("quadro")


func _malhas(ator: Entregador) -> Array[MeshInstance3D]:
	var malhas: Array[MeshInstance3D] = []
	for no: Node in ator.find_children("*", "MeshInstance3D", true, false):
		if not no is AtorSprite:
			malhas.append(no as MeshInstance3D)
	return malhas


func test_a_curva_escolhe_o_quadro_do_lado_dela() -> void:
	for modelo in Entregador.CENAS.size():
		var ator := _ator(modelo)
		ator.atualizar(PASSO, 20.0, 0.5, 0.0, false, 1.0, 0.0)
		assert_int(_quadro(ator)).is_equal(AtorSprite.RETO)
		# Inclinacao positiva e para a direita, e o ultimo quadro e o deitado
		# para a direita.
		ator.atualizar(PASSO, 20.0, 0.5, 0.0, false, 1.0, deg_to_rad(35.0))
		assert_int(_quadro(ator)).is_equal(AtorSprite.RETO * 2)
		ator.atualizar(PASSO, 20.0, 0.5, 0.0, false, 1.0, deg_to_rad(-15.0))
		assert_int(_quadro(ator)).is_equal(AtorSprite.RETO - 1)


func test_o_soco_passa_pelos_tres_quadros_do_lado_dele() -> void:
	var ator := _ator(Entregador.Modelo.CG_160)
	ator.socar(-1, 0.1, 0.1, 0.4)
	var vistos: Array[int] = []
	# Um pouco alem do `total`, para ver a volta ao quadro reto.
	for i in int(0.5 / PASSO):
		ator.atualizar(PASSO, 20.0, 0.5, 0.0, false)
		if vistos.is_empty() or vistos.back() != _quadro(ator):
			vistos.append(_quadro(ator))
	assert_array(vistos).is_equal(AtorSprite.SOCO[-1] + [AtorSprite.RETO])


func test_o_modelo_some_da_camera_e_deixa_a_sombra() -> void:
	for modelo in Entregador.CENAS.size():
		var ator := _ator(modelo)
		ator.atualizar(PASSO, 20.0, 0.5, 0.0, false)
		assert_bool(_sprite(ator).visible).is_true()
		for malha in _malhas(ator):
			assert_int(malha.cast_shadow).is_equal(
				GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			)
		# O tombo ainda nao tem quadro: quem cai e o modelo.
		ator.atualizar(PASSO, 20.0, 0.0, 0.0, true)
		assert_bool(_sprite(ator).visible).is_false()
		for malha in _malhas(ator):
			assert_int(malha.cast_shadow).is_equal(GeometryInstance3D.SHADOW_CASTING_SETTING_ON)


func test_o_sprite_cresce_com_a_moto() -> void:
	var alturas: Array[float] = []
	for modelo in Entregador.CENAS.size():
		alturas.append((_sprite(_ator(modelo)).mesh as QuadMesh).size.y)
	# A XRE tem o banco mais alto que a CG: o piloto em cima dela tambem.
	assert_float(alturas[Entregador.Modelo.XRE_300]).is_greater(alturas[Entregador.Modelo.CG_160])
	for altura in alturas:
		assert_float(altura).is_between(1.4, 2.6)


func test_entre_dois_quadros_o_quad_gira_o_que_falta() -> void:
	var ator := _ator(Entregador.Modelo.CG_160)
	var material := _sprite(ator).material_override as ShaderMaterial
	var rolagens: Array[float] = []
	# De 5 em 5 graus, passando pela troca de quadro em 7,5: o desenho mais o
	# giro tem de andar junto com a moto, sem saltar para tras na troca.
	for graus: float in [0.0, 5.0, 10.0, 20.0, 40.0]:
		ator.atualizar(PASSO, 20.0, 0.5, 0.0, false, 1.0, deg_to_rad(graus))
		var desenhado := (_quadro(ator) - AtorSprite.RETO) * AtorSprite.PASSO_DA_CURVA
		var total := desenhado + rad_to_deg(material.get_shader_parameter("rolagem"))
		# A ginga do tronco soma uns graus; a moto manda no resto.
		assert_float(total).is_equal_approx(graus, 3.0)
		rolagens.append(total)
	for i in rolagens.size() - 1:
		assert_float(rolagens[i + 1]).is_greater(rolagens[i])
