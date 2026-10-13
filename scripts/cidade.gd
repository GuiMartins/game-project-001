class_name Cidade
extends RefCounted
## O que fica dos dois lados da avenida: predio colado em predio, e as ruas que
## a cruzam, com semaforo e a fila parada no vermelho.
##
## A avenida alterna dois trechos. No corredor, o predio vem na linha da
## calcada, alto, e o ceu so aparece em cima. No largo, a fachada recua uns
## 5 m e fica baixa - sobrado e comercio -, com uma praca de canteiros na
## frente, e o quadro abre. A alternancia e o ritmo do video de referencia: o
## corredor so parece fechado porque o largo veio antes.
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
## Comprimento de cada trecho, em metros. O largo e curto: a 35 m/s sao uns
## 2 s de respiro, e e o corredor que se quer na maior parte da volta. Mais
## curto que isso o largo vira um buraco na fileira, e nao um trecho. Ja foi
## de 60 a 130 m, e nas referencias nao ha trecho aberto desse tamanho
## (V11a).
const LARGO_COMPRIMENTO := Vector2(40.0, 80.0)
const CORREDOR_COMPRIMENTO := Vector2(180.0, 380.0)
## Quanto a fachada do largo recua alem do `RECUO_FACHADA`. Era 8 a 12 m de
## pedra vazia, que nenhuma referencia tem; agora e o fundo de uma praca, com
## canteiro na frente (`_monta_praca`), e cabe o canteiro e a passagem.
const LARGO_RECUO := Vector2(4.0, 7.0)
## A altura sorteada em cada trecho, que o `_tipo_de_predio` vira tipo. No
## largo so cabe sobrado e comercio: predio alto recuado e so um corredor mais
## longe, e o que abre o quadro e o ceu que aparece por cima.
## No corredor, de 12 m para cima: nas referencias ele e um canion de 8 a 15
## andares saindo pelo topo do quadro (`video_01/t5.0s`), e sobrado no meio
## dele abria janela de ceu no nivel da rua (V11a).
const ALTURA_LARGO := Vector2(6.0, 16.0)
const ALTURA_CORREDOR := Vector2(12.0, 30.0)
## O canteiro da praca do largo: comprido ao longo da avenida, baixo o bastante
## para nao esconder a loja atras e alto o bastante para ler como mureta a
## 640x360. Um a cada `CANTEIRO_PASSO` metros, com passagem entre eles.
const CANTEIRO := Vector3(2.2, 0.5, 6.0)
const CANTEIRO_PASSO: float = 10.0
const COR_CANTEIRO := Color(0.62, 0.60, 0.56)
const COR_GRAMA := Color(0.30, 0.46, 0.18)
## A distancia entre um grupo de arvores e o seguinte, de cada lado.
const ARVORE_PASSO := Vector2(35.0, 75.0)
## A chance de o grupo ser uma copa, e nao palmeiras. Menos da metade: a copa
## e o momento de passar por baixo, e momento repetido perde a graca.
const ARVORE_COPA: float = 0.4
## Entre uma palmeira e a do lado, no grupo.
const PALMEIRA_PASSO: float = 4.0

var track: RoadTrack


func _init(a_track: RoadTrack) -> void:
	track = a_track


## Monta tudo em `props`. `rua` e o gerador so da cidade: nada que sai dele
## mexe no transito nem nos rivais.
func montar(rua: RandomNumberGenerator, props: Node3D) -> void:
	var cruzamentos := _sorteia_cruzamentos(rua)
	var trechos := _sorteia_trechos(rua)
	track.pintar(cruzamentos, RUA_LARGURA * 0.5)
	_monta_ruas(cruzamentos, rua, props)
	for side: float in [-1.0, 1.0]:
		_monta_quarteirao(side, cruzamentos, trechos, rua, props)
		_monta_praca(side, cruzamentos, trechos, props)
	# Por ultimo, para os sorteios das arvores nao mexerem em predio nem rua.
	for side: float in [-1.0, 1.0]:
		_monta_arvores(side, cruzamentos, rua, props)


