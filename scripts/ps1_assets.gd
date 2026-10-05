class_name PS1Assets
extends RefCounted
## Fábrica de texturas procedurales de 32x32 (filtrado Nearest) y materiales PS1.
## Así el proyecto funciona sin assets externos; sustituye cualquier textura por
## una tuya pintada a mano manteniendo el mismo material.

const SHADER := preload("res://shaders/ps1_spatial.gdshader")
const VIEWMODEL_SHADER := preload("res://shaders/ps1_viewmodel.gdshader")
const TEX_SIZE := 32

static var _textures := {}
static var _boxes := {}
static var _colored_boxes := {}
static var _flat_markers := {}
static var _vertex_color_flat: ShaderMaterial
static var _viewmodel_flat: ShaderMaterial
static var _materials := {}


## BoxMesh compartido por tamaño: miles de cajas iguales usan un solo búfer
## en la GPU (imprescindible en WebGL).
static func box(size: Vector3) -> BoxMesh:
	var key := size.snappedf(0.001)
	if not _boxes.has(key):
		var m := BoxMesh.new()
		m.size = key
		_boxes[key] = m
	return _boxes[key]


## Material PS1 con textura procedural. world_uv tilea la textura en espacio mundo
## (uv_scale = repeticiones por unidad).
static func material(tex_name: String, tint := Color.WHITE, uv_scale := Vector2(0.5, 0.5),
		world_uv := true, emission := 0.0) -> ShaderMaterial:
	var key := "%s|%s|%s|%s|%s" % [tex_name, tint.to_html(), uv_scale, world_uv, emission]
	if _materials.has(key):
		return _materials[key]
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("albedo", tint)
	mat.set_shader_parameter("uv_scale", uv_scale)
	mat.set_shader_parameter("world_uv", world_uv)
	mat.set_shader_parameter("emission_strength", emission)
	if tex_name != "":
		mat.set_shader_parameter("albedo_texture", texture(tex_name))
	_materials[key] = mat
	return mat


## Color plano (personajes, detalles). Devuelve un "marcador" ligero que solo
## lleva el color: setup_box() lo convierte en una caja con el color en los
## vértices y un único material compartido. WebGL deja de dibujar si hay más de
## un centenar de materiales distintos, así que nunca se crea uno por color.
## Para mallas que no son cajas, resolve() da el material real.
static func flat(color: Color, emission := 0.0) -> Material:
	var key := "%s|%s" % [color.to_html(), emission]
	if not _flat_markers.has(key):
		var marker := ShaderMaterial.new() # Sin shader: no ocupa nada en la GPU.
		marker.set_meta("flat_color", color)
		marker.set_meta("flat_emission", emission)
		_flat_markers[key] = marker
	return _flat_markers[key]


## Material real para un marcador de flat(); cualquier otro material pasa tal cual.
static func resolve(mat: Material) -> Material:
	if mat == null or not mat.has_meta("flat_color"):
		return mat
	return material("", mat.get_meta("flat_color"), Vector2.ONE, false, mat.get_meta("flat_emission"))


## Asigna malla y material a una caja. Las de color plano comparten material.
static func setup_box(mi: MeshInstance3D, size: Vector3, mat: Material) -> void:
	if mat and mat.has_meta("flat_color") and float(mat.get_meta("flat_emission")) == 0.0:
		mi.mesh = colored_box(size, mat.get_meta("flat_color"))
		mi.material_override = vertex_color_flat()
	else:
		mi.mesh = box(size)
		mi.material_override = resolve(mat)


