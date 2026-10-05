class_name DioramaWorld
extends Node3D
## Construye proceduralmente el diorama de Skalitz (Bohemia, 1403): una maqueta
## sobre una peana de madera, encima de una mesa. Todo se genera con primitivas
## y texturas de 32x32 para no depender de assets externos.
##
## Coordenadas: +X este, -Z norte. La maqueta mide 96x96 m (de -48 a 48);
## el pueblo amurallado ocupa el centro (-18 a 18) y el campo lo construye
## Countryside. También lleva el ciclo de día y noche (Economy.hour).
## Registra "map_features" (huellas de edificios) para el minimapa.
## set_first_person() cambia la atmósfera al bajar a jugar dentro de la maqueta.

const HALF := 18.0 ## Mitad del pueblo amurallado.
const WORLD_HALF := 48.0 ## Mitad de la maqueta entera.
const PLINTH_HEIGHT := 3.0
const PLINTH_TOP := -1.6

var map_features: Array[Dictionary] = []
## Líneas del minimapa (río, caminos): {points, color, width}.
var map_lines: Array[Dictionary] = []
## Nodos que giran sin parar (rueda del molino): {node, speed}.
var spinners: Array[Dictionary] = []

var _first_person := false
var _sun: DirectionalLight3D
var _env: Environment
var _fire_light: OmniLight3D
var _fire_timer := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("diorama_world")
	_rng.seed = 1403
	_build_environment()
	_build_base()
	_build_ground()
	Countryside.new(self).build()
	_build_church()
	_build_forge()
	_build_houses()
	_build_walls()
	_build_props()
	_build_trees()
	_build_bounds()
	_build_villagers()
	_build_location_zones()
	_build_training_ground()
	_build_animals()


func _process(delta: float) -> void:
	# Parpadeo del fuego de la fragua a ~12 fps: nervioso, como en la época.
	_fire_timer -= delta
	if _fire_light and _fire_timer <= 0.0:
		_fire_timer = 1.0 / 12.0
		_fire_light.light_energy = _rng.randf_range(1.4, 2.2)
	for sp: Dictionary in spinners:
		(sp.node as Node3D).rotate_x(sp.speed * delta)
	_update_daylight()


## Sol, luz ambiente y color del cielo según la hora (Economy.hour).
func _update_daylight() -> void:
	var d := Economy.daylight()
	_sun.light_energy = lerpf(0.08, 1.05, d)
	_sun.rotation_degrees.x = lerpf(-8.0, -58.0, d)
	_sun.light_color = Color(1.0, 0.6, 0.4).lerp(Color(1.0, 0.92, 0.78), d)
	_env.ambient_light_energy = lerpf(0.3, 0.75, d)
	_env.ambient_light_color = Color(0.32, 0.38, 0.6).lerp(Color(0.55, 0.55, 0.66), d)
	if _first_person:
		var night := Color(0.04, 0.05, 0.1)
		var dusk := Color(0.6, 0.42, 0.36)
		var day := Color(0.48, 0.56, 0.68)
		var sky := night.lerp(dusk, d / 0.35) if d < 0.35 else dusk.lerp(day, (d - 0.35) / 0.65)
		_env.background_color = sky
		_env.fog_light_color = sky


# --- Entorno -------------------------------------------------------------------

## Dentro de la maqueta: cielo de atardecer y niebla densa (la distancia de
## dibujado corta típica de PS1). Desde fuera: la habitación oscura.
func set_first_person(enabled: bool) -> void:
	_first_person = enabled
	if not enabled:
		_env.background_color = Color(0.09, 0.07, 0.10)
		_env.fog_light_color = _env.background_color
	create_tween().tween_property(_env, "fog_density", 0.035 if enabled else 0.0015, 1.0)


func _build_environment() -> void:
	var env := Environment.new()
	_env = env
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.09, 0.07, 0.10)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.55, 0.66)
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_light_color = Color(0.09, 0.07, 0.10)
	env.fog_density = 0.0015
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	_sun = sun
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.light_color = Color(1.0, 0.92, 0.78)
	sun.light_energy = 1.05
	sun.shadow_enabled = false # La PS1 no tenía sombras reales: usamos "blobs".
	add_child(sun)


