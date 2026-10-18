class_name Pessoa
extends Node3D
## Uma pessoa da rua em pecas, posada no codigo: quem atravessa a rua
## (`Travessia`), quem desce do carro (`Carro.desembarcar`), quem pula da
## frente da moto e quem nao pulou a tempo e voa (`atropelar`).
##
## A gente da calcada e o `Pedestres`, em `MultiMesh`, porque e mais de mil, e
## so sabe andar reto. Esta e para as poucas que precisam de mais: sentar,
## levantar, virar, esperar o carro passar e pular. Mesmo modelo, em pecas
## (`Articulada`, em `arte/pedestres.py`), e o mesmo shader.
##
## Como o ator, a pose pula na `cadencia` e o lugar anda liso: a camera segue a
## moto a cada passo, e gente parada no lugar enquanto o mundo anda tremeria.

signal chegou

enum Estado { PARADA, ANDANDO, SENTADA, DESEMBARCANDO, SUSTO, VOANDO, CAIDA }

const CENA: PackedScene = preload("res://assets/pedestres/pedestres.glb")
const GRUPO_MOTOS: StringName = &"motos"
## Medidas de `arte/pedestres.py`: altura do quadril em pe, coxa e canela.
const QUADRIL: float = 0.92
const COXA: float = 0.44
const CANELA: float = 0.48
## Dois passos, e o balanco da perna: os mesmos do `pedestres.gdshader`, para
## quem desce do carro andar igual a quem ja estava na calcada.
const PASSADA: float = 1.4
const BALANCO: float = 0.35
## Quanto antes de a moto chegar a pessoa pula, em segundos, e ate que
## distancia do caminho dela ainda e susto, em metros. 0,7 s e o que da para
## ver o pulo antes de passar: a 50 m/s, a moto esta a 35 m quando ele comeca.
const SUSTO_ANTES: float = 0.7
const SUSTO_PERTO: float = 1.6
## O pulo: quanto dura no ar, quanto leva para baixo e quanto fica olhando
## depois, ainda de bracos meio erguidos, antes de voltar ao que fazia.
const SUSTO_DURA: float = 0.5
const SUSTO_PULO: float = 1.3
const SUSTO_OLHA: float = 0.5
## Moto mais rapida que isso de um passo para o outro foi teletransportada
## (largada, renascer depois do tombo), e nao vem vindo.
const MOTO_TETO: float = 120.0
## O atropelo, no chao: a moto a menos disto do centro da pessoa a pega. A meia
## largura da moto (0,375) mais a de um ombro; o mesmo do `Multidao`.
const RAIO: float = 0.55
const MOTO_MINIMA: float = 2.0
## Onde o corpo gira no ar, acima dos pes: o meio do quadril.
const PIVO := Vector3(0.0, 0.95, 0.0)
## Gravidade do voo. Mais que a de verdade de proposito: com 9,8 o corpo boia, e
## a tela de pixel le como camera lenta.
const GRAVIDADE: float = 16.0
## Quanto da velocidade da moto vai para o corpo, e o quanto ele sobe. A moto a
## 50 m/s joga a pessoa 2,3 m para cima e uns 30 m para a frente antes do
## primeiro quique: e Road Rash, e nao laudo de pericia.
const EMPURRAO: float = 0.55
const SUBIDA := Vector2(3.0, 0.11)
## Como o corpo desliza deitado depois do segundo quique, em m/s2, e de quantos
## em quantos metros deixa rastro.
const ATRITO: float = 9.0
const RASTRO: float = 0.7
## Quanto acima do chao fica o meio do corpo deitado.
const DEITADO: float = 0.12

## A fiscal tem silhueta propria, mantendo as mesmas articulacoes.
var cena_articulada: PackedScene = CENA
## Poses por segundo (`WorldTuning.ator_cadencia`, repassada pelo `World`); 0 e liso.
var cadencia: float = 12.0
var estado: Estado = Estado.PARADA
## A roupa de quem veio da calcada continua a mesma quando voa e cai.
var avatar: int = PedestreSprite.PRAIA
## Velocidade de caminhada, em m/s.
var velocidade: float = 1.4

