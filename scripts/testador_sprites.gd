class_name TestadorSprites
extends Control
## O testador de sprites: todas as folhas do projeto numa lista, e para cada
## uma a folha em 2D (`TelaSprite`) ou o sprite dentro do jogo (`CenaSprite`).
## Abre com `python3 tools/dev.py sprites-ver`.
##
## A UI e montada aqui, no codigo, como o painel do F3: um `.tscn` cheio de nos
## de controle e um diff que ninguem le.
##
## Argumentos (depois de `--`): `--sprite=<id>` abre naquela folha, `--cena`
## abre no modo 3D, `--captura=<arquivo.png>` salva a tela e sai (para conferir
## sem olhar).

enum Modo { FOLHA, CENA }

const LARGURA_LISTA: float = 330.0
const FPS_PADRAO: float = 8.0
## Quantas vezes o mundo do jogo e menor que a tela: 640x360 em 1920x1080.
const ENCOLHE_DO_JOGO: int = 3
const GIRO_SOZINHO: float = 40.0

var _itens: Array[CatalogoSprites.Item] = []
var _visiveis: Array[CatalogoSprites.Item] = []
var _item: CatalogoSprites.Item
var _modo: int = Modo.FOLHA
var _tocando: bool = false
var _fps: float = FPS_PADRAO
var _acumulado: float = 0.0
var _gira_sozinho: bool = false
var _atualizando: bool = false
var _curva: int = AtorSprite.RETO

var _filtro: LineEdit
var _so_avisos: CheckBox
var _lista: ItemList
var _resumo: Label
var _tela: TelaSprite
var _contentor_cena: SubViewportContainer
var _cena: CenaSprite
var _barra_folha: Control
var _barra_cena: Control
var _grupo_moto: Control
var _grupo_voo: Control
var _grupo_queda: Control
var _info: RichTextLabel
var _vista: OptionButton
var _linha: OptionButton
var _quadro: HSlider
var _quadro_rotulo: Label
var _tocar: CheckButton
var _zoom: SpinBox
var _espelhar: CheckBox
var _inclina_2d: HSlider
var _inclina_rotulo: Label
var _modo_botao: OptionButton


func _ready() -> void:
	_itens = CatalogoSprites.varrer()
	_monta()
	_preenche_lista()
	var args := _argumentos()
	if args.has("cena"):
		_muda_modo(Modo.CENA)
	var alvo := String(args.get("sprite", ""))
	var inicial := 0
	for i in _visiveis.size():
		if _visiveis[i].id == alvo:
			inicial = i
	_lista.select(inicial)
	_escolhe(_visiveis[inicial])
	if args.has("captura"):
		_captura_e_sai.call_deferred(String(args["captura"]))


func _process(delta: float) -> void:
	if _modo == Modo.FOLHA and _tocando and _item != null and _item.colunas > 1:
		_acumulado += delta
		var passo := 1.0 / _fps
		while _acumulado >= passo:
			_acumulado -= passo
			_vai_para((_tela.coluna + 1) % _item.colunas)
	if _modo == Modo.CENA and _gira_sozinho:
		_cena.yaw_graus = fposmod(_cena.yaw_graus + GIRO_SOZINHO * delta, 360.0)


func _unhandled_key_input(evento: InputEvent) -> void:
	var tecla := evento as InputEventKey
	if tecla == null or not tecla.pressed or tecla.echo:
		return
	match tecla.keycode:
		KEY_SPACE:
			_tocar.button_pressed = not _tocar.button_pressed
		KEY_RIGHT:
			_passo_quadro(1)
		KEY_LEFT:
			_passo_quadro(-1)
		KEY_TAB:
			_muda_modo(Modo.CENA if _modo == Modo.FOLHA else Modo.FOLHA)
		KEY_ESCAPE:
			get_tree().quit()
		_:
			return
	get_viewport().set_input_as_handled()


# --- montagem --------------------------------------------------------------


func _monta() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var fundo := ColorRect.new()
	fundo.color = Color(0.13, 0.14, 0.16)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	var raiz := HBoxContainer.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.add_theme_constant_override("separation", 8)
	add_child(raiz)
	raiz.add_child(_monta_lista())
	raiz.add_child(_monta_direita())


