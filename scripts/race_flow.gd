class_name RaceFlow
extends CanvasLayer
## O fluxo em volta da corrida: menu, configuracoes e tela de resultado.
##
## Isto nao e o menu bonito do jogo, e o contrato continua valendo - nada de
## arte e audio ate o feel fechar. E o CAMINHO de entrar e sair de uma corrida
## sem tecla escondida. Ate aqui a unica forma de correr de novo era o `R`, e a
## unica forma de descobrir que existe troca de camera era ler o README. Quem
## baixa o zip da release nao le o README, e prototipo que ninguem consegue
## jogar de ponta a ponta nao responde a pergunta que ele existe pra responder.
##
## Mora DENTRO do SubViewport de 320x180 pelo mesmo motivo que a `Hud`:
## interface nitida sobre mundo pixelado e o visual de remaster preguicoso.
##
## O banco de provas NAO passa por aqui - `iniciar(true)` larga direto na
## corrida. Menu esperando ENTER num processo headless e teste que trava em vez
## de falhar, e travado nao tem codigo de saida pra CI ler.

signal corrida_pedida
signal pixel_alternado
signal camera_alternada
signal painel_pedido
## A tela mudou. Quem ouve decide o que congelar e o que esconder - o fluxo nao
## conhece o mundo nem a Hud.
signal tela_mudou(nova: int)

enum Tela { MENU, CORRIDA, CONFIGURACOES, RESULTADO }

## Quantas linhas de menu cabem de uma vez. A tela mais cheia e a de
## configuracoes, com quatro.
const MAX_ITENS: int = 4

## Altura de uma linha de menu, em pixels da tela de 320x180. Menos que isto e
## o contorno preto de um rotulo encosta no de baixo.
const PASSO_ITEM: float = 14.0

## Escurecedor por cima do mundo congelado. O mesmo alpha que a antiga tela de
## fim usava: o suficiente pra ler texto de 8px sobre asfalto claro, pouco o
## bastante pra ainda se ver que tem uma corrida parada atras.
const ESCURECEDOR: Color = Color(0.05, 0.05, 0.09, 0.82)

const COR_SELECIONADO: Color = Color(1.0, 0.9, 0.4)
const COR_ITEM: Color = Color(0.82, 0.85, 0.92)

## Como descrever o estado do pixel e da camera na tela de configuracoes.
##
## Vem de fora em vez de o fluxo ler o `Main`: quem sabe se o pixel esta ligado
## e quem o liga. Mesmo padrao de `PlayerBike.find_clear_lateral`.
var descreve_pixel: Callable
var descreve_camera: Callable

var tela: int = Tela.MENU

## Tem uma corrida congelada atras do menu?
##
## Ela troca a primeira linha de JOGAR pra CONTINUAR. Menu de pausa que joga
## fora a corrida em andamento e menu que ninguem abre - e sem uma saida que
## nao seja fechar a janela, o ESC no meio da corrida nao teria pra onde ir.
var _corrida_pausada: bool = false

var _raiz: Control
var _titulo: Label
var _subtitulo: Label
var _texto: Label
var _rodape: Label
var _itens: Array[Label] = []
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
	# 150px numa tela de 180 - as duas saidas embaixo ficavam POR CIMA das
	# ultimas linhas do placar. Apertar a entrelinha e o que faz o placar
	# inteiro e as saidas caberem sem cortar nenhum dos dois.
	_texto.add_theme_constant_override("line_spacing", -3)
	# O rodape mora sempre no mesmo lugar, colado no pe da tela: e a unica
	# linha que nunca muda de posicao entre as telas.
	_rodape = _rotulo(8, Color(0.45, 0.5, 0.6))
	_posicionar(_rodape, Hud.H - 16.0)
	for _i in MAX_ITENS:
		_itens.append(_rotulo(8, COR_ITEM))


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
	if evento.is_action_pressed("ui_down"):
		# Da a volta em vez de parar no ultimo: com tres itens, rolar e mais
		# rapido que mirar.
		_selecionado = (_selecionado + 1) % quantos
		_pintar_itens()
	elif evento.is_action_pressed("ui_up"):
		_selecionado = (_selecionado - 1 + quantos) % quantos
		_pintar_itens()
	elif evento.is_action_pressed("ui_accept"):
		_escolher(_selecionado)
	elif evento.is_action_pressed("ui_cancel"):
		_voltar()
	else:
		return false
	return true


