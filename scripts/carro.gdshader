// Material dos carros: a textura de paleta de `arte/carros.py`, com troca de cor e luzes.
//
// Um material so para os cinco modelos e a frota inteira. O que muda de um
// carro para o outro vem por instancia: a pintura, a roupa e a pele de quem
// dirige, e o estado das luzes. A mascara diz onde cada coisa entra:
//
// - R: pintura da lataria.
// - G, em sextos: 1 pele, 2 camisa do motorista, 3 camisa do passageiro,
//   4 seta esquerda, 5 seta direita, 6 lanterna.
// - B: o que acende sozinho. 1 e sempre aceso (luminoso do taxi, letreiro do
//   onibus); meio e o farol, que so acende de noite.
//
// A corrida anoitece (`Relogio`): o escuro vem no global `noite`, e cada carro
// acende o farol no seu limiar - motorista nao liga o farol todo no mesmo
// segundo. De noite a lanterna tambem acende de verdade, porque a 0,5 de dia
// ela e so cor, e no escuro cor sem luz e nada.
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

// Lanterna acesa de dia, como no video de referencia, e luminoso: abaixo do
// limiar do glow (`world.gd`), so cor.
uniform float lanterna_acesa = 0.5;
uniform float sempre_aceso = 0.9;
// Freio e seta sao o aviso de que o corredor vai fechar, e sao o que brilha.
// O numero e grande porque o glow do Godot aplica o limiar DEPOIS do primeiro
// desfoque: a 30 m a lanterna tem 3 px e chega ao limiar com ~13% do que tem,
// enquanto a calcada branca ao sol (2,0, logo abaixo do limiar de 2,2) e area
// grande e nao perde nada. Com 45, a lanterna a 30 m passa; com 14, nao.
uniform float lanterna_freio = 45.0;
uniform float seta_acesa = 45.0;
// A cor da LUZ, e nao a da lente pintada na textura. Com 45 de intensidade, o
// pouco de verde da lente (0,004) vira 0,2 e a lanterna desbota para salmao;
// a luz tem de ser cor pura para continuar vermelha depois do tonemap.
uniform vec3 luz_freio = vec3(1.0, 0.004, 0.0);
uniform vec3 luz_seta = vec3(1.0, 0.3, 0.0);
// De noite. O farol bem acima do limiar do glow: e o que se ve de um carro no
// escuro antes da lataria. A lanterna acesa sobe ate perto do limiar, so o
// suficiente para ser luz - o freio (45) continua sendo o aviso, muito acima.
uniform float farol_aceso = 7.0;
uniform float lanterna_noite = 3.0;

global uniform float noite;

instance uniform vec3 pintura : source_color = vec3(0.66, 0.67, 0.70);
instance uniform vec3 pele : source_color = vec3(0.60, 0.42, 0.31);
instance uniform vec3 camisa : source_color = vec3(0.82, 0.82, 0.80);
instance uniform vec3 camisa2 : source_color = vec3(0.32, 0.46, 0.68);
// x = freio de 0 a 1, y = seta esquerda acesa, z = seta direita acesa.
instance uniform vec3 luzes = vec3(0.0);
// Quando este carro acende o farol, no escuro da hora (`Carro.FAROL_*`).
instance uniform float farol_limiar = 0.3;


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
	// A mesma rampa das luzes (`Relogio.RAMPA`): farol e cone acendem juntos.
	float acende = clamp((noite - farol_limiar) / 0.04, 0.0, 1.0);
	float brilho = m.b > 0.75 ? m.b * sempre_aceso : 0.0;
	if (m.b > 0.25 && m.b < 0.75) {
		brilho = farol_aceso * acende;
	}
	vec3 luz = vec3(0.0);
	if (degrau == 1) {
		cor = troca(cor, pele_fabrica, pele, 1.0);
	} else if (degrau == 2) {
		cor = troca(cor, camisa_fabrica, camisa, 1.0);
	} else if (degrau == 3) {
		cor = troca(cor, camisa2_fabrica, camisa2, 1.0);
	} else if (degrau == 4) {
		luz = luz_seta * luzes.y * seta_acesa;
	} else if (degrau == 5) {
		luz = luz_seta * luzes.z * seta_acesa;
	} else if (degrau == 6) {
		brilho = mix(lanterna_acesa, lanterna_noite, acende);
		luz = luz_freio * luzes.x * lanterna_freio;
	}
	ALBEDO = cor;
	ROUGHNESS = 1.0;
	EMISSION = cor * brilho + luz;
}
