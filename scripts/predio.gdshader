// Material dos predios: a textura de paleta de `arte/predios.py`, com troca de cor.
//
// Um material so para os quatro modelos e para a avenida inteira. A cor de
// cada predio vem por instancia (`set_instance_shader_parameter`), e nao por
// material: centenas de predios continuam sendo um material, um shader e uma
// textura. A mascara diz onde cada cor entra: R = pintura da parede, G = toldo
// e faixa do letreiro, B = o que acende no outdoor (1 o fundo da tela, que
// tambem leva a cor; 0,4 a foto, acesa na propria cor). O resto - vidro,
// friso, telha - fica como foi pintado.
//
// De noite (`Relogio`, global `noite`) janela e vitrine acendem. O modelo traz
// no segundo UV, por face de vidro, uma semente e o que ela e (`arte/predios.py`,
// "Luz de noite"): x a semente, y meio para janela e 1 para vitrine. A semente
// somada a posicao do predio decide se aquela janela acende, quando e em que
// tom - o mesmo modelo repetido pela avenida acende um desenho diferente em
// cada copia, e cada janela no seu momento: o predio vai acendendo.
shader_type spatial;
// Mesma luz do resto do mundo: fosco e sem especular. Vidro com reflexo de sol
// seria bonito e piscaria a cada quadro em 640x360.
render_mode specular_disabled;

// Trilinear, e nao nearest: predio e quase sempre visto de longe, com o
// caixilho e o friso menores que um pixel. Nearest escolhe um texel por pixel
// e a escolha muda a cada quadro, entao a fachada pisca em faixas verticais;
// o linear entre mipmaps media o que nao cabe no pixel. O pixel da tela segue
// vindo dos 640x360 e da quantizacao, como no asfalto (`road_track.gd`).
uniform sampler2D albedo : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D mascara : hint_default_black, filter_linear_mipmap_anisotropic;

// A cor pintada na textura em cada canal. A troca preserva o tom relativo: a
// cornija continua mais escura que a parede depois de pintada de rosa.
uniform vec3 pintura_fabrica : source_color = vec3(0.86, 0.78, 0.60);
uniform vec3 loja_fabrica : source_color = vec3(0.15, 0.35, 0.68);
uniform vec3 tela_fabrica : source_color = vec3(0.20, 0.70, 0.95);
// O quanto a tela acende. Tem de passar o limiar do glow (`world.gd`), que
// fica logo acima do mais claro que o sol faz - a calcada branca, a 2,0 -,
// para o outdoor ser o ponto mais claro abaixo do horizonte, como no video.
// Ao contrario da lanterna, ele e area grande e chega inteiro ao limiar.
uniform float tela_brilho = 4.0;
// O quanto a foto por cima da tela acende (V13a). Menos que o fundo: a 4,
// areia, pele e amarelo passavam do branco no tonemap, e a foto virava um
// painel branco estourado. A 2 ela guarda a cor, e o fundo segue sendo o que
// cruza o limiar do glow - o painel inteiro continua o mais claro da rua.
uniform float foto_brilho = 2.0;

// De noite. Vitrine quase toda acesa, que comercio de avenida fica aberto ate
// tarde, e quente. Janela de apartamento so uma parte, a maioria amarelada de
// lampada e uma ou outra azulada de televisao. As duas abaixo do limiar do
// glow: sao centenas, e com halo a fachada viraria uma nevoa.
uniform float janelas_acesas = 0.4;
uniform float vitrines_acesas = 0.85;
uniform float janela_brilho = 1.6;
uniform float vitrine_brilho = 1.2;
uniform vec3 luz_quente : source_color = vec3(1.0, 0.78, 0.48);
uniform vec3 luz_fria : source_color = vec3(0.7, 0.82, 1.0);
uniform vec3 luz_loja : source_color = vec3(1.0, 0.88, 0.66);

global uniform float noite;

instance uniform vec3 pintura : source_color = vec3(0.86, 0.78, 0.60);
instance uniform vec3 loja : source_color = vec3(0.15, 0.35, 0.68);
instance uniform vec3 tela : source_color = vec3(0.20, 0.70, 0.95);


float sorteio(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}


// A luz de noite desta face: zero se ela nao acende (ou ainda nao).
vec3 luz_da_noite(vec2 luz, vec3 predio) {
	if (noite <= 0.0 || luz.y < 0.25) {
		return vec3(0.0);
	}
	float semente = fract(luz.x + sorteio(predio.xz));
	bool vitrine = luz.y > 0.75;
	if (semente >= (vitrine ? vitrines_acesas : janelas_acesas)) {
		return vec3(0.0);
	}
	// Quando acende: a vitrine no comeco do escuro, a janela espalhada pela
	// hora azul inteira e pela noite adentro.
	float quando = fract(semente * 13.37);
	float limiar = vitrine ? mix(0.15, 0.45, quando) : mix(0.25, 0.9, quando);
	// A mesma rampa das luzes (`Relogio.RAMPA`).
	float acende = clamp((noite - limiar) / 0.04, 0.0, 1.0);
	if (vitrine) {
		return luz_loja * vitrine_brilho * acende;
	}
	vec3 tom = fract(semente * 31.7) < 0.15 ? luz_fria : luz_quente;
	// Nem toda lampada e igual: umas mais fortes que as outras.
	return tom * janela_brilho * (0.6 + 0.4 * fract(semente * 7.1)) * acende;
}


float luminancia(vec3 cor) {
	return dot(cor, vec3(0.2126, 0.7152, 0.0722));
}


vec3 troca(vec3 cor, vec3 fabrica, vec3 nova, float peso) {
	vec3 tingida = nova * (luminancia(cor) / max(luminancia(fabrica), 0.0001));
	return mix(cor, tingida, peso);
}


// A lona do andaime (V17a): o modelo marca as faces dela com a semente da luz
// acima de 1 (`arte/predios.py`, `LONA_MARCA`). Metade dos pixels some, em
// xadrez, e o resto fica: tela de protecao deixa ver o andaime e o concreto
// por tras. Furo em vez de alpha porque o mundo e opaco e dithered - nada aqui
// ordena transparencia - e porque o xadrez de um pixel de 640x360 e a mesma
// trama que a paleta ja usa. De perto o xadrez anda com a camera; de longe o
// mip e a quantizacao fecham ele numa cor so, e e assim que lona lê.
void fragment() {
	if (UV2.x > 1.5) {
		ivec2 px = ivec2(FRAGCOORD.xy);
		if (((px.x + px.y) & 1) == 0) {
			discard;
		}
	}
	vec3 cor = texture(albedo, UV).rgb;
	vec3 m = texture(mascara, UV).rgb;
	cor = troca(cor, pintura_fabrica, pintura, m.r);
	cor = troca(cor, loja_fabrica, loja, m.g);
	// Rampa, e nao degrau: o mip de longe mistura a tela com a celula ao
	// lado, e o degrau acenderia a mistura num pixel e apagaria no outro.
	cor = troca(cor, tela_fabrica, tela, smoothstep(0.5, 1.0, m.b));
	ALBEDO = cor;
	ROUGHNESS = 1.0;
	float brilho = mix(foto_brilho, tela_brilho, smoothstep(0.5, 1.0, m.b));
	EMISSION = cor * smoothstep(0.0, 0.4, m.b) * brilho + luz_da_noite(UV2, NODE_POSITION_WORLD);
}
