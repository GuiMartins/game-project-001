class_name TelaProjetor
extends Node2D
## A prova do projetor (2D05): uma tela 2D de 640 x 360 com a pista de verdade
## (`RoadTrack`) projetada por `ProjetorPista`, o asfalto e a calçada que o
## jogo já tem, e os sprites que já existem (a CG, as pessoas, o poste e as
## árvores). Não é o jogo: não há trânsito, rival, colisão nem som, só o que
## responde à pergunta "acelerar, inclinar e ver a pista passar está gostoso em
## pseudo-3D?" antes de gastar as ~80 gerações do Flow.
##
## Tudo aqui é provisório e de propósito: se a prova passar, o projetor vira o
## renderizador do jogo (2D63 em diante) e o que está neste arquivo é jogado
## fora ou reescrito.

const LARGURA: int = 640
const ALTURA: int = 360
const HORIZONTE: int = 150
## A moto fica a esta distância da câmera, em metros.
const Z_DA_MOTO: float = 3.5
## Pixels por metro em que o atlas da CG foi desenhado (`ALTURA_PX` pelo
## piloto de ~1,5 m), e dos pedestres (`PedestreSprite.PPM`).
const MOTO_PPM: float = 80.0
const COMPRIMENTO_DA_PROVA: float = 6000.0
const SEMENTE: int = 20260831

const VELOCIDADE_MAX: float = 58.0
const ACELERACAO: float = 14.0
const FREIO: float = 30.0
## Metros por segundo de deslocamento lateral com o guidão todo de um lado.
const VELOCIDADE_LATERAL: float = 9.0
## Quanto a curva empurra a moto para fora: aceleração lateral = v² · curvatura
## · este fator. 1 seria a física inteira; a prova quer sentir a curva sem
## brigar com ela.
const EMPURRAO_DA_CURVA: float = 0.25
## Quanto o guidão demora a ir de um lado ao outro, por segundo.
const RESPOSTA_DA_INCLINACAO: float = 7.0

const CEU_ALTO := Color(0.36, 0.55, 0.82)
const CEU_BAIXO := Color(0.78, 0.86, 0.93)
const CHAO := Color(0.17, 0.17, 0.18)
const MEIO_FIO := Color(0.72, 0.70, 0.66)
const SERVICO := Color(0.22, 0.22, 0.23)
const TINTA := Color(0.90, 0.89, 0.84)
const AMARELO := Color(0.88, 0.70, 0.20)
const PAREDES: Array[Color] = [
	Color(0.62, 0.55, 0.48),
	Color(0.46, 0.52, 0.58),
	Color(0.70, 0.64, 0.52),
	Color(0.52, 0.42, 0.40),
	Color(0.58, 0.60, 0.56),
]
## Faixa de serviço entre a calçada e a fachada (`RoadTrack.FAIXA_SERVICO`).
const RECUO_DA_FACHADA: float = 1.6
const BLOCO: float = 26.0
const ESPACO_DO_POSTE: float = 18.0
const ESPACO_DA_ARVORE: float = 44.0
const ESPACO_DA_PESSOA: float = 30.0

## Velocidade do passo dos pedestres, em quadros por segundo, e em metros por
## segundo ao longo da pista.
const PASSO_DA_PESSOA_FPS: float = 9.0
const VELOCIDADE_DA_PESSOA: float = 1.3

var automatico: bool = false
## O teto de velocidade, em m/s: `--vel=` baixa para olhar o que passa devagar.
var teto: float = VELOCIDADE_MAX
var velocidade: float = 0.0
var percurso: float = 0.0
var lateral: float = 0.0
var inclinacao: float = 0.0

