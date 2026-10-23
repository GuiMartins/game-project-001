// O sprite de tudo que o jogo desenha em 2D50: o piloto, a pessoa, e o que vier
// das folhas do Google Flow (`arte/recortar.gd`). Um shader so, para o que e
// igual nos tres - o billboard, a escolha da linha do angulo, o escurecer da
// noite - e uma chave para o que muda.
//
// - `angulos`: como a linha do atlas sai do angulo da camera. 0 a 3 sao as
//   folhas do pedestre (ver o `vertex`); 4 e uma linha so, que fica como foi
//   desenhada - o piloto, que o jogo sempre ve de tras.
// - `recolore`: troca o vermelho da folha (a bag e a camiseta, `VERMELHO_REF`)
//   por `cor`. O resto da folha fica como o Flow desenhou.
// - `n_luzes`: acende o brilho das luzes da ficha (`SpriteLuzes`), por cima do
//   desenho, nas coordenadas da celula.
//
// O billboard e feito aqui, e nao com `billboard_mode`, porque o quad do piloto
// mora dentro do `Visual`, que inclina na curva: o billboard do material
// herdaria a rolagem e o sprite deitaria duas vezes, uma pela pose desenhada e
// outra pelo no. Daqui so se usa a posicao do no; quem inclina e o quadro.
//
// Gira so em volta do vertical: o sprite foi desenhado com a camera um pouco
// acima, e deitar ele para a camera que olha de cima achata o desenho.

render_mode unshaded, cull_disabled, skip_vertex_transform, shadows_disabled;

uniform sampler2D atlas : source_color, filter_nearest_mipmap;
uniform int colunas = 8;
uniform int linhas = 5;
uniform int quadro = 0;
uniform int angulos = 0;
uniform bool multidao = false;
// Folha de 8 linhas: a esquerda tem linhas proprias (7, 6, 5), em vez de espelhar a direita.
uniform bool dois_lados = false;
// Quanto o quad gira em volta do pe (radianos, + topo para a direita da tela),
// desliza para o lado e desce com a suspensao (metros). Desce inteiro, e nao
// encolhe: o tamanho nao muda.
uniform float giro = 0.0;
uniform float desvio = 0.0;
uniform float afunda = 0.0;
// A cor do corredor. A camiseta e a bag das folhas sao vermelhas, e e nelas
// que a cor entra, como no modelo 3D.
uniform float recolore = 0.0;
uniform vec3 cor : source_color = vec3(0.82, 0.12, 0.10);
// O sprite e `unshaded`: a luz esta pintada na folha, e e luz de dia. De noite
// (`Relogio`) ele escurece para a luz da rua, ou sairia um entregador ao sol no
// meio do breu.
uniform vec3 luz_da_noite : source_color = vec3(0.24, 0.25, 0.32);
// As luzes da celula atual, as da ficha: (x, y em pixels da celula, raio em
// pixels, 1 se so acende de noite) e (cor, forca de 0 a 1). Quem muda de quadro
// troca estes numeros (`SpriteLuzes.aplica`); farol e lanterna de noite, e o
// freio, que acende de dia, mudam so a forca.
const int MAX_LUZES = 8;
uniform int n_luzes = 0;
uniform vec2 celula_px = vec2(64.0, 64.0);
uniform vec4 luz_pos[MAX_LUZES];
uniform vec4 luz_cor[MAX_LUZES];
instance uniform float tempo = 0.0;
instance uniform float cadencia = 0.0;
instance uniform float andando = 0.0;
global uniform float noite;

// O vermelho da bag na folha, em linear: e o tom que vira a `cor` cheia. Mais
// escuro que ele vira a `cor` sombreada na mesma proporcao.
const float VERMELHO_REF = 0.75;

// Os mesmos numeros e a mesma ida e volta do `Multidao` e do shader 3D.
const float TRECHO = 9.8;
const float VIRA = 0.8;
const float PASSADA = 1.4;

// A celula do atlas que este quadro desenha, para as luzes.
varying flat vec2 celula;

