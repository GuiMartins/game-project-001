class_name Sangue
extends RefCounted
## A mancha de sangue no chao, de quem foi atropelado: um `Decal` com uma
## textura gerada aqui, uma vez.
##
## As manchas moram no no do grupo `GRUPO`, que o `World` cria e limpa a cada
## largada; sem ele (num teste solto), ninguem mancha nada. E so as ultimas
## `MAX` ficam: quem atravessa a calcada inteira a 180 km/h deixa um rastro, e
## o rastro nao pode crescer sem fim.

const GRUPO: StringName = &"sangue"
const MAX: int = 80
## Lado da textura, em pixels. A 640x360 uma mancha de 1 m a 10 m tem uns 15
## px: mais que 32 seria detalhe que nao chega na tela.
const LADO: int = 32
## Vermelho escuro, quase marrom: sangue no asfalto ao sol nao e o vermelho da
## bag, e nao pode competir com ela.
const COR := Color(0.38, 0.02, 0.03, 0.92)

static var _textura: Texture2D


## Uma mancha em `onde` (no mundo), de `tamanho` metros (largura, comprimento)
## e com o comprimento apontado para `rumo` (radianos em volta de Y).
static func manchar(arvore: SceneTree, onde: Vector3, tamanho: Vector2, rumo: float) -> void:
	if arvore == null:
		return
	var pai := arvore.get_first_node_in_group(GRUPO) as Node3D
	if pai == null:
		return
	var mancha := Decal.new()
	mancha.texture_albedo = textura()
	# Meio metro de altura: pega o chao numa ladeira de 14% sob uma mancha de
	# 2 m, e quase nada de quem passa por cima.
	mancha.size = Vector3(tamanho.x, 0.5, tamanho.y)
	mancha.upper_fade = 0.2
	mancha.lower_fade = 0.2
	pai.add_child(mancha)
	mancha.global_position = onde
	mancha.global_rotation = Vector3(0.0, rumo, 0.0)
	while pai.get_child_count() > MAX:
		pai.get_child(0).free()


## Um borrao central de borda irregular e uns pingos em volta. Sorteio fixo:
## toda mancha e a mesma, girada e esticada pelo `Decal`.
static func textura() -> Texture2D:
	if _textura != null:
		return _textura
	var img := Image.create(LADO, LADO, false, Image.FORMAT_RGBA8)
	img.fill(Color(COR, 0.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var bolhas: Array[Vector3] = [Vector3(0.5, 0.5, 0.3)]
	for i in 5:
		bolhas.append(Vector3(rng.randf_range(0.3, 0.7), rng.randf_range(0.3, 0.7), 0.14))
	for i in 7:
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.32, 0.46)
		bolhas.append(Vector3(0.5 + cos(a) * r, 0.5 + sin(a) * r, rng.randf_range(0.03, 0.06)))
	for y in LADO:
		for x in LADO:
			var p := Vector2((float(x) + 0.5) / LADO, (float(y) + 0.5) / LADO)
			for b in bolhas:
				# A borda ondula com o angulo: circulo perfeito le como tinta.
				var d := p - Vector2(b.x, b.y)
				var onda := 1.0 + 0.18 * sin(atan2(d.y, d.x) * 5.0 + b.x * 20.0)
				if d.length() < b.z * onda:
					img.set_pixel(x, y, COR)
					break
	_textura = ImageTexture.create_from_image(img)
	return _textura
