class_name Hud
extends CanvasLayer
## HUD desenhada DENTRO do SubViewport, na resolucao interna do mundo.
##
## De proposito: se a interface renderizar em resolucao nativa e o mundo em
## pixel grosso, o resultado e aquele visual meio-termo de remaster preguicoso.
##
## O layout e o das referencias (REFERENCIA_VIDEO.md, *A HUD*): quatro cantos
## e o centro vazio. `POS` no topo esquerdo, distancia restante no topo
## direito (a corrida e de A a B, nao de volta, entao o `LAP` vira isto),
## `SPEED` e `TIME` embaixo, cada um com a sua barra segmentada. O combo e os
## avisos aparecem e somem no centro alto. Tudo estatico: a HUD e a unica coisa
## parada na tela, e e isso que separa interface de mundo.

## A tela de 320x180 em que o `RaceFlow` ainda escreve o menu, e o fator que
## leva para a resolucao interna. A HUD nao usa mais: ela e desenhada direto
## em 640x360 (`LARGURA`, `ALTURA`).
const W: int = 320
const H: int = 180
const ESCALA: int = 2

## A tela para a qual o layout foi desenhado, em pixels de verdade.
const LARGURA: int = 640
const ALTURA: int = 360
## Margem dos cantos: ~5% da largura e da altura, a das referencias.
const MARGEM: Vector2i = Vector2i(32, 18)
const LARGURA_BARRA: int = 160
const ALTURA_BARRA: int = 11
const SEGMENTOS_SPEED: int = 18
const SEGMENTOS_TIME: int = 15
## Estrelas da nota, de 1 a 5 (`RaceRun.stars`). As apagadas aparecem em
## cinza: e contando as que faltam que o jogador entende que a nota e de 5.
const ESTRELAS: int = 5
## Abaixo disto o relogio fica vermelho. 15 s e o que da para decidir entre
## arriscar o corredor ou nao.
const PRAZO_APERTADO: float = 15.0

## Os degraus da barra, do verde ao vermelho. Uma cor por segmento: o degrade
## das referencias sobe em degraus, e nao liso.
const CORES_BARRA: Array[Color] = [
	Color(0.2, 0.85, 0.25),
	Color(0.6, 0.9, 0.2),
	Color(1.0, 0.88, 0.15),
	Color(1.0, 0.55, 0.1),
	Color(0.95, 0.2, 0.12),
]
## O tanque de adrenalina: ciano enchendo, amarelo enquanto o boost queima.
const LARGURA_BOOST: int = 62
const ALTURA_BOOST: int = 9
const SEGMENTOS_BOOST: int = 8
const COR_BOOST: Color = Color(0.3, 0.85, 1.0)
const COR_BOOST_QUEIMANDO: Color = Color(1.0, 0.88, 0.25)
const COR_APAGADO: Color = Color(0.2, 0.21, 0.25)
const COR_MOLDURA: Color = Color(0.82, 0.85, 0.92)
const COR_FUNDO_BARRA: Color = Color(0.05, 0.06, 0.08, 0.85)

var run: RaceRun
var player: PlayerBike

## Legenda: pequena, amarelo para laranja. Valor: grande, branco para
## cinza-claro, que le como chanfro. Miudo: a unidade e os avisos.
var fonte_legenda: FonteHud
var fonte_valor: FonteHud
var fonte_miuda: FonteHud

var _painel: Control

var _evento_texto: String = ""
var _evento_cor: Color = Color.WHITE
var _event_time: float = 0.0
var _position_flash: float = 0.0
var _combo_flash: float = 0.0
var _combo_texto: String = ""
var _hint_time: float = 0.0
var _last_position: int = 0


func _ready() -> void:
	layer = 10
	fonte_legenda = FonteHud.new(1, 1, Color(1.0, 0.92, 0.25), Color(1.0, 0.5, 0.08))
	fonte_valor = FonteHud.new(2, 2, Color(1, 1, 1), Color(0.72, 0.76, 0.84), 2, 2)
	fonte_miuda = FonteHud.new(1, 1, Color(1, 1, 1), Color(0.8, 0.83, 0.9))

	_painel = Control.new()
	_painel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_painel.draw.connect(_desenha)
	add_child(_painel)


