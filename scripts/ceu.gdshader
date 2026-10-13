// O ceu: gradiente de meio-dia e cumulo de base reta e topo em bolhas,
// iluminado pelo sol, andando devagar com o vento.
//
// Na comparacao da V14 (textura com trama, lisa, esparsa, ruido e objeto no
// mundo) ganhou a nuvem feita no shader. Mas ruido recortado por limiar e
// mancha: borda rendada, sem base, sem volume - "poca de leite derramado". O
// que faz cumulo e a estrutura, e e ela que este shader desenha:
// - base reta, porque e onde o ar chega no ponto de orvalho;
// - topo em domo feito de bolhas, mais alto no meio;
// - cada bolha com a sua normal, entao o sol acende um lado e o pe fica na
//   sombra azulada.
// O ruido so quebra a borda das bolhas (`detalhe`).
//
// O gradiente e o mesmo do ProceduralSkyMaterial de antes - mesmas cores,
// mesma curva de 0,15 -, para a luz ambiente, que vem do ceu, nao mudar.
// Os numeros da nuvem sao sliders do F3 (`WorldTuning`, grupo Ceu), e o
// `world.gd` repassa. Os defaults daqui so valem ate o primeiro quadro.
shader_type sky;

uniform vec3 topo : source_color = vec3(0.16, 0.38, 0.82);
uniform vec3 horizonte : source_color = vec3(0.62, 0.74, 0.88);
uniform vec3 chao_horizonte : source_color = vec3(0.55, 0.6, 0.62);
uniform vec3 chao_fundo : source_color = vec3(0.24, 0.26, 0.25);

uniform float altura_min = 8.0;
uniform float altura_max = 40.0;
uniform float cobertura = 0.42;
uniform float tamanho = 16.0;
uniform float achatamento = 2.0;
uniform float borda = 0.0;
uniform float detalhe = 4.0;
uniform float sombra = 0.5;
uniform float brilho = 1.1;
uniform float faixas_de_tom = 0.0;
uniform float vento = 0.15;

// Bolhas por cumulo: a fileira de baixo, que da a base e o domo, e as menores
// por cima, que dao a couve-flor.
const int FILEIRA = 6;
const int TOPETES = 5;

vec4 hash4(float n) {
	return fract(sin(vec4(n, n + 1.31, n + 2.77, n + 4.13)) * vec4(43758.55, 22578.15, 19642.35, 68023.71));
}

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

// Ruido de valor na DIRECAO do olhar, sem costura atras da camera.
float ruido(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(
			mix(hash3(i), hash3(i + vec3(1, 0, 0)), u.x),
			mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), u.x),
			u.y
		),
		mix(
			mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), u.x),
			mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), u.x),
			u.y
		),
		u.z
	);
}

float fbm(vec3 p) {
	return ruido(p) * 0.6 + ruido(p * 2.1) * 0.3 + ruido(p * 4.3) * 0.1;
}

// Testa o ponto (lon, elev) contra o cumulo da celula `id` da camada.
// Devolve (achou, normal x, normal y, altura relativa na nuvem).
vec4 cumulo(float id, float camada, float celula, float lon, float elev, float quebra) {
	vec4 h = hash4(id * 7.13 + camada * 101.7);
	if (h.x > cobertura) {
		return vec4(0.0);
	}
	vec4 h2 = hash4(id * 3.71 + camada * 57.3 + 11.0);
	float largura = tamanho * (0.6 + 0.8 * h.z);
	float altura = largura / achatamento;
	float base = mix(altura_min, max(altura_min, altura_max - altura), h.w);
	// Perspectiva: nuvem perto do horizonte esta mais longe, e parece menor.
	float longe = mix(0.55, 1.0, smoothstep(altura_min, altura_min + 25.0, base));
	largura *= longe;
	altura *= longe;
	float centro = (id + 0.5 + (h.y - 0.5) * 0.6) * celula;
	// Longitude encolhe com o cosseno da altura: e o que deixa a bolha redonda.
	float esc = cos(radians(elev));
	if (elev < base || abs(lon - centro) * esc > largura) {
		return vec4(0.0);
	}
	float melhor = -2.0;
	vec2 normal = vec2(0.0);
	for (int i = 0; i < FILEIRA + TOPETES; i++) {
		vec4 b = hash4(id * 13.7 + camada * 31.1 + float(i) * 1.618);
		vec2 c;
		float r;
		if (i < FILEIRA) {
			float f = (float(i) + 0.5) / float(FILEIRA);
			float perfil = pow(sin(3.14159 * f), 0.7);
			r = altura * (0.35 + 0.45 * perfil) * (0.85 + 0.3 * b.x);
			c = vec2(centro + (f - 0.5) * largura * 0.85 / esc, base + r * 0.55);
		} else {
			// Topete: sentado na borda de cima de uma bolha do meio.
			float f = 0.2 + 0.6 * b.y;
			float perfil = pow(sin(3.14159 * f), 0.7);
			float r0 = altura * (0.35 + 0.45 * perfil);
			float a = mix(0.25, 0.75, b.z) * 3.14159;
			r = r0 * (0.35 + 0.25 * b.x);
			c = vec2(
				centro + ((f - 0.5) * largura * 0.85 + cos(a) * r0 * 0.75) / esc,
				base + r0 * 0.55 + sin(a) * r0 * 0.75
			);
		}
		vec2 d = vec2((lon - c.x) * esc, elev - c.y);
		float dist = length(d) + quebra * r;
		if (dist < r) {
			// A bolha mais por fora (normal mais para cima) decide a luz.
			vec2 n = d / r;
			if (n.y > melhor) {
				melhor = n.y;
				normal = n;
			}
		}
	}
	if (melhor < -1.5) {
		return vec4(0.0);
	}
	return vec4(1.0, normal, clamp((elev - base) / altura, 0.0, 1.0));
}

