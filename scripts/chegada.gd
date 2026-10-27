class_name Chegada
extends Node3D
## A festa fica no endereco que decide a corrida, sem consumir sorteios do mundo.

## Dez metros deixam o atropelo acontecer antes de a moto inteira terminar.
const COMPRIMENTO: float = 10.0
const FILEIRAS: int = 14

const BRANCO := Color(0.94, 0.94, 0.9)
const PRETO := Color(0.035, 0.045, 0.06)
const TECIDO: Shader = preload("res://scripts/bandeira.gdshader")
const LARANJA := Color(0.95, 0.28, 0.055)


class Torcedor:
	extends Pessoa
	var fiscal: bool = false
	var posto := Vector3.ZERO
	var direcao: float = 0.0

	func _ready() -> void:
		super._ready()
		add_to_group(&"torcida_chegada")

	func reiniciar() -> void:
		estado = Estado.PARADA
		_corpo = Basis.IDENTITY
		_vel = Vector3.ZERO
		_relogio = 0.0
		_motos.clear()
		_caminho.clear()
		colocar(posto, direcao)

	# A torcida fica parada, e parada o atlas de caminhada ja da (o primeiro
	# quadro). So o fiscal segue em 3D: o gesto e a haste da bandeira nao estao
	# em atlas nenhum.
	func usar_sprite(ligado: bool) -> void:
		super.usar_sprite(ligado and not fiscal)

	func _olha_motos(delta: float) -> void:
		# Ele segura o posto, mas continua sujeito ao mesmo atropelo dos pedestres.
		if fiscal:
			_sem_susto = 1.0
		super._olha_motos(delta)

	func _fica() -> void:
		super._fica()
		if fiscal:
			# Uma varrida larga e mais lenta; o peso acompanha o ombro em vez de
			# sacudir apenas a ponta de um braco levantado.
			var ciclo := _relogio * TAU / 1.65
			_braco[0] = 2.1 + 0.25 * cos(ciclo)
			_abre[0] = 0.85 + 0.65 * sin(ciclo)
			_tronco = 0.09 * cos(ciclo)
			_coxa[0] = 0.07 * sin(ciclo)
			_coxa[1] = -_coxa[0]


