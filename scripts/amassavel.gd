class_name Amassavel
extends StaticBody3D
## Peca fixa que amassa com a batida, em vez de sair voando: o poste. Fica de
## pe, no mesmo lugar e com o mesmo colisor - e o jogador que cai, se chegou
## rapido (`PlayerBike._resolve_collisions`), e o poste que leva a marca.
##
## O amassado e visual e proporcional a forca: a malha envergada para longe de
## quem bateu e um pouco mais baixa. O colisor nao acompanha, de proposito: e
## ele que o banco de provas mede, e um poste que muda de forma no meio da
## corrida mudaria a quina que o rival pega.

## O topo do poste envergado na batida mais forte (a 100% da `max_speed`).
const ENVERGA_MAX: float = 24.0
## Quanto a malha encolhe na batida mais forte, por causa da dobra.
const ENCOLHE_MAX: float = 0.1

var amassado: float = 0.0
var _malha: Node3D
var _inicial := Transform3D.IDENTITY


func _ready() -> void:
	add_to_group(&"quebraveis")


## A malha que amassa: so ela gira, o corpo e o colisor ficam nos eixos do mundo.
func usar_malha(malha: Node3D) -> void:
	_malha = malha
	_inicial = malha.transform


## Bateu com `forca` (0 a 1, a fracao da velocidade maxima da moto que chegou
## na face) vindo na direcao `de` (a da moto). Bater de novo mais fraco nao
## desamassa: vale a pior batida.
func amassar(forca: float, de: Vector3) -> void:
	forca = clampf(forca, 0.0, 1.0)
	de.y = 0.0
	if _malha == null or forca <= amassado or de.length_squared() < 1e-6:
		return
	amassado = forca
	# O topo vai para onde a moto ia: gira em torno do eixo horizontal
	# perpendicular a batida. O pe fica onde estava.
	var eixo := Vector3.UP.cross(de.normalized())
	var giro := Basis(eixo, deg_to_rad(ENVERGA_MAX) * forca)
	var escala := Basis.from_scale(Vector3(1.0, 1.0 - ENCOLHE_MAX * forca, 1.0))
	var base := global_basis.orthonormalized()
	# `eixo` esta no mundo; a malha esta no espaco do corpo.
	var local := base.inverse() * giro * base
	_malha.transform = Transform3D(local * _inicial.basis * escala, _inicial.origin)


func reiniciar() -> void:
	amassado = 0.0
	if _malha != null:
		_malha.transform = _inicial
