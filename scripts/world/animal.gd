class_name Animal
extends CharacterBody3D
## Animal low-poly con comportamiento sencillo:
##   - Pasta y deambula alrededor de su "casa".
##   - Las presas (ciervos, conejos, gallinas...) huyen si Henry se acerca.
##   - El perro sigue a Henry de lejos. Los lobos atacan.
## Se puede cazar: deja carne/pieles en el inventario. Matar ganado ajeno
## baja la reputación de Henry.

const SPECIES := {
	"gallina": {"name": "Gallina", "hp": 5.0, "speed": 1.6, "flee": 3.5, "radius": 0.2, "drops": {"carne": 1}, "livestock": true},
	"cerdo": {"name": "Cerdo", "hp": 30.0, "speed": 1.8, "flee": 2.0, "radius": 0.35, "drops": {"carne": 3}, "livestock": true},
	"oveja": {"name": "Oveja", "hp": 20.0, "speed": 1.8, "flee": 3.5, "radius": 0.35, "drops": {"carne": 2, "lana": 1}, "livestock": true},
	"vaca": {"name": "Vaca", "hp": 50.0, "speed": 1.3, "flee": 0.0, "radius": 0.5, "drops": {"carne": 5, "pieles": 1}, "livestock": true},
	"perro": {"name": "Perro", "hp": 25.0, "speed": 4.0, "flee": 0.0, "radius": 0.25, "drops": {}, "livestock": true, "follow": true},
	"ciervo": {"name": "Ciervo", "hp": 30.0, "speed": 6.5, "flee": 12.0, "radius": 0.35, "drops": {"carne": 3, "pieles": 2}},
	"conejo": {"name": "Conejo", "hp": 5.0, "speed": 5.0, "flee": 6.0, "radius": 0.15, "drops": {"carne": 1, "pieles": 1}},
	"lobo": {"name": "Lobo", "hp": 35.0, "speed": 5.2, "flee": 0.0, "radius": 0.3, "drops": {"pieles": 2},
		"hostile": true, "aggro": 11.0, "damage": 9.0},
}

enum State { IDLE, WANDER, FLEE, CHASE, ATTACK, STAGGER, DEAD }

@export var species := "gallina"
@export var home_radius := 5.0

var display_name := ""
var hit_color := Color(0.6, 0.05, 0.05)
var stats: CombatStats
var state: State = State.IDLE

var _def: Dictionary
var _home := Vector3.ZERO
var _target := Vector3.ZERO
var _timer := 0.0
var _cooldown := 0.0
var _hit_done := false
var _push := Vector3.ZERO
var _anim_t := 0.0
var _visual: Node3D
var _legs: Array[Node3D] = []
var _head: Node3D
var _player: Node3D


func _ready() -> void:
	_def = SPECIES[species]
	display_name = _def.name
	add_to_group("damageable")
	add_to_group("animal")
	if _def.get("hostile", false):
		add_to_group("enemy")
	_home = global_position
	_timer = randf_range(0.0, 3.0)

	var shape := CapsuleShape3D.new()
	shape.radius = _def.radius
	shape.height = maxf(_def.radius * 2.0 + 0.1, 0.5)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = shape.height * 0.5
	add_child(cs)
	collision_layer = 1
	stats = CombatStats.new()
	stats.max_health = _def.hp
	add_child(stats)
	stats.died.connect(_die)
	_visual = Node3D.new()
	add_child(_visual)
	_build_body()


func is_alive() -> bool:
	return state != State.DEAD


# --- Cuerpo ------------------------------------------------------------------

