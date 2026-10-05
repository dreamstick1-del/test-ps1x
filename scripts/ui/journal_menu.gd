extends Control
## Diario de Henry (I): cuatro páginas, ←/→ para cambiar.
##   INVENTARIO  · objetos (Enter usa comida/bebida), equipo y dinero.
##   SKALITZ     · sociedad: población por clase, riqueza, satisfacción,
##                 prosperidad, seguridad, arcas del señor y de la iglesia.
##   MERCADO     · precios, tendencia y existencias de cada bien.
##   CRÓNICA     · últimos sucesos del pueblo.

const PAGES := ["INVENTARIO", "SKALITZ", "MERCADO", "CRÓNICA"]

var _page := 0
var _tabs: Label
var _body: VBoxContainer
var _player: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.position = Vector2(20, 10)
	panel.custom_minimum_size = Vector2(280, 220)
	add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	_tabs = Label.new()
	_tabs.add_theme_color_override("font_color", PS1Theme.ACCENT)
	_tabs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_tabs)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 0)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_body)
	var hint := Label.new()
	hint.text = "←/→: página  ·  Enter: usar  ·  I/Esc: cerrar"
	hint.add_theme_font_size_override("font_size", 8)
	hint.add_theme_color_override("font_color", PS1Theme.TEXT_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)

	GameManager.state_changed.connect(func(s: GameManager.GameState, _o: GameManager.GameState) -> void:
		visible = s == GameManager.GameState.JOURNAL
		if visible:
			_build())


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_left"):
		_page = (_page + PAGES.size() - 1) % PAGES.size()
		_build()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		_page = (_page + 1) % PAGES.size()
		_build()
		get_viewport().set_input_as_handled()


func _build() -> void:
	var tabs := []
	for i in PAGES.size():
		tabs.append("[%s]" % PAGES[i] if i == _page else PAGES[i].to_lower())
	_tabs.text = "  ".join(tabs)
	for child in _body.get_children():
		child.queue_free()
	match _page:
		0: _inventory_page()
		1: _society_page()
		2: _market_page()
		3: _chronicle_page()


func _inventory_page() -> void:
	_line("%s   ·   Bolsa: %d groschen   ·   Reputación: %+d" % [Economy.clock_text(), Economy.money, roundi(Economy.reputation)], PS1Theme.TEXT)
	var weapon: String = Weapons.get_def(Economy.equipped.weapon).name
	if Economy.has_shield():
		weapon += " + escudo"
	var armor: String = Economy.EQUIPMENT[Economy.equipped.armor].name if Economy.equipped.armor != "" else "Ropa de lino"
	_line("Arma: %s   ·   Armadura: %s" % [weapon, armor], Color(0.85, 0.9, 1.0))
	_line("— Objetos —", PS1Theme.TEXT_DIM)
	if Economy.inventory.is_empty():
		_line("(nada)", PS1Theme.TEXT_DIM)
	var first: Button = null
	for good: String in Economy.inventory:
		var def: Dictionary = Economy.GOODS[good]
		var effect := ""
		if def.has("use"):
			var parts := []
			for k: String in def.use:
				parts.append("+%d %s" % [def.use[k], "vida" if k == "heal" else "aguante"])
			effect = "  (usar: %s)" % ", ".join(parts)
		var b := PS1Theme.menu_button(_body, "%s x%d%s" % [def.name, Economy.inventory[good], effect])
		b.pressed.connect(_use.bind(good))
		if first == null:
			first = b
	if first:
		first.grab_focus.call_deferred()


func _use(good: String) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
	var used := Economy.use_item(good, _player)
	if used != "":
		GameManager.show_message("%s: ñam" % used if Economy.GOODS[good].use.has("heal") else "%s: ¡glu glu!" % used,
			Color(0.7, 1.0, 0.6), 1.0)
	_build()


func _society_page() -> void:
	_line("%s   ·   %d habitantes en %d hogares" % [Economy.clock_text(), Economy.population_total(), Economy.households.size()], PS1Theme.TEXT)
	_bar_line("Prosperidad", Economy.prosperity() / 100.0, Color(0.4, 0.8, 0.4))
	_bar_line("Satisfacción", Economy.satisfaction_avg(), Color(0.9, 0.75, 0.3))
	_bar_line("Seguridad", Economy.safety, Color(0.5, 0.6, 0.95))
	_line("— Clases —          hogares  personas  riqueza  ánimo", PS1Theme.TEXT_DIM)
	for c: Dictionary in Economy.class_summary():
		_line("%-14s %5d %8d %8d gr %5d%%" % [c["class"], c.households, c.people, roundi(c.avg_wealth),
			roundi(c.satisfaction * 100.0)], PS1Theme.TEXT)
	_line("Arcas de Sir Radzig: %d gr   ·   Iglesia: %d gr" % [roundi(Economy.lord_treasury), roundi(Economy.church_coffers)], Color(0.85, 0.9, 1.0))
	_line("Cosecha x%.1f   ·   Mina x%.1f   ·   Impuestos cada 7 días" % [Economy.harvest, Economy.mine_yield], PS1Theme.TEXT_DIM)


func _market_page() -> void:
	_line("Bien                 precio  tend.  existencias", PS1Theme.TEXT_DIM)
	for good: String in Economy.GOODS:
		var arrow: String = ["▼ baja", "  =", "▲ sube"][Economy.trend(good) + 1]
		var ratio: float = Economy.price(good) / Economy.GOODS[good].base
		var color := Color(1.0, 0.55, 0.45) if ratio > 1.4 else (Color(0.6, 1.0, 0.6) if ratio < 0.75 else PS1Theme.TEXT)
		_line("%-18s %5.1f gr  %-6s  %5d" % [Economy.GOODS[good].name, Economy.price(good), arrow,
			int(Economy.stock[good])], color)


func _chronicle_page() -> void:
	for entry: String in Economy.event_log:
		var l := _line(entry, PS1Theme.TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(268, 0)


func _line(text: String, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_color", color)
	_body.add_child(l)
	return l


func _bar_line(label: String, value: float, color: Color) -> void:
	var filled := roundi(clampf(value, 0.0, 1.0) * 20.0)
	_line("%-13s %s %d%%" % [label, "█".repeat(filled) + "░".repeat(20 - filled), roundi(value * 100.0)], color)