## Onde a avenida e largo e onde e corredor. Cada um e `[fim, recuo]`: o
## trecho vai do fim do anterior ate `fim`, e `recuo` e o que a fachada recua
## alem do `RECUO_FACHADA` - zero no corredor. Os dois lados da avenida
## dividem a mesma lista: largo de um lado so e um predio faltando, e nao uma
## praca.
##
## Comeca no largo, como o video: e a largada que respira, e o corredor
## chega depois.
func _sorteia_trechos(rua: RandomNumberGenerator) -> Array[Vector2]:
	var lista: Array[Vector2] = []
	var o := 0.0
	var largo := true
	while o < track.length:
		var faixa := LARGO_COMPRIMENTO if largo else CORREDOR_COMPRIMENTO
		o += rua.randf_range(faixa.x, faixa.y)
		var recuo := rua.randf_range(LARGO_RECUO.x, LARGO_RECUO.y) if largo else 0.0
		lista.append(Vector2(o, recuo))
		largo = not largo
	return lista


## O recuo extra do trecho em que cai `o`; zero e corredor.
static func recuo_em(trechos: Array[Vector2], o: float) -> float:
	for t in trechos:
		if o < t.x:
			return t.y
	return 0.0


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


## Se o ponto `offset` da avenida, do lado `side`, cai na boca de uma rua - ou
## na calcada da esquina dela, onde fica o semaforo. Poste ali e poste no
## meio da rua.
static func na_boca(cruzamentos: Array[Vector2], offset: float, side: float) -> bool:
	for c in cruzamentos:
		if _abre(c.y, side) and absf(offset - c.x) < RUA_LARGURA * 0.5 + RUA_CALCADA:
			return true
	return false


static func _abre(lados: float, side: float) -> bool:
	return lados == LADO_AMBOS or lados == side


## Predio colado em predio, de um lado da avenida, parando so nas ruas.
##
## Nenhuma avenida de cidade tem 15 m de vazio entre um predio e o outro: o
## buraco e o que fazia a rua parecer cenario. O vao que sobra e o da junta
## entre duas obras, ate meio metro - o bastante para a fachada nao parecer
## uma parede so, pouco para o ceu aparecer no nivel da rua.
func _monta_quarteirao(
	side: float,
	cruzamentos: Array[Vector2],
	trechos: Array[Vector2],
	rua: RandomNumberGenerator,
	props: Node3D
) -> void:
	var edge := RoadTrack.half_width() + RoadTrack.SHOULDER
	var vaos: Array[Vector2] = []
	for c in cruzamentos:
		if _abre(c.y, side):
			var meio := RUA_LARGURA * 0.5 + RUA_CALCADA
			vaos.append(Vector2(c.x - meio, c.x + meio))

	var o := 12.0
	while o < track.length - 10.0:
		var recuo := recuo_em(trechos, o)
		var alturas := ALTURA_LARGO if recuo > 0.0 else ALTURA_CORREDOR
		var tipo := _tipo_de_predio(rua.randf_range(alturas.x, alturas.y))
		var caixa := Predio.malha(tipo).get_aabb()
		var lateral := (edge + RECUO_FACHADA + recuo + Predio.frente(tipo)) * side
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


## Os canteiros da praca no recuo de cada largo (V11a): o largo fica, mas como
## praca, e nao como chao vazio. Arvore e gente vem com a V16 e a V19; o
## canteiro e o que ja da escala e tira o descampado. Nao sorteia nada, para
## nao mexer na cidade que vem depois no mesmo gerador.
func _monta_praca(
	side: float, cruzamentos: Array[Vector2], trechos: Array[Vector2], props: Node3D
) -> void:
	var edge := RoadTrack.half_width() + RoadTrack.SHOULDER
	var meio := RUA_LARGURA * 0.5 + RUA_CALCADA
	var caixa := BoxMesh.new()
	caixa.size = CANTEIRO
	caixa.material = RoadTrack.material_liso(COR_CANTEIRO)
	var terra := BoxMesh.new()
	terra.size = Vector3(CANTEIRO.x - 0.3, 0.02, CANTEIRO.z - 0.3)
	terra.material = RoadTrack.material_liso(COR_GRAMA)
	var inicio := 0.0
	for t in trechos:
		if t.y > 0.0:
			# Na metade da faixa entre a calcada e a fachada recuada.
			var lateral := (edge + RECUO_FACHADA + t.y * 0.5) * side
			var o := inicio + CANTEIRO_PASSO * 0.5
			while o < minf(t.x, track.length) - CANTEIRO.z:
				var na_rua := false
				for c in cruzamentos:
					if _abre(c.y, side) and absf(o - c.x) < meio + CANTEIRO.z:
						na_rua = true
				if not na_rua:
					_canteiro(props, track.transform_at(o, lateral), caixa, terra)
				o += CANTEIRO_PASSO
		inicio = t.x