# A pose, nos angulos que o corpo entende, e nao nos do no: o `_aplica` faz a
# conta de sinal. Coxa e braco positivos vao para a frente; joelho positivo
# leva a canela para tras; tronco positivo tomba para a frente; `_abre` afasta
# o braco do corpo.
var _altura: float = QUADRIL
var _tronco: float = 0.0
var _coxa: Array[float] = [0.0, 0.0]
var _joelho: Array[float] = [0.0, 0.0]
var _braco: Array[float] = [0.0, 0.0]
var _abre: Array[float] = [0.06, 0.06]
## Para onde olha, em radianos em volta de Y; 0 e -Z do pai.
var _rumo: float = 0.0

var _no_raiz: Node3D
var _no_quadril: Node3D
var _no_tronco: Node3D
var _nos_braco: Array[Node3D] = []
var _nos_coxa: Array[Node3D] = []
var _nos_canela: Array[Node3D] = []
var _malhas: Array[MeshInstance3D] = []
var _sprite := PedestreSprite.new()
var _em_sprite: bool = false

var _desde: float = 0.0
var _fase: float = 0.0
var _relogio: float = 0.0
var _caminho := PackedVector3Array()
## Onde cada moto estava no passo anterior, para saber para onde ela vai.
var _motos: Dictionary[int, Vector3] = {}
var _susto_de := Vector3.ZERO
var _susto_para := Vector3.ZERO
var _antes_do_susto: Estado = Estado.PARADA
var _sem_susto: float = 0.0
# O voo do atropelo, no espaco do pai: o meio do corpo, a velocidade, o eixo
# e o angulo do giro, e o giro do corpo inteiro em volta do `PIVO`.
var _centro := Vector3.ZERO
var _vel := Vector3.ZERO
var _eixo := Vector3.RIGHT
var _giro: float = 0.0
var _giro_vel: float = 0.0
var _quiques: int = 0
var _desde_rastro: float = 0.0
var _corpo := Basis.IDENTITY
var _chao_de_partida: float = 0.0
var _dica: float = -1.0
var _rng := RandomNumberGenerator.new()
## O ritmo de quem esta parado, por pessoa, para dez esperando na esquina nao
## balancarem juntas.
var _ritmo: float = 3.0

# O desembarque, no espaco do carro (`desembarcar`).
var _assento := Vector3.ZERO
var _altura_banco: float = 0.5
var _lado: float = -1.0
var _meia_largura: float = 0.9
var _fecha_em: float = 2.0
var _saida := PackedVector3Array()


func _ready() -> void:
	var cena := cena_articulada.instantiate()
	var raiz := cena.find_child("Articulada", true, false) as Node3D
	assert(raiz != null, "pedestres.glb sem o no Articulada")
	raiz.get_parent().remove_child(raiz)
	cena.free()
	raiz.transform = Transform3D.IDENTITY
	add_child(raiz)
	_no_raiz = raiz
	_no_quadril = raiz.find_child("Quadril", true, false) as Node3D
	_no_tronco = raiz.find_child("Tronco", true, false) as Node3D
	for lado: String in ["E", "D"]:
		_nos_braco.append(raiz.find_child("Braco_" + lado, true, false) as Node3D)
		_nos_coxa.append(raiz.find_child("Coxa_" + lado, true, false) as Node3D)
		_nos_canela.append(raiz.find_child("Canela_" + lado, true, false) as Node3D)
	_junta_malhas(raiz)
	for malha in _malhas:
		malha.set_instance_shader_parameter(&"articulado", 1.0)
		for s in malha.mesh.get_surface_count():
			malha.set_surface_override_material(
				s, Pedestres.material(malha.mesh.surface_get_material(s))
			)
	add_to_group(Pedestres.GRUPO_NOS)
	add_child(_sprite)
	_aplica()
	usar_sprite(_em_sprite)


func _junta_malhas(no: Node) -> void:
	if no is MeshInstance3D:
		_malhas.append(no as MeshInstance3D)
	for filho in no.get_children():
		_junta_malhas(filho)


## A roupa e a pele. `pele` com alfa 0 fica a do modelo.
func vestir(camisa: Color, pele := Color(0, 0, 0, 0)) -> void:
	for malha in _malhas:
		malha.set_instance_shader_parameter(&"camisa", camisa)
		malha.set_instance_shader_parameter(&"pele", pele)


## A mesma escolha PERSONAGENS do menu vale para quem atravessa, desembarca e cai.
func usar_sprite(ligado: bool) -> void:
	_em_sprite = ligado
	_sprite.visible = ligado
	var sombra := (
		GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		if ligado
		else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	)
	for malha in _malhas:
		malha.cast_shadow = sombra
	if ligado:
		_sprite.posar(estado, _fase, _relogio, _giro, _vel.length(), avatar)


