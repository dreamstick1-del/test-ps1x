extends Control
## HUD a 320x240 para la primera persona:
##  - Vida, aguante, experiencia y nivel (arriba a la izquierda) + objetivo.
##  - Minimapa (arriba a la derecha) y punto de mira.
##  - Barra del enemigo al que golpeas (arriba, centrada).
##  - Habilidades activas 1-2-3 con su recarga (abajo a la izquierda).
##  - Subtítulos, avisos grandes ("¡PARADA!"), destellos de daño y pantalla de muerte.

const Minimap := preload("res://scripts/ui/minimap.gd")

var _health := 100.0
var _stamina := 100.0

var _gameplay_root: Control
var _minimap: Control
var _subtitle_panel: PanelContainer
var _subtitle_label: Label
var _prompt_label: Label
var _location_label: Label
var _objective_label: Label
var _message_label: Label
var _flash: ColorRect
var _death_root: Control
var _subtitle_time_left := 0.0
var _location_tween: Tween
var _message_tween: Tween
var _flash_tween: Tween

var _focused_enemy: Node
var _focus_time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(0, 0, 0, 0)
	add_child(_flash)

	_gameplay_root = Control.new()
	_gameplay_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gameplay_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_gameplay_root.draw.connect(_draw_gameplay)
	add_child(_gameplay_root)

	_minimap = Minimap.new()
	_minimap.name = "MinimapUI"
	_minimap.position = Vector2(320 - 56 - 6, 6)
	_minimap.custom_minimum_size = Vector2(56, 56)
	_gameplay_root.add_child(_minimap)

	_objective_label = _label(_gameplay_root, Vector2(6, 46), Vector2(190, 30), 8)
	_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective_label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))

	_prompt_label = _label(_gameplay_root, Vector2(0, 132), Vector2(320, 14), 10)
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.add_theme_color_override("font_color", PS1Theme.ACCENT)

	_location_label = _label(_gameplay_root, Vector2(0, 74), Vector2(320, 14), 12)
	_location_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_location_label.modulate.a = 0.0

	_message_label = _label(self, Vector2(0, 92), Vector2(320, 20), 16)
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.add_theme_constant_override("shadow_offset_x", 2)
	_message_label.add_theme_constant_override("shadow_offset_y", 2)
	_message_label.modulate.a = 0.0

	_subtitle_panel = PanelContainer.new()
	_subtitle_panel.name = "SubtitleText"
	_subtitle_panel.position = Vector2(20, 160)
	_subtitle_panel.custom_minimum_size = Vector2(280, 0)
	_subtitle_panel.visible = false
	_subtitle_label = Label.new()
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_panel.add_child(_subtitle_label)
	add_child(_subtitle_panel)

	_death_root = Control.new()
	_death_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_death_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_death_root.visible = false
	add_child(_death_root)
	var dim := ColorRect.new()
	dim.color = Color(0.25, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_death_root.add_child(dim)
	var dead_label := _label(_death_root, Vector2(0, 90), Vector2(320, 30), 24)
	dead_label.text = "HAS MUERTO"
	dead_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dead_label.add_theme_color_override("font_color", Color(0.9, 0.12, 0.08))
	var retry := _label(_death_root, Vector2(0, 128), Vector2(320, 14), 10)
	retry.text = "Pulsa E para volver a intentarlo"
	retry.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	GameManager.state_changed.connect(_on_state_changed)
	GameManager.player_stats_changed.connect(_on_stats)
	GameManager.subtitle_requested.connect(_on_subtitle)
	GameManager.interactable_changed.connect(_on_interactable)
	GameManager.location_changed.connect(_on_location)
	GameManager.message_requested.connect(_on_message)
	GameManager.objective_changed.connect(func(text: String) -> void: _objective_label.text = "▶ " + text)
	GameManager.enemy_focused.connect(func(enemy: Node) -> void:
		_focused_enemy = enemy
		_focus_time = 3.0)
	GameManager.screen_flash.connect(_on_flash)
	GameManager.dialog_started.connect(func(_s: String, _l: PackedStringArray) -> void:
		_subtitle_panel.visible = false)
	Skills.leveled_up.connect(func(level: int) -> void:
		_on_message("¡NIVEL %d!  +1 PUNTO (Tab)" % level, Color(0.6, 0.9, 1.0), 2.2))
	_on_state_changed(GameManager.current_state, GameManager.current_state)


func _process(delta: float) -> void:
	if _subtitle_time_left > 0.0:
		_subtitle_time_left -= delta
		if _subtitle_time_left <= 0.0:
			_subtitle_panel.visible = false
	_focus_time -= delta
	_prompt_label.visible = GameManager.can_interact() and int(Time.get_ticks_msec() / 400) % 3 != 0
	if _gameplay_root.visible:
		_gameplay_root.queue_redraw()


# --- Dibujo ------------------------------------------------------------------

func _draw_gameplay() -> void:
	var font := ThemeDB.fallback_font
	var ci := _gameplay_root
	_bar(Vector2(6, 6), "VIDA", _health / 100.0, Color(0.75, 0.12, 0.1), font)
	_bar(Vector2(6, 17), "AGUANTE", _stamina / 100.0, Color(0.75, 0.68, 0.18), font)
	_bar(Vector2(6, 28), "NV %d" % Skills.level, float(Skills.xp) / Skills.xp_to_next(),
		Color(0.35, 0.6, 0.95), font)
	if Skills.points > 0:
		_text(Vector2(112, 35), "+%d" % Skills.points, PS1Theme.ACCENT, font)

	if GameManager.is_playing():
		# Punto de mira: dorado si hay algo con lo que interactuar.
		var c := PS1Theme.ACCENT if GameManager.interactable else Color(1, 1, 1, 0.75)
		ci.draw_rect(Rect2(159, 116, 2, 3), c)
		ci.draw_rect(Rect2(159, 121, 2, 3), c)
		ci.draw_rect(Rect2(155, 119, 3, 2), c)
		ci.draw_rect(Rect2(162, 119, 3, 2), c)
		_draw_skill_slots(font)

	if _focus_time > 0.0 and is_instance_valid(_focused_enemy) and "stats" in _focused_enemy:
		var stats: CombatStats = _focused_enemy.stats
		var ratio := stats.health / stats.max_health if not stats.dead else 0.0
		var x := 126.0
		_text(Vector2(x, 12), _focused_enemy.display_name, Color(1.0, 0.75, 0.65), font)
		ci.draw_rect(Rect2(x - 1, 15, 102, 6), Color.BLACK)
		ci.draw_rect(Rect2(x, 16, 100, 4), Color(0.3, 0.05, 0.05))
		ci.draw_rect(Rect2(x, 16, floorf(100 * ratio), 4), Color(0.85, 0.15, 0.1))


func _draw_skill_slots(font: Font) -> void:
	var ci := _gameplay_root
	for slot in [1, 2, 3]:
		var id := Skills.skill_for_slot(slot)
		var def: Dictionary = Skills.DEFS[id]
		var pos := Vector2(6 + (slot - 1) * 26, 208)
		var learned := Skills.rank(id) > 0
		ci.draw_rect(Rect2(pos - Vector2.ONE, Vector2(24, 24)), PS1Theme.BORDER if learned else Color(0.3, 0.3, 0.3))
		ci.draw_rect(Rect2(pos, Vector2(22, 22)), Color(0.08, 0.08, 0.16, 0.9))
		if learned:
			_text(pos + Vector2(4, 15), def.short, PS1Theme.TEXT, font)
			var cd := Skills.cooldown_fraction(id)
			if cd > 0.0:
				ci.draw_rect(Rect2(pos, Vector2(22, ceilf(22 * cd))), Color(0, 0, 0, 0.7))
		else:
			_text(pos + Vector2(8, 15), "-", Color(0.4, 0.4, 0.4), font)
		_text(pos + Vector2(1, 7), str(slot), PS1Theme.ACCENT, font)


func _bar(pos: Vector2, label: String, value: float, color: Color, font: Font) -> void:
	var width := 60.0
	_text(pos + Vector2(0, 7), label, PS1Theme.TEXT, font)
	var bar_pos := pos + Vector2(46, 1)
	var ci := _gameplay_root
	ci.draw_rect(Rect2(bar_pos - Vector2.ONE, Vector2(width + 2, 7)), Color.BLACK)
	ci.draw_rect(Rect2(bar_pos, Vector2(width, 5)), color.darkened(0.7))
	var fill := floorf(width * clampf(value, 0.0, 1.0))
	ci.draw_rect(Rect2(bar_pos, Vector2(fill, 5)), color)
	ci.draw_rect(Rect2(bar_pos, Vector2(fill, 1)), color.lightened(0.35))


func _text(pos: Vector2, text: String, color: Color, font: Font) -> void:
	_gameplay_root.draw_string(font, pos + Vector2.ONE, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.BLACK)
	_gameplay_root.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, color)