## Palmeira em grupo de duas ou tres e arvore de copa debrucada sobre a pista,
## na faixa de servico (V16). Um grupo a cada 35 a 75 m de cada lado: mais
## que isso a avenida vira bosque e esconde a fachada, que e o referencial de
## velocidade; menos e a copa por cima da camera vira acidente, e nao ritmo.
func _monta_arvores(
	side: float, cruzamentos: Array[Vector2], rua: RandomNumberGenerator, props: Node3D
) -> void:
	# Na faixa de servico, 3 m depois do meio-fio: atras da linha dos postes
	# (0,6 m) e da do rival que terminou a corrida (1,6 m).
	var lateral := (
		(RoadTrack.half_width() + RoadTrack.SHOULDER + RoadTrack.FAIXA_SERVICO * 0.5) * side
	)
	var o := rua.randf_range(20.0, 60.0)
	while o < track.length - 20.0:
		var copa := rua.randf() < ARVORE_COPA
		var quantas := 1 if copa else rua.randi_range(2, 3)
		for i in quantas:
			var aqui := o + i * PALMEIRA_PASSO
			if Cidade.na_boca(cruzamentos, aqui, side):
				continue
			var pe := track.point(aqui, lateral)
			var para_a_pista := track.sample_basis(aqui).x * -side
			var tipo := Arvore.Tipo.COPA if copa else Arvore.Tipo.PALMEIRA
			props.add_child(Arvore.criar(tipo, pe, para_a_pista))
		o += rua.randf_range(ARVORE_PASSO.x, ARVORE_PASSO.y)


func _canteiro(props: Node3D, onde: Transform3D, caixa: BoxMesh, terra: BoxMesh) -> void:
	var no := Node3D.new()
	no.name = "Canteiro"
	props.add_child(no)
	no.global_transform = onde
	var mureta := MeshInstance3D.new()
	mureta.mesh = caixa
	mureta.position.y = CANTEIRO.y * 0.5
	no.add_child(mureta)
	var grama := MeshInstance3D.new()
	grama.mesh = terra
	grama.position.y = CANTEIRO.y + 0.01
	no.add_child(grama)
	_colisor(no, AABB(Vector3(-CANTEIRO.x, 0.0, -CANTEIRO.z) * 0.5, CANTEIRO))


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
## O asfalto, a pintura e o meio-fio de todas as ruas sao uma malha so, com
## tres superficies: dezenas de ruas viram tres chamadas de desenho.
func _monta_ruas(cruzamentos: Array[Vector2], rua: RandomNumberGenerator, props: Node3D) -> void:
	var road_w := RoadTrack.half_width()
	# Onde acaba o andavel: dali para fora fica o que a moto nao alcanca.
	var calcada := RoadTrack.SHOULDER
	var asfalto := SurfaceTool.new()
	asfalto.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tinta := SurfaceTool.new()
	tinta.begin(Mesh.PRIMITIVE_TRIANGLES)
	var meio_fio := SurfaceTool.new()
	meio_fio.begin(Mesh.PRIMITIVE_TRIANGLES)
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
			# `r` corre na largura da rua, e na ladeira ele sobe junto com a
			# avenida: a rua e o retangulo de `perto_a` a `perto_b`, que estao em
			# alturas diferentes. Tirado na horizontal, a zebra, o meio-fio e a
			# fila ficavam na altura do meio da rua - a 10% de rampa, uma borda
			# 30 cm acima do asfalto e a outra enterrada nele.
			var r := (perto_b - perto_a).normalized()
			if r.dot((-d).cross(Vector3.UP)) < 0.0:
				r = -r
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
			# Meio-fio dos dois lados da rua. Sem ele o asfalto da rua no sol fica
			# da cor do cimentado em volta, e a zebra parece pintada na calcada.
			for lado: float in [-1.0, 1.0]:
				var borda := chao + r * lado * (meio + RoadTrack.MEIO_FIO * 0.5)
				_faixa(meio_fio, borda, d, r, RoadTrack.MEIO_FIO, RUA_COMPRIMENTO)
			# Faixa de pedestre na linha da calcada, com a mesma zebra e a mesma
			# retencao da avenida, so na mao de quem chega. Fica a
			# `ZEBRA_ESQUINA` do asfalto da avenida, como a da avenida fica da
			# boca da rua: e por ali que passa quem anda pela calcada.
			var zebra := RoadTrack.ZEBRA_ESQUINA
			for x in RoadTrack.listras_da_zebra(RUA_LARGURA):
				var p := chao + r * x + d * zebra
				_faixa(tinta, p, d, r, RoadTrack.ZEBRA_LISTRA, RoadTrack.ZEBRA_COMPRIMENTO)
			var retencao := zebra + RoadTrack.ZEBRA_COMPRIMENTO + RoadTrack.RETENCAO_RECUO
			var linha := chao + d * (retencao + RoadTrack.RETENCAO_LARGURA * 0.5)
			_faixa(tinta, linha, r, d, RoadTrack.RETENCAO_LARGURA, meio)
			# O fundo da rua e a fachada de um predio da quadra de tras, olhando
			# para a avenida: rua que acaba no vazio mostra a borda do mundo, e
			# predio no fundo e o "T" que toda rua de bairro tem.
			var tipo := _tipo_de_predio(rua.randf_range(6.0, 23.0))
			var pe := centro + d * (RUA_COMPRIMENTO - 2.0 + Predio.frente(tipo))
			_predio(props, rua, tipo, pe, -d)
			# Tracejado do meio da rua, um carro depois da retencao.
			var t := retencao + 5.0
			while t < RUA_COMPRIMENTO - 3.0:
				_faixa(tinta, chao + d * t, d, r, 0.14, 2.0)
				t += 4.5

			# Metade das ruas chega na avenida e metade sai dela. Quem chega
			# para no vermelho - a avenida esta no verde, e e o jogador que
			# passa. Rua de saida nao tem semaforo nem fila: ninguem espera
			# para sair da avenida.
			if rua.randf() < 0.5:
				continue
			# Na faixa de servico, e nao no andavel como os postes da avenida:
			# na esquina e a fila da rua que precisa do foco, e no andavel
			# ele fecharia a curva de quem entra na transversal.
			var esquina := centro + acima + d * (calcada + 0.8) + r * (meio + 0.9)
			_semaforo(props, materiais, esquina, d, track.sample_basis(c.x).z)
			var fila := retencao + RoadTrack.RETENCAO_LARGURA + 0.6
			# Na ladeira o carro tomba de lado junto com a rua, senao uma roda
			# fica no ar e a outra dentro do asfalto.
			var normal := d.cross(r)
			if normal.y < 0.0:
				normal = -normal
			var faixa := centro + acima + r * meio * 0.5
			for _i in rua.randi_range(1, 3):
				fila = _carro_parado(props, rua, faixa, d, normal, fila)

	var malha := ArrayMesh.new()
	asfalto.commit(malha)
	malha.surface_set_material(0, RoadTrack.material_texturizado(RoadTrack.ASFALTO))
	tinta.commit(malha)
	malha.surface_set_material(1, RoadTrack.material_liso(RoadTrack.TINTA))
	meio_fio.commit(malha)
	malha.surface_set_material(2, RoadTrack.material_liso(RoadTrack.COR_MEIO_FIO))
	var ruas := MeshInstance3D.new()
	ruas.name = "Ruas"
	ruas.mesh = malha
	ruas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	props.add_child(ruas)


