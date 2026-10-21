class_name TremorDeCamera
extends RefCounted
## A regra do tremor de câmera, a mesma em toda câmera: quando treme e quanto.
##
## O Arthur achou o tremor "chato" e "aleatório". Tremer sempre, com a mesma
## força, não diz nada ao jogador; tremer só quando a moto está rápida, e mais
## quanto mais rápida, transforma o tremor em leitura de velocidade. Por isso
## a garupa e a perseguição leem esta classe, e nenhuma tem curva própria.

## O tremor de quem segura o celular: uma senoide por banda medida no vídeo
## (2-5, 5-10, 10-15 Hz), com frequências que não se repetem juntas. Ruído
## branco - um sorteio por quadro - lê como câmera digital chacoalhando; isto
## tem ritmo de braço e corpo em cima de uma moto.
const HZ: Array[float] = [2.7, 4.3, 7.1, 11.9]
## Amplitudes relativas de cada banda. Somam ~1 de valor eficaz
## (sqrt(sum(a^2) / 2) = 0,995), então o `nivel` de 1,0 é o tremor eficaz do
## slider, na mesma unidade dos 0,5-0,8 graus medidos no vídeo.
const PESO: Array[float] = [1.0, 0.8, 0.5, 0.3]
## Fração da `max_speed` abaixo da qual a câmera não treme: corredor lento,
## largada e parado ficam firmes, e o tremor aparece como aviso de pressa.
const COMECA_EM: float = 0.4
## O nível no boost cheio, em relação ao do cruzeiro (1,0 na `max_speed`). O
## pico do nitro é a única hora em que o tremor passa do slider.
const PICO_NO_BOOST: float = 1.4


## Quanto da amplitude do slider vale a esta velocidade: 0 até `COMECA_EM`,
## sobe suave até 1,0 na `max_speed` e segue até `PICO_NO_BOOST` na velocidade
## do boost. Caído é 0: na queda a câmera já leva o tranco da batida, e
## tremer por cima da capotada só suja a cena.
static func nivel(velocidade: float, tuning: BikeTuning, caido: bool = false) -> float:
	if caido:
		return 0.0
	var fracao := absf(velocidade) / maxf(tuning.max_speed, 1.0)
	var subida := smoothstep(COMECA_EM, 1.0, fracao)
	var boost := clampf(inverse_lerp(1.0, tuning.boost_speed_mult, fracao), 0.0, 1.0)
	return subida * lerpf(1.0, PICO_NO_BOOST, boost)


## A soma das bandas do tremor num eixo, com valor eficaz ~1. `fase` separa os
## eixos: com a mesma fase os três tremem juntos e a imagem só anda na
## diagonal.
static func banda(tempo: float, fase: float) -> float:
	var soma := 0.0
	for i in HZ.size():
		soma += PESO[i] * sin(TAU * (HZ[i] * tempo + fase * float(i + 1)))
	return soma
