extends SceneTree
## Recorta as folhas de pedestre geradas no Google Flow em atlas por pessoa e
## por animacao: `assets/sprites/pedestres/<id>_<animacao>.png` e o `.json` que
## descreve a grade.
##
##     python tools/dev.py sprites-pedestres
##
## As folhas (`arte/flow/pedestres/*.jpg`) sao a fonte, e o atlas e build: o
## mesmo principio de `arte/sprites_flow.gd`, que faz o piloto. A diferenca e o
## que se mede. O piloto alinha pelo pe do pneu e iguala a area da silhueta,
## porque gira e estica o braco. A pessoa anda, pula e voa, e cada animacao tem
## uma coisa que nao pode mudar de um quadro para o outro: em pe, a altura e o
## lugar do tronco; no ar, o tamanho e o centro do corpo; no chao, o comprimento
## e o contato com o asfalto. `ANIMACOES` diz qual vale para cada uma.
##
## Em todas:
##
## 1. tira o verde, com a borda dura (o pixel e da pessoa ou do fundo);
## 2. acha cada desenho pelos vaos entre eles, sem grade fixa, e confere que
##    sao `linhas` x `colunas`: o Flow erra a contagem, e o erro tem de aparecer
##    aqui, e nao como uma pessoa pulando de lugar no jogo;
## 3. escala a linha para a altura real da pessoa, por uma medida que nao muda
##    com a pose (`escala`), e nao a de cada quadro: a perna que se estica ou a
##    passada que abaixa o corpo mudam o desenho, e um sprite que inflasse e
##    desinflasse a cada passo parece respirar;
## 4. posiciona pela ancora da animacao (`ancora_x`, `ancora_y`).
##
## O lado esquerdo nao tem linha: o jogo espelha o direito.

## Pixels por metro do sprite, o mesmo em toda animacao. Na camera de
## perseguicao uma pessoa a 25 m tem uns 60 px dos 540; 100 px/m da 175 a uma
## pessoa de 1,75 m, o que ainda passa dos 100 px de perto sem o mipmap ter de
## adivinhar.
const PPM: float = 100.0
## Um pixel e fundo quando o verde passa os outros dois canais por esta margem
## (0-255). O JPEG suja a borda: abaixo disso sobra uma franja verde.
const MARGEM_VERDE: int = 40
## Faixa vazia, em pixels da folha, que separa dois desenhos.
const VAO: int = 4
## Quanto do topo do desenho entra no calculo do centro do tronco.
const FRACAO_TRONCO: float = 0.4
## O quadro 7 da linha de tres quartos de costas do andar sai virado de lado em
## todas as folhas: o Flow le a fase de 270 graus como uma virada. Vira copia do
## vizinho.
const REPARO_LINHA: int = 3
const REPARO_COLUNA: int = 6
const REPARO_DE: int = 5

const ORIGEM: String = "res://arte/flow/pedestres/"
const SAIDA: String = "res://assets/sprites/pedestres/"
## Onde saem as folhas de conferencia (atlas sobre cinza), fora do git.
const CONFERENCIA: String = "res://.dev/sprites_pedestres/"

## Cinco angulos, na ordem das linhas das folhas de pose
## (`arte/boneco_flow.gd`, `ANGULOS_*`).
const CINCO: Array[String] = [
	"frente", "tres_quartos_frente", "lado", "tres_quartos_costas", "costas"
]
const DIRECAO_DO_VOO: Array[String] = [
	"lado", "tres_quartos_costas", "costas", "tres_quartos_frente"
]

