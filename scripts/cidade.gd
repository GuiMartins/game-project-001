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
## E entre um corredor e o largo seguinte, de vez em quando, a via expressa
## (V11b, `ViaExpressa`): muro de mural, mureta e viaduto, sem rua, calcada nem
## gente. Ela soma pista, e nao toma o lugar de um corredor: a corrida fica
## mais longa pelo comprimento das expressas (`plano_de_expressas`).
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
## O "nao e obra" de `fase_de_obra`: `Predio.Obra` e um enum, e a falta dele
## precisa caber num int.
const SEM_OBRA: int = -1
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
## A faixa de grama colada na fachada da praca: largura, e o comprimento de
## cada pedaco, curto o bastante para seguir a curva da avenida.
const GRAMA_LARGURA: float = 1.6
const GRAMA_PASSO: float = 4.0
## A distancia entre um ponto da faixa de servico e o seguinte, de cada lado.
const SERVICO_PASSO := Vector2(30.0, 65.0)
## A chance de cada coisa num ponto da faixa de servico; o que sobra e mupi.
## Copa e menos de um terco: e o momento de passar por baixo, e momento
## repetido perde a graca.
const ARVORE_COPA: float = 0.3
const PALMEIRAS: float = 0.4
const CACAMBA: float = 0.15
## A placa de curva: a janela em que o giro e medido, o giro a partir do qual
## e curva (0,2 rad em 40 m e um raio de ~200 m) e quanto antes dela a placa
## fica - a 35 m/s, um segundo e meio de aviso.
const CURVA_JANELA: float = 40.0
const CURVA_LIMIAR: float = 0.2
const CURVA_AVISO: float = 50.0
## Quanto antes do semaforo suspenso fica o portico da placa verde.
const PORTICO_ANTES: float = 30.0
## Entre uma palmeira e a do lado, no grupo.
const PALMEIRA_PASSO: float = 4.0
## A via expressa (V11b): quantas por corrida, de que tamanho, e depois de qual
## corredor (contando do zero) cada uma entra. Duas de 320 a 480 m somam uns
## 800 m aos 3,2 km da avenida, uns 25 s a mais de corrida a 120 km/h: o
## bastante para ser um trecho, e nao uma passagem, e pouco para a avenida
## virar o intervalo. Depois do segundo corredor, e nao do primeiro: a
## largada mostra a avenida antes.
const EXPRESSAS: int = 2
const EXPRESSA_COMPRIMENTO := Vector2(320.0, 480.0)
const EXPRESSA_DEPOIS: Array[int] = [1, 3]
## O viaduto ocupa a expressa menos 20 m de cada ponta, e chega de lado nos
## 60 m seguintes (`ViaExpressa.VIADUTO_CURVA`). A placa verde fica 50 m
## depois da entrada: ali o tabuleiro ainda vem 20 m para fora, e o braco dela
## (9 m, a 7,4 m de altura) nao entra embaixo dele.
const VIADUTO_PONTA: float = 20.0
const EXPRESSA_PLACA: float = 50.0
## A faixa de servico da avenida (arvore, cacamba) para a menos disso da
## expressa: e onde ficam a zebra e a retencao da rua da esquina, ate 12 m
## antes dela.
const EXPRESSA_FOLGA: float = 15.0
## A mao contraria da expressa precisa vir de algum lugar e ir para algum
## lugar: em cada ponta ela vira numa transversal, a rua da esquina, que abre
## so do lado do viaduto. Antes ela nascia colada no ultimo predio e morria
## de cara na calcada do quarteirao.
## Cruzamento sorteado a menos disto da esquina sai: as duas bocas ficariam a
## um predio fino uma da outra, e o sorteio normal ja nao poe rua a menos de 70.
const ESQUINA_FOLGA: float = 40.0
## Quais expressas (contando do zero) separam as maos com mureta e os pilares
## do viaduto no eixo da pista, e nao com a faixa dupla amarela. A segunda:
## a primeira mostra a mao contraria aberta, e a segunda tem de ser outra
## coisa, senao a corrida repete o mesmo trecho.
const PILARES_NO_MEIO: Array[int] = [1]

