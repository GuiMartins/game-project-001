// Ampliacao do SubViewport para a janela: "sharp bilinear", nearest no miolo
// do pixel e linear so na costura entre dois pixels.
//
// O mundo sai em 640x360 e a janela pode ter qualquer tamanho. Em escala
// inteira (1280, 1920, 2560, 3840) o nearest puro e perfeito. Fora dela
// (1366, 1600, tela cheia de Mac a 3,76x) o nearest faz umas colunas de 3 px
// e outras de 4, e com a camera andando cada borda pula de uma coluna para
// outra a cada quadro: a tela inteira treme. Aqui a costura vira uma rampa de
// UM pixel de tela, o que some com o tremor e quase nao amacia.
//
// Em escala inteira o resultado e identico ao nearest (o centro de todo pixel
// de tela cai longe da costura e a rampa satura), entao a janela padrao de
// 1920x1080, onde rodam o `shots` e a `prova`, nao muda nada.
//
// Exige `texture_filter` linear no SubViewportContainer: o shader so escolhe
// ONDE ler, quem mistura os dois vizinhos e o filtro.
shader_type canvas_item;

void fragment() {
	vec2 tamanho = vec2(textureSize(TEXTURE, 0));
	vec2 texel = UV * tamanho;
	// Quantos texels cabem num pixel de tela. Sai da derivada, e nao de um
	// uniform com a escala, para seguir sozinho a janela redimensionada e a
	// tecla que desliga o pixel (stretch_shrink 1).
	vec2 passo = fwidth(texel);
	vec2 costura = floor(texel + 0.5);
	texel = costura + clamp((texel - costura) / passo, -0.5, 0.5);
	COLOR = texture(TEXTURE, texel / tamanho);
}
