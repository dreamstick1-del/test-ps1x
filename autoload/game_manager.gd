extends Node
## Autoload "GameManager".
## Controla el estado global del juego (MENU, PLAYING, DIALOG, CUTSCENE, PAUSED,
## SKILLS, DEAD, TRADE, JOURNAL),
## registra el mapa de controles y hace de "bus" de señales entre el mundo 3D
## del diorama y la interfaz 2D, que viven en SubViewports distintos.

enum GameState { MENU, PLAYING, DIALOG, CUTSCENE, PAUSED, SKILLS, DEAD, TRADE, JOURNAL }

signal state_changed(new_state: GameState, old_state: GameState)
signal dialog_started(speaker: String, lines: PackedStringArray)
signal dialog_finished
signal subtitle_requested(text: String, duration: float)
signal interactable_changed(interactable: Node)
signal location_changed(location_name: String)
signal player_stats_changed(health: float, stamina: float)
signal settings_changed
signal message_requested(text: String, color: Color, duration: float)
signal objective_changed(text: String)
signal enemy_focused(enemy: Node)
signal screen_flash(color: Color)
signal player_died
signal trade_opened(shop: String, merchant: String)

## Teclas, ratón y mando por acción. Se registran en tiempo de ejecución
## para que el proyecto funcione sin tocar el Input Map del editor.
const KEY_BINDINGS := {
	"adelante": [KEY_W, KEY_UP],
	"atras": [KEY_S, KEY_DOWN],
	"izquierda": [KEY_A],
	"derecha": [KEY_D],
	"girar_izquierda": [KEY_LEFT],
	"girar_derecha": [KEY_RIGHT],
	"mirar_arriba": [KEY_PAGEUP],
	"mirar_abajo": [KEY_PAGEDOWN],
	"sprint": [KEY_SHIFT],
	"saltar": [KEY_SPACE],
	"agacharse": [KEY_CTRL, KEY_C],
	"esquivar": [KEY_ALT, KEY_V],
	"interactuar": [KEY_E, KEY_F],
	"atacar": [KEY_J],
	"bloquear": [KEY_K],
	"arma_siguiente": [KEY_Q],
	"arma_anterior": [KEY_Z],
	"skill_1": [KEY_1],
	"skill_2": [KEY_2],
	"skill_3": [KEY_3],
	"habilidades": [KEY_TAB],
	"diario": [KEY_I, KEY_L],
	"pausa": [KEY_ESCAPE, KEY_P],
}
const MOUSE_BINDINGS := {
	"atacar": MOUSE_BUTTON_LEFT,
	"bloquear": MOUSE_BUTTON_RIGHT,
	"arma_siguiente": MOUSE_BUTTON_WHEEL_DOWN,
	"arma_anterior": MOUSE_BUTTON_WHEEL_UP,
}
const JOY_BINDINGS := {
	"sprint": JOY_BUTTON_LEFT_STICK,
	"saltar": JOY_BUTTON_A,
	"agacharse": JOY_BUTTON_B,
	"esquivar": JOY_BUTTON_RIGHT_STICK,
	"interactuar": JOY_BUTTON_X,
	"atacar": JOY_BUTTON_RIGHT_SHOULDER,
	"bloquear": JOY_BUTTON_LEFT_SHOULDER,
	"arma_siguiente": JOY_BUTTON_DPAD_DOWN,
	"skill_1": JOY_BUTTON_DPAD_LEFT,
	"skill_2": JOY_BUTTON_DPAD_UP,
	"skill_3": JOY_BUTTON_DPAD_RIGHT,
	"habilidades": JOY_BUTTON_BACK,
	"pausa": JOY_BUTTON_START,
}
## Estados con menú abierto: pausan el mundo y sueltan el ratón.
const MENU_STATES := [GameState.PAUSED, GameState.SKILLS, GameState.TRADE, GameState.JOURNAL]

## Sticks: [eje, dirección]. Izquierdo = moverse, derecho = mirar.
const JOY_AXES := {
	"adelante": [JOY_AXIS_LEFT_Y, -1.0],
	"atras": [JOY_AXIS_LEFT_Y, 1.0],
	"izquierda": [JOY_AXIS_LEFT_X, -1.0],
	"derecha": [JOY_AXIS_LEFT_X, 1.0],
	"girar_izquierda": [JOY_AXIS_RIGHT_X, -1.0],
	"girar_derecha": [JOY_AXIS_RIGHT_X, 1.0],
	"mirar_arriba": [JOY_AXIS_RIGHT_Y, -1.0],
	"mirar_abajo": [JOY_AXIS_RIGHT_Y, 1.0],
}

