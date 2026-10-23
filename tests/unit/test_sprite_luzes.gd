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
