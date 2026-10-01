// Material dos predios: a textura de paleta de `arte/predios.py`, com troca de cor.
//
// Um material so para os quatro modelos e para a avenida inteira. A cor de
// cada predio vem por instancia (`set_instance_shader_parameter`), e nao por
// material: centenas de predios continuam sendo um material, um shader e uma
// textura. A mascara diz onde cada cor entra: R = pintura da parede, G = toldo
// e faixa do letreiro. O resto - vidro, friso, telha, mural - fica como foi
// pintado.
shader_type spatial;
// Mesma luz do resto do mundo: fosco e sem especular. Vidro com reflexo de sol
// seria bonito e piscaria a cada quadro em 640x360.
render_mode specular_disabled;

uniform sampler2D albedo : source_color, filter_nearest_mipmap;
uniform sampler2D mascara : hint_default_black, filter_nearest_mipmap;

// A cor pintada na textura em cada canal. A troca preserva o tom relativo: a
// cornija continua mais escura que a parede depois de pintada de rosa.
uniform vec3 pintura_fabrica : source_color = vec3(0.86, 0.78, 0.60);
uniform vec3 loja_fabrica : source_color = vec3(0.15, 0.35, 0.68);

instance uniform vec3 pintura : source_color = vec3(0.86, 0.78, 0.60);
instance uniform vec3 loja : source_color = vec3(0.15, 0.35, 0.68);


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
	ALBEDO = cor;
	ROUGHNESS = 1.0;
}
