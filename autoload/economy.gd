extends Node
## Autoload "Economy": simulación socioeconómica de Skalitz.
##
## - Reloj: el día avanza mientras se juega (1 hora de juego = HOUR_SECONDS s).
## - Mercado: cada bien tiene existencias en el pueblo y un precio que sale de la
##   oferta y la demanda (más existencias -> más barato).
## - Sociedad: ~18 hogares con oficio, clase social, miembros y riqueza.
##   Cada día producen, transforman (trigo -> harina -> pan, trigo -> cerveza,
##   carbón -> herramientas), venden, compran lo que necesitan y, si no llegan,
##   pasan hambre y baja su satisfacción. Cada 7 días pagan impuestos al señor
##   del castillo y el diezmo a la iglesia.
## - Eventos: cosechas, vetas de plata, lobos, mercaderes, ataques de bandidos.
## - Henry: dinero (groschen), inventario, equipo y reputación (afecta precios).

signal market_changed
signal player_changed
signal day_passed(day: int)
signal event_logged(text: String)

const HOUR_SECONDS := 15.0

const GOODS := {
	"trigo": {"name": "Trigo", "base": 2.0},
	"harina": {"name": "Harina", "base": 3.0},
	"pan": {"name": "Pan", "base": 4.0, "use": {"heal": 20.0}, "decay": 0.1},
	"carne": {"name": "Carne", "base": 6.0, "use": {"heal": 35.0}, "decay": 0.15},
	"huevos": {"name": "Huevos", "base": 1.0, "use": {"heal": 6.0}, "decay": 0.1},
	"leche": {"name": "Leche", "base": 2.0, "use": {"stamina": 40.0}, "decay": 0.3},
	"cerveza": {"name": "Cerveza", "base": 3.0, "use": {"stamina": 100.0, "heal": 5.0}},
	"lana": {"name": "Lana", "base": 4.0},
	"pieles": {"name": "Pieles", "base": 8.0},
	"carbon": {"name": "Carbón", "base": 3.0},
	"plata": {"name": "Mineral de plata", "base": 14.0},
	"herramientas": {"name": "Herramientas", "base": 20.0},
}

## Equipo no-arma. Las armas salen de Weapons.DEFS (ver equipment_def()).
const EQUIPMENT := {
	"gambeson": {"name": "Gambesón acolchado", "price": 80, "slot": "armor", "armor": 0.25,
		"desc": "Capas de lino cosidas: -25% de daño recibido."},
	"escudo": {"name": "Escudo de madera", "price": 60, "slot": "shield",
		"desc": "Bloquea más daño, gasta menos aguante y cubre más ángulo."},
}

## Tiendas: qué bienes manejan y qué oficio pone (y recibe) el dinero.
const SHOPS := {
	"mercado": {"name": "Puesto del mercado", "owner": "comerciante",
		"goods": ["pan", "huevos", "leche", "carne", "cerveza", "lana", "pieles"]},
	"herreria": {"name": "Herrería de Martin", "owner": "herrero",
		"goods": ["herramientas", "carbon", "plata"], "equipment": ["espada_acero", "hacha", "maza", "lanza", "daga", "escudo", "gambeson"]},
	"molino": {"name": "Molino del río", "owner": "molinero",
		"goods": ["trigo", "harina", "pan"]},
}

## Oficios. produce: unidades/día por miembro trabajador.
## convert: transforma 'ratio' unidades de 'from' en 1 de 'to', hasta 'rate'/día.
const PROFESSIONS := {
	"campesino": {"label": "Campesinos", "class": "Siervos", "produce": {"trigo": 2.2}},
	"pastor": {"label": "Pastores", "class": "Siervos", "produce": {"lana": 0.7, "leche": 1.4, "carne": 0.3, "huevos": 1.0}},
	"carbonero": {"label": "Carboneros", "class": "Siervos", "produce": {"carbon": 1.6}},
	"cazador": {"label": "Cazadores", "class": "Siervos", "produce": {"carne": 0.6, "pieles": 0.3}},
	"minero": {"label": "Mineros", "class": "Mineros", "produce": {"plata": 0.5}},
	"molinero": {"label": "Molineros", "class": "Artesanos", "convert": {"from": "trigo", "to": "harina", "ratio": 1.0, "rate": 9.0}},
	"panadero": {"label": "Panaderos", "class": "Artesanos", "convert": {"from": "harina", "to": "pan", "ratio": 1.0, "rate": 9.0}},
	"tabernero": {"label": "Taberneros", "class": "Artesanos", "convert": {"from": "trigo", "to": "cerveza", "ratio": 1.0, "rate": 5.0}},
	"herrero": {"label": "Herreros", "class": "Artesanos", "convert": {"from": "carbon", "to": "herramientas", "ratio": 4.0, "rate": 1.0}},
	"comerciante": {"label": "Comerciantes", "class": "Burgueses", "margin": 0.08},
	"clero": {"label": "Clero", "class": "Clero", "wage": 2.0},
	"guardia": {"label": "Guardias", "class": "Guardia", "wage": 3.0},
}