## Peana de madera, mesa y placa con el nombre. El terreno lo pone Countryside.
func _build_base() -> void:
	var wood := PS1Assets.material("wood", Color(0.75, 0.6, 0.5), Vector2(0.2, 0.2))
	var plinth := BoxMesh.new()
	plinth.size = Vector3(WORLD_HALF * 2 + 2.4, PLINTH_HEIGHT, WORLD_HALF * 2 + 2.4)
	plinth.subdivide_width = 24
	plinth.subdivide_depth = 24
	_mesh(self, plinth, Vector3(0, PLINTH_TOP - PLINTH_HEIGHT * 0.5, 0), wood)

	var table := PlaneMesh.new()
	table.size = Vector2(420, 420)
	table.subdivide_width = 30
	table.subdivide_depth = 30
	_mesh(self, table, Vector3(0, PLINTH_TOP - PLINTH_HEIGHT, 0),
		PS1Assets.material("wood", Color(0.35, 0.24, 0.2), Vector2(0.05, 0.05)))

	var plaque_z := WORLD_HALF + 1.2
	_box(self, Vector3(22, 2.2, 0.1), Vector3(0, PLINTH_TOP - 1.5, plaque_z + 0.02), PS1Assets.flat(Color(0.45, 0.33, 0.12)))
	var label := Label3D.new()
	label.text = "SKALITZ  ·  ANNO 1403"
	label.font_size = 64
	label.pixel_size = 0.03
	label.modulate = Color(1.0, 0.85, 0.45)
	label.outline_size = 0
	label.shaded = false
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	label.position = Vector3(0, PLINTH_TOP - 1.5, plaque_z + 0.08)
	add_child(label)


func _build_ground() -> void:
	var dirt := PS1Assets.material("dirt", Color.WHITE, Vector2(0.6, 0.6))
	_plane(Vector2(3.0, 12.0), Vector3(0, 0.02, 11.9), dirt, 6)      # camino sur
	_plane(Vector2(4.5, 3.0), Vector3(7.5, 0.02, 1.0), dirt, 3)      # hacia la forja
	_plane(Vector2(5.6, 2.4), Vector3(-8.2, 0.02, 4.5), dirt, 3)     # barrio oeste
	_plane(Vector2(2.6, 1.4), Vector3(0, 0.02, -5.9), dirt, 2)       # puerta iglesia
	_plane(Vector2(11, 11), Vector3(0, 0.035, 0), PS1Assets.material("cobble", Color.WHITE, Vector2(0.5, 0.5)), 6)
	map_features.append({"pos": Vector2(0, 0), "size": Vector2(11, 11), "rot": 0.0, "color": Color(0.45, 0.43, 0.4)})
	map_features.append({"pos": Vector2(0, 11.9), "size": Vector2(3, 12), "rot": 0.0, "color": Color(0.5, 0.38, 0.25)})


# --- Edificios -----------------------------------------------------------------

func _build_church() -> void:
	var stone := PS1Assets.material("stone", Color(0.95, 0.93, 0.9), Vector2(0.5, 0.5))
	var roof := PS1Assets.material("shingle", Color(0.6, 0.6, 0.75), Vector2(0.6, 0.6))
	var dark := PS1Assets.flat(Color(0.06, 0.05, 0.05))

	# Nave
	_box(self, Vector3(6, 4.5, 8), Vector3(0, 2.25, -10), stone)
	var prism := PrismMesh.new()
	prism.size = Vector3(6.8, 3.0, 8.4)
	_mesh(self, prism, Vector3(0, 4.5 + 1.5, -10), roof)
	_box(self, Vector3(1.4, 2.4, 0.1), Vector3(0, 1.2, -5.97), PS1Assets.material("wood", Color(0.6, 0.45, 0.35), Vector2(1, 1)))
	_box(self, Vector3(0.7, 1.4, 0.1), Vector3(0, 3.6, -5.97), dark) # rosetón
	for z: float in [-12.0, -9.5, -7.5]:
		for x: float in [-3.03, 3.03]:
			_box(self, Vector3(0.1, 1.4, 0.6), Vector3(x, 2.8, z), dark)
	_solid(Vector3(6, 4.5, 8), Vector3(0, 2.25, -10))

	# Torre
	_box(self, Vector3(3, 9, 3), Vector3(0, 4.5, -15.5), stone)
	var spire := CylinderMesh.new()
	spire.top_radius = 0.0
	spire.bottom_radius = 2.4
	spire.height = 4.0
	spire.radial_segments = 4
	spire.rings = 1
	_mesh(self, spire, Vector3(0, 11, -15.5), roof, Vector3(0, PI / 4, 0))
	for side: Vector3 in [Vector3(0, 0, 1.53), Vector3(1.53, 0, 0), Vector3(-1.53, 0, 0)]:
		var size := Vector3(0.9, 1.4, 0.1) if side.x == 0.0 else Vector3(0.1, 1.4, 0.9)
		_box(self, size, Vector3(0, 7.6, -15.5) + side, dark)
	var gold := PS1Assets.flat(Color(0.9, 0.75, 0.3), 0.3)
	_box(self, Vector3(0.12, 1.2, 0.12), Vector3(0, 13.5, -15.5), gold)
	_box(self, Vector3(0.7, 0.12, 0.12), Vector3(0, 13.7, -15.5), gold)
	_solid(Vector3(3, 9, 3), Vector3(0, 4.5, -15.5))

	_feature(Vector3(0, 0, -10), Vector2(6, 8), Color(0.62, 0.62, 0.66))
	_feature(Vector3(0, 0, -15.5), Vector2(3, 3), Color(0.7, 0.7, 0.75))