## Uma torre em cada `OBRA_UMA_EM` do corredor vira obra (V17a): esqueleto ou
## meio vestida, de andaime e lona, com guindaste em cima. Uma em tres deixa uma obra a cada
## uns 600 m de avenida: e a silhueta de "cidade crescendo", e nao a cidade
## toda em construcao. Uma em seis deixava so duas na corrida inteira.
const OBRA_UMA_EM: int = 3
## Mastro e lanca do guindaste de cima da obra, e o pe dele na laje: fora do
## miolo do elevador, entre dois pilares, para nao atravessar nenhum.
const OBRA_MASTRO: float = 15.0
const OBRA_LANCA: float = 28.0
const OBRA_GUINDASTE := Vector3(4.5, 0.0, 3.0)
## O guindaste atras do muro de cada via expressa: a que distancia do muro, a
## que altura e que alcance, e em que ponto do trecho (fracao do comprimento).
const EXPRESSA_GUINDASTE_ATRAS: float = 14.0
const EXPRESSA_GUINDASTE_MASTRO: float = 36.0
const EXPRESSA_GUINDASTE_LANCA: float = 24.0
const EXPRESSA_GUINDASTE_EM: float = 0.4

## Os nomes que o GPS escreve (V25a), em caixa alta como no celular. Lugar e
## livre, marca nao (V18). A avenida e uma por corrida; a via expressa ganha
## nome proprio, porque entrar nela e trocar de via. Fora daqui os nomes que
## a placa verde aponta (`Portal.DESTINOS`), para a placa nao mandar o jogador
## para a avenida em que ele ja esta.
const AVENIDAS: Array[String] = [
	"AV. RODRIGUES ALVES",
	"AV. FRANCISCO BICALHO",
	"AV. MARACANA",
	"AV. DOS DEMOCRATICOS",
	"RUA DO RIACHUELO",
	"AV. MEM DE SA",
]
const VIAS_EXPRESSAS: Array[String] = [
	"LINHA AMARELA",
	"ELEVADO DO JOA",
	"ELEVADO PAULO DE FRONTIN",
]

var track: RoadTrack
## O fundo da cidade (V14a): os marcos que a `Marcos` planta no fim das retas.
## Trocar de cidade e trocar este catalogo.
var marcos: Array[Marcos.Marco] = Marcos.rio()
## Onde a pista e via expressa, `[de, ate, lado]`: o mesmo que vai para o
## `RoadTrack.expressas`.
var expressas: Array[Vector3] = []


func _init(a_track: RoadTrack) -> void:
	track = a_track


## Monta tudo em `props`. `rua` e o gerador so da cidade: nada que sai dele
## mexe no transito nem nos rivais.
func montar(rua: RandomNumberGenerator, props: Node3D) -> void:
	var cruzamentos := _sorteia_cruzamentos(rua)
	var trechos := _sorteia_trechos(rua, plano_de_expressas(rua.seed))
	track.expressas = expressas
	track.pilares_no_meio = []
	for i in expressas.size():
		track.pilares_no_meio.append(PILARES_NO_MEIO.has(i))
	_da_nomes(rua.seed)
	cruzamentos = cruzamentos.filter(func(c: Vector2) -> bool: return not _perto_de_esquina(c.x))
	cruzamentos.append_array(esquinas_das_expressas(expressas))
	cruzamentos.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	track.pintar(cruzamentos, RUA_LARGURA * 0.5)
	_monta_expressas(rua.seed, props)
	_monta_ruas(cruzamentos, rua, props)
	for side: float in [-1.0, 1.0]:
		_monta_quarteirao(side, cruzamentos, trechos, rua, props)
		_monta_praca(side, cruzamentos, trechos, props)
	# Por ultimo, para os sorteios da faixa de servico nao mexerem em predio
	# nem rua. As placas de curva nao sorteiam nada.
	for side: float in [-1.0, 1.0]:
		_monta_faixa_de_servico(side, cruzamentos, rua, props)
	_monta_placas(cruzamentos, props)
	_monta_portais(cruzamentos, props)
	Marcos.montar(track, rua.seed, marcos, props)
	Pedestres.montar(track, cruzamentos, rua, props)


