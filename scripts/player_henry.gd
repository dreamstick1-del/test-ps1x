extends CharacterBody3D
## Henry en primera persona, al estilo King's Field (PS1):
## ratón/stick derecho para mirar, WASD para andar y desplazarse de lado,
## flechas ←/→ para girar con teclado. El combate vive en PlayerCombat.
##
## Movimientos:
##   andar / correr (Shift, gasta aguante) con aceleración e inercia,
##   saltar (Espacio, con margen de "coyote" y salto guardado),
##   agacharse (Ctrl, más lento y sigiloso; no se levanta bajo un techo),
##   esquivar (Alt, impulso corto con invulnerabilidad),
##   caídas: la cámara se hunde al aterrizar; desde muy alto, daño.
## Su cuerpo (Model) solo lo ve la cámara del diorama: la cámara de los ojos
## no renderiza la capa 2.

@export_group("Movimiento")
@export var velocidad_caminar: float = 3.0
@export var velocidad_correr: float = 5.2
@export var velocidad_retroceso: float = 2.2
@export var gravedad: float = 20.0
@export var consumo_correr: float = 16.0 ## Aguante por segundo.
@export var velocidad_agachado: float = 1.5
@export var aceleracion: float = 18.0
@export var aceleracion_aire: float = 4.0
@export var fuerza_salto: float = 6.4
@export var coste_salto: float = 8.0
@export var velocidad_esquiva: float = 8.5
@export var coste_esquiva: float = 15.0

const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.15
const EYE_STAND := 1.62
const EYE_CROUCH := 1.0

@export_group("Cámara")
@export var sensibilidad_raton: float = 0.12 ## Grados por píxel.
@export var velocidad_giro_teclas: float = 140.0 ## Grados por segundo.
@export var velocidad_mirar: float = 110.0 ## Stick derecho / RePág-AvPág.
@export var balanceo_al_andar: bool = true

const BODY_LAYER := 2

var is_running := false
var is_crouching := false
## Mientras sea > 0 los golpes no hacen daño (esquiva).
var invulnerable := 0.0

var _coyote := 0.0
var _jump_buffer := 0.0
var _dodge_t := 0.0
var _dodge_dir := Vector3.ZERO
var _fall_speed := 0.0
var _land_dip := 0.0
var _was_on_floor := true
var _move_vel := Vector3.ZERO
var _pitch := 0.0
var _bob_t := 0.0
var _shake := 0.0
var _push := Vector3.ZERO
var _spin_left := 0.0
var _spin_speed := 0.0
var _last_reported := Vector2(-1, -1)

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var weapon: FirstPersonWeapon = $Head/Camera3D/Weapon
@onready var stats: CombatStats = $Stats
@onready var combat: PlayerCombat = $Combat
## PS1RiggedCharacter (modelo FBX) o PS1Character (cajas): ambos exponen play().
@onready var model = $Model
@onready var collider: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	camera.cull_mask &= ~(1 << (BODY_LAYER - 1))
	if model.has_method("set_visual_layer"):
		model.set_visual_layer(BODY_LAYER)
	_set_capsule(STAND_HEIGHT)
	stats.health_changed.connect(func(_h: float, _m: float) -> void: _report())
	stats.stamina_changed.connect(func(_s: float, _m: float) -> void: _report())
	GameManager.player_died.connect(_on_died)
	_report()


## Movimiento de ratón (lo reenvía la escena principal desde el viewport raíz).
func add_look(relative: Vector2) -> void:
	if not GameManager.is_playing() or stats.dead:
		return
	rotate_y(-deg_to_rad(relative.x * sensibilidad_raton))
	_pitch = clampf(_pitch - deg_to_rad(relative.y * sensibilidad_raton), -1.35, 1.35)


