class_name AnaliseSprites
extends RefCounted
## O que se descobre de uma folha olhando mais fundo que a ficha: o movimento
## entre quadros, a borda do recorte, o tamanho contra o que a ficha promete e
## a semelhanca com a referencia 3D que foi ao Flow.
##
## Roda uma vez por folha e custa de meio a um segundo, entao nao entra na
## varredura (`CatalogoSprites.varrer`), que e instantanea. O resultado vai para
## `Item.avisos_analise`, `Item.notas_quadro` e `Item.iou_referencia`.
##
## Cada limite aqui foi posto olhando o que as folhas de hoje medem: o que
## passa e o que e defeito de verdade. Aviso que dispara em folha boa ensina a
## ignorar o aviso.

## Dois quadros seguidos com IoU acima disto sao o mesmo quadro.
const IGUAIS: float = 0.995
## Quanto o salto entre dois quadros seguidos pode diferir do salto da mesma
## dupla na referencia, em IoU, antes de virar aviso: a referencia diz quanto o
## corpo muda ali, e o Flow nao pode mudar muito mais nem muito menos. Assimetrico
## de proposito: pessoa e boneco nunca tem a mesma silhueta (roupa, cabelo,
## bolsa), e isso ja da uns 20% de diferenca em qualquer par. Mudar mais que a
## referencia e o quadro que treme; mudar menos e o que trava.
const SALTO_A_MAIS: float = 0.30
const SALTO_A_MENOS: float = 0.40
## Quanto a emenda do ciclo (ultimo para o primeiro) pode ser pior que o pior
## par seguido da folha.
const EMENDA_PIOR: float = 0.10
## O quadro com IoU contra a referencia abaixo da mediana da folha por mais
## que isto e uma pose que o Flow nao copiou.
const POSE_LONGE: float = 0.25
## Quanto a outra linha tem de parecer mais com o quadro que a propria linha
## para o quadro contar como "de outro angulo", e so conta se a outra linha nao
## e vizinha: tres quartos e lado tem silhuetas parecidas, e frente e costas a
## mesma (o que as separa e o rosto, que silhueta nao ve).
const ANGULO_TROCADO: float = 0.20
## Quanto a altura relativa a referencia (quadro sobre mediana da linha) pode
## fugir de 1 antes de virar aviso: o Flow desenhou a pessoa maior ou menor que
## o boneco naquela pose.
const ESCALA_DIFERENTE: float = 0.18
## Altura do desenho de pe contra a da ficha: cabelo, capacete e coque passam um
## pouco dos 1,65 m, e o pe pode ficar um pouco abaixo da linha.
const ALTURA_DA_FICHA: float = 0.08
## Pixel meio transparente e franja: o shader corta no alfa 0,5 e a borda
## meio-tom vira degrau ou halo. Fracao de pixels do corpo, por quadro.
const SEMITRANSPARENTE: float = 0.01
## Pixel de borda onde o verde passa os outros canais por esta margem (0-255):
## sobra do chroma key. Fracao dos pixels de borda, por quadro.
const MARGEM_VERDE: int = 20
const BORDA_VERDE: float = 0.04
## Pixels opacos sem vizinho opaco (um grao solto) por quadro.
const GRAOS_SOLTOS: int = 3
## Quanto o centro de massa do andar pode pular de um quadro para outro (px), a
## 100 px/m: o tronco que o quadro desloca.
const PULO_DO_CENTRO_PX: float = 7.0
## Quanto a abertura de perna precisa crescer das colunas juntas para as
## abertas no ciclo de andar, sobre a altura.
const ABERTURA_MINIMA: float = 0.04


## Analisa `item` e preenche os campos de resultado. Seguro de chamar de outra
## thread: so mexe no proprio `item`, e a referencia se protege sozinha.
static func analisar(item: CatalogoSprites.Item) -> void:
	item.trava.lock()
	_analisa(item)
	item.trava.unlock()


