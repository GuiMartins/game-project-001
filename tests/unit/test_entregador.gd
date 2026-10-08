extends GdUnitTestSuite
## O ator: a pose que sai da velocidade, do acelerador, do esterco e da queda.
##
## Nada disto aparece no banco de provas. A fisica anda igual com a roda
## girando para tras, o pe enterrado no asfalto ou a mao a um palmo do guidao, e
## a regressao visual so pega a tela errada por inteiro. E o tipo de erro que
## nasce de um sinal trocado - a mesma classe da guinada que ja inverteu o jogo
## uma vez - e que ninguem ve ate parar para olhar a moto de perto.

const PASSO: float = 1.0 / 60.0
const LADOS: Array[String] = ["E", "D"]


func _ator(modelo: int = Entregador.Modelo.CG_160) -> Entregador:
	var ator: Entregador = auto_free(Entregador.new())
	ator.modelo = modelo
	add_child(ator)
	return ator


## Todas as motos, para os testes que valem para qualquer uma: a pose e uma so,
## e o que muda de moto para moto e lido do modelo. Um no faltando ou um eixo
## na altura errada num modelo novo aparece aqui, e nao na pista.
func _modelos() -> Array[int]:
	var todos: Array[int] = []
	for i in Entregador.CENAS.size():
		todos.append(i)
	return todos


func _anda(
	ator: Entregador,
	segundos: float,
	velocidade: float,
	acelerador: float,
	esterco: float,
	caido: bool = false,
	lado: float = 1.0
) -> void:
	for i in int(segundos / PASSO):
		ator.atualizar(PASSO, velocidade, acelerador, esterco, caido, lado)


func _no(ator: Entregador, nome: String) -> Node3D:
	return ator.find_child(nome, true, false) as Node3D


func test_roda_gira_para_a_frente() -> void:
	var ator := _ator()
	# Um passo so: a 10 m/s a roda de 0,3 m gira meio radiano, longe de dar a
	# volta e enganar o sinal.
	ator.atualizar(PASSO, 10.0, 1.0, 0.0, false)
	var topo := _no(ator, "Roda_Traseira").global_basis * Vector3.UP
	# A frente e -Z. Rodando para a frente, o topo da roda vai para la.
	assert_float(topo.z).is_less(0.0)


func test_parado_o_pe_esquerdo_vai_ao_chao() -> void:
	for modelo in _modelos():
		var ator := _ator(modelo)
		_anda(ator, 1.0, 0.0, 0.0, 0.0)
		var pe := _no(ator, "Pe_E").global_position
		assert_float(pe.y).is_equal_approx(Entregador.PE_NO_CHAO.y, 0.01)
		assert_float(pe.x).is_equal_approx(Entregador.PE_NO_CHAO.x, 0.01)
		# O direito nao sai da pedaleira: so um pe desce.
		assert_float(_no(ator, "Pe_D").global_position.y).is_greater(0.3)


func test_andando_o_pe_volta_para_a_pedaleira() -> void:
	var ator := _ator()
	_anda(ator, 1.0, 0.0, 0.0, 0.0)
	_anda(ator, 1.0, 20.0, 1.0, 0.0)
	assert_float(_no(ator, "Pe_E").global_position.y).is_greater(0.3)


func test_as_maos_acompanham_o_guidao() -> void:
	for modelo in _modelos():
		var ator := _ator(modelo)
		# Em repouso cada mao esta na sua manopla. Guarda onde, no espaco do
		# garfo.
		var direcao := _no(ator, "Direcao")
		var manoplas: Array[Vector3] = []
		for lado in LADOS:
			manoplas.append(direcao.to_local(_no(ator, "Mao_" + lado).global_position))

		# Devagar e com o esterco no batente: o caso em que o guidao mais vira.
		_anda(ator, 1.0, 2.0, 0.0, 1.0)
		var virou := rad_to_deg(direcao.basis.get_rotation_quaternion().get_angle())
		assert_float(virou).is_greater(10.0)
		for i in LADOS.size():
			var mao := _no(ator, "Mao_" + LADOS[i]).global_position
			var manopla := direcao.to_global(manoplas[i])
			assert_float(mao.distance_to(manopla)).is_less(0.01)


