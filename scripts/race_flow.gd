class_name RaceFlow
extends CanvasLayer
## O fluxo em volta da corrida: o menu e a tela de resultado.
##
## Isto nao e o menu bonito do jogo, e o contrato continua valendo - nada de
## arte e audio ate o feel fechar. E o CAMINHO de entrar e sair de uma corrida
## sem tecla escondida. Ate aqui a unica forma de correr de novo era o `R`, e a
## unica forma de descobrir que existe troca de camera era ler o README. Quem
## baixa o zip da release nao le o README, e prototipo que ninguem consegue
## jogar de ponta a ponta nao responde a pergunta que ele existe pra responder.
##
## O menu e uma pagina so: JOGAR, as opcoes em colunas por secao e as saidas.
## As opcoes sao as diferencas do projeto que se quer comparar ligando e
## desligando - pixel, piloto em sprite, cadencia, sombra -, e escondidas numa
## segunda tela elas viravam tres teclas a mais por comparacao. Com o mundo
## congelado atras, a troca aparece na hora.
##
## Mora DENTRO do SubViewport, na resolucao interna, pelo mesmo motivo que a `Hud`:
## interface nitida sobre mundo pixelado e o visual de remaster preguicoso.
##
## O banco de provas NAO passa por aqui - `iniciar(true)` larga direto na
## corrida. Menu esperando ENTER num processo headless e teste que trava em vez
## de falhar, e travado nao tem codigo de saida pra CI ler.

signal corrida_pedida
signal painel_pedido
## A tela mudou. Quem ouve decide o que congelar e o que esconder - o fluxo nao
## conhece o mundo nem a Hud.
signal tela_mudou(nova: int)

enum Tela { MENU, CORRIDA, RESULTADO }

## As linhas fixas do menu, em volta das opcoes: JOGAR em cima, as duas saidas
## embaixo.
const JOGAR: String = "JOGAR"
const PAINEL: String = "PAINEL DE TUNING (F3)"
const SAIR: String = "SAIR"

## Onde moram as colunas de opcoes, em unidades de layout (a tela de 320x180 em
## que a `Hud` e escrita; ver `Hud.ESCALA`): do cabecalho da secao ate a linha
## das saidas.
const TOPO_COLUNAS: float = 46.0
const PE_COLUNAS: float = 148.0
## Passo de uma linha de opcao. O maximo e o do menu antigo com folga para o
## contorno; abaixo do minimo o contorno preto de um rotulo come o de baixo, e
## a secao quebra em mais uma coluna em vez de apertar mais.
const PASSO_MAX: float = 12.0
const PASSO_MIN: float = 8.0
## A fonte acompanha o passo: 72% dele e o maior corpo em que o contorno de
## duas linhas vizinhas ainda nao se encosta.
const FONTE_POR_PASSO: float = 0.72
const FONTE_MIN: int = 5
const FONTE_MAX: int = 8
## Margem das colunas nas bordas da tela e entre uma e outra.
const MARGEM: float = 8.0

## Escurecedor por cima do mundo congelado. O mesmo alpha que a antiga tela de
## fim usava: o suficiente pra ler texto de 8px sobre asfalto claro, pouco o
## bastante pra ainda se ver que tem uma corrida parada atras.
const ESCURECEDOR: Color = Color(0.05, 0.05, 0.09, 0.82)

const COR_SELECIONADO: Color = Color(1.0, 0.9, 0.4)
const COR_ITEM: Color = Color(0.82, 0.85, 0.92)
const COR_VALOR: Color = Color(0.6, 0.85, 1.0)
const COR_SECAO: Color = Color(1.0, 0.6, 0.25)


## Uma linha de opcao do menu. `valor` devolve o texto do estado de agora, e
## `muda` recebe o passo: 1 para a direita e o ENTER, -1 para a esquerda.
##
## Vem de fora em vez de o fluxo ler o `Main`: quem sabe se o pixel esta ligado
## e quem o liga. Mesmo padrao de `PlayerBike.find_clear_lateral`.
class Opcao:
	var secao: String
	var nome: String
	var valor: Callable
	var muda: Callable


var tela: int = Tela.MENU

## Tem uma corrida congelada atras do menu?
##
## Ela troca a primeira linha de JOGAR pra CONTINUAR. Menu de pausa que joga
## fora a corrida em andamento e menu que ninguem abre - e sem uma saida que
## nao seja fechar a janela, o ESC no meio da corrida nao teria pra onde ir.
var _corrida_pausada: bool = false

