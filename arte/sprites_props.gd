extends SceneTree
## Recorta os props do Google Flow (`arte/flow/props/*.jpg`) em
## `assets/sprites/props/<id>.png` e `.json`: arvore de copa, palmeira, poste e
## placas (2D50, 2D51 e 2D53 da `docs/MIGRACAO_2D.md`).
##
##     python3 tools/dev.py sprites-props
##
## Roda no Godot, e nao em Python, pelo mesmo motivo do `sprites_pedestres.gd`:
## o Python do sistema nao le JPEG sem Pillow.
##
## Cada prop e uma imagem so, de frente, em fundo verde (#00FF00). O que se faz
## aqui e o que se faria no editor de imagem: tirar o verde, recortar na
## silhueta, levar a altura para a medida real do objeto e gravar onde fica o pe
## (a ancora do projetor). Quem quebra e voa depois gira o sprite inteiro.

## Mesma medida comum dos pedestres: sem ela o sprite mudaria de tamanho entre
## folhas (S03 a S05 da `AUDITORIA_SPRITES.md`).
const PIXELS_POR_METRO: float = 64.0

## Um pixel e fundo quando e verde puro por esta margem. A folha de arvore tem
## verde de folha, mas nunca com vermelho e azul tao baixos e verde tao alto
## ao mesmo tempo; o JPEG so suja a borda, e isso o `_limpar_borda` trata.
const FUNDO_VERDE_MIN: float = 0.70
const FUNDO_OUTROS_MAX: float = 0.42
const FUNDO_DIFERENCA_MIN: float = 0.40
## Alpha menor que isto some depois de reduzir: borda dura, como no resto do
## jogo, e nao um halo meio verde.
const CORTE_ALPHA: float = 0.5
## O pe e achado nas linhas de baixo da silhueta, pela media do x: pe de poste
## e de tronco com raiz aberta nao e um pixel so.
const FRACAO_PE: float = 0.03

const ORIGEM: String = "res://arte/flow/props/"
const SAIDA: String = "res://assets/sprites/props/"

## `altura_m`: altura real do objeto, do pe ao ponto mais alto. `espelho`: o
## outro lado sai do espelho dele (a placa de curva a esquerda vira a de curva a
## direita; o resto e simetrico e o projetor espelha como quiser).
const PROPS: Dictionary = {
	"copa": {"altura_m": 8.0, "espelho": ""},
	"palmeira": {"altura_m": 11.0, "espelho": ""},
	"poste":
	{
		"altura_m": 8.5,
		"espelho": "",
		# As duas lanternas, em pixels do sprite: o shader acende o vidro delas
		# de noite (`SpriteLuzes`), no lugar das lentes da malha 3D.
		"luzes":
		[
			{
				"nome": "lente_esquerda",
				"linha": 0,
				"coluna": 0,
				"ponto": [45, 136],
				"raio": 16,
				"so_de_noite": true
			},
			{
				"nome": "lente_direita",
				"linha": 0,
				"coluna": 0,
				"ponto": [235, 136],
				"raio": 16,
				"so_de_noite": true
			},
		],
	},
	"placa_curva": {"altura_m": 3.2, "espelho": "placa_curva_dir"},
	"placa_mao_dupla": {"altura_m": 3.2, "espelho": ""},
}


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA))
	var falhou := false
	for id: String in PROPS:
		if not _recortar(id, PROPS[id]):
			falhou = true
	quit(1 if falhou else 0)


func _recortar(id: String, ficha: Dictionary) -> bool:
	var imagem := Image.load_from_file(ProjectSettings.globalize_path(ORIGEM + id + ".jpg"))
	if imagem == null or imagem.is_empty():
		push_error("props: sem %s%s.jpg" % [ORIGEM, id])
		return false
	imagem.convert(Image.FORMAT_RGBA8)
	_tirar_fundo(imagem)
	var caixa := _caixa(imagem)
	if caixa.size.y < 50:
		push_error("props: %s sem silhueta (fundo nao era verde?)" % id)
		return false
	var recorte := imagem.get_region(caixa)
	var altura := int(round(float(ficha["altura_m"]) * PIXELS_POR_METRO))
	var largura := int(round(float(recorte.get_width()) * altura / recorte.get_height()))
	recorte.resize(largura, altura, Image.INTERPOLATE_LANCZOS)
	_endurecer_alpha(recorte)
	_limpar_borda(recorte)
	var pe := _pe(recorte)
	recorte.save_png(ProjectSettings.globalize_path(SAIDA + id + ".png"))
	_gravar_ficha(id, ficha, recorte.get_size(), pe)
	if ficha["espelho"] != "":
		var lado := recorte.duplicate() as Image
		lado.flip_x()
		lado.save_png(ProjectSettings.globalize_path(SAIDA + String(ficha["espelho"]) + ".png"))
		_gravar_ficha(
			String(ficha["espelho"]), ficha, recorte.get_size(), Vector2i(largura - pe.x, pe.y)
		)
	print("props: %s %dx%d pe=%s" % [id, largura, altura, pe])
	return true


