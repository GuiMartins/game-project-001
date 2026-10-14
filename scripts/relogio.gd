class_name Relogio
extends Node
## A hora da corrida, e quem a pinta no mundo.
##
## A corrida larga ao meio-dia e cruza a linha de noite. O relogio e o
## progresso do jogador na rota, e nao o cronometro: quem anda chega na noite,
## e a noite fechada chega junto com a reta final, seja a corrida de dois
## minutos ou de quatro. E so anda para a frente - bater e ficar para tras nao
## devolve a tarde.
##
## Medindo (banco de provas, shots, prova visual), a hora e fixa: o dia, salvo
## `--hora` pedindo outra. "Regrediu" e "o quadro foi tirado mais tarde" nao
## podem ser a mesma coisa.
##
## O que ele mexe: ceu, sol (que vira lua), ambiente, neblina, o LUT, o
## parametro global `noite` (que cada shader le para acender farol, lanterna e
## janela) e as luzes do grupo `GRUPO`, que so existem de noite.

## Grupo das luzes que acendem com o escuro: poste, farol. Cada uma guarda na
## meta `limiar` quando acende e em `energia` o quanto, acesa.
const GRUPO: StringName = &"luz_da_noite"
## Parametro global de shader com o `Hora.escuro` (`project.godot`,
## `shader_globals`). Um so para o mundo inteiro, em vez de varrer instancia.
const GLOBAL: StringName = &"noite"
## Quanto do escuro uma luz leva para ir de apagada a acesa. Curto: lampada
## acende, nao amanhece. Mas nao zero, que a energia num degrau so seria um
## estalo no asfalto inteiro.
const RAMPA: float = 0.04
## O menor passo de hora que vale reaplicar. Em 1/256 a mudanca de um passo
## para o outro fica abaixo de um degrau da paleta; menor que isso seria
## refazer LUT e luz todo quadro por nada.
const PASSO: float = 1.0 / 256.0

## Os sliders do ceu que sao da hora, e nao do F3.
const CEU_DA_HORA: Dictionary = {
	"ceu_topo": "topo",
	"ceu_horizonte": "horizonte",
	"ceu_chao_horizonte": "chao_horizonte",
	"ceu_chao_fundo": "chao_fundo",
	"nuvem_luz": "nuvem_luz",
	"nuvem_baixo": "nuvem_baixo",
	"estrelas": "estrelas",
	"astro_disco": "astro_disco",
	"astro_halo": "astro_halo",
	"lua": "lua",
}

## O escuro aplicado agora, para quem nasce no meio da noite (carro reciclado,
## rival que entra no R) acender sozinho. Estatico porque e um mundo so, e ler
## o parametro global de volta do servidor de render trava o quadro.
static var escuro: float = 0.0

## A hora travada, de 0 a 1, ou negativa para seguir a corrida. E o que o
## `main.gd` poe quando esta medindo.
var hora_fixa: float = -1.0

var _env: Environment
var _astro: DirectionalLight3D
var _ceu: ShaderMaterial
var _luts: Array[Texture3D] = []
## As fatias de cada LUT, lidas uma vez. Vazio quando a textura nao devolve
## dado (o render dummy do headless): ai o LUT so troca nas chaves.
var _fatias: Array[Array] = []
var _lut_misturado: ImageTexture3D
## A hora aplicada agora, e a maior que a corrida ja alcancou.
var _t: float = -1.0
var _maximo: float = 0.0


func montar(env: Environment, astro: DirectionalLight3D, ceu: ShaderMaterial) -> void:
	_env = env
	_astro = astro
	_ceu = ceu
	for caminho in Hora.LUTS:
		var lut: Texture3D = load(caminho)
		_luts.append(lut)
		_fatias.append(_le_fatias(lut))
	aplicar(0.0)


## Volta ao comeco da corrida: meio-dia, ou a hora travada.
func zerar() -> void:
	_maximo = 0.0
	aplicar(hora_fixa if hora_fixa >= 0.0 else 0.0)


## Trava a hora em `t` (0 a 1) e aplica ja, sem esperar o proximo quadro. A
## prova visual congela o mundo antes do primeiro, e sem isto fotografaria o
## meio-dia.
func fixar(t: float) -> void:
	hora_fixa = clampf(t, 0.0, 1.0)
	aplicar(hora_fixa)


## Anda o relogio com o jogador em `progresso` (0 a 1 da rota). `forcada` e o
## slider do F3: negativa segue a corrida.
func andar(progresso: float, comeca: float, fecha: float, forcada: float) -> void:
	var t: float
	if hora_fixa >= 0.0:
		t = hora_fixa
	elif forcada >= 0.0:
		t = forcada
	else:
		_maximo = maxf(_maximo, curva(progresso, comeca, fecha))
		t = _maximo
	if absf(t - _t) >= PASSO or (t != _t and (t == 0.0 or t == 1.0)):
		aplicar(t)


