shader_type spatial;
render_mode unshaded, cull_disabled, skip_vertex_transform, shadows_disabled;

uniform sampler2D atlas : source_color, filter_nearest_mipmap;
uniform int colunas = 8;
uniform int linhas = 5;
uniform int quadro = 0;
uniform int angulos = 0;
uniform bool multidao = false;
// Folha de 8 linhas: a esquerda tem linhas proprias (7, 6, 5), em vez de espelhar a direita.
uniform bool dois_lados = false;
uniform float giro = 0.0;
uniform vec3 luz_da_noite : source_color = vec3(0.24, 0.25, 0.32);
instance uniform float tempo = 0.0;
instance uniform float cadencia = 0.0;
instance uniform float andando = 0.0;
global uniform float noite;

// Os mesmos numeros e a mesma ida e volta do `Multidao` e do shader 3D.
const float TRECHO = 9.8;
const float VIRA = 0.8;
const float PASSADA = 1.4;

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
	para_camera = length(para_camera) > 0.001 ? normalize(para_camera) : -frente;
	float a = acos(clamp(dot(para_camera, frente), -1.0, 1.0));
	int faixa = clamp(int(round(a * 4.0 / PI)), 0, 4);
	int linha = faixa;
	// Quatro vistas reais: os tres quartos traseiros usam as costas.
	if (angulos == 0 && linhas == 4) linha = min(faixa, 3);
	if (angulos == 1) linha = min(faixa, 2);
	if (angulos == 2) linha = faixa == 0 ? 3 : faixa == 1 ? 1 : faixa == 2 ? 0 : 2;
	if (angulos == 3) linha = faixa == 4 ? 2 : faixa == 3 ? 1 : faixa == 2 ? 0 : 3;
	bool espelha = dot(para_camera, direita_pessoa) < 0.0;
	if (dois_lados) {
		// Frente e costas ficam como foram desenhadas nos dois lados; so os tres
		// quartos e o perfil trocam de linha.
		if (espelha && faixa >= 1 && faixa <= 3) linha = 8 - faixa;
		espelha = false;
	}
	vec3 direita_tela = normalize(cross(vec3(0.0, 1.0, 0.0), para_camera));
	float c = cos(giro);
	float s = sin(giro);
	vec2 p = vec2(VERTEX.x * c + VERTEX.y * s, -VERTEX.x * s + VERTEX.y * c);
	vec3 mundo = origem + direita_tela * p.x + vec3(0.0, 1.0, 0.0) * p.y;
	VERTEX = (VIEW_MATRIX * vec4(mundo, 1.0)).xyz;
	NORMAL = (VIEW_MATRIX * vec4(para_camera, 0.0)).xyz;
	UV = vec2((coluna + (espelha ? 1.0 - UV.x : UV.x)) / float(colunas),
		(float(linha) + UV.y) / float(linhas));
}

void fragment() {
	vec4 c = texture(atlas, UV);
	ALBEDO = c.rgb * mix(vec3(1.0), luz_da_noite, noite);
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