func test_joelho_abre_devagar_e_fecha_rapido() -> void:
	var ator := _ator()
	_anda(ator, 2.0, 3.0, 0.0, 0.0)
	var devagar := absf(_no(ator, "Canela_E").global_position.x)
	_anda(ator, 2.0, 30.0, 1.0, 0.0)
	var rapido := absf(_no(ator, "Canela_E").global_position.x)
	assert_float(devagar).is_greater(rapido + 0.05)


func test_a_queda_tomba_para_o_lado_pedido() -> void:
	for lado: float in [-1.0, 1.0]:
		var ator := _ator()
		_anda(ator, 1.0, 0.0, 0.0, 0.0, true, lado)
		# A moto deita em cima do lado pedido: o guidao vai para la e desce.
		var guidao := _no(ator, "Direcao").global_position
		assert_float(guidao.x * lado).is_greater(0.8)
		assert_float(guidao.y).is_less(0.4)
		# O piloto cai do mesmo lado, deitado, e nada dele atravessa o asfalto.
		var cabeca := _no(ator, "Cabeca").global_position
		assert_float(cabeca.x * lado).is_greater(0.5)
		assert_float(cabeca.y).is_less(0.4)
		_nada_no_subsolo(ator)


func test_a_queda_arremessa_o_piloto_para_a_frente() -> void:
	var ator := _ator()
	_anda(ator, 1.0, 25.0, 1.0, 0.0)
	# O corpo para no lugar da batida; quem voa e o piloto.
	_anda(ator, 0.4, 0.0, 0.0, 0.0, true, 1.0)
	var no_ar := _no(ator, "Piloto").global_position
	assert_float(no_ar.y).is_greater(0.9)
	_anda(ator, 1.6, 0.0, 0.0, 0.0, true, 1.0)
	var no_chao := _no(ator, "Piloto").global_position
	# A frente e -Z. Saiu a 25 m/s: voa e arrasta varios metros, e para.
	assert_float(no_chao.z).is_less(-6.0)
	assert_float(no_chao.y).is_less(0.45)
	_nada_no_subsolo(ator)
	# Levantou: o piloto volta para o banco no mesmo passo.
	_anda(ator, PASSO, 12.0, 0.0, 0.0)
	assert_float(_no(ator, "Piloto").global_position.distance_to(Vector3(0.0, 0.93, 0.24))).is_less(
		0.1
	)


func test_as_rodas_nao_saem_do_chao() -> void:
	for modelo in _modelos():
		var ator := _ator(modelo)
		_anda(ator, 1.0, 20.0, 1.0, 0.0)
		var rodas: Array[Node3D] = [_no(ator, "Roda_Traseira"), _no(ator, "Roda_Dianteira")]
		# Cada eixo na altura do raio da propria roda: na XRE a da frente e
		# maior, e um eixo so de referencia enterraria uma ou levantaria a outra.
		var alturas: Array[float] = []
		for roda in rodas:
			var raio := (roda as MeshInstance3D).get_aabb().size.y * 0.5
			assert_float(roda.global_position.y).is_equal_approx(raio, 0.01)
			alturas.append(roda.global_position.y)
		var garfo := _no(ator, "Direcao")
		var garfo_alto := garfo.global_position.y
		var mais_baixo := garfo_alto
		var mais_alto := garfo_alto
		var v := 20.0
		# Arranca, freia no talo e arranca de novo: a moto inteira afunda e
		# levanta, e os eixos nao saem do lugar.
		for fase: float in [16.0, -30.0, 16.0]:
			for i in 30:
				v = maxf(v + fase * PASSO, 0.0)
				ator.atualizar(PASSO, v, 1.0 if fase > 0.0 else 0.0, 0.0, false)
				for k in rodas.size():
					assert_float(rodas[k].global_position.y).is_equal_approx(alturas[k], 0.002)
				mais_baixo = minf(mais_baixo, garfo.global_position.y)
				mais_alto = maxf(mais_alto, garfo.global_position.y)
		assert_float(mais_alto - mais_baixo).is_greater(0.04)