## Os nomes da avenida e das expressas, por hash da semente, e nao pelo `rua`:
## sortear daquele gerador mudaria toda a cidade que sai dele depois.
func _da_nomes(semente: int) -> void:
	track.nome = AVENIDAS[hash(semente + 11) % AVENIDAS.size()]
	var primeira := hash(semente + 13) % VIAS_EXPRESSAS.size()
	var nomes: Array[String] = []
	for i in expressas.size():
		nomes.append(VIAS_EXPRESSAS[(primeira + i) % VIAS_EXPRESSAS.size()])
	track.nomes_das_expressas = nomes


## Onde a avenida e largo e onde e corredor. Cada um e `[fim, recuo]`: o
## trecho vai do fim do anterior ate `fim`, e `recuo` e o que a fachada recua
## alem do `RECUO_FACHADA` - zero no corredor. Os dois lados da avenida
## dividem a mesma lista: largo de um lado so e um predio faltando, e nao uma
## praca.
##
## Comeca no largo, como o video: e a largada que respira, e o corredor
## chega depois.
##
## As `expressas` (comprimentos, de `plano_de_expressas`) entram depois dos
## corredores do `EXPRESSA_DEPOIS`, como trecho sem recuo, e vao para
## `self.expressas`. Os sorteios da avenida sao os mesmos com ou sem elas.
func _sorteia_trechos(rua: RandomNumberGenerator, plano: Array[float] = []) -> Array[Vector2]:
	var lista: Array[Vector2] = []
	expressas = []
	var o := 0.0
	var largo := true
	var corredor := 0
	while o < track.length:
		var faixa := LARGO_COMPRIMENTO if largo else CORREDOR_COMPRIMENTO
		o += rua.randf_range(faixa.x, faixa.y)
		var recuo := rua.randf_range(LARGO_RECUO.x, LARGO_RECUO.y) if largo else 0.0
		lista.append(Vector2(o, recuo))
		if not largo:
			var k := EXPRESSA_DEPOIS.find(corredor)
			if k >= 0 and k < plano.size() and o + plano[k] < track.length - 100.0:
				# O viaduto fica sempre a esquerda, como na `03`: e o lado da mao
				# contraria, e aqui se anda pela direita - mao contraria a direita
				# e mao inglesa. Ja alternou, e a segunda expressa vinha ao contrario.
				var lado := LADO_ESQUERDA
				expressas.append(Vector3(o, o + plano[k], lado))
				o += plano[k]
				lista.append(Vector2(o, 0.0))
			corredor += 1
		largo = not largo
	return lista


## O comprimento de cada via expressa da corrida, da semente da cidade. Sai
## antes da pista existir: o `World` soma isso ao tamanho dela.
static func plano_de_expressas(semente: int) -> Array[float]:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(semente + 3)
	var plano: Array[float] = []
	for i in EXPRESSAS:
		plano.append(rng.randf_range(EXPRESSA_COMPRIMENTO.x, EXPRESSA_COMPRIMENTO.y))
	return plano


## Quanto as expressas somam a pista.
static func extra_de_expressas(semente: int) -> float:
	var total := 0.0
	for c in plano_de_expressas(semente):
		total += c
	return total


## A expressa em que cai `o`, ou `Vector3.ZERO`.
static func expressa_em(pista: RoadTrack, o: float) -> Vector3:
	for e in pista.expressas:
		if o >= e.x and o <= e.y:
			return e
	return Vector3.ZERO


## Onde corre o tabuleiro de uma expressa `[de, ate, lado]`.
static func viaduto_de(e: Vector3) -> Vector2:
	return Vector2(e.x + VIADUTO_PONTA, e.y - VIADUTO_PONTA)


## Se o ponto `o` do lado `side` esta embaixo de um viaduto: poste ali fura o
## tabuleiro.
static func sob_viaduto(pista: RoadTrack, o: float, side: float) -> bool:
	var e := expressa_em(pista, o)
	if e == Vector3.ZERO or e.z != side:
		return false
	var v := viaduto_de(e)
	return o >= v.x and o <= v.y


