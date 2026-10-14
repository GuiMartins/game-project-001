class_name Multidao
extends MultiMeshInstance3D
## A gente de uma pose do `Pedestres`, num `MultiMesh`: o relogio dela e o
## atropelo.
##
## O relogio mora aqui, e nao no `TIME` do shader: com o mundo pausado, ou
## congelado na prova, ele para junto.
##
## O atropelo e de quem esta desenhado. A moto que passa a menos de `RAIO` de
## uma pessoa a apaga do `MultiMesh` e poe no lugar dela uma `Pessoa`
## articulada, que voa. Para saber onde cada um esta, a conta do shader e
## refeita aqui (`lugar`), com os mesmos dois sorteios por pessoa - que por
## isso saem daqui, pelo `INSTANCE_CUSTOM`, e nao de um hash no shader: o seno
## da GPU nao bate com o da CPU, e a moto atropelaria o vazio do lado.

## O trecho, a virada e a velocidade de quem anda: tem de bater com o
## `pedestres.gdshader`.
const TRECHO: float = 9.8
const VIRA: float = 0.8
const VELOCIDADE := Vector2(1.1, 1.6)
## Distancia, no chao, do centro da moto ao da pessoa para contar atropelo: a
## meia largura da moto (0,375) mais a de um ombro.
const RAIO: float = 0.55
## Abaixo disso a moto encosta, e nao atropela.
const MOTO_MINIMA: float = 2.0
## Lado da celula da grade que acha quem esta perto da moto, em metros. Maior
## que o meio trecho mais o raio: quem esta a ate uma celula de distancia e
## tudo o que precisa ser olhado.
const CELULA: float = 8.0
## Corpos no chao ao mesmo tempo; o mais velho some quando passa disto.
const MAX_CORPOS: int = 30

## Poses por segundo, repassada pelo `World` de `WorldTuning.ator_cadencia`.
var cadencia: float = 0.0:
	set(valor):
		cadencia = valor
		set_instance_shader_parameter(&"cadencia", valor)

var _andando: bool = false
var _tempo: float = 0.0
var _base: Array[Transform3D] = []
var _camisas: Array[Color] = []
var _sorteios: Array[Vector2] = []
var _caidos: Dictionary[int, bool] = {}
var _grade: Dictionary[Vector2i, PackedInt32Array] = {}
var _motos: Dictionary[int, Vector3] = {}
var _corpos: Array[Pessoa] = []


## `gente` e o que o `Pedestres.posicoes` devolve para esta pose.
func montar(gente: Array, andando: bool) -> void:
	_andando = andando
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = Pedestres.malha()
	mm.instance_count = gente.size()
	for i in gente.size():
		var t: Transform3D = gente[i][0]
		var camisa: Color = gente[i][1]
		var sorteio := Vector2(_sorteio(i, 1), _sorteio(i, 2))
		mm.set_instance_transform(i, t)
		mm.set_instance_color(i, camisa)
		mm.set_instance_custom_data(i, Color(sorteio.x, sorteio.y, 0.0, 0.0))
		_base.append(t)
		_camisas.append(camisa)
		_sorteios.append(sorteio)
		var celula := _celula(t.origin)
		if not _grade.has(celula):
			_grade[celula] = PackedInt32Array()
		_grade[celula].append(i)
	multimesh = mm
	set_instance_shader_parameter(&"andando", 1.0 if andando else 0.0)
	# O shader leva cada um ate meio trecho para frente ou para tras, longe do
	# transform que o `MultiMesh` usa para saber o que esta na tela.
	extra_cull_margin = 6.0
	add_to_group(Pedestres.GRUPO_NOS)
	add_to_group(&"multidao")


## De 0 a 1, estavel por pessoa e por canal: o mesmo em toda rodada.
static func _sorteio(i: int, canal: int) -> float:
	return float(hash(i * 7919 + canal * 104729) % 100000) / 100000.0