## Carimbo de versao, e se isto e o executavel ou o projeto rodando da fonte.
##
## Existe porque "continua igual" e "voce esta abrindo o build antigo" sao
## indistinguiveis sem ele, e ja custaram uma rodada de teste. E estatico
## porque o menu mostra o mesmo carimbo, e a Hud fica escondida la - dois
## lugares lendo a versao de jeitos diferentes e o proximo jeito de ela mentir.
static func carimbo_versao() -> String:
	return (
		"v%s %s"
		% [
			ProjectSettings.get_setting("application/config/version", "?"),
			"build" if OS.has_feature("template") else "fonte"
		]
	)


## Tempo no formato das referencias, `mm:ss.d`.
static func formata_tempo(segundos: float) -> String:
	var s := maxf(segundos, 0.0)
	var decimos := int(floor(s * 10.0))
	return "%02d:%02d.%d" % [decimos / 600, (decimos / 10) % 60, decimos % 10]


## Distancia restante em valor e unidade: metro perto da chegada, quilometro
## com uma casa longe dela. "2400 M" sao quatro digitos que o olho tem de
## contar; "2.4 KM" se le de relance.
static func formata_distancia(metros: float) -> PackedStringArray:
	var m := maxf(metros, 0.0)
	if m >= 1000.0:
		return PackedStringArray(["%.1f" % (m / 1000.0), "KM"])
	return PackedStringArray(["%d" % int(m), "M"])


## Quantos segmentos acendem para uma fracao. Arredonda para cima: o ultimo
## segundo de prazo ainda e um segmento aceso, e a barra so apaga de vez
## quando o tempo acabou mesmo.
static func segmentos_acesos(fracao: float, total: int) -> int:
	return clampi(ceili(clampf(fracao, 0.0, 1.0) * total - 0.001), 0, total)


func bind(a_run: RaceRun, a_player: PlayerBike) -> void:
	run = a_run
	player = a_player
	# A lista de teclas some depois da largada: no meio do transito ela vira
	# ruido em cima da pista.
	_hint_time = 7.0
	_last_position = a_run.position


func show_event(text: String, color: Color) -> void:
	_evento_texto = text
	_evento_cor = color
	_event_time = 1.6


func _process(delta: float) -> void:
	# Com o pixel desligado o SubViewport cresce para a resolucao da janela.
	# A HUD acompanha em multiplo inteiro, para o pixel da fonte continuar
	# quadrado, e o layout continua sendo o de 640x360.
	var tela := get_viewport().get_visible_rect().size
	var k := maxi(int(floor(tela.y / ALTURA)), 1)
	scale = Vector2(k, k)
	_painel.size = (tela / k).floor()

	if run == null or player == null:
		return

	# Pisca por um instante na troca de posicao. O aviso de texto some em 1,6 s,
	# e sem o pisca a unica coisa que marca uma ultrapassagem e um numero que
	# muda no canto sem ninguem olhar.
	if run.position != _last_position:
		_position_flash = 0.6
		_last_position = run.position
	_position_flash = maxf(_position_flash - delta, 0.0)

	if run.combo >= 2:
		_combo_flash = 0.35
		_combo_texto = "CORREDOR x%d" % run.combo
	_combo_flash = maxf(_combo_flash - delta, 0.0)
	_event_time = maxf(_event_time - delta, 0.0)
	_hint_time = maxf(_hint_time - delta, 0.0)

	_painel.queue_redraw()