func _build_forge() -> void:
	# La herrería de Martin, el padre de Henry. Puerta mirando a la plaza (oeste).
	var root := _house(Vector3(12, 0, 1), 6.0, 5.0, 3.2, -PI / 2, "shingle", Color(0.55, 0.35, 0.3))
	var stone := PS1Assets.material("stone", Color(0.8, 0.78, 0.75), Vector2(0.8, 0.8))
	# Chimenea
	_box(root, Vector3(1.0, 3.0, 1.0), Vector3(1.6, 4.4, 1.2), stone)

	# Fragua al aire libre bajo un tejadillo
	var wood := PS1Assets.material("wood", Color.WHITE, Vector2(0.8, 0.8))
	_box(self, Vector3(1.6, 0.9, 1.3), Vector3(8.2, 0.45, -0.9), stone)
	_box(self, Vector3(1.1, 0.12, 0.8), Vector3(8.2, 0.93, -0.9), PS1Assets.flat(Color(1.0, 0.45, 0.1), 2.5))
	for x: float in [7.3, 9.1]:
		_box(self, Vector3(0.15, 2.3, 0.15), Vector3(x, 1.15, -1.7), wood)
	var awning := PrismMesh.new()
	awning.size = Vector3(2.4, 0.6, 2.2)
	_mesh(self, awning, Vector3(8.2, 2.55, -0.9), PS1Assets.material("thatch", Color.WHITE, Vector2(0.8, 0.8)))
	_solid(Vector3(1.6, 0.9, 1.3), Vector3(8.2, 0.45, -0.9))

	_fire_light = OmniLight3D.new()
	_fire_light.light_color = Color(1.0, 0.55, 0.2)
	_fire_light.omni_range = 6.0
	_fire_light.position = Vector3(8.2, 1.4, -0.9)
	add_child(_fire_light)

	# Yunque
	var iron := PS1Assets.flat(Color(0.22, 0.22, 0.25))
	_box(self, Vector3(0.5, 0.55, 0.5), Vector3(8.0, 0.28, 2.2), wood)
	_box(self, Vector3(0.75, 0.2, 0.3), Vector3(8.0, 0.65, 2.2), iron)
	_box(self, Vector3(0.25, 0.12, 0.2), Vector3(8.45, 0.68, 2.2), iron)
	_solid(Vector3(0.75, 0.8, 0.5), Vector3(8.0, 0.4, 2.2))


func _build_houses() -> void:
	var houses := [
		# pos, ancho, fondo, alto, rotación, tejado
		[Vector3(-10, 0, -3), 5.0, 4.0, 3.0, 0.0, "thatch"],
		[Vector3(-13, 0, 5), 4.0, 5.0, 2.8, PI / 2, "shingle"],
		[Vector3(-8, 0, 12), 4.5, 4.0, 3.0, 0.0, "thatch"],
		[Vector3(9, 0, -9), 5.0, 4.0, 3.0, 0.0, "shingle"],
		[Vector3(14, 0, -13), 4.0, 4.0, 2.8, 0.0, "thatch"],
		[Vector3(-13, 0, -13), 4.0, 5.0, 3.0, 0.0, "shingle"],
		[Vector3(13, 0, 11), 4.0, 4.0, 2.8, -PI / 2, "thatch"],
	]
	for h: Array in houses:
		var root := _house(h[0], h[1], h[2], h[3], h[4], h[5], Color(0.6, 0.45, 0.3))
		if h[5] == "shingle":
			_box(root, Vector3(0.6, 1.6, 0.6), Vector3(h[1] * 0.25, h[3] + 1.2, 0.0),
				PS1Assets.material("stone", Color(0.8, 0.75, 0.7), Vector2(1, 1)))


