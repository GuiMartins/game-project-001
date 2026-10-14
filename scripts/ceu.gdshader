// O ceu: gradiente de meio-dia e um campo de tufos de nuvem, andando devagar
// com o vento.
//
// Na comparacao da V14 (textura com trama, lisa, esparsa, ruido e objeto no
// mundo) ganhou a nuvem feita no shader. A forma veio das referencias, depois
// de duas erradas (ruido recortado era "poca de leite"; cumulo grande de domo
// arrumado nao e o que elas tem):
// - muitos tufos pequenos em grupos irregulares, com azul entre os grupos;
// - o ceu inteiro, menores e mais juntos perto do horizonte, onde acumulam
//   num banco;
// - cada tufo com o pe cortado reto e o alto em calombo;
// - tufo solto e branco; onde se empilha, varios tons de cinza azulado;
// - a borda se desfaz em pixel solto, nem recorte liso nem degrade.
//
// A perspectiva vem de projetar a direcao do olhar num "teto" de nuvem: perto
// do horizonte o mesmo tufo fica longe, menor e achatado. Projecao plana pura
// (1/tan) achata demais; o expoente `perspectiva` dosa.
//
// O gradiente do meio-dia e o mesmo do ProceduralSkyMaterial de antes -
// mesmas cores, mesma curva de 0,15 -, para a luz ambiente, que vem do ceu,
// nao mudar.
// Atras de tudo, em volta do mundo, a serra (V14a): duas fileiras de cume
// azulado no horizonte, a de tras mais alta e mais clara. Sao um perfil por
// azimute - ruido de valor sobre o circulo, que fecha sem emenda -, e nao
// malha: a 800 m de alcance da camera uma malha cortaria na neblina, e o
// perfil no ceu vale em qualquer curva da pista. A cor sai do horizonte e do
// topo da hora, entao a serra anoitece junto sem numero proprio.
// Os numeros da nuvem sao sliders do F3 (`WorldTuning`, grupo Ceu), e o
// `world.gd` repassa. As cores, as estrelas e o disco do astro sao da hora
// (`Hora`), e o `Relogio` repassa: a corrida anoitece. Os defaults daqui sao
// o meio-dia, e so valem ate o primeiro quadro.
shader_type sky;

uniform vec3 topo : source_color = vec3(0.16, 0.38, 0.82);
uniform vec3 horizonte : source_color = vec3(0.62, 0.74, 0.88);
uniform vec3 chao_horizonte : source_color = vec3(0.55, 0.6, 0.62);
uniform vec3 chao_fundo : source_color = vec3(0.24, 0.26, 0.25);

uniform float altura_min = 2.0;
uniform float cobertura = 0.5;
uniform float tufo = 4.0;
uniform float grupo = 6.0;
uniform float perspectiva = 0.35;
uniform float detalhe = 0.6;
uniform float trama = 0.5;
uniform float sombra = 0.5;
uniform float cinza = 1.0;
uniform float banco = 0.35;
uniform float brilho = 1.1;
uniform float faixas_de_tom = 5.0;
uniform float vento = 0.15;

// A serra: altura do cume mais alto em graus, quanto do relevo e picote fino
// (0 e ondulado, 1 e serrilhado) e a semente do perfil, que o `World` sorteia.
uniform float serra_altura = 9.0;
uniform float serra_rugosidade = 0.5;
uniform float serra_semente = 0.0;

// Da hora. A nuvem multiplica pela luz e soma o laranja da cidade na barriga;
// de dia, branco e preto, ou seja, nada.
uniform vec3 nuvem_luz : source_color = vec3(1.0);
uniform vec3 nuvem_baixo : source_color = vec3(0.0);
uniform float estrelas = 0.0;
// O disco do astro: raio em graus, quanto do halo, e o brilho proprio da lua
// (a luz dela e fraca demais para o disco aparecer pela energia).
uniform float astro_disco = 1.5;
uniform float astro_halo = 0.25;
uniform float lua = 0.0;

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