var current_state: GameState = GameState.MENU
var interactable: Node = null
## Progreso de la misión (lo usa QuestDirector; sobrevive a "reintentar").
var quest_stage := 0
## true al recargar la escena tras morir: se salta menú e intro.
var retrying := false
var objective := ""
var last_speaker := ""

var settings := {
	## Imagen nítida: 480x360 en vez de 320x240 y temblor de vértices más fino.
	"nitido": true,
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
		elif current_state in [GameState.SKILLS, GameState.TRADE, GameState.JOURNAL]:
			change_state(GameState.PLAYING)
	elif Input.is_action_just_pressed("habilidades"):
		_toggle_menu(GameState.SKILLS)
	elif Input.is_action_just_pressed("diario"):
		_toggle_menu(GameState.JOURNAL)


func _toggle_menu(menu: GameState) -> void:
	if current_state == GameState.PLAYING:
		change_state(menu)
	elif current_state == menu:
		change_state(GameState.PLAYING)


# --- Estados -----------------------------------------------------------------

func change_state(new_state: GameState) -> void:
	if new_state == current_state:
		return
	var old_state := current_state
	current_state = new_state
	get_tree().paused = new_state in MENU_STATES
	# En primera persona el ratón se captura solo mientras se juega.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if new_state == GameState.PLAYING \
		else Input.MOUSE_MODE_VISIBLE
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
	Engine.time_scale = 1.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	current_state = GameState.MENU


# --- Diálogos e interacción --------------------------------------------------

func start_dialog(speaker: String, lines: PackedStringArray) -> void:
	if current_state != GameState.PLAYING or lines.is_empty():
		return
	last_speaker = speaker
	change_state(GameState.DIALOG)
	dialog_started.emit(speaker, lines)


func end_dialog() -> void:
	# Evita que la misma pulsación que cierra el diálogo lo vuelva a abrir.
	_interact_blocked_until_ms = Time.get_ticks_msec() + 300
	change_state(GameState.PLAYING)
	dialog_finished.emit()


func open_trade(shop: String, merchant: String) -> void:
	if current_state != GameState.PLAYING:
		return
	change_state(GameState.TRADE)
	trade_opened.emit(shop, merchant)


func close_trade() -> void:
	_interact_blocked_until_ms = Time.get_ticks_msec() + 300
	change_state(GameState.PLAYING)


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


## Texto grande en el centro de la pantalla ("¡PARADA!", "NIVEL 2"...).
func show_message(text: String, color := Color(1.0, 0.82, 0.35), duration := 1.4) -> void:
	message_requested.emit(text, color, duration)


func set_objective(text: String) -> void:
	objective = text
	objective_changed.emit(text)


# --- Opciones gráficas -------------------------------------------------------

func set_setting(key: String, value: bool) -> void:
	settings[key] = value
	_apply_render_settings()
	settings_changed.emit()


func _apply_render_settings() -> void:
	# Uniformes globales declarados en project.godot -> [shader_globals].
	# 0 = sin temblor; 1 = rejilla clásica de 160x120; 2 = la mitad de temblor.
	var snap := 0.0
	if settings.vertex_jitter:
		snap = 2.0 if settings.nitido else 1.0
	RenderingServer.global_shader_parameter_set("ps1_vertex_snap", snap)
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
		if MOUSE_BINDINGS.has(action):
			var mb := InputEventMouseButton.new()
			mb.button_index = MOUSE_BINDINGS[action]
			InputMap.action_add_event(action, mb)
		if JOY_BINDINGS.has(action):
			var jb := InputEventJoypadButton.new()
			jb.button_index = JOY_BINDINGS[action]
			InputMap.action_add_event(action, jb)
		if JOY_AXES.has(action):
			var jm := InputEventJoypadMotion.new()
			jm.axis = JOY_AXES[action][0]
			jm.axis_value = JOY_AXES[action][1]
			InputMap.action_add_event(action, jm)