## Consumo diario por persona.
const NEEDS := {"pan": 0.5, "carne": 0.08, "huevos": 0.25, "leche": 0.2, "cerveza": 0.25}
## Lo que gasta cada oficio para trabajar (por hogar y día).
const UPKEEP := {"herramientas": 0.04}

const SURNAMES := ["Novák", "Dvořák", "Černý", "Procházka", "Kučera", "Veselý", "Horák", "Němec",
	"Marek", "Pospíšil", "Hájek", "Jelínek", "Král", "Růžička", "Beneš", "Fiala", "Sedláček", "Zeman"]

# --- Estado ------------------------------------------------------------------

var day := 1
var hour := 8.0
var stock := {}
var prices := {}
var prev_prices := {}
var households: Array[Dictionary] = []
var lord_treasury := 0.0
var church_coffers := 0.0
var safety := 1.0 ## 0-1. Baja tras los ataques.
var harvest := 1.0 ## Modificador de la cosecha de este año.
var mine_yield := 1.0
var event_log: Array[String] = []

var money := 25
var inventory := {}
var owned_equipment: Array[String] = []
var equipped := {"weapon": "espada", "armor": "", "shield": ""}
var reputation := 0.0 ## -100..100

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	reset()


func _process(delta: float) -> void:
	if GameManager.current_state not in [GameManager.GameState.PLAYING, GameManager.GameState.DIALOG]:
		return
	hour += delta / HOUR_SECONDS
	if hour >= 24.0:
		hour -= 24.0
		_simulate_day()


func reset() -> void:
	_rng.seed = 1403
	day = 1
	hour = 8.0
	money = 25
	inventory = {"pan": 2}
	owned_equipment = ["espada"]
	equipped = {"weapon": "espada", "armor": "", "shield": ""}
	reputation = 0.0
	safety = 1.0
	harvest = 1.0
	mine_yield = 1.0
	lord_treasury = 0.0
	church_coffers = 0.0
	event_log = []
	stock = {"trigo": 40.0, "harina": 20.0, "pan": 45.0, "carne": 8.0, "huevos": 30.0, "leche": 14.0,
		"cerveza": 25.0, "lana": 12.0, "pieles": 4.0, "carbon": 20.0, "plata": 6.0, "herramientas": 5.0}
	_build_households()
	_update_prices()
	prev_prices = prices.duplicate()
	log_event("Comienza el día en Skalitz.")
	market_changed.emit()
	player_changed.emit()


func _build_households() -> void:
	households.clear()
	var plan := [
		["campesino", 5], ["pastor", 2], ["carbonero", 1], ["cazador", 1], ["minero", 3],
		["molinero", 1], ["panadero", 1], ["tabernero", 1], ["herrero", 1], ["comerciante", 1],
		["clero", 1], ["guardia", 1],
	]
	var i := 0
	for entry: Array in plan:
		for n in entry[1]:
			var prof: String = entry[0]
			households.append({
				"name": SURNAMES[i % SURNAMES.size()],
				"profession": prof,
				"members": _rng.randi_range(2, 6) if prof not in ["clero", "guardia"] else _rng.randi_range(1, 3),
				"wealth": _rng.randf_range(15.0, 40.0) * (3.0 if prof in ["comerciante", "molinero", "herrero"] else 1.0),
				"satisfaction": 0.8,
			})
			i += 1


# --- Reloj ---------------------------------------------------------------------

func clock_text() -> String:
	return "Día %d  %02d:%02d" % [day, int(hour), int(fmod(hour, 1.0) * 60.0)]


## 0 = noche cerrada, 1 = pleno día.
func daylight() -> float:
	return clampf(sin((hour - 6.0) / 12.0 * PI) * 1.6, 0.0, 1.0) if hour > 5.0 and hour < 19.0 else 0.0


func is_open() -> bool:
	return hour >= 6.0 and hour < 21.0


# --- Mercado -----------------------------------------------------------------

