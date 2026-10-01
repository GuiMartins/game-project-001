class_name MedidaDeQuadro
extends RefCounted
## As tres proporcoes que a regressao visual compara (`dev.py shots`).
##
## Nao e comparacao pixel a pixel: driver e GPU mudam o ultimo bit de quase todo
## pixel. Isto pega a tela ficar ERRADA POR INTEIRO - a pista sumir, o mundo
## apagar -, que e o que nenhuma medida de fisica pega. Mora fora do banco de
## provas porque e outra pergunta: ele mede a moto; isto mede a tela.


## Ceu, luminancia e familias de cor de um quadro, amostrados de 4 em 4 pixels.
##
## A amostragem existe porque isto roda a cada 2,5 s de simulacao e um viewport
## inteiro sao 900 mil leituras de pixel em GDScript. De 4 em 4 sao 57 mil, e a
## proporcao nao muda.
##
## `ceu` e o mesmo quadro desenhado sem geometria nenhuma (ver
## `_captura_ceu` no `selftest.gd`). Pixel igual ao dele na mesma posicao e
## ceu - ou seja, lugar onde NAO ha mundo desenhado. Vazio se a imagem for.
static func medir(image: Image, ceu: Image) -> Dictionary:
	var w := image.get_width()
	var h := image.get_height()
	if w == 0 or h == 0:
		return {}

	var sky_hits := 0
	var luma := 0.0
	var seen := {}
	var total := 0
	for y in range(0, h, 4):
		for x in range(0, w, 4):
			var c := image.get_pixel(x, y)
			total += 1
			luma += c.get_luminance()
			# Pouco mais de um degrau da quantizacao (1/15 = 0,067, ver
			# `paleta.gdshader`): entre a referencia e o quadro a camera anda
			# dois quadros, e o pixel que estava na borda de uma banda pode cair
			# no degrau vizinho sem deixar de ser ceu.
			var sky := ceu.get_pixel(x, y)
			if absf(c.r - sky.r) < 0.08 and absf(c.g - sky.g) < 0.08 and absf(c.b - sky.b) < 0.08:
				sky_hits += 1
			# Cor quantizada em 5 niveis por canal: conta quantas familias de
			# cor a cena tem, sem contar ruido de sombreamento como cor nova.
			var key := (int(c.r * 4.0) << 6) | (int(c.g * 4.0) << 3) | int(c.b * 4.0)
			seen[key] = true

	return {
		"ceu": float(sky_hits) / float(total),
		"luminancia": luma / float(total),
		"familias": float(seen.size()),
	}
