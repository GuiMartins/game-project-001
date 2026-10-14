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
