class_name SacoReciclaveis
extends Node2D
## Estouro em canvas: sprites e trajetorias analiticas, sem corpo ou particula 3D.
## O dono fornece a ancora 2D do impacto e pode mover/escalar este no com a
## projecao da pista. O sorteio e local: nao muda transito nem o corpo atingido.

signal terminou

const ATLAS: Texture2D = preload("res://assets/sprites/efeitos/reciclaveis.svg")
const CELULA := Vector2(32.0, 48.0)
const LATAS: int = 20
const GARRAFAS: int = 20
const RETALHOS: int = 10
const GRAVIDADE: float = 780.0
const DURACAO: float = 7.0
const APAGA_EM: float = 5.8


class Peca:
	extends RefCounted

	var tipo: int = 0
	var chao := Vector2.ZERO
	var velocidade := Vector2.ZERO
	var altura: float = 0.0
	var subida: float = 0.0
	var giro: float = 0.0
	var rotacao: float = 0.0
	var escala: float = 1.0
	var quicou: bool = false


var _pecas: Array[Peca] = []
var _tempo: float = 0.0
var _estourou: bool = false
var _terminou: bool = false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_physics_process(false)


## Reinicia tambem o saco fechado para conferir o antes/depois do impacto.
func reiniciar(onde: Vector2 = Vector2.ZERO) -> void:
	position = onde
	_pecas.clear()
	_tempo = 0.0
	_estourou = false
	_terminou = false
	set_physics_process(false)
	queue_redraw()


## `impacto` esta em pixels por segundo no plano do chao da tela. A direcao
## da moto influencia o jato, mas a dispersao radial deixa lixo dos dois lados.
func estourar(impacto: Vector2, semente: int = 17) -> void:
	if _estourou:
		return
	_estourou = true
	var rng := RandomNumberGenerator.new()
	rng.seed = semente
	var forca := clampf(impacto.length(), 60.0, 450.0)
	var empurrao := impacto.limit_length(450.0) * 0.27
	for i in LATAS + GARRAFAS + RETALHOS:
		var p := Peca.new()
		p.tipo = i % 2 if i % 5 < 2 else 2 + i % 2 if i % 5 < 4 else 4
		# Setores garantem o espalhamento em volta do saco; jitter impede um
		# circulo regular. A profundidade usa menos pixels que a horizontal.
		var angulo := TAU * float(i) / float(LATAS + GARRAFAS + RETALHOS)
		angulo += rng.randf_range(-0.22, 0.22)
		var radial := Vector2(cos(angulo), sin(angulo) * 0.32)
		p.chao = Vector2(rng.randf_range(-8.0, 8.0), rng.randf_range(-4.0, 4.0))
		p.velocidade = radial * rng.randf_range(110.0, 180.0 + forca * 0.3) + empurrao
		p.altura = rng.randf_range(12.0, 36.0)
		p.subida = rng.randf_range(175.0, 320.0 + forca * 0.17)
		p.giro = rng.randf_range(-13.0, 13.0)
		p.rotacao = rng.randf_range(-PI, PI)
		p.escala = rng.randf_range(0.46, 0.63) if p.tipo < 4 else rng.randf_range(0.4, 0.85)
		_pecas.append(p)
	set_physics_process(true)
	queue_redraw()


func _physics_process(delta: float) -> void:
	avancar(delta)


## Passos limitados mantem o quique estavel ao pausar/arrastar a previa.
func avancar(delta: float) -> void:
	if not _estourou or _terminou or delta <= 0.0:
		return
	var falta := minf(delta, DURACAO - _tempo)
	while falta > 0.000001:
		var passo := minf(falta, 1.0 / 120.0)
		_tempo += passo
		for p in _pecas:
			_avanca_peca(p, passo)
		falta -= passo
	if _tempo >= DURACAO - 0.00001:
		_terminou = true
		_pecas.clear()
		set_physics_process(false)
		terminou.emit()
	queue_redraw()


func _avanca_peca(p: Peca, delta: float) -> void:
	p.chao += p.velocidade * delta
	p.altura += p.subida * delta
	p.subida -= GRAVIDADE * delta
	p.rotacao += p.giro * delta
	if p.altura <= 0.0:
		p.altura = 0.0
		if p.subida < -55.0 and p.tipo < 4:
			p.subida = -p.subida * (0.32 if p.tipo < 2 else 0.43)
			p.velocidade *= 0.64
			p.giro *= 0.6
			p.quicou = true
		else:
			p.subida = 0.0
			p.velocidade *= exp(-5.5 * delta)
			p.giro *= exp(-7.0 * delta)
	else:
		p.velocidade *= exp(-0.65 * delta)


func _draw() -> void:
	if not _estourou:
		draw_texture_rect_region(ATLAS, Rect2(-31.0, -85.0, 62.0, 90.0), _regiao(5))
		return
	var alfa := 1.0 - smoothstep(APAGA_EM, DURACAO, _tempo)
	if alfa <= 0.0:
		return
	# Sombra de contato em 2D: nao depende de luz, camera ou malha 3D.
	for p in _pecas:
		var sombra := clampf(1.0 - p.altura / 260.0, 0.05, 0.45) * alfa
		draw_set_transform(p.chao + Vector2(0.0, 2.0), 0.0, Vector2(1.0, 0.25))
		draw_circle(Vector2.ZERO, 8.0 * p.escala, Color(0.02, 0.025, 0.03, sombra))
	# Dois rasgos grandes tornam legivel a ruptura antes da chuva de objetos.
	if _tempo < 0.25:
		for lado: int in [-1, 1]:
			draw_set_transform(Vector2(lado * _tempo * 100.0, -32.0), lado * _tempo * 4.0)
			draw_texture_rect_region(
				ATLAS,
				Rect2(-30.0, -48.0, 60.0, 90.0),
				_regiao(6 if lado < 0 else 7),
				Color(1.0, 1.0, 1.0, 1.0 - _tempo / 0.25)
			)
	for p in _pecas:
		draw_set_transform(p.chao - Vector2(0.0, p.altura), p.rotacao, Vector2.ONE * p.escala)
		draw_texture_rect_region(
			ATLAS, Rect2(-CELULA * 0.5, CELULA), _regiao(p.tipo), Color(1.0, 1.0, 1.0, alfa)
		)
	draw_set_transform(Vector2.ZERO)


static func _regiao(tipo: int) -> Rect2:
	return Rect2(Vector2(tipo * CELULA.x, 0.0), CELULA)
