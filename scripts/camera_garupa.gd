class_name CameraGarupa
extends RefCounted
## O cinegrafista na garupa de outra moto: a simulacao por tras do modo GARUPA.
##
## A camera nao e presa na moto do jogador. Ela e segurada por alguem em outro
## veiculo, que tem a propria velocidade (fica para tras no talo, encosta na
## freada), anda na rua (a altura segue o chao embaixo DELA) e mira firme no
## piloto. Copiar so os numeros - distancia, FOV - sem esse modelo da uma
## perseguicao colada, e nao a filmagem de garupa. Ver
## docs/REFERENCIA_CAMERA_GARUPA.md.
##
## Mora fora do `ChaseCamera` por dois motivos: e uma simulacao com estado
## proprio, e assim ela e testavel sem camera, sem arvore e sem tela. O
## `ChaseCamera` so preenche uma `Leitura` e aplica o `Transform3D` que sai.
##
## O cinegrafista vive em coordenadas de pista `(s, l)`, como o transito, e
## pelo mesmo motivo: andar na curva e de graca, e ele nunca sai da rua nem
## fura o chao. O invariante "so o jogador roda fisica" fica intacto.

## Do centro da moto ao eixo traseiro, em metros. Sai de `EIXO_TRASEIRO` em
## `arte/entregador.py` (y = -0,66 no Blender, que e +Z no Godot). O contato
## do pneu traseiro e o pino do enquadramento: tudo se mede a partir dele.
const EIXO_TRASEIRO: float = 0.66

## Ganho da folga na velocidade desejada (1/s). E a constante de tempo de
## ~0,8 s com que a distancia volta ao alvo depois de qualquer empurrao: mais
## rapido vira braco de metal, mais lento a moto foge da tela no corredor.
const GANHO_FOLGA: float = 1.2

## A trava de longe, em metros. Mais que isso o piloto vira um ponto no meio
## da rua e o modo deixa de ser garupa - na largada do talo a camera chega aqui
## e volta pela aproximacao lenta.
const DISTANCIA_MAX: float = 12.0

## Onde a camera nasce e onde ela para quando o jogador cai, em metros. E o
## "longe" da abertura do video (~3,5 m): na volta a aproximacao lenta refaz o
## plano de abertura sozinha.
const DISTANCIA_LONGE: float = 4.0

## Quanto o contato traseiro pode pular entre dois quadros, alem do que a
## velocidade explica, antes de contar como teletransporte (largada, respawn
## depois da queda, reinicio). A moto mais rapida anda ~1,1 m num quadro de
## 60 Hz e isso ja esta descontado; 3 m e so o que nenhuma fisica faz.
const SALTO: float = 3.0

## Mira: quanto a frente do contato traseiro, em metros. Poe o centro do
## quadro no banco, que e onde o video deixa (o capacete fica perto do topo).
const MIRA_A_FRENTE: float = 0.3

## A camera nunca mais perto que isto do asfalto, em metros, nem embaixo dela
## nem 1 m a frente: no fundo de um vale, com a moto ja subindo, a mira
## inclinada faria a lente cortar o chao da frente.
const ALTURA_MINIMA: float = 0.5

## Quanto da beirada da calcada a camera respeita, em metros. Alem disso ela
## entraria no mato e nos predios.
const MARGEM_CALCADA: float = 0.4

## Quao rapido a lateral da camera persegue o alvo (1/s): ~0,33 s. Solta o
## bastante para a moto escorregar na tela no corredor, firme o bastante para
## o pneu nao sair da faixa central.
const TAXA_LATERAL: float = 3.0

## Quanto dura uma troca de lado, em segundos, com `smoothstep`: nunca um
## degrau. No video cada troca leva ~1 s, sem corte.
const DURACAO_TROCA: float = 1.2
## De quanto em quanto tempo o cinegrafista troca de lado, em segundos. No
## video, de 2 a 12 s; o centro e so passagem, e dura pouco.
const INTERVALO_LADO := Vector2(6.0, 12.0)
const INTERVALO_CENTRO := Vector2(2.0, 3.0)
## Chance de a troca ir para o outro lado; o resto vai para o centro.
const CHANCE_OUTRO_LADO: float = 2.0 / 3.0

