class_name PlacaSprite
extends RefCounted
## A placa da moto em sprite (`docs/MIGRACAO_2D.md`, 2D16): o texto Mercosul de
## `Placa` desenhado por codigo sobre o quadrilatero que a ficha marca, e nao na
## folha do Flow. O Flow desenha letra de mentira e a cada quadro troca uma por
## outra; o jogo sorteia a placa de cada moto (`Placa.do_no`), e so o codigo sabe
## escrever a mesma em todos os quadros, de todos os angulos.
##
## Tres passos:
##
## 1. `acha` mede, num quadro recortado, onde o Flow pos a chapa branca;
## 2. `apaga` deixa essa chapa lisa, e a ficha do atlas guarda o quadrilatero;
## 3. `pinta` escreve o texto no quadrilatero, na hora, com a fonte de pixel
##    abaixo, que e do tamanho em que a placa chega a tela (uns 25 px de largura).
##
## Moto e piloto se escrevem para todos: nada aqui sabe de modelo.

## Chapa: pixel claro e quase sem cor. A pele e a camisa tem cor; o capacete e o
## jeans sao escuros.
const CLARO: int = 150
## Chapa na sombra do quadro: mais escura, e so vale se for um retangulo cheio
## (ver `RETANGULAR`), porque o cinza da moto tambem passa deste limiar.
const CLARO_NA_SOMBRA: int = 100
## Uma mancha e chapa se enche assim do retangulo que a contem, e tem a forma de
## placa (largura 1 a 3,5 vezes a altura).
const RETANGULAR: float = 0.7
const MAX_COLORIDO: int = 28
## Onde procurar: o quadro abaixo desta fracao da caixa do desenho, e a faixa do
## meio dele. Mais alto e a bag, e para os lados, o retrovisor.
const ABAIXO_DE: float = 0.35
const FAIXA_DO_MEIO: float = 0.45
## A janela dos tres quartos: abaixo desta fracao da altura e no terco da
## traseira.
const ABAIXO_DE_TRES_QUARTOS: float = 0.45
const TERCO_DA_TRASEIRA: float = 0.38
## Menos pixels que isto e o brilho de um cromado, e nao uma placa.
const AREA_MINIMA: int = 12
## A chapa lisa, no lugar da que o Flow desenhou.
const CHAPA := Color(0.93, 0.93, 0.92)
const AZUL := Color(0.05, 0.22, 0.58)
const TINTA := Color(0.08, 0.08, 0.09)
## A faixa azul, como fracao da altura (`Placa.FAIXA` e `Placa.ALTURA`).
const FRACAO_DA_FAIXA: float = 0.19
## Fonte de pixel 3 x 5: cada glifo e cinco linhas de tres bits, da de cima para
## a de baixo, o bit mais alto a esquerda.
const GLIFOS: Dictionary = {
	"A": [2, 5, 7, 5, 5],
	"B": [6, 5, 6, 5, 6],
	"C": [3, 4, 4, 4, 3],
	"D": [6, 5, 5, 5, 6],
	"E": [7, 4, 6, 4, 7],
	"F": [7, 4, 6, 4, 4],
	"G": [3, 4, 5, 5, 3],
	"H": [5, 5, 7, 5, 5],
	"I": [7, 2, 2, 2, 7],
	"J": [1, 1, 1, 5, 2],
	"K": [5, 5, 6, 5, 5],
	"L": [4, 4, 4, 4, 7],
	"M": [5, 7, 7, 5, 5],
	"N": [6, 5, 5, 5, 5],
	"O": [2, 5, 5, 5, 2],
	"P": [6, 5, 6, 4, 4],
	"Q": [2, 5, 5, 6, 3],
	"R": [6, 5, 6, 5, 5],
	"S": [3, 4, 2, 1, 6],
	"T": [7, 2, 2, 2, 2],
	"U": [5, 5, 5, 5, 7],
	"V": [5, 5, 5, 5, 2],
	"W": [5, 5, 7, 7, 5],
	"X": [5, 5, 2, 5, 5],
	"Y": [5, 5, 2, 2, 2],
	"Z": [7, 1, 2, 4, 7],
	"0": [7, 5, 5, 5, 7],
	"1": [2, 6, 2, 2, 7],
	"2": [6, 1, 2, 4, 7],
	"3": [6, 1, 2, 1, 6],
	"4": [5, 5, 7, 1, 1],
	"5": [7, 4, 6, 1, 6],
	"6": [3, 4, 7, 5, 7],
	"7": [7, 1, 2, 2, 2],
	"8": [7, 5, 7, 5, 7],
	"9": [7, 5, 7, 1, 6],
}


