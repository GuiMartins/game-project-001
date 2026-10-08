class_name Cidade
extends RefCounted
## O que fica dos dois lados da avenida: predio colado em predio, e as ruas que
## a cruzam, com semaforo e a fila parada no vermelho.
##
## Nada aqui anda, mas tudo bate: predio, semaforo e carro parado tem colisor
## na camada do mundo, e a moto que sai da avenida acha eles pela frente. Serve
## ao olho, ao referencial de velocidade - a fachada passando do lado - e a
## saida pela calcada, que tem preco.

## A rua que cruza a avenida: duas maos de 3,3 m mais a sarjeta. A calcada dela
## e o recuo dos predios de cada lado da esquina.
const RUA_LARGURA: float = 8.0
const RUA_CALCADA: float = 2.0
## Do asfalto da avenida ate o fim do chao (`RoadTrack.GROUND`, mais o
## acostamento): rua que acaba antes dele e um tapete de asfalto na calcada.
const RUA_COMPRIMENTO: float = 36.0
## De que lado da avenida a rua abre. O sinal e o mesmo do `side` da colocacao.
const LADO_ESQUERDA: float = -1.0
const LADO_DIREITA: float = 1.0
const LADO_AMBOS: float = 0.0
## Da beira da calcada andavel ate a fachada, em metros: a faixa de servico e o
## resto da calcada. E o espaco onde vai morar poste, arvore e gente.
const RECUO_FACHADA: float = 6.0

var track: RoadTrack


func _init(a_track: RoadTrack) -> void:
	track = a_track


## Monta tudo em `props`. `rua` e o gerador so da cidade: nada que sai dele
## mexe no transito nem nos rivais.
func montar(rua: RandomNumberGenerator, props: Node3D) -> void:
	var cruzamentos := _sorteia_cruzamentos(rua)
	_monta_ruas(cruzamentos, rua, props)
	for side: float in [-1.0, 1.0]:
		_monta_quarteirao(side, cruzamentos, rua, props)


## Onde a avenida e cruzada. Cada um e `[offset, lados]`, com `lados` em
## `LADO_*`: cruzamento de verdade abre os dois lados; rua que so chega de um
## lado e o "T" de bairro.
##
## Entre 70 e 160 m: e o quarteirao do Centro e da Zona Norte. Mais perto que
## isso o corredor de predios nunca fecha, e e o corredor fechado que da a
## velocidade; mais longe e avenida de beira de estrada, sem rua nenhuma.
func _sorteia_cruzamentos(rua: RandomNumberGenerator) -> Array[Vector2]:
	var lista: Array[Vector2] = []
	var o := rua.randf_range(70.0, 130.0)
	while o < track.length - RUA_LARGURA:
		var sorteio := rua.randf()
		var lados := LADO_AMBOS
		if sorteio < 0.25:
			lados = LADO_ESQUERDA
		elif sorteio < 0.5:
			lados = LADO_DIREITA
		lista.append(Vector2(o, lados))
		o += rua.randf_range(70.0, 160.0)
	return lista


static func _abre(lados: float, side: float) -> bool:
	return lados == LADO_AMBOS or lados == side


## Predio colado em predio, de um lado da avenida, parando so nas ruas.
##
## Nenhuma avenida de cidade tem 15 m de vazio entre um predio e o outro: o
## buraco e o que fazia a rua parecer cenario. O vao que sobra e o da junta
## entre duas obras, ate meio metro - o bastante para a fachada nao parecer
## uma parede so, pouco para o ceu aparecer no nivel da rua.
func _monta_quarteirao(
	side: float, cruzamentos: Array[Vector2], rua: RandomNumberGenerator, props: Node3D
) -> void:
	var edge := RoadTrack.half_width() + RoadTrack.SHOULDER
	var vaos: Array[Vector2] = []
	for c in cruzamentos:
		if _abre(c.y, side):
			var meio := RUA_LARGURA * 0.5 + RUA_CALCADA
			vaos.append(Vector2(c.x - meio, c.x + meio))

	var o := 12.0
	while o < track.length - 10.0:
		var h := rua.randf_range(6.0, 26.0)
		var tipo := _tipo_de_predio(h)
		var caixa := Predio.malha(tipo).get_aabb()
		var lateral := (edge + RECUO_FACHADA + Predio.frente(tipo)) * side
		# Na curva, o metro de pista no eixo nao e o metro na fachada: por
		# fora ele estica, por dentro encolhe. A largura do predio e medida
		# onde ele esta, senao abre buraco por fora e encavala por dentro.
		var escala := track.point(o, lateral).distance_to(track.point(o + 1.0, lateral))
		var passo := caixa.size.x / maxf(escala, 0.2)
		var pulou := false
		for vao in vaos:
			if o < vao.y and o + passo > vao.x:
				o = vao.y
				pulou = true
				break
		if pulou:
			continue
		# A fachada (-Z) olha para a pista, e a ponta dela fica no recuo.
		var base := track.transform_at(o + passo * 0.5, lateral)
		_predio(props, rua, tipo, base.origin, base.basis.x * -side)
		o += passo + rua.randf_range(0.0, 0.5)