var _opcoes: Array[Opcao] = []
var _raiz: Control
var _titulo: Label
var _subtitulo: Label
var _texto: Label
var _rodape: Label
## Um par de rotulos por linha da tela: o nome a esquerda e o valor a direita.
## As linhas sem valor (JOGAR, SAIR) usam so o nome, centralizado.
var _nomes: Array[Label] = []
var _valores: Array[Label] = []
var _cabecalhos: Array[Label] = []
## Onde cada linha da tela recebe o mouse, em pixels de layout (os de `_raiz`),
## na ordem de `rotulos_da_tela`. A caixa do rotulo nao serve: ela e mais alta
## que o passo, e a de uma linha cobriria a de baixo.
var _alvos: Array[Rect2] = []
var _selecionado: int = 0


func _ready() -> void:
	# Acima da `Hud` (layer 10): a tela de resultado tapa o painel de corrida.
	layer = 20

	_raiz = Control.new()
	_raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_raiz)

	var escurecedor := ColorRect.new()
	escurecedor.color = ESCURECEDOR
	escurecedor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	escurecedor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(escurecedor)

	_titulo = _rotulo(16, Color(1, 1, 1))
	_subtitulo = _rotulo(8, Color(0.7, 0.75, 0.85))
	_texto = _rotulo(8, Color(1, 1, 1))
	# O resumo tem dez linhas, e no espacamento padrao da fonte elas passam de
	# 150 unidades numa tela de 180 - as duas saidas embaixo ficavam POR CIMA das
	# ultimas linhas do placar. Apertar a entrelinha e o que faz o placar
	# inteiro e as saidas caberem sem cortar nenhum dos dois.
	_texto.add_theme_constant_override("line_spacing", -3 * Hud.ESCALA)
	# O rodape mora sempre no mesmo lugar, colado no pe da tela: e a unica
	# linha que nunca muda de posicao entre as telas.
	_rodape = _rotulo(8, Color(0.45, 0.5, 0.6))
	_posicionar(_rodape, Hud.H - 16.0)


## Acrescenta uma opcao ao menu, na coluna `secao`. A ordem de chamada e a
## ordem na tela.
func opcao(secao: String, nome: String, valor: Callable, muda: Callable) -> void:
	var nova := Opcao.new()
	nova.secao = secao
	nova.nome = nome
	nova.valor = valor
	nova.muda = muda
	_opcoes.append(nova)
	if tela == Tela.MENU and is_node_ready():
		_ir_para(Tela.MENU)


## Larga o fluxo. `direto_na_corrida` pula o menu inteiro - e o que o banco de
## provas usa.
func iniciar(direto_na_corrida: bool) -> void:
	_ir_para(Tela.CORRIDA if direto_na_corrida else Tela.MENU)


## O mundo acabou de cruzar a linha: mostra o placar e as saidas.
func mostrar_resultado(resumo: String) -> void:
	_corrida_pausada = false
	_texto.text = resumo
	_ir_para(Tela.RESULTADO)


## Trata uma tecla de navegacao. Devolve `true` se consumiu o evento.
##
## O input chega pelo `Main` e nao por um `_unhandled_input` daqui, porque o
## fluxo mora dentro do SubViewport e o SubViewport deste projeto nao trata
## input localmente (`handle_input_locally = false`). Encaminhar de fora e uma
## linha; descobrir por que a seta nao anda o menu e uma tarde.
func navegar(evento: InputEvent) -> bool:
	if tela == Tela.CORRIDA:
		# ESC e a unica tecla de fluxo que o jogo escuta com a corrida andando:
		# ela congela o mundo e abre o menu. O resto e do jogo.
		if not evento.is_action_pressed("ui_cancel"):
			return false
		_corrida_pausada = true
		_ir_para(Tela.MENU)
		return true

	var quantos := rotulos_da_tela().size()
	var opcao_aqui := _opcao_selecionada()
	if evento.is_action_pressed("ui_down"):
		# Da a volta em vez de parar no ultimo: rolar e mais rapido que mirar.
		# Desce a primeira coluna inteira e continua no topo da seguinte.
		_selecionado = (_selecionado + 1) % quantos
	elif evento.is_action_pressed("ui_up"):
		_selecionado = (_selecionado - 1 + quantos) % quantos
	elif opcao_aqui != null and evento.is_action_pressed("ui_right"):
		opcao_aqui.muda.call(1)
	elif opcao_aqui != null and evento.is_action_pressed("ui_left"):
		opcao_aqui.muda.call(-1)
	elif evento.is_action_pressed("ui_accept"):
		_escolher(_selecionado)
	elif evento.is_action_pressed("ui_cancel"):
		_voltar()
	else:
		return false
	_pintar_itens()
	return true


