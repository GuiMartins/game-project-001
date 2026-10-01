// Quantizacao com dither: o ultimo passe do mundo, e por isso o ultimo de todos.
//
// Neblina, tonemap e LUT produzem tons entre as cores da paleta; se a
// quantizacao rodasse antes deles, eles devolveriam os tons que ela acabou de
// tirar. A HUD entra DEPOIS, por cima (layer maior): ela ja e desenhada em
// cores escolhidas a mao, e passar texto pelo dither so suja o texto.
//
// O dither e Bayer 4x4 ordenado, e transforma banda em textura - a 640x360 com
// upscale de 2x ou 3x o padrao e visivel, que e a intencao. Duas regras, as
// duas armadilhas conhecidas (DIRECAO_VISUAL.md):
// - indexado pelo pixel do SubViewport (FRAGCOORD), nunca pela coordenada de
//   tela: indexado em tela, ele nao escala com o upscale e some;
// - fixo na tela, nao no mundo: dither preso ao mundo rasteja quando a camera
//   anda, o "chuvisco".
shader_type canvas_item;

uniform sampler2D tela : hint_screen_texture, filter_nearest;
// Niveis por canal. 16 sao 4 bits por canal, 4096 cores: o bastante para a
// cena ler como foto, pouco o bastante para o ceu fazer banda.
uniform float niveis : hint_range(2.0, 64.0, 1.0) = 16.0;

// A matriz de Bayer como constante, e nao uma textura de 4x4: textura de arte
// passa por importacao, compressao e mipmap, e cada um desses e uma armadilha
// que estraga o padrao sem avisar. Valores em dezesseis avos, 0 a 15.
const float BAYER[16] = float[](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0
);


void fragment() {
	vec3 cor = texture(tela, SCREEN_UV).rgb;
	ivec2 p = ivec2(FRAGCOORD.xy) % 4;
	// Limiar no meio de cada degrau: (0.5 .. 15.5) / 16.
	float limiar = (BAYER[p.y * 4 + p.x] + 0.5) / 16.0;
	float passos = niveis - 1.0;
	COLOR = vec4(floor(cor * passos + limiar) / passos, 1.0);
}
