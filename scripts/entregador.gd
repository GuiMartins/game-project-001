class_name Entregador
extends Node3D
## O ator: moto e piloto de `assets/entregador`, posados a cada passo de fisica.
##
## Mora no no `Visual` de `PlayerBike` e `RivalBike`, com a origem no chao,
## embaixo do centro da moto. Quem inclina a moto nas curvas e o `Visual`, que
## e do corpo; este no cuida do que acontece DENTRO da moto: roda girando,
## guidao, joelho, tronco, o pe que desce quando ela para e o tombo da queda.
##
## Nada aqui e clipe de animacao. O modelo e de pecas rigidas com a origem na
## articulacao (ver `arte/entregador.py`), e cada pose sai de quatro numeros
## por passo: velocidade, acelerador, esterco e se caiu. Pose lida do estado
## nao desencontra da fisica - a roda gira exatamente na velocidade em que a
## moto anda, e o pe toca o chao no passo em que ela para.

const CENA: PackedScene = preload("res://assets/entregador/entregador.glb")
const SHADER: Shader = preload("res://scripts/entregador.gdshader")
const ALBEDO: Texture2D = preload("res://assets/entregador/entregador_albedo.png")
const MASCARA: Texture2D = preload("res://assets/entregador/entregador_mascara.png")

## A cor pintada na textura em cada canal da mascara: a celula mais clara sob
## ele em `PALETA`, no `arte/entregador.py`. Mudou la, muda aqui - o
## `test_entregador.gd` le a textura e reprova se as duas divergirem.
const BAG_FABRICA := Color(0.95, 0.42, 0.15)
const JAQUETA_FABRICA := Color(0.20, 0.25, 0.34)
const MOTO_FABRICA := Color(0.70, 0.11, 0.09)

## Quanto a jaqueta escurece em relacao a cor do corredor. Na cor cheia ela
## vira macacao de mascote; escura, le como roupa e deixa a bag e a moto
## carregarem a cor, que sao os dois blocos que a camera de tras enxerga.
const JAQUETA_ESCURECE: float = 0.6

## Abaixo disto, em m/s, a moto conta como parada e o pe esquerdo desce. 1 m/s
## e passo de gente: acima disso quem pilota ja recolheu o pe.
const PARADO: float = 1.0
## Quanto tempo o pe leva para descer ou subir, em segundos. Mais rapido que
## isso o pe teleporta; mais lento, a moto arranca com o pe arrastando.
const TEMPO_DO_PE: float = 0.25
## Onde a bota esquerda pousa com a moto parada, no espaco do `Visual`: meio
## metro para o lado, um pouco atras do centro, com o tornozelo a 7,5 cm do
## asfalto (a altura da bota). A perna de 0,9 m alcanca dali com folga minima,
## que e como entregador de verdade fica: na ponta do pe.
const PE_NO_CHAO := Vector3(-0.42, 0.075, 0.1)
## Quanto a moto deita para o lado do pe no chao, em graus.
const INCLINA_PARADO: float = 7.0

## Velocidade, em m/s, em que os joelhos terminam de fechar no tanque. 15 m/s
## sao 54 km/h, um terco do teto: joelho aberto e coisa de manobra, nao de reta.
const JOELHO_FECHA: float = 15.0
## Para que lado o joelho aponta, aberto e fechado: e o polo do IK da perna, o
## componente lateral de um vetor que aponta para a frente.
const JOELHO_ABERTO: float = 0.9
const JOELHO_FECHADO: float = -0.05

## Velocidade, em m/s, em que o tronco deita o maximo. Perto do teto (~49 m/s)
## e de proposito: deitar inteiro e o que se faz no talo, nao em cruzeiro.
const DEITA: float = 35.0
## Angulo do tronco em graus, positivo para tras: sentado, deitado no tanque e
## o quanto ele levanta a mais com o pe no chao.
const TRONCO_SENTADO: float = 4.0
const TRONCO_DEITADO: float = -14.0
const TRONCO_PE_NO_CHAO: float = 8.0