func _desenha() -> void:
	if run == null or player == null:
		return
	var tela := Vector2i(_painel.size)
	var direita := tela.x - MARGEM.x
	var alto_legenda := fonte_legenda.altura
	var alto_valor := fonte_valor.altura

	# --- Topo esquerdo: POS e as estrelas.
	var y := MARGEM.y
	fonte_legenda.desenhar(_painel, Vector2i(MARGEM.x, y), "POS")
	y += alto_legenda + 5
	var cor_pos := Color(1.0, 0.9, 0.4) if _position_flash > 0.0 else Color.WHITE
	fonte_valor.desenhar(_painel, Vector2i(MARGEM.x, y), run.position_text(), cor_pos)
	y += alto_valor + 6
	var estrelas := run.stars()
	var x := MARGEM.x
	for i in ESTRELAS:
		var cor := Color.WHITE if i < estrelas else Color(0.35, 0.35, 0.4)
		fonte_legenda.desenhar(_painel, Vector2i(x, y), "*", cor)
		x += fonte_legenda.largura("*") + 2

	# A adrenalina, embaixo das estrelas: barra curta, de uma cor so, porque
	# nao e medidor de perigo como SPEED e TIME, e tanque. Ja foi borda
	# pontilhada em volta da tela, e lia como moldura de outro jogo; aqui ela
	# fala a mesma lingua das outras duas barras.
	y += alto_legenda + 6
	fonte_legenda.desenhar(_painel, Vector2i(MARGEM.x, y), "BOOST")
	var cor_boost := COR_BOOST_QUEIMANDO if player.boosting else COR_BOOST
	_barra(
		Vector2i(MARGEM.x + fonte_legenda.largura("BOOST") + 6, y - 1),
		Vector2i(LARGURA_BOOST, ALTURA_BOOST),
		SEGMENTOS_BOOST,
		player.adrenaline / 100.0,
		[cor_boost]
	)

	# --- Topo direito: distancia restante, valor e unidade na mesma base.
	y = MARGEM.y
	fonte_legenda.desenhar(_painel, Vector2i(direita - fonte_legenda.largura("DIST"), y), "DIST")
	y += alto_legenda + 5
	var dist := formata_distancia(run.distance_total - run.distance_done)
	_valor_com_unidade(direita, y, dist[0], dist[1], true)

	# --- Baixo: as duas barras e o que fica em cima delas.
	var y_barra := tela.y - MARGEM.y - ALTURA_BARRA
	var y_valor := y_barra - 6 - alto_valor
	var y_legenda := y_valor - 5 - alto_legenda

	fonte_legenda.desenhar(_painel, Vector2i(MARGEM.x, y_legenda), "SPEED")
	_valor_com_unidade(MARGEM.x, y_valor, "%d" % roundi(player.speed_kmh()), "KM/H", false)
	var fracao_speed := player.speed / maxf(player.tuning.max_speed, 0.01)
	_barra(
		Vector2i(MARGEM.x, y_barra),
		Vector2i(LARGURA_BARRA, ALTURA_BARRA),
		SEGMENTOS_SPEED,
		fracao_speed,
		CORES_BARRA
	)

	var x_time := direita - LARGURA_BARRA
	fonte_legenda.desenhar(_painel, Vector2i(x_time, y_legenda), "TIME")
	var texto_tempo := "ATRASADO" if run.late else formata_tempo(run.time_left)
	var apertado := run.late or run.time_left < PRAZO_APERTADO
	var cor_tempo := Color(1.0, 0.35, 0.3) if apertado else Color.WHITE
	fonte_valor.desenhar(_painel, Vector2i(x_time, y_valor), texto_tempo, cor_tempo)
	var fracao_tempo := 0.0 if run.late else run.time_left / maxf(run.time_total, 0.01)
	_barra(
		Vector2i(x_time, y_barra),
		Vector2i(LARGURA_BARRA, ALTURA_BARRA),
		SEGMENTOS_TIME,
		fracao_tempo,
		CORES_BARRA
	)

	# O carimbo fica no rodape, embaixo da barra do TIME: sempre ali, e tao
	# apagado que so quem procura ve.
	var carimbo := carimbo_versao()
	fonte_miuda.desenhar(
		_painel,
		Vector2i(direita - fonte_miuda.largura(carimbo), tela.y - MARGEM.y + 4),
		carimbo,
		Color(0.8, 0.83, 0.9, 0.75)
	)

	# --- Centro alto: avisos que aparecem e somem. Nao no meio da tela: ali e
	# onde a pista a frente aparece, e texto em cima do corredor tapa o carro
	# que voce vai ter que desviar.
	if _event_time > 0.0:
		_centralizado(fonte_miuda, MARGEM.y, _evento_texto, _evento_cor)
	# Combo e contramao dividem o lugar: quase nunca coincidem, e quando
	# coincidem a contramao ganha.
	var y_aviso := MARGEM.y + alto_legenda + 8
	if player.wrong_way:
		_centralizado(fonte_valor, y_aviso, "CONTRAMAO", Color(1.0, 0.35, 0.3))
	elif _combo_flash > 0.0:
		_centralizado(fonte_valor, y_aviso, _combo_texto, Color(1.0, 0.9, 0.4))

	if _hint_time > 0.0:
		_centralizado(
			fonte_miuda,
			y_legenda - alto_legenda - 10,
			"WASD  Q/E SOCO  SHIFT BOOST  R REINICIA  ESC MENU",
			Color(0.75, 0.8, 0.9)
		)


