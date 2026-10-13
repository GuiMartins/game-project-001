// O ceu: gradiente de meio-dia e um campo de tufos de nuvem, andando devagar
// com o vento.
//
// Na comparacao da V14 (textura com trama, lisa, esparsa, ruido e objeto no
// mundo) ganhou a nuvem feita no shader. A forma veio das referencias, depois
// de duas erradas (ruido recortado era "poca de leite"; cumulo grande de domo
// arrumado nao e o que elas tem):
// - muitos tufos pequenos em grupos irregulares, com azul entre os grupos;
// - o ceu inteiro, menores e mais juntos perto do horizonte;
// - cada tufo com o pe cortado reto e o alto em calombo;
// - dois ou tres tons, topo branco e baixo azulado;
// - a borda se desfaz em pixel solto, nem recorte liso nem degrade.
//
// A perspectiva vem de projetar a direcao do olhar num "teto" de nuvem: perto
// do horizonte o mesmo tufo fica longe, menor e achatado. Projecao plana pura
// (1/tan) achata demais; o expoente `perspectiva` dosa.
//
// O gradiente e o mesmo do ProceduralSkyMaterial de antes - mesmas cores,
// mesma curva de 0,15 -, para a luz ambiente, que vem do ceu, nao mudar.
// Os numeros sao sliders do F3 (`WorldTuning`, grupo Ceu), e o `world.gd`
// repassa. Os defaults daqui so valem ate o primeiro quadro.
shader_type sky;

uniform vec3 topo : source_color = vec3(0.16, 0.38, 0.82);
uniform vec3 horizonte : source_color = vec3(0.62, 0.74, 0.88);
uniform vec3 chao_horizonte : source_color = vec3(0.55, 0.6, 0.62);
uniform vec3 chao_fundo : source_color = vec3(0.24, 0.26, 0.25);

uniform float altura_min = 4.0;
uniform float cobertura = 0.5;
uniform float tufo = 4.0;
uniform float grupo = 6.0;
uniform float perspectiva = 0.35;
uniform float detalhe = 0.6;
uniform float trama = 0.5;
uniform float sombra = 0.5;
uniform float brilho = 1.1;
uniform float faixas_de_tom = 3.0;
uniform float vento = 0.15;

// A matriz de Bayer do `paleta.gdshader`, pela mesma razao de ser constante.
const float BAYER[16] = float[](
	0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0
);

vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash2(i).x, hash2(i + vec2(1.0, 0.0)).x, u.x),
		mix(hash2(i + vec2(0.0, 1.0)).x, hash2(i + vec2(1.0, 1.0)).x, u.x),
		u.y
	);
}

// Onde ha grupo de nuvem: ruido de baixa frequencia, em unidades de tufo.
float mascara(vec2 q) {
	vec2 p = q / grupo;
	return ruido(p) * 0.65 + ruido(p * 2.3 + 5.1) * 0.35;
}

// Uma oitava de tufos: um circulo por celula, so onde a mascara deixa, com o pe
// cortado reto. `fora` e a direcao do horizonte no plano (o "para baixo" da
// tela). Devolve (densidade 0-1, tom 0-1); densidade 0 e fora.
vec2 tufos(vec2 q, float escala, float semente, vec2 fora, float limiar) {
	vec2 qs = q * escala;
	vec2 cel = floor(qs);
	vec2 melhor = vec2(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 c = cel + vec2(float(x), float(y));
			vec2 h = hash2(c + semente);
			vec2 centro = c + 0.15 + 0.7 * h;
			float m = mascara(centro / escala);
			if (m < limiar) {
				continue;
			}
			// Na borda do grupo o tufo encolhe: e o que faz o grupo terminar em
			// tufo pequeno, e nao numa parede.
			float r =
				(0.45 + 0.35 * hash2(c + semente + 7.7).x) * smoothstep(limiar, limiar + 0.12, m);
			vec2 d = qs - centro;
			float dist = length(d);
			// Quanto o ponto esta abaixo do centro, para o lado do horizonte.
			float baixo = dot(d, fora);
			if (dist < r && baixo < r * 0.3) {
				float dens = 1.0 - dist / r;
				if (dens > melhor.x) {
					melhor = vec2(dens, clamp(0.55 - baixo / r * 0.7, 0.0, 1.0));
				}
			}
		}
	}
	return melhor;
}