## Quanto o guidao vira com o esterco inteiro, em graus, parado e a partir de
## 14 m/s. Moto de verdade quase nao vira o guidao em velocidade: a curva sai
## da inclinacao, e e assim que o `PlayerBike` funciona.
const ESTERCO_DEVAGAR: float = 20.0
const ESTERCO_RAPIDO: float = 4.0
## Quanto do esterco o tronco acompanha, girando os ombros para o lado da
## curva. Sem isso, com o guidao no batente, a manopla de fora foge do alcance
## do braco: e o que todo piloto faz, e o que deixa o IK chegar.
const TRONCO_SEGUE_GUIDAO: float = 0.5

## O tombo: angulo e onde fica o pivo, metros para o lado da queda. Tombar em
## volta do centro enterraria meia moto no asfalto; em volta da lateral ela
## deita em cima do lado que bateu no chao.
const QUEDA: float = 85.0
const QUEDA_PIVO: float = 0.3
const TEMPO_DA_QUEDA: float = 0.3

var _modelo: Node3D
var _material: ShaderMaterial
var _cores: Array[Color] = [BAG_FABRICA, JAQUETA_FABRICA, MOTO_FABRICA]
## Transformacao de repouso de cada no do modelo. A posicao de cada filho e o
## osso do pai, e e daqui que o IK tira o comprimento de braco e perna.
var _repouso: Dictionary[Node3D, Transform3D] = {}
var _rodas: Array[Node3D] = []
var _raio_roda: float = 0.3
var _direcao: Node3D
var _eixo_direcao: Vector3
var _tronco: Node3D
var _cabeca: Node3D
## Por lado, esquerdo e direito: [raiz, meio, ponta] de cada cadeia.
var _bracos: Array[Array] = []
var _pernas: Array[Array] = []
## Onde fica cada manopla, no espaco da direcao, e cada pedaleira, no do modelo.
var _manoplas: Array[Vector3] = []
var _pedaleiras: Array[Vector3] = []

var _giro: float = 0.0
var _esterco: float = 0.0
var _aperto: float = 0.0
var _deitado: float = 0.0
## 1 = pe esquerdo no chao. Nasce 1: toda corrida comeca parada.
var _pe: float = 1.0
var _queda: float = 0.0
var _lado_queda: float = 1.0


func _ready() -> void:
	var cena := CENA.instantiate() as Node3D
	add_child(cena)
	_modelo = cena.get_node("Entregador") as Node3D

	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("albedo", ALBEDO)
	_material.set_shader_parameter("mascara", MASCARA)
	_material.set_shader_parameter("bag_fabrica", BAG_FABRICA)
	_material.set_shader_parameter("jaqueta_fabrica", JAQUETA_FABRICA)
	_material.set_shader_parameter("moto_fabrica", MOTO_FABRICA)
	_aplica_cores()
	_prepara(_modelo)

	_rodas = [_no("Roda_Traseira"), _no("Roda_Dianteira")]
	_raio_roda = (_rodas[0] as MeshInstance3D).get_aabb().size.y * 0.5
	_direcao = _no("Direcao")
	# O garfo inteiro gira em volta da reta que liga a cabeca do garfo ao eixo
	# dianteiro, e nao em volta da vertical: e o que faz a roda estercar sem
	# sair de baixo do paralama.
	_eixo_direcao = _no("Roda_Dianteira").position.normalized()
	_tronco = _no("Tronco")
	_cabeca = _no("Cabeca")
	for lado: String in ["E", "D"]:
		var mao := _no("Mao_" + lado)
		_bracos.append([_no("Braco_" + lado), _no("Antebraco_" + lado), mao])
		_manoplas.append(_no_modelo(mao) - _no_modelo(_direcao))
		var pe := _no("Pe_" + lado)
		_pernas.append([_no("Coxa_" + lado), _no("Canela_" + lado), pe])
		_pedaleiras.append(_no_modelo(pe))


