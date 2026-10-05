class_name PS1Theme
extends RefCounted
## Tema de interfaz estilo menú de PS1: paneles azul oscuro con borde dorado,
## texto sin antialiasing y botones con cursor "▶".

const TEXT := Color(0.93, 0.88, 0.74)
const TEXT_DIM := Color(0.62, 0.58, 0.50)
const ACCENT := Color(1.0, 0.82, 0.35)
const PANEL_BG := Color(0.04, 0.05, 0.13, 0.9)
const BORDER := Color(0.72, 0.60, 0.36)


static func build() -> Theme:
	var t := Theme.new()
	t.default_font_size = 10

	var panel := StyleBoxFlat.new()
	panel.bg_color = PANEL_BG
	panel.border_color = BORDER
	panel.set_border_width_all(1)
	panel.set_content_margin_all(5)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)

	var empty := StyleBoxEmpty.new()
	empty.set_content_margin_all(1)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(0.25, 0.22, 0.45, 0.7)
	focus.set_content_margin_all(1)
	for state in ["normal", "disabled"]:
		t.set_stylebox(state, "Button", empty)
	for state in ["hover", "pressed", "focus"]:
		t.set_stylebox(state, "Button", focus)
	t.set_color("font_color", "Button", TEXT_DIM)
	t.set_color("font_hover_color", "Button", ACCENT)
	t.set_color("font_focus_color", "Button", ACCENT)
	t.set_color("font_pressed_color", "Button", ACCENT)
	t.set_color("font_hover_pressed_color", "Button", ACCENT)

	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.85))
	t.set_constant("shadow_offset_x", "Label", 1)
	t.set_constant("shadow_offset_y", "Label", 1)
	return t


## Añade un botón con cursor "▶" que aparece al tener el foco.
static func menu_button(parent: Control, text: String) -> Button:
	var b := Button.new()
	b.text = "  " + text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_entered.connect(func() -> void: b.text = "▶ " + b.text.substr(2))
	b.focus_exited.connect(func() -> void: b.text = "  " + b.text.substr(2))
	b.mouse_entered.connect(b.grab_focus)
	parent.add_child(b)
	return b


static func set_button_text(b: Button, text: String) -> void:
	b.text = ("▶ " if b.has_focus() else "  ") + text
