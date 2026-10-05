extends CharacterBody3D
## Henry: control tipo "tanque" (giro + avance/retroceso) característico de los
## juegos de PS1 con cámaras fijas (Resident Evil, Silent Hill...).

@export_group("Movimiento")
@export var velocidad_caminar: float = 2.5
@export var velocidad_correr: float = 4.5
@export var velocidad_retroceso: float = 1.6
@export var velocidad_rotacion: float = 160.0 ## Grados por segundo.
@export var gravedad: float = 20.0

@export_group("Estamina")
@export var estamina_max: float = 100.0
@export var consumo_estamina: float = 22.0 ## Por segundo corriendo.
@export var recuperacion_estamina: float = 14.0 ## Por segundo sin correr.
@export var umbral_recuperacion: float = 30.0 ## Si se agota, no se puede volver a correr hasta aquí.

var health: float = 100.0
var stamina: float = 100.0
var is_running: bool = false

var _exhausted: bool = false
var _last_reported := Vector2(-1, -1)

## PS1RiggedCharacter (modelo FBX) o PS1Character (cajas): ambos exponen play().
@onready var model = $Model


func _physics_process(delta: float) -> void:
	var input_movimiento := 0.0
	var input_rotacion := 0.0

	if GameManager.is_playing():
		input_movimiento = Input.get_axis("atras", "adelante")
		input_rotacion = Input.get_axis("giro_derecha", "giro_izquierda")
		if Input.is_action_just_pressed("interactuar") and GameManager.can_interact():
			GameManager.interactable.interact(self)
			input_movimiento = 0.0
			input_rotacion = 0.0

	procesar_movimiento(delta, input_movimiento, input_rotacion)
	actualizar_estamina(delta)
	actualizar_animacion(input_movimiento, input_rotacion)


func procesar_movimiento(delta: float, input_movimiento: float, input_rotacion: float) -> void:
	# Correr solo hacia delante y si queda estamina.
	is_running = input_movimiento > 0.0 and Input.is_action_pressed("sprint") \
		and not _exhausted and GameManager.is_playing()

	var current_speed := velocidad_caminar
	if is_running:
		current_speed = velocidad_correr
	elif input_movimiento < 0.0:
		current_speed = velocidad_retroceso

	rotate_y(deg_to_rad(velocidad_rotacion) * input_rotacion * delta)

	# Dirección según la rotación actual del personaje (-Z es "adelante").
	var direccion := -global_transform.basis.z * input_movimiento
	velocity.x = direccion.x * current_speed
	velocity.z = direccion.z * current_speed
	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= gravedad * delta

	move_and_slide()


func actualizar_estamina(delta: float) -> void:
	if is_running:
		stamina = maxf(stamina - consumo_estamina * delta, 0.0)
		if stamina <= 0.0:
			_exhausted = true
	else:
		stamina = minf(stamina + recuperacion_estamina * delta, estamina_max)
		if _exhausted and stamina >= umbral_recuperacion:
			_exhausted = false

	var stats := Vector2(health, stamina)
	if not stats.is_equal_approx(_last_reported):
		_last_reported = stats
		GameManager.report_player_stats(health, stamina / estamina_max * 100.0)


func actualizar_animacion(input_movimiento: float, input_rotacion: float) -> void:
	if GameManager.current_state == GameManager.GameState.DIALOG:
		model.play("idle")
	elif input_movimiento > 0.0 and is_running:
		model.play("run")
	elif input_movimiento != 0.0:
		model.play("walk", 0.7 if input_movimiento < 0.0 else 1.0)
	elif input_rotacion != 0.0:
		model.play("walk", 0.6) # Pasitos al girar sobre sí mismo.
	else:
		model.play("idle")
