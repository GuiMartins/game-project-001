class_name CatalogoSprites
extends RefCounted
## Tudo o que o jogo tem em sprite, achado na pasta e conferido contra a ficha
## de cada folha. Alimenta o testador (`TestadorSprites`).
##
## A lista nasce da varredura de `assets/sprites/`, e nao de uma tabela escrita
## a mao: folha nova aparece sozinha, e folha que perdeu o `.json` aparece com
## aviso em vez de sumir.

enum Tipo { MOTO, PEDESTRE }

const PASTA: String = "res://assets/sprites"
const PASTA_PEDESTRES: String = "res://assets/sprites/pedestres"

## Quantos pixels o pe desenhado pode estar longe do ponto do pe da ficha, e o
## quanto o pe e a altura podem variar de quadro em quadro numa folha que anda,
## antes de virar aviso. Acima disso o sprite escorrega no chao ou cresce e
## encolhe a cada passo. Valores medidos nas folhas atuais; ver o aviso real
## antes de apertar.
const TOLERANCIA_PE_PX: int = 4
const TOLERANCIA_VARIACAO_PE_PX: int = 3
const TOLERANCIA_VARIACAO_ALTURA: float = 0.08
## Notas de borda: sao do recorte, e nao da pose, e nao entram na conta de
## "mesmo quadro marcado em varias pessoas".
const NOTAS_DE_BORDA: Array[String] = ["meio transparente", "franja verde", "pixels soltos"]
## A partir de quantas pessoas marcadas no mesmo quadro o problema deixa de ser
## da pessoa e passa a ser suspeita da referencia que as cinco compartilham.
const PESSOAS_PARA_SUSPEITAR: int = 3


## Uma folha: o que a ficha diz dela e o que se mediu na imagem.
class Item:
	extends RefCounted

	var id: String = ""
	var tipo: int = Tipo.PEDESTRE
	## "Moto", "Vovo", "Obra"... e a animacao ("andando", "curva").
	var grupo: String = ""
	var animacao: String = ""
	var caminho: String = ""
	var colunas: int = 1
	var linhas: int = 1
	var celula := Vector2i.ZERO
	var pe := Vector2i.ZERO
	var pixels_por_metro: float = 100.0
	var altura_m: float = 0.0
	## Altura de referencia em pixels do que a folha desenha de pe, para a
	## regua: altura_m * pixels_por_metro nos pedestres, `ALTURA_PX` na moto.
	var altura_px: float = 0.0
	var rotulos_linhas: PackedStringArray = []
	var espelha_lado_esquerdo: bool = false
	## Um por quadro, na ordem `linha * colunas + coluna`: o retangulo de pixel
	## opaco dentro da celula (vazio se o quadro esta em branco).
	var caixas: Array[Rect2i] = []
	var avisos: PackedStringArray = []
	var tamanho_imagem := Vector2i.ZERO
	## O que `AnaliseSprites` acha: o que se mede olhando o movimento, a borda
	## e a referencia. Fica de fora de `avisos` de proposito: aquilo e instantaneo
	## e este custa um segundo por folha, entao so aparece depois da analise.
	var analisado: bool = false
	var avisos_analise: PackedStringArray = []
	## Aviso -> quadros que o disparam, antes de virarem uma linha so por tipo.
	var grupos_analise: Dictionary = {}
	## Notas de um quadro so, na ordem `linha * colunas + coluna`, para a folha
	## marcar qual quadro e o problema.
	var notas_quadro: Dictionary = {}
	## A semelhanca de cada quadro com o da referencia (IoU de 0 a 1), ou vazio
	## se a folha nao tem referencia.
	var iou_referencia: PackedFloat32Array = []
	var referencia: ReferenciaSprites
	var silhuetas: Array[Silhueta] = []
	## `AnaliseSprites` roda numa thread de fundo e o testador pode pedir a mesma
	## folha ao mesmo tempo: quem chega depois espera, e nao analisa duas vezes.
	var trava := Mutex.new()

	func nome() -> String:
		return "%s  %s" % [grupo, animacao]

	func quadros() -> int:
		return colunas * linhas

	## Todo aviso da folha: o que se ve de cara e o que a analise achou.
	func todos_os_avisos() -> PackedStringArray:
		return avisos + avisos_analise

	func tem_aviso() -> bool:
		return not avisos.is_empty() or not avisos_analise.is_empty()

	func nota_do_quadro(coluna: int, linha: int) -> PackedStringArray:
		return notas_quadro.get(linha * colunas + coluna, PackedStringArray())

	func anota(coluna: int, linha: int, texto: String) -> void:
		var chave := linha * colunas + coluna
		var notas: PackedStringArray = notas_quadro.get(chave, PackedStringArray())
		notas.append(texto)
		notas_quadro[chave] = notas

	func caixa(coluna: int, linha: int) -> Rect2i:
		var i := linha * colunas + coluna
		return caixas[i] if i >= 0 and i < caixas.size() else Rect2i()

	## Textura para desenhar, ou null se o arquivo nao abre.
	func textura() -> Texture2D:
		return load(caminho) as Texture2D


