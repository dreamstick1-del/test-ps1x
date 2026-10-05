extends Control
## Menú de habilidades (Tab). Pausa el juego mientras está abierto.
## Enter/clic sobre una habilidad la aprende si hay puntos y se cumplen
## los requisitos.

var _header: Label
var _info: Label
var _desc: Label
var _list: VBoxContainer
var _buttons := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var panel := PanelContainer.new()
	panel.position = Vector2(30, 14)
	panel.custom_minimum_size = Vector2(260, 212)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	panel.add_child(box)

	_header = Label.new()
	_header.add_theme_color_override("font_color", PS1Theme.ACCENT)
	_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_header)
	_info = Label.new()
	_info.add_theme_font_size_override("font_size", 8)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_info)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 0)
	box.add_child(_list)
	var last_kind := ""
	for id: String in Skills.ORDER:
		var def: Dictionary = Skills.DEFS[id]
		if def.kind != last_kind:
			last_kind = def.kind
			var section := Label.new()
			section.text = "— PASIVAS —" if def.kind == "pasiva" else "— ACTIVAS (teclas 1, 2, 3) —"
			section.add_theme_font_size_override("font_size", 8)
			section.add_theme_color_override("font_color", PS1Theme.TEXT_DIM)
			_list.add_child(section)
		var b := PS1Theme.menu_button(_list, "")
		b.pressed.connect(_learn.bind(id))
		b.focus_entered.connect(_describe.bind(id))
		_buttons[id] = b

	_desc = Label.new()
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size = Vector2(248, 34)
	_desc.add_theme_font_size_override("font_size", 8)
	box.add_child(_desc)
	var hint := Label.new()
	hint.text = "Enter: aprender  ·  Tab/Esc: cerrar"
	hint.add_theme_font_size_override("font_size", 8)
	hint.add_theme_color_override("font_color", PS1Theme.TEXT_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)

	GameManager.state_changed.connect(_on_state_changed)
	Skills.changed.connect(_refresh)


func _on_state_changed(new_state: GameManager.GameState, _old: GameManager.GameState) -> void:
	visible = new_state == GameManager.GameState.SKILLS
	if visible:
		_refresh()
		(_buttons[Skills.ORDER[0]] as Button).grab_focus()


func _refresh() -> void:
	_header.text = "HABILIDADES  ·  NIVEL %d" % Skills.level
	_info.text = "XP %d/%d   ·   Puntos disponibles: %d" % [Skills.xp, Skills.xp_to_next(), Skills.points]
	for id: String in _buttons:
		var def: Dictionary = Skills.DEFS[id]
		var r := Skills.rank(id)
		var pips := "■".repeat(r) + "□".repeat(def.max - r)
		var key := "[%d] " % def.slot if def.has("slot") else ""
		PS1Theme.set_button_text(_buttons[id], "%s%s  %s" % [key, def.name, pips])
		var available: bool = Skills.learn_block_reason(id) == ""
		(_buttons[id] as Button).modulate = Color.WHITE if available or r > 0 else Color(0.6, 0.6, 0.6)
	for id: String in _buttons:
		if (_buttons[id] as Button).has_focus():
			_describe(id)


func _describe(id: String) -> void:
	var def: Dictionary = Skills.DEFS[id]
	var text: String = def.desc
	if def.kind == "activa":
		text += "  (Aguante %d · Recarga %ds)" % [def.stamina, def.cooldown]
	var reason := Skills.learn_block_reason(id)
	if reason != "":
		text += "\n" + reason
	_desc.text = text


func _learn(id: String) -> void:
	if Skills.learn(id):
		GameManager.show_message("%s aprendida" % Skills.DEFS[id].name, Color(0.7, 1.0, 0.6), 1.2)
	_describe(id)
