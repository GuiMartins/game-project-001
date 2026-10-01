extends GdUnitTestSuite
## Autoria da queda do rival: quem derruba paga, quem assiste nao.
##
## Um rival ia ao chao e o jogador recebia 150 de estilo e 20 de adrenalina,
## tivesse ele encostado no rival ou nao. Parado na largada, sem input, os cinco
## rivais se espatifavam sozinhos no transito e a nota subia um quinto sozinha.
##
## O banco de provas pega o efeito disso com o mundo rodando (a corrida solta
## exige ZERO rivais derrubados, porque o piloto automatico nao soca). Aqui e a
## regra em si: quanto tempo um soco responde pela queda do rival.


func _rival() -> RivalBike:
	var pista: RoadTrack = auto_free(RoadTrack.new())
	pista.build(300.0, RandomNumberGenerator.new())
	var mundo: Node = auto_free(Node.new())
	# A moto so precisa existir: o rival cambaleando nao consulta nada dela, e
	# fora da arvore ela nem roda fisica.
	var jogador: PlayerBike = auto_free(PlayerBike.new())
	var rival: RivalBike = auto_free(RivalBike.new())
	# Na arvore de proposito: e o `_ready` que monta o sensor de acidente e a
	# hitbox do soco, e sem eles nem `reset_race` roda.
	add_child(rival)
	rival.setup(pista, BikeTuning.new(), WorldTuning.new(), mundo, jogador, Color.WHITE, 1)
	rival.reset_race(10.0, 0.0, 1000.0)
	return rival


func test_rival_inteiro_nao_tem_dono() -> void:
	# Ninguem encostou nele: se cair no transito agora, a queda e dele.
	assert_bool(_rival().derrubado_pelo_jogador()).is_false()


func test_o_soco_responde_pela_queda() -> void:
	var rival := _rival()
	rival.receive_hit(1, 7.5, 0.7)
	assert_bool(rival.derrubado_pelo_jogador()).is_true()


func test_o_credito_do_soco_cobre_o_cambaleio_inteiro() -> void:
	# O golpe do Road Rash nao derruba, empurra: o rival ainda passa o
	# `punch_stagger` sem governar a moto, e e ai que ele acha a lataria.
	var rival := _rival()
	rival.receive_hit(1, 7.5, 0.7)
	for i in 8:
		rival._physics_process(0.1)
	assert_bool(rival.derrubado_pelo_jogador()).is_true()


func test_o_credito_do_soco_expira() -> void:
	# Passado o prazo, o rival voltou a correr por conta propria. Creditar ao
	# jogador uma queda de meia avenida depois e o mesmo bug com outro nome.
	var rival := _rival()
	rival.receive_hit(1, 7.5, 0.7)
	for i in 20:
		rival._physics_process(0.1)
	assert_bool(rival.derrubado_pelo_jogador()).is_false()
