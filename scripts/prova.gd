extends Node
## O quadro congelado da prova visual (P0 do `docs/PROVA_VISUAL.md`).
##
## `godot -- --prova` monta a corrida, poe o pelotao em quatro pontos fixos da
## pista e salva o que o SubViewport desenhou em cada um. Sem isto, toda
## comparacao de visual e contra um print diferente - outro instante, outro
## transito, outra camera -, e "melhorou?" deixa de ter resposta. E o mesmo
## raciocinio que fixou a semente do banco de provas.
##
## Tres coisas fazem o quadro ser o mesmo de uma rodada para outra:
##
## - O mundo congela antes do primeiro passo de fisica. O que se move por
##   tempo - moto, rivais, transito, camera - dependeria de quantos quadros
##   couberam em cada passo, e isso muda com a maquina.
## - A camera e encaixada, nao perseguida: o atraso dela tambem e por tempo.
## - A HUD fica de fora. Ela tem relogio proprio (a dica de teclas some em
##   7 s), e e assunto da P8.

## Quadros que o motor desenha antes da captura. O primeiro depois de mexer na
## cena pode sair com a cena antiga; tres e folga.
const QUADROS_DE_ESPERA: int = 3
## Passos de fisica entre largar e congelar: meio segundo. Um so ja poria rival
## e carro no lugar, mas o piloto nasce parado e com o pe no chao, e em meio
## segundo a 25 m/s ele recolheu o pe - o quadro mostra a pose de quem anda.
const PASSOS: int = 30

var _main: Node
var _world: World


func setup(main: Node) -> void:
	_main = main
	_world = main.get("world")
	# Congela AGORA, antes de a fisica rodar um passo sequer: e o que faz a
	# pose de todos sair igual, a de repouso.
	_world.process_mode = Node.PROCESS_MODE_DISABLED
	(main.get("hud") as CanvasLayer).visible = false
	_roda.call_deferred()


func _roda() -> void:
	var saida := OS.get_environment("RUSHFOOD_PROVA_DIR")
	if saida.is_empty():
		saida = ProjectSettings.globalize_path("res://.dev/prova")
	DirAccess.make_dir_recursive_absolute(saida)

	var imagens: Array[Image] = []
	for quadro: Dictionary in pontos(_world.track):
		_world.start_race(quadro["offset"], quadro["velocidade"])
		await _passos(PASSOS)
		_world.camera.encaixar()
		for i in QUADROS_DE_ESPERA:
			await RenderingServer.frame_post_draw
		var sub: SubViewport = _main.get("sub_viewport")
		var imagem := sub.get_texture().get_image()
		imagem.save_png("%s/%s.png" % [saida, quadro["nome"]])
		imagens.append(imagem)
		print("prova: %-8s offset %6.0f m" % [quadro["nome"], quadro["offset"]])

	_folha(imagens).save_png("%s/folha.png" % saida)
	print("prova: %d quadros em %s" % [imagens.size(), saida])
	get_tree().quit(0)


## Deixa o mundo rodar exatamente `n` passos de fisica e congela de novo.
##
## Rival e carro sao corpos sincronizados com a fisica: a posicao que o
## `start_race` da a eles so vale no passo seguinte, e sem passo nenhum eles
## ficam desenhados na origem do mundo. Conta em passos, e nao em quadros nem
## em segundos de relogio: o passo tem duracao fixa, e o resultado de `n`
## passos e o mesmo em qualquer maquina.
##
## `physics_frame` sai ANTES de cada passo. O primeiro await acorda antes do
## passo 1; cada await seguinte acorda depois de um passo inteiro.
func _passos(n: int) -> void:
	_world.process_mode = Node.PROCESS_MODE_INHERIT
	for i in n + 1:
		await get_tree().physics_frame
	_world.process_mode = Node.PROCESS_MODE_DISABLED


## Os pontos da pista que entram no quadro. Escolhidos pela geometria, e nao
## por offset digitado: "a curva mais fechada" continua sendo a curva mais
## fechada se alguem mexer no tamanho da pista.
##
## O pelotao larga do grid em cada ponto, entao todo quadro tem rival na frente
## - e o ator e metade do que a prova quer comparar.
static func pontos(track: RoadTrack) -> Array[Dictionary]:
	var lista: Array[Dictionary] = [{"nome": "largada", "offset": 0.0, "velocidade": 0.0}]
	var usados: Array[float] = [0.0]

	var curva := _melhor(track, usados, func(o: float) -> float: return _curvatura(track, o))
	usados.append(curva)
	var ladeira := _melhor(track, usados, func(o: float) -> float: return track.grade_at(o))
	usados.append(ladeira)
	var reta := _melhor(
		track,
		usados,
		func(o: float) -> float: return -_curvatura(track, o) - absf(track.grade_at(o)) * 0.5
	)

	# O grid poe o jogador 12 m a frente do offset pedido; recuar 40 m deixa o
	# trecho que interessa entre 20 e 50 m a frente da camera.
	lista.append({"nome": "curva", "offset": curva - 40.0, "velocidade": 25.0})
	lista.append({"nome": "ladeira", "offset": ladeira - 40.0, "velocidade": 25.0})
	lista.append({"nome": "reta", "offset": reta - 40.0, "velocidade": 25.0})
	return lista


## Quanto a pista vira nos proximos 40 m, em radianos.
static func _curvatura(track: RoadTrack, o: float) -> float:
	var a := -track.sample_basis(o).z
	var b := -track.sample_basis(o + 40.0).z
	return absf(wrapf(atan2(b.x, b.z) - atan2(a.x, a.z), -PI, PI))


## O offset de maior nota, longe da largada, da chegada e dos ja escolhidos.
static func _melhor(track: RoadTrack, usados: Array[float], nota: Callable) -> float:
	var melhor := 150.0
	var melhor_nota := -INF
	var o := 150.0
	while o < track.length - 300.0:
		var longe := true
		for u in usados:
			if absf(o - u) < 250.0:
				longe = false
		if longe:
			var n: float = nota.call(o)
			if n > melhor_nota:
				melhor_nota = n
				melhor = o
		o += 5.0
	return melhor


## Os quadros numa imagem so, em grade de dois por linha, para ver de uma vez.
static func _folha(imagens: Array[Image]) -> Image:
	var w := imagens[0].get_width()
	var h := imagens[0].get_height()
	var linhas := ceili(imagens.size() / 2.0)
	var folha := Image.create(w * 2, h * linhas, false, imagens[0].get_format())
	for i in imagens.size():
		var pos := Vector2i((i % 2) * w, (i / 2) * h)
		folha.blit_rect(imagens[i], Rect2i(0, 0, w, h), pos)
	return folha
