class_name Pedestres
extends RefCounted
## A gente da calcada (V19): parada e andando, dos dois lados, e mais gente na
## esquina. Sem logica nenhuma e sem colisor. Quem atravessa a rua, desce do
## carro ou pula da frente da moto e a `Pessoa`, articulada, e sao poucas.
##
## Um `MultiMesh` por pose: sao mais de mil pessoas por corrida, e cada uma
## como no proprio seria mil chamadas de desenho. A malha e uma so, de pe, e
## quem anda e balanca e o `pedestres.gdshader`, no vertice: `MultiMesh` nao
## tem esqueleto. A camisa e a superficie `roupa` do modelo, branca, que a cor
## da instancia pinta; pele, calca e cabelo ficam como foram pintados.

enum Pose { PARADO, ANDANDO }

const CENA: PackedScene = preload("res://assets/pedestres/pedestres.glb")
const SHADER: Shader = preload("res://scripts/pedestres.gdshader")
const NOS: Array[String] = ["Parado", "Andando"]
## O grupo de quem anda na rua, `Multidao` e `Pessoa`, para o `World` repassar
## a cadencia do ator.
const GRUPO_NOS: StringName = &"pedestres"

## As camisas. Cor de roupa de rua: clara e lisa, e nenhuma mais saturada que
## a bag, que tem que ser a coisa mais viva da tela.
const CAMISAS: Array[Color] = [
	Color(0.95, 0.95, 0.92),
	Color(0.92, 0.90, 0.84),
	Color(0.78, 0.22, 0.20),
	Color(0.95, 0.80, 0.30),
	Color(0.30, 0.48, 0.78),
	Color(0.34, 0.62, 0.42),
	Color(0.20, 0.20, 0.22),
	Color(0.85, 0.55, 0.62),
]
## A distancia entre um grupo e o seguinte, de cada lado, e quantos por grupo.
const PASSO := Vector2(6.0, 16.0)
const GRUPO := Vector2i(1, 3)
## Na esquina junta mais gente, esperando para atravessar a rua que cruza.
const ESQUINA := Vector2i(3, 6)

static var _malha: Mesh
static var _materiais: Dictionary[String, ShaderMaterial] = {}


## Espalha a gente pela calcada da avenida em `props`. Entre a faixa de
## servico e a fachada: fora do andavel, por onde a moto foge, e da faixa das
## arvores, para ninguem nascer dentro de um tronco.
static func montar(
	track: RoadTrack, cruzamentos: Array[Vector2], rua: RandomNumberGenerator, props: Node3D
) -> void:
	var onde := posicoes(track, cruzamentos, rua)
	for pose: int in Pose.values():
		props.add_child(_multimesh(pose, onde[pose]))


## Onde fica cada pessoa, por pose: `[transform, camisa]`. Separado do
## `montar` para o teste ler: sem tela, o `MultiMesh` nao guarda o que recebe.
static func posicoes(
	track: RoadTrack, cruzamentos: Array[Vector2], rua: RandomNumberGenerator
) -> Array[Array]:
	var edge := RoadTrack.half_width() + RoadTrack.SHOULDER
	var perto := edge + RoadTrack.FAIXA_SERVICO + 0.4
	var longe := edge + Cidade.RECUO_FACHADA - 0.8
	var onde: Array[Array] = [[], []]
	for side: float in [-1.0, 1.0]:
		var o := rua.randf_range(5.0, 15.0)
		while o < track.length - 5.0:
			var quantos := rua.randi_range(GRUPO.x, GRUPO.y)
			if _na_esquina(cruzamentos, o, side):
				quantos = rua.randi_range(ESQUINA.x, ESQUINA.y)
			for i in quantos:
				var aqui := o + rua.randf_range(-1.5, 1.5)
				var lateral := rua.randf_range(perto, longe) * side
				var pose := Pose.ANDANDO if rua.randf() < 0.5 else Pose.PARADO
				# Quem anda, anda ao longo da calcada, num sentido ou no outro;
				# quem esta parado olha para qualquer lado.
				var giro := (
					(0.0 if rua.randf() < 0.5 else PI)
					if pose == Pose.ANDANDO
					else rua.randf_range(-PI, PI)
				)
				var camisa := CAMISAS[rua.randi_range(0, CAMISAS.size() - 1)]
				if Cidade.na_boca(cruzamentos, aqui, side):
					continue
				var t := track.transform_at(aqui, lateral)
				t.basis = t.basis * Basis(Vector3.UP, giro)
				onde[pose].append([t, camisa])
			o += rua.randf_range(PASSO.x, PASSO.y)
	return onde


