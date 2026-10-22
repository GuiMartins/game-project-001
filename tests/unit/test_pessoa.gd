extends GdUnitTestSuite
## A gente que faz mais do que andar reto: desce do carro, atravessa a rua e
## pula da frente da moto.
##
## Nada disto tem colisor nem entra numa medida do banco de provas: quem desce
## do carro e fica sentado no meio da faixa, ou quem pula para dentro do
## caminho da moto, deixa o jogo rodando igual. So aparece aqui.

const PASSO: float = 1.0 / 60.0


func _carro() -> Carro:
	var carro: Carro = auto_free(Carro.new())
	add_child(carro)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	carro.montar(Carro.Modelo.SEDA, rng)
	return carro


## Roda o carro e quem desceu dele por `segundos`, fechando a porta em
## `fecha_em`, como o `TrafficCar` faz.
func _roda(carro: Carro, segundos: float, fecha_em: float) -> Pessoa:
	var pessoa := carro.find_child("Desceu", false, false) as Pessoa
	assert_object(pessoa).is_not_null()
	pessoa.set_physics_process(false)
	var t := 0.0
	var fechou := false
	var fora_na_porta := false
	while t < segundos:
		t += PASSO
		carro.atualizar(PASSO, 0.0, 0.0, true, 0)
		pessoa._physics_process(PASSO)
		if t >= fecha_em and not fechou:
			carro.fechar_portas()
			fechou = true
			fora_na_porta = absf(pessoa.position.x) > carro.caixa().size.x * 0.5
	# Quando a porta bate, ela ja esta do lado de fora: senao a porta fecha
	# nela.
	assert_bool(fora_na_porta).is_true()
	return pessoa


func test_motorista_desce_pelo_lado_da_rua_e_contorna_ate_a_calcada() -> void:
	var carro := _carro()
	carro.abrir_porta(-1)
	# A calcada a direita do carro, e a porta do motorista a esquerda.
	carro.desembarcar(2.5, 3.0)
	# Pela porta da frente desce quem dirigia, e o banco dele fica vazio.
	var da_frente := carro.porta_ativa().name == "Porta_DE"
	assert_bool(carro.find_child("Motorista", true, false).visible).is_equal(not da_frente)
	var pessoa := _roda(carro, 20.0, 2.5)
	assert_int(pessoa.estado).is_equal(Pessoa.Estado.PARADA)
	assert_float(pessoa.position.x).is_equal_approx(3.0, 0.05)
	# De pe, e nao sentada no meio da calcada.
	assert_float(pessoa.get("_altura")).is_equal_approx(Pessoa.QUADRIL, 0.001)


func test_quem_desce_do_lado_da_calcada_vai_direto_para_ela() -> void:
	var carro := _carro()
	carro.abrir_porta(1)
	carro.desembarcar(3.5, 3.0)
	var pessoa := _roda(carro, 20.0, 3.5)
	assert_int(pessoa.estado).is_equal(Pessoa.Estado.PARADA)
	assert_float(pessoa.position.x).is_equal_approx(3.0, 0.05)


func test_reciclar_o_carro_leva_quem_desceu_e_devolve_o_motorista() -> void:
	var carro := _carro()
	carro.abrir_porta(-1)
	carro.desembarcar(2.5, 3.0)
	var rng := RandomNumberGenerator.new()
	carro.montar(Carro.Modelo.SEDA, rng)
	assert_bool(carro.find_child("Motorista", true, false).visible).is_true()
	await await_idle_frame()
	assert_object(carro.find_child("Desceu", false, false)).is_null()


## Uma moto de mentira: so precisa estar no grupo e andar.
func _moto(de: Vector3) -> Node3D:
	var moto: Node3D = auto_free(Node3D.new())
	add_child(moto)
	moto.position = de
	moto.add_to_group(Pessoa.GRUPO_MOTOS)
	return moto


func test_pula_para_fora_do_caminho_da_moto() -> void:
	var raiz: Node3D = auto_free(Node3D.new())
	add_child(raiz)
	var pessoa: Pessoa = Pessoa.new()
	raiz.add_child(pessoa)
	pessoa.set_physics_process(false)
	pessoa.colocar(Vector3(0.3, 0.0, 0.0), 0.0)
	var moto := _moto(Vector3(0.0, 0.0, 40.0))
	var pulou := false
	for i in 120:
		moto.position.z -= 40.0 * PASSO
		pessoa._physics_process(PASSO)
		pulou = pulou or pessoa.estado == Pessoa.Estado.SUSTO
	assert_bool(pulou).is_true()
	# Para o lado em que ja estava, e longe o bastante para a moto passar.
	assert_float(pessoa.position.x).is_greater(1.2)
	assert_int(pessoa.estado).is_equal(Pessoa.Estado.PARADA)


