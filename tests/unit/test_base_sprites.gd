extends GdUnitTestSuite
## A base de uma folha (`BaseSprites`): fixar, achar o que mudou e mostrar.
##
## Usa uma folha de mentira, com id proprio, para nao pisar na base que quem
## trabalha na arte fixou de verdade em `user://`.

var _item: CatalogoSprites.Item


func before_test() -> void:
	_item = CatalogoSprites.varrer()[1]
	_item.id = "__teste_da_base__"
	BaseSprites.limpar(_item)


func after_test() -> void:
	BaseSprites.limpar(_item)


func test_sem_base_nao_ha_o_que_carregar() -> void:
	assert_bool(BaseSprites.existe(_item)).is_false()
	assert_object(BaseSprites.carregar(_item)).is_null()


func test_fixada_a_base_e_igual_a_folha_de_agora() -> void:
	assert_int(BaseSprites.fixar(_item)).is_equal(OK)
	var base := BaseSprites.carregar(_item)
	assert_object(base).is_not_null()
	assert_int(BaseSprites.quadros_diferentes(_item, base).size()).is_equal(0)


func test_a_folha_que_mudou_acusa_so_os_quadros_que_mudaram() -> void:
	BaseSprites.fixar(_item)
	var base := BaseSprites.carregar(_item)
	# Mexe em um pixel do quadro 3 (coluna 2, linha 0) da copia.
	var origem := Vector2i(2 * _item.celula.x, 0)
	var pixel := base.get_pixel(origem.x + 5, origem.y + 5)
	base.set_pixel(origem.x + 5, origem.y + 5, Color.WHITE if pixel != Color.WHITE else Color.BLACK)
	assert_array(Array(BaseSprites.quadros_diferentes(_item, base))).is_equal([2])


func test_base_de_outro_tamanho_diz_que_tudo_mudou() -> void:
	BaseSprites.fixar(_item)
	var pequena := Image.create_empty(10, 10, false, Image.FORMAT_RGBA8)
	assert_int(BaseSprites.quadros_diferentes(_item, pequena).size()).is_equal(_item.quadros())


func test_a_diferenca_marca_em_magenta_so_o_que_mudou() -> void:
	var antes := Image.create_empty(4, 4, false, Image.FORMAT_RGBA8)
	antes.fill(Color(0.5, 0.5, 0.5, 1.0))
	var depois := antes.duplicate() as Image
	depois.set_pixel(1, 1, Color(1.0, 0.0, 0.0, 1.0))
	var dif := BaseSprites.diferenca(antes, depois)
	assert_float(dif.get_pixel(1, 1).r).is_equal_approx(1.0, 0.01)
	assert_float(dif.get_pixel(1, 1).g).is_equal_approx(0.1, 0.01)
	assert_float(dif.get_pixel(1, 1).b).is_equal_approx(0.8, 0.01)
	assert_float(dif.get_pixel(2, 2).r).is_equal_approx(0.5, 0.01)


func test_limpar_apaga_a_base() -> void:
	BaseSprites.fixar(_item)
	BaseSprites.limpar(_item)
	assert_bool(BaseSprites.existe(_item)).is_false()