## Um predio com o pe em `pe`, a fachada olhando para `olha`, e o colisor dele.
##
## O colisor e a caixa do corpo, sem o que a fachada avanca: toldo, sacada e
## marquise ficam acima da cabeca, e bater num toldo a 3 m do chao seria parede
## invisivel. Os fundos sao parede lisa no `+Z` da planta, e a origem e o
## centro dela - entao a frente do corpo esta no espelho dos fundos.
func _predio(
	props: Node3D, rua: RandomNumberGenerator, tipo: Predio.Tipo, pe: Vector3, olha: Vector3
) -> void:
	var predio := Predio.criar(tipo, rua.randf(), rua.randf())
	props.add_child(predio)
	# Base 1 m abaixo da pista: na rampa o predio nao pode ficar com o pe no ar.
	predio.global_transform = Transform3D(Basis.looking_at(olha, Vector3.UP), pe + Vector3.DOWN)
	var caixa := Predio.malha(tipo).get_aabb()
	var fundo := caixa.end.z
	_colisor(
		predio,
		AABB(
			Vector3(caixa.position.x, 0.0, -fundo), Vector3(caixa.size.x, caixa.size.y, fundo * 2.0)
		)
	)


## Caixa estatica na camada do mundo, em `caixa` no espaco de `dono`.
static func _colisor(dono: Node3D, caixa: AABB) -> void:
	var corpo := StaticBody3D.new()
	corpo.collision_layer = Layers.WORLD
	corpo.collision_mask = 0
	var forma := BoxShape3D.new()
	forma.size = caixa.size
	var cs := CollisionShape3D.new()
	cs.shape = forma
	cs.position = caixa.get_center()
	corpo.add_child(cs)
	dono.add_child(corpo)


## O asfalto, a pintura, o semaforo e a fila de cada rua que cruza a avenida.
##
## O asfalto e a pintura de todas as ruas sao uma malha so, com duas
## superficies: dezenas de ruas viram duas chamadas de desenho.
func _monta_ruas(cruzamentos: Array[Vector2], rua: RandomNumberGenerator, props: Node3D) -> void:
	var road_w := RoadTrack.half_width()
	# Onde acaba o andavel: dali para fora fica o que a moto nao alcanca.
	var calcada := RoadTrack.SHOULDER
	var asfalto := SurfaceTool.new()
	asfalto.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tinta := SurfaceTool.new()
	tinta.begin(Mesh.PRIMITIVE_TRIANGLES)
	var materiais := _materiais_de_semaforo()

	for c in cruzamentos:
		for side: float in [-1.0, 1.0]:
			if not _abre(c.y, side):
				continue
			# Base da rua na beira do asfalto da avenida: a rua corta a calcada.
			# `d` aponta para fora, ao longo da rua; `r` e a direita de quem vem
			# pela rua chegando na avenida - aqui se anda pela direita.
			var meio := RUA_LARGURA * 0.5
			var perto_a := track.point(c.x - meio, road_w * side)
			var perto_b := track.point(c.x + meio, road_w * side)
			var centro := (perto_a + perto_b) * 0.5
			var d := track.sample_basis(c.x).x * side
			d.y = 0.0
			d = d.normalized()
			var r := (-d).cross(Vector3.UP)
			# A calcada esta na altura da pista e a rua passa por cima dela, 6 cm
			# acima: acima tambem do meio-fio e da faixa de servico, que ela corta,
			# e o bastante para nao brigar com eles no depth buffer.
			var acima := Vector3.UP * 0.06
			_retangulo(
				asfalto,
				perto_a + acima,
				perto_b + acima,
				d,
				RUA_COMPRIMENTO,
				Vector2(
					RUA_LARGURA / RoadTrack.LANE_WIDTH, RUA_COMPRIMENTO / RoadTrack.ASFALTO_TILE
				)
			)
			var chao := centro + acima + Vector3.UP * 0.03
			# Faixa de pedestre na linha da calcada, e a linha de retencao logo
			# atras dela, so na mao de quem chega. Listra de 0,5 m com periodo de
			# 1 m: ela corre ao longo da rua, de lado para a moto, e de lado nao
			# pisca (a regra do `arte/chao.py` e para o que se atravessa).
			var listra := -meio + 0.4
			while listra < meio - 0.4:
				var p := chao + r * (listra + 0.25) + d * (calcada + 0.4)
				_faixa(tinta, p, d, r, 0.5, 3.0)
				listra += 1.0
			_faixa(tinta, chao + d * (calcada + 4.0), r, d, 0.4, meio)
			# O fundo da rua e a fachada de um predio da quadra de tras, olhando
			# para a avenida: rua que acaba no vazio mostra a borda do mundo, e
			# predio no fundo e o "T" que toda rua de bairro tem.
			var tipo := _tipo_de_predio(rua.randf_range(6.0, 23.0))
			var pe := centro + d * (RUA_COMPRIMENTO - 2.0 + Predio.frente(tipo))
			_predio(props, rua, tipo, pe, -d)
			# Tracejado do meio da rua.
			var t := calcada + 5.0
			while t < RUA_COMPRIMENTO - 3.0:
				_faixa(tinta, chao + d * t, d, r, 0.14, 2.0)
				t += 4.5

			# Metade das ruas chega na avenida e metade sai dela. Quem chega
			# para no vermelho - a avenida esta no verde, e e o jogador que
			# passa. Rua de saida nao tem semaforo nem fila: ninguem espera
			# para sair da avenida.
			if rua.randf() < 0.5:
				continue
			# Na faixa de servico, alinhado com os postes: no andavel a moto
			# atravessaria o poste, que nao tem colisor.
			var esquina := centro + acima + d * (calcada + 0.8) + r * (meio + 0.9)
			_semaforo(props, materiais, esquina, d, track.sample_basis(c.x).z)
			var fila := calcada + 4.8
			for _i in rua.randi_range(1, 3):
				fila = _carro_parado(props, rua, centro + acima + r * meio * 0.5, d, fila)

	var malha := ArrayMesh.new()
	asfalto.commit(malha)
	malha.surface_set_material(0, RoadTrack.material_texturizado(RoadTrack.ASFALTO))
	tinta.commit(malha)
	malha.surface_set_material(1, RoadTrack.material_liso(Color(0.88, 0.86, 0.68)))
	var ruas := MeshInstance3D.new()
	ruas.name = "Ruas"
	ruas.mesh = malha
	ruas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	props.add_child(ruas)


