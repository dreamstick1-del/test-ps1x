class_name Paving
extends RefCounted
## Enlosado con profundidad real: cada losa es una pieza de geometría con los
## cantos biselados, separada de las demás por una junta, con su propio tono y
## pequeñas diferencias de altura e inclinación (como un suelo gastado de verdad).
## Todas las losas de una zona van en una sola malla: una única llamada de dibujo.
## La superficie usa la foto de suelo con relieve (ps1_relief.gdshader).

const ALBEDO := "res://assets/textures/paving_albedo.png"
const NORMAL := "res://assets/textures/paving_normal.png"

const TOP := 0.065 ## Altura media de la cara superior de las losas.
const GAP := 0.035 ## Ancho de las juntas.
const BEVEL := 0.018 ## Bisel de los cantos.


## Enlosa un rectángulo (x, z) en hiladas a lo largo de X, a matajunta.
## Devuelve el nodo con la malla, la lechada de las juntas y la colisión.
static func build(parent: Node3D, rect: Rect2, row_depth := 0.9, lengths := [0.9, 1.2, 1.5],
		seed_value := 1403) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var root := Node3D.new()
	root.name = "Paving"
	parent.add_child(root)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var z := rect.position.y
	var row := 0
	while z < rect.end.y - 0.05:
		var depth := minf(row_depth, rect.end.y - z)
		var x := rect.position.x - (rng.randf_range(0.2, 0.6) if row % 2 == 1 else 0.0)
		while x < rect.end.x - 0.05:
			var length: float = lengths[rng.randi() % lengths.size()]
			var x0 := maxf(x, rect.position.x)
			var x1 := minf(x + length, rect.end.x)
			if x1 - x0 > 0.15:
				_slab(st, rng, Rect2(x0 + GAP * 0.5, z + GAP * 0.5, x1 - x0 - GAP, depth - GAP))
			x += length
		z += depth
		row += 1
	st.generate_tangents()
	var mi := MeshInstance3D.new()
	mi.name = "Slabs"
	mi.mesh = st.commit()
	mi.material_override = PS1Assets.relief(ALBEDO, NORMAL, Vector2(0.55, 0.55))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)

	# Lechada oscura que se ve por las juntas.
	var grout := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = rect.size
	plane.subdivide_width = int(rect.size.x)
	plane.subdivide_depth = int(rect.size.y)
	grout.mesh = plane
	grout.position = Vector3(rect.get_center().x, 0.025, rect.get_center().y)
	grout.material_override = PS1Assets.material("dirt", Color(0.32, 0.3, 0.28), Vector2(1.5, 1.5))
	root.add_child(grout)

	# Se camina sobre las losas, no 6 cm por debajo.
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(rect.size.x, 0.1, rect.size.y)
	cs.shape = shape
	cs.position = Vector3(rect.get_center().x, TOP - 0.05, rect.get_center().y)
	body.add_child(cs)
	root.add_child(body)
	return root


## Una losa: tronco de pirámide (la cara de arriba algo más pequeña = bisel).
static func _slab(st: SurfaceTool, rng: RandomNumberGenerator, r: Rect2) -> void:
	# Tono propio: unas más claras, otras más oscuras y húmedas, alguna más cálida.
	var shade := rng.randf_range(0.7, 1.1)
	var warm := rng.randf_range(-0.025, 0.015)
	st.set_color(Color(shade + warm, shade, shade - warm + 0.02).srgb_to_linear())
	var h := TOP + rng.randf_range(-0.009, 0.009)
	var tilt := Vector2(rng.randf_range(-0.008, 0.008), rng.randf_range(-0.008, 0.008))
	var bottom := -0.04
	var b := [
		Vector3(r.position.x, bottom, r.position.y), Vector3(r.end.x, bottom, r.position.y),
		Vector3(r.end.x, bottom, r.end.y), Vector3(r.position.x, bottom, r.end.y),
	]
	var t := []
	for i in 4:
		var c: Vector3 = b[i]
		var inset := Vector3(BEVEL if i in [0, 3] else -BEVEL, 0, BEVEL if i in [0, 1] else -BEVEL)
		var rel := Vector2(c.x - r.get_center().x, c.z - r.get_center().y)
		t.append(Vector3(c.x, h + rel.x * tilt.x + rel.y * tilt.y, c.z) + inset)
	_quad(st, t[0], t[3], t[2], t[1]) # Cara superior.
	for i in 4:
		var j := (i + 1) % 4
		_quad(st, b[i], t[i], t[j], b[j]) # Bisel y canto en una sola cara inclinada.


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	var n := (b - a).cross(c - a).normalized()
	# Godot toma como cara frontal el orden horario visto desde fuera.
	for v: Vector3 in [a, c, b, a, d, c]:
		st.set_normal(n)
		st.set_uv(Vector2(v.x, v.z) * 0.55)
		st.add_vertex(v)