var _track: RoadTrack
var _projetor := ProjetorPista.new()
var _tempo: float = 0.0
## Para cada amostra, a linha de tela até onde as amostras mais perto já
## taparam: o que cai abaixo dela está atrás de uma crista.
var _cobertura: Array[int] = []
var _pessoas: Array[CatalogoSprites.Item] = []
var _props: Dictionary = {}
## Quem segura as texturas. O `Item.textura()` devolve um `load`, e uma textura
## que ninguem mais segura e liberada antes de o desenho gravado no `_draw` ser
## executado: o sprite sai como retangulo branco.
var _texturas: Dictionary = {}


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_projetor.horizonte_y = HORIZONTE
	_projetor.centro_x = LARGURA * 0.5
	_track = RoadTrack.new()
	add_child(_track)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEMENTE
	_track.build(COMPRIMENTO_DA_PROVA, rng)
	for item in CatalogoSprites.varrer():
		_texturas[item.id] = item.textura()
		if item.tipo == CatalogoSprites.Tipo.PROP:
			_props[item.id] = item
		elif item.tipo == CatalogoSprites.Tipo.PEDESTRE and item.animacao == "andando":
			_pessoas.append(item)


func _process(delta: float) -> void:
	_tempo += delta
	var guidao := _guidao()
	var acelera := (
		automatico or Input.is_physical_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_W)
	)
	var freia := Input.is_physical_key_pressed(KEY_DOWN) or Input.is_physical_key_pressed(KEY_S)
	if acelera:
		velocidade = minf(velocidade + ACELERACAO * delta, teto)
	elif freia:
		velocidade = maxf(velocidade - FREIO * delta, 0.0)
	else:
		velocidade = maxf(velocidade - ACELERACAO * 0.25 * delta, 0.0)
	inclinacao = move_toward(inclinacao, guidao, RESPOSTA_DA_INCLINACAO * delta)
	var curvatura := _curvatura(percurso)
	lateral += (
		inclinacao * VELOCIDADE_LATERAL * (0.35 + velocidade / VELOCIDADE_MAX) * delta
		# Rumo positivo é curva para a esquerda: a moto escapa para a direita.
		+ curvatura * velocidade * velocidade * EMPURRAO_DA_CURVA * delta
	)
	var limite := RoadTrack.sidewalk_limit() - 0.6
	lateral = clampf(lateral, -limite, limite)
	percurso += velocidade * delta
	if percurso > _track.length - ProjetorPista.VISAO - 40.0:
		percurso = 0.0
	queue_redraw()


func _guidao() -> float:
	if automatico:
		return clampf(sin(_tempo * 0.7) * 0.9 - lateral * 0.12, -1.0, 1.0)
	var guidao := 0.0
	if Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A):
		guidao -= 1.0
	if Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D):
		guidao += 1.0
	return guidao


## Quanto a pista vira por metro logo à frente, em radianos, + para a esquerda.
func _curvatura(o: float) -> float:
	var a := ProjetorPista.rumo_em(_track, o)
	var b := ProjetorPista.rumo_em(_track, minf(o + 25.0, _track.length))
	return wrapf(b - a, -PI, PI) / 25.0


# --- desenho ---------------------------------------------------------------


func _draw() -> void:
	if _track == null:
		return
	_ceu()
	_projetor.projetar(_track, percurso - Z_DA_MOTO, lateral)
	_chao()
	_fachadas()
	_sprites()
	_painel()


func _ceu() -> void:
	var cantos := PackedVector2Array(
		[Vector2(0, 0), Vector2(LARGURA, 0), Vector2(LARGURA, HORIZONTE), Vector2(0, HORIZONTE)]
	)
	var cores := PackedColorArray([CEU_ALTO, CEU_ALTO, CEU_BAIXO, CEU_BAIXO])
	draw_polygon(cantos, cores)
	draw_rect(Rect2(0, HORIZONTE, LARGURA, ALTURA - HORIZONTE), CHAO)


