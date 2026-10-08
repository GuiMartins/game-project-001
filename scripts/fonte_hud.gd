class_name FonteHud
extends RefCounted
## A fonte de arcade da HUD: italico pesado, contorno preto duro e degrade
## vertical, tudo assado no pixel.
##
## Nao e `FontFile` de proposito. Fonte vetorial antialiasada num jogo
## pixelado e o erro de HUD nitida sobre mundo pixelado, so que dentro da HUD
## (DIRECAO_VISUAL.md, *HUD*); e fonte bitmap no Godot nao tem contorno nem
## degrade, que sao metade do visual das referencias. Assar os dois no glifo e
## desenhar com `draw_texture_rect_region` em posicao inteira da o pixel exato
## que a referencia tem, sem depender de hinting, filtro nem subpixel.
##
## E e gerada aqui, e nao num `arte/fonte_hud.py`, porque o glifo e uma tabela
## de 7 linhas de texto: o diff dela ja e legivel, e um PNG no LFS nao seria.

## Altura do glifo na grade base, em pixels.
const ALTURA: int = 7

## A grade de 7 linhas de cada caractere, linha de cima primeiro. So
## maiuscula: a HUD de arcade e caixa alta, e `desenhar` sobe o que vier em
## minuscula. Largura variavel - o `1`, o `:` e o `.` estreitos sao o que
## impede "1:01.1" de parecer espacado por acidente.
##
## Duas armadilhas do negrito, que engorda todo traco para a direita: o `0`
## nao tem barra (com ela, gordo, le como `8`), e `M`, `N` e `W` sao mais
## largos que o resto, porque no 5x7 o vao entre as pernas some e o `M` vira
## `N`.
const GLIFOS: Dictionary = {
	"0": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
	"1": [".#.", "##.", ".#.", ".#.", ".#.", ".#.", "###"],
	"2": [".###.", "#...#", "....#", "..##.", ".#...", "#....", "#####"],
	"3": ["####.", "....#", "....#", ".###.", "....#", "....#", "####."],
	"4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
	"5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
	"6": [".###.", "#....", "#....", "####.", "#...#", "#...#", ".###."],
	"7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
	"8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
	"9": [".###.", "#...#", "#...#", ".####", "....#", "....#", ".###."],
	"A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
	"B": ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
	"C": [".###.", "#...#", "#....", "#....", "#....", "#...#", ".###."],
	"D": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
	"E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
	"F": ["#####", "#....", "#....", "####.", "#....", "#....", "#...."],
	"G": [".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".####"],
	"H": ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
	"I": ["###", ".#.", ".#.", ".#.", ".#.", ".#.", "###"],
	"J": ["..###", "...#.", "...#.", "...#.", "...#.", "#..#.", ".##.."],
	"K": ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
	"L": ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
	"M": ["#.....#", "##...##", "#.#.#.#", "#..#..#", "#.....#", "#.....#", "#.....#"],
	"N": ["#....#", "##...#", "#.#..#", "#..#.#", "#...##", "#....#", "#....#"],
	"O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
	"P": ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
	"Q": [".###.", "#...#", "#...#", "#...#", "#.#.#", "#..#.", ".##.#"],
	"R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
	"S": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
	"T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
	"U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
	"V": ["#...#", "#...#", "#...#", "#...#", "#...#", ".#.#.", "..#.."],
	"W": ["#.....#", "#.....#", "#.....#", "#..#..#", "#.#.#.#", "##...##", "#.....#"],
	"X": ["#...#", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#"],
	"Y": ["#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."],
	"Z": ["#####", "....#", "...#.", "..#..", ".#...", "#....", "#####"],
	":": [".", "#", "#", ".", "#", "#", "."],
	".": [".", ".", ".", ".", ".", "#", "#"],
	",": ["..", "..", "..", "..", "..", ".#", "#."],
	"/": ["....#", "...#.", "...#.", "..#..", ".#...", ".#...", "#...."],
	"-": ["....", "....", "....", "####", "....", "....", "...."],
	"+": [".....", "..#..", "..#..", "#####", "..#..", "..#..", "....."],
	"!": ["#", "#", "#", "#", "#", ".", "#"],
	"?": [".###.", "#...#", "....#", "..##.", "..#..", ".....", "..#.."],
	"%": ["##..#", "##..#", "...#.", "..#..", ".#...", "#..##", "#..##"],
	"(": [".#", "#.", "#.", "#.", "#.", "#.", ".#"],
	")": ["#.", ".#", ".#", ".#", ".#", ".#", "#."],
	"'": ["#", "#", ".", ".", ".", ".", "."],
	"_": [".....", ".....", ".....", ".....", ".....", ".....", "#####"],
	# A estrela da nota: o `*` da HUD nao e asterisco, e o glifo que o jogador
	# conta de relance.
	"*": ["..#..", "..#..", "#####", ".###.", ".###.", "##.##", "#...#"],
}

## O caractere que ocupa o lugar de qualquer coisa que a tabela nao tem. Um
## buraco no texto e pior que um sinal visivel de que falta glifo: o buraco
## parece espaco de proposito.
const FALTANTE: String = "?"

## Acentos viram a letra sem acento. A HUD e caixa alta de arcade, e o texto
## que chega do mundo e escrito sem acento de proposito; isto so evita o `?`
## se alguem escrever com.
const SEM_ACENTO: Dictionary = {
	"Á": "A",
	"À": "A",
	"Â": "A",
	"Ã": "A",
	"É": "E",
	"Ê": "E",
	"Í": "I",
	"Ó": "O",
	"Ô": "O",
	"Õ": "O",
	"Ú": "U",
	"Ç": "C",
}

## Largura do espaco e vao entre letras, em pixels da grade base.
const ESPACO: int = 3
const VAO: int = 1

var escala: int
var contorno: int
var sombra: int
## Quanto a letra cresce de largura para ficar pesada: o traco de 1 pixel da
## grade vira `escala + negrito`. E o "pesado" do arcade dos anos 90.
var negrito: int
## Linhas de saida por pixel de deslocamento do italico. 4 da ~14 graus, o
## inclinado das referencias; menos que 3 ja vira serrilha de escada.
var passo_italico: int
var altura: int

var _contornos: Texture2D
var _miolos: Texture2D
var _regioes: Dictionary = {}  ## caractere -> Rect2i no atlas
var _avancos: Dictionary = {}  ## caractere -> pixels ate a proxima letra


## `cor_topo` e `cor_base` fazem o degrade vertical do miolo: amarelo para
## laranja na legenda, branco para cinza-claro no valor (le como chanfro).
func _init(
	a_escala: int,
	a_contorno: int,
	cor_topo: Color,
	cor_base: Color,
	a_negrito: int = 1,
	a_sombra: int = 1,
	a_passo_italico: int = 4
) -> void:
	escala = a_escala
	contorno = a_contorno
	negrito = a_negrito
	sombra = a_sombra
	passo_italico = a_passo_italico
	altura = ALTURA * escala
	_monta_atlas(cor_topo, cor_base)


## Largura do texto em pixels, do primeiro pixel do miolo ao ultimo, sem o
## contorno. E o que o alinhamento a direita precisa.
func largura(texto: String) -> int:
	var total := 0
	var chars := _normaliza(texto)
	for i in chars.length():
		var c := chars[i]
		if c == " ":
			total += ESPACO * escala
			continue
		total += _avancos[c]
	if total > 0 and not chars.ends_with(" "):
		total -= VAO * escala
	return total + _sobra_italico()


## Desenha `texto` com o canto de cima-esquerda do miolo em `pos`.
##
## Em duas passadas, todos os contornos e depois todos os miolos: com uma so,
## o contorno preto da letra seguinte come a borda do miolo da anterior, e o
## texto pesado vira um borrao.
func desenhar(ci: CanvasItem, pos: Vector2i, texto: String, cor: Color = Color.WHITE) -> void:
	var chars := _normaliza(texto)
	for atlas: Texture2D in [_contornos, _miolos]:
		var x := pos.x
		for i in chars.length():
			var c := chars[i]
			if c == " ":
				x += ESPACO * escala
				continue
			var r: Rect2i = _regioes[c]
			var destino := Rect2(Vector2(x - contorno, pos.y - contorno), r.size)
			# A cor tinge so o miolo: contorno tingido de vermelho deixa de
			# ser contorno e o texto perde a borda no asfalto claro.
			var tinta := cor if atlas == _miolos else Color(1, 1, 1, cor.a)
			ci.draw_texture_rect_region(atlas, destino, Rect2(r), tinta)
			x += _avancos[c]


func _normaliza(texto: String) -> String:
	var saida := ""
	var alto := texto.to_upper()
	for i in alto.length():
		var c := alto[i]
		c = SEM_ACENTO.get(c, c)
		if c != " " and not GLIFOS.has(c):
			c = FALTANTE
		saida += c
	return saida


func _sobra_italico() -> int:
	return (altura - 1) / passo_italico


func _monta_atlas(cor_topo: Color, cor_base: Color) -> void:
	var margem := contorno
	var mais_larga := 0
	for linhas: Array in GLIFOS.values():
		mais_larga = maxi(mais_larga, (linhas[0] as String).length())
	var largura_celula := mais_larga * escala + negrito + _sobra_italico() + 2 * margem
	var altura_celula := altura + 2 * margem + sombra
	var chaves := GLIFOS.keys()
	var img_contorno := Image.create_empty(
		largura_celula * chaves.size(), altura_celula, false, Image.FORMAT_RGBA8
	)
	var img_miolo := Image.create_empty(
		largura_celula * chaves.size(), altura_celula, false, Image.FORMAT_RGBA8
	)
	for indice in chaves.size():
		var c: String = chaves[indice]
		var linhas: Array = GLIFOS[c]
		var w_base: int = (linhas[0] as String).length()
		var miolo := _rasteriza(linhas)
		var w: int = w_base * escala + negrito + _sobra_italico()
		var origem := Vector2i(indice * largura_celula + margem, margem)
		_pinta(img_contorno, img_miolo, miolo, origem, cor_topo, cor_base)
		_regioes[c] = Rect2i(
			indice * largura_celula, 0, w + 2 * margem, altura + 2 * margem + sombra
		)
		_avancos[c] = w_base * escala + negrito + VAO * escala
	_contornos = ImageTexture.create_from_image(img_contorno)
	_miolos = ImageTexture.create_from_image(img_miolo)


## O glifo na resolucao de saida: escala, negrito e italico, como conjunto de
## pixels acesos.
func _rasteriza(linhas: Array) -> Dictionary:
	var acesos := {}
	for y in altura:
		var linha: String = linhas[y / escala]
		# Italico: as linhas de cima andam para a direita. Calculado na saida,
		# e nao na grade base, para o degrau ter o tamanho do pixel da tela e
		# nao o da letra.
		var desvio := (altura - 1 - y) / passo_italico
		for xb in linha.length():
			if linha[xb] != "#":
				continue
			for dx in escala + negrito:
				acesos[Vector2i(xb * escala + dx + desvio, y)] = true
	return acesos


func _pinta(
	img_contorno: Image,
	img_miolo: Image,
	miolo: Dictionary,
	origem: Vector2i,
	cor_topo: Color,
	cor_base: Color
) -> void:
	var preto := Color(0, 0, 0, 1)
	var sombra_cor := Color(0, 0, 0, 0.55)
	# Sombra primeiro, contorno por cima: a sombra e o contorno deslocado
	# para baixo, e so aparece onde o contorno nao chega.
	for passada in 2:
		var dy := sombra if passada == 0 else 0
		var cor := sombra_cor if passada == 0 else preto
		for p: Vector2i in miolo:
			for ox in range(-contorno, contorno + 1):
				for oy in range(-contorno, contorno + 1):
					var alvo := origem + p + Vector2i(ox, oy + dy)
					if passada == 0 or img_contorno.get_pixelv(alvo).a < 1.0:
						img_contorno.set_pixelv(alvo, cor)
	for p: Vector2i in miolo:
		var t := float(p.y) / float(maxi(altura - 1, 1))
		img_miolo.set_pixelv(origem + p, cor_topo.lerp(cor_base, t))