## Veste o corredor de uma cor: bag e moto nela, jaqueta num tom escuro dela.
##
## Uma cor por corredor, e nao uma combinacao livre de tres: de longe, o que
## separa um entregador do outro e a mancha de cor, e "passei o amarelo" so
## funciona se o amarelo for amarelo da bag ao paralama.
func pintar(cor: Color) -> void:
	_cores = [cor, cor.darkened(JAQUETA_ESCURECE), cor]
	_aplica_cores()


## Um passo de pose. `velocidade` em m/s; `acelerador` de 0 a 1; `esterco` de
## -1 (esquerda) a 1 (direita); `lado_queda` so conta enquanto `caido`, e diz
## para que lado a moto tomba: -1 esquerda, 1 direita.
func atualizar(
	delta: float,
	velocidade: float,
	acelerador: float,
	esterco: float,
	caido: bool,
	lado_queda: float = 1.0
) -> void:
	var v := absf(velocidade)
	_giro = wrapf(_giro + velocidade / _raio_roda * delta, 0.0, TAU)

	var parado := v < PARADO and not caido
	_pe = move_toward(_pe, 1.0 if parado else 0.0, delta / TEMPO_DO_PE)
	if caido:
		if is_zero_approx(_queda):
			_lado_queda = -1.0 if lado_queda < 0.0 else 1.0
		_queda = move_toward(_queda, 1.0, delta / TEMPO_DA_QUEDA)
	else:
		# Levantar e instantaneo de proposito: quem levanta a moto do jogador
		# e o respawn, que ja teleporta ela para a pista.
		_queda = 0.0

	var esterco_max := lerpf(ESTERCO_DEVAGAR, ESTERCO_RAPIDO, clampf(v / 14.0, 0.0, 1.0))
	_esterco = lerpf(_esterco, esterco * esterco_max, 1.0 - exp(-10.0 * delta))
	_aperto = lerpf(_aperto, clampf(v / JOELHO_FECHA, 0.0, 1.0), 1.0 - exp(-4.0 * delta))
	# O acelerador decide o quanto deitar: no gas o piloto se encolhe atras do
	# painel, e solta o corpo quando alivia ou freia.
	var deita := clampf(v / DEITA, 0.0, 1.0) * (0.55 + 0.45 * clampf(acelerador, 0.0, 1.0))
	_deitado = lerpf(_deitado, deita, 1.0 - exp(-3.0 * delta))

	_posa()


func _posa() -> void:
	var pivo := Vector3.ZERO
	var angulo := deg_to_rad(INCLINA_PARADO) * _suave(_pe)
	if _queda > 0.0:
		pivo = Vector3(QUEDA_PIVO * _lado_queda, 0.0, 0.0)
		# Negativo tomba para a direita: rotacao positiva em Z leva o topo para
		# -X, a esquerda. A mesma convencao do `lean` do `PlayerBike`.
		angulo = -_lado_queda * deg_to_rad(QUEDA) * _suave(_queda)
	var tombo := Basis(Vector3.BACK, angulo)
	_modelo.transform = Transform3D(tombo, pivo - tombo * pivo)

	# Rodando para a frente, o topo da roda vai para -Z: rotacao NEGATIVA em X.
	for roda in _rodas:
		roda.rotation.x = -_giro
	_direcao.basis = Basis(_eixo_direcao, deg_to_rad(_esterco))

	var tronco := lerpf(TRONCO_SENTADO, TRONCO_DEITADO, _deitado)
	tronco += TRONCO_PE_NO_CHAO * _suave(_pe)
	_tronco.rotation.x = deg_to_rad(tronco)
	# Negativo vira para a direita: rotacao positiva em Y leva a frente (-Z)
	# para -X, a esquerda.
	_tronco.rotation.y = -deg_to_rad(_esterco) * TRONCO_SEGUE_GUIDAO
	# A cabeca desfaz o giro do tronco: o piloto deita, mas continua olhando a
	# pista, e nao o tanque.
	_cabeca.rotation.x = -deg_to_rad(tronco)

	var base := _modelo.global_basis
	for i in 2:
		var sinal := -1.0 if i == 0 else 1.0
		var braco: Array = _bracos[i]
		var mao: Node3D = braco[2]
		var manopla := _direcao.global_transform * _manoplas[i]
		# Cotovelo para fora e para baixo, como quem segura um guidao largo.
		_ik(braco[0], braco[1], mao, manopla, base * Vector3(sinal, -1.0, 0.3))
		mao.global_basis = _direcao.global_basis

		var perna: Array = _pernas[i]
		var pe: Node3D = perna[2]
		var alvo := _modelo.global_transform * _pedaleiras[i]
		var abertura := lerpf(JOELHO_ABERTO, JOELHO_FECHADO, _aperto)
		var polo := base * Vector3(sinal * abertura, 0.3, -1.0)
		var no_chao := _suave(_pe) if i == 0 else 0.0
		if no_chao > 0.0:
			alvo = alvo.lerp(global_transform * PE_NO_CHAO, no_chao)
			polo = polo.lerp(global_basis * Vector3(-0.3, 0.3, -1.0), no_chao)
		_ik(perna[0], perna[1], pe, alvo, polo)
		# Na pedaleira a bota acompanha a moto; no chao, assenta no asfalto.
		# Por quaternion, e nao `Basis.slerp`: o `global_basis` sai do produto
		# de tombo, guinada e inclinacao, e chega com o comprimento dos eixos em
		# 0,9999. O `slerp` da Basis exige rotacao exata e cospe um erro por pe
		# por passo de fisica; `get_rotation_quaternion` ortonormaliza antes.
		var na_moto := base.get_rotation_quaternion()
		pe.global_basis = Basis(na_moto.slerp(global_basis.get_rotation_quaternion(), no_chao))


