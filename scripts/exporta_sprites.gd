class_name ExportaSprites
extends RefCounted
## Imagens para levar do testador: um quadro ampliado, a folha com os quadros
## problematicos marcados e a comparacao com a referencia, de pe e inteira.
##
## A comparacao e para devolver ao Flow ou mostrar a quem desenha: o boneco, a
## pessoa e a sobreposicao, linha por linha, na mesma grade. No projeto fica em
## `.dev/sprites_export/`, fora do git; no editor exportado, em `Documentos/RushFood
## Sprites`, porque o pacote nao e gravavel.

const PASTA: String = "res://.dev/sprites_export"
const PASTA_DO_EDITOR_EXPORTADO: String = "RushFood Sprites"
const COR_AVISO := Color(1.0, 0.25, 0.2)
const COR_SO_REFERENCIA := Color(1.0, 0.3, 0.3)
const COR_SO_FOLHA := Color(0.3, 0.8, 1.0)
const COR_AS_DUAS := Color(0.95, 0.95, 0.95)
const FUNDO := Color(0.36, 0.37, 0.39)
const VERDE := Color(0.0, 1.0, 0.0)
## Quanto cada celula da grade de silhueta cresce na sobreposicao.
const AUMENTO_DA_SILHUETA: int = 3


static func pasta_absoluta() -> String:
	var caminho := ProjectSettings.globalize_path(PASTA)
	if not OS.has_feature("editor"):
		caminho = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS).path_join(PASTA_DO_EDITOR_EXPORTADO)
	DirAccess.make_dir_recursive_absolute(caminho)
	return caminho


static func _imagem(item: CatalogoSprites.Item) -> Image:
	return CatalogoSprites.imagem_de(item.caminho)


## Um quadro, ampliado em pixel inteiro, sobre cinza.
static func quadro(item: CatalogoSprites.Item, coluna: int, linha: int, aumento: int) -> Image:
	var folha := _imagem(item)
	if folha == null:
		return null
	var celula := folha.get_region(Rect2i(Vector2i(coluna, linha) * item.celula, item.celula))
	var saida := Image.create_empty(item.celula.x, item.celula.y, false, Image.FORMAT_RGBA8)
	saida.fill(FUNDO)
	saida.blend_rect(celula, Rect2i(Vector2i.ZERO, item.celula), Vector2i.ZERO)
	saida.resize(item.celula.x * aumento, item.celula.y * aumento, Image.INTERPOLATE_NEAREST)
	return saida


## A folha sobre cinza, com um retangulo vermelho nos quadros que a analise
## marcou.
static func folha_marcada(item: CatalogoSprites.Item) -> Image:
	var folha := _imagem(item)
	if folha == null:
		return null
	var saida := Image.create_empty(
		folha.get_width(), folha.get_height(), false, Image.FORMAT_RGBA8
	)
	saida.fill(FUNDO)
	saida.blend_rect(folha, Rect2i(Vector2i.ZERO, folha.get_size()), Vector2i.ZERO)
	for chave: int in item.notas_quadro:
		var origem := Vector2i(chave % item.colunas, chave / item.colunas) * item.celula
		_moldura(saida, Rect2i(origem, item.celula), COR_AVISO, 3)
	return saida


## Referencia, folha e sobreposicao empilhadas, uma linha de angulos por vez.
## Devolve null se a folha nao tem referencia.
static func comparacao(item: CatalogoSprites.Item) -> Image:
	AnaliseSprites.analisar(item)
	var ref := item.referencia
	if ref == null or ref.colunas != item.colunas or ref.linhas != item.linhas:
		return null
	var folha := _imagem(item)
	if folha == null:
		return null
	var celula := Vector2i(maxi(item.celula.x, ref.celula.x), maxi(item.celula.y, ref.celula.y))
	var silhueta := Vector2i(Silhueta.LARGURA, Silhueta.ALTURA) * AUMENTO_DA_SILHUETA
	celula = Vector2i(maxi(celula.x, silhueta.x), maxi(celula.y, silhueta.y))
	var saida := Image.create_empty(
		item.colunas * celula.x, item.linhas * 3 * celula.y, false, Image.FORMAT_RGBA8
	)
	saida.fill(FUNDO)
	for l in item.linhas:
		for c in item.colunas:
			var topo := Vector2i(c * celula.x, l * 3 * celula.y)
			# 1. a referencia, sobre o verde em que foi enviada.
			var da_ref := Image.create_empty(ref.celula.x, ref.celula.y, false, Image.FORMAT_RGBA8)
			da_ref.fill(VERDE)
			da_ref.blend_rect(
				ref.celula_imagem(c, l), Rect2i(Vector2i.ZERO, ref.celula), Vector2i.ZERO
			)
			saida.blit_rect(da_ref, Rect2i(Vector2i.ZERO, ref.celula), topo)
			# 2. o quadro entregue.
			var meio := topo + Vector2i(0, celula.y)
			var da_folha := folha.get_region(Rect2i(Vector2i(c, l) * item.celula, item.celula))
			saida.blend_rect(da_folha, Rect2i(Vector2i.ZERO, item.celula), meio)
			# 3. as duas silhuetas.
			var baixo := topo + Vector2i(0, 2 * celula.y)
			_sobrepoe(saida, baixo, item.silhuetas[l * item.colunas + c], ref.silhueta(c, l))
			if item.notas_quadro.has(l * item.colunas + c):
				_moldura(saida, Rect2i(topo, Vector2i(celula.x, 3 * celula.y)), COR_AVISO, 4)
	return saida


static func _sobrepoe(destino: Image, origem: Vector2i, a: Silhueta, b: Silhueta) -> void:
	if a.vazia() or b.vazia():
		return
	for y in Silhueta.ALTURA:
		for x in Silhueta.LARGURA:
			var da_folha := a.grade[y * Silhueta.LARGURA + x] == 1
			var da_ref := b.grade[y * Silhueta.LARGURA + x] == 1
			var cor := FUNDO
			if da_folha and da_ref:
				cor = COR_AS_DUAS
			elif da_ref:
				cor = COR_SO_REFERENCIA
			elif da_folha:
				cor = COR_SO_FOLHA
			else:
				continue
			destino.fill_rect(
				Rect2i(
					origem + Vector2i(x, y) * AUMENTO_DA_SILHUETA,
					Vector2i(AUMENTO_DA_SILHUETA, AUMENTO_DA_SILHUETA)
				),
				cor
			)


static func _moldura(imagem: Image, area: Rect2i, cor: Color, espessura: int) -> void:
	imagem.fill_rect(Rect2i(area.position, Vector2i(area.size.x, espessura)), cor)
	imagem.fill_rect(Rect2i(area.position.x, area.end.y - espessura, area.size.x, espessura), cor)
	imagem.fill_rect(Rect2i(area.position, Vector2i(espessura, area.size.y)), cor)
	imagem.fill_rect(Rect2i(area.end.x - espessura, area.position.y, espessura, area.size.y), cor)
