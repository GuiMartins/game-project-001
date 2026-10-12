// A marca do piloto que a camera segue: o borrao (`borrao.gdshader`) nao
// passa onde ela esta.
//
// E um `material_overlay`: redesenha a mesma malha sem mexer na cor (soma
// zero) e grava 1 no stencil onde o piloto aparece. Overlay, e nao uma
// variante do shader do entregador, porque assim marca qualquer malha do ator
// - a do modelo, o disco da `RodaLisa`, peca que alguem acrescentar - sem
// cada material precisar saber que o borrao existe.
//
// Por que stencil, e nao profundidade: o piloto e a coisa mais perto da
// camera, junto com o asfalto em volta da roda e o carro colado. Pela
// profundidade os tres sao iguais, e so o piloto tem de ficar nitido.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, shadows_disabled, fog_disabled;
stencil_mode write, compare_always, 1;


void fragment() {
	ALBEDO = vec3(0.0);
}
