// Suelo con relieve (losas, empedrado): como ps1_spatial (temblor de vértices,
// Nearest) pero con iluminación por píxel y normal map, para que los poros y
// las juntas reciban luz y sombra. Brillo suave de piedra húmeda.
shader_type spatial;
render_mode diffuse_lambert, cull_back;

global uniform float ps1_vertex_snap;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap, repeat_enable, hint_default_white;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float normal_depth : hint_range(0.0, 4.0) = 1.6;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.72;
uniform float specular_value : hint_range(0.0, 1.0) = 0.35;
// Oscurece los huecos (zonas oscuras de la foto) para dar profundidad.
uniform float cavity_strength : hint_range(0.0, 2.0) = 0.6;
uniform vec2 uv_scale = vec2(0.6);
uniform vec2 snap_resolution = vec2(160.0, 120.0);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// UV desde arriba en espacio mundo: cada losa enseña un trozo distinto.
	UV = world_pos.xz * uv_scale;
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	if (ps1_vertex_snap > 0.5 && clip.w > 0.0) {
		vec2 ndc = clip.xy / clip.w;
		ndc = round(ndc * snap_resolution * ps1_vertex_snap) / (snap_resolution * ps1_vertex_snap);
		clip.xy = ndc * clip.w;
	}
	POSITION = clip;
}

void fragment() {
	vec3 tex = texture(albedo_texture, UV).rgb;
	float lum = dot(tex, vec3(0.299, 0.587, 0.114));
	float cavity = mix(1.0, smoothstep(0.15, 0.65, lum), cavity_strength);
	ALBEDO = albedo.rgb * tex * COLOR.rgb * cavity;
	NORMAL_MAP = texture(normal_texture, UV).rgb;
	NORMAL_MAP_DEPTH = normal_depth;
	ROUGHNESS = roughness_value;
	SPECULAR = specular_value;
}
