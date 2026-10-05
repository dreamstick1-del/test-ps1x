class_name Foliage
extends RefCounted
## Matas de hierba alta, juncos, arbustos y plantas de jardín hechos con tarjetas
## cruzadas (planos en estrella con una textura recortada de una foto).
## Los arbustos de hojas llevan además una tarjeta horizontal arriba (copa).
## Todas las matas de un tipo van en un MultiMesh: una sola llamada de dibujo.

const TEXTURES := {
	"hierba": "res://assets/textures/tallgrass_albedo.png",
	"hojas": "res://assets/textures/shrub_albedo.png",
	"morada": "res://assets/textures/purple_albedo.png",
	"copa": "res://assets/textures/leafcluster_albedo.png",
	"pino": "res://assets/textures/pine_albedo.png",
}

## Tipos: tamaño (ancho, alto), tinte y nº de tarjetas.
const KINDS := {
	"mata": {"size": Vector2(1.1, 0.75), "tint": Color(1, 1, 1), "cards": 3},
	"hierba_alta": {"size": Vector2(1.4, 1.2), "tint": Color(1.0, 1.05, 0.95), "cards": 3},
	"junco": {"size": Vector2(0.9, 1.7), "tint": Color(0.85, 0.95, 0.8), "cards": 3},
	"seca": {"size": Vector2(1.0, 0.7), "tint": Color(1.45, 1.15, 0.6), "cards": 3},
	"trigo": {"size": Vector2(0.8, 1.0), "tint": Color(1.7, 1.3, 0.45), "cards": 2},
	"arbusto": {"size": Vector2(1.7, 1.4), "tint": Color(0.8, 0.85, 0.75), "cards": 4, "texture": "hojas", "top": true},
	"seto": {"size": Vector2(1.6, 1.15), "tint": Color(0.9, 0.95, 0.85), "cards": 4, "texture": "hojas", "top": true},
	# Copa de árbol: dos pisos de tarjetas con racimos de hojas (ver Broadleaf).
	"copa": {"size": Vector2(3.6, 2.6), "tint": Color(1, 1, 1), "cards": 8, "texture": "copa",
		"layers": [[Vector2(3.6, 2.6), 1.55, 0.0], [Vector2(2.7, 2.1), 2.75, 0.45]]},
	# Pino: 16 planos (2 pisos de 8) con la silueta de abeto; sin tarjeta arriba.
	"pino": {"size": Vector2(2.8, 4.4), "tint": Color(1, 1, 1), "cards": 8, "texture": "pino", "top": false,
		"layers": [[Vector2(2.9, 4.4), 0.35, 0.0], [Vector2(2.5, 4.0), 0.75, 0.2]]},
	"ornamental": {"size": Vector2(1.35, 0.95), "tint": Color(1, 1, 1), "cards": 4, "texture": "morada", "top": true},
}

static var _materials := {}
static var _meshes := {}


## points: [{pos: Vector3, scale: float, tint: Color (opcional)}]
static func plant(parent: Node3D, kind: String, points: Array) -> MultiMeshInstance3D:
	if points.is_empty():
		return null
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _mesh(kind)
	mm.instance_count = points.size()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind) + points.size()
	var base_tint: Color = KINDS[kind].tint
	for i in points.size():
		var p: Dictionary = points[i]
		var s: float = p.get("scale", 1.0) * rng.randf_range(0.8, 1.2)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.85, 1.2), s))
		mm.set_instance_transform(i, Transform3D(basis, p.pos))
		var shade := rng.randf_range(0.85, 1.1)
		var tint: Color = p.get("tint", base_tint) * shade
		mm.set_instance_color(i, Color(tint.r, tint.g, tint.b, 1.0))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Foliage_" + kind
	mmi.multimesh = mm
	mmi.material_override = material(KINDS[kind].get("texture", "hierba"))
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)
	return mmi


static func material(texture := "hierba") -> ShaderMaterial:
	if not _materials.has(texture):
		var mat := ShaderMaterial.new()
		mat.shader = load("res://shaders/ps1_foliage.gdshader")
		mat.set_shader_parameter("foliage_texture", load(TEXTURES[texture]))
		if texture != "hierba":
			mat.set_shader_parameter("wind_strength", 0.04) # Las matas de hojas apenas se mueven.
		_materials[texture] = mat
	return _materials[texture]


## Tarjetas en estrella. Cada tarjeta usa un trozo distinto de la textura.
## Tarjetas en estrella (y copa horizontal opcional) a la altura `lift`.
static func _cards(st: SurfaceTool, size: Vector2, cards: int, lift: float, turn: float, top_card: bool) -> void:
	var up := Vector3.UP * lift
	for c in cards:
		var a := PI * c / cards + turn
		var dir := Vector3(cos(a), 0, sin(a)) * size.x * 0.5
		# Cada tarjeta muestra la mata entera; una de cada dos, en espejo.
		var u0 := 0.0 if c % 2 == 0 else 1.0
		var u1 := 1.0 - u0
		var corners := [
			[up - dir, Vector2(u0, 1)], [up + dir, Vector2(u1, 1)],
			[up + dir + Vector3.UP * size.y, Vector2(u1, 0)], [up - dir + Vector3.UP * size.y, Vector2(u0, 0)],
		]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_normal(Vector3.UP)
			st.set_uv(corners[idx][1])
			st.add_vertex(corners[idx][0])
	if top_card:
		# Copa: tarjeta horizontal, vista desde arriba.
		var h := lift + size.y * 0.8
		var r := size.x * 0.33
		var top := [
			[Vector3(-r, h, -r), Vector2(0, 0)], [Vector3(r, h, -r), Vector2(1, 0)],
			[Vector3(r, h, r), Vector2(1, 1)], [Vector3(-r, h, r), Vector2(0, 1)],
		]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_normal(Vector3.UP)
			st.set_uv(top[idx][1])
			st.add_vertex(top[idx][0])


static func _mesh(kind: String) -> ArrayMesh:
	if _meshes.has(kind):
		return _meshes[kind]
	var def: Dictionary = KINDS[kind]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for layer: Array in def.get("layers", [[def.size, 0.0, 0.0]]):
		_cards(st, layer[0], def.cards, layer[1], layer[2], def.get("top", def.has("layers")))
	var mesh := st.commit()
	_meshes[kind] = mesh
	return mesh
