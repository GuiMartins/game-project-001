extends GdUnitTestSuite
## O recorte de folha do Flow (`arte/recorte_de_folha.gd`), com uma folha feita
## aqui: retangulos de cor sobre o verde, em grade, do jeito que o Flow entrega.

const Recorte := preload("res://arte/recorte_de_folha.gd")

const VERDE := Color(0.0, 1.0, 0.0)


func _ficha() -> Dictionary:
	return {
		"fonte": "res://nada.jpg",
		"saida": "res://nada",
		"linhas": ["frente", "lado"],
		"colunas": 3,
		"celula": [40, 60],
		"pe_y": 56,
		"altura_m": 1.0,
		"pixels_por_metro": 50.0,
		"escala": "altura",
		"ancora_x": "centro",
		"ancora_y": "pes",
		"vao": 4,
		"area_minima": 100,
	}


## Uma grade de `linhas` x `colunas` retangulos vermelhos de 20x40 sobre verde.
func _folha(linhas: int, colunas: int, altura: int = 40) -> Image:
	var imagem := Image.create_empty(colunas * 60 + 20, linhas * 80 + 20, false, Image.FORMAT_RGBA8)
	imagem.fill(VERDE)
	for l in linhas:
		for c in colunas:
			imagem.fill_rect(Rect2i(20 + c * 60, 20 + l * 80, 20, altura), Color(0.8, 0.1, 0.1))
	return imagem


func test_acha_a_grade_pelos_vaos_e_poe_cada_desenho_na_sua_celula() -> void:
	var feito := Recorte.atlas_da_ficha(_ficha(), _folha(2, 3))
	assert_bool(feito.has("erro")).is_false()
	var atlas: Image = feito["atlas"]
	assert_vector(Vector2(atlas.get_size())).is_equal(Vector2(120, 120))
	# O desenho tem 40 px e a altura pedida e 50: escala 1,25, 50 px, de pe_y.
	assert_float(atlas.get_pixel(20, 56 - 25).a).is_equal(1.0)
	assert_float(atlas.get_pixel(20, 56 - 55).a).is_equal(0.0)
	# O da segunda linha, terceira coluna, esta na celula certa.
	assert_float(atlas.get_pixel(2 * 40 + 20, 60 + 56 - 25).a).is_equal(1.0)


func test_o_verde_some_e_nao_deixa_franja() -> void:
	var feito := Recorte.atlas_da_ficha(_ficha(), _folha(2, 3))
	var atlas: Image = feito["atlas"]
	assert_float(atlas.get_pixel(2, 2).a).is_equal(0.0)
	var cor := atlas.get_pixel(20, 56 - 25)
	assert_float(cor.g).is_less(cor.r)


func test_reprova_a_folha_com_a_contagem_errada_e_diz_o_que_achou() -> void:
	var feito := Recorte.atlas_da_ficha(_ficha(), _folha(2, 2))
	assert_bool(feito.has("erro")).is_true()
	assert_str(feito["erro"]).contains("devia ser 2 x 3")
	assert_str(feito["erro"]).contains("[2, 2]")


func test_sujeira_menor_que_a_area_minima_nao_conta_como_desenho() -> void:
	var imagem := _folha(2, 3)
	imagem.fill_rect(Rect2i(5, 5, 6, 6), Color(0.8, 0.1, 0.1))
	var feito := Recorte.atlas_da_ficha(_ficha(), imagem)
	assert_bool(feito.has("erro")).is_false()


func test_ficha_sem_campo_e_reprovada_pelo_nome_dele() -> void:
	var ficha := _ficha()
	ficha.erase("pe_y")
	assert_str(Recorte.confere_ficha(ficha)).contains("pe_y")


func test_luz_fora_da_celula_e_reprovada() -> void:
	var ficha := _ficha()
	ficha["luzes"] = [{"nome": "lanterna", "linha": 0, "coluna": 0, "ponto": [41, 10]}]
	assert_str(Recorte.confere_ficha(ficha)).contains("lanterna")
	ficha["luzes"] = [{"nome": "lanterna", "linha": 0, "coluna": 0, "ponto": [39, 10]}]
	assert_str(Recorte.confere_ficha(ficha)).is_empty()


func test_escala_fixa_pede_uma_medida_por_linha() -> void:
	var ficha := _ficha()
	ficha["escala"] = "fixa"
	assert_str(Recorte.confere_ficha(ficha)).contains("pixels_por_metro_fonte")
	var medidas: Array = []
	medidas.resize((ficha["linhas"] as Array).size())
	medidas.fill(170.0)
	ficha["pixels_por_metro_fonte"] = medidas
	assert_str(Recorte.confere_ficha(ficha)).is_empty()


func test_a_ancora_dos_pes_ignora_o_que_empurra_o_centro() -> void:
	# Um adulto de pe com um objeto alto de um lado: o centro anda para o lado
	# do objeto, e o meio dos pes continua sob o corpo.
	var largura := 40
	var cheio := PackedByteArray()
	cheio.resize(largura * 40)
	for y in range(10, 40):
		for x in range(5, 9):
			cheio[y * largura + x] = 1
	for y in range(0, 10):
		for x in range(20, 38):
			cheio[y * largura + x] = 1
	var caixa := Recorte.caixa_do_desenho(cheio, largura, Rect2i(0, 0, largura, 40))
	assert_float(caixa["pes_x"]).is_equal_approx(6.5, 0.6)
	assert_float((caixa["centro"] as Vector2).x).is_greater(12.0)


func test_a_ficha_do_atlas_leva_as_luzes_e_o_espelho() -> void:
	var ficha := _ficha()
	ficha["espelho"] = true
	ficha["luzes"] = [{"nome": "farol", "linha": 1, "coluna": 2, "ponto": [10, 10]}]
	var info := Recorte.ficha_do_atlas(ficha)
	assert_bool(info["espelha_o_lado_esquerdo"]).is_true()
	assert_int((info["luzes"] as Array).size()).is_equal(1)
	assert_array(info["pe"]).contains_exactly([20, 56])
