class_name Mobiliario
extends RefCounted
## A cacamba, o mupi, a placa de curva (V17) e a de mao dupla de
## `arte/mobiliario.py`.
##
## Mesma ideia do `Poste` e da `Arvore`: o `.glb` e aberto uma vez e cada peca
## divide a malha. O modelo olha para -Z: a cacamba de comprido ao longo da
## pista, e o mupi e a placa encarando quem vem.

enum Tipo { CACAMBA, MUPI, PLACA_ESQUERDA, PLACA_DIREITA, PLACA_MAO_DUPLA }

const CENA: PackedScene = preload("res://assets/mobiliario/mobiliario.glb")
const NOS: Array[String] = ["Cacamba", "Mupi", "PlacaEsquerda", "PlacaDireita", "PlacaMaoDupla"]
## O colisor de cada uma, no espaco do modelo. A cacamba e o mupi sao caixa
## inteira, que a moto que sobe na calcada encontra; da placa, so o poste.
const COLISORES: Array[Vector3] = [
	Vector3(2.4, 1.0, 1.4),
	Vector3(1.4, 2.3, 0.3),
	Vector3(0.15, 2.6, 0.15),
	Vector3(0.15, 2.6, 0.15),
	Vector3(0.15, 2.6, 0.15),
]

static var _malhas: Array[Mesh] = []


## Uma peca com o pe em `pe` e a frente (-Z) apontando para `olha`.
static func criar(tipo: Tipo, pe: Vector3, olha: Vector3) -> StaticBody3D:
	var corpo := StaticBody3D.new()
	corpo.name = NOS[tipo]
	corpo.collision_layer = Layers.WORLD
	corpo.collision_mask = 0
	corpo.position = pe
	olha.y = 0.0
	corpo.basis = Basis.looking_at(olha.normalized(), Vector3.UP)
	var mi := MeshInstance3D.new()
	mi.mesh = malha(tipo)
	corpo.add_child(mi)
	var forma := Greybox.box_shape(COLISORES[tipo])
	forma.position = Vector3.UP * COLISORES[tipo].y * 0.5
	corpo.add_child(forma)
	return corpo


static func malha(tipo: Tipo) -> Mesh:
	if _malhas.is_empty():
		var cena := CENA.instantiate()
		for nome in NOS:
			var no := cena.find_child(nome, true, false) as MeshInstance3D
			assert(no != null, "mobiliario.glb sem o no %s" % nome)
			_malhas.append(no.mesh)
		cena.free()
	return _malhas[tipo]