## Trata um evento de mouse, com `ponto` em pixels do SubViewport. Devolve
## `true` se consumiu.
##
## Passar por cima seleciona, como a seta. O clique esquerdo e o ENTER; numa
## opcao, o direito e a rodinha andam o valor para tras e para a frente. Vem
## pelo `Main` pelo mesmo motivo do teclado: o SubViewport nao trata input.
func apontar(evento: InputEvent, ponto: Vector2) -> bool:
	if tela == Tela.CORRIDA:
		return false
	var i := _linha_em(ponto / scale.x)
	if i < 0:
		return false
	if evento is InputEventMouseMotion:
		if i != _selecionado:
			_selecionado = i
			_pintar_itens()
		return true
	var botao := evento as InputEventMouseButton
	if botao == null or not botao.pressed:
		return false
	_selecionado = i
	var o := _opcao_selecionada()
	match botao.button_index:
		MOUSE_BUTTON_LEFT:
			_escolher(i)
		MOUSE_BUTTON_RIGHT when o != null:
			o.muda.call(-1)
		MOUSE_BUTTON_WHEEL_UP when o != null:
			o.muda.call(1)
		MOUSE_BUTTON_WHEEL_DOWN when o != null:
			o.muda.call(-1)
		_:
			return false
	_pintar_itens()
	return true


## O centro da linha `i` em pixels do SubViewport: onde clicar para acertar
## ela. Publica para o unitario clicar sem refazer a conta do layout.
func centro_da_linha(i: int) -> Vector2:
	return _alvos[i].get_center() * scale.x


func _linha_em(ponto: Vector2) -> int:
	for i in mini(_alvos.size(), rotulos_da_tela().size()):
		if _alvos[i].has_point(ponto):
			return i
	return -1


func _process(_delta: float) -> void:
	# O SubViewport nem sempre e de 640x360 (960x540 em tela grande, ou o
	# tamanho do viewport base com o pixel desligado), e o menu, escrito para
	# 640x360, ficaria num canto. Mesma conta da `Hud`: a escala e a altura
	# sobre 360, e nao inteira, para o menu ocupar a tela em qualquer
	# resolucao interna; em 540p o pixel da fonte sai a 1,5x.
	var tela_px := get_viewport().get_visible_rect().size
	var k := maxf(tela_px.y / (Hud.H * Hud.ESCALA), 1.0)
	scale = Vector2(k, k)
	_raiz.size = (tela_px / k).floor()
	# O menu mostra estado que muda enquanto ele esta aberto (a tecla F do
	# pixel, a moto que o F3 troca), entao os rotulos se refazem por frame.
	if tela == Tela.MENU:
		_pintar_itens()


## --- Telas ----------------------------------------------------------------


func _ir_para(nova: int) -> void:
	tela = nova
	_selecionado = 0
	_raiz.visible = nova != Tela.CORRIDA

	_titulo.visible = false
	_subtitulo.visible = false
	_texto.visible = false
	for cabecalho in _cabecalhos:
		cabecalho.visible = false

	match nova:
		Tela.MENU:
			_posicionar(_titulo, 4.0)
			_titulo.text = "RUSHFOOD"
			_titulo.visible = true
			_posicionar(_subtitulo, 21.0)
			_subtitulo.text = "corrida de entregadores - prototipo"
			_subtitulo.visible = true
			_monta_menu()
			_rodape.text = ("setas movem   < > mudam   ENTER escolhe   %s" % Hud.carimbo_versao())
		Tela.RESULTADO:
			_posicionar(_texto, 8.0)
			_texto.size = Vector2(Hud.W, 124) * Hud.ESCALA
			_texto.visible = true
			_garante_linhas(2)
			_alvos.clear()
			for i in 2:
				_linha_centralizada(i, 0.0, 134.0 + 14.0 * i, Hud.W, FONTE_MAX)
				_alvo(i, 0.0, 134.0 + 14.0 * i, Hud.W, 14.0)
			_rodape.text = "ENTER escolhe"

	_pintar_itens()
	tela_mudou.emit(nova)


