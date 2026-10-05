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
	# Hojas sueltas fotografiadas sobre un dedo: se recortan (PNG con alfa) y se
	# estampan muchas veces para formar un racimo de copa de árbol.
	# Silueta de pino (abeto) con pisos de ramas caídas hechas de miles de agujas;
	# el color sale de la foto de pasto, oscurecido hacia verde azulado.
	"pine": {"src": "grass_photo.jpg", "crop": Rect2(0, 0, 1, 1), "size": 256, "needles": 9000},
	"leafcluster": {"src": "leaf_front_photo.jpg", "srcs": ["leaf_front_photo.jpg", "leaf_back_photo.jpg"],
		"crop": Rect2(0, 0, 1, 1), "size": 256, "cluster": 130},
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
	if p.has("needles"):
		_make_pine(name, img, size, p.needles)
		return
	if p.has("cluster"):
		_make_cluster(name, p)
		return
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


## ¿Está (u, v) dentro de la silueta de abeto? u, v en 0..1 (v = 0 arriba).
## Cinco pisos de ramas: cada piso se ensancha hacia abajo y acaba en un borde
## ondulado; el árbol entero se ensancha con la altura.
func _pine_halfwidth(v: float) -> float:
	var tiers := 5.0
	var f := fmod(v * tiers, 1.0)
	return (0.08 + 0.92 * v) * 0.47 * (0.4 + 0.6 * f)