## Um carro a menos que isto, na lateral, do ponto da camera ocupa o ponto. Com
## meia largura de carro de 0,9 m, sobram 0,3 m entre a lente e a lataria.
const LATERAL_CARRO: float = 1.2
## Metade do comprimento do carro (`TrafficCar.SIZE.z`).
const MEIO_CARRO: float = 2.2
## Metade da largura do carro (`TrafficCar.SIZE.x`).
const MEIA_LARGURA_CARRO: float = 0.9
## Carro mais perto que isto da lateral do jogador nao passa por ele: ou o
## jogador desvia (e a lateral dele muda), ou bate (e ele para). So carro que
## pode passar ao lado da moto chega na camera - sem isto, seguir um carro na
## mesma faixa mandava o cinegrafista para o centro sem motivo.
const LATERAL_PASSA: float = 1.25
## Com quanto tempo de antecedencia o cinegrafista sai do caminho de um carro,
## em segundos. A troca leva 1,2 s, mas na metade dela a lente ja saiu da
## faixa do carro.
const ANTECEDENCIA: float = 0.8
## Quanto o cinegrafista recua quando os dois lados estao ocupados, em metros.
## No centro ele fica atras da moto, e mais longe o carro que passa ao lado
## nao entra no quadro pela lente.
const RECUO_BLOQUEADO: float = 1.0


## O que o cinegrafista enxerga do jogador num quadro.
##
## Valores soltos, e nao o `PlayerBike`: a moto so tem posicao global dentro da
## arvore, e os testes dirigem o cinegrafista sem arvore nenhuma.
class Leitura:
	extends RefCounted
	## Metros de pista do contato do pneu traseiro.
	var s: float = 0.0
	## Lateral do jogador, metros do eixo (+ = direita).
	var l: float = 0.0
	## Velocidade ao longo da pista, m/s. Negativa na contramao.
	var velocidade: float = 0.0
	## Inclinacao da moto, radianos (+ = direita).
	var inclinacao: float = 0.0
	## Contato do pneu traseiro com o chao, no mundo.
	var contato: Vector3 = Vector3.ZERO
	## Para onde a moto aponta, horizontal e unitario.
	var frente: Vector3 = Vector3.FORWARD
	var caido: bool = false
	## Carros do transito: `(s, l, velocidade)` de cada um.
	var carros: Array[Vector3] = []


var tuning: BikeTuning
var track: RoadTrack

## Metros de pista andados pelo cinegrafista.
var s_c: float = 0.0
## Lateral do cinegrafista, metros do eixo.
var l_c: float = 0.0
## Velocidade do cinegrafista ao longo da pista, m/s.
var v_c: float = 0.0
## Para onde a camera olha, no mundo. Exposto para teste e diagnostico.
var mira: Vector3 = Vector3.ZERO

var _iniciado: bool = false
var _s_jogador: float = 0.0

## O lado, de -1 (esquerda) a +1 (direita), com o centro em 0. Durante a troca
## ele anda de `_lado_de` para `_lado_para` em `DURACAO_TROCA`.
var _lado: float = 1.0
var _lado_de: float = 1.0
var _lado_para: float = 1.0
var _troca_t: float = DURACAO_TROCA
var _ate_trocar: float = 0.0
var _recuo: float = 0.0
## RNG proprio, semeado da semente do mundo: a mesma corrida, a mesma camera.
var _rng := RandomNumberGenerator.new()


func _init(a_tuning: BikeTuning, a_track: RoadTrack, semente: int = 0) -> void:
	tuning = a_tuning
	track = a_track
	_rng.seed = semente
	# Comeca a direita, rente ao meio-fio, como a abertura do video.
	_ate_trocar = _rng.randf_range(INTERVALO_LADO.x, INTERVALO_LADO.y)


## Le a moto do jogador. So vale com ela na arvore: usa a posicao global.
static func ler(moto: PlayerBike, transito: Array[TrafficCar] = []) -> Leitura:
	var leitura := Leitura.new()
	var frente := Vector3(sin(moto.heading), 0.0, cos(moto.heading))
	leitura.s = moto.track_offset - EIXO_TRASEIRO
	leitura.l = moto.track_lateral
	# A velocidade que importa e a de metros de PISTA, que e a moeda do
	# cinegrafista: de lado a moto anda menos pista que o velocimetro diz, na
	# contramao anda para tras, e no lado de fora de uma curva cada metro de
	# pista e mais que um metro de asfalto. Com o velocimetro puro, a 50 m/s
	# num curvao a camera ganhava 1 m/s por segundo e ficava colada na trava.
	# Tudo no plano: a moto anda na horizontal, e a ladeira so encurtaria a conta.
	var antes := moto.track.point(moto.track_offset - 0.5, moto.track_lateral)
	var depois := moto.track.point(moto.track_offset + 0.5, moto.track_lateral)
	var passo := Vector3(depois.x - antes.x, 0.0, depois.z - antes.z)
	var metros_por_metro := maxf(passo.length(), 0.01)
	leitura.velocidade = moto.speed * frente.dot(passo / metros_por_metro) / metros_por_metro
	leitura.inclinacao = moto.lean
	# O visual da moto fica no chao (`PlayerBike._visual`), e e em volta do
	# chao que ela inclina: o contato nao anda com a inclinacao.
	leitura.contato = (
		moto.global_position + Vector3.DOWN * (PlayerBike.SIZE.y * 0.5) - frente * EIXO_TRASEIRO
	)
	leitura.frente = frente
	leitura.caido = moto.state == PlayerBike.State.CRASHED
	for carro in transito:
		leitura.carros.append(Vector3(carro.offset, carro.lateral, carro.speed))
	return leitura


