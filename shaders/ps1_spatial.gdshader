// Material "PS1" para geometría 3D:
//  - Vertex snapping (jitter de vértices por falta de precisión subpíxel).
//  - Affine texture mapping (texturas que se "deforman" sin corrección de perspectiva).
//  - Filtrado de texturas Nearest.
//  - Iluminación por vértice (Godot 4.4+ en Forward+, en 4.3 se ignora sin error).
//  - UV opcionales en espacio mundo, para tilear texturas en primitivas.
shader_type spatial;
render_mode vertex_lighting, diffuse_lambert, specular_disabled, cull_back;

global uniform float ps1_vertex_snap;
global uniform float ps1_affine;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_nearest, repeat_enable, hint_default_white;
uniform vec2 uv_scale = vec2(1.0);
uniform bool world_uv = false;
uniform float emission_strength = 0.0;
// Multiplica por el color de vértice / de instancia (terreno, MultiMesh).
uniform bool use_vertex_color = false;
// Rejilla de snapping (en "píxeles" de media resolución: 320x240 -> 160x120).
uniform vec2 snap_resolution = vec2(160.0, 120.0);

varying vec3 affine_uvw;

void vertex() {
	if (world_uv) {
		vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		vec3 wn = abs(normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz));
		vec2 uvw;
		if (wn.y >= wn.x && wn.y >= wn.z) {
			uvw = wp.xz;
		} else if (wn.x >= wn.z) {
			uvw = vec2(wp.z, -wp.y);
		} else {
			uvw = vec2(wp.x, -wp.y);
		}
		UV = uvw * uv_scale;
	} else {
		UV = UV * uv_scale;
	}

	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	if (ps1_vertex_snap > 0.5 && clip.w > 0.0) {
		vec2 ndc = clip.xy / clip.w;
		ndc = round(ndc * snap_resolution * ps1_vertex_snap) / (snap_resolution * ps1_vertex_snap);
		clip.xy = ndc * clip.w;
	}
	POSITION = clip;
	// Guardamos UV*w para deshacer la corrección de perspectiva en el fragment.
	affine_uvw = vec3(UV * clip.w, clip.w);
}

void fragment() {
	vec2 affine_uv = affine_uvw.xy / affine_uvw.z;
	vec2 uv = mix(UV, affine_uv, clamp(ps1_affine, 0.0, 1.0));
	vec3 tex = texture(albedo_texture, uv).rgb;
	ALBEDO = albedo.rgb * tex;
	if (use_vertex_color) {
		ALBEDO *= COLOR.rgb;
	}
	EMISSION = ALBEDO * emission_strength;
}