## Casa de entramado: paredes, tejado a dos aguas, puerta y ventanas en +Z local.
func _house(pos: Vector3, w: float, d: float, h: float, rot_y: float, roof_tex: String,
		map_color: Color) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = rot_y
	add_child(root)

	_box(root, Vector3(w, h, d), Vector3(0, h * 0.5, 0), PS1Assets.material("plaster"))
	var roof_h := w * 0.42
	var prism := PrismMesh.new()
	prism.size = Vector3(w + 0.6, roof_h, d + 0.6)
	var roof_tint := Color(1, 1, 1) if roof_tex == "thatch" else Color(0.95, 0.85, 0.85)
	_mesh(root, prism, Vector3(0, h + roof_h * 0.5, 0), PS1Assets.material(roof_tex, roof_tint, Vector2(0.6, 0.6)))

	var door_mat := PS1Assets.material("wood", Color(0.7, 0.55, 0.45), Vector2(1.2, 1.2))
	_box(root, Vector3(0.9, 1.7, 0.1), Vector3(0, 0.85, d * 0.5 + 0.02), door_mat)
	var window_mat := PS1Assets.flat(Color(0.12, 0.09, 0.06))
	for sx: float in [-1.0, 1.0]:
		_box(root, Vector3(0.55, 0.5, 0.1), Vector3(sx * w * 0.3, h * 0.6, d * 0.5 + 0.02), window_mat)
		_box(root, Vector3(0.1, 0.5, 0.55), Vector3(sx * (w * 0.5 + 0.02), h * 0.6, 0), window_mat)

	_solid(Vector3(w, h, d), pos + Vector3(0, h * 0.5, 0), rot_y)
	_feature(pos, Vector2(w, d), map_color, rot_y)
	return root


func _build_walls() -> void:
	var stone := PS1Assets.material("stone", Color(0.88, 0.86, 0.82), Vector2(0.5, 0.5))
	var roof := PS1Assets.material("shingle", Color(0.9, 0.8, 0.8), Vector2(0.8, 0.8))
	var z := HALF - 0.8
	# Muralla sur con puerta
	for x_range: Vector2 in [Vector2(-HALF + 0.4, -3.2), Vector2(3.2, HALF - 0.4)]:
		var length := x_range.y - x_range.x
		var center := Vector3((x_range.x + x_range.y) * 0.5, 0.9, z)
		_box(self, Vector3(length, 1.8, 0.8), center, stone)
		_solid(Vector3(length, 1.8, 0.8), center)
		_feature(center, Vector2(length, 0.8), Color(0.55, 0.55, 0.55))
		# Almenas
		var x := x_range.x + 0.4
		while x < x_range.y - 0.3:
			_box(self, Vector3(0.5, 0.4, 0.8), Vector3(x, 2.0, z), stone)
			x += 1.0
	for sx: float in [-2.4, 2.4]:
		_box(self, Vector3(1.6, 3.4, 1.6), Vector3(sx, 1.7, z), stone)
		var cap := CylinderMesh.new()
		cap.top_radius = 0.0
		cap.bottom_radius = 1.3
		cap.height = 1.4
		cap.radial_segments = 4
		cap.rings = 1
		_mesh(self, cap, Vector3(sx, 4.1, z), roof, Vector3(0, PI / 4, 0))
		_solid(Vector3(1.6, 3.4, 1.6), Vector3(sx, 1.7, z))
		_feature(Vector3(sx, 0, z), Vector2(1.6, 1.6), Color(0.6, 0.6, 0.6))

	# Empalizada de estacas en los otros tres lados.
	var stake := CylinderMesh.new()
	stake.top_radius = 0.0
	stake.bottom_radius = 0.16
	stake.height = 1.9
	stake.radial_segments = 5
	stake.rings = 1
	var stake_mat := PS1Assets.material("wood", Color(0.8, 0.7, 0.6), Vector2(1, 1))
	var p := -HALF + 0.3
	# Huecos: este (puente), oeste (mina) y norte (castillo).
	while p <= HALF - 0.3:
		var lean := _rng.randf_range(-0.08, 0.08)
		if p < 3.0 or p > 6.0:
			_mesh(self, stake, Vector3(-HALF + 0.3, 0.95, p), stake_mat, Vector3(lean, 0, lean))
		if absf(p) > 1.8:
			_mesh(self, stake, Vector3(HALF - 0.3, 0.95, p), stake_mat, Vector3(-lean, 0, lean))
		if p < 7.8 or p > 11.2:
			_mesh(self, stake, Vector3(p, 0.95, -HALF + 0.3), stake_mat, Vector3(lean, 0, -lean))
		p += 0.75
	var post := Vector3(0.3, 2.6, 0.3)
	for gate: Vector3 in [Vector3(-HALF + 0.3, 1.3, 2.8), Vector3(-HALF + 0.3, 1.3, 6.2), Vector3(HALF - 0.3, 1.3, -2.0),
			Vector3(HALF - 0.3, 1.3, 2.0), Vector3(7.6, 1.3, -HALF + 0.3), Vector3(11.4, 1.3, -HALF + 0.3)]:
		_box(self, post, gate, stake_mat)
	# Colisión de la empalizada (con sus huecos).
	_solid(Vector3(0.5, 2.5, HALF - 6.4 + HALF), Vector3(-HALF + 0.3, 1.2, (-HALF + 2.8) * 0.5 + 0.0))
	_solid(Vector3(0.5, 2.5, HALF - 6.2), Vector3(-HALF + 0.3, 1.2, (6.2 + HALF) * 0.5))
	_solid(Vector3(0.5, 2.5, HALF - 2.0), Vector3(HALF - 0.3, 1.2, (-HALF - 2.0) * 0.5))
	_solid(Vector3(0.5, 2.5, HALF - 2.0), Vector3(HALF - 0.3, 1.2, (HALF + 2.0) * 0.5))
	_solid(Vector3(HALF + 7.6, 2.5, 0.5), Vector3((-HALF + 7.6) * 0.5, 1.2, -HALF + 0.3))
	_solid(Vector3(HALF - 11.4, 2.5, 0.5), Vector3((HALF + 11.4) * 0.5, 1.2, -HALF + 0.3))


