class_name Entregador
extends Node3D
## O ator: a moto e quem pilota, de `assets/entregador`, posados a cada passo.
##
## Mora no no `Visual` de `PlayerBike` e `RivalBike`, com a origem no chao,
## embaixo do centro da moto. Quem inclina a moto nas curvas e o `Visual`; este
## no cuida do que acontece DENTRO da moto: roda girando, guidao, suspensao, o
## piloto jogado pela freada, o soco, a pancada, o tombo e, de noite, o farol.
##
## Nada aqui e clipe de animacao. O modelo e de pecas rigidas com a origem na
## articulacao (`arte/entregador.py`), e cada pose sai do estado da moto:
## velocidade, acelerador, esterco, inclinacao e se caiu. Pose lida do estado
## nao desencontra da fisica - a roda gira na velocidade em que a moto anda, o
## garfo afunda no passo em que ela freia e o pe desce no passo em que ela para.
##
## O que nao e estado continuo chega por evento: `socar` e `levar_golpe`,
## chamados no mesmo passo em que o corpo abre a hitbox ou leva o empurrao.
##
## A moto e uma de `Modelo`, e todas tem a mesma arvore de nos (ver o topo do
## `arte/xre300.py`): o ator le do proprio modelo o que muda de uma para outra
## - raio de cada roda, altura de cada eixo, onde ficam manopla e pedaleira -,
## e a mesma pose serve para todas. A moto e so visual: a fisica do corpo nao
## sabe qual esta montada.

## As motos que existem. A ordem e a de `CENAS` e `NOMES`.
enum Modelo { CG_160, XRE_300, PCX_160 }

const CENAS: Array[PackedScene] = [
	preload("res://assets/entregador/entregador.glb"),
	preload("res://assets/entregador/xre300.glb"),
	preload("res://assets/entregador/pcx160.glb"),
]
const NOMES: PackedStringArray = ["CG 160", "XRE 300", "PCX 160"]
const SHADER: Shader = preload("res://scripts/entregador.gdshader")
const ALBEDO: Texture2D = preload("res://assets/entregador/entregador_albedo.png")
const MASCARA: Texture2D = preload("res://assets/entregador/entregador_mascara.png")

## A cor pintada na textura em cada canal da mascara: a celula mais clara sob
## ele em `PALETA`, no `arte/entregador.py`. Mudou la, muda aqui - o
## `test_entregador.gd` le a textura e reprova se as duas divergirem.
const BAG_FABRICA := Color(0.82, 0.12, 0.10)
const CAMISA_FABRICA := Color(0.74, 0.11, 0.09)
const MOTO_FABRICA := Color(0.70, 0.11, 0.09)

## Quanto a camiseta escurece em relacao a cor do corredor. Pouco: nas T-poses
## e no sprite camiseta e bag sao a mesma cor, e um tom abaixo basta para a bag
## se separar dela, com o vivo escuro desenhando a borda.
const CAMISA_ESCURECE: float = 0.1

## Abaixo disto, em m/s, a moto conta como parada e o pe esquerdo desce. 1 m/s
## e passo de gente: acima disso quem pilota ja recolheu o pe.
const PARADO: float = 1.0
## Quanto tempo o pe leva para descer ou subir, em segundos. Mais rapido que
## isso o pe teleporta; mais lento, a moto arranca com o pe arrastando.
const TEMPO_DO_PE: float = 0.25
## Onde a bota esquerda pousa com a moto parada, no espaco do `Visual`: 40 cm
## para o lado, um pouco a frente do quadril, com o tornozelo a 7,5 cm do
## asfalto (a altura da bota). A perna de 0,88 m alcanca dali com 3 cm de
## folga, que e como entregador de verdade fica numa CG: na ponta do pe.
const PE_NO_CHAO := Vector3(-0.40, 0.075, 0.05)
## Quanto a moto deita para o lado do pe no chao, em graus, por modelo. A XRE
## tem o banco 6 cm mais alto, e quem para nela faz o que se faz de verdade:
## deita mais a moto para o pe chegar no mesmo asfalto. Com 7 graus a perna
## esticava inteira e a bota ficava pendurada a 5 cm do chao. A PCX e o
## contrario: banco 4 cm mais baixo que o da CG, e scooter parada fica quase
## em pe - a bota chega no asfalto com o joelho ainda dobrado.
const INCLINA_PARADO: Array[float] = [7.0, 10.0, 5.0]

## Velocidade, em m/s, em que os joelhos terminam de fechar no tanque. 15 m/s
## sao 54 km/h, um terco do teto: joelho aberto e coisa de manobra, nao de reta.
const JOELHO_FECHA: float = 15.0
## Para que lado o joelho aponta, aberto e fechado: e o polo do IK da perna, o
## componente lateral de um vetor que aponta para a frente. Fechado nao e zero:
## o tanque da CG tem 36 cm, e joelho no meio da moto atravessa a lata.
const JOELHO_ABERTO: float = 0.9
const JOELHO_FECHADO: float = 0.3
## Quanto o joelho de dentro da curva abre, por radiano de inclinacao. E pouco,
## de proposito: piloto de CG nao pendura o joelho, so solta a perna.
const JOELHO_NA_CURVA: float = 0.6

## Velocidade, em m/s, em que o tronco deita o maximo. Perto do teto (~49 m/s)
## e de proposito: deitar inteiro e o que se faz no talo, nao em cruzeiro.
const DEITA: float = 35.0
## Tronco em graus, + para tras: sentado, no talo e com o pe no chao. Como no
## video, segue sentado a 128 km/h (o modelo ja tem 14): so se encolhe.
const TRONCO_SENTADO: float = 2.0
const TRONCO_DEITADO: float = -3.0
const TRONCO_PE_NO_CHAO: float = 6.0
## Quanto do angulo da curva o tronco deita a mais que a moto. Quem pilota
## acompanha a moto e poe um pouco do corpo para dentro, e e esse pouco que
## separa piloto de boneco colado no banco.
const TRONCO_NA_CURVA: float = 0.12

## Quanto o guidao vira com o esterco inteiro, em graus, parado e a partir de
## 14 m/s. Em velocidade a curva sai da inclinacao, como no `PlayerBike`.
const ESTERCO_DEVAGAR: float = 20.0
const ESTERCO_RAPIDO: float = 4.0
## Quanto do esterco o tronco acompanha, girando os ombros: sem isso, com o
## guidao no batente, a manopla de fora foge do braco.
const TRONCO_SEGUE_GUIDAO: float = 0.5

