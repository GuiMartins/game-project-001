// Material do entregador: a textura de paleta do modelo, com troca de cor.
//
// Um material so, para o jogador e para os rivais. A mascara diz onde cada cor
// nova entra (R = bag, G = camiseta, B = pintura da moto); o resto do modelo
// fica com a cor pintada na textura. E o plano de arte que o world.gd declara
// desde o greybox: mesmo modelo, paleta trocada.
//
// De noite (`Relogio`, global `noite`) farol e lanterna acendem. Nao ha canal
// livre na mascara para dizer onde eles estao, entao o shader os acha pela
// cor pintada: o branco-palha do farol e o vermelho da lanterna sao celulas
// unicas da paleta, e fora da mascara (o vermelho da bag e o da moto tem
// mascara, e por isso nao acendem). O `test_entregador.gd` confere que as
// duas cores existem na textura - paleta que mudar sem mudar aqui reprova.
shader_type spatial;
// Mesma luz das caixas do greybox (Greybox.material): fosco e sem especular.
// Um ator com reflexo num mundo de caixas foscas le como recortado e colado.
render_mode specular_disabled;

uniform sampler2D albedo : source_color, filter_nearest_mipmap;
uniform sampler2D mascara : hint_default_black, filter_nearest_mipmap;

// A cor que a textura tem pintada em cada canal. A troca preserva o tom
// relativo: a tampa da bag e mais escura que a bag, e continua mais escura
// quando a bag do rival e verde.
uniform vec3 bag_fabrica : source_color = vec3(0.82, 0.12, 0.10);
uniform vec3 camisa_fabrica : source_color = vec3(0.74, 0.11, 0.09);
uniform vec3 moto_fabrica : source_color = vec3(0.70, 0.11, 0.09);

uniform vec3 bag : source_color = vec3(0.82, 0.12, 0.10);
uniform vec3 camisa : source_color = vec3(0.74, 0.11, 0.09);
uniform vec3 moto : source_color = vec3(0.70, 0.11, 0.09);

// As celulas que acendem (`arte/entregador.py`).
uniform vec3 farol_fabrica : source_color = vec3(0.98, 0.96, 0.82);
uniform vec3 lanterna_fabrica : source_color = vec3(0.85, 0.08, 0.06);
// Os mesmos numeros do carro (`carro.gdshader`): farol acima do glow, lanterna
// logo abaixo, e o freio muito acima - e o aviso.
uniform float farol_aceso = 7.0;
uniform float lanterna_noite = 3.0;
uniform float lanterna_freio = 45.0;
uniform vec3 luz_freio = vec3(1.0, 0.004, 0.0);
// Quando esta moto acende, e o freio de agora (0 a 1). Uniforme comum, e nao
// por instancia: cada ator ja tem o seu material, por causa da cor.
uniform float farol_limiar = 0.1;
uniform float freio = 0.0;

global uniform float noite;


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
	vec3 emissao = vec3(0.0);
	if (noite > farol_limiar && max(m.r, max(m.g, m.b)) < 0.05) {
		float acende = clamp((noite - farol_limiar) / 0.04, 0.0, 1.0);
		if (distance(cor, farol_fabrica) < 0.03) {
			emissao = cor * farol_aceso * acende;
		} else if (distance(cor, lanterna_fabrica) < 0.03) {
			// O freio so de noite: de dia a lanterna da moto nunca acendeu, e
			// ensinar o freio de dia e outra conversa, fora da noite.
			emissao = (cor * lanterna_noite + luz_freio * freio * lanterna_freio) * acende;
		}
	}
	cor = troca(cor, bag_fabrica, bag, m.r);
	cor = troca(cor, camisa_fabrica, camisa, m.g);
	cor = troca(cor, moto_fabrica, moto, m.b);
	ALBEDO = cor;
	ROUGHNESS = 1.0;
	EMISSION = emissao;
}
