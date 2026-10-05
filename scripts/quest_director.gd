class_name QuestDirector
extends Node
## Misión de introducción, que va enseñando cada sistema:
##   0. Habla con Martin.            -> diálogo
##   1. Golpea el muñeco 5 veces.    -> combate básico
##   2. Aprende una habilidad (Tab). -> árbol de habilidades
##   3. Habla con el guardia.        -> dispara el asalto
##   4. Primera oleada de bandidos.
##   5. Segunda oleada con su cabecilla.
##   6. Fin: Skalitz a salvo.
## La etapa se guarda en GameManager.quest_stage: al reintentar tras morir
## se repite la oleada en curso.

const WAVES := [
	[
		{"pos": Vector3(-1.0, 0, 15.6), "model": "Character_05"},
		{"pos": Vector3(1.0, 0, 15.9), "model": "Character_03"},
		{"pos": Vector3(0.0, 0, 14.6), "model": "Character_05"},
	],
	[
		{"pos": Vector3(-1.2, 0, 15.6), "model": "Character_03"},
		{"pos": Vector3(1.2, 0, 15.6), "model": "Character_05"},
		{"pos": Vector3(0.0, 0, 16.2), "model": "Character_04", "boss": true},
	],
]

var world: Node3D
var _dummy_hits := 0
var _alive := 0


func start(diorama_world: Node3D) -> void:
	world = diorama_world
	GameManager.dialog_finished.connect(_on_dialog_finished)
	Skills.changed.connect(_on_skills_changed)
	for dummy in get_tree().get_nodes_in_group("training_dummy"):
		dummy.hit.connect(_on_dummy_hit)
	_enter(GameManager.quest_stage)


func _enter(stage: int) -> void:
	GameManager.quest_stage = stage
	match stage:
		0:
			GameManager.set_objective("Habla con Martin, tu padre, en la forja.")
		1:
			_dummy_hits = 0
			GameManager.set_objective("Practica con el muñeco de paja (clic izq.: atacar, clic der.: bloquear).")
		2:
			if _any_skill_learned():
				_enter(3)
				return
			GameManager.set_objective("Tienes un punto de habilidad: pulsa Tab y aprende algo.")
		3:
			GameManager.set_objective("Habla con el guardia de la puerta sur.")
		4:
			GameManager.set_objective("¡Bandidos! Defiende Skalitz.")
			GameManager.show_message("¡BANDIDOS EN LA PUERTA!", Color(1.0, 0.35, 0.25), 2.5)
			_spawn_wave(0)
		5:
			GameManager.set_objective("¡Acaba con su cabecilla!")
			GameManager.show_message("¡VIENE SU CABECILLA!", Color(1.0, 0.35, 0.25), 2.5)
			_spawn_wave(1)
		6:
			GameManager.set_objective("Skalitz está a salvo... por ahora.")
			GameManager.show_message("¡VICTORIA!", Color(1.0, 0.85, 0.3), 3.0)
			GameManager.show_subtitle("Los bandidos huyen. Pero algo más grande se acerca por el camino del sur...", 6.0)


func _on_dialog_finished() -> void:
	var speaker := GameManager.last_speaker
	if GameManager.quest_stage == 0 and speaker == "Martin":
		_enter(1)
	elif GameManager.quest_stage == 3 and speaker == "Guardia":
		_enter(4)


func _on_dummy_hit() -> void:
	if GameManager.quest_stage != 1:
		return
	_dummy_hits += 1
	if _dummy_hits >= 5:
		GameManager.show_message("¡Bien hecho!", Color(0.7, 1.0, 0.6), 1.2)
		_enter(2)


func _on_skills_changed() -> void:
	if GameManager.quest_stage == 2 and _any_skill_learned():
		_enter(3)


func _any_skill_learned() -> bool:
	for id: String in Skills.DEFS:
		if Skills.rank(id) > 0:
			return true
	return false


func _spawn_wave(index: int) -> void:
	_alive = 0
	for spec: Dictionary in WAVES[index]:
		var b := Bandit.new()
		b.model_path = "res://assets/characters/%s.fbx" % spec.model
		b.sight_range = 60.0
		if spec.get("boss", false):
			b.display_name = "Cabecilla"
			b.outfit = "jefe"
			b.weapon = "hammer"
			b.max_health = 120.0
			b.damage = 20.0
			b.move_speed = 2.6
			b.xp_reward = 80
			b.body_scale = 1.1
			b.attack_cooldown = Vector2(1.4, 2.4)
		else:
			b.weapon = "axe" if spec.model == "Character_05" else "sword"
		b.position = spec.pos
		b.rotation.y = 0.0
		world.add_child(b)
		b.killed.connect(_on_bandit_killed)
		_alive += 1


func _on_bandit_killed(_b: Bandit) -> void:
	_alive -= 1
	if _alive > 0:
		GameManager.set_objective("¡Bandidos! Quedan %d." % _alive)
		return
	var next := GameManager.quest_stage + 1
	await get_tree().create_timer(3.0, false).timeout
	_enter(next)