func _monta_lista() -> Control:
	var caixa := VBoxContainer.new()
	caixa.custom_minimum_size.x = LARGURA_LISTA
	_filtro = LineEdit.new()
	_filtro.placeholder_text = "filtrar (vovo, andando, moto...)"
	_filtro.clear_button_enabled = true
	_filtro.text_changed.connect(func(_t: String) -> void: _preenche_lista())
	caixa.add_child(_filtro)
	_so_avisos = CheckBox.new()
	_so_avisos.text = "so com avisos"
	_so_avisos.toggled.connect(func(_b: bool) -> void: _preenche_lista())
	caixa.add_child(_so_avisos)
	_lista = ItemList.new()
	_lista.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lista.item_selected.connect(
		func(i: int) -> void:
			if i >= 0 and i < _visiveis.size():
				_escolhe(_visiveis[i])
	)
	caixa.add_child(_lista)
	_resumo = Label.new()
	caixa.add_child(_resumo)
	var ajuda := Label.new()
	ajuda.text = "espaco: tocar   setas: quadro   tab: 2D/3D   esc: sair"
	ajuda.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ajuda.modulate = Color(1, 1, 1, 0.6)
	caixa.add_child(ajuda)
	return caixa


func _monta_direita() -> Control:
	var caixa := VBoxContainer.new()
	caixa.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var topo := HBoxContainer.new()
	var rotulo := Label.new()
	rotulo.text = "Modo"
	topo.add_child(rotulo)
	_modo_botao = _opcoes(["Folha 2D", "Cena 3D"], func(i: int) -> void: _muda_modo(i))
	topo.add_child(_modo_botao)
	caixa.add_child(topo)

	var palco := Control.new()
	palco.size_flags_vertical = Control.SIZE_EXPAND_FILL
	palco.clip_contents = true
	_tela = TelaSprite.new()
	_tela.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tela.celula_escolhida.connect(
		func(c: int, l: int) -> void:
			_vai_para(c)
			_escolhe_linha(l)
	)
	_tela.zoom_alterado.connect(func(v: int) -> void: _zoom.set_value_no_signal(v))
	palco.add_child(_tela)
	_contentor_cena = SubViewportContainer.new()
	_contentor_cena.set_anchors_preset(Control.PRESET_FULL_RECT)
	_contentor_cena.stretch = true
	_contentor_cena.visible = false
	var porta := SubViewport.new()
	porta.own_world_3d = true
	porta.msaa_3d = Viewport.MSAA_DISABLED
	_cena = CenaSprite.new()
	porta.add_child(_cena)
	_contentor_cena.add_child(porta)
	palco.add_child(_contentor_cena)
	caixa.add_child(palco)

	_barra_folha = _monta_barra_folha()
	caixa.add_child(_barra_folha)
	_barra_cena = _monta_barra_cena()
	_barra_cena.visible = false
	caixa.add_child(_barra_cena)

	_info = RichTextLabel.new()
	_info.bbcode_enabled = true
	_info.fit_content = true
	_info.scroll_active = false
	caixa.add_child(_info)
	return caixa


