class_name PS1Character
extends Node3D
## Personaje low-poly construido con cajas (sin assets externos) y animado con
## un AnimationPlayer cuyas pistas usan interpolación NEAREST: el movimiento
## salta de pose en pose, rígido y entrecortado como en la PS1.
## Mira hacia -Z (el "adelante" de Godot).
##
## Para usar un modelo de Blender en su lugar, sustituye este nodo por tu .glb y
## conserva los nombres de animación: idle, walk, run, talk.

@export var skin_color := Color(0.86, 0.66, 0.50)
@export var hair_color := Color(0.26, 0.17, 0.09)
@export var tunic_color := Color(0.58, 0.14, 0.11)
@export var sleeve_color := Color(0.50, 0.12, 0.10)
@export var pants_color := Color(0.27, 0.23, 0.18)
@export var boots_color := Color(0.17, 0.11, 0.07)
@export var belt_color := Color(0.33, 0.22, 0.11)
@export var has_hood := false
@export var body_scale := 1.0

var animation_player: AnimationPlayer
var body: Node3D

## Propiedades animadas y su valor de reposo. Todas las animaciones fijan todas
## las pistas, así una pose nunca "se queda pegada" al cambiar de animación.
const ANIMATED := {
	"Body:position:y": 0.0,
	"Body/Hips/Torso:rotation:x": 0.0,
	"Body/Hips/Torso/Head:rotation:x": 0.0,
	"Body/Hips/Torso/Head:rotation:y": 0.0,
	"Body/Hips/Torso/ArmL:rotation:x": 0.0,
	"Body/Hips/Torso/ArmR:rotation:x": 0.0,
	"Body/Hips/Torso/ArmL:rotation:z": 0.0,
	"Body/Hips/Torso/ArmR:rotation:z": 0.0,
	"Body/LegL:rotation:x": 0.0,
	"Body/LegR:rotation:x": 0.0,
}


func _ready() -> void:
	scale = Vector3.ONE * body_scale
	_build_body()
	_build_animations()
	play("idle")
	# Desincroniza a los personajes que comparten animación.
	animation_player.seek(randf() * animation_player.current_animation_length, true)


func play(anim_name: String, speed := 1.0) -> void:
	animation_player.speed_scale = speed
	if animation_player.current_animation != anim_name:
		animation_player.play(anim_name)


# --- Malla -----------------------------------------------------------------

func _build_body() -> void:
	var shadow := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.9, 0.9)
	shadow.mesh = quad
	shadow.material_override = PS1Assets.blob_shadow_material()
	shadow.rotation.x = -PI / 2
	shadow.position.y = 0.03
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shadow)

	body = _pivot("Body", self, Vector3.ZERO)
	var hips := _pivot("Hips", body, Vector3(0, 0.92, 0))
	_part(hips, Vector3(0.40, 0.20, 0.24), Vector3(0, 0.0, 0), pants_color)

	var torso := _pivot("Torso", hips, Vector3(0, 0.08, 0))
	_part(torso, Vector3(0.46, 0.52, 0.27), Vector3(0, 0.26, 0), tunic_color)
	_part(torso, Vector3(0.48, 0.07, 0.29), Vector3(0, 0.04, 0), belt_color)
	_part(torso, Vector3(0.50, 0.16, 0.29), Vector3(0, -0.05, 0), tunic_color.darkened(0.1))

	var head := _pivot("Head", torso, Vector3(0, 0.52, 0))
	_part(head, Vector3(0.11, 0.08, 0.11), Vector3(0, 0.03, 0), skin_color.darkened(0.1))
	_part(head, Vector3(0.26, 0.28, 0.26), Vector3(0, 0.20, 0), skin_color)
	_part(head, Vector3(0.05, 0.07, 0.05), Vector3(0, 0.17, -0.145), skin_color.darkened(0.12))
	for side: float in [-1.0, 1.0]:
		_part(head, Vector3(0.05, 0.03, 0.01), Vector3(side * 0.065, 0.23, -0.132), Color(0.08, 0.06, 0.05))
	if has_hood:
		_part(head, Vector3(0.30, 0.12, 0.30), Vector3(0, 0.36, 0.01), hair_color)
		_part(head, Vector3(0.30, 0.30, 0.07), Vector3(0, 0.20, 0.13), hair_color)
		_part(head, Vector3(0.36, 0.10, 0.34), Vector3(0, 0.0, 0.02), hair_color)
	else:
		_part(head, Vector3(0.28, 0.09, 0.28), Vector3(0, 0.36, 0.01), hair_color)
		_part(head, Vector3(0.28, 0.20, 0.06), Vector3(0, 0.25, 0.12), hair_color)
		for side: float in [-1.0, 1.0]:
			_part(head, Vector3(0.03, 0.12, 0.20), Vector3(side * 0.14, 0.28, 0.03), hair_color)

	for side: float in [-1.0, 1.0]:
		var arm := _pivot("ArmL" if side < 0 else "ArmR", torso, Vector3(side * 0.30, 0.47, 0))
		_part(arm, Vector3(0.14, 0.32, 0.15), Vector3(0, -0.14, 0), tunic_color)
		_part(arm, Vector3(0.12, 0.24, 0.13), Vector3(0, -0.40, 0), sleeve_color)
		_part(arm, Vector3(0.10, 0.10, 0.11), Vector3(0, -0.57, 0), skin_color)

		var leg := _pivot("LegL" if side < 0 else "LegR", body, Vector3(side * 0.11, 0.90, 0))
		_part(leg, Vector3(0.17, 0.50, 0.18), Vector3(0, -0.25, 0), pants_color)
		_part(leg, Vector3(0.18, 0.36, 0.20), Vector3(0, -0.68, 0), boots_color)
		_part(leg, Vector3(0.18, 0.06, 0.28), Vector3(0, -0.86, -0.04), boots_color.darkened(0.2))


