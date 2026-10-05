class_name Villager
extends StaticBody3D
## Aldeano con el que se puede hablar: Henry lo detecta mirándolo de cerca
## (rayo desde la cámara en primera persona) y al interactuar abre un diálogo.

@export var display_name := "Aldeano"
@export var lines: PackedStringArray = []
## Aspecto. Con "model" (ruta FBX) y "outfit" usa PS1RiggedCharacter;
## si no, PS1Character con colores (tunic_color, hair_color, has_hood...).
@export var appearance: Dictionary = {}
## Oficio (para los comentarios sobre la economía, ver Economy.gossip).
@export var profession := ""
## Tienda que abre al hablarle (clave de Economy.SHOPS) o "".
@export var shop := ""
## Mientras GameManager.quest_stage <= este valor, habla en vez de comerciar.
@export var talk_until_stage := -1

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

	GameManager.dialog_finished.connect(_on_dialog_finished)


func get_prompt() -> String:
	if shop != "" and GameManager.quest_stage > talk_until_stage:
		return "Comerciar con %s" % display_name
	return "Hablar con %s" % display_name


func interact(player: Node3D) -> void:
	var dir := player.global_position - global_position
	dir.y = 0.0
	if dir.length() > 0.01:
		rotation.y = atan2(-dir.x, -dir.z)
	_talking = true
	model.call("play", "talk")
	if shop != "" and GameManager.quest_stage > talk_until_stage:
		if not Economy.is_open():
			GameManager.start_dialog(display_name, PackedStringArray(["Es muy tarde, muchacho. Vuelve cuando salga el sol."]))
		else:
			GameManager.open_trade(shop, display_name)
			_talking = false
			model.call("play", "idle")
		return
	var all_lines := lines.duplicate()
	if GameManager.quest_stage > talk_until_stage:
		all_lines.append(Economy.gossip(profession))
	GameManager.start_dialog(display_name, all_lines)


func _on_dialog_finished() -> void:
	if _talking:
		_talking = false
		model.call("play", "idle")