// Uma oitava de tufos, como CAMPO: cada tufo soma uma bolha macia (metaball)
// e a nuvem e onde a soma passa do limiar. Tufo desenhado como circulo
// separado, com luz propria, empilhava em bolas e o cinza mudava em degrau de
// um circulo para o outro; somados, vizinhos se fundem num contorno so e a
// luz sai da forma da massa inteira.
// `fora` e a direcao do horizonte no plano (o "para baixo" da tela). Devolve
// (densidade, quanto ela cresce para cima): o segundo e o que diz se o ponto
// esta no pe da massa (cresce para cima, sombra) ou no alto (decresce, sol).
vec2 tufos(vec2 q, float escala, float semente, vec2 fora, float limiar) {
	vec2 qs = q * escala;
	vec2 cel = floor(qs);
	vec2 campo = vec2(0.0);
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
			float r = (0.6 + 0.45 * hash2(c + semente + 7.7).x) * smoothstep(limiar, limiar + 0.15, m);
			vec2 d = qs - centro;
			float s2 = dot(d, d) / (r * r);
			if (s2 >= 1.0) {
				continue;
			}
			// O pe reto: abaixo do centro a bolha murcha rapido, entao a soma
			// de varias termina numa linha quase reta, e nao em barriga.
			float baixo = dot(d, fora) / r;
			float pe = 1.0 - smoothstep(0.05, 0.4, baixo);
			float k = (1.0 - s2) * (1.0 - s2);
			campo.x += k * pe;
			// Derivada da bolha na direcao de cima (-fora), em unidades de
			// tufo: cresce para cima abaixo do centro, cai acima dele.
			campo.y += 4.0 * (1.0 - s2) * baixo / r * pe;
		}
	}
	return campo;
}

// Os tons da nuvem, do cinza da base de uma massa grossa ao branco do topo
// iluminado. Cinza puxado para o azul: e o ceu que ilumina por baixo.
vec3 tom_da_nuvem(float t) {
	vec3 cinza_escuro = mix(vec3(0.5, 0.53, 0.6), vec3(0.62, 0.66, 0.74), 1.0 - sombra);
	vec3 medio = vec3(0.68, 0.71, 0.77);
	vec3 claro = vec3(0.85, 0.87, 0.9);
	vec3 alto = vec3(brilho);
	if (t < 0.33) {
		return mix(cinza_escuro, medio, t / 0.33);
	} else if (t < 0.66) {
		return mix(medio, claro, (t - 0.33) / 0.33);
	}
	return mix(claro, alto, (t - 0.66) / 0.34);
}

// Altura do perfil de uma fileira da serra, de 0 a 1, no azimute `az`. Ruido
// sobre o circulo (cos, sin), e nao sobre o angulo: o angulo tem emenda em pi.
float perfil_da_serra(float az, float semente) {
	vec2 c = vec2(cos(az), sin(az));
	float grande = ruido(c * 2.2 + semente);
	float medio = ruido(c * 5.5 + semente * 1.7 + 11.0);
	// Em crista (1 - |2n - 1|): o picote vira pico, e nao ondulacao - a serra
	// das referencias e de pontas.
	float fino = 1.0 - abs(ruido(c * 15.0 + semente * 2.3 + 23.0) * 2.0 - 1.0);
	float h = grande * 0.62 + medio * (0.3 - 0.1 * serra_rugosidade) + fino * 0.2 * serra_rugosidade;
	return clamp(h * 1.2 - 0.15, 0.0, 1.0);
}