func test_moto_que_passa_longe_nao_assusta() -> void:
	var raiz: Node3D = auto_free(Node3D.new())
	add_child(raiz)
	var pessoa: Pessoa = Pessoa.new()
	raiz.add_child(pessoa)
	pessoa.set_physics_process(false)
	pessoa.colocar(Vector3.ZERO, 0.0)
	var moto := _moto(Vector3(4.0, 0.0, 40.0))
	for i in 120:
		moto.position.z -= 40.0 * PASSO
		pessoa._physics_process(PASSO)
		assert_int(pessoa.estado).is_not_equal(Pessoa.Estado.SUSTO)


func test_travessia_e_quatro_na_zebra_para_uma_fora() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260831
	var pista: RoadTrack = auto_free(RoadTrack.new())
	add_child(pista)
	pista.build(3200.0, rng)
	var props: Node3D = auto_free(Node3D.new())
	add_child(props)
	Cidade.new(pista).montar(rng, props)
	var bocas := 0
	for c in pista.cruzamentos:
		bocas += 2 if c.y == Cidade.LADO_AMBOS else 1
	var plano := Travessia.planejar(pista, rng)
	var zebra := 0
	var fora := 0
	for e in plano:
		if e.tipo == Travessia.Tipo.ZEBRA:
			zebra += 1
		else:
			fora += 1
			# Fora da faixa e longe da zebra e da boca da rua.
			for c in pista.cruzamentos:
				assert_float(absf(e.offset - c.x)).is_greater_equal(25.0)
	assert_int(zebra).is_greater(0)
	assert_int(fora).is_equal(roundi(zebra * Travessia.FORA_POR_ZEBRA))
	# Sem exagero: nem toda boca de rua tem gente atravessando.
	assert_int(zebra).is_less(bocas / 2 + 1)


func test_faixa_livre_espera_o_carro_que_vem() -> void:
	# Carro na faixa, 20 m atras, a 10 m/s: chega em 2 s menos o meio carro.
	assert_bool(Travessia._livre_de(100.0, 0.0, 3.3, 3.0, 80.0, 1.65, 10.0, 0.9, 2.2)).is_false()
	# O mesmo carro, para quem so precisa de 1 s.
	assert_bool(Travessia._livre_de(100.0, 0.0, 3.3, 1.0, 80.0, 1.65, 10.0, 0.9, 2.2)).is_true()
	# Na outra faixa nao conta.
	assert_bool(Travessia._livre_de(100.0, 0.0, 3.3, 3.0, 80.0, -1.65, 10.0, 0.9, 2.2)).is_true()
	# Ja passou.
	assert_bool(Travessia._livre_de(100.0, 0.0, 3.3, 3.0, 105.0, 1.65, 10.0, 0.9, 2.2)).is_true()
	# Parado bem em cima de onde se atravessa.
	assert_bool(Travessia._livre_de(100.0, 0.0, 3.3, 3.0, 100.0, 1.65, 0.0, 0.9, 2.2)).is_false()


func _sangue() -> Node3D:
	var no: Node3D = auto_free(Node3D.new())
	add_child(no)
	no.add_to_group(Sangue.GRUPO)
	return no


func test_atropelada_voa_quica_e_fica_deitada_longe() -> void:
	var sangue := _sangue()
	var raiz: Node3D = auto_free(Node3D.new())
	add_child(raiz)
	var pessoa: Pessoa = Pessoa.new()
	raiz.add_child(pessoa)
	pessoa.set_physics_process(false)
	pessoa.colocar(Vector3.ZERO, 0.0)
	# Perto demais para pular: a 40 m/s, 1 m e um passo e meio.
	var moto := _moto(Vector3(0.0, 0.0, 1.0))
	var voou := false
	var mais_alto := 0.0
	for i in 600:
		moto.position.z -= 40.0 * PASSO
		pessoa._physics_process(PASSO)
		voou = voou or pessoa.estado == Pessoa.Estado.VOANDO
		mais_alto = maxf(mais_alto, pessoa.position.y)
	assert_bool(voou).is_true()
	assert_int(pessoa.estado).is_equal(Pessoa.Estado.CAIDA)
	# Subiu, foi para onde a moto ia (-Z) e parou deitada no chao.
	assert_float(mais_alto).is_greater(1.0)
	assert_float(pessoa.position.z).is_less(-6.0)
	assert_float(pessoa.position.y + Pessoa.PIVO.y).is_equal_approx(Pessoa.DEITADO, 0.01)
	# Mancha onde foi pega, onde quicou, por onde arrastou e onde parou.
	assert_int(sangue.get_child_count()).is_greater(3)


