extends Control
## Escena principal: contiene el diorama 3D (SubViewport 320x240), la interfaz
## (otro SubViewport 320x240 transparente) y el marco CRT a resolución nativa.
## Orquesta el flujo:
##   MENU (cámara orbitando la maqueta) -> CUTSCENE (intro que acaba metiéndose
##   en los ojos de Henry) -> PLAYING en primera persona.
## Al morir (DEAD) se recarga la escena y se vuelve directamente al juego.

@onready var game_view: SubViewportContainer = $GameView
@onready var world: DioramaWorld = $GameView/SubViewport/DioramaWorld
@onready var camera: DioramaCamera = $GameView/SubViewport/DioramaWorld/Camera3D
@onready var player: CharacterBody3D = $GameView/SubViewport/DioramaWorld/Player_Henry
@onready var ui_root: Control = $UIView/SubViewport/UIRoot
@onready var main_menu: Control = $UIView/SubViewport/UIRoot/MainMenu
@onready var fade: ColorRect = $UIView/SubViewport/UIRoot/Fade
@onready var crt_overlay: ColorRect = $CRTOverlay

var _skip_cutscene := false
var _cutscene_started_ms := 0
var _died_ms := 0


func _ready() -> void:
	var retrying := GameManager.retrying
	GameManager.retrying = false
	GameManager.reset()
	ui_root.theme = PS1Theme.build()
	main_menu.new_game_requested.connect(_on_new_game)
	GameManager.settings_changed.connect(_apply_settings)
	GameManager.player_died.connect(func() -> void: _died_ms = Time.get_ticks_msec())
	_apply_settings()

	fade.color.a = 1.0
	create_tween().tween_property(fade, "color:a", 0.0, 1.2)
	if retrying:
		main_menu.hide()
		_enter_gameplay()
	else:
		camera.start_orbit()


## El ratón se mueve en el viewport raíz; se lo pasamos a Henry.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		player.add_look(event.relative)
	elif event is InputEventMouseButton and event.pressed and GameManager.is_playing() \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(_delta: float) -> void:
	var interact := Input.is_action_just_pressed("interactuar") or Input.is_action_just_pressed("ui_accept")
	match GameManager.current_state:
		GameManager.GameState.CUTSCENE:
			if Time.get_ticks_msec() - _cutscene_started_ms > 600 and \
					(interact or Input.is_action_just_pressed("pausa")):
				_skip_cutscene = true
		GameManager.GameState.DEAD:
			if interact and Time.get_ticks_msec() - _died_ms > 1500:
				GameManager.retrying = true
				get_tree().reload_current_scene()


func _apply_settings() -> void:
	crt_overlay.visible = GameManager.settings.crt
	var post := game_view.material as ShaderMaterial
	post.set_shader_parameter("dither_enabled", GameManager.settings.dither)


func _on_new_game() -> void:
	Skills.reset()
	GameManager.quest_stage = 0
	GameManager.change_state(GameManager.GameState.CUTSCENE)
	_skip_cutscene = false
	_cutscene_started_ms = Time.get_ticks_msec()
	await _play_intro()
	if _skip_cutscene:
		fade.color.a = 1.0
		create_tween().tween_property(fade, "color:a", 0.0, 0.5)
	GameManager.show_subtitle("", 0.0)
	_enter_gameplay()
	GameManager.show_subtitle("Ratón: mirar · WASD: moverse · Shift: correr · Clic izq.: atacar · Clic der.: bloquear · 1-2-3: habilidades · Tab: menú de habilidades · E: hablar", 8.0)


func _enter_gameplay() -> void:
	player.camera.current = true
	world.set_first_person(true)
	var quest := QuestDirector.new()
	quest.name = "QuestDirector"
	world.add_child(quest)
	quest.start(world)
	GameManager.change_state(GameManager.GameState.PLAYING)
	GameManager.location_changed.emit("SKALITZ")


## Cutscene de introducción: de la vista de maqueta a los ojos de Henry.
func _play_intro() -> void:
	var henry := player.global_position
	var shots := [
		[Vector3(-24, 18, 26), Vector3(0, 0, 0), 4.5, "Bohemia, año del Señor de 1403."],
		[Vector3(0, 9, 4), Vector3(0, 5, -15), 4.5, "Skalitz. Un pequeño pueblo minero de plata."],
		[Vector3(3, 6, 12), Vector3(11, 1, 1), 4.5, "Allí vivía Henry, el hijo de Martin el herrero."],
		[henry + Vector3(-2.5, 2.2, 2.5), henry + Vector3(0, 1.3, 0), 3.0,
			"Para él, aquel iba a ser un día cualquiera..."],
	]
	for shot: Array in shots:
		if _skip_cutscene or not is_inside_tree():
			return
		camera.fly_to(shot[0], shot[1], shot[2])
		GameManager.show_subtitle(shot[3], shot[2] + 0.3)
		await _wait_or_skip(shot[2] + 0.5)
	if _skip_cutscene or not is_inside_tree():
		return
	# Y nos metemos dentro de su cabeza.
	camera.fly_to_transform(player.eye_transform(), 1.2)
	await _wait_or_skip(1.25)


func _wait_or_skip(seconds: float) -> void:
	var end_ms := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end_ms and not _skip_cutscene and is_inside_tree():
		await get_tree().process_frame
