// Terreno a partir de UNA sola foto de pasto (grass_albedo + grass_normal).
// El alfa de la textura es una máscara de "seco" (0 = hoja verde, 1 = paja).
// Con ella se sacan cuatro variantes y se mezclan por vértice:
//   - frondoso : las manchas secas se vuelven verdes          (COLOR.a = 0)
//   - natural  : la foto tal cual                             (COLOR.a = 0.5)
//   - seco     : lo verde se vuelve paja                       (COLOR.a = 1)
//   - barro    : las fibras se vuelven tierra pisada           (UV2.x = 0..1)
// y encima, grava de otra foto (gravel_albedo) para caminos   (UV2.y = 0..1)
// COLOR.rgb sigue siendo un tinte (roca en las cumbres, arena en la orilla...).
// Para que no se note la repetición, la textura se lee a dos escalas con
// rotación distinta y se mezclan con un ruido de baja frecuencia.
shader_type spatial;
render_mode diffuse_lambert, cull_back;

global uniform float ps1_vertex_snap;

uniform sampler2D grass_texture : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D grass_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D gravel_texture : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D gravel_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float gravel_scale = 0.55;
uniform float uv_scale = 0.45; // Repeticiones por metro.
uniform float normal_depth : hint_range(0.0, 4.0) = 1.2;
uniform vec3 lush_color : source_color = vec3(0.30, 0.48, 0.16);
uniform vec3 straw_color : source_color = vec3(0.70, 0.62, 0.40);
uniform vec3 mud_color : source_color = vec3(0.31, 0.25, 0.19);
uniform vec2 snap_resolution = vec2(160.0, 120.0);

varying vec3 world_pos;
varying float mud;
varying float gravel;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	mud = UV2.x;
	gravel = UV2.y;
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	if (ps1_vertex_snap > 0.5 && clip.w > 0.0) {
		vec2 ndc = clip.xy / clip.w;
		ndc = round(ndc * snap_resolution) / snap_resolution;
		clip.xy = ndc * clip.w;
	}
	POSITION = clip;
}

vec3 variant(vec4 tex, float dryness, float mud_amount) {
	float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	float detail = lum / 0.42; // Relieve de la foto conservado en todas las variantes.
	// Frondoso: las zonas secas de la foto pasan a verde.
	vec3 lush = mix(tex.rgb, lush_color * detail, tex.a * 0.85);
	// Seco: las zonas verdes pasan a paja.
	vec3 dry = mix(tex.rgb, straw_color * detail, (1.0 - tex.a) * 0.7);
	vec3 col = dryness < 0.5 ? mix(lush, tex.rgb, dryness * 2.0) : mix(tex.rgb, dry, dryness * 2.0 - 1.0);
	// Barro: tierra con fibras sueltas que asoman.
	vec3 dirt = mud_color * (0.55 + 0.9 * detail);
	float fibers = smoothstep(0.55, 0.85, lum) * 0.35;
	return mix(col, mix(dirt, col, fibers), mud_amount);
}

void fragment() {
	vec2 uv_a = world_pos.xz * uv_scale;
	// Segunda lectura rotada ~37° y a otra escala: rompe la repetición.
	mat2 rot = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	vec2 uv_b = rot * world_pos.xz * uv_scale * 0.61 + vec2(0.37, 0.71);
	float macro = smoothstep(0.3, 0.7, value_noise(world_pos.xz * 0.09));
	vec4 tex = mix(texture(grass_texture, uv_a), texture(grass_texture, uv_b), macro);
	vec3 nrm = mix(texture(grass_normal, uv_a).rgb, texture(grass_normal, uv_b).rgb, macro);

	// Variación suave extra de sequedad para que ningún prado sea uniforme.
	float wobble = (value_noise(world_pos.xz * 0.21 + 13.0) - 0.5) * 0.35;
	float dryness = clamp(COLOR.a + wobble, 0.0, 1.0);
	float mud_amount = clamp(mud + (value_noise(world_pos.xz * 0.8) - 0.5) * 0.4 * step(0.05, mud), 0.0, 1.0);

	vec3 col = variant(tex, dryness, mud_amount);
	// Grava: borde irregular (ruido) para que el camino no sea una franja recta.
	float g = clamp(gravel + (value_noise(world_pos.xz * 1.3) - 0.5) * 0.5 * step(0.05, gravel), 0.0, 1.0);
	g = smoothstep(0.35, 0.65, g);
	vec2 guv = rot * world_pos.xz * gravel_scale;
	col = mix(col, texture(gravel_texture, guv).rgb * 1.15, g);
	nrm = mix(nrm, texture(gravel_normal, guv).rgb, g);
	ALBEDO = col * mix(COLOR.rgb, vec3(1.0), g);
	NORMAL_MAP = nrm;
	NORMAL_MAP_DEPTH = normal_depth * (1.0 - mud_amount * 0.5);
	ROUGHNESS = 0.9;
	SPECULAR = 0.15;
}
