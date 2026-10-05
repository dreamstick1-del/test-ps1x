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
	# Foto de lado: se recortan hojas con transparencia para matas y arbustos.
	"tallgrass": {"src": "tallgrass_photo.jpg", "crop": Rect2(0.0, 0.42, 1.0, 0.56), "size": 256,
		"blades": 90},
	"gravel": {"src": "gravel_photo.jpg", "crop": Rect2(0.0, 0.05, 0.68, 0.8), "size": 256,
		"normal": 7.0, "equalize": 0.8},
	# Fotos de hojas desde arriba: los huecos oscuros entre hojas se vuelven
	# transparentes y se recorta una silueta redonda de mata.
	"shrub": {"src": "shrub_photo.jpg", "crop": Rect2(0.15, 0.5, 0.7, 0.48), "size": 256, "leaves": 0.17},
	"purple": {"src": "purple_photo.jpg", "crop": Rect2(0.1, 0.25, 0.8, 0.6), "size": 256, "leaves": 0.11},
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
	if p.has("leaves"):
		_make_leaves(name, img, size, p.leaves)
		return
	if p.has("blades"):
		_make_blades(name, img, size, p.blades)
		return
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


## Recorta hojas de hierba con transparencia: dibuja N hojas (triángulos largos
## y curvados que salen del suelo) y cada píxel de hoja toma el color de la foto.
## Abajo más oscuro (sombra entre los tallos), puntas a veces secas como en la foto.
## La mata queda centrada y no toca los bordes laterales de la textura.
func _make_blades(name: String, photo: Image, size: int, count: int) -> void:
	var out := Image.create(size, size, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var avg := Color(0, 0, 0)
	for y in size:
		for x in size:
			avg += photo.get_pixel(x, y)
	avg /= float(size * size)
	for i in count:
		# Mata en abanico: las hojas nacen cerca del centro y se abren hacia
		# los lados; las de fuera son más bajas. Así ninguna toca el borde.
		var spread := rng.randf_range(-1.0, 1.0)
		var base_x := size * (0.5 + spread * 0.14)
		var height := rng.randf_range(0.55, 0.98) * size * (1.0 - absf(spread) * 0.35)
		var width := rng.randf_range(3.0, 8.0)
		var lean := spread * rng.randf_range(0.25, 0.5) * height
		var dry_tip := rng.randf() < 0.3
		for yy in int(height):
			var t := float(yy) / height # 0 abajo, 1 punta
			var cx := base_x + lean * t * t
			var half := width * (1.0 - t) * 0.5 + 0.35
			for xx in range(int(cx - half - 1), int(cx + half + 2)):
				if absf(xx + 0.5 - cx) > half:
					continue
				var px := posmod(xx, size)
				var py := size - 1 - yy
				var c := photo.get_pixel(px, py)
				# Fuera reflejos raros (blancos/morados): hacia el verde medio de la foto.
				var off := absf(c.r - c.g) + absf(c.b - c.g * 0.6)
				c = c.lerp(avg, clampf(0.25 + off, 0.0, 0.8))
				c = c.darkened(0.45 * (1.0 - t) * (1.0 - t))
				if dry_tip and t > 0.8:
					c = c.lerp(Color(0.55, 0.36, 0.2), 0.7)
				out.set_pixel(px, py, Color(c.r, c.g, c.b, 1.0))
	out.save_png(ProjectSettings.globalize_path("res://assets/textures/%s_albedo.png" % name))
	print("Textura '%s' (hojas recortadas) generada desde %s" % [name, PRESETS[name].src])


## Mata de hojas: alfa = hoja (más clara que el hueco oscuro entre hojas)
## dentro de una silueta redondeada de borde irregular, más plana por abajo.
func _make_leaves(name: String, photo: Image, size: int, threshold: float) -> void:
	var out := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 3
	noise.frequency = 0.035
	for y in size:
		for x in size:
			var c := photo.get_pixel(x, y)
			var lum := c.get_luminance()
			# Silueta: elipse con el borde mordido por ruido, apoyada abajo.
			var u := (x + 0.5) / size * 2.0 - 1.0
			var v := (y + 0.5) / size * 2.0 - 1.0
			var r := Vector2(u, (v - 0.12) * 1.15).length() + noise.get_noise_2d(x, y) * 0.28
			var inside := r < 0.9 and y < size - 2
			var leaf := lum > threshold
			# Más sombra hacia el centro-bajo de la mata (oclusión falsa).
			var shade := 1.0 - clampf(v, 0.0, 1.0) * 0.35
			# El corazón de la mata es macizo: los huecos se ven como sombra.
			var core := r < 0.55
			if core and not leaf:
				shade *= 0.45
			out.set_pixel(x, y, Color(c.r * shade, c.g * shade, c.b * shade, 1.0 if inside and (leaf or core) else 0.0))
	out.save_png(ProjectSettings.globalize_path("res://assets/textures/%s_albedo.png" % name))
	print("Textura '%s' (hojas recortadas) generada desde %s" % [name, PRESETS[name].src])


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
