class_name Marcos
extends RefCounted
## Os marcos do fundo (V14a): o que fica no fim da reta e faz a tela ler "Rio"
## de longe - igreja no morro, roda-gigante, museu, torre de igreja.
##
## Sao um CATALOGO de pecas baixas, e a `Cidade` escolhe onde a pista da vista:
## ao fim de cada reta, a algumas centenas de metros, de lado. Trocar de cidade
## e trocar o catalogo (`rio`); nenhum marco nasce em coordenada fixa.
##
## Sao primitivas montadas aqui, e nao um modelo do Blender como o poste e a
## arvore: a 300 m e debaixo de neblina um marco e uma silhueta de poucos
## pixels, e o que ele precisa ter e a forma, a altura e o lugar - nao a
## textura. Sem colisor: ficam alem do chao da avenida, fora do alcance da moto.
##
## Cada peca nasce com o pe em Y = 0 e a frente em -Z, e desce 30 m abaixo
## disso num morro: a pista sobe e desce, e sem o pe fundo a peca flutuaria
## quando o fim da reta estivesse num vale.


## Uma peca do catalogo: o nome, o raio que ela ocupa no chao (para nao nascer
## em cima da pista), a altura, a escala e quem a monta.
class Marco:
	extends RefCounted
	var nome: StringName
	var raio: float
	var altura: float
	## Quanto a peca cresce ao ser plantada; `raio` e `altura` sao os dela
	## inteira, ja com isso.
	var escala: float
	var construir: Callable

	func _init(
		a_nome: StringName, a_raio: float, a_altura: float, a_escala: float, a_construir: Callable
	) -> void:
		nome = a_nome
		raio = a_raio
		altura = a_altura
		escala = a_escala
		construir = a_construir


## O grupo de todo marco plantado: a prova visual acha o primeiro por ele.
const GRUPO: StringName = &"marcos"

## Onde cai o primeiro marco, e quanto sobra entre o fim de uma reta e a
## busca da seguinte. Com 400 a 700 m, e a visao de 300 a 430 m, dois marcos
## nunca dividem a mesma tela: o de tras ainda e neblina quando o da frente
## passa.
const PRIMEIRO := Vector2(120.0, 320.0)
const ESPACO := Vector2(400.0, 700.0)
## A reta acaba quando o rumo gira mais que isto em `RETA_JANELA` metros.
const RETA_GIRO: float = 0.1
const RETA_JANELA: float = 60.0
## A que distancia do fim da reta o marco fica, e quanto para o lado. Perto
## demais ele vira parede; longe demais, a neblina de 0,0045 engole: a 450 m
## sobram 13% dele e a roda-gigante, que e feita de linha, sumia de vez. A 200
## a 320 m sobram de 25% a 40%, o azul de distancia das referencias.
const DISTANCIA := Vector2(170.0, 260.0)
const LADO := Vector2(0.0, 24.0)
## A folga entre a beirada do marco e qualquer ponto da pista.
const FOLGA: float = 40.0
## O espacamento com que a pista e amostrada para medir a folga.
const AMOSTRA: float = 16.0
## Deixa de procurar este tanto antes do fim da pista: marco atras da linha de
## chegada ninguem ve.
const FIM_FOLGA: float = 40.0
## Quantas posicoes tentar para cada peca antes de desistir dela.
const TENTATIVAS: int = 8
## Quanto o pe do marco desce abaixo do fim da reta.
const PE: float = 30.0

## O azul do ar de distancia, e quanto de cada peca ele toma: a serra e o
## marco leem como "longe" por esse azul, nao por sumirem.
const AR := Color(0.55, 0.68, 0.85)
const ENEVOADO: float = 0.4

const COR_MORRO := Color(0.30, 0.40, 0.27)
const COR_PEDRA := Color(0.52, 0.50, 0.46)
const COR_PAREDE := Color(0.93, 0.92, 0.87)
const COR_TELHA := Color(0.62, 0.30, 0.20)
const COR_ESCURO := Color(0.20, 0.22, 0.26)
const COR_VIDRO := Color(0.42, 0.58, 0.68)

static var _materiais: Dictionary = {}


