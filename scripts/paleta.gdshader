// Quantizacao com dither: o ultimo passe do mundo, e por isso o ultimo de todos.
//
// Neblina, tonemap e LUT produzem tons entre as cores da paleta; se a
// quantizacao rodasse antes deles, eles devolveriam os tons que ela acabou de
// tirar. A HUD entra DEPOIS, por cima (layer maior): ela ja e desenhada em
// cores escolhidas a mao, e passar texto pelo dither so suja o texto.
//
// O dither transforma banda em textura - a 640x360 com upscale de 2x ou 3x o
// padrao e visivel, que e a intencao. Desde a V03a ele e ruido em celula de
// 2 px (o "tufo" das paradas de referencia, nao a grade de Bayer) e so mora
// no gradiente suave: ceu, nuvem, neblina e asfalto borrado; fachada fica
// lisa. Duas regras, as duas armadilhas conhecidas (DIRECAO_VISUAL.md):
// - indexado pelo pixel do SubViewport (FRAGCOORD), nunca pela coordenada de
//   tela: indexado em tela, ele nao escala com o upscale e some;
// - fixo na tela, nao no mundo: dither preso ao mundo rasteja quando a camera
//   anda, o "chuvisco".
shader_type canvas_item;

uniform sampler2D tela : hint_screen_texture, filter_nearest;
// Niveis por canal. 16 sao 4 bits por canal, 4096 cores: o bastante para a
// cena ler como foto, pouco o bastante para o ceu fazer banda.
uniform float niveis : hint_range(2.0, 64.0, 1.0) = 16.0;
// Amplitude do dither: 1 e o Bayer inteiro, 0 e arredondamento seco (banda
// sem textura). Existe para a V03 do backlog visual pesar o quanto de padrao
// a tela aguenta sem mexer na quantidade de cores.
uniform float forca : hint_range(0.0, 1.0) = 1.0;
// Quanto a trama depende do que ha em volta (V03a). Nas paradas de
// referencia a trama mora no ceu, na nuvem e no asfalto borrado, e a fachada
// e lisa: o dither existe para quebrar banda, e so gradiente suave faz banda.
// Parede chapada nao tem banda para quebrar (nela o Bayer so desenha
// reticula), e superficie com detalhe - janela, cornija, piloto - ja esconde a
// banda sozinha. 0 e o Bayer por igual; 1 deixa a trama so no gradiente suave.
uniform float so_no_gradiente : hint_range(0.0, 1.0) = 1.0;
// Variacao de cor, em degraus da paleta ao longo de `RAIO` pixels, a partir
// da qual o gradiente conta inteiro. Um quarto de degrau ja e o ceu fazendo
// banda; abaixo disso e parede chapada.
uniform float degraus_cheios : hint_range(0.05, 2.0) = 0.25;
// Detalhe (laplaciano em `RAIO` pixels, em degraus) a partir do qual a
// superficie ja e textura e dispensa trama. A curva da luz no ceu mal sai do
// zero; uma janela a menos de `RAIO` pixels passa de um degrau.
uniform float detalhe_maximo : hint_range(0.1, 4.0) = 1.0;
// Lado da celula do dither em pixels do SubViewport. As paradas tem a trama
// 2-3x mais grossa que o pixel da cena; celula de 2 engrossa so a trama, sem
// baixar a resolucao de quem tem detalhe (fachada, piloto).
uniform int celula : hint_range(1, 4) = 2;
// 0 e a grade de Bayer; 1 e ruido por celula, o "tufo" das paradas. Os dois
// ficam presos a tela, nunca ao mundo.
uniform float tufo : hint_range(0.0, 1.0) = 1.0;

// A matriz de Bayer como constante, e nao uma textura de 4x4: textura de arte
// passa por importacao, compressao e mipmap, e cada um desses e uma armadilha
// que estraga o padrao sem avisar. Valores em dezesseis avos, 0 a 15.
const float BAYER[16] = float[](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0
);
// Distancia, em pixels, em que se medem gradiente e detalhe. Um pixel so
// enxerga o degrau da propria banda, e no meio da banda le parede chapada;
// quatro abrangem a largura de uma banda do ceu em 640x360, e a trama cobre o
// gradiente inteiro. Pela mesma razao, o meio de uma janela de fachada ainda
// ve a aresta dela.
const float RAIO = 4.0;


float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}


// Hash inteiro barato, sem textura pelo mesmo motivo do Bayer. Sai em [0, 1).
float hash(ivec2 p) {
	uint h = uint(p.x) * 374761393u + uint(p.y) * 668265263u;
	h = (h ^ (h >> 13u)) * 1274126177u;
	return float(h ^ (h >> 16u)) / 4294967296.0;
}


void fragment() {
	vec3 cor = texture(tela, SCREEN_UV).rgb;
	ivec2 c = ivec2(FRAGCOORD.xy) / celula;
	float bayer = (BAYER[(c.y % 4) * 4 + c.x % 4] + 0.5) / 16.0;
	float limiar01 = mix(bayer, hash(c), tufo);
	float passos = niveis - 1.0;

	float peso = 1.0;
	if (so_no_gradiente > 0.0) {
		vec2 r = RAIO * SCREEN_PIXEL_SIZE;
		float direita = luma(texture(tela, SCREEN_UV + vec2(r.x, 0.0)).rgb);
		float esquerda = luma(texture(tela, SCREEN_UV - vec2(r.x, 0.0)).rgb);
		float baixo = luma(texture(tela, SCREEN_UV + vec2(0.0, r.y)).rgb);
		float cima = luma(texture(tela, SCREEN_UV - vec2(0.0, r.y)).rgb);
		// Primeira derivada: o quanto a cor anda. Segunda: o quanto ela
		// dobra. Gradiente de ceu anda e nao dobra; janela dobra.
		float gradiente = length(vec2(direita - esquerda, baixo - cima)) * passos;
		float detalhe = abs(direita + esquerda + baixo + cima - 4.0 * luma(cor)) * passos;
		float suave = smoothstep(0.0, degraus_cheios, gradiente)
			* (1.0 - smoothstep(0.5 * detalhe_maximo, detalhe_maximo, detalhe));
		peso = mix(1.0, suave, so_no_gradiente);
	}

	// Limiar no meio de cada degrau: (0.5 .. 15.5) / 16.
	float limiar = 0.5 + (limiar01 - 0.5) * forca * peso;
	COLOR = vec4(floor(cor * passos + limiar) / passos, 1.0);
}
