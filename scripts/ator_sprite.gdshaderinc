// O ator em sprite (`Entregador.sprite`): um quadro do atlas recortado das
// folhas do Google Flow (`arte/sprites_flow.gd`), de frente para a camera.
//
// O billboard e feito aqui, e nao com `billboard_mode`, porque o quad mora
// dentro do `Visual`, que inclina na curva: o billboard do material herdaria a
// rolagem e o sprite deitaria duas vezes, uma pela pose desenhada e outra
// pelo no. Daqui so se usa a posicao do no; quem inclina e o quadro.
//
// Gira so em volta do vertical: o sprite foi desenhado com a camera um pouco
// acima, e deitar ele para a camera que olha de cima achata o piloto.

render_mode unshaded, cull_disabled, skip_vertex_transform, shadows_disabled;

uniform sampler2D atlas : source_color, filter_nearest_mipmap;
// Qual celula do atlas, e quantas ele tem. Uma fileira so.
uniform int quadro = 2;
uniform int quadros = 11;
// A ginga (`AtorSprite.posar`): quanto o quad gira em volta do pe do pneu
// (radianos, + topo para a direita da tela), desliza para o lado e desce com
// a suspensao (metros). Desce inteiro, e nao encolhe: o tamanho nao muda.
uniform float rolagem = 0.0;
uniform float desvio = 0.0;
uniform float afunda = 0.0;
// A empinada (0..1), vista de tras: com a frente no ar o corpo da moto sobe
// em cima da roda traseira e o piloto se estica para tras. O atlas nao tem
// quadro disso, entao o quad estica na vertical a partir do pe do pneu.
uniform float empina = 0.0;
// A cor do corredor. A camiseta e a bag das folhas sao vermelhas, e e nelas
// que a cor entra, como no modelo 3D.
uniform vec3 cor : source_color = vec3(0.82, 0.12, 0.10);
// O vermelho da bag na folha, em linear: e o tom que vira a `cor` cheia. Mais
// escuro que ele vira a `cor` sombreada na mesma proporcao.
const float VERMELHO_REF = 0.75;
// O sprite e `unshaded`: a luz esta pintada na folha, e e luz de dia. De
// noite (`Relogio`) ele escurece para a luz da rua, ou sairia um entregador ao
// sol no meio do breu.
uniform vec3 luz_da_noite : source_color = vec3(0.24, 0.25, 0.32);

global uniform float noite;

void vertex() {
	vec3 origem = MODEL_MATRIX[3].xyz;
	vec3 para_camera = CAMERA_POSITION_WORLD - origem;
	para_camera.y = 0.0;
	vec3 frente = length(para_camera) > 0.001 ? normalize(para_camera) : vec3(0.0, 0.0, 1.0);
	vec3 direita = normalize(cross(vec3(0.0, 1.0, 0.0), frente));
	// O vertice ja vem com o pe do pneu na origem (`center_offset`): girar em
	// volta dela deixa a roda no asfalto.
	vec2 p = VERTEX.xy;
	p.y *= 1.0 + 0.22 * empina;
	float c = cos(rolagem);
	float s = sin(rolagem);
	p = vec2(p.x * c + p.y * s, -p.x * s + p.y * c);
	p += vec2(desvio, -afunda);
	vec3 mundo = origem + direita * p.x + vec3(0.0, 1.0, 0.0) * p.y;
	VERTEX = (VIEW_MATRIX * vec4(mundo, 1.0)).xyz;
	NORMAL = normalize((VIEW_MATRIX * vec4(frente, 0.0)).xyz);
	UV = vec2((float(quadro) + UV.x) / float(quadros), UV.y);
}

void fragment() {
	vec4 c = texture(atlas, UV);
	// Vermelho e o canal que passa os outros dois com folga: a bag e a
	// camiseta. A lanterna tambem entra, e de longe nao se ve a diferenca.
	float dominio = c.r / max(max(c.g, c.b), 0.01);
	float pinta = smoothstep(2.5, 5.0, dominio) * step(0.04, c.r);
	ALBEDO = mix(c.rgb, cor * (c.r / VERMELHO_REF), pinta);
	ALBEDO *= mix(vec3(1.0), luz_da_noite, noite);
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
