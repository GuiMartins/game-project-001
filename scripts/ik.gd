class_name Ik
extends RefCounted
## IK de dois ossos, para os atores de pecas rigidas: o entregador e quem dirige
## os carros.
##
## Os dois modelos seguem a mesma convencao (`arte/entregador.py`,
## `arte/carros.py`): cada peca tem a origem na articulacao e a posicao de cada
## filho e o osso do pai. Entao o comprimento de braco e perna vem do modelo,
## e nao de um numero copiado para ca.


## Dobra `raiz` e `meio` para a ponta do segundo osso alcancar `alvo`.
##
## `osso_a` e `osso_b` sao as posicoes de repouso do meio e da ponta, cada uma
## no espaco do pai. `polo` diz para que lado a articulacao do meio aponta.
## Alvo fora do alcance estica o membro reto na direcao dele em vez de quebrar.
static func dois_ossos(
	raiz: Node3D, meio: Node3D, osso_a: Vector3, osso_b: Vector3, alvo: Vector3, polo: Vector3
) -> void:
	var la := osso_a.length()
	var lb := osso_b.length()
	var origem := raiz.global_position
	var falta := alvo - origem
	var eixo := falta.normalized()
	var dist := clampf(falta.length(), absf(la - lb) + 0.001, la + lb - 0.001)
	var ao_longo := (la * la - lb * lb + dist * dist) / (2.0 * dist)
	var afasta := sqrt(maxf(la * la - ao_longo * ao_longo, 0.0))
	var lado := (polo - eixo * polo.dot(eixo)).normalized()
	var junta := origem + eixo * ao_longo + lado * afasta
	var fim := origem + eixo * dist

	var pai := (raiz.get_parent() as Node3D).global_basis
	var de := (pai * osso_a).normalized()
	raiz.global_basis = Basis(Quaternion(de, (junta - origem).normalized())) * pai
	var base_raiz := raiz.global_basis
	var de_b := (base_raiz * osso_b).normalized()
	meio.global_basis = Basis(Quaternion(de_b, (fim - junta).normalized())) * base_raiz
