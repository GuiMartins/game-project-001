extends GdUnitTestSuite
## A silhueta (`Silhueta`): a forma de um quadro, e o quanto duas se parecem.
##
## E a conta por baixo de toda comparacao com a referencia. Se ela errasse, o
## testador acusaria pose certa e deixaria passar pose errada.


func _retangulo(tamanho: Vector2i, caixa: Rect2i) -> Image:
	var imagem := Image.create_empty(tamanho.x, tamanho.y, false, Image.FORMAT_RGBA8)
	imagem.fill_rect(caixa, Color.WHITE)
	return imagem


func test_a_silhueta_acha_a_caixa_do_corpo() -> void:
	var s := Silhueta.de_imagem(_retangulo(Vector2i(100, 100), Rect2i(20, 10, 30, 60)))
	assert_object(s.caixa).is_equal(Rect2i(20, 10, 30, 60))
	assert_bool(s.vazia()).is_false()


func test_imagem_em_branco_e_silhueta_vazia() -> void:
	var s := Silhueta.de_imagem(Image.create_empty(50, 50, false, Image.FORMAT_RGBA8))
	assert_bool(s.vazia()).is_true()


func test_silhueta_igual_tem_iou_um() -> void:
	var a := Silhueta.de_imagem(_retangulo(Vector2i(100, 100), Rect2i(20, 10, 30, 60)))
	assert_float(Silhueta.iou(a, a)).is_equal(1.0)


func test_o_lugar_e_a_escala_na_celula_nao_entram_na_conta() -> void:
	# O mesmo corpo, em outro canto e duas vezes maior: e a mesma pose.
	var a := Silhueta.de_imagem(_retangulo(Vector2i(100, 100), Rect2i(10, 10, 20, 40)))
	var b := Silhueta.de_imagem(_retangulo(Vector2i(200, 200), Rect2i(100, 50, 40, 80)))
	assert_float(Silhueta.iou(a, b)).is_greater(0.99)


func test_formas_diferentes_se_parecem_pouco() -> void:
	# Um corpo cheio contra uma moldura vazia dentro da mesma caixa.
	var cheio := _retangulo(Vector2i(100, 100), Rect2i(10, 10, 80, 80))
	var oco := cheio.duplicate() as Image
	oco.fill_rect(Rect2i(30, 30, 40, 40), Color(0, 0, 0, 0))
	var iou := Silhueta.iou(Silhueta.de_imagem(cheio), Silhueta.de_imagem(oco))
	assert_float(iou).is_between(0.6, 0.85)


func test_silhueta_vazia_nao_se_parece_com_nada() -> void:
	var vazia := Silhueta.de_imagem(Image.create_empty(50, 50, false, Image.FORMAT_RGBA8))
	var cheia := Silhueta.de_imagem(_retangulo(Vector2i(50, 50), Rect2i(5, 5, 20, 20)))
	assert_float(Silhueta.iou(vazia, cheia)).is_equal(0.0)
	assert_float(Silhueta.iou(vazia, vazia)).is_equal(0.0)


func test_a_abertura_mede_a_perna_aberta_contra_a_junta() -> void:
	# Tronco de 20 px e, embaixo, ou duas pernas coladas ou abertas.
	var junta := _retangulo(Vector2i(100, 100), Rect2i(40, 10, 20, 80))
	var aberta := _retangulo(Vector2i(100, 100), Rect2i(40, 10, 20, 60))
	aberta.fill_rect(Rect2i(20, 70, 8, 20), Color.WHITE)
	aberta.fill_rect(Rect2i(72, 70, 8, 20), Color.WHITE)
	var s_junta := Silhueta.de_imagem(junta)
	var s_aberta := Silhueta.de_imagem(aberta)
	assert_float(s_aberta.abertura(aberta)).is_greater(s_junta.abertura(junta) + 0.3)


func test_o_centro_de_massa_acompanha_o_corpo() -> void:
	var esquerda := Silhueta.centro(_retangulo(Vector2i(100, 100), Rect2i(10, 10, 20, 20)))
	var direita := Silhueta.centro(_retangulo(Vector2i(100, 100), Rect2i(70, 10, 20, 20)))
	assert_float(direita.x - esquerda.x).is_between(55.0, 65.0)