## Se `o` esta a ate 8 m da boca de uma rua que abre do lado `side`.
static func _na_esquina(cruzamentos: Array[Vector2], o: float, side: float) -> bool:
	for c in cruzamentos:
		var abre := c.y == Cidade.LADO_AMBOS or c.y == side
		var borda := Cidade.RUA_LARGURA * 0.5 + Cidade.RUA_CALCADA
		if abre and absf(absf(o - c.x) - borda) < 8.0:
			return true
	return false


static func _multimesh(pose: Pose, gente: Array) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = malha()
	mm.instance_count = gente.size()
	for i in gente.size():
		mm.set_instance_transform(i, gente[i][0])
		mm.set_instance_color(i, gente[i][1])
	var mmi := Multidao.new()
	mmi.name = "Pedestres" + NOS[pose]
	mmi.multimesh = mm
	mmi.set_instance_shader_parameter(&"andando", 1.0 if pose == Pose.ANDANDO else 0.0)
	# O shader leva cada um ate meio trecho para frente ou para tras, longe do
	# transform que o `MultiMesh` usa para saber o que esta na tela.
	mmi.extra_cull_margin = 6.0
	mmi.add_to_group(GRUPO_NOS)
	return mmi


## A pessoa de pe, com o material de cada superficie trocado pelo shader na
## mesma cor. Compartilhada por toda corrida: o que anima vem de cada
## `Multidao`, e nao do material.
static func malha() -> Mesh:
	if _malha == null:
		var cena := CENA.instantiate()
		var no := cena.find_child("Pessoa", true, false) as MeshInstance3D
		assert(no != null, "pedestres.glb sem o no Pessoa")
		_malha = no.mesh
		for s in _malha.get_surface_count():
			_malha.surface_set_material(s, material(_malha.surface_get_material(s)))
		cena.free()
	return _malha


## O material do shader no lugar de `mat`, um por material do `.glb`, e o
## mesmo para a malha do `MultiMesh` e para as pecas da `Pessoa`.
static func material(mat: Material) -> ShaderMaterial:
	var nome := mat.resource_name
	if not _materiais.has(nome):
		var novo := ShaderMaterial.new()
		novo.shader = SHADER
		novo.set_shader_parameter(&"cor", (mat as BaseMaterial3D).albedo_color)
		novo.set_shader_parameter(&"roupa", nome == "roupa")
		novo.set_shader_parameter(&"e_pele", nome == "pele")
		_materiais[nome] = novo
	return _materiais[nome]


## Os pedestres de uma pose. So o relogio deles mora aqui: com o mundo pausado,
## ou congelado na prova, ele para junto, e o `TIME` do shader nao pararia.
class Multidao:
	extends MultiMeshInstance3D

	## Poses por segundo, repassada pelo `World` de `WorldTuning.ator_cadencia`.
	var cadencia: float = 0.0:
		set(valor):
			cadencia = valor
			set_instance_shader_parameter(&"cadencia", valor)
	var _tempo: float = 0.0

	# No passo de fisica, e nao no quadro: a prova roda um numero exato de
	# passos, e o quadro dela tem de sair igual em toda maquina.
	func _physics_process(delta: float) -> void:
		_tempo += delta
		set_instance_shader_parameter(&"tempo", _tempo)
