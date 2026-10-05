// Post-proceso aplicado al SubViewportContainer del juego (480x360 o 320x240):
// reduce el color a 15 bits (5 bits por canal, como la PS1) con dithering Bayer 4x4.
shader_type canvas_item;

uniform bool dither_enabled = true;
uniform float color_levels = 32.0;
uniform vec2 render_size = vec2(320.0, 240.0);
uniform float dither_strength = 1.0;

float bayer4(ivec2 p) {
	// Matriz de Bayer 4x4 codificada por filas.
	int idx = (p.y % 4) * 4 + (p.x % 4);
	const float m[16] = float[16](
		0.0, 8.0, 2.0, 10.0,
		12.0, 4.0, 14.0, 6.0,
		3.0, 11.0, 1.0, 9.0,
		15.0, 7.0, 13.0, 5.0);
	return m[idx] / 16.0 - 0.5;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (dither_enabled) {
		ivec2 p = ivec2(floor(UV * render_size));
		c.rgb += bayer4(p) * dither_strength / color_levels;
		c.rgb = floor(c.rgb * (color_levels - 1.0) + 0.5) / (color_levels - 1.0);
	}
	COLOR = vec4(clamp(c.rgb, 0.0, 1.0), 1.0);
}
