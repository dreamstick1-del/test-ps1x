extends PanelContainer
## Caja de diálogo con efecto máquina de escribir. "Interactuar" completa la
## línea o pasa a la siguiente; al acabar devuelve el control al jugador.

@export var chars_per_second := 45.0

var _lines: PackedStringArray = []
var _index := 0
var _visible_chars := 0.0
var _opened_at_ms := 0

var _speaker: Label
var _text: Label
var _arrow: Label


func _ready() -> void:
	visible = false
	position = Vector2(8, 170)
	custom_minimum_size = Vector2(304, 62)
	size = custom_minimum_size

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 1)
	add_child(vbox)
	_speaker = Label.new()
	_speaker.add_theme_color_override("font_color", PS1Theme.ACCENT)
	vbox.add_child(_speaker)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(294, 30)
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_text)
	_arrow = Label.new()
	_arrow.text = "▼"
	_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vbox.add_child(_arrow)

	GameManager.dialog_started.connect(_on_dialog_started)


func _on_dialog_started(speaker: String, lines: PackedStringArray) -> void:
	_speaker.text = speaker
	_lines = lines
	_index = 0
	_opened_at_ms = Time.get_ticks_msec()
	_show_line()
	visible = true


func _show_line() -> void:
	_text.text = _lines[_index]
	_visible_chars = 0.0
	_text.visible_characters = 0


func _process(delta: float) -> void:
	if not visible:
		return
	var total := _text.get_total_character_count()
	if _text.visible_characters < total:
		_visible_chars += chars_per_second * delta
		_text.visible_characters = mini(int(_visible_chars), total)
	_arrow.visible = _text.visible_characters >= total and int(Time.get_ticks_msec() / 300) % 2 == 0

	# Ignora la misma pulsación que abrió el diálogo.
	if Time.get_ticks_msec() - _opened_at_ms < 150:
		return
	if Input.is_action_just_pressed("interactuar") or Input.is_action_just_pressed("ui_accept"):
		if _text.visible_characters < total:
			_text.visible_characters = total
			_visible_chars = total
		elif _index + 1 < _lines.size():
			_index += 1
			_show_line()
		else:
			visible = false
			GameManager.end_dialog()