## Sorteia o que a deixa diferente das outras: o passo e o ritmo de quem
## espera. `rng` e de quem a criou, e nada daqui e medido pelo banco de provas.
func sortear(rng: RandomNumberGenerator) -> void:
	velocidade = rng.randf_range(1.1, 1.6)
	_rng.seed = rng.randi()
	# A semente ja sorteada decide a aparencia sem mudar a sequencia de
	# pedestres, carros e obstaculos que compartilham o mesmo RNG.
	avatar = int(_rng.seed % PedestreSprite.ANDANDO.size())
	_ritmo = rng.randf_range(2.5, 4.0)
	_fase = rng.randf() * TAU


## Anda pelos `pontos`, no espaco do pai, e emite `chegou` no ultimo.
func ir(pontos: PackedVector3Array) -> void:
	_caminho = pontos.duplicate()
	if estado != Estado.SUSTO:
		estado = Estado.ANDANDO


## Para onde esta, olhando para `ponto` (no espaco do pai).
func esperar(ponto: Vector3) -> void:
	_caminho.clear()
	if estado != Estado.SUSTO:
		estado = Estado.PARADA
	var d := ponto - position
	if Vector2(d.x, d.z).length() > 0.01:
		_rumo = atan2(-d.x, -d.z)


## Ja posta em `lugar`, de pe e olhando para `rumo`.
func colocar(lugar: Vector3, rumo: float) -> void:
	position = lugar
	_rumo = rumo
	_pose_de_pe()
	_aplica()


## Pula para `destino` (no espaco do pai), de frente para de onde vem o perigo,
## e fica parada la: e quem chamou que decide o que ela faz depois.
func pular_para(destino: Vector3) -> void:
	_caminho.clear()
	_comeca_susto(destino, Estado.PARADA)


## A moto pegou: voa na direcao dela (`v_mundo`, a velocidade da moto no
## mundo), girando, quica duas vezes, desliza deitada e fica. Mancha o chao
## onde e pega, onde cai e por onde arrasta.
func atropelar(v_mundo: Vector3) -> void:
	if estado == Estado.VOANDO or estado == Estado.CAIDA:
		return
	var pai := get_parent_node_3d()
	var v := pai.global_basis.inverse() * v_mundo if pai != null else v_mundo
	v.y = 0.0
	var rapido := v.length()
	var frente := v / maxf(rapido, 0.001)
	var lado := Vector3(-frente.z, 0.0, frente.x)
	_vel = (
		v * EMPURRAO
		+ lado * rapido * 0.12 * _rng.randf_range(-1.0, 1.0)
		+ Vector3.UP * (SUBIDA.x + rapido * SUBIDA.y)
	)
	# Cambalhota para a frente, na direcao em que vai, com um fio de parafuso.
	_eixo = (Vector3.UP.cross(frente) + frente * _rng.randf_range(-0.3, 0.3)).normalized()
	_giro = 0.0
	_giro_vel = clampf(7.0 + rapido * 0.15, 7.0, 14.0)
	_quiques = 0
	_centro = position + PIVO
	_chao_de_partida = position.y
	_dica = -1.0
	_caminho.clear()
	estado = Estado.VOANDO
	_relogio = 0.0
	_mancha(_centro - PIVO, Vector2(1.0, 1.0), atan2(frente.x, frente.z))


## Sai do carro pela porta do lado `lado` (-1 esquerda, 1 direita do carro).
## Tudo no espaco do carro, que e o pai: `assento` e o quadril sentado, e a
## porta bate em `fecha_em` segundos, quando a mao dela empurra. Depois anda
## pela `saida`.
func desembarcar(
	assento: Vector3, lado: float, meia_largura: float, fecha_em: float, saida: PackedVector3Array
) -> void:
	_assento = Vector3(assento.x, 0.0, assento.z)
	_altura_banco = assento.y
	_lado = lado
	_meia_largura = meia_largura
	_fecha_em = fecha_em
	_saida = saida
	_relogio = 0.0
	estado = Estado.DESEMBARCANDO
	position = _assento
	_rumo = 0.0
	_pose_sentada()
	_aplica()


