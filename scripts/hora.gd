class_name Hora
extends RefCounted
## Os numeros de uma hora do dia: ceu, astro, ambiente, neblina e quanto ja
## escureceu.
##
## A corrida anoitece: larga ao meio-dia e cruza a linha de noite (o `Relogio`
## e quem anda). Sao quatro horas-chave, e o que fica entre elas e mistura. Ir
## direto do meio-dia para a noite passa por um cinza lavado no meio, porque o
## azul do ceu e o preto da noite se misturam em cinza; as duas chaves do meio
## - o sol baixo e laranja e a hora azul com o horizonte ainda aceso - sao o
## que faz a passagem ter cor.
##
## Uma hora e so dado: quem aplica no `Environment`, no sol e no ceu e o
## `Relogio`. Assim o teste confere o dia contra os numeros de antes sem montar
## mundo nenhum.

## Onde cada chave mora na hora corrida, de 0 (meio-dia) a 1 (noite fechada).
## O entardecer e o crepusculo ganham um terco cada: menos que isso e a cor da
## passagem dura um piscar.
const CHAVES: Array[float] = [0.0, 0.35, 0.65, 1.0]
## O LUT de cada chave, na mesma ordem (`arte/paleta.py`).
const LUTS: Array[String] = [
	"res://assets/visual/lut_dia.png",
	"res://assets/visual/lut_entardecer.png",
	"res://assets/visual/lut_crepusculo.png",
	"res://assets/visual/lut_noite.png",
]

## O gradiente do ceu (`ceu.gdshader`).
var ceu_topo: Color
var ceu_horizonte: Color
var ceu_chao_horizonte: Color
var ceu_chao_fundo: Color
## Multiplica o tom da nuvem: branco de dia, laranja no entardecer, quase
## preto de noite.
var nuvem_luz: Color
## Soma na barriga da nuvem, onde ela e grossa e escura: o laranja que a
## cidade acesa joga de baixo. De dia e preto, ou seja, nada.
var nuvem_baixo: Color
## Quanto das estrelas aparece, de 0 a 1.
var estrelas: float

## A unica luz direcional, que e sol de dia e lua de noite (ver `Relogio`).
var astro_rotacao: Vector3
var astro_cor: Color
var astro_energia: float
## O disco desenhado no ceu: raio em graus, o halo, e quanto ele brilha por
## conta propria. O disco do sol brilha pela energia da luz; a lua tem energia
## baixa (ilumina pouco) e precisaria de 10 vezes mais para o disco aparecer,
## entao ela brilha por fora.
var astro_disco: float
var astro_halo: float
var lua: float

var ambiente_energia: float
var ambiente_cor: Color
var ambiente_ceu: float
var neblina_cor: Color
var neblina_densidade: float

## Quanto ja escureceu, de 0 a 1. E o que acende a cidade: cada lampada,
## farol e janela tem o seu limiar (ver `Relogio.limiar`), e acende quando
## isto passa dele. Nao e a hora corrida: o entardecer ainda e claro, e a
## cidade acende quase toda na hora azul.
var escuro: float


## O meio-dia de sol duro: os numeros exatos do mundo antes de anoitecer. O
## teste confere um por um, porque e esta a hora que o banco de provas e a
## prova visual fotografam.
static func dia() -> Hora:
	var h := Hora.new()
	h.ceu_topo = Color(0.16, 0.38, 0.82)
	h.ceu_horizonte = Color(0.62, 0.74, 0.88)
	h.ceu_chao_horizonte = Color(0.55, 0.6, 0.62)
	h.ceu_chao_fundo = Color(0.24, 0.26, 0.25)
	h.nuvem_luz = Color(1.0, 1.0, 1.0)
	h.nuvem_baixo = Color(0.0, 0.0, 0.0)
	h.estrelas = 0.0
	h.astro_rotacao = Vector3(-42.0, 38.0, 0.0)
	h.astro_cor = Color(1.0, 0.96, 0.88)
	h.astro_energia = 2.0
	h.astro_disco = 1.5
	h.astro_halo = 0.25
	h.lua = 0.0
	# Metade do ceu, metade cinza neutro. So com o ceu, a sombra de um predio no
	# asfalto saia azul royal: na sombra a unica luz e a do ceu, e o LUT ainda
	# satura por cima. A sombra continua fria, so que fria de cinza.
	h.ambiente_energia = 0.5
	h.ambiente_cor = Color(0.62, 0.63, 0.65)
	h.ambiente_ceu = 0.5
	# Na cor do horizonte, para o predio do fundo sumir no ceu e nao num cinza.
	h.neblina_cor = Color(0.62, 0.74, 0.88)
	h.neblina_densidade = 0.0045
	h.escuro = 0.0
	return h


