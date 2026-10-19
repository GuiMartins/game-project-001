class_name Silhueta
extends RefCounted
## A forma de um quadro, reduzida ao que se compara: onde ha corpo, e nao a cor.
##
## Serve para pôr lado a lado coisas que não têm o mesmo tamanho nem a mesma
## roupa: o boneco cinza da referência e a pessoa que o Flow desenhou em cima
## dele. Cada uma vira uma grade pequena de zero e um, esticada para caber na
## própria caixa, e a semelhança é a interseção sobre a união (IoU). Esticar na
## caixa tira da conta a escala e o lugar na célula, que o recorte já acerta; o
## que sobra é a pose.

## Pontos da grade em cada eixo. 48x64 pega o braço e a perna de um boneco de
## 160x200 sem pagar mais que 3 mil leituras por quadro.
const LARGURA: int = 48
const ALTURA: int = 64
## Alfa a partir do qual um pixel e corpo, o mesmo corte do `ALPHA_SCISSOR` do
## shader do sprite.
const CORTE: float = 0.5

## Um quadro: a caixa do corpo na imagem (em pixels, a partir do canto da
## celula) e a grade dele esticada na caixa.
var caixa := Rect2i()
var grade := PackedByteArray()


func vazia() -> bool:
	return caixa.size == Vector2i.ZERO


## A silhueta de `celula`, uma imagem so com a celula.
static func de_imagem(celula: Image) -> Silhueta:
	var s := Silhueta.new()
	s.caixa = celula.get_used_rect()
	s.grade.resize(LARGURA * ALTURA)
	if s.vazia():
		return s
	var caixa := s.caixa
	for gy in ALTURA:
		var y := caixa.position.y + int((gy + 0.5) * caixa.size.y / ALTURA)
		for gx in LARGURA:
			var x := caixa.position.x + int((gx + 0.5) * caixa.size.x / LARGURA)
			s.grade[gy * LARGURA + gx] = 1 if celula.get_pixel(x, y).a >= CORTE else 0
	return s


## Interseção sobre união das duas grades, de 0 (nada em comum) a 1 (iguais).
## Silhueta vazia não se parece com nada.
static func iou(a: Silhueta, b: Silhueta) -> float:
	if a.vazia() or b.vazia():
		return 0.0
	var dentro := 0
	var junto := 0
	for i in LARGURA * ALTURA:
		var x := a.grade[i]
		var y := b.grade[i]
		dentro += x & y
		junto += x | y
	return float(dentro) / float(maxi(junto, 1))


## A razão largura/altura da caixa: o corpo de frente é estreito, o de lado
## com a perna aberta, largo.
func proporcao() -> float:
	return float(caixa.size.x) / float(maxi(caixa.size.y, 1))


## Quão aberta está a perna: a largura da faixa de baixo da silhueta sobre a
## altura dela. Mesma medida do recorte (`FRACAO_PES` em
## `arte/sprites_pedestres.gd`), para a conta bater com a que ordenou a folha.
func abertura(celula: Image, fracao: float = 0.15) -> float:
	if vazia():
		return 0.0
	var topo := caixa.end.y - maxi(int(caixa.size.y * fracao), 1)
	var esq := caixa.end.x
	var dir := caixa.position.x
	for y in range(topo, caixa.end.y):
		for x in range(caixa.position.x, caixa.end.x):
			if celula.get_pixel(x, y).a >= CORTE:
				esq = mini(esq, x)
				dir = maxi(dir, x)
	return float(maxi(dir - esq + 1, 0)) / float(caixa.size.y)


## O centro de massa do corpo na celula, a partir do canto de cima da caixa
## da celula, por amostragem: basta para ver o corpo pulando de lugar.
static func centro(celula: Image, passo: int = 4) -> Vector2:
	var soma := Vector2.ZERO
	var n := 0
	var tamanho := celula.get_size()
	for y in range(0, tamanho.y, passo):
		for x in range(0, tamanho.x, passo):
			if celula.get_pixel(x, y).a >= CORTE:
				soma += Vector2(x, y)
				n += 1
	return soma / float(n) if n > 0 else Vector2(-1.0, -1.0)
