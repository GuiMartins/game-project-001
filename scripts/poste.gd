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

## A lente da cabeca de LED, no modelo: um pouco abaixo dos 10 m da ponta do
## braco e a 3,4 m do fuste para cada lado (`arte/poste.py`: a ponta a 3,2 m,
## e a cabeca de 0,75 m comecando 0,15 m antes dela).
const LENTE := Vector2(3.425, 9.9)
## A superficie da lente na malha: a segunda, depois do ferro.
const SUPERFICIE_LENTE: int = 1
const LAMPADA: Shader = preload("res://scripts/lampada.gdshader")
## Branco de LED neutro puxado para o quente: e o que a cabeca chata do V15
## acende na rua de verdade, e contra o azul da noite separa luz de ceu.
const COR_DA_LUZ := Color(1.0, 0.93, 0.8)
## A poca no chao: 24 m de alcance para a luz chegar com forca nos 10 m de
## altura e o cone de 70 graus abrir uma poca de uns 14 m - a cabeca da pista
## pinta duas faixas, a da calcada pinta a calcada inteira. O espacamento dos
## postes e de 18 a 34 m, entao entre uma poca e outra sobra meia-luz, e e esse
## ritmo de claro e menos claro que da a velocidade de noite. Forte: e a luz
## principal da rua, e com 6 a calcada sumia.
const ALCANCE: float = 24.0
const ANGULO: float = 70.0
const ENERGIA: float = 10.0
## Quando os postes acendem, no escuro da `Hora`: entre o fim do entardecer e o
## meio da hora azul. Cada poste no seu.
const ACENDE_DE: float = 0.3
const ACENDE_ATE: float = 0.55

static var _malha: Mesh
static var _lente: ShaderMaterial


## Um poste com o pe em `pe` e o braco da pista apontando para `olha`.
static func criar(pe: Vector3, olha: Vector3) -> Amassavel:
	var corpo := Amassavel.new()
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
	corpo.usar_malha(mi)
	# De noite: as duas lentes acendem e cada uma joga a sua poca, a da pista e
	# a da calcada. O mesmo limiar para lente e luz, que e a mesma lampada.
	var quando := Relogio.limiar(pe, ACENDE_DE, ACENDE_ATE)
	mi.set_surface_override_material(SUPERFICIE_LENTE, lente())
	mi.set_instance_shader_parameter(&"limiar", quando)
	for lado: float in [-1.0, 1.0]:
		var luz := LuzDaNoite.spot(COR_DA_LUZ, ENERGIA, ALCANCE, ANGULO, quando)
		luz.position = Vector3(0.0, LENTE.y, LENTE.x * lado)
		luz.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		mi.add_child(luz)
	var forma := Greybox.box_shape(COLISOR)
	forma.position = Vector3.UP * COLISOR.y * 0.5
	corpo.add_child(forma)
	return corpo


## A lente que acende de noite (`lampada.gdshader`), uma para todos os postes:
## quando cada um acende vai no parametro de instancia.
static func lente() -> ShaderMaterial:
	if _lente == null:
		_lente = ShaderMaterial.new()
		_lente.shader = LAMPADA
		_lente.set_shader_parameter(&"acesa", COR_DA_LUZ)
	return _lente


static func malha() -> Mesh:
	if _malha == null:
		var cena := CENA.instantiate()
		var no := cena.find_child("Poste", true, false) as MeshInstance3D
		assert(no != null, "poste.glb sem o no Poste")
		_malha = no.mesh
		cena.free()
	return _malha
