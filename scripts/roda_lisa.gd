class_name RodaLisa
extends RefCounted
## O borrao da roda em alta velocidade: os raios somem e um disco toma o lugar.
##
## A 35 m/s a roda da volta e meia por quadro, e a 60 Hz os raios piscam ou
## parecem girar para tras. Girando de verdade, cada ponto do raio vira um
## anel: o friso cinza do raio vira um anel cinza, o raio preto some no preto.
## O disco e esse desenho, tirado da malha dos raios de cada roda (`Raios_*`,
## filho da roda no modelo), e por isso serve a qualquer moto sem constante
## por modelo. Pneu, aro e cubo ficam: sao redondos, e girando nao piscam.
##
## Um por roda, com o estado dele: o `Entregador` so diz a velocidade.

## Velocidades, em m/s, em que o borrao entra e em que os raios voltam:
## separadas para nao piscar na fronteira.
const LIGA: float = 16.0
const DESLIGA: float = 14.0
## Aneis do disco, do cubo a ponta dos raios. 16 em 0,3 m da 2 cm cada: mais
## fino que um pixel da tela a 6 m.
const ANEIS: int = 16
## O fundo do borrao: o vao entre os raios e o outro lado da roda, no escuro.
## O mesmo "preto" da paleta do `arte/entregador.py`.
const FUNDO := Color(0.07, 0.07, 0.08)
## Quanto o anel puxa para a cor do raio, por fracao da volta que o raio
## cobre. O borrao fisico de cinco raios de 2 cm sai 12% da cor deles, e isso
## e preto com preto: forcado, o friso aparece como anel, que e o efeito que
## se quer ver de longe.
const GANHO: float = 4.0
## Meia espessura do disco, em metros: fica no plano do meio da roda, dentro
## do aro, como os raios que ele substitui.
const MEIA_LARGURA: float = 0.012

static var _material: StandardMaterial3D

var _raios: Node3D
var _disco: MeshInstance3D


func _init(roda: Node3D, paleta: Image) -> void:
	for filho in roda.get_children():
		if filho is MeshInstance3D and String(filho.name).begins_with("Raios"):
			_raios = filho
	assert(_raios != null, "roda %s sem os raios" % roda.name)
	_disco = MeshInstance3D.new()
	_disco.name = "Disco"
	_disco.mesh = _malha(_aneis((_raios as MeshInstance3D).mesh, paleta))
	_disco.material_override = _material_do_disco()
	_disco.visible = false
	roda.add_child(_disco)


func atualizar(velocidade: float) -> void:
	if velocidade > LIGA:
		_disco.visible = true
	elif velocidade < DESLIGA:
		_disco.visible = false
	_raios.visible = not _disco.visible


func lisa() -> bool:
	return _disco.visible


## A cor de cada anel e o raio de fora do ultimo: a media do que passa por
## cada distancia do eixo, pesada pela area que os raios cobrem ali.
static func _aneis(malha: Mesh, paleta: Image) -> Array:
	var arrays := malha.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if indices.is_empty():
		indices = PackedInt32Array(range(vertices.size()))
	var fora := 0.0
	for v in vertices:
		fora = maxf(fora, Vector2(v.y, v.z).length())

	var area: Array[float] = []
	var soma: Array[Color] = []
	area.resize(ANEIS)
	soma.resize(ANEIS)
	area.fill(0.0)
	soma.fill(Color(0, 0, 0, 0))
	# Triangulo comprido (o lado de um raio vai do cubo ao aro) cai em varios
	# aneis: amostrado numa grade, e nao pelo centro, que poria tudo num so.
	var grade := 6
	for t in range(0, indices.size(), 3):
		var a := vertices[indices[t]]
		var b := vertices[indices[t + 1]]
		var c := vertices[indices[t + 2]]
		var projetada := absf((b - a).cross(c - a).x) * 0.5
		if projetada < 1e-9:
			continue
		var uv := uvs[indices[t]]
		var x := clampi(int(uv.x * paleta.get_width()), 0, paleta.get_width() - 1)
		var y := clampi(int(uv.y * paleta.get_height()), 0, paleta.get_height() - 1)
		var cor := paleta.get_pixel(x, y)
		var pedaco := projetada / float(grade * (grade + 1) / 2)
		for i in grade:
			for j in grade - i:
				var p := a + (b - a) * ((i + 0.33) / grade) + (c - a) * ((j + 0.33) / grade)
				var anel := clampi(int(Vector2(p.y, p.z).length() / fora * ANEIS), 0, ANEIS - 1)
				area[anel] += pedaco
				soma[anel] += cor * pedaco

	var cores: Array[Color] = []
	for k in ANEIS:
		var r0 := fora * k / ANEIS
		var r1 := fora * (k + 1) / ANEIS
		# Metade da area projetada: malha fechada conta a frente e o verso.
		var cobre := area[k] * 0.5 / (PI * (r1 * r1 - r0 * r0))
		var media := soma[k] / area[k] if area[k] > 0.0 else FUNDO
		cores.append(FUNDO.lerp(media, minf(cobre * GANHO, 1.0)))
	return [cores, fora]


static func _malha(aneis: Array) -> ArrayMesh:
	var cores: Array[Color] = aneis[0]
	var fora: float = aneis[1]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lados := 24
	for k in ANEIS:
		st.set_color(cores[k])
		var r0 := fora * k / ANEIS
		var r1 := fora * (k + 1) / ANEIS
		for i in lados:
			var a0 := TAU * i / lados
			var a1 := TAU * (i + 1) / lados
			for lado: float in [-1.0, 1.0]:
				var x := lado * MEIA_LARGURA
				var q := [
					Vector3(x, cos(a0) * r0, sin(a0) * r0),
					Vector3(x, cos(a0) * r1, sin(a0) * r1),
					Vector3(x, cos(a1) * r1, sin(a1) * r1),
					Vector3(x, cos(a1) * r0, sin(a1) * r0),
				]
				var normal := Vector3(lado, 0.0, 0.0)
				_triangulo(st, q[0], q[1], q[2], normal)
				_triangulo(st, q[0], q[2], q[3], normal)
	st.generate_normals()
	return st.commit()


## Triangulo virado para `fora`. O Godot descarta face anti-horaria sem avisar
## (ver o `CLAUDE.md`): a ordem sai da normal pedida, e nao da mao.
static func _triangulo(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, fora: Vector3) -> void:
	# Horario visto de fora e normal geometrica apontando para dentro.
	if (b - a).cross(c - a).dot(fora) > 0.0:
		var t := b
		b = c
		c = t
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)


## A mesma luz do material do entregador: fosco e sem especular. A cor vem
## por vertice, porque o disco nao tem celula na paleta.
static func _material_do_disco() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.vertex_color_is_srgb = true
		_material.roughness = 1.0
		_material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return _material
