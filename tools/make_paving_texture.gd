extends SceneTree
## Herramienta: convierte una foto de suelo en una textura de losa repetible
## con mapa de relieve (normal map).
##
##   godot --headless --path . -s tools/make_paving_texture.gd
##
## Entrada:  assets/textures/source/paving_photo.jpg
## Salida:   assets/textures/paving_albedo.png  (color, 256x256, sin costuras)
##           assets/textures/paving_normal.png  (relieve sacado de la luminancia)

const SRC := "res://assets/textures/source/paving_photo.jpg"
const SIZE := 256
## Zona de la foto que es superficie de losa (sin juntas), en fracciones.
const CROP := Rect2(0.13, 0.22, 0.80, 0.44)


func _init() -> void:
	var photo := Image.load_from_file(ProjectSettings.globalize_path(SRC))
	photo.convert(Image.FORMAT_RGB8)
	var r := Rect2i(Vector2i(CROP.position * Vector2(photo.get_size())), Vector2i(CROP.size * Vector2(photo.get_size())))
	var crop := photo.get_region(r)
	crop.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
	_equalize(crop)
	var albedo := _make_seamless(crop)
	albedo.save_png(ProjectSettings.globalize_path("res://assets/textures/paving_albedo.png"))

	# Relieve: luminancia -> altura (los poros oscuros son huecos) -> normales.
	var height := albedo.duplicate() as Image
	height.convert(Image.FORMAT_L8)
	height.convert(Image.FORMAT_RGBA8)
	height.bump_map_to_normal_map(6.0)
	height.save_png(ProjectSettings.globalize_path("res://assets/textures/paving_normal.png"))
	print("Textura de losa generada desde ", SRC)
	quit()


## Quita el degradado de luz de la foto (una zona mojada más oscura que otra):
## divide cada píxel por el brillo medio de su entorno.
func _equalize(img: Image) -> void:
	var blur := img.duplicate() as Image
	blur.resize(8, 8, Image.INTERPOLATE_BILINEAR)
	blur.resize(SIZE, SIZE, Image.INTERPOLATE_BILINEAR)
	var mean := Color(0, 0, 0)
	for y in SIZE:
		for x in SIZE:
			mean += img.get_pixel(x, y)
	mean /= float(SIZE * SIZE)
	for y in SIZE:
		for x in SIZE:
			var c := img.get_pixel(x, y)
			var b := blur.get_pixel(x, y)
			img.set_pixel(x, y, Color(
				clampf(c.r / maxf(b.r, 0.02) * mean.r, 0, 1),
				clampf(c.g / maxf(b.g, 0.02) * mean.g, 0, 1),
				clampf(c.b / maxf(b.b, 0.02) * mean.b, 0, 1)))


## Hace la imagen repetible: mezcla con su copia desplazada media imagen,
## usando la copia solo cerca de los bordes.
func _make_seamless(img: Image) -> Image:
	var out := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	var h := SIZE / 2
	for y in SIZE:
		for x in SIZE:
			var a := img.get_pixel(x, y)
			var b := img.get_pixel((x + h) % SIZE, (y + h) % SIZE)
			var dx := absf(float(x) - h) / h
			var dy := absf(float(y) - h) / h
			var w := clampf(maxf(dx, dy) * 1.6 - 0.6, 0.0, 1.0) # 0 en el centro, 1 en el borde
			out.set_pixel(x, y, a.lerp(b, w))
	return out