func test_cada_roda_gira_na_velocidade_da_moto() -> void:
	for modelo in _modelos():
		var ator := _ator(modelo)
		# Um passo so, para nao dar a volta: o angulo e a distancia andada
		# sobre o raio de CADA roda.
		ator.atualizar(PASSO, 10.0, 1.0, 0.0, false)
		for nome: String in ["Roda_Traseira", "Roda_Dianteira"]:
			var roda := _no(ator, nome) as MeshInstance3D
			var raio := roda.get_aabb().size.y * 0.5
			assert_float(-roda.rotation.x).is_equal_approx(10.0 * PASSO / raio, 0.001)


func test_trocar_de_moto_com_ela_andando() -> void:
	var ator := _ator()
	_anda(ator, 1.0, 20.0, 1.0, 0.0)
	ator.trocar_modelo(Entregador.Modelo.XRE_300)
	assert_int(ator.modelo).is_equal(Entregador.Modelo.XRE_300)
	# Um modelo so na arvore: a moto velha sai inteira, e nao fica um segundo
	# piloto parado na largada.
	assert_int(ator.find_children("Piloto", "", true, false).size()).is_equal(1)
	_anda(ator, 0.5, 20.0, 1.0, 1.0)
	var direcao := _no(ator, "Direcao")
	var mao := _no(ator, "Mao_D").global_position
	assert_float(mao.distance_to(direcao.global_position)).is_less(0.6)
	# Pedido fora da lista nao quebra: fica na ultima.
	ator.trocar_modelo(99)
	assert_int(ator.modelo).is_equal(Entregador.CENAS.size() - 1)


func test_toda_moto_tem_um_nome_no_menu() -> void:
	assert_int(Entregador.NOMES.size()).is_equal(Entregador.CENAS.size())
	assert_int(Entregador.INCLINA_PARADO.size()).is_equal(Entregador.CENAS.size())


func test_a_freada_afunda_o_garfo_e_joga_o_piloto_para_a_frente() -> void:
	var ator := _ator()
	_anda(ator, 2.0, 20.0, 0.5, 0.0)
	var garfo := _no(ator, "Direcao").global_position
	var cabeca := _no(ator, "Cabeca").global_position
	var v := 20.0
	for i in 18:
		v -= 30.0 * PASSO
		ator.atualizar(PASSO, v, 0.0, 0.0, false)
	assert_float(_no(ator, "Direcao").global_position.y).is_less(garfo.y - 0.03)
	# A frente e -Z: o capacete vai para la.
	assert_float(_no(ator, "Cabeca").global_position.z).is_less(cabeca.z - 0.05)


func test_a_mola_continua_presa_no_amortecedor() -> void:
	for modelo in _modelos():
		var ator := _ator(modelo)
		ator.atualizar(PASSO, 0.0, 0.0, 0.0, false)
		var molas: Array[Node3D] = []
		var topos: Array[Vector3] = []
		for lado in LADOS:
			var mola := _no(ator, "Mola_" + lado)
			molas.append(mola)
			topos.append(mola.to_local(_no(ator, "Amortecedor_" + lado).global_position))
		_anda(ator, 1.0, 20.0, 1.0, 0.0)
		var v := 20.0
		for i in 20:
			v -= 30.0 * PASSO
			ator.atualizar(PASSO, v, 0.0, 0.0, false)
		for i in LADOS.size():
			var topo := molas[i].to_global(topos[i])
			var amortecedor := _no(ator, "Amortecedor_" + LADOS[i]).global_position
			assert_float(topo.distance_to(amortecedor)).is_less(0.005)