func _pivot(pivot_name: String, parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = pivot_name
	n.position = pos
	parent.add_child(n)
	return n


func _part(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.position = pos
	mi.material_override = PS1Assets.flat(color)
	parent.add_child(mi)
	return mi


# --- Animaciones -----------------------------------------------------------

func _build_animations() -> void:
	animation_player = AnimationPlayer.new()
	animation_player.name = "AnimationPlayer"
	add_child(animation_player)

	var lib := AnimationLibrary.new()
	# idle: respiración en 2 poses.
	lib.add_animation("idle", _make_anim(2.0, {
		"Body:position:y": [0.0, -0.015],
		"Body/Hips/Torso/ArmL:rotation:z": [-0.05, -0.08],
		"Body/Hips/Torso/ArmR:rotation:z": [0.05, 0.08],
		"Body/Hips/Torso/Head:rotation:x": [0.0, 0.04],
	}))
	# walk: ciclo de 4 poses.
	lib.add_animation("walk", _make_anim(0.64, {
		"Body:position:y": [0.0, 0.035, 0.0, 0.035],
		"Body/LegL:rotation:x": [0.5, 0.0, -0.5, 0.0],
		"Body/LegR:rotation:x": [-0.5, 0.0, 0.5, 0.0],
		"Body/Hips/Torso/ArmL:rotation:x": [-0.4, 0.0, 0.4, 0.0],
		"Body/Hips/Torso/ArmR:rotation:x": [0.4, 0.0, -0.4, 0.0],
	}))
	# run: 4 poses más amplias y torso inclinado hacia delante.
	lib.add_animation("run", _make_anim(0.44, {
		"Body:position:y": [0.0, 0.07, 0.0, 0.07],
		"Body/Hips/Torso:rotation:x": [-0.22, -0.22, -0.22, -0.22],
		"Body/LegL:rotation:x": [0.9, 0.1, -0.8, 0.1],
		"Body/LegR:rotation:x": [-0.8, 0.1, 0.9, 0.1],
		"Body/Hips/Torso/ArmL:rotation:x": [-0.9, 0.0, 0.9, 0.0],
		"Body/Hips/Torso/ArmR:rotation:x": [0.9, 0.0, -0.9, 0.0],
	}))
	# talk: gesticula con un brazo y asiente.
	lib.add_animation("talk", _make_anim(1.2, {
		"Body/Hips/Torso/Head:rotation:x": [0.0, 0.12, 0.0, -0.06],
		"Body/Hips/Torso/Head:rotation:y": [0.0, 0.0, 0.15, 0.0],
		"Body/Hips/Torso/ArmR:rotation:x": [0.6, 0.9, 0.6, 0.3],
		"Body/Hips/Torso/ArmR:rotation:z": [0.2, 0.2, 0.3, 0.2],
	}))
	animation_player.add_animation_library("", lib)


func _make_anim(length: float, tracks: Dictionary) -> Animation:
	var anim := Animation.new()
	anim.length = length
	anim.loop_mode = Animation.LOOP_LINEAR
	for path: String in ANIMATED:
		var values: Array = tracks.get(path, [ANIMATED[path]])
		var idx := anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(idx, NodePath(path))
		anim.track_set_interpolation_type(idx, Animation.INTERPOLATION_NEAREST)
		anim.value_track_set_update_mode(idx, Animation.UPDATE_DISCRETE)
		var step := length / values.size()
		for i in values.size():
			anim.track_insert_key(idx, i * step, values[i])
	return anim