## O chão linha a linha: para cada linha de tela, o metro de pista que ela vê, e
## as faixas (asfalto, meio-fio, calçada, serviço) que passam por ali. É a única
## forma de a textura ter perspectiva certa sem um shader.
func _chao() -> void:
	var asfalto: Texture2D = RoadTrack.ASFALTO
	var calcada: Texture2D = RoadTrack.CALCADA
	var meia := RoadTrack.half_width()
	var calcada_ate := RoadTrack.sidewalk_limit()
	var amostras := _projetor.amostras
	_cobertura.clear()
	var coberto := ALTURA
	for j in amostras.size() - 1:
		_cobertura.append(coberto)
		var a := amostras[j]
		var b := amostras[j + 1]
		# Atrás de uma crista: a amostra seguinte não sobe na tela.
		if b.tela_y >= a.tela_y or b.tela_y >= coberto:
			continue
		var topo := maxi(int(ceil(b.tela_y)), 0)
		var base := coberto - 1 if j == 0 else mini(int(floor(a.tela_y)), coberto - 1)
		for linha in range(topo, base + 1):
			var p := ProjetorPista.na_linha(a, b, float(linha) + 0.5)
			if p == Vector3.ZERO:
				continue
			_linha_do_chao(linha, p, asfalto, calcada, meia, calcada_ate)
		coberto = mini(coberto, topo)
	_cobertura.append(coberto)


func _linha_do_chao(
	linha: int, p: Vector3, asfalto: Texture2D, calcada: Texture2D, meia: float, calcada_ate: float
) -> void:
	var o := p.x
	var cx := _projetor.centro_x + p.y * p.z
	var escala := p.z
	# Só o fundo da linha: o chão e a faixa de serviço.
	draw_rect(Rect2(0, linha, LARGURA, 1), CHAO)
	_faixa(calcada, RoadTrack.CALCADA_TILE, -calcada_ate, -meia - 0.2, cx, escala, linha, o)
	_faixa(calcada, RoadTrack.CALCADA_TILE, meia + 0.2, calcada_ate, cx, escala, linha, o)
	_faixa(asfalto, RoadTrack.ASFALTO_TILE, -meia, meia, cx, escala, linha, o)
	_cor(MEIO_FIO, -meia - 0.2, -meia, cx, escala, linha)
	_cor(MEIO_FIO, meia, meia + 0.2, cx, escala, linha)
	_cor(SERVICO, calcada_ate, calcada_ate + RECUO_DA_FACHADA, cx, escala, linha)
	_cor(SERVICO, -calcada_ate - RECUO_DA_FACHADA, -calcada_ate, cx, escala, linha)
	_marcas(linha, o, cx, escala)


## As faixas pintadas: borda contínua, divisórias tracejadas e a dupla amarela
## do meio, como em `RoadTrack.pintar`.
func _marcas(linha: int, o: float, cx: float, escala: float) -> void:
	var meia := RoadTrack.half_width()
	var faixa := RoadTrack.LANE_WIDTH
	_cor(TINTA, -meia + 0.15, -meia + 0.35, cx, escala, linha)
	_cor(TINTA, meia - 0.35, meia - 0.15, cx, escala, linha)
	_cor(AMARELO, -0.24, -0.12, cx, escala, linha)
	_cor(AMARELO, 0.12, 0.24, cx, escala, linha)
	if fposmod(o, 9.0) < 4.5:
		for k: float in [-1.0, 1.0]:
			_cor(TINTA, k * faixa - 0.08, k * faixa + 0.08, cx, escala, linha)


## Uma faixa de textura entre dois laterais, com o mapa preso à pista (e não à
## tela) e a linha da textura escolhida pelo metro de percurso.
func _faixa(
	textura: Texture2D,
	ladrilho: float,
	de: float,
	ate: float,
	cx: float,
	escala: float,
	linha: int,
	o: float
) -> void:
	var x0 := cx + de * escala
	var x1 := cx + ate * escala
	var ini := maxf(x0, 0.0)
	var fim := minf(x1, float(LARGURA))
	if fim - ini < 1.0:
		return
	var tamanho := textura.get_size()
	var lat_ini := (ini - cx) / escala
	var lat_fim := (fim - cx) / escala
	var v := floorf(fposmod(o / ladrilho, 1.0) * tamanho.y)
	var u0 := (lat_ini / ladrilho + 64.0) * tamanho.x
	var largura_u := (lat_fim - lat_ini) / ladrilho * tamanho.x
	draw_texture_rect_region(textura, Rect2(ini, linha, fim - ini, 1), Rect2(u0, v, largura_u, 1))


