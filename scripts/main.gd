extends Node
## Pipeline de render e teclas globais.
##
## O look pixel sai de um SubViewport de 640x360 com upscale INTEIRO de 2x pra
## 1280x720. Inteiro importa: 2.5x deixa pixel de tamanhos diferentes na mesma
## tela e o serrilhado fica sujo em vez de proposital. A janela escala o resto
## (ver `scale_mode` no `project.godot`): 1920x1080 da 3x por pixel, exato.

## 1280x720 / 2 = 640x360 exato. O SubViewportContainer faz a conta sozinho
## via stretch_shrink - setar sub_viewport.size na mao nao funciona com stretch
## ligado, o container sobrescreve.
##
## Era 4 (320x180). Subiu na P1 da prova visual: a 320x180 o piloto tem uns
## 37 px de altura no talo, e nao cabe nele o que faz um ator ler como foto em
## vez de boneco. A conta esta no `docs/DIRECAO_VISUAL.md`.
const PIXEL_SHRINK: int = 2

## Onde a moto escolhida no menu fica guardada entre uma sessao e outra. Num
## arquivo so dela, e nao no `tuning.tres`: o tuning e o que o F3 salva quando
## alguem aperta Salvar, e escolher moto nao e mexer em slider.
const MOTO_SALVA: String = "user://moto.cfg"

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
## Se a moto escolhida e lida e gravada no user://. Desligado no banco de
## provas e na prova visual, pelo mesmo motivo do tuning: medida que depende
## de qual moto alguem escolheu ontem nao compara com nada.
var _moto_salva: bool = false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var selftest_mode := args.has("--selftest") or OS.has_environment("RUSHFOOD_SELFTEST")
	var prova_mode := args.has("--prova")
	var medindo := selftest_mode or prova_mode

	## O banco de provas roda nos defaults do repositorio, nao no user://.
	##
	## A semente ja era fixa pra o numero ser comparavel entre rodadas, mas o
	## tuning tinha ficado de fora: bastava alguem clicar em Salvar pra
	## "regrediu" e "voce mexeu num slider ontem" virarem a mesma coisa. Com
	## --selftest-user voce mede os seus ajustes, quando e isso que quer.
	var use_saved := not medindo or args.has("--selftest-user")
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
	_moto_salva = use_saved
	if _moto_salva:
		world.player.usar_modelo(_le_moto())

	_monta_paleta()

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
	fluxo.descreve_moto = func() -> String: return Entregador.NOMES[world.player.modelo()]
	fluxo.moto_trocada.connect(_trocar_moto)
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
	fluxo.iniciar(medindo)

	if selftest_mode:
		var selftest: Node = load("res://scripts/selftest.gd").new()
		add_child(selftest)
		selftest.call("setup", self)
	elif prova_mode:
		var prova: Node = load("res://scripts/prova.gd").new()
		add_child(prova)
		prova.call("setup", self)


## O passe de quantizacao com dither (`paleta.gdshader`): o ultimo do mundo.
##
## Um ColorRect que le a tela ja desenhada, numa camada acima do 3D e abaixo da
## HUD (layer 10). Acima de tudo que mexe na cor - neblina, tonemap, LUT -
## porque eles devolveriam os tons que ele tira; abaixo da HUD porque texto
## passado no dither so suja.
func _monta_paleta() -> void:
	var camada := CanvasLayer.new()
	camada.name = "Paleta"
	camada.layer = 5
	sub_viewport.add_child(camada)
	var tela := ColorRect.new()
	tela.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = preload("res://scripts/paleta.gdshader")
	tela.material = material
	camada.add_child(tela)


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
	# tela - o "6/6" da corrida bem em cima do "6o LUGAR de 6".
	hud.visible = correndo


func _trocar_moto(passo: int) -> void:
	var total := Entregador.CENAS.size()
	var nova := posmod(world.player.modelo() + passo, total)
	world.player.usar_modelo(nova)
	if not _moto_salva:
		return
	var arquivo := ConfigFile.new()
	arquivo.set_value("jogador", "moto", nova)
	arquivo.save(MOTO_SALVA)


func _le_moto() -> int:
	var arquivo := ConfigFile.new()
	if arquivo.load(MOTO_SALVA) != OK:
		return Entregador.Modelo.CG_160
	return int(arquivo.get_value("jogador", "moto", Entregador.Modelo.CG_160))


func _restart() -> void:
	world.set_physics_process(true)
	world.restart()
	hud.bind(world.run, world.player)