## A hora com o jogador em `progresso` da rota: meio-dia ate `comeca`, noite
## fechada de `fecha` em diante, e uma reta no meio.
static func curva(progresso: float, comeca: float, fecha: float) -> float:
	if fecha <= comeca:
		return 1.0 if progresso >= comeca else 0.0
	return clampf((progresso - comeca) / (fecha - comeca), 0.0, 1.0)


## Um limiar de escuro em [de, ate] para a coisa em `onde`, sempre o mesmo para
## o mesmo lugar. E o que faz a cidade acender aos poucos, e nao num estalo.
## Hash da posicao, e nao sorteio: a noite nao pode tirar numero do gerador do
## mundo, ou a corrida do banco de provas mudaria.
static func limiar(onde: Vector3, de: float, ate: float) -> float:
	var h := hash(Vector3i(onde.round()))
	return lerpf(de, ate, float(h % 1000) / 999.0)


func hora() -> float:
	return _t


func aplicar(t: float) -> void:
	_t = t
	var h := Hora.na(t)
	for campo: String in CEU_DA_HORA:
		_ceu.set_shader_parameter(CEU_DA_HORA[campo], h.get(campo))
	_astro.rotation_degrees = h.astro_rotacao
	_astro.light_color = h.astro_cor
	_astro.light_energy = h.astro_energia
	_env.ambient_light_energy = h.ambiente_energia
	_env.ambient_light_color = h.ambiente_cor
	_env.ambient_light_sky_contribution = h.ambiente_ceu
	_env.fog_light_color = h.neblina_cor
	_env.fog_density = h.neblina_densidade
	_env.tonemap_exposure = h.exposicao
	_env.adjustment_color_correction = _lut(t)
	escuro = h.escuro
	RenderingServer.global_shader_parameter_set(GLOBAL, h.escuro)
	acender(get_tree(), h.escuro)


## Acende e apaga as luzes do `GRUPO` para o `escuro` de agora.
static func acender(arvore: SceneTree, quanto: float) -> void:
	if arvore == null:
		return
	for no in arvore.get_nodes_in_group(GRUPO):
		acender_uma(no as Light3D, quanto)


## Uma luz so: a de quem nasce depois, com o `escuro` estatico.
static func acender_uma(luz: Light3D, quanto: float) -> void:
	var k := clampf((quanto - float(luz.get_meta(&"limiar", 0.5))) / RAMPA, 0.0, 1.0)
	luz.visible = k > 0.0
	luz.light_energy = float(luz.get_meta(&"energia", 1.0)) * k


## O LUT da hora `t`: a chave, se `t` cai numa, ou a mistura das duas vizinhas.
## O `Environment` so aceita um LUT, entao a mistura e feita aqui, na CPU: sao
## 16 x 16 x 16 cores, menos de meio milissegundo.
func _lut(t: float) -> Texture3D:
	var onde := Hora.trecho(t)
	var i := int(onde.x)
	if onde.y <= 0.0:
		return _luts[i]
	if onde.y >= 1.0:
		return _luts[i + 1]
	var a: Array = _fatias[i]
	var b: Array = _fatias[i + 1]
	if a.is_empty() or b.is_empty():
		return _luts[i] if onde.y < 0.5 else _luts[i + 1]
	var fatias: Array[Image] = []
	for k in a.size():
		fatias.append(_mistura(a[k] as Image, b[k] as Image, onde.y))
	var primeira := fatias[0]
	if _lut_misturado == null:
		_lut_misturado = ImageTexture3D.new()
		_lut_misturado.create(
			primeira.get_format(),
			primeira.get_width(),
			primeira.get_height(),
			fatias.size(),
			false,
			fatias
		)
	else:
		_lut_misturado.update(fatias)
	return _lut_misturado


static func _le_fatias(lut: Texture3D) -> Array[Image]:
	var fatias: Array[Image] = []
	for fatia in lut.get_data():
		var copia := (fatia as Image).duplicate() as Image
		if copia.is_compressed():
			return []
		copia.convert(Image.FORMAT_RGB8)
		fatias.append(copia)
	return fatias


static func _mistura(a: Image, b: Image, f: float) -> Image:
	var da := a.get_data()
	var db := b.get_data()
	var saida := PackedByteArray()
	saida.resize(da.size())
	for i in da.size():
		saida[i] = int(da[i] + (db[i] - da[i]) * f + 0.5)
	return Image.create_from_data(a.get_width(), a.get_height(), false, a.get_format(), saida)
