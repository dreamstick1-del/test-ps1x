// Marco de televisor CRT dibujado encima de todo a resolución nativa:
// scanlines, viñeta y esquinas redondeadas. No muestrea la pantalla,
// solo oscurece, así que es muy barato.
shader_type canvas_item;

uniform float scanline_count = 240.0;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.28;
uniform float vignette_strength : hint_range(0.0, 2.0) = 0.55;
uniform float corner_radius : hint_range(0.0, 0.2) = 0.05;

void fragment() {
	vec2 d = UV - 0.5;
	float scan = sin(UV.y * scanline_count * PI);
	float alpha = (1.0 - scan * scan) * scanline_strength;
	alpha += dot(d, d) * vignette_strength;

	vec2 q = abs(d) - (0.5 - corner_radius);
	float corner = length(max(q, vec2(0.0))) - corner_radius;
	if (corner > 0.0) {
		alpha = 1.0;
	}
	COLOR = vec4(0.0, 0.0, 0.0, clamp(alpha, 0.0, 1.0));
}