func _physics_process(delta: float) -> void:
	_relogio += delta
	_sem_susto = maxf(_sem_susto - delta, 0.0)
	_olha_motos(delta)
	match estado:
		Estado.ANDANDO:
			_anda(delta)
		Estado.PARADA:
			_fica()
		Estado.SENTADA:
			_pose_sentada()
		Estado.DESEMBARCANDO:
			_desembarca()
		Estado.SUSTO:
			_assusta()
		Estado.VOANDO:
			_voa(delta)
		Estado.CAIDA:
			_desliza(delta)
	_desde += delta
	var periodo := 1.0 / cadencia if cadencia > 0.0 else 0.0
	# A mesma folga de um milesimo da `Cadencia`: cinco passos de 1/60 somados
	# ficam um fio abaixo de 1/12.
	if _desde >= periodo - 0.001:
		_desde = clampf(_desde - periodo, 0.0, periodo)
		_aplica()


func _anda(delta: float) -> void:
	var passo := velocidade * delta
	while not _caminho.is_empty():
		var falta := _caminho[0] - position
		if Vector2(falta.x, falta.z).length() > 0.01:
			_rumo = rotate_toward(_rumo, atan2(-falta.x, -falta.z), 8.0 * delta)
		if falta.length() > passo:
			position += falta.normalized() * passo
			break
		position = _caminho[0]
		passo -= falta.length()
		_caminho.remove_at(0)
	_fase = fmod(_fase + velocidade * delta / PASSADA * TAU, TAU)
	_pose_andando()
	if _caminho.is_empty():
		estado = Estado.PARADA
		chegou.emit()


func _fica() -> void:
	_pose_de_pe()
	# O peso de um pe para o outro, como a gente parada do `MultiMesh`.
	var peso := sin(TAU * _relogio / _ritmo)
	_coxa[0] = 0.04 * peso
	_coxa[1] = -0.04 * peso
	_tronco = 0.02 * peso


func _pose_de_pe() -> void:
	_altura = QUADRIL
	_tronco = 0.0
	for i in 2:
		_coxa[i] = 0.0
		_joelho[i] = 0.0
		_braco[i] = 0.0
		_abre[i] = 0.06


## A fiscal usa o corpo articulado porque o atlas de caminhada nao tem sinal
## de largada. Quem dirige a sequencia fornece o mesmo relogio da contagem.
func sinalizar_largada(segundos: float) -> void:
	usar_sprite(false)
	_pose_de_pe()
	# Tres frases de um segundo: um braco, o outro, os dois descendo.
	# O arco lateral e o contrapeso do tronco fazem o gesto fluir pelo corpo.
	var t := clampf(segundos, 0.0, 3.0)
	var primeiro := smoothstep(0.08, 0.85, t)
	var segundo := smoothstep(1.08, 1.85, t)
	var baixa := smoothstep(2.15, 3.0, t)
	_braco[1] = 2.8 * primeiro * (1.0 - baixa)
	_braco[0] = 2.8 * segundo * (1.0 - baixa)
	_abre[1] = 0.12 + 0.65 * sin(PI * primeiro) + 0.7 * sin(PI * baixa)
	_abre[0] = 0.12 + 0.65 * sin(PI * segundo) + 0.7 * sin(PI * baixa)
	var peso := 0.10 * sin(TAU * t / 3.0)
	_coxa[0] = 0.10 * primeiro * (1.0 - baixa)
	_joelho[0] = 0.20 * primeiro * (1.0 - baixa)
	_tronco = -0.06 * (primeiro + segundo) + 0.22 * sin(PI * baixa)
	_corpo = Basis.IDENTITY
	_aplica()
	_no_quadril.position.x = peso
	_no_tronco.rotation.z = -peso * 0.65
	_no_tronco.rotation.y = 0.10 * sin(PI * t)


func _pose_andando(para_tras: bool = false) -> void:
	var f0 := -_fase if para_tras else _fase
	for i in 2:
		var f := f0 + PI * float(i)
		_coxa[i] = BALANCO * sin(f)
		# O joelho dobra na perna que vem para a frente, e estica na que apoia.
		_joelho[i] = 0.6 * maxf(cos(f), 0.0)
		_braco[i] = -0.8 * BALANCO * sin(f)
		_abre[i] = 0.06
	# O quadril desce um fio com as pernas abertas: sem isso o boneco desliza.
	_altura = QUADRIL - 0.03 * absf(sin(_fase))
	_tronco = 0.05