## Como cada animacao e medida e posta na celula.
##
## `escala`, a medida que vira a altura real da pessoa:
## - `altura`: a mediana das alturas dos quadros da linha (quem anda ou se
##   assusta passa a maior parte do tempo em pe);
## - `altura_alta`: o quartil de cima das alturas (no desembarque, metade dos
##   quadros esta sentada e so o resto mede a pessoa);
## - `coluna_zero`: a altura do primeiro quadro, que nas folhas de voo e sempre
##   o boneco em pe, antes de girar (nos outros, o corpo vira e a altura nao diz
##   nada);
## - `comprimento`: a largura do corpo deitado, na mediana das linhas de
##   `medir_linhas` (na linha de frente ele esta de ponta para a camera).
##
## `ancora_x`: `tronco` (o terco de cima do desenho) ou `centro` (o meio de
## todos os pixels). `ancora_y`: `pes` (o pe mais baixo no chao, quadro a
## quadro), `chao` (a linha do chao da linha da folha, e quem pula fica acima
## dela) ou `centro`.
const ANIMACOES: Dictionary = {
	"andando":
	{
		"linhas": CINCO,
		"colunas": 8,
		"celula": Vector2i(160, 200),
		"pe_y": 196,
		"area_minima": 4000,
		"escala": "altura",
		"ancora_x": "tronco",
		"ancora_y": "pes",
	},
	"susto":
	{
		"linhas": ["frente", "tres_quartos_frente", "lado"],
		"colunas": 6,
		"celula": Vector2i(224, 224),
		"pe_y": 220,
		"area_minima": 4000,
		"escala": "altura",
		"ancora_x": "tronco",
		"ancora_y": "chao",
	},
	"desembarcando":
	{
		"linhas":
		[
			"carro_de_lado",
			"carro_tres_quartos_frente",
			"carro_tres_quartos_costas",
			"carro_de_frente"
		],
		"colunas": 8,
		"celula": Vector2i(256, 208),
		"pe_y": 204,
		"area_minima": 4000,
		"escala": "altura_alta",
		"ancora_x": "tronco",
		"ancora_y": "chao",
	},
	"voando":
	{
		"linhas": DIRECAO_DO_VOO,
		"colunas": 8,
		"celula": Vector2i(240, 240),
		"pe_y": 120,
		"area_minima": 1200,
		"escala": "coluna_zero",
		"ancora_x": "centro",
		"ancora_y": "centro",
	},
	"caida":
	{
		"linhas": DIRECAO_DO_VOO,
		"colunas": 3,
		"celula": Vector2i(224, 112),
		"pe_y": 108,
		"area_minima": 4000,
		"escala": "comprimento",
		"medir_linhas": [0, 1, 3],
		"ancora_x": "centro",
		"ancora_y": "pes",
	},
}

## Cada pessoa: a altura real e de que folha vem cada linha de cada animacao.
## Na lista, um texto troca a folha e os numeros seguintes sao as linhas dela,
## na ordem das linhas do atlas. O escritorio anda por duas folhas: a primeira
## tem o passo certo em todas as linhas menos a de costas, que saiu de frente; a
## segunda tem as costas, e o passo de lado e mais fraco.
const PESSOAS: Dictionary = {
	"vovo":
	{
		"altura": 1.55,
		"fontes":
		{
			"andando": ["vovo_andando", 0, 1, 2, 3, 4],
			"susto": ["vovo_susto", 0, 1, 2],
			"desembarcando": ["vovo_desembarcando", 0, 1, 2, 3],
			"voando": ["vovo_voando", 0, 1, 2, 3],
			"caida": ["vovo_caida", 0, 1, 2, 3],
		},
	},
	"obra":
	{
		"altura": 1.78,
		"fontes":
		{
			"andando": ["obra_andando", 0, 1, 2, 3, 4],
			"susto": ["obra_susto", 0, 1, 2],
			"desembarcando": ["obra_desembarcando", 0, 1, 2, 3],
			"voando": ["obra_voando", 0, 1, 2, 3],
			"caida": ["obra_caida", 0, 1, 2, 3],
		},
	},
	"praia":
	{
		"altura": 1.75,
		"fontes":
		{
			"andando": ["praia_andando", 0, 1, 2, 3, 4],
			"susto": ["praia_susto", 0, 1, 2],
			"desembarcando": ["praia_desembarcando", 0, 1, 2, 3],
			"voando": ["praia_voando", 0, 1, 2, 3],
			"caida": ["praia_caida", 0, 1, 2, 3],
		},
	},
	"adolescente":
	{
		"altura": 1.65,
		"fontes":
		{
			"andando": ["adolescente_andando", 0, 1, 2, 3, 4],
			"susto": ["adolescente_susto", 0, 1, 2],
			"desembarcando": ["adolescente_desembarcando", 0, 1, 2, 3],
			"voando": ["adolescente_voando", 0, 1, 2, 3],
			"caida": ["adolescente_caida", 0, 1, 2, 3],
		},
	},
	"escritorio":
	{
		"altura": 1.68,
		"fontes":
		{
			"andando": ["escritorio_andando", 0, 1, 2, 3, "escritorio_andando_costas", 4],
			"susto": ["escritorio_susto", 0, 1, 2],
			"desembarcando": ["escritorio_desembarcando", 0, 1, 2, 3],
			"voando": ["escritorio_voando", 0, 1, 2, 3],
			"caida": ["escritorio_caida", 0, 1, 2, 3],
		},
	},
}


