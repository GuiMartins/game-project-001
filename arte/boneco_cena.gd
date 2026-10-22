extends Node
## A bancada das folhas de referencia (`python tools/dev.py boneco`): a tela
## ortografica de fundo verde, a luz chapada e a grade que o Flow recebe.
##
## Pessoa, moto, carro, prop e fachada passam por aqui, cada um com o seu
## `arte/boneco_*.gd` so decidindo a pose. Camera, luz, fundo e captura sao os
## mesmos para todos de proposito: o Flow aprende a escala e o jeito de ler a
## luz de uma folha e espera o mesmo da seguinte.
##
## Cada folha e uma grade, uma linha por angulo e uma coluna por quadro, e
## sai com um `.json` do lado (grade, celula, pixels por metro, ponto do pe). O
## recorte (2D02) le a ficha, e nao adivinha a escala pelo nome do arquivo.
##
## Roda com tela: o renderizador do `--headless` e um dummy, e sai tudo preto.

const VERDE := Color(0.0, 1.0, 0.0)
## Pixels por metro das pessoas e das motos: um adulto de 1,75 m ocupa uns 340
## dos 400 de uma celula de pe, e sobra margem para o balanco do braco.
const PPM_PESSOA: float = 192.0
## Folga em volta do objeto na celula, em metros: o chao embaixo e o ar em cima.
const FOLGA: float = 0.4
## O maior lado de uma celula de objeto, em pixels.
const LADO_MAXIMO: float = 1400.0

var vp: SubViewport
var camera: Camera3D

var _raiz: Node


## Monta a bancada embaixo de `raiz`. O que se quer fotografar entra em `vp`.
func monta(raiz: Node) -> void:
	_raiz = raiz
	vp = SubViewport.new()
	vp.own_world_3d = true
	# Sem MSAA e sem suavizacao: a borda do boneco e o que o Flow vai ler, e
	# meio-tom no contorno vira halo na folha dele.
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	raiz.add_child(vp)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = VERDE
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.74, 0.78)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)

	# Luz de frente e de cima, a mesma de qualquer angulo: a folha de personagem
	# pede "luz chapada", e o boneco que muda de sombra a cada angulo ensina o
	# Flow a mudar tambem.
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-40.0, 0.0, 0.0)
	sol.light_energy = 0.9
	vp.add_child(sol)

	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	vp.add_child(camera)