## O que cada linha da tela atual diz.
##
## A ORDEM importa: e ela que `_escolher` usa como indice, e as duas funcoes
## vivem coladas de proposito. E publica pra o unitario poder travar essa
## ordem - trocar duas linhas de lugar e a mudanca mais barata de fazer e a
## mais cara de perceber, porque o menu continua desenhando lindamente e so o
## que ele FAZ e que troca.
func rotulos_da_tela() -> PackedStringArray:
	match tela:
		Tela.MENU:
			# A primeira linha troca de nome, e nao de lugar: mexer no numero de
			# itens moveria o indice que `_escolher` usa, e SAIR passaria a
			# morar em outra linha.
			var rotulos := PackedStringArray(["CONTINUAR" if _corrida_pausada else JOGAR])
			for o in _opcoes:
				rotulos.append("%s: %s" % [o.nome, _descreve(o.valor)])
			rotulos.append(PAINEL)
			rotulos.append(SAIR)
			return rotulos
		Tela.RESULTADO:
			return PackedStringArray(["CORRER DE NOVO", "MENU"])
	return PackedStringArray()


func _escolher(indice: int) -> void:
	match tela:
		Tela.MENU:
			if indice == 0:
				if _corrida_pausada:
					_corrida_pausada = false
					_ir_para(Tela.CORRIDA)
				else:
					_correr()
			elif indice <= _opcoes.size():
				_opcoes[indice - 1].muda.call(1)
			elif indice == _opcoes.size() + 1:
				painel_pedido.emit()
			else:
				get_tree().quit()
		Tela.RESULTADO:
			if indice == 0:
				_correr()
			else:
				_ir_para(Tela.MENU)


## A opcao na linha selecionada, ou null nas linhas fixas.
func _opcao_selecionada() -> Opcao:
	if tela != Tela.MENU or _selecionado < 1 or _selecionado > _opcoes.size():
		return null
	return _opcoes[_selecionado - 1]


func _voltar() -> void:
	# Do menu raiz nao se volta pra lugar nenhum: ESC que fecha o jogo sem
	# perguntar e a forma mais rapida de alguem perder uma corrida por engano.
	if tela != Tela.MENU:
		_ir_para(Tela.MENU)


func _correr() -> void:
	_corrida_pausada = false
	_ir_para(Tela.CORRIDA)
	corrida_pedida.emit()


## --- Desenho --------------------------------------------------------------


## Distribui as linhas do menu: JOGAR no topo, uma coluna por secao no meio e
## as saidas lado a lado embaixo.
##
## O menu nao tem limite de opcoes. Com mais linhas do que cabe no passo
## maximo, o passo e a fonte encolhem juntos; abaixo do passo minimo a secao
## quebra numa coluna a mais, sem cabecalho, e as colunas ficam mais estreitas.
func _monta_menu() -> void:
	var total := _opcoes.size() + 3
	_garante_linhas(total)
	_alvos.clear()
	_alvos.resize(total)

	# As colunas: cada uma e uma lista de indices de linha (1 = primeira
	# opcao), com o titulo da secao so na primeira parte dela.
	var cabem := maxi(int((PE_COLUNAS - TOPO_COLUNAS) / PASSO_MIN) - 1, 1)
	var colunas: Array[Array] = []
	var titulos: PackedStringArray = []
	for i in _opcoes.size():
		var secao := _opcoes[i].secao
		var mesma := i > 0 and _opcoes[i - 1].secao == secao
		if not mesma or colunas.back().size() >= cabem:
			colunas.append([])
			titulos.append(secao if not mesma else "")
		colunas.back().append(i + 1)

	var mais_alta := 1
	for coluna in colunas:
		mais_alta = maxi(mais_alta, coluna.size())
	# Uma linha a mais pelo cabecalho da secao.
	var passo := clampf((PE_COLUNAS - TOPO_COLUNAS) / (mais_alta + 1), PASSO_MIN, PASSO_MAX)
	var fonte := clampi(int(passo * FONTE_POR_PASSO), FONTE_MIN, FONTE_MAX)
	var largura := (Hud.W - MARGEM) / maxf(colunas.size(), 1.0)

	_linha_centralizada(0, 0.0, TOPO_COLUNAS - 13.0, Hud.W, FONTE_MAX)
	_alvo(0, 0.0, TOPO_COLUNAS - 13.0, Hud.W, 12.0)
	while _cabecalhos.size() < colunas.size():
		_cabecalhos.append(_rotulo(FONTE_MAX, COR_SECAO))
	for c in colunas.size():
		var x := MARGEM * 0.5 + largura * c
		var cabecalho := _cabecalhos[c]
		cabecalho.text = titulos[c]
		cabecalho.visible = true
		_estilo(cabecalho, fonte)
		_coloca(cabecalho, x + MARGEM * 0.5, TOPO_COLUNAS, largura - MARGEM)
		cabecalho.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		for r in colunas[c].size():
			var i: int = colunas[c][r]
			var y := TOPO_COLUNAS + passo * (r + 1)
			_estilo(_nomes[i], fonte)
			_estilo(_valores[i], fonte)
			_coloca(_nomes[i], x + MARGEM * 0.5, y, largura - MARGEM)
			_coloca(_valores[i], x + MARGEM * 0.5, y, largura - MARGEM)
			_nomes[i].horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			_alvo(i, x + MARGEM * 0.5, y, largura - MARGEM, passo)
			_valores[i].horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_linha_centralizada(total - 2, 0.0, PE_COLUNAS + 2.0, Hud.W * 0.5, FONTE_MAX)
	_linha_centralizada(total - 1, Hud.W * 0.5, PE_COLUNAS + 2.0, Hud.W * 0.5, FONTE_MAX)
	_alvo(total - 2, 0.0, PE_COLUNAS + 2.0, Hud.W * 0.5, 12.0)
	_alvo(total - 1, Hud.W * 0.5, PE_COLUNAS + 2.0, Hud.W * 0.5, 12.0)


