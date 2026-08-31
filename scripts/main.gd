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
var tuning_panel: TuningPanel
var tuning: BikeTuning

var _pixel_mode: bool = true


func _ready() -> void:
	tuning = BikeTuning.load_or_default()

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
	world.setup(tuning)

	hud = Hud.new()
	hud.name = "Hud"
	sub_viewport.add_child(hud)
	hud.bind(world.run, world.player)

	world.event_logged.connect(hud.show_event)
	world.run_finished.connect(_on_run_finished)

	tuning_panel = TuningPanel.new()
	tuning_panel.name = "TuningPanel"
	add_child(tuning_panel)
	tuning_panel.setup(tuning)

	if OS.get_cmdline_user_args().has("--selftest") or OS.has_environment("RUSHFOOD_SELFTEST"):
		var selftest: Node = load("res://scripts/selftest.gd").new()
		add_child(selftest)
		selftest.call("setup", self)


func _apply_pixel_mode() -> void:
	container.stretch_shrink = PIXEL_SHRINK if _pixel_mode else 1


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if event.is_action("debug_pixel_toggle"):
		_pixel_mode = not _pixel_mode
		_apply_pixel_mode()
		hud.show_event("pixel %s" % ("ligado" if _pixel_mode else "desligado"), Color(0.7, 0.9, 1.0))
	elif event.is_action("debug_camera_cycle"):
		world.camera.cycle_mode()
	elif event.is_action("debug_tuning_panel"):
		tuning_panel.toggle()
	elif event.is_action("debug_restart"):
		_restart()


func _on_run_finished() -> void:
	hud.show_result(world.run.summary() + "\n\nR pra correr de novo")


func _restart() -> void:
	world.set_physics_process(true)
	world.restart()
	hud.bind(world.run, world.player)