func _physics_process(delta: float) -> void:
	var playing := GameManager.is_playing() and not stats.dead
	var input := Vector2.ZERO
	if playing:
		input = Input.get_vector("izquierda", "derecha", "adelante", "atras")
		var turn := Input.get_axis("girar_derecha", "girar_izquierda")
		rotate_y(deg_to_rad(velocidad_giro_teclas) * turn * delta)
		var look := Input.get_axis("mirar_abajo", "mirar_arriba")
		_pitch = clampf(_pitch + deg_to_rad(velocidad_mirar) * look * delta, -1.35, 1.35)
		_update_interaction()
		if Input.is_action_just_pressed("interactuar") and GameManager.can_interact():
			_talk_to(GameManager.interactable)

	if _spin_left > 0.0:
		rotate_y(_spin_speed * delta)
		_spin_left -= delta
	invulnerable -= delta

	var on_floor := is_on_floor()
	_coyote = 0.12 if on_floor else _coyote - delta
	_jump_buffer -= delta
	_update_crouch(playing, delta)

	is_running = playing and input.y < -0.1 and Input.is_action_pressed("sprint") \
		and stats.stamina > 0.0 and not combat.is_blocking and not is_crouching
	var speed := velocidad_caminar
	if is_crouching:
		speed = velocidad_agachado
	elif is_running:
		speed = velocidad_correr
	elif input.y > 0.1:
		speed = velocidad_retroceso
	if combat.is_blocking:
		speed *= 0.5
	speed *= combat.move_speed_factor()

	var dir := transform.basis * Vector3(input.x, 0.0, input.y)
	if dir.length() > 1.0:
		dir = dir.normalized()

	# Esquiva: impulso corto en la dirección de la marcha (o hacia atrás).
	if playing and Input.is_action_just_pressed("esquivar") and _dodge_t <= 0.0 and on_floor:
		if stats.spend_stamina(coste_esquiva):
			_dodge_dir = dir.normalized() if dir.length() > 0.1 else transform.basis.z
			_dodge_t = 0.24
			invulnerable = 0.32
			model.play("run")
	if _dodge_t > 0.0:
		_dodge_t -= delta
		_move_vel = _dodge_dir * velocidad_esquiva
	else:
		# Aceleración e inercia: en el aire apenas se puede corregir.
		var accel := (aceleracion if on_floor else aceleracion_aire) * maxf(speed, 2.0) * delta
		_move_vel = _move_vel.move_toward(dir * speed, accel)
	velocity.x = _move_vel.x + _push.x
	velocity.z = _move_vel.z + _push.z
	_push = _push.move_toward(Vector3.ZERO, 14.0 * delta)

	# Salto (con salto guardado: pulsar justo antes de aterrizar también vale).
	if playing and Input.is_action_just_pressed("saltar"):
		_jump_buffer = 0.15
	if _jump_buffer > 0.0 and _coyote > 0.0 and not is_crouching and _dodge_t <= 0.0:
		if stats.spend_stamina(coste_salto):
			velocity.y = fuerza_salto
			_coyote = 0.0
			_jump_buffer = 0.0
	elif on_floor and velocity.y <= 0.0:
		velocity.y = -0.5
	else:
		velocity.y -= gravedad * delta
	_fall_speed = minf(_fall_speed, velocity.y)
	move_and_slide()
	_check_landing()

	if is_running:
		stats.drain_stamina(consumo_correr * delta)
	stats.regen_blocked = is_running or combat.is_blocking
	weapon.running = is_running
	weapon.airborne = not is_on_floor()
	_update_camera(delta, Vector2(velocity.x, velocity.z).length())
	_update_body_animation(input)


## Agacharse: mantener Ctrl. Encoge la cápsula y baja los ojos; no se puede
## levantar si hay algo encima.
func _update_crouch(playing: bool, delta: float) -> void:
	var want := playing and Input.is_action_pressed("agacharse")
	if want and not is_crouching:
		is_crouching = true
		_set_capsule(CROUCH_HEIGHT)
	elif not want and is_crouching and not _ceiling_above():
		is_crouching = false
		_set_capsule(STAND_HEIGHT)
	var eye := EYE_CROUCH if is_crouching else EYE_STAND
	head.position.y = move_toward(head.position.y, eye - _land_dip, delta * 4.0)
	_land_dip = move_toward(_land_dip, 0.0, delta * 1.2)


func _set_capsule(height: float) -> void:
	var cap := collider.shape as CapsuleShape3D
	cap.height = height
	collider.position.y = height * 0.5


