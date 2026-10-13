// O ceu: gradiente de meio-dia e nuvem de ruido, com borda dura e base
// azulada, andando devagar com o vento.
//
// Substitui o ProceduralSkyMaterial porque a nuvem dele e textura: na
// comparacao da V14 (atual, lisa, esparsa, ruido e objeto no mundo), a de
// ruido foi a escolhida. O gradiente e o mesmo do procedural - mesmas cores,
// mesma curva de 0,15 -, para a luz ambiente, que vem do ceu, nao mudar.
//
// Os numeros da nuvem sao sliders do F3 (`WorldTuning`, grupo Ceu), e o
// `world.gd` repassa. Os defaults daqui so valem ate o primeiro quadro.
shader_type sky;

uniform vec3 topo : source_color = vec3(0.16, 0.38, 0.82);
uniform vec3 horizonte : source_color = vec3(0.62, 0.74, 0.88);
uniform vec3 chao_horizonte : source_color = vec3(0.55, 0.6, 0.62);
uniform vec3 chao_fundo : source_color = vec3(0.24, 0.26, 0.25);

uniform float altura_min = 8.0;
uniform float altura_max = 40.0;
uniform float cobertura = 0.35;
uniform float tamanho = 10.0;
uniform float achatamento = 2.0;
uniform float borda = 0.0;
uniform float detalhe = 4.0;
uniform float sombra = 0.5;
uniform float brilho = 1.1;
uniform float faixas_de_tom = 0.0;
uniform float vento = 0.15;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

// Ruido de valor em 3D, amostrado na DIRECAO do olhar: em longitude e
// latitude ele teria costura atras da camera, e a pista faz curva.
float ruido(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(
			mix(hash(i), hash(i + vec3(1, 0, 0)), u.x),
			mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), u.x),
			u.y
		),
		mix(
			mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), u.x),
			mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), u.x),
			u.y
		),
		u.z
	);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	float soma = 0.0;
	for (int i = 0; i < 6; i++) {
		if (float(i) >= detalhe) {
			break;
		}
		v += a * ruido(p);
		soma += a;
		p = p * 2.03 + vec3(1.7, 9.2, 3.1);
		a *= 0.5;
	}
	return v / soma;
}

void sky() {
	vec3 dir = EYEDIR;
	float elev = degrees(asin(clamp(dir.y, -1.0, 1.0)));
	float c = clamp(elev / 90.0, 0.0, 1.0);
	vec3 cor = mix(horizonte, topo, clamp(1.0 - pow(1.0 - c, 1.0 / 0.15), 0.0, 1.0));
	if (elev < 0.0) {
		float g = clamp(-elev / 90.0, 0.0, 1.0);
		cor = mix(chao_horizonte, chao_fundo, clamp(1.0 - pow(1.0 - g, 1.0 / 0.02), 0.0, 1.0));
	} else {
		// O vento gira o ceu em volta do eixo vertical.
		float giro = radians(TIME * vento);
		vec3 d = vec3(
			dir.x * cos(giro) - dir.z * sin(giro), dir.y, dir.x * sin(giro) + dir.z * cos(giro)
		);
		// Um radiano tem 57 graus: dividir por `tamanho` faz a nuvem ter mais
		// ou menos esse tamanho em graus. Achatada no vertical, porque cumulo
		// visto de longe e mais largo que alto.
		vec3 p = vec3(d.x, d.y * achatamento, d.z) * (57.3 / tamanho);
		float n = fbm(p);
		// A faixa em que existe nuvem, com rampa nas duas pontas.
		float rampa = max((altura_max - altura_min) * 0.25, 0.5);
		float faixa =
			smoothstep(altura_min, altura_min + rampa, elev)
			* (1.0 - smoothstep(altura_max - rampa, altura_max, elev));
		float dens = n * faixa;
		// Cobertura 0 e ceu limpo, 1 e quase fechado. O fbm mora entre ~0,25 e
		// ~0,75, e o limiar anda dentro disso.
		float limiar = mix(0.72, 0.32, cobertura);
		float alfa = smoothstep(limiar, limiar + 0.001 + borda * 0.15, dens);
		if (alfa > 0.0) {
			// Luz por cima: onde ha menos nuvem logo acima, e borda de cima e
			// clareia; onde ha mais, e o pe dela, na sombra azulada.
			float acima = fbm(p + vec3(0.0, 0.35, 0.0)) * faixa;
			float t = clamp(0.45 + (dens - acima) * 6.0 + (dens - limiar) * 3.0, 0.0, 1.0);
			if (faixas_de_tom >= 2.0) {
				t = floor(t * faixas_de_tom) / (faixas_de_tom - 1.0);
				t = clamp(t, 0.0, 1.0);
			}
			vec3 alto = vec3(brilho);
			// A base e o branco puxado para o azul do horizonte.
			vec3 base = mix(alto, horizonte * 0.8, sombra);
			cor = mix(cor, mix(base, alto, t), alfa);
		}
		// O sol: disco e um halo curto, o que o procedural tinha.
		if (LIGHT0_ENABLED) {
			float ang = degrees(acos(clamp(dot(dir, LIGHT0_DIRECTION), -1.0, 1.0)));
			float disco = 1.0 - smoothstep(0.0, 1.5, ang);
			float halo = pow(1.0 - smoothstep(0.0, 25.0, ang), 4.0) * 0.25;
			cor += LIGHT0_COLOR * LIGHT0_ENERGY * (disco + halo);
		}
	}
	COLOR = cor;
}
