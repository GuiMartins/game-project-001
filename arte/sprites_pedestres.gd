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
## Faixa vazia, em pixels da folha, que separa dois desenhos.
const VAO: int = 4
const Recorte := preload("res://arte/recorte_de_folha.gd")
## Em que ponto do passo cada coluna do ciclo de andar esta, pela abertura das
## pernas: 0 junto (a perna passando pela outra), 1 no meio, 2 aberto (o
## calcanhar da frente tocando o chao). Dois passos em oito quadros, como a
## folha de pose (`arte/boneco_flow.gd`, `_pose_andando`) desenha.
const CICLO_DA_PASSADA: Array[int] = [0, 1, 2, 1, 0, 1, 2, 1]
## Os angulos em que a abertura mede a passada. De frente e de costas a perna
## que vai e a que volta ficam uma atras da outra, e a largura dos pes muda
## com o pe que levanta, nao com o passo: reordenar ali trocaria o ciclo da
## folha por um sorteio.
const ANGULOS_DA_PASSADA: Array[String] = ["tres_quartos_frente", "lado", "tres_quartos_costas"]
## Nem nesses a linha e reordenada quando a abertura quase nao varia nela: a
## medida vira ruido. Diferenca entre a maior e a menor abertura, sobre a
## altura.
const VARIACAO_MINIMA: float = 0.08
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
## na ordem das linhas do atlas. Uma folha so por animacao, desde a leva de
## 18/10/2026 (`docs/AUDITORIA_SPRITES.md`, S06); o texto continua aceitando
## mais, para quando uma linha sair errada e so ela for refeita.
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
		# A linha de costas da folha saiu de frente: ele andava para longe
		# mostrando o rosto. A de tres quartos de costas e costas puras, e
		{
			# serve as duas.
			"andando": ["adolescente_andando", 0, 1, 2, 3, 3],
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
			"andando": ["escritorio_andando", 0, 1, 2, 3, 4],
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
	# Segue depois de uma folha reprovada: o Flow erra varias numa leva, e
	# saber todas de uma vez e refazer todas de uma vez.
	var reprovadas: Array[String] = []
	for id: String in PESSOAS:
		var ficha: Dictionary = PESSOAS[id]
		for animacao: String in ficha["fontes"]:
			if not _atlas(id, animacao, ficha, folhas):
				reprovadas.append(id + "_" + animacao)
	if not reprovadas.is_empty():
		push_error("refaca no Flow: %s" % ", ".join(reprovadas))
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
		if animacao == "andando" and na_folha == REPARO_LINHA:
			da_linha[REPARO_COLUNA] = da_linha[REPARO_DE]
		# O Flow virou de costas o ultimo quadro frontal do operario. O
		# primeiro quadro fecha o ciclo na mesma pose e direcao.
		if id == "obra" and animacao == "andando" and linha == 0:
			da_linha[7] = da_linha[0]
		if animacao == "andando" and linhas[linha] in ANGULOS_DA_PASSADA:
			da_linha = _ordena_passada(da_linha)
		quadros.append(da_linha)
	var escala_folha := Recorte.escala_da_folha(regra, quadros, altura_px)
	for linha in linhas.size():
		var nome: String = origem[linha][0]
		var escala := (
			escala_folha
			if escala_folha > 0.0
			else Recorte.escala_da_linha(regra, quadros[linha], altura_px)
		)
		var chao := Recorte.chao_da_linha(quadros[linha])
		for coluna in colunas:
			Recorte.cola(
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


## A linha do andar na ordem do passo (`CICLO_DA_PASSADA`), pela abertura das
## pernas de cada quadro: os dois mais fechados nas passagens, os dois mais
## abertos nos contatos, e os quatro do meio entre eles. Dentro de cada grupo,
## a ordem da folha.
##
## O Flow nao segue a ordem das colunas da referencia ao pe da letra, e as
## folhas da primeira leva vieram de uma referencia embaralhada (ver
## `docs/AUDITORIA_SPRITES.md`, S01): a passada abria e fechava fora de
## ritmo, e o pedestre andava como quem tropeca. Qual perna esta na frente a
## medida nao ve; a 60 px de altura, na calcada, o olho tambem nao. O ritmo,
## ve.
func _ordena_passada(linha: Array) -> Array:
	var aberturas: Array = linha.map(func(q: Dictionary) -> float: return q["abertura"])
	if aberturas.max() - aberturas.min() < VARIACAO_MINIMA:
		return linha
	var indices: Array = range(linha.size())
	indices.sort_custom(func(a: int, b: int) -> bool: return aberturas[a] < aberturas[b])
	var grupos: Array[Array] = [indices.slice(0, 2), indices.slice(2, 6), indices.slice(6)]
	for grupo in grupos:
		grupo.sort()
	var saida: Array = []
	for ponto in CICLO_DA_PASSADA:
		saida.append(linha[grupos[ponto].pop_front()])
	return saida


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
func _folha(caminho: String, n_linhas: int, n_colunas: int, regra: Dictionary) -> Variant:
	var imagem := Recorte.carrega(caminho)
	if imagem == null:
		return null
	var cheio := Recorte.tira_verde(imagem)
	var desenhos := Recorte.acha_desenhos(
		cheio,
		imagem.get_width(),
		imagem.get_height(),
		VAO,
		int(regra["area_minima"]),
		Recorte.caixa_do_desenho
	)
	var contagem := Recorte.contagem(desenhos)
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