func _monta_barra_folha() -> Control:
	var fluxo := HFlowContainer.new()
	_vista = _opcoes(
		["Quadro", "Folha toda"],
		func(i: int) -> void:
			_tela.vista = i
			_tocar.disabled = i == TelaSprite.Vista.FOLHA
	)
	fluxo.add_child(_rotulo("Vista"))
	fluxo.add_child(_vista)
	_linha = _opcoes([], func(i: int) -> void: _escolhe_linha(i))
	fluxo.add_child(_rotulo("Linha"))
	fluxo.add_child(_linha)
	_espelhar = _check("espelhar", false, func(b: bool) -> void: _tela.espelhar = b)
	fluxo.add_child(_espelhar)
	_tocar = CheckButton.new()
	_tocar.text = "tocar"
	_tocar.toggled.connect(func(b: bool) -> void: _tocando = b)
	fluxo.add_child(_tocar)
	var fps := SpinBox.new()
	fps.min_value = 1
	fps.max_value = 60
	fps.value = _fps
	fps.suffix = "fps"
	fps.value_changed.connect(func(v: float) -> void: _fps = v)
	fluxo.add_child(fps)
	var anterior := Button.new()
	anterior.text = "<"
	anterior.pressed.connect(func() -> void: _passo_quadro(-1))
	fluxo.add_child(anterior)
	_quadro = HSlider.new()
	_quadro.custom_minimum_size.x = 220
	_quadro.step = 1
	_quadro.value_changed.connect(
		func(v: float) -> void:
			if not _atualizando:
				_vai_para(int(v))
	)
	fluxo.add_child(_quadro)
	var proximo := Button.new()
	proximo.text = ">"
	proximo.pressed.connect(func() -> void: _passo_quadro(1))
	fluxo.add_child(proximo)
	_quadro_rotulo = Label.new()
	_quadro_rotulo.custom_minimum_size.x = 210
	fluxo.add_child(_quadro_rotulo)
	fluxo.add_child(_rotulo("Zoom (0 = auto)"))
	_zoom = SpinBox.new()
	_zoom.min_value = 0
	_zoom.max_value = TelaSprite.ZOOM_MAX
	_zoom.value_changed.connect(func(v: float) -> void: _tela.zoom = int(v))
	fluxo.add_child(_zoom)
	fluxo.add_child(_rotulo("Fundo"))
	fluxo.add_child(
		_opcoes(
			["Cinza", "Asfalto", "Calcada", "Branco", "Preto"],
			func(i: int) -> void: _tela.fundo = i
		)
	)
	fluxo.add_child(_check("noite", false, func(b: bool) -> void: _tela.noite = b))
	fluxo.add_child(_check("grade", true, func(b: bool) -> void: _tela.grade = b))
	fluxo.add_child(_check("chao e pe", true, func(b: bool) -> void: _tela.chao = b))
	fluxo.add_child(_check("regua", true, func(b: bool) -> void: _tela.regua = b))
	fluxo.add_child(_check("caixa medida", false, func(b: bool) -> void: _tela.caixa = b))
	_grupo_moto = HBoxContainer.new()
	_grupo_moto.add_child(_rotulo("Inclinacao"))
	_inclina_2d = _slider(-35.0, 35.0, 0.5, 0.0, func(v: float) -> void: _inclina_na_folha(v))
	_grupo_moto.add_child(_inclina_2d)
	_inclina_rotulo = Label.new()
	_grupo_moto.add_child(_inclina_rotulo)
	var caixa := VBoxContainer.new()
	caixa.add_child(fluxo)
	caixa.add_child(_grupo_moto)
	_grupo_moto.visible = false
	return caixa


func _monta_barra_cena() -> Control:
	var fluxo := HFlowContainer.new()
	fluxo.add_child(_rotulo("Camera: angulo"))
	var angulo := _slider(0.0, 359.0, 1.0, 0.0, func(v: float) -> void: _cena.yaw_graus = v)
	angulo.custom_minimum_size.x = 200
	fluxo.add_child(angulo)
	fluxo.add_child(_check("girar sozinha", false, func(b: bool) -> void: _gira_sozinho = b))
	fluxo.add_child(_rotulo("distancia"))
	fluxo.add_child(_slider(1.5, 15.0, 0.1, 4.0, func(v: float) -> void: _cena.distancia = v))
	fluxo.add_child(_rotulo("altura"))
	fluxo.add_child(
		_slider(-5.0, 70.0, 1.0, 12.0, func(v: float) -> void: _cena.elevacao_graus = v)
	)
	fluxo.add_child(_rotulo("velocidade"))
	fluxo.add_child(
		_slider(0.1, 3.0, 0.05, 1.0, func(v: float) -> void: _cena.velocidade_animacao = v)
	)
	fluxo.add_child(_check("pausar", false, func(b: bool) -> void: _cena.pausado = b))
	fluxo.add_child(_check("elenco", false, func(b: bool) -> void: _cena.elenco = b))
	fluxo.add_child(_check("regua de 2 m", true, func(b: bool) -> void: _cena.regua = b))
	fluxo.add_child(_rotulo("noite"))
	fluxo.add_child(_slider(0.0, 1.0, 0.05, 0.0, func(v: float) -> void: _cena.noite = v))
	fluxo.add_child(
		_check(
			"pixelado (resolucao do jogo)",
			false,
			func(b: bool) -> void: _contentor_cena.stretch_shrink = ENCOLHE_DO_JOGO if b else 1
		)
	)
	var moto := HBoxContainer.new()
	moto.add_child(_rotulo("Moto"))
	moto.add_child(
		_opcoes(["CG 160", "XRE 300", "PCX 160"], func(i: int) -> void: _cena.modelo_moto = i)
	)
	moto.add_child(_rotulo("inclinacao"))
	moto.add_child(
		_slider(-35.0, 35.0, 0.5, 0.0, func(v: float) -> void: _cena.inclinacao_graus = v)
	)
	var esquerdo := Button.new()
	esquerdo.text = "soco E"
	esquerdo.pressed.connect(func() -> void: _cena.soco(-1))
	moto.add_child(esquerdo)
	var direito := Button.new()
	direito.text = "soco D"
	direito.pressed.connect(func() -> void: _cena.soco(1))
	moto.add_child(direito)
	moto.name = "Moto"
	_grupo_voo = HBoxContainer.new()
	_grupo_voo.add_child(_rotulo("Giro no ar"))
	_grupo_voo.add_child(_slider(-6.28, 6.28, 0.05, 0.0, func(v: float) -> void: _cena.giro = v))
	_grupo_queda = HBoxContainer.new()
	_grupo_queda.add_child(
		_check("ainda desliza (quadro 2)", true, func(b: bool) -> void: _cena.movendo = b)
	)
	var caixa := VBoxContainer.new()
	caixa.add_child(fluxo)
	caixa.add_child(moto)
	caixa.add_child(_grupo_voo)
	caixa.add_child(_grupo_queda)
	caixa.set_meta(&"moto", moto)
	return caixa