## A cabeca procura o horizonte: desfaz esta fracao da inclinacao da moto. E
## o que o pescoco de quem pilota faz sozinho, e o que faz a curva parecer
## pilotada e nao a moto e o boneco tombando juntos.
const CABECA_NIVELA: float = 0.35
## E olha para dentro da curva, por radiano de inclinacao: se olha para onde
## se vai, nao para onde a moto aponta.
const CABECA_OLHA_CURVA: float = 0.45

## --- Suspensao ---
##
## As rodas nunca saem do asfalto: o que se mexe e a massa suspensa (quadro,
## motor, tanque e quem esta sentado), e o garfo e a balanca acompanham por
## conta. Dois numeros por passo - quanto a frente e a traseira afundam, em
## metros - e o resto e geometria.

## Quanto cada eixo pode afundar (y) e esticar (x), em metros a partir da
## posicao de repouso, que ja e a moto com o piloto em cima. A CG tem 13 cm de
## curso na frente e 10,5 atras; um terco disso e o que o peso parado ja come.
const CURSO_FRENTE := Vector2(-0.04, 0.09)
const CURSO_TRAS := Vector2(-0.04, 0.07)
## Frequencia natural (Hz) e fracao do amortecimento critico de cada eixo.
## Moto de rua fica perto de 2 Hz; abaixo de 0,5 de amortecimento a frente
## passa do ponto e volta depois da freada, que e o balanco que le como mola.
const FREQ_FRENTE: float = 1.9
const FREQ_TRAS: float = 1.7
const AMORTECE_FRENTE: float = 0.35
const AMORTECE_TRAS: float = 0.42
## Mergulho da frente e agachada da traseira com a aceleracao, em metros no
## limite. A conta passa por `tanh`: o freio do jogo e de 30 m/s2, tres vezes o
## de uma CG, e linear ele bateria o garfo no batente a cada freada.
const MERGULHO: float = 0.085
const AGACHA: float = 0.03
## Aceleracao, em m/s2, em que o mergulho chega a 76% do limite. 20 e o meio
## do caminho entre a freada de verdade (8) e a do jogo (30).
const ACELERACAO_REF: float = 20.0
## Metros que os dois eixos afundam por m/s2 de aceleracao vertical: o peso
## dobrado na curva, o pouso do salto, a lombada da ladeira. 3 mm e o que a
## mola da CG cede por m/s2 com 230 kg em cima.
const PESO: float = 0.003
## Ondulacao do asfalto, em metros. Comprimento de onda de 7 e 18 m: e o
## sobe-e-desce que a massa suspensa sente; o que e mais curto que isso o pneu
## e a mola engolem, e na tela so viraria tremedeira.
const ASFALTO: float = 0.006

## --- O corpo de quem pilota ---
##
## O tronco e uma massa presa por mola no quadril: a freada joga ele para a
## frente, a arrancada para tras, o pouso para baixo e a troca brusca de lado
## deixa ele para tras um instante. Os bracos dobram e esticam sozinhos,
## porque as maos continuam presas na manopla pelo IK.

## Frequencia (Hz) e amortecimento da massa. 2 Hz e o tronco de quem esta
## firme no guidao; mais mole que isso, o piloto vira boneco de posto.
const MASSA_FREQ: float = 2.0
const MASSA_AMORTECE: float = 0.4
## Quanto o tronco escorrega para a frente na freada cheia, em metros na
## altura dos ombros. 11 cm sao uns 13 graus.
const MASSA_FRENTE: float = 0.11
## Metros de atraso do tronco por rad/s2 de aceleracao da inclinacao. Na
## troca de lado mais rapida do jogo (~25 rad/s2), uns 7 cm.
const MASSA_ROLAGEM: float = 0.003
## Metros que o tronco desce por m/s2 de aceleracao vertical.
const MASSA_PESO: float = 0.004
## A distancia do quadril aos ombros, para virar deslocamento em angulo.
const TRONCO_ALAVANCA: float = 0.45

## --- O soco ---
##
## O braco do lado solta a manopla, arma na frente do peito e abre para o lado
## na altura do capacete de quem esta ao lado. A cabeca vira para o alvo antes
## da mao sair: e o "olhar o lado" que diz para quem joga de onde vem o golpe.
## O tempo e o da hitbox (`punch_windup`, `punch_active`, `punch_cooldown`),
## entao o braco esta esticado exatamente quando o soco pode acertar.

## Onde o punho fica armado e onde ele chega, no espaco do tronco, com X
## espelhado pelo lado. Esticado esta fora do alcance de proposito: o IK estica
## o braco reto apontando para la, que e o soco no fim do curso.
const SOCO_ARMADO := Vector3(0.06, 0.52, -0.26)
const SOCO_ESTICADO := Vector3(1.1, 0.52, -0.10)
## Quanto o tronco gira para tras armando e para o lado batendo, e quanto ele
## deita para o lado do golpe, em graus. E de onde sai a forca do soco.
const SOCO_ARMA: float = 14.0
const SOCO_BATE: float = 22.0
const SOCO_DEITA: float = 14.0
## Graus que a cabeca vira para o lado do alvo.
const SOCO_OLHA: float = 55.0
## Fracao do tempo ativo da hitbox que o braco leva para esticar inteiro. O
## resto ele fica esticado: e o quadro que o olho guarda.
const SOCO_ESTICA: float = 0.6

## --- A pancada ---

## Velocidade, em m/s, que o tronco ganha para o lado do empurrao.
const GOLPE_EMPURRA: float = 1.8
## Velocidade de giro, em rad/s, que a cabeca ganha: vira para longe do soco.
const GOLPE_CABECA: float = 9.0
## A moto treme no guidao depois da pancada: graus, Hz e quanto dura, em
## segundos ate cair para 37%.
const BAMBOLEIO: float = 6.0
const BAMBOLEIO_HZ: float = 5.0
const BAMBOLEIO_TEMPO: float = 0.35
## Frequencia (Hz) e amortecimento da mola do pescoco.
const CABECA_FREQ: float = 3.5
const CABECA_AMORTECE: float = 0.3

## --- A queda ---