static func _analisa(item: CatalogoSprites.Item) -> void:
	if item.analisado:
		return
	item.analisado = true
	if item.caixas.is_empty() or item.tamanho_imagem == Vector2i.ZERO:
		return
	var imagem := Image.load_from_file(ProjectSettings.globalize_path(item.caminho))
	if imagem == null or imagem.is_empty():
		return
	var celulas: Array[Image] = []
	for linha in item.linhas:
		for coluna in item.colunas:
			var origem := Vector2i(coluna * item.celula.x, linha * item.celula.y)
			celulas.append(imagem.get_region(Rect2i(origem, item.celula)))
	for celula in celulas:
		item.silhuetas.append(Silhueta.de_imagem(celula))
	if item.tipo == CatalogoSprites.Tipo.PEDESTRE:
		item.referencia = ReferenciaSprites.de(item.animacao, item.colunas, item.linhas)
		_confere_a_referencia(item)
		_confere_o_movimento(item, celulas)
		_confere_a_altura(item)
	_confere_a_borda(item, celulas)
	_fecha(item)


## Soma `onde` (um quadro) ao aviso `texto`. Doze avisos iguais escondem o
## treze, que e diferente: sai uma linha por tipo, com a lista dos quadros.
static func _avisa(item: CatalogoSprites.Item, texto: String, onde: String) -> void:
	var lista: Array = item.grupos_analise.get(texto, [])
	lista.append(onde)
	item.grupos_analise[texto] = lista


static func _fecha(item: CatalogoSprites.Item) -> void:
	for texto: String in item.grupos_analise:
		var onde: Array = item.grupos_analise[texto]
		var mostra := onde.slice(0, 8)
		var resto := onde.size() - mostra.size()
		var lista := ", ".join(PackedStringArray(mostra))
		if resto > 0:
			lista += " e mais %d" % resto
		item.avisos_analise.append("%s (quadro/linha: %s)" % [texto, lista])


static func _onde(coluna: int, linha: int) -> String:
	return "%d/%d" % [coluna + 1, linha + 1]


# --- referencia ------------------------------------------------------------


static func _confere_a_referencia(item: CatalogoSprites.Item) -> void:
	var ref := item.referencia
	if ref == null or ref.colunas != item.colunas or ref.linhas != item.linhas:
		return
	item.iou_referencia.resize(item.quadros())
	for l in item.linhas:
		for c in item.colunas:
			var i := l * item.colunas + c
			item.iou_referencia[i] = Silhueta.iou(item.silhuetas[i], ref.silhueta(c, l))
	# A caida tem tres quadros por linha e a referencia dela e cortada pela
	# propria grade (ver `ReferenciaSprites`): comparar ali acusa o boneco, e nao
	# a pessoa. O IoU fica na tela; o aviso nao.
	if item.animacao == "caida":
		return
	var ordenado := Array(item.iou_referencia)
	ordenado.sort()
	var mediana: float = ordenado[ordenado.size() / 2]
	for l in item.linhas:
		for c in item.colunas:
			var i := l * item.colunas + c
			if item.iou_referencia[i] < mediana - POSE_LONGE:
				item.anota(
					c,
					l,
					(
						"so %d%% da referencia (a folha tem %d%%): a pose nao foi copiada"
						% [roundi(item.iou_referencia[i] * 100.0), roundi(mediana * 100.0)]
					)
				)
				_avisa(item, "referencia: pose longe da referencia", _onde(c, l))
			_confere_o_angulo(item, c, l)
	_confere_a_escala_na_linha(item)


## O quadro parece muito mais com a referencia de uma linha que nao e vizinha da
## sua do que com a da propria: o Flow desenhou um angulo no lugar do outro.
static func _confere_o_angulo(item: CatalogoSprites.Item, coluna: int, linha: int) -> void:
	if item.linhas < 3:
		return
	var i := linha * item.colunas + coluna
	var propria := item.iou_referencia[i]
	var melhor := propria
	var qual := linha
	for outra in item.linhas:
		if absi(outra - linha) < 2:
			continue
		var parecido := Silhueta.iou(item.silhuetas[i], item.referencia.silhueta(coluna, outra))
		if parecido > melhor:
			melhor = parecido
			qual = outra
	if qual != linha and melhor - propria > ANGULO_TROCADO:
		var rotulo := item.rotulos_linhas[qual] if qual < item.rotulos_linhas.size() else str(qual)
		item.anota(
			coluna,
			linha,
			(
				'parece o angulo "%s" da referencia (%d%%), e nao o da propria linha (%d%%)'
				% [rotulo, roundi(melhor * 100.0), roundi(propria * 100.0)]
			)
		)
		_avisa(item, "angulo: parece o de outra linha da referencia", _onde(coluna, linha))