## O quadrilatero da chapa branca no `quadro` (uma imagem so do quadro), na
## ordem canto de cima a esquerda, de cima a direita, de baixo a direita e de
## baixo a esquerda, em pixels do quadro; vazio se nao achou. `caixa` e o
## retangulo do desenho dentro do quadro. `larga` procura como nos tres quartos
## de costas, em que a placa sai do eixo.
static func acha(quadro: Image, caixa: Rect2i, larga: bool = false) -> PackedVector2Array:
	if caixa.size.x <= 0 or caixa.size.y <= 0:
		return PackedVector2Array()
	var y0 := caixa.position.y + int(caixa.size.y * ABAIXO_DE)
	var x0 := caixa.position.x + int(caixa.size.x * (0.5 - FAIXA_DO_MEIO * 0.5))
	var x1 := caixa.position.x + int(caixa.size.x * (0.5 + FAIXA_DO_MEIO * 0.5))
	if larga:
		# Em tres quartos a moto aponta para a direita, e a traseira, com a placa,
		# fica no terco da esquerda, mais para baixo.
		y0 = caixa.position.y + int(caixa.size.y * ABAIXO_DE_TRES_QUARTOS)
		x0 = caixa.position.x
		x1 = caixa.position.x + int(caixa.size.x * TERCO_DA_TRASEIRA)
	var janela := Rect2i(x0, y0, x1 - x0, caixa.end.y - y0).intersection(
		Rect2i(Vector2i.ZERO, quadro.get_size())
	)
	# Chapa clara: o maior pedaco neutro dentro da janela ja basta, com o texto
	# de mentira do Flow furando a forma. Na sombra so vale o retangulo cheio.
	for claro: int in [CLARO, CLARO_NA_SOMBRA]:
		var achados := _melhor_chapa(quadro, janela, claro, caixa, claro != CLARO)
		if achados.size() >= AREA_MINIMA:
			return _cantos(achados)
	return PackedVector2Array()


## A maior mancha de pixel claro e neutro na `janela`, com forma de placa.
static func _melhor_chapa(
	quadro: Image, janela: Rect2i, claro: int, caixa: Rect2i, exige_forma: bool
) -> Array[Vector2i]:
	var visto: Dictionary = {}
	var melhor: Array[Vector2i] = []
	var teto := int(caixa.size.x * caixa.size.y * 0.15)
	for y in range(janela.position.y, janela.end.y):
		for x in range(janela.position.x, janela.end.x):
			var p := Vector2i(x, y)
			if visto.has(p) or not _e_chapa(quadro, x, y, claro):
				continue
			var mancha := _mancha(quadro, p, janela, visto, claro)
			if (
				mancha.size() > melhor.size()
				and mancha.size() <= teto
				and (not exige_forma or _tem_forma_de_placa(mancha))
			):
				melhor = mancha
	return melhor


static func _tem_forma_de_placa(mancha: Array[Vector2i]) -> bool:
	var minimo := mancha[0]
	var maximo := mancha[0]
	for p in mancha:
		minimo = minimo.min(p)
		maximo = maximo.max(p)
	var tamanho := maximo - minimo + Vector2i.ONE
	var proporcao := float(tamanho.x) / float(tamanho.y)
	return (
		float(mancha.size()) / float(tamanho.x * tamanho.y) >= RETANGULAR
		and proporcao >= 1.0
		and proporcao <= 3.5
	)


## Deixa a chapa lisa: pinta o quadrilatero, e os pixels claros em volta que o
## Flow usou de letra, de `CHAPA`. O que fica de fora e o desenho, intocado.
static func apaga(quadro: Image, cantos: PackedVector2Array) -> void:
	if cantos.size() != 4:
		return
	for p in _pixels_do_quadrilatero(cantos):
		if p.x >= 0 and p.y >= 0 and p.x < quadro.get_width() and p.y < quadro.get_height():
			quadro.set_pixelv(p, CHAPA)


## A placa ("ABC1D23") pronta, `largura` x `altura` px, em duas linhas como a de
## moto: a faixa azul no topo e, embaixo, tres letras e depois quatro caracteres.
static func chapa(texto: String, largura: int, altura: int) -> Image:
	var imagem := Image.create_empty(largura, altura, false, Image.FORMAT_RGBA8)
	imagem.fill(CHAPA)
	var faixa := maxi(roundi(altura * FRACAO_DA_FAIXA), 1)
	imagem.fill_rect(Rect2i(0, 0, largura, faixa), AZUL)
	var livre := altura - faixa
	_linha(imagem, texto.substr(0, 3), Rect2i(0, faixa, largura, livre / 2))
	_linha(imagem, texto.substr(3), Rect2i(0, faixa + livre / 2, largura, livre - livre / 2))
	return imagem


## Escreve `texto` no `quadro`, dentro do quadrilatero `cantos`: para cada pixel
## do quadrilatero acha o ponto da chapa que cai nele (mapa bilinear dos quatro
## cantos) e copia a cor. Vizinho mais proximo, e nao filtro: e pixel de arcade.
static func pinta(quadro: Image, cantos: PackedVector2Array, texto: String) -> void:
	if cantos.size() != 4:
		return
	var largura := maxi(
		roundi(maxf(cantos[0].distance_to(cantos[1]), cantos[3].distance_to(cantos[2]))), 6
	)
	var altura := maxi(
		roundi(maxf(cantos[0].distance_to(cantos[3]), cantos[1].distance_to(cantos[2]))), 5
	)
	var placa := chapa(texto, largura, altura)
	for p in _pixels_do_quadrilatero(cantos):
		if p.x < 0 or p.y < 0 or p.x >= quadro.get_width() or p.y >= quadro.get_height():
			continue
		var uv := _uv(cantos, Vector2(p) + Vector2(0.5, 0.5))
		var u := clampi(int(uv.x * placa.get_width()), 0, placa.get_width() - 1)
		var v := clampi(int(uv.y * placa.get_height()), 0, placa.get_height() - 1)
		quadro.set_pixelv(p, placa.get_pixel(u, v))


