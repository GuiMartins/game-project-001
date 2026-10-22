extends RefCounted
## O recorte das folhas do Google Flow, para todas as folhas: tira o verde, acha
## cada desenho pelos vaos entre eles, escala por uma medida que nao muda com a
## pose, poe pela ancora e grava o atlas com a ficha dele.
##
## Moravam copiados em `sprites_pedestres.gd`, `sprites_flow.gd` e
## `sprites_props.gd`, cada um com o seu jeito de achar a borda e de duas ou tres
## medidas iguais. Esta e a unica copia. Folha nova entra com uma ficha
## (`arte/flow/fichas/*.json`, lida pelo `arte/recortar.gd`), e nao com um script
## de 600 linhas: quem tem uma regra propria (a ordem da passada do pedestre, o
## angulo do piloto) chama as funcoes daqui e acrescenta so a regra.
##
## O Flow nao entrega grade: entrega um quadro com N desenhos, cada um num
## tamanho e numa posicao. Por isso o recorte acha cada desenho pelos vaos, e so
## depois confere que a contagem e a da ficha: o Flow erra a conta, e o erro tem
## de aparecer aqui, e nao como uma pessoa pulando de lugar no jogo.

## Um pixel e fundo quando o verde passa os outros dois canais por esta margem
## (0-255). O JPEG suja a borda: abaixo disso sobra uma franja verde.
const MARGEM_VERDE: int = 40
## Quanto do topo do desenho entra no calculo do centro do tronco.
const FRACAO_TRONCO: float = 0.4
## Quanto do pe da silhueta mede a abertura das pernas.
const FRACAO_PES: float = 0.15

## Os campos que uma ficha de folha precisa ter, e o que cada um diz.
##
## - `fonte`: a imagem do Flow, `res://...jpg`.
## - `saida`: o prefixo do que sai, sem extensao: `<saida>.png` e `<saida>.json`.
## - `linhas`: o nome de cada linha (o angulo ou a pose); o tamanho dela e o
##   numero de linhas da grade.
## - `colunas`: quantos desenhos tem cada linha.
## - `celula`: [largura, altura] de cada quadro do atlas, em pixels.
## - `pe_y`: onde fica o chao na celula, de cima para baixo.
## - `altura_m` e `pixels_por_metro`: o tamanho real do que se desenha, e a
##   medida comum de todas as folhas (sem ela o sprite muda de tamanho na troca).
## - `escala`: `altura`, `altura_alta`, `coluna_zero` ou `comprimento`.
## - `ancora_x`: `tronco` ou `centro`. `ancora_y`: `pes`, `chao` ou `centro`.
## - `vao` e `area_minima`: o que separa dois desenhos e o que e sujeira.
## - `espelho`: o lado esquerdo sai por espelho do direito (ver o `.json`).
## - `luzes`: pontos que o shader acende (lanterna, farol, lente, vidro), cada um
##   `{"nome", "linha", "coluna", "ponto": [x, y]}` em pixels da celula. O recorte
##   so confere que cada ponto cai dentro dela e os repassa: luz nao e desenho,
##   e uma camada de luz pedida ao Flow nunca cai no mesmo pixel da folha de base.
const CAMPOS_DA_FICHA: PackedStringArray = [
	"fonte",
	"saida",
	"linhas",
	"colunas",
	"celula",
	"pe_y",
	"altura_m",
	"pixels_por_metro",
	"escala",
	"ancora_x",
	"ancora_y",
	"vao",
	"area_minima",
]


## A imagem lida do disco e convertida para RGBA8, ou null (e erro) se nao ler.
static func carrega(caminho: String) -> Image:
	var imagem := Image.load_from_file(ProjectSettings.globalize_path(caminho))
	if imagem == null or imagem.is_empty():
		push_error("nao li %s - rode `git lfs pull`" % caminho)
		return null
	imagem.convert(Image.FORMAT_RGBA8)
	return imagem


## Tira o verde de `imagem`, com a borda dura (o pixel e do desenho ou do
## fundo), e devolve a mascara: 1 onde ficou desenho.
static func tira_verde(imagem: Image, margem: int = MARGEM_VERDE) -> PackedByteArray:
	var largura := imagem.get_width()
	var altura := imagem.get_height()
	var dados := imagem.get_data()
	var cheio := PackedByteArray()
	cheio.resize(largura * altura)
	for p in largura * altura:
		var r := dados[p * 4]
		var g := dados[p * 4 + 1]
		var b := dados[p * 4 + 2]
		if g - maxi(r, b) > margem:
			# Pre-multiplicado: o fundo vira preto transparente, e a reducao
			# nao puxa verde para dentro da borda.
			dados[p * 4] = 0
			dados[p * 4 + 1] = 0
			dados[p * 4 + 2] = 0
			dados[p * 4 + 3] = 0
		else:
			# O verde que o fundo rebate na borda do desenho: o canal verde
			# nunca passa o maior dos outros dois.
			dados[p * 4 + 1] = mini(g, maxi(r, b))
			cheio[p] = 1
	imagem.set_data(largura, altura, false, Image.FORMAT_RGBA8, dados)
	return cheio


