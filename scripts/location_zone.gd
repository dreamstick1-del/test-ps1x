class_name LocationZone
extends Area3D
## Zona con nombre ("LA PLAZA", "LA FORJA"...). Al entrar Henry, el HUD
## muestra el nombre del lugar.

@export var zone_name := ""
@export var size := Vector3(10, 4, 10)


func _ready() -> void:
	monitorable = false
	var box := BoxShape3D.new()
	box.size = size
	var cs := CollisionShape3D.new()
	cs.shape = box
	cs.position.y = size.y * 0.5
	add_child(cs)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and GameManager.is_playing():
		GameManager.location_changed.emit(zone_name)
