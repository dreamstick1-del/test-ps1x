class_name FirstPersonWeapon
extends Node3D
## Espada y brazo de Henry en primera persona (hijo de la cámara).
## Las animaciones son secuencias de poses clave muestreadas a 15 fps:
## el arma salta de pose en pose, entrecortada como en un juego de PS1.

const FPS := 15.0

## Poses: [posición respecto a la cámara, rotación en grados].
const POSES := {
	"rest": [Vector3(0.34, -0.36, -0.5), Vector3(-30, -10, -16)],
	"block": [Vector3(0.04, -0.16, -0.46), Vector3(8, 0, 84)],
	"wind_r": [Vector3(0.50, -0.06, -0.42), Vector3(-15, -55, -75)],
	"slash_l": [Vector3(-0.42, -0.36, -0.56), Vector3(-75, 45, 70)],
	"wind_l": [Vector3(-0.42, -0.08, -0.44), Vector3(-15, 55, 75)],
	"slash_r": [Vector3(0.46, -0.40, -0.56), Vector3(-75, -45, -70)],
	"thrust_back": [Vector3(0.22, -0.22, -0.28), Vector3(-90, 0, 0)],
	"thrust_fwd": [Vector3(0.06, -0.14, -0.95), Vector3(-90, 0, 0)],
	"overhead": [Vector3(0.14, 0.18, -0.30), Vector3(28, 0, -8)],
	"overhead_down": [Vector3(0.04, -0.46, -0.62), Vector3(-115, 0, 0)],
	"pray": [Vector3(0.10, -0.75, -0.40), Vector3(-10, 0, 0)],
}

## 0..1, lo fija el jugador según su velocidad (balanceo al andar).
var bob_amount := 0.0
var holding_block := false

var _sword: Node3D
var _keys: Array = []
var _time := 0.0
var _playing := false
var _base := Transform3D()
var _bob_t := 0.0


func _ready() -> void:
	_sword = WeaponFactory.build("sword")
	# Puño y manga de Henry agarrando la espada.
	var skin := Color(0.86, 0.66, 0.52)
	var sleeve := Color(0.82, 0.76, 0.62)
	_add_box(_sword, Vector3(0.09, 0.11, 0.1), Vector3(0, 0.0, 0.0), skin)
	_add_box(_sword, Vector3(0.1, 0.3, 0.11), Vector3(0.02, -0.12, 0.2), sleeve, Vector3(-60, 0, 0))
	WeaponFactory.make_viewmodel(_sword)
	for child: Node3D in _sword.get_children():
		child.scale = Vector3.ONE * 0.85
		child.position *= 0.85
	add_child(_sword)
	_base = pose("rest")
	_sword.transform = _base


func pose(pose_name: String) -> Transform3D:
	var p: Array = POSES[pose_name]
	var rot: Vector3 = p[1]
	return Transform3D(Basis.from_euler(rot * (PI / 180.0)), p[0])


## Reproduce [[pose, duración], ...]. Devuelve la duración total.
func play(sequence: Array) -> float:
	_keys = [{"t": 0.0, "xf": _base}]
	var t := 0.0
	for step: Array in sequence:
		t += step[1]
		_keys.append({"t": t, "xf": pose(step[0])})
	_time = 0.0
	_playing = true
	return t


func is_playing() -> bool:
	return _playing


func _process(delta: float) -> void:
	if _playing:
		_time += delta
		var sample := floorf(_time * FPS) / FPS
		var last: Dictionary = _keys.back()
		if sample >= last.t:
			_playing = false
			_base = last.xf
		else:
			for i in _keys.size() - 1:
				var a: Dictionary = _keys[i]
				var b: Dictionary = _keys[i + 1]
				if sample >= a.t and sample < b.t:
					_base = a.xf.interpolate_with(b.xf, (sample - a.t) / (b.t - a.t))
					break
	else:
		var target := pose("block" if holding_block else "rest")
		_base = _base.interpolate_with(target, minf(delta * 16.0, 1.0))

	_bob_t += delta * (5.0 + bob_amount * 6.0)
	var bob := Vector3(sin(_bob_t) * 0.014, -absf(cos(_bob_t)) * 0.02, 0.0) * bob_amount
	_sword.transform = Transform3D(_base.basis, _base.origin + bob)


func _add_box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, rot_deg := Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	PS1Assets.setup_box(mi, size, PS1Assets.flat(color))
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