func montar(pista: RoadTrack, distancia: float) -> void:
	name = "Chegada"
	var meio := RoadTrack.half_width()
	transform = pista.transform_at(distancia, 0.0)
	# O portico acompanha a inclinacao da pista; o publico usa a altura local
	# de cada amostra para nao flutuar quando a chegada cai numa rampa.
	for lado: float in [-1.0, 1.0]:
		_caixa(self, Vector3(0.65, 6.7, 0.65), Vector3(lado * (meio + 0.7), 3.35, 0), LARANJA)
	_caixa(self, Vector3(meio * 2.0 + 2.0, 1.5, 0.5), Vector3(0, 6.0, 0), PRETO)
	var letreiro := Label3D.new()
	letreiro.text = "CHEGADA"
	letreiro.font_size = 110
	letreiro.pixel_size = 0.011
	letreiro.outline_size = 12
	letreiro.position = Vector3(0, 6.0, 0.28)
	add_child(letreiro)
	for i in 28:
		for j in FILEIRAS:
			var largura := meio * 2.0 / 28.0
			var passo := COMPRIMENTO / float(FILEIRAS)
			var o := distancia - COMPRIMENTO * 0.5 + (float(j) + 0.5) * passo
			var p := pista.point(o, -meio + (float(i) + 0.5) * largura)
			var bloco := _caixa(
				self,
				Vector3(largura, 0.018, passo),
				to_local(p) + Vector3.UP * 0.025,
				BRANCO if (i + j) % 2 == 0 else PRETO
			)
			bloco.basis = global_basis.inverse() * pista.sample_basis(o)
	for lado: float in [-1.0, 1.0]:
		for i in 18:
			var o := distancia - 18.0 + float(i % 9) * 3.0
			var lateral := lado * (meio + 1.6 + float(i / 9) * 0.8)
			var pessoa := Torcedor.new()
			add_child(pessoa)
			var p := pista.point(o, lateral)
			pessoa.posto = to_local(p)
			pessoa.direcao = lado * PI * 0.5
			pessoa.colocar(pessoa.posto, pessoa.direcao)
			pessoa.vestir(Color.from_hsv(fposmod(float(i) * 0.137 + lado * 0.12, 1.0), 0.7, 0.9))
		# A grade deixa o corredor visualmente livre, sem mudar a fisica da prova.
		for i in 10:
			var o := distancia - 20.0 + float(i) * 3.0
			var grade := Node3D.new()
			add_child(grade)
			grade.global_transform = pista.transform_at(o, lado * (meio + 0.5))
			for h: float in [0.5, 1.0]:
				_caixa(grade, Vector3(0.06, 0.06, 2.8), Vector3(0, h, 0), BRANCO)
			_caixa(grade, Vector3(0.07, 1.1, 0.07), Vector3.ZERO + Vector3.UP * 0.55, LARANJA)
	var palco := Node3D.new()
	add_child(palco)
	palco.global_transform = pista.transform_at(distancia - COMPRIMENTO * 0.5, 0.0)
	var fiscal := Torcedor.new()
	fiscal.name = "FiscalDaBandeira"
	fiscal.fiscal = true
	fiscal.cadencia = 0.0
	palco.add_child(fiscal)
	fiscal.direcao = PI
	fiscal.colocar(fiscal.posto, fiscal.direcao)
	fiscal.vestir(BRANCO)
	# A haste e filha do braco: a mao e a bandeira nunca se separam no aceno.
	var braco := fiscal.find_child("Braco_E", true, false) as Node3D
	var haste := Node3D.new()
	haste.name = "BandeiraQuadriculada"
	braco.add_child(haste)
	haste.position = Vector3(0, -0.55, 0)
	_caixa(haste, Vector3(0.035, 1.8, 0.035), Vector3(0, -0.65, 0), BRANCO)
	var tecido := MeshInstance3D.new()
	tecido.name = "Tecido"
	# Subdivisoes deixam a onda curvar o pano, mantendo a borda presa a haste.
	var plano := PlaneMesh.new()
	plano.orientation = PlaneMesh.FACE_Z
	plano.size = Vector2(1.32, 0.88)
	plano.subdivide_width = 31
	plano.subdivide_depth = 19
	tecido.mesh = plano
	tecido.position = Vector3(0.66, -0.96, 0)
	var material := ShaderMaterial.new()
	material.shader = TECIDO
	tecido.material_override = material
	tecido.custom_aabb = AABB(Vector3(-0.8, -0.6, -0.6), Vector3(1.6, 1.2, 1.2))
	haste.add_child(tecido)
	# A corrida chega de noite: ilumina a faixa, o fiscal e o publico.
	for lado: float in [-1.0, 1.0]:
		var luz := OmniLight3D.new()
		luz.position = Vector3(lado * meio * 0.65, 5, 0)
		luz.omni_range = 24.0
		luz.light_energy = 2.5
		luz.light_color = Color(1.0, 0.88, 0.7)
		add_child(luz)


func _caixa(pai: Node3D, tamanho: Vector3, lugar: Vector3, cor: Color) -> MeshInstance3D:
	var no := MeshInstance3D.new()
	var malha := BoxMesh.new()
	malha.size = tamanho
	no.mesh = malha
	no.material_override = RoadTrack.material_liso(cor)
	no.position = lugar
	pai.add_child(no)
	return no


## Projeta a caixa inteira na direcao da pista, inclusive ao cruzar enviesado.
static func recuo_traseira(eixos: Basis, tamanho: Vector3, rumo: Basis) -> float:
	return (
		(
			absf(eixos.x.dot(rumo.z)) * tamanho.x
			+ absf(eixos.y.dot(rumo.z)) * tamanho.y
			+ absf(eixos.z.dot(rumo.z)) * tamanho.z
		)
		* 0.5
	)