static func _e_chapa(quadro: Image, x: int, y: int, claro: int) -> bool:
	var c := quadro.get_pixel(x, y)
	if c.a < 0.5:
		return false
	var r := roundi(c.r * 255.0)
	var g := roundi(c.g * 255.0)
	var b := roundi(c.b * 255.0)
	return (
		mini(r, mini(g, b)) >= claro and maxi(r, maxi(g, b)) - mini(r, mini(g, b)) <= MAX_COLORIDO
	)


## A mancha de pixels de chapa ligada a `inicio`, em 4 vizinhos.
static func _mancha(
	quadro: Image, inicio: Vector2i, janela: Rect2i, visto: Dictionary, claro: int
) -> Array[Vector2i]:
	var achados: Array[Vector2i] = []
	var pilha: Array[Vector2i] = [inicio]
	visto[inicio] = true
	while not pilha.is_empty():
		var p: Vector2i = pilha.pop_back()
		achados.append(p)
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q := p + d
			if not janela.has_point(q) or visto.has(q):
				continue
			if _e_chapa(quadro, q.x, q.y, claro):
				visto[q] = true
				pilha.append(q)
	return achados


## Os quatro cantos de uma mancha: os pontos mais extremos nas duas diagonais.
## Para um retangulo (ou um paralelogramo, na moto inclinada) sao os cantos de
## verdade.
static func _cantos(mancha: Array[Vector2i]) -> PackedVector2Array:
	var topo_esq := mancha[0]
	var topo_dir := mancha[0]
	var base_dir := mancha[0]
	var base_esq := mancha[0]
	for p in mancha:
		if p.x + p.y < topo_esq.x + topo_esq.y:
			topo_esq = p
		if p.x - p.y > topo_dir.x - topo_dir.y:
			topo_dir = p
		if p.x + p.y > base_dir.x + base_dir.y:
			base_dir = p
		if p.x - p.y < base_esq.x - base_esq.y:
			base_esq = p
	# O pixel e um quadrado: o canto de baixo e da direita fica um pixel adiante.
	return PackedVector2Array(
		[
			Vector2(topo_esq),
			Vector2(topo_dir) + Vector2(1, 0),
			Vector2(base_dir) + Vector2(1, 1),
			Vector2(base_esq) + Vector2(0, 1)
		]
	)


static func _pixels_do_quadrilatero(cantos: PackedVector2Array) -> Array[Vector2i]:
	var minimo := cantos[0]
	var maximo := cantos[0]
	for c in cantos:
		minimo = minimo.min(c)
		maximo = maximo.max(c)
	var achados: Array[Vector2i] = []
	for y in range(floori(minimo.y), ceili(maximo.y)):
		for x in range(floori(minimo.x), ceili(maximo.x)):
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), cantos):
				achados.append(Vector2i(x, y))
	return achados


## (u, v) de 0 a 1 do ponto `p` dentro do quadrilatero, pelo mapa bilinear
## inverso. Num paralelogramo e exato; no quadrilatero torto e a aproximacao
## de quem so tem quatro cantos.
static func _uv(cantos: PackedVector2Array, p: Vector2) -> Vector2:
	var a := cantos[0]
	var b := cantos[1] - a
	var d := cantos[3] - a
	var det := b.x * d.y - b.y * d.x
	if absf(det) < 0.0001:
		return Vector2(0.5, 0.5)
	var q := p - a
	return Vector2((q.x * d.y - q.y * d.x) / det, (b.x * q.y - b.y * q.x) / det)


## Uma linha de texto centrada na `faixa` da chapa, em pixel inteiro: o glifo e
## 3 x 5, e a escala e o maior inteiro em que a linha toda cabe.
static func _linha(imagem: Image, texto: String, faixa: Rect2i) -> void:
	if texto.is_empty() or faixa.size.y < 5:
		return
	var colunas := texto.length() * 4 - 1
	var escala := maxi(mini(faixa.size.x / colunas, faixa.size.y / 6), 1)
	var largura := colunas * escala
	var x0 := faixa.position.x + (faixa.size.x - largura) / 2
	var y0 := faixa.position.y + (faixa.size.y - 5 * escala) / 2
	for i in texto.length():
		var glifo: Array = GLIFOS.get(texto[i], GLIFOS["0"])
		for linha in 5:
			for coluna in 3:
				if (int(glifo[linha]) >> (2 - coluna)) & 1 == 1:
					var onde := Vector2i(x0 + (i * 4 + coluna) * escala, y0 + linha * escala)
					imagem.fill_rect(Rect2i(onde, Vector2i(escala, escala)), TINTA)