## O tombo da moto: angulo e onde fica o pivo, metros para o lado da queda.
## Tombar em volta do centro enterraria meia moto no asfalto; em volta da
## lateral ela deita em cima do lado que bateu no chao.
const QUEDA: float = 85.0
const QUEDA_PIVO: float = 0.3
const TEMPO_DA_QUEDA: float = 0.3
## Segundos que a moto leva girando deitada ate parar de rodar. Mais que o
## tombo: ela cai de uma vez e o giro vem do deslize, que demora a morrer.
const TEMPO_DO_GIRO: float = 0.9
## O piloto e arremessado por cima do guidao: esta fracao da velocidade vai
## com ele, ate o teto, mais um impulso para cima e para o lado do tombo. O
## teto e o que segura o corpo dentro da tela: a camera fica com a moto, que
## desliza bem menos que isso.
const ARREMESSO: float = 0.4
const ARREMESSO_MAX: float = 9.0
const ARREMESSO_CIMA: float = 3.5
const ARREMESSO_LADO: float = 1.2
## Gravidade do voo, em m/s2. Mais que a da Terra e menos que a da moto (26):
## com 9,8 o piloto flutua; com 26, nao da tempo de ver o voo.
const GRAVIDADE: float = 14.0
## Desaceleracao de corpo arrastando no asfalto, em m/s2.
const ATRITO_NO_CHAO: float = 8.0
## Quanto tempo o corpo leva para largar a moto e abrir os bracos.
const TEMPO_DE_SOLTAR: float = 0.15

static var _imagem_da_paleta: Image

## Qual moto esta montada. Troca por `trocar_modelo`.
var modelo: int = Modelo.CG_160
## Se este e o corredor que a camera segue: o borrao de velocidade passa em
## volta dele e nao nele (`foco.gdshader`). E do ator, e nao do `PlayerBike`,
## porque a camera pode seguir qualquer um, e qualquer moto montada tem de
## sair marcada inteira, disco da roda lisa inclusive.
var foco: bool = false:
	set(valor):
		foco = valor
		Foco.marcar(_modelo, foco)
		_sprite.marcar_foco(foco)
## Desenhado em sprite (`AtorSprite`) no lugar do modelo 3D. O modelo segue
## montado e posado: ele lanca a sombra, e e ele que aparece no tombo, que as
## folhas ainda nao desenham.
var sprite: bool = false:
	set(valor):
		if valor == sprite:
			return
		sprite = valor
		_mostra_sprite()

var _modelo: Node3D
var _material: ShaderMaterial
var _farol := FarolDaMoto.new()
var _sprite := AtorSprite.new()
var _cores: Array[Color] = [BAG_FABRICA, CAMISA_FABRICA, MOTO_FABRICA]
## Transformacao de repouso de cada no do modelo. A posicao de cada filho e o
## osso do pai, e e daqui que o IK tira o comprimento de braco e perna.
var _repouso: Dictionary[Node3D, Transform3D] = {}
var _moto: Node3D
var _suspenso: Node3D
var _balanca: Node3D
var _garfo: Node3D
var _piloto: Node3D
## Traseira e dianteira, nessa ordem, e o raio e o giro de cada uma: na XRE a
## da frente e aro 21 e a de tras 18, e com um raio so uma das duas giraria
## mais devagar do que a moto anda.
var _rodas: Array[Node3D] = []
var _raios: Array[float] = [0.3, 0.3]
var _giros: Array[float] = [0.0, 0.0]
## Altura de cada eixo em repouso, no espaco do `Moto`, na mesma ordem: e onde
## o eixo tem que continuar, com a moto afundando ou nao.
var _altura_eixo: Array[float] = [0.31, 0.31]
var _entre_eixos: float = 1.32
var _direcao: Node3D
var _eixo_direcao: Vector3
var _amortecedores: Array[Node3D] = []
var _molas: Array[Node3D] = []
## Por amortecedor: a direcao de cima para baixo em repouso e o comprimento.
var _eixos_amortecedor: Array[Vector3] = []
var _comprimentos_amortecedor: Array[float] = []
var _tronco: Node3D
var _cabeca: Node3D
## Por lado, esquerdo e direito: [raiz, meio, ponta] de cada cadeia.
var _bracos: Array[Array] = []
var _pernas: Array[Array] = []
## Onde fica cada manopla, no espaco da direcao, e cada pedaleira, no do
## `Suspenso`.
var _manoplas: Array[Vector3] = []
var _pedaleiras: Array[Vector3] = []
## Pontos do corpo que nao podem entrar no asfalto, com o raio de cada um.
var _contatos: Array[Array] = []

var _esterco: float = 0.0
var _aperto: float = 0.0
var _deitado: float = 0.0
var _inclinacao: float = 0.0
## 1 = pe esquerdo no chao. Nasce 1: toda corrida comeca parada.
var _pe: float = 1.0
var _queda: float = 0.0
var _lado_queda: float = 1.0
var _giro_queda: float = 0.0
var _girado: float = 0.0
var _relogio: float = 0.0
var _passo: float = 1.0 / 60.0
var _rodado: float = 0.0
var _tremor := Tremor.new()
var _cotovelos := Cotovelos.new()
var _comandos := Comandos.new()
## Quanto o tremor afunda a frente (x) e a traseira (y) neste passo, em metros.
var _treme := Vector2.ZERO
## O borrao de cada roda em alta, na ordem de `_rodas`.
var _lisas: Array[RodaLisa] = []

## O que o ator mede do proprio movimento.
var _acel := Acelerometro.new()
## A ultima velocidade de pe: a do instante da queda, que e com a qual o
## piloto sai voando.
var _v_de_pe: float = 0.0

## Quanto a frente (x) e a traseira (y) afundaram, em metros, e a que
## velocidade.
var _susp := Vector2.ZERO
var _susp_v := Vector2.ZERO
var _massa := Vector3.ZERO
var _massa_v := Vector3.ZERO
## Giro (x) e rolagem (y) da cabeca solta pela pancada, em radianos.
var _pescoco := Vector2.ZERO
var _pescoco_v := Vector2.ZERO
var _bamboleio: float = 0.0

var _soco_lado: int = 0
## Segundos desde que o soco saiu; negativo e sem soco.
var _soco_t: float = -1.0
var _soco_preparo: float = 0.1
var _soco_ativo: float = 0.1
var _soco_total: float = 0.4

## O voo do piloto, no espaco deste no: onde esta, para onde vai, como gira.
var _voando: bool = false
var _voo := Transform3D.IDENTITY
var _voo_v := Vector3.ZERO
var _voo_giro := Vector3.ZERO
var _voo_t: float = 0.0
## Segundos desde que o corpo tocou o chao; negativo e ainda no ar.
var _no_chao_t: float = -1.0


func _ready() -> void:
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("albedo", ALBEDO)
	_material.set_shader_parameter("mascara", MASCARA)
	_material.set_shader_parameter("bag_fabrica", BAG_FABRICA)
	_material.set_shader_parameter("camisa_fabrica", CAMISA_FABRICA)
	_material.set_shader_parameter("moto_fabrica", MOTO_FABRICA)
	_aplica_cores()
	add_child(_sprite)
	_monta()


