class_name DioramaCamera
extends Camera3D
## Cámara del diorama con tres modos:
##  ORBIT     -> gira alrededor de la maqueta (menú principal).
##  CINEMATIC -> vuelos interpolados (cutscenes).
##  FIXED     -> planos fijos por zona que siguen a Henry con la mirada.
## Usa profundidad de campo para el efecto "tilt-shift" de miniatura.

enum Mode { ORBIT, CINEMATIC, FIXED }

@export_group("Órbita")
@export var orbit_center := Vector3(0, -1.0, 0)
@export var orbit_radius := 44.0
@export var orbit_height := 28.0
@export var orbit_speed := 0.10 ## Radianes por segundo.

@export_group("Planos fijos")
@export_range(0.0, 1.0) var track_weight := 0.35 ## Cuánto gira la cámara hacia Henry.
@export var track_smoothing := 5.0

var mode: Mode = Mode.ORBIT
var target: Node3D

var _orbit_angle := 0.6
var _zones: Array[CameraZone] = []
var _active_zone: CameraZone
var _look_point := Vector3.ZERO
var _tween: Tween
var _attributes := CameraAttributesPractical.new()


func _ready() -> void:
	add_to_group("diorama_camera")
	attributes = _attributes
	_set_miniature_dof(true)


func _process(delta: float) -> void:
	match mode:
		Mode.ORBIT:
			_orbit_angle += orbit_speed * delta
			global_position = orbit_center + Vector3(sin(_orbit_angle) * orbit_radius,
				orbit_height, cos(_orbit_angle) * orbit_radius)
			look_at(orbit_center)
		Mode.FIXED:
			if _active_zone and target:
				var desired := _desired_look()
				_look_point = _look_point.lerp(desired, clampf(track_smoothing * delta, 0.0, 1.0))
				_safe_look_at(_look_point)


func start_orbit() -> void:
	_kill_tween()
	mode = Mode.ORBIT
	_set_miniature_dof(true)


## Vuelo de cámara para cutscenes. Devuelve el Tween por si se quiere esperar.
func fly_to(pos: Vector3, look: Vector3, duration: float) -> Tween:
	_kill_tween()
	mode = Mode.CINEMATIC
	var from := global_transform
	var to := Transform3D(Basis.looking_at(look - pos), pos)
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_method(func(t: float) -> void: global_transform = from.interpolate_with(to, t),
		0.0, 1.0, duration)
	return _tween


func enter_gameplay(player: Node3D) -> void:
	_kill_tween()
	target = player
	mode = Mode.FIXED
	_set_miniature_dof(false)
	var zone: CameraZone = null
	for node in get_tree().get_nodes_in_group("camera_zone"):
		var z := node as CameraZone
		if z.contains(player.global_position):
			zone = z
	if zone:
		if not _zones.has(zone):
			_zones.append(zone)
		_cut_to(zone)


func zone_entered(zone: CameraZone) -> void:
	_zones.erase(zone)
	_zones.append(zone)
	if mode == Mode.FIXED:
		_cut_to(zone)


func zone_exited(zone: CameraZone) -> void:
	_zones.erase(zone)
	if mode == Mode.FIXED and zone == _active_zone and not _zones.is_empty():
		_cut_to(_zones.back())


func _cut_to(zone: CameraZone) -> void:
	if zone == _active_zone:
		return
	_active_zone = zone
	global_position = zone.camera_position
	_look_point = _desired_look()
	_safe_look_at(_look_point)
	GameManager.location_changed.emit(zone.zone_name)


func _desired_look() -> Vector3:
	if target == null:
		return _active_zone.look_target
	return _active_zone.look_target.lerp(target.global_position + Vector3.UP, track_weight)


func _safe_look_at(point: Vector3) -> void:
	if global_position.distance_squared_to(point) > 0.0001:
		look_at(point)


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()


## Desenfoque de cerca y de lejos = sensación de maqueta en miniatura.
func _set_miniature_dof(strong: bool) -> void:
	_attributes.dof_blur_far_enabled = true
	_attributes.dof_blur_near_enabled = strong
	_attributes.dof_blur_far_distance = 58.0 if strong else 30.0
	_attributes.dof_blur_far_transition = 20.0
	_attributes.dof_blur_near_distance = 30.0
	_attributes.dof_blur_near_transition = 12.0
	_attributes.dof_blur_amount = 0.12 if strong else 0.06
