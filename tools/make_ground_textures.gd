extends SceneTree
## Herramienta: convierte fotos de suelo en texturas repetibles con relieve.
##
##   godot --headless --path . -s tools/make_ground_textures.gd
##
## Por cada entrada de PRESETS lee assets/textures/source/<src>, recorta la zona
## útil, quita el degradado de luz, la hace repetible (sin costuras) y guarda:
##   assets/textures/<name>_albedo.png  color (RGB) + máscara en alfa (opcional)
##   assets/textures/<name>_normal.png  relieve sacado de la luminancia
##
## Máscara "dryness" (pasto): alfa = cuánto de seco/marrón tiene cada píxel.
## El shader del terreno la usa para hacer variantes (verde, seco, barro)
## a partir de una sola foto.

const PRESETS := {
	"paving": {"src": "paving_photo.jpg", "crop": Rect2(0.13, 0.22, 0.80, 0.44), "size": 256,
		"normal": 6.0, "equalize": 1.0},
	"grass": {"src": "grass_photo.jpg", "crop": Rect2(0.0, 0.0, 1.0, 1.0), "size": 256,
		"normal": 4.0, "equalize": 0.7, "mask": "dryness"},
}


func _init() -> void:
	var only := OS.get_cmdline_user_args()
	for name: String in PRESETS:
		if only.is_empty() or name in only:
			_make(name, PRESETS[name])
	quit()


func _make(name: String, p: Dictionary) -> void:
	var size: int = p.size
	var photo := Image.load_from_file(ProjectSettings.globalize_path("res://assets/textures/source/" + p.src))
	photo.convert(Image.FORMAT_RGB8)
	var crop_r: Rect2 = p.crop
	var r := Rect2i(Vector2i(crop_r.position * Vector2(photo.get_size())), Vector2i(crop_r.size * Vector2(photo.get_size())))
	var img := photo.get_region(r)
	img.resize(size, size, Image.INTERPOLATE_LANCZOS)
	_equalize(img, size, p.get("equalize", 1.0))
	var albedo := _make_seamless(img, size)

	if p.get("mask", "") == "dryness":
		albedo.convert(Image.FORMAT_RGBA8)
		for y in size:
			for x in size:
				var c := albedo.get_pixel(x, y)
				# Verde = hoja viva; marrón/gris = seco. 0 = muy verde, 1 = seco.
				var green := c.g - (c.r + c.b) * 0.5
				c.a = clampf(1.0 - green * 9.0, 0.0, 1.0)
				albedo.set_pixel(x, y, c)

	albedo.save_png(ProjectSettings.globalize_path("res://assets/textures/%s_albedo.png" % name))
	var height := albedo.duplicate() as Image
	height.convert(Image.FORMAT_L8)
	height.convert(Image.FORMAT_RGBA8)
	height.bump_map_to_normal_map(p.normal)
	height.save_png(ProjectSettings.globalize_path("res://assets/textures/%s_normal.png" % name))
	print("Textura '%s' generada desde %s" % [name, p.src])


## Quita el degradado de luz de la foto: divide cada píxel por el brillo medio
## de su entorno (strength 0 = no tocar, 1 = aplanar del todo).
func _equalize(img: Image, size: int, strength: float) -> void:
	var blur := img.duplicate() as Image
	blur.resize(8, 8, Image.INTERPOLATE_BILINEAR)
	blur.resize(size, size, Image.INTERPOLATE_BILINEAR)
	var mean := Color(0, 0, 0)
	for y in size:
		for x in size:
			mean += img.get_pixel(x, y)
	mean /= float(size * size)
	for y in size:
		for x in size:
			var c := img.get_pixel(x, y)
			var b := blur.get_pixel(x, y)
			var flat := Color(
				clampf(c.r / maxf(b.r, 0.02) * mean.r, 0, 1),
				clampf(c.g / maxf(b.g, 0.02) * mean.g, 0, 1),
				clampf(c.b / maxf(b.b, 0.02) * mean.b, 0, 1))
			img.set_pixel(x, y, c.lerp(flat, strength))


## Hace la imagen repetible: mezcla con su copia desplazada media imagen,
## usando la copia solo cerca de los bordes.
func _make_seamless(img: Image, size: int) -> Image:
	var out := Image.create(size, size, false, Image.FORMAT_RGB8)
	var h := size / 2
	for y in size:
		for x in size:
			var a := img.get_pixel(x, y)
			var b := img.get_pixel((x + h) % size, (y + h) % size)
			var dx := absf(float(x) - h) / h
			var dy := absf(float(y) - h) / h
			var w := clampf(maxf(dx, dy) * 1.6 - 0.6, 0.0, 1.0) # 0 en el centro, 1 en el borde
			out.set_pixel(x, y, a.lerp(b, w))
	return out