## A rua de cada ponta das `expressas`, como cruzamento `[offset, lados]`: a
## boca dela acaba onde a expressa comeca (ou comeca onde ela acaba), e abre
## so do lado do viaduto, que e onde corre a mao contraria.
static func esquinas_das_expressas(lista: Array[Vector3]) -> Array[Vector2]:
	var esquinas: Array[Vector2] = []
	for e in lista:
		esquinas.append(Vector2(e.x - RUA_LARGURA * 0.5, e.z))
		esquinas.append(Vector2(e.y + RUA_LARGURA * 0.5, e.z))
	return esquinas


## Para que lado da pista a mao contraria sai da rua `c`, do lado `side` da
## avenida: +1 se ela segue para a frente (a entrada da expressa), -1 para
## tras (a saida), zero se nao e rua de esquina.
func _mao_contraria_em(c: Vector2, side: float) -> float:
	for e in expressas:
		if e.z != side:
			continue
		if absf(c.x - (e.x - RUA_LARGURA * 0.5)) < 0.01:
			return 1.0
		if absf(c.x - (e.y + RUA_LARGURA * 0.5)) < 0.01:
			return -1.0
	return 0.0


func _perto_de_esquina(o: float) -> bool:
	for e in expressas:
		if (
			o > e.x - RUA_LARGURA * 0.5 - ESQUINA_FOLGA
			and o < e.y + RUA_LARGURA * 0.5 + ESQUINA_FOLGA
		):
			return true
	return false


func _perto_de_expressa(o: float) -> bool:
	for e in expressas:
		if o > e.x - EXPRESSA_FOLGA and o < e.y + EXPRESSA_FOLGA:
			return true
	return false


## Cada expressa com o kit da `ViaExpressa`, os paineis de um gerador so dela,
## e a placa verde da entrada.
func _monta_expressas(semente: int, props: Node3D) -> void:
	var paineis := RandomNumberGenerator.new()
	paineis.seed = hash(semente + 4)
	var mat := _materiais_de_semaforo()
	for i in expressas.size():
		var e := expressas[i]
		var no_meio := track.pilares_no_meio[i]
		ViaExpressa.montar(track, e.x, e.y, e.z, viaduto_de(e), paineis, props, no_meio)
		var destinos: Array = Portal.DESTINOS[i % Portal.DESTINOS.size()]
		var onde := track.transform_at(e.x + EXPRESSA_PLACA, Portal.LATERAL)
		props.add_child(Portal.placa(onde, mat, destinos))
		_guindaste_atras_do_muro(e, i, props)
		props.add_child(Contramao.criar(track, e, hash([semente, i, 7])))
		ViaExpressa.placas_de_mao_dupla(track, e, mat, props)


## O guindaste ao fundo, atras do muro alto da expressa (`03_viaduto`). Sem
## colisor: esta alem do muro e do alambrado.
func _guindaste_atras_do_muro(e: Vector3, i: int, props: Node3D) -> void:
	var fechado := -e.z
	var lateral := (
		(RoadTrack.sidewalk_limit() + ViaExpressa.MURO_ALTO.x + EXPRESSA_GUINDASTE_ATRAS) * fechado
	)
	var base := track.transform_at(lerpf(e.x, e.y, EXPRESSA_GUINDASTE_EM), lateral)
	var g := Guindaste.criar(
		EXPRESSA_GUINDASTE_MASTRO, EXPRESSA_GUINDASTE_LANCA, _giro(hash([track.length, i]))
	)
	props.add_child(g)
	g.global_transform = Transform3D(base.basis, base.origin + Vector3.DOWN)


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
	# Na expressa a borda e muro: predio nenhum dos dois lados.
	for e in expressas:
		vaos.append(Vector2(e.x, e.y))

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
		var obra := fase_de_obra(rua.seed, tipo, o, side)
		_predio(props, rua, tipo, base.origin, base.basis.x * -side, obra)
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
	# A faixa de grama colada na fachada da praca (V17, `video_01/t2.0s`): o
	# verde que separa a calcada do predio recuado. Uma malha so para todas.
	var grama := SurfaceTool.new()
	grama.begin(Mesh.PRIMITIVE_TRIANGLES)
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
			var fachada := (edge + RECUO_FACHADA + t.y) * side
			var dentro := fachada - GRAMA_LARGURA * side
			var g := inicio
			while g < minf(t.x, track.length) - 0.1:
				var g1 := minf(g + GRAMA_PASSO, minf(t.x, track.length))
				if not Cidade.na_boca(cruzamentos, (g + g1) * 0.5, side):
					var acima := Vector3.UP * 0.04
					var cantos: Array[Vector3] = [
						track.point(g, dentro) + acima,
						track.point(g, fachada) + acima,
						track.point(g1, fachada) + acima,
						track.point(g1, dentro) + acima,
					]
					_quad_deitado(grama, cantos, [])
				g = g1
		inicio = t.x
	var malha := ArrayMesh.new()
	grama.commit(malha)
	if malha.get_surface_count() > 0:
		malha.surface_set_material(0, RoadTrack.material_liso(COR_GRAMA))
		var faixa := MeshInstance3D.new()
		faixa.name = "Grama"
		faixa.mesh = malha
		faixa.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		props.add_child(faixa)


