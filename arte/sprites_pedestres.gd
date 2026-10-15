extends SceneTree
## Recorta as folhas de pedestre geradas no Google Flow em atlas por pessoa:
## `assets/sprites/pedestres/<id>.png` e o `<id>.json` que descreve a grade.
##
##     python tools/dev.py sprites-pedestres
##
## As folhas (`arte/flow/pedestres/*.jpg`) sao a fonte, e o atlas e build: o
## mesmo principio de `arte/sprites_flow.gd`, que faz o piloto. A diferenca e o
## que se mede. O piloto alinha pelo pe do pneu e iguala a area da silhueta,
## porque gira e estica o braco. A pessoa anda, e o que nao pode mudar de um
## quadro para outro e a altura dela e o lugar do tronco:
##
## 1. tira o verde, com a borda dura (o pixel e da pessoa ou do fundo);
## 2. acha cada desenho pelos vaos entre eles, sem grade fixa, e confere que
##    sao `LINHAS` x `COLUNAS`: o Flow erra a contagem, e o erro tem de aparecer
##    aqui, e nao como uma pessoa pulando de lugar no jogo;
## 3. escala a linha inteira para a altura real da pessoa. A medida e a mediana
##    dos oito quadros da linha, e nao a de cada um: a perna que se estica ou a
##    passada que abaixa o corpo mudam a altura do desenho, e um sprite que
##    inflasse e desinflasse a cada passo parece respirar;
## 4. poe o pe mais baixo na linha do chao e o tronco no meio da celula. O tronco
##    e a media dos pixels do terco de cima, e nao a caixa: na caixa, a perna
##    que abre empurra a pessoa para o lado a cada passo.
##
## O lado esquerdo nao tem linha: o jogo espelha o direito.

## Cinco angulos, na ordem das linhas das folhas de pose
## (`arte/boneco_flow.gd`, `ANGULOS_CINCO`).
const LINHAS: Array[String] = [
	"frente", "tres_quartos_frente", "lado", "tres_quartos_costas", "costas"
]
const COLUNAS: int = 8
## Pixels por metro do sprite. Na camera de perseguicao uma pessoa a 25 m tem
## uns 60 px dos 540; 100 px/m da 175 a uma pessoa de 1,75 m, o que ainda
## passa dos 100 px de perto sem o mipmap ter de adivinhar.
const PPM: float = 100.0
## Celula do atlas. A largura cabe a passada de lado e o braco aberto; o pe fica
## perto do fundo, com folga para o contorno.
const CELULA := Vector2i(160, 200)
const PE_Y: int = 196
## Um pixel e fundo quando o verde passa os outros dois canais por esta margem
## (0-255). O JPEG suja a borda: abaixo disso sobra uma franja verde.
const MARGEM_VERDE: int = 40
## Faixa vazia, em pixels da folha, que separa dois desenhos.
const VAO: int = 12
## Desenho com menos pixels que isto e sujeira do JPEG, nao quadro.
const AREA_MINIMA: int = 4000
## Quanto do topo do desenho entra no calculo do centro do tronco.
const FRACAO_TRONCO: float = 0.4
## O quadro 7 da linha de tres quartos de costas sai virado de lado em todas as
## folhas: o Flow le a fase de 270 graus como uma virada. Vira copia do vizinho.
const REPARO_LINHA: int = 3
const REPARO_COLUNA: int = 6
const REPARO_DE: int = 5

const ORIGEM: String = "res://arte/flow/pedestres/"
const SAIDA: String = "res://assets/sprites/pedestres/"
## Onde saem as folhas de conferencia (atlas sobre cinza), fora do git.
const CONFERENCIA: String = "res://.dev/sprites_pedestres/"

## Cada pessoa: a altura real e de que folha vem cada linha. O escritorio vem de
## duas: a primeira tem o passo certo em todas as linhas menos a de costas, que
## saiu de frente; a segunda tem as costas, e o passo de lado e mais fraco.
const PESSOAS: Dictionary = {
	"vovo": {"altura": 1.55, "linhas": ["vovo_andando", 0, 1, 2, 3, 4]},
	"obra": {"altura": 1.78, "linhas": ["obra_andando", 0, 1, 2, 3, 4]},
	"praia": {"altura": 1.75, "linhas": ["praia_andando", 0, 1, 2, 3, 4]},
	"adolescente": {"altura": 1.65, "linhas": ["adolescente_andando", 0, 1, 2, 3, 4]},
	"escritorio":
	{
		"altura": 1.68,
		"linhas": ["escritorio_andando", 0, 1, 2, 3, "escritorio_andando_costas", 4],
	},
}


func _initialize() -> void:
	var folhas: Dictionary = {}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CONFERENCIA))
	for id: String in PESSOAS:
		if not _pessoa(id, PESSOAS[id], folhas):
			quit(1)
			return
	quit(0)