## Para que lado o cinegrafista esta indo: -1, 0 ou +1.
func lado() -> float:
	return _lado_para


## Distancia de pista do cinegrafista ao contato traseiro, em metros.
func distancia() -> float:
	return _s_jogador - s_c


## Poe o cinegrafista longe, na velocidade do jogador. Na largada e depois de
## qualquer teletransporte: ele chega pela aproximacao lenta, como no video.
func reiniciar(leitura: Leitura) -> void:
	s_c = leitura.s - DISTANCIA_LONGE
	v_c = leitura.velocidade
	l_c = _lateral_alvo(leitura)
	_s_jogador = leitura.s
	_iniciado = true


## Poe o cinegrafista direto onde ele terminaria, sem respiro. Para o quadro
## congelado da prova visual: atraso que depende do relogio nao se compara.
func encaixar(leitura: Leitura) -> Transform3D:
	_lado = _lado_para
	_lado_de = _lado_para
	_troca_t = DURACAO_TROCA
	s_c = leitura.s - tuning.garupa_distancia
	v_c = leitura.velocidade
	l_c = _lateral_alvo(leitura)
	_s_jogador = leitura.s
	_iniciado = true
	return _pose(leitura)


func passo(delta: float, leitura: Leitura) -> Transform3D:
	var esperado := _s_jogador + leitura.velocidade * delta
	if not _iniciado or absf(leitura.s - esperado) > SALTO:
		reiniciar(leitura)
	_s_jogador = leitura.s
	_escolhe_lado(delta, leitura)
	_anda(delta, leitura)
	var alvo := _lateral_alvo(leitura)
	l_c = lerpf(l_c, alvo, 1.0 - exp(-TAXA_LATERAL * delta))
	l_c = _fora_dos_carros(_na_calcada(l_c), leitura)
	return _pose(leitura)


## O passo 2 do documento: tres quartos, e troca.
##
## A camera nao fica atras da roda: de lado, o fundo da rua aparece ao lado do
## piloto, que de outro jeito taparia exatamente o que vem pela frente.
func _escolhe_lado(delta: float, leitura: Leitura) -> void:
	_troca_t += delta
	_ate_trocar -= delta
	var t := clampf(_troca_t / DURACAO_TROCA, 0.0, 1.0)
	_lado = lerpf(_lado_de, _lado_para, smoothstep(0.0, 1.0, t))

	var livre_direita := _livre(1.0, leitura)
	var livre_esquerda := _livre(-1.0, leitura)
	_recuo = 0.0 if livre_direita or livre_esquerda else RECUO_BLOQUEADO

	# Carro no caminho, ou o lado caiu fora da calcada: troca na hora.
	if _lado_para != 0.0 and not _livre(_lado_para, leitura):
		if _livre(-_lado_para, leitura):
			_troca(-_lado_para)
		else:
			_troca(0.0)
		return
	if _ate_trocar > 0.0:
		return

	var livres: Array[float] = []
	if livre_esquerda:
		livres.append(-1.0)
	if livre_direita:
		livres.append(1.0)
	if _lado_para == 0.0:
		if livres.is_empty():
			# Os dois lados ocupados: segura o centro e olha de novo logo.
			_ate_trocar = 0.5
		else:
			_troca(livres[_rng.randi_range(0, livres.size() - 1)])
	elif _rng.randf() < CHANCE_OUTRO_LADO and livres.has(-_lado_para):
		_troca(-_lado_para)
	else:
		_troca(0.0)


## Comeca uma troca do lado de agora - mesmo no meio de outra - para `para`.
func _troca(para: float) -> void:
	_lado_de = _lado
	_lado_para = para
	_troca_t = 0.0
	var intervalo := INTERVALO_CENTRO if para == 0.0 else INTERVALO_LADO
	_ate_trocar = _rng.randf_range(intervalo.x, intervalo.y)


