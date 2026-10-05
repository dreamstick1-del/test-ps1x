extends Control
## Menú principal estilo PS1 dibujado sobre el diorama girando.
## "Juego Nuevo" emite new_game_requested; la escena principal lanza la intro.

signal new_game_requested

var _main_box: VBoxContainer
var _options_box: VBoxContainer
var _press_start: Label
var _option_buttons := {}
var _started := false

const OPTION_LABELS := {
	"nitido": "Imagen nítida (480p)",
	"crt": "Filtro CRT",
	"dither": "Dithering 15 bits",
	"vertex_jitter": "Temblor de vértices",
	"affine": "Texturas afines",
}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var title := Label.new()
	title.text = "SKALITZ"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", PS1Theme.ACCENT)
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 26)
	title.size = Vector2(320, 40)
	add_child(title)

	var subtitle := Label.new()
	subtitle.text = "ANNO DOMINI 1403"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.position = Vector2(0, 64)
	subtitle.size = Vector2(320, 14)
	add_child(subtitle)

	_press_start = Label.new()
	_press_start.text = "PULSA START"
	_press_start.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_press_start.position = Vector2(0, 160)
	_press_start.size = Vector2(320, 14)
	add_child(_press_start)

	var footer := Label.new()
	footer.text = "© 1999 DIORAMA SOFT"
	footer.add_theme_font_size_override("font_size", 8)
	footer.add_theme_color_override("font_color", PS1Theme.TEXT_DIM)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.position = Vector2(0, 222)
	footer.size = Vector2(320, 12)
	add_child(footer)

	_main_box = _make_panel(Vector2(110, 140), Vector2(100, 0))
	var new_game := PS1Theme.menu_button(_main_box, "Juego Nuevo")
	new_game.pressed.connect(_on_new_game)
	PS1Theme.menu_button(_main_box, "Opciones").pressed.connect(_show_options)
	PS1Theme.menu_button(_main_box, "Salir").pressed.connect(func() -> void: get_tree().quit())

	_options_box = _make_panel(Vector2(70, 100), Vector2(180, 0))
	for key: String in OPTION_LABELS:
		var b := PS1Theme.menu_button(_options_box, "")
		_option_buttons[key] = b
		b.pressed.connect(_toggle_option.bind(key))
	PS1Theme.menu_button(_options_box, "Volver").pressed.connect(_show_main)
	_refresh_options()

	_main_box.get_parent().visible = false
	_options_box.get_parent().visible = false


func _process(_delta: float) -> void:
	if _started or GameManager.current_state != GameManager.GameState.MENU:
		return
	if not _press_start.visible:
		return
	_press_start.modulate.a = 1.0 if int(Time.get_ticks_msec() / 500) % 2 == 0 else 0.0
	if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("interactuar") \
			or Input.is_action_just_pressed("pausa"):
		_press_start.visible = false
		# Espera un frame para que la misma pulsación no active "Juego Nuevo".
		await get_tree().process_frame
		_show_main()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and _press_start.visible:
		_press_start.visible = false
		_show_main.call_deferred()


func _make_panel(pos: Vector2, min_size: Vector2) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.position = pos
	panel.custom_minimum_size = min_size
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)
	return box


func _show_main() -> void:
	_options_box.get_parent().visible = false
	_main_box.get_parent().visible = true
	(_main_box.get_child(0) as Button).grab_focus()


func _show_options() -> void:
	_main_box.get_parent().visible = false
	_options_box.get_parent().visible = true
	(_options_box.get_child(0) as Button).grab_focus()


func _toggle_option(key: String) -> void:
	GameManager.set_setting(key, not GameManager.settings[key])
	_refresh_options()


func _refresh_options() -> void:
	for key: String in _option_buttons:
		var on: bool = GameManager.settings[key]
		PS1Theme.set_button_text(_option_buttons[key], "%s: %s" % [OPTION_LABELS[key], "SI" if on else "NO"])


func _on_new_game() -> void:
	if _started:
		return
	_started = true
	_main_box.get_parent().visible = false
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.6)
	tween.tween_callback(hide)
	new_game_requested.emit()
