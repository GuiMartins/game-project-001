// O andar da gente da calcada, no vertice: `MultiMesh` nao tem esqueleto.
//
// A malha e uma so, de pe (`arte/pedestres.py`), e cada peca traz no U da UV
// de que parte e: perna gira em volta do quadril, braco em volta do ombro. O
// que muda de uma pessoa para outra - velocidade, de onde comeca, o ritmo do
// balanco - sai de dois sorteios por instancia, no `INSTANCE_CUSTOM`, que o
// `Multidao` tambem usa para saber onde cada um esta na hora do atropelo.
shader_type spatial;

// A cor da superficie, a do material que o `.glb` trouxe.
uniform vec3 cor : source_color = vec3(1.0);
// A camisa: so ela leva a cor da instancia, e pele, calca e cabelo nao.
uniform bool roupa = false;
// A pele, que a `Pessoa` troca para sair do carro com a pele de quem dirigia.
uniform bool e_pele = false;

// Segundos de jogo, e nao `TIME`: com o mundo pausado, ou congelado na prova
// visual, a gente congela junto, e o quadro da prova sai igual toda vez.
instance uniform float tempo = 0.0;
// Poses por segundo, a mesma trava do ator (`WorldTuning.ator_cadencia`); 0 e
// liso. Como no ator, so a pose pula: o lugar na calcada anda liso, senao a
// gente tremeria contra a camera, que segue a moto a cada passo.
instance uniform float cadencia = 0.0;
// 1 anda pela calcada; 0 fica parado, so passando o peso de um pe para outro.
instance uniform float andando = 0.0;
// A `Pessoa`, articulada, e posada no codigo: o vertice fica onde esta. Ela
// nao e `MultiMesh`, entao a cor vem daqui, e nao do `COLOR`.
instance uniform float articulado = 0.0;
instance uniform vec3 camisa : source_color = vec3(1.0);
// Alfa 0 e a pele do modelo.
instance uniform vec4 pele : source_color = vec4(0.0);

// Os pivos de `arte/pedestres.py`.
const float QUADRIL = 0.92;
const float OMBRO = 1.42;
// O trecho, a virada e a velocidade tem de bater com o `Multidao`.
// O trecho que cada um anda, em metros, centrado em onde o `Pedestres` o pos:
// vai ate o fim, para, vira e volta. Ja foi "some no fim e brota no comeco",
// e com centenas na tela sempre tinha alguem saindo do chao. Curto porque
// anda reto, na tangente de onde nasceu: no curvao mais fechado da pista
// (0,6 grau/m, uns 95 m de raio), 5 m para cada lado desviam 13 cm da
// calcada. Sete passadas inteiras, para a perna chegar no fim reta e a
// virada nao comecar de pe no ar.
const float TRECHO = 9.8;
// Quanto leva a virada no fim do trecho, em segundos, parado.
const float VIRA = 0.8;
// Dois passos, em metros: a perna fecha o ciclo quando o corpo anda isto, e o
// pe nao patina na calcada.
const float PASSADA = 1.4;
// Balanco da perna, em radianos; o braco vai a 80%, ao contrario. E o 0,35 da
// pose "andando" que existia antes do shader.
const float BALANCO = 0.35;


// Gira `v` em volta do eixo X que passa na altura `pivo`.
vec3 gira_x(vec3 v, float pivo, float a) {
	float c = cos(a);
	float s = sin(a);
	v.y -= pivo;
	v = vec3(v.x, v.y * c - v.z * s, v.y * s + v.z * c);
	v.y += pivo;
	return v;
}


vec3 normal_x(vec3 n, float a) {
	return gira_x(n, 0.0, a);
}


void vertex() {
	// A `Pessoa` e posada no codigo, e o Godot nao aceita `return` no
	// `vertex()`: ela simplesmente nao entra.
	if (articulado < 0.5) {
		// Os dois sorteios da pessoa, os mesmos que o `Multidao` usa para
		// saber onde ela esta na hora do atropelo.
		float s1 = INSTANCE_CUSTOM.x;
		float s2 = INSTANCE_CUSTOM.y;
		float pose = cadencia > 0.0 ? floor(tempo * cadencia) / cadencia : tempo;
		int parte = int(round(UV.x * 8.0));
		float lado = (parte == 1 || parte == 3) ? -1.0 : 1.0;
		if (andando > 0.5) {
			// De 1,1 a 1,6 m/s: o passo de quem anda na rua, sem fila indiana.
			float vel = mix(1.1, 1.6, s1);
			float ida = TRECHO / vel;
			float ciclo = 2.0 * (ida + VIRA);
			// O lugar sai do tempo liso; a pose - perna e virada - do travado.
			float t = mod(tempo + s2 * ciclo, ciclo);
			float tp = mod(pose + s2 * ciclo, ciclo);
			float onde = t < ida ? t * vel
				: t < ida + VIRA ? TRECHO
				: t < 2.0 * ida + VIRA ? TRECHO - (t - ida - VIRA) * vel
				: 0.0;
			float andado = tp < ida ? tp * vel
				: tp < ida + VIRA ? TRECHO
				: tp < 2.0 * ida + VIRA ? TRECHO + (tp - ida - VIRA) * vel
				: 2.0 * TRECHO;
			float rumo = tp < ida ? 0.0
				: tp < ida + VIRA ? PI * smoothstep(0.0, 1.0, (tp - ida) / VIRA)
				: tp < 2.0 * ida + VIRA ? PI
				: PI + PI * smoothstep(0.0, 1.0, (tp - 2.0 * ida - VIRA) / VIRA);
			float a = BALANCO * sin(TAU * andado / PASSADA);
			if (parte == 1 || parte == 2) {
				VERTEX = gira_x(VERTEX, QUADRIL, a * lado);
				NORMAL = normal_x(NORMAL, a * lado);
			} else if (parte == 3 || parte == 4) {
				VERTEX = gira_x(VERTEX, OMBRO, -0.8 * a * lado);
				NORMAL = normal_x(NORMAL, -0.8 * a * lado);
			}
			float c = cos(rumo);
			float s = sin(rumo);
			VERTEX = vec3(VERTEX.x * c + VERTEX.z * s, VERTEX.y, -VERTEX.x * s + VERTEX.z * c);
			NORMAL = vec3(NORMAL.x * c + NORMAL.z * s, NORMAL.y, -NORMAL.x * s + NORMAL.z * c);
			// A frente do modelo e -Z.
			VERTEX.z -= onde - TRECHO * 0.5;
		} else {
			// O peso de um pe para o outro: o corpo inteiro tomba um fio para o
			// lado, em volta dos pes, num ritmo de 2,5 a 4 s por ida e volta.
			float a = 0.03 * sin(TAU * (pose / mix(2.5, 4.0, s1) + s2));
			float c = cos(a);
			float s = sin(a);
			VERTEX = vec3(VERTEX.x * c - VERTEX.y * s, VERTEX.x * s + VERTEX.y * c, VERTEX.z);
			NORMAL = vec3(NORMAL.x * c - NORMAL.y * s, NORMAL.x * s + NORMAL.y * c, NORMAL.z);
		}
	}
}


void fragment() {
	vec3 c = roupa ? cor * COLOR.rgb * camisa : cor;
	ALBEDO = e_pele && pele.a > 0.5 ? pele.rgb : c;
}
