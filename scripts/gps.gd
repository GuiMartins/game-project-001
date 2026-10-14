class_name Gps
extends Control
## O GPS de celular da `04_vertical` (V25a): o elemento da HUD que mais diz
## "entregador de app".
##
## Quarteiroes azul-acinzentados, ruas em branco por cima, e a seta vermelha
## parada um pouco abaixo do meio, apontando para cima: o mapa gira em volta
## dela (*heading-up*), e nao ela no mapa. E assim que o GPS de quem esta
## pilotando funciona, e e o que faz a transversal passar por ele no mesmo
## instante em que o cruzamento passa na tela.
##
## Le so a `RoadTrack`: a avenida e a curva, as transversais sao os
## `cruzamentos` com a `boca`. Outra pista ou outra cidade usa o mesmo mapa sem
## mudar codigo. Nao ha rota desenhada: a corrida e uma reta de A a B, e uma
## linha em cima da avenida so repetiria a avenida.
##
## Os rivais aparecem como um ponto na cor da bag de cada um: o mapa e o
## unico lugar da tela que mostra quem vem colado atras, e a bag e o que
## separa um rival do outro na pista tambem. Quem esta longe sai do recorte, e
## e o certo: o `POS` ja diz a colocacao, o mapa diz quem esta por perto.
##
## Desenhado em 2D, no proprio `Control`, com recorte: sem camera nem
## `SubViewport` a mais. E dentro da HUD, entao fica fora da medida do `shots`.

## O lado do mapa a 640x360, sem a moldura.
const LADO: int = 72
## Metros por pixel. Com 2,4 o mapa mostra uns 170 m de cidade: duas ou tres
## transversais, que sao 70 a 160 m uma da outra (`Cidade`). Mais perto, o
## cruzamento passaria pelo mapa em dois segundos, a 120 km/h, e mais longe a
## avenida de 13 m viraria um fio.
const METROS_POR_PIXEL: float = 2.4
## Onde fica a seta, em fracao da altura: abaixo do meio, porque o que importa
## e o que vem pela frente, e nao o que ja passou.
const SETA_EM: float = 0.65
## Quanto da avenida e amostrado para tras e para a frente da moto, e de
## quantos em quantos metros. A diagonal do mapa sao 120 m de cada lado da
## seta, com folga.
const ATRAS: float = 140.0
const FRENTE: float = 200.0
const PASSO: float = 6.0
## Ate onde a transversal vai, da beira da avenida para fora.
const RUA_COMPRIMENTO: float = 160.0
## As ruas de tras, paralelas a avenida, a estes metros do meio-fio. Nao
## existem no mundo: atras da fachada o mundo acaba (`RoadTrack.GROUND`). Mas
## sem elas o mapa e uma linha e dois tracos, e o que faz ele ler como GPS e o
## xadrez de quarteiroes da `04`. Mais finas que as transversais, para a
## avenida e as ruas de verdade continuarem mandando no desenho.
const PARALELAS: Array[float] = [55.0, 125.0]
const PARALELA_LARGURA: float = 2.0

## A moldura e da mesma lingua das barras (`Hud.COR_MOLDURA`), mais grossa:
## 2 px de claro com o contorno preto por fora.
const MOLDURA: int = 2
const COR_QUARTEIRAO := Color(0.34, 0.41, 0.53)
const COR_RUA := Color(0.93, 0.94, 0.96)
const COR_SETA := Color(0.92, 0.12, 0.10)
const COR_CONTORNO := Color(0.03, 0.03, 0.05)
## O ponto do rival: 3 px de cor com 1 px de contorno. Menor que a seta, que
## e voce e tem de mandar no mapa.
const RIVAL: int = 3

var track: RoadTrack
var player: Node3D
## Quem mais corre: precisa de `global_position` e `bag_color`.
var rivais: Array = []
## O ponto da avenida em que a moto esta, de um quadro para o outro: e o
## palpite da `RoadTrack.project`, que e busca local.
var progresso: float = 0.0


func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(LADO + MOLDURA * 2, LADO + MOLDURA * 2)
	size = custom_minimum_size


## Comeca de novo numa pista: o palpite volta para o comeco dela.
func ligar(a_track: RoadTrack, a_player: Node3D, a_rivais: Array = []) -> void:
	track = a_track
	player = a_player
	rivais = a_rivais
	progresso = 0.0


## Onde um ponto do mundo cai no mapa, em pixels do `Control`. `frente` e
## `direita` sao da moto, no plano do chao.
static func no_mapa(
	ponto: Vector3, moto: Vector3, frente: Vector3, direita: Vector3, centro: Vector2
) -> Vector2:
	var d := ponto - moto
	return centro + Vector2(d.dot(direita), -d.dot(frente)) / METROS_POR_PIXEL


