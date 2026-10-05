class_name PlayerCombat
extends Node
## Combate de Henry en primera persona:
##  - Arma equipada (Weapons.DEFS): cada una con su daño, velocidad, alcance y combo.
##    Q / rueda del ratón para cambiar entre las que se tengan.
##  - Clic corto: combo ligero. Mantener: ataque cargado (más daño cuanto más
##    se carga). Corriendo: estocada a la carrera. En el aire: golpe en caída.
##    Agachado contra alguien desprevenido: ataque sigiloso (x2,5).
##  - Bloqueo con parada: si el golpe llega justo al levantar la guardia,
##    no hay daño y el enemigo queda aturdido. Con escudo se bloquea mejor.
##  - Habilidades activas (1, 2, 3) del árbol de Skills.
## Todo gasta aguante: sin aguante no se puede atacar ni bloquear.

const CHARGE_START := 0.28 ## Segundos manteniendo el clic para empezar a cargar.
const CHARGE_FULL := 1.2

var is_blocking := false
var is_charging := false

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
var _press_t := -1.0
var _charge := 0.0
var _air_attack := false


func _ready() -> void:
	_player = get_parent()
	_stats = _player.get_node("Stats")
	_weapon = _player.get_node("Head/Camera3D/Weapon")
	_stats.died.connect(_on_died)
	Skills.changed.connect(_apply_skills)
	Economy.player_changed.connect(_sync_equipment)
	_apply_skills()
	_sync_equipment.call_deferred()


func _apply_skills() -> void:
	_stats.set_maximums(100.0 + Skills.bonus_health(), 100.0 + Skills.bonus_stamina())
	_stats.regen_multiplier = Skills.stamina_regen_multiplier()


func weapon_def() -> Dictionary:
	return Weapons.get_def(Economy.equipped.weapon)


## Modelo del arma y escudo según lo equipado (al comprar o cambiar de arma).
func _sync_equipment() -> void:
	_weapon.set_weapon(weapon_def().model, _weapon.is_inside_tree() and GameManager.is_playing())
	_weapon.set_shield(Economy.has_shield())


## El jugador camina más despacio mientras carga o golpea.
func move_speed_factor() -> float:
	if is_charging:
		return 0.45
	return 0.7 if _busy > 0.0 else 1.0


func _physics_process(delta: float) -> void:
	_tick_pending(delta)
	_busy -= delta
	_stagger -= delta
	_combo_window -= delta

	if not GameManager.is_playing() or _stats.dead or _stagger > 0.0:
		_cancel_charge()
		is_blocking = false
		_weapon.holding_block = false
		_press_t = -1.0
		return

	# Cambiar de arma.
	for dir: int in [1, -1]:
		if Input.is_action_just_pressed("arma_siguiente" if dir == 1 else "arma_anterior") and _busy <= 0.0:
			var before: String = Economy.equipped.weapon
			if Economy.cycle_weapon(dir) != before:
				_cancel_charge()
				_busy = 0.36
				GameManager.show_message(weapon_def().name, Color(0.9, 0.85, 0.7), 0.9)

	var want_block := Input.is_action_pressed("bloquear") and _stats.stamina > 0.0
	if want_block and not is_blocking and _busy <= 0.0:
		_cancel_charge()
		is_blocking = true
		_block_started_ms = Time.get_ticks_msec()
	elif not want_block:
		is_blocking = false
	_weapon.holding_block = is_blocking
	if is_blocking:
		_press_t = -1.0
		return

	# Ataque: pulsación corta = ligero; mantener = cargado.
	if Input.is_action_just_pressed("atacar"):
		_press_t = 0.0
		if not _player.is_on_floor() and _busy <= 0.0:
			_jump_attack()
			_press_t = -1.0
		elif _player.is_running and _busy <= 0.0:
			_running_attack()
			_press_t = -1.0
	if _press_t >= 0.0:
		_press_t += delta
		if Input.is_action_pressed("atacar"):
			if _press_t >= CHARGE_START and not is_charging and _busy <= 0.0 and _stats.stamina > 0.0:
				is_charging = true
				_charge = 0.0
				_weapon.charging = true
		else:
			if is_charging:
				_heavy_attack()
			elif _busy > 0.0:
				_queued = _busy < 0.3 # Encadenar el combo pulsando al final del golpe.
			else:
				_light_attack()
			_press_t = -1.0
	if is_charging:
		_charge = minf(_charge + delta, CHARGE_FULL)
		_stats.regen_blocked = true
	elif _queued and _busy <= 0.0:
		_queued = false
		_light_attack()

	for slot in [1, 2, 3]:
		if Input.is_action_just_pressed("skill_%d" % slot):
			_use_skill(slot)


func _cancel_charge() -> void:
	is_charging = false
	_weapon.charging = false


# --- Ataques -------------------------------------------------------------------