func price(good: String) -> float:
	return prices.get(good, GOODS[good].base)


## Precio al que vende la tienda a Henry (redondeado hacia arriba).
func buy_price(good: String) -> int:
	return maxi(1, ceili(price(good) * 1.2 * (1.0 - reputation / 400.0)))


## Precio que paga la tienda a Henry.
func sell_price(good: String) -> int:
	return maxi(0, floori(price(good) * 0.8 * (1.0 + reputation / 400.0)))


func trend(good: String) -> int:
	var d: float = price(good) - prev_prices.get(good, price(good))
	return 1 if d > 0.05 else (-1 if d < -0.05 else 0)


func shop_funds(shop: String) -> float:
	var owner: String = SHOPS[shop].owner
	var total := 0.0
	for h: Dictionary in households:
		if h.profession == owner:
			total += h.wealth
	return total


func buy(shop: String, good: String) -> String:
	var cost := buy_price(good)
	if stock.get(good, 0.0) < 1.0:
		return "No queda %s." % GOODS[good].name.to_lower()
	if money < cost:
		return "No tienes suficiente dinero."
	money -= cost
	stock[good] -= 1.0
	inventory[good] = inventory.get(good, 0) + 1
	_pay_owner(shop, cost)
	_after_trade()
	return ""


func sell(shop: String, good: String) -> String:
	if inventory.get(good, 0) <= 0:
		return "No tienes %s." % GOODS[good].name.to_lower()
	var pay := sell_price(good)
	if shop_funds(shop) < pay:
		return "El tendero no tiene dinero para pagarte."
	inventory[good] -= 1
	if inventory[good] <= 0:
		inventory.erase(good)
	money += pay
	stock[good] = stock.get(good, 0.0) + 1.0
	_pay_owner(shop, -pay)
	reputation = minf(reputation + 0.2, 100.0)
	_after_trade()
	return ""


## Definición de cualquier equipo: armas (Weapons.DEFS) o el resto (EQUIPMENT).
func equipment_def(id: String) -> Dictionary:
	if Weapons.DEFS.has(id):
		var w: Dictionary = Weapons.DEFS[id].duplicate()
		w["slot"] = "weapon"
		return w
	return EQUIPMENT[id]


func owned_weapons() -> Array[String]:
	var out: Array[String] = []
	for id: String in owned_equipment:
		if Weapons.DEFS.has(id):
			out.append(id)
	return out


## Cambia a la siguiente arma que se tenga (dir = 1 o -1).
func cycle_weapon(dir: int) -> String:
	var list := owned_weapons()
	if list.size() < 2:
		return equipped.weapon
	var i := list.find(equipped.weapon)
	equipped.weapon = list[posmod(i + dir, list.size())]
	player_changed.emit()
	return equipped.weapon


func buy_equipment(shop: String, id: String) -> String:
	var def: Dictionary = equipment_def(id)
	if id in owned_equipment:
		return "Ya lo tienes."
	var cost := ceili(def.price * (1.0 - reputation / 400.0))
	if money < cost:
		return "Cuesta %d groschen. No te llega." % cost
	money -= cost
	owned_equipment.append(id)
	equipped[def.slot] = id
	_pay_owner(shop, cost)
	_after_trade()
	return ""


func equipment_price(id: String) -> int:
	return ceili(equipment_def(id).price * (1.0 - reputation / 400.0))


func _pay_owner(shop: String, amount: float) -> void:
	var owners := households.filter(func(h: Dictionary) -> bool: return h.profession == SHOPS[shop].owner)
	for h: Dictionary in owners:
		h.wealth = maxf(h.wealth + amount / owners.size(), 0.0)


func _after_trade() -> void:
	_update_prices()
	market_changed.emit()
	player_changed.emit()


## Henry recoge algo (caza, mina...).
func add_item(good: String, amount := 1) -> void:
	inventory[good] = inventory.get(good, 0) + amount
	player_changed.emit()


## Usa un consumible. Devuelve el efecto aplicado o "" si no se puede.
func use_item(good: String, player: Node) -> String:
	if inventory.get(good, 0) <= 0 or not GOODS[good].has("use"):
		return ""
	var effect: Dictionary = GOODS[good].use
	var stats: CombatStats = player.get_node("Stats")
	if effect.has("heal"):
		stats.heal(effect.heal)
	if effect.has("stamina"):
		stats.stamina = minf(stats.stamina + effect.stamina, stats.max_stamina)
		stats.stamina_changed.emit(stats.stamina, stats.max_stamina)
	inventory[good] -= 1
	if inventory[good] <= 0:
		inventory.erase(good)
	player_changed.emit()
	return GOODS[good].name