# --- Atrezo ------------------------------------------------------------------

func _build_props() -> void:
	var stone := PS1Assets.material("stone", Color.WHITE, Vector2(1.0, 1.0))
	var wood := PS1Assets.material("wood", Color.WHITE, Vector2(1.0, 1.0))
	var thatch := PS1Assets.material("thatch", Color.WHITE, Vector2(1.0, 1.0))

	# Pozo en el centro de la plaza
	var ring := CylinderMesh.new()
	ring.top_radius = 0.9
	ring.bottom_radius = 0.95
	ring.height = 0.8
	ring.radial_segments = 8
	ring.rings = 1
	_mesh(self, ring, Vector3(0, 0.4, 0), stone)
	var water := CylinderMesh.new()
	water.top_radius = 0.7
	water.bottom_radius = 0.7
	water.height = 0.05
	water.radial_segments = 8
	_mesh(self, water, Vector3(0, 0.78, 0), PS1Assets.material("water", Color.WHITE, Vector2(1, 1)))
	for sx: float in [-0.75, 0.75]:
		_box(self, Vector3(0.14, 1.6, 0.14), Vector3(sx, 1.4, 0), wood)
	_box(self, Vector3(1.7, 0.1, 0.1), Vector3(0, 1.95, 0), wood)
	var well_roof := PrismMesh.new()
	well_roof.size = Vector3(2.0, 0.7, 1.4)
	_mesh(self, well_roof, Vector3(0, 2.45, 0), thatch, Vector3(0, PI / 2, 0))
	_cylinder_solid(1.0, 1.0, Vector3(0, 0.5, 0))
	_feature(Vector3.ZERO, Vector2(1.8, 1.8), Color(0.3, 0.4, 0.55))

	# Puesto del mercado
	var stall := Vector3(-3.8, 0, -3.0)
	_box(self, Vector3(2.6, 0.9, 1.2), stall + Vector3(0, 0.45, 0), wood)
	for corner: Vector3 in [Vector3(-1.2, 0, -0.5), Vector3(1.2, 0, -0.5), Vector3(-1.2, 0, 0.5), Vector3(1.2, 0, 0.5)]:
		_box(self, Vector3(0.1, 2.0, 0.1), stall + corner + Vector3(0, 1.0, 0), wood)
	for i in 4:
		var stripe := PS1Assets.flat(Color(0.75, 0.15, 0.12) if i % 2 == 0 else Color(0.9, 0.85, 0.7))
		_box(self, Vector3(0.7, 0.08, 1.5), stall + Vector3(-1.05 + i * 0.7, 2.05, 0), stripe)
	for i in 5:
		var produce := PS1Assets.flat([Color(0.8, 0.2, 0.1), Color(0.9, 0.7, 0.2), Color(0.4, 0.6, 0.2)][i % 3])
		_box(self, Vector3(0.25, 0.2, 0.25), stall + Vector3(-1.0 + i * 0.5, 1.0, 0), produce)
	_solid(Vector3(2.6, 0.9, 1.2), stall + Vector3(0, 0.45, 0))
	_feature(stall, Vector2(2.6, 1.2), Color(0.7, 0.25, 0.2))

	# Barriles junto a la forja
	var barrel := CylinderMesh.new()
	barrel.top_radius = 0.32
	barrel.bottom_radius = 0.32
	barrel.height = 0.8
	barrel.radial_segments = 7
	barrel.rings = 1
	for pos: Vector3 in [Vector3(9.9, 0.4, 4.6), Vector3(9.2, 0.4, 4.9), Vector3(9.6, 1.2, 4.75)]:
		_mesh(self, barrel, pos, wood)
	_solid(Vector3(1.4, 1.2, 0.8), Vector3(9.55, 0.6, 4.75))

	# Carro con heno junto a la puerta sur
	var cart := Vector3(5.0, 0, 13.5)
	_box(self, Vector3(1.6, 0.4, 2.6), cart + Vector3(0, 0.7, 0), wood)
	_box(self, Vector3(1.4, 0.6, 2.2), cart + Vector3(0, 1.15, 0), thatch)
	var wheel := CylinderMesh.new()
	wheel.top_radius = 0.5
	wheel.bottom_radius = 0.5
	wheel.height = 0.12
	wheel.radial_segments = 8
	wheel.rings = 1
	for sx: float in [-0.88, 0.88]:
		_mesh(self, wheel, cart + Vector3(sx, 0.5, 0.3), wood, Vector3(0, 0, PI / 2))
	_box(self, Vector3(0.1, 0.1, 2.0), cart + Vector3(0, 0.6, -2.0), wood)
	_solid(Vector3(1.8, 1.5, 2.6), cart + Vector3(0, 0.75, 0))
	_feature(cart, Vector2(1.6, 2.6), Color(0.6, 0.5, 0.25))

	# Balas de heno
	var bale := CylinderMesh.new()
	bale.top_radius = 0.55
	bale.bottom_radius = 0.55
	bale.height = 1.0
	bale.radial_segments = 8
	bale.rings = 1
	for pos: Vector3 in [Vector3(-15.5, 0.55, 9.5), Vector3(-14.4, 0.55, 10.2), Vector3(16.0, 0.55, 1.5)]:
		_mesh(self, bale, pos, thatch, Vector3(0, 0, PI / 2))
		_solid(Vector3(1.0, 1.1, 1.1), pos)


