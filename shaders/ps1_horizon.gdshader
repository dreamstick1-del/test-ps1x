shader_type spatial;
// Anillo del horizonte: siluetas de colinas y bosque lejanos (textura generada
// por Atmosphere) teñidas por la bruma del horizonte. Va pegado a la cámara,
// como un fondo pintado: no tiene paralaje.
render_mode unshaded, cull_disabled, fog_disabled, depth_draw_opaque;

uniform sampler2D silhouette : filter_nearest, repeat_enable;
uniform vec3 land_color : source_color = vec3(0.22, 0.28, 0.24);
uniform vec3 haze_color : source_color = vec3(0.66, 0.74, 0.82);
uniform float haze = 0.55;

void fragment() {
	vec4 t = texture(silhouette, UV);
	if (t.a < 0.5) {
		discard;
	}
	// t.r: luz de la silueta (copas más claras arriba), UV.y: más bruma abajo.
	vec3 c = land_color * (0.75 + t.r * 0.5);
	ALBEDO = mix(c, haze_color, clamp(haze + (UV.y - 0.6) * 0.5, 0.0, 1.0));
}
