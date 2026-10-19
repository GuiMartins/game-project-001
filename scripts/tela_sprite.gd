class_name TelaSprite
extends Control
## A folha em 2D, em pixel inteiro e sem filtro: o que o artista desenhou, sem o
## jogo no meio. Cinco vistas:
##
## - QUADRO: um quadro, com a grade da celula, a linha do chao, o ponto do pe,
##   a regua de altura e a caixa do que foi medido;
## - FOLHA: o atlas todo, com os quadros que a analise marcou em vermelho;
## - REFERENCIA: o quadro ao lado do boneco 3D que foi ao Flow, e a
##   sobreposicao das duas silhuetas (o que o IoU enxerga);
## - BASE: a folha que se fixou antes, a de agora e o que mudou;
## - DUAS: o mesmo quadro de duas folhas, no mesmo chao e na mesma escala.

signal celula_escolhida(coluna: int, linha: int)
## O zoom mudou pela roda do mouse; quem mostra o numero acompanha.
signal zoom_alterado(valor: int)

enum Vista { QUADRO, FOLHA, REFERENCIA, BASE, DUAS }
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
## O verde em que o Flow desenhou, para a referencia aparecer como foi enviada.
const VERDE_DO_FLOW := Color(0.0, 1.0, 0.0)
const COR_CHAO := Color(0.2, 0.9, 0.3, 0.9)
const COR_PE := Color(1.0, 0.25, 0.25)
const COR_REGUA := Color(1.0, 0.85, 0.2, 0.95)
const COR_GRADE := Color(1.0, 1.0, 1.0, 0.35)
const COR_CAIXA := Color(0.3, 0.7, 1.0, 0.95)
const COR_ESCOLHIDA := Color(1.0, 0.85, 0.2, 1.0)
const COR_AVISO := Color(1.0, 0.3, 0.25, 1.0)
## A sobreposicao: so a referencia, so a folha, as duas.
const COR_SO_REFERENCIA := Color(1.0, 0.3, 0.3)
const COR_SO_FOLHA := Color(0.3, 0.8, 1.0)
const COR_AS_DUAS := Color(0.95, 0.95, 0.95)
const ZOOM_MAX: int = 16
const MARGEM: float = 12.0

var item: CatalogoSprites.Item:
	set(valor):
		item = valor
		_textura = item.textura() if item != null else null
		_limpa_cache()
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
## A folha com quem comparar na vista DUAS.
var outro: CatalogoSprites.Item:
	set(valor):
		outro = valor
		_textura_outro = outro.textura() if outro != null else null
		queue_redraw()
## A folha de base, inteira, para a vista BASE (null se nao ha).
var base: Image:
	set(valor):
		base = valor
		_limpa_cache()
		queue_redraw()
## A referencia do quadro de agora quando ela nao vem de uma folha pronta (a
## moto, que o testador renderiza do modelo 3D): so a celula, sem o fundo.
var referencia_extra: Image:
	set(valor):
		referencia_extra = valor
		_limpa_cache()
		queue_redraw()

var _textura: Texture2D
var _textura_outro: Texture2D
## Onde a folha cai na tela e com que aumento, para o clique achar a celula.
var _origem := Vector2.ZERO
var _escala: float = 1.0
## Texturas montadas a partir de imagens, por chave: refazer a cada `_draw`
## alocaria na GPU a cada quadro.
var _cache: Dictionary = {}


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


func _limpa_cache() -> void:
	_cache.clear()


# --- desenho ---------------------------------------------------------------


func _draw() -> void:
	_desenha_fundo(Rect2(Vector2.ZERO, size))
	if item == null or _textura == null or item.celula == Vector2i.ZERO:
		_texto(Vector2(12, 24), "sem folha para mostrar", Color.WHITE)
		return
	var tinta := LUZ_DA_NOITE if noite else Color.WHITE
	match vista:
		Vista.QUADRO:
			_escala = _escala_para(Vector2(item.celula))
			_desenha_quadro(tinta)
		Vista.FOLHA:
			_escala = _escala_para(Vector2(item.tamanho_imagem))
			_desenha_folha(tinta)
		Vista.REFERENCIA:
			_desenha_referencia(tinta)
		Vista.BASE:
			_desenha_base(tinta)
		Vista.DUAS:
			_desenha_duas(tinta)
	var rodape := "x%d   quadro %d/%d" % [int(_escala), coluna + 1, item.colunas]
	if item.linhas > 1 and linha < item.rotulos_linhas.size():
		rodape += "   %s" % item.rotulos_linhas[linha]
	if espelhar:
		rodape += "   espelhado"
	_texto(Vector2(12, size.y - 12), rodape, Color.WHITE)
	if vista == Vista.QUADRO:
		_desenha_notas()


