class_name Atmosphere
extends Node3D
## Cielo, niebla y bruma del mundo, según la hora (Economy.hour):
##  - Cielo (shaders/ps1_sky.gdshader): degradado en bandas, sol que cruza de
##    este a oeste, luna y estrellas de noche, nubes de baja resolución que se
##    mueven con el viento.
##  - Horizonte (shaders/ps1_horizon.gdshader): dos anillos con siluetas de
##    montes y bosque lejanos pegados a la cámara, para que más allá de la
##    maqueta no se vea el vacío.
##  - Niebla: más espesa al amanecer y de noche, ligera a mediodía, del color del
##    horizonte; niebla de altura que se queda en los valles y el río.
##  - Bancos de niebla baja (shaders/ps1_mist.gdshader) sobre el río y los
##    bosques, sobre todo por la mañana.
## Solo se ve en primera persona; desde fuera de la maqueta, la habitación oscura.

## Paleta por hora: [hora, cénit, horizonte, nube iluminada, nube en sombra].
const PALETTE := [
	[0.0, Color(0.02, 0.03, 0.08), Color(0.07, 0.08, 0.15), Color(0.2, 0.21, 0.28), Color(0.06, 0.06, 0.1)],
	[4.8, Color(0.04, 0.05, 0.12), Color(0.12, 0.11, 0.19), Color(0.24, 0.22, 0.3), Color(0.08, 0.07, 0.12)],
	[6.2, Color(0.24, 0.3, 0.5), Color(0.86, 0.56, 0.42), Color(1.0, 0.74, 0.58), Color(0.45, 0.34, 0.42)],
	[8.0, Color(0.34, 0.5, 0.76), Color(0.74, 0.76, 0.78), Color(1.0, 0.97, 0.92), Color(0.6, 0.62, 0.68)],
	[12.0, Color(0.27, 0.45, 0.78), Color(0.66, 0.74, 0.82), Color(1.0, 1.0, 1.0), Color(0.62, 0.66, 0.74)],
	[16.5, Color(0.3, 0.45, 0.74), Color(0.76, 0.73, 0.68), Color(1.0, 0.95, 0.86), Color(0.6, 0.58, 0.62)],
	[18.3, Color(0.25, 0.26, 0.45), Color(0.96, 0.52, 0.3), Color(1.0, 0.62, 0.38), Color(0.42, 0.27, 0.32)],
	[19.6, Color(0.07, 0.07, 0.18), Color(0.3, 0.18, 0.24), Color(0.36, 0.23, 0.28), Color(0.11, 0.09, 0.14)],
	[21.0, Color(0.02, 0.03, 0.08), Color(0.07, 0.08, 0.15), Color(0.2, 0.21, 0.28), Color(0.06, 0.06, 0.1)],
	[24.0, Color(0.02, 0.03, 0.08), Color(0.07, 0.08, 0.15), Color(0.2, 0.21, 0.28), Color(0.06, 0.06, 0.1)],
]
## Niebla por hora: [hora, densidad, densidad en altura (valles), bruma baja 0..1].
const FOG := [
	[0.0, 0.042, 0.12, 0.35],
	[4.5, 0.05, 0.16, 0.5],
	[6.5, 0.062, 0.3, 1.0],
	[9.0, 0.032, 0.12, 0.35],
	[11.0, 0.022, 0.04, 0.08],
	[16.0, 0.022, 0.04, 0.05],
	[18.5, 0.03, 0.08, 0.2],
	[20.5, 0.04, 0.12, 0.35],
	[24.0, 0.042, 0.12, 0.35],
]
const FOG_HEIGHT := 1.2 ## Por debajo de esta altura la niebla se espesa.

var enabled := false
var _env: Environment
var _sky_mat: ShaderMaterial
var _rings: Node3D
var _ring_mats: Array[ShaderMaterial] = []
var _mist_mat: ShaderMaterial
var _mist: MultiMeshInstance3D
var _noise: NoiseTexture2D


func setup(env: Environment) -> void:
	_env = env
	_noise = NoiseTexture2D.new()
	_noise.width = 128
	_noise.height = 128
	_noise.seamless = true
	var fn := FastNoiseLite.new()
	fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fn.frequency = 0.03
	fn.fractal_octaves = 4
	fn.seed = 1403
	_noise.noise = fn

	_sky_mat = ShaderMaterial.new()
	_sky_mat.shader = load("res://shaders/ps1_sky.gdshader")
	_sky_mat.set_shader_parameter("cloud_noise", _noise)
	var sky := Sky.new()
	sky.sky_material = _sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	env.sky = sky
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.fog_sky_affect = 0.0 # El cielo hace su propia bruma en el horizonte.
	env.fog_height = FOG_HEIGHT

	_build_rings()
	_build_mist()
	set_enabled(false)


func set_enabled(on: bool) -> void:
	enabled = on
	_env.background_mode = Environment.BG_SKY if on else Environment.BG_COLOR
	_env.fog_height_density = 0.0
	_rings.visible = on
	_mist.visible = on