func _eh_fundo(cor: Color) -> bool:
	var outros := maxf(cor.r, cor.b)
	return (
		cor.g >= FUNDO_VERDE_MIN
		and outros <= FUNDO_OUTROS_MAX
		and cor.g - outros >= FUNDO_DIFERENCA_MIN
	)


func _tirar_fundo(imagem: Image) -> void:
	for y in imagem.get_height():
		for x in imagem.get_width():
			if _eh_fundo(imagem.get_pixel(x, y)):
				imagem.set_pixel(x, y, Color(0, 0, 0, 0))


## A caixa dos pixels que sobraram, sem as ilhas de sujeira do JPEG: so conta a
## linha ou coluna com mais que um punhado de pixels.
func _caixa(imagem: Image) -> Rect2i:
	var w := imagem.get_width()
	var h := imagem.get_height()
	var colunas := PackedInt32Array()
	colunas.resize(w)
	var linhas := PackedInt32Array()
	linhas.resize(h)
	for y in h:
		for x in w:
			if imagem.get_pixel(x, y).a > 0.5:
				colunas[x] += 1
				linhas[y] += 1
	var x0 := 0
	var x1 := w - 1
	var y0 := 0
	var y1 := h - 1
	while x0 < w and colunas[x0] < 3:
		x0 += 1
	while x1 > x0 and colunas[x1] < 3:
		x1 -= 1
	while y0 < h and linhas[y0] < 3:
		y0 += 1
	while y1 > y0 and linhas[y1] < 3:
		y1 -= 1
	return Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1)


func _endurecer_alpha(imagem: Image) -> void:
	for y in imagem.get_height():
		for x in imagem.get_width():
			var cor := imagem.get_pixel(x, y)
			cor.a = 1.0 if cor.a >= CORTE_ALPHA else 0.0
			imagem.set_pixel(x, y, cor)


## Quem encosta no fundo herda um verde do JPEG e da reducao. Puxa o verde
## desses pixels para o maior dos outros dois canais, so um pouco acima: a folha
## continua folha e some a franja neon.
func _limpar_borda(imagem: Image) -> void:
	var w := imagem.get_width()
	var h := imagem.get_height()
	for y in h:
		for x in w:
			var cor := imagem.get_pixel(x, y)
			if cor.a == 0.0 or not _na_borda(imagem, x, y, w, h):
				continue
			var teto := maxf(cor.r, cor.b) + 0.08
			if cor.g > teto:
				cor.g = teto
				imagem.set_pixel(x, y, cor)


func _na_borda(imagem: Image, x: int, y: int, w: int, h: int) -> bool:
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var vx := x + d.x
		var vy := y + d.y
		if vx < 0 or vy < 0 or vx >= w or vy >= h or imagem.get_pixel(vx, vy).a == 0.0:
			return true
	return false


func _pe(imagem: Image) -> Vector2i:
	var h := imagem.get_height()
	var topo := int(h * (1.0 - FRACAO_PE))
	var soma := 0
	var n := 0
	for y in range(topo, h):
		for x in imagem.get_width():
			if imagem.get_pixel(x, y).a > 0.0:
				soma += x
				n += 1
	var x_pe := int(round(float(soma) / n)) if n > 0 else imagem.get_width() / 2
	return Vector2i(x_pe, h - 1)


func _gravar_ficha(id: String, ficha: Dictionary, tamanho: Vector2i, pe: Vector2i) -> void:
	var dados := {
		"altura_m": ficha["altura_m"],
		"largura_m": snappedf(tamanho.x / PIXELS_POR_METRO, 0.01),
		"tamanho": [tamanho.x, tamanho.y],
		"pe": [pe.x, pe.y],
		"pixels_por_metro": PIXELS_POR_METRO,
		"angulo": "frente",
	}
	if ficha.has("luzes"):
		dados["luzes"] = ficha["luzes"]
	var arquivo := FileAccess.open(
		ProjectSettings.globalize_path(SAIDA + id + ".json"), FileAccess.WRITE
	)
	arquivo.store_string(JSON.stringify(dados, "\t", true) + "\n")
