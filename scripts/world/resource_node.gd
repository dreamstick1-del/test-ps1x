class_name ResourceNode
extends StaticBody3D
## Veta de mineral que Henry puede picar. Tiene unas cuantas cargas al día;
## cada golpe cuesta aguante y da una unidad del bien (para vender o usar).

@export var good := "plata"
@export var display_name := "veta de plata"
@export var charges_per_day := 3
@export var stamina_cost := 20.0

var _charges := 3
var _sparkles: Array[MeshInstance3D] = []


func _ready() -> void:
	_charges = charges_per_day
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.3, 1.1, 1.1)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = 0.5
	add_child(cs)
	var rock := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.3, 1.1, 1.1)
	rock.mesh = box
	rock.position.y = 0.5
	rock.rotation = Vector3(0.2, randf() * TAU, 0.1)
	rock.material_override = PS1Assets.material("stone", Color(0.7, 0.68, 0.66), Vector2(1, 1))
	add_child(rock)
	for i in 5:
		var s := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3.ONE * 0.12
		s.mesh = b
		s.position = Vector3(randf_range(-0.6, 0.6), randf_range(0.3, 1.0), randf_range(-0.56, 0.56))
		s.material_override = PS1Assets.resolve(PS1Assets.flat(Color(0.85, 0.88, 0.95), 0.8))
		add_child(s)
		_sparkles.append(s)
	Economy.day_passed.connect(func(_d: int) -> void:
		_charges = charges_per_day
		_update_visual())


func get_prompt() -> String:
	return "Picar %s (%d)" % [display_name, _charges] if _charges > 0 else "La %s está agotada" % display_name


func interact(player: Node3D) -> void:
	if _charges <= 0:
		GameManager.show_message("Agotada. Vuelve mañana.", Color(0.8, 0.8, 0.8), 1.2)
		return
	var stats: CombatStats = player.get_node("Stats")
	if not stats.spend_stamina(stamina_cost):
		GameManager.show_message("Estás agotado", Color(0.9, 0.9, 0.6), 1.0)
		return
	_charges -= 1
	player.shake(0.06)
	CombatFX.burst(get_parent(), global_position + Vector3(0, 0.9, 0), Color(0.85, 0.88, 0.95), 10, 3.0)
	Economy.add_item(good)
	GameManager.show_message("+1 %s" % Economy.GOODS[good].name, Color(0.85, 0.9, 1.0), 1.0)
	_update_visual()


func _update_visual() -> void:
	for i in _sparkles.size():
		_sparkles[i].visible = i < _charges * 2
