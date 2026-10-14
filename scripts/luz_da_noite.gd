class_name LuzDaNoite
extends RefCounted
## As luzes que so existem de noite: poca do poste, cone do farol.
##
## Sao `SpotLight3D` de verdade, e nao so lampada brilhando: o que vende a rua
## de noite e o asfalto iluminado embaixo do poste e na frente do farol, e
## emissao nao ilumina o chao. Todas sem sombra - a sombra de quem passa
## embaixo do poste seria bonita, e custaria uma sombra por luz, que e o mais
## caro que o Forward+ tem.
##
## Nascem apagadas e invisiveis: de dia elas nao custam nada, e o `Relogio`
## acende cada uma quando o escuro passa do limiar dela.

## Onde a luz deixa de existir, em metros da camera. A neblina da noite ja
## cobriu metade do mundo a essa distancia, e e o que segura o numero de luzes
## por quadro em uma dezena e pouco, com 150 postes na avenida.
const SOME_A: float = 140.0


static func spot(
	cor: Color, energia: float, alcance: float, angulo: float, limiar: float
) -> SpotLight3D:
	var luz := SpotLight3D.new()
	luz.name = "LuzDaNoite"
	luz.light_color = cor
	luz.spot_range = alcance
	luz.spot_angle = angulo
	# Borda macia: o cone duro de um holofote vira um circulo serrilhado no
	# asfalto a 640x360.
	luz.spot_angle_attenuation = 0.6
	luz.shadow_enabled = false
	luz.distance_fade_enabled = true
	luz.distance_fade_begin = SOME_A - 30.0
	luz.distance_fade_length = 30.0
	# Nao entra na luz do ceu nem no GI: e luz de rua, nao de mundo.
	luz.light_bake_mode = Light3D.BAKE_DISABLED
	luz.visible = false
	luz.light_energy = 0.0
	luz.set_meta(&"limiar", limiar)
	luz.set_meta(&"energia", energia)
	luz.add_to_group(Relogio.GRUPO)
	return luz
