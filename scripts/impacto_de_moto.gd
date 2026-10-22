class_name ImpactoDeMoto
extends RefCounted
## As regras de bater de uma moto, iguais para quem tem fisica (`PlayerBike`) e
## para quem anda paramétrico na curva (`RivalBike`).
##
## Cada batida vira uma de quatro coisas, nesta ordem: raspada, quina, quique ou
## queda. Quem mede a batida muda (o jogador le o `move_and_slide`, o rival le o
## sensor e a geometria do que encostou), mas a pergunta "isso derruba?" e a
## mesma, e por isso mora aqui, e nao copiada nos dois corpos: moto que cai por
## regra diferente da do jogador e rival andando de outro jeito.

## Quanto da velocidade de aproximacao volta como tranco, numa batida que nao
## derruba. Na traseira de um carro voce fica com a velocidade dele menos isto:
## sem o tranco, encostar no para-choque so freava, e frear nao e bater.
const QUIQUE: float = 0.3
## Segundos sem pilotar depois do quique. Curto: e o guidao que sacode na mao,
## nao a pancada de rival, que tira 0,7 s.
const TEMPO_DO_QUIQUE: float = 0.25
## Abaixo desta aproximacao (m/s) a batida e encostar, e nao bater. Encostar tira
## o embalo, nao o controle (V31).
const ENCOSTO: float = 5.0
## Segundos em que uma quina ou um quique nao se repete. O contato dura alguns
## passos de fisica, e cada um deles cobrava o tranco inteiro de novo.
const RESPIRO: float = 0.3


## A forca (0 a 1) com que uma moto de `velocidade` (horizontal, antes da
## batida) amassa o que tem a face `normal`.
##
## A velocidade toda conta, e nao so a componente contra a face: o poste e fino,
## e quem o pega de raspao a 140 km/h o amassa do mesmo jeito. De frente vale o
## dobro de uma raspada.
static func forca_no_amassavel(velocidade: Vector3, normal: Vector3, max_speed: float) -> float:
	var rapidez := velocidade.length()
	var de_frente := maxf(-velocidade.dot(normal), 0.0)
	var cheia := de_frente / maxf(rapidez, 0.01)
	return clampf(rapidez / max_speed * lerpf(0.4, 1.0, cheia), 0.0, 1.0)


## O quanto da relativa vai contra a face, de 0 (raspando) a 1 (de frente).
static func de_frente(chegada: float, relativa: Vector3) -> float:
	return clampf(chegada / maxf(relativa.length(), 0.01), 0.0, 1.0)


## O angulo de incidencia, em graus, de uma batida `de_frente` (0 a 1).
static func incidencia(frente: float) -> float:
	return rad_to_deg(asin(frente))


## Raspada: bateu de lado o bastante para so perder velocidade e seguir.
static func raspou(frente: float, t: BikeTuning, em_respiro: bool) -> bool:
	return incidencia(frente) <= t.crash_angle or em_respiro


## Se uma batida que nao foi raspada derruba. `poupado` e quem nao cai: moto nao
## derruba moto (o rival e da mesma altura, e na traseira dele quem leva a pior
## e o guidao, nao o corpo), e quem acabou de levantar tem um respiro.
static func derruba(chegada: float, t: BikeTuning, poupado: bool) -> bool:
	return not poupado and chegada >= t.crash_min_speed


## Para que lado a moto desvia numa quina: 0 se a batida pegou a face cheia, +1
## ou -1 (o lado do `centro`) se so uma ponta dela ficou em cima.
##
## Mede quanto da moto ficou em cima da face batida, ao longo dela, como fracao
## da mais estreita das duas. `centro` e onde a moto esta em relacao ao meio da
## face, `minha` e a meia largura dela nessa direcao e `meia_face` a da face.
## O ponto de contato nao serve: face contra face, o Godot devolve um canto da
## area de contato, e esse canto e quase sempre a borda da lataria.
static func lado_da_quina(centro: float, minha: float, meia_face: float, t: BikeTuning) -> float:
	var em_cima := minf(centro + minha, meia_face) - maxf(centro - minha, -meia_face)
	if em_cima >= t.corner_fraction * 2.0 * minf(minha, meia_face):
		return 0.0
	return 1.0 if centro >= 0.0 else -1.0