## O lado `lado` cabe na calcada e nenhum carro vai passar por ali.
func _livre(lado: float, leitura: Leitura) -> bool:
	var l := leitura.l + lado * tuning.garupa_lado
	if absf(l) > RoadTrack.sidewalk_limit() - MARGEM_CALCADA:
		return false
	for carro in leitura.carros:
		if absf(carro.y - leitura.l) < LATERAL_PASSA or absf(carro.y - l) >= LATERAL_CARRO:
			continue
		# Onde o carro esta em relacao a lente, e ate onde ele chega antes de
		# a troca tirar a lente do caminho.
		var fecha := maxf(v_c - carro.z, 0.0)
		var tras := carro.x - MEIO_CARRO - s_c
		var frente := carro.x + MEIO_CARRO - s_c
		if frente > -0.5 and tras < fecha * ANTECEDENCIA + 0.5:
			return false
	return true


## A ultima trava: a lente nunca dentro de um carro. Com `near = 0,1`, a tela
## viraria o interior da caixa. A troca de lado ja tira a camera do caminho
## com antecedencia; isto so pega o carro que trocou de faixa em cima dela.
func _fora_dos_carros(l: float, leitura: Leitura) -> float:
	var folga := MEIA_LARGURA_CARRO + 0.3
	for carro in leitura.carros:
		if absf(carro.x - s_c) > MEIO_CARRO + 0.3 or absf(l - carro.y) >= folga:
			continue
		var lado := 1.0 if l >= carro.y else -1.0
		l = carro.y + lado * folga
	return l


## O passo 1 do documento: a distancia, pela velocidade propria.
##
## A posicao anda ANTES da folga ser medida. Na ordem contraria a camera
## media a folga com o jogador ja no quadro novo e ela ainda no velho, e
## estabilizava `velocidade * delta` mais perto que o alvo: 0,67 m a 40 m/s,
## quase metade da distancia inteira.
func _anda(delta: float, leitura: Leitura) -> void:
	s_c += v_c * delta
	var v_j := leitura.velocidade
	# Travas rigidas, sem rampa: dentro da moto nunca, nem freando no talo.
	if leitura.s - s_c < tuning.garupa_distancia_min:
		s_c = leitura.s - tuning.garupa_distancia_min
		v_c = minf(v_c, v_j)
	elif leitura.s - s_c > DISTANCIA_MAX:
		s_c = leitura.s - DISTANCIA_MAX
		v_c = maxf(v_c, v_j)

	# Caido, o jogador para na hora e o cinegrafista nao: ele recua devagar ate
	# o longe e fica olhando. Na volta, a aproximacao refaz a abertura.
	var alvo := DISTANCIA_LONGE if leitura.caido else tuning.garupa_distancia + _recuo
	var folga := (leitura.s - s_c) - alvo
	var v_desejada := v_j + minf(folga * GANHO_FOLGA, tuning.garupa_aproximacao)
	v_c += clampf(v_desejada - v_c, -tuning.garupa_freio * delta, tuning.garupa_acel * delta)
	# Para tras so na velocidade de aproximacao: e a mao recuando para abrir o
	# plano, nao uma moto de re.
	v_c = maxf(v_c, minf(v_j, 0.0) - tuning.garupa_aproximacao)


func _lateral_alvo(leitura: Leitura) -> float:
	return _na_calcada(leitura.l + _lado * tuning.garupa_lado)


func _na_calcada(l: float) -> float:
	var limite := RoadTrack.sidewalk_limit() - MARGEM_CALCADA
	return clampf(l, -limite, limite)


func _pose(leitura: Leitura) -> Transform3D:
	# A altura sai do chao embaixo do cinegrafista, e nao do da moto: na crista
	# de uma ladeira ele sobe e desce no tempo dele, e a moto some e volta no
	# horizonte. E feel, e e de graca.
	var chao := track.point(s_c, l_c)
	var posicao := chao + Vector3.UP * tuning.garupa_altura
	var chao_a_frente := track.point(s_c + 1.0, l_c).y
	posicao.y = maxf(posicao.y, maxf(chao.y, chao_a_frente) + ALTURA_MINIMA)

	# A mira nao e suavizada, e usa o "cima" do MUNDO: e o pino do
	# enquadramento. A roda fica parada na tela e o tronco tomba por cima dela.
	# Toda a suavizacao mora na posicao - o contrario da perseguicao, que
	# suaviza as duas e deixa o pneu nadar.
	mira = (
		leitura.contato + leitura.frente * MIRA_A_FRENTE + Vector3.UP * tuning.garupa_mira_altura
	)
	var base := Basis.looking_at(mira - posicao, Vector3.UP)
	return Transform3D(base, posicao)
