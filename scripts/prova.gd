extends Node
## O quadro congelado da prova visual (P0 do `docs/PROVA_VISUAL.md`).
##
## `godot -- --prova` monta a corrida, poe o pelotao em cinco pontos fixos da
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
## Para cada quadro da prova, a referencia de enquadramento mais parecido.
## Escolhido a olho, quadro a quadro, e nao por medida: o que se compara e a
## cara da tela, e a pista do jogo tem curva e ladeira que o video nao tem.
##
## - `largada`: avenida larga e reta, carro do lado - o `t0.0s` e isso.
## - `curva`: o video nao faz curva; o `t3.8s` e o quadro com a moto mais
##   deitada e a rua abrindo para um lado.
## - `ladeira`: tambem nao ha ladeira; o `t1.0s` e o de horizonte mais alto.
## - `reta`: corredor de predio fechando no ponto de fuga, como no `t5.0s`.
## - `faixa`: a zebra chegando por baixo da moto, como no `t3.0s`.
##
## As imagens paradas (V01 do backlog visual) entram ao lado quando existirem;
## enquanto nao, ficam de fora sem reclamar, porque a folha continua servindo
## so com o video.
const REFERENCIAS: Dictionary = {
	"largada": ["video_01/t0.0s.png", "01_centro.png"],
	"curva": ["video_01/t3.8s.png", "04_vertical.png"],
	"ladeira": ["video_01/t1.0s.png", "03_viaduto.png"],
	"reta": ["video_01/t5.0s.png", "02_praca_maua.png"],
	"faixa": ["video_01/t3.0s.png"],
}
## Fundo do que sobra quando uma linha e mais curta que a mais longa. Cinza
## medio, e nao preto: preto se confunde com o tunel e a sombra do jogo.
const FUNDO := Color(0.5, 0.5, 0.5)
## As variantes da V03 do backlog visual ("quanto de pixel"), na ordem em que
## entram na linha da comparacao: como esta, sem o passe de paleta, e com o
## dither pela metade. `forca` negativa desliga o passe inteiro.
const VARIANTES_PIXEL: Array[Dictionary] = [
	{"nome": "atual", "forca": 1.0},
	{"nome": "sem_paleta", "forca": -1.0},
	{"nome": "dither_fraco", "forca": 0.5},
]
## O recorte da lupa das variantes: ceu, neblina, fachada e asfalto da
## largada, onde a banda e o padrao do dither aparecem. Na folha inteira as
## tres variantes ficam iguais a olho - a diferenca mora no pixel.
const LUPA := Rect2i(200, 40, 200, 150)
const LUPA_ESCALA: int = 3
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
	# `dev.py prova --garupa`: os mesmos quadros pela camera nova, para ajustar
	# a garupa contra um quadro fixo, e nao contra a lembranca.
	if OS.get_environment("RUSHFOOD_PROVA_CAMERA") == "garupa":
		_world.camera.mode = ChaseCamera.Mode.GARUPA
	_roda.call_deferred()


func _roda() -> void:
	var saida := OS.get_environment("RUSHFOOD_PROVA_DIR")
	if saida.is_empty():
		saida = ProjectSettings.globalize_path("res://.dev/prova")
	DirAccess.make_dir_recursive_absolute(saida)

	var variantes := OS.get_environment("RUSHFOOD_PROVA_VARIANTES") == "1"
	var linhas_variantes: Array[Array] = []
	var imagens: Array[Image] = []
	# `dev.py prova --kmh`: os quadros andando em outra velocidade. A largada
	# continua parada - e o quadro do piloto com o pe no chao.
	var velocidade := OS.get_environment("RUSHFOOD_PROVA_VELOCIDADE")
	for quadro: Dictionary in pontos(_world.track):
		var v: float = quadro["velocidade"]
		if v > 0.0 and velocidade.is_valid_float():
			v = velocidade.to_float()
		_world.start_race(quadro["offset"], v)
		await _passos(PASSOS)
		# A 180 km/h o pelotao do grid esta na frente, e em meio segundo a moto
		# ja freou nele. O quadro e de quem anda nessa velocidade: ela volta
		# para o velocimetro, que e o que o borrao le.
		if v > 0.0 and velocidade.is_valid_float():
			_world.player.speed = v
		_world.camera.encaixar()
		for i in QUADROS_DE_ESPERA:
			await RenderingServer.frame_post_draw
		var imagem := _captura()
		imagem.save_png("%s/%s.png" % [saida, quadro["nome"]])
		imagens.append(imagem)
		# `dev.py prova --variantes`: o mesmo quadro congelado com a paleta
		# trocada. O mundo nao anda entre uma captura e outra, entao so o
		# passe de cor muda - e e so ele que esta em julgamento.
		if variantes:
			var linha: Array[Image] = []
			for variante: Dictionary in VARIANTES_PIXEL:
				_paleta(variante["forca"])
				for i in QUADROS_DE_ESPERA:
					await RenderingServer.frame_post_draw
				linha.append(_captura())
			_paleta(1.0)
			linha.append_array(_referencias(quadro["nome"]))
			linhas_variantes.append(linha)
		print("prova: %-8s offset %6.0f m" % [quadro["nome"], quadro["offset"]])

	_folha(imagens).save_png("%s/folha.png" % saida)
	print("prova: %d quadros em %s" % [imagens.size(), saida])
	# `dev.py prova --referencia`: o quadro ao lado do que ele quer parecer.
	# E a pergunta da P9, e comparar o jogo so com ele mesmo nao a responde.
	if OS.get_environment("RUSHFOOD_PROVA_REFERENCIA") == "1":
		var linhas: Array[Array] = []
		for i in imagens.size():
			var nome: String = pontos(_world.track)[i]["nome"]
			var linha: Array[Image] = [imagens[i]]
			linha.append_array(_referencias(nome))
			linhas.append(linha)
		comparacao(linhas).save_png("%s/comparacao.png" % saida)
		print("prova: comparacao com a referencia em %s/comparacao.png" % saida)
	if variantes:
		comparacao(linhas_variantes).save_png("%s/variantes.png" % saida)
		lupa(linhas_variantes[0].slice(0, VARIANTES_PIXEL.size())).save_png(
			"%s/variantes_lupa.png" % saida
		)
		# Cada variante da largada em tela cheia de 1080p, um arquivo por
		# variante: e o tamanho em que o jogador ve, e trocar de arquivo no
		# visualizador mostra a diferenca melhor que qualquer folha.
		for i in VARIANTES_PIXEL.size():
			var cheia := (linhas_variantes[0][i] as Image).duplicate() as Image
			cheia.resize(cheia.get_width() * 3, cheia.get_height() * 3, Image.INTERPOLATE_NEAREST)
			cheia.save_png("%s/variante_%d_%s.png" % [saida, i + 1, VARIANTES_PIXEL[i]["nome"]])
		print("prova: variantes de pixel em %s/variantes.png" % saida)
	get_tree().quit(0)


