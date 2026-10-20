class_name TestadorSprites
extends Control
## O testador de sprites: todas as folhas do projeto numa lista, e para cada
## uma a folha em 2D (`TelaSprite`) ou o sprite dentro do jogo (`CenaSprite`).
## Abre com `python3 tools/dev.py sprites-ver`.
##
## A UI e montada aqui, no codigo, como o painel do F3: um `.tscn` cheio de nos
## de controle e um diff que ninguem le.
##
## A analise (`AnaliseSprites`: movimento, borda, referencia) roda em threads
## de fundo desde a abertura, e a lista ganha a marca de aviso folha a folha
## conforme elas terminam.
##
## Argumentos (depois de `--`): `--sprite=<id>` abre naquela folha, `--cena`
## abre no modo 3D (`--gira` ja com a camera girando), `--jogar` abre no playground, `--vista=<quadro|folha|referencia|base|duas>`,
## `--quadro=<n>` e `--linha=<n>` (de 1), `--evento=<atropelar|susto|carro|carro_rua|
## largada>` (com `--jogar`), `--espera=<s>` e `--captura=<arquivo.png>` salva a
## tela e sai (para conferir sem olhar).

enum Modo { FOLHA, CENA, JOGAR }

## Largura da galeria: as cinco animacoes de uma pessoa numa fileira so.
const LARGURA_LISTA: float = 440.0
const FPS_PADRAO: float = 8.0
## Quantas vezes o mundo do jogo e menor que a tela: 640x360 em 1920x1080.
const ENCOLHE_DO_JOGO: int = 3
const GIRO_SOZINHO: float = 40.0
## As poses por segundo que o jogo oferece (`Main.CADENCIAS`); 0 e liso.
const CADENCIAS: Array[int] = [0, 24, 15, 12, 8]
const VISTAS: Array[String] = ["quadro", "folha", "referencia", "base", "duas"]
const ALTURA_DA_INFO: float = 150.0
const AUMENTO_DO_EXPORTE: int = 4

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
## Item -> id da tarefa de analise ainda nao recolhida.
var _tarefas: Dictionary = {}
var _total_de_tarefas: int = 0
var _recorrentes := PackedStringArray()
## Para a foto da moto, que chega depois de alguns quadros: so vale a ultima.
var _pedido_da_moto: int = 0
var _status_texto: String = ""

var _filtro: LineEdit
var _so_avisos: CheckBox
var _galeria := GaleriaSprites.new()
var _resumo: Label
var _tela: TelaSprite
var _contentor_cena: SubViewportContainer
var _cena: CenaSprite
var _contentor_jogo: SubViewportContainer
var _jogo: JogoSprite
var _barra_jogo := BarraDoJogo.new()
var _moto_3d: ReferenciaMoto
var _barra_folha: Control
var _barra_cena: Control
var _grupo_moto: Control
var _grupo_voo: Control
var _grupo_queda: Control
var _grupo_outra: Control
var _info: RichTextLabel
var _vista: Control
var _linhas: HBoxContainer
var _quadro: HSlider
var _quadro_rotulo: Label
var _tocar: CheckButton
var _zoom: SpinBox
var _espelhar: CheckBox
var _inclina_2d: HSlider
var _inclina_rotulo: Label
var _modo_botao: Control
var _outra_rotulo: Label
var _status: Label


func _ready() -> void:
	_itens = CatalogoSprites.varrer()
	_monta()
	_preenche_lista()
	var args := _argumentos()
	if args.has("cena"):
		_muda_modo(Modo.CENA)
	_gira_sozinho = args.has("gira")
	if args.has("jogar"):
		_muda_modo(Modo.JOGAR)
	var alvo := String(args.get("sprite", ""))
	var inicial := 0
	for i in _visiveis.size():
		if _visiveis[i].id == alvo:
			inicial = i
	_escolhe(_visiveis[inicial])
	if args.has("yaw"):
		_cena.yaw_graus = float(args["yaw"])
	if args.has("pista"):
		_cena.velocidade_da_pista = float(args["pista"])
	if args.has("vista"):
		var vista := VISTAS.find(String(args["vista"]))
		if vista >= 0:
			_muda_vista(vista)
	if args.has("quadro"):
		_vai_para(int(args["quadro"]) - 1)
	if args.has("linha"):
		_escolhe_linha(int(args["linha"]) - 1)
	_comeca_a_analisar()
	if args.has("evento") and _jogo != null:
		_dispara_o_evento(String(args["evento"]))
	if args.has("captura"):
		_captura_e_sai.call_deferred(String(args["captura"]), float(args.get("espera", 0.0)))


