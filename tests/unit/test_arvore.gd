extends GdUnitTestSuite
## As arvores da avenida em sprite (2D51): o pe tem de ficar no chao e a altura
## tem de ser a da ficha. Pe errado afunda ou levita a arvore, e nada da erro:
## foi assim que a primeira versao nasceu enterrada e o jogo ficou sem arvore.


func _sprite(tipo: Arvore.Tipo) -> Sprite3D:
	var corpo: StaticBody3D = auto_free(Arvore.criar(tipo, Vector3.ZERO, Vector3.FORWARD))
	return corpo.get_child(0) as Sprite3D


## Altura do desenho em metros.
func _altura(sprite: Sprite3D) -> float:
	return sprite.texture.get_height() * sprite.pixel_size


func test_o_pe_fica_no_chao() -> void:
	# Centrado: o meio do desenho sobe meia altura e o pe fica na origem.
	for tipo: int in Arvore.Tipo.values():
		var sprite := _sprite(tipo as Arvore.Tipo)
		assert_bool(sprite.centered).is_true()
		assert_float(sprite.position.y).is_equal_approx(_altura(sprite) * 0.5, 0.05)


func test_a_altura_e_a_da_ficha() -> void:
	var copa := _altura(_sprite(Arvore.Tipo.COPA))
	var palmeira := _altura(_sprite(Arvore.Tipo.PALMEIRA))
	assert_float(copa).is_between(7.5, 8.5)
	assert_float(palmeira).is_between(10.5, 11.5)
