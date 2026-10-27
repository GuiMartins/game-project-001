extends GdUnitTestSuite
## O catalogo dos sprites (`CatalogoSprites`): a varredura acha tudo o que o
## jogo usa, e a conferencia de cada folha contra a ficha dela.
##
## Os avisos conhecidos estao listados aqui de proposito: folha nova com aviso
## reprova, e a lista so cresce com justificativa. Sem isso o aviso vira
## paisagem na tela do testador, como erro de console que ninguem le.

## Folhas que o catalogo marca e que sao quadros recortados pela propria arte.
## Um quadro de queda ou de desembarque que encosta na celula e a pose
## esticada, nao defeito; o dia que alguem alargar a celula, sai daqui.
const AVISOS_CONHECIDOS: Array[String] = ["escritorio_caida", "obra_desembarcando"]

var _itens: Array[CatalogoSprites.Item] = []


func before_test() -> void:
	_itens = CatalogoSprites.varrer()


func _item(id: String) -> CatalogoSprites.Item:
	for item in _itens:
		if item.id == id:
			return item
	return null


func test_a_varredura_acha_a_moto_e_os_cinco_pedestres_em_cinco_animacoes() -> void:
	assert_object(_item("moto")).is_not_null()
	for pessoa: String in ["vovo", "obra", "praia", "adolescente", "escritorio", "mendigo"]:
		for animacao: String in ["andando", "caida", "desembarcando", "susto", "voando"]:
			assert_object(_item("%s_%s" % [pessoa, animacao])).is_not_null()
	# A moca de moletom so tem a folha de andar.
	assert_object(_item("moletom_andando")).is_not_null()
	assert_object(_item("executivo_andando")).is_not_null()
	assert_int(_itens.size()).is_equal(77)


func test_todo_pedestre_que_o_jogo_carrega_esta_no_catalogo() -> void:
	assert_int(BarraDoJogo.NOMES_DAS_PESSOAS.size()).is_equal(PedestreSprite.ANDANDO.size())
	for textura in PedestreSprite.ANDANDO:
		var id := textura.resource_path.get_file().get_basename()
		assert_object(_item(id)).is_not_null()


func test_a_moto_vem_do_atlas_do_ator() -> void:
	var moto := _item("moto")
	assert_int(moto.colunas).is_equal(AtorSprite.QUADROS)
	assert_vector(Vector2(moto.celula)).is_equal(AtorSprite.CELULA)
	assert_vector(Vector2(moto.tamanho_imagem)).is_equal(
		AtorSprite.CELULA * Vector2(AtorSprite.QUADROS, 1.0)
	)
	assert_int(moto.caixas.size()).is_equal(AtorSprite.QUADROS)


func test_toda_ficha_bate_com_a_imagem() -> void:
	for item in _itens:
		assert_vector(Vector2(item.tamanho_imagem)).is_equal(
			Vector2(item.colunas * item.celula.x, item.linhas * item.celula.y)
		)


func test_so_os_avisos_conhecidos_aparecem() -> void:
	var com_aviso: Array[String] = []
	for item in _itens:
		if not item.avisos.is_empty():
			com_aviso.append(item.id)
	com_aviso.sort()
	var esperado := AVISOS_CONHECIDOS.duplicate()
	esperado.sort()
	assert_array(com_aviso).is_equal(esperado)


func test_o_pe_que_caminha_nao_escorrega_na_ficha() -> void:
	for item in _itens:
		if item.animacao != "andando":
			continue
		for linha in item.linhas:
			for coluna in item.colunas:
				var uso := item.caixa(coluna, linha)
				assert_int(absi(uso.end.y - item.pe.y)).is_less_equal(
					CatalogoSprites.TOLERANCIA_PE_PX
				)


func test_ficha_sem_imagem_vira_aviso_e_nao_some() -> void:
	# O caminho de um id que nao existe: o item nasce com aviso, nao com excecao.
	var item := CatalogoSprites._folha(
		"ninguem_andando", CatalogoSprites.PASTA_PEDESTRES, CatalogoSprites.Tipo.PEDESTRE
	)
	assert_bool(item.avisos.is_empty()).is_false()


func test_os_props_entram_como_uma_imagem_so_com_o_tamanho_da_ficha() -> void:
	for id: String in [
		"poste", "copa", "palmeira", "placa_curva", "placa_curva_dir", "placa_mao_dupla"
	]:
		var prop := _item(id)
		assert_object(prop).is_not_null()
		assert_int(prop.tipo).is_equal(CatalogoSprites.Tipo.PROP)
		assert_int(prop.quadros()).is_equal(1)
		assert_vector(Vector2(prop.tamanho_imagem)).is_equal(Vector2(prop.celula))
		assert_int(prop.rotulos_linhas.size()).is_equal(1)