## Llamar cada fotograma. `toward_sun`: dirección hacia el sol (o hacia la luna).
func update(hour: float, daylight: float, toward_sun: Vector3, sun_up: bool) -> void:
	if not enabled:
		return
	var cam := get_viewport().get_camera_3d()
	if cam:
		_rings.global_position = cam.global_position

	var p := _palette(hour)
	var top: Color = p[0]
	var horizon: Color = p[1]
	_sky_mat.set_shader_parameter("sky_top", top)
	_sky_mat.set_shader_parameter("sky_horizon", horizon)
	_sky_mat.set_shader_parameter("ground_color", horizon.lerp(Color(0.16, 0.2, 0.16), 0.45) * lerpf(0.4, 1.0, daylight))
	_sky_mat.set_shader_parameter("cloud_lit", p[2])
	_sky_mat.set_shader_parameter("cloud_shade", p[3])
	_sky_mat.set_shader_parameter("sun_dir", toward_sun if sun_up else -toward_sun)
	_sky_mat.set_shader_parameter("sun_visible", 1.0 if sun_up else 0.0)
	_sky_mat.set_shader_parameter("moon_visible", 0.0 if sun_up else 1.0)
	_sky_mat.set_shader_parameter("sun_color", Color(1.0, 0.62, 0.38).lerp(Color(1.0, 0.95, 0.82), daylight))
	# Estrellas: aparecen ya entrada la noche y se van antes del alba.
	var night := smoothstep(19.3, 20.6, hour) if hour > 12.0 else 1.0 - smoothstep(4.4, 5.6, hour)
	_sky_mat.set_shader_parameter("night", night)
	# Nubosidad que cambia poco a poco de un día para otro.
	var cover := 0.42 + 0.14 * sin(Economy.day * 1.7 + hour * 0.12)
	_sky_mat.set_shader_parameter("cloud_cover", cover)

	var f := _fog(hour)
	# La niebla es del color del horizonte pero más pálida (la bruma real es blanquecina).
	var fog_color := horizon.lerp(Color(0.62, 0.66, 0.72) * (horizon.get_luminance() / 0.66), 0.45)
	_env.fog_light_color = fog_color
	_env.fog_density = f[0]
	_env.fog_height_density = f[1]
	_env.background_color = horizon
	_sky_mat.set_shader_parameter("sky_horizon", horizon.lerp(fog_color, 0.5))

	# Los anillos se pierden en la niebla igual que lo que hay delante de ellos.
	var fade := exp(-f[0] * 45.0)
	for i in _ring_mats.size():
		_ring_mats[i].set_shader_parameter("haze_color", fog_color)
		_ring_mats[i].set_shader_parameter("haze", 1.0 - fade * (0.7 if i == 0 else 0.95))
		_ring_mats[i].set_shader_parameter("land_color",
			(Color(0.26, 0.31, 0.4) if i == 0 else Color(0.13, 0.19, 0.13)) * lerpf(0.35, 1.0, daylight))

	_mist_mat.set_shader_parameter("opacity", f[2] * 0.75)
	_mist_mat.set_shader_parameter("mist_color", fog_color.lerp(Color(0.9, 0.92, 0.95) * lerpf(0.25, 1.0, daylight), 0.4))


func _palette(hour: float) -> Array:
	for i in PALETTE.size() - 1:
		var a: Array = PALETTE[i]
		var b: Array = PALETTE[i + 1]
		if hour >= a[0] and hour <= b[0]:
			var t: float = (hour - a[0]) / (b[0] - a[0])
			return [(a[1] as Color).lerp(b[1], t), (a[2] as Color).lerp(b[2], t),
				(a[3] as Color).lerp(b[3], t), (a[4] as Color).lerp(b[4], t)]
	return PALETTE[0].slice(1)


func _fog(hour: float) -> Array:
	for i in FOG.size() - 1:
		var a: Array = FOG[i]
		var b: Array = FOG[i + 1]
		if hour >= a[0] and hour <= b[0]:
			var t: float = (hour - a[0]) / (b[0] - a[0])
			return [lerpf(a[1], b[1], t), lerpf(a[2], b[2], t), lerpf(a[3], b[3], t)]
	return FOG[0].slice(1)


# --- Horizonte -------------------------------------------------------------------

func _build_rings() -> void:
	_rings = Node3D.new()
	_rings.name = "HorizonRings"
	add_child(_rings)
	# La cámara solo dibuja hasta 60 m (distancia corta de PS1): los anillos van
	# justo por dentro de ese límite.
	# [radio, altura sobre los ojos, profundidad bajo los ojos, repeticiones, bruma, tipo]
	for spec: Array in [[58.0, 8.0, 24.0, 3, 0.7, "montes"], [54.0, 4.5, 22.0, 5, 0.5, "bosque"]]:
		var mat := ShaderMaterial.new()
		mat.shader = load("res://shaders/ps1_horizon.gdshader")
		mat.set_shader_parameter("silhouette", _silhouette(spec[5], spec[1] / (spec[1] + spec[2])))
		mat.set_shader_parameter("haze", spec[4])
		var mi := MeshInstance3D.new()
		mi.mesh = _ring_mesh(spec[0], spec[1], -spec[2], spec[3])
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 400.0
		_rings.add_child(mi)
		_ring_mats.append(mat)


