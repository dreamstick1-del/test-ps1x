extends Control
## Menú de pausa. Funciona con el árbol pausado (process_mode ALWAYS).

var _continue: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var panel := PanelContainer.new()
	panel.position = Vector2(105, 80)
	panel.custom_minimum_size = Vector2(110, 0)
	add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	var title := Label.new()
	title.text = "PAUSA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", PS1Theme.ACCENT)
	box.add_child(title)
	_continue = PS1Theme.menu_button(box, "Continuar")
	_continue.pressed.connect(GameManager.resume_game)
	PS1Theme.menu_button(box, "Menú principal").pressed.connect(_back_to_menu)

	GameManager.state_changed.connect(_on_state_changed)


func _on_state_changed(new_state: GameManager.GameState, _old: GameManager.GameState) -> void:
	visible = new_state == GameManager.GameState.PAUSED
	if visible:
		_continue.grab_focus()


func _back_to_menu() -> void:
	GameManager.reset()
	get_tree().reload_current_scene()