## Os pixels de uma folha. Do disco quando o arquivo existe (o editor do Godot e o
## `dev.py`): o importado pode vir comprimido na GPU e nao devolver pixel. Num
## build exportado o PNG nao vai no pacote, so o importado, e as folhas sao
## importadas sem compressao (`compress/mode=0`), entao `get_image` serve.
static func imagem_de(caminho: String) -> Image:
	var disco := ProjectSettings.globalize_path(caminho)
	if FileAccess.file_exists(disco):
		return Image.load_from_file(disco)
	var textura := load(caminho) as Texture2D
	return textura.get_image() if textura != null else null


## Os arquivos de uma pasta do projeto, pelos nomes de origem. Num build exportado
## `DirAccess` lista `x.png.import` e `x.png.remap`, e nao `x.png`; o
## `ResourceLoader` devolve o nome que o projeto conhece.
static func _arquivos(pasta: String) -> PackedStringArray:
	var nomes: PackedStringArray = []
	for nome in ResourceLoader.list_directory(pasta):
		if not nome.ends_with("/") and not nomes.has(nome):
			nomes.append(nome)
	return nomes


## Todas as folhas, a moto primeiro e depois os pedestres por nome.
static func varrer() -> Array[Item]:
	var itens: Array[Item] = []
	itens.append(_moto())
	var arquivos := _arquivos(PASTA_PEDESTRES)
	var nomes: PackedStringArray = []
	for arquivo in arquivos:
		if arquivo.ends_with(".png"):
			nomes.append(arquivo.get_basename())
	nomes.sort()
	for nome in nomes:
		itens.append(_pedestre(nome))
	# Ficha sem folha: o contrario do aviso de cima.
	for arquivo in arquivos:
		if arquivo.ends_with(".json") and not nomes.has(arquivo.get_basename()):
			var orfao := Item.new()
			orfao.id = arquivo.get_basename()
			orfao.grupo = orfao.id
			orfao.animacao = "?"
			orfao.caminho = "%s/%s" % [PASTA_PEDESTRES, arquivo]
			orfao.avisos.append("ficha sem imagem: falta %s.png" % orfao.id)
			itens.append(orfao)
	return itens


static func _moto() -> Item:
	var item := Item.new()
	item.id = "moto"
	item.tipo = Tipo.MOTO
	item.grupo = "Moto"
	item.animacao = "curva e soco"
	item.caminho = AtorSprite.ATLAS.resource_path
	item.colunas = AtorSprite.QUADROS
	item.linhas = 1
	item.celula = Vector2i(AtorSprite.CELULA)
	item.pe = Vector2i(AtorSprite.PE)
	item.altura_px = AtorSprite.ALTURA_PX
	item.rotulos_linhas = PackedStringArray(["unica"])
	_medir(item, true, false)
	return item