func _process(_delta: float) -> void:
	# A tela de configuracoes mostra estado que muda enquanto ela esta aberta
	# (o pixel alterna na propria linha), entao o rotulo se refaz por frame.
	if tela == Tela.CONFIGURACOES:
		_pintar_itens()


## --- Telas ----------------------------------------------------------------


func _ir_para(nova: int) -> void:
	tela = nova
	_selecionado = 0
	_raiz.visible = nova != Tela.CORRIDA

	_titulo.visible = false
	_subtitulo.visible = false
	_texto.visible = false

	match nova:
		Tela.MENU:
			_posicionar(_titulo, 30.0)
			_titulo.text = "RUSHFOOD"
			_titulo.visible = true
			_posicionar(_subtitulo, 50.0)
			_subtitulo.text = "corrida de entregadores - prototipo"
			_subtitulo.visible = true
			_posicionar_itens(90.0)
			_rodape.text = "setas movem   ENTER escolhe   %s" % Hud.carimbo_versao()
		Tela.CONFIGURACOES:
			_posicionar(_titulo, 18.0)
			_titulo.text = "CONFIGURACOES"
			_titulo.visible = true
			_posicionar_itens(58.0)
			_rodape.text = "ENTER muda   ESC volta"
		Tela.RESULTADO:
			_posicionar(_texto, 8.0)
			_texto.size = Vector2(Hud.W, 124)
			_texto.visible = true
			_posicionar_itens(134.0)
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
			# morar onde CONFIGURACOES morava.
			return PackedStringArray(
				["CONTINUAR" if _corrida_pausada else "JOGAR", "CONFIGURACOES", "SAIR"]
			)
		Tela.CONFIGURACOES:
			return PackedStringArray(
				[
					"PIXEL 320x180: %s" % _descreve(descreve_pixel),
					"CAMERA: %s" % _descreve(descreve_camera),
					"PAINEL DE TUNING",
					"VOLTAR",
				]
			)
		Tela.RESULTADO:
			return PackedStringArray(["CORRER DE NOVO", "MENU"])
	return PackedStringArray()


func _escolher(indice: int) -> void:
	match tela:
		Tela.MENU:
			match indice:
				0:
					if _corrida_pausada:
						_corrida_pausada = false
						_ir_para(Tela.CORRIDA)
					else:
						_correr()
				1:
					_ir_para(Tela.CONFIGURACOES)
				2:
					get_tree().quit()
		Tela.CONFIGURACOES:
			match indice:
				0:
					pixel_alternado.emit()
				1:
					camera_alternada.emit()
				2:
					painel_pedido.emit()
				3:
					_ir_para(Tela.MENU)
		Tela.RESULTADO:
			if indice == 0:
				_correr()
			else:
				_ir_para(Tela.MENU)


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


func _pintar_itens() -> void:
	var rotulos := rotulos_da_tela()
	for i in _itens.size():
		var item := _itens[i]
		item.visible = i < rotulos.size()
		if not item.visible:
			continue
		var escolhido := i == _selecionado
		# O cursor entra nos dois casos pra largura do texto nao mudar: com
		# alinhamento centralizado, um prefixo so no selecionado faz a linha
		# inteira pular de lado quando a selecao anda.
		item.text = "%s %s" % [">" if escolhido else " ", rotulos[i]]
		item.add_theme_color_override("font_color", COR_SELECIONADO if escolhido else COR_ITEM)


func _posicionar_itens(topo: float) -> void:
	for i in _itens.size():
		_posicionar(_itens[i], topo + float(i) * PASSO_ITEM)


func _posicionar(rotulo: Label, y: float) -> void:
	rotulo.position = Vector2(0, y)
	rotulo.size = Vector2(Hud.W, 20)


func _rotulo(tamanho: int, cor: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_color", cor)
	# Contorno preto pelo mesmo motivo da Hud: texto claro some no asfalto
	# claro do meio-dia, e aqui ele aparece por cima do mundo congelado.
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 3)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(l)
	return l


func _descreve(fonte: Callable) -> String:
	return str(fonte.call()) if fonte.is_valid() else "?"