## Monta a moto `modelo` no lugar da que estiver aqui.
##
## Fora da arvore so anota: o `_ready` monta. Dentro, troca na hora, e a pose
## continua de onde estava - a roda segue girando, a suspensao segue onde
## estava -, porque o estado do ator e da moto andando, nao da malha.
func trocar_modelo(novo: int) -> void:
	novo = clampi(novo, 0, CENAS.size() - 1)
	if novo == modelo and _modelo != null:
		return
	modelo = novo
	if _material == null:
		return
	_monta()
	_posa()


func _monta() -> void:
	if _modelo != null:
		var velha := _modelo.get_parent()
		remove_child(velha)
		velha.free()
	_repouso.clear()
	_amortecedores.clear()
	_molas.clear()
	_eixos_amortecedor.clear()
	_comprimentos_amortecedor.clear()
	_bracos.clear()
	_pernas.clear()
	_manoplas.clear()
	_pedaleiras.clear()

	var cena := CENAS[modelo].instantiate() as Node3D
	add_child(cena)
	_modelo = cena.get_node("Entregador") as Node3D
	_prepara(_modelo)

	_moto = _no("Moto")
	_suspenso = _no("Suspenso")
	_balanca = _no("Balanca")
	_garfo = _no("Garfo")
	_piloto = _no("Piloto")
	_rodas = [_no("Roda_Traseira"), _no("Roda_Dianteira")]
	_lisas.clear()
	for i in 2:
		_raios[i] = (_rodas[i] as MeshInstance3D).get_aabb().size.y * 0.5
		_lisas.append(RodaLisa.new(_rodas[i], _paleta()))
	var eixo_tras := _no_relativo(_rodas[0], _moto)
	var eixo_frente := _no_relativo(_rodas[1], _moto)
	_altura_eixo = [eixo_tras.y, eixo_frente.y]
	_entre_eixos = eixo_tras.z - eixo_frente.z
	_farol.montar(_moto, _material, eixo_frente, _raios[1])
	_direcao = _no("Direcao")
	# O garfo gira em volta da reta cabeca do garfo-eixo, e nao da vertical: a
	# roda esterca sem sair do paralama. A bainha desliza na mesma reta.
	_eixo_direcao = _repouso[_garfo].origin.normalized()
	for lado: String in ["E", "D"]:
		var amortecedor := _no("Amortecedor_" + lado)
		var mola := _no("Mola_" + lado)
		_amortecedores.append(amortecedor)
		_molas.append(mola)
		var cima := _repouso[amortecedor].origin
		var baixo := _repouso[_balanca].origin + _repouso[mola].origin
		_eixos_amortecedor.append((baixo - cima).normalized())
		_comprimentos_amortecedor.append(cima.distance_to(baixo))

	_tronco = _no("Tronco")
	_cabeca = _no("Cabeca")
	for lado: String in ["E", "D"]:
		var mao := _no("Mao_" + lado)
		_bracos.append([_no("Braco_" + lado), _no("Antebraco_" + lado), mao])
		_manoplas.append(_no_relativo(mao, _modelo) - _no_relativo(_direcao, _modelo))
		var pe := _no("Pe_" + lado)
		_pernas.append([_no("Coxa_" + lado), _no("Canela_" + lado), pe])
		# O pe nao e filho do `Suspenso`, mas em repouso o `Suspenso` esta na
		# origem: a bota em repouso esta em cima da pedaleira dos dois jeitos.
		_pedaleiras.append(_no_relativo(pe, _modelo))

	# O capacete e a bag passam do pivo: o centro de cada um, no espaco do no.
	_contatos = [
		[_piloto, Vector3.ZERO, 0.13],
		[_cabeca, Vector3(0.0, 0.15, -0.03), 0.15],
		[_no("Bag"), Vector3(0.0, 0.04, 0.16), 0.17],
	]
	for i in 2:
		for no: Node3D in [_bracos[i][0], _bracos[i][1], _bracos[i][2]]:
			_contatos.append([no, Vector3.ZERO, 0.06])
		_contatos.append([_pernas[i][1], Vector3.ZERO, 0.07])
		_contatos.append([_pernas[i][2], Vector3.ZERO, 0.08])
	_comandos.montar(_modelo, FichaDaMoto.de(modelo))
	# A malha velha foi junto com a moto velha: a nova nasce sem a marca.
	Foco.marcar(_modelo, foco)
	_sprite.medir(_modelo, self, eixo_tras.z)
	_mostra_sprite()


## Veste o corredor de uma cor: bag e moto nela, camiseta um tom abaixo dela.
##
## Uma cor por corredor, e nao uma combinacao livre de tres: de longe, o que
## separa um entregador do outro e a mancha de cor, e "passei o amarelo" so
## funciona se o amarelo for amarelo da bag ao paralama.
func pintar(cor: Color) -> void:
	_cores = [cor, cor.darkened(CAMISA_ESCURECE), cor]
	_aplica_cores()


## O soco saiu para `lado` (-1 esquerda, 1 direita), com o tempo da hitbox:
## `preparo` ate ela abrir, `ativo` aberta e `total` ate poder socar de novo.
func socar(lado: int, preparo: float, ativo: float, total: float) -> void:
	if _voando:
		return
	_soco_lado = -1 if lado < 0 else 1
	_soco_t = 0.0
	_soco_preparo = maxf(preparo, 0.02)
	_soco_ativo = maxf(ativo, 0.02)
	_soco_total = maxf(total, _soco_preparo + _soco_ativo + 0.05)


## Levou um soco que empurra para `lado` (-1 esquerda, 1 direita): o tronco vai
## junto com o empurrao, a cabeca vira para longe do punho e o guidao treme.
func levar_golpe(lado: int) -> void:
	var s := -1.0 if lado < 0 else 1.0
	_massa_v.x += s * GOLPE_EMPURRA
	_pescoco_v += Vector2(-s * GOLPE_CABECA, -s * GOLPE_CABECA * 0.6)
	_bamboleio = 1.0
	# Quem apanha nao termina o soco que estava dando.
	_soco_t = -1.0


## Se o braco esta fora da manopla, socando.
func socando() -> bool:
	return _soco_t >= 0.0


