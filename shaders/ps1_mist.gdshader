shader_type spatial;
// Bancos de niebla baja: tarjetas que siempre miran a la cámara (solo giran en
// Y), con ruido que se desplaza despacio. La opacidad la fija Atmosphere según
// la hora (mucha al amanecer, casi nada a mediodía).
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

uniform vec3 mist_color : source_color = vec3(0.8, 0.82, 0.85);
uniform float opacity = 0.5;
uniform sampler2D noise : filter_nearest, repeat_enable;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
		vec4(0.0, 1.0, 0.0, 0.0),
		vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
		MODEL_MATRIX[3]);
}

void fragment() {
	vec2 seed = MODEL_MATRIX[3].xz * 0.031;
	float n = texture(noise, UV * vec2(1.3, 0.5) + seed + vec2(TIME * 0.008, 0.0)).r;
	float n2 = texture(noise, UV * vec2(2.6, 1.1) - seed - vec2(TIME * 0.013, 0.0)).r;
	float shape = smoothstep(0.0, 0.3, UV.x) * smoothstep(1.0, 0.7, UV.x)
		* smoothstep(0.0, 0.55, UV.y) * smoothstep(1.0, 0.85, UV.y);
	float a = clamp((n * 0.7 + n2 * 0.5 - 0.3) * 1.6, 0.0, 1.0) * shape * opacity;
	// Se desvanece al acercarse (no tapar la cara con una tarjeta plana).
	a *= smoothstep(2.5, 9.0, length(VERTEX));
	a = floor(a * 6.0 + 0.5) / 6.0; // pocos niveles de transparencia
	if (a <= 0.0) {
		discard;
	}
	ALBEDO = mist_color;
	ALPHA = a;
}