func _pose_sentada() -> void:
	_altura = _altura_banco
	# Encostado no banco, coxa deitada e canela em pe: o pe fica no assoalho.
	_tronco = -0.12
	for i in 2:
		_coxa[i] = 1.5
		_joelho[i] = 1.5
		_braco[i] = 0.7
		_abre[i] = 0.1


## A coreografia de sair do carro, em fases, todas contadas do comeco. A porta
## leva uns 0,3 s para abrir; o resto se espreme para a mao chegar na porta
## quando o `TrafficCar` a fecha, e com porta de 2 s fica tudo um quarto mais
## rapido do que com a de 4.
func _desembarca() -> void:
	var t := _relogio
	var k := clampf((_fecha_em - 0.9) / 1.45, 0.6, 1.0)
	var t0 := 0.35 * k
	var t1 := 0.85 * k
	var t2 := 1.45 * k
	var t3 := _fecha_em - 0.35
	var t4 := _fecha_em
	var t5 := _fecha_em + 0.35
	# A frente do carro e -Z. O braco que fica do lado da frente, de quem olha
	# para fora, e o que segura na coluna para levantar; o de fora e o que
	# empurra a porta.
	var frente := 1 if _lado < 0.0 else 0
	var fora := 0 if _lado < 0.0 else 1
	var para_fora := -_lado * PI * 0.5
	var no_banco := Vector3(_lado * (_meia_largura + 0.12 - COXA), 0.0, _assento.z)
	var de_pe := Vector3(_lado * (_meia_largura + 0.12), 0.0, _assento.z)
	var recuado := Vector3(_lado * (_meia_largura + 0.35), 0.0, _assento.z + 0.75)
	var olha_porta := -_lado * 0.4
	if t < t0:
		_pose_sentada()
	elif t < t1:
		# Gira no banco e poe as pernas para fora.
		var s := smoothstep(t0, t1, t)
		position = _assento.lerp(no_banco, s)
		_rumo = lerpf(0.0, para_fora, s)
		_pose_sentada()
		_braco[frente] = lerpf(0.7, 1.6, s)
	elif t < t2:
		# Levanta: o pe fica, o quadril vem por cima dele, o tronco tomba para a
		# frente no meio do caminho e a mao da frente puxa na coluna.
		var s := smoothstep(t1, t2, t)
		position = no_banco.lerp(de_pe, s)
		_rumo = para_fora
		_altura = lerpf(_altura_banco, QUADRIL, s)
		_tronco = lerpf(-0.12, 0.0, s) + 0.55 * sin(PI * s)
		for i in 2:
			_coxa[i] = lerpf(1.5, 0.0, s)
			_joelho[i] = lerpf(1.5, 0.0, s)
			_braco[i] = lerpf(0.7, 0.0, s)
			_abre[i] = lerpf(0.1, 0.06, s)
		_braco[frente] = lerpf(1.6, 0.0, s * s) + 0.8 * sin(PI * s)
	elif t < t3:
		# Dois passos para tras, ainda de frente para a porta, virando para ela.
		var s := smoothstep(t2, t3, t)
		var antes := position
		position = de_pe.lerp(recuado, s)
		_rumo = lerp_angle(para_fora, olha_porta, s)
		_fase = fmod(_fase + antes.distance_to(position) / PASSADA * TAU, TAU)
		_pose_andando(true)
	elif t < t5:
		# Empurra a porta: o braco de fora vai a frente e o tronco acompanha.
		var s := clampf((t - t3) / (t4 - t3), 0.0, 1.0)
		var volta := clampf((t - t4) / (t5 - t4), 0.0, 1.0)
		position = recuado
		_rumo = olha_porta
		_pose_de_pe()
		_braco[fora] = 1.4 * sin(PI * 0.5 * s) * (1.0 - volta)
		_tronco = 0.15 * sin(PI * 0.5 * s) * (1.0 - volta)
	else:
		ir(_saida)