func _cor(cor: Color, de: float, ate: float, cx: float, escala: float, linha: int) -> void:
	var x0 := maxf(cx + de * escala, 0.0)
	var x1 := minf(cx + ate * escala, float(LARGURA))
	# Pelo menos um pixel: a faixa fina de longe vira um pontilhado, que é o que
	# o olho espera dela, e não some.
	if x1 < x0 + 1.0:
		x1 = x0 + 1.0
		if x0 >= LARGURA or x1 <= 0.0:
			return
	draw_rect(Rect2(x0, linha, x1 - x0, 1), cor)


## Os prédios dos dois lados: um quadrilátero por quarteirão, de frente para a
## pista, do mais longe ao mais perto. Cortados na crista, para não vazarem
## pela rampa na frente deles.
func _fachadas() -> void:
	var lado_de_fora := RoadTrack.sidewalk_limit() + RECUO_DA_FACHADA
	var inicial := floorf((percurso - Z_DA_MOTO) / BLOCO)
	var ultimo_bloco := floorf((percurso - Z_DA_MOTO + ProjetorPista.VISAO) / BLOCO)
	var b := ultimo_bloco
	while b >= inicial:
		for lado: float in [-1.0, 1.0]:
			_fachada(int(b), lado, lado_de_fora)
		b -= 1.0


func _fachada(bloco: int, lado: float, recuo: float) -> void:
	var o0 := maxf(float(bloco) * BLOCO, percurso - Z_DA_MOTO + ProjetorPista.Z_INICIAL + 0.5)
	var o1 := float(bloco + 1) * BLOCO
	if o1 <= o0:
		return
	var semente := hash(bloco * 2 + (1 if lado > 0.0 else 0))
	var altura := 9.0 + float(semente % 31)
	var perto := _projetor.ponto(o0, lado * recuo)
	var longe := _projetor.ponto(o1, lado * recuo)
	if perto == Vector3.ZERO or longe == Vector3.ZERO:
		return
	var cor := PAREDES[semente % PAREDES.size()]
	var corte := _corte_em(o1)
	var poligono := PackedVector2Array(
		[
			Vector2(perto.x, perto.y),
			Vector2(longe.x, longe.y),
			Vector2(longe.x, longe.y - altura * longe.z),
			Vector2(perto.x, perto.y - altura * perto.z)
		]
	)
	_poligono_cortado(poligono, cor, corte)
	# As janelas: uma faixa escura a cada três metros de altura.
	var andares := int(altura / 3.0)
	for andar in range(1, andares):
		var h := float(andar) * 3.0
		var janela := PackedVector2Array(
			[
				Vector2(perto.x, perto.y - h * perto.z),
				Vector2(longe.x, longe.y - h * longe.z),
				Vector2(longe.x, longe.y - (h + 1.4) * longe.z),
				Vector2(perto.x, perto.y - (h + 1.4) * perto.z)
			]
		)
		_poligono_cortado(janela, cor.darkened(0.45), corte)


## Até que linha de tela o que está a `o` metros de percurso pode ser visto.
func _corte_em(o: float) -> float:
	var amostras := _projetor.amostras
	for j in amostras.size() - 1:
		if o <= amostras[j + 1].o:
			return float(_cobertura[j]) if j < _cobertura.size() else float(ALTURA)
	return float(ALTURA)


