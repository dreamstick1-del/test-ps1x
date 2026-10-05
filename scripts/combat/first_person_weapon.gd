class_name FirstPersonWeapon
extends Node3D
## Arma, brazo y escudo de Henry en primera persona (hijo de la cámara).
## Las animaciones son secuencias de poses clave muestreadas a 15 fps:
## el arma salta de pose en pose, entrecortada como en un juego de PS1.
##
## El arma cambia con set_weapon() (bajar, cambiar el modelo, subir).
## El escudo va en la mano izquierda y se levanta al bloquear.

const FPS := 15.0

## Poses: [posición respecto a la cámara, rotación en grados].
const POSES := {
	"rest": [Vector3(0.34, -0.36, -0.5), Vector3(-30, -10, -16)],
	"block": [Vector3(0.04, -0.16, -0.46), Vector3(8, 0, 84)],
	"block_shield": [Vector3(0.36, -0.3, -0.42), Vector3(-10, -20, -40)],
	"wind_r": [Vector3(0.50, -0.06, -0.42), Vector3(-15, -55, -75)],
	"slash_l": [Vector3(-0.42, -0.36, -0.56), Vector3(-75, 45, 70)],
	"wind_l": [Vector3(-0.42, -0.08, -0.44), Vector3(-15, 55, 75)],
	"slash_r": [Vector3(0.46, -0.40, -0.56), Vector3(-75, -45, -70)],
	"thrust_back": [Vector3(0.22, -0.22, -0.28), Vector3(-90, 0, 0)],
	"thrust_fwd": [Vector3(0.06, -0.14, -0.95), Vector3(-90, 0, 0)],
	"overhead": [Vector3(0.14, 0.18, -0.30), Vector3(28, 0, -8)],
	"charge": [Vector3(0.26, -0.12, -0.5), Vector3(10, -18, -32)],
	"overhead_down": [Vector3(0.04, -0.46, -0.62), Vector3(-115, 0, 0)],
	"pray": [Vector3(0.10, -0.75, -0.40), Vector3(-10, 0, 0)],
	"run": [Vector3(0.3, -0.52, -0.42), Vector3(-62, -18, -30)],
	"lowered": [Vector3(0.3, -0.95, -0.35), Vector3(-80, -10, -20)],
	"jump": [Vector3(0.36, -0.28, -0.46), Vector3(-15, -12, -22)],
}

## Pose del escudo: [posición, rotación].
const SHIELD_POSES := {
	"rest": [Vector3(-0.5, -0.5, -0.62), Vector3(-15, 55, 10)],
	"block": [Vector3(-0.2, -0.3, -0.7), Vector3(-5, 18, 0)],
	"lowered": [Vector3(-0.5, -1.0, -0.5), Vector3(-30, 60, 10)],
}

## Ajuste del modelo en la mano: escala y desplazamiento a lo largo del mango.
const GRIPS := {
	"spear": {"scale": 0.85, "offset": Vector3(0, -0.35, 0)},
	"dagger": {"scale": 1.0, "offset": Vector3.ZERO},
	"mace": {"scale": 0.9, "offset": Vector3.ZERO},
	"axe": {"scale": 0.9, "offset": Vector3.ZERO},
}

## 0..1, lo fija el jugador según su velocidad (balanceo al andar).
var bob_amount := 0.0
var holding_block := false
var charging := false
var running := false
var airborne := false

var _arm: Node3D
var _model: Node3D
var _model_kind := ""
var _shield: Node3D
var _shield_xf := Transform3D()
var _keys: Array = []
var _time := 0.0
var _playing := false
var _base := Transform3D()
var _bob_t := 0.0
var _swap_t := 0.0
var _pending_kind := ""


func _ready() -> void:
	_arm = Node3D.new()
	add_child(_arm)
	_build_hand()
	_set_model("sword")
	_base = pose("rest")
	_arm.transform = _base
	_shield = Node3D.new()
	var shield_model := WeaponFactory.build("shield")
	WeaponFactory.make_viewmodel(shield_model)
	shield_model.scale = Vector3.ONE * 0.72
	_shield.add_child(shield_model)
	_shield.visible = false
	add_child(_shield)
	_shield_xf = _pose_of(SHIELD_POSES, "rest")