static func _pedestre(nome: String) -> Item:
	var item := Item.new()
	item.id = nome
	item.tipo = Tipo.PEDESTRE
	var partes := nome.split("_", false, 1)
	item.grupo = String(partes[0]).capitalize()
	item.animacao = partes[1] if partes.size() > 1 else "?"
	item.caminho = "%s/%s.png" % [PASTA_PEDESTRES, nome]
	var ficha := _ler_ficha("%s/%s.json" % [PASTA_PEDESTRES, nome])
	if ficha.is_empty():
		item.avisos.append("sem ficha (%s.json): nao ha como saber a celula" % nome)
		return item
	var celula: Array = ficha.get("celula", [0, 0])
	var pe: Array = ficha.get("pe", [0, 0])
	item.celula = Vector2i(int(celula[0]), int(celula[1]))
	item.pe = Vector2i(int(pe[0]), int(pe[1]))
	item.colunas = int(ficha.get("colunas", 1))
	var rotulos: Array = ficha.get("linhas", [])
	item.linhas = maxi(rotulos.size(), 1)
	for rotulo: Variant in rotulos:
		item.rotulos_linhas.append(String(rotulo))
	item.pixels_por_metro = float(ficha.get("pixels_por_metro", 100.0))
	item.altura_m = float(ficha.get("altura_m", 0.0))
	item.altura_px = item.altura_m * item.pixels_por_metro
	item.espelha_lado_esquerdo = bool(ficha.get("espelha_o_lado_esquerdo", false))
	_medir(item, item.animacao == "andando", true)
	return item


static func _ler_ficha(caminho: String) -> Dictionary:
	if not FileAccess.file_exists(caminho):
		return {}
	var dados: Variant = JSON.parse_string(FileAccess.get_file_as_string(caminho))
	return dados if dados is Dictionary else {}


## Mede a imagem quadro a quadro e preenche os avisos. `anda` liga a conferencia
## de pe e altura constantes: numa folha de queda ou de voo o corpo sai do chao
## de proposito, e o aviso seria ruido. `confere_altura` fica desligado na moto:
## deitada a 28 graus ela desenha 104 px de altura contra 120 em pe, que e a
## geometria, e nao defeito.
static func _medir(item: Item, anda: bool, confere_altura: bool) -> void:
	var imagem := imagem_de(item.caminho)
	if imagem == null or imagem.is_empty():
		item.avisos.append("a imagem nao abre: %s" % item.caminho)
		return
	item.tamanho_imagem = imagem.get_size()
	var esperado := Vector2i(item.colunas * item.celula.x, item.linhas * item.celula.y)
	if item.tamanho_imagem != esperado:
		item.avisos.append(
			(
				"imagem %dx%d, mas a ficha pede %dx%d (%d colunas x %d linhas de %dx%d)"
				% [
					item.tamanho_imagem.x,
					item.tamanho_imagem.y,
					esperado.x,
					esperado.y,
					item.colunas,
					item.linhas,
					item.celula.x,
					item.celula.y
				]
			)
		)
		return
	if item.pe.x < 0 or item.pe.y < 0 or item.pe.x >= item.celula.x or item.pe.y >= item.celula.y:
		item.avisos.append("o pe %s cai fora da celula %s" % [item.pe, item.celula])
	var vazios := 0
	var colados := 0
	for linha in item.linhas:
		for coluna in item.colunas:
			var origem := Vector2i(coluna * item.celula.x, linha * item.celula.y)
			var uso := imagem.get_region(Rect2i(origem, item.celula)).get_used_rect()
			item.caixas.append(uso)
			if uso.size == Vector2i.ZERO:
				vazios += 1
			elif (
				uso.position.x == 0
				or uso.position.y == 0
				or uso.end.x >= item.celula.x
				or uso.end.y >= item.celula.y
			):
				colados += 1
	if vazios > 0:
		item.avisos.append("%d quadro(s) em branco" % vazios)
	if colados > 0:
		item.avisos.append("%d quadro(s) encostam na borda da celula (cortados?)" % colados)
	if anda:
		_confere_constancia(item, confere_altura)


