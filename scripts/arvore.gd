class_name Arvore
extends RefCounted
## A palmeira e a arvore de copa, em sprite (`assets/sprites/props/`, 2D51).
##
## Billboard so em torno do Y: a arvore fica de pe e vira para a camera, que e
## o que o Road Rash faz com o prop e o que a migracao 2D vai fazer com ele de
## qualquer jeito. Um `Sprite3D` por arvore, textura compartilhada.
##
## Era o `.glb` low-poly de `arte/arvores.py`: a copa debrucava 3 m sobre a
## pista. O sprite e simetrico e de frente, entao essa debruçada some ate o
## sprite de tres quartos.

enum Tipo { COPA, PALMEIRA }

const SPRITES: Array[String] = ["copa", "palmeira"]
const NOS: Array[String] = ["Copa", "Palmeira"]
const PASTA: String = "res://assets/sprites/props/"

## O colisor e so o pe do tronco, como o do poste: copa e folha ficam acima de
## qualquer cabeca, e bater em folha seria parede invisivel.
const COLISOR := Vector3(0.5, 3.0, 0.5)

static var _fichas: Array[Dictionary] = []
static var _texturas: Array[Texture2D] = []


## Uma arvore com o pe em `pe`. `olha` fica por compatibilidade com quem planta
## (a malha 3D virava a copa para a pista); o billboard vira sozinho.
static func criar(tipo: Tipo, pe: Vector3, _olha: Vector3) -> StaticBody3D:
	_carregar()
	var corpo := StaticBody3D.new()
	corpo.name = NOS[tipo]
	corpo.collision_layer = Layers.WORLD
	corpo.collision_mask = 0
	corpo.position = pe
	var ficha := _fichas[tipo]
	var sprite := Sprite3D.new()
	sprite.texture = _texturas[tipo]
	sprite.pixel_size = 1.0 / float(ficha["pixels_por_metro"])
	# Centrado, e o centro sobe meia altura: o pe cai na origem do corpo. Era
	# `offset` com o sprite solto, e o sinal do Y errou duas vezes (primeiro
	# enterrou a arvore e depois a pos no ar), sem erro nenhum. O x do pe fica
	# no meio do desenho: nos cinco sprites ele passa por menos de 2% da largura.
	var ancora: Array = ficha["pe"]
	sprite.position.y = (float(ancora[1]) - sprite.texture.get_height() * 0.5) * sprite.pixel_size
	# Espelha metade das arvores, para a avenida nao repetir a mesma silhueta. Sai
	# da posicao, e nao de um sorteio: um `randf` aqui deslocaria a sequencia do
	# gerador da cidade e mudaria o mundo inteiro por causa de um espelho.
	sprite.flip_h = (int(floorf(pe.x * 7.0)) + int(floorf(pe.z * 13.0))) % 2 == 0
	# `Sprite3D` nasce sem sombreamento: sem isto ele ignora o sol, a sombra dos
	# predios e os faroes, e fica um recorte chapado no meio da cena.
	sprite.shaded = true
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	corpo.add_child(sprite)
	var forma := Greybox.box_shape(COLISOR)
	forma.position = Vector3.UP * COLISOR.y * 0.5
	corpo.add_child(forma)
	return corpo


static func textura(tipo: Tipo) -> Texture2D:
	_carregar()
	return _texturas[tipo]


static func _carregar() -> void:
	if not _texturas.is_empty():
		return
	for nome in SPRITES:
		_texturas.append(load(PASTA + nome + ".png") as Texture2D)
		var texto := FileAccess.get_file_as_string(PASTA + nome + ".json")
		_fichas.append(JSON.parse_string(texto) as Dictionary)