## Um passo de pose. `velocidade` em m/s; `acelerador` de 0 a 1; `esterco` de
## -1 (esquerda) a 1 (direita). `inclinacao` e a da moto na curva, em
## radianos, positiva para a direita - a mesma que o corpo aplica no `Visual`.
## `lado_queda` e `giro_queda` so contam enquanto `caido`, e so no primeiro
## passo da queda: para que lado a moto tomba (-1 esquerda, 1 direita) e quanto
## ela gira deitada, em radianos (positivo para a esquerda, como a guinada).
func atualizar(
	delta: float,
	velocidade: float,
	acelerador: float,
	esterco: float,
	caido: bool,
	lado_queda: float = 1.0,
	inclinacao: float = 0.0,
	giro_queda: float = 0.0,
	freio: float = 0.0
) -> void:
	if delta <= 0.0:
		return
	var v := absf(velocidade)
	_relogio += delta
	_passo = delta
	for i in 2:
		_giros[i] = wrapf(_giros[i] + velocidade / _raios[i] * delta, 0.0, TAU)
	_rodado += v * delta
	_inclinacao = inclinacao
	_treme = _tremor.passo(delta, v, caido)
	_cotovelos.passo(delta, v, inclinacao, global_position)
	for lisa in _lisas:
		lisa.atualizar(v)
	_acel.medir(delta, global_position, velocidade, inclinacao, caido)
	_comandos.passo(delta, v, acelerador, freio, caido)
	_farol.frear(freio, caido)

	var parado := v < PARADO and not caido
	_pe = move_toward(_pe, 1.0 if parado else 0.0, delta / TEMPO_DO_PE)
	if caido:
		if is_zero_approx(_queda):
			_lado_queda = -1.0 if lado_queda < 0.0 else 1.0
			_giro_queda = giro_queda
			_solta(velocidade)
		_queda = move_toward(_queda, 1.0, delta / TEMPO_DA_QUEDA)
		_girado = move_toward(_girado, 1.0, delta / TEMPO_DO_GIRO)
	else:
		# Levantar e instantaneo de proposito: quem levanta a moto do jogador
		# e o respawn, que ja teleporta ela para a pista.
		_queda = 0.0
		_girado = 0.0
		_voando = false
		_v_de_pe = v

	var esterco_max := lerpf(ESTERCO_DEVAGAR, ESTERCO_RAPIDO, clampf(v / 14.0, 0.0, 1.0))
	_esterco = lerpf(_esterco, esterco * esterco_max, 1.0 - exp(-10.0 * delta))
	_aperto = lerpf(_aperto, clampf(v / JOELHO_FECHA, 0.0, 1.0), 1.0 - exp(-4.0 * delta))
	# O acelerador decide o quanto deitar: no gas o piloto se encolhe atras do
	# painel, e solta o corpo quando alivia ou freia.
	var deita := clampf(v / DEITA, 0.0, 1.0) * (0.55 + 0.45 * clampf(acelerador, 0.0, 1.0))
	_deitado = lerpf(_deitado, deita, 1.0 - exp(-3.0 * delta))
	_bamboleio *= exp(-delta / BAMBOLEIO_TEMPO)
	if _soco_t >= 0.0:
		_soco_t += delta
		if _soco_t >= _soco_total or caido:
			_soco_t = -1.0

	_suspensao(delta, v)
	_corpo(delta)
	if _voando:
		_voa(delta, velocidade)
	_posa()


func _suspensao(delta: float, v: float) -> void:
	if _voando:
		return
	# O asfalto: a traseira passa na mesma onda que a frente, um entre eixos
	# depois. So anda com a moto andando.
	var pisa := clampf(v / 8.0, 0.0, 1.0) * ASFALTO
	var d := _rodado
	var onda_frente := pisa * (0.6 * sin(d * 0.35) + 0.4 * sin(d * 0.9 + 1.3))
	d -= _entre_eixos
	var onda_tras := pisa * (0.6 * sin(d * 0.35) + 0.4 * sin(d * 0.9 + 1.3))

	var freia := tanh(-_acel.longitudinal / ACELERACAO_REF)
	var alvo := Vector2(
		MERGULHO * freia + PESO * _acel.vertical + onda_frente,
		-AGACHA * freia + PESO * _acel.vertical + onda_tras
	)
	var w := Vector2(TAU * FREQ_FRENTE, TAU * FREQ_TRAS)
	var zeta := Vector2(AMORTECE_FRENTE, AMORTECE_TRAS)
	_susp_v += (w * w * (alvo - _susp) - 2.0 * zeta * w * _susp_v) * delta
	_susp += _susp_v * delta
	# Batente: no fim do curso a mola para seco, e a velocidade morre ali.
	var frente := clampf(_susp.x, CURSO_FRENTE.x, CURSO_FRENTE.y)
	var tras := clampf(_susp.y, CURSO_TRAS.x, CURSO_TRAS.y)
	if frente != _susp.x:
		_susp_v.x = 0.0
	if tras != _susp.y:
		_susp_v.y = 0.0
	_susp = Vector2(frente, tras)


func _corpo(delta: float) -> void:
	var alvo := Vector3(
		-MASSA_ROLAGEM * _acel.rolagem,
		-MASSA_PESO * _acel.vertical,
		MASSA_FRENTE * tanh(_acel.longitudinal / ACELERACAO_REF)
	)
	var w := TAU * MASSA_FREQ
	_massa_v += (w * w * (alvo - _massa) - 2.0 * MASSA_AMORTECE * w * _massa_v) * delta
	_massa += _massa_v * delta
	_massa = _massa.clamp(Vector3(-0.2, -0.08, -0.16), Vector3(0.2, 0.05, 0.12))

	var wp := TAU * CABECA_FREQ
	_pescoco_v += (-wp * wp * _pescoco - 2.0 * CABECA_AMORTECE * wp * _pescoco_v) * delta
	_pescoco += _pescoco_v * delta


func _posa() -> void:
	var pivo := Vector3.ZERO
	var angulo := deg_to_rad(INCLINA_PARADO[modelo]) * _suave(_pe)
	if _queda > 0.0:
		pivo = Vector3(QUEDA_PIVO * _lado_queda, 0.0, 0.0)
		# Negativo tomba para a direita: rotacao positiva em Z leva o topo para
		# -X, a esquerda. A mesma convencao do `lean` do `PlayerBike`.
		angulo = -_lado_queda * deg_to_rad(QUEDA) * _suave(_queda)
	var tombo := Basis(Vector3.BACK, angulo)
	# O giro por fora do tombo: a moto ja deitada roda em volta da vertical,
	# rapido no comeco e morrendo com o atrito. So a moto: o piloto ja largou
	# ela e voa por conta propria.
	var giro := Basis(Vector3.UP, _giro_queda * (1.0 - pow(1.0 - _girado, 2.0)))
	_moto.transform = Transform3D(giro, Vector3.ZERO) * Transform3D(tombo, pivo - tombo * pivo)

	_posa_suspensao()

	# Rodando para a frente, o topo da roda vai para -Z: rotacao NEGATIVA em X.
	for i in 2:
		_rodas[i].rotation.x = -_giros[i]
	if _voando:
		_posa_voo()
	else:
		_posa_piloto()
	_mostra_sprite()


