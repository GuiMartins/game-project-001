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
## 4. reduz cada quadro para o tamanho do reto, pela medida que vale para ele;
## 5. mede a inclinacao que cada quadro desenha, que o `AtorSprite` tem de
##    saber (`INCLINACOES`) para girar so o que falta.
##
## A medida comum e quadro a quadro, e nao a folha. A IA nao desenha o mesmo
## piloto duas vezes no mesmo tamanho: na mesma folha, os quadros deitados
## sairam com 12% mais area que o reto, e a folha de combate veio com a camera
## mais baixa, o piloto mais alto e mais estreito. Qualquer medida por folha
## deixava o ator inflando e desinflando a cada troca de quadro.
##
## Na curva a medida e a area, que nao muda quando o desenho gira; a altura
## mudaria, porque o deitado e mais baixo de verdade. No soco e a altura do
## quadro de voltar a pilotar: a camera da folha de combate e mais baixa, e
## igualado pela area o piloto ficava 4% a 6% mais alto que o reto - o
## capacete pulava para cima a cada soco, que e o que se le como crescer.

## Altura do piloto reto (`MEDIDA`) no atlas, do pneu ao capacete, em pixels;
## os outros quadros tem a area dele, e podem passar disto. Na camera de
## perseguicao o ator ocupa uns 100 px dos 360; um pouco acima disso o mipmap
## mais proximo ainda e o proprio atlas, e o sprite chega na tela sem ser
## reamostrado duas vezes.
const ALTURA: int = 120
## Tamanho de cada celula do atlas. A largura cabe o braco esticado do soco,
## que passa meia altura para fora do corpo; a altura, o piloto das folhas de
## camera baixa, que igualado pela area passa da `ALTURA` em ate 25%.
const CELULA := Vector2i(192, 160)
## Onde o pe do pneu traseiro fica na celula, a partir do canto de cima.
const PE := Vector2i(96, 156)

## Um pixel e fundo quando o verde passa os outros dois canais por esta margem
## (0-255). O JPEG suja a borda: abaixo disso sobra uma franja verde no piloto.
const MARGEM_VERDE: int = 40
## Faixa vazia, em pixels da folha, que separa dois desenhos. Menor que isto e
## so um vao dentro do mesmo desenho, entre o braco e o corpo.
const VAO: int = 12
## Desenho com menos pixels que isto e sujeira do JPEG, nao quadro.
const AREA_MINIMA: int = 4000

## O quadro que da o tamanho de todos: o piloto reto, indo em frente.
const MEDIDA: Array = ["pilotando_a", 0, 2]

## Os quadros do atlas, na ordem do `AtorSprite`: folha, linha, coluna de cada
## um, a coluna, na mesma linha, que mede o quadro, e o que se mede nela
## (`area` ou `altura`, ver o topo). So entra o que o jogo tem como mostrar - o
## chute das folhas de combate fica de fora porque nao existe chute.
##
## O soco se mede pelo quadro de voltar a pilotar da propria folha, e nao por
## ele mesmo: o braco esticado e area a mais, e o punho armado e altura a mais,
## e medido por eles o piloto encolheria justamente no quadro do soco.
const QUADROS: Array[Array] = [
	# A inclinacao, da esquerda para a direita, indo reto.
	["pilotando_a", 0, 0, 0, "area"],
	["pilotando_a", 0, 1, 1, "area"],
	["pilotando_a", 0, 2, 2, "area"],
	["pilotando_a", 0, 3, 3, "area"],
	["pilotando_a", 0, 4, 4, "area"],
	# Soco para a esquerda: arma, estica, recolhe.
	["combate_a", 0, 0, 3, "altura"],
	["combate_a", 0, 1, 3, "altura"],
	["combate_a", 0, 2, 3, "altura"],
	# Soco para a direita: o punho armado da folha e o do braco errado, e o
	# recolhido serve para armar e para recolher.
	["combate_b", 0, 2, 3, "altura"],
	["combate_b", 0, 1, 3, "altura"],
	["combate_b", 0, 2, 3, "altura"],
]

const ORIGEM: String = "res://arte/flow/"
const SAIDA: String = "res://assets/sprites/entregador.png"


