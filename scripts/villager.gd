class_name Villager
extends StaticBody3D
## Aldeano con el que se puede hablar: Henry lo detecta mirándolo de cerca
## (rayo desde la cámara en primera persona) y al interactuar abre un diálogo.
##
## Vida propia: trabaja según su oficio (WORK), mira alrededor de vez en
## cuando, se gira y saluda cuando Henry se acerca, se encoge de miedo durante
## el asalto de los bandidos y lo celebra cuando acaba.

## Animación de trabajo por oficio (ver PS1RiggedCharacter).
const WORK := {
	"herrero": "hammer", "minero": "hammer", "campesino": "hoe", "clero": "pray",
	"comerciante": "call", "guardia": "guard", "pastor": "look_around", "molinero": "idle",
}
const GREET_DISTANCE := 4.5

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
## Animación de trabajo; "" = la de su oficio. "idle" para los que no dan golpe.
@export var work_anim := ""

var model: Node3D
var _talking := false
var _home_yaw := 0.0
var _busy := 0.0
var _ambient := 0.0
var _greet_cooldown := 0.0
var _cheered := false
var _player: Node3D


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
	_home_yaw = rotation.y
	if work_anim == "":
		work_anim = WORK.get(profession, "idle")
	_ambient = randf_range(0.0, 3.0)


func _process(delta: float) -> void:
	if not model is PS1RiggedCharacter or _talking:
		return
	var rig := model as PS1RiggedCharacter
	_busy -= delta
	_ambient -= delta
	_greet_cooldown -= delta
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node3D
	var stage := GameManager.quest_stage

	# Asalto: los guardias en guardia, el resto encogido de miedo.
	if stage == 4 or stage == 5:
		rig.play("guard" if profession == "guardia" else "cower")
		return
	if stage >= 6 and not _cheered:
		_cheered = true
		_busy = randf_range(2.5, 4.0)
		rig.play("cheer")
		return
	if _busy > 0.0:
		return

	var to := Vector3.ZERO
	var near := false
	if _player and GameManager.is_playing():
		to = _player.global_position - global_position
		to.y = 0.0
		near = to.length() < GREET_DISTANCE
	if near:
		# Se gira hacia Henry y le saluda (una vez cada cierto tiempo).
		rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), minf(delta * 3.0, 1.0))
		if _greet_cooldown <= 0.0:
			_greet_cooldown = 45.0
			_busy = 1.2
			rig.play_once("wave")
		else:
			rig.play("idle")
		return
	rotation.y = lerp_angle(rotation.y, _home_yaw, minf(delta * 2.0, 1.0))
	if _ambient <= 0.0:
		# Casi siempre trabajando; de vez en cuando, una pausa para mirar alrededor.
		if randf() < 0.25:
			_ambient = 3.0
			rig.play_once("look_around")
			_busy = 3.0
		else:
			_ambient = randf_range(5.0, 10.0)
			rig.play(work_anim)
	elif rig.animation_player.current_animation == "" or not rig.animation_player.is_playing():
		rig.play(work_anim)


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
		_greet_cooldown = 45.0 # Ya se han saludado.