static func _confere_constancia(item: Item, confere_altura: bool) -> void:
	for linha in item.linhas:
		var pes: Array[int] = []
		var alturas: Array[int] = []
		for coluna in item.colunas:
			var uso := item.caixa(coluna, linha)
			if uso.size == Vector2i.ZERO:
				continue
			pes.append(uso.end.y)
			alturas.append(uso.size.y)
		if pes.is_empty():
			continue
		var rotulo := _rotulo(item, linha)
		var pe_min: int = pes.min()
		var pe_max: int = pes.max()
		if pe_max - pe_min > TOLERANCIA_VARIACAO_PE_PX:
			item.avisos.append(
				(
					"%s: o pe varia %d px entre quadros (%d a %d)"
					% [rotulo, pe_max - pe_min, pe_min, pe_max]
				)
			)
		var alt_min: int = alturas.min()
		var alt_max: int = alturas.max()
		if (
			confere_altura
			and float(alt_max - alt_min) / float(alt_max) > TOLERANCIA_VARIACAO_ALTURA
		):
			item.avisos.append(
				"%s: a altura varia de %d a %d px entre quadros" % [rotulo, alt_min, alt_max]
			)
		# O pe da ficha e onde o jogo apoia o sprite; o desenho tem de chegar la.
		if (
			absi(pe_max - item.pe.y) > TOLERANCIA_PE_PX
			and absi(pe_min - item.pe.y) > TOLERANCIA_PE_PX
		):
			item.avisos.append(
				(
					"%s: o desenho acaba em y=%d e a ficha apoia o pe em y=%d"
					% [rotulo, pe_max, item.pe.y]
				)
			)


static func _rotulo(item: Item, linha: int) -> String:
	if item.linhas == 1:
		return "folha"
	return item.rotulos_linhas[linha] if linha < item.rotulos_linhas.size() else "linha %d" % linha


## Os quadros marcados em varias pessoas da mesma animacao. As cinco folhas
## partem da mesma referencia: quando a mesma celula sai errada em tres delas, o
## defeito provavelmente nao e do Flow, e sim do boneco que lhe foi dado.
## Devolve "animacao quadro/linha: N de M pessoas" por suspeita.
static func recorrentes(itens: Array[Item]) -> PackedStringArray:
	var contagem: Dictionary = {}
	var total: Dictionary = {}
	for item in itens:
		if item.tipo != Tipo.PEDESTRE:
			continue
		total[item.animacao] = int(total.get(item.animacao, 0)) + 1
		for chave: int in item.notas_quadro:
			var de_pose := false
			for nota: String in item.notas_quadro[chave]:
				var de_borda := false
				for trecho in NOTAS_DE_BORDA:
					de_borda = de_borda or nota.contains(trecho)
				de_pose = de_pose or not de_borda
			if de_pose:
				var id := "%s|%d|%d" % [item.animacao, chave % item.colunas, chave / item.colunas]
				contagem[id] = int(contagem.get(id, 0)) + 1
	var achados := PackedStringArray()
	var ids: Array = contagem.keys()
	ids.sort()
	for id: String in ids:
		if contagem[id] < PESSOAS_PARA_SUSPEITAR:
			continue
		var partes := id.split("|")
		achados.append(
			(
				"%s, quadro %d/%d: marcado em %d de %d pessoas"
				% [
					partes[0],
					int(partes[1]) + 1,
					int(partes[2]) + 1,
					contagem[id],
					total[partes[0]]
				]
			)
		)
	return achados
