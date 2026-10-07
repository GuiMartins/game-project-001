// Material dos carros: a textura de paleta de `arte/carros.py`, com troca de cor e luzes.
//
// Um material so para os cinco modelos e a frota inteira. O que muda de um
// carro para o outro vem por instancia: a pintura, a roupa e a pele de quem
// dirige, e o estado das luzes. A mascara diz onde cada coisa entra:
//
// - R: pintura da lataria.
// - G, em sextos: 1 pele, 2 camisa do motorista, 3 camisa do passageiro,
//   4 seta esquerda, 5 seta direita, 6 lanterna.
// - B: sempre aceso (luminoso do taxi, letreiro do onibus).
shader_type spatial;
// Mesma luz do resto do mundo: fosco e sem especular. Lataria com reflexo de
// sol piscaria a cada quadro em 640x360, e o brilho que conta - lanterna e
// seta - vem da emissao.
render_mode specular_disabled;

uniform sampler2D albedo : source_color, filter_nearest_mipmap;
uniform sampler2D mascara : hint_default_black, filter_nearest_mipmap;

// A cor pintada na textura em cada canal. A troca preserva o tom relativo: a
// soleira continua mais escura que a porta depois de pintada de vermelho.
uniform vec3 pintura_fabrica : source_color = vec3(0.66, 0.67, 0.70);
uniform vec3 pele_fabrica : source_color = vec3(0.60, 0.42, 0.31);
uniform vec3 camisa_fabrica : source_color = vec3(0.82, 0.82, 0.80);
uniform vec3 camisa2_fabrica : source_color = vec3(0.32, 0.46, 0.68);

// Lanterna acesa de dia, como no video de referencia, e o quanto ela sobe na
// freada. Seta e luminoso nao tem meio-termo: ou acendem, ou nao.
uniform float lanterna_acesa = 0.5;
uniform float lanterna_freio = 2.6;
uniform float seta_acesa = 2.4;
uniform float sempre_aceso = 0.9;

instance uniform vec3 pintura : source_color = vec3(0.66, 0.67, 0.70);
instance uniform vec3 pele : source_color = vec3(0.60, 0.42, 0.31);
instance uniform vec3 camisa : source_color = vec3(0.82, 0.82, 0.80);
instance uniform vec3 camisa2 : source_color = vec3(0.32, 0.46, 0.68);
// x = freio de 0 a 1, y = seta esquerda acesa, z = seta direita acesa.
instance uniform vec3 luzes = vec3(0.0);


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
	int degrau = int(round(m.g * 6.0));
	float brilho = m.b * sempre_aceso;
	if (degrau == 1) {
		cor = troca(cor, pele_fabrica, pele, 1.0);
	} else if (degrau == 2) {
		cor = troca(cor, camisa_fabrica, camisa, 1.0);
	} else if (degrau == 3) {
		cor = troca(cor, camisa2_fabrica, camisa2, 1.0);
	} else if (degrau == 4) {
		brilho = luzes.y * seta_acesa;
	} else if (degrau == 5) {
		brilho = luzes.z * seta_acesa;
	} else if (degrau == 6) {
		brilho = lanterna_acesa + luzes.x * lanterna_freio;
	}
	ALBEDO = cor;
	ROUGHNESS = 1.0;
	EMISSION = cor * brilho;
}