func _exit_tree() -> void:
	# Tarefa que ainda corre nao pode sobreviver ao no que a analisa.
	for item: CatalogoSprites.Item in _tarefas:
		WorkerThreadPool.wait_for_task_completion(_tarefas[item])


func _process(delta: float) -> void:
	_recolhe_analises()
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
	# Jogando, as setas e a barra de espaco sao da moto e da pessoa.
	if _modo == Modo.JOGAR and tecla.keycode not in [KEY_TAB, KEY_ESCAPE]:
		return
	match tecla.keycode:
		KEY_SPACE:
			_tocar.button_pressed = not _tocar.button_pressed
		KEY_RIGHT:
			_passo_quadro(1)
		KEY_LEFT:
			_passo_quadro(-1)
		KEY_UP:
			_escolhe_linha(_tela.linha - 1)
		KEY_DOWN:
			_escolhe_linha(_tela.linha + 1)
		KEY_TAB:
			_muda_modo((_modo + 1) % Modo.size())
		KEY_ESCAPE:
			_encerra(0)
		_:
			return
	get_viewport().set_input_as_handled()


# --- analise em segundo plano ---------------------------------------------


func _comeca_a_analisar() -> void:
	for item in _itens:
		_tarefas[item] = WorkerThreadPool.add_task(
			AnaliseSprites.analisar.bind(item), false, "analise %s" % item.id
		)
	_total_de_tarefas = _tarefas.size()


## Recolhe as analises que terminaram e atualiza a lista e a folha aberta.
func _recolhe_analises() -> void:
	if _tarefas.is_empty():
		return
	var prontas: Array = []
	for item: CatalogoSprites.Item in _tarefas:
		if WorkerThreadPool.is_task_completed(_tarefas[item]):
			prontas.append(item)
	if prontas.is_empty():
		return
	for item: CatalogoSprites.Item in prontas:
		WorkerThreadPool.wait_for_task_completion(_tarefas[item])
		_tarefas.erase(item)
	if _tarefas.is_empty():
		_recorrentes = CatalogoSprites.recorrentes(_itens)
	_preenche_lista()
	if _tarefas.is_empty() or prontas.has(_item):
		# A analise da folha aberta chegou: o que ela mostra muda.
		_tela.queue_redraw()
		_mostra_info()


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
	_moto_3d = ReferenciaMoto.new()
	add_child(_moto_3d)


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
	_galeria.montar(_itens)
	_galeria.escolhida.connect(_escolhe)
	_galeria.comparada.connect(
		func(item: CatalogoSprites.Item) -> void:
			_compara_com(item)
			_muda_vista(TelaSprite.Vista.DUAS)
	)
	caixa.add_child(_galeria)
	_resumo = Label.new()
	caixa.add_child(_resumo)
	var ajuda := Label.new()
	ajuda.text = (
		"espaco: tocar   setas: quadro e linha   tab: 2D/3D\n"
		+ "botao direito numa miniatura: comparar   esc: sair"
	)
	ajuda.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ajuda.modulate = Color(1, 1, 1, 0.6)
	caixa.add_child(ajuda)
	return caixa


func _monta_direita() -> Control:
	var caixa := VBoxContainer.new()
	caixa.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var topo := HBoxContainer.new()
	_modo_botao = _segmentado(
		["Folha 2D", "Cena 3D", "Jogar"], 0, func(i: int) -> void: _muda_modo(i)
	)
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
	_contentor_jogo = SubViewportContainer.new()
	_contentor_jogo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_contentor_jogo.stretch = true
	_contentor_jogo.visible = false
	var porta_do_jogo := SubViewport.new()
	porta_do_jogo.own_world_3d = true
	porta_do_jogo.msaa_3d = Viewport.MSAA_DISABLED
	# O jogo so nasce quando alguem vai jogar: a pista, o carro e a chegada custam
	# a montar, e quem so olha folhas nao precisa deles.
	_contentor_jogo.add_child(porta_do_jogo)
	palco.add_child(_contentor_jogo)
	caixa.add_child(palco)

	_barra_folha = _monta_barra_folha()
	caixa.add_child(_barra_folha)
	_barra_cena = _monta_barra_cena()
	_barra_cena.visible = false
	caixa.add_child(_barra_cena)
	_barra_jogo.visible = false
	caixa.add_child(_barra_jogo)

	_info = RichTextLabel.new()
	_info.bbcode_enabled = true
	_info.scroll_active = true
	_info.custom_minimum_size.y = ALTURA_DA_INFO
	caixa.add_child(_info)
	return caixa