## Os desenhos achados em `cheio`, linha a linha. `medidor` e chamado com
## (cheio, largura, regiao) e devolve o que se mede de cada desenho, sempre com
## `area`: quem tem medida propria (o pe do pneu, o tronco) passa a sua.
static func acha_desenhos(
	cheio: PackedByteArray, largura: int, altura: int, vao: int, area_minima: int, medidor: Callable
) -> Array:
	var desenhos: Array = []
	for faixa in faixas(soma_linhas(cheio, largura, altura), vao):
		var linha: Array = []
		for corte in faixas(soma_colunas(cheio, largura, faixa.x, faixa.y), vao):
			var caixa: Dictionary = medidor.call(
				cheio, largura, Rect2i(corte.x, faixa.x, corte.y - corte.x, faixa.y - faixa.x)
			)
			if caixa["area"] >= area_minima:
				linha.append(caixa)
		if not linha.is_empty():
			desenhos.append(linha)
	return desenhos


## Quantos desenhos ha em cada linha achada.
static func contagem(desenhos: Array) -> Array:
	return desenhos.map(func(l: Array) -> int: return l.size())


static func soma_linhas(cheio: PackedByteArray, largura: int, altura: int) -> PackedInt32Array:
	var soma := PackedInt32Array()
	soma.resize(altura)
	for y in altura:
		var n := 0
		for x in largura:
			n += cheio[y * largura + x]
		soma[y] = n
	return soma


static func soma_colunas(
	cheio: PackedByteArray, largura: int, y0: int, y1: int
) -> PackedInt32Array:
	var soma := PackedInt32Array()
	soma.resize(largura)
	for y in range(y0, y1):
		for x in largura:
			soma[x] += cheio[y * largura + x]
	return soma


## Os trechos ocupados de uma projecao, como (inicio, fim), juntando os que um
## vao menor que `vao` separa.
static func faixas(soma: PackedInt32Array, vao: int) -> Array[Vector2i]:
	var achadas: Array[Vector2i] = []
	var inicio := -1
	var vazio := 0
	for i in soma.size():
		if soma[i] > 2:
			if inicio < 0:
				inicio = i
			vazio = 0
		elif inicio >= 0:
			vazio += 1
			if vazio >= vao:
				achadas.append(Vector2i(inicio, i - vazio + 1))
				inicio = -1
	if inicio >= 0:
		achadas.append(Vector2i(inicio, soma.size() - vazio))
	return achadas


## A caixa justa do desenho dentro de `regiao`, a area dele, e os pontos de
## ancora: o meio dos pixels do terco de cima (que nao anda com a perna), o meio
## de todos eles, o fundo e a abertura das pernas, que diz em que ponto do passo
## o quadro esta.
static func caixa_do_desenho(cheio: PackedByteArray, largura: int, regiao: Rect2i) -> Dictionary:
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
	var pe_min := maximo.x
	var pe_max := minimo.x
	var faixa_pe := maxi(int(float(maximo.y - minimo.y) * FRACAO_PES), 1)
	for y in range(maximo.y - faixa_pe, maximo.y + 1):
		for x in range(minimo.x, maximo.x + 1):
			if cheio[y * largura + x] == 1:
				pe_min = mini(pe_min, x)
				pe_max = maxi(pe_max, x)
	return {
		"retangulo": Rect2i(minimo, maximo - minimo + Vector2i.ONE),
		"area": area,
		"tronco_x": float(soma_x) / maxf(n, 1.0),
		"centro": soma / maxf(area, 1.0),
		"fundo": float(maximo.y + 1),
		"abertura": float(maxi(pe_max - pe_min, 0)) / float(maximo.y - minimo.y + 1),
	}


## A escala unica da folha, para as medidas que a pedem; 0 quando cada linha tem
## a sua. `quadros` e o desenho de cada linha, na ordem das linhas.
static func escala_da_folha(regra: Dictionary, quadros: Array, altura_px: float) -> float:
	if regra["escala"] != "comprimento":
		return 0.0
	var larguras := PackedFloat32Array()
	for i: int in regra["medir_linhas"]:
		for q: Dictionary in quadros[i]:
			larguras.append(float((q["retangulo"] as Rect2i).size.x))
	larguras.sort()
	return altura_px / larguras[larguras.size() / 2]


## A escala de uma linha: o que da a `altura_px` a medida que nao muda com a
## pose.
## - `altura`: a mediana das alturas (quem anda passa a maior parte em pe);
## - `altura_alta`: o quartil de cima (metade dos quadros esta sentada);
## - `coluna_zero`: a altura do primeiro quadro, o boneco em pe antes de girar.
static func escala_da_linha(regra: Dictionary, linha: Array, altura_px: float) -> float:
	var alturas := PackedFloat32Array()
	for q: Dictionary in linha:
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
static func chao_da_linha(linha: Array) -> float:
	var fundos := PackedFloat32Array()
	for q: Dictionary in linha:
		fundos.append(float(q["fundo"]))
	fundos.sort()
	return fundos[int(float(fundos.size() - 1) * 0.75)]


