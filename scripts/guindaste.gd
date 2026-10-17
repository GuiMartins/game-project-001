class_name Guindaste
extends RefCounted
## O guindaste de torre amarelo da obra (V17a), montado de pecas repetidas.
##
## O mastro e a lanca sao trechos de `arte/predios.py` empilhados, e nao um
## modelo esticado: a altura e o alcance de cada guindaste sao quantos
## trechos ele leva, e escala esticaria a trelica e engrossaria o perfil.
## Por isso a `Cidade` pode pôr um em cima de uma obra (`04_vertical`) ou
## sozinho atras do muro da via expressa (`03_viaduto`) sem modelo novo.

## Os trechos do `.glb` medem isso; o `test_guindaste.gd` reprova se divergirem.
const TRECHO_MASTRO: float = 3.0
const TRECHO_LANCA: float = 4.0
## Onde a lanca comeca no topo (o raio da mesa giratoria) e a que altura da
## junta ela corre, alinhada com a contra-lanca.
const RAIZ_DA_LANCA: float = 1.1
const ALTURA_DA_LANCA: float = 0.04
## Quanto da lanca o carrinho anda: do meio para a ponta, onde a carga fica.
const CARRINHO: float = 0.65


## Um guindaste com o pe na origem. `altura` e a do mastro, `lanca` o alcance
## ate a ponta e `giro` o angulo da lanca em torno de Y (zero aponta para +X).
## Os dois arredondam para cima, em trechos inteiros.
static func criar(altura: float, lanca: float, giro: float) -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "Guindaste"
	var trechos := maxi(ceili(altura / TRECHO_MASTRO), 1)
	for i in trechos:
		var mastro := _peca("GuindasteMastro")
		mastro.name = "Mastro%d" % i
		mastro.position.y = i * TRECHO_MASTRO
		raiz.add_child(mastro)

	var topo := _peca("GuindasteTopo")
	topo.name = "Topo"
	topo.position.y = trechos * TRECHO_MASTRO
	topo.rotation.y = giro
	raiz.add_child(topo)

	var secoes := maxi(ceili(lanca / TRECHO_LANCA), 1)
	for i in secoes:
		var secao := _peca("GuindasteLanca")
		secao.name = "Lanca%d" % i
		secao.position = Vector3(RAIZ_DA_LANCA + i * TRECHO_LANCA, ALTURA_DA_LANCA, 0.0)
		topo.add_child(secao)
	var gancho := _peca("GuindasteGancho")
	gancho.name = "Gancho"
	gancho.position = Vector3(RAIZ_DA_LANCA + secoes * TRECHO_LANCA * CARRINHO, 0.0, 0.0)
	topo.add_child(gancho)
	return raiz


## A altura do ponto mais alto, para quem precisa saber se passa por cima de
## alguma coisa: mastro mais a torre em A da mesa giratoria.
static func altura_total(altura: float) -> float:
	return maxi(ceili(altura / TRECHO_MASTRO), 1) * TRECHO_MASTRO + 7.4


## Treliça de ferro de longe vira cintilacao quando a sombra anda por cima do
## chao, e sai cara por tao pouco: o guindaste nao projeta sombra.
static func _peca(nome: String) -> MeshInstance3D:
	var mi := Predio.peca(nome)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