## O que mora na faixa de servico, 3 m depois do meio-fio: palmeira em grupo
## de duas ou tres e arvore de copa debrucada sobre a pista (V16), cacamba e
## mupi (V17). Um ponto a cada 30 a 65 m de cada lado, e uma coisa so por
## ponto: sorteadas juntas, a cacamba nunca cai dentro do tronco da palmeira.
## Mais denso que isso a avenida vira bosque e esconde a fachada, que e o
## referencial de velocidade; menos e a copa por cima da camera vira acidente,
## e nao ritmo.
func _monta_faixa_de_servico(
	side: float, cruzamentos: Array[Vector2], rua: RandomNumberGenerator, props: Node3D
) -> void:
	# Atras da linha dos postes (0,6 m) e da do rival que terminou a corrida
	# (1,6 m).
	var lateral := (
		(RoadTrack.half_width() + RoadTrack.SHOULDER + RoadTrack.FAIXA_SERVICO * 0.5) * side
	)
	var o := rua.randf_range(20.0, 60.0)
	while o < track.length - 20.0:
		var sorteio := rua.randf()
		var quantas := rua.randi_range(2, 3)
		var para_a_pista := track.sample_basis(o).x * -side
		var ao_longo := -track.sample_basis(o).z
		if Cidade.na_boca(cruzamentos, o, side) or _perto_de_expressa(o):
			pass
		elif sorteio < ARVORE_COPA:
			props.add_child(Arvore.criar(Arvore.Tipo.COPA, track.point(o, lateral), para_a_pista))
		elif sorteio < ARVORE_COPA + PALMEIRAS:
			for i in quantas:
				var aqui := o + i * PALMEIRA_PASSO
				if not Cidade.na_boca(cruzamentos, aqui, side):
					var pe := track.point(aqui, lateral)
					props.add_child(Arvore.criar(Arvore.Tipo.PALMEIRA, pe, para_a_pista))
		elif sorteio < ARVORE_COPA + PALMEIRAS + CACAMBA:
			var tipo := Mobiliario.Tipo.CACAMBA
			props.add_child(Mobiliario.criar(tipo, track.point(o, lateral), para_a_pista))
		else:
			# O mupi encara quem vem: a foto acesa e para o transito ler.
			var tipo := Mobiliario.Tipo.MUPI
			props.add_child(Mobiliario.criar(tipo, track.point(o, lateral), -ao_longo))
		o += rua.randf_range(SERVICO_PASSO.x, SERVICO_PASSO.y)


## O losango amarelo antes de cada curva (V17), do lado direito, encarando
## quem vem. A curva e medida como na prova visual: quanto o rumo gira em
## `CURVA_JANELA` metros. A placa fica `CURVA_AVISO` antes de onde a curva
## comeca, no andavel, depois da linha dos postes.
func _monta_placas(cruzamentos: Array[Vector2], props: Node3D) -> void:
	var lateral := RoadTrack.half_width() + 1.4
	var na_curva := false
	var o := 0.0
	while o < track.length - CURVA_JANELA:
		var giro := giro_em(track, o)
		var agora := absf(giro) > CURVA_LIMIAR
		if agora and not na_curva and o >= CURVA_AVISO:
			var aqui := o - CURVA_AVISO
			if not Cidade.na_boca(cruzamentos, aqui, 1.0):
				# Guinada positiva gira para a esquerda.
				var tipo := (
					Mobiliario.Tipo.PLACA_ESQUERDA if giro > 0.0 else Mobiliario.Tipo.PLACA_DIREITA
				)
				var quem_vem := track.sample_basis(aqui).z
				props.add_child(Mobiliario.criar(tipo, track.point(aqui, lateral), quem_vem))
		na_curva = agora
		o += 10.0