void sky() {
	vec3 dir = EYEDIR;
	float elev = degrees(asin(clamp(dir.y, -1.0, 1.0)));
	float c = clamp(elev / 90.0, 0.0, 1.0);
	vec3 cor = mix(horizonte, topo, clamp(1.0 - pow(1.0 - c, 1.0 / 0.15), 0.0, 1.0));
	if (elev < 0.0) {
		float g = clamp(-elev / 90.0, 0.0, 1.0);
		cor = mix(chao_horizonte, chao_fundo, clamp(1.0 - pow(1.0 - g, 1.0 / 0.02), 0.0, 1.0));
	} else if (elev < altura_max + tamanho) {
		float lon = mod(degrees(atan(dir.x, dir.z)) + TIME * vento, 360.0);
		// Uma nuvem por celula, e celulas inteiras na volta: sem costura.
		float n_cel = max(floor(360.0 / (tamanho * 1.6)), 3.0);
		float celula = 360.0 / n_cel;
		// A borda quebrada: so encolhe a bolha, nunca cresce, para o ruido nao
		// soltar fiapo fora da nuvem.
		float quebra = max(fbm(dir * (57.3 / tamanho) * 3.0) - 0.3, 0.0) * 0.08 * detalhe;
		vec4 hit = vec4(0.0);
		// Duas camadas defasadas, para nem toda nuvem estar na mesma fileira.
		for (int camada = 0; camada < 2; camada++) {
			float l = lon + float(camada) * celula * 0.5;
			float id = floor(l / celula);
			for (int k = -1; k <= 1; k++) {
				float idk = id + float(k);
				// O id da volta: a celula n_cel e a celula 0.
				float idw = mod(idk, n_cel);
				vec4 r = cumulo(idw, float(camada), celula, l - (idk - idw) * celula, elev, quebra);
				if (r.x > 0.5 && hit.x < 0.5) {
					hit = r;
				}
			}
		}
		if (hit.x > 0.5) {
			// Luz: a normal da bolha no espaco do olhar, contra o sol.
			vec3 frente = normalize(vec3(dir.x, 0.0, dir.z));
			vec3 lado = vec3(frente.z, 0.0, -frente.x);
			vec2 n2 = hit.yz;
			float nz = sqrt(max(1.0 - dot(n2, n2), 0.0));
			vec3 n3 = normalize(lado * n2.x + vec3(0.0, n2.y, 0.0) - frente * nz);
			float sol = LIGHT0_ENABLED ? dot(n3, LIGHT0_DIRECTION) : 0.5;
			float t = clamp(0.25 + 0.45 * hit.w + 0.4 * sol + 0.25 * n2.y, 0.0, 1.0);
			if (faixas_de_tom >= 2.0) {
				t = clamp(floor(t * faixas_de_tom) / (faixas_de_tom - 1.0), 0.0, 1.0);
			}
			vec3 alto = vec3(brilho);
			// A base e o branco puxado para o azul do horizonte.
			vec3 base = mix(alto, horizonte * 0.8, sombra);
			vec3 nuvem = mix(base, alto, t);
			// Borda: 0 recorta seco; acima, a ponta da bolha some no ceu.
			float alfa = 1.0 - smoothstep(1.0 - borda * 0.5, 1.0, length(n2));
			cor = mix(cor, nuvem, borda > 0.0 ? alfa : 1.0);
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
