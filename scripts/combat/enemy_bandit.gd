class_name Bandit
extends CharacterBody3D
## Bandido con IA sencilla de máquina de estados:
##   IDLE -> TAUNT (te ve y te provoca) -> CHASE -> ATTACK -> CHASE
##   CHASE: se acerca y, mientras recupera el aliento, te rodea de lado o
##          retrocede para no quedarse pegado.
##   ATTACK: tres ataques (ver ATTACKS) con amago visible y destello de aviso.
##           El pesado (destello rojo) gasta mucho aguante si lo bloqueas:
##           mejor esquivarlo o hacer una parada.
##   BLOCK: se cubre. STAGGER: aturdido. DEAD: cae de rodillas y de espaldas.

signal killed(bandit: Bandit)

enum State { IDLE, CHASE, ATTACK, STAGGER, DEAD, BLOCK, TAUNT }

## anim, duración, instante del golpe (s desde el inicio), daño x, alcance extra,
## color del aviso, golpe pesado.
const ATTACKS := {
	"tajo": {"anim": "attack", "time": 0.95, "hit_at": 0.5, "mult": 1.0, "reach": 0.0,
		"flash": Color(1.6, 1.4, 0.6), "heavy": false},
	"pesado": {"anim": "attack_heavy", "time": 1.4, "hit_at": 0.72, "mult": 1.7, "reach": 0.25,
		"flash": Color(2.0, 0.7, 0.4), "heavy": true},
	"estocada": {"anim": "attack_thrust", "time": 1.05, "hit_at": 0.45, "mult": 0.85, "reach": 0.8,
		"flash": Color(1.6, 1.4, 0.6), "heavy": false},
}
## Preferencias de ataque según el arma: [tajo, pesado, estocada].
const ATTACK_WEIGHTS := {
	"sword": [0.5, 0.15, 0.35],
	"axe": [0.55, 0.35, 0.1],
	"hammer": [0.45, 0.45, 0.1],
}

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
## Probabilidad de cubrirse cuando Henry está cerca y no le toca atacar.
@export var block_chance := 0.3

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
var _attack: Dictionary = ATTACKS["tajo"]
var _strafe_dir := 1.0
var _strafe_t := 0.0


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


## Todavía no ha visto a Henry (para el ataque sigiloso).
func is_unaware() -> bool:
	return state == State.IDLE


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
				# Agachado, Henry pasa desapercibido hasta estar mucho más cerca.
				var sight := sight_range * (0.35 if _player.get("is_crouching") else 1.0)
				if dist < sight:
					if dist > 4.0 and randf() < 0.6:
						state = State.TAUNT
						_timer = 1.0
						model.play_once("taunt")
					else:
						state = State.CHASE
			State.TAUNT:
				_face(to, delta, 6.0)
				if _timer <= 0.0 or dist < 2.5:
					state = State.CHASE
			State.CHASE:
				_face(to, delta, 8.0)
				if dist <= attack_range and _cooldown <= 0.0:
					_start_attack()
				elif dist <= attack_range + 0.8 and _cooldown > 0.3 and randf() < block_chance * delta * 2.0:
					state = State.BLOCK
					_timer = randf_range(0.6, 1.1)
					model.play_once("block")
				elif dist > attack_range + 1.4 or (dist > attack_range * 0.8 and _cooldown <= 0.0):
					var spd := move_speed * (1.25 if dist > 5.0 else 1.0)
					desired = _steer(to / dist, delta) * spd
					model.play_moving("run" if dist > 5.0 else "walk", spd)
				elif dist < attack_range * 0.6:
					# Demasiado cerca: un paso atrás.
					desired = -to / dist * move_speed * 0.5
					model.play_moving("walk_back", move_speed * 0.5)
				else:
					desired = _circle(to / dist, delta)
			State.ATTACK:
				var elapsed: float = _attack.time - _timer
				if _attack.anim == "attack_thrust" and elapsed > 0.38 and elapsed < 0.5:
					desired = to / maxf(dist, 0.01) * 3.0 # Paso adelante de la estocada.
				if elapsed < _attack.hit_at - 0.15:
					_face(to, delta, 4.0) # Corrige la puntería durante el amago.
				if not _hit_done and elapsed >= _attack.hit_at:
					_hit_done = true
					_try_hit(to, dist)
				if _timer <= 0.0:
					state = State.CHASE
					_cooldown = randf_range(attack_cooldown.x, attack_cooldown.y)
			State.STAGGER:
				if _timer <= 0.0:
					state = State.CHASE
			State.BLOCK:
				_face(to, delta, 6.0)
				if _timer <= 0.0:
					state = State.CHASE

	desired += _separation()
	velocity.x = desired.x + _push.x
	velocity.z = desired.z + _push.z
	_push = _push.move_toward(Vector3.ZERO, 12.0 * delta)
	move_and_slide()


