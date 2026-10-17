// Borrao radial de velocidade (V08 do backlog visual).
//
// Um quad que cobre a tela, preso a camera, no passe transparente do 3D. Nao
// e o `ColorRect` que a DIRECAO_VISUAL.md previa: shader `canvas_item` nao le
// profundidade no Godot 4.7 ("hint_depth_texture is not supported in
// canvas_item shaders"), e sem profundidade nao ha mascara. O preco e a ordem:
// o borrao le a cena ja com neblina, mas roda ANTES de glow, tonemap e LUT, e
// nao depois. Para borrao isso e o certo - mistura luz em HDR linear, como a
// lente - e a paleta (`paleta.gdshader`) continua sendo o ultimo passe.
//
// O tamanho do risco e o do movimento de verdade, de camera andando para a
// frente: um ponto parado no mundo foge do ponto de fuga tanto mais rapido
// quanto mais longe dele esta na tela e quanto mais perto da camera esta. Por
// isso o asfalto rasante e o carro colado viram risco e o carro a 20 m nao.
// O piloto anda junto com a camera e nao se move na tela: fica de fora pelo
// stencil que o `foco.gdshader` grava nele.
shader_type spatial;
render_mode unshaded, fog_disabled, shadows_disabled, depth_test_disabled, depth_draw_never, cull_disabled;
stencil_mode read, compare_not_equal, 1;

// Amostras ao longo do risco. 10 a 640x360: o risco mais longo (`maximo`) tem
// ~90 px, 9 px entre amostras; com mais espaco que isso o risco vira copias
// separadas do mesmo carro. Sem sorteio entre amostras de proposito: ruido
// que muda a cada quadro e cintilacao, o modo de falha que a tela inteira
// evita (DIRECAO_VISUAL.md).
const int AMOSTRAS = 10;

uniform sampler2D tela : hint_screen_texture, filter_linear, repeat_disable;
uniform sampler2D profundidade : hint_depth_texture, filter_nearest, repeat_disable;

// Quanto borra, ja com a velocidade dentro: 0 parado, e passa do valor de
// velocidade maxima no boost. E o comprimento do risco, em fracao da tela,
// de um ponto colado na camera a uma tela inteira do ponto de fuga.
uniform float forca = 0.0;
// Onde a moto vai na tela (UV): o ponto de fuga do movimento. Nao e o centro
// da tela - a camera olha um pouco para baixo, e na curva a moto nao vai para
// onde a lente aponta.
uniform vec2 fuga = vec2(0.5, 0.45);
// Ate quantos metros da camera o borrao vale inteiro. O piloto fica a ~4,5 m
// (`cam_distance`), e o asfalto ao lado da roda e o carro do corredor tambem.
uniform float perto = 5.0;
// O que sobra de borrao no infinito, em fracao do inteiro. A conta pura
// (1/distancia) zera a fachada a 30 m, e nas referencias a periferia inteira
// borra: o borrao e pintado, nao fotografado (DIRECAO_VISUAL.md).
uniform float longe = 0.15;
// O risco mais comprido, em fracao da tela. Sem teto, o canto de baixo a 1 m
// da camera borraria a tela inteira por cima dele. Era 0,1; com o reforco do
// `chao` o pe da tela batia nele ja em cruzeiro e a zebra continuava inteira.
// A 0,14 o risco tem ~90 px, e as 10 amostras ficam a 9 px uma da outra.
uniform float maximo = 0.14;
// Quanto o chao abaixo do ponto de fuga borra a mais, no pe da tela (V08a). A
// 2 o asfalto riscava e a zebra nao; a 3 a zebra risca como no `t3.0s`.
// Nas referencias o terco de baixo do asfalto e todo risco, e a conta do
// movimento nao chega la sozinha: o chao debaixo da moto esta a ~6 m da
// camera, alem do `perto`, e pesa so ~0,7. Cresce do ponto de fuga para baixo,
// entao fachada e ceu nao mudam, e o piloto continua fora pelo stencil.
uniform float chao = 3.0;


void vertex() {
	// Cobre a tela inteira direto no espaco de recorte, qualquer que seja a
	// lente ou o tamanho do quad.
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}


float distancia(vec2 uv, mat4 inv_projecao) {
	float d = texture(profundidade, uv).r;
	vec4 visto = inv_projecao * vec4(uv * 2.0 - 1.0, d, 1.0);
	return -visto.z / visto.w;
}


void fragment() {
	vec2 uv = SCREEN_UV;
	float z = distancia(uv, INV_PROJECTION_MATRIX);
	float perto_ate = clamp(perto / max(z, 0.001), 0.0, 1.0);
	float peso = mix(longe, 1.0, perto_ate * perto_ate);
	peso *= mix(1.0, chao, smoothstep(fuga.y, 1.0, uv.y));
	vec2 raio = uv - fuga;
	float comprimento = min(forca * peso * length(raio), maximo);
	// O risco vai do pixel para o ponto de fuga: o que esta aqui agora veio de
	// la, porque tudo foge dele.
	vec2 passo = -normalize(raio + vec2(1e-6)) * comprimento / float(AMOSTRAS);
	vec3 soma = vec3(0.0);
	for (int i = 0; i < AMOSTRAS; i++) {
		soma += texture(tela, uv + passo * float(i)).rgb;
	}
	ALBEDO = soma / float(AMOSTRAS);
}
