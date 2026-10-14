class_name FarolDaMoto
extends RefCounted
## O farol e a lanterna de uma moto de noite, de qualquer moto e de qualquer
## corredor: o `Entregador` tem um, jogador ou rival.
##
## Duas partes. O que brilha e do material (`entregador.gdshader`): a lente do
## farol e a da lanterna acendem pela cor pintada, e a lanterna cresce na
## freada. O que ilumina e um cone de verdade (`LuzDaNoite`), saindo de cima da
## roda da frente: cada moto tem o farol num lugar - na PCX ele nem e da
## direcao -, e a luz em si nao se ve, so a poca que ela faz no chao.

## As celulas que acendem, achadas pela cor (`arte/entregador.py`).
const FAROL_FABRICA := Color(0.98, 0.96, 0.82)
const LANTERNA_FABRICA := Color(0.85, 0.08, 0.06)
## Moto anda de farol aceso - no Brasil, ate de dia, por lei. Aqui so de
## noite, para o dia continuar o dia de sempre: acende no comecinho do
## escuro, antes de qualquer carro.
const LIMIAR: float = 0.08
## O cone, como o do carro (`Carro.FAROL_*`), um pouco mais estreito e curto:
## farol de moto e um so, menor. Mira baixa, para a poca cair na frente da
## roda, que e onde a camera de perseguicao olha.
const ALCANCE: float = 26.0
const ANGULO: float = 28.0
const ENERGIA: float = 3.0
const MIRA: float = -8.0
## Do chao ate o farol, em metros: o das tres motos fica entre 0,85 e 1,0.
const ALTURA: float = 0.9
const COR := Color(1.0, 0.95, 0.85)
## O menor passo de freio que vale mandar ao material: e uma chamada ao
## servidor de render por moto, e o freio do rival oscila a cada passo.
const PASSO_DO_FREIO: float = 0.05

var _material: ShaderMaterial
var _luz: SpotLight3D
var _freio: float = 0.0


## Poe o cone na `moto` recem-montada (o velho foi embora com a malha velha) e
## ensina ao `material` do ator onde estao farol e lanterna e quando acender.
## `eixo_frente` e o eixo da roda da frente no espaco da moto.
func montar(
	moto: Node3D, material: ShaderMaterial, eixo_frente: Vector3, raio_frente: float
) -> void:
	_material = material
	_material.set_shader_parameter("farol_fabrica", FAROL_FABRICA)
	_material.set_shader_parameter("lanterna_fabrica", LANTERNA_FABRICA)
	_material.set_shader_parameter("farol_limiar", LIMIAR)
	_material.set_shader_parameter("freio", _freio)
	_luz = LuzDaNoite.spot(COR, ENERGIA, ALCANCE, ANGULO, LIMIAR)
	_luz.position = Vector3(0.0, eixo_frente.y - raio_frente + ALTURA, eixo_frente.z)
	_luz.rotation_degrees = Vector3(MIRA, 0.0, 0.0)
	moto.add_child(_luz)
	Relogio.acender_uma(_luz, Relogio.escuro)


## A lanterna acompanha o freio, de 0 a 1. Caido nao freia.
func frear(freio: float, caido: bool) -> void:
	var agora := 0.0 if caido else clampf(freio, 0.0, 1.0)
	var mudou := absf(agora - _freio) > PASSO_DO_FREIO or (agora == 0.0) != (_freio == 0.0)
	if mudou and _material != null:
		_freio = agora
		_material.set_shader_parameter("freio", agora)