func has_shield() -> bool:
	return equipped.shield != ""


func armor_reduction() -> float:
	return EQUIPMENT[equipped.armor].armor if equipped.armor != "" else 0.0


# --- Sucesos que vienen del juego ---------------------------------------------

func change_reputation(amount: float, reason: String) -> void:
	reputation = clampf(reputation + amount, -100.0, 100.0)
	if reason != "":
		log_event(reason)
	player_changed.emit()


func raid_event() -> void:
	safety = 0.35
	for good: String in ["pan", "carne", "cerveza", "lana"]:
		stock[good] *= 0.6
	log_event("¡Los bandidos asaltan Skalitz! Se llevan comida y lana.")
	_update_prices()
	market_changed.emit()


func raid_repelled() -> void:
	change_reputation(25.0, "Henry ayuda a expulsar a los bandidos. El pueblo se lo agradece.")
	safety = maxf(safety, 0.6)


func log_event(text: String) -> void:
	event_log.push_front("Día %d: %s" % [day, text])
	if event_log.size() > 12:
		event_log.pop_back()
	event_logged.emit(text)


# --- Simulación diaria ----------------------------------------------------------

func _simulate_day() -> void:
	day += 1
	prev_prices = prices.duplicate()

	for h: Dictionary in households:
		var prof: Dictionary = PROFESSIONS[h.profession]
		var workers := maxf(h.members * 0.6, 1.0)
		var eff: float = (0.6 + 0.4 * h.satisfaction) * (0.7 + 0.3 * safety)
		if stock.get("herramientas", 0.0) < 1.0 and h.profession not in ["clero", "guardia", "comerciante"]:
			eff *= 0.75 # Sin herramientas se trabaja peor.

		for good: String in prof.get("produce", {}):
			var mod := harvest if good == "trigo" else (mine_yield if good == "plata" else 1.0)
			var q: float = prof.produce[good] * workers * eff * mod
			stock[good] += q
			h.wealth += q * price(good) * 0.7
		if prof.has("convert"):
			var c: Dictionary = prof.convert
			var q := minf(c.rate * eff, stock.get(c.from, 0.0) / c.ratio)
			stock[c.from] -= q * c.ratio
			stock[c.to] += q
			h.wealth += maxf(q * (price(c.to) - price(c.from) * c.ratio), q * 0.3)
		if prof.has("wage"):
			var wage: float = prof.wage * h.members
			var payer := "lord" if h.profession == "guardia" else "church"
			if payer == "lord":
				lord_treasury -= wage
			else:
				church_coffers -= wage
			h.wealth += wage
		if prof.has("margin"):
			h.wealth += _market_volume() * prof.margin

		# Consumo: compra lo que puede; si no llega, pasa necesidad.
		var met := 0.0
		var wanted := 0.0
		for good: String in NEEDS:
			var want: float = NEEDS[good] * h.members
			var p := price(good)
			var can := minf(want, minf(stock.get(good, 0.0), h.wealth / p))
			stock[good] -= can
			h.wealth -= can * p
			met += can / want * (2.0 if good == "pan" else 1.0)
			wanted += 2.0 if good == "pan" else 1.0
		for good: String in UPKEEP:
			var q: float = minf(UPKEEP[good], stock.get(good, 0.0))
			stock[good] -= q
		h.satisfaction = lerpf(h.satisfaction, met / wanted * (0.6 + 0.4 * safety), 0.5)

	# Impuestos semanales al señor y diezmo a la iglesia.
	if day % 7 == 0:
		var taxed := 0.0
		var tithe := 0.0
		for h: Dictionary in households:
			if h.profession in ["clero", "guardia"]:
				continue
			taxed += h.wealth * 0.10
			tithe += h.wealth * 0.05
			h.wealth *= 0.85
		lord_treasury += taxed
		church_coffers += tithe
		log_event("Se cobran impuestos: %d gr para Sir Radzig y %d de diezmo." % [taxed, tithe])

	for good: String in GOODS:
		stock[good] = maxf(stock[good] * (1.0 - GOODS[good].get("decay", 0.0)), 0.0)
	safety = minf(safety + 0.08, 1.0)
	_random_event()
	_update_prices()
	day_passed.emit(day)
	market_changed.emit()


