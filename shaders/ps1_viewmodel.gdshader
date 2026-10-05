// Material del arma en primera persona: igual que ps1_spatial (jitter de
// vértices, Lambert) pero sin test de profundidad, así la espada nunca
// atraviesa paredes visualmente.
shader_type spatial;
render_mode depth_test_disabled, vertex_lighting, diffuse_lambert, specular_disabled, cull_back;

global uniform float ps1_vertex_snap;

uniform vec4 albedo : source_color = vec4(1.0);
uniform float emission_strength = 0.0;
uniform bool use_vertex_color = false;
uniform vec2 snap_resolution = vec2(160.0, 120.0);

void vertex() {
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	if (ps1_vertex_snap > 0.5 && clip.w > 0.0) {
		vec2 ndc = clip.xy / clip.w;
		ndc = round(ndc * snap_resolution * ps1_vertex_snap) / (snap_resolution * ps1_vertex_snap);
		clip.xy = ndc * clip.w;
	}
	POSITION = clip;
}

void fragment() {
	ALBEDO = albedo.rgb;
	if (use_vertex_color) {
		ALBEDO *= COLOR.rgb;
	}
	EMISSION = ALBEDO * emission_strength;
}