func _escala_para(fonte: Vector2) -> float:
	if zoom > 0:
		return float(zoom)
	# Folga para as bordas e o texto, e inteiro: pixel meio pixel borra.
	var cabe := minf((size.x - 24.0) / fonte.x, (size.y - 48.0) / fonte.y)
	return maxf(floorf(cabe), 1.0)


func _desenha_fundo(area: Rect2) -> void:
	if TEXTURAS.has(fundo):
		draw_texture_rect(TEXTURAS[fundo], area, true)
	else:
		draw_rect(area, COR_FUNDO[fundo])


func _celula_fonte(alvo: CatalogoSprites.Item, c: int, l: int) -> Rect2:
	var celula := Vector2(alvo.celula)
	return Rect2(Vector2(c, l) * celula, celula)


## Desenha uma celula de `textura` em `destino`, espelhada se `espelhada`.
func _desenha_celula(
	textura: Texture2D, fonte: Rect2, destino: Rect2, tinta: Color, espelhada: bool
) -> void:
	if espelhada:
		draw_set_transform(
			Vector2(destino.position.x * 2.0 + destino.size.x, 0.0), 0.0, Vector2(-1, 1)
		)
	draw_texture_rect_region(textura, destino, fonte, tinta)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _desenha_quadro(tinta: Color) -> void:
	var celula := Vector2(item.celula)
	_origem = ((size - celula * _escala) * 0.5).floor()
	var destino := Rect2(_origem, celula * _escala)
	_desenha_celula(_textura, _celula_fonte(item, coluna, linha), destino, tinta, espelhar)
	if grade:
		draw_rect(destino, COR_GRADE, false, 1.0)
	if chao:
		var y := _origem.y + (item.pe.y + 1) * _escala
		draw_line(Vector2(0.0, y), Vector2(size.x, y), COR_CHAO, 1.0)
	if regua and item.altura_px > 0.0:
		_desenha_regua(_origem, item, _escala)
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
	_desenha_pe(_origem, item, _escala)


func _desenha_pe(origem: Vector2, alvo: CatalogoSprites.Item, escala: float) -> void:
	var pe := origem + (Vector2(alvo.pe) + Vector2(0.5, 1.0)) * escala
	draw_line(pe - Vector2(8, 0), pe + Vector2(8, 0), COR_PE, 2.0)
	draw_line(pe - Vector2(0, 8), pe + Vector2(0, 8), COR_PE, 2.0)


## A regua ao lado do pe: a altura que a ficha diz que a pessoa tem, em escala.
## Se o desenho passa dela ou fica aquem, o sprite esta no tamanho errado.
func _desenha_regua(origem: Vector2, alvo: CatalogoSprites.Item, escala: float) -> void:
	var x := origem.x + (alvo.pe.x - alvo.celula.x * 0.42) * escala
	var base_y := origem.y + (alvo.pe.y + 1) * escala
	var topo := base_y - alvo.altura_px * escala
	draw_line(Vector2(x, base_y), Vector2(x, topo), COR_REGUA, 2.0)
	draw_line(Vector2(x - 5, topo), Vector2(x + 5, topo), COR_REGUA, 2.0)
	var rotulo := "%.2f m" % alvo.altura_m if alvo.altura_m > 0.0 else "piloto reto"
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
	# Os quadros que a analise marcou: o problema tem endereco.
	for chave: int in item.notas_quadro:
		var dono := Vector2(chave % item.colunas, chave / item.colunas) * celula
		draw_rect(Rect2(_origem + dono, celula).grow(-1.0), COR_AVISO, false, 2.0)
	var atual := Rect2(_origem + Vector2(coluna, linha) * celula, celula)
	draw_rect(atual, COR_ESCOLHIDA, false, 2.0)


## O que a analise achou deste quadro, no canto de cima.
func _desenha_notas() -> void:
	var y := 24.0
	if not item.iou_referencia.is_empty():
		var iou := item.iou_referencia[linha * item.colunas + coluna]
		var texto := "semelhanca com a referencia: %d%%" % roundi(iou * 100.0)
		_texto(Vector2(12, y), texto, Color.WHITE)
		y += 20.0
	for nota in item.nota_do_quadro(coluna, linha):
		_texto(Vector2(12, y), "! %s" % nota, COR_AVISO.lightened(0.3))
		y += 20.0


# --- paineis ---------------------------------------------------------------


## Divide a area em `n` paineis lado a lado, com espaco em cima para o titulo.
func _paineis(n: int) -> Array[Rect2]:
	var lista: Array[Rect2] = []
	var largura := (size.x - MARGEM * (n + 1)) / n
	for i in n:
		lista.append(Rect2(MARGEM + i * (largura + MARGEM), 40.0, largura, size.y - 100.0))
	return lista