void sky() {
	vec3 dir = EYEDIR;
	float elev = degrees(asin(clamp(dir.y, -1.0, 1.0)));
	float c = clamp(elev / 90.0, 0.0, 1.0);
	vec3 cor = mix(horizonte, topo, clamp(1.0 - pow(1.0 - c, 1.0 / 0.15), 0.0, 1.0));
	if (elev < 0.0) {
		float g = clamp(-elev / 90.0, 0.0, 1.0);
		cor = mix(chao_horizonte, chao_fundo, clamp(1.0 - pow(1.0 - g, 1.0 / 0.02), 0.0, 1.0));
	} else if (elev > altura_min * 0.5) {
		// O vento gira o ceu em volta do eixo vertical.
		float giro = radians(TIME * vento);
		vec2 h = vec2(dir.x * cos(giro) - dir.z * sin(giro), dir.x * sin(giro) + dir.z * cos(giro));
		vec2 fora = normalize(h + vec2(1e-6));
		float t_e = max(tan(radians(elev)), 1e-3);
		// O ponto no teto de nuvem. Normalizado para que, a 15 graus, um tufo
		// meca `tufo` graus.
		float ref = tan(radians(15.0));
		float escala_ref = cos(radians(15.0)) / pow(ref, -perspectiva) * 57.3 / tufo;
		vec2 q = fora * pow(t_e, -perspectiva) * escala_ref;
		// Cobertura 0 e ceu limpo, 1 e quase fechado; a mascara mora em ~0,2-0,8.
		float limiar = mix(0.75, 0.3, cobertura);
		// Perto do chao as nuvens rareiam: o horizonte e neblina, nao parede.
		limiar += (1.0 - smoothstep(altura_min, altura_min + 4.0, elev)) * 0.5;
		vec2 grande = tufos(q, 1.0, 0.0, fora, limiar);
		vec2 miudo = detalhe > 0.0 ? tufos(q, 2.3, 31.7, fora, limiar + 0.05) : vec2(0.0);
		miudo.x *= detalhe;
		vec2 hit = grande.x >= miudo.x ? grande : miudo;
		if (hit.x > 0.0) {
			// A borda: numa faixa estreita do contorno, o pixel some pelo Bayer
			// da tela. Preso a tela, e nao ao ceu, para nao rastejar quando a
			// camera gira. No mapa de luz ambiente nao ha tela, e la a borda e
			// cheia.
			bool cheio = true;
			if (!AT_CUBEMAP_PASS && trama > 0.0) {
				ivec2 px = ivec2(FRAGCOORD.xy) % 4;
				float limiar_px = (BAYER[px.y * 4 + px.x] + 0.5) / 16.0;
				cheio = clamp(hit.x / (trama * 0.4), 0.0, 1.0) > limiar_px;
			}
			if (cheio) {
				float t = hit.y;
				if (faixas_de_tom >= 2.0) {
					t = clamp(floor(t * faixas_de_tom) / (faixas_de_tom - 1.0), 0.0, 1.0);
				}
				vec3 alto = vec3(brilho);
				// O baixo e o branco puxado para o azul do horizonte.
				vec3 baixo = mix(alto, horizonte * 0.8, sombra);
				cor = mix(baixo, alto, t);
			}
		}
	}
	// O sol: disco e um halo curto, o que o procedural tinha.
	if (LIGHT0_ENABLED) {
		float ang = degrees(acos(clamp(dot(dir, LIGHT0_DIRECTION), -1.0, 1.0)));
		float disco = 1.0 - smoothstep(0.0, 1.5, ang);
		float halo = pow(1.0 - smoothstep(0.0, 25.0, ang), 4.0) * 0.25;
		cor += LIGHT0_COLOR * LIGHT0_ENERGY * (disco + halo);
	}
	COLOR = cor;
}