func _label(parent: Control, pos: Vector2, size_px: Vector2, font_size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = size_px
	l.add_theme_font_size_override("font_size", font_size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


# --- Señales ---------------------------------------------------------------

func _on_state_changed(new_state: GameManager.GameState, _old: GameManager.GameState) -> void:
	_gameplay_root.visible = new_state in [GameManager.GameState.PLAYING, GameManager.GameState.DIALOG,
		GameManager.GameState.PAUSED, GameManager.GameState.SKILLS, GameManager.GameState.DEAD]
	_death_root.visible = new_state == GameManager.GameState.DEAD
	if new_state == GameManager.GameState.MENU:
		_subtitle_panel.visible = false


func _on_stats(health: float, stamina: float) -> void:
	_health = health
	_stamina = stamina


func _on_subtitle(text: String, duration: float) -> void:
	_subtitle_label.text = text
	_subtitle_panel.visible = text != ""
	_subtitle_panel.reset_size()
	_subtitle_panel.position.y = 202 - _subtitle_panel.size.y
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


func _on_message(text: String, color: Color, duration: float) -> void:
	_message_label.text = text
	_message_label.add_theme_color_override("font_color", color)
	if _message_tween and _message_tween.is_valid():
		_message_tween.kill()
	_message_label.modulate.a = 1.0
	_message_tween = create_tween()
	_message_tween.tween_interval(duration)
	_message_tween.tween_property(_message_label, "modulate:a", 0.0, 0.4)


func _on_flash(color: Color) -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash.color = color
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash, "color:a", 0.0, 0.35)