func _initialize() -> void:
	var folhas: Dictionary = {}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CONFERENCIA))
	for id: String in PESSOAS:
		var ficha: Dictionary = PESSOAS[id]
		for animacao: String in ficha["fontes"]:
			if not _atlas(id, animacao, ficha, folhas):
				quit(1)
				return
	quit(0)


func _atlas(id: String, animacao: String, ficha: Dictionary, folhas: Dictionary) -> bool:
	var regra: Dictionary = ANIMACOES[animacao]
	var linhas: Array = regra["linhas"]
	var colunas: int = regra["colunas"]
	var celula: Vector2i = regra["celula"]
	var altura_px: float = float(ficha["altura"]) * PPM
	var origem: Array = _origens(ficha["fontes"][animacao])
	var atlas := Image.create_empty(
		celula.x * colunas, celula.y * linhas.size(), false, Image.FORMAT_RGBA8
	)
	# Todos os desenhos da animacao antes de escalar: algumas medidas sao da
	# folha inteira (`comprimento`).
	var quadros: Array = []
	for linha in linhas.size():
		var nome: String = origem[linha][0]
		if not folhas.has(nome):
			folhas[nome] = _folha(ORIGEM + nome + ".jpg", linhas.size(), colunas, regra)
			if folhas[nome] == null:
				return false
		var desenhos: Array = folhas[nome]["desenhos"]
		var na_folha: int = origem[linha][1]
		if na_folha >= desenhos.size():
			push_error("%s: a folha nao tem a linha %d" % [nome, na_folha])
			return false
		var da_linha: Array = (desenhos[na_folha] as Array).duplicate()
		if animacao == "andando" and linha == REPARO_LINHA:
			da_linha[REPARO_COLUNA] = da_linha[REPARO_DE]
		# O Flow virou de costas o ultimo quadro frontal do operario. O
		# primeiro quadro fecha o ciclo na mesma pose e direcao.
		if id == "obra" and animacao == "andando" and linha == 0:
			da_linha[7] = da_linha[0]
		quadros.append(da_linha)
	var escala_folha := _escala_da_folha(regra, quadros, altura_px)
	for linha in linhas.size():
		var nome: String = origem[linha][0]
		var escala := (
			escala_folha if escala_folha > 0.0 else _escala(regra, quadros[linha], altura_px)
		)
		var chao := _chao(quadros[linha])
		for coluna in colunas:
			_cola(
				atlas,
				regra,
				Vector2i(coluna, linha),
				folhas[nome]["imagem"],
				quadros[linha][coluna],
				escala,
				chao
			)
		print("  %s %s %s: escala %.4f" % [id, animacao, linhas[linha], escala])
	var base := id + "_" + animacao
	var erro := atlas.save_png(SAIDA + base + ".png")
	if erro != OK:
		push_error("nao gravei %s: %s" % [base, error_string(erro)])
		return false
	_escreve_json(base, animacao, regra, ficha)
	_confere(base, atlas, regra)
	print(
		(
			"+ %s%s.png: %d x %d quadros de %dx%d"
			% [SAIDA, base, colunas, linhas.size(), celula.x, celula.y]
		)
	)
	return true


## As folhas de onde vem cada linha: o nome da folha e a linha dentro dela. Na
## lista da ficha, um texto troca a folha e os numeros seguintes sao as linhas
## dela, na ordem das linhas do atlas.
func _origens(lista: Array) -> Array:
	var saida: Array = []
	var folha := ""
	for item: Variant in lista:
		if item is String:
			folha = item
		else:
			saida.append([folha, item])
	return saida