## Poe a massa suspensa onde as molas mandam, e o garfo e a balanca onde as
## rodas precisam estar para continuar no chao.
func _posa_suspensao() -> void:
	# O tremor entra aqui, e nao na mola: e curto demais para ela, e somado
	# depois dela as rodas continuam no chao pela mesma conta.
	var susp := _susp + _treme
	var arfa := (susp.x + susp.y) * 0.5
	# Frente afundando mais que a traseira e nariz para baixo: rotacao
	# negativa em X, que leva a frente (-Z) para baixo.
	var arfagem := (susp.y - susp.x) / _entre_eixos
	var corpo := Basis(Vector3.RIGHT, arfagem)
	_suspenso.transform = Transform3D(corpo, Vector3(0.0, -arfa, 0.0))

	var tremido := BAMBOLEIO * _bamboleio * sin(_relogio * TAU * BAMBOLEIO_HZ)
	_direcao.basis = Basis(_eixo_direcao, deg_to_rad(_esterco + tremido))
	# A bainha corre ao longo do garfo ate o eixo voltar a altura de repouso.
	# A conta e linear no quanto ela corre, entao sai exata num passo so.
	var no_moto := _suspenso.transform * _direcao.transform
	var repouso_garfo := _repouso[_garfo].origin
	var ao_longo := no_moto.basis * _eixo_direcao
	var altura := (no_moto * repouso_garfo).y
	var corre := (altura - _altura_eixo[1]) / ao_longo.y
	_garfo.position = repouso_garfo - _eixo_direcao * corre

	# A balanca gira em volta do pivo ate o eixo traseiro voltar a altura de
	# repouso. Com as duas rotacoes em X, a altura do eixo e um cosseno do
	# angulo somado, e o angulo sai de um arco-cosseno.
	var braco := _repouso[_rodas[0]].origin
	var fase := atan2(braco.z, braco.y)
	var alcance := Vector2(braco.y, braco.z).length()
	var pivo := corpo * _repouso[_balanca].origin
	var cos_alvo := clampf((_altura_eixo[0] + arfa - pivo.y) / alcance, -1.0, 1.0)
	_balanca.basis = Basis(Vector3.RIGHT, acos(cos_alvo) - fase - arfagem)

	# O corpo do amortecedor mira na mola, e a mola mira no corpo e encolhe.
	for i in 2:
		var amortecedor := _amortecedores[i]
		var mola := _molas[i]
		var cima := amortecedor.position
		var baixo := _balanca.transform * mola.position
		var eixo: Vector3 = _eixos_amortecedor[i]
		amortecedor.basis = Basis(Quaternion(eixo, (baixo - cima).normalized()))
		var falta := _balanca.transform.affine_inverse() * cima - mola.position
		var gira := Basis(Quaternion(-eixo, falta.normalized()))
		mola.basis = gira * _estica(-eixo, falta.length() / _comprimentos_amortecedor[i])


func _posa_piloto() -> void:
	# O quadril vai com a massa suspensa, e escorrega um pouco no banco com o
	# tronco: na freada cheia, 4 cm para a frente.
	var quadril := _repouso[_piloto].origin + Vector3(0.0, 0.0, _massa.z * 0.35)
	_piloto.transform = _moto.transform * _suspenso.transform * Transform3D(Basis.IDENTITY, quadril)

	var soco := _fases_do_soco()
	var arma: float = soco.x
	var bate: float = soco.y
	var peso_soco: float = soco.z
	var s := float(_soco_lado)

	var tronco := lerpf(TRONCO_SENTADO, TRONCO_DEITADO, _deitado)
	tronco += TRONCO_PE_NO_CHAO * _suave(_pe)
	var arfagem := tronco + rad_to_deg(atan(_massa.z / TRONCO_ALAVANCA) + _massa.y * 1.5)
	# Negativo vira para a direita: rotacao positiva em Y leva a frente (-Z)
	# para -X, a esquerda.
	var guinada := -_esterco * TRONCO_SEGUE_GUIDAO
	guinada += s * (SOCO_ARMA * (arma - bate) - SOCO_BATE * bate)
	# Rolagem positiva leva o topo para -X: o tronco deslocado para a direita
	# (+X) e rolagem negativa.
	var rolagem := -rad_to_deg(atan(_massa.x / TRONCO_ALAVANCA))
	rolagem -= rad_to_deg(_inclinacao) * TRONCO_NA_CURVA
	rolagem -= s * SOCO_DEITA * bate
	_tronco.basis = _rotacao(guinada, rolagem, arfagem)

	# A cabeca desfaz a arfagem do tronco - o piloto deita, mas continua
	# olhando a pista, e nao o tanque -, procura o horizonte, olha para dentro
	# da curva e, no soco, para o alvo.
	var cabeca_guinada := -rad_to_deg(_inclinacao) * CABECA_OLHA_CURVA - guinada * 0.6
	cabeca_guinada += -s * SOCO_OLHA * peso_soco + rad_to_deg(_pescoco.x)
	var cabeca_rolagem := rad_to_deg(_inclinacao) * CABECA_NIVELA - rolagem * 0.5
	cabeca_rolagem += rad_to_deg(_pescoco.y)
	_cabeca.basis = _rotacao(cabeca_guinada, cabeca_rolagem, -arfagem)

	var base := _suspenso.global_basis
	for i in 2:
		var sinal := -1.0 if i == 0 else 1.0
		var braco: Array = _bracos[i]
		var mao: Node3D = braco[2]
		var manopla := _direcao.global_transform * _manoplas[i]
		var alvo := manopla
		var polo := base * _cotovelos.polo(i)
		var solta := 0.0
		if peso_soco > 0.0 and is_equal_approx(sinal, s):
			solta = peso_soco
			var espelho := Vector3(s, 1.0, 1.0)
			var armado := _tronco.global_transform * (SOCO_ARMADO * espelho)
			var esticado := _tronco.global_transform * (SOCO_ESTICADO * espelho)
			alvo = _trajeto_do_soco(manopla, armado, esticado)
			# Armando, o cotovelo sobe e abre; batendo, o braco ja esta reto e
			# o polo so decide para onde a dobra volta.
			var polo_arma := _tronco.global_basis * Vector3(s, 0.7, 0.4)
			var polo_bate := _tronco.global_basis * Vector3(s * 0.3, -1.0, 0.6)
			polo = polo.lerp(polo_arma, arma).lerp(polo_bate, bate)
		_ik(braco[0], braco[1], mao, alvo, polo)
		# Na manopla a luva segue o guidao; no soco, o antebraco.
		var no_guidao := (_direcao.global_basis * _comandos.pulso(i)).get_rotation_quaternion()
		var no_braco := (braco[1] as Node3D).global_basis.get_rotation_quaternion()
		mao.global_basis = Basis(no_guidao.slerp(no_braco, solta))

		var perna: Array = _pernas[i]
		var pe: Node3D = perna[2]
		var pedaleira := _suspenso.global_transform * _pedaleiras[i]
		# O joelho de dentro da curva abre um pouco: inclinado para a direita,
		# e o direito.
		var dentro := maxf(_inclinacao * sinal, 0.0) * JOELHO_NA_CURVA
		var abertura := lerpf(JOELHO_ABERTO, JOELHO_FECHADO, _aperto) + dentro
		var polo_perna := base * Vector3(sinal * abertura, 0.3, -1.0)
		var no_chao := _suave(_pe) if i == 0 else 0.0
		if no_chao > 0.0:
			pedaleira = pedaleira.lerp(global_transform * PE_NO_CHAO, no_chao)
			polo_perna = polo_perna.lerp(global_basis * Vector3(-0.3, 0.3, -1.0), no_chao)
		_ik(perna[0], perna[1], pe, pedaleira, polo_perna)
		# Na pedaleira a bota acompanha a moto (e o pedal); no chao, assenta no
		# asfalto. Por quaternion: o `slerp` da Basis exige rotacao exata, e o
		# produto de tombo, guinada e inclinacao chega com eixo de 0,9999.
		var na_moto := (base * _comandos.bota(i)).get_rotation_quaternion()
		pe.global_basis = Basis(na_moto.slerp(global_basis.get_rotation_quaternion(), no_chao))
	_comandos.posar()


