// Material do entregador: a textura de paleta do modelo, com troca de cor.
//
// Um material so, para o jogador e para os rivais. A mascara diz onde cada cor
// nova entra (R = bag, G = jaqueta, B = pintura da moto); o resto do modelo
// fica com a cor pintada na textura. E o plano de arte que o world.gd declara
// desde o greybox: mesmo modelo, paleta trocada.
shader_type spatial;
// Mesma luz das caixas do greybox (Greybox.material): fosco e sem especular.
// Um ator com reflexo num mundo de caixas foscas le como recortado e colado.
render_mode specular_disabled;

uniform sampler2D albedo : source_color, filter_nearest_mipmap;
uniform sampler2D mascara : hint_default_black, filter_nearest_mipmap;

// A cor que a textura tem pintada em cada canal. A troca preserva o tom
// relativo: a tampa da bag e mais escura que a bag, e continua mais escura
// quando a bag do rival e verde.
uniform vec3 bag_fabrica : source_color = vec3(0.95, 0.42, 0.15);
uniform vec3 jaqueta_fabrica : source_color = vec3(0.20, 0.25, 0.34);
uniform vec3 moto_fabrica : source_color = vec3(0.70, 0.11, 0.09);

uniform vec3 bag : source_color = vec3(0.95, 0.42, 0.15);
uniform vec3 jaqueta : source_color = vec3(0.20, 0.25, 0.34);
uniform vec3 moto : source_color = vec3(0.70, 0.11, 0.09);


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
	cor = troca(cor, bag_fabrica, bag, m.r);
	cor = troca(cor, jaqueta_fabrica, jaqueta, m.g);
	cor = troca(cor, moto_fabrica, moto, m.b);
	ALBEDO = cor;
	ROUGHNESS = 1.0;
}
