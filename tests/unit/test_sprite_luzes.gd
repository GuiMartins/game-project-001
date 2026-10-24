extends GdUnitTestSuite
## As luzes da ficha no shader do sprite (`SpriteLuzes`). O brilho em si e do
## shader e precisa de tela; aqui e a conta que vai para ele.


func _ficha() -> Dictionary:
	return {
		"celula": [64, 48],
		"luzes":
		[
			{"nome": "lanterna_e", "linha": 0, "coluna": 0, "ponto": [10, 20], "raio": 5},
			{
				"nome": "freio",
				"linha": 0,
				"coluna": 0,
				"ponto": [50, 20],
				"cor": [1.0, 0.0, 0.0],
				"so_de_noite": false,
			},
			{"nome": "farol", "linha": 2, "coluna": 1, "ponto": [30, 30]},
		],
	}


func test_so_entram_as_luzes_da_celula() -> void:
	var luzes := SpriteLuzes.da_celula(_ficha(), 0, 0)
	assert_int(luzes["n"]).is_equal(2)
	assert_vector((luzes["pos"] as PackedVector4Array)[0]).is_equal(Vector4(10, 20, 5, 1))
	assert_int(SpriteLuzes.da_celula(_ficha(), 2, 1)["n"]).is_equal(1)
	assert_int(SpriteLuzes.da_celula(_ficha(), 1, 1)["n"]).is_equal(0)


func test_o_shader_recebe_sempre_max_itens() -> void:
	var luzes := SpriteLuzes.da_celula(_ficha(), 0, 0)
	assert_int((luzes["pos"] as PackedVector4Array).size()).is_equal(SpriteLuzes.MAX)
	assert_int((luzes["cor"] as PackedVector4Array).size()).is_equal(SpriteLuzes.MAX)


func test_o_freio_acende_de_dia_e_a_lanterna_so_de_noite() -> void:
	var pos := SpriteLuzes.da_celula(_ficha(), 0, 0)["pos"] as PackedVector4Array
	assert_float(pos[0].w).is_equal(1.0)
	assert_float(pos[1].w).is_equal(0.0)


func test_a_cor_e_o_raio_tem_padrao() -> void:
	var luzes := SpriteLuzes.da_celula(_ficha(), 2, 1)
	var pos := luzes["pos"] as PackedVector4Array
	var cor := luzes["cor"] as PackedVector4Array
	assert_float(pos[0].z).is_equal(SpriteLuzes.RAIO_PADRAO)
	assert_float(cor[0].x).is_equal(SpriteLuzes.COR_PADRAO.r)


func test_a_forca_vem_pelo_nome_e_o_resto_acende_inteiro() -> void:
	var cor := SpriteLuzes.da_celula(_ficha(), 0, 0, {"freio": 0.25})["cor"] as PackedVector4Array
	assert_float(cor[0].w).is_equal(1.0)
	assert_float(cor[1].w).is_equal(0.25)
	cor = SpriteLuzes.da_celula(_ficha(), 0, 0, {"freio": 7.0})["cor"] as PackedVector4Array
	assert_float(cor[1].w).is_equal(1.0)


func test_aplica_poe_no_material_as_luzes_e_a_celula() -> void:
	var material := ShaderMaterial.new()
	SpriteLuzes.aplica(material, _ficha(), 0, 0)
	assert_int(int(material.get_shader_parameter(&"n_luzes"))).is_equal(2)
	assert_vector(material.get_shader_parameter(&"celula_px")).is_equal(Vector2(64, 48))