func _pessoa(id: String, ficha: Dictionary, folhas: Dictionary) -> bool:
	var altura_px: float = float(ficha["altura"]) * PPM
	var origem: Array = _origens(ficha["linhas"])
	var atlas := Image.create_empty(
		CELULA.x * COLUNAS, CELULA.y * LINHAS.size(), false, Image.FORMAT_RGBA8
	)
	for linha in LINHAS.size():
		var nome: String = origem[linha][0]
		if not folhas.has(nome):
			folhas[nome] = _folha(ORIGEM + nome + ".jpg")
			if folhas[nome] == null:
				return false
		var desenhos: Array = folhas[nome]["desenhos"]
		var na_folha: int = origem[linha][1]
		if na_folha >= desenhos.size():
			push_error("%s: a folha nao tem a linha %d" % [nome, na_folha])
			return false
		var quadros: Array = (desenhos[na_folha] as Array).duplicate()
		if linha == REPARO_LINHA:
			quadros[REPARO_COLUNA] = quadros[REPARO_DE]
		var alturas := PackedFloat32Array()
		for q: Dictionary in quadros:
			alturas.append(float((q["retangulo"] as Rect2i).size.y))
		alturas.sort()
		var escala := altura_px / ((alturas[3] + alturas[4]) * 0.5)
		for coluna in COLUNAS:
			_cola(atlas, coluna, linha, folhas[nome]["imagem"], quadros[coluna], escala)
		print("  %s %s: escala %.4f" % [id, LINHAS[linha], escala])
	var png := SAIDA + id + ".png"
	var erro := atlas.save_png(png)
	if erro != OK:
		push_error("nao gravei %s: %s" % [png, error_string(erro)])
		return false
	_escreve_json(id, ficha)
	_confere(id, atlas)
	print("+ %s: %d x %d quadros de %dx%d" % [png, COLUNAS, LINHAS.size(), CELULA.x, CELULA.y])
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


## A folha sem o verde e os desenhos achados nela, linha a linha. So devolve se
## a contagem for a da grade.
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
			if caixa["area"] >= AREA_MINIMA:
				linha.append(caixa)
		if not linha.is_empty():
			desenhos.append(linha)
	var contagem: Array = desenhos.map(func(l: Array) -> int: return l.size())
	print("  %s: %s desenhos por linha" % [caminho.get_file(), contagem])
	if desenhos.size() < LINHAS.size() or contagem.any(func(n: int) -> bool: return n != COLUNAS):
		push_error(
			(
				"%s: a grade devia ser %d x %d e saiu %s - o Flow errou a contagem, refaca a folha"
				% [caminho.get_file(), LINHAS.size(), COLUNAS, contagem]
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


## A caixa justa do desenho dentro de `regiao`, a area dele e onde fica o
## tronco: o meio dos pixels do terco de cima, que nao anda com a perna.
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
	var limite := minimo.y + int(float(maximo.y - minimo.y) * FRACAO_TRONCO)
	var soma_x := 0
	var n := 0
	for y in range(minimo.y, limite + 1):
		for x in range(minimo.x, maximo.x + 1):
			if cheio[y * largura + x] == 1:
				soma_x += x
				n += 1
	var tronco_x := float(soma_x) / maxf(n, 1.0)
	return {
		"retangulo": Rect2i(minimo, maximo - minimo + Vector2i.ONE),
		"area": area,
		"tronco_x": tronco_x,
	}


## Reduz o desenho e cola na celula (`coluna`, `linha`), com o tronco no meio e
## o pe mais baixo em `PE_Y`.
func _cola(
	atlas: Image, coluna: int, linha: int, folha: Image, desenho: Dictionary, escala: float
) -> void:
	var caixa: Rect2i = desenho["retangulo"]
	var recorte := folha.get_region(caixa)
	var tamanho := Vector2i((Vector2(caixa.size) * escala).round()).max(Vector2i.ONE)
	recorte.resize(tamanho.x, tamanho.y, Image.INTERPOLATE_LANCZOS)
	var tronco_x: float = (float(desenho["tronco_x"]) - float(caixa.position.x)) * escala
	var origem := Vector2i(coluna * CELULA.x, linha * CELULA.y)
	var destino := origem + Vector2i(roundi(CELULA.x * 0.5 - tronco_x), PE_Y - tamanho.y)
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
	var celula := Rect2i(origem, CELULA)
	var colado := Rect2i(destino, tamanho).intersection(celula)
	if colado.size != tamanho:
		print("  ! quadro %d da linha %d passou da celula e foi cortado" % [coluna, linha])
	atlas.blit_rect(recorte, Rect2i(colado.position - destino, colado.size), colado.position)


func _escreve_json(id: String, ficha: Dictionary) -> void:
	var info := {
		"celula": [CELULA.x, CELULA.y],
		"pe": [CELULA.x / 2, PE_Y],
		"colunas": COLUNAS,
		"linhas": LINHAS,
		"altura_m": ficha["altura"],
		"pixels_por_metro": PPM,
		"espelha_o_lado_esquerdo": true,
	}
	var arquivo := FileAccess.open(SAIDA + id + ".json", FileAccess.WRITE)
	arquivo.store_string(JSON.stringify(info, "\t") + "\n")


## O atlas sobre cinza, com a linha do chao, para ver a olho se os pes ficam
## no mesmo lugar. Vai para `.dev/`, que o git ignora.
func _confere(id: String, atlas: Image) -> void:
	var fundo := Image.create_empty(
		atlas.get_width(), atlas.get_height(), false, Image.FORMAT_RGBA8
	)
	fundo.fill(Color(0.5, 0.5, 0.5))
	for linha in LINHAS.size():
		for x in atlas.get_width():
			fundo.set_pixel(x, linha * CELULA.y + PE_Y, Color(1, 0, 1))
	fundo.blend_rect(atlas, Rect2i(Vector2i.ZERO, atlas.get_size()), Vector2i.ZERO)
	fundo.save_png(CONFERENCIA + id + ".png")