func _titulo(painel: Rect2, texto: String) -> void:
	_texto(painel.position + Vector2(0, -10), texto, Color.WHITE)


## O aumento inteiro que faz uma imagem de `tamanho` caber em `painel`.
func _cabe(painel: Rect2, tamanho: Vector2) -> float:
	if zoom > 0:
		return float(zoom)
	var s := floorf(minf(painel.size.x / tamanho.x, painel.size.y / tamanho.y))
	return maxf(s, 1.0)


func _centra(painel: Rect2, tamanho: Vector2) -> Vector2:
	return (painel.position + (painel.size - tamanho) * 0.5).floor()


func _desenha_referencia(tinta: Color) -> void:
	var paineis := _paineis(3)
	var s := _cabe(paineis[1], Vector2(item.celula))
	_escala = s
	var i := linha * item.colunas + coluna
	var ref := item.referencia
	var celula_ref: Image = null
	var silhueta_ref: Silhueta = null
	if ref != null and ref.colunas == item.colunas and ref.linhas == item.linhas:
		celula_ref = ref.celula_imagem(coluna, linha)
		silhueta_ref = ref.silhueta(coluna, linha)
	elif referencia_extra != null:
		celula_ref = referencia_extra
		silhueta_ref = Silhueta.de_imagem(referencia_extra)
	# 1. a referencia, no verde em que foi enviada.
	_titulo(paineis[0], "referencia 3D (o que foi ao Flow)")
	draw_rect(paineis[0], VERDE_DO_FLOW)
	if celula_ref != null:
		var tamanho := Vector2(celula_ref.get_size())
		var destino := Rect2(_centra(paineis[0], tamanho * s), tamanho * s)
		draw_texture_rect(_textura_da_imagem("ref", celula_ref), destino, false)
	else:
		_texto(paineis[0].position + Vector2(10, 24), "esta folha nao tem referencia", Color.BLACK)
	# 2. o quadro entregue.
	_titulo(paineis[1], "quadro entregue")
	_desenha_fundo(paineis[1])
	var celula := Vector2(item.celula)
	var destino_folha := Rect2(_centra(paineis[1], celula * s), celula * s)
	_desenha_celula(_textura, _celula_fonte(item, coluna, linha), destino_folha, tinta, espelhar)
	if chao:
		var y := destino_folha.position.y + (item.pe.y + 1) * s
		draw_line(Vector2(paineis[1].position.x, y), Vector2(paineis[1].end.x, y), COR_CHAO, 1.0)
	# 3. as duas silhuetas, esticadas na propria caixa.
	_titulo(paineis[2], "sobreposicao (vermelho: so a referencia, azul: so o quadro)")
	_desenha_fundo(paineis[2])
	var silhueta_folha: Silhueta = item.silhuetas[i] if i < item.silhuetas.size() else null
	if silhueta_ref != null and silhueta_folha != null and not silhueta_ref.vazia():
		var sobre := _textura_da_imagem("sobre", _sobreposicao(silhueta_folha, silhueta_ref))
		var maximo := Vector2(Silhueta.LARGURA, Silhueta.ALTURA)
		var g := _cabe(paineis[2], maximo)
		draw_texture_rect(sobre, Rect2(_centra(paineis[2], maximo * g), maximo * g), false)
		var iou := Silhueta.iou(silhueta_folha, silhueta_ref)
		var onde := paineis[2].position + Vector2(0, paineis[2].size.y + 18)
		_texto(onde, "semelhanca (IoU) %d%%" % roundi(iou * 100.0), Color.WHITE)
	else:
		_texto(paineis[2].position + Vector2(10, 24), "sem silhueta para comparar", Color.WHITE)
	if ref != null:
		_desenha_avisos_da_referencia(ref)


## Os avisos da propria referencia, para ver se foi ela que saiu ruim.
func _desenha_avisos_da_referencia(ref: ReferenciaSprites) -> void:
	var chave := linha * item.colunas + coluna
	var notas: PackedStringArray = ref.avisos_do_quadro.get(chave, PackedStringArray())
	var y := size.y - 34.0
	for nota in notas:
		_texto(Vector2(MARGEM, y), "! referencia: %s" % nota, COR_AVISO.lightened(0.3))
		y -= 20.0


