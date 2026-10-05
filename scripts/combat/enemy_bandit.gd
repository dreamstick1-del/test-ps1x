class_name Bandit
extends CharacterBody3D
## Bandido con IA sencilla de máquina de estados:
##   IDLE -> CHASE (te ve) -> ATTACK (amago visible, golpe a los 0,5 s) -> CHASE
##   STAGGER: aturdido tras una parada o un golpe fuerte.
##   DEAD: cae de espaldas, da experiencia y desaparece.
## El amago (brazo arriba + destello amarillo) es la señal para bloquear o
## hacer una parada.

signal killed(bandit: Bandit)

enum State { IDLE, CHASE, ATTACK, STAGGER, DEAD }

@export var display_name := "Bandido"
@export var model_path := "res://assets/characters/Character_05.fbx"
@export var outfit := "bandido"
@export var weapon := "axe"
@export var max_health := 45.0
@export var damage := 12.0
@export var move_speed := 3.0
@export var attack_range := 1.7
@export var attack_cooldown := Vector2(1.0, 2.0)
@export var sight_range := 14.0
@export var xp_reward := 25
@export var body_scale := 1.0

var hit_color := Color(0.55, 0.04, 0.04)
var stats: CombatStats
var model: PS1RiggedCharacter
var state: State = State.IDLE

var _timer := 0.0
var _cooldown := 0.6
var _hit_done := false
var _push := Vector3.ZERO
var _stuck_time := 0.0
var _avoid_time := 0.0
var _avoid_side := 1.0
var _player: Node3D


func _ready() -> void:
	add_to_group("damageable")
	add_to_group("enemy")
	var shape := CapsuleShape3D.new()
	shape.radius = 0.32
	shape.height = 1.8
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = 0.9
	add_child(cs)

	stats = CombatStats.new()
	stats.max_health = max_health
	add_child(stats)
	stats.died.connect(_die)

	model = PS1RiggedCharacter.new()
	model.model_path = model_path
	model.outfit = outfit
	model.weapon = weapon
	model.body_scale = body_scale
	add_child(model)


func is_alive() -> bool:
	return state != State.DEAD


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	if state == State.DEAD:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node3D

	_timer -= delta
	_cooldown -= delta
	var desired := Vector3.ZERO
	var active: bool = GameManager.is_playing() and _player != null and _player.is_alive()

	if not active:
		model.play("idle")
	else:
		var to := _player.global_position - global_position
		to.y = 0.0
		var dist := to.length()
		match state:
			State.IDLE:
				model.play("idle")
				if dist < sight_range:
					state = State.CHASE
			State.CHASE:
				_face(to, delta, 8.0)
				if dist <= attack_range and _cooldown <= 0.0:
					_start_attack()
				elif dist > attack_range * 0.8:
					desired = _steer(to / dist, delta) * move_speed * (1.25 if dist > 5.0 else 1.0)
					model.play("run" if dist > 5.0 else "walk")
				else:
					model.play("idle")
			State.ATTACK:
				if _timer > 0.5:
					_face(to, delta, 4.0) # Corrige la puntería durante el amago.
				if not _hit_done and _timer <= 0.45:
					_hit_done = true
					_try_hit(to, dist)
				if _timer <= 0.0:
					state = State.CHASE
					_cooldown = randf_range(attack_cooldown.x, attack_cooldown.y)
			State.STAGGER:
				if _timer <= 0.0:
					state = State.CHASE

	desired += _separation()
	velocity.x = desired.x + _push.x
	velocity.z = desired.z + _push.z
	_push = _push.move_toward(Vector3.ZERO, 12.0 * delta)
	move_and_slide()


func _start_attack() -> void:
	state = State.ATTACK
	_timer = 0.95
	_hit_done = false
	model.play_once("attack")
	model.flash(Color(1.6, 1.4, 0.6), 0.15) # Aviso: ¡va a golpear!


func _try_hit(to: Vector3, dist: float) -> void:
	var fwd := -global_transform.basis.z
	if dist <= attack_range + 0.5 and dist > 0.01 and fwd.dot(to / dist) > 0.5:
		_player.receive_hit({"damage": damage, "knockback": to / dist * 2.5, "source": self})


func receive_hit(hit: Dictionary) -> void:
	if state == State.DEAD:
		return
	stats.take_damage(hit.damage)
	if state == State.DEAD:
		return
	model.flash(Color(2.0, 0.4, 0.4), 0.12)
	_push = hit.knockback
	# Los golpes ligeros no interrumpen un ataque ya lanzado (hay que bloquear).
	if hit.get("heavy", false) or state != State.ATTACK:
		stagger(hit.stagger)


func stagger(duration: float) -> void:
	if state == State.DEAD:
		return
	state = State.STAGGER
	_timer = duration
	model.play_once("hit")


func _die() -> void:
	state = State.DEAD
	remove_from_group("damageable")
	collision_layer = 0
	model.play_once("hit")
	var tween := create_tween()
	tween.tween_property(model, "rotation:x", PI / 2, 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_interval(8.0)
	tween.tween_property(model, "position:y", -0.6, 2.0)
	tween.tween_callback(queue_free)
	Skills.add_xp(xp_reward)
	GameManager.show_message("+%d XP" % xp_reward, Color(0.7, 0.9, 1.0), 1.0)
	killed.emit(self)


func _face(to: Vector3, delta: float, speed: float) -> void:
	if to.length() < 0.01:
		return
	var target := atan2(-to.x, -to.z)
	rotation.y = lerp_angle(rotation.y, target, minf(speed * delta, 1.0))


## Persecución directa; si se queda atascado contra algo, rodea por un lado.
func _steer(dir: Vector3, delta: float) -> Vector3:
	if _avoid_time > 0.0:
		_avoid_time -= delta
		return dir.rotated(Vector3.UP, 1.1 * _avoid_side)
	if get_real_velocity().length() < move_speed * 0.25:
		_stuck_time += delta
		if _stuck_time > 0.35:
			_stuck_time = 0.0
			_avoid_time = 0.7
			_avoid_side = 1.0 if randf() < 0.5 else -1.0
	else:
		_stuck_time = 0.0
	return dir


## Evita que los bandidos se amontonen unos encima de otros.
func _separation() -> Vector3:
	var push := Vector3.ZERO
	for other: Node3D in get_tree().get_nodes_in_group("enemy"):
		if other == self:
			continue
		var d := global_position - other.global_position
		d.y = 0.0
		if d.length() < 1.1 and d.length() > 0.01:
			push += d.normalized() * (1.1 - d.length()) * 3.0
	return push