# --- pecas de UI -----------------------------------------------------------


func _rotulo(texto: String) -> Label:
	var rotulo := Label.new()
	rotulo.text = texto
	rotulo.modulate = Color(1, 1, 1, 0.75)
	return rotulo


func _check(texto: String, ligado: bool, ao_mudar: Callable) -> CheckBox:
	var caixa := CheckBox.new()
	caixa.text = texto
	caixa.button_pressed = ligado
	caixa.toggled.connect(ao_mudar)
	return caixa


func _slider(
	minimo: float, maximo: float, passo: float, valor: float, ao_mudar: Callable
) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = minimo
	slider.max_value = maximo
	slider.step = passo
	slider.value = valor
	slider.custom_minimum_size.x = 140
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(ao_mudar)
	return slider


func _opcoes(nomes: Array, ao_escolher: Callable) -> OptionButton:
	var botao := OptionButton.new()
	for nome: String in nomes:
		botao.add_item(nome)
	botao.item_selected.connect(ao_escolher)
	return botao


# --- comportamento ---------------------------------------------------------


func _preenche_lista() -> void:
	var texto := _filtro.text.strip_edges().to_lower()
	var anterior := _item
	_visiveis.clear()
	_lista.clear()
	var avisos := 0
	for item in _itens:
		avisos += 1 if not item.avisos.is_empty() else 0
		if _so_avisos.button_pressed and item.avisos.is_empty():
			continue
		if (
			texto != ""
			and not (item.id.replace("_", " ") + " " + item.nome()).to_lower().contains(texto)
		):
			continue
		_visiveis.append(item)
		var marca := "! " if not item.avisos.is_empty() else "  "
		_lista.add_item(marca + item.nome())
		if not item.avisos.is_empty():
			_lista.set_item_custom_fg_color(_lista.item_count - 1, Color(1.0, 0.8, 0.3))
	_resumo.text = "%d de %d folhas   (%d com aviso)" % [_visiveis.size(), _itens.size(), avisos]
	var ainda := _visiveis.find(anterior)
	if ainda >= 0:
		_lista.select(ainda)


func _escolhe(item: CatalogoSprites.Item) -> void:
	_item = item
	_atualizando = true
	_tela.item = item
	_tela.coluna = 0
	_tela.linha = 0
	_tela.espelhar = false
	_espelhar.button_pressed = false
	_espelhar.visible = item.tipo == CatalogoSprites.Tipo.PEDESTRE
	_linha.clear()
	for rotulo in item.rotulos_linhas:
		_linha.add_item(rotulo)
	_linha.visible = item.linhas > 1
	_quadro.min_value = 0
	_quadro.max_value = maxi(item.colunas - 1, 0)
	_quadro.value = 0
	_curva = AtorSprite.RETO
	_atualizando = false
	if item.tipo == CatalogoSprites.Tipo.MOTO:
		_inclina_na_folha(_inclina_2d.value)
	else:
		_vai_para(0)
	_grupo_moto.visible = item.tipo == CatalogoSprites.Tipo.MOTO
	_muda_grupos_da_cena()
	_cena.mostrar(item)
	_mostra_info()