func _centralizado(fonte: FonteHud, y: int, texto: String, cor: Color) -> void:
	var x := (int(_painel.size.x) - fonte.largura(texto)) / 2
	fonte.desenhar(_painel, Vector2i(x, y), texto, cor)


## Numero grande e unidade miuda apoiados na mesma linha de base, como o
## "128 km/h" das referencias. `ancora_direita` diz se `x` e onde o bloco
## termina, para o canto direito.
func _valor_com_unidade(
	x: int, y: int, valor: String, unidade: String, ancora_direita: bool
) -> void:
	var vao := 4
	var largura_valor := fonte_valor.largura(valor)
	var largura_total := largura_valor + vao + fonte_miuda.largura(unidade)
	var inicio := x - largura_total if ancora_direita else x
	fonte_valor.desenhar(_painel, Vector2i(inicio, y), valor)
	var y_unidade := y + fonte_valor.altura - fonte_miuda.altura
	fonte_miuda.desenhar(_painel, Vector2i(inicio + largura_valor + vao, y_unidade), unidade)


## A barra segmentada: moldura clara de canto cortado, fundo escuro, um
## retangulo por segmento. Segmento discreto e o que faz ela ler como medidor
## de arcade e nao como barra de carregamento. `cores` sao os degraus, da
## esquerda para a direita.
func _barra(pos: Vector2i, tamanho: Vector2i, segmentos: int, fracao: float, cores: Array) -> void:
	var w := tamanho.x
	var h := tamanho.y
	# Canto cortado de 1 px: o "arredondado" possivel em pixel.
	_painel.draw_rect(Rect2(pos.x + 1, pos.y, w - 2, h), COR_MOLDURA)
	_painel.draw_rect(Rect2(pos.x, pos.y + 1, w, h - 2), COR_MOLDURA)
	_painel.draw_rect(Rect2(pos.x + 1, pos.y + 1, w - 2, h - 2), COR_FUNDO_BARRA)

	var vao := 2
	var dentro := Rect2i(pos.x + 3, pos.y + 3, w - 6, h - 6)
	var largura_seg := (dentro.size.x - (segmentos - 1) * vao) / segmentos
	# A sobra da divisao inteira vai para a margem esquerda, para a barra
	# ficar centrada na moldura em vez de terminar com um vao torto.
	var sobra := dentro.size.x - (largura_seg * segmentos + (segmentos - 1) * vao)
	var x := dentro.position.x + sobra / 2
	var acesos := segmentos_acesos(fracao, segmentos)
	for i in segmentos:
		var degrau := i * cores.size() / segmentos
		var cor: Color = cores[degrau] if i < acesos else COR_APAGADO
		var r := Rect2(x, dentro.position.y, largura_seg, dentro.size.y)
		_painel.draw_rect(r, cor)
		# Um fio claro no topo do segmento aceso: o chanfro que faz o segmento
		# parecer lampada e nao tinta.
		if i < acesos:
			_painel.draw_rect(Rect2(x, dentro.position.y, largura_seg, 1), cor.lightened(0.45))
		x += largura_seg + vao
