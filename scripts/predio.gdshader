// Material dos predios: a textura de paleta de `arte/predios.py`, com troca de cor.
//
// Um material so para os quatro modelos e para a avenida inteira. A cor de
// cada predio vem por instancia (`set_instance_shader_parameter`), e nao por
// material: centenas de predios continuam sendo um material, um shader e uma
// textura. A mascara diz onde cada cor entra: R = pintura da parede, G = toldo
// e faixa do letreiro, B = o que acende no outdoor (1 o fundo da tela, que
// tambem leva a cor; 0,4 a foto, acesa na propria cor). O resto - vidro,
// friso, telha - fica como foi pintado.
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

instance uniform vec3 pintura : source_color = vec3(0.86, 0.78, 0.60);
instance uniform vec3 loja : source_color = vec3(0.15, 0.35, 0.68);
instance uniform vec3 tela : source_color = vec3(0.20, 0.70, 0.95);


float luminancia(vec3 cor) {
	return dot(cor, vec3(0.2126, 0.7152, 0.0722));
}


vec3 troca(vec3 cor, vec3 fabrica, vec3 nova, float peso) {
	vec3 tingida = nova * (luminancia(cor) / max(luminancia(fabrica), 0.0001));
	return mix(cor, tingida, peso);
}


void fragment() {
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
	EMISSION = cor * smoothstep(0.0, 0.4, m.b) * brilho;
}
