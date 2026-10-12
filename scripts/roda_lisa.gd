class_name RodaLisa
extends RefCounted
## O disco que cobre o vazado da roda em alta velocidade.
##
## A 35 m/s a roda da volta e meia por quadro, e a 60 Hz os raios piscam ou
## parecem girar para tras. O borrao de verdade transforma raio e vazado num
## disco de tom medio; aqui o disco e malha, ligado pelo `Entregador` acima de
## uma velocidade. O resto da roda (pneu, aro, cubo, freio) ja e redondo, e
## girando nao estrobosca.

## Raio do disco em fracao do raio da roda: ate onde comeca o pneu nas tres
## motos (0,72 na CG, 0,73 na XRE, 0,70 na PCX), passando um pouco para
## dentro dele, e a meia largura, em metros, que cobre os raios cruzados da
## XRE sem sair pelo flanco de nenhum pneu.
const DISCO_RAIO: float = 0.74
const DISCO_MEIA_LARGURA: float = 0.035


## Monta o disco de uma roda, filho dela e escondido: quem liga e o ator. A
## cor sai da propria malha: o UV dos raios, com o mesmo material do resto. Assim
## a roda raiada da XRE e a de liga da CG ganham cada uma o seu tom sem
## constante por modelo, e a pintura do corredor vale no disco tambem.
static func criar(roda: MeshInstance3D, raio: float, material: Material) -> MeshInstance3D:
	var arrays := roda.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if indices.is_empty():
		indices = PackedInt32Array(range(vertices.size()))
	# Voto por triangulo: entre o cubo e o aro, perto do plano do meio, so ha
	# raio. O disco de freio fica de fora pela largura, o tambor pelo raio, e o
	# box dos raios da CG so tem vertice nas pontas, por isso o centro e nao o
	# vertice.
	var votos: Dictionary[Vector2, int] = {}
	for t in range(0, indices.size(), 3):
		var centro := (
			(vertices[indices[t]] + vertices[indices[t + 1]] + vertices[indices[t + 2]]) / 3.0
		)
		var r := Vector2(centro.y, centro.z).length()
		if absf(centro.x) < DISCO_MEIA_LARGURA and r > raio * 0.3 and r < raio * 0.55:
			var uv := uvs[indices[t]]
			votos[uv] = votos.get(uv, 0) + 1
	var uv := uvs[0]
	var mais := 0
	for chave: Vector2 in votos:
		if votos[chave] > mais:
			mais = votos[chave]
			uv = chave

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_uv(uv)
	var lados := 20
	var r_disco := raio * DISCO_RAIO
	var w := DISCO_MEIA_LARGURA
	for k in lados:
		var a0 := TAU * k / lados
		var a1 := TAU * (k + 1) / lados
		var p0 := Vector2(cos(a0), sin(a0)) * r_disco
		var p1 := Vector2(cos(a1), sin(a1)) * r_disco
		for lado: float in [-1.0, 1.0]:
			_triangulo(
				st,
				Vector3(lado * w, 0.0, 0.0),
				Vector3(lado * w, p0.x, p0.y),
				Vector3(lado * w, p1.x, p1.y),
				Vector3(lado, 0.0, 0.0)
			)
		var fora := Vector3(0.0, cos((a0 + a1) * 0.5), sin((a0 + a1) * 0.5))
		var q := [
			Vector3(-w, p0.x, p0.y),
			Vector3(w, p0.x, p0.y),
			Vector3(w, p1.x, p1.y),
			Vector3(-w, p1.x, p1.y),
		]
		_triangulo(st, q[0], q[1], q[2], fora)
		_triangulo(st, q[0], q[2], q[3], fora)
	st.generate_normals()

	var disco := MeshInstance3D.new()
	disco.name = "Disco"
	disco.mesh = st.commit()
	disco.material_override = material
	disco.visible = false
	roda.add_child(disco)
	return disco


## Triangulo virado para `fora`. O Godot descarta face anti-horaria sem avisar
## (ver o `CLAUDE.md`), e acertar a ordem na mao em tres faces diferentes e
## onde isso se perde: aqui a ordem sai da normal pedida.
static func _triangulo(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, fora: Vector3) -> void:
	# Horario visto de fora e normal geometrica apontando para dentro.
	if (b - a).cross(c - a).dot(fora) > 0.0:
		var t := b
		b = c
		c = t
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)