func _make_pine(name: String, photo: Image, size: int, needles: int) -> void:
	var out := Image.create(size, size, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	# Tronco al centro.
	for y in range(int(size * 0.15), size):
		for x in range(size / 2 - 2, size / 2 + 2):
			out.set_pixel(x, y, Color(0.22, 0.14, 0.09))
	var drawn := 0
	var tries := 0
	while drawn < needles and tries < needles * 6:
		tries += 1
		var v := rng.randf_range(0.02, 0.97)
		var u := rng.randf()
		var hw := _pine_halfwidth(v)
		if absf(u - 0.5) > hw:
			continue
		drawn += 1
		# Color: un píxel verde de la foto, oscurecido hacia verde azulado. Las
		# agujas de dentro (cerca del tronco y del techo de cada piso) más oscuras.
		var c := photo.get_pixel(rng.randi() % size, rng.randi() % size)
		var inner := 1.0 - absf(u - 0.5) / maxf(hw, 0.01)
		var tier_f := fmod(v * 5.0, 1.0)
		var light := lerpf(0.95, 0.45, inner * 0.6 + (1.0 - tier_f) * 0.4) * rng.randf_range(0.85, 1.1)
		var col := Color(c.r * 0.32 * light, (c.g * 0.6 + 0.05) * light, c.b * 0.55 * light + 0.04, 1.0)
		# Aguja: trazo corto que cae hacia fuera.
		var side := signf(u - 0.5)
		var dir := Vector2(side * rng.randf_range(0.6, 1.0), rng.randf_range(0.3, 0.8)).normalized()
		var length := rng.randf_range(4.0, 9.0)
		var start := Vector2(u * size, v * size)
		for k in int(length):
			var q := start + dir * k
			var px := int(q.x)
			var py := int(q.y)
			if px >= 0 and py >= 0 and px < size and py < size:
				out.set_pixel(px, py, col)
	out.save_png(ProjectSettings.globalize_path("res://assets/textures/%s_albedo.png" % name))
	print("Textura '%s' (%d agujas) generada desde %s" % [name, drawn, PRESETS[name].src])


## Recorta la hoja de una foto: verde = hoja; piel (rojiza) y fondo gris fuera.
## Devuelve la hoja recortada a su caja, con alfa, a `target` px de alto.
func _cut_leaf(src: String, target: int) -> Image:
	var photo := Image.load_from_file(ProjectSettings.globalize_path("res://assets/textures/source/" + src))
	photo.convert(Image.FORMAT_RGBA8)
	photo.resize(photo.get_width() / 4, photo.get_height() / 4, Image.INTERPOLATE_BILINEAR)
	var w := photo.get_width()
	var h := photo.get_height()
	var cols := PackedInt32Array()
	var rows := PackedInt32Array()
	cols.resize(w)
	rows.resize(h)
	for y in h:
		for x in w:
			var c := photo.get_pixel(x, y)
			# Hoja: verde (o verde amarillento) claramente por encima del azul y sin
			# el rojo de la piel. El fondo gris tiene verde y azul parecidos.
			var leaf := c.g - c.b > 0.15 and c.g > c.r - 0.03
			photo.set_pixel(x, y, Color(c.r, c.g, c.b, 1.0 if leaf else 0.0))
			if leaf:
				cols[x] += 1
				rows[y] += 1
	# Caja = filas/columnas con bastante hoja (ignora motas verdes sueltas).
	var minx := _first_over(cols, 0.12, false)
	var maxx := _first_over(cols, 0.12, true)
	var miny := _first_over(rows, 0.12, false)
	var maxy := _first_over(rows, 0.12, true)
	var leaf_img := photo.get_region(Rect2i(minx, miny, maxx - minx + 1, maxy - miny + 1))
	var scale := float(target) / leaf_img.get_height()
	leaf_img.resize(maxi(1, int(leaf_img.get_width() * scale)), target, Image.INTERPOLATE_BILINEAR)
	leaf_img.save_png(ProjectSettings.globalize_path("res://assets/textures/leaf_%s.png" % src.get_basename().replace("_photo", "")))
	return leaf_img


func _first_over(counts: PackedInt32Array, fraction: float, from_end: bool) -> int:
	var peak := 0
	for c in counts:
		peak = maxi(peak, c)
	var n := counts.size()
	for i in n:
		var idx := n - 1 - i if from_end else i
		if counts[idx] > peak * fraction:
			return idx
	return 0


## Racimo de hojas para copas: estampa N hojas (anverso y reverso) giradas y
## de tamaños distintos dentro de una silueta redonda. Las del fondo, más
## oscuras (sombra interior de la copa); las de delante, más claras.
func _make_cluster(name: String, p: Dictionary) -> void:
	var size: int = p.size
	var leaves: Array[Image] = []
	for src: String in p.srcs:
		leaves.append(_cut_leaf(src, 44))
	var out := Image.create(size, size, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var count: int = p.cluster
	for i in count:
		var depth := float(i) / count # 0 = fondo, 1 = delante
		var a := rng.randf() * TAU
		var rad := pow(rng.randf(), 0.7) * size * 0.36
		var center := Vector2(size, size) * 0.5 + Vector2(cos(a), sin(a) * 0.9) * rad
		var leaf: Image = leaves[0] if rng.randf() < 0.7 else leaves[1]
		var scale := rng.randf_range(0.7, 1.15)
		var rot := rng.randf() * TAU
		var light := lerpf(0.45, 1.1, depth) * rng.randf_range(0.9, 1.1)
		_stamp(out, leaf, center, rot, scale, light)
	out.save_png(ProjectSettings.globalize_path("res://assets/textures/%s_albedo.png" % name))
	print("Textura '%s' (racimo de %d hojas) generada desde %s" % [name, count, ", ".join(p.srcs)])


func _stamp(out: Image, leaf: Image, center: Vector2, rot: float, scale: float, light: float) -> void:
	var lw := leaf.get_width() * scale
	var lh := leaf.get_height() * scale
	var r := ceili(Vector2(lw, lh).length() * 0.5)
	var cs := cos(-rot)
	var sn := sin(-rot)
	for y in range(int(center.y) - r, int(center.y) + r):
		for x in range(int(center.x) - r, int(center.x) + r):
			if x < 0 or y < 0 or x >= out.get_width() or y >= out.get_height():
				continue
			var d := Vector2(x, y) - center
			var u := (d.x * cs - d.y * sn) / scale + leaf.get_width() * 0.5
			var v := (d.x * sn + d.y * cs) / scale + leaf.get_height() * 0.5
			if u < 0 or v < 0 or u >= leaf.get_width() or v >= leaf.get_height():
				continue
			var c := leaf.get_pixel(int(u), int(v))
			if c.a < 0.5:
				continue
			out.set_pixel(x, y, Color(c.r * light, c.g * light, c.b * light, 1.0))


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