## Sol a 12 graus, laranja, sombra comprida. O ceu esquenta de baixo para
## cima, e a nuvem pega a luz rasante por baixo.
static func entardecer() -> Hora:
	var h := Hora.new()
	h.ceu_topo = Color(0.2, 0.3, 0.58)
	h.ceu_horizonte = Color(0.98, 0.64, 0.4)
	h.ceu_chao_horizonte = Color(0.55, 0.44, 0.4)
	h.ceu_chao_fundo = Color(0.2, 0.18, 0.17)
	h.nuvem_luz = Color(1.0, 0.8, 0.64)
	h.nuvem_baixo = Color(0.1, 0.02, 0.05)
	h.estrelas = 0.0
	# A mesma direcao do meio-dia, so mais baixa: o sol nao pula de lado no
	# ceu enquanto desce.
	h.astro_rotacao = Vector3(-12.0, 38.0, 0.0)
	h.astro_cor = Color(1.0, 0.62, 0.32)
	h.astro_energia = 1.6
	# Perto do horizonte o sol parece maior e o halo abre: e o que o olho
	# espera de um por do sol, mesmo que a lente nao concorde.
	h.astro_disco = 2.2
	h.astro_halo = 0.6
	h.lua = 0.0
	h.ambiente_energia = 0.45
	h.ambiente_cor = Color(0.62, 0.52, 0.5)
	h.ambiente_ceu = 0.5
	h.neblina_cor = Color(0.86, 0.62, 0.46)
	h.neblina_densidade = 0.005
	h.escuro = 0.1
	return h


## A hora azul: o sol ja desceu, o horizonte ainda brilha e a cidade acende.
## Sem luz direta nenhuma - quem ilumina e o ceu, pelo ambiente.
static func crepusculo() -> Hora:
	var h := Hora.new()
	h.ceu_topo = Color(0.06, 0.09, 0.24)
	h.ceu_horizonte = Color(0.6, 0.36, 0.3)
	h.ceu_chao_horizonte = Color(0.25, 0.2, 0.22)
	h.ceu_chao_fundo = Color(0.08, 0.08, 0.1)
	h.nuvem_luz = Color(0.42, 0.32, 0.4)
	h.nuvem_baixo = Color(0.12, 0.04, 0.02)
	h.estrelas = 0.15
	# O sol 6 graus abaixo do horizonte, na mesma direcao: apagado, mas sem
	# trocar de lado. E daqui que a luz vira a lua (ver `noite`).
	h.astro_rotacao = Vector3(6.0, 38.0, 0.0)
	h.astro_cor = Color(0.9, 0.5, 0.35)
	h.astro_energia = 0.0
	h.astro_disco = 2.2
	h.astro_halo = 0.6
	h.lua = 0.0
	h.ambiente_energia = 0.5
	h.ambiente_cor = Color(0.22, 0.24, 0.36)
	h.ambiente_ceu = 0.5
	h.neblina_cor = Color(0.36, 0.26, 0.3)
	h.neblina_densidade = 0.0055
	h.escuro = 0.6
	return h