void sky() {
	vec3 dir = EYEDIR;
	float elev = degrees(asin(clamp(dir.y, -1.0, 1.0)));
	float c = clamp(elev / 90.0, 0.0, 1.0);
	vec3 cor = mix(horizonte, topo, clamp(1.0 - pow(1.0 - c, 1.0 / 0.15), 0.0, 1.0));
	// As estrelas, por baixo da nuvem: poucas, que e ceu de cidade, e de um
	// pixel. Uma por celula de uma grade em volta da camera, com raio de ~1/4
	// de grau - o pixel de 640x360 com a camera de perseguicao. Maior que isso
	// vira confete; menor some e volta conforme a camera anda. So acima de
	// 12 graus: perto do horizonte a poluicao luminosa apaga tudo.
	if (estrelas > 0.0 && elev > 12.0) {
		vec3 p = dir * 230.0;
		vec3 cel = floor(p);
		vec2 h = hash2(cel.xy + cel.z * 17.31);
		if (h.x > 0.994) {
			vec2 j = hash2(cel.yz + 3.7);
			vec3 centro = cel + vec3(0.25 + 0.5 * j.x, 0.25 + 0.5 * j.y, 0.5);
			float d = length(p - centro);
			float brilho_estrela = (1.0 - smoothstep(0.2, 0.6, d)) * (0.35 + 0.65 * h.y);
			cor += vec3(0.85, 0.9, 1.0) * brilho_estrela * estrelas * smoothstep(12.0, 30.0, elev);
		}
	}
	if (elev < 0.0) {
		float g = clamp(-elev / 90.0, 0.0, 1.0);
		cor = mix(chao_horizonte, chao_fundo, clamp(1.0 - pow(1.0 - g, 1.0 / 0.02), 0.0, 1.0));
	} else if (elev > altura_min * 0.3) {
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
		// O banco do horizonte: olhando de lado, a mesma camada de nuvem se
		// empilha, e la embaixo ela fecha. `banco` e o quanto ela fecha.
		float perto = 1.0 - smoothstep(altura_min, altura_min + 20.0, elev);
		limiar -= perto * banco;
		// So a ultima fresta antes do chao rareia, e la a neblina engole.
		limiar += (1.0 - smoothstep(altura_min * 0.3, altura_min, elev)) * 0.6;
		vec2 grande = tufos(q, 1.0, 0.0, fora, limiar);
		// As massas: tufos do dobro do tamanho, que so existem no banco, e sao
		// o que faz o horizonte ser monte de nuvem e nao pipoca miuda.
		// Entra aos poucos, e nao num `if` seco: ligada de uma vez, ela riscava
		// uma linha reta no ceu na altura em que comecava.
		float peso_massa = smoothstep(0.05, 0.3, perto);
		vec2 massa = peso_massa > 0.0 ? tufos(q, 0.5, 57.1, fora, limiar + 0.1 * (1.0 - perto)) * peso_massa : vec2(0.0);
		vec2 miudo = detalhe > 0.0 ? tufos(q, 2.3, 31.7, fora, limiar + 0.05) : vec2(0.0);
		// A derivada do miudo vem em unidades dele, 2,3 vezes menores; e a da
		// massa, em unidades dela, 2 vezes maiores.
		vec2 campo = grande + massa * vec2(1.0, 0.5) + miudo * vec2(0.6, 2.3 * 0.6) * detalhe;
		// O contorno da nuvem: a soma passando de 0,3, e nao a borda de um tufo.
		float dens = campo.x - 0.3;
		// Luz: no alto da massa a densidade cai para cima e o sol bate; no pe
		// ela cresce para cima, e e sombra. Normalizada pela propria
		// densidade, para valer igual em massa grande e pequena.
		float subida = campo.y / max(campo.x, 0.3);
		// Espessura: onde a soma e alta ha nuvem empilhada atras, e a luz nao
		// atravessa - e o cinza. Continuo, entao as faixas de tom seguem as
		// curvas de nivel da massa, e nao circulos.
		float espessura = max(campo.x - 0.6, 0.0);
		float t = 0.72 - subida * 0.18 - espessura * cinza * 0.65 - perto * cinza * 0.2;
		t = clamp(t, 0.0, 1.0);
		// Toda aresta daqui - o contorno e a troca de faixa de tom - e limiar
		// num campo que anda com a camera. Seca, ela fica mais fina que o pixel
		// de 640x360 e acende e apaga a cada quadro, o mesmo tremor que a
		// sombra e a quina de predio tinham na V28. Entao cada aresta e uma
		// rampa da largura de um pixel, medida pela derivada na tela (fwidth),
		// e a paleta da tela transforma a rampa em trama presa a tela. As
		// derivadas saem aqui, fora de qualquer `if`, onde elas valem.
		float px_dens = fwidth(dens);
		float faixas = max(faixas_de_tom, 2.0);
		float x = t * (faixas - 1.0);
		float px_x = fwidth(x);
		if (faixas_de_tom >= 2.0) {
			float degrau = floor(x);
			float f = x - degrau;
			t = (degrau + smoothstep(1.0 - max(px_x, 1e-4), 1.0, f)) / (faixas - 1.0);
		}
		// Borda: um pixel de rampa no minimo; `trama` alarga ate quatro.
		float largura = px_dens * (1.0 + trama * 3.0);
		float alfa = smoothstep(0.0, max(largura, 1e-4), dens);
		if (alfa > 0.0) {
			// A hora tinge: a luz multiplica a nuvem inteira, e o laranja da
			// cidade entra so por baixo, onde ela e grossa (t baixo).
			vec3 nuvem = tom_da_nuvem(t) * nuvem_luz + nuvem_baixo * (1.0 - t);
			// Perspectiva aerea: a nuvem do horizonte esta a dezenas de km, e o
			// ar entre ela e a camera a puxa para a cor do horizonte.
			nuvem = mix(nuvem, horizonte, (1.0 - smoothstep(0.0, 14.0, elev)) * 0.35);
			cor = mix(cor, nuvem, alfa);
		}
	}
	// A serra, por cima da nuvem e por baixo do sol. Cada fileira e uma rampa de
	// um pixel (fwidth), como a borda da nuvem: aresta seca mais fina que o
	// pixel de 640x360 acende e apaga andando.
	float serra_alfa = 0.0;
	if (serra_altura > 0.0) {
		float az = atan(dir.x, dir.z);
		float elev_graus = degrees(asin(clamp(dir.y, -1.0, 1.0)));
		// A de tras: alta e clara, quase a cor do ar.
		float h_tras = serra_altura * (0.45 + 0.55 * perfil_da_serra(az, serra_semente));
		// A da frente: mais baixa, mais escura, com outro perfil.
		float h_frente = serra_altura * 0.55 * perfil_da_serra(az + 1.7, serra_semente + 41.0);
		float px_tras = max(fwidth(elev_graus - h_tras), 1e-4);
		float px_frente = max(fwidth(elev_graus - h_frente), 1e-4);
		float a_tras = (1.0 - smoothstep(0.0, px_tras, elev_graus - h_tras)) * step(0.0, elev_graus);
		float a_frente = (1.0 - smoothstep(0.0, px_frente, elev_graus - h_frente)) * step(0.0, elev_graus);
		// O pe da serra some na neblina do horizonte: quanto mais perto do
		// chao, mais ela e da cor do ar.
		// Bem mais escura que o ceu que ela tapa: a 6 graus o gradiente ja esta
		// a 38% do caminho para o topo, e uma serra do mesmo azul que isso
		// some. Escurece em vez de azular, entao vale em qualquer hora.
		vec3 cor_tras = mix(horizonte, topo, 0.45) * vec3(0.5, 0.58, 0.58);
		cor_tras = mix(horizonte, cor_tras, 0.6 + 0.4 * smoothstep(0.0, h_tras * 0.5 + 0.01, elev_graus));
		vec3 cor_frente = mix(horizonte, topo, 0.6) * vec3(0.34, 0.42, 0.42);
		cor_frente = mix(cor_tras, cor_frente, 0.5 + 0.5 * smoothstep(0.0, h_frente * 0.5 + 0.01, elev_graus));
		cor = mix(cor, cor_tras, a_tras);
		cor = mix(cor, cor_frente, a_frente);
		serra_alfa = max(a_tras, a_frente);
	}
	// O sol: disco e um halo curto, o que o procedural tinha. De noite a
	// mesma luz e a lua, e o disco dela brilha por conta propria.
	if (LIGHT0_ENABLED) {
		float ang = degrees(acos(clamp(dot(dir, LIGHT0_DIRECTION), -1.0, 1.0)));
		float disco = 1.0 - smoothstep(0.0, astro_disco, ang);
		float halo = pow(1.0 - smoothstep(0.0, 25.0, ang), 4.0) * astro_halo;
		cor += LIGHT0_COLOR * (LIGHT0_ENERGY * (disco + halo) + lua * disco * 1.5) * (1.0 - serra_alfa);
	}
	COLOR = cor;
}
