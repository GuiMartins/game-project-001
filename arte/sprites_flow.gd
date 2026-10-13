extends SceneTree
## Recorta as folhas geradas no Google Flow em `assets/sprites/entregador.png`.
##
##     python tools/dev.py sprites
##
## As folhas (`arte/flow/*.jpg`) sao a fonte, e o atlas e build: o mesmo
## principio do `.blend` e do `assets/entregador/`. Roda no Godot fixado, e nao
## em Python, porque o Python do sistema nao le JPEG sem Pillow, e dependencia
## nova so para isto e uma instalacao a mais nas tres maquinas.
##
## O que a IA entrega nao e uma folha de sprite: e um quadro com N desenhos em
## fundo verde, cada um num tamanho e numa posicao. O que este script faz e o
## que faria uma pessoa no editor de imagem, so que repetivel:
##
## 1. tira o verde, com a borda dura (o pixel e do piloto ou do fundo);
## 2. acha cada desenho pelas faixas vazias entre eles, sem grade fixa;
## 3. alinha todos pelo pe do pneu traseiro, que e o ponto que encosta no
##    asfalto - alinhado pela caixa, o piloto que soca pularia de lado;
## 4. reduz cada folha para o mesmo tamanho de bag, porque cada geracao saiu
##    numa escala.
##
## A medida comum e a bag, e nao a altura do piloto. Cada geracao tambem sai
## com a camera numa altura: nas folhas de combate ela esta mais baixa, e o
## piloto sai mais alto e mais estreito. Igualadas pela altura, o corpo de
## quem soca ficava 15% mais fino que o de quem pilota, e o ator encolhia a
## cada soco. A bag e o maior bloco que a camera de tras ve, e e pelo tamanho
## dela que o olho mede o piloto.

## Altura do piloto da primeira folha no atlas, do pneu ao capacete, em
## pixels; as outras seguem pela bag, e podem passar disto. Na camera de
## perseguicao o ator ocupa uns 100 px dos 360; um pouco acima disso o mipmap
## mais proximo ainda e o proprio atlas, e o sprite chega na tela sem ser
## reamostrado duas vezes.
const ALTURA: int = 120
## Tamanho de cada celula do atlas. A largura cabe o braco esticado do soco,
## que passa meia altura para fora do corpo; a altura, o piloto das folhas de
## camera baixa, que igualado pela bag passa da `ALTURA` em ate 25%.
const CELULA := Vector2i(192, 160)
## Onde o pe do pneu traseiro fica na celula, a partir do canto de cima.
const PE := Vector2i(96, 156)

## Um pixel e fundo quando o verde passa os outros dois canais por esta margem
## (0-255). O JPEG suja a borda: abaixo disso sobra uma franja verde no piloto.
const MARGEM_VERDE: int = 40
## Faixa vazia, em pixels da folha, que separa dois desenhos. Menor que isto e
## so um vao dentro do mesmo desenho, entre o braco e o corpo.
const VAO: int = 12
## Um pixel e da bag ou da camiseta quando o vermelho passa o dobro dos outros
## dois canais e nao e sombra preta (0-255).
const VERMELHO_MINIMO: int = 90
## Desenho com menos pixels que isto e sujeira do JPEG, nao quadro.
const AREA_MINIMA: int = 4000

## Os quadros do atlas, na ordem do `Entregador.QUADROS_SPRITE`: folha, linha e
## coluna de cada um. So entra o que o jogo tem como mostrar - o chute das
## folhas de combate fica de fora porque nao existe chute.
const QUADROS: Array[Array] = [
	# A inclinacao, da esquerda para a direita, indo reto.
	["pilotando_a", 0, 0],
	["pilotando_a", 0, 1],
	["pilotando_a", 0, 2],
	["pilotando_a", 0, 3],
	["pilotando_a", 0, 4],
	# Soco para a esquerda: arma, estica, recolhe.
	["combate_a", 0, 0],
	["combate_a", 0, 1],
	["combate_a", 0, 2],
	# Soco para a direita: o punho armado da folha e o do braco errado, e o
	# recolhido serve para armar e para recolher.
	["combate_b", 0, 2],
	["combate_b", 0, 1],
	["combate_b", 0, 2],
]

const ORIGEM: String = "res://arte/flow/"
const SAIDA: String = "res://assets/sprites/entregador.png"


