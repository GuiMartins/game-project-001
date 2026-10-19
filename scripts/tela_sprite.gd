class_name TelaSprite
extends Control
## A folha em 2D, em pixel inteiro e sem filtro: o que o artista desenhou, sem o
## jogo no meio. Mostra um quadro ou a folha toda, com a grade da celula, a
## linha do chao, o ponto do pe, a regua de altura e a caixa do que foi medido.

signal celula_escolhida(coluna: int, linha: int)
## O zoom mudou pela roda do mouse; quem mostra o numero acompanha.
signal zoom_alterado(valor: int)

enum Vista { QUADRO, FOLHA }
enum Fundo { CINZA, ASFALTO, CALCADA, BRANCO, PRETO }

const COR_FUNDO: Dictionary[int, Color] = {
	Fundo.CINZA: Color(0.36, 0.37, 0.39),
	Fundo.BRANCO: Color(1.0, 1.0, 1.0),
	Fundo.PRETO: Color(0.0, 0.0, 0.0),
}
const TEXTURAS: Dictionary[int, Texture2D] = {
	Fundo.ASFALTO: preload("res://assets/visual/asfalto_albedo.png"),
	Fundo.CALCADA: preload("res://assets/visual/calcada_albedo.png"),
}
## O mesmo tom que o shader do sprite poe por cima de noite (`luz_da_noite`).
const LUZ_DA_NOITE := Color(0.24, 0.25, 0.32)
const COR_CHAO := Color(0.2, 0.9, 0.3, 0.9)
const COR_PE := Color(1.0, 0.25, 0.25)
const COR_REGUA := Color(1.0, 0.85, 0.2, 0.95)
const COR_GRADE := Color(1.0, 1.0, 1.0, 0.35)
const COR_CAIXA := Color(0.3, 0.7, 1.0, 0.95)
const COR_ESCOLHIDA := Color(1.0, 0.85, 0.2, 1.0)
const ZOOM_MAX: int = 16

var item: CatalogoSprites.Item:
	set(valor):
		item = valor
		_textura = item.textura() if item != null else null
		queue_redraw()
var vista: int = Vista.QUADRO:
	set(valor):
		vista = valor
		queue_redraw()
var coluna: int = 0:
	set(valor):
		coluna = valor
		queue_redraw()
var linha: int = 0:
	set(valor):
		linha = valor
		queue_redraw()
var espelhar: bool = false:
	set(valor):
		espelhar = valor
		queue_redraw()
## 0 e "o maior que cabe"; de 1 em diante, o aumento fixo.
var zoom: int = 0:
	set(valor):
		zoom = clampi(valor, 0, ZOOM_MAX)
		queue_redraw()
var fundo: int = Fundo.CINZA:
	set(valor):
		fundo = valor
		queue_redraw()
var noite: bool = false:
	set(valor):
		noite = valor
		queue_redraw()
var grade: bool = true:
	set(valor):
		grade = valor
		queue_redraw()
var chao: bool = true:
	set(valor):
		chao = valor
		queue_redraw()
var regua: bool = true:
	set(valor):
		regua = valor
		queue_redraw()
var caixa: bool = false:
	set(valor):
		caixa = valor
		queue_redraw()

var _textura: Texture2D
## Onde a folha cai na tela e com que aumento, para o clique achar a celula.
var _origem := Vector2.ZERO
var _escala: float = 1.0


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true
	focus_mode = Control.FOCUS_CLICK


func _gui_input(evento: InputEvent) -> void:
	if evento is InputEventMouseButton and evento.pressed:
		var botao := evento as InputEventMouseButton
		match botao.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				zoom = maxi(zoom, int(_escala)) + 1
				zoom_alterado.emit(zoom)
				accept_event()
			MOUSE_BUTTON_WHEEL_DOWN:
				zoom = maxi(maxi(zoom, int(_escala)) - 1, 1)
				zoom_alterado.emit(zoom)
				accept_event()
			MOUSE_BUTTON_LEFT:
				if vista == Vista.FOLHA and item != null:
					_escolhe_celula(botao.position)
					accept_event()


func _escolhe_celula(ponto: Vector2) -> void:
	var local := (ponto - _origem) / _escala
	if item.celula.x <= 0 or item.celula.y <= 0:
		return
	var c := floori(local.x / item.celula.x)
	var l := floori(local.y / item.celula.y)
	if c >= 0 and c < item.colunas and l >= 0 and l < item.linhas:
		celula_escolhida.emit(c, l)


func _draw() -> void:
	_desenha_fundo()
	if item == null or _textura == null or item.celula == Vector2i.ZERO:
		_texto(Vector2(12, 24), "sem folha para mostrar", Color.WHITE)
		return
	var tamanho_fonte := (
		Vector2(item.celula) if vista == Vista.QUADRO else Vector2(item.tamanho_imagem)
	)
	_escala = _escala_para(tamanho_fonte)
	var tinta := LUZ_DA_NOITE if noite else Color.WHITE
	if vista == Vista.QUADRO:
		_desenha_quadro(tinta)
	else:
		_desenha_folha(tinta)
	var rodape := "x%d   quadro %d/%d" % [int(_escala), coluna + 1, item.colunas]
	if item.linhas > 1 and linha < item.rotulos_linhas.size():
		rodape += "   %s" % item.rotulos_linhas[linha]
	if espelhar:
		rodape += "   espelhado"
	_texto(Vector2(12, size.y - 12), rodape, Color.WHITE)


