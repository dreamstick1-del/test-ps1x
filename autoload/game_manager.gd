extends Node
## Autoload "GameManager".
## Controla el estado global del juego (MENU, PLAYING, DIALOG, CUTSCENE, PAUSED),
## registra el mapa de controles y hace de "bus" de señales entre el mundo 3D
## del diorama y la interfaz 2D, que viven en SubViewports distintos.

enum GameState { MENU, PLAYING, DIALOG, CUTSCENE, PAUSED }

signal state_changed(new_state: GameState, old_state: GameState)
signal dialog_started(speaker: String, lines: PackedStringArray)
signal dialog_finished
signal subtitle_requested(text: String, duration: float)
signal interactable_changed(interactable: Node)
signal location_changed(location_name: String)
signal player_stats_changed(health: float, stamina: float)
signal settings_changed

## Teclas y botones de mando por acción. Se registran en tiempo de ejecución
## para que el proyecto funcione sin tocar el Input Map del editor.
const KEY_BINDINGS := {
	"adelante": [KEY_W, KEY_UP],
	"atras": [KEY_S, KEY_DOWN],
	"giro_izquierda": [KEY_A, KEY_LEFT],
	"giro_derecha": [KEY_D, KEY_RIGHT],
	"sprint": [KEY_SHIFT],
	"interactuar": [KEY_E, KEY_SPACE],
	"pausa": [KEY_ESCAPE, KEY_P],
}
const JOY_BINDINGS := {
	"adelante": JOY_BUTTON_DPAD_UP,
	"atras": JOY_BUTTON_DPAD_DOWN,
	"giro_izquierda": JOY_BUTTON_DPAD_LEFT,
	"giro_derecha": JOY_BUTTON_DPAD_RIGHT,
	"sprint": JOY_BUTTON_B,
	"interactuar": JOY_BUTTON_A,
	"pausa": JOY_BUTTON_START,
}
## Stick izquierdo: [eje, dirección].
const JOY_AXES := {
	"adelante": [JOY_AXIS_LEFT_Y, -1.0],
	"atras": [JOY_AXIS_LEFT_Y, 1.0],
	"giro_izquierda": [JOY_AXIS_LEFT_X, -1.0],
	"giro_derecha": [JOY_AXIS_LEFT_X, 1.0],
}

var current_state: GameState = GameState.MENU
var interactable: Node = null

var settings := {
	"crt": true,
	"dither": true,
	"vertex_jitter": true,
	"affine": true,
}

var _state_before_pause: GameState = GameState.PLAYING
var _interact_blocked_until_ms := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_input()
	_apply_render_settings()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("pausa"):
		if current_state == GameState.PLAYING:
			pause_game()
		elif current_state == GameState.PAUSED:
			resume_game()


# --- Estados -----------------------------------------------------------------

func change_state(new_state: GameState) -> void:
	if new_state == current_state:
		return
	var old_state := current_state
	current_state = new_state
	get_tree().paused = new_state == GameState.PAUSED
	state_changed.emit(new_state, old_state)


func is_playing() -> bool:
	return current_state == GameState.PLAYING


func pause_game() -> void:
	_state_before_pause = current_state
	change_state(GameState.PAUSED)


func resume_game() -> void:
	change_state(_state_before_pause)


## Vuelve al estado inicial (se usa al recargar la escena desde la pausa).
func reset() -> void:
	interactable = null
	get_tree().paused = false
	current_state = GameState.MENU


# --- Diálogos e interacción --------------------------------------------------

func start_dialog(speaker: String, lines: PackedStringArray) -> void:
	if current_state != GameState.PLAYING or lines.is_empty():
		return
	change_state(GameState.DIALOG)
	dialog_started.emit(speaker, lines)


func end_dialog() -> void:
	# Evita que la misma pulsación que cierra el diálogo lo vuelva a abrir.
	_interact_blocked_until_ms = Time.get_ticks_msec() + 300
	change_state(GameState.PLAYING)
	dialog_finished.emit()


func can_interact() -> bool:
	return is_playing() and interactable != null \
		and Time.get_ticks_msec() >= _interact_blocked_until_ms


func set_interactable(node: Node) -> void:
	interactable = node
	interactable_changed.emit(node)


func clear_interactable(node: Node) -> void:
	if interactable == node:
		interactable = null
		interactable_changed.emit(null)


func show_subtitle(text: String, duration: float = 3.0) -> void:
	subtitle_requested.emit(text, duration)


func report_player_stats(health: float, stamina: float) -> void:
	player_stats_changed.emit(health, stamina)


# --- Opciones gráficas -------------------------------------------------------

func set_setting(key: String, value: bool) -> void:
	settings[key] = value
	_apply_render_settings()
	settings_changed.emit()


func _apply_render_settings() -> void:
	# Uniformes globales declarados en project.godot -> [shader_globals].
	RenderingServer.global_shader_parameter_set("ps1_vertex_snap", 1.0 if settings.vertex_jitter else 0.0)
	RenderingServer.global_shader_parameter_set("ps1_affine", 1.0 if settings.affine else 0.0)


# --- Input -------------------------------------------------------------------

func _register_input() -> void:
	for action: String in KEY_BINDINGS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, 0.4)
		for key: Key in KEY_BINDINGS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
		if JOY_BINDINGS.has(action):
			var jb := InputEventJoypadButton.new()
			jb.button_index = JOY_BINDINGS[action]
			InputMap.action_add_event(action, jb)
		if JOY_AXES.has(action):
			var jm := InputEventJoypadMotion.new()
			jm.axis = JOY_AXES[action][0]
			jm.axis_value = JOY_AXES[action][1]
			InputMap.action_add_event(action, jm)