func test_moto_parada_nao_atropela() -> void:
	var raiz: Node3D = auto_free(Node3D.new())
	add_child(raiz)
	var pessoa: Pessoa = Pessoa.new()
	raiz.add_child(pessoa)
	pessoa.set_physics_process(false)
	pessoa.colocar(Vector3.ZERO, 0.0)
	_moto(Vector3(0.2, 0.0, 0.0))
	for i in 60:
		pessoa._physics_process(PASSO)
	assert_int(pessoa.estado).is_equal(Pessoa.Estado.PARADA)


func test_moto_atropela_quem_anda_na_calcada_e_a_largada_devolve() -> void:
	_sangue()
	var multidao: Multidao = auto_free(Multidao.new())
	add_child(multidao)
	var gente: Array = []
	for i in 6:
		gente.append([Transform3D(Basis.IDENTITY, Vector3(float(i) * 20.0, 0.0, 0.0)), Color.RED])
	multidao.montar(gente, true)
	multidao.set_physics_process(false)
	multidao._physics_process(PASSO)
	# A moto vem pela lateral, reto em cima de onde a terceira esta agora - que
	# nao e onde nasceu: ela anda.
	var alvo := multidao.lugar(2)
	var moto := _moto(alvo + Vector3(-10.0, 0.0, 0.0))
	for i in 30:
		moto.position = alvo + Vector3(-10.0 + 30.0 * PASSO * float(i + 1), 0.0, 0.0)
		multidao._physics_process(PASSO)
	assert_bool(multidao.caiu(2)).is_true()
	for i: int in [0, 1, 3, 4, 5]:
		assert_bool(multidao.caiu(i)).is_false()
	assert_object(multidao.find_child("Atropelado", false, false)).is_not_null()
	multidao.reiniciar()
	assert_bool(multidao.caiu(2)).is_false()


func test_quem_anda_no_multimesh_vai_e_volta_sem_sair_do_trecho() -> void:
	var meio := Multidao.TRECHO * 0.5
	var antes := Multidao.deslocamento(0.0, 0.3, 0.6)
	var maior := 0.0
	for i in 1200:
		var agora := Multidao.deslocamento(float(i) * 0.05, 0.3, 0.6)
		assert_float(absf(agora)).is_less_equal(meio + 0.001)
		# Sem teletransporte: a 1,6 m/s, no maximo 8 cm por passo de 0,05 s.
		maior = maxf(maior, absf(agora - antes))
		antes = agora
	assert_float(maior).is_less(0.1)


func test_menu_troca_toda_a_multidao_e_mantem_o_atropelado() -> void:
	var multidao: Multidao = auto_free(Multidao.new())
	add_child(multidao)
	var gente: Array = []
	for i in 15:
		gente.append([Transform3D(Basis.IDENTITY, Vector3(float(i) * 20.0, 0.0, 0.0)), Color.RED])
	multidao.montar(gente, true)
	var total := 0
	for no in multidao.get_children():
		if no is MultiMeshInstance3D:
			total += (no as MultiMeshInstance3D).multimesh.instance_count
			assert_bool(no.visible).is_false()
	assert_int(total).is_equal(gente.size())
	multidao.sprite = true
	for no in multidao.get_children():
		if no is MultiMeshInstance3D:
			assert_bool(no.visible).is_true()
	var corpo := multidao.atropelar(2, Vector3(20.0, 0.0, 0.0))
	assert_bool(corpo.find_child("Sprite", false, false).visible).is_true()
	multidao.sprite = false
	corpo.usar_sprite(false)
	assert_bool(corpo.find_child("Sprite", false, false).visible).is_false()
	multidao.reiniciar()
	assert_bool(multidao.caiu(2)).is_false()


func test_sprite_da_multidao_acompanha_a_rampa() -> void:
	var pista: RoadTrack = auto_free(RoadTrack.new())
	add_child(pista)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260831
	pista.build(3000.0, rng)
	var gente: Array = Pedestres.posicoes(pista, [], rng)[Pedestres.Pose.ANDANDO]
	assert_bool(gente.is_empty()).is_false()
	var maior_erro := 0.0
	var maior_erro_sem_relevo := 0.0
	for item: Array in gente:
		var base: Transform3D = item[0]
		var relevo: Vector2 = item[2]
		var o := pista.curve.get_closest_offset(base.origin)
		var sentido := 1.0 if base.basis.z.dot(pista.sample_basis(o).z) > 0.0 else -1.0
		for passo in 15:
			var deslocado := -Multidao.TRECHO * 0.5 + float(passo) * Multidao.TRECHO / 14.0
			var piso := pista.sample_position(o + sentido * deslocado).y
			var sem_relevo := base.origin.y - base.basis.z.y * deslocado
			var sprite := sem_relevo + Multidao.altura_do_relevo(deslocado, relevo)
			maior_erro_sem_relevo = maxf(maior_erro_sem_relevo, absf(sem_relevo - piso))
			maior_erro = maxf(maior_erro, absf(sprite - piso))
	assert_float(maior_erro_sem_relevo).is_greater(0.05)
	assert_float(maior_erro).is_less(0.05)


