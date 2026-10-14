extends GdUnitTestSuite
## O fluxo em volta da corrida: o menu de pagina unica e o resultado.
##
## Duas coisas aqui quebram em silencio, e sao as duas que este arquivo trava.
##
## A primeira e a ORDEM das linhas do menu. `RaceFlow._escolher` decide pelo
## indice, entao trocar duas linhas de lugar faz SAIR morar onde o PAINEL
## morava - e o menu continua desenhando lindamente. Ninguem descobre isso
## olhando; descobre fechando o jogo sem querer.
##
## A segunda e o banco de provas. Se o fluxo parar de largar direto na corrida
## no modo selftest, o processo headless fica esperando um ENTER que nunca vem:
## o portao nao reprova, ele TRAVA, e travado nao tem codigo de saida pra CI
## ler. E o unico jeito de essa regressao aparecer em segundos em vez de num
## job de CI pendurado.


func _fluxo(direto_na_corrida: bool = false) -> RaceFlow:
	var fluxo: RaceFlow = auto_free(RaceFlow.new())
	add_child(fluxo)
	fluxo.iniciar(direto_na_corrida)
	return fluxo


## Um fluxo com duas opcoes, uma em cada secao, que anotam os passos que
## receberam em `passos`: [secao, passo].
func _com_opcoes(passos: Array) -> RaceFlow:
	var fluxo := _fluxo()
	fluxo.opcao(
		"CORRIDA",
		"MOTO",
		func() -> String: return "CG 160",
		func(passo: int) -> void: passos.append(["MOTO", passo])
	)
	fluxo.opcao(
		"VISUAL",
		"PIXEL",
		func() -> String: return "SIM",
		func(passo: int) -> void: passos.append(["PIXEL", passo])
	)
	return fluxo


func _aperta(fluxo: RaceFlow, acoes: Array[String]) -> void:
	for acao in acoes:
		fluxo.navegar(_tecla(acao))


func _tecla(acao: String) -> InputEventAction:
	var evento := InputEventAction.new()
	evento.action = acao
	evento.pressed = true
	return evento


func test_banco_de_provas_larga_direto_na_corrida() -> void:
	var fluxo := _fluxo(true)
	assert_int(fluxo.tela).is_equal(RaceFlow.Tela.CORRIDA)
	# E nao consome tecla nenhuma: no selftest o input e todo do piloto
	# automatico, e um menu comendo o acelerador nao mediria a moto.
	assert_bool(fluxo.navegar(_tecla("ui_accept"))).is_false()
	assert_bool(fluxo.navegar(_tecla("ui_down"))).is_false()


func test_o_menu_e_jogar_as_opcoes_e_as_saidas() -> void:
	var fluxo := _com_opcoes([])
	assert_int(fluxo.tela).is_equal(RaceFlow.Tela.MENU)
	assert_array(fluxo.rotulos_da_tela()).is_equal(
		["JOGAR", "MOTO: CG 160", "PIXEL: SIM", RaceFlow.PAINEL, "SAIR"]
	)


func test_seta_de_lado_muda_so_a_opcao_selecionada() -> void:
	var passos: Array = []
	var fluxo := _com_opcoes(passos)
	_aperta(fluxo, ["ui_down", "ui_right", "ui_left", "ui_accept", "ui_down", "ui_right"])
	# ENTER numa opcao e o mesmo que a seta para a direita.
	assert_array(passos).is_equal([["MOTO", 1], ["MOTO", -1], ["MOTO", 1], ["PIXEL", 1]])
	# Mudar opcao nao larga a corrida: quem troca quer ver antes.
	assert_int(fluxo.tela).is_equal(RaceFlow.Tela.MENU)


func test_seta_de_lado_fora_das_opcoes_nao_muda_nada() -> void:
	var passos: Array = []
	var fluxo := _com_opcoes(passos)
	assert_bool(fluxo.navegar(_tecla("ui_right"))).is_false()
	_aperta(fluxo, ["ui_up", "ui_left", "ui_up", "ui_right"])
	assert_array(passos).is_empty()


func test_opcao_nova_entra_antes_das_saidas() -> void:
	# A ordem e de quem registra; as saidas ficam sempre por ultimo, senao SAIR
	# muda de indice a cada opcao que nasce.
	var fluxo := _com_opcoes([])
	fluxo.opcao("VISUAL", "SOMBRA", func() -> String: return "NAO", func(_p: int) -> void: pass)
	var rotulos := fluxo.rotulos_da_tela()
	assert_str(rotulos[3]).is_equal("SOMBRA: NAO")
	assert_str(rotulos[rotulos.size() - 1]).is_equal("SAIR")


func test_painel_pede_o_painel_de_tuning() -> void:
	var fluxo := _com_opcoes([])
	var pedidos: Array[int] = [0]
	fluxo.painel_pedido.connect(func() -> void: pedidos[0] += 1)
	_aperta(fluxo, ["ui_up", "ui_up", "ui_accept"])
	assert_int(pedidos[0]).is_equal(1)
	assert_int(fluxo.tela).is_equal(RaceFlow.Tela.MENU)