func _start_attack() -> void:
	state = State.ATTACK
	var weights: Array = ATTACK_WEIGHTS.get(weapon, ATTACK_WEIGHTS["sword"])
	var roll := randf()
	var key := "estocada"
	if roll < weights[0]:
		key = "tajo"
	elif roll < weights[0] + weights[1]:
		key = "pesado"
	_attack = ATTACKS[key]
	_timer = _attack.time
	_hit_done = false
	model.play_once(_attack.anim)
	model.flash(_attack.flash, 0.3 if _attack.heavy else 0.15) # Aviso: ¡va a golpear!


func _try_hit(to: Vector3, dist: float) -> void:
	var fwd := -global_transform.basis.z
	var reach: float = attack_range + 0.5 + _attack.reach
	if dist <= reach and dist > 0.01 and fwd.dot(to / dist) > 0.5:
		_player.receive_hit({"damage": damage * _attack.mult, "knockback": to / dist * (4.5 if _attack.heavy else 2.5),
			"heavy": _attack.heavy, "source": self})


## Rodea a Henry de lado mientras espera para atacar; cambia de sentido de vez en cuando.
func _circle(dir: Vector3, delta: float) -> Vector3:
	_strafe_t -= delta
	if _strafe_t <= 0.0:
		_strafe_t = randf_range(0.8, 1.8)
		_strafe_dir = 1.0 if randf() < 0.5 else -1.0
	if get_real_velocity().length() < 0.2 and _strafe_t < 0.5:
		_strafe_dir = -_strafe_dir # Contra una pared: al otro lado.
		_strafe_t = 1.0
	model.play_moving("strafe_r" if _strafe_dir > 0.0 else "strafe_l", move_speed * 0.5)
	return dir.cross(Vector3.UP) * _strafe_dir * move_speed * 0.5


func receive_hit(hit: Dictionary) -> void:
	if state == State.DEAD:
		return
	if state == State.BLOCK:
		var from: Node3D = hit.source
		var to := from.global_position - global_position
		to.y = 0.0
		var facing := (-global_transform.basis.z).dot(to.normalized()) > 0.3
		if facing:
			if hit.get("heavy", false) or hit.get("guard_break", false):
				GameManager.show_message("¡GUARDIA ROTA!", Color(1.0, 0.75, 0.3), 0.8)
				CombatFX.burst(get_parent(), global_position + Vector3(0, 1.3, 0), Color(1.0, 0.85, 0.4), 14, 4.0)
				stats.take_damage(hit.damage * 0.6)
				if state != State.DEAD:
					stagger(1.4)
				return
			GameManager.show_message("Bloqueado", Color(0.8, 0.8, 0.85), 0.5)
			CombatFX.burst(get_parent(), global_position + Vector3(0, 1.3, 0), Color(1.0, 0.95, 0.7), 6, 2.5)
			stats.take_damage(hit.damage * 0.15)
			_push = hit.knockback * 0.5
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
	model.play_once("death")
	var tween := create_tween()
	tween.tween_interval(0.55)
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
