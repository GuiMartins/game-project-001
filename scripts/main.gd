extends Node
## Pipeline de render e teclas globais.
##
## O look pixel sai de um SubViewport de 320x180 com upscale INTEIRO de 4x pra
## 1280x720. Inteiro importa: 3.7x deixa pixel de tamanhos diferentes na mesma
## tela e o serrilhado fica sujo em vez de proposital.

## 1280x720 / 4 = 320x180 exato. O SubViewportContainer faz a conta sozinho
## via stretch_shrink - setar sub_viewport.size na mao nao funciona com stretch
## ligado, o container sobrescreve.
const PIXEL_SHRINK: int = 4

var sub_viewport: SubViewport
var container: SubViewportContainer
var world: World
var hud: Hud
var fluxo: RaceFlow
var tuning_panel: TuningPanel
var tuning: BikeTuning
var world_tuning: WorldTuning
## De onde os valores vieram, pro relatorio do banco de provas dizer.
var tuning_source: String = ""

var _pixel_mode: bool = true


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var selftest_mode := args.has("--selftest") or OS.has_environment("RUSHFOOD_SELFTEST")

	## O banco de provas roda nos defaults do repositorio, nao no user://.
	##
	## A semente ja era fixa pra o numero ser comparavel entre rodadas, mas o
	## tuning tinha ficado de fora: bastava alguem clicar em Salvar pra
	## "regrediu" e "voce mexeu num slider ontem" virarem a mesma coisa. Com
	## --selftest-user voce mede os seus ajustes, quando e isso que quer.
	var use_saved := not selftest_mode or args.has("--selftest-user")
	tuning = BikeTuning.load_or_default() if use_saved else BikeTuning.new()
	world_tuning = WorldTuning.load_or_default() if use_saved else WorldTuning.new()
	tuning_source = "user:// (ajustes salvos)" if use_saved else "defaults do repositorio"

	container = SubViewportContainer.new()
	container.name = "PixelPipeline"
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.stretch_shrink = PIXEL_SHRINK
	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)

	sub_viewport = SubViewport.new()
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sub_viewport.msaa_3d = Viewport.MSAA_DISABLED
	sub_viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	sub_viewport.handle_input_locally = false
	container.add_child(sub_viewport)

	world = World.new()
	world.name = "World"
	sub_viewport.add_child(world)
	world.setup(tuning, world_tuning)

	hud = Hud.new()
	hud.name = "Hud"
	sub_viewport.add_child(hud)
	hud.bind(world.run, world.player)

	world.event_logged.connect(hud.show_event)
	world.run_finished.connect(_on_run_finished)

	fluxo = RaceFlow.new()
	fluxo.name = "RaceFlow"
	sub_viewport.add_child(fluxo)
	fluxo.descreve_pixel = func() -> String: return "LIGADO" if _pixel_mode else "DESLIGADO"
	fluxo.descreve_camera = func() -> String: return world.camera.mode_name()
	fluxo.corrida_pedida.connect(_restart)
	fluxo.pixel_alternado.connect(_toggle_pixel)
	fluxo.camera_alternada.connect(world.camera.cycle_mode)
	fluxo.tela_mudou.connect(_on_tela_mudou)

	tuning_panel = TuningPanel.new()
	tuning_panel.name = "TuningPanel"
	# Window nasce visivel. Esconder ANTES de entrar na arvore evita a janela
	# do painel piscar na tela no startup.
	tuning_panel.visible = false
	add_child(tuning_panel)
	tuning_panel.setup(tuning, world_tuning)
	fluxo.painel_pedido.connect(tuning_panel.toggle)

	# O banco de provas larga direto na corrida. Menu esperando ENTER num
	# processo headless e teste que trava em vez de falhar - e travado nao tem
	# codigo de saida pra CI ler.
	fluxo.iniciar(selftest_mode)

	if selftest_mode:
		var selftest: Node = load("res://scripts/selftest.gd").new()
		add_child(selftest)
		selftest.call("setup", self)


func _apply_pixel_mode() -> void:
	container.stretch_shrink = PIXEL_SHRINK if _pixel_mode else 1


func _toggle_pixel() -> void:
	_pixel_mode = not _pixel_mode
	_apply_pixel_mode()
	hud.show_event("pixel %s" % ("ligado" if _pixel_mode else "desligado"), Color(0.7, 0.9, 1.0))


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	# O fluxo tem a primeira palavra: no menu, ENTER e seta nao sao do jogo.
	if fluxo.navegar(event):
		return
	if event.is_action("debug_pixel_toggle"):
		_toggle_pixel()
	elif event.is_action("debug_camera_cycle"):
		world.camera.cycle_mode()
	elif event.is_action("debug_tuning_panel"):
		tuning_panel.toggle()
	elif event.is_action("debug_restart") and fluxo.tela == RaceFlow.Tela.CORRIDA:
		_restart()


func _on_run_finished() -> void:
	fluxo.mostrar_resultado(world.run.summary())


## Congela o mundo fora da corrida.
##
## Um `process_mode` no `World` derruba a arvore inteira de uma vez - moto,
## rivais, transito e camera. Desligar no por no e uma lista que alguem esquece
## de atualizar quando nascer o proximo no, e `get_tree().paused` levaria junto
## o proprio menu e o painel de tuning.
func _on_tela_mudou(tela: int) -> void:
	var correndo := tela == RaceFlow.Tela.CORRIDA
	world.process_mode = (Node.PROCESS_MODE_INHERIT if correndo else Node.PROCESS_MODE_DISABLED)
	# A Hud some em qualquer tela que nao seja a corrida, o resultado incluso.
	# Deixa-la por baixo do placar parecia dar contexto e na pratica so
	# embaralhou: sao dois textos claros, do mesmo tamanho, no mesmo lugar da
	# tela de 320x180 - o "6/6" da corrida bem em cima do "6o LUGAR de 6".
	hud.visible = correndo


func _restart() -> void:
	world.set_physics_process(true)
	world.restart()
	hud.bind(world.run, world.player)