func _escala_para(fonte: Vector2) -> float:
	if zoom > 0:
		return float(zoom)
	# Folga para as bordas e o texto, e inteiro: pixel meio pixel borra.
	var cabe := minf((size.x - 24.0) / fonte.x, (size.y - 48.0) / fonte.y)
	return maxf(floorf(cabe), 1.0)


func _desenha_fundo() -> void:
	if TEXTURAS.has(fundo):
		draw_texture_rect(TEXTURAS[fundo], Rect2(Vector2.ZERO, size), true)
	else:
		draw_rect(Rect2(Vector2.ZERO, size), COR_FUNDO[fundo])


func _desenha_quadro(tinta: Color) -> void:
	var celula := Vector2(item.celula)
	_origem = ((size - celula * _escala) * 0.5).floor()
	var fonte := Rect2(Vector2(coluna, linha) * celula, celula)
	var destino := Rect2(_origem, celula * _escala)
	if espelhar:
		draw_set_transform(
			Vector2(destino.position.x * 2.0 + destino.size.x, 0.0), 0.0, Vector2(-1, 1)
		)
	draw_texture_rect_region(_textura, destino, fonte, tinta)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if grade:
		draw_rect(destino, COR_GRADE, false, 1.0)
	if chao:
		var y := _origem.y + (item.pe.y + 1) * _escala
		draw_line(Vector2(0.0, y), Vector2(size.x, y), COR_CHAO, 1.0)
	if regua and item.altura_px > 0.0:
		_desenha_regua()
	if caixa:
		var uso := item.caixa(coluna, linha)
		if uso.size != Vector2i.ZERO:
			var x0 := uso.position.x
			if espelhar:
				x0 = item.celula.x - uso.end.x
			draw_rect(
				Rect2(_origem + Vector2(x0, uso.position.y) * _escala, Vector2(uso.size) * _escala),
				COR_CAIXA,
				false,
				1.0
			)
	# O pe por cima de tudo, para nao sumir debaixo do sprite.
	var pe := _origem + (Vector2(item.pe) + Vector2(0.5, 1.0)) * _escala
	draw_line(pe - Vector2(8, 0), pe + Vector2(8, 0), COR_PE, 2.0)
	draw_line(pe - Vector2(0, 8), pe + Vector2(0, 8), COR_PE, 2.0)


## A regua ao lado do pe: a altura que a ficha diz que a pessoa tem, em escala.
## Se o desenho passa dela ou fica aquem, o sprite esta no tamanho errado.
func _desenha_regua() -> void:
	var x := _origem.x + (item.pe.x - item.celula.x * 0.42) * _escala
	var base := _origem.y + (item.pe.y + 1) * _escala
	var topo := base - item.altura_px * _escala
	draw_line(Vector2(x, base), Vector2(x, topo), COR_REGUA, 2.0)
	draw_line(Vector2(x - 5, topo), Vector2(x + 5, topo), COR_REGUA, 2.0)
	var rotulo := "%.2f m" % item.altura_m if item.altura_m > 0.0 else "piloto reto"
	_texto(Vector2(x + 8, topo + 14), rotulo, COR_REGUA)


func _desenha_folha(tinta: Color) -> void:
	var total := Vector2(item.tamanho_imagem) * _escala
	_origem = ((size - total) * 0.5).floor()
	draw_texture_rect(_textura, Rect2(_origem, total), false, tinta)
	var celula := Vector2(item.celula) * _escala
	if grade:
		for c in item.colunas + 1:
			var x := _origem.x + c * celula.x
			draw_line(Vector2(x, _origem.y), Vector2(x, _origem.y + total.y), COR_GRADE, 1.0)
		for l in item.linhas + 1:
			var y := _origem.y + l * celula.y
			draw_line(Vector2(_origem.x, y), Vector2(_origem.x + total.x, y), COR_GRADE, 1.0)
	if chao:
		for l in item.linhas:
			var y := _origem.y + l * celula.y + (item.pe.y + 1) * _escala
			draw_line(Vector2(_origem.x, y), Vector2(_origem.x + total.x, y), COR_CHAO, 1.0)
	if caixa:
		for l in item.linhas:
			for c in item.colunas:
				var uso := item.caixa(c, l)
				if uso.size != Vector2i.ZERO:
					var dono := Vector2(c, l) * celula
					draw_rect(
						Rect2(
							_origem + dono + Vector2(uso.position) * _escala,
							Vector2(uso.size) * _escala
						),
						COR_CAIXA,
						false,
						1.0
					)
	var atual := Rect2(_origem + Vector2(coluna, linha) * celula, celula)
	draw_rect(atual, COR_ESCOLHIDA, false, 2.0)


func _texto(onde: Vector2, texto: String, cor: Color) -> void:
	var fonte := get_theme_default_font()
	# Sombra de um pixel: o texto passa por cima de fundo claro e escuro.
	draw_string(fonte, onde + Vector2(1, 1), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.BLACK)
	draw_string(fonte, onde, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, cor)
