extends GdUnitTestSuite
## A placa da moto em sprite (`PlacaSprite`): achar a chapa do Flow no quadro,
## deixa-la lisa e escrever a placa do jogo por cima, em qualquer quadrilatero.

const QUADRO := Vector2i(80, 80)


## O pixel de uma imagem guarda 8 bits por canal: comparar com a cor em float
## pede uma folga de meio degrau.
func _igual(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.01 and absf(a.g - b.g) < 0.01 and absf(a.b - b.b) < 0.01


func _quadro_com_chapa(onde: Rect2i) -> Image:
	var imagem := Image.create_empty(QUADRO.x, QUADRO.y, false, Image.FORMAT_RGBA8)
	# O desenho: um bloco vermelho de 40 x 60 no meio, como a bag e a camiseta.
	imagem.fill_rect(Rect2i(20, 15, 40, 60), Color(0.8, 0.1, 0.1))
	imagem.fill_rect(onde, Color(0.85, 0.85, 0.85))
	return imagem


func test_acha_a_chapa_branca_no_meio_de_baixo_do_desenho() -> void:
	var quadro := _quadro_com_chapa(Rect2i(32, 55, 16, 10))
	var cantos := PlacaSprite.acha(quadro, quadro.get_used_rect())
	assert_int(cantos.size()).is_equal(4)
	assert_vector(cantos[0]).is_equal(Vector2(32, 55))
	assert_vector(cantos[2]).is_equal(Vector2(48, 65))


func test_nao_acha_chapa_onde_so_ha_camiseta() -> void:
	var quadro := Image.create_empty(QUADRO.x, QUADRO.y, false, Image.FORMAT_RGBA8)
	quadro.fill_rect(Rect2i(20, 15, 40, 60), Color(0.8, 0.1, 0.1))
	assert_int(PlacaSprite.acha(quadro, quadro.get_used_rect()).size()).is_equal(0)


func test_pixel_claro_demais_de_cima_do_desenho_nao_e_placa() -> void:
	# O brilho do capacete, la em cima, fica fora da janela de busca.
	var quadro := _quadro_com_chapa(Rect2i(32, 55, 16, 10))
	quadro.fill_rect(Rect2i(36, 16, 8, 6), Color(0.95, 0.95, 0.95))
	var cantos := PlacaSprite.acha(quadro, quadro.get_used_rect())
	assert_float(cantos[0].y).is_greater_equal(55.0)


func test_tres_quartos_procura_no_terco_da_traseira_a_esquerda() -> void:
	var quadro := Image.create_empty(QUADRO.x, QUADRO.y, false, Image.FORMAT_RGBA8)
	quadro.fill_rect(Rect2i(10, 20, 60, 50), Color(0.2, 0.2, 0.25))
	quadro.fill_rect(Rect2i(12, 50, 10, 8), Color(0.85, 0.85, 0.85))
	assert_int(PlacaSprite.acha(quadro, quadro.get_used_rect()).size()).is_equal(0)
	var cantos := PlacaSprite.acha(quadro, quadro.get_used_rect(), true)
	assert_int(cantos.size()).is_equal(4)
	assert_vector(cantos[0]).is_equal(Vector2(12, 50))


func test_a_chapa_tem_a_faixa_azul_em_cima_e_texto_embaixo() -> void:
	var placa := PlacaSprite.chapa("ABC1D23", 40, 34)
	assert_vector(Vector2(placa.get_width(), placa.get_height())).is_equal(Vector2(40, 34))
	assert_bool(_igual(placa.get_pixel(20, 1), PlacaSprite.AZUL)).is_true()
	var tinta := 0
	for y in range(8, 34):
		for x in 40:
			if _igual(placa.get_pixel(x, y), PlacaSprite.TINTA):
				tinta += 1
	assert_int(tinta).is_greater(60)


func test_textos_diferentes_dao_chapas_diferentes() -> void:
	var a := PlacaSprite.chapa("ABC1D23", 40, 34)
	var b := PlacaSprite.chapa("XYZ9K87", 40, 34)
	assert_bool(a.get_data() == b.get_data()).is_false()
	assert_bool(a.get_data() == PlacaSprite.chapa("ABC1D23", 40, 34).get_data()).is_true()


func test_toda_letra_e_todo_digito_tem_glifo() -> void:
	for caractere in Placa.LETRAS + Placa.DIGITOS:
		assert_bool(PlacaSprite.GLIFOS.has(caractere)).is_true()
		assert_int((PlacaSprite.GLIFOS[caractere] as Array).size()).is_equal(5)


func test_pinta_so_dentro_do_quadrilatero() -> void:
	var quadro := _quadro_com_chapa(Rect2i(32, 55, 16, 10))
	var antes := quadro.duplicate() as Image
	var cantos := PackedVector2Array(
		[Vector2(32, 55), Vector2(48, 55), Vector2(48, 65), Vector2(32, 65)]
	)
	PlacaSprite.pinta(quadro, cantos, "ABC1D23")
	for y in QUADRO.y:
		for x in QUADRO.x:
			if not Rect2i(32, 55, 16, 10).has_point(Vector2i(x, y)):
				assert_bool(quadro.get_pixel(x, y) == antes.get_pixel(x, y)).is_true()
	assert_bool(_igual(quadro.get_pixel(40, 56), PlacaSprite.AZUL)).is_true()


func test_pinta_num_paralelogramo_inclinado_leva_a_faixa_para_o_lado_de_cima() -> void:
	var quadro := Image.create_empty(QUADRO.x, QUADRO.y, false, Image.FORMAT_RGBA8)
	# A moto deitada: a chapa vira um paralelogramo, mais alta na direita.
	var cantos := PackedVector2Array(
		[Vector2(20, 40), Vector2(50, 30), Vector2(50, 44), Vector2(20, 54)]
	)
	PlacaSprite.pinta(quadro, cantos, "ABC1D23")
	assert_bool(_igual(quadro.get_pixel(35, 36), PlacaSprite.AZUL)).is_true()
	assert_bool(_igual(quadro.get_pixel(35, 49), PlacaSprite.AZUL)).is_false()


func test_apaga_deixa_a_chapa_lisa() -> void:
	var quadro := _quadro_com_chapa(Rect2i(32, 55, 16, 10))
	quadro.set_pixel(40, 60, Color.BLACK)
	var cantos := PackedVector2Array(
		[Vector2(32, 55), Vector2(48, 55), Vector2(48, 65), Vector2(32, 65)]
	)
	PlacaSprite.apaga(quadro, cantos)
	assert_bool(_igual(quadro.get_pixel(40, 60), PlacaSprite.CHAPA)).is_true()


func test_toda_placa_das_fichas_cai_dentro_da_celula() -> void:
	var achou := 0
	for item in CatalogoSprites.varrer():
		if item.tipo != CatalogoSprites.Tipo.MOTO_FOLHA:
			continue
		var ficha: Dictionary = CatalogoSprites._ler_ficha(item.caminho.get_basename() + ".json")
		for placa: Dictionary in ficha.get("placa", []):
			achou += 1
			for canto: Array in placa["cantos"]:
				(
					assert_bool(
						Rect2(Vector2.ZERO, Vector2(item.celula)).has_point(
							Vector2(canto[0], canto[1])
						)
					)
					. is_true()
				)
	assert_int(achou).is_greater(60)
