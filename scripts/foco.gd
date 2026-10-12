class_name Foco
extends RefCounted
## A marca do corredor que a camera segue (`foco.gdshader`): o borrao de
## velocidade passa em volta dele e nao nele.

## Um material so para todo ator marcado: ele nao tem parametro nenhum.
static var _material: ShaderMaterial


## Poe (ou tira) a marca em toda malha debaixo de `raiz`: a do modelo, o disco
## da `RodaLisa` e peca que alguem acrescentar.
static func marcar(raiz: Node, sim: bool) -> void:
	if raiz == null:
		return
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = preload("res://scripts/foco.gdshader")
		# O primeiro do passe transparente: o borrao (`Borrao`) le o stencil
		# que isto grava, e precisa vir depois.
		_material.render_priority = Material.RENDER_PRIORITY_MIN
	for malha: Node in raiz.find_children("*", "MeshInstance3D", true, false):
		(malha as MeshInstance3D).material_overlay = _material if sim else null