func _olha_motos(delta: float) -> void:
	var podendo := estado in [Estado.PARADA, Estado.ANDANDO] and _sem_susto <= 0.0 and delta > 0.0
	# Pega quem esta de pe em qualquer coisa - parado, andando, no meio do
	# pulo, descendo do carro ja com o pe no chao -, e nao quem esta sentado
	# dentro dele nem quem ja voou.
	var pegavel := (
		delta > 0.0
		and estado not in [Estado.SENTADA, Estado.VOANDO, Estado.CAIDA]
		and not (estado == Estado.DESEMBARCANDO and _relogio < 1.0)
	)
	for no in get_tree().get_nodes_in_group(GRUPO_MOTOS):
		var moto := no as Node3D
		var id := moto.get_instance_id()
		var agora := moto.global_position
		var antes: Vector3 = _motos.get(id, agora)
		_motos[id] = agora
		if not pegavel:
			continue
		var v := (agora - antes) / delta
		v.y = 0.0
		var rapido := v.length()
		if rapido < MOTO_MINIMA or rapido > MOTO_TETO:
			continue
		var rel := global_position - agora
		var alto := absf(rel.y)
		rel.y = 0.0
		if rel.length() < RAIO and alto < 1.5:
			atropelar(v)
			return
		if not podendo or rapido < 3.0:
			continue
		var quando := rel.dot(v) / (rapido * rapido)
		if quando <= 0.0 or quando > SUSTO_ANTES:
			continue
		var fora := rel - v * quando
		if fora.length() > SUSTO_PERTO:
			continue
		# Para o lado de onde ja esta, para fora do caminho dela; quem esta
		# bem na frente pula para a direita de quem vem.
		var lado := Vector3(-v.z, 0.0, v.x).normalized()
		if fora.length() > 0.2 and lado.dot(fora) < 0.0:
			lado = -lado
		var no_pai := get_parent_node_3d().global_basis.inverse() * lado
		no_pai.y = 0.0
		_comeca_susto(position + no_pai.normalized() * SUSTO_PULO, estado)
		return


func _comeca_susto(destino: Vector3, depois: Estado) -> void:
	_susto_de = position
	_susto_para = destino
	_antes_do_susto = depois
	_relogio = 0.0
	estado = Estado.SUSTO
	# De frente para o perigo, pulando de costas.
	var d := destino - position
	if Vector2(d.x, d.z).length() > 0.01:
		_rumo = atan2(d.x, d.z)


func _assusta() -> void:
	var t := _relogio
	var s := clampf(t / SUSTO_DURA, 0.0, 1.0)
	var arco := sin(PI * s)
	position = _susto_de.lerp(_susto_para, smoothstep(0.0, 1.0, s)) + Vector3.UP * 0.3 * arco
	# Bracos para cima e para a frente, como quem se protege, e as pernas
	# encolhidas no ar.
	var bracos := 1.8 * arco if t < SUSTO_DURA else 0.9 * (1.0 - (t - SUSTO_DURA) / SUSTO_OLHA)
	_altura = QUADRIL - 0.12 * arco
	_tronco = -0.25 * arco
	for i in 2:
		_coxa[i] = 0.7 * arco
		_joelho[i] = 1.2 * arco
		_braco[i] = maxf(bracos, 0.0)
		_abre[i] = 0.06 + 0.4 * arco
	if t >= SUSTO_DURA + SUSTO_OLHA:
		position = _susto_para
		_sem_susto = 1.0
		_pose_de_pe()
		estado = Estado.ANDANDO if _antes_do_susto == Estado.ANDANDO else Estado.PARADA
		if estado == Estado.ANDANDO and _caminho.is_empty():
			estado = Estado.PARADA


func _voa(delta: float) -> void:
	_vel.y -= GRAVIDADE * delta
	_centro += _vel * delta
	_giro += _giro_vel * delta
	position = _centro - PIVO
	var eixo_local := Basis(Vector3.UP, _rumo).inverse() * _eixo
	_corpo = Basis(eixo_local.normalized(), _giro)
	# Bracos e pernas soltos, sacudindo.
	var t := _relogio
	_altura = QUADRIL
	_tronco = -0.2
	for i in 2:
		var f := PI * float(i)
		_braco[i] = 1.8 + 0.8 * sin(t * 13.0 + f)
		_abre[i] = 1.0 + 0.3 * sin(t * 9.0 + f)
		_coxa[i] = 0.6 * sin(t * 11.0 + f)
		_joelho[i] = 0.7 + 0.4 * sin(t * 7.0 + f)
	var chao := _chao(_centro)
	if _vel.y < 0.0 and _centro.y - 0.3 <= chao:
		_quiques += 1
		var plano := Vector2(_vel.x, _vel.z)
		_mancha(Vector3(_centro.x, chao, _centro.z), Vector2(1.2, 1.4), atan2(plano.x, plano.y))
		if _quiques < 2:
			_centro.y = chao + 0.3
			_vel.y = -_vel.y * 0.3
			_vel.x *= 0.55
			_vel.z *= 0.55
			_giro_vel *= 0.5
		else:
			# Deita, de brucos e com a cabeca para onde ia, e desliza.
			_vel.y = 0.0
			_vel.x *= 0.6
			_vel.z *= 0.6
			if plano.length() > 0.01:
				_rumo = atan2(-plano.x, -plano.y)
			_corpo = Basis(Vector3.RIGHT, -PI * 0.5)
			_centro.y = chao + DEITADO
			position = _centro - PIVO
			_desde_rastro = 0.0
			estado = Estado.CAIDA
			_pose_deitada()


