class_name ReferenciaSprites
extends RefCounted
## A referência de pose que foi ao Google Flow: o `Pessoa` do jogo, posado pelo
## mesmo código que o anima, num boneco cinza (`dev.py boneco`,
## `arte/boneco_flow.gd`; as folhas em `arte/flow/referencia/`).
##
## O Flow redesenhou cada célula com uma pessoa em cima do boneco, e daí saíram
## os atlas. Pôr a célula do atlas ao lado da célula do boneco mostra se o Flow
## errou a pose. E mostra o outro lado, que sem isto ninguém vê: a referência
## pode ter saído ruim (quadros iguais, perna que não abre, boneco colado na
## borda), e aí o Flow desenhou direito o que lhe pediram errado.
##
## Uma folha por animação, e não por pessoa: as cinco pessoas partem da mesma.

const PASTA: String = "res://arte/flow/referencia"
## A mesma margem do recorte: pixel é fundo quando o verde passa os outros dois
## canais por isto (0-255).
const MARGEM_VERDE: int = 40
## Altura que a célula da referência ganha depois de reduzida. A original tem
## 400 a 540 px de altura; perto da dos sprites (200 a 240) a comparação não
## perde detalhe e a conta fica quatro vezes mais barata.
const ALTURA_CELULA: int = 200
## Quanto o corpo da referência pode variar de altura dentro de uma linha antes
## de a referência virar suspeita: boneco que muda de tamanho entre quadros de
## uma mesma linha passa o erro adiante.
const VARIACAO_ALTURA: float = 0.10
## Dois quadros seguidos com IoU acima disto são o mesmo quadro.
const IGUAIS: float = 0.995
## Abertura de perna que separa "junto" de "aberto" no ciclo de andar, sobre a
## altura (a perna aberta passa de 0,20 e a junta fica abaixo de 0,12).
const ABERTURA_MINIMA: float = 0.04

static var _cache: Dictionary = {}
static var _trava := Mutex.new()

## A folha reduzida e com o verde tirado (alfa 0), a grade e as silhuetas.
var animacao: String = ""
var imagem: Image
var colunas: int = 1
var linhas: int = 1
var celula := Vector2i.ZERO
var silhuetas: Array[Silhueta] = []
var avisos: PackedStringArray = []
## Avisos por quadro, na ordem `linha * colunas + coluna`.
var avisos_do_quadro: Dictionary = {}


## A referência da animação, ou null se a folha não existe (a moto não tem).
## Lê e mede uma vez; as demais chamadas devolvem o mesmo objeto.
static func de(animacao: String, colunas: int, linhas: int) -> ReferenciaSprites:
	_trava.lock()
	var chave := "%s:%d:%d" % [animacao, colunas, linhas]
	if not _cache.has(chave):
		_cache[chave] = _carregar(animacao, colunas, linhas)
	var achada: ReferenciaSprites = _cache[chave]
	_trava.unlock()
	return achada


static func caminho(animacao: String) -> String:
	return "%s/%s.png" % [PASTA, animacao]


static func _carregar(animacao: String, colunas: int, linhas: int) -> ReferenciaSprites:
	var arquivo := ProjectSettings.globalize_path(caminho(animacao))
	if not FileAccess.file_exists(arquivo):
		return null
	var cheia := Image.load_from_file(arquivo)
	if cheia == null or cheia.is_empty():
		return null
	var ref := ReferenciaSprites.new()
	ref.animacao = animacao
	ref.colunas = colunas
	ref.linhas = linhas
	# A grade da folha de pose e uniforme: o `boneco_flow.gd` poe uma celula de
	# mesmo tamanho para cada pose.
	var original := Vector2i(cheia.get_width() / colunas, cheia.get_height() / linhas)
	var fator := float(ALTURA_CELULA) / float(original.y)
	ref.celula = Vector2i(roundi(original.x * fator), ALTURA_CELULA)
	cheia.resize(ref.celula.x * colunas, ref.celula.y * linhas, Image.INTERPOLATE_BILINEAR)
	ref.imagem = _tira_o_verde(cheia)
	for l in linhas:
		for c in colunas:
			var celula_img := ref.imagem.get_region(Rect2i(_origem(ref, c, l), ref.celula))
			ref.silhuetas.append(Silhueta.de_imagem(celula_img))
	_diagnostica(ref)
	return ref


static func _origem(ref: ReferenciaSprites, coluna: int, linha: int) -> Vector2i:
	return Vector2i(coluna * ref.celula.x, linha * ref.celula.y)


