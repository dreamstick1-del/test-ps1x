extends Control
## HUD a 320x240: barras de vida/estamina, minimapa, subtítulos, aviso de
## interacción y nombre de la zona al cambiar de plano de cámara.

const Minimap := preload("res://scripts/ui/minimap.gd")

var _health := 100.0
var _stamina := 100.0

var _gameplay_root: Control
var _minimap: Control
var _subtitle_panel: PanelContainer
var _subtitle_label: Label
var _prompt_label: Label
var _location_label: Label
var _subtitle_time_left := 0.0
var _location_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_gameplay_root = Control.new()
	_gameplay_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gameplay_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_gameplay_root.draw.connect(_draw_bars)
	add_child(_gameplay_root)

	_minimap = Minimap.new()
	_minimap.name = "MinimapUI"
	_minimap.position = Vector2(320 - 64 - 8, 8)
	_gameplay_root.add_child(_minimap)

	_prompt_label = Label.new()
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.position = Vector2(0, 150)
	_prompt_label.size = Vector2(320, 14)
	_prompt_label.add_theme_color_override("font_color", PS1Theme.ACCENT)
	_gameplay_root.add_child(_prompt_label)

	_location_label = Label.new()
	_location_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_location_label.position = Vector2(0, 34)
	_location_label.size = Vector2(320, 14)
	_location_label.add_theme_font_size_override("font_size", 12)
	_location_label.modulate.a = 0.0
	_gameplay_root.add_child(_location_label)

	_subtitle_panel = PanelContainer.new()
	_subtitle_panel.name = "SubtitleText"
	_subtitle_panel.position = Vector2(20, 196)
	_subtitle_panel.size = Vector2(280, 0)
	_subtitle_panel.custom_minimum_size = Vector2(280, 0)
	_subtitle_panel.visible = false
	_subtitle_label = Label.new()
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_panel.add_child(_subtitle_label)
	add_child(_subtitle_panel)

	GameManager.state_changed.connect(_on_state_changed)
	GameManager.player_stats_changed.connect(_on_stats)
	GameManager.subtitle_requested.connect(_on_subtitle)
	GameManager.interactable_changed.connect(_on_interactable)
	GameManager.location_changed.connect(_on_location)
	GameManager.dialog_started.connect(func(_s: String, _l: PackedStringArray) -> void:
		_subtitle_panel.visible = false)
	_on_state_changed(GameManager.current_state, GameManager.current_state)


func _process(delta: float) -> void:
	if _subtitle_time_left > 0.0:
		_subtitle_time_left -= delta
		if _subtitle_time_left <= 0.0:
			_subtitle_panel.visible = false
	# El aviso parpadea como un "PRESS START".
	_prompt_label.visible = GameManager.can_interact() and int(Time.get_ticks_msec() / 400) % 3 != 0


func _draw_bars() -> void:
	var font := ThemeDB.fallback_font
	_bar(Vector2(8, 10), "VIDA", _health, Color(0.75, 0.12, 0.1), font)
	_bar(Vector2(8, 22), "AGUANTE", _stamina, Color(0.75, 0.68, 0.18), font)


func _bar(pos: Vector2, label: String, value: float, color: Color, font: Font) -> void:
	var width := 60.0
	draw_string_shadowed(font, pos + Vector2(0, 7), label)
	var bar_pos := pos + Vector2(42, 1)
	_gameplay_root.draw_rect(Rect2(bar_pos - Vector2.ONE, Vector2(width + 2, 7)), Color.BLACK)
	_gameplay_root.draw_rect(Rect2(bar_pos, Vector2(width, 5)), color.darkened(0.7))
	var fill := floorf(width * clampf(value / 100.0, 0.0, 1.0))
	_gameplay_root.draw_rect(Rect2(bar_pos, Vector2(fill, 5)), color)
	_gameplay_root.draw_rect(Rect2(bar_pos, Vector2(fill, 1)), color.lightened(0.35))


func draw_string_shadowed(font: Font, pos: Vector2, text: String) -> void:
	_gameplay_root.draw_string(font, pos + Vector2.ONE, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.BLACK)
	_gameplay_root.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, PS1Theme.TEXT)


func _on_state_changed(new_state: GameManager.GameState, _old: GameManager.GameState) -> void:
	_gameplay_root.visible = new_state in [GameManager.GameState.PLAYING, GameManager.GameState.DIALOG,
		GameManager.GameState.PAUSED]
	if new_state == GameManager.GameState.MENU:
		_subtitle_panel.visible = false


func _on_stats(health: float, stamina: float) -> void:
	_health = health
	_stamina = stamina
	_gameplay_root.queue_redraw()


func _on_subtitle(text: String, duration: float) -> void:
	_subtitle_label.text = text
	_subtitle_panel.visible = text != ""
	_subtitle_panel.reset_size()
	_subtitle_panel.position.y = 228 - _subtitle_panel.size.y
	_subtitle_time_left = duration


func _on_interactable(node: Node) -> void:
	if node and node.has_method("get_prompt"):
		_prompt_label.text = "[E] " + node.get_prompt()


func _on_location(location_name: String) -> void:
	_location_label.text = "- %s -" % location_name
	if _location_tween and _location_tween.is_valid():
		_location_tween.kill()
	_location_label.modulate.a = 1.0
	_location_tween = create_tween()
	_location_tween.tween_interval(1.8)
	_location_tween.tween_property(_location_label, "modulate:a", 0.0, 0.6)