func _build_trees() -> void:
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.14
	trunk_mesh.bottom_radius = 0.22
	trunk_mesh.height = 1.4
	trunk_mesh.radial_segments = 5
	trunk_mesh.rings = 1
	var trunk_mat := PS1Assets.material("wood", Color(0.6, 0.45, 0.35), Vector2(1, 1))
	var leaves := [
		PS1Assets.flat(Color(0.16, 0.32, 0.14)),
		PS1Assets.flat(Color(0.22, 0.38, 0.16)),
		PS1Assets.flat(Color(0.28, 0.40, 0.15)),
	]
	var spots := [
		Vector2(-16, -7), Vector2(-15.5, 0), Vector2(-16, 12.5), Vector2(-12, 16), Vector2(-4.5, 15.5),
		Vector2(6.5, 16.0), Vector2(10, 15.5), Vector2(16, 15), Vector2(16.2, 7), Vector2(16, -4),
		Vector2(16, -8.5), Vector2(5, -15), Vector2(-5, -15), Vector2(-8.5, -16.2),
		Vector2(-16.5, -16.5), Vector2(-5, 8), Vector2(5, 8.5), Vector2(-16.2, -3.5), Vector2(4.6, -6.6),
	]
	for spot: Vector2 in spots:
		var s := _rng.randf_range(0.85, 1.25)
		var base := Vector3(spot.x, 0, spot.y)
		var tree := Node3D.new()
		tree.position = base
		tree.scale = Vector3.ONE * s
		tree.rotation.y = _rng.randf() * TAU
		add_child(tree)
		_mesh(tree, trunk_mesh, Vector3(0, 0.7, 0), trunk_mat)
		var mat: Material = leaves[_rng.randi() % leaves.size()]
		for layer in 3:
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 1.25 - layer * 0.3
			cone.height = 1.5
			cone.radial_segments = 6
			cone.rings = 1
			_mesh(tree, cone, Vector3(0, 1.7 + layer * 0.75, 0), mat)
		_cylinder_solid(0.3 * s, 2.0, base + Vector3(0, 1.0, 0))
		map_features.append({"pos": spot, "size": Vector2(1.6, 1.6) * s, "rot": 0.0,
			"color": Color(0.15, 0.3, 0.12), "round": true})


## Muros invisibles en el borde de la peana: Henry no puede caerse de la maqueta.
func _build_bounds() -> void:
	var t := 1.0
	var span := WORLD_HALF * 2 + 2
	_solid(Vector3(span, 12, t), Vector3(0, 3, -WORLD_HALF - t * 0.5))
	_solid(Vector3(span, 12, t), Vector3(0, 3, WORLD_HALF + t * 0.5))
	_solid(Vector3(t, 12, span), Vector3(-WORLD_HALF - t * 0.5, 3, 0))
	_solid(Vector3(t, 12, span), Vector3(WORLD_HALF + t * 0.5, 3, 0))