## Um carro esperando o verde, `fila` metros adiante do asfalto da avenida,
## na mao de quem chega. Devolve onde comeca o espaco do proximo da fila.
##
## E so o `Carro`, sem `TrafficCar`: nao anda e nao entra no transito. Tem
## colisor, da lataria, porque a moto que entra na rua bate nele. Uma pose so,
## parado e sem encostar, e o que acende a lanterna de freio.
func _carro_parado(
	props: Node3D, rua: RandomNumberGenerator, faixa: Vector3, d: Vector3, fila: float
) -> float:
	var sorteio := rua.randf()
	var modelo := Carro.Modelo.SEDA
	if sorteio < 0.3:
		modelo = Carro.Modelo.HATCH
	elif sorteio < 0.45:
		modelo = Carro.Modelo.SUV
	elif sorteio < 0.6:
		modelo = Carro.Modelo.TAXI
	elif sorteio < 0.66:
		modelo = Carro.Modelo.ONIBUS
	var carro := Carro.new()
	carro.name = "CarroParado"
	props.add_child(carro)
	carro.montar(modelo, rua)
	var comprimento := carro.caixa().size.z
	if fila + comprimento > RUA_COMPRIMENTO - 2.0:
		carro.queue_free()
		return fila
	carro.global_transform = Transform3D(
		Basis.looking_at(-d, Vector3.UP), faixa + d * (fila + comprimento * 0.5)
	)
	carro.atualizar(1.0 / 60.0, 0.0, 0.0, false, 0)
	_colisor(carro, carro.caixa())
	return fila + comprimento + rua.randf_range(1.2, 2.5)


## Poste na esquina com dois focos: o da rua, no vermelho, para a fila; o da
## avenida, no verde, para o jogador. `d` aponta para a rua; `frente_avenida`
## e o +Z da pista, de onde o jogador vem.
func _semaforo(
	props: Node3D, mat: Dictionary, pe: Vector3, d: Vector3, frente_avenida: Vector3
) -> void:
	var raiz := Node3D.new()
	raiz.name = "Semaforo"
	props.add_child(raiz)
	raiz.global_position = pe
	var poste := Greybox.box(Vector3(0.16, 4.4, 0.16), Color.BLACK)
	poste.material_override = mat["poste"]
	raiz.add_child(poste)
	poste.position = Vector3.UP * 2.2
	# Um pouco mais grosso que o poste: a 50 m/s, 16 cm de colisor e o que um
	# quadro de fisica atravessa de raspao.
	_colisor(raiz, AABB(Vector3(-0.2, 0.0, -0.2), Vector3(0.4, 4.4, 0.4)))
	frente_avenida.y = 0.0
	_foco(raiz, mat, d, "vermelho", Vector3.UP * 3.6 + d * 0.15)
	_foco(raiz, mat, frente_avenida.normalized(), "verde", Vector3.UP * 3.6 - d * 0.15)


