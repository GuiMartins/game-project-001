// Distorcao de barril da lente ultra-angular da GARUPA (V26): a curva que o
// poste faz na borda de uma 0,5x de celular, e que FOV alto de jogo nao faz
// (FOV alto estica a borda, nao curva).
//
// Roda antes do `paleta.gdshader`, no mesmo SubViewport de 640x360: reamostra
// a imagem com a quantizacao ainda por vir, para o dither cair sobre o pixel
// ja distorcido e nao ser distorcido junto. Por isso a leitura e linear: com
// nearest, a distorcao vira pixel de tamanho irregular (uma coluna repetida,
// outra pulada), e a quantizacao seguinte nao conserta isso.
//
// Conta: r_fonte = r * (1 + k r^2) / (1 + k), com r = 1 no canto. Canto parado,
// centro ampliado em (1 + k), retas curvando para fora. `k` e a unica
// pergunta; 0 devolve a imagem como esta.
shader_type canvas_item;

uniform sampler2D tela : hint_screen_texture, filter_linear, repeat_disable;
// A referencia pede entre 0,10 e 0,20 (REFERENCIA_CAMERA_GARUPA.md).
uniform float k : hint_range(0.0, 0.5, 0.01) = 0.15;

void fragment() {
	// Isotropico: o raio e medido em unidades de altura, para o barril ser
	// redondo e nao oval. r = 1 no canto da tela.
	vec2 aspecto = vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	vec2 c = (SCREEN_UV - 0.5) * 2.0 * aspecto;
	float r2 = dot(c, c) / dot(aspecto, aspecto);
	vec2 fonte = c * (1.0 + k * r2) / (1.0 + k);
	COLOR = vec4(texture(tela, fonte / aspecto * 0.5 + 0.5).rgb, 1.0);
}