## Carro e fachada ainda nao tem folha no repositorio: o catalogo tem de medi-los
## quando chegarem, entao a prova monta uma folha de teste com a mesma ficha que
## o `dev.py recortar` grava.
func _folha_de_teste(
	nome: String, ficha: Dictionary, tipo: int, desenho: Rect2i
) -> CatalogoSprites.Item:
	var pasta := "user://catalogo_teste"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(pasta))
	var colunas: int = ficha["colunas"]
	var linhas: int = (ficha["linhas"] as Array).size()
	var celula := Vector2i(int(ficha["celula"][0]), int(ficha["celula"][1]))
	var imagem := Image.create_empty(
		celula.x * colunas, celula.y * linhas, false, Image.FORMAT_RGBA8
	)
	for l in linhas:
		for c in colunas:
			var onde := Rect2i(
				desenho.position + Vector2i(c * celula.x, l * celula.y), desenho.size
			)
			imagem.fill_rect(onde, Color.WHITE)
	imagem.save_png("%s/%s.png" % [pasta, nome])
	var arquivo := FileAccess.open("%s/%s.json" % [pasta, nome], FileAccess.WRITE)
	arquivo.store_string(JSON.stringify(ficha))
	arquivo.close()
	return CatalogoSprites._folha(nome, pasta, tipo)


func _ficha_de_carro() -> Dictionary:
	return {
		"celula": [100, 60],
		"colunas": 2,
		"linhas": ["frente", "lado_porta"],
		"pe": [50, 56],
		"pixels_por_metro": 32.0,
		"altura_m": 1.5,
	}


func test_carro_com_o_pe_e_a_altura_da_ficha_nao_tem_aviso() -> void:
	# 1,5 m a 32 px/m = 48 px, de y=8 a y=56: o pe da ficha.
	var item := _folha_de_teste(
		"hatch_base", _ficha_de_carro(), CatalogoSprites.Tipo.CARRO, Rect2i(10, 8, 80, 48)
	)
	assert_int(item.tipo).is_equal(CatalogoSprites.Tipo.CARRO)
	assert_array(item.avisos).is_empty()


func test_carro_mais_alto_que_a_ficha_avisa() -> void:
	var item := _folha_de_teste(
		"sedan_base", _ficha_de_carro(), CatalogoSprites.Tipo.CARRO, Rect2i(10, 2, 80, 54)
	)
	assert_bool(" ".join(item.avisos).contains("a ficha pede")).is_true()


func test_carro_flutuando_acima_do_pe_da_ficha_avisa() -> void:
	var item := _folha_de_teste(
		"suv_base", _ficha_de_carro(), CatalogoSprites.Tipo.CARRO, Rect2i(10, 0, 80, 48)
	)
	assert_bool(" ".join(item.avisos).contains("a ficha apoia o pe")).is_true()


func test_angulo_desconhecido_na_ficha_avisa() -> void:
	var ficha := _ficha_de_carro()
	ficha["linhas"] = ["frente", "diagonal"]
	var item := _folha_de_teste(
		"van_base", ficha, CatalogoSprites.Tipo.FACHADA, Rect2i(10, 8, 80, 48)
	)
	assert_bool(" ".join(item.avisos).contains("angulo desconhecido")).is_true()


func test_a_cg_por_folha_tem_a_grade_da_tabela_da_migracao() -> void:
	# `MIGRACAO_2D.md`: tres angulos (costas, 3/4 costas, lado); 5 quadros de
	# inclinacao em pilotando, 4 em parado, 6 de soco (3 por lado), 4 de golpe
	# recebido (2 por lado) e 4 de tombo (so de costas); a moto caida e uma
	# coluna de cinco angulos.
	var tres := ["costas", "tres_quartos_costas", "lado"]
	var quatro := ["lado", "tres_quartos_costas", "costas", "tres_quartos_frente"]
	var cinco := ["frente", "tres_quartos_frente", "lado", "tres_quartos_costas", "costas"]
	for esperado: Array in [
		["cg_pilotando", 5, tres],
		["cg_parado", 4, tres],
		["cg_combate", 6, tres],
		["cg_golpe", 4, tres],
		["cg_tombo", 4, ["costas"]],
		["cg_caida", 1, cinco],
		["xre_pilotando", 5, tres],
		["xre_parado", 4, tres],
		["xre_combate", 6, tres],
		["xre_golpe", 4, tres],
		["xre_tombo", 4, ["costas"]],
		["xre_caida", 1, cinco],
		["pcx_pilotando", 5, tres],
		["pcx_parado", 4, tres],
		["pcx_combate", 6, tres],
		["pcx_golpe", 4, tres],
		["pcx_tombo", 4, ["costas"]],
		["pcx_caida", 1, cinco],
		["piloto_voando", 8, quatro],
		["piloto_caido", 3, quatro],
	]:
		var moto := _item(esperado[0])
		assert_object(moto).is_not_null()
		assert_int(moto.tipo).is_equal(CatalogoSprites.Tipo.MOTO_FOLHA)
		assert_int(moto.colunas).is_equal(esperado[1])
		assert_array(Array(moto.rotulos_linhas)).is_equal(esperado[2])
		assert_float(moto.pixels_por_metro).is_equal(100.0)