## Caixa de tres luzes olhando para `olha`, com so `acesa` emitindo.
func _foco(raiz: Node3D, mat: Dictionary, olha: Vector3, acesa: String, onde: Vector3) -> void:
	var caixa := Greybox.box(Vector3(0.34, 0.95, 0.24), Color.BLACK)
	caixa.material_override = mat["caixa"]
	raiz.add_child(caixa)
	caixa.position = onde
	caixa.basis = Basis.looking_at(olha, Vector3.UP)
	var cores: Array[String] = ["vermelho", "amarelo", "verde"]
	for i in cores.size():
		var luz := Greybox.box(Vector3(0.2, 0.2, 0.06), Color.BLACK)
		luz.material_override = mat[cores[i] + ("_aceso" if cores[i] == acesa else "")]
		caixa.add_child(luz)
		# -Z da caixa e para onde ela olha.
		luz.position = Vector3(0.0, 0.29 - 0.29 * float(i), -0.13)


## Materiais do semaforo, um de cada, compartilhados por todos.
static func _materiais_de_semaforo() -> Dictionary:
	var lampadas := {
		"vermelho": Color(0.95, 0.12, 0.08),
		"amarelo": Color(0.98, 0.70, 0.08),
		"verde": Color(0.15, 0.90, 0.35),
	}
	var mat := {
		"poste": Greybox.material(Color(0.22, 0.23, 0.22)),
		"caixa": Greybox.material(Color(0.10, 0.10, 0.10)),
	}
	for nome: String in lampadas:
		var cor: Color = lampadas[nome]
		mat[nome] = Greybox.material(cor.darkened(0.8))
		var acesa := Greybox.material(cor, true)
		acesa.emission_energy_multiplier = 2.0
		mat[nome + "_aceso"] = acesa
	return mat


## Retangulo deitado: borda perto de `a` a `b`, esticado `comprimento` em `d`.
## UV de 0 a `uv` - no asfalto, em faixas e em tiles, como na avenida.
static func _retangulo(
	st: SurfaceTool, a: Vector3, b: Vector3, d: Vector3, comprimento: float, uv: Vector2
) -> void:
	var c := b + d * comprimento
	var e := a + d * comprimento
	_quad_deitado(st, [a, b, c, e], [Vector2(0, 0), Vector2(uv.x, 0), uv, Vector2(0, uv.y)])


## Faixa de tinta com centro de largura em `p`: `comprida` ao longo de `ao_longo`,
## `largura` no outro eixo.
static func _faixa(
	st: SurfaceTool, p: Vector3, ao_longo: Vector3, lado: Vector3, largura: float, comprida: float
) -> void:
	var a := p - lado * largura * 0.5
	var b := p + lado * largura * 0.5
	_quad_deitado(st, [a, b, b + ao_longo * comprida, a + ao_longo * comprida], [])


## Dois triangulos virados para cima. Godot descarta face anti-horaria sem
## avisar (ver o `_quad` da pista), e aqui a ordem dos cantos depende do lado
## da avenida - entao o winding e conferido pela normal, e nao confiado.
static func _quad_deitado(st: SurfaceTool, cantos: Array[Vector3], uvs: Array[Vector2]) -> void:
	for primeiro: int in [1, 2]:
		var ordem: Array[int] = [0, primeiro, primeiro + 1]
		var n := (cantos[ordem[1]] - cantos[ordem[0]]).cross(cantos[ordem[2]] - cantos[ordem[0]])
		# Na ordem horaria vista de cima, este produto aponta para baixo.
		if n.y > 0.0:
			ordem = [ordem[0], ordem[2], ordem[1]]
		for i in ordem:
			st.set_normal(Vector3.UP)
			if not uvs.is_empty():
				st.set_uv(uvs[i])
			st.add_vertex(cantos[i])


## Qual dos quatro predios cabe na altura sorteada. A faixa de cada um e a
## proporcao dele na avenida: um quarto de sobrado, o grosso de predio baixo
## de comercio, e torre so de vez em quando - torre demais fecha o ceu, e o
## ceu e metade da leitura de velocidade.
static func _tipo_de_predio(altura: float) -> Predio.Tipo:
	if altura < 11.0:
		return Predio.Tipo.SOBRADO
	if altura < 19.0:
		return Predio.Tipo.COMERCIO
	if altura < 23.0:
		return Predio.Tipo.ESCRITORIO
	return Predio.Tipo.TORRE