## Quanto do soco ja aconteceu: (armar, bater, peso). `armar` e `bater` vao de
## 0 a 1 e voltam juntos para 0 no recolhimento; `peso` e o quanto o corpo
## esta no soco, e e o que vira a cabeca.
func _fases_do_soco() -> Vector3:
	if _soco_t < 0.0:
		return Vector3.ZERO
	var t := _soco_t
	if t < _soco_preparo:
		var u := _suave(t / _soco_preparo)
		return Vector3(u, 0.0, u)
	t -= _soco_preparo
	if t < _soco_ativo:
		var u := clampf(t / (_soco_ativo * SOCO_ESTICA), 0.0, 1.0)
		return Vector3(1.0, 1.0 - (1.0 - u) * (1.0 - u), 1.0)
	t -= _soco_ativo
	var volta := 1.0 - _suave(t / maxf(_soco_total - _soco_preparo - _soco_ativo, 0.01))
	return Vector3(volta, volta, volta)


## Onde a mao do soco esta: da manopla ao punho armado, dele ao braco esticado,
## e de volta a manopla.
func _trajeto_do_soco(manopla: Vector3, armado: Vector3, esticado: Vector3) -> Vector3:
	var t := _soco_t
	if t < _soco_preparo:
		return manopla.lerp(armado, _suave(t / _soco_preparo))
	t -= _soco_preparo
	if t < _soco_ativo:
		var u := clampf(t / (_soco_ativo * SOCO_ESTICA), 0.0, 1.0)
		return armado.lerp(esticado, 1.0 - (1.0 - u) * (1.0 - u))
	t -= _soco_ativo
	var u := _suave(t / maxf(_soco_total - _soco_preparo - _soco_ativo, 0.01))
	return esticado.lerp(manopla, u)


## A queda comecou: o piloto larga a moto com a velocidade que ela tinha.
func _solta(velocidade: float) -> void:
	_voando = true
	_voo = _piloto.transform
	_voo_t = 0.0
	_no_chao_t = -1.0
	_soco_t = -1.0
	var frente := minf(maxf(_v_de_pe, absf(velocidade)) * ARREMESSO, ARREMESSO_MAX)
	_voo_v = Vector3(_lado_queda * ARREMESSO_LADO, ARREMESSO_CIMA, -frente)
	# Cambalhota para a frente (rotacao negativa em X leva o topo para -Z), um
	# pouco de rolagem para o lado do tombo e de guinada.
	_voo_giro = Vector3(-1.0 - frente * 0.5, _lado_queda * 0.8, -_lado_queda * 1.5)


## Um passo do voo: balistico no ar, arrastando no chao.
##
## O voo e no espaco deste no, que anda junto com o corpo, e o corpo caido
## continua deslizando - o do jogador pelo que sobrou da batida, o do rival na
## velocidade dele. Por isso o voo desconta a `velocidade`, e o piloto se
## afasta da moto na diferenca.
func _voa(delta: float, velocidade: float) -> void:
	_voo_t += delta
	_voo_v.y -= GRAVIDADE * delta
	var relativa := _voo_v + Vector3(0.0, 0.0, velocidade)
	_voo.origin += relativa * delta
	var giro := _voo_giro.length()
	if giro > 1e-4:
		_voo.basis = Basis(_voo_giro / giro, giro * delta) * _voo.basis
	_voo.basis = _voo.basis.orthonormalized()
	if _no_chao_t >= 0.0:
		_no_chao_t += delta
		# No chao o corpo assenta deitado: o torso vai para a horizontal, e o
		# ombro tambem, de costas ou de bruços. De lado, o braco de baixo
		# escora o corpo inteiro meio metro acima do asfalto.
		var torso := (_voo.basis * Vector3.UP).normalized()
		var deitado := Vector3(torso.x, 0.0, torso.z)
		if deitado.length() < 0.1:
			deitado = _voo.basis * Vector3.BACK
			deitado.y = 0.0
		deitado = deitado.normalized()
		var ombro := _voo.basis * Vector3.RIGHT
		var ombro_deitado := ombro - deitado * ombro.dot(deitado)
		ombro_deitado.y = 0.0
		if ombro_deitado.length() < 0.1:
			ombro_deitado = deitado.cross(Vector3.UP)
		# O torso do modelo e o Y local: o alvo poe o Y no `deitado`.
		ombro_deitado = ombro_deitado.normalized()
		var alvo := Basis(ombro_deitado, deitado, ombro_deitado.cross(deitado))
		var quanto := 1.0 - exp(-8.0 * delta)
		var de := _voo.basis.get_rotation_quaternion()
		_voo.basis = Basis(de.slerp(alvo.get_rotation_quaternion(), quanto))


