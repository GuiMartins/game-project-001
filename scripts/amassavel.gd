class_name Amassavel
extends StaticBody3D
## Poste, semaforo, portico e placa: tudo que e fixo no chao e amassa com a
## batida, em vez de sair voando. Fica de pe, no mesmo lugar e com o mesmo
## colisor - e o jogador que cai, se chegou rapido (`PlayerBike`), e a peca que
## leva a marca. Uma classe so para todas: peca que umas voam e outras nao
## le como bug, e foi assim que o Arthur viu a V34.
##
## O amassado e visual e proporcional a forca: o desenho envergado para longe de
## quem bateu e um pouco mais baixo. O colisor nao acompanha, de proposito: e
## ele que o banco de provas mede, e uma peca que muda de forma no meio da
## corrida mudaria a quina que o rival pega.

## O topo envergado na batida mais forte (a 100% da `max_speed`).
const ENVERGA_MAX: float = 40.0
## Quanto o desenho encolhe na batida mais forte, por causa da dobra.
const ENCOLHE_MAX: float = 0.2
## Abaixo disto a marca nao e batida, e encosto: nao amassa nem avisa.
const FORCA_MINIMA: float = 0.05

var amassado: float = 0.0
## Quem tem o desenho, quando ele nao e o proprio corpo (semaforo, portico): o
## corpo e so o colisor, filho do no que carrega as malhas.
var raiz: Node3D
var _malhas: Array[Node3D] = []
var _iniciais: Array[Transform3D] = []


## Colisor de caixa de pe no chao, filho de `raiz`, que carrega o desenho.
static func com_colisor(a_raiz: Node3D, tamanho: Vector3) -> Amassavel:
	var corpo := Amassavel.new()
	corpo.raiz = a_raiz
	corpo.collision_layer = Layers.WORLD
	corpo.collision_mask = 0
	var forma := Greybox.box_shape(tamanho)
	forma.position = Vector3.UP * tamanho.y * 0.5
	corpo.add_child(forma)
	a_raiz.add_child(corpo)
	return corpo


func _ready() -> void:
	add_to_group(&"quebraveis")


## Bateu com `forca` (0 a 1, a fracao da velocidade maxima da moto que chegou
## na face) vindo na direcao `de` (a da moto). Bater de novo mais fraco nao
## desamassa: vale a pior batida. Devolve se foi a primeira batida da largada.
func amassar(forca: float, de: Vector3) -> bool:
	forca = clampf(forca, 0.0, 1.0)
	de.y = 0.0
	if forca < FORCA_MINIMA or forca <= amassado or de.length_squared() < 1e-6:
		return false
	_acha_as_malhas()
	var primeira := amassado == 0.0
	amassado = forca
	# O topo vai para onde a moto ia: gira em torno do eixo horizontal
	# perpendicular a batida. O pe fica onde estava.
	var eixo := Vector3.UP.cross(de.normalized())
	var giro := Basis(eixo, deg_to_rad(ENVERGA_MAX) * forca)
	var escala := Basis.from_scale(Vector3(1.0, 1.0 - ENCOLHE_MAX * forca, 1.0))
	var dono := _dono()
	var base := dono.global_basis.orthonormalized()
	# `eixo` esta no mundo; as malhas, no espaco de quem as carrega.
	var dobra := Transform3D(base.inverse() * giro * base * escala, Vector3.ZERO)
	for i in _malhas.size():
		_malhas[i].transform = dobra * _iniciais[i]
	return primeira


func reiniciar() -> void:
	amassado = 0.0
	for i in _malhas.size():
		_malhas[i].transform = _iniciais[i]


func _dono() -> Node3D:
	return raiz if raiz != null else self


## O desenho e tudo que o dono carrega e nao e colisor. Achado na primeira
## batida, e nao na criacao: o semaforo e o portico ganham as luzes e as chapas
## depois do colisor.
func _acha_as_malhas() -> void:
	if not _malhas.is_empty():
		return
	for no in _dono().get_children():
		if no is Node3D and no != self and not (no is CollisionShape3D):
			_malhas.append(no as Node3D)
			_iniciais.append((no as Node3D).transform)