func test_o_hatch_tem_a_base_em_cinco_angulos_e_a_porta_em_tres() -> void:
	var cinco := ["frente", "tres_quartos_frente", "lado", "tres_quartos_costas", "costas"]
	var base := _item("hatch_base")
	assert_object(base).is_not_null()
	assert_int(base.tipo).is_equal(CatalogoSprites.Tipo.CARRO)
	assert_int(base.colunas).is_equal(1)
	assert_array(Array(base.rotulos_linhas)).is_equal(cinco)
	var porta := _item("hatch_porta_1")
	assert_object(porta).is_not_null()
	assert_int(porta.colunas).is_equal(5)
	assert_array(Array(porta.rotulos_linhas)).is_equal(
		["lado", "tres_quartos_frente", "tres_quartos_costas"]
	)


func test_o_seda_tem_a_base_em_cinco_angulos_com_e_sem_passageiro() -> void:
	var base := _item("seda_base")
	assert_object(base).is_not_null()
	assert_int(base.tipo).is_equal(CatalogoSprites.Tipo.CARRO)
	assert_int(base.colunas).is_equal(2)
	assert_array(Array(base.rotulos_linhas)).is_equal(
		["frente", "tres_quartos_frente", "lado", "tres_quartos_costas", "costas"]
	)


func test_o_seda_tem_duas_portas_em_tres_angulos() -> void:
	for nome: String in ["seda_porta_1", "seda_porta_2"]:
		var porta := _item(nome)
		assert_object(porta).is_not_null()
		assert_int(porta.tipo).is_equal(CatalogoSprites.Tipo.CARRO)
		assert_int(porta.colunas).is_equal(5)
		assert_array(Array(porta.rotulos_linhas)).is_equal(
			["lado", "tres_quartos_frente", "tres_quartos_costas"]
		)


func test_o_suv_tem_a_base_em_cinco_angulos_com_e_sem_passageiro() -> void:
	var base := _item("suv_base")
	assert_object(base).is_not_null()
	assert_int(base.tipo).is_equal(CatalogoSprites.Tipo.CARRO)
	assert_int(base.colunas).is_equal(2)
	assert_array(Array(base.rotulos_linhas)).is_equal(
		["frente", "tres_quartos_frente", "lado", "tres_quartos_costas", "costas"]
	)


func test_o_suv_tem_duas_portas_em_tres_angulos() -> void:
	for nome: String in ["suv_porta_1", "suv_porta_2"]:
		var porta := _item(nome)
		assert_object(porta).is_not_null()
		assert_int(porta.tipo).is_equal(CatalogoSprites.Tipo.CARRO)
		assert_int(porta.colunas).is_equal(5)
		assert_array(Array(porta.rotulos_linhas)).is_equal(
			["lado", "tres_quartos_frente", "tres_quartos_costas"]
		)


func test_taxi_onibus_e_bau_tem_base_e_portas_na_grade_da_ficha() -> void:
	var cinco := ["frente", "tres_quartos_frente", "lado", "tres_quartos_costas", "costas"]
	var tres := ["lado", "tres_quartos_frente", "tres_quartos_costas"]
	# nome -> [colunas, linhas]
	var folhas := {
		"taxi_base": [2, cinco],
		"taxi_porta_1": [5, tres],
		"taxi_porta_2": [5, tres],
		"bau_base": [1, cinco],
		"bau_porta_1": [5, tres],
	}
	for nome: String in folhas:
		var item := _item(nome)
		assert_object(item).is_not_null()
		assert_int(item.tipo).is_equal(CatalogoSprites.Tipo.CARRO)
		assert_int(item.colunas).is_equal(folhas[nome][0])
		assert_array(Array(item.rotulos_linhas)).is_equal(folhas[nome][1])
	# O ônibus tem dois ângulos a mais, do lado da porta, e não espelha.
	var base := _item("onibus_base")
	assert_object(base).is_not_null()
	assert_int(base.colunas).is_equal(2)
	assert_int(base.rotulos_linhas.size()).is_equal(7)
	var porta := _item("onibus_porta")
	assert_object(porta).is_not_null()
	assert_int(porta.colunas).is_equal(4)
	assert_array(Array(porta.rotulos_linhas)).is_equal(
		["lado_porta", "tres_quartos_frente_porta", "tres_quartos_costas_porta"]
	)
