class_name Arvore
extends RefCounted
## A palmeira e a arvore de copa de `arte/arvores.py`, prontas para plantar.
##
## Mesma ideia do `Poste`: o `.glb` e aberto uma vez so e toda arvore da
## avenida divide a malha. O modelo olha para -Z, para onde a copa se debruca:
## quem planta aponta -Z para o eixo da avenida.

enum Tipo { COPA, PALMEIRA }

const CENA: PackedScene = preload("res://assets/arvores/arvores.glb")
const NOS: Array[String] = ["Copa", "Palmeira"]

## O colisor e so o pe do tronco, como o do poste: copa e folha ficam acima de
## qualquer cabeca, e bater em folha seria parede invisivel.
const COLISOR := Vector3(0.5, 3.0, 0.5)

static var _malhas: Array[Mesh] = []


## Uma arvore com o pe em `pe` e a copa debrucada para `olha`.
static func criar(tipo: Tipo, pe: Vector3, olha: Vector3) -> StaticBody3D:
	var corpo := StaticBody3D.new()
	corpo.name = NOS[tipo]
	corpo.collision_layer = Layers.WORLD
	corpo.collision_mask = 0
	corpo.position = pe
	var mi := MeshInstance3D.new()
	mi.mesh = malha(tipo)
	olha.y = 0.0
	mi.basis = Basis.looking_at(olha.normalized(), Vector3.UP)
	corpo.add_child(mi)
	var forma := Greybox.box_shape(COLISOR)
	forma.position = Vector3.UP * COLISOR.y * 0.5
	corpo.add_child(forma)
	return corpo


static func malha(tipo: Tipo) -> Mesh:
	if _malhas.is_empty():
		var cena := CENA.instantiate()
		for nome in NOS:
			var no := cena.find_child(nome, true, false) as MeshInstance3D
			assert(no != null, "arvores.glb sem o no %s" % nome)
			_malhas.append(no.mesh)
		cena.free()
	return _malhas[tipo]