## O semaforo suspenso na retencao de cada cruzamento, na mao de quem vem, e
## o portico da placa verde 30 m antes, em cruzamento sim, cruzamento nao
## (V18). Nada sorteado: a placa diz o destino da vez na lista.
func _monta_portais(cruzamentos: Array[Vector2], props: Node3D) -> void:
	var mat := _materiais_de_semaforo()
	var boca := RUA_LARGURA * 0.5
	for i in cruzamentos.size():
		var c := cruzamentos[i]
		# Na rua da esquina da expressa a avenida nao para: nem semaforo, nem
		# a placa que vem antes dele.
		if track.e_esquina(c):
			continue
		var retencao := (
			c.x
			- boca
			- RoadTrack.ZEBRA_ESQUINA
			- RoadTrack.ZEBRA_COMPRIMENTO
			- RoadTrack.RETENCAO_RECUO
		)
		props.add_child(Portal.semaforo(track.transform_at(retencao, Portal.LATERAL), mat))
		var antes := retencao - PORTICO_ANTES
		if i % 2 == 0 and antes > 0.0 and not Cidade.na_boca(cruzamentos, antes, 1.0):
			var destinos: Array = Portal.DESTINOS[(i / 2) % Portal.DESTINOS.size()]
			var onde := track.transform_at(antes, Portal.LATERAL)
			props.add_child(Portal.placa(onde, mat, destinos))


## Quanto o rumo da pista gira de `o` ate `CURVA_JANELA` metros adiante, em
## radianos. Positivo e para a esquerda, como a guinada.
static func giro_em(pista: RoadTrack, o: float) -> float:
	var a := -pista.sample_basis(o).z
	var b := -pista.sample_basis(o + CURVA_JANELA).z
	return wrapf(atan2(b.x, b.z) - atan2(a.x, a.z), -PI, PI)


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
	props: Node3D,
	rua: RandomNumberGenerator,
	tipo: Predio.Tipo,
	pe: Vector3,
	olha: Vector3,
	obra: int = SEM_OBRA
) -> void:
	# A obra gasta os mesmos dois sorteios do predio que ela substitui: o que
	# vem depois na avenida e igual, com ou sem obra.
	var predio: MeshInstance3D
	var caixa: AABB
	if obra == SEM_OBRA:
		predio = Predio.criar(tipo, rua.randf(), rua.randf())
		caixa = Predio.malha(tipo).get_aabb()
	else:
		predio = Predio.criar_obra(obra as Predio.Obra, rua.randf(), rua.randf())
		# O colisor e o corpo da torre: o andaime sai 2,2 m dela, sobre a
		# calcada, e ninguem anda de moto num tubo ali.
		caixa = Predio.malha(Predio.Tipo.TORRE).get_aabb()
	props.add_child(predio)
	# Base 1 m abaixo da pista: na rampa o predio nao pode ficar com o pe no ar.
	predio.global_transform = Transform3D(Basis.looking_at(olha, Vector3.UP), pe + Vector3.DOWN)
	if obra != SEM_OBRA:
		_guindaste_da_obra(predio, hash([rua.seed, pe.snapped(Vector3.ONE)]))
	var fundo := caixa.end.z
	_colisor(
		predio,
		AABB(
			Vector3(caixa.position.x, 0.0, -fundo), Vector3(caixa.size.x, caixa.size.y, fundo * 2.0)
		)
	)


## Qual obra, se for, entra no lugar da torre que cai em `o` do lado `side`.
## Nao sorteia: o `rua` e sequencial, e um numero a mais dele mudaria a cidade
## inteira dali para frente. Sai de um hash da semente e da posicao, que e
## estavel por predio.
static func fase_de_obra(semente: int, tipo: Predio.Tipo, o: float, side: float) -> int:
	if tipo != Predio.Tipo.TORRE:
		return SEM_OBRA
	var h := hash([semente, int(o), int(side)])
	if posmod(h, OBRA_UMA_EM) != 0:
		return SEM_OBRA
	return posmod(h >> 8, Predio.Obra.size())


