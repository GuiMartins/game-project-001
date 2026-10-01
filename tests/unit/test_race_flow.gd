extends GdUnitTestSuite
## O fluxo em volta da corrida: menu, configuracoes e resultado.
##
## Duas coisas aqui quebram em silencio, e sao as duas que este arquivo trava.
##
## A primeira e a ORDEM das linhas do menu. `RaceFlow._escolher` decide pelo
## indice, entao trocar duas linhas de lugar faz SAIR morar onde CONFIGURACOES
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


func test_jogo_abre_no_menu() -> void:
	var fluxo := _fluxo()
	assert_int(fluxo.tela).is_equal(RaceFlow.Tela.MENU)
	assert_array(fluxo.rotulos_da_tela()).is_equal(["JOGAR", "CONFIGURACOES", "SAIR"])


func test_sair_e_sempre_a_ultima_linha_do_menu() -> void:
	# Com e sem corrida congelada atras: a primeira linha troca de NOME, nunca
	# de lugar, senao o indice que SAIR ocupa passa a depender do estado.
	var fluxo := _fluxo()
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


func test_configuracoes_mostram_o_estado_de_quem_sabe() -> void:
	var fluxo := _fluxo()
	fluxo.descreve_pixel = func() -> String: return "LIGADO"
	fluxo.descreve_camera = func() -> String: return "CAPACETE"

	fluxo.navegar(_tecla("ui_down"))
	fluxo.navegar(_tecla("ui_accept"))

	assert_int(fluxo.tela).is_equal(RaceFlow.Tela.CONFIGURACOES)
	var rotulos := fluxo.rotulos_da_tela()
	assert_str(rotulos[0]).contains("LIGADO")
	assert_str(rotulos[1]).contains("CAPACETE")
	assert_str(rotulos[rotulos.size() - 1]).is_equal("VOLTAR")


func test_esc_nas_configuracoes_volta_pro_menu() -> void:
	var fluxo := _fluxo()
	fluxo.navegar(_tecla("ui_down"))
	fluxo.navegar(_tecla("ui_accept"))
	assert_int(fluxo.tela).is_equal(RaceFlow.Tela.CONFIGURACOES)

	fluxo.navegar(_tecla("ui_cancel"))
	assert_int(fluxo.tela).is_equal(RaceFlow.Tela.MENU)


func test_selecao_da_a_volta_nas_duas_direcoes() -> void:
	var fluxo := _fluxo()
	var pedidos: Array[int] = [0]
	fluxo.corrida_pedida.connect(func() -> void: pedidos[0] += 1)

	# Uma seta pra cima no primeiro item cai no ultimo (SAIR), e uma pra baixo
	# devolve pro primeiro. So a volta completa prova as duas pontas sem
	# precisar apertar ENTER em cima do SAIR e fechar o jogo no meio do teste.
	fluxo.navegar(_tecla("ui_up"))
	fluxo.navegar(_tecla("ui_down"))
	fluxo.navegar(_tecla("ui_accept"))

	assert_int(pedidos[0]).is_equal(1)
	assert_int(fluxo.tela).is_equal(RaceFlow.Tela.CORRIDA)
