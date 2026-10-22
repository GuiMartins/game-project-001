extends SceneTree
## Folhas de referencia das fachadas, para dar ao Google Flow.
##
##     python tools/dev.py boneco fachada
##
## Os cinco predios (`Predio.Tipo`) e as quatro fases da obra (`Predio.Obra`),
## cada um de frente e com a empena lateral, que e o que aparece na esquina
## (`MIGRACAO_2D.md`, Cenario). Ortograficas e de frente: a fachada vira
## parede repetida na horizontal, e nao um sprite que gira. Em cinza sobre
## verde, com a pintura, a loja e a tela do outdoor em tons neutros: a cor
## sai por cor-chave na folha do Flow.
##
## Roda com tela: o renderizador do `--headless` e um dummy, e sai tudo preto.

const Cena := preload("res://arte/boneco_cena.gd")

const PASTA: String = "res://arte/flow/referencia/fachada/"
const PPM: float = 64.0
const TOM_PINTURA := Color(0.70, 0.71, 0.74)
const TOM_LOJA := Color(0.46, 0.47, 0.50)
const TOM_TELA := Color(0.56, 0.58, 0.62)
## O predio olha para -Z: 180 o poe de frente para a camera e -90 mostra a
## empena do lado +X.
const GIROS: Array[float] = [180.0, -90.0]

var _cena := Cena.new()


func _initialize() -> void:
	root.add_child(_cena)
	_cena.monta(root)
	_roda.call_deferred()


func _roda() -> void:
	await process_frame
	for tipo: int in Predio.Tipo.values():
		await _faz(Predio.NOS[tipo].to_lower(), Predio.criar(tipo as Predio.Tipo, 0.0, 0.0))
	for fase: int in Predio.Obra.values():
		await _faz(
			"obra_%s" % Predio.NOS_OBRA[fase].to_lower(),
			Predio.criar_obra(fase as Predio.Obra, 0.0, 0.0)
		)
	quit()


func _faz(nome: String, predio: MeshInstance3D) -> void:
	predio.set_instance_shader_parameter("pintura", TOM_PINTURA)
	predio.set_instance_shader_parameter("loja", TOM_LOJA)
	predio.set_instance_shader_parameter("tela", TOM_TELA)
	await _cena.objeto(nome, PASTA, predio, GIROS, PPM)
