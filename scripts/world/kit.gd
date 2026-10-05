class_name Kit
extends RefCounted
## Coloca piezas del kit medieval (assets/env/*.fbx) con el material PS1.
##
## El kit es modular sobre una rejilla de 4 m:
##  - plaster_wall*, stone_square*: módulo de 4x4 m y 3 m de alto (cuatro paredes),
##    desde el origen hacia +X y -Z. Se apilan para hacer plantas.
##  - roof_*: tejado a dos aguas de un módulo, cumbrera a lo largo de X, con hastial.
##  - puertas, ventanas, chimeneas, jardineras: centradas en X, apoyadas en Y=0.
##  - mercado: puestos, barriles, cajas, cestas, sacos, heno...
##
## Todas las piezas con la misma textura comparten un único material PS1
## (en WebGL no conviene tener cientos de materiales distintos).

const DIR := "res://assets/env/%s.fbx"

static var _scenes := {}
static var _materials := {}
static var _aabbs := {}


static func place(parent: Node3D, piece: String, pos: Vector3, rot_y := 0.0, scale := 1.0) -> Node3D:
	var node := _scene(piece).instantiate() as Node3D
	node.position = pos
	node.rotation.y = rot_y
	if scale != 1.0:
		node.scale = Vector3.ONE * scale
	parent.add_child(node)
	_ps1ify(node)
	return node


## Coloca una pieza y le añade una caja de colisión ajustada a su tamaño.
static func place_solid(parent: Node3D, piece: String, pos: Vector3, rot_y := 0.0, shrink := 0.05) -> Node3D:
	var node := place(parent, piece, pos, rot_y)
	var box := aabb(piece).grow(-shrink)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box.size.max(Vector3.ONE * 0.05)
	cs.shape = shape
	cs.position = box.get_center()
	body.add_child(cs)
	node.add_child(body)
	return node


## Caja que ocupa la pieza en su propio espacio (sin rotar ni mover).
static func aabb(piece: String) -> AABB:
	if _aabbs.has(piece):
		return _aabbs[piece]
	var inst := _scene(piece).instantiate() as Node3D
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in inst.find_children("*", "MeshInstance3D", true, false):
		var xf := Transform3D()
		var p: Node = mi
		while p and p != inst:
			if p is Node3D:
				xf = (p as Node3D).transform * xf
			p = p.get_parent()
		var b := xf * mi.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	inst.free()
	_aabbs[piece] = box
	return box


static func _scene(piece: String) -> PackedScene:
	if not _scenes.has(piece):
		_scenes[piece] = load(DIR % piece)
	return _scenes[piece]


## Sustituye los materiales importados por el PS1 (uno por textura).
static func _ps1ify(node: Node) -> void:
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for s in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(s) as BaseMaterial3D
			if src == null:
				continue
			mi.set_surface_override_material(s, _material(src))


static func _material(src: BaseMaterial3D) -> Material:
	var tex := src.albedo_texture
	var key := "%s|%s" % [tex.resource_path if tex else "", src.albedo_color.to_html()]
	if not _materials.has(key):
		if tex:
			_materials[key] = PS1Assets.textured(tex, src.albedo_color)
		else:
			_materials[key] = PS1Assets.resolve(PS1Assets.flat(src.albedo_color))
	return _materials[key]