## Reduz o desenho e cola na celula (`quadro` = coluna, linha), pela ancora da
## regra. `chao` e a linha do chao da linha da folha, na escala dela.
static func cola(
	atlas: Image,
	regra: Dictionary,
	quadro: Vector2i,
	folha: Image,
	desenho: Dictionary,
	escala: float,
	chao: float
) -> void:
	var celula := _celula(regra)
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
	borda_dura(recorte)
	# Cortado na celula: um braco que passasse dela apareceria no quadro vizinho.
	var limite := Rect2i(origem, celula)
	var colado := Rect2i(destino, tamanho).intersection(limite)
	if colado.size != tamanho:
		print("  ! quadro %d da linha %d passou da celula e foi cortado" % [quadro.x, quadro.y])
	atlas.blit_rect(recorte, Rect2i(colado.position - destino, colado.size), colado.position)


## A borda dura: desfaz o pre-multiplicado e corta o alfa no meio. Meio-tom na
## silhueta e o que faz um sprite ler como recortado por tesoura de IA, e nao
## como digitalizado.
static func borda_dura(recorte: Image) -> void:
	var tamanho := recorte.get_size()
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


## O atlas de uma ficha, a partir da folha ja lida. Devolve `{"atlas": Image,
## "escalas": Array[float]}`, ou `{"erro": String}` se a ficha estiver errada ou
## o Flow tiver errado a contagem: o erro e o que a pessoa le para refazer a
## folha, e por isso diz a grade que esperava e a que achou.
static func atlas_da_ficha(ficha: Dictionary, imagem: Image) -> Dictionary:
	var erro := confere_ficha(ficha)
	if erro != "":
		return {"erro": erro}
	var linhas: Array = ficha["linhas"]
	var colunas: int = ficha["colunas"]
	var celula := _celula(ficha)
	var cheio := tira_verde(imagem, int(ficha.get("margem_verde", MARGEM_VERDE)))
	var desenhos := acha_desenhos(
		cheio,
		imagem.get_width(),
		imagem.get_height(),
		int(ficha["vao"]),
		int(ficha["area_minima"]),
		caixa_do_desenho
	)
	var achados := contagem(desenhos)
	if desenhos.size() != linhas.size() or achados.any(func(n: int) -> bool: return n != colunas):
		return {
			"erro":
			(
				"a grade devia ser %d x %d e saiu %s - o Flow errou a contagem, refaca a folha"
				% [linhas.size(), colunas, achados]
			)
		}
	var altura_px := float(ficha["altura_m"]) * float(ficha["pixels_por_metro"])
	var atlas := Image.create_empty(
		celula.x * colunas, celula.y * linhas.size(), false, Image.FORMAT_RGBA8
	)
	var escala_unica := escala_da_folha(ficha, desenhos, altura_px)
	var escalas: Array[float] = []
	for linha in linhas.size():
		var escala := (
			escala_unica
			if escala_unica > 0.0
			else escala_da_linha(ficha, desenhos[linha], altura_px)
		)
		escalas.append(escala)
		var chao := chao_da_linha(desenhos[linha])
		for coluna in colunas:
			cola(
				atlas, ficha, Vector2i(coluna, linha), imagem, desenhos[linha][coluna], escala, chao
			)
	return {"atlas": atlas, "escalas": escalas}


## Confere que a ficha tem todos os campos e que as luzes caem na celula. Devolve
## o erro, ou "" se estiver certa.
static func confere_ficha(ficha: Dictionary) -> String:
	for campo in CAMPOS_DA_FICHA:
		if not ficha.has(campo):
			return "falta o campo `%s`" % campo
	var celula := _celula(ficha)
	var linhas: Array = ficha["linhas"]
	var colunas: int = ficha["colunas"]
	for luz: Dictionary in ficha.get("luzes", []):
		var ponto := Vector2(luz["ponto"][0], luz["ponto"][1])
		if (
			ponto.x < 0.0
			or ponto.y < 0.0
			or ponto.x >= celula.x
			or ponto.y >= celula.y
			or int(luz["linha"]) >= linhas.size()
			or int(luz["coluna"]) >= colunas
		):
			return "a luz `%s` cai fora da celula %s" % [luz.get("nome", "?"), celula]
	return ""


## O `.json` que acompanha o atlas: o que o jogo precisa para desenhar e o que o
## shader precisa para acender.
static func ficha_do_atlas(ficha: Dictionary) -> Dictionary:
	var celula := _celula(ficha)
	var info := {
		"celula": [celula.x, celula.y],
		"pe": [celula.x / 2, int(ficha["pe_y"])],
		"colunas": int(ficha["colunas"]),
		"linhas": ficha["linhas"],
		"altura_m": ficha["altura_m"],
		"pixels_por_metro": ficha["pixels_por_metro"],
		"espelha_o_lado_esquerdo": ficha.get("espelho", false),
	}
	if ficha.has("luzes"):
		info["luzes"] = ficha["luzes"]
	return info


static func _celula(regra: Dictionary) -> Vector2i:
	var celula: Variant = regra["celula"]
	if celula is Vector2i:
		return celula
	return Vector2i(int(celula[0]), int(celula[1]))