## A escala unica da folha, para as medidas que a pedem; 0 quando cada linha tem
## a sua.
func _escala_da_folha(regra: Dictionary, quadros: Array, altura_px: float) -> float:
	if regra["escala"] != "comprimento":
		return 0.0
	var larguras := PackedFloat32Array()
	for i: int in regra["medir_linhas"]:
		for q: Dictionary in quadros[i]:
			larguras.append(float((q["retangulo"] as Rect2i).size.x))
	larguras.sort()
	return altura_px / larguras[larguras.size() / 2]


func _escala(regra: Dictionary, quadros: Array, altura_px: float) -> float:
	var alturas := PackedFloat32Array()
	for q: Dictionary in quadros:
		alturas.append(float((q["retangulo"] as Rect2i).size.y))
	var medida: float
	match regra["escala"]:
		"altura":
			alturas.sort()
			medida = (alturas[(alturas.size() - 1) / 2] + alturas[alturas.size() / 2]) * 0.5
		"altura_alta":
			alturas.sort()
			medida = alturas[int(float(alturas.size() - 1) * 0.75)]
		"coluna_zero":
			medida = alturas[0]
		_:
			push_error("escala desconhecida: %s" % regra["escala"])
			return 1.0
	return altura_px / medida


## A linha do chao da linha da folha: o fundo do desenho que apoia mais baixo,
## sem contar o de fora (no quartil de cima). Quem pula tem o fundo acima dela.
func _chao(quadros: Array) -> float:
	var fundos := PackedFloat32Array()
	for q: Dictionary in quadros:
		fundos.append(float(q["fundo"]))
	fundos.sort()
	return fundos[int(float(fundos.size() - 1) * 0.75)]


## A folha sem o verde e os desenhos achados nela, linha a linha. So devolve se
## a contagem for a da grade.
func _folha(caminho: String, n_linhas: int, n_colunas: int, regra: Dictionary) -> Variant:
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
			# O verde que o fundo rebate na borda da pessoa: o canal verde nunca
			# passa o maior dos outros dois.
			dados[p * 4 + 1] = mini(g, maxi(r, b))
			cheio[p] = 1
	imagem.set_data(largura, altura, false, Image.FORMAT_RGBA8, dados)

	var desenhos: Array = []
	for faixa in _faixas(_soma_linhas(cheio, largura, altura)):
		var linha: Array = []
		for corte in _faixas(_soma_colunas(cheio, largura, faixa.x, faixa.y)):
			var caixa := _caixa(
				cheio, largura, Rect2i(corte.x, faixa.x, corte.y - corte.x, faixa.y - faixa.x)
			)
			if caixa["area"] >= int(regra["area_minima"]):
				linha.append(caixa)
		if not linha.is_empty():
			desenhos.append(linha)
	var contagem: Array = desenhos.map(func(l: Array) -> int: return l.size())
	print("  %s: %s desenhos por linha" % [caminho.get_file(), contagem])
	if desenhos.size() < n_linhas or contagem.any(func(n: int) -> bool: return n != n_colunas):
		push_error(
			(
				"%s: a grade devia ser %d x %d e saiu %s - o Flow errou a contagem, refaca a folha"
				% [caminho.get_file(), n_linhas, n_colunas, contagem]
			)
		)
		return null
	return {"imagem": imagem, "desenhos": desenhos}


func _soma_linhas(cheio: PackedByteArray, largura: int, altura: int) -> PackedInt32Array:
	var soma := PackedInt32Array()
	soma.resize(altura)
	for y in altura:
		var n := 0
		for x in largura:
			n += cheio[y * largura + x]
		soma[y] = n
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