func _muda_grupos_da_cena() -> void:
	var moto := _item != null and _item.tipo == CatalogoSprites.Tipo.MOTO
	var moto_caixa := _barra_cena.get_meta(&"moto") as Control
	moto_caixa.visible = moto
	_grupo_voo.visible = _item != null and _item.animacao == "voando"
	_grupo_queda.visible = _item != null and _item.animacao == "caida"


func _mostra_info() -> void:
	var item := _item
	var linhas: PackedStringArray = []
	var medidas := (
		"imagem %dx%d   %d colunas x %d linhas   celula %dx%d   pe (%d, %d)"
		% [
			item.tamanho_imagem.x,
			item.tamanho_imagem.y,
			item.colunas,
			item.linhas,
			item.celula.x,
			item.celula.y,
			item.pe.x,
			item.pe.y
		]
	)
	if item.altura_m > 0.0:
		medidas += "   %.2f m a %d px/m" % [item.altura_m, int(item.pixels_por_metro)]
	var cabecalho := "[b]%s[/b]  [color=gray]%s[/color]"
	linhas.append(cabecalho % [item.nome(), item.caminho.trim_prefix("res://")])
	linhas.append(medidas)
	if item.avisos.is_empty():
		linhas.append("[color=lightgreen]sem avisos[/color]")
	for aviso in item.avisos:
		linhas.append("[color=orange]! %s[/color]" % aviso)
	_info.text = "\n".join(linhas)


func _muda_modo(modo: int) -> void:
	_modo = modo
	_modo_botao.select(modo)
	_tela.visible = modo == Modo.FOLHA
	_contentor_cena.visible = modo == Modo.CENA
	_barra_folha.visible = modo == Modo.FOLHA
	_barra_cena.visible = modo == Modo.CENA


func _passo_quadro(delta: int) -> void:
	if _item == null:
		return
	_vai_para(posmod(_tela.coluna + delta, _item.colunas))


func _vai_para(coluna: int) -> void:
	if _item == null:
		return
	_tela.coluna = clampi(coluna, 0, _item.colunas - 1)
	_atualizando = true
	_quadro.set_value_no_signal(_tela.coluna)
	_atualizando = false
	_quadro_rotulo.text = _nome_do_quadro(_item, _tela.coluna)


func _escolhe_linha(linha: int) -> void:
	_tela.linha = clampi(linha, 0, maxi(_item.linhas - 1, 0))
	_linha.select(_tela.linha)


## A moto na folha: o quadro que o `AtorSprite` escolheria para essa
## inclinacao, com a mesma folga de troca do jogo.
func _inclina_na_folha(graus: float) -> void:
	if _item == null or _item.tipo != CatalogoSprites.Tipo.MOTO:
		return
	_curva = AtorSprite.quadro_da_curva(graus, _curva)
	_vai_para(_curva)
	_inclina_rotulo.text = (
		"%.1f graus -> quadro %d (desenha %.1f)" % [graus, _curva, AtorSprite.INCLINACOES[_curva]]
	)


static func _nome_do_quadro(item: CatalogoSprites.Item, coluna: int) -> String:
	if item.tipo == CatalogoSprites.Tipo.MOTO:
		if coluna < AtorSprite.INCLINACOES.size():
			return "%d: curva %+.1f graus" % [coluna, AtorSprite.INCLINACOES[coluna]]
		var fases := ["arma", "estica", "recolhe"]
		for lado: int in AtorSprite.SOCO:
			var onde := (AtorSprite.SOCO[lado] as Array).find(coluna)
			if onde >= 0:
				return "%d: soco %s, %s" % [coluna, "E" if lado < 0 else "D", fases[onde]]
	return "quadro %d de %d" % [coluna + 1, item.colunas]


static func _argumentos() -> Dictionary:
	var achados := {}
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--"):
			continue
		var partes := arg.trim_prefix("--").split("=", true, 1)
		achados[partes[0]] = partes[1] if partes.size() > 1 else true
	return achados


func _captura_e_sai(caminho: String) -> void:
	# Alguns quadros para o 3D assentar: o primeiro sai antes do shader compilar.
	for i in 12:
		await get_tree().process_frame
	var imagem := get_viewport().get_texture().get_image()
	var erro := imagem.save_png(caminho)
	print("captura: ", caminho, " (", error_string(erro), ")")
	get_tree().quit(0 if erro == OK else 1)