func _monta_barra_folha() -> Control:
	var fluxo := HFlowContainer.new()
	_vista = _segmentado(
		["Quadro", "Folha", "Referencia", "Antes/depois", "Duas folhas"],
		0,
		func(i: int) -> void: _muda_vista(i)
	)
	fluxo.add_child(_vista)
	# Um botao por angulo, com o primeiro quadro da linha no lugar do nome: o
	# angulo se escolhe olhando para ele.
	_linhas = HBoxContainer.new()
	fluxo.add_child(_linhas)
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
	fluxo.add_child(_rotulo("cadencia do jogo"))
	var ao_escolher_cadencia := func(i: int) -> void:
		_fps = FPS_PADRAO if CADENCIAS[i] == 0 else float(CADENCIAS[i])
		fps.set_value_no_signal(_fps)
	fluxo.add_child(_segmentado(["livre", "24", "15", "12", "8"], 0, ao_escolher_cadencia))
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
	fluxo.add_child(_amostras_de_fundo())
	fluxo.add_child(_check("noite", false, func(b: bool) -> void: _tela.noite = b))
	fluxo.add_child(_check("grade", true, func(b: bool) -> void: _tela.grade = b))
	fluxo.add_child(_check("chao e pe", true, func(b: bool) -> void: _tela.chao = b))
	fluxo.add_child(_check("regua", true, func(b: bool) -> void: _tela.regua = b))
	fluxo.add_child(_check("caixa medida", false, func(b: bool) -> void: _tela.caixa = b))

	var base := HBoxContainer.new()
	base.add_child(_rotulo("Base"))
	var fixar := Button.new()
	fixar.text = "fixar a folha de agora"
	fixar.pressed.connect(_fixa_a_base)
	base.add_child(fixar)
	var limpar := Button.new()
	limpar.text = "limpar"
	limpar.pressed.connect(_limpa_a_base)
	base.add_child(limpar)
	base.add_child(_rotulo("   Exportar"))
	var quadro := Button.new()
	quadro.text = "quadro"
	quadro.pressed.connect(_exporta_o_quadro)
	base.add_child(quadro)
	var marcada := Button.new()
	marcada.text = "folha marcada"
	marcada.pressed.connect(_exporta_a_folha_marcada)
	base.add_child(marcada)
	var comparacao := Button.new()
	comparacao.text = "comparacao com a referencia"
	comparacao.pressed.connect(_exporta_a_comparacao)
	base.add_child(comparacao)
	_status = Label.new()
	_status.modulate = Color(0.6, 1.0, 0.6)
	base.add_child(_status)

	_grupo_outra = HBoxContainer.new()
	_outra_rotulo = Label.new()
	_grupo_outra.add_child(_outra_rotulo)
	_grupo_outra.visible = false

	_grupo_moto = HBoxContainer.new()
	_grupo_moto.add_child(_rotulo("Inclinacao"))
	_inclina_2d = _slider(-35.0, 35.0, 0.5, 0.0, func(v: float) -> void: _inclina_na_folha(v))
	_grupo_moto.add_child(_inclina_2d)
	_inclina_rotulo = Label.new()
	_grupo_moto.add_child(_inclina_rotulo)
	_grupo_moto.visible = false

	var caixa := VBoxContainer.new()
	caixa.add_child(fluxo)
	caixa.add_child(base)
	caixa.add_child(_grupo_outra)
	caixa.add_child(_grupo_moto)
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
	fluxo.add_child(_rotulo("lente"))
	fluxo.add_child(_slider(20.0, 90.0, 1.0, 40.0, func(v: float) -> void: _cena.fov = v))
	var do_jogo := Button.new()
	do_jogo.text = "camera do jogo"
	do_jogo.pressed.connect(func() -> void: _cena.camera_do_jogo())
	fluxo.add_child(do_jogo)
	fluxo.add_child(_rotulo("velocidade da animacao"))
	fluxo.add_child(
		_slider(0.1, 3.0, 0.05, 1.0, func(v: float) -> void: _cena.velocidade_animacao = v)
	)
	fluxo.add_child(_check("pausar", false, func(b: bool) -> void: _cena.pausado = b))
	fluxo.add_child(_check("elenco", false, func(b: bool) -> void: _cena.elenco = b))
	fluxo.add_child(_check("regua de 2 m", true, func(b: bool) -> void: _cena.regua = b))
	fluxo.add_child(_rotulo("pista (m/s)"))
	fluxo.add_child(
		_slider(0.0, 60.0, 1.0, 0.0, func(v: float) -> void: _cena.velocidade_da_pista = v)
	)
	fluxo.add_child(_rotulo("cadencia"))
	fluxo.add_child(
		_segmentado(
			["livre", "24", "15", "12", "8"],
			0,
			func(i: int) -> void: _cena.cadencia_hz = float(CADENCIAS[i])
		)
	)
	fluxo.add_child(_rotulo("hora (0 meio-dia, 1 noite)"))
	fluxo.add_child(_slider(0.0, 1.0, 0.01, 0.0, func(v: float) -> void: _cena.hora = v))
	fluxo.add_child(_check("paleta do jogo", false, func(b: bool) -> void: _cena.paleta = b))
	fluxo.add_child(
		_check(
			"resolucao do jogo (÷3)",
			false,
			func(b: bool) -> void: _contentor_cena.stretch_shrink = ENCOLHE_DO_JOGO if b else 1
		)
	)
	var moto := HBoxContainer.new()
	moto.add_child(_rotulo("Moto"))
	moto.add_child(
		_segmentado(
			["CG 160", "XRE 300", "PCX 160"], 0, func(i: int) -> void: _cena.modelo_moto = i
		)
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
	return PecasDeUi.rotulo(texto)


func _check(texto: String, ligado: bool, ao_mudar: Callable) -> CheckBox:
	return PecasDeUi.marcar(texto, ligado, ao_mudar)


func _slider(
	minimo: float, maximo: float, passo: float, valor: float, ao_mudar: Callable
) -> HSlider:
	return PecasDeUi.slider(minimo, maximo, passo, valor, ao_mudar)


func _segmentado(nomes: Array, marcado: int, ao_escolher: Callable) -> HBoxContainer:
	return PecasDeUi.segmentado(nomes, marcado, ao_escolher)


func _marca(grupo: Control, indice: int) -> void:
	PecasDeUi.marca_o_segmento(grupo, indice)


## O fundo da folha em amostras de cor, no lugar de uma lista de nomes.
func _amostras_de_fundo() -> HBoxContainer:
	var caixa := HBoxContainer.new()
	var grupo := ButtonGroup.new()
	var nomes := ["cinza", "asfalto", "calcada", "branco", "preto"]
	for i in nomes.size():
		var botao := Button.new()
		botao.toggle_mode = true
		botao.button_group = grupo
		botao.tooltip_text = nomes[i]
		botao.custom_minimum_size = Vector2(34, 30)
		botao.expand_icon = true
		botao.icon = _amostra(i)
		botao.set_pressed_no_signal(i == 0)
		botao.pressed.connect(func() -> void: _tela.fundo = i)
		caixa.add_child(botao)
	return caixa


func _amostra(fundo: int) -> Texture2D:
	if TelaSprite.TEXTURAS.has(fundo):
		var recorte := AtlasTexture.new()
		recorte.atlas = TelaSprite.TEXTURAS[fundo]
		recorte.region = Rect2(0, 0, 32, 32)
		return recorte
	var imagem := Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
	imagem.fill(TelaSprite.COR_FUNDO[fundo])
	return ImageTexture.create_from_image(imagem)


## Um botao por angulo da folha, com o primeiro quadro da linha como icone.
func _monta_as_linhas(item: CatalogoSprites.Item) -> void:
	for filho in _linhas.get_children():
		_linhas.remove_child(filho)
		filho.queue_free()
	_linhas.visible = item.linhas > 1
	if item.linhas <= 1:
		return
	var grupo := ButtonGroup.new()
	for l in item.linhas:
		var rotulo := item.rotulos_linhas[l] if l < item.rotulos_linhas.size() else str(l + 1)
		var curto := rotulo.replace("tres_quartos_", "3/4 ").replace("_", " ")
		var botao := GaleriaSprites.botao_com_icone(
			GaleriaSprites.recorte(item, 0, l), curto, Vector2(76, 86)
		)
		botao.button_group = grupo
		botao.tooltip_text = rotulo
		botao.set_pressed_no_signal(l == 0)
		botao.pressed.connect(_escolhe_linha.bind(l))
		_linhas.add_child(botao)


## A outra folha da vista "Duas folhas": a mesma animacao de outra pessoa, se
## houver, e senao a moto.
func _outra_padrao() -> CatalogoSprites.Item:
	for item in _itens:
		if item != _item and item.animacao == _item.animacao:
			return item
	return _itens[0]


func _compara_com(item: CatalogoSprites.Item) -> void:
	_tela.outro = item
	_outra_rotulo.text = (
		"Comparando com: %s   (botao direito em outra folha da lista troca)" % item.id
	)


# --- comportamento ---------------------------------------------------------


## Aplica o filtro e as marcas de aviso as miniaturas. Roda a cada analise que
## termina, entao so mexe no que ja existe: nada e refeito.
func _preenche_lista() -> void:
	var texto := _filtro.text.strip_edges().to_lower()
	_visiveis.clear()
	var avisos := 0
	for item in _itens:
		avisos += 1 if item.tem_aviso() else 0
		var nome := item.id.replace("_", " ") + " " + item.nome()
		var passa := not (_so_avisos.button_pressed and not item.tem_aviso())
		if passa and (texto == "" or nome.to_lower().contains(texto)):
			_visiveis.append(item)
	_galeria.mostrar(_visiveis)
	_galeria.marcar_avisos()
	var analisando := ""
	if not _tarefas.is_empty():
		analisando = (
			"   analisando %d/%d" % [_total_de_tarefas - _tarefas.size(), _total_de_tarefas]
		)
	_resumo.text = (
		"%d de %d folhas   (%d com aviso)%s" % [_visiveis.size(), _itens.size(), avisos, analisando]
	)


func _escolhe(item: CatalogoSprites.Item) -> void:
	_item = item
	_galeria.marcar(item)
	if _jogo != null and item.tipo == CatalogoSprites.Tipo.PEDESTRE:
		_jogo.avatar = CenaSprite._avatar_do(item)
	# Quem abre a folha espera o resultado dela: a thread ja pode ter feito, ou
	# o trabalho e feito aqui, uma vez so (`Item.trava`).
	AnaliseSprites.analisar(item)
	_atualizando = true
	_tela.item = item
	_tela.coluna = 0
	_tela.linha = 0
	_tela.espelhar = false
	_tela.referencia_extra = null
	_tela.base = BaseSprites.carregar(item)
	_espelhar.button_pressed = false
	_espelhar.visible = item.tipo == CatalogoSprites.Tipo.PEDESTRE
	_monta_as_linhas(item)
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
	_atualiza_a_moto_3d()


func _muda_grupos_da_cena() -> void:
	var moto := _item != null and _item.tipo == CatalogoSprites.Tipo.MOTO
	(_barra_cena.get_meta(&"moto") as Control).visible = moto
	_grupo_voo.visible = _item != null and _item.animacao == "voando"
	_grupo_queda.visible = _item != null and _item.animacao == "caida"


func _muda_vista(vista: int) -> void:
	_marca(_vista, vista)
	_tela.vista = vista
	_tocar.disabled = vista != TelaSprite.Vista.QUADRO
	_grupo_outra.visible = vista == TelaSprite.Vista.DUAS
	if vista == TelaSprite.Vista.DUAS and _tela.outro == null:
		_compara_com(_outra_padrao())
	_atualiza_a_moto_3d()


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
	var todos := item.todos_os_avisos()
	if todos.is_empty():
		if item.analisado:
			linhas.append("[color=lightgreen]sem avisos[/color]")
		else:
			linhas.append("[color=gray]analisando...[/color]")
	for aviso in todos:
		linhas.append("[color=orange]! %s[/color]" % aviso)
	linhas.append_array(_info_da_referencia(item))
	linhas.append_array(_info_da_base(item))
	if not _status_texto.is_empty():
		linhas.append("[color=lightgreen]%s[/color]" % _status_texto)
	_info.text = "\n".join(linhas)


## O que a referencia diz de si mesma, e as suspeitas por recorrencia. E aqui
## que se ve que o defeito pode ser do boneco e nao do Flow.
func _info_da_referencia(item: CatalogoSprites.Item) -> PackedStringArray:
	var linhas: PackedStringArray = []
	if item.tipo == CatalogoSprites.Tipo.MOTO:
		(
			linhas
			. append(
				"[color=gray]referencia: o modelo 3D da moto, fotografado ao vivo (vista Referencia 3D)[/color]"
			)
		)
		return linhas
	var ref := item.referencia
	if ref == null:
		return linhas
	linhas.append(
		(
			"[color=gray]referencia 3D: arte/flow/referencia/%s.png, %d colunas x %d linhas[/color]"
			% [item.animacao, ref.colunas, ref.linhas]
		)
	)
	if ref.avisos.is_empty():
		linhas.append("[color=lightgreen]a referencia nao tem defeito que se meça[/color]")
	for aviso in ref.avisos:
		linhas.append("[color=yellow]! referencia: %s[/color]" % aviso)
	for suspeita in _recorrentes:
		if suspeita.begins_with(item.animacao + ","):
			linhas.append("[color=salmon]suspeita da referencia: %s[/color]" % suspeita)
	return linhas


func _info_da_base(item: CatalogoSprites.Item) -> PackedStringArray:
	var linhas: PackedStringArray = []
	if not BaseSprites.existe(item):
		return linhas
	var diferentes := BaseSprites.quadros_diferentes(item, _tela.base)
	linhas.append(
		(
			"[color=gray]base fixada em %s: %d de %d quadros mudaram[/color]"
			% [BaseSprites.data(item), diferentes.size(), item.quadros()]
		)
	)
	return linhas


func _muda_modo(modo: int) -> void:
	_modo = modo
	_marca(_modo_botao, modo)
	_tela.visible = modo == Modo.FOLHA
	_contentor_cena.visible = modo == Modo.CENA
	_contentor_jogo.visible = modo == Modo.JOGAR
	_barra_folha.visible = modo == Modo.FOLHA
	_barra_cena.visible = modo == Modo.CENA
	_barra_jogo.visible = modo == Modo.JOGAR
	if modo == Modo.JOGAR:
		_garante_o_jogo()
		# O foco no campo de busca engoliria o WASD.
		get_viewport().gui_release_focus()
	if _jogo != null:
		# O jogo parado nao le os controles nem gasta fisica: a moto responderia
		# ao teclado de dentro de outro modo.
		_jogo.process_mode = (
			Node.PROCESS_MODE_INHERIT if modo == Modo.JOGAR else Node.PROCESS_MODE_DISABLED
		)


## O playground so e montado na primeira vez que alguem vai jogar.
func _garante_o_jogo() -> void:
	if _jogo != null:
		return
	_jogo = JogoSprite.new()
	if _item != null and _item.tipo == CatalogoSprites.Tipo.PEDESTRE:
		_jogo.avatar = CenaSprite._avatar_do(_item)
	_contentor_jogo.get_child(0).add_child(_jogo)
	_barra_jogo.montar(_jogo)


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
	_atualiza_a_moto_3d()


func _escolhe_linha(linha: int) -> void:
	if _item == null:
		return
	_tela.linha = clampi(linha, 0, maxi(_item.linhas - 1, 0))
	if _linhas.get_child_count() > _tela.linha:
		(_linhas.get_child(_tela.linha) as Button).set_pressed_no_signal(true)


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


## A referencia da moto e uma foto do modelo 3D, que chega depois de alguns
## quadros; so o ultimo pedido vale, e so quando alguem esta olhando para ela.
func _atualiza_a_moto_3d() -> void:
	if _item == null or _item.tipo != CatalogoSprites.Tipo.MOTO:
		return
	if _tela.vista != TelaSprite.Vista.REFERENCIA:
		return
	_pedido_da_moto += 1
	var pedido := _pedido_da_moto
	var imagem: Image = await _moto_3d.fotografar(_tela.coluna, Entregador.Modelo.CG_160)
	if pedido == _pedido_da_moto and imagem != null:
		_tela.referencia_extra = imagem


# --- base e exportacao -----------------------------------------------------


func _fixa_a_base() -> void:
	var erro := BaseSprites.fixar(_item)
	_tela.base = BaseSprites.carregar(_item)
	_avisa("base fixada" if erro == OK else "nao deu para fixar: %s" % error_string(erro))


func _limpa_a_base() -> void:
	BaseSprites.limpar(_item)
	_tela.base = null
	_avisa("base apagada")


func _exporta_o_quadro() -> void:
	var imagem := ExportaSprites.quadro(_item, _tela.coluna, _tela.linha, AUMENTO_DO_EXPORTE)
	_grava(imagem, "%s_c%d_l%d.png" % [_item.id, _tela.coluna + 1, _tela.linha + 1])


func _exporta_a_folha_marcada() -> void:
	_grava(ExportaSprites.folha_marcada(_item), "%s_marcada.png" % _item.id)


func _exporta_a_comparacao() -> void:
	var imagem := ExportaSprites.comparacao(_item)
	if imagem == null:
		_avisa("esta folha nao tem referencia gravada para comparar")
		return
	_grava(imagem, "%s_comparacao.png" % _item.id)


func _grava(imagem: Image, nome: String) -> void:
	if imagem == null:
		_avisa("nada para exportar")
		return
	var caminho := ExportaSprites.pasta_absoluta().path_join(nome)
	var erro := imagem.save_png(caminho)
	_avisa(("gravado: %s" % caminho) if erro == OK else ("erro ao gravar: %s" % error_string(erro)))
	if erro == OK:
		OS.shell_show_in_file_manager(caminho)


func _avisa(texto: String) -> void:
	_status_texto = texto
	_status.text = texto.get_file() if texto.begins_with("gravado") else texto
	_mostra_info()


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


## Sai do programa. Os `SubViewport` 3D (a cena, o jogo, a foto da moto) param de
## desenhar e saem da arvore um quadro antes: sair no meio do desenho deixava o
## processo pendurado no macOS, esperando a GPU, em metade das saidas.
func _encerra(codigo: int) -> void:
	for contentor: SubViewportContainer in [_contentor_cena, _contentor_jogo]:
		for porta in contentor.get_children():
			(porta as SubViewport).render_target_update_mode = SubViewport.UPDATE_DISABLED
		contentor.visible = false
	_moto_3d.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if _jogo != null:
		_jogo.process_mode = Node.PROCESS_MODE_DISABLED
	for i in 3:
		await get_tree().process_frame
	get_tree().quit(codigo)


## Uma situacao do playground a partir da linha de comando, para conferir sem
## pilotar: `--jogar --evento=atropelar --espera=0.6 --captura=a.png`.
func _dispara_o_evento(nome: String) -> void:
	match nome:
		"atropelar":
			_jogo.atropelar(25.0)
		"susto":
			_jogo.passar_uma_moto(25.0, 1.0)
		"carro":
			_jogo.sair_do_carro(1)
		"carro_rua":
			_jogo.sair_do_carro(-1)
		"largada":
			_jogo.largada()


static func _argumentos() -> Dictionary:
	var achados := {}
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--"):
			continue
		var partes := arg.trim_prefix("--").split("=", true, 1)
		achados[partes[0]] = partes[1] if partes.size() > 1 else true
	return achados


func _captura_e_sai(caminho: String, espera: float = 0.0) -> void:
	# Alguns quadros para o 3D assentar, e para a analise e a foto da moto
	# chegarem: o primeiro quadro sai antes do shader compilar.
	for i in 40:
		await get_tree().process_frame
	if espera > 0.0:
		await get_tree().create_timer(espera).timeout
	var imagem := get_viewport().get_texture().get_image()
	var erro := imagem.save_png(caminho)
	print("captura: ", caminho, " (", error_string(erro), ")")
	_encerra(0 if erro == OK else 1)