## A altura do quadro sobre a mediana da linha, contra a mesma conta na
## referencia: o boneco e a pessoa na mesma pose tem de crescer e diminuir juntos.
static func _confere_a_escala_na_linha(item: CatalogoSprites.Item) -> void:
	if item.animacao == "voando":
		# De cabeca para baixo a altura da caixa e a do giro, e nao a da pessoa.
		return
	for l in item.linhas:
		var delas: Array[float] = []
		var da_ref: Array[float] = []
		for c in item.colunas:
			delas.append(float(item.silhuetas[l * item.colunas + c].caixa.size.y))
			da_ref.append(float(item.referencia.silhueta(c, l).caixa.size.y))
		var mediana_dela := _mediana(delas)
		var mediana_ref := _mediana(da_ref)
		if mediana_dela <= 0.0 or mediana_ref <= 0.0:
			continue
		for c in item.colunas:
			if delas[c] <= 0.0 or da_ref[c] <= 0.0:
				continue
			var relativa := (delas[c] / mediana_dela) / (da_ref[c] / mediana_ref)
			if absf(relativa - 1.0) > ESCALA_DIFERENTE:
				var maior := relativa > 1.0
				item.anota(
					c,
					l,
					(
						"%s que a referencia pede: %.0f%% da altura relativa dela"
						% ["mais alta" if maior else "mais baixa", relativa * 100.0]
					)
				)
				_avisa(
					item,
					"escala: o quadro sai %s que a referencia" % ("maior" if maior else "menor"),
					_onde(c, l)
				)


# --- movimento -------------------------------------------------------------


static func _confere_o_movimento(item: CatalogoSprites.Item, celulas: Array[Image]) -> void:
	if item.colunas < 3 or item.animacao == "caida":
		return
	var ciclo := item.animacao == "andando"
	var ref := item.referencia
	var tem_ref := ref != null and ref.colunas == item.colunas and ref.linhas == item.linhas
	for l in item.linhas:
		var saltos: Array[float] = []
		var pares := item.colunas if ciclo else item.colunas - 1
		for c in pares:
			var seguinte := (c + 1) % item.colunas
			var a := item.silhuetas[l * item.colunas + c]
			var b := item.silhuetas[l * item.colunas + seguinte]
			var parecido := Silhueta.iou(a, b)
			saltos.append(parecido)
			var esperado := (
				Silhueta.iou(ref.silhueta(c, l), ref.silhueta(seguinte, l)) if tem_ref else -1.0
			)
			# Quadro repetido: a animacao trava ali. So vale onde a referencia
			# muda: de frente e de costas o boneco quase nao mexe, e a pessoa
			# tambem nao.
			if (
				parecido >= IGUAIS
				and esperado < IGUAIS - 0.02
				and not (ciclo and c == item.colunas - 1)
			):
				item.anota(seguinte, l, "igual ao quadro anterior, e a referencia muda")
				_avisa(item, "movimento: quadro igual ao anterior", _onde(seguinte, l))
			if tem_ref:
				_compara_o_salto(item, c, seguinte, l, parecido, esperado)
		if ciclo:
			_confere_a_emenda(item, l, saltos)
			_confere_o_pulo_do_centro(item, l, celulas)
	if ciclo:
		_confere_a_passada(item, celulas)


