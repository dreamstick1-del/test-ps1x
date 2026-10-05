class_name TrainingDummy
extends StaticBody3D
## Muñeco de paja para practicar. Nunca muere y da un poco de experiencia
## (hasta un tope, para que no se pueda subir de nivel solo con él).

signal hit

const XP_CAP := 24

var display_name := "Muñeco de paja"
var hit_color := Color(0.85, 0.75, 0.35)
var stats: CombatStats

var _visual: Node3D
var _xp_given := 0


func _ready() -> void:
	add_to_group("damageable")
	add_to_group("training_dummy")
	var shape := CylinderShape3D.new()
	shape.radius = 0.35
	shape.height = 1.9
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = 0.95
	add_child(cs)

	stats = CombatStats.new()
	stats.max_health = 60.0
	add_child(stats)

	_visual = Node3D.new()
	add_child(_visual)
	var wood := PS1Assets.material("wood", Color.WHITE, Vector2(1, 1))
	var straw := PS1Assets.material("thatch", Color.WHITE, Vector2(1.5, 1.5))
	_box(Vector3(0.1, 1.9, 0.1), Vector3(0, 0.95, 0), wood)
	_box(Vector3(1.1, 0.09, 0.09), Vector3(0, 1.45, 0), wood)
	var body := CylinderMesh.new()
	body.top_radius = 0.24
	body.bottom_radius = 0.3
	body.height = 0.75
	body.radial_segments = 6
	body.rings = 1
	_mesh(body, Vector3(0, 1.15, 0), straw)
	_box(Vector3(0.3, 0.3, 0.3), Vector3(0, 1.72, 0), PS1Assets.flat(Color(0.75, 0.68, 0.5)))
	for x: float in [-0.07, 0.07]:
		_box(Vector3(0.05, 0.05, 0.02), Vector3(x, 1.76, -0.155), PS1Assets.flat(Color(0.1, 0.08, 0.06)))
	_box(Vector3(0.14, 0.03, 0.02), Vector3(0, 1.65, -0.155), PS1Assets.flat(Color(0.35, 0.1, 0.08)))


func is_alive() -> bool:
	return true


func receive_hit(hit_info: Dictionary) -> void:
	stats.take_damage(hit_info.damage)
	if stats.health <= 0.0 or stats.dead:
		stats.dead = false
		stats.heal(stats.max_health)
	# Bamboleo a saltos.
	var dir: Vector3 = hit_info.knockback
	var tilt := 0.35 if dir.length() > 0.01 else 0.2
	var tween := create_tween()
	tween.tween_property(_visual, "rotation:x", tilt, 0.06)
	tween.tween_property(_visual, "rotation:x", -tilt * 0.5, 0.12)
	tween.tween_property(_visual, "rotation:x", 0.0, 0.12)
	if _xp_given < XP_CAP:
		_xp_given += 2
		Skills.add_xp(2)
	hit.emit()


func stagger(_duration: float) -> void:
	pass


func _box(size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	PS1Assets.setup_box(mi, size, mat)
	mi.position = pos
	_visual.add_child(mi)


func _mesh(mesh: Mesh, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = PS1Assets.resolve(mat)
	_visual.add_child(mi)
