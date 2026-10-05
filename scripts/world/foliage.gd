class_name Foliage
extends RefCounted
## Matas de hierba alta, juncos y arbustos hechos con tarjetas cruzadas
## (3 planos en estrella con la textura recortada de la foto de hierba).
## Todas las matas de un tipo van en un MultiMesh: una sola llamada de dibujo.

const TEXTURE := "res://assets/textures/tallgrass_albedo.png"

## Tipos: tamaño (ancho, alto), tinte y nº de tarjetas.
const KINDS := {
	"mata": {"size": Vector2(1.1, 0.75), "tint": Color(1, 1, 1), "cards": 3},
	"hierba_alta": {"size": Vector2(1.4, 1.2), "tint": Color(1.0, 1.05, 0.95), "cards": 3},
	"junco": {"size": Vector2(0.9, 1.7), "tint": Color(0.85, 0.95, 0.8), "cards": 3},
	"seca": {"size": Vector2(1.0, 0.7), "tint": Color(1.45, 1.15, 0.6), "cards": 3},
	"trigo": {"size": Vector2(0.8, 1.0), "tint": Color(1.7, 1.3, 0.45), "cards": 2},
	"arbusto": {"size": Vector2(1.8, 1.3), "tint": Color(0.72, 0.85, 0.65), "cards": 5},
}

static var _material: ShaderMaterial
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
	mmi.material_override = material()
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)
	return mmi


static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = load("res://shaders/ps1_foliage.gdshader")
		_material.set_shader_parameter("foliage_texture", load(TEXTURE))
	return _material


## Tarjetas en estrella. Cada tarjeta usa un trozo distinto de la textura.
static func _mesh(kind: String) -> ArrayMesh:
	if _meshes.has(kind):
		return _meshes[kind]
	var def: Dictionary = KINDS[kind]
	var size: Vector2 = def.size
	var cards: int = def.cards
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for c in cards:
		var a := PI * c / cards
		var dir := Vector3(cos(a), 0, sin(a)) * size.x * 0.5
		# Cada tarjeta muestra la mata entera; una de cada dos, en espejo.
		var u0 := 0.0 if c % 2 == 0 else 1.0
		var u1 := 1.0 - u0
		var corners := [
			[-dir, Vector2(u0, 1)], [dir, Vector2(u1, 1)],
			[dir + Vector3.UP * size.y, Vector2(u1, 0)], [-dir + Vector3.UP * size.y, Vector2(u0, 0)],
		]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_normal(Vector3.UP)
			st.set_uv(corners[idx][1])
			st.add_vertex(corners[idx][0])
	var mesh := st.commit()
	_meshes[kind] = mesh
	return mesh