func _build_body() -> void:
	match species:
		"gallina":
			_part(_visual, Vector3(0.26, 0.24, 0.34), Vector3(0, 0.3, 0), Color(0.95, 0.93, 0.88))
			_head = _pivot(Vector3(0, 0.42, -0.15))
			_part(_head, Vector3(0.13, 0.15, 0.13), Vector3(0, 0.06, 0), Color(0.95, 0.93, 0.88))
			_part(_head, Vector3(0.04, 0.07, 0.1), Vector3(0, 0.16, 0), Color(0.85, 0.1, 0.08))
			_part(_head, Vector3(0.05, 0.04, 0.06), Vector3(0, 0.05, -0.09), Color(0.95, 0.75, 0.2))
			_part(_visual, Vector3(0.18, 0.2, 0.08), Vector3(0, 0.42, 0.17), Color(0.85, 0.83, 0.78))
			for x: float in [-0.06, 0.06]:
				_leg(Vector3(x, 0.19, 0), Vector3(0.03, 0.19, 0.03), Color(0.95, 0.75, 0.2))
		"conejo":
			_part(_visual, Vector3(0.2, 0.2, 0.32), Vector3(0, 0.16, 0), Color(0.55, 0.5, 0.45))
			_head = _pivot(Vector3(0, 0.26, -0.16))
			_part(_head, Vector3(0.14, 0.14, 0.14), Vector3(0, 0.02, -0.04), Color(0.55, 0.5, 0.45))
			for x: float in [-0.04, 0.04]:
				_part(_head, Vector3(0.04, 0.18, 0.03), Vector3(x, 0.16, 0), Color(0.6, 0.55, 0.5))
			_part(_visual, Vector3(0.08, 0.08, 0.06), Vector3(0, 0.2, 0.18), Color(0.95, 0.95, 0.95))
			for p: Vector3 in [Vector3(-0.07, 0.07, -0.1), Vector3(0.07, 0.07, -0.1), Vector3(-0.07, 0.07, 0.1), Vector3(0.07, 0.07, 0.1)]:
				_leg(p, Vector3(0.05, 0.08, 0.08), Color(0.5, 0.45, 0.4))
		_:
			_quadruped()