## O catalogo do Rio: o que as referencias mostram atras da avenida.
static func rio() -> Array[Marco]:
	# A escala existe porque o corredor tem canion de 30 m dos dois lados: a
	# 200 m, so o que passa de uns 15 graus aparece por cima dele, e o marco
	# tem de ser maior que o real para ler como marco, e nao como um predio a
	# mais. O morro, que ja e alto, fica no tamanho que e.
	return [
		Marco.new(&"igreja_no_morro", 80.0, 115.0, 1.0, _igreja_no_morro),
		Marco.new(&"roda_gigante", 40.0, 100.0, 1.5, _roda_gigante),
		Marco.new(&"museu", 60.0, 55.0, 1.7, _museu),
		Marco.new(&"torre_de_igreja", 35.0, 100.0, 1.5, _torre_de_igreja),
	]


## Planta os marcos ao longo da pista e devolve cada um, na ordem. `semente` e
## a da cidade; o sorteio e proprio, entao nada do resto muda por causa dele.
static func montar(
	track: RoadTrack, semente: int, catalogo: Array[Marco], props: Node3D
) -> Array[Node3D]:
	var plantados: Array[Node3D] = []
	if catalogo.is_empty():
		return plantados
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(semente + 9)
	var pontos := _amostra(track)
	var anterior := -1
	var o := rng.randf_range(PRIMEIRO.x, PRIMEIRO.y)
	while o < track.length - FIM_FOLGA:
		var fim := _fim_de_reta(track, o)
		var primeiro := _sorteia(rng, catalogo.size(), anterior)
		# Se a peca sorteada nao cabe no fim desta reta (o morro e largo), tenta
		# as outras: vista sem marco e pior que vista com o segundo da fila.
		for k in catalogo.size():
			var idx := (primeiro + k) % catalogo.size()
			if idx == anterior and catalogo.size() > 1:
				continue
			var onde: Variant = _acha_lugar(track, fim, catalogo[idx], pontos, rng)
			if onde == null:
				continue
			var no := _pe_do_marco(catalogo[idx], onde as Transform3D)
			# De onde da a vista: a prova poe a camera 60 m antes dele.
			no.set_meta(&"fim", fim)
			props.add_child(no)
			plantados.append(no)
			anterior = idx
			break
		o = fim + rng.randf_range(ESPACO.x, ESPACO.y)
	return plantados


## O primeiro ponto, a partir de `o`, onde a pista deixa de ser reta.
static func _fim_de_reta(track: RoadTrack, o: float) -> float:
	var s := o
	var limite := track.length - FIM_FOLGA
	while s < limite:
		if absf(_giro(track, s)) > RETA_GIRO:
			return s
		s += 20.0
	return limite


static func _giro(track: RoadTrack, o: float) -> float:
	var a := -track.sample_basis(o).z
	var b := -track.sample_basis(minf(o + RETA_JANELA, track.length)).z
	return wrapf(atan2(b.x, b.z) - atan2(a.x, a.z), -PI, PI)


## Nunca a mesma peca duas vezes seguidas.
static func _sorteia(rng: RandomNumberGenerator, quantas: int, anterior: int) -> int:
	var idx := rng.randi_range(0, quantas - 1)
	if quantas > 1 and idx == anterior:
		idx = (idx + 1 + rng.randi_range(0, quantas - 2)) % quantas
	return idx


## A posicao e a frente do marco: a `DISTANCIA` a frente de `fim`, de lado, com
## a folga da pista toda. A frente (-Z) encara quem vem pela reta. Nulo se
## nenhuma tentativa couber.
static func _acha_lugar(
	track: RoadTrack,
	fim: float,
	marco: Marco,
	pontos: PackedVector3Array,
	rng: RandomNumberGenerator
) -> Variant:
	var base := track.sample_position(fim)
	var frente := -track.sample_basis(fim).z
	frente.y = 0.0
	frente = frente.normalized()
	var direita := track.sample_basis(fim).x
	direita.y = 0.0
	direita = direita.normalized()
	var lado := 1.0 if rng.randf() < 0.5 else -1.0
	for i in TENTATIVAS:
		var longe := rng.randf_range(DISTANCIA.x, DISTANCIA.y)
		var de_lado := rng.randf_range(LADO.x, LADO.y) * lado
		var p := base + frente * longe + direita * de_lado
		p.y = base.y
		if _livre(p, marco.raio + FOLGA, pontos):
			return Transform3D(Basis.looking_at(-frente, Vector3.UP), p)
		lado = -lado
	return null


