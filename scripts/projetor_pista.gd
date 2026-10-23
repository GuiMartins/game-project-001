class_name ProjetorPista
extends RefCounted
## O projetor por segmento da migração para 2D (`docs/MIGRACAO_2D.md`, 2D05): da
## pista de verdade (`RoadTrack`, curva e rampa como dado) para posições de
## tela, como o Road Rash e o OutRun fazem.
##
## A câmera olha reto ao longo da pista e o horizonte não se mexe. A curva não
## gira a câmera: cada amostra à frente se desloca de lado pelo quanto a pista
## já virou até ali, e a rampa a sobe ou desce na tela. É isso que faz o
## pseudo-3D ser barato, e é também o que se perde: a geometria livre.
##
## Só calcula. Quem desenha (`TelaProjetor`) pede as amostras e liga os pontos.

## A distância entre amostras, em metros: a malha da pista (`RoadTrack.MESH_STEP`)
## tem o mesmo passo, e menos que isso só repete o que a curva já tem.
const PASSO: float = 4.0
## Até onde se vê à frente, em metros.
const VISAO: float = 520.0
## A altura da câmera sobre o asfalto, em metros, e a distância focal em pixels
## da tela de 640 x 360 (`TelaProjetor`): com estes dois, o asfalto chega à
## borda de baixo a ~2 m da câmera, e a moto, 3,5 m à frente, fica com ~85 px
## por metro, perto da escala em que o desenho dela foi feito.
const ALTURA_CAMERA: float = 1.4
const FOCO: float = 300.0
## A primeira amostra, à frente da câmera: mais perto que isso a escala explode.
const Z_INICIAL: float = 1.0
## Quanto da virada da pista entra na tela. A pista de verdade vira até
## 0,6 grau por metro, que em 400 m dá mais de uma volta; contado inteiro, o
## projetor dobraria sobre si mesmo. O ganho encolhe o ângulo, e o limite
## impede que o cosseno do passo chegue a zero.
const GANHO_CURVA: float = 0.35
const LIMITE_CURVA: float = 1.2
## Quanto da subida da pista entra na tela, 1 sendo a pista real.
const GANHO_RAMPA: float = 1.0


## Um ponto da pista à frente da câmera.
class Amostra:
	extends RefCounted

	## O quanto de pista já passou, em metros desde o início do percurso.
	var o: float = 0.0
	## Distância à frente da câmera, em metros, já descontada a curva.
	var z: float = 0.0
	## Onde o eixo da pista está em relação à câmera, + direita, em metros.
	var x: float = 0.0
	## A altura do asfalto sobre o chão da câmera, em metros.
	var y: float = 0.0
	## Onde o eixo da pista cai na tela, e quantos pixels vale um metro ali.
	var tela_x: float = 0.0
	var tela_y: float = 0.0
	var escala: float = 0.0


var amostras: Array[Amostra] = []
var centro_x: float = 320.0
var horizonte_y: float = 150.0


## Projeta a pista a partir de `camera_o` (metros de percurso), com a câmera
## `camera_lateral` metros à direita do eixo.
func projetar(track: RoadTrack, camera_o: float, camera_lateral: float) -> void:
	amostras.clear()
	var rumo_0 := rumo_em(track, camera_o)
	var altura_0 := track.sample_position(camera_o).y
	var fim := minf(camera_o + VISAO, track.length)
	var o := camera_o + Z_INICIAL
	var anterior: Amostra = null
	while o <= fim:
		var a := Amostra.new()
		a.o = o
		if anterior == null:
			a.z = Z_INICIAL
			a.x = -camera_lateral
		else:
			var giro := clampf(
				wrapf(rumo_em(track, o) - rumo_0, -PI, PI) * GANHO_CURVA,
				-LIMITE_CURVA,
				LIMITE_CURVA
			)
			var passo := o - anterior.o
			a.z = anterior.z + passo * cos(giro)
			# Rumo positivo gira para a esquerda (Y para cima, mão direita), e
			# o X do projetor cresce para a direita: o sinal troca aqui.
			a.x = anterior.x - passo * sin(giro)
		a.y = (track.sample_position(o).y - altura_0) * GANHO_RAMPA
		a.escala = FOCO / a.z
		a.tela_x = centro_x + a.x * a.escala
		a.tela_y = horizonte_y + (ALTURA_CAMERA - a.y) * a.escala
		amostras.append(a)
		anterior = a
		# As amostras caem em múltiplos do passo, e não a cada passo a partir da
		# câmera: o desenho da pista não pode andar junto com ela.
		o = (floorf(o / PASSO) + 1.0) * PASSO


## Onde cai um ponto a `o` metros de percurso e `lateral` metros do eixo: o X
## de tela, o Y de tela e a escala, ou `Vector3.ZERO` se está fora da visão.
func ponto(o: float, lateral: float) -> Vector3:
	for j in amostras.size() - 1:
		var a := amostras[j]
		var b := amostras[j + 1]
		if o < a.o or o > b.o:
			continue
		var s := (o - a.o) / (b.o - a.o)
		# A profundidade é linear no metro; a escala, não. Interpolar o Z e
		# refazer a escala dele é o que dá perspectiva certa no meio do passo.
		var z := lerpf(a.z, b.z, s)
		var escala := FOCO / z
		var x := lerpf(a.x, b.x, s) + lateral
		var y := lerpf(a.y, b.y, s)
		return Vector3(centro_x + x * escala, horizonte_y + (ALTURA_CAMERA - y) * escala, escala)
	return Vector3.ZERO


## Para a linha de tela `linha`, o que é a pista nela: o metro de percurso, o X
## do eixo e a escala, ou vazio se a linha cai fora do segmento `a`-`b`. É a
## mesma conta do `ponto`, ao contrário: dado o Y, achar o Z.
static func na_linha(a: Amostra, b: Amostra, linha: float) -> Vector3:
	var altura := a.tela_y - b.tela_y
	if altura <= 0.0:
		return Vector3.ZERO
	var t := clampf((a.tela_y - linha) / altura, 0.0, 1.0)
	# 1/Z é o que varia linear na tela dentro de um quadrilátero plano.
	var z := 1.0 / lerpf(1.0 / a.z, 1.0 / b.z, t)
	var s := (z - a.z) / (b.z - a.z) if b.z != a.z else 0.0
	return Vector3(lerpf(a.o, b.o, s), lerpf(a.x, b.x, s), FOCO / z)


## O rumo da pista no ponto, em radianos, na mesma convenção em que a pista é
## construída: `sin` no X e `cos` no Z.
static func rumo_em(track: RoadTrack, o: float) -> float:
	var frente := -track.sample_basis(o).z
	return atan2(frente.x, frente.z)