func _ceiling_above() -> bool:
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.0,
		global_position + Vector3.UP * (STAND_HEIGHT + 0.05))
	query.exclude = [get_rid()]
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## Al tocar el suelo: la cámara se hunde según la velocidad de caída;
## desde muy alto, se pierde vida.
func _check_landing() -> void:
	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor:
		var impact := -_fall_speed
		_land_dip = clampf(impact * 0.025, 0.04, 0.35)
		if impact > 13.0:
			stats.take_damage((impact - 13.0) * 6.0)
			shake(0.1)
			GameManager.screen_flash.emit(Color(0.6, 0.0, 0.0, 0.35))
		combat.on_landed(impact)
	if on_floor:
		_fall_speed = 0.0
	_was_on_floor = on_floor


func _update_camera(delta: float, hspeed: float) -> void:
	head.rotation.x = _pitch
	var moving := hspeed > 0.3 and is_on_floor()
	if balanceo_al_andar and moving:
		_bob_t += delta * hspeed * 2.4
	# Balanceo: más amplio corriendo, casi nada agachado.
	var amp := 0.4 if is_crouching else (1.4 if is_running else 1.0)
	var bob := Vector3(sin(_bob_t * 0.5) * 0.025, absf(sin(_bob_t * 0.5)) * 0.04, 0.0) * amp if moving else Vector3.ZERO
	camera.position = camera.position.lerp(bob, minf(delta * 12.0, 1.0))
	camera.h_offset = randf_range(-1.0, 1.0) * _shake
	camera.v_offset = randf_range(-1.0, 1.0) * _shake
	_shake = move_toward(_shake, 0.0, delta * 0.5)
	weapon.bob_amount = clampf(hspeed / velocidad_correr, 0.0, 1.0)
	weapon.visible = camera.current


## El cuerpo solo se ve desde la cámara del diorama (intro, menú).
func _update_body_animation(input: Vector2) -> void:
	if not is_on_floor():
		model.play("idle")
	elif input.length() < 0.1:
		model.play("idle")
	else:
		model.play("run" if is_running else "walk")


## Lo que hay justo delante de los ojos (2,6 m) y se puede usar.
func _update_interaction() -> void:
	var from := camera.global_position
	var to := from - camera.global_transform.basis.z * 2.6
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var target: Node = null
	if hit and hit.collider.has_method("interact"):
		target = hit.collider
	if target != GameManager.interactable:
		if target:
			GameManager.set_interactable(target)
		else:
			GameManager.clear_interactable(GameManager.interactable)


## Gira la vista hacia la cara del aldeano y empieza el diálogo
## (con objetos, como las vetas de mineral, solo interactúa).
func _talk_to(villager: Node3D) -> void:
	if not villager is Villager:
		villager.interact(self)
		return
	var face := villager.global_position + Vector3(0, 1.6, 0)
	var d := face - camera.global_position
	var target_yaw := atan2(-d.x, -d.z)
	var target_pitch := atan2(d.y, Vector2(d.x, d.z).length())
	var start_yaw := rotation.y
	var start_pitch := _pitch
	var tween := create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_method(func(t: float) -> void:
		rotation.y = lerp_angle(start_yaw, target_yaw, t)
		_pitch = lerpf(start_pitch, target_pitch, t), 0.0, 1.0, 0.3)
	villager.interact(self)


# --- API para el combate y la escena ---------------------------------------------

func receive_hit(hit: Dictionary) -> void:
	if invulnerable > 0.0:
		GameManager.show_message("¡ESQUIVADO!", Color(0.7, 0.9, 1.0), 0.6)
		return
	combat.receive_hit(hit)


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


## Impulso hacia delante (ataque a la carrera).
func lunge(speed: float) -> void:
	_move_vel = -transform.basis.z * speed


func push(impulse: Vector3) -> void:
	_push += Vector3(impulse.x, 0.0, impulse.z)


## Giro completo (Torbellino).
func spin(duration: float) -> void:
	_spin_left = duration
	_spin_speed = TAU / duration


func is_alive() -> bool:
	return not stats.dead


func eye_transform() -> Transform3D:
	return camera.global_transform


func _on_died() -> void:
	# Caída de la cámara al suelo, a saltos.
	var tween := create_tween()
	tween.tween_property(head, "position:y", 0.35, 0.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(head, "rotation:z", 1.2, 0.6)
	weapon.hide()


func _report() -> void:
	var stats_now := Vector2(stats.health, stats.stamina)
	if stats_now.is_equal_approx(_last_reported):
		return
	_last_reported = stats_now
	GameManager.report_player_stats(stats.health / stats.max_health * 100.0,
		stats.stamina / stats.max_stamina * 100.0)