func test_o_luminoso_do_taxi_cai_na_placa_do_teto_em_todos_os_quadros() -> void:
	# Coordenada que cai no verde nao acende nada: o shader preserva o alfa.
	# Conferir o pixel real pega o erro que apenas validar os limites nao pega.
	for nome: String in ["taxi_base", "taxi_porta_1", "taxi_porta_2"]:
		var caminho := "res://assets/sprites/carros/%s" % nome
		var ficha: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(caminho + ".json"))
		var fonte: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string("res://arte/flow/fichas/%s.json" % nome)
		)
		assert_array(ficha["luzes"]).is_equal(fonte["luzes"])
		var colunas := int(ficha["colunas"])
		var linhas: Array = ficha["linhas"]
		var celula := Vector2i(int(ficha["celula"][0]), int(ficha["celula"][1]))
		var imagem := CatalogoSprites.imagem_de(caminho + ".png")
		assert_int((ficha["luzes"] as Array).size()).is_equal(colunas * linhas.size())
		for linha in linhas.size():
			for coluna in colunas:
				var aceso := SpriteLuzes.da_celula(ficha, linha, coluna)
				assert_int(aceso["n"]).is_equal(1)
				var pos := (aceso["pos"] as PackedVector4Array)[0]
				var pixel := imagem.get_pixelv(
					Vector2i(coluna, linha) * celula + Vector2i(int(pos.x), int(pos.y))
				)
				assert_float(pixel.a).is_equal(1.0)
				assert_float(minf(pixel.r, minf(pixel.g, pixel.b))).is_greater(0.7)
				assert_float(pos.y).is_less(celula.y * 0.35)
				var apagado := SpriteLuzes.da_celula(ficha, linha, coluna, {"luminoso": 0.0})
				assert_float((apagado["cor"] as PackedVector4Array)[0].w).is_equal(0.0)


func test_os_letreiros_do_onibus_caem_no_painel_ambar_visivel() -> void:
	# O perfil esquerdo nao mostra painel; o 3/4 traseiro das portas mostra dois.
	# Acender uma coordenada herdada do espelho iluminaria a carroceria vermelha.
	for nome: String in ["onibus_base", "onibus_porta_1", "onibus_porta_2"]:
		var caminho := "res://assets/sprites/carros/%s" % nome
		var ficha: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(caminho + ".json"))
		var imagem := CatalogoSprites.imagem_de(caminho + ".png")
		var celula := Vector2i(int(ficha["celula"][0]), int(ficha["celula"][1]))
		var linhas: Array = ficha["linhas"]
		for linha in linhas.size():
			for coluna in int(ficha["colunas"]):
				var luzes := SpriteLuzes.da_celula(ficha, linha, coluna)
				var esperado := 3
				if nome == "onibus_base" and linha == 2:
					esperado = 0
				elif nome != "onibus_base" and linha == 2:
					esperado = 6
				assert_int(luzes["n"]).is_equal(esperado)
				for i in int(luzes["n"]):
					var pos := (luzes["pos"] as PackedVector4Array)[i]
					var pixel := imagem.get_pixelv(
						Vector2i(coluna, linha) * celula + Vector2i(int(pos.x), int(pos.y))
					)
					assert_float(pixel.a).is_equal(1.0)
					assert_float(pixel.g).is_greater(pixel.b)
					assert_float(pixel.g).is_greater(pixel.r * 0.35)
					assert_float(pos.w).is_equal(0.0)


func test_o_onibus_tem_sete_vistas_sem_espelhar_as_portas_para_a_esquerda() -> void:
	var base := CatalogoSprites._folha(
		"onibus_base", CatalogoSprites.PASTA_CARROS, CatalogoSprites.Tipo.CARRO
	)
	assert_object(base).is_not_null()
	assert_int(base.colunas).is_equal(2)
	assert_bool(base.espelha_lado_esquerdo).is_false()
	assert_array(Array(base.rotulos_linhas)).is_equal(
		[
			"frente",
			"tres_quartos_frente",
			"lado",
			"tres_quartos_costas",
			"costas",
			"lado_da_porta",
			"tres_quartos_da_porta"
		]
	)
	for nome: String in ["onibus_porta_1", "onibus_porta_2"]:
		var porta := CatalogoSprites._folha(
			nome, CatalogoSprites.PASTA_CARROS, CatalogoSprites.Tipo.CARRO
		)
		assert_object(porta).is_not_null()
		assert_bool(porta.espelha_lado_esquerdo).is_false()
		assert_int(porta.colunas).is_equal(5)
		assert_array(Array(porta.rotulos_linhas)).is_equal(
			["lado", "tres_quartos_frente", "tres_quartos_costas"]
		)