## [cuerpo, color, altura de patas, cabeza, color de cabeza, color de patas]
func _quadruped() -> void:
	var specs := {
		"cerdo": [Vector3(0.5, 0.42, 0.9), Color(0.9, 0.65, 0.6), 0.25, Vector3(0.36, 0.34, 0.3), Color(0.9, 0.65, 0.6), Color(0.85, 0.6, 0.55)],
		"oveja": [Vector3(0.55, 0.5, 0.8), Color(0.92, 0.9, 0.82), 0.38, Vector3(0.2, 0.24, 0.3), Color(0.2, 0.18, 0.16), Color(0.2, 0.18, 0.16)],
		"vaca": [Vector3(0.7, 0.7, 1.5), Color(0.55, 0.38, 0.25), 0.6, Vector3(0.34, 0.38, 0.5), Color(0.92, 0.9, 0.85), Color(0.45, 0.32, 0.22)],
		"perro": [Vector3(0.28, 0.3, 0.7), Color(0.55, 0.4, 0.25), 0.34, Vector3(0.24, 0.24, 0.3), Color(0.55, 0.4, 0.25), Color(0.45, 0.32, 0.2)],
		"ciervo": [Vector3(0.38, 0.5, 1.05), Color(0.6, 0.42, 0.26), 0.75, Vector3(0.2, 0.24, 0.36), Color(0.6, 0.42, 0.26), Color(0.5, 0.35, 0.22)],
		"lobo": [Vector3(0.34, 0.42, 0.95), Color(0.45, 0.45, 0.47), 0.5, Vector3(0.26, 0.26, 0.38), Color(0.4, 0.4, 0.42), Color(0.35, 0.35, 0.37)],
	}
	var s: Array = specs[species]
	var body: Vector3 = s[0]
	var leg_h: float = s[2]
	_part(_visual, body, Vector3(0, leg_h + body.y * 0.5, 0), s[1])
	var neck_up := 0.35 if species in ["ciervo"] else 0.1
	_head = _pivot(Vector3(0, leg_h + body.y * 0.75 + neck_up, -body.z * 0.5))
	var head: Vector3 = s[3]
	_part(_head, head, Vector3(0, 0, -head.z * 0.45), s[4])
	if species == "ciervo":
		_part(_visual, Vector3(0.16, 0.45, 0.16), Vector3(0, leg_h + body.y + 0.05, -body.z * 0.45), s[1])
		for x: float in [-0.08, 0.08]:
			_part(_head, Vector3(0.03, 0.35, 0.03), Vector3(x, 0.27, 0.02), Color(0.85, 0.8, 0.7))
			_part(_head, Vector3(0.18, 0.03, 0.03), Vector3(x * 1.8, 0.36, 0.02), Color(0.85, 0.8, 0.7))
	if species == "vaca":
		for x: float in [-0.2, 0.2]:
			_part(_head, Vector3(0.14, 0.05, 0.05), Vector3(x, 0.2, 0.05), Color(0.9, 0.88, 0.8))
		_part(_visual, Vector3(0.72, 0.35, 0.5), Vector3(0, leg_h + 0.45, 0.2), Color(0.95, 0.93, 0.9))
	if species == "cerdo":
		_part(_head, Vector3(0.16, 0.12, 0.06), Vector3(0, -0.04, -0.17), Color(0.95, 0.6, 0.6))
	if species in ["perro", "lobo"]:
		_part(_head, Vector3(0.12, 0.12, 0.18), Vector3(0, -0.04, -0.25), s[4].darkened(0.1))
		for x: float in [-0.08, 0.08]:
			_part(_head, Vector3(0.06, 0.12, 0.04), Vector3(x, 0.17, 0.0), s[4].darkened(0.2))
		_part(_visual, Vector3(0.08, 0.08, 0.35), Vector3(0, leg_h + body.y * 0.8, body.z * 0.6), s[1])
	if species == "lobo":
		for x: float in [-0.06, 0.06]:
			_part(_head, Vector3(0.04, 0.03, 0.01), Vector3(x, 0.05, -0.2), Color(1.0, 0.8, 0.2))
	for p: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		_leg(Vector3(p.x * body.x * 0.32, leg_h, p.y * body.z * 0.38), Vector3(0.1, leg_h, 0.1), s[5])


