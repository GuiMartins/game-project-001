class_name MotoFantasma
extends Node3D
## Uma moto que so passa: reta, a velocidade pedida, e some. Entra no grupo das
## motos, entao a gente da rua reage a ela (pula ou e atropelada) como reage a
## uma de verdade, mas sem fisica nem piloto.
##
## Serve ao playground do testador de sprites (`JogoSprite`): testar o susto e o
## atropelo de uma pessoa sem precisar pilotar ate ela, na velocidade e na
## distancia do corredor que se quer.

## Em Z, onde a moto some: passou da pessoa e de tudo o que ha para ver.
const LIMITE_Z: float = -400.0

var velocidade: float = 25.0
var modelo: int = Entregador.Modelo.CG_160
var sprite: bool = true
var cadencia_hz: float = 12.0

var _ator := Entregador.new()


func _ready() -> void:
	add_to_group(Pessoa.GRUPO_MOTOS)
	_ator.modelo = modelo
	add_child(_ator)
	_ator.sprite = sprite
	_ator.cadencia.hz = cadencia_hz
	_ator.pintar(PlayerBike.COR)


func _physics_process(delta: float) -> void:
	# A moto anda na reta de -Z, a direcao da pista do testador.
	position.z -= velocidade * delta
	_ator.atualizar(delta, velocidade, 0.5, 0.0, false)
	if position.z < LIMITE_Z:
		queue_free()


## Desenha em sprite ou em 3D, e na cadencia pedida: o mesmo que o `World`
## repassa a todo corredor.
func usar(a_sprite: bool, hz: float) -> void:
	sprite = a_sprite
	cadencia_hz = hz
	_ator.sprite = a_sprite
	_ator.cadencia.hz = hz
