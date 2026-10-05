class_name CameraZone
extends Area3D
## Zona de cámara fija. Cuando Henry entra, la DioramaCamera corta a este plano
## (corte seco, como en los survival horror de PS1).

@export var zone_name := ""
@export var size := Vector3(10, 4, 10)
@export var camera_position := Vector3.ZERO
@export var look_target := Vector3.ZERO


func _ready() -> void:
	add_to_group("camera_zone")
	monitorable = false
	var box := BoxShape3D.new()
	box.size = size
	var cs := CollisionShape3D.new()
	cs.shape = box
	cs.position.y = size.y * 0.5
	add_child(cs)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func contains(point: Vector3) -> bool:
	var local := point - global_position
	return absf(local.x) <= size.x * 0.5 and absf(local.z) <= size.z * 0.5


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		get_tree().call_group("diorama_camera", "zone_entered", self)


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		get_tree().call_group("diorama_camera", "zone_exited", self)