func test_o_soco_solta_o_braco_do_lado_e_volta_para_a_manopla() -> void:
	for lado: int in [-1, 1]:
		var ator := _ator()
		var direcao := _no(ator, "Direcao")
		var manoplas: Array[Vector3] = []
		for nome in LADOS:
			manoplas.append(direcao.to_local(_no(ator, "Mao_" + nome).global_position))
		_anda(ator, 1.0, 20.0, 1.0, 0.0)
		ator.socar(lado, 0.09, 0.13, 0.45)
		# No meio da janela ativa da hitbox o braco esta esticado para o lado.
		_anda(ator, 0.09 + 0.13 * 0.8, 20.0, 1.0, 0.0)
		var do_soco := 0 if lado < 0 else 1
		var punho := _no(ator, "Mao_" + LADOS[do_soco]).global_position
		assert_float(punho.x * lado).is_greater(0.8)
		# A outra mao continua no guidao.
		var outra := _no(ator, "Mao_" + LADOS[1 - do_soco]).global_position
		assert_float(outra.distance_to(direcao.to_global(manoplas[1 - do_soco]))).is_less(0.01)
		# E a cabeca olha para o lado do soco.
		var olhar := -_no(ator, "Cabeca").global_basis.z
		assert_float(olhar.x * lado).is_greater(0.4)
		_anda(ator, 0.3, 20.0, 1.0, 0.0)
		assert_bool(ator.socando()).is_false()
		punho = _no(ator, "Mao_" + LADOS[do_soco]).global_position
		assert_float(punho.distance_to(direcao.to_global(manoplas[do_soco]))).is_less(0.01)


func test_a_pancada_joga_o_tronco_com_o_empurrao() -> void:
	for lado: int in [-1, 1]:
		var ator := _ator()
		_anda(ator, 2.0, 20.0, 1.0, 0.0)
		var antes := _no(ator, "Cabeca").global_position
		ator.levar_golpe(lado)
		_anda(ator, 0.15, 20.0, 1.0, 0.0)
		assert_float((_no(ator, "Cabeca").global_position.x - antes.x) * lado).is_greater(0.03)
		_anda(ator, 3.0, 20.0, 1.0, 0.0)
		assert_float(_no(ator, "Cabeca").global_position.distance_to(antes)).is_less(0.01)


func _nada_no_subsolo(ator: Entregador) -> void:
	for nome: String in [
		"Piloto", "Cabeca", "Mao_E", "Mao_D", "Pe_E", "Pe_D", "Canela_E", "Canela_D"
	]:
		assert_float(_no(ator, nome).global_position.y).is_greater(0.0)


func test_a_queda_gira_deitada_para_o_lado_pedido() -> void:
	for giro: float in [-1.0, 1.0]:
		var ator := _ator()
		for i in int(1.5 / PASSO):
			ator.atualizar(PASSO, 0.0, 0.0, 0.0, true, 1.0, 0.0, giro)
		# O tombo e em volta do eixo da moto, entao a reta de uma roda a outra
		# so muda com o giro. Positivo gira para a esquerda, como a guinada: a
		# frente (-Z) vai para -X.
		var eixo := (
			_no(ator, "Roda_Dianteira").global_position - _no(ator, "Roda_Traseira").global_position
		)
		assert_float(eixo.x * giro).is_less(0.0)
		assert_float(absf(atan2(-eixo.x, -eixo.z))).is_equal_approx(1.0, 0.02)


func test_cores_de_fabrica_batem_com_a_textura() -> void:
	# Le o PNG que o gerador escreveu, nao a textura importada: e ele que o
	# `arte/entregador.py` regera quando a paleta muda.
	var albedo := Image.load_from_file(
		ProjectSettings.globalize_path("res://assets/entregador/entregador_albedo.png")
	)
	var mascara := Image.load_from_file(
		ProjectSettings.globalize_path("res://assets/entregador/entregador_mascara.png")
	)
	var fabrica: Array[Color] = [
		Entregador.BAG_FABRICA, Entregador.JAQUETA_FABRICA, Entregador.MOTO_FABRICA
	]
	for canal in 3:
		# A cor de fabrica de cada canal e a celula mais clara sob ele: a bag e
		# mais clara que a tampa dela, a pintura mais que o detalhe escuro.
		var mais_clara := Color.BLACK
		for y in range(4, albedo.get_height(), 8):
			for x in range(4, albedo.get_width(), 8):
				var cor := albedo.get_pixel(x, y)
				if mascara.get_pixel(x, y)[canal] < 0.5:
					continue
				if cor.get_luminance() > mais_clara.get_luminance():
					mais_clara = cor
		assert_float(mais_clara.r).is_equal_approx(fabrica[canal].r, 0.01)
		assert_float(mais_clara.g).is_equal_approx(fabrica[canal].g, 0.01)
		assert_float(mais_clara.b).is_equal_approx(fabrica[canal].b, 0.01)
