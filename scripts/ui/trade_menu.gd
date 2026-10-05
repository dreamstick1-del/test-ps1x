extends Control
## Ventana de comercio. ←/→ cambia entre COMPRAR y VENDER, Enter compra o
## vende una unidad. Los precios salen de Economy (oferta/demanda + reputación).

var _shop := ""
var _mode := "comprar"
var _title: Label
var _info: Label
var _greeting: Label
var _list: VBoxContainer
var _status: Label
var _rows: Array = [] ## [{button, kind, id}]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var panel := PanelContainer.new()
	panel.position = Vector2(24, 12)
	panel.custom_minimum_size = Vector2(272, 216)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	panel.add_child(box)
	_title = _label(box, 10, PS1Theme.ACCENT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_greeting = _label(box, 8, Color(0.85, 0.9, 1.0))
	_greeting.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_greeting.custom_minimum_size = Vector2(260, 0)
	_info = _label(box, 8, PS1Theme.TEXT)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 0)
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_list)
	_status = _label(box, 8, Color(1.0, 0.7, 0.5))
	var hint := _label(box, 8, PS1Theme.TEXT_DIM)
	hint.text = "←/→: comprar/vender  ·  Enter: 1 unidad  ·  Esc: salir"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	GameManager.trade_opened.connect(_open)
	GameManager.state_changed.connect(func(s: GameManager.GameState, _o: GameManager.GameState) -> void:
		visible = s == GameManager.GameState.TRADE)
	Economy.player_changed.connect(_refresh_keep_focus)


func _open(shop: String, merchant: String) -> void:
	_shop = shop
	_mode = "comprar"
	_title.text = "%s  ·  %s" % [Economy.SHOPS[shop].name.to_upper(), merchant]
	_greeting.text = "«%s»" % Economy.gossip()
	_status.text = ""
	_rebuild()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		_mode = "vender" if _mode == "comprar" else "comprar"
		_rebuild()
		get_viewport().set_input_as_handled()


func _rebuild() -> void:
	for child in _list.get_children():
		child.queue_free()
	_rows.clear()
	var def: Dictionary = Economy.SHOPS[_shop]
	var header := _label(_list, 8, PS1Theme.TEXT_DIM)
	header.text = ("[COMPRAR]   vender" if _mode == "comprar" else "comprar   [VENDER]") + \
		"            precio    tienes"
	for good: String in def.goods:
		if _mode == "vender" and Economy.inventory.get(good, 0) <= 0:
			continue
		_add_row("good", good)
	if _mode == "comprar":
		for id: String in def.get("equipment", []):
			_add_row("equipment", id)
	if _mode == "vender":
		for good: String in Economy.inventory:
			if good not in def.goods and Economy.inventory[good] > 0:
				_add_row("good", good) # También compran otras cosas, pero las anotan aparte.
	_refresh()
	if not _rows.is_empty():
		(_rows[0].button as Button).grab_focus.call_deferred()


func _add_row(kind: String, id: String) -> void:
	var b := PS1Theme.menu_button(_list, "")
	b.pressed.connect(_act.bind(kind, id))
	_rows.append({"button": b, "kind": kind, "id": id})


func _refresh() -> void:
	_info.text = "Tu bolsa: %d groschen   ·   Caja de la tienda: %d" % [Economy.money, Economy.shop_funds(_shop)]
	for row: Dictionary in _rows:
		var text := ""
		if row.kind == "equipment":
			var eq: Dictionary = Economy.EQUIPMENT[row.id]
			var owned: bool = row.id in Economy.owned_equipment
			text = "%-18s %4s gr   %s" % [eq.name, Economy.equipment_price(row.id), "TUYO" if owned else eq.desc.substr(0, 14)]
		else:
			var g: Dictionary = Economy.GOODS[row.id]
			var p := Economy.buy_price(row.id) if _mode == "comprar" else Economy.sell_price(row.id)
			var arrow: String = ["▼", " ", "▲"][Economy.trend(row.id) + 1]
			var extra := " (%d en el pueblo)" % int(Economy.stock.get(row.id, 0.0)) if _mode == "comprar" else ""
			text = "%-16s %3d gr %s  x%d%s" % [g.name, p, arrow, Economy.inventory.get(row.id, 0), extra]
		PS1Theme.set_button_text(row.button, text)


func _refresh_keep_focus() -> void:
	if visible:
		_refresh()


func _act(kind: String, id: String) -> void:
	var err := ""
	if kind == "equipment":
		err = Economy.buy_equipment(_shop, id)
		if err == "":
			GameManager.show_message("%s equipado" % Economy.EQUIPMENT[id].name, Color(0.7, 1.0, 0.6), 1.5)
	elif _mode == "comprar":
		err = Economy.buy(_shop, id)
	else:
		err = Economy.sell(_shop, id)
		if err == "" and Economy.inventory.get(id, 0) <= 0:
			_rebuild()
	_status.text = err


func _label(parent: Control, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l