## Um carro esperando o verde, `fila` metros adiante do asfalto da avenida,
## na mao de quem chega, de pe em `normal`, a do chao da rua. Devolve onde
## comeca o espaco do proximo da fila.
##
## E so o `Carro`, sem `TrafficCar`: nao anda e nao entra no transito. Tem
## colisor, da lataria, porque a moto que entra na rua bate nele. Uma pose so,
## parado e sem encostar, e o que acende a lanterna de freio.
func _carro_parado(
	props: Node3D,
	rua: RandomNumberGenerator,
	faixa: Vector3,
	d: Vector3,
	normal: Vector3,
	fila: float
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
		Basis.looking_at(-d, normal), faixa + d * (fila + comprimento * 0.5)
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


## Qual dos cinco predios cabe na altura sorteada. No corredor (12 a 30 m) sai
## um quinto de comercio, um terco de deco, pouco escritorio e o resto torre:
## o canion das referencias, que sai pelo topo do quadro. O ceu que sobra e o
## de cima da avenida, e e ele que conta para a velocidade. O largo sorteia so
## ate 16 m, e fica no sobrado e no comercio.
static func _tipo_de_predio(altura: float) -> Predio.Tipo:
	if altura < 10.0:
		return Predio.Tipo.SOBRADO
	if altura < 16.0:
		return Predio.Tipo.COMERCIO
	if altura < 21.5:
		return Predio.Tipo.DECO
	if altura < 23.0:
		return Predio.Tipo.ESCRITORIO
	return Predio.Tipo.TORRE