## O quanto o corpo muda de um quadro para o seguinte tem de ser o quanto muda
## na referencia: mudar mais e tremer, mudar menos e travar.
static func _compara_o_salto(
	item: CatalogoSprites.Item, c: int, seguinte: int, l: int, parecido: float, esperado: float
) -> void:
	var a_mais := parecido < esperado - SALTO_A_MAIS
	var a_menos := parecido > esperado + SALTO_A_MENOS
	if not a_mais and not a_menos:
		return
	item.anota(
		seguinte,
		l,
		(
			"do quadro %d para este: %d%% de semelhanca, a referencia tem %d%%"
			% [c + 1, roundi(parecido * 100.0), roundi(esperado * 100.0)]
		)
	)
	_avisa(
		item,
		(
			"movimento: muda mais que a referencia entre quadros seguidos (treme)"
			if a_mais
			else "movimento: muda menos que a referencia entre quadros seguidos (trava)"
		),
		"%d>%d/%d" % [c + 1, seguinte + 1, l + 1]
	)


## A emenda do ciclo, do ultimo quadro para o primeiro, nao pode ser o salto
## mais feio da linha: o pe tem de acabar onde o primeiro quadro comeca.
static func _confere_a_emenda(item: CatalogoSprites.Item, linha: int, saltos: Array[float]) -> void:
	var emenda: float = saltos[saltos.size() - 1]
	var pior_dos_outros := 1.0
	for i in saltos.size() - 1:
		pior_dos_outros = minf(pior_dos_outros, saltos[i])
	if emenda < pior_dos_outros - EMENDA_PIOR:
		item.anota(
			0,
			linha,
			(
				"a emenda do ciclo (quadro %d para o 1) tem so %d%%"
				% [item.colunas, roundi(emenda * 100.0)]
			)
		)
		_avisa(item, "movimento: o ciclo nao emenda", "linha %d" % (linha + 1))


## O tronco nao pode andar de um lado para o outro entre quadros: o
## deslocamento vem do `Pessoa`, e quadro que ja vem torto escorrega.
static func _confere_o_pulo_do_centro(
	item: CatalogoSprites.Item, linha: int, celulas: Array[Image]
) -> void:
	var xs: Array[float] = []
	for c in item.colunas:
		xs.append(Silhueta.centro(celulas[linha * item.colunas + c]).x)
	var limite := PULO_DO_CENTRO_PX * item.pixels_por_metro / 100.0
	for c in item.colunas:
		var seguinte := (c + 1) % item.colunas
		var pulo := absf(xs[seguinte] - xs[c])
		if pulo > limite:
			item.anota(
				seguinte,
				linha,
				"o corpo pula %.0f px de lado em relacao ao quadro %d" % [pulo, c + 1]
			)
			_avisa(item, "movimento: o corpo pula de lado entre quadros", _onde(seguinte, linha))


## Os dois passos do ciclo (`CICLO_DA_PASSADA` em `arte/sprites_pedestres.gd`):
## a perna abre nas colunas 3 e 7 e fecha nas 1 e 5, vista de lado e de tres
## quartos. A folha pode ter sido reordenada pelo recorte, mas se mesmo assim a
## perna nao abre onde deveria, o pe da pessoa desliza no chao.
static func _confere_a_passada(item: CatalogoSprites.Item, celulas: Array[Image]) -> void:
	for l: int in [1, 2, 3]:
		if l >= item.linhas:
			continue
		var aberturas: Array[float] = []
		for c in item.colunas:
			aberturas.append(
				item.silhuetas[l * item.colunas + c].abertura(celulas[l * item.colunas + c])
			)
		var juntas := (aberturas[0] + aberturas[4]) * 0.5
		var abertas := (aberturas[2] + aberturas[6]) * 0.5
		if abertas - juntas < ABERTURA_MINIMA:
			_avisa(item, "movimento: a perna nao abre onde o ciclo manda", "linha %d" % (l + 1))


# --- tamanho ---------------------------------------------------------------