void vertex() {
	vec3 origem = MODEL_MATRIX[3].xyz;
	vec3 eixo_x = normalize(MODEL_MATRIX[0].xyz);
	vec3 eixo_z = normalize(MODEL_MATRIX[2].xyz);
	float rumo = 0.0;
	float coluna = float(quadro);
	if (multidao && andando > 0.5) {
		float vel = mix(1.1, 1.6, INSTANCE_CUSTOM.x);
		float ida = TRECHO / vel;
		float ciclo = 2.0 * (ida + VIRA);
		float t = mod(tempo + INSTANCE_CUSTOM.y * ciclo, ciclo);
		float pose = cadencia > 0.0 ? floor(tempo * cadencia) / cadencia : tempo;
		float tp = mod(pose + INSTANCE_CUSTOM.y * ciclo, ciclo);
		float onde = t < ida ? t * vel : t < ida + VIRA ? TRECHO
			: t < 2.0 * ida + VIRA ? TRECHO - (t - ida - VIRA) * vel : 0.0;
		float andado = tp < ida ? tp * vel : tp < ida + VIRA ? TRECHO
			: tp < 2.0 * ida + VIRA ? TRECHO + (tp - ida - VIRA) * vel : 2.0 * TRECHO;
		rumo = tp < ida ? 0.0 : tp < ida + VIRA ? PI * smoothstep(0.0, 1.0, (tp - ida) / VIRA)
			: tp < 2.0 * ida + VIRA ? PI : PI + PI * smoothstep(0.0, 1.0, (tp - 2.0 * ida - VIRA) / VIRA);
		coluna = floor(mod(andado / PASSADA, 1.0) * 8.0);
		float deslocado = onde - TRECHO * 0.5;
		float u = deslocado / (TRECHO * 0.5);
		origem -= eixo_z * deslocado;
		origem.y += 0.5 * (INSTANCE_CUSTOM.z + INSTANCE_CUSTOM.w) * u * u
			+ 0.5 * (INSTANCE_CUSTOM.z - INSTANCE_CUSTOM.w) * u;
	}
	vec3 frente = -eixo_x * sin(rumo) - eixo_z * cos(rumo);
	vec3 direita_pessoa = eixo_x * cos(rumo) - eixo_z * sin(rumo);
	vec3 para_camera = CAMERA_POSITION_WORLD - origem;
	para_camera.y = 0.0;
	para_camera = length(para_camera) > 0.001 ? normalize(para_camera)
		: angulos == 4 ? vec3(0.0, 0.0, 1.0) : -frente;
	float a = acos(clamp(dot(para_camera, frente), -1.0, 1.0));
	int faixa = clamp(int(round(a * 4.0 / PI)), 0, 4);
	int linha = faixa;
	// Quatro vistas reais: os tres quartos traseiros usam as costas.
	if (angulos == 0 && linhas == 4) linha = min(faixa, 3);
	if (angulos == 1) linha = min(faixa, 2);
	if (angulos == 2) linha = faixa == 0 ? 3 : faixa == 1 ? 1 : faixa == 2 ? 0 : 2;
	if (angulos == 3) linha = faixa == 4 ? 2 : faixa == 3 ? 1 : faixa == 2 ? 0 : 3;
	// Uma linha so: o desenho fica como foi feito, sem espelho nem angulo.
	if (angulos == 4) linha = 0;
	bool espelha = angulos != 4 && dot(para_camera, direita_pessoa) < 0.0;
	if (dois_lados) {
		// Frente e costas ficam como foram desenhadas nos dois lados; so os tres
		// quartos e o perfil trocam de linha.
		if (espelha && faixa >= 1 && faixa <= 3) linha = 8 - faixa;
		espelha = false;
	}
	vec3 direita_tela = normalize(cross(vec3(0.0, 1.0, 0.0), para_camera));
	float c = cos(giro);
	float s = sin(giro);
	// O vertice do piloto ja vem com o pe do pneu na origem (`center_offset`):
	// girar em volta dela deixa a roda no asfalto.
	vec2 p = vec2(VERTEX.x * c + VERTEX.y * s, -VERTEX.x * s + VERTEX.y * c);
	p += vec2(desvio, -afunda);
	vec3 mundo = origem + direita_tela * p.x + vec3(0.0, 1.0, 0.0) * p.y;
	VERTEX = (VIEW_MATRIX * vec4(mundo, 1.0)).xyz;
	NORMAL = (VIEW_MATRIX * vec4(para_camera, 0.0)).xyz;
	celula = vec2(coluna, float(linha));
	UV = vec2((coluna + (espelha ? 1.0 - UV.x : UV.x)) / float(colunas),
		(float(linha) + UV.y) / float(linhas));
}

void fragment() {
	vec4 c = texture(atlas, UV);
	// Vermelho e o canal que passa os outros dois com folga: a bag e a
	// camiseta. A lanterna tambem entra, e de longe nao se ve a diferenca.
	float dominio = c.r / max(max(c.g, c.b), 0.01);
	float pinta = smoothstep(2.5, 5.0, dominio) * step(0.04, c.r) * recolore;
	ALBEDO = mix(c.rgb, cor * (c.r / VERMELHO_REF), pinta);
	ALBEDO *= mix(vec3(1.0), luz_da_noite, noite);
	// O brilho das luzes da ficha, por cima: o pixel da celula onde o shader
	// esta, contra o ponto e o raio de cada luz.
	vec2 local = (UV * vec2(float(colunas), float(linhas)) - celula) * celula_px;
	for (int i = 0; i < MAX_LUZES; i++) {
		if (i >= n_luzes) break;
		float perto = 1.0 - smoothstep(0.0, 1.0, distance(local, luz_pos[i].xy) / luz_pos[i].z);
		float forca = luz_cor[i].a * mix(1.0, noite, luz_pos[i].w);
		ALBEDO += luz_cor[i].rgb * forca * perto;
	}
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