func _process(_delta: float) -> void:
	if track == null or player == null:
		return
	progresso = track.project(player.global_position, progresso).x
	queue_redraw()


func _draw() -> void:
	var dentro := Rect2(MOLDURA, MOLDURA, LADO, LADO)
	draw_rect(Rect2(Vector2.ZERO, size), COR_CONTORNO)
	draw_rect(Rect2(1, 1, size.x - 2, size.y - 2), Hud.COR_MOLDURA)
	draw_rect(dentro, COR_QUARTEIRAO)
	if track == null or player == null:
		return

	# A frente da moto, deitada no chao: a camera segue o rumo, e o mapa
	# tambem. -Z e a frente no corpo de toda moto.
	var frente := -player.global_basis.z
	frente.y = 0.0
	frente = frente.normalized() if frente.length_squared() > 1e-6 else Vector3.FORWARD
	var direita := frente.cross(Vector3.UP)
	var moto := player.global_position
	var centro := dentro.position + Vector2(LADO * 0.5, LADO * SETA_EM)

	# As paralelas, por baixo de tudo: so seguem a curva da avenida, mais
	# para fora.
	for distancia in PARALELAS:
		for lado: float in [-1.0, 1.0]:
			var paralela := PackedVector2Array()
			var p := maxf(progresso - ATRAS, 0.0)
			var fim_p := minf(progresso + FRENTE, track.length)
			var lateral := (RoadTrack.sidewalk_limit() + distancia) * lado
			while p <= fim_p:
				paralela.append(no_mapa(track.point(p, lateral), moto, frente, direita, centro))
				p += PASSO * 2.0
			if paralela.size() >= 2:
				draw_polyline(paralela, COR_RUA, PARALELA_LARGURA)

	# Transversais depois: a avenida passa por cima delas, e a boca fica
	# limpa.
	var meia_rua := maxf(track.boca, 1.0)
	for c in track.cruzamentos:
		if c.x < progresso - ATRAS or c.x > progresso + FRENTE:
			continue
		for lado: float in [-1.0, 1.0]:
			if c.y != Cidade.LADO_AMBOS and c.y != lado:
				continue
			var base := track.point(c.x, RoadTrack.half_width() * lado)
			var para_fora := track.sample_basis(c.x).x * lado
			var fim := base + para_fora * RUA_COMPRIMENTO
			draw_line(
				no_mapa(base, moto, frente, direita, centro),
				no_mapa(fim, moto, frente, direita, centro),
				COR_RUA,
				meia_rua * 2.0 / METROS_POR_PIXEL
			)

	var avenida := PackedVector2Array()
	var o := maxf(progresso - ATRAS, 0.0)
	var ate := minf(progresso + FRENTE, track.length)
	while o < ate:
		avenida.append(no_mapa(track.sample_position(o), moto, frente, direita, centro))
		o += PASSO
	avenida.append(no_mapa(track.sample_position(ate), moto, frente, direita, centro))
	if avenida.size() >= 2:
		# A largura da avenida mais as calcadas: o que no mapa de celular e "a
		# rua", do meio-fio de um lado ao do outro.
		var largura := RoadTrack.sidewalk_limit() * 2.0 / METROS_POR_PIXEL
		draw_polyline(avenida, COR_RUA, largura)
		# Uma pista inteira de cidade em 7 px: o fio do meio e o que diz que
		# ela e larga, e nao uma rua como as outras.
		draw_polyline(avenida, COR_QUARTEIRAO.lerp(COR_RUA, 0.55), 1.0)

	for rival: Node3D in rivais:
		if not is_instance_valid(rival):
			continue
		var onde := no_mapa(rival.global_position, moto, frente, direita, centro).floor()
		var cor: Color = rival.get("bag_color")
		var meio := float(RIVAL / 2)
		draw_rect(Rect2(onde - Vector2.ONE * (meio + 1.0), Vector2.ONE * (RIVAL + 2)), COR_CONTORNO)
		draw_rect(Rect2(onde - Vector2.ONE * meio, Vector2.ONE * RIVAL), cor)

	# A seta por ultimo: rival colado nao pode tapar voce.
	_seta(centro)


## A seta do GPS: triangulo vermelho com o pe recortado e contorno preto, como
## a da referencia. Sem contorno ela some no branco da avenida, que passa
## sempre embaixo dela.
func _seta(ponta_em: Vector2) -> void:
	var p := ponta_em
	var contorno := PackedVector2Array(
		[p + Vector2(0, -7), p + Vector2(6, 6), p + Vector2(0, 3), p + Vector2(-6, 6)]
	)
	var miolo := PackedVector2Array(
		[p + Vector2(0, -5), p + Vector2(4, 4), p + Vector2(0, 1.5), p + Vector2(-4, 4)]
	)
	draw_colored_polygon(contorno, COR_CONTORNO)
	draw_colored_polygon(miolo, COR_SETA)