func _light_attack() -> void:
	var w := weapon_def()
	if not _stats.spend_stamina(w.stamina):
		GameManager.show_message("Sin aliento", Color(0.9, 0.9, 0.6), 0.8)
		return
	if _combo_window <= 0.0:
		_combo = 0
	var combo := Weapons.combo(Economy.equipped.weapon)
	var step: Array = combo[_combo % combo.size()]
	var total := _weapon.play(step[0], w.speed)
	_busy = total - 0.06
	_combo_window = total + 0.35
	_combo += 1
	var cone: float = step[3] if step[3] > 0.0 else w.cone
	_schedule_hit(step[1] / w.speed, {
		"damage": w.damage * step[2], "cone": cone, "reach": w.reach + (0.4 if cone < 60.0 else 0.0),
		"stagger": w.stagger, "knockback": 1.5,
	})


## Ataque cargado: tajo de arriba abajo; el daño crece con la carga.
func _heavy_attack() -> void:
	var w := weapon_def()
	var power := _charge / CHARGE_FULL
	_cancel_charge()
	if not _stats.spend_stamina(w.stamina * (1.6 + power)):
		GameManager.show_message("Sin aliento", Color(0.9, 0.9, 0.6), 0.8)
		return
	_busy = _weapon.play([["overhead_down", 0.1], ["overhead_down", 0.22], ["rest", 0.25]], w.speed)
	if power >= 0.99:
		GameManager.show_message("¡GOLPE CARGADO!", Color(1.0, 0.7, 0.3), 0.7)
	_schedule_hit(0.1 / w.speed, {
		"damage": w.damage * lerpf(1.6, 2.6, power), "cone": maxf(w.cone * 0.7, 40.0), "reach": w.reach + 0.2,
		"stagger": w.stagger + 0.6 + power * 0.6, "knockback": 3.0 + power * 3.0, "heavy": true,
	})


## Corriendo: estocada a la carrera con impulso.
func _running_attack() -> void:
	var w := weapon_def()
	if not _stats.spend_stamina(w.stamina * 1.5):
		return
	_player.lunge(7.0)
	_busy = _weapon.play([["thrust_back", 0.08], ["thrust_fwd", 0.08], ["thrust_fwd", 0.16], ["rest", 0.2]], w.speed)
	_schedule_hit(0.14 / w.speed, {
		"damage": w.damage * 1.5, "cone": 50.0, "reach": w.reach + 0.8,
		"stagger": w.stagger + 0.4, "knockback": 4.0, "heavy": true,
	})


## En el aire: el golpe cae al aterrizar (más fuerte cuanto más alta la caída).
func _jump_attack() -> void:
	var w := weapon_def()
	if not _stats.spend_stamina(w.stamina * 1.3):
		return
	_air_attack = true
	_weapon.play([["overhead", 0.12]], w.speed)
	_busy = 2.0 # Hasta aterrizar.


func on_landed(impact: float) -> void:
	if not _air_attack:
		return
	_air_attack = false
	var w := weapon_def()
	_busy = _weapon.play([["overhead_down", 0.08], ["overhead_down", 0.18], ["rest", 0.22]], w.speed)
	_player.shake(0.08)
	_resolve_hit({
		"damage": w.damage * (1.8 + clampf(impact - 5.0, 0.0, 6.0) * 0.08), "cone": 120.0,
		"reach": w.reach + 0.3, "stagger": w.stagger + 0.8, "knockback": 4.5, "heavy": true,
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
	var base_damage: float = weapon_def().damage
	var reach: float = weapon_def().reach
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
		var damage: float = params.damage * Skills.damage_multiplier()
		# Ataque sigiloso: agachado contra alguien que no te ha visto.
		if _player.is_crouching and target.has_method("is_unaware") and target.is_unaware():
			damage *= 2.5
			GameManager.show_message("¡ATAQUE SIGILOSO!", Color(0.8, 0.6, 1.0), 0.9)
		target.receive_hit({
			"damage": damage,
			"stagger": params.stagger,
			"knockback": dir * params.knockback,
			"heavy": params.get("heavy", false),
			"guard_break": weapon_def().get("guard_break", false),
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
	# Con escudo se cubre un ángulo mucho mayor.
	var facing := fwd.dot(to_attacker.normalized()) > (-0.2 if Economy.has_shield() else 0.25)
	var damage: float = hit.damage * (1.0 - Economy.armor_reduction())

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
		var shield := Economy.has_shield()
		var cost := damage * Skills.block_stamina_factor() * (Weapons.SHIELD.stamina_factor if shield else 1.0)
		if hit.get("heavy", false):
			cost *= 1.8 # Los golpes pesados se esquivan o se paran, no se aguantan.
		if _stats.stamina >= cost:
			_stats.drain_stamina(cost)
			var absorb := minf(Skills.block_absorb() + (Weapons.SHIELD.absorb_bonus if shield else 0.0), 0.97)
			_stats.take_damage(damage * (1.0 - absorb))
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
	_cancel_charge()
	GameManager.change_state(GameManager.GameState.DEAD)
	GameManager.player_died.emit()