## Cinza liso em tudo que e malha embaixo de `no`. Sem roupa nem pele nem
## pintura: um manequim, que e o que o Flow pode vestir do jeito que quiser.
func pinta(no: Node, cor: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cor
	mat.roughness = 1.0
	_pinta_com(no, mat)


func _pinta_com(no: Node, mat: StandardMaterial3D) -> void:
	if no is MeshInstance3D:
		var malha := no as MeshInstance3D
		malha.material_override = mat
	for filho in no.get_children():
		_pinta_com(filho, mat)


## A caixa de toda malha embaixo de `no`, no espaco de `no`.
func caixa_de(no: Node3D) -> AABB:
	var caixa := AABB()
	var primeira := true
	var pendentes: Array[Node] = [no]
	while not pendentes.is_empty():
		var atual: Node = pendentes.pop_back()
		pendentes.append_array(atual.get_children())
		var malha := atual as MeshInstance3D
		if malha == null or not malha.visible:
			continue
		var parte := (
			(no.global_transform.affine_inverse() * malha.global_transform) * malha.get_aabb()
		)
		caixa = parte if primeira else caixa.merge(parte)
		primeira = false
	return caixa


## Fotografa `no` (um prop, uma fachada) uma vez por giro de `giros`, em graus,
## numa linha so. A celula acompanha o objeto: a diagonal da planta de largura
## e o topo de altura, com `FOLGA` em volta, e o objeto gira em volta do meio
## da planta dele, e nao da origem do modelo. A escala e a `ppm_max`, ou a que
## cabe em `LADO_MAXIMO` px, se o objeto for grande: um guindaste de 30 m nao
## precisa de 4000 px para o Flow entender o desenho.
func objeto(nome: String, pasta: String, no: Node3D, giros: Array, ppm_max: float) -> void:
	var pivo := Node3D.new()
	vp.add_child(pivo)
	pivo.add_child(no)
	var caixa := caixa_de(no)
	no.position = -Vector3(
		caixa.position.x + caixa.size.x * 0.5, 0.0, caixa.position.z + caixa.size.z * 0.5
	)
	var diagonal := Vector2(caixa.size.x, caixa.size.z).length()
	# Alguns modelos (o poste) tem fundacao abaixo do chao: a celula guarda ate
	# ela, e o chao continua em y = 0.
	var abaixo := maxf(FOLGA, -caixa.position.y + 0.05)
	var celula := Vector2(diagonal + 2.0 * FOLGA, caixa.end.y + FOLGA + abaixo)
	var ppm := minf(ppm_max, LADO_MAXIMO / maxf(celula.x, celula.y))
	var posa := func(_linha: int, coluna: int) -> void: pivo.rotation.y = deg_to_rad(giros[coluna])
	await faz_folha(
		nome, pasta, giros.size(), 1, celula, celula.y * 0.5 - abaixo, ppm, posa, diagonal + 6.0
	)
	pivo.free()


## Faz uma folha de `colunas` x `linhas` quadros e salva em `pasta + nome + .png`.
## `posa` e chamada com (linha, coluna) antes de cada quadro e deixa a cena como
## ele deve sair. `celula_m` e o tamanho da celula em metros, `centro` a altura
## do meio da camera, `ppm` os pixels por metro.
##
## `distancia` e para onde a camera olha de longe: ortografica, so tem de ficar
## alem do que se fotografa.
func faz_folha(
	nome: String,
	pasta: String,
	colunas: int,
	linhas: int,
	celula_m: Vector2,
	centro: float,
	ppm: float,
	posa: Callable,
	distancia: float = 6.0
) -> void:
	var celula := Vector2i(roundi(celula_m.x * ppm), roundi(celula_m.y * ppm))
	vp.size = celula
	camera.size = celula_m.y
	camera.position = Vector3(0.0, centro, distancia)
	var img := Image.create(colunas * celula.x, linhas * celula.y, false, Image.FORMAT_RGB8)
	img.fill(VERDE)
	for linha in linhas:
		for coluna in colunas:
			posa.call(linha, coluna)
			await _quadro(img, coluna, linha, celula)
	DirAccess.make_dir_recursive_absolute(pasta)
	var caminho := pasta + nome + ".png"
	var erro := img.save_png(caminho)
	assert(erro == OK, "nao salvou " + caminho)
	_ficha(pasta + nome + ".json", colunas, linhas, celula, centro, celula_m, ppm)
	print("+ ", ProjectSettings.globalize_path(caminho), "  ", img.get_size())


## Pinta o quadro atual e cola na folha.
func _quadro(folha: Image, coluna: int, linha: int, celula: Vector2i) -> void:
	# Espera o desenho, e nao o quadro: com a janela atras de outra o macOS
	# segura o desenho e o `process_frame` continua chegando, e a folha saia
	# com a pose de outra coluna. Foi assim que o ciclo de andar e o susto das
	# folhas do Flow sairam embaralhados. O primeiro desenho depois de mexer
	# na cena pode ainda ser o da pose antiga; o segundo e o dela.
	for i in 2:
		await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	folha.blit_rect(img, Rect2i(Vector2i.ZERO, celula), Vector2i(coluna, linha) * celula)


## A ficha da folha. O pe (ou a base) e o ponto do chao no meio da celula: a
## camera olha o centro a `centro` m do chao, entao o chao esta `centro` m
## abaixo do meio da celula.
func _ficha(
	caminho: String,
	colunas: int,
	linhas: int,
	celula: Vector2i,
	centro: float,
	celula_m: Vector2,
	ppm: float
) -> void:
	var chao_y := (celula_m.y * 0.5 + centro) * ppm
	var ficha := {
		"colunas": colunas,
		"linhas": linhas,
		"celula": [celula.x, celula.y],
		"pixels_por_metro": ppm,
		"pe": [celula.x * 0.5, chao_y],
	}
	var arquivo := FileAccess.open(caminho, FileAccess.WRITE)
	assert(arquivo != null, "nao abriu " + caminho)
	arquivo.store_string(JSON.stringify(ficha, "\t") + "\n")
