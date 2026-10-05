class_name CombatStats
extends Node
## Vida y aguante de cualquier combatiente (Henry, bandidos, muñeco).

signal health_changed(health: float, max_health: float)
signal stamina_changed(stamina: float, max_stamina: float)
signal died

@export var max_health := 100.0
@export var max_stamina := 100.0
@export var stamina_regen := 24.0 ## Por segundo.
@export var regen_delay := 0.7 ## Espera tras gastar aguante.

var health: float
var stamina: float
var dead := false
var regen_multiplier := 1.0
## Mientras sea true (corriendo, bloqueando) no se recupera aguante.
var regen_blocked := false

var _regen_wait := 0.0


func _ready() -> void:
	health = max_health
	stamina = max_stamina


func _process(delta: float) -> void:
	if _regen_wait > 0.0:
		_regen_wait -= delta
		return
	if regen_blocked or dead or stamina >= max_stamina:
		return
	stamina = minf(stamina + stamina_regen * regen_multiplier * delta, max_stamina)
	stamina_changed.emit(stamina, max_stamina)


## Gasta aguante para una acción. Falla si no queda nada (se permite quedarse
## a cero con la última acción: así nunca se "pierde" un golpe por 1 punto).
func spend_stamina(amount: float) -> bool:
	if stamina <= 0.0:
		return false
	drain_stamina(amount)
	return true


func drain_stamina(amount: float) -> void:
	stamina = maxf(stamina - amount, 0.0)
	_regen_wait = regen_delay
	stamina_changed.emit(stamina, max_stamina)


func take_damage(amount: float) -> void:
	if dead:
		return
	health = maxf(health - amount, 0.0)
	health_changed.emit(health, max_health)
	if health <= 0.0:
		dead = true
		died.emit()


func heal(amount: float) -> void:
	if dead:
		return
	health = minf(health + amount, max_health)
	health_changed.emit(health, max_health)


## Cambia los máximos conservando lo ganado (usado al subir habilidades).
func set_maximums(new_health: float, new_stamina: float) -> void:
	health += maxf(new_health - max_health, 0.0)
	stamina += maxf(new_stamina - max_stamina, 0.0)
	max_health = new_health
	max_stamina = new_stamina
	health = minf(health, max_health)
	stamina = minf(stamina, max_stamina)
	health_changed.emit(health, max_health)
	stamina_changed.emit(stamina, max_stamina)