## Se nenhum ponto da pista chega a `raio` de `p`, no plano.
static func _livre(p: Vector3, raio: float, pontos: PackedVector3Array) -> bool:
	for q in pontos:
		if Vector2(p.x - q.x, p.z - q.z).length() < raio:
			return false
	return true


static func _amostra(track: RoadTrack) -> PackedVector3Array:
	var pontos := PackedVector3Array()
	var s := 0.0
	while s < track.length:
		pontos.append(track.sample_position(s))
		s += AMOSTRA
	pontos.append(track.sample_position(track.length))
	return pontos


static func _pe_do_marco(marco: Marco, onde: Transform3D) -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "Marco_%s" % marco.nome
	raiz.add_to_group(GRUPO)
	raiz.transform = onde.scaled_local(Vector3.ONE * marco.escala)
	marco.construir.call(raiz)
	return raiz


## --- As pecas -------------------------------------------------------------


## O morro de pedra e mato com a igreja branca no alto (`02_praca_maua`).
static func _igreja_no_morro(raiz: Node3D) -> void:
	_cone(raiz, 14.0, 75.0, 92.0 + PE, Vector3(0.0, 92.0 * 0.5 - PE * 0.5, 0.0), COR_MORRO)
	# A pedra aparecendo no meio do mato, de um lado so.
	_caixa(raiz, Vector3(26.0, 30.0, 22.0), Vector3(-22.0, 38.0, -26.0), COR_PEDRA, 0.4)
	var topo := 90.0
	_caixa(raiz, Vector3(14.0, 9.0, 24.0), Vector3(0.0, topo + 4.5, 0.0), COR_PAREDE)
	_telhado(raiz, Vector3(15.0, 5.0, 25.0), Vector3(0.0, topo + 11.5, 0.0), COR_TELHA)
	# A torre fica na frente (-Z), onde a fachada encara a avenida.
	_caixa(raiz, Vector3(6.0, 17.0, 6.0), Vector3(0.0, topo + 8.5, -9.0), COR_PAREDE)
	_telhado(raiz, Vector3(7.0, 5.0, 7.0), Vector3(0.0, topo + 19.5, -9.0), COR_TELHA)


## A roda-gigante de frente: o aro encara quem vem pela reta.
static func _roda_gigante(raiz: Node3D) -> void:
	var raio := 34.0
	var cubo := Vector3(0.0, raio + 7.0, 0.0)
	_plinto(raiz, Vector3(70.0, 4.0, 40.0), COR_PEDRA)
	# O toro nasce deitado (eixo Y); em pe, o eixo vai para Z.
	var aro := TorusMesh.new()
	aro.inner_radius = raio - 1.4
	aro.outer_radius = raio + 1.4
	aro.rings = 28
	aro.ring_segments = 5
	var mi := _malha(raiz, aro, cubo, COR_PAREDE)
	mi.rotation.x = PI * 0.5
	for i in 6:
		var raio_a := _caixa(raiz, Vector3(1.0, raio * 2.0, 1.0), cubo, COR_PAREDE)
		raio_a.rotation.z = PI / 6.0 * float(i)
	for i in 12:
		var ang := TAU / 12.0 * float(i)
		var cor := COR_VIDRO if i % 2 == 0 else COR_TELHA
		_caixa(raiz, Vector3(5.0, 5.0, 5.0), cubo + Vector3(cos(ang), sin(ang), 0.0) * raio, cor)
	for lado: float in [-1.0, 1.0]:
		var perna := _caixa(
			raiz,
			Vector3(2.0, cubo.y + 4.0, 2.0),
			Vector3(cubo.x + lado * 7.0, cubo.y * 0.5, 0.0),
			COR_ESCURO
		)
		perna.rotation.z = -lado * atan2(14.0, cubo.y)
	_caixa(raiz, Vector3(3.0, 3.0, 4.0), cubo, COR_ESCURO)


## O prédio baixo do museu: bloco branco, laje comprida que avanca sobre ele e
## uma nadadeira alta - o que o diferencia de um galpao a 300 m.
static func _museu(raiz: Node3D) -> void:
	_plinto(raiz, Vector3(110.0, 3.0, 60.0), COR_PEDRA)
	_caixa(raiz, Vector3(72.0, 10.0, 26.0), Vector3(0.0, 5.0, 0.0), COR_PAREDE)
	_caixa(raiz, Vector3(70.0, 3.0, 5.0), Vector3(0.0, 7.0, -14.0), COR_VIDRO)
	_caixa(raiz, Vector3(94.0, 2.5, 34.0), Vector3(4.0, 11.5, 0.0), COR_PAREDE, 0.0)
	var nadadeira := _caixa(raiz, Vector3(3.0, 30.0, 34.0), Vector3(-22.0, 22.0, 0.0), COR_PAREDE)
	nadadeira.rotation.z = -0.18
	_caixa(raiz, Vector3(2.5, 22.0, 30.0), Vector3(-6.0, 18.0, 0.0), COR_PAREDE).rotation.z = 0.12


