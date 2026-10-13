class_name Poste
extends RefCounted
## O poste de dois bracos de `arte/poste.py`, pronto para plantar na calcada.
##
## Mesma ideia do `Predio`: o `.glb` e aberto uma vez so e todo poste da
## avenida divide a malha. Sao uns cento e cinquenta por corrida.
##
## O modelo olha para -Z, onde fica o braco da pista: quem planta aponta -Z
## para o eixo da avenida.

const CENA: PackedScene = preload("res://assets/poste/poste.glb")

## O colisor e o da caixa do greybox, e nao o desenho do poste: e ele que
## serve ao combate (jogar rival no poste), e o banco de provas mede essa
## pancada. Braco e luminaria ficam acima de qualquer cabeca.
const COLISOR := Vector3(0.35, 6.0, 0.35)

## Do eixo da avenida ao eixo do poste: 0,6 m depois do meio-fio, como no
## video. Ja foi no fundo da calcada, na faixa de servico, e de la o braco nao
## alcancava a pista - nao passava por cima da camera, que e para o que ele
## existe. Rente ao meio-fio, o poste fica no andavel: quem sobe na calcada
## tem que desviar dele, como na rua de verdade.
const LATERAL: float = RoadTrack.LANE_WIDTH * RoadTrack.LANE_COUNT * 0.5 + 0.6

static var _malha: Mesh


## Um poste com o pe em `pe` e o braco da pista apontando para `olha`.
static func criar(pe: Vector3, olha: Vector3) -> StaticBody3D:
	var corpo := StaticBody3D.new()
	corpo.name = "Poste"
	corpo.collision_layer = Layers.WORLD
	corpo.collision_mask = 0
	corpo.position = pe
	# So a malha gira. O corpo fica nos eixos do mundo, como a caixa ficava:
	# girado, o colisor quadrado mudaria a quina que o rival pega na curva.
	var mi := MeshInstance3D.new()
	mi.mesh = malha()
	olha.y = 0.0
	mi.basis = Basis.looking_at(olha.normalized(), Vector3.UP)
	corpo.add_child(mi)
	var forma := Greybox.box_shape(COLISOR)
	forma.position = Vector3.UP * COLISOR.y * 0.5
	corpo.add_child(forma)
	return corpo


static func malha() -> Mesh:
	if _malha == null:
		var cena := CENA.instantiate()
		var no := cena.find_child("Poste", true, false) as MeshInstance3D
		assert(no != null, "poste.glb sem o no Poste")
		_malha = no.mesh
		cena.free()
	return _malha