func _alvo(i: int, x: float, y: float, largura: float, altura: float) -> void:
	if _alvos.size() <= i:
		_alvos.resize(i + 1)
	_alvos[i] = Rect2(Vector2(x, y) * Hud.ESCALA, Vector2(largura, altura) * Hud.ESCALA)


func _pintar_itens() -> void:
	var rotulos := rotulos_da_tela()
	for i in _nomes.size():
		var nome := _nomes[i]
		var valor := _valores[i]
		nome.visible = i < rotulos.size()
		valor.visible = false
		if not nome.visible:
			continue
		var escolhido := i == _selecionado
		var cor := COR_SELECIONADO if escolhido else COR_ITEM
		nome.add_theme_color_override("font_color", cor)
		var o: Opcao = null
		if tela == Tela.MENU and i >= 1 and i <= _opcoes.size():
			o = _opcoes[i - 1]
		if o == null:
			# O cursor dos dois lados: com alinhamento centralizado, um prefixo
			# so de um lado faz a linha inteira pular quando a selecao anda.
			nome.text = "> %s <" % rotulos[i] if escolhido else rotulos[i]
			continue
		nome.text = o.nome
		valor.visible = true
		# As setas so na linha selecionada: e ali que elas mudam o valor, e
		# alinhado a direita o nome nao se mexe quando elas aparecem.
		var texto := _descreve(o.valor)
		valor.text = "< %s >" % texto if escolhido else texto
		valor.add_theme_color_override("font_color", cor if escolhido else COR_VALOR)


## Garante `n` pares de rotulos de linha.
func _garante_linhas(n: int) -> void:
	while _nomes.size() < n:
		_nomes.append(_rotulo(FONTE_MAX, COR_ITEM))
		var valor := _rotulo(FONTE_MAX, COR_VALOR)
		valor.visible = false
		_valores.append(valor)


func _linha_centralizada(i: int, x: float, y: float, largura: float, fonte: int) -> void:
	_estilo(_nomes[i], fonte)
	_coloca(_nomes[i], x, y, largura)
	_nomes[i].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _posicionar(rotulo: Label, y: float) -> void:
	_coloca(rotulo, 0.0, y, Hud.W)


func _coloca(rotulo: Label, x: float, y: float, largura: float) -> void:
	rotulo.position = Vector2(x, y) * Hud.ESCALA
	rotulo.size = Vector2(largura, 20) * Hud.ESCALA


func _rotulo(tamanho: int, cor: Color) -> Label:
	var l := Label.new()
	_estilo(l, tamanho)
	l.add_theme_color_override("font_color", cor)
	# Contorno preto pelo mesmo motivo da Hud: texto claro some no asfalto
	# claro do meio-dia, e aqui ele aparece por cima do mundo congelado.
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Nome comprido numa coluna estreita corta com reticencias em vez de
	# invadir o valor ou a coluna do lado.
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.clip_text = true
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(l)
	return l


## Corpo da fonte e contorno proporcional: o contorno de 3 do corpo 8 come
## uma fonte de 5 inteira.
func _estilo(rotulo: Label, tamanho: int) -> void:
	rotulo.add_theme_font_size_override("font_size", tamanho * Hud.ESCALA)
	rotulo.add_theme_constant_override(
		"outline_size", maxi(roundi(tamanho * 0.375), 2) * Hud.ESCALA
	)


func _descreve(fonte: Callable) -> String:
	return str(fonte.call()) if fonte.is_valid() else "?"