## De pe, a pessoa tem a altura da ficha. Se uma sai maior ou menor, o jogo
## pinta pessoas de tamanhos que nao sao os dela.
static func _confere_a_altura(item: CatalogoSprites.Item) -> void:
	if item.animacao != "andando" or item.altura_px <= 0.0:
		return
	var alturas: Array[float] = []
	for c in item.colunas:
		alturas.append(float(item.silhuetas[c].caixa.size.y))
	var mediana := _mediana(alturas)
	var razao := mediana / item.altura_px
	if absf(razao - 1.0) > ALTURA_DA_FICHA:
		item.avisos_analise.append(
			(
				"tamanho: de frente ela tem %.0f px e a ficha pede %.0f (%.2f m): %.0f%%"
				% [mediana, item.altura_px, item.altura_m, razao * 100.0]
			)
		)


# --- borda -----------------------------------------------------------------


## A borda do recorte, quadro a quadro, nos bytes da celula. Ve tres coisas:
## meio-tom, franja verde e grao solto.
static func _confere_a_borda(item: CatalogoSprites.Item, celulas: Array[Image]) -> void:
	for i in celulas.size():
		var medida := medir_borda(celulas[i], item.caixas[i])
		var coluna := i % item.colunas
		var linha := i / item.colunas
		var onde := _onde(coluna, linha)
		if medida["semi"] > SEMITRANSPARENTE:
			item.anota(
				coluna, linha, "%.1f%% do corpo meio transparente" % (medida["semi"] * 100.0)
			)
			_avisa(item, "borda: meio-tom, o shader corta no alfa 0,5 e vira degrau", onde)
		if medida["verde"] > BORDA_VERDE:
			item.anota(
				coluna, linha, "%.0f%% da borda com franja verde" % (medida["verde"] * 100.0)
			)
			_avisa(item, "borda: franja verde do chroma key", onde)
		if medida["graos"] > GRAOS_SOLTOS:
			item.anota(coluna, linha, "%d pixels soltos fora do corpo" % medida["graos"])
			_avisa(item, "borda: pixels soltos", onde)


## `semi`: fracao dos pixels do corpo que sao meio transparentes. `verde`:
## fracao dos pixels de borda esverdeados. `graos`: pixels opacos sem vizinho
## opaco nos quatro lados.
static func medir_borda(celula: Image, caixa: Rect2i) -> Dictionary:
	var medida := {"semi": 0.0, "verde": 0.0, "graos": 0}
	if caixa.size == Vector2i.ZERO:
		return medida
	var dados := celula.get_data()
	var largura := celula.get_width()
	var altura := celula.get_height()
	var corpo := 0
	var meio := 0
	var borda := 0
	var esverdeado := 0
	var graos := 0
	for y in range(caixa.position.y, caixa.end.y):
		var linha := y * largura
		for x in range(caixa.position.x, caixa.end.x):
			var o := (linha + x) * 4
			var a: int = dados[o + 3]
			if a == 0:
				continue
			corpo += 1
			if a < 255:
				meio += 1
			# Os quatro vizinhos, desenrolados: um laco com lista aqui aloca
			# por pixel, e a folha de pedestre tem 400 mil deles.
			var esq := 0 if x == 0 else dados[o - 4 + 3]
			var dir := 0 if x == largura - 1 else dados[o + 4 + 3]
			var cima := 0 if y == 0 else dados[o - largura * 4 + 3]
			var baixo := 0 if y == altura - 1 else dados[o + largura * 4 + 3]
			var opacos := int(esq >= 128) + int(dir >= 128) + int(cima >= 128) + int(baixo >= 128)
			if a >= 128 and opacos == 0:
				graos += 1
			if opacos < 4:
				borda += 1
				if dados[o + 1] - maxi(dados[o], dados[o + 2]) > MARGEM_VERDE:
					esverdeado += 1
	medida["semi"] = float(meio) / float(maxi(corpo, 1))
	medida["verde"] = float(esverdeado) / float(maxi(borda, 1))
	medida["graos"] = graos
	return medida


static func _mediana(valores: Array[float]) -> float:
	if valores.is_empty():
		return 0.0
	var ordenado := valores.duplicate()
	ordenado.sort()
	return ordenado[ordenado.size() / 2]
