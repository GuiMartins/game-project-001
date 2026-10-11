extends GdUnitTestSuite
## A folha de comparacao da prova visual (V02 do backlog visual).
##
## A prova em si precisa de tela e nao roda aqui; a montagem da folha e conta
## de imagem, e e ela que decide se o jogo aparece no tamanho em que e julgado.

const Prova := preload("res://scripts/prova.gd")


func _imagem(w: int, h: int, cor: Color) -> Image:
	var imagem := Image.create(w, h, false, Image.FORMAT_RGB8)
	imagem.fill(cor)
	return imagem


func test_o_jogo_fica_no_tamanho_e_a_referencia_vai_a_altura_dele() -> void:
	var jogo := _imagem(640, 360, Color.RED)
	var video := _imagem(640, 480, Color.BLUE)
	var folha := Prova.comparacao([[jogo, video]])
	# 640x480 na altura 360 vira 480x360.
	assert_int(folha.get_width()).is_equal(640 + 480)
	assert_int(folha.get_height()).is_equal(360)
	assert_that(folha.get_pixel(639, 180)).is_equal(Color.RED)
	assert_that(folha.get_pixel(640, 180)).is_equal(Color.BLUE)


func test_linha_sem_referencia_completa_com_fundo() -> void:
	# Enquanto as imagens paradas nao chegam, uma linha pode ter menos
	# referencias que outra; a folha toma a largura da maior.
	var jogo := _imagem(640, 360, Color.RED)
	var folha := Prova.comparacao([[jogo, _imagem(640, 480, Color.BLUE)], [jogo]])
	assert_int(folha.get_width()).is_equal(1120)
	assert_int(folha.get_height()).is_equal(720)
	assert_that(folha.get_pixel(0, 360)).is_equal(Color.RED)
	# 0,5 vira 127 ou 128 em 8 bits: compara com meio degrau de folga.
	assert_float(folha.get_pixel(900, 500).r).is_equal_approx(Prova.FUNDO.r, 0.003)


func test_toda_prova_tem_referencia_de_video() -> void:
	# Quadro novo na prova sem referencia sai sozinho na linha, e a folha
	# deixa de responder a pergunta para ele.
	for nome: String in ["largada", "curva", "ladeira", "reta"]:
		assert_bool(Prova.REFERENCIAS.has(nome)).is_true()
		assert_bool((Prova.REFERENCIAS[nome][0] as String).begins_with("video_01/")).is_true()


func test_lupa_amplia_sem_filtro() -> void:
	# A lupa existe para mostrar o dither; filtro bilinear apagaria o padrao
	# que ela esta ali para mostrar.
	var imagem := _imagem(640, 360, Color.BLACK)
	imagem.set_pixelv(Prova.LUPA.position, Color.WHITE)
	var lupa := Prova.lupa([imagem, imagem])
	var e := Prova.LUPA_ESCALA
	assert_int(lupa.get_width()).is_equal(Prova.LUPA.size.x * e * 2)
	assert_that(lupa.get_pixel(e - 1, e - 1)).is_equal(Color.WHITE)
	assert_that(lupa.get_pixel(e, e)).is_equal(Color.BLACK)
