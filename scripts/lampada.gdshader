// A lente de uma lampada que acende de noite: a do poste.
//
// De dia e a lente clara e apagada do `arte/poste.py`, com o mesmo acabamento
// do material que vinha do glTF. Quando o escuro (`noite`, posto pelo
// `Relogio`) passa do limiar desta lampada, ela acende - cada poste no seu,
// e a avenida acende em onda, como fotocelula, e nao num estalo so.
shader_type spatial;

global uniform float noite;

uniform vec3 apagada : source_color = vec3(0.82, 0.84, 0.82);
uniform vec3 acesa : source_color = vec3(1.0, 0.93, 0.8);
// Bem acima do limiar do glow (2,2): a lente e uma tira de 2 cm vista de
// baixo a 10 m, e sem o halo ela seria um risco claro, nao uma luz.
uniform float brilho = 9.0;
instance uniform float limiar = 0.5;

void fragment() {
	// A mesma rampa das luzes (`Relogio.RAMPA`): lampada e poca acendem juntas.
	float acende = clamp((noite - limiar) / 0.04, 0.0, 1.0);
	ALBEDO = apagada;
	ROUGHNESS = 0.8;
	METALLIC = 0.0;
	EMISSION = acesa * brilho * acende;
}
