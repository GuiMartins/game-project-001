class_name Quebravel
extends StaticBody3D
## Poste ou placa que cede ao toque do jogador e volta na proxima corrida.

var visual: Node3D
var quebrado: bool = false
var _rotacao_inicial: Vector3
var _animacao: Tween


## Fuste de semaforo ou portico, cujo desenho mora no no pai.
static func com_colisor(raiz: Node3D, tamanho: Vector3) -> Quebravel:
	var corpo := Quebravel.new()
	corpo.visual = raiz
	corpo.collision_layer = Layers.WORLD
	corpo.collision_mask = 0
	var forma := Greybox.box_shape(tamanho)
	forma.position = Vector3.UP * tamanho.y * 0.5
	corpo.add_child(forma)
	raiz.add_child(corpo)
	return corpo


func _ready() -> void:
	if visual == null:
		visual = self
	_rotacao_inicial = visual.rotation
	add_to_group(&"quebraveis")


func quebrar(direcao: Vector3) -> void:
	if quebrado:
		return
	quebrado = true
	set_deferred("collision_layer", 0)
	var queda := visual.global_basis.inverse() * direcao
	queda.y = 0.0
	if queda.length_squared() < 0.001:
		queda = Vector3.FORWARD
	queda = queda.normalized()
	_animacao = create_tween()
	_animacao.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_animacao.tween_property(
		visual, "rotation", _rotacao_inicial + Vector3(queda.z, 0.0, -queda.x) * 1.4, 0.45
	)
	_animacao.tween_callback(func() -> void: visual.visible = false)


func reiniciar() -> void:
	if _animacao != null:
		_animacao.kill()
	quebrado = false
	visual.rotation = _rotacao_inicial
	visual.visible = true
	set_deferred("collision_layer", Layers.WORLD)
