class_name DioramaCamera
extends Camera3D
## Cámara que mira la maqueta desde fuera:
##  ORBIT     -> gira alrededor del diorama (menú principal).
##  CINEMATIC -> vuelos interpolados (cutscenes), p. ej. hasta los ojos de Henry.
## Usa profundidad de campo para el efecto "tilt-shift" de miniatura.

enum Mode { ORBIT, CINEMATIC }

@export var orbit_center := Vector3(0, -1.0, 0)
@export var orbit_radius := 44.0
@export var orbit_height := 28.0
@export var orbit_speed := 0.10 ## Radianes por segundo.

var mode: Mode = Mode.ORBIT

var _orbit_angle := 0.6
var _tween: Tween
var _attributes := CameraAttributesPractical.new()


func _ready() -> void:
	attributes = _attributes
	_attributes.dof_blur_far_enabled = true
	_attributes.dof_blur_near_enabled = true
	_attributes.dof_blur_far_distance = 58.0
	_attributes.dof_blur_far_transition = 20.0
	_attributes.dof_blur_near_distance = 30.0
	_attributes.dof_blur_near_transition = 12.0
	_attributes.dof_blur_amount = 0.12


func _process(delta: float) -> void:
	if mode == Mode.ORBIT:
		_orbit_angle += orbit_speed * delta
		global_position = orbit_center + Vector3(sin(_orbit_angle) * orbit_radius,
			orbit_height, cos(_orbit_angle) * orbit_radius)
		look_at(orbit_center)


func start_orbit() -> void:
	_kill_tween()
	mode = Mode.ORBIT


## Vuelo de cámara para cutscenes. Devuelve el Tween por si se quiere esperar.
func fly_to(pos: Vector3, look: Vector3, duration: float) -> Tween:
	return fly_to_transform(Transform3D(Basis.looking_at(look - pos), pos), duration)


func fly_to_transform(to: Transform3D, duration: float) -> Tween:
	_kill_tween()
	mode = Mode.CINEMATIC
	var from := global_transform
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_method(func(t: float) -> void: global_transform = from.interpolate_with(to, t),
		0.0, 1.0, duration)
	# Al acercarse a los ojos de Henry el desenfoque de miniatura molesta.
	_tween.parallel().tween_property(_attributes, "dof_blur_amount", 0.0, duration)
	return _tween


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
