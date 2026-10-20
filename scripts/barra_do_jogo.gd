class_name BarraDoJogo
extends VBoxContainer
## Os controles do playground (`JogoSprite`): quem se conduz, sprite ou 3D, e um
## botao para cada situacao que o jogo tem.
##
## So chama a API do `JogoSprite`; nada aqui sabe de fisica nem de animacao.

## As poses por segundo que o jogo oferece (`Main.CADENCIAS`); 0 e liso.
const CADENCIAS: Array[int] = [0, 24, 15, 12, 8]
const NOMES_DAS_PESSOAS: Array[String] = [
	"Vovo", "Obra", "Praia", "Adolescente", "Escritorio", "Moletom"
]
const AJUDA := (
	"Pessoa: WASD ou setas andam, Shift corre.   Moto: W acelera, S freia, A e D inclinam, "
	+ "Shift e o boost, Q e E socam, R recomeca.   Tab troca de modo."
)

var _jogo: JogoSprite
var _velocidade_kmh: float = 90.0
var _ultimo_evento: Label
var _quem: HBoxContainer


func montar(jogo: JogoSprite) -> void:
	_jogo = jogo
	add_child(_linha_do_ator())
	add_child(_linha_das_situacoes())
	add_child(_linha_da_camera())
	var ajuda := PecasDeUi.rotulo(AJUDA)
	ajuda.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(ajuda)
	_ultimo_evento = Label.new()
	_ultimo_evento.modulate = Color(0.6, 1.0, 0.6)
	add_child(_ultimo_evento)
	jogo.evento.connect(func(texto: String) -> void: _ultimo_evento.text = texto)


func _linha_do_ator() -> Control:
	var fluxo := HFlowContainer.new()
	fluxo.add_child(PecasDeUi.rotulo("Conduzir"))
	fluxo.add_child(
		PecasDeUi.segmentado(["Pessoa", "Moto"], _jogo.ator, func(i: int) -> void: _jogo.ator = i)
	)
	fluxo.add_child(PecasDeUi.rotulo("Quem"))
	_quem = PecasDeUi.segmentado(
		NOMES_DAS_PESSOAS, _jogo.avatar, func(i: int) -> void: _jogo.avatar = i
	)
	fluxo.add_child(_quem)
	# A galeria tambem escolhe a pessoa: o botao acompanha.
	_jogo.avatar_alterado.connect(func(i: int) -> void: PecasDeUi.marca_o_segmento(_quem, i))
	fluxo.add_child(PecasDeUi.rotulo("Desenho"))
	fluxo.add_child(
		PecasDeUi.segmentado(
			["Sprite", "3D"], 0 if _jogo.sprite else 1, func(i: int) -> void: _jogo.sprite = i == 0
		)
	)
	fluxo.add_child(PecasDeUi.rotulo("cadencia (Hz)"))
	fluxo.add_child(
		PecasDeUi.segmentado(
			["livre", "24", "15", "12", "8"],
			CADENCIAS.find(int(_jogo.cadencia_hz)),
			func(i: int) -> void: _jogo.cadencia_hz = float(CADENCIAS[i])
		)
	)
	fluxo.add_child(PecasDeUi.rotulo("moto"))
	fluxo.add_child(
		PecasDeUi.segmentado(
			["CG 160", "XRE 300", "PCX 160"],
			_jogo.modelo_moto,
			func(i: int) -> void: _jogo.modelo_moto = i
		)
	)
	return fluxo


func _linha_das_situacoes() -> Control:
	var fluxo := HFlowContainer.new()
	fluxo.add_child(PecasDeUi.rotulo("Velocidade da moto (km/h)"))
	var velocidade := PecasDeUi.slider(
		10.0, 220.0, 5.0, _velocidade_kmh, func(v: float) -> void: _velocidade_kmh = v
	)
	velocidade.custom_minimum_size.x = 180
	fluxo.add_child(velocidade)
	fluxo.add_child(PecasDeUi.botao("Atropelar", func() -> void: _jogo.atropelar(_ms())))
	# Quem esta de pe na frente da moto pula: o susto. So nao pula quem ja pulou
	# ha menos de um segundo, quem desce do carro ou quem nao viu a tempo.
	fluxo.add_child(
		PecasDeUi.botao("Moto em cima dela", func() -> void: _jogo.passar_uma_moto(_ms(), 0.0))
	)
	fluxo.add_child(
		PecasDeUi.botao("Moto de raspao", func() -> void: _jogo.passar_uma_moto(_ms(), 1.0))
	)
	fluxo.add_child(
		PecasDeUi.botao("Moto de longe", func() -> void: _jogo.passar_uma_moto(_ms(), 2.5))
	)
	fluxo.add_child(
		PecasDeUi.botao("Sair do carro (calcada)", func() -> void: _jogo.sair_do_carro(1))
	)
	fluxo.add_child(PecasDeUi.botao("Sair do carro (rua)", func() -> void: _jogo.sair_do_carro(-1)))
	fluxo.add_child(PecasDeUi.botao("Largada", func() -> void: _jogo.largada()))
	fluxo.add_child(PecasDeUi.botao("Levantar", func() -> void: _jogo.nova_pessoa()))
	fluxo.add_child(PecasDeUi.botao("Moto no inicio", func() -> void: _jogo.reiniciar_a_moto()))
	fluxo.add_child(PecasDeUi.botao("Limpar manchas", func() -> void: _jogo.limpar_o_chao()))
	return fluxo


func _linha_da_camera() -> Control:
	var fluxo := HFlowContainer.new()
	fluxo.add_child(PecasDeUi.rotulo("Camera da pessoa: angulo"))
	fluxo.add_child(
		PecasDeUi.slider(
			-180.0, 180.0, 1.0, 0.0, func(v: float) -> void: _jogo.camera_yaw_graus = v
		)
	)
	fluxo.add_child(PecasDeUi.rotulo("distancia"))
	fluxo.add_child(
		PecasDeUi.slider(2.0, 15.0, 0.1, 5.5, func(v: float) -> void: _jogo.camera_distancia = v)
	)
	fluxo.add_child(PecasDeUi.rotulo("altura"))
	fluxo.add_child(
		PecasDeUi.slider(
			-5.0, 70.0, 1.0, 14.0, func(v: float) -> void: _jogo.camera_elevacao_graus = v
		)
	)
	fluxo.add_child(
		PecasDeUi.marcar("camera lenta (1/4)", false, func(b: bool) -> void: _jogo.camera_lenta = b)
	)
	fluxo.add_child(PecasDeUi.rotulo("hora"))
	fluxo.add_child(
		PecasDeUi.slider(0.0, 1.0, 0.01, 0.0, func(v: float) -> void: _jogo.ambiente.hora = v)
	)
	fluxo.add_child(
		PecasDeUi.marcar("paleta do jogo", false, func(b: bool) -> void: _jogo.ambiente.paleta = b)
	)
	return fluxo


func _ms() -> float:
	return _velocidade_kmh / 3.6