func _initialize() -> void:
	var folhas: Dictionary = {}
	# A primeira folha da a escala pela altura; as outras, pela bag dela.
	var referencia: Dictionary = {}
	var atlas := Image.create_empty(CELULA.x * QUADROS.size(), CELULA.y, false, Image.FORMAT_RGBA8)
	for i in QUADROS.size():
		var nome: String = QUADROS[i][0]
		if not folhas.has(nome):
			folhas[nome] = _folha(ORIGEM + nome + ".jpg")
			if folhas[nome] == null:
				quit(1)
				return
			var nova: Dictionary = folhas[nome]
			if referencia.is_empty():
				referencia = nova
				nova["escala"] = float(ALTURA) / nova["altura"]
			else:
				nova["escala"] = (referencia["escala"] * sqrt(referencia["bag"] / nova["bag"]))
			print("  %s: escala %.4f" % [nome, nova["escala"]])
		var folha: Dictionary = folhas[nome]
		var linhas: Array = folha["desenhos"]
		var linha: int = QUADROS[i][1]
		var coluna: int = QUADROS[i][2]
		if linha >= linhas.size() or coluna >= (linhas[linha] as Array).size():
			push_error("%s: nao achei o desenho da linha %d, coluna %d" % [nome, linha, coluna])
			quit(1)
			return
		var desenho: Dictionary = linhas[linha][coluna]
		_cola(atlas, i, folha["imagem"], desenho, folha["escala"])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA.get_base_dir()))
	var erro := atlas.save_png(SAIDA)
	if erro != OK:
		push_error("nao gravei %s: %s" % [SAIDA, error_string(erro)])
		quit(1)
		return
	print("+ %s: %d quadros de %dx%d" % [SAIDA, QUADROS.size(), CELULA.x, CELULA.y])
	quit(0)


## A folha sem o verde, os desenhos achados nela e as medianas da altura do
## desenho e da area da bag, em pixels da folha.
func _folha(caminho: String) -> Variant:
	var imagem := Image.load_from_file(ProjectSettings.globalize_path(caminho))
	if imagem == null or imagem.is_empty():
		push_error("nao li %s - rode `git lfs pull`" % caminho)
		return null
	imagem.convert(Image.FORMAT_RGBA8)
	var largura := imagem.get_width()
	var altura := imagem.get_height()
	var dados := imagem.get_data()
	var cheio := PackedByteArray()
	cheio.resize(largura * altura)
	var vermelho := PackedByteArray()
	vermelho.resize(largura * altura)
	for p in largura * altura:
		var r := dados[p * 4]
		var g := dados[p * 4 + 1]
		var b := dados[p * 4 + 2]
		if g - maxi(r, b) > MARGEM_VERDE:
			# Pre-multiplicado: o fundo vira preto transparente, e a reducao
			# nao puxa verde para dentro da borda.
			dados[p * 4] = 0
			dados[p * 4 + 1] = 0
			dados[p * 4 + 2] = 0
			dados[p * 4 + 3] = 0
		else:
			# O verde que o fundo rebate na borda do piloto e na lataria: o
			# canal verde nunca passa o maior dos outros dois.
			dados[p * 4 + 1] = mini(g, maxi(r, b))
			cheio[p] = 1
			if r > VERMELHO_MINIMO and r > 2 * maxi(g, b):
				vermelho[p] = 1
	imagem.set_data(largura, altura, false, Image.FORMAT_RGBA8, dados)

	var desenhos: Array = []
	var alturas: Array[float] = []
	var bags: Array[float] = []
	for faixa in _faixas(_soma_linhas(cheio, largura, 0, altura, 0, largura)):
		var linha: Array = []
		var colunas := _soma_colunas(cheio, largura, faixa.x, faixa.y)
		for corte in _faixas(colunas):
			var caixa := _caixa(
				cheio,
				vermelho,
				largura,
				Rect2i(corte.x, faixa.x, corte.y - corte.x, faixa.y - faixa.x)
			)
			if caixa["area"] < AREA_MINIMA:
				continue
			linha.append(caixa)
			alturas.append(float((caixa["retangulo"] as Rect2i).size.y))
			bags.append(float(caixa["bag"]))
		if not linha.is_empty():
			desenhos.append(linha)
	alturas.sort()
	bags.sort()
	print(
		(
			"  %s: %s desenhos por linha"
			% [caminho.get_file(), desenhos.map(func(l: Array) -> int: return l.size())]
		)
	)
	# A mediana e nao a media: o punho armado acima do capacete estica a caixa
	# de um quadro, e a escala nao pode encolher a folha inteira por ele.
	return {
		"imagem": imagem,
		"desenhos": desenhos,
		"altura": alturas[alturas.size() / 2],
		"bag": bags[bags.size() / 2],
	}


