extends GdUnitTestSuite
## A bancada das folhas de referencia (`arte/boneco_cena.gd`). So a conta da
## caixa: a captura em si precisa de tela e e o `dev.py boneco` que a exercita.

const Cena := preload("res://arte/boneco_cena.gd")


func _caixa(tamanho: Vector3, onde: Vector3) -> MeshInstance3D:
	var malha := MeshInstance3D.new()
	var forma := BoxMesh.new()
	forma.size = tamanho
	malha.mesh = forma
	malha.position = onde
	return malha


func test_a_caixa_e_no_espaco_do_no_e_nao_no_do_mundo() -> void:
	var cena: Node = auto_free(Cena.new())
	var raiz: Node3D = auto_free(Node3D.new())
	raiz.position = Vector3(10.0, 5.0, 0.0)
	add_child(raiz)
	raiz.add_child(_caixa(Vector3(1.0, 2.0, 1.0), Vector3(3.0, 0.0, 0.0)))
	var caixa: AABB = cena.caixa_de(raiz)
	assert_vector(caixa.position).is_equal_approx(Vector3(2.5, -1.0, -0.5), Vector3.ONE * 0.001)
	assert_vector(caixa.size).is_equal_approx(Vector3(1.0, 2.0, 1.0), Vector3.ONE * 0.001)


func test_a_caixa_junta_todas_as_malhas_e_ignora_as_escondidas() -> void:
	var cena: Node = auto_free(Cena.new())
	var raiz: Node3D = auto_free(Node3D.new())
	add_child(raiz)
	raiz.add_child(_caixa(Vector3.ONE, Vector3.ZERO))
	raiz.add_child(_caixa(Vector3.ONE, Vector3(4.0, 0.0, 0.0)))
	var escondida := _caixa(Vector3.ONE, Vector3(100.0, 0.0, 0.0))
	escondida.visible = false
	raiz.add_child(escondida)
	var caixa: AABB = cena.caixa_de(raiz)
	assert_float(caixa.size.x).is_equal_approx(5.0, 0.001)
