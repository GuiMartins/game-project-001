class_name BaseSprites
extends RefCounted
## A "base" de uma folha: uma copia guardada para comparar com a de agora.
##
## Cada rodada do Flow troca a folha inteira, e o que importa e saber o que
## mudou: se o quadro novo e melhor ou so diferente. Fixa-se a folha atual como
## base antes de trocar o arquivo, e depois o testador mostra a base, a nova e a
## diferenca lado a lado.
##
## Mora em `user://sprites_base/`, e nao no repositorio: e uma bancada de
## trabalho de quem esta refazendo a arte, nao conteudo do projeto. O historico
## do git ja guarda as versoes que entraram; a base guarda a que ainda nao.

const PASTA: String = "user://sprites_base"
## Diferenca de canal (0-255) a partir da qual dois pixels sao diferentes: o
## PNG nao perde nada, mas a folha pode ter sido repintada em tom parecido.
const LIMIAR: int = 12


static func caminho(item: CatalogoSprites.Item) -> String:
	return "%s/%s.png" % [PASTA, item.id]


static func existe(item: CatalogoSprites.Item) -> bool:
	return FileAccess.file_exists(caminho(item))


## Guarda a folha de agora como base. Devolve o erro do Godot.
static func fixar(item: CatalogoSprites.Item) -> int:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PASTA))
	var atual := CatalogoSprites.imagem_de(item.caminho)
	if atual == null or atual.is_empty():
		return ERR_FILE_CANT_READ
	return atual.save_png(caminho(item))


static func limpar(item: CatalogoSprites.Item) -> void:
	if existe(item):
		DirAccess.remove_absolute(caminho(item))


## A base, ou null se nao ha.
static func carregar(item: CatalogoSprites.Item) -> Image:
	if not existe(item):
		return null
	var base := Image.load_from_file(ProjectSettings.globalize_path(caminho(item)))
	return null if base == null or base.is_empty() else base


## Quando a base foi fixada, em texto.
static func data(item: CatalogoSprites.Item) -> String:
	if not existe(item):
		return ""
	var quando := FileAccess.get_modified_time(caminho(item))
	return Time.get_datetime_string_from_unix_time(quando, true)


## Quais quadros diferem da base, na ordem `linha * colunas + coluna`. Se a base
## tem outro tamanho, todos diferem: a grade mudou.
static func quadros_diferentes(item: CatalogoSprites.Item, base: Image) -> PackedInt32Array:
	var diferentes := PackedInt32Array()
	var atual := CatalogoSprites.imagem_de(item.caminho)
	if atual == null or base == null or atual.get_size() != base.get_size():
		for i in item.quadros():
			diferentes.append(i)
		return diferentes
	for l in item.linhas:
		for c in item.colunas:
			var regiao := Rect2i(Vector2i(c * item.celula.x, l * item.celula.y), item.celula)
			# A comparacao de bytes e nativa: so quem difere paga a conta pixel a
			# pixel.
			if atual.get_region(regiao).get_data() != base.get_region(regiao).get_data():
				diferentes.append(l * item.colunas + c)
	return diferentes


## A diferenca de dois quadros: o atual esmaecido, e em magenta o que mudou.
## `base` e `atual` sao imagens so da celula.
static func diferenca(base: Image, atual: Image) -> Image:
	var saida := Image.create_empty(
		atual.get_width(), atual.get_height(), false, Image.FORMAT_RGBA8
	)
	for y in atual.get_height():
		for x in atual.get_width():
			var a := atual.get_pixel(x, y)
			var b := base.get_pixel(x, y)
			var mudou := (
				absi(roundi((a.r - b.r) * 255.0)) > LIMIAR
				or absi(roundi((a.g - b.g) * 255.0)) > LIMIAR
				or absi(roundi((a.b - b.b) * 255.0)) > LIMIAR
				or absi(roundi((a.a - b.a) * 255.0)) > LIMIAR
			)
			if mudou:
				saida.set_pixel(x, y, Color(1.0, 0.1, 0.8, 1.0))
			elif a.a > 0.5:
				saida.set_pixel(x, y, Color(a.r, a.g, a.b, 0.35))
	return saida
