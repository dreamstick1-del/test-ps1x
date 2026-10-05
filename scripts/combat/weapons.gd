class_name Weapons
extends RefCounted
## Catálogo de armas de Henry. Cada arma define su modelo, sus números y sus
## ataques (secuencias de poses del arma en primera persona, ver
## FirstPersonWeapon.POSES). Las duraciones de las poses se dividen por `speed`.
##
##   damage   daño base de un golpe ligero
##   speed    velocidad de las animaciones (1 = espada)
##   reach    alcance en metros
##   cone     ancho del barrido en grados
##   stamina  aguante por golpe ligero
##   stagger  aturdimiento que causa
##   guard_break  rompe la guardia de un enemigo que bloquea
##   combo    golpes ligeros encadenados: [secuencia, instante del impacto, multiplicador, cono]

const DEFS := {
	"espada": {
		"name": "Espada de Martin", "model": "sword", "damage": 12.0, "speed": 1.0, "reach": 2.2,
		"cone": 110.0, "stamina": 10.0, "stagger": 0.35, "price": 0,
		"desc": "Equilibrada. Tajos rápidos y estocada final.",
		"combo": "slash",
	},
	"espada_acero": {
		"name": "Espada de acero", "model": "sword_steel", "damage": 16.0, "speed": 1.05, "reach": 2.3,
		"cone": 110.0, "stamina": 10.0, "stagger": 0.4, "price": 120,
		"desc": "Acero de Kutná Hora: más daño y algo más rápida.",
		"combo": "slash",
	},
	"hacha": {
		"name": "Hacha de leñador", "model": "axe", "damage": 19.0, "speed": 0.75, "reach": 2.0,
		"cone": 100.0, "stamina": 15.0, "stagger": 0.7, "price": 70,
		"desc": "Lenta pero brutal: aturde y destroza escudos.",
		"combo": "chop", "guard_break": true,
	},
	"maza": {
		"name": "Maza de armas", "model": "mace", "damage": 16.0, "speed": 0.85, "reach": 1.9,
		"cone": 95.0, "stamina": 13.0, "stagger": 0.9, "price": 90,
		"desc": "Aplasta guardias y deja al rival aturdido.",
		"combo": "chop", "guard_break": true,
	},
	"lanza": {
		"name": "Lanza", "model": "spear", "damage": 14.0, "speed": 0.95, "reach": 3.3,
		"cone": 40.0, "stamina": 11.0, "stagger": 0.35, "price": 80,
		"desc": "Mucho alcance: mantén lejos al enemigo con estocadas.",
		"combo": "thrust",
	},
	"daga": {
		"name": "Daga", "model": "dagger", "damage": 8.0, "speed": 1.6, "reach": 1.6,
		"cone": 90.0, "stamina": 6.0, "stagger": 0.2, "price": 40,
		"desc": "Rapidísima y barata en aguante. Ideal agachado: puñalada triple.",
		"combo": "stab",
	},
}

## Combos: [secuencia de poses, impacto (s), multiplicador de daño, cono (0 = el del arma)].
const COMBOS := {
	"slash": [
		[[["wind_r", 0.09], ["slash_l", 0.13], ["slash_l", 0.1], ["rest", 0.16]], 0.15, 1.0, 0.0],
		[[["wind_l", 0.09], ["slash_r", 0.13], ["slash_r", 0.1], ["rest", 0.16]], 0.15, 1.0, 0.0],
		[[["thrust_back", 0.14], ["thrust_fwd", 0.09], ["thrust_fwd", 0.14], ["rest", 0.2]], 0.2, 1.6, 45.0],
	],
	"chop": [
		[[["wind_r", 0.16], ["slash_l", 0.14], ["slash_l", 0.14], ["rest", 0.2]], 0.24, 1.0, 0.0],
		[[["overhead", 0.22], ["overhead_down", 0.1], ["overhead_down", 0.16], ["rest", 0.24]], 0.3, 1.5, 60.0],
	],
	"thrust": [
		[[["thrust_back", 0.12], ["thrust_fwd", 0.08], ["thrust_fwd", 0.12], ["rest", 0.16]], 0.18, 1.0, 0.0],
		[[["thrust_back", 0.1], ["thrust_fwd", 0.08], ["thrust_fwd", 0.12], ["rest", 0.16]], 0.16, 1.0, 0.0],
		[[["wind_r", 0.1], ["slash_l", 0.14], ["slash_l", 0.1], ["rest", 0.18]], 0.17, 1.2, 120.0],
	],
	"stab": [
		[[["thrust_back", 0.07], ["thrust_fwd", 0.06], ["rest", 0.1]], 0.1, 1.0, 0.0],
		[[["wind_r", 0.07], ["slash_l", 0.08], ["rest", 0.1]], 0.1, 1.0, 0.0],
		[[["thrust_back", 0.07], ["thrust_fwd", 0.06], ["rest", 0.1]], 0.1, 1.3, 0.0],
	],
}

## Escudo (mano izquierda): mejora el bloqueo cuando se lleva equipado.
const SHIELD := {"name": "Escudo de madera", "price": 60, "absorb_bonus": 0.18, "stamina_factor": 0.65,
	"block_angle": 0.0, "desc": "Bloquea más daño, gasta menos aguante y cubre más ángulo."}


static func get_def(id: String) -> Dictionary:
	return DEFS.get(id, DEFS["espada"])


static func combo(id: String) -> Array:
	return COMBOS[get_def(id).combo]