func test_muitas_opcoes_cabem_na_tela() -> void:
	# A tela nao tem limite de linhas: com mais do que cabe, a fonte encolhe e
	# a secao quebra em colunas. Nenhum rotulo pode sair da tela de 320x180.
	var fluxo := _fluxo()
	for i in 40:
		fluxo.opcao(
			"SECAO %d" % (i / 15),
			"OPCAO %d" % i,
			func() -> String: return "SIM",
			func(_p: int) -> void: pass
		)
	var tela := Rect2(Vector2.ZERO, Vector2(Hud.W, Hud.H) * Hud.ESCALA)
	var visiveis := 0
	for rotulo: Label in fluxo.find_children("*", "Label", true, false):
		if not rotulo.visible:
			continue
		visiveis += 1
		# A caixa do rotulo e mais alta que o texto; quem tem de caber e o texto,
		# da altura do corpo da fonte.
		var corpo := float(rotulo.get_theme_font_size("font_size"))
		var texto := Rect2(rotulo.position, Vector2(rotulo.size.x, corpo))
		assert_bool(tela.encloses(texto)).override_failure_message(rotulo.text).is_true()
	assert_int(visiveis).is_greater(40)


func test_sair_e_sempre_a_ultima_linha_do_menu() -> void:
	# Com e sem corrida congelada atras: a primeira linha troca de NOME, nunca
	# de lugar, senao o indice que SAIR ocupa passa a depender do estado.
	var fluxo := _com_opcoes([])
	var parado := fluxo.rotulos_da_tela()
	fluxo.navegar(_tecla("ui_accept"))
	fluxo.navegar(_tecla("ui_cancel"))
	var pausado := fluxo.rotulos_da_tela()

	assert_int(pausado.size()).is_equal(parado.size())
	assert_str(parado[parado.size() - 1]).is_equal("SAIR")
	assert_str(pausado[pausado.size() - 1]).is_equal("SAIR")
	assert_str(parado[0]).is_equal("JOGAR")
	assert_str(pausado[0]).is_equal("CONTINUAR")


func test_jogar_pede_corrida_nova() -> void:
	var fluxo := _fluxo()
	var pedidos: Array[int] = [0]
	fluxo.corrida_pedida.connect(func() -> void: pedidos[0] += 1)

	fluxo.navegar(_tecla("ui_accept"))

	assert_int(fluxo.tela).is_equal(RaceFlow.Tela.CORRIDA)
	assert_int(pedidos[0]).is_equal(1)


func test_esc_congela_a_corrida_e_continuar_nao_a_joga_fora() -> void:
	var fluxo := _fluxo(true)
	var pedidos: Array[int] = [0]
	fluxo.corrida_pedida.connect(func() -> void: pedidos[0] += 1)

	assert_bool(fluxo.navegar(_tecla("ui_cancel"))).is_true()
	assert_int(fluxo.tela).is_equal(RaceFlow.Tela.MENU)

	fluxo.navegar(_tecla("ui_accept"))
	assert_int(fluxo.tela).is_equal(RaceFlow.Tela.CORRIDA)
	# Nenhum pedido de corrida NOVA: continuar tem que devolver a corrida que
	# estava congelada. Largar de novo apagaria a colocacao de quem pausou
	# faltando 200 m, e menu de pausa que faz isso e menu que ninguem abre.
	assert_int(pedidos[0]).is_equal(0)


func test_esc_no_menu_nao_sai_dele() -> void:
	var fluxo := _com_opcoes([])
	assert_bool(fluxo.navegar(_tecla("ui_cancel"))).is_true()
	assert_int(fluxo.tela).is_equal(RaceFlow.Tela.MENU)


func test_resultado_oferece_correr_de_novo_e_menu() -> void:
	var fluxo := _fluxo(true)
	fluxo.mostrar_resultado("1o LUGAR de 6")
	assert_int(fluxo.tela).is_equal(RaceFlow.Tela.RESULTADO)
	assert_array(fluxo.rotulos_da_tela()).is_equal(["CORRER DE NOVO", "MENU"])

	var pedidos: Array[int] = [0]
	fluxo.corrida_pedida.connect(func() -> void: pedidos[0] += 1)
	fluxo.navegar(_tecla("ui_accept"))

	# Aqui a corrida acabou de verdade, entao correr de novo E uma corrida
	# nova - o oposto do que o ESC faz.
	assert_int(fluxo.tela).is_equal(RaceFlow.Tela.CORRIDA)
	assert_int(pedidos[0]).is_equal(1)


func test_selecao_da_a_volta_nas_duas_direcoes() -> void:
	var fluxo := _com_opcoes([])
	var pedidos: Array[int] = [0]
	fluxo.corrida_pedida.connect(func() -> void: pedidos[0] += 1)

	# Uma seta pra cima no primeiro item cai no ultimo (SAIR), e uma pra baixo
	# devolve pro primeiro. So a volta completa prova as duas pontas sem
	# precisar apertar ENTER em cima do SAIR e fechar o jogo no meio do teste.
	_aperta(fluxo, ["ui_up", "ui_down", "ui_accept"])

	assert_int(pedidos[0]).is_equal(1)
	assert_int(fluxo.tela).is_equal(RaceFlow.Tela.CORRIDA)
