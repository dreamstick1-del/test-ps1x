class_name PlayerCombat
extends Node
## Combate de Henry en primera persona:
##  - Combo ligero de 3 golpes (tajo derecha, tajo izquierda, estocada).
##  - Bloqueo con parada: si el golpe llega justo al levantar la guardia,
##    no hay daño y el enemigo queda aturdido.
##  - Habilidades activas (1, 2, 3) del árbol de Skills.
## Todo gasta aguante: sin aguante no se puede atacar ni bloquear.

@export var base_damage := 12.0
@export var reach := 2.2
@export var light_stamina := 10.0

var is_blocking := false

var _player: CharacterBody3D
var _stats: CombatStats
var _weapon: FirstPersonWeapon
var _block_started_ms := 0
var _busy := 0.0
var _stagger := 0.0
var _combo := 0
var _combo_window := 0.0
var _queued := false
var _pending: Array = []

const COMBO := [
	{"seq": [["wind_r", 0.09], ["slash_l", 0.13], ["slash_l", 0.1], ["rest", 0.16]], "hit": 0.15, "mult": 1.0, "cone": 110.0, "reach": 0.0},
	{"seq": [["wind_l", 0.09], ["slash_r", 0.13], ["slash_r", 0.1], ["rest", 0.16]], "hit": 0.15, "mult": 1.0, "cone": 110.0, "reach": 0.0},
	{"seq": [["thrust_back", 0.14], ["thrust_fwd", 0.09], ["thrust_fwd", 0.14], ["rest", 0.2]], "hit": 0.2, "mult": 1.6, "cone": 45.0, "reach": 0.5},
]


func _ready() -> void:
	_player = get_parent()
	_stats = _player.get_node("Stats")
	_weapon = _player.get_node("Head/Camera3D/Weapon")
	_stats.died.connect(_on_died)
	Skills.changed.connect(_apply_skills)
	_apply_skills()


func _apply_skills() -> void:
	_stats.set_maximums(100.0 + Skills.bonus_health(), 100.0 + Skills.bonus_stamina())
	_stats.regen_multiplier = Skills.stamina_regen_multiplier()


func _physics_process(delta: float) -> void:
	_tick_pending(delta)
	_busy -= delta
	_stagger -= delta
	_combo_window -= delta

	if not GameManager.is_playing() or _stats.dead or _stagger > 0.0:
		is_blocking = false
		_weapon.holding_block = false
		return

	var want_block := Input.is_action_pressed("bloquear") and _stats.stamina > 0.0
	if want_block and not is_blocking and _busy <= 0.0:
		is_blocking = true
		_block_started_ms = Time.get_ticks_msec()
	elif not want_block:
		is_blocking = false
	_weapon.holding_block = is_blocking
	if is_blocking:
		return

	if Input.is_action_just_pressed("atacar"):
		if _busy > 0.0:
			_queued = _busy < 0.3 # Encadenar el combo pulsando al final del golpe.
		else:
			_light_attack()
	elif _queued and _busy <= 0.0:
		_queued = false
		_light_attack()

	for slot in [1, 2, 3]:
		if Input.is_action_just_pressed("skill_%d" % slot):
			_use_skill(slot)


# --- Ataques -------------------------------------------------------------------

func _light_attack() -> void:
	if not _stats.spend_stamina(light_stamina):
		GameManager.show_message("Sin aliento", Color(0.9, 0.9, 0.6), 0.8)
		return
	if _combo_window <= 0.0:
		_combo = 0
	var step: Dictionary = COMBO[_combo % COMBO.size()]
	var total := _weapon.play(step.seq)
	_busy = total - 0.06
	_combo_window = total + 0.35
	_combo += 1
	_schedule_hit(step.hit, {
		"damage": base_damage * step.mult, "cone": step.cone, "reach": reach + step.reach,
		"stagger": 0.35, "knockback": 1.5,
	})


func _use_skill(slot: int) -> void:
	var id := Skills.skill_for_slot(slot)
	if Skills.rank(id) == 0:
		GameManager.show_message("Aún no la has aprendido (Tab)", Color(0.8, 0.8, 0.8), 1.0)
		return
	if not Skills.is_ready(id) or _busy > 0.0:
		return
	if not _stats.spend_stamina(Skills.DEFS[id].stamina):
		GameManager.show_message("Sin aliento", Color(0.9, 0.9, 0.6), 0.8)
		return
	Skills.trigger_cooldown(id)
	match id:
		"golpe_poderoso":
			_busy = _weapon.play([["overhead", 0.3], ["overhead_down", 0.1], ["overhead_down", 0.22], ["rest", 0.25]])
			_schedule_hit(0.38, {
				"damage": base_damage * 2.5, "cone": 75.0, "reach": reach + 0.2,
				"stagger": 1.3, "knockback": 5.0, "heavy": true,
			})
		"torbellino":
			_busy = _weapon.play([["wind_r", 0.1], ["slash_l", 0.42], ["rest", 0.22]])
			_player.spin(0.42)
			_schedule_hit(0.3, {
				"damage": base_damage * 1.4, "cone": 360.0, "reach": reach + 0.6,
				"stagger": 0.7, "knockback": 4.0, "heavy": true,
			})
		"oracion":
			_busy = _weapon.play([["pray", 0.35], ["pray", 0.7], ["rest", 0.3]])
			_schedule_call(0.6, func() -> void:
				_stats.heal(40.0)
				GameManager.screen_flash.emit(Color(1.0, 0.95, 0.7, 0.45))
				GameManager.show_message("+40 VIDA", Color(0.7, 1.0, 0.6), 1.0))


