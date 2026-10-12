class_name FichaDaMoto
extends RefCounted
## A ficha tecnica de verdade de cada moto: o que a fabrica publica.
##
## A fisica de cada moto sai daqui (`FisicaDaMoto.da_ficha`), e nao de numero
## afinado na mao: moto nova entra com a ficha dela e ja nasce calibrada em
## relacao a CG, que e onde a mola foi afinada. O teste unitario reprova moto
## em `Entregador.CENAS` sem ficha.
##
## Fontes: fichas da Honda Brasil repetidas por Motoo e Motonline (out/2026).
## Onde elas divergem (ano, versao, gasolina ou etanol), vale a versao mais
## vendida e o valor com gasolina. A precisao e de ficha, nao de laboratorio:
## o que importa e a proporcao entre uma moto e outra.

## Peso seco, kg.
var peso_kg: float
## Distancia entre eixos, mm.
var entre_eixos_mm: float
## Altura do banco, mm. Faz as vezes da altura do centro de massa: com o
## piloto em cima, quase metade do peso esta sentada ali.
var banco_mm: float
## Pneus no formato da lateral: largura/perfil-aro. [dianteiro, traseiro].
var pneus: PackedStringArray
## Motor. Ainda nao entram na fisica: a V05a decidiu que velocidade e
## aceleracao sao iguais nas tres. Ficam na ficha para quando entrarem.
var cilindrada_cm3: float
var potencia_cv: float
var torque_kgfm: float


func _init(
	a_peso: float,
	a_entre_eixos: float,
	a_banco: float,
	a_pneus: PackedStringArray,
	a_cilindrada: float,
	a_potencia: float,
	a_torque: float
) -> void:
	peso_kg = a_peso
	entre_eixos_mm = a_entre_eixos
	banco_mm = a_banco
	pneus = a_pneus
	cilindrada_cm3 = a_cilindrada
	potencia_cv = a_potencia
	torque_kgfm = a_torque


## A ficha do `modelo` (um `Entregador.Modelo`), ou null se a moto nao tem.
static func de(modelo: int) -> FichaDaMoto:
	match modelo:
		Entregador.Modelo.CG_160:
			# CG 160 Titan, a moto do entregador.
			return FichaDaMoto.new(
				117.0, 1315.0, 790.0, ["80/100-18", "100/80-18"], 162.7, 14.9, 1.4
			)
		Entregador.Modelo.XRE_300:
			return FichaDaMoto.new(
				148.0, 1417.0, 860.0, ["90/90-21", "120/80-18"], 291.6, 25.6, 2.8
			)
		Entregador.Modelo.PCX_160:
			return FichaDaMoto.new(
				124.0, 1313.0, 764.0, ["110/70-14", "130/70-13"], 156.9, 16.0, 1.5
			)
	return null


## Diametro externo do pneu, em mm: aro em polegadas mais duas vezes a parede
## (largura vezes o perfil). "90/90-21" da 533 + 162 = 695 mm.
static func diametro_mm(pneu: String) -> float:
	var partes := pneu.split("-")
	var secao := partes[0].split("/")
	var parede := secao[0].to_float() * secao[1].to_float() / 100.0
	return partes[1].to_float() * 25.4 + 2.0 * parede


## Soma dos diametros dos dois pneus, em mm.
func rodas_mm() -> float:
	return diametro_mm(pneus[0]) + diametro_mm(pneus[1])
