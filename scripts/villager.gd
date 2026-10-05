class_name Villager
extends StaticBody3D
## Aldeano con el que se puede hablar. Al entrar Henry en su radio se registra
## como "interactuable" en el GameManager; al interactuar abre un diálogo.

@export var display_name := "Aldeano"
@export var lines: PackedStringArray = []
@export var talk_radius := 1.9
## Aspecto. Con "model" (ruta FBX) y "outfit" usa PS1RiggedCharacter;
## si no, PS1Character con colores (tunic_color, hair_color, has_hood...).
@export var appearance: Dictionary = {}

var model: Node3D
var _talking := false


func _ready() -> void:
	add_to_group("villager")
	var shape := CapsuleShape3D.new()
	shape.radius = 0.3
	shape.height = 1.8
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = 0.9
	add_child(cs)

	model = PS1RiggedCharacter.new() if appearance.has("model") else PS1Character.new()
	for key: String in appearance:
		model.set("model_path" if key == "model" else key, appearance[key])
	add_child(model)

	var area := Area3D.new()
	area.monitorable = false
	var sphere := SphereShape3D.new()
	sphere.radius = talk_radius
	var acs := CollisionShape3D.new()
	acs.shape = sphere
	acs.position.y = 0.9
	area.add_child(acs)
	add_child(area)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	GameManager.dialog_finished.connect(_on_dialog_finished)


func get_prompt() -> String:
	return "Hablar con %s" % display_name


func interact(player: Node3D) -> void:
	var dir := player.global_position - global_position
	dir.y = 0.0
	if dir.length() > 0.01:
		rotation.y = atan2(-dir.x, -dir.z)
	_talking = true
	model.call("play", "talk")
	GameManager.start_dialog(display_name, lines)


func _on_dialog_finished() -> void:
	if _talking:
		_talking = false
		model.call("play", "idle")


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		GameManager.set_interactable(self)


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		GameManager.clear_interactable(self)