# --- Personajes y cámaras -------------------------------------------------------

func _build_villagers() -> void:
	_villager("Martin", Vector3(8.6, 0, 3.4), PI / 2, {
		"model": "res://assets/characters/Character_02.fbx", "outfit": "herrero", "body_scale": 1.04,
		"weapon": "hammer",
	}, {"shop": "herreria", "profession": "herrero", "talk_until_stage": 0}, [
		"¡Henry! Por fin apareces. ¿Dónde te habías metido?",
		"Esa espada que llevas la forjé yo. A ver si sabes usarla.",
		"Ve al muñeco de paja de ahí al lado y dale unos buenos tajos.",
		"Clic izquierdo para golpear, clic derecho para cubrirte. Si te cubres justo a tiempo, desarmas al rival.",
	])
	_villager("Theresa", Vector3(-2.4, 0, 2.6), PI * 0.85, {
		"tunic_color": Color(0.30, 0.38, 0.55), "sleeve_color": Color(0.85, 0.80, 0.68),
		"hair_color": Color(0.55, 0.32, 0.14), "pants_color": Color(0.30, 0.38, 0.55),
		"body_scale": 0.94,
	}, {}, [
		"Buenos días, Henry. Qué mañana tan tranquila, ¿verdad?",
		"Dicen que por el camino del sur se han visto columnas de humo.",
		"Seguro que no es nada... seguro.",
	])
	_villager("Padre Ondřej", Vector3(1.9, 0, -5.2), PI, {
		"model": "res://assets/characters/Character_03.fbx", "outfit": "cura",
	}, {"profession": "clero"}, [
		"Que Dios te guarde, hijo.",
		"Esta iglesia lleva en pie más de cien años.",
		"Rezo para que siga así otros cien.",
	])
	_villager("Guardia", Vector3(2.7, 0, 15.3), 0.0, {
		"model": "res://assets/characters/Character_04.fbx", "outfit": "guardia", "body_scale": 1.03,
		"weapon": "sword",
	}, {"profession": "guardia"}, [
		"Alto ahí, muchacho. ¿Pensabas salir del pueblo?",
		"Hay rumores de bandidos merodeando por los caminos.",
		"Espera... ¿oyes eso? ¡Cascos de caballo! ¡Están aquí! ¡Coge tu espada!",
	])
	_villager("Kuneš", Vector3(-9.7, 0, 4.4), -PI / 2, {
		"model": "res://assets/characters/Character_05.fbx", "outfit": "campesino",
	}, {"profession": "campesino"}, [
		"¿Qué miras, chaval? ¿Nunca has visto a un hombre descansar?",
		"Si ves a mi mujer, yo no estoy aquí.",
	])
	_villager("Ludmila", Vector3(-5.9, 0, -2.0), PI / 2, {
		"tunic_color": Color(0.55, 0.2, 0.25), "sleeve_color": Color(0.9, 0.85, 0.72),
		"hair_color": Color(0.3, 0.18, 0.1), "pants_color": Color(0.55, 0.2, 0.25),
		"has_hood": true, "body_scale": 0.92,
	}, {"shop": "mercado", "profession": "comerciante"}, ["¡Pan, huevos, cerveza! ¡Lo mejor de Skalitz!"])
	_villager("Pešek", _on_ground(34.6, -7.5), PI / 2, {
		"model": "res://assets/characters/Character_02.fbx", "outfit": "molinero",
	}, {"shop": "molino", "profession": "molinero"}, ["El molino nunca descansa."])
	_villager("Radovan", _on_ground(-29.8, -1.2), -PI / 2, {
		"model": "res://assets/characters/Character_05.fbx", "outfit": "minero", "weapon": "hammer",
	}, {"profession": "minero"}, [
		"Esta mina ha hecho rico a más de un señor... y a ningún minero.",
		"Si tienes brazos, pica en las vetas de ahí fuera. La plata se paga bien en la herrería.",
	])
	_villager("Mikuláš", _on_ground(40.6, 13.2), -PI / 2, {
		"model": "res://assets/characters/Character_03.fbx", "outfit": "pastor",
	}, {"profession": "pastor"}, [
		"Cuidado con mis ovejas, muchacho. Cada una vale su peso en lana.",
		"Por las noches bajan lobos del bosque del noroeste.",
	])
	_villager("Guardia del castillo", _on_ground(0, -29.5), 0.0, {
		"model": "res://assets/characters/Character_04.fbx", "outfit": "guardia", "weapon": "sword",
	}, {"profession": "guardia"}, [
		"El castillo de Sir Radzig Kobyla. Aquí se pagan los impuestos del pueblo.",
		"Sin permiso no se entra, muchacho.",
	])