func test_pessoa_em_sprite_tem_folha_para_todos_os_estados() -> void:
	var pessoa: Pessoa = auto_free(Pessoa.new())
	add_child(pessoa)
	pessoa.usar_sprite(true)
	var desenho := pessoa.find_child("Sprite", false, false) as PedestreSprite
	for avatar in PedestreSprite.ANDANDO.size():
		pessoa.avatar = avatar
		for estado: int in Pessoa.Estado.values():
			pessoa.estado = estado
			pessoa._aplica()
			var esperado: Texture2D = PedestreSprite.ANDANDO[avatar]
			match estado:
				Pessoa.Estado.SUSTO:
					esperado = PedestreSprite.da_pose(PedestreSprite.SUSTO, avatar)
				Pessoa.Estado.SENTADA, Pessoa.Estado.DESEMBARCANDO:
					esperado = PedestreSprite.da_pose(PedestreSprite.DESEMBARCANDO, avatar)
				Pessoa.Estado.VOANDO:
					esperado = PedestreSprite.da_pose(PedestreSprite.VOANDO, avatar)
				Pessoa.Estado.CAIDA:
					esperado = PedestreSprite.da_pose(PedestreSprite.CAIDA, avatar)
			assert_bool(desenho.visible).is_true()
			(
				assert_object(
					(desenho.material_override as ShaderMaterial).get_shader_parameter(&"atlas")
				)
				. is_equal(esperado)
			)


func test_caminhada_parcial_conserva_identidade_e_recupera_ancora_depois_da_queda() -> void:
	var desenho: PedestreSprite = auto_free(PedestreSprite.new())
	add_child(desenho)
	desenho.visible = true
	for avatar in PedestreSprite.APENAS_CAMINHADA:
		for estado: int in Pessoa.Estado.values():
			desenho.posar(estado, PI, 0.8, 0.5, 1.0, avatar)
			var mat := desenho.material_override as ShaderMaterial
			assert_object(mat.get_shader_parameter(&"atlas")).is_equal(
				PedestreSprite.ANDANDO[avatar]
			)
			assert_int(int(mat.get_shader_parameter(&"linhas"))).is_equal(4)
			assert_int(int(mat.get_shader_parameter(&"colunas"))).is_equal(8)
		desenho.posar(Pessoa.Estado.CAIDA, 0.0, 1.0, 0.0, 0.0, avatar)
		desenho.posar(Pessoa.Estado.ANDANDO, PI, 0.0, 0.0, 1.0, avatar)
		assert_float((desenho.mesh as QuadMesh).center_offset.y).is_equal_approx(0.96, 0.001)
		assert_float(desenho.position.y).is_equal(0.0)
		(
			assert_float(
				float((desenho.material_override as ShaderMaterial).get_shader_parameter(&"giro"))
			)
			. is_equal(0.0)
		)


func test_quem_desembarca_nao_sorteia_personagem_com_apenas_caminhada() -> void:
	var pessoa: Pessoa = auto_free(Pessoa.new())
	add_child(pessoa)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261022
	for i in 100:
		pessoa.sortear(rng, true)
		assert_bool(pessoa.avatar in PedestreSprite.APENAS_CAMINHADA).is_false()


func test_fiscal_ergue_um_braco_depois_outro_e_baixa_os_dois() -> void:
	var pessoa: Pessoa = auto_free(Pessoa.new())
	pessoa.cena_articulada = preload("res://assets/pedestres/fiscal.glb")
	add_child(pessoa)
	pessoa.set_physics_process(false)
	pessoa.usar_sprite(true)
	pessoa.sinalizar_largada(0.0)
	assert_float(pessoa._nos_braco[1].rotation.x).is_equal_approx(0.0, 0.001)
	pessoa.sinalizar_largada(1.0)
	assert_float(pessoa._nos_braco[1].rotation.x).is_greater(2.7)
	assert_float(pessoa._nos_braco[0].rotation.x).is_equal_approx(0.0, 0.001)
	pessoa.sinalizar_largada(2.0)
	for braco in pessoa._nos_braco:
		assert_float(braco.rotation.x).is_greater(2.7)
	pessoa.sinalizar_largada(3.0)
	for braco in pessoa._nos_braco:
		assert_float(braco.rotation.x).is_equal_approx(0.0, 0.001)
	assert_bool(pessoa._sprite.visible).is_false()
	assert_vector(pessoa._no_quadril.position).is_equal_approx(
		Vector3(0, Pessoa.QUADRIL, 0), Vector3.ONE * 0.001
	)
