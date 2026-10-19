class_name ReferenciaMoto
extends SubViewport
## A referencia da moto: o modelo 3D do jogo, posado como o quadro do atlas.
##
## As folhas dos pedestres tem a referencia gravada (`arte/flow/referencia/`),
## mas a moto nao: o que foi ao Flow para o piloto foi o modelo 3D em pe e
## deitado, e esse modelo esta aqui, no `Entregador`. Renderizar o quadro no
## mesmo angulo e na mesma inclinacao que o atlas desenha da a mesma comparacao
## que a dos pedestres: a silhueta do 3D contra a do sprite.
##
## A camera e a do jogo (atras, baixa), mas a do Flow nao esta no repositorio,
## entao so a pose vale, e nao o enquadramento. A comparacao e por silhueta
## esticada na propria caixa (`Silhueta`), que tira o enquadramento da conta.

const LADO: Vector2i = Vector2i(384, 320)
## Quanto o modelo assenta antes da foto: a mola da suspensao e o tronco levam
## alguns passos para parar.
const PASSOS_PARA_ASSENTAR: int = 90
const PASSO: float = 1.0 / 60.0
## Os tempos de cada fase do soco, para fotografar no meio dela: (preparo,
## ativo) de `Entregador.socar`, e quando cai a foto de cada fase.
const SOCO_PREPARO: float = 0.15
const SOCO_ATIVO: float = 0.1
const SOCO_TOTAL: float = 0.45
const TEMPO_DA_FASE: Array[float] = [0.08, 0.2, 0.33]

var _camera := Camera3D.new()
var _ator: Entregador
var _modelo: int = -1


func _init() -> void:
	size = LADO
	own_world_3d = true
	transparent_bg = true
	render_target_update_mode = SubViewport.UPDATE_DISABLED
	msaa_3d = Viewport.MSAA_DISABLED
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	add_child(sol)
	var ambiente := Environment.new()
	ambiente.background_mode = Environment.BG_CLEAR_COLOR
	ambiente.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ambiente.ambient_light_color = Color.WHITE
	ambiente.ambient_light_energy = 0.6
	var mundo := WorldEnvironment.new()
	mundo.environment = ambiente
	add_child(mundo)
	_camera.fov = 30.0
	_camera.position = Vector3(0.0, 1.2, 6.5)
	add_child(_camera)
	_camera.look_at_from_position(_camera.position, Vector3(0.0, 0.8, 0.0))


## A moto no quadro `coluna` do atlas: curva (0 a 4) ou soco (5 a 10), de
## `modelo` (`Entregador.Modelo`). Devolve a imagem com fundo transparente.
func fotografar(coluna: int, modelo: int) -> Image:
	_prepara(modelo)
	var graus := 0.0
	var lado := 0
	var fase := -1
	if coluna < AtorSprite.INCLINACOES.size():
		graus = AtorSprite.INCLINACOES[coluna]
	else:
		for l: int in AtorSprite.SOCO:
			var onde := (AtorSprite.SOCO[l] as Array).find(coluna)
			if onde >= 0:
				lado = l
				fase = onde
	var inclinacao := deg_to_rad(graus)
	for i in PASSOS_PARA_ASSENTAR:
		_ator.atualizar(PASSO, 12.0, 0.5, 0.0, false, 1.0, inclinacao)
	if fase >= 0:
		_ator.socar(lado, SOCO_PREPARO, SOCO_ATIVO, SOCO_TOTAL)
		var feito := 0.0
		while feito < TEMPO_DA_FASE[fase]:
			_ator.atualizar(PASSO, 12.0, 0.5, 0.0, false, 1.0, inclinacao)
			feito += PASSO
	render_target_update_mode = SubViewport.UPDATE_ONCE
	# Dois quadros: um para a cena aceitar a pose e outro para desenhar.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var imagem := get_texture().get_image()
	render_target_update_mode = SubViewport.UPDATE_DISABLED
	return imagem


func _prepara(modelo: int) -> void:
	if _ator != null and _modelo == modelo:
		return
	if _ator != null:
		_ator.queue_free()
	_ator = Entregador.new()
	_ator.modelo = modelo
	add_child(_ator)
	_modelo = modelo