func _ring_mesh(radius: float, top: float, bottom: float, repeats: int, segments := 64) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in segments:
		var a0 := TAU * i / segments
		var a1 := TAU * (i + 1) / segments
		var u0 := float(i) / segments * repeats
		var u1 := float(i + 1) / segments * repeats
		var p0 := Vector3(cos(a0), 0, sin(a0)) * radius
		var p1 := Vector3(cos(a1), 0, sin(a1)) * radius
		var quad := [
			[p0 + Vector3(0, top, 0), Vector2(u0, 0)], [p1 + Vector3(0, top, 0), Vector2(u1, 0)],
			[p1 + Vector3(0, bottom, 0), Vector2(u1, 1)], [p0 + Vector3(0, bottom, 0), Vector2(u0, 1)],
		]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_uv(quad[idx][1])
			st.add_vertex(quad[idx][0])
	return st.commit()


## Silueta en una textura (alfa = sólido, rojo = luz). `horizon_v`: dónde cae la
## línea del horizonte (altura de los ojos) en la textura.
func _silhouette(kind: String, horizon_v: float) -> ImageTexture:
	var w := 512
	var h := 128
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77 if kind == "montes" else 91
	var phases := []
	for i in 6:
		phases.append(rng.randf() * TAU)
	var horizon_px := horizon_v * h
	for x in w:
		var u := float(x) / w
		var top: float
		if kind == "montes":
			# Cordillera suave: senos de frecuencias enteras (la textura se repite sin costura).
			var m := 0.55 * sin(u * TAU * 2.0 + phases[0]) + 0.3 * sin(u * TAU * 5.0 + phases[1]) \
				+ 0.15 * sin(u * TAU * 11.0 + phases[2])
			top = horizon_px * (0.45 - m * 0.42)
		else:
			# Lomas con copas de árboles: bultos pequeños y alguna punta de pino.
			var hill := 0.5 * sin(u * TAU * 3.0 + phases[3]) + 0.3 * sin(u * TAU * 7.0 + phases[4])
			var crowns := absf(sin(u * TAU * 61.0 + phases[5])) * 0.35 + absf(sin(u * TAU * 97.0)) * 0.2
			var pine := 0.5 if fmod(u * 173.0, 1.0) < 0.12 else 0.0
			top = horizon_px * (0.6 - hill * 0.3 - crowns - pine)
		top = clampf(top, 1.0, h - 1.0)
		for y in h:
			if y >= top:
				var light := clampf(1.0 - (y - top) / (h * 0.25), 0.0, 1.0)
				img.set_pixel(x, y, Color(light, 0, 0, 1))
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)


# --- Niebla baja -------------------------------------------------------------------

func _build_mist() -> void:
	_mist_mat = ShaderMaterial.new()
	_mist_mat.shader = load("res://shaders/ps1_mist.gdshader")
	_mist_mat.set_shader_parameter("noise", _noise)
	var spots: Array[Vector3] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 6
	# A lo largo del río.
	var z := -44.0
	while z <= 44.0:
		var x := Countryside.river_x(z) + rng.randf_range(-1.5, 1.5)
		spots.append(Vector3(x, -0.6 + 1.0, z))
		z += rng.randf_range(5.5, 8.0)
	# En los claros de los bosques.
	for ff: Vector3 in Countryside.FOREST_FLOORS:
		for i in 6:
			var a := rng.randf() * TAU
			var r := rng.randf_range(0.0, ff.z * 0.85)
			var px := ff.x + cos(a) * r
			var pz := ff.y + sin(a) * r
			spots.append(Vector3(px, Countryside.height(px, pz) + 1.1, pz))
	# Unos pocos en los prados y campos.
	for rect: Rect2 in Countryside.FIELDS + [Countryside.PASTURE]:
		for i in 2:
			var px := rng.randf_range(rect.position.x, rect.end.x)
			var pz := rng.randf_range(rect.position.y, rect.end.y)
			spots.append(Vector3(px, Countryside.height(px, pz) + 1.0, pz))

	var quad := QuadMesh.new()
	quad.size = Vector2(10.0, 2.6)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = quad
	mm.instance_count = spots.size()
	for i in spots.size():
		mm.set_instance_transform(i, Transform3D(Basis(), spots[i]))
	_mist = MultiMeshInstance3D.new()
	_mist.name = "MistBanks"
	_mist.multimesh = mm
	_mist.material_override = _mist_mat
	_mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mist.extra_cull_margin = 8.0
	add_child(_mist)
