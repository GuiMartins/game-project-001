shader_type spatial;
render_mode cull_disabled;

// A onda cresce para a ponta livre; junto a haste, o pano continua preso.
void vertex() {
	float x = VERTEX.x + 0.66;
	float y = VERTEX.y;
	float fase = x * 8.0 - TIME * 9.0 + y * 2.5;
	float amplitude = 0.19 * x;
	VERTEX.z += amplitude * sin(fase) + 0.045 * x * sin(x * 17.0 - TIME * 14.0);
	VERTEX.y -= 0.07 * x * x;
	float dx = 0.19 * sin(fase) + amplitude * 8.0 * cos(fase)
		+ 0.045 * sin(x * 17.0 - TIME * 14.0)
		+ 0.765 * x * cos(x * 17.0 - TIME * 14.0);
	float dy = amplitude * 2.5 * cos(fase);
	NORMAL = normalize(vec3(-dx, -dy, 1.0));
}

void fragment() {
	float quadriculado = mod(floor(UV.x * 6.0) + floor(UV.y * 4.0), 2.0);
	ALBEDO = mix(vec3(0.035, 0.045, 0.06), vec3(0.94, 0.94, 0.9), quadriculado);
	ROUGHNESS = 0.95;
}
