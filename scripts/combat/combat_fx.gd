class_name CombatFX
extends RefCounted
## Efectos de impacto: chispas/sangre en cubitos y "hit-stop" (congelar un
## instante el juego al golpear, para que los golpes pesen).

static var _hitstop_token := 0


static func burst(parent: Node, pos: Vector3, color: Color, amount := 10, speed := 3.0) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = amount
	p.lifetime = 0.45
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -9.8, 0)
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE * 0.05
	p.mesh = cube
	p.material_override = PS1Assets.flat(color, 0.6)
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	parent.get_tree().create_timer(1.0, true, false, true).timeout.connect(p.queue_free)


static func hitstop(tree: SceneTree, duration := 0.06) -> void:
	_hitstop_token += 1
	var token := _hitstop_token
	Engine.time_scale = 0.05
	await tree.create_timer(duration, true, false, true).timeout
	if token == _hitstop_token:
		Engine.time_scale = 1.0