func _captura() -> Image:
	var sub: SubViewport = _main.get("sub_viewport")
	return sub.get_texture().get_image()


## Troca a forca do dither do passe de paleta; negativa esconde o passe.
func _paleta(forca: float) -> void:
	var camada: CanvasLayer = (_main.get("sub_viewport") as Node).get_node("Paleta")
	camada.visible = forca >= 0.0
	var tela := camada.get_child(0) as ColorRect
	(tela.material as ShaderMaterial).set_shader_parameter("forca", maxf(forca, 0.0))


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
	# A primeira zebra longe da largada, entrando no quadro como a do `t3.0s`:
	# a retencao a uns 25 m da camera, a zebra inteira no chao do quadro.
	for c in track.cruzamentos:
		if c.x > 150.0:
			var zebra := c.x - track.boca - RoadTrack.ZEBRA_ESQUINA - RoadTrack.ZEBRA_COMPRIMENTO
			lista.append({"nome": "faixa", "offset": zebra - 38.0, "velocidade": 25.0})
			break
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


## As referencias de um quadro que existem no disco, na ordem de `REFERENCIAS`.
## Le o PNG direto, e nao como recurso: `docs/` tem `.gdignore`, e video de
## referencia importado iria parar dentro do jogo exportado.
static func _referencias(nome: String) -> Array[Image]:
	var pasta := ProjectSettings.globalize_path("res://docs/referencias")
	var achadas: Array[Image] = []
	for arquivo: String in REFERENCIAS.get(nome, []):
		var caminho := "%s/%s" % [pasta, arquivo]
		if not FileAccess.file_exists(caminho):
			continue
		var imagem := Image.load_from_file(caminho)
		if imagem != null:
			achadas.append(imagem)
	return achadas


## Uma linha por quadro: o jogo e, a direita, cada referencia na altura dele.
## A referencia e que se ajusta, nunca o jogo: o pixel do jogo e o que esta em
## julgamento, e esticar ele com filtro esconderia justamente o bloco de pixel.
static func comparacao(linhas: Array[Array]) -> Image:
	var h: int = (linhas[0][0] as Image).get_height()
	var formato := Image.FORMAT_RGBA8
	var prontas: Array[Array] = []
	var largura := 0
	for linha in linhas:
		var pronta: Array[Image] = []
		var w := 0
		for original: Image in linha:
			var imagem := original.duplicate() as Image
			imagem.convert(formato)
			if imagem.get_height() != h:
				var nova_w := roundi(imagem.get_width() * float(h) / imagem.get_height())
				imagem.resize(nova_w, h, Image.INTERPOLATE_BILINEAR)
			pronta.append(imagem)
			w += imagem.get_width()
		prontas.append(pronta)
		largura = maxi(largura, w)
	var folha := Image.create(largura, h * linhas.size(), false, formato)
	folha.fill(FUNDO)
	for i in prontas.size():
		var x := 0
		for imagem: Image in prontas[i]:
			var tamanho := Rect2i(Vector2i.ZERO, imagem.get_size())
			folha.blit_rect(imagem, tamanho, Vector2i(x, i * h))
			x += imagem.get_width()
	return folha


## O mesmo recorte de cada imagem, ampliado sem filtro e lado a lado.
static func lupa(imagens: Array) -> Image:
	var w := LUPA.size.x * LUPA_ESCALA
	var h := LUPA.size.y * LUPA_ESCALA
	var folha := Image.create(w * imagens.size(), h, false, Image.FORMAT_RGBA8)
	for i in imagens.size():
		var recorte := (imagens[i] as Image).get_region(LUPA)
		recorte.convert(Image.FORMAT_RGBA8)
		recorte.resize(w, h, Image.INTERPOLATE_NEAREST)
		folha.blit_rect(recorte, Rect2i(Vector2i.ZERO, recorte.get_size()), Vector2i(i * w, 0))
	return folha