func _poligono_cortado(poligono: PackedVector2Array, cor: Color, corte: float) -> void:
	if corte >= ALTURA:
		draw_colored_polygon(poligono, cor)
		return
	var janela := PackedVector2Array(
		[
			Vector2(-50, -2000),
			Vector2(LARGURA + 50, -2000),
			Vector2(LARGURA + 50, corte),
			Vector2(-50, corte)
		]
	)
	for pedaco in Geometry2D.intersect_polygons(poligono, janela):
		if Geometry2D.triangulate_polygon(pedaco).size() > 0:
			draw_colored_polygon(pedaco, cor)


# --- sprites ---------------------------------------------------------------


## Tudo o que está de pé na pista, do mais longe ao mais perto, com a moto no
## lugar dela entre os dois.
func _sprites() -> void:
	var camera_o := percurso - Z_DA_MOTO
	var fila: Array[Dictionary] = []
	_postes(camera_o, fila)
	_arvores(camera_o, fila)
	_gente(camera_o, fila)
	fila.append({"o": percurso, "moto": true})
	fila.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return x["o"] > y["o"])
	for coisa in fila:
		if coisa.has("moto"):
			_moto()
		else:
			_desenha_coisa(coisa)


func _postes(camera_o: float, fila: Array[Dictionary]) -> void:
	var meia := RoadTrack.half_width()
	var primeiro := ceili((camera_o + ProjetorPista.Z_INICIAL) / ESPACO_DO_POSTE)
	var ultimo := floori((camera_o + ProjetorPista.VISAO) / ESPACO_DO_POSTE)
	for i in range(primeiro, ultimo + 1):
		var lado := 1.0 if i % 2 == 0 else -1.0
		fila.append(
			{"item": _props.get("poste"), "o": i * ESPACO_DO_POSTE, "lat": lado * (meia + 1.0)}
		)


func _arvores(camera_o: float, fila: Array[Dictionary]) -> void:
	var meia := RoadTrack.half_width()
	var primeiro := ceili((camera_o + ProjetorPista.Z_INICIAL) / ESPACO_DA_ARVORE)
	var ultimo := floori((camera_o + ProjetorPista.VISAO) / ESPACO_DA_ARVORE)
	for i in range(primeiro, ultimo + 1):
		var semente := hash(i)
		var lado := 1.0 if semente % 2 == 0 else -1.0
		var qual: String = "copa" if (semente / 2) % 3 != 0 else "palmeira"
		fila.append(
			{
				"item": _props.get(qual),
				"o": i * ESPACO_DA_ARVORE + float(semente % 7),
				"lat": lado * (meia + 1.9)
			}
		)


## Os pedestres da calçada, sorteados por trecho de pista (e não por tempo), para
## cada trecho ter sempre a mesma gente e a prova ser comparável.
func _gente(camera_o: float, fila: Array[Dictionary]) -> void:
	if _pessoas.is_empty():
		return
	var meia := RoadTrack.half_width()
	var primeiro := ceili((camera_o + ProjetorPista.Z_INICIAL) / ESPACO_DA_PESSOA)
	var ultimo := floori((camera_o + ProjetorPista.VISAO) / ESPACO_DA_PESSOA)
	for i in range(primeiro, ultimo + 1):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(i * 31 + 7)
		if rng.randf() < 0.3:
			continue
		var sentido := 1.0 if rng.randf() < 0.5 else -1.0
		var lado := 1.0 if rng.randf() < 0.5 else -1.0
		var o := i * ESPACO_DA_PESSOA + rng.randf() * ESPACO_DA_PESSOA
		(
			fila
			. append(
				{
					"item": _pessoas[rng.randi() % _pessoas.size()],
					"o": o + sentido * VELOCIDADE_DA_PESSOA * _tempo,
					"lat": lado * (meia + 0.6 + rng.randf() * 1.2),
					"sentido": sentido,
					"fase": rng.randf() * 8.0,
				}
			)
		)


