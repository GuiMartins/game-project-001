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
		var desenhado: float = AtorSprite.INCLINACOES[_quadro(ator)]
		var total := desenhado + rad_to_deg(material.get_shader_parameter("rolagem"))
		# A ginga do tronco soma uns graus; a moto manda no resto.
		assert_float(total).is_equal_approx(graus, 3.0)
		rolagens.append(total)
	for i in rolagens.size() - 1:
		assert_float(rolagens[i + 1]).is_greater(rolagens[i])


## Pixels opacos do quadro `q` do atlas.
func _area(atlas: Image, q: int) -> int:
	var area := 0
	for y in int(AtorSprite.CELULA.y):
		for x in int(AtorSprite.CELULA.x):
			if atlas.get_pixel(q * int(AtorSprite.CELULA.x) + x, y).a > 0.5:
				area += 1
	return area


func test_todo_quadro_tem_o_tamanho_do_reto() -> void:
	# A IA desenha cada quadro num tamanho, e o recorte (`arte/sprites_flow.gd`)
	# e quem iguala. Sem isso o piloto incha e desincha a cada troca de quadro,
	# e nenhum outro teste ve: o jogo continua rodando.
	var atlas := AtorSprite.ATLAS.get_image()
	if atlas.is_compressed():
		atlas.decompress()
	var reto := float(_area(atlas, AtorSprite.RETO))
	for q in AtorSprite.RETO * 2 + 1:
		assert_float(_area(atlas, q) / reto).is_between(0.97, 1.03)
	# O soco se iguala pela altura (`_altura`), e nao pela area: a folha de
	# combate tem a camera mais baixa, e o piloto dela e mais estreito.
	for lado: int in AtorSprite.SOCO:
		for q: int in AtorSprite.SOCO[lado]:
			assert_float(_area(atlas, q) / reto).is_between(0.9, 1.15)


## Altura da silhueta do quadro `q`, do pneu ao topo, em pixels.
func _altura(atlas: Image, q: int) -> int:
	var primeira := -1
	var ultima := -1
	for y in int(AtorSprite.CELULA.y):
		for x in int(AtorSprite.CELULA.x):
			if atlas.get_pixel(q * int(AtorSprite.CELULA.x) + x, y).a > 0.5:
				if primeira < 0:
					primeira = y
				ultima = y
				break
	return ultima - primeira + 1


func test_o_soco_nao_levanta_o_capacete() -> void:
	# Igualado pela area, o piloto da folha de combate ficava 4% a 6% mais alto
	# que o reto, e o capacete pulava a cada soco. O quadro de recolher e o
	# piloto de volta a posicao de pilotar: tem a altura do reto.
	var atlas := AtorSprite.ATLAS.get_image()
	if atlas.is_compressed():
		atlas.decompress()
	var reto := _altura(atlas, AtorSprite.RETO)
	for lado: int in AtorSprite.SOCO:
		var recolhe: int = AtorSprite.SOCO[lado][2]
		assert_int(_altura(atlas, recolhe)).is_between(reto - 2, reto + 2)


func test_as_inclinacoes_sao_as_do_atlas() -> void:
	# O ator gira so o que o quadro nao desenha. Com o numero errado, a moto na
	# tela anda para tras na troca de quadro - foi o que a auditoria achou.
	var recorte: GDScript = load("res://arte/sprites_flow.gd")
	var atlas := AtorSprite.ATLAS.get_image()
	if atlas.is_compressed():
		atlas.decompress()
	for q in AtorSprite.INCLINACOES.size():
		var medida: float = recorte.call("inclinacao", atlas, q)
		assert_float(medida).is_equal_approx(AtorSprite.INCLINACOES[q], 0.5)


func test_a_troca_de_quadro_tem_folga() -> void:
	# Oscilando em volta da fronteira entre o reto e o primeiro deitado, o
	# quadro nao pisca: so troca quando o outro ganha pela folga.
	var meio := (AtorSprite.INCLINACOES[2] + AtorSprite.INCLINACOES[3]) * 0.5
	var q := AtorSprite.RETO
	for graus: float in [meio - 0.5, meio + 0.5, meio - 0.5, meio + 0.5]:
		q = AtorSprite.quadro_da_curva(graus, q)
		assert_int(q).is_equal(AtorSprite.RETO)
	q = AtorSprite.quadro_da_curva(meio + AtorSprite.FOLGA_DA_TROCA, q)
	assert_int(q).is_equal(AtorSprite.RETO + 1)
	# E de longe vai direto, sem passar pelos do meio.
	assert_int(AtorSprite.quadro_da_curva(-40.0, AtorSprite.RETO * 2)).is_equal(0)


func test_a_suspensao_nao_muda_o_tamanho_do_sprite() -> void:
	# O sprite desce com a suspensao, e nao encolhe: achatado, a altura oscilava
	# 5% a cada lombada e o piloto parecia mudar de tamanho.
	var ator := _ator(Entregador.Modelo.CG_160)
	var material := _sprite(ator).material_override as ShaderMaterial
	var quad := _sprite(ator).mesh as QuadMesh
	var tamanho := quad.size
	var visto: Array[float] = []
	# Acelera e depois freia forte: a moto agacha e mergulha.
	for i in 90:
		var v := 20.0 + 0.5 * i if i < 45 else 42.0 - 1.0 * (i - 45)
		var freio := 0.0 if i < 45 else 1.0
		ator.atualizar(PASSO, v, 1.0 - freio, 0.0, false, 1.0, 0.0, 0.0, freio)
		visto.append(material.get_shader_parameter("afunda"))
	assert_vector(quad.size).is_equal(tamanho)
	(
		assert_array(
			material.shader.get_shader_uniform_list().map(
				func(u: Dictionary) -> String: return u["name"]
			)
		)
		. not_contains(["estica"])
	)
	# E desce de verdade: a freada afunda a frente.
	assert_float(visto.max() - visto.min()).is_greater(0.001)