func _random_event() -> void:
	if _rng.randf() > 0.3:
		return
	match _rng.randi_range(0, 5):
		0:
			harvest = 1.4
			log_event("Buena cosecha: los campos rebosan de trigo.")
		1:
			harvest = 0.5
			log_event("El tizón ataca el trigo. La cosecha será pobre.")
		2:
			mine_yield = 1.8
			log_event("Los mineros encuentran una nueva veta de plata.")
		3:
			stock["lana"] *= 0.6
			stock["carne"] *= 0.6
			log_event("Los lobos atacan el rebaño durante la noche.")
		4:
			stock["herramientas"] += 6.0
			stock["cerveza"] += 15.0
			log_event("Llega un mercader de Praga con herramientas y cerveza.")
		5:
			harvest = 1.0
			mine_yield = 1.0
			log_event("Una semana tranquila en Skalitz.")


func _update_prices() -> void:
	var population := population_total()
	for good: String in GOODS:
		var daily: float = NEEDS.get(good, 0.0) * population
		var target := daily * 3.0 + 8.0
		var ratio := target / maxf(stock.get(good, 0.0), 0.5)
		prices[good] = GOODS[good].base * clampf(pow(ratio, 0.5), 0.4, 3.0)


func _market_volume() -> float:
	var v := 0.0
	for good: String in NEEDS:
		v += NEEDS[good] * population_total() * price(good)
	return v * 0.1


# --- Estadísticas (Diario) -------------------------------------------------------

func population_total() -> int:
	var n := 0
	for h: Dictionary in households:
		n += h.members
	return n


## [{class, households, people, avg_wealth, satisfaction}] por clase social.
func class_summary() -> Array:
	var by := {}
	for h: Dictionary in households:
		var c: String = PROFESSIONS[h.profession]["class"]
		if not by.has(c):
			by[c] = {"class": c, "households": 0, "people": 0, "wealth": 0.0, "satisfaction": 0.0}
		by[c].households += 1
		by[c].people += h.members
		by[c].wealth += h.wealth
		by[c].satisfaction += h.satisfaction
	var out := []
	for c: String in by:
		var d: Dictionary = by[c]
		out.append({"class": c, "households": d.households, "people": d.people,
			"avg_wealth": d.wealth / d.households, "satisfaction": d.satisfaction / d.households})
	return out


func satisfaction_avg() -> float:
	var s := 0.0
	for h: Dictionary in households:
		s += h.satisfaction
	return s / households.size()


## 0-100: satisfacción, seguridad y comida disponible.
func prosperity() -> float:
	var food := clampf(stock.get("pan", 0.0) / (NEEDS.pan * population_total() * 3.0), 0.0, 1.0)
	return 100.0 * (satisfaction_avg() * 0.5 + safety * 0.25 + food * 0.25)


## Comentario de un aldeano según cómo va el pueblo.
func gossip(profession := "") -> String:
	var lines: Array[String] = []
	var worst := ""
	var worst_ratio := 1.0
	for good: String in GOODS:
		var r: float = price(good) / GOODS[good].base
		if r > worst_ratio:
			worst_ratio = r
			worst = good
	if worst != "" and worst_ratio > 1.5:
		lines.append("¿Has visto a cuánto está %s? %d groschen. ¡Un robo!" % [GOODS[worst].name.to_lower(), roundi(price(worst))])
	if safety < 0.6:
		lines.append("Desde el ataque de los bandidos nadie duerme tranquilo.")
	if satisfaction_avg() < 0.5:
		lines.append("Muchas familias pasan hambre este mes. Algo tiene que cambiar.")
	if prosperity() > 75.0:
		lines.append("Buenos tiempos para Skalitz, gracias a Dios.")
	if reputation > 30.0:
		lines.append("Todos hablan bien de ti, Henry.")
	elif reputation < -20.0:
		lines.append("No me fío de ti, muchacho. La gente habla.")
	match profession:
		"minero": lines.append("La plata de la mina sale a %d groschen. Si encuentras mineral, véndeselo a Martin." % roundi(price("plata")))
		"molinero": lines.append("El molino no para: el trigo entra por un lado y la harina sale por el otro.")
		"campesino": lines.append("Este año la cosecha va %s." % ("muy bien" if harvest > 1.1 else ("fatal" if harvest < 0.8 else "como siempre")))
		"herrero": lines.append("Con un buen acero y un gambesón no te tumba ni un cumano.")
	if lines.is_empty():
		lines.append("Día tranquilo en Skalitz.")
	return lines[_rng.randi() % lines.size()]