## Cambia de arma: baja la actual, cambia el modelo y sube la nueva.
func set_weapon(kind: String, animate := true) -> void:
	if kind == _model_kind and _pending_kind == "":
		return
	if not animate:
		_set_model(kind)
		return
	_pending_kind = kind
	_swap_t = 0.36


func set_shield(enabled: bool) -> void:
	_shield.visible = enabled


func is_swapping() -> bool:
	return _swap_t > 0.0


func pose(pose_name: String) -> Transform3D:
	return _pose_of(POSES, pose_name)


func _pose_of(table: Dictionary, pose_name: String) -> Transform3D:
	var p: Array = table[pose_name]
	var rot: Vector3 = p[1]
	return Transform3D(Basis.from_euler(rot * (PI / 180.0)), p[0])


## Reproduce [[pose, duración], ...] a `speed`x. Devuelve la duración total.
func play(sequence: Array, speed := 1.0) -> float:
	_keys = [{"t": 0.0, "xf": _base}]
	var t := 0.0
	for step: Array in sequence:
		t += step[1] / speed
		_keys.append({"t": t, "xf": pose(step[0])})
	_time = 0.0
	_playing = true
	return t


func is_playing() -> bool:
	return _playing


func _process(delta: float) -> void:
	if _swap_t > 0.0:
		_swap_t -= delta
		if _pending_kind != "" and _swap_t <= 0.18:
			_set_model(_pending_kind)
			_pending_kind = ""
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
		var target_name := "rest"
		if _swap_t > 0.0:
			target_name = "lowered"
		elif charging:
			target_name = "charge"
		elif holding_block:
			target_name = "block_shield" if _shield.visible else "block"
		elif airborne:
			target_name = "jump"
		elif running:
			target_name = "run"
		_base = _base.interpolate_with(pose(target_name), minf(delta * 16.0, 1.0))

	var shield_target := "rest"
	if _swap_t > 0.0 or running:
		shield_target = "lowered"
	elif holding_block:
		shield_target = "block"
	_shield_xf = _shield_xf.interpolate_with(_pose_of(SHIELD_POSES, shield_target), minf(delta * 14.0, 1.0))

	_bob_t += delta * (5.0 + bob_amount * 6.0)
	var bob := Vector3(sin(_bob_t) * 0.014, -absf(cos(_bob_t)) * 0.02, 0.0) * bob_amount
	var shake := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * 0.006 if charging else Vector3.ZERO
	_arm.transform = Transform3D(_base.basis, _base.origin + bob + shake)
	_shield.transform = Transform3D(_shield_xf.basis, _shield_xf.origin + bob * 0.8)


## Puño y manga de Henry (fijos); el modelo del arma va encima.
func _build_hand() -> void:
	var skin := Color(0.86, 0.66, 0.52)
	var sleeve := Color(0.82, 0.76, 0.62)
	var hand := Node3D.new()
	hand.name = "Hand"
	_add_box(hand, Vector3(0.09, 0.11, 0.1), Vector3(0, 0.0, 0.0), skin)
	_add_box(hand, Vector3(0.1, 0.3, 0.11), Vector3(0.02, -0.12, 0.2), sleeve, Vector3(-60, 0, 0))
	WeaponFactory.make_viewmodel(hand)
	_arm.add_child(hand)


func _set_model(kind: String) -> void:
	if _model:
		_model.queue_free()
	_model_kind = kind
	_model = WeaponFactory.build(kind)
	WeaponFactory.make_viewmodel(_model)
	var grip: Dictionary = GRIPS.get(kind, {"scale": 0.85, "offset": Vector3.ZERO})
	_model.scale = Vector3.ONE * grip.scale
	_model.position = grip.offset
	_arm.add_child(_model)


func _add_box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, rot_deg := Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	PS1Assets.setup_box(mi, size, PS1Assets.flat(color))
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