## Caja con el color horneado en los vértices (en lineal, como hacía source_color).
static func colored_box(size: Vector3, color: Color) -> ArrayMesh:
	var key := "%s|%s" % [size.snappedf(0.001), color.to_html()]
	if not _colored_boxes.has(key):
		var arrays := box(size).get_mesh_arrays()
		var colors := PackedColorArray()
		colors.resize((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
		colors.fill(color.srgb_to_linear())
		arrays[Mesh.ARRAY_COLOR] = colors
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		_colored_boxes[key] = mesh
	return _colored_boxes[key]


static func vertex_color_flat() -> ShaderMaterial:
	if _vertex_color_flat == null:
		_vertex_color_flat = vertex_colored("", Vector2.ONE, false)
	return _vertex_color_flat


## Versión para el arma en primera persona (sin test de profundidad).
static func viewmodel_vertex_color() -> ShaderMaterial:
	if _viewmodel_flat == null:
		_viewmodel_flat = viewmodel(Color.WHITE)
		_viewmodel_flat.set_shader_parameter("use_vertex_color", true)
	return _viewmodel_flat


## Material PS1 con una textura propia (personajes con UV), sin caché.
static func textured(tex: Texture2D, tint := Color.WHITE) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("albedo", tint)
	mat.set_shader_parameter("albedo_texture", tex)
	mat.set_shader_parameter("world_uv", false)
	return mat


## Material que además multiplica por el color de vértice o de instancia.
static func vertex_colored(tex_name: String, uv_scale := Vector2(0.5, 0.5), world_uv := true) -> ShaderMaterial:
	var mat := material(tex_name, Color.WHITE, uv_scale, world_uv).duplicate() as ShaderMaterial
	mat.set_shader_parameter("use_vertex_color", true)
	return mat


## Material del arma en primera persona (sin test de profundidad).
static func viewmodel(color: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = VIEWMODEL_SHADER
	mat.set_shader_parameter("albedo", color)
	return mat


## Sombra "blob" circular, como las de los juegos de PS1.
static func blob_shadow_material() -> StandardMaterial3D:
	if _materials.has("__blob"):
		return _materials["__blob"]
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.albedo_texture = texture("blob")
	mat.albedo_color = Color(0, 0, 0, 0.55)
	_materials["__blob"] = mat
	return mat


static func texture(tex_name: String) -> Texture2D:
	if _textures.has(tex_name):
		return _textures[tex_name]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(tex_name)
	var img := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGBA8)
	match tex_name:
		"grass": _paint_grass(img, rng)
		"dirt": _paint_dirt(img, rng)
		"cobble": _paint_cobble(img, rng)
		"plaster": _paint_plaster(img, rng)
		"thatch": _paint_thatch(img, rng)
		"shingle": _paint_shingle(img, rng)
		"stone": _paint_stone(img, rng)
		"wood": _paint_wood(img, rng)
		"water": _paint_water(img, rng)
		"blob": _paint_blob(img)
		_:
			img.fill(Color.MAGENTA)
	var tex := ImageTexture.create_from_image(img)
	_textures[tex_name] = tex
	return tex


# --- Pintores ------------------------------------------------------------------

static func _noise_fill(img: Image, rng: RandomNumberGenerator, base: Color, amount: float) -> void:
	for y in TEX_SIZE:
		for x in TEX_SIZE:
			var n := rng.randf_range(-amount, amount)
			img.set_pixel(x, y, Color(base.r + n, base.g + n, base.b + n * 0.6))


static func _paint_grass(img: Image, rng: RandomNumberGenerator) -> void:
	_noise_fill(img, rng, Color(0.30, 0.46, 0.20), 0.05)
	for i in 70:
		var x := rng.randi_range(0, TEX_SIZE - 1)
		var y := rng.randi_range(1, TEX_SIZE - 1)
		var c := Color(0.20, 0.34, 0.13) if rng.randf() < 0.7 else Color(0.48, 0.55, 0.24)
		img.set_pixel(x, y, c)
		img.set_pixel(x, y - 1, c.lightened(0.08))
	for i in 4:
		img.set_pixel(rng.randi_range(0, 31), rng.randi_range(0, 31), Color(0.85, 0.80, 0.35))


static func _paint_dirt(img: Image, rng: RandomNumberGenerator) -> void:
	_noise_fill(img, rng, Color(0.42, 0.32, 0.21), 0.05)
	for i in 30:
		var x := rng.randi_range(0, TEX_SIZE - 2)
		var y := rng.randi_range(0, TEX_SIZE - 2)
		var c := Color(0.55, 0.47, 0.38) if rng.randf() < 0.5 else Color(0.30, 0.22, 0.14)
		img.set_pixel(x, y, c)
		img.set_pixel(x + 1, y, c.darkened(0.15))


static func _paint_cobble(img: Image, rng: RandomNumberGenerator) -> void:
	img.fill(Color(0.25, 0.23, 0.21))
	for row in 4:
		var offset := 4 if row % 2 else 0
		for col in 4:
			var shade := rng.randf_range(0.42, 0.58)
			var x0 := col * 8 + offset
			for y in range(row * 8 + 1, row * 8 + 7):
				for x in range(x0 + 1, x0 + 7):
					var n := rng.randf_range(-0.03, 0.03)
					img.set_pixel(x % TEX_SIZE, y, Color(shade + n, shade + n - 0.02, shade + n - 0.05))


static func _paint_plaster(img: Image, rng: RandomNumberGenerator) -> void:
	# Pared de entramado de madera (fachwerk) típica de Bohemia.
	_noise_fill(img, rng, Color(0.86, 0.80, 0.66), 0.035)
	var beam := Color(0.30, 0.19, 0.11)
	for i in TEX_SIZE:
		for t in 2:
			img.set_pixel(i, t, beam)                # viga superior
			img.set_pixel(i, 15 + t, beam)           # viga media
			img.set_pixel(t, i, beam)                # poste izquierdo
			img.set_pixel(16 + t, i, beam)           # poste central
	for i in 14:
		img.set_pixel(2 + i, 2 + i, beam)            # riostra diagonal
		img.set_pixel(3 + i, 2 + i, beam)


static func _paint_thatch(img: Image, rng: RandomNumberGenerator) -> void:
	for x in TEX_SIZE:
		var col := rng.randf_range(0.0, 0.08)
		for y in TEX_SIZE:
			var band := 0.06 if (y % 8) < 2 else 0.0
			var n := rng.randf_range(-0.03, 0.03) + col - band
			img.set_pixel(x, y, Color(0.62 + n, 0.50 + n, 0.25 + n * 0.5))


static func _paint_shingle(img: Image, rng: RandomNumberGenerator) -> void:
	for y in TEX_SIZE:
		var row := y / 6
		for x in TEX_SIZE:
			var tile := (x + (row % 2) * 4) / 8
			var shade := 0.85 + 0.15 * sin(float(tile * 7 + row * 3))
			var n := rng.randf_range(-0.03, 0.03)
			var c := Color(0.55 * shade + n, 0.22 * shade + n, 0.15 * shade + n)
			if y % 6 == 5 or (x + (row % 2) * 4) % 8 == 0:
				c = c.darkened(0.45)
			img.set_pixel(x, y, c)


static func _paint_stone(img: Image, rng: RandomNumberGenerator) -> void:
	img.fill(Color(0.33, 0.32, 0.30))
	for row in 4:
		var offset := 5 if row % 2 else 0
		for col in 3:
			var shade := rng.randf_range(0.5, 0.66)
			var x0 := col * 11 + offset
			for y in range(row * 8 + 1, row * 8 + 8):
				for x in range(x0 + 1, x0 + 11):
					var n := rng.randf_range(-0.035, 0.035)
					img.set_pixel(x % TEX_SIZE, y, Color(shade + n, shade + n, shade + n - 0.02))


static func _paint_wood(img: Image, rng: RandomNumberGenerator) -> void:
	for y in TEX_SIZE:
		var plank := y / 8
		var base := 0.85 + 0.1 * sin(float(plank * 5))
		for x in TEX_SIZE:
			var grain := 0.05 * sin(float(x) * 0.6 + float(y) * 1.7 + plank)
			var n := rng.randf_range(-0.025, 0.025)
			var c := Color((0.48 + grain + n) * base, (0.33 + grain + n) * base, (0.20 + n) * base)
			if y % 8 == 0:
				c = c.darkened(0.5)
			img.set_pixel(x, y, c)


static func _paint_water(img: Image, rng: RandomNumberGenerator) -> void:
	_noise_fill(img, rng, Color(0.13, 0.25, 0.33), 0.03)
	for i in 12:
		var x := rng.randi_range(0, TEX_SIZE - 4)
		var y := rng.randi_range(0, TEX_SIZE - 1)
		for k in 3:
			img.set_pixel(x + k, y, Color(0.35, 0.50, 0.58))


static func _paint_blob(img: Image) -> void:
	var center := Vector2(TEX_SIZE, TEX_SIZE) * 0.5
	for y in TEX_SIZE:
		for x in TEX_SIZE:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(center) / (TEX_SIZE * 0.5)
			# Escalonado en 4 niveles: nada de degradados suaves.
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = floorf(a * 4.0) / 3.0
			img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