func _initialize() -> void:
	var folhas: Dictionary = {}
	for quadro: Array in QUADROS + [MEDIDA]:
		var nome: String = quadro[0]
		if not folhas.has(nome):
			folhas[nome] = _folha(ORIGEM + nome + ".jpg")
			if folhas[nome] == null:
				quit(1)
				return
	var reto: Variant = _desenho(folhas, MEDIDA[0], MEDIDA[1], MEDIDA[2])
	if reto == null:
		quit(1)
		return
	var escala_reto := float(ALTURA) / float((reto["retangulo"] as Rect2i).size.y)
	# A area que todo quadro tem no atlas: a do reto, na escala que da a ele a
	# `ALTURA`. Area cresce com o quadrado da escala, dai a raiz abaixo.
	var area_alvo := float(reto["area"]) * escala_reto * escala_reto

	var atlas := Image.create_empty(CELULA.x * QUADROS.size(), CELULA.y, false, Image.FORMAT_RGBA8)
	for i in QUADROS.size():
		var nome: String = QUADROS[i][0]
		var desenho: Variant = _desenho(folhas, nome, QUADROS[i][1], QUADROS[i][2])
		var medida: Variant = _desenho(folhas, nome, QUADROS[i][1], QUADROS[i][3])
		if desenho == null or medida == null:
			quit(1)
			return
		var escala := (
			sqrt(area_alvo / float(medida["area"]))
			if QUADROS[i][4] == "area"
			else float(ALTURA) / float((medida["retangulo"] as Rect2i).size.y)
		)
		_cola(atlas, i, folhas[nome]["imagem"], desenho, escala)
		print(
			(
				"  quadro %d (%s): escala %.4f, inclinacao desenhada %.1f graus"
				% [i, nome, escala, inclinacao(atlas, i)]
			)
		)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA.get_base_dir()))
	var erro := atlas.save_png(SAIDA)
	if erro != OK:
		push_error("nao gravei %s: %s" % [SAIDA, error_string(erro)])
		quit(1)
		return
	print("+ %s: %d quadros de %dx%d" % [SAIDA, QUADROS.size(), CELULA.x, CELULA.y])
	quit(0)


func _desenho(folhas: Dictionary, nome: String, linha: int, coluna: int) -> Variant:
	var linhas: Array = folhas[nome]["desenhos"]
	if linha >= linhas.size() or coluna >= (linhas[linha] as Array).size():
		push_error("%s: nao achei o desenho da linha %d, coluna %d" % [nome, linha, coluna])
		return null
	return linhas[linha][coluna]


## A folha sem o verde e os desenhos achados nela, linha a linha.
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
	imagem.set_data(largura, altura, false, Image.FORMAT_RGBA8, dados)

	var desenhos: Array = []
	for faixa in _faixas(_soma_linhas(cheio, largura, 0, altura, 0, largura)):
		var linha: Array = []
		var colunas := _soma_colunas(cheio, largura, faixa.x, faixa.y)
		for corte in _faixas(colunas):
			var caixa := _caixa(
				cheio, largura, Rect2i(corte.x, faixa.x, corte.y - corte.x, faixa.y - faixa.x)
			)
			if caixa["area"] < AREA_MINIMA:
				continue
			linha.append(caixa)
		if not linha.is_empty():
			desenhos.append(linha)
	print(
		(
			"  %s: %s desenhos por linha"
			% [caminho.get_file(), desenhos.map(func(l: Array) -> int: return l.size())]
		)
	)
	return {"imagem": imagem, "desenhos": desenhos}


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


## A caixa justa do desenho dentro de `regiao`, a area dele e onde fica o pe
## do pneu traseiro: a linha mais baixa e o meio dos pixels nela e logo acima.
func _caixa(cheio: PackedByteArray, largura: int, regiao: Rect2i) -> Dictionary:
	var minimo := Vector2i(regiao.end)
	var maximo := Vector2i(regiao.position)
	var area := 0
	for y in range(regiao.position.y, regiao.end.y):
		for x in range(regiao.position.x, regiao.end.x):
			if cheio[y * largura + x] == 1:
				area += 1
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
	return {"retangulo": Rect2i(minimo, maximo - minimo + Vector2i.ONE), "area": area, "pe": pe}


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


## Quanto o quadro `indice` do atlas desenha a moto deitada, em graus, positivo
## para a direita: o angulo da reta do pe do pneu ao alto do capacete, os
## centros das 11 linhas de baixo e das 13 de cima da silhueta. O
## `AtorSprite.INCLINACOES` tem de ter estes numeros, e o teste confere.
static func inclinacao(atlas: Image, indice: int) -> float:
	var topo := Vector2.ZERO
	var base := Vector2.ZERO
	var n_topo := 0
	var n_base := 0
	var primeira := -1
	var ultima := -1
	for y in CELULA.y:
		for x in CELULA.x:
			if atlas.get_pixel(indice * CELULA.x + x, y).a > 0.5:
				if primeira < 0:
					primeira = y
				ultima = y
	for y in range(primeira, ultima + 1):
		for x in CELULA.x:
			if atlas.get_pixel(indice * CELULA.x + x, y).a <= 0.5:
				continue
			if y <= primeira + 12:
				topo += Vector2(x, y)
				n_topo += 1
			if y >= ultima - 10:
				base += Vector2(x, y)
				n_base += 1
	topo /= maxf(n_topo, 1.0)
	base /= maxf(n_base, 1.0)
	return rad_to_deg(atan2(topo.x - base.x, base.y - topo.y))
