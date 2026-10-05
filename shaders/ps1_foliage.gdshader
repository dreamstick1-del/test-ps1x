// Vegetación en tarjetas (hierba alta, juncos, matas): textura con transparencia
// recortada (alpha scissor, sin ordenar transparencias: barato y estilo PS1),
// visible por las dos caras, con vaivén de viento a saltos (12 fps) que solo
// mueve la parte alta. Mantiene el temblor de vértices PS1.
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;

global uniform float ps1_vertex_snap;

uniform sampler2D foliage_texture : source_color, filter_nearest_mipmap, repeat_enable;
uniform float alpha_cut = 0.5;
uniform float wind_strength = 0.12;
// Volúmenes (copas, pinos): el viento mueve según la altura y se conserva la
// normal real de la forma para que tenga luz y sombra.
uniform bool volume = false;
uniform vec2 snap_resolution = vec2(160.0, 120.0);

void vertex() {
	// UV.y = 0 arriba, 1 abajo: el viento solo empuja la punta
	// (en la copa horizontal, según la altura del vértice).
	float sway = abs(NORMAL.y) > 0.9 && VERTEX.y > 0.3 ? 0.7 : (1.0 - UV.y);
	if (volume) {
		sway = clamp((VERTEX.y - 1.5) / 3.0, 0.0, 1.0);
	}
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = floor(TIME * 12.0) / 12.0;
	float phase = t * 1.7 + wp.x * 0.35 + wp.z * 0.27;
	VERTEX.x += sin(phase) * wind_strength * sway * sway;
	VERTEX.z += cos(phase * 0.8) * wind_strength * 0.6 * sway * sway;
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	if (ps1_vertex_snap > 0.5 && clip.w > 0.0) {
		vec2 ndc = clip.xy / clip.w;
		ndc = round(ndc * snap_resolution) / snap_resolution;
		clip.xy = ndc * clip.w;
	}
	POSITION = clip;
	// Las caras de las tarjetas iluminan como si miraran arriba (sin rayas oscuras).
	if (!volume) {
		NORMAL = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
	}
}

void fragment() {
	vec4 tex = texture(foliage_texture, UV);
	if (tex.a < alpha_cut) {
		discard;
	}
	ALBEDO = tex.rgb * COLOR.rgb;
}