## Verde vira transparente. Em bytes, e nao pixel a pixel: a folha reduzida
## ainda tem uns 800 mil pixels.
static func _tira_o_verde(origem: Image) -> Image:
	var rgba := origem.duplicate() as Image
	rgba.convert(Image.FORMAT_RGBA8)
	var dados := rgba.get_data()
	var n := dados.size()
	var i := 0
	while i < n:
		var r := dados[i]
		var g := dados[i + 1]
		var b := dados[i + 2]
		if g - maxi(r, b) > MARGEM_VERDE:
			dados[i + 3] = 0
		i += 4
	return Image.create_from_data(
		rgba.get_width(), rgba.get_height(), false, Image.FORMAT_RGBA8, dados
	)


## A célula da referência, já sem o verde.
func celula_imagem(coluna: int, linha: int) -> Image:
	return imagem.get_region(Rect2i(_origem(self, coluna, linha), celula))


func silhueta(coluna: int, linha: int) -> Silhueta:
	var i := linha * colunas + coluna
	return silhuetas[i] if i >= 0 and i < silhuetas.size() else Silhueta.new()


static func _diagnostica(ref: ReferenciaSprites) -> void:
	for l in ref.linhas:
		var alturas: Array[int] = []
		for c in ref.colunas:
			var s := ref.silhueta(c, l)
			if s.vazia():
				_nota(ref, c, l, "a referencia nao tem boneco nesta celula")
				continue
			alturas.append(s.caixa.size.y)
			if (
				s.caixa.position.x <= 1
				or s.caixa.position.y <= 1
				or s.caixa.end.x >= ref.celula.x - 1
				or s.caixa.end.y >= ref.celula.y - 1
			):
				_nota(ref, c, l, "o boneco encosta na borda da celula (cortado pela grade?)")
			if c > 0 and not ref.silhueta(c - 1, l).vazia():
				if Silhueta.iou(ref.silhueta(c - 1, l), s) >= IGUAIS and ref.animacao != "caida":
					_nota(ref, c, l, "igual ao quadro anterior: a referencia nao anda aqui")
		if alturas.size() > 1:
			var menor: int = alturas.min()
			var maior: int = alturas.max()
			if float(maior - menor) / float(maior) > VARIACAO_ALTURA and ref.animacao == "andando":
				ref.avisos.append(
					(
						"linha %d: o boneco varia de %d a %d px de altura entre quadros"
						% [l, menor, maior]
					)
				)
	if ref.animacao == "andando":
		_diagnostica_passada(ref)
	# Uma linha por tipo de problema, com a lista dos quadros: 12 avisos iguais
	# escondem o 13o que e diferente.
	var por_nota: Dictionary = {}
	var chaves: Array = ref.avisos_do_quadro.keys()
	chaves.sort()
	for chave: int in chaves:
		for nota: String in ref.avisos_do_quadro[chave]:
			var onde: Array = por_nota.get(nota, [])
			onde.append("%d/%d" % [chave % ref.colunas + 1, chave / ref.colunas + 1])
			por_nota[nota] = onde
	for nota: String in por_nota:
		ref.avisos.append("%s (quadro/linha: %s)" % [nota, ", ".join(por_nota[nota])])


## O ciclo de andar da referencia tem de abrir a perna onde a folha diz
## (`CICLO_DA_PASSADA`): as colunas 3 e 7 (indice 2 e 6) abertas, as 1 e 5
## juntas. Se nao abre, o Flow nao tem o que copiar.
static func _diagnostica_passada(ref: ReferenciaSprites) -> void:
	for l: int in [1, 2, 3]:
		var aberturas: Array[float] = []
		for c in ref.colunas:
			var img := ref.celula_imagem(c, l)
			aberturas.append(ref.silhueta(c, l).abertura(img))
		var juntas := (aberturas[0] + aberturas[4]) * 0.5
		var abertas := (aberturas[2] + aberturas[6]) * 0.5
		if abertas - juntas < ABERTURA_MINIMA:
			(
				ref
				. avisos
				. append(
					(
						"linha %d: a passada nao abre (juntas %.2f, abertas %.2f da altura): sem ciclo para copiar"
						% [l, juntas, abertas]
					)
				)
			)


static func _nota(ref: ReferenciaSprites, coluna: int, linha: int, texto: String) -> void:
	var chave := linha * ref.colunas + coluna
	var notas: PackedStringArray = ref.avisos_do_quadro.get(chave, PackedStringArray())
	notas.append(texto)
	ref.avisos_do_quadro[chave] = notas
