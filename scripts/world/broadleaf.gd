class_name Broadleaf
extends RefCounted
## Árboles de hoja ancha (robles, tilos) con la copa hecha de racimos de hojas
## recortadas de las fotos (assets/textures/leafcluster_albedo.png).
##
## Tronco con tres ramas (una malla) + copa de tarjetas cruzadas en dos pisos
## (tipo "copa" de Foliage). Todo en MultiMesh: dos llamadas de dibujo para
## cientos de árboles. Cada árbol lleva su tono, tamaño y giro.

static var _trunk_mesh: ArrayMesh


## spots: posiciones (x, y, z) en el suelo. Devuelve los puntos para el minimapa.
static func plant(world: Node3D, spots: Array[Vector3], seed_value := 77) -> void:
	if spots.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _trunk()
	mm.instance_count = spots.size()
	var crowns := []
	var body := StaticBody3D.new()
	body.name = "BroadleafCollision"
	world.add_child(body)
	for i in spots.size():
		var pos := spots[i]
		var s := rng.randf_range(0.85, 1.35)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s)
		mm.set_instance_transform(i, Transform3D(basis, pos - Vector3(0, 0.1, 0)))
		mm.set_instance_color(i, Color(0.62, 0.5, 0.42) * rng.randf_range(0.85, 1.1))
		# Tono de la copa: verdes más frescos o más oscuros, alguno ya amarilleando.
		var tint := Color(1, 1, 1)
		var roll := rng.randf()
		if roll < 0.2:
			tint = Color(0.8, 0.88, 0.75)
		elif roll > 0.9:
			tint = Color(1.25, 1.1, 0.7)
		crowns.append({"pos": pos, "scale": s, "tint": tint * rng.randf_range(0.9, 1.08)})
		var cs := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = 0.3 * s
		shape.height = 2.4 * s
		cs.shape = shape
		cs.position = pos + Vector3(0, 1.2 * s, 0)
		body.add_child(cs)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "BroadleafTrunks"
	mmi.multimesh = mm
	mmi.material_override = PS1Assets.vertex_colored("wood", Vector2(1.5, 1.5), false)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(mmi)
	Foliage.plant(world, "copa", crowns)


## Tronco algo inclinado con tres ramas que se abren hacia la copa.
static func _trunk() -> ArrayMesh:
	if _trunk_mesh:
		return _trunk_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_cylinder(st, Vector3.ZERO, Vector3(0.05, 2.3, 0.0), 0.24, 0.15)
	for b in 3:
		var a := TAU * b / 3.0 + 0.4
		var dir := Vector3(cos(a), 0.0, sin(a))
		var start := Vector3(0.05, 1.7 + b * 0.18, 0.0)
		_cylinder(st, start, start + dir * 0.9 + Vector3(0, 0.75, 0), 0.1, 0.05)
	st.generate_normals()
	_trunk_mesh = st.commit()
	return _trunk_mesh


static func _cylinder(st: SurfaceTool, a: Vector3, b: Vector3, r0: float, r1: float, sides := 6) -> void:
	var axis := (b - a).normalized()
	var side := axis.cross(Vector3.FORWARD if absf(axis.z) < 0.9 else Vector3.RIGHT).normalized()
	var up := side.cross(axis)
	for i in sides:
		var t0 := TAU * i / sides
		var t1 := TAU * (i + 1) / sides
		var d0 := side * cos(t0) + up * sin(t0)
		var d1 := side * cos(t1) + up * sin(t1)
		var p := [a + d0 * r0, a + d1 * r0, b + d1 * r1, b + d0 * r1]
		var u0 := float(i) / sides
		var u1 := float(i + 1) / sides
		var uv := [Vector2(u0, 1), Vector2(u1, 1), Vector2(u1, 0), Vector2(u0, 0)]
		for idx in [0, 2, 1, 0, 3, 2]:
			st.set_uv(uv[idx])
			st.add_vertex(p[idx])