func _pivot(pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	_visual.add_child(n)
	return n


func _leg(pivot_pos: Vector3, size: Vector3, color: Color) -> void:
	var pivot := _pivot(pivot_pos)
	_part(pivot, size, Vector3(0, -size.y * 0.5, 0), color)
	_legs.append(pivot)


func _part(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.position = pos
	mi.material_override = PS1Assets.flat(color)
	parent.add_child(mi)


# --- Comportamiento -------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = -0.5
	if state == State.DEAD:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node3D
	_timer -= delta
	_cooldown -= delta

	var playing: bool = GameManager.is_playing() and _player != null and _player.is_alive()
	var to_player := Vector3.ZERO
	var dist := INF
	if playing:
		to_player = _player.global_position - global_position
		to_player.y = 0.0
		dist = to_player.length()

	var move := Vector3.ZERO
	var speed: float = _def.speed
	match state:
		State.IDLE, State.WANDER:
			if playing and _def.get("hostile", false) and dist < _def.aggro:
				state = State.CHASE
			elif playing and _def.flee > 0.0 and dist < _def.flee:
				state = State.FLEE
				_timer = 2.5
			elif playing and _def.get("follow", false) and dist > 5.0 and dist < 18.0:
				move = to_player / dist * speed * 0.8
			elif state == State.WANDER:
				var to := _target - global_position
				to.y = 0.0
				if to.length() < 0.4 or _timer <= 0.0:
					state = State.IDLE
					_timer = randf_range(2.0, 6.0)
				else:
					move = to.normalized() * speed * 0.35
			elif _timer <= 0.0:
				var a := randf() * TAU
				_target = _home + Vector3(cos(a), 0, sin(a)) * randf() * home_radius
				state = State.WANDER
				_timer = 8.0
		State.FLEE:
			if dist > 0.01:
				move = -to_player / dist * speed
			if _timer <= 0.0 and dist > _def.flee:
				state = State.IDLE
		State.CHASE:
			if not playing or dist > _def.aggro * 1.8:
				state = State.IDLE
			elif dist < 1.5 and _cooldown <= 0.0:
				state = State.ATTACK
				_timer = 0.7
				_hit_done = false
			elif dist > 1.2:
				move = to_player / dist * speed
		State.ATTACK:
			if not _hit_done and _timer <= 0.35:
				_hit_done = true
				var fwd := -global_transform.basis.z
				if dist < 2.0 and fwd.dot(to_player / maxf(dist, 0.01)) > 0.4:
					_player.receive_hit({"damage": _def.damage, "knockback": to_player.normalized() * 2.0, "source": self})
			if _timer <= 0.0:
				state = State.CHASE
				_cooldown = randf_range(1.0, 1.8)
		State.STAGGER:
			if _timer <= 0.0:
				state = State.CHASE if _def.get("hostile", false) else State.FLEE
				_timer = 2.0

	if state == State.CHASE or state == State.ATTACK:
		_face(to_player, delta, 10.0)
	elif move.length() > 0.05:
		_face(move, delta, 6.0)

	velocity.x = move.x + _push.x
	velocity.z = move.z + _push.z
	_push = _push.move_toward(Vector3.ZERO, 10.0 * delta)
	move_and_slide()
	_animate(delta, Vector2(velocity.x, velocity.z).length())


## Patas a saltos (8 poses por segundo) y cabeza que baja a pastar.
func _animate(delta: float, hspeed: float) -> void:
	_anim_t += delta
	var frame := floorf(_anim_t * 8.0)
	var swing := 0.0
	if hspeed > 0.2:
		swing = [0.5, 0.0, -0.5, 0.0][int(frame) % 4] * clampf(hspeed / 2.0, 0.5, 1.2)
	for i in _legs.size():
		_legs[i].rotation.x = swing * (1.0 if i % 2 == (i / 2) % 2 else -1.0)
	if _head:
		var grazing := state == State.IDLE and int(_anim_t * 0.5) % 3 != 0 and species not in ["lobo", "perro"]
		_head.rotation.x = -0.6 if grazing else (0.25 if state == State.ATTACK and _timer > 0.35 else 0.0)


func _face(dir: Vector3, delta: float, speed: float) -> void:
	if dir.length() < 0.01:
		return
	rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), minf(speed * delta, 1.0))


# --- Combate ---------------------------------------------------------------------

func receive_hit(hit: Dictionary) -> void:
	if state == State.DEAD:
		return
	stats.take_damage(hit.damage)
	_push = hit.knockback * 1.2
	if state != State.DEAD:
		stagger(0.4)


func stagger(duration: float) -> void:
	if state == State.DEAD:
		return
	state = State.STAGGER
	_timer = duration


func _die() -> void:
	state = State.DEAD
	remove_from_group("damageable")
	remove_from_group("enemy")
	collision_layer = 0
	var tween := create_tween()
	tween.tween_property(_visual, "rotation:z", PI / 2, 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_interval(6.0)
	tween.tween_property(_visual, "position:y", -0.6, 1.5)
	tween.tween_callback(queue_free)
	var loot := []
	for good: String in _def.drops:
		Economy.add_item(good, _def.drops[good])
		loot.append("+%d %s" % [_def.drops[good], Economy.GOODS[good].name])
	if not loot.is_empty():
		GameManager.show_message("  ".join(loot), Color(0.85, 0.9, 1.0), 1.4)
	if _def.get("livestock", false):
		Economy.change_reputation(-12.0, "Alguien ha matado un animal ajeno (%s). La gente murmura." % display_name.to_lower())
	elif _def.get("hostile", false):
		Skills.add_xp(15)
	else:
		Skills.add_xp(5)
