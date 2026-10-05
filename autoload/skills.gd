extends Node
## Autoload "Skills": experiencia, niveles y árbol de habilidades de Henry.
## Sobrevive a "reintentar" tras morir (el progreso no se pierde).
##
## Pasivas: mejoran estadísticas. Activas: se lanzan con 1, 2 y 3, gastan
## aguante y tienen tiempo de recarga.

signal changed
signal leveled_up(level: int)

const DEFS := {
	"fuerza": {
		"name": "Fuerza", "kind": "pasiva", "max": 3,
		"desc": "+15% de daño con la espada por rango.",
	},
	"vitalidad": {
		"name": "Vitalidad", "kind": "pasiva", "max": 3,
		"desc": "+25 de vida máxima por rango.",
	},
	"aguante": {
		"name": "Aguante", "kind": "pasiva", "max": 3,
		"desc": "+20 de aguante máximo y un 25% más de recuperación por rango.",
	},
	"defensa": {
		"name": "Defensa", "kind": "pasiva", "max": 3,
		"desc": "El bloqueo absorbe más daño y gasta menos aguante. Paradas más fáciles.",
	},
	"golpe_poderoso": {
		"name": "Golpe Poderoso", "kind": "activa", "slot": 1, "short": "GP", "max": 1,
		"cooldown": 5.0, "stamina": 25.0,
		"desc": "Tajo vertical a dos manos: daño x2,5 y derriba al enemigo.",
	},
	"torbellino": {
		"name": "Torbellino", "kind": "activa", "slot": 2, "short": "TB", "max": 1,
		"cooldown": 9.0, "stamina": 35.0, "requires": {"fuerza": 1},
		"desc": "Giras sobre ti mismo golpeando a todos los enemigos cercanos.",
	},
	"oracion": {
		"name": "Oración", "kind": "activa", "slot": 3, "short": "OR", "max": 1,
		"cooldown": 30.0, "stamina": 10.0, "requires": {"vitalidad": 1},
		"desc": "Un padrenuestro rápido: recuperas 40 de vida.",
	},
}
const ORDER := ["fuerza", "vitalidad", "aguante", "defensa", "golpe_poderoso", "torbellino", "oracion"]

var level := 1
var xp := 0
var points := 1
var ranks := {}
var _cooldowns := {}


func _process(delta: float) -> void:
	for id: String in _cooldowns:
		_cooldowns[id] = maxf(_cooldowns[id] - delta, 0.0)


func reset() -> void:
	level = 1
	xp = 0
	points = 1
	ranks = {}
	_cooldowns = {}
	changed.emit()


func rank(id: String) -> int:
	return ranks.get(id, 0)


func xp_to_next() -> int:
	return 30 + level * 30


func add_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		points += 1
		leveled_up.emit(level)
	changed.emit()


## "" si se puede aprender; si no, el motivo.
func learn_block_reason(id: String) -> String:
	var def: Dictionary = DEFS[id]
	if rank(id) >= def.max:
		return "Rango máximo"
	var reqs: Dictionary = def.get("requires", {})
	for req: String in reqs:
		if rank(req) < reqs[req]:
			return "Requiere %s %d" % [DEFS[req].name, reqs[req]]
	if points <= 0:
		return "Sin puntos de habilidad"
	return ""


func learn(id: String) -> bool:
	if learn_block_reason(id) != "":
		return false
	ranks[id] = rank(id) + 1
	points -= 1
	changed.emit()
	return true


func skill_for_slot(slot: int) -> String:
	for id: String in DEFS:
		if DEFS[id].get("slot", 0) == slot:
			return id
	return ""


func is_ready(id: String) -> bool:
	return rank(id) > 0 and _cooldowns.get(id, 0.0) <= 0.0


func trigger_cooldown(id: String) -> void:
	_cooldowns[id] = DEFS[id].get("cooldown", 0.0)


## 1 = recién usada, 0 = lista.
func cooldown_fraction(id: String) -> float:
	var cd: float = DEFS[id].get("cooldown", 0.0)
	return _cooldowns.get(id, 0.0) / cd if cd > 0.0 else 0.0


# --- Modificadores que lee el combate ---------------------------------------

func damage_multiplier() -> float:
	return 1.0 + 0.15 * rank("fuerza")


func bonus_health() -> float:
	return 25.0 * rank("vitalidad")


func bonus_stamina() -> float:
	return 20.0 * rank("aguante")


func stamina_regen_multiplier() -> float:
	return 1.0 + 0.25 * rank("aguante")


## Fracción del daño que absorbe el bloqueo.
func block_absorb() -> float:
	return 0.7 + 0.08 * rank("defensa")


## Aguante gastado por punto de daño bloqueado.
func block_stamina_factor() -> float:
	return 0.8 - 0.15 * rank("defensa")


## Segundos tras levantar la guardia en los que un bloqueo es una parada.
func parry_window() -> float:
	return 0.2 + 0.05 * rank("defensa")