func _posa_voo() -> void:
	_piloto.transform = _voo
	var soltou := _suave(_voo_t / TEMPO_DE_SOLTAR)
	var deitou := _suave(_no_chao_t / 0.4) if _no_chao_t >= 0.0 else 0.0
	_tronco.basis = Basis.IDENTITY
	_cabeca.basis = Basis.IDENTITY
	var corpo := _piloto.global_transform
	for i in 2:
		var s := -1.0 if i == 0 else 1.0
		var bate := sin(_voo_t * 11.0 + s) * (1.0 - deitou)
		# No ar os bracos soltam para cima, abanando; no chao, abrem.
		var mao_ar := Vector3(s * 0.55, 0.85 + 0.15 * bate, -0.15 + 0.1 * bate)
		var mao_chao := Vector3(s * 0.75, 0.40, 0.10)
		var alvo := corpo * mao_ar.lerp(mao_chao, deitou)
		var braco: Array = _bracos[i]
		var manopla := _direcao.global_transform * _manoplas[i]
		alvo = manopla.lerp(alvo, soltou)
		_ik(braco[0], braco[1], braco[2], alvo, corpo.basis * Vector3(s, -0.3, 0.5))
		(braco[2] as Node3D).basis = Basis.IDENTITY

		var pe_ar := Vector3(s * 0.2, -0.78, -0.15 - 0.1 * bate)
		var pe_chao := Vector3(s * 0.25, -0.86, 0.05)
		var pe_alvo := corpo * pe_ar.lerp(pe_chao, deitou)
		var perna: Array = _pernas[i]
		var pedaleira := _suspenso.global_transform * _pedaleiras[i]
		pe_alvo = pedaleira.lerp(pe_alvo, soltou)
		_ik(perna[0], perna[1], perna[2], pe_alvo, corpo.basis * Vector3(s * 0.3, 0.0, -1.0))
		(perna[2] as Node3D).basis = Basis.IDENTITY

	# O asfalto: o ponto mais fundo do corpo nao passa do chao. Encostou, o
	# corpo quica pouco, arrasta e para de girar.
	var fundo := INF
	for contato: Array in _contatos:
		var no: Node3D = contato[0]
		var desvio: Vector3 = contato[1]
		var raio: float = contato[2]
		fundo = minf(fundo, to_local(no.global_transform * desvio).y - raio)
	if fundo >= 0.0:
		return
	_voo.origin.y -= fundo
	_piloto.transform = _voo
	if _no_chao_t < 0.0:
		_no_chao_t = 0.0
	if _voo_v.y < 0.0:
		_voo_v.y = -_voo_v.y * 0.25 if _voo_v.y < -3.0 else 0.0
	var plano := Vector2(_voo_v.x, _voo_v.z)
	plano = plano.move_toward(Vector2.ZERO, ATRITO_NO_CHAO * _passo)
	_voo_v = Vector3(plano.x, _voo_v.y, plano.y)
	_voo_giro *= 0.9


## IK de dois ossos: dobra `raiz` e `meio` para a `ponta` alcancar o `alvo`.
##
## Os ossos sao as posicoes de repouso dos filhos (ver `Ik.dois_ossos`).
func _ik(raiz: Node3D, meio: Node3D, ponta: Node3D, alvo: Vector3, polo: Vector3) -> void:
	Ik.dois_ossos(raiz, meio, _repouso[meio].origin, _repouso[ponta].origin, alvo, polo)


## Guinada, rolagem e arfagem em graus, nessa ordem: gira o pescoco, deita o
## corpo para o lado e so entao inclina para a frente ou para tras.
func _rotacao(guinada: float, rolagem: float, arfagem: float) -> Basis:
	return (
		Basis(Vector3.UP, deg_to_rad(guinada))
		* Basis(Vector3.BACK, deg_to_rad(rolagem))
		* Basis(Vector3.RIGHT, deg_to_rad(arfagem))
	)


## Escala `k` so ao longo da direcao unitaria `d`: a mola encolhe sem
## engordar.
func _estica(d: Vector3, k: float) -> Basis:
	var m := k - 1.0
	return Basis(
		Vector3.RIGHT + d * (m * d.x), Vector3.UP + d * (m * d.y), Vector3.BACK + d * (m * d.z)
	)


## A textura de paleta lida uma vez so: e dela que o borrao tira a cor dos
## raios.
static func _paleta() -> Image:
	if _imagem_da_paleta == null:
		_imagem_da_paleta = ALBEDO.get_image()
	return _imagem_da_paleta


func _suave(t: float) -> float:
	return smoothstep(0.0, 1.0, t)


func _aplica_cores() -> void:
	_sprite.pintar(_cores[0])
	if _material == null:
		return
	_material.set_shader_parameter("bag", _cores[0])
	_material.set_shader_parameter("camisa", _cores[1])
	_material.set_shader_parameter("moto", _cores[2])


func _prepara(no: Node) -> void:
	if no is Node3D:
		_repouso[no as Node3D] = (no as Node3D).transform
	if no is MeshInstance3D:
		(no as MeshInstance3D).material_override = _material
	for filho in no.get_children():
		_prepara(filho)


func _no(nome: String) -> Node3D:
	var achado := _modelo.find_child(nome, true, false) as Node3D
	assert(achado != null, "entregador.glb sem o no %s" % nome)
	return achado


## Posicao de repouso relativa a `ancestral`. Vale somar as translacoes porque
## nenhuma peca tem rotacao em repouso - e uma convencao do gerador.
func _no_relativo(no: Node3D, ancestral: Node3D) -> Vector3:
	var pos := Vector3.ZERO
	var atual: Node = no
	while atual != ancestral:
		pos += _repouso[atual as Node3D].origin
		atual = atual.get_parent()
	return pos


## Sprite ou modelo neste passo, e o quadro do sprite.
func _mostra_sprite() -> void:
	if _modelo == null:
		return
	var fase := -1
	if _soco_t >= 0.0:
		fase = 0 if _soco_t < _soco_preparo else (1 if _soco_t < _soco_preparo + _soco_ativo else 2)
	_sprite.mostrar(_modelo, sprite and is_zero_approx(_queda) and not _voando)
	# O tronco jogado pela curva e pela pancada, e o bamboleio do guidao,
	# viram o sprite inteiro gingando; a suspensao e o tremor, ele afundando.
	var tremido := deg_to_rad(BAMBOLEIO * _bamboleio * sin(_relogio * TAU * BAMBOLEIO_HZ))
	var ginga := Vector3(
		atan(_massa.x / TRONCO_ALAVANCA) * 0.5 + tremido * 0.5,
		_massa.x * 0.5,
		(_susp.x + _susp.y + _treme.x + _treme.y) * 0.5 - _massa.y
	)
	_sprite.posar(_inclinacao, _soco_lado, fase, ginga)
