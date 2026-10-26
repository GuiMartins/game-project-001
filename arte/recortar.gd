extends SceneTree
## Recorta uma folha do Google Flow pela ficha dela: o atlas em `<saida>.png` e a
## ficha do atlas em `<saida>.json`.
##
##     python3 tools/dev.py recortar                  # todas as fichas
##     python3 tools/dev.py recortar carro_hatch_base # uma, pelo nome
##
## Folha nova entra com uma ficha em `arte/flow/fichas/<nome>.json`, e nao com
## um script: grade, celula, ancora, pixels por metro, espelho, cor-chave e as
## coordenadas das luzes. O que o recorte faz e tudo de `recorte_de_folha.gd`,
## que os recortes do piloto (`sprites_flow.gd`) e dos pedestres
## (`sprites_pedestres.gd`) tambem usam; eles so acrescentam a regra propria
## (o angulo do piloto, a ordem da passada).
##
## Roda no Godot, e nao em Python, porque o Python do sistema nao le JPEG sem
## Pillow. Sai com 1 se alguma folha reprovar, depois de tentar todas: o Flow
## erra varias numa leva, e saber todas de uma vez e refazer todas de uma vez.

const Recorte := preload("res://arte/recorte_de_folha.gd")

const FICHAS: String = "res://arte/flow/fichas/"
## Onde saem as folhas de conferencia (atlas sobre cinza, com a linha do chao),
## fora do git.
const CONFERENCIA: String = "res://.dev/recortar/"


func _initialize() -> void:
	var nomes := _nomes(OS.get_cmdline_user_args())
	if nomes.is_empty():
		print("recortar: nenhuma ficha em %s" % FICHAS)
	var reprovadas: Array[String] = []
	for nome in nomes:
		if not _recorta(nome):
			reprovadas.append(nome)
	if not reprovadas.is_empty():
		push_error("refaca no Flow: %s" % ", ".join(reprovadas))
		quit(1)
		return
	quit(0)


## Os nomes pedidos, ou todas as fichas da pasta.
func _nomes(pedidos: PackedStringArray) -> PackedStringArray:
	if not pedidos.is_empty():
		return pedidos
	var nomes := PackedStringArray()
	for arquivo in DirAccess.get_files_at(FICHAS):
		if arquivo.ends_with(".json"):
			nomes.append(arquivo.get_basename())
	nomes.sort()
	return nomes


func _recorta(nome: String) -> bool:
	var texto := FileAccess.get_file_as_string(FICHAS + nome + ".json")
	var ficha: Variant = JSON.parse_string(texto)
	if not ficha is Dictionary:
		push_error("%s: nao li a ficha em %s" % [nome, FICHAS])
		return false
	var imagem := Recorte.carrega(str(ficha.get("fonte", "")))
	if imagem == null:
		return false
	var feito := Recorte.atlas_da_ficha(ficha, imagem)
	if feito.has("erro"):
		push_error("%s: %s" % [nome, feito["erro"]])
		return false
	var saida := str(ficha["saida"])
	var atlas: Image = feito["atlas"]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(saida.get_base_dir()))
	var erro := atlas.save_png(saida + ".png")
	if erro != OK:
		push_error("%s: nao gravei o atlas: %s" % [nome, error_string(erro)])
		return false
	_espelha_quadros(atlas, ficha)
	if ficha.has("espelha_quadros"):
		# O PNG saiu antes da virada: sem regravar, so a ficha com `placa` (que
		# regrava abaixo) levava o espelho para o disco.
		atlas.save_png(saida + ".png")
	var info := Recorte.ficha_do_atlas(ficha)
	if ficha.get("placa", false):
		info["placa"] = _placas(atlas, ficha)
		# A chapa do Flow foi apagada do atlas: regrava com ela lisa.
		atlas.save_png(saida + ".png")
	var arquivo := FileAccess.open(saida + ".json", FileAccess.WRITE)
	arquivo.store_string(JSON.stringify(info, "\t") + "\n")
	_confere(nome, atlas, ficha)
	print("+ %s.png: %s" % [saida, feito["escalas"]])
	return true


## Vira na horizontal, em volta do meio da celula, os quadros que o Flow
## desenhou de frente para o lado errado: a moto de toda folha aponta para a
## direita (a esquerda sai por espelho), e o Flow as vezes erra uma linha ou um
## quadro so. A ficha diz quais, em `espelha_quadros`: pares `[linha, coluna]`.
func _espelha_quadros(atlas: Image, ficha: Dictionary) -> void:
	var celula := Vector2i(int(ficha["celula"][0]), int(ficha["celula"][1]))
	for par: Array in ficha.get("espelha_quadros", []):
		var origem := Vector2i(int(par[1]), int(par[0])) * celula
		var quadro := atlas.get_region(Rect2i(origem, celula))
		quadro.flip_x()
		atlas.blit_rect(quadro, Rect2i(Vector2i.ZERO, celula), origem)


## Onde esta a placa em cada quadro de costas e de tres quartos de costas, em
## pixels da celula, e a apaga do atlas (`PlacaSprite`): o jogo escreve a placa
## da moto por cima. Quadro sem placa achada fica de fora da lista, e aparece no
## log, para o dono da folha ver (a empinada de costas, por exemplo, esconde a
## chapa atras da bag).
func _placas(atlas: Image, ficha: Dictionary) -> Array:
	var celula := Vector2i(int(ficha["celula"][0]), int(ficha["celula"][1]))
	var achadas: Array = []
	var linhas: Array = ficha["linhas"]
	for linha in linhas.size():
		var nome := str(linhas[linha])
		if nome != "costas" and nome != "tres_quartos_costas":
			continue
		for coluna in int(ficha["colunas"]):
			var origem := Vector2i(coluna, linha) * celula
			var quadro := atlas.get_region(Rect2i(origem, celula))
			var caixa := quadro.get_used_rect()
			var cantos := PlacaSprite.acha(quadro, caixa, nome != "costas")
			if cantos.size() != 4:
				print("  . sem placa: quadro %d da linha %s" % [coluna, nome])
				continue
			PlacaSprite.apaga(quadro, cantos)
			atlas.blit_rect(quadro, Rect2i(Vector2i.ZERO, celula), origem)
			var pontos: Array = []
			for c in cantos:
				pontos.append([c.x, c.y])
			achadas.append({"coluna": coluna, "linha": linha, "cantos": pontos})
	return achadas


## O atlas sobre cinza, com a linha do chao de cada linha, para ver a olho se os
## pes ficam no mesmo lugar.
func _confere(nome: String, atlas: Image, ficha: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CONFERENCIA))
	var celula := Vector2i(int(ficha["celula"][0]), int(ficha["celula"][1]))
	var fundo := Image.create_empty(
		atlas.get_width(), atlas.get_height(), false, Image.FORMAT_RGBA8
	)
	fundo.fill(Color(0.5, 0.5, 0.5))
	for linha in (ficha["linhas"] as Array).size():
		for x in atlas.get_width():
			fundo.set_pixel(x, linha * celula.y + int(ficha["pe_y"]), Color(1, 0, 1))
	fundo.blend_rect(atlas, Rect2i(Vector2i.ZERO, atlas.get_size()), Vector2i.ZERO)
	fundo.save_png(CONFERENCIA + nome + ".png")