## As silhuetas numa imagem so: so a referencia, so a folha, as duas.
func _sobreposicao(a: Silhueta, b: Silhueta) -> Image:
	var imagem := Image.create_empty(Silhueta.LARGURA, Silhueta.ALTURA, false, Image.FORMAT_RGBA8)
	for y in Silhueta.ALTURA:
		for x in Silhueta.LARGURA:
			var da_folha := a.grade[y * Silhueta.LARGURA + x] == 1
			var da_ref := b.grade[y * Silhueta.LARGURA + x] == 1
			if da_folha and da_ref:
				imagem.set_pixel(x, y, COR_AS_DUAS)
			elif da_ref:
				imagem.set_pixel(x, y, COR_SO_REFERENCIA)
			elif da_folha:
				imagem.set_pixel(x, y, COR_SO_FOLHA)
	return imagem


func _textura_da_imagem(chave: String, imagem: Image) -> ImageTexture:
	# A chave inclui o quadro: cada quadro tem a sua.
	var completa := "%s:%d:%d" % [chave, coluna, linha]
	if not _cache.has(completa):
		_cache[completa] = ImageTexture.create_from_image(imagem)
	return _cache[completa]


func _desenha_base(tinta: Color) -> void:
	var paineis := _paineis(3)
	var s := _cabe(paineis[1], Vector2(item.celula))
	_escala = s
	var celula := Vector2(item.celula)
	var titulos := ["base fixada", "agora", "o que mudou (magenta)"]
	var regioes: Array[Rect2] = []
	for i in 3:
		_titulo(paineis[i], titulos[i])
		_desenha_fundo(paineis[i])
		regioes.append(Rect2(_centra(paineis[i], celula * s), celula * s))
	_desenha_celula(_textura, _celula_fonte(item, coluna, linha), regioes[1], tinta, espelhar)
	if base == null:
		_texto(paineis[0].position + Vector2(10, 24), 'sem base: use "fixar base"', Color.WHITE)
		return
	if base.get_size() != item.tamanho_imagem:
		var aviso := "a base tem outro tamanho (%dx%d)" % [base.get_width(), base.get_height()]
		_texto(paineis[0].position + Vector2(10, 24), aviso, Color.WHITE)
		return
	var fonte := Rect2i(Vector2i(coluna, linha) * item.celula, item.celula)
	var da_folha := Image.load_from_file(ProjectSettings.globalize_path(item.caminho))
	if da_folha == null:
		return
	var da_base := base.get_region(fonte)
	var diferenca := BaseSprites.diferenca(da_base, da_folha.get_region(fonte))
	draw_texture_rect(_textura_da_imagem("base", da_base), regioes[0], false, tinta)
	draw_texture_rect(_textura_da_imagem("dif", diferenca), regioes[2], false)


func _desenha_duas(tinta: Color) -> void:
	if outro == null or _textura_outro == null:
		_texto(Vector2(12, 24), "escolha a outra folha", Color.WHITE)
		return
	var paineis := _paineis(2)
	var maior := Vector2(maxi(item.celula.x, outro.celula.x), maxi(item.celula.y, outro.celula.y))
	var s := _cabe(paineis[0], maior)
	_escala = s
	var duas: Array[CatalogoSprites.Item] = [item, outro]
	var texturas: Array[Texture2D] = [_textura, _textura_outro]
	var colunas: Array[int] = [coluna, mini(coluna, outro.colunas - 1)]
	var linhas: Array[int] = [linha, mini(linha, outro.linhas - 1)]
	# O mesmo chao nos dois: a linha de base do painel, e cada folha apoiada nela
	# pelo proprio pe. Assim a altura relativa das duas se ve a olho.
	var chao_y := paineis[0].end.y - 24.0
	for i in 2:
		var alvo := duas[i]
		var legenda := "%s   (quadro %d, linha %d)" % [alvo.nome(), colunas[i] + 1, linhas[i] + 1]
		_titulo(paineis[i], legenda)
		_desenha_fundo(paineis[i])
		# O pe da folha cai no meio do painel, e a base dele no chao comum.
		var origem := (
			Vector2(paineis[i].get_center().x - (alvo.pe.x + 0.5) * s, chao_y - (alvo.pe.y + 1) * s)
			. floor()
		)
		var destino := Rect2(origem, Vector2(alvo.celula) * s)
		_desenha_celula(
			texturas[i], _celula_fonte(alvo, colunas[i], linhas[i]), destino, tinta, espelhar
		)
		if regua and alvo.altura_px > 0.0:
			_desenha_regua(origem, alvo, s)
		_desenha_pe(origem, alvo, s)
	draw_line(Vector2(0.0, chao_y), Vector2(size.x, chao_y), COR_CHAO, 1.0)


func _texto(onde: Vector2, texto: String, cor: Color) -> void:
	var fonte := get_theme_default_font()
	# Sombra de um pixel: o texto passa por cima de fundo claro e escuro.
	draw_string(fonte, onde + Vector2(1, 1), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.BLACK)
	draw_string(fonte, onde, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, cor)
