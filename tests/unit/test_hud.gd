extends GdUnitTestSuite
## A HUD de arcade: a fonte assada e as contas que viram texto e segmento.
##
## O que quebra em silencio aqui e glifo. Um caractere novo num aviso que a
## tabela nao tem vira `?` na tela, e ninguem olha o canto da tela procurando
## isso; e uma linha com largura diferente das outras desenha a letra torta
## sem erro nenhum.


func test_toda_linha_de_um_glifo_tem_a_mesma_largura() -> void:
	for c: String in FonteHud.GLIFOS:
		var linhas: Array = FonteHud.GLIFOS[c]
		assert_int(linhas.size()).override_failure_message("glifo '%s'" % c).is_equal(
			FonteHud.ALTURA
		)
		var w := (linhas[0] as String).length()
		for linha: String in linhas:
			assert_int(linha.length()).override_failure_message("glifo '%s'" % c).is_equal(w)


func test_tudo_que_a_hud_escreve_tem_glifo() -> void:
	# O que a Hud e o World escrevem hoje, em caixa alta como a fonte desenha.
	var textos: Array[String] = [
		"POS",
		"DIST",
		"SPEED",
		"TIME",
		"KM/H",
		"KM",
		"M",
		"ATRASADO",
		"CONTRAMAO",
		"CORREDOR x3",
		"WASD  Q/E SOCO  SHIFT BOOST  R REINICIA  ESC MENU",
		"capotou: parede",
		"perdeu posicao - 3/6",
		Hud.carimbo_versao(),
		Hud.formata_tempo(83.47),
		"*",
	]
	for texto in textos:
		var alto := texto.to_upper()
		for i in alto.length():
			var c := alto[i]
			if c == " ":
				continue
			(
				assert_bool(FonteHud.GLIFOS.has(c))
				. override_failure_message("'%s' em \"%s\" nao tem glifo" % [c, texto])
				. is_true()
			)


func test_largura_cresce_com_o_texto_e_ignora_caixa() -> void:
	var fonte := FonteHud.new(1, 1, Color.WHITE, Color.WHITE)
	assert_int(fonte.largura("128")).is_greater(fonte.largura("12"))
	assert_int(fonte.largura("km/h")).is_equal(fonte.largura("KM/H"))
	# O alinhamento a direita depende de a largura ser exata para a escala.
	var grande := FonteHud.new(2, 2, Color.WHITE, Color.WHITE, 2, 2)
	assert_int(grande.largura("8")).is_greater(fonte.largura("8"))


func test_tempo_no_formato_das_referencias() -> void:
	assert_str(Hud.formata_tempo(13.5)).is_equal("00:13.5")
	assert_str(Hud.formata_tempo(83.47)).is_equal("01:23.4")
	# Nunca negativo: o relogio para no zero, quem diz que atrasou e o texto.
	assert_str(Hud.formata_tempo(-2.0)).is_equal("00:00.0")


func test_distancia_vira_km_longe_da_chegada() -> void:
	assert_array(Array(Hud.formata_distancia(2430.0))).is_equal(["2.4", "KM"])
	assert_array(Array(Hud.formata_distancia(850.0))).is_equal(["850", "M"])
	assert_array(Array(Hud.formata_distancia(-5.0))).is_equal(["0", "M"])


func test_barra_so_apaga_de_vez_no_zero() -> void:
	assert_int(Hud.segmentos_acesos(1.0, 15)).is_equal(15)
	assert_int(Hud.segmentos_acesos(0.0, 15)).is_equal(0)
	# O ultimo fiapo de prazo ainda e um segmento aceso.
	assert_int(Hud.segmentos_acesos(0.01, 15)).is_equal(1)
	# Acima do teto (boost) a barra satura, nao transborda.
	assert_int(Hud.segmentos_acesos(1.3, 18)).is_equal(18)