func _schedule_hit(delay: float, params: Dictionary) -> void:
	_pending.append({"t": delay, "hit": params})


func _schedule_call(delay: float, callable: Callable) -> void:
	_pending.append({"t": delay, "call": callable})


func _tick_pending(delta: float) -> void:
	for i in range(_pending.size() - 1, -1, -1):
		var p: Dictionary = _pending[i]
		p.t -= delta
		if p.t <= 0.0:
			_pending.remove_at(i)
			if _stats.dead:
				continue
			if p.has("call"):
				(p["call"] as Callable).call()
			else:
				_resolve_hit(p.hit)


## Golpea a todo lo "damageable" dentro del alcance y del cono frontal.
func _resolve_hit(params: Dictionary) -> void:
	var origin := _player.global_position
	var fwd := -_player.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var cos_half := cos(deg_to_rad(params.cone * 0.5))
	var hit_any := false
	for target: Node3D in get_tree().get_nodes_in_group("damageable"):
		if not target.is_alive():
			continue
		var to := target.global_position - origin
		to.y = 0.0
		var dist := to.length()
		if dist > params.reach + 0.35:
			continue
		if params.cone < 360.0 and dist > 0.05 and fwd.dot(to / dist) < cos_half:
			continue
		var dir := to / dist if dist > 0.05 else fwd
		target.receive_hit({
			"damage": params.damage * Skills.damage_multiplier(),
			"stagger": params.stagger,
			"knockback": dir * params.knockback,
			"heavy": params.get("heavy", false),
			"source": _player,
		})
		CombatFX.burst(target.get_parent(), target.global_position + Vector3(0, 1.2, 0), target.hit_color, 12)
		GameManager.enemy_focused.emit(target)
		hit_any = true
	if hit_any:
		CombatFX.hitstop(get_tree(), 0.1 if params.get("heavy", false) else 0.05)
		_player.shake(0.08 if params.get("heavy", false) else 0.04)


# --- Defensa -----------------------------------------------------------------

## Llamado por los enemigos. hit = {damage, knockback, source}
func receive_hit(hit: Dictionary) -> void:
	if _stats.dead:
		return
	var attacker: Node3D = hit.source
	var to_attacker := attacker.global_position - _player.global_position
	to_attacker.y = 0.0
	var fwd := -_player.global_transform.basis.z
	var facing := fwd.dot(to_attacker.normalized()) > 0.25
	var damage: float = hit.damage

	if is_blocking and facing:
		var since := (Time.get_ticks_msec() - _block_started_ms) / 1000.0
		var spark_pos := _player.global_position + fwd * 0.6 + Vector3(0, 1.4, 0)
		if since <= Skills.parry_window():
			GameManager.show_message("¡PARADA!", Color(1.0, 0.85, 0.3), 0.9)
			CombatFX.burst(_player.get_parent(), spark_pos, Color(1.0, 0.9, 0.4), 16, 4.0)
			CombatFX.hitstop(get_tree(), 0.14)
			if attacker.has_method("stagger"):
				attacker.stagger(1.5)
			Skills.add_xp(4)
			return
		var cost := damage * Skills.block_stamina_factor()
		if _stats.stamina >= cost:
			_stats.drain_stamina(cost)
			_stats.take_damage(damage * (1.0 - Skills.block_absorb()))
			CombatFX.burst(_player.get_parent(), spark_pos, Color(1.0, 0.9, 0.5), 8, 3.0)
			_player.shake(0.05)
			return
		# Sin aguante para aguantar el golpe: guardia rota.
		_stats.drain_stamina(_stats.stamina)
		is_blocking = false
		_stagger = 0.7
		damage *= 0.6
		GameManager.show_message("¡GUARDIA ROTA!", Color(1.0, 0.4, 0.3), 1.0)

	_stats.take_damage(damage)
	GameManager.screen_flash.emit(Color(0.75, 0.0, 0.0, 0.45))
	_player.shake(0.12)
	_player.push(hit.get("knockback", Vector3.ZERO))


func _on_died() -> void:
	_pending.clear()
	GameManager.change_state(GameManager.GameState.DEAD)
	GameManager.player_died.emit()