func _desenha_coisa(coisa: Dictionary) -> void:
	var item: CatalogoSprites.Item = coisa["item"]
	if item == null:
		return
	var p := _projetor.ponto(coisa["o"], coisa["lat"])
	if p == Vector3.ZERO:
		return
	var corte := _corte_em(coisa["o"])
	if p.y >= corte:
		return
	var textura: Texture2D = _texturas.get(item.id)
	if textura == null:
		return
	var coluna := 0
	var linha := 0
	var espelha := false
	if coisa.has("sentido"):
		coluna = int(coisa["fase"] + _tempo * PASSO_DA_PESSOA_FPS) % maxi(item.colunas, 1)
		var qual := _angulo_da_pessoa(item, p.x, coisa["sentido"])
		linha = qual[0]
		espelha = qual[1]
	var k := p.z / item.pixels_por_metro
	_sprite(textura, item, coluna, linha, Vector2(p.x, p.y), k, espelha, corte)


## Qual linha da folha e se espelha, para uma pessoa em `tela_x` indo para longe
## ou para perto. Devolve [linha, espelha]: perto do centro ela se vê de costas
## ou de frente, e quanto mais de lado na tela, mais de perfil; as folhas
## desenham o lado direito, e o esquerdo é o espelho (`espelha_o_lado_esquerdo`).
func _angulo_da_pessoa(item: CatalogoSprites.Item, tela_x: float, sentido: float) -> Array:
	var desvio := absf(tela_x - _projetor.centro_x) / (LARGURA * 0.5)
	var longe := sentido > 0.0
	var nome := "costas" if longe else "frente"
	var de_lado := false
	if desvio > 0.75:
		nome = "lado"
		de_lado = true
	elif desvio > 0.3:
		nome = "tres_quartos_costas" if longe else "tres_quartos_frente"
		de_lado = true
	var linha := item.rotulos_linhas.find(nome)
	return [maxi(linha, 0), de_lado and tela_x < _projetor.centro_x]


func _moto() -> void:
	var p := _projetor.ponto(percurso, lateral)
	if p == Vector3.ZERO:
		return
	var graus := inclinacao * 28.0
	var quadro := AtorSprite.RETO
	var melhor := INF
	for i in AtorSprite.INCLINACOES.size():
		var d := absf(AtorSprite.INCLINACOES[i] - graus)
		if d < melhor:
			melhor = d
			quadro = i
	var k := p.z / MOTO_PPM
	# Trepidação do asfalto: sobe e desce um pixel, mais forte quanto mais rápido.
	var tremor := sin(_tempo * 55.0) * clampf(velocidade / VELOCIDADE_MAX, 0.0, 1.0) * 0.8
	var celula := AtorSprite.CELULA
	var origem := Rect2(Vector2(quadro * celula.x, 0.0), celula)
	var pe := AtorSprite.PE * k
	var destino := Rect2(Vector2(p.x, p.y + tremor) - pe, celula * k)
	draw_texture_rect_region(AtorSprite.ATLAS, destino, origem)


func _sprite(
	textura: Texture2D,
	item: CatalogoSprites.Item,
	coluna: int,
	linha: int,
	pe_na_tela: Vector2,
	k: float,
	espelha: bool,
	corte: float
) -> void:
	var celula := Vector2(item.celula)
	var origem := Rect2(Vector2(coluna * celula.x, linha * celula.y), celula)
	var pe := Vector2(item.pe)
	if espelha:
		pe.x = celula.x - pe.x
	var destino := Rect2(pe_na_tela - pe * k, celula * k)
	if destino.end.y > corte:
		var parte := (corte - destino.position.y) / destino.size.y
		if parte <= 0.0:
			return
		destino.size.y *= parte
		origem.size.y *= parte
	if espelha:
		origem.position.x += origem.size.x
		origem.size.x = -origem.size.x
	draw_texture_rect_region(textura, destino, origem)


func _painel() -> void:
	var fonte := ThemeDB.fallback_font
	var texto := "%3d km/h   ←/→ guidão   ↑ acelera   ↓ freia   Esc sai" % int(velocidade * 3.6)
	draw_string(fonte, Vector2(9, 17), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.BLACK)
	draw_string(fonte, Vector2(8, 16), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
