extends Control
## Escena principal: contiene el diorama 3D (SubViewport 320x240), la interfaz
## (otro SubViewport 320x240 transparente) y el marco CRT a resolución nativa.
## Orquesta el flujo MENU -> CUTSCENE (intro) -> PLAYING.

@onready var game_view: SubViewportContainer = $GameView
@onready var camera: DioramaCamera = $GameView/SubViewport/DioramaWorld/Camera3D
@onready var player: CharacterBody3D = $GameView/SubViewport/DioramaWorld/Player_Henry
@onready var ui_root: Control = $UIView/SubViewport/UIRoot
@onready var main_menu: Control = $UIView/SubViewport/UIRoot/MainMenu
@onready var fade: ColorRect = $UIView/SubViewport/UIRoot/Fade
@onready var crt_overlay: ColorRect = $CRTOverlay

var _skip_cutscene := false
var _cutscene_started_ms := 0


func _ready() -> void:
	GameManager.reset()
	ui_root.theme = PS1Theme.build()
	main_menu.new_game_requested.connect(_on_new_game)
	GameManager.settings_changed.connect(_apply_settings)
	_apply_settings()
	camera.start_orbit()

	fade.color.a = 1.0
	create_tween().tween_property(fade, "color:a", 0.0, 1.2)


func _process(_delta: float) -> void:
	if GameManager.current_state == GameManager.GameState.CUTSCENE \
			and Time.get_ticks_msec() - _cutscene_started_ms > 600:
		if Input.is_action_just_pressed("interactuar") or Input.is_action_just_pressed("ui_accept") \
				or Input.is_action_just_pressed("pausa"):
			_skip_cutscene = true


func _apply_settings() -> void:
	crt_overlay.visible = GameManager.settings.crt
	var post := game_view.material as ShaderMaterial
	post.set_shader_parameter("dither_enabled", GameManager.settings.dither)


func _on_new_game() -> void:
	GameManager.change_state(GameManager.GameState.CUTSCENE)
	_skip_cutscene = false
	_cutscene_started_ms = Time.get_ticks_msec()
	await _play_intro()

	if _skip_cutscene:
		# Corte a negro rápido para que el salto no sea brusco.
		fade.color.a = 1.0
		create_tween().tween_property(fade, "color:a", 0.0, 0.5)
	GameManager.show_subtitle("", 0.0)
	camera.enter_gameplay(player)
	GameManager.change_state(GameManager.GameState.PLAYING)
	GameManager.show_subtitle("Flechas/WASD: andar y girar · Shift: correr · E: hablar · Esc: pausa", 6.0)


## Cutscene de introducción: la cámara pasa de la vista de maqueta a Henry.
func _play_intro() -> void:
	var henry := player.global_position
	var henry_fwd := -player.global_transform.basis.z
	var shots := [
		[Vector3(-24, 18, 26), Vector3(0, 0, 0), 4.5, "Bohemia, año del Señor de 1403."],
		[Vector3(0, 9, 4), Vector3(0, 5, -15), 4.5, "Skalitz. Un pequeño pueblo minero de plata."],
		[Vector3(3, 6, 12), Vector3(11, 1, 1), 4.5, "Allí vivía Henry, el hijo de Martin el herrero."],
		[henry + henry_fwd * 3.0 + Vector3(-1.2, 1.6, 0), henry + Vector3(0, 1.3, 0), 3.5,
			"Para él, aquel iba a ser un día cualquiera..."],
	]
	for shot: Array in shots:
		if _skip_cutscene or not is_inside_tree():
			return
		camera.fly_to(shot[0], shot[1], shot[2])
		GameManager.show_subtitle(shot[3], shot[2] + 0.3)
		await _wait_or_skip(shot[2] + 0.5)


func _wait_or_skip(seconds: float) -> void:
	var end_ms := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end_ms and not _skip_cutscene and is_inside_tree():
		await get_tree().process_frame
