shader_type sky;
// Cielo de PS1: degradado en bandas, sol/luna como discos, estrellas y dos capas
// de nubes con ruido de baja resolución (filtro NEAREST) y pocos tonos.
// Los colores los pone Atmosphere según la hora.

uniform vec3 sky_top : source_color = vec3(0.28, 0.46, 0.78);
uniform vec3 sky_horizon : source_color = vec3(0.66, 0.74, 0.82);
uniform vec3 ground_color : source_color = vec3(0.3, 0.33, 0.3);
uniform vec3 sun_dir = vec3(0.0, 0.9, 0.35); // hacia el sol
uniform vec3 sun_color : source_color = vec3(1.0, 0.95, 0.8);
uniform float sun_visible = 1.0;
uniform float moon_visible = 0.0;
uniform vec3 cloud_lit : source_color = vec3(1.0);
uniform vec3 cloud_shade : source_color = vec3(0.62, 0.66, 0.74);
uniform float cloud_cover = 0.45;
uniform float night = 0.0;
uniform vec2 wind = vec2(0.006, 0.002);
uniform sampler2D cloud_noise : filter_nearest, repeat_enable;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float h = clamp(d.y, 0.0, 1.0);
	// Degradado en 10 bandas, como las cúpulas de cielo pintadas de la época.
	float band = floor(sqrt(h) * 10.0) / 10.0;
	vec3 col = mix(sky_horizon, sky_top, band);
	if (d.y < 0.0) {
		col = mix(sky_horizon, ground_color, clamp(-d.y * 5.0, 0.0, 1.0));
	}

	vec3 s = normalize(sun_dir);
	float sd = dot(d, s);
	// Halo y disco del sol (cuadrado-ish por las bandas: PS1).
	col += sun_color * smoothstep(0.93, 1.0, sd) * 0.3 * sun_visible;
	if (sd > 0.9988 && sun_visible > 0.5) {
		col = sun_color * 1.3;
	}
	// Luna (opuesta al sol) y estrellas.
	float md = dot(d, -s);
	if (md > 0.9992 && moon_visible > 0.5) {
		col = mix(col, vec3(0.85, 0.88, 0.95), moon_visible);
	}
	col += vec3(0.25, 0.28, 0.4) * smoothstep(0.985, 1.0, md) * 0.25 * moon_visible;
	if (night > 0.01 && d.y > 0.0) {
		float st = hash(floor(d * 160.0));
		if (st > 0.9965) {
			col += vec3(0.75, 0.8, 1.0) * night * smoothstep(0.03, 0.25, d.y) * (0.4 + (st - 0.9965) * 170.0);
		}
	}

	// Nubes: proyectadas sobre un "techo" plano; dos capas que se mueven con el viento.
	if (d.y > 0.0) {
		vec2 uv = d.xz / (d.y + 0.1) * 0.18;
		float n1 = texture(cloud_noise, uv + TIME * wind).r;
		float n2 = texture(cloud_noise, uv * 2.1 - TIME * wind * 1.6 + vec2(0.37, 0.71)).r;
		float n = n1 * 0.68 + n2 * 0.32;
		float edge = 1.0 - cloud_cover;
		float dens = smoothstep(edge, edge + 0.2, n);
		dens = floor(dens * 4.0 + 0.5) / 4.0; // cuatro tonos: nada de degradados suaves
		dens *= smoothstep(0.0, 0.2, d.y);
		float lit = clamp(0.5 + 0.5 * sd - (n - edge) * 1.1, 0.0, 1.0);
		lit = floor(lit * 3.0 + 0.5) / 3.0;
		vec3 cc = mix(cloud_shade, cloud_lit, lit);
		col = mix(col, cc, dens * 0.95);
	}
	// Bruma en el horizonte: enlaza el cielo con la niebla del suelo.
	col = mix(col, sky_horizon, (1.0 - smoothstep(0.0, 0.14, abs(d.y))) * 0.55);
	COLOR = col;
}