## IK de dois ossos: dobra `raiz` e `meio` para a `ponta` alcancar o `alvo`.
##
## `polo` diz para que lado a articulacao do meio aponta. Os ossos sao as
## posicoes de repouso dos filhos, entao comprimento de braco e de perna vem do
## modelo, e nao de um numero copiado para ca. Alvo fora do alcance estica o
## membro reto na direcao dele em vez de quebrar.
func _ik(raiz: Node3D, meio: Node3D, ponta: Node3D, alvo: Vector3, polo: Vector3) -> void:
	var osso_a := _repouso[meio].origin
	var osso_b := _repouso[ponta].origin
	var la := osso_a.length()
	var lb := osso_b.length()
	var origem := raiz.global_position
	var falta := alvo - origem
	var eixo := falta.normalized()
	var dist := clampf(falta.length(), absf(la - lb) + 0.001, la + lb - 0.001)
	var ao_longo := (la * la - lb * lb + dist * dist) / (2.0 * dist)
	var afasta := sqrt(maxf(la * la - ao_longo * ao_longo, 0.0))
	var lado := (polo - eixo * polo.dot(eixo)).normalized()
	var junta := origem + eixo * ao_longo + lado * afasta
	var fim := origem + eixo * dist

	var pai := (raiz.get_parent() as Node3D).global_basis
	var de := (pai * osso_a).normalized()
	raiz.global_basis = Basis(Quaternion(de, (junta - origem).normalized())) * pai
	var base_raiz := raiz.global_basis
	var de_b := (base_raiz * osso_b).normalized()
	meio.global_basis = Basis(Quaternion(de_b, (fim - junta).normalized())) * base_raiz


func _suave(t: float) -> float:
	return smoothstep(0.0, 1.0, t)


func _aplica_cores() -> void:
	if _material == null:
		return
	_material.set_shader_parameter("bag", _cores[0])
	_material.set_shader_parameter("jaqueta", _cores[1])
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


## Posicao de repouso relativa ao modelo. Vale somar as translacoes porque
## nenhuma peca tem rotacao em repouso - e uma convencao do gerador.
func _no_modelo(no: Node3D) -> Vector3:
	var pos := Vector3.ZERO
	var atual: Node = no
	while atual != _modelo:
		pos += _repouso[atual as Node3D].origin
		atual = atual.get_parent()
	return pos