## O guindaste no alto da obra, com a lanca virada para onde o hash mandar.
func _guindaste_da_obra(predio: Node3D, h: int) -> void:
	var g := Guindaste.criar(OBRA_MASTRO, OBRA_LANCA, _giro(h))
	g.position = Vector3(OBRA_GUINDASTE.x, Predio.OBRA_LAJE_DO_TOPO, OBRA_GUINDASTE.z)
	predio.add_child(g)


## Oito direcoes para a lanca: guindaste parado na obra nao aponta sempre para
## o mesmo lado, e oito bastam para dois vizinhos nao se alinharem.
static func _giro(h: int) -> float:
	return posmod(h >> 4, 8) * TAU / 8.0


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
			# Na rua da esquina da expressa ele comeca depois do chanfro da
			# quina, do lado dela: e por ali que a mao contraria vira.
			var contraria := _mao_contraria_em(c, side)
			var lado_da_contraria := signf(r.dot(-track.sample_basis(c.x).z * contraria))
			for lado: float in [-1.0, 1.0]:
				var borda := chao + r * lado * (meio + RoadTrack.MEIO_FIO * 0.5)
				if contraria != 0.0 and lado == lado_da_contraria:
					var raio := RoadTrack.ESQUINA_RAIO
					_faixa(
						meio_fio, borda + d * raio, d, r, RoadTrack.MEIO_FIO, RUA_COMPRIMENTO - raio
					)
				else:
					_faixa(meio_fio, borda, d, r, RoadTrack.MEIO_FIO, RUA_COMPRIMENTO)
			# Faixa de pedestre na linha da calcada, com a mesma zebra e a mesma
			# retencao da avenida, so na mao de quem chega. Fica a
			# `ZEBRA_ESQUINA` do asfalto da avenida, como a da avenida fica da
			# boca da rua: e por ali que passa quem anda pela calcada. Na rua da
			# esquina da expressa nao ha calcada de um lado, ninguem atravessa e
			# ninguem para: nem uma nem outra.
			var zebra := RoadTrack.ZEBRA_ESQUINA
			var retencao := zebra + RoadTrack.ZEBRA_COMPRIMENTO + RoadTrack.RETENCAO_RECUO
			if contraria == 0.0:
				for x in RoadTrack.listras_da_zebra(RUA_LARGURA):
					var p := chao + r * x + d * zebra
					_faixa(tinta, p, d, r, RoadTrack.ZEBRA_LISTRA, RoadTrack.ZEBRA_COMPRIMENTO)
				var linha := chao + d * (retencao + RoadTrack.RETENCAO_LARGURA * 0.5)
				_faixa(tinta, linha, r, d, RoadTrack.RETENCAO_LARGURA, meio)
			# O fundo da rua e a fachada de um predio da quadra de tras, olhando
			# para a avenida: rua que acaba no vazio mostra a borda do mundo, e
			# predio no fundo e o "T" que toda rua de bairro tem.
			var tipo := _tipo_de_predio(rua.randf_range(6.0, 23.0))
			var pe := centro + d * (RUA_COMPRIMENTO - 2.0 + Predio.frente(tipo))
			_predio(props, rua, tipo, pe, -d)
			# Tracejado do meio da rua, um carro depois da retencao; na rua da
			# esquina, desde o fim do chanfro.
			var t := retencao + 5.0 if contraria == 0.0 else RoadTrack.ESQUINA_RAIO + 1.0
			while t < RUA_COMPRIMENTO - 3.0:
				_faixa(tinta, chao + d * t, d, r, 0.14, 2.0)
				t += 4.5

			# Metade das ruas chega na avenida e metade sai dela. Quem chega
			# para no vermelho - a avenida esta no verde, e e o jogador que
			# passa. Rua de saida nao tem semaforo nem fila: ninguem espera
			# para sair da avenida.
			# Na rua da esquina da expressa, nem um nem outro: ali nao ha
			# retencao, e a fila parava no caminho da mao contraria.
			if rua.randf() < 0.5 or contraria != 0.0:
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
	Quebravel.com_colisor(raiz, Vector3(0.4, 4.4, 0.4))
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