func _soma_linhas(
	cheio: PackedByteArray, largura: int, y0: int, y1: int, x0: int, x1: int
) -> PackedInt32Array:
	var soma := PackedInt32Array()
	soma.resize(y1 - y0)
	for y in range(y0, y1):
		var n := 0
		for x in range(x0, x1):
			n += cheio[y * largura + x]
		soma[y - y0] = n
	return soma


func _soma_colunas(cheio: PackedByteArray, largura: int, y0: int, y1: int) -> PackedInt32Array:
	var soma := PackedInt32Array()
	soma.resize(largura)
	for y in range(y0, y1):
		for x in largura:
			soma[x] += cheio[y * largura + x]
	return soma


## Os trechos ocupados de uma projecao, como (inicio, fim), juntando os que um
## vao menor que `VAO` separa.
func _faixas(soma: PackedInt32Array) -> Array[Vector2i]:
	var faixas: Array[Vector2i] = []
	var inicio := -1
	var vazio := 0
	for i in soma.size():
		if soma[i] > 2:
			if inicio < 0:
				inicio = i
			vazio = 0
		elif inicio >= 0:
			vazio += 1
			if vazio >= VAO:
				faixas.append(Vector2i(inicio, i - vazio + 1))
				inicio = -1
	if inicio >= 0:
		faixas.append(Vector2i(inicio, soma.size() - vazio))
	return faixas


## A caixa justa do desenho dentro de `regiao`, a area dele e a da bag, e
## onde fica o pe do pneu traseiro: a linha mais baixa e o meio dos pixels
## nela e logo acima.
func _caixa(
	cheio: PackedByteArray, vermelho: PackedByteArray, largura: int, regiao: Rect2i
) -> Dictionary:
	var minimo := Vector2i(regiao.end)
	var maximo := Vector2i(regiao.position)
	var area := 0
	var bag := 0
	for y in range(regiao.position.y, regiao.end.y):
		for x in range(regiao.position.x, regiao.end.x):
			if cheio[y * largura + x] == 1:
				area += 1
				bag += vermelho[y * largura + x]
				minimo = minimo.min(Vector2i(x, y))
				maximo = maximo.max(Vector2i(x, y))
	# O pneu de tras e a parte mais baixa do desenho; 15 px de folha pegam o
	# arco de baixo dele, onde ele ainda e estreito e centrado.
	var soma_x := 0
	var n := 0
	for y in range(maxi(maximo.y - 15, minimo.y), maximo.y + 1):
		for x in range(minimo.x, maximo.x + 1):
			if cheio[y * largura + x] == 1:
				soma_x += x
				n += 1
	var pe := Vector2(float(soma_x) / maxf(n, 1.0), float(maximo.y + 1))
	return {
		"retangulo": Rect2i(minimo, maximo - minimo + Vector2i.ONE),
		"area": area,
		"bag": bag,
		"pe": pe
	}


## Reduz o desenho e cola na celula `indice`, com o pe do pneu em `PE`.
func _cola(atlas: Image, indice: int, folha: Image, desenho: Dictionary, escala: float) -> void:
	var caixa: Rect2i = desenho["retangulo"]
	var recorte := folha.get_region(caixa)
	var tamanho := Vector2i((Vector2(caixa.size) * escala).round()).max(Vector2i.ONE)
	recorte.resize(tamanho.x, tamanho.y, Image.INTERPOLATE_LANCZOS)
	var pe: Vector2 = (desenho["pe"] - Vector2(caixa.position)) * escala
	var destino := Vector2i(indice * CELULA.x, 0) + PE - Vector2i(pe.round())
	# A borda dura: desfaz o pre-multiplicado e corta o alfa no meio. Meio-tom
	# na silhueta e o que faz um sprite ler como recortado por tesoura de IA, e
	# nao como digitalizado.
	var dados := recorte.get_data()
	for p in tamanho.x * tamanho.y:
		var a := dados[p * 4 + 3]
		if a < 128:
			for c in 4:
				dados[p * 4 + c] = 0
			continue
		for c in 3:
			dados[p * 4 + c] = mini(255, int(dados[p * 4 + c] * 255.0 / a))
		dados[p * 4 + 3] = 255
	recorte.set_data(tamanho.x, tamanho.y, false, Image.FORMAT_RGBA8, dados)
	# Cortado na celula: um braco que passasse dela apareceria no quadro vizinho.
	var celula := Rect2i(indice * CELULA.x, 0, CELULA.x, CELULA.y)
	var colado := Rect2i(destino, tamanho).intersection(celula)
	if colado.size != tamanho:
		print("  ! quadro %d passou da celula e foi cortado" % indice)
	atlas.blit_rect(recorte, Rect2i(colado.position - destino, colado.size), colado.position)
