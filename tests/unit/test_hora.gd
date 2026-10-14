extends GdUnitTestSuite
## A corrida que anoitece: as horas-chave e o relogio.
##
## O que quebra em silencio aqui e o DIA. O banco de provas, os shots e a prova
## visual fotografam o meio-dia, e o meio-dia agora sai da `Hora.dia()` em vez
## de numeros escritos no `world.gd`. Um numero que andar ali muda a tela de
## toda medida, e o jogo continua rodando lindo - so que outro.


func test_o_dia_e_o_meio_dia_de_antes() -> void:
	# Os numeros de `world.gd:_build_environment` e do `ceu.gdshader` antes de
	# a corrida anoitecer.
	var h := Hora.dia()
	assert_that(h.ceu_topo).is_equal(Color(0.16, 0.38, 0.82))
	assert_that(h.ceu_horizonte).is_equal(Color(0.62, 0.74, 0.88))
	assert_that(h.ceu_chao_horizonte).is_equal(Color(0.55, 0.6, 0.62))
	assert_that(h.ceu_chao_fundo).is_equal(Color(0.24, 0.26, 0.25))
	assert_that(h.astro_rotacao).is_equal(Vector3(-42.0, 38.0, 0.0))
	assert_that(h.astro_cor).is_equal(Color(1.0, 0.96, 0.88))
	assert_float(h.astro_energia).is_equal(2.0)
	assert_float(h.astro_disco).is_equal(1.5)
	assert_float(h.astro_halo).is_equal(0.25)
	assert_float(h.ambiente_energia).is_equal(0.5)
	assert_that(h.ambiente_cor).is_equal(Color(0.62, 0.63, 0.65))
	assert_float(h.ambiente_ceu).is_equal(0.5)
	assert_that(h.neblina_cor).is_equal(Color(0.62, 0.74, 0.88))
	assert_float(h.neblina_densidade).is_equal(0.0045)
	# E nada da noite: nem nuvem tingida, nem estrela, nem lua, nem escuro.
	assert_that(h.nuvem_luz).is_equal(Color(1.0, 1.0, 1.0))
	assert_that(h.nuvem_baixo).is_equal(Color(0.0, 0.0, 0.0))
	assert_float(h.estrelas).is_equal(0.0)
	assert_float(h.lua).is_equal(0.0)
	assert_float(h.escuro).is_equal(0.0)


func test_na_chave_a_hora_e_a_propria_chave() -> void:
	var chaves := Hora.chaves()
	for i in Hora.CHAVES.size():
		var h := Hora.na(Hora.CHAVES[i])
		assert_that(h.ceu_topo).is_equal(chaves[i].ceu_topo)
		assert_float(h.escuro).is_equal(chaves[i].escuro)
		assert_that(h.astro_rotacao).is_equal(chaves[i].astro_rotacao)


func test_um_lut_por_chave() -> void:
	assert_int(Hora.LUTS.size()).is_equal(Hora.CHAVES.size())
	for caminho in Hora.LUTS:
		assert_bool(ResourceLoader.exists(caminho)).is_true()
		assert_object(load(caminho)).is_instanceof(Texture3D)


func test_o_escuro_so_cresce() -> void:
	# Se o escuro voltasse em algum trecho, a lampada que acendeu apagaria no
	# meio da corrida.
	var antes := -1.0
	for i in 101:
		var escuro := Hora.na(i / 100.0).escuro
		assert_float(escuro).is_greater_equal(antes)
		antes = escuro


func test_a_curva_vai_do_meio_dia_a_noite() -> void:
	assert_float(Relogio.curva(0.0, 0.25, 0.85)).is_equal(0.0)
	assert_float(Relogio.curva(0.25, 0.25, 0.85)).is_equal(0.0)
	assert_float(Relogio.curva(0.55, 0.25, 0.85)).is_equal_approx(0.5, 1e-6)
	assert_float(Relogio.curva(0.85, 0.25, 0.85)).is_equal(1.0)
	assert_float(Relogio.curva(1.0, 0.25, 0.85)).is_equal(1.0)
	# Limites trocados no F3 nao dividem por zero: viram um degrau.
	assert_float(Relogio.curva(0.5, 0.6, 0.6)).is_equal(0.0)
	assert_float(Relogio.curva(0.7, 0.6, 0.6)).is_equal(1.0)


func test_o_limiar_e_o_mesmo_para_o_mesmo_lugar() -> void:
	var onde := Vector3(120.0, 0.0, -45.0)
	var a := Relogio.limiar(onde, 0.3, 0.7)
	assert_float(Relogio.limiar(onde, 0.3, 0.7)).is_equal(a)
	assert_float(a).is_between(0.3, 0.7)
	# E espalha: dez postes seguidos nao acendem todos no mesmo instante.
	var limiares := {}
	for i in 10:
		limiares[Relogio.limiar(Vector3(i * 25.0, 0.0, 0.0), 0.3, 0.7)] = true
	assert_int(limiares.size()).is_greater(5)
