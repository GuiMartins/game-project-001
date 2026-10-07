// O vidro dos carros: escuro de frente, espelho de raspao.
//
// E o que deixa ver o motorista e, ao mesmo tempo, ler o vidro como vidro, e
// nao como buraco. Duas coisas fazem isso, e nenhuma e reflexo de verdade:
//
// - Fresnel. Olhando de frente o vidro e transparente e escuro; quanto mais de
//   lado, mais opaco e mais claro. E por isso que o para-brisa visto de tras,
//   em angulo, le como uma placa clara, e a janela lateral do carro emparelhado
//   deixa ver quem dirige.
// - Um ceu falso: o reflexo e um degrade entre o asfalto e o ceu pela direcao
//   refletida. Vidro de cima pega o ceu, vidro de lado pega a rua.
//
// O reflexo sai pela emissao e nao pelo albedo: reflexo nao escurece na
// sombra do proprio carro, e um vidro apagado na sombra le como janela aberta.
shader_type spatial;
// Os dois lados: pela janela do motorista se ve o vidro do outro lado, e ele
// tambem e vidro.
render_mode blend_mix, cull_disabled, specular_disabled, depth_draw_never;

uniform vec3 tinta : source_color = vec3(0.07, 0.09, 0.11);
uniform vec3 ceu : source_color = vec3(0.62, 0.74, 0.88);
uniform vec3 horizonte : source_color = vec3(0.86, 0.88, 0.90);
uniform vec3 chao : source_color = vec3(0.16, 0.16, 0.17);
// Opacidade de frente e de raspao. 0,45 de frente e o insulfilm da frota
// brasileira: da para ver gente, nao da para ver rosto.
uniform float opacidade_frente = 0.45;
uniform float opacidade_raspao = 0.92;
uniform float reflexo = 0.55;


void fragment() {
	float de_frente = clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	float fresnel = pow(1.0 - de_frente, 3.0);
	vec3 refletido = (INV_VIEW_MATRIX * vec4(reflect(-VIEW, NORMAL), 0.0)).xyz;
	vec3 ambiente = mix(chao, horizonte, smoothstep(-0.25, 0.0, refletido.y));
	ambiente = mix(ambiente, ceu, smoothstep(0.05, 0.5, refletido.y));
	ALBEDO = tinta;
	ROUGHNESS = 1.0;
	EMISSION = ambiente * reflexo * (0.25 + 0.75 * fresnel);
	ALPHA = mix(opacidade_frente, opacidade_raspao, fresnel);
}