func _on_ground(x: float, z: float) -> Vector3:
	return Vector3(x, Countryside.height(x, z), z)


func _villager(display_name: String, pos: Vector3, rot_y: float, look: Dictionary,
		role: Dictionary, lines: Array) -> void:
	var v := Villager.new()
	v.shop = role.get("shop", "")
	v.profession = role.get("profession", "")
	v.talk_until_stage = role.get("talk_until_stage", -1)
	v.name = display_name.replace(" ", "_")
	v.display_name = display_name
	v.lines = PackedStringArray(lines)
	v.appearance = look
	v.position = pos
	v.rotation.y = rot_y
	add_child(v)


## Zonas con nombre (el HUD lo muestra al entrar).
func _build_location_zones() -> void:
	add_location("LA IGLESIA", Vector3(0, 0, -11.75), Vector3(36.4, 4, 12.9))
	add_location("LA PLAZA", Vector3(0, 0, 0.2), Vector3(16, 4, 11.6))
	add_location("BARRIO OESTE", Vector3(-12.95, 0, 6.3), Vector3(10.5, 4, 23.8))
	add_location("LA FORJA", Vector3(12.95, 0, 6.3), Vector3(10.5, 4, 23.8))
	add_location("PUERTA SUR", Vector3(0, 0, 11.95), Vector3(16, 4, 12.5))


func add_location(zone_name: String, center: Vector3, size: Vector3) -> void:
	var zone := LocationZone.new()
	zone.name = "Zone_" + zone_name.replace(" ", "_").replace("Í", "I")
	zone.zone_name = zone_name
	zone.size = size
	zone.position = center
	add_child(zone)


## Muñeco de paja junto a la forja.
func _build_training_ground() -> void:
	var dummy := TrainingDummy.new()
	dummy.name = "TrainingDummy"
	dummy.position = Vector3(6.4, 0, 6.6)
	add_child(dummy)
	map_features.append({"pos": Vector2(6.4, 6.6), "size": Vector2(0.8, 0.8), "rot": 0.0,
		"color": Color(0.85, 0.75, 0.35), "round": true})


## Animales: [especie, centro de su zona, radio, cantidad].
func _build_animals() -> void:
	var herds := [
		["gallina", Vector2(-2, 9), 4.0, 6], ["perro", Vector2(4, 5), 5.0, 1],
		["cerdo", Vector2(-14, 33.5), 1.6, 4], ["gallina", Vector2(-21, 32), 3.5, 4],
		["oveja", Vector2(43, 14), 3.5, 7], ["vaca", Vector2(43, 25), 3.0, 4], ["perro", Vector2(41, 11), 3.0, 1],
		["conejo", Vector2(24, -10), 5.0, 3], ["conejo", Vector2(24, 10), 5.0, 3],
		["ciervo", Vector2(32, -34), 8.0, 5], ["lobo", Vector2(-36, -40), 5.0, 3],
	]
	for herd: Array in herds:
		for i in herd[3]:
			var a := _rng.randf() * TAU
			var c: Vector2 = herd[1] + Vector2(cos(a), sin(a)) * _rng.randf() * herd[2] * 0.8
			var animal := Animal.new()
			animal.species = herd[0]
			animal.home_radius = herd[2]
			animal.position = Vector3(c.x, Countryside.height(c.x, c.y) + 0.3, c.y)
			animal.rotation.y = _rng.randf() * TAU
			add_child(animal)


# --- Utilidades ----------------------------------------------------------------

func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot_y := 0.0) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	return _mesh(parent, box, pos, mat, Vector3(0, rot_y, 0))


## Plano subdividido: con mapeado afín, los polígonos grandes se deforman
## demasiado, así que (como en la PS1) se trocean en polígonos pequeños.
func _plane(size: Vector2, pos: Vector3, mat: Material, subdivisions: int) -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = size
	plane.subdivide_width = subdivisions
	plane.subdivide_depth = subdivisions
	return _mesh(self, plane, pos, mat)


func _solid(size: Vector3, pos: Vector3, rot_y := 0.0) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation.y = rot_y
	var shape := BoxShape3D.new()
	shape.size = size
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	add_child(body)


func _cylinder_solid(radius: float, height: float, pos: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	add_child(body)


func _feature(pos: Vector3, size: Vector2, color: Color, rot_y := 0.0) -> void:
	map_features.append({"pos": Vector2(pos.x, pos.z), "size": size, "rot": rot_y, "color": color})