## Noite de cidade grande: azul-marinho em cima, laranja sujo embaixo - e a
## luz da cidade batendo na poeira do ar -, poucas estrelas e a lua.
static func noite() -> Hora:
	var h := Hora.new()
	h.ceu_topo = Color(0.012, 0.018, 0.05)
	h.ceu_horizonte = Color(0.2, 0.12, 0.09)
	h.ceu_chao_horizonte = Color(0.1, 0.08, 0.08)
	h.ceu_chao_fundo = Color(0.03, 0.03, 0.04)
	h.nuvem_luz = Color(0.1, 0.1, 0.14)
	h.nuvem_baixo = Color(0.16, 0.08, 0.04)
	h.estrelas = 1.0
	# A lua do outro lado do ceu. O caminho do crepusculo ate aqui gira a luz
	# enquanto ela ainda esta apagada, e a lua so acende no fim (`lua`).
	h.astro_rotacao = Vector3(-38.0, -50.0, 0.0)
	h.astro_cor = Color(0.62, 0.72, 1.0)
	h.astro_energia = 0.18
	h.astro_disco = 0.9
	h.astro_halo = 0.15
	h.lua = 1.0
	h.ambiente_energia = 0.6
	h.ambiente_cor = Color(0.1, 0.12, 0.2)
	h.ambiente_ceu = 0.5
	h.neblina_cor = Color(0.12, 0.09, 0.09)
	h.neblina_densidade = 0.006
	h.escuro = 1.0
	return h


static func chaves() -> Array[Hora]:
	return [dia(), entardecer(), crepusculo(), noite()]


## Em que trecho entre chaves a hora `t` cai: (indice da chave de baixo, quanto
## ja andou ate a de cima). Nas pontas, a propria chave com 0.
static func trecho(t: float) -> Vector2:
	t = clampf(t, 0.0, 1.0)
	for i in range(CHAVES.size() - 1):
		if t <= CHAVES[i + 1]:
			return Vector2(i, (t - CHAVES[i]) / (CHAVES[i + 1] - CHAVES[i]))
	return Vector2(CHAVES.size() - 2, 1.0)


## A hora `t`, de 0 (meio-dia) a 1 (noite fechada), misturada das chaves.
static func na(t: float) -> Hora:
	var lista := chaves()
	var onde := trecho(t)
	return lista[int(onde.x)].mistura(lista[int(onde.x) + 1], onde.y)


## Esta hora andando `f` em direcao a `outra`.
func mistura(outra: Hora, f: float) -> Hora:
	if f <= 0.0:
		return self
	if f >= 1.0:
		return outra
	var h := Hora.new()
	h.ceu_topo = ceu_topo.lerp(outra.ceu_topo, f)
	h.ceu_horizonte = ceu_horizonte.lerp(outra.ceu_horizonte, f)
	h.ceu_chao_horizonte = ceu_chao_horizonte.lerp(outra.ceu_chao_horizonte, f)
	h.ceu_chao_fundo = ceu_chao_fundo.lerp(outra.ceu_chao_fundo, f)
	h.nuvem_luz = nuvem_luz.lerp(outra.nuvem_luz, f)
	h.nuvem_baixo = nuvem_baixo.lerp(outra.nuvem_baixo, f)
	h.estrelas = lerpf(estrelas, outra.estrelas, f)
	h.astro_rotacao = astro_rotacao.lerp(outra.astro_rotacao, f)
	h.astro_cor = astro_cor.lerp(outra.astro_cor, f)
	# Pelo mesmo motivo, a luz que nasce do apagado (a lua saindo do
	# crepusculo) so ganha forca no fim: acesa durante o giro, a sombra de
	# todo predio varreria o asfalto.
	var g := f * f * f if is_zero_approx(astro_energia) else f
	h.astro_energia = lerpf(astro_energia, outra.astro_energia, g)
	h.astro_disco = lerpf(astro_disco, outra.astro_disco, f)
	h.astro_halo = lerpf(astro_halo, outra.astro_halo, f)
	# A lua acende no fim do trecho, e nao junto com o giro: com a luz
	# girando do poente ate o lado da lua, um disco aceso no meio do caminho
	# seria uma lua atravessando o ceu em vinte segundos.
	h.lua = lerpf(lua, outra.lua, f * f * f)
	h.ambiente_energia = lerpf(ambiente_energia, outra.ambiente_energia, f)
	h.ambiente_cor = ambiente_cor.lerp(outra.ambiente_cor, f)
	h.ambiente_ceu = lerpf(ambiente_ceu, outra.ambiente_ceu, f)
	h.neblina_cor = neblina_cor.lerp(outra.neblina_cor, f)
	h.neblina_densidade = lerpf(neblina_densidade, outra.neblina_densidade, f)
	h.escuro = lerpf(escuro, outra.escuro, f)
	return h