## A caixa justa do desenho dentro de `regiao`, a area dele, e os pontos de
## ancora: o meio dos pixels do terco de cima (que nao anda com a perna), o meio
## de todos eles e o fundo.
func _caixa(cheio: PackedByteArray, largura: int, regiao: Rect2i) -> Dictionary:
	var minimo := Vector2i(regiao.end)
	var maximo := Vector2i(regiao.position)
	var area := 0
	var soma := Vector2.ZERO
	for y in range(regiao.position.y, regiao.end.y):
		for x in range(regiao.position.x, regiao.end.x):
			if cheio[y * largura + x] == 1:
				area += 1
				soma += Vector2(x, y)
				minimo = minimo.min(Vector2i(x, y))
				maximo = maximo.max(Vector2i(x, y))
	var limite := minimo.y + int(float(maximo.y - minimo.y) * FRACAO_TRONCO)
	var soma_x := 0
	var n := 0
	for y in range(minimo.y, limite + 1):
		for x in range(minimo.x, maximo.x + 1):
			if cheio[y * largura + x] == 1:
				soma_x += x
				n += 1
	return {
		"retangulo": Rect2i(minimo, maximo - minimo + Vector2i.ONE),
		"area": area,
		"tronco_x": float(soma_x) / maxf(n, 1.0),
		"centro": soma / maxf(area, 1.0),
		"fundo": float(maximo.y + 1),
	}


## Reduz o desenho e cola na celula (`quadro` = coluna, linha), pela ancora da
## animacao. `chao` e a linha do chao da linha da folha, na escala dela.
func _cola(
	atlas: Image,
	regra: Dictionary,
	quadro: Vector2i,
	folha: Image,
	desenho: Dictionary,
	escala: float,
	chao: float
) -> void:
	var celula: Vector2i = regra["celula"]
	var caixa: Rect2i = desenho["retangulo"]
	var recorte := folha.get_region(caixa)
	var tamanho := Vector2i((Vector2(caixa.size) * escala).round()).max(Vector2i.ONE)
	recorte.resize(tamanho.x, tamanho.y, Image.INTERPOLATE_LANCZOS)
	var origem := quadro * celula
	var x: float
	if regra["ancora_x"] == "tronco":
		x = celula.x * 0.5 - (float(desenho["tronco_x"]) - caixa.position.x) * escala
	else:
		x = celula.x * 0.5 - ((desenho["centro"] as Vector2).x - caixa.position.x) * escala
	var y: float
	match regra["ancora_y"]:
		"pes":
			y = float(regra["pe_y"]) - tamanho.y
		"chao":
			y = float(regra["pe_y"]) - tamanho.y - (chao - float(desenho["fundo"])) * escala
		_:
			y = celula.y * 0.5 - ((desenho["centro"] as Vector2).y - caixa.position.y) * escala
	var destino := origem + Vector2i(roundi(x), roundi(y))
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
	var limite := Rect2i(origem, celula)
	var colado := Rect2i(destino, tamanho).intersection(limite)
	if colado.size != tamanho:
		print("  ! quadro %d da linha %d passou da celula e foi cortado" % [quadro.x, quadro.y])
	atlas.blit_rect(recorte, Rect2i(colado.position - destino, colado.size), colado.position)


func _escreve_json(base: String, animacao: String, regra: Dictionary, ficha: Dictionary) -> void:
	var celula: Vector2i = regra["celula"]
	var info := {
		"animacao": animacao,
		"celula": [celula.x, celula.y],
		"pe": [celula.x / 2, regra["pe_y"]],
		"colunas": regra["colunas"],
		"linhas": regra["linhas"],
		"altura_m": ficha["altura"],
		"pixels_por_metro": PPM,
		"espelha_o_lado_esquerdo": true,
	}
	var arquivo := FileAccess.open(SAIDA + base + ".json", FileAccess.WRITE)
	arquivo.store_string(JSON.stringify(info, "\t") + "\n")


## O atlas sobre cinza, com a linha do chao, para ver a olho se os pes ficam no
## mesmo lugar. Vai para `.dev/`, que o git ignora.
func _confere(base: String, atlas: Image, regra: Dictionary) -> void:
	var celula: Vector2i = regra["celula"]
	var fundo := Image.create_empty(
		atlas.get_width(), atlas.get_height(), false, Image.FORMAT_RGBA8
	)
	fundo.fill(Color(0.5, 0.5, 0.5))
	for linha in (regra["linhas"] as Array).size():
		for x in atlas.get_width():
			fundo.set_pixel(x, linha * celula.y + int(regra["pe_y"]), Color(1, 0, 1))
	fundo.blend_rect(atlas, Rect2i(Vector2i.ZERO, atlas.get_size()), Vector2i.ZERO)
	fundo.save_png(CONFERENCIA + base + ".png")