## A torre de igreja com a nave baixa colada (`01_centro`).
static func _torre_de_igreja(raiz: Node3D) -> void:
	_plinto(raiz, Vector3(60.0, 3.0, 60.0), COR_PEDRA)
	_caixa(raiz, Vector3(22.0, 17.0, 34.0), Vector3(8.0, 8.5, 6.0), COR_PAREDE)
	_telhado(raiz, Vector3(23.0, 7.0, 35.0), Vector3(8.0, 20.5, 6.0), COR_TELHA)
	_caixa(raiz, Vector3(10.0, 44.0, 10.0), Vector3(-6.0, 22.0, -8.0), COR_PAREDE)
	_caixa(raiz, Vector3(8.0, 7.0, 8.0), Vector3(-6.0, 47.5, -8.0), COR_PAREDE)
	# Os vaos do sino, na face da frente.
	_caixa(raiz, Vector3(3.0, 4.5, 0.4), Vector3(-6.0, 47.5, -12.1), COR_ESCURO)
	_cone(raiz, 0.5, 6.5, 12.0, Vector3(-6.0, 57.0, -8.0), COR_TELHA, 4)


## --- Primitivas -----------------------------------------------------------


## Uma caixa; `torto` inclina a face (em radianos) para a pedra nao sair um
## bloco liso.
static func _caixa(
	raiz: Node3D, tamanho: Vector3, pos: Vector3, cor: Color, torto: float = 0.0
) -> MeshInstance3D:
	var caixa := BoxMesh.new()
	caixa.size = tamanho
	var mi := _malha(raiz, caixa, pos, cor)
	mi.rotation.y = torto
	return mi


## Um tronco de cone de `lados` faces: o morro e a ponta do campanario.
static func _cone(
	raiz: Node3D,
	raio_topo: float,
	raio_base: float,
	altura: float,
	pos: Vector3,
	cor: Color,
	lados: int = 9
) -> MeshInstance3D:
	var cone := CylinderMesh.new()
	cone.top_radius = raio_topo
	cone.bottom_radius = raio_base
	cone.height = altura
	cone.radial_segments = lados
	cone.rings = 1
	return _malha(raiz, cone, pos, cor)


## O telhado de duas aguas: um prisma com a cumeeira ao longo de Z.
static func _telhado(raiz: Node3D, tamanho: Vector3, pos: Vector3, cor: Color) -> MeshInstance3D:
	var prisma := PrismMesh.new()
	prisma.size = tamanho
	return _malha(raiz, prisma, pos, cor)


## O terreno de baixo: uma laje que desce `PE` metros, para a peca nunca
## flutuar sobre o fim da reta.
static func _plinto(raiz: Node3D, tamanho: Vector3, cor: Color) -> void:
	_caixa(
		raiz,
		Vector3(tamanho.x, tamanho.y + PE, tamanho.z),
		Vector3(0.0, (tamanho.y - PE) * 0.5, 0.0),
		cor
	)


static func _malha(raiz: Node3D, malha: Mesh, pos: Vector3, cor: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = malha
	mi.position = pos
	mi.material_override = _material(cor)
	# A 300 m a sombra de um marco nao se ve, e a sombra do sol so alcanca 250.
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	raiz.add_child(mi)
	return mi


static func _material(cor: Color) -> StandardMaterial3D:
	if not _materiais.has(cor):
		var mat := RoadTrack.material_liso(cor.lerp(AR, ENEVOADO))
		# A neblina do mundo (0,0045) a 250 m ja cobre 67% e leva a peca para
		# a cor do horizonte: sem contraste nenhum com o ceu. O ar entre a
		# camera e o marco, aqui, e o `ENEVOADO` na propria cor; a luz da hora
		# continua valendo, e de noite ele escurece junto com o resto.
		mat.disable_fog = true
		_materiais[cor] = mat
	return _materiais[cor]
