// Variante C da comparacao da V14: nuvem de ruido no proprio shader do ceu.
//
// Refaz o gradiente do ProceduralSkyMaterial (mesmas cores, mesma curva) e
// poe por cima um fbm limitado a faixa baixa, com borda dura e tres tons, que
// anda devagar com o vento. A banda e o dither ficam com a paleta da tela.
shader_type sky;

uniform vec3 topo : source_color = vec3(0.16, 0.38, 0.82);
uniform vec3 horizonte : source_color = vec3(0.62, 0.74, 0.88);
uniform vec3 chao_horizonte : source_color = vec3(0.55, 0.6, 0.62);
uniform vec3 chao_fundo : source_color = vec3(0.24, 0.26, 0.25);
// Graus por segundo de deriva: devagar o bastante para so se notar parado.
uniform float vento = 0.15;
// Quanto do ceu baixo vira nuvem: mais alto, menos nuvem.
uniform float limiar = 0.45;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x),
		u.y
	);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * ruido(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void sky() {
	float elev = degrees(asin(clamp(EYEDIR.y, -1.0, 1.0)));
	float c = clamp(elev / 90.0, 0.0, 1.0);
	vec3 cor = mix(horizonte, topo, clamp(1.0 - pow(1.0 - c, 1.0 / 0.15), 0.0, 1.0));
	if (elev < 0.0) {
		float g = clamp(-elev / 90.0, 0.0, 1.0);
		cor = mix(chao_horizonte, chao_fundo, clamp(1.0 - pow(1.0 - g, 1.0 / 0.02), 0.0, 1.0));
	} else {
		// Longitude em graus, para a nuvem ter o mesmo tamanho em toda volta.
		float lon = degrees(atan(EYEDIR.x, EYEDIR.z)) + TIME * vento;
		// Esticada na horizontal: cumulo visto de longe e mais largo que alto.
		vec2 p = vec2(lon / 9.0, elev / 4.0);
		float n = fbm(p);
		// A faixa: some abaixo de 3 graus e acima de 24, mais densa por volta
		// de 10, que e onde a fresta entre os predios mostra o ceu.
		float faixa = smoothstep(3.0, 7.0, elev) * (1.0 - smoothstep(14.0, 24.0, elev));
		float d = n * faixa;
		if (d > limiar) {
			// Tom pela densidade e pela altura: base azulada, topo branco.
			float t = clamp((d - limiar) * 5.0 + (elev - 6.0) / 30.0, 0.0, 1.0);
			vec3 base = vec3(0.45, 0.55, 0.78);
			vec3 alto = vec3(1.15, 1.15, 1.12);
			cor = mix(base, alto, t);
		}
		// Sol: o disco, para nao perder o que o procedural tinha.
		if (LIGHT0_ENABLED) {
			float ang = acos(clamp(dot(EYEDIR, LIGHT0_DIRECTION), -1.0, 1.0));
			cor += LIGHT0_COLOR * LIGHT0_ENERGY * (1.0 - smoothstep(0.0, radians(1.5), ang));
		}
	}
	COLOR = cor;
}