func _desliza(delta: float) -> void:
	var plano := Vector2(_vel.x, _vel.z)
	var rapido := plano.length()
	if rapido <= 0.0:
		return
	var passo := minf(rapido * delta, rapido * rapido / (2.0 * ATRITO))
	var novo := maxf(rapido - ATRITO * delta, 0.0)
	var rumo := Vector3(plano.x, 0.0, plano.y) / rapido
	_centro += rumo * passo
	_centro.y = _chao(_centro) + DEITADO
	_vel = rumo * novo
	position = _centro - PIVO
	_desde_rastro += passo
	var no_chao := Vector3(_centro.x, _centro.y - DEITADO, _centro.z)
	if _desde_rastro >= RASTRO:
		_desde_rastro = 0.0
		_mancha(no_chao, Vector2(0.5, 0.9), atan2(plano.x, plano.y))
	if novo <= 0.0:
		# A poca de onde parou.
		_mancha(no_chao, Vector2(1.5, 1.5), atan2(plano.x, plano.y))


func _pose_deitada() -> void:
	_altura = QUADRIL
	_tronco = 0.0
	_braco = [0.4, -0.3]
	_abre = [1.1, 0.6]
	_coxa = [0.25, -0.1]
	_joelho = [0.4, 0.1]


## A altura do chao sob `p` (espaco do pai). Sai da pista, que nao tem
## colisor: e a mesma amostragem da moto. Sem pista (num teste), e o chao de
## onde voou.
func _chao(p: Vector3) -> float:
	var pista := get_tree().get_first_node_in_group(RoadTrack.GRUPO) as RoadTrack
	var pai := get_parent_node_3d()
	if pista == null or pai == null:
		return _chao_de_partida
	var no_mundo := pai.to_global(p)
	var na_pista := pista.to_local(no_mundo)
	if _dica < 0.0:
		_dica = pista.curve.get_closest_offset(na_pista)
	_dica = pista.project(na_pista, _dica).x
	var chao := pista.to_global(pista.sample_position(_dica))
	return pai.to_local(Vector3(no_mundo.x, chao.y, no_mundo.z)).y


## Mancha em `onde` (espaco do pai); `rumo` e o do comprimento, no pai.
func _mancha(onde: Vector3, tamanho: Vector2, rumo: float) -> void:
	var pai := get_parent_node_3d()
	var no_mundo := pai.to_global(onde) if pai != null else onde
	var giro := rumo + (pai.global_rotation.y if pai != null else 0.0)
	Sangue.manchar(get_tree(), no_mundo, tamanho, giro)


## Passa a pose para os nos. So na vez da cadencia: entre uma e outra, o boneco
## segura a pose e so o lugar anda.
func _aplica() -> void:
	if _no_quadril == null:
		return
	rotation = Vector3(0.0, _rumo, 0.0)
	_no_raiz.transform = Transform3D(_corpo, PIVO - _corpo * PIVO)
	_no_quadril.position = Vector3(0.0, _altura, 0.0)
	_no_tronco.rotation = Vector3(-_tronco, 0.0, 0.0)
	for i in 2:
		var lado := -1.0 if i == 0 else 1.0
		_nos_coxa[i].rotation = Vector3(_coxa[i], 0.0, 0.0)
		_nos_canela[i].rotation = Vector3(-_joelho[i], 0.0, 0.0)
		_nos_braco[i].rotation = Vector3(_braco[i], 0.0, _abre[i] * lado)
	_sprite.posar(estado, _fase, _relogio, _giro, _vel.length(), avatar)