func _celula(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / CELULA), floori(p.z / CELULA))


## Quantas pessoas, e onde a `i` esta agora, no espaco deste no.
func quantos() -> int:
	return _base.size()


func lugar(i: int) -> Vector3:
	var t := _base[i]
	if not _andando:
		return t.origin
	return t * Vector3(0.0, 0.0, -deslocamento(_tempo, _sorteios[i].x, _sorteios[i].y))


## Quanto quem anda esta a frente do meio do trecho, ao longo da frente com que
## nasceu. A mesma conta do shader, com o tempo liso.
static func deslocamento(tempo: float, s1: float, s2: float) -> float:
	var vel := lerpf(VELOCIDADE.x, VELOCIDADE.y, s1)
	var ida := TRECHO / vel
	var ciclo := 2.0 * (ida + VIRA)
	var t := fposmod(tempo + s2 * ciclo, ciclo)
	var onde := 0.0
	if t < ida:
		onde = t * vel
	elif t < ida + VIRA:
		onde = TRECHO
	elif t < 2.0 * ida + VIRA:
		onde = TRECHO - (t - ida - VIRA) * vel
	return onde - TRECHO * 0.5


func caiu(i: int) -> bool:
	return _caidos.has(i)


## Volta todo mundo para a calcada: a corrida recomecou.
func reiniciar() -> void:
	for i: int in _caidos:
		multimesh.set_instance_transform(i, _base[i])
	_caidos.clear()
	for corpo in _corpos:
		if is_instance_valid(corpo):
			corpo.queue_free()
	_corpos.clear()
	_motos.clear()


# No passo de fisica, e nao no quadro: a prova roda um numero exato de
# passos, e o quadro dela tem de sair igual em toda maquina.
func _physics_process(delta: float) -> void:
	_tempo += delta
	set_instance_shader_parameter(&"tempo", _tempo)
	for no in get_tree().get_nodes_in_group(Pessoa.GRUPO_MOTOS):
		var moto := no as Node3D
		var id := moto.get_instance_id()
		var agora := to_local(moto.global_position)
		var antes: Vector3 = _motos.get(id, agora)
		_motos[id] = agora
		if delta <= 0.0:
			continue
		var v := (agora - antes) / delta
		var rapido := Vector2(v.x, v.z).length()
		if rapido < MOTO_MINIMA or rapido > Pessoa.MOTO_TETO:
			continue
		_atropela_perto(agora, global_basis * v)


func _atropela_perto(moto: Vector3, v_mundo: Vector3) -> void:
	var centro := _celula(moto)
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var celula := centro + Vector2i(dx, dz)
			if not _grade.has(celula):
				continue
			for i in _grade[celula]:
				if _caidos.has(i):
					continue
				var p := lugar(i)
				if absf(p.y - moto.y) > 1.5:
					continue
				if Vector2(p.x - moto.x, p.z - moto.z).length() < RAIO:
					atropelar(i, v_mundo)


## Tira a `i` do `MultiMesh` e poe no lugar dela quem voa.
func atropelar(i: int, v_mundo: Vector3) -> Pessoa:
	_caidos[i] = true
	var lugar_agora := lugar(i)
	# Fundo do mundo, e nao escala zero: matriz nula vira normal NaN no shader.
	var sumido := _base[i]
	sumido.origin.y -= 1000.0
	multimesh.set_instance_transform(i, sumido)
	var corpo := Pessoa.new()
	corpo.name = "Atropelado"
	add_child(corpo)
	corpo.cadencia = cadencia
	corpo.vestir(_camisas[i])
	var frente := -_base[i].basis.z
	corpo.colocar(lugar_agora, atan2(-frente.x, -frente.z))
	corpo.atropelar(v_mundo)
	_corpos.append(corpo)
	while _corpos.size() > MAX_CORPOS:
		var velho: Pessoa = _corpos.pop_front()
		if is_instance_valid(velho):
			velho.queue_free()
	return corpo
