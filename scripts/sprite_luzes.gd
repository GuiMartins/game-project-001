class_name SpriteLuzes
extends RefCounted
## As luzes da ficha de uma folha (`arte/flow/fichas/`) no shader do sprite
## (`sprite.gdshader`): lanterna, freio, seta, farol, lente de poste, janela.
##
## Luz nao e desenho: uma camada de luz pedida ao Flow nunca cai no mesmo pixel
## da folha de base, entao a ficha diz onde ela fica na celula e o shader acende
## o brilho por cima. Cada luz da ficha e um dicionario:
##
## - `nome`, `linha`, `coluna`: quem e e em que quadro do atlas ela existe;
## - `ponto`: [x, y], em pixels da celula;
## - `raio`: o tamanho do brilho, em pixels (`RAIO_PADRAO`);
## - `cor`: [r, g, b] (`COR_PADRAO`);
## - `so_de_noite`: o farol e a lente de poste so acendem no escuro e o freio
##   acende de dia tambem (verdadeiro por padrao).
##
## O shader tem `MAX` luzes por vez: as da celula que esta na tela. Quem troca
## de quadro chama `aplica` de novo; quem acende ou apaga uma luz so troca a
## forca dela (`forcas`, por nome, de 0 a 1; as que faltam acendem inteiras).

## O mesmo `MAX_LUZES` do shader.
const MAX: int = 8
## Um amarelo quente: o do poste e do farol, que e o que mais se repete.
const COR_PADRAO := Color(1.0, 0.85, 0.5)
const RAIO_PADRAO: float = 6.0


## As luzes de `ficha` que existem na celula (`linha`, `coluna`), no formato das
## duas listas do shader: `pos` (x, y, raio, so_de_noite) e `cor` (rgb, forca),
## sempre com `MAX` itens, e quantas valem em `n`. Passando de `MAX`, as que
## sobram ficam apagadas, e o erro avisa: o shader nao tem onde pô-las.
static func da_celula(
	ficha: Dictionary, linha: int, coluna: int, forcas: Dictionary = {}
) -> Dictionary:
	var pos := PackedVector4Array()
	var cor := PackedVector4Array()
	for luz: Dictionary in ficha.get("luzes", []):
		if int(luz["linha"]) != linha or int(luz["coluna"]) != coluna:
			continue
		if pos.size() >= MAX:
			push_error("a celula %d,%d tem mais de %d luzes" % [linha, coluna, MAX])
			break
		var ponto: Array = luz["ponto"]
		var raio := float(luz.get("raio", RAIO_PADRAO))
		var so_de_noite := 1.0 if luz.get("so_de_noite", true) else 0.0
		pos.append(Vector4(float(ponto[0]), float(ponto[1]), maxf(raio, 0.001), so_de_noite))
		var rgb: Array = luz.get("cor", [])
		var tom := (
			Color(float(rgb[0]), float(rgb[1]), float(rgb[2])) if rgb.size() == 3 else COR_PADRAO
		)
		var forca := clampf(float(forcas.get(str(luz.get("nome", "")), 1.0)), 0.0, 1.0)
		cor.append(Vector4(tom.r, tom.g, tom.b, forca))
	var n := pos.size()
	pos.resize(MAX)
	cor.resize(MAX)
	return {"n": n, "pos": pos, "cor": cor}


## Poe no material as luzes da celula e o tamanho dela, que o shader precisa para
## achar o pixel onde esta.
static func aplica(
	material: ShaderMaterial, ficha: Dictionary, linha: int, coluna: int, forcas: Dictionary = {}
) -> void:
	var luzes := da_celula(ficha, linha, coluna, forcas)
	# A ficha do atlas diz `celula`; a de um prop de imagem so, `tamanho`.
	var celula: Array = ficha["celula"] if ficha.has("celula") else ficha["tamanho"]
	material.set_shader_parameter(&"celula_px", Vector2(float(celula[0]), float(celula[1])))
	material.set_shader_parameter(&"n_luzes", luzes["n"])
	material.set_shader_parameter(&"luz_pos", luzes["pos"])
	material.set_shader_parameter(&"luz_cor", luzes["cor"])
