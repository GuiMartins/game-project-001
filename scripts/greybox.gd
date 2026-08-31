extends RefCounted
class_name Greybox
## Caixas brancas. Nada mais.
##
## O texto de referencia e explicito: prototipar o feel com cubos brancos antes
## de qualquer arte. Estes helpers existem pra que trocar caixa por Sprite3D
## billboard mais tarde seja um unico ponto de mudanca.

static func material(color: Color, emissive: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	if emissive:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 0.6
	return mat


static func box(size: Vector3, color: Color, emissive: bool = false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material(color, emissive)
	return mi


static func box_shape(size: Vector3) -> CollisionShape3D:
	var shape := BoxShape3D.new()
	shape.size = size
	var cs := CollisionShape3D.new()
	cs.shape = shape
	return cs
