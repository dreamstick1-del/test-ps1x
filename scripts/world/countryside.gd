class_name Countryside
extends RefCounted
## Construye el campo alrededor de Skalitz (la maqueta mide 96x96 m):
##
##              BOSQUE NO (lobos)    CASTILLO (colina)       BOSQUE NE (ciervos)
##   MINA DE PLATA (colina)    [   SKALITZ   ]  campos de trigo | RÍO | pastos
##                             [ (amurallado)]       puente ---- | ~~~ | MOLINO
##   CARBONERAS      GRANJA (cerdos)    camino del sur
##
## El terreno es una malla con colinas, cauce del río y caminos aplanados;
## colorea los vértices (caminos, surcos, orillas) y genera su colisión.

const HALF := 48.0
const VILLAGE := 20.0
const STEP := 1.0

## Caminos: polilíneas (x, z). Se aplanan y se pintan de tierra.
const ROADS := [
	[Vector2(0, 17), Vector2(0, 26), Vector2(0, 48)],
	[Vector2(17, 0), Vector2(30, 0), Vector2(48, 0)],
	[Vector2(-17, 4.5), Vector2(-26, 2), Vector2(-33, -3)],
	[Vector2(9.5, -17), Vector2(6, -24), Vector2(0, -29)],
	[Vector2(0, 26), Vector2(-12, 28), Vector2(-20, 30)],
	[Vector2(-20, 30), Vector2(-32, 37)],
	[Vector2(30, 0), Vector2(36, -6), Vector2(36, -9)],
	[Vector2(36, 0), Vector2(40, 8), Vector2(40, 11)],
]
## Caminos que suben colinas: se pintan pero no se aplanan.
const CLIMBING_ROADS := [3]

const FIELDS := [Rect2(20, -17, 8, 13), Rect2(20, 4, 8, 12), Rect2(-31, 34, 12, 9)]
const PASTURE := Rect2(39, 4, 8, 28)
## Sendas de tierra dentro del pueblo.
const VILLAGE_PATHS := [Rect2(5.3, -0.5, 4.5, 3.0), Rect2(-11.0, 3.3, 5.6, 2.4), Rect2(-0.9, 5.5, 1.8, 0.6)]
## Suelo de bosque: (x, z, radio).
const FOREST_FLOORS := [Vector3(34, -36, 14), Vector3(-36, -38, 12), Vector3(-40, 26, 9), Vector3(18, 36, 10)]
const CASTLE := Vector2(0, -37)
const MINE_HILL := Vector2(-42, -6)

var w: DioramaWorld
var rng := RandomNumberGenerator.new()


func _init(world: DioramaWorld) -> void:
	w = world
	rng.seed = 1403


func build() -> void:
	_build_terrain()
	_build_water()
	_build_bridge()
	_build_mill()
	_build_fields()
	_build_pasture()
	_build_castle()
	_build_mine()
	_build_farm()
	_build_charcoal_camp()
	_build_forests()
	_build_map_lines()


# --- Altura del terreno --------------------------------------------------------

static func river_x(z: float) -> float:
	return 32.0 + 3.5 * sin(z * 0.07)


static func height(x: float, z: float) -> float:
	var h := 0.55 * sin(x * 0.11 + 1.3) * cos(z * 0.09 - 0.4) + 0.3 * sin(x * 0.23 + z * 0.17)
	h += 6.5 * clampf(_bump(x, z, CASTLE, 17.0) * 1.6, 0.0, 1.0)
	h += 8.0 * _ellipse_bump(x, z, MINE_HILL, Vector2(11, 18))
	h += 2.5 * _bump(x, z, Vector2(36, -38), 14.0)
	h += 1.5 * _bump(x, z, Vector2(-38, -40), 12.0)
	# El pueblo es llano (sus edificios están construidos a altura 0).
	var vx := absf(x) - VILLAGE
	var vz := absf(z) - VILLAGE
	var outside := clampf(maxf(vx, vz) / 5.0, 0.0, 1.0)
	h *= outside
	for i in ROADS.size():
		if i in CLIMBING_ROADS:
			continue
		var d := _dist_to_polyline(Vector2(x, z), ROADS[i])
		h *= lerpf(0.15, 1.0, smoothstep(1.8, 4.5, d))
	h *= 1.0 - smoothstep(43.0, 47.0, maxf(absf(x), absf(z)))
	var rd := absf(x - river_x(z))
	if rd < 4.2:
		h = lerpf(-1.4, h, smoothstep(2.3, 4.2, rd))
	return h


static func _bump(x: float, z: float, c: Vector2, r: float) -> float:
	var t := clampf(1.0 - Vector2(x, z).distance_to(c) / r, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


static func _ellipse_bump(x: float, z: float, c: Vector2, r: Vector2) -> float:
	var d := Vector2((x - c.x) / r.x, (z - c.y) / r.y).length()
	var t := clampf(1.0 - d, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


static func _dist_to_polyline(p: Vector2, pts: Array) -> float:
	var best := INF
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var t := clampf((p - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
		best = minf(best, p.distance_to(a + (b - a) * t))
	return best


static func road_distance(x: float, z: float) -> float:
	var best := INF
	for pts: Array in ROADS:
		best = minf(best, _dist_to_polyline(Vector2(x, z), pts))
	return best


func ground(x: float, z: float) -> Vector3:
	return Vector3(x, height(x, z), z)


# --- Terreno -------------------------------------------------------------------

func _build_terrain() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := int(HALF * 2 / STEP)
	for iz in n:
		for ix in n:
			var x0 := -HALF + ix * STEP
			var z0 := -HALF + iz * STEP
			var quad := [Vector2(x0, z0), Vector2(x0 + STEP, z0), Vector2(x0 + STEP, z0 + STEP), Vector2(x0, z0 + STEP)]
			for idx in [0, 1, 2, 0, 2, 3]:
				var p: Vector2 = quad[idx]
				var g := ground_sample(p.x, p.y)
				st.set_color(g.color)
				st.set_uv2(Vector2(g.mud, 0.0))
				st.add_vertex(Vector3(p.x, height(p.x, p.y), p.y))
	st.generate_normals()
	var mesh := st.commit()
	var mi := MeshInstance3D.new()
	mi.name = "Terrain"
	mi.mesh = mesh
	mi.material_override = PS1Assets.terrain()
	w.add_child(mi)

	var body := StaticBody3D.new()
	body.name = "TerrainCollision"
	var cs := CollisionShape3D.new()
	cs.shape = mesh.create_trimesh_shape()
	body.add_child(cs)
	w.add_child(body)

	# Faldón de tierra alrededor (el borde de la maqueta) hasta la peana.
	var dirt := PS1Assets.material("dirt", Color(0.85, 0.8, 0.8), Vector2(0.6, 0.6))
	for side: Array in [[Vector3(0, -0.8, HALF), Vector3(HALF * 2, 1.6, 0.1)], [Vector3(0, -0.8, -HALF), Vector3(HALF * 2, 1.6, 0.1)],
			[Vector3(HALF, -0.8, 0), Vector3(0.1, 1.6, HALF * 2)], [Vector3(-HALF, -0.8, 0), Vector3(0.1, 1.6, HALF * 2)]]:
		var box := BoxMesh.new()
		box.size = side[1]
		box.subdivide_width = 24
		box.subdivide_depth = 24
		w._mesh(w, box, side[0], dirt)


## Qué variante de pasto lleva cada punto del mapa (ver ps1_terrain.gdshader):
##   color.rgb = tinte (roca, arena, sombra del bosque, surcos)
##   color.a   = sequedad: 0 frondoso, 0.5 como la foto, 1 paja
##   mud       = 0 pasto, 1 tierra pisada (caminos, corrales, campos arados)
func ground_sample(x: float, z: float) -> Dictionary:
	var p := Vector2(x, z)
	var tint := Color(1, 1, 1)
	var dry := 0.3 + 0.18 * sin(x * 0.13 + 1.7) * cos(z * 0.11)
	var mud := 0.0
	var h := height(x, z)

	# Dentro del pueblo: huertos y patios bien regados, sendas pisadas.
	if absf(x) < 18.0 and absf(z) < 18.0:
		dry = 0.2
		for path: Rect2 in VILLAGE_PATHS:
			mud = maxf(mud, 1.0 - clampf(_rect_distance(p, path) / 1.2, 0.0, 1.0))
	# Colinas: más secas cuanto más altas; roca en las cumbres.
	if h > 1.5:
		dry = maxf(dry, clampf(0.55 + (h - 1.5) * 0.12, 0.0, 0.95))
	if h > 3.0:
		tint = tint.lerp(Color(0.9, 0.9, 0.85), clampf((h - 3.0) / 4.0, 0.0, 0.6))
	# Bosques: suelo en sombra con pinocha.
	for f: Vector3 in FOREST_FLOORS:
		var k := 1.0 - clampf(p.distance_to(Vector2(f.x, f.y)) / f.z, 0.0, 1.0)
		tint = tint.lerp(Color(0.72, 0.74, 0.68), k * 0.8)
		mud = maxf(mud, k * 0.3)
	# Campos de trigo: tierra arada con surcos y rastrojo seco alrededor.
	for f: Rect2 in FIELDS:
		var d := _rect_distance(p, f)
		if d < 3.0:
			dry = maxf(dry, 0.85 - d * 0.1)
		if f.grow(0.3).has_point(p):
			mud = 0.85
			tint = Color(1.05, 0.95, 0.85) if int(floor(x * 2.0)) % 2 == 0 else Color(0.85, 0.78, 0.7)
	# Granja: corral de cerdos embarrado y patio pisado.
	mud = maxf(mud, 1.0 - clampf(_rect_distance(p, Rect2(-17, 31, 6, 5)) / 1.0, 0.0, 1.0))
	if Rect2(-30, 22, 12, 14).has_point(p):
		mud = maxf(mud, 0.35)
	# Carboneras y mina: tierra negra y removida.
	var coal := 1.0 - clampf(p.distance_to(Vector2(-36, 40)) / 7.0, 0.0, 1.0)
	if coal > 0.0:
		mud = maxf(mud, coal)
		tint = tint.lerp(Color(0.55, 0.52, 0.5), coal)
	mud = maxf(mud, 1.0 - clampf(p.distance_to(Vector2(-29, -4)) / 6.0, 0.0, 1.0))
	# Orillas del río: hierba húmeda, luego arena y barro.
	var rd := absf(x - river_x(z))
	if rd < 6.5:
		dry = minf(dry, 0.1)
	if rd < 4.5:
		tint = tint.lerp(Color(1.25, 1.12, 0.85), 0.5)
		mud = maxf(mud, 0.5)
	# Pastos junto al río: verdes y jugosos; barro junto a la puerta y el abrevadero.
	if PASTURE.grow(1.0).has_point(p):
		dry = 0.0
		tint = Color(1, 1, 1)
		mud = 0.0
		mud = maxf(mud, 1.0 - clampf(p.distance_to(Vector2(40, 11)) / 3.0, 0.0, 1.0))
	# Caminos: tierra pisada en el centro que se funde con el pasto.
	var road := road_distance(x, z)
	mud = maxf(mud, 1.0 - smoothstep(1.2, 2.6, road))
	return {"color": Color(tint.r, tint.g, tint.b, clampf(dry, 0.0, 1.0)), "mud": clampf(mud, 0.0, 1.0)}


static func _rect_distance(p: Vector2, r: Rect2) -> float:
	var d := Vector2(maxf(maxf(r.position.x - p.x, 0.0), p.x - r.end.x), maxf(maxf(r.position.y - p.y, 0.0), p.y - r.end.y))
	return d.length()


# --- Río, puente y molino -----------------------------------------------------------

func _build_water() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var z := -HALF
	while z < HALF:
		var z2 := z + 2.0
		var a := Vector3(river_x(z) - 3.6, -0.6, z)
		var b := Vector3(river_x(z) + 3.6, -0.6, z)
		var c := Vector3(river_x(z2) + 3.6, -0.6, z2)
		var d := Vector3(river_x(z2) - 3.6, -0.6, z2)
		for v: Vector3 in [a, b, c, a, c, d]:
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
		z = z2
	var mi := MeshInstance3D.new()
	mi.name = "River"
	mi.mesh = st.commit()
	mi.material_override = PS1Assets.material("water", Color(0.9, 1.0, 1.1), Vector2(0.4, 0.4))
	w.add_child(mi)
	w.add_location("EL RÍO", Vector3(32, -2, 0), Vector3(9, 6, 96))


func _build_bridge() -> void:
	var wood := PS1Assets.material("wood", Color(0.85, 0.7, 0.55), Vector2(0.8, 0.8))
	var x := river_x(0.0)
	w._box(w, Vector3(11, 0.2, 3.0), Vector3(x, 0.02, 0), wood)
	w._solid(Vector3(11, 0.2, 3.0), Vector3(x, 0.02, 0))
	for sz: float in [-1.45, 1.45]:
		w._box(w, Vector3(11, 0.1, 0.1), Vector3(x, 0.95, sz), wood)
		w._solid(Vector3(11, 1.0, 0.1), Vector3(x, 0.6, sz))
		for i in 6:
			w._box(w, Vector3(0.12, 0.9, 0.12), Vector3(x - 5 + i * 2, 0.5, sz), wood)
	for i in 3:
		w._box(w, Vector3(0.3, 1.6, 0.3), Vector3(x - 2 + i * 2, -0.75, 0), wood)
	w.map_features.append({"pos": Vector2(x, 0), "size": Vector2(11, 3), "rot": 0.0, "color": Color(0.55, 0.4, 0.25)})


func _build_mill() -> void:
	var pos := ground(37.5, -10)
	w._house(pos, 5.0, 5.0, 3.4, -PI / 2, "thatch", Color(0.6, 0.45, 0.3))
	# Rueda hidráulica en la orilla, girando con la corriente.
	var wheel := Node3D.new()
	wheel.name = "MillWheel"
	wheel.position = Vector3(river_x(-10) + 2.6, 0.4, -10)
	w.add_child(wheel)
	var wood := PS1Assets.material("wood", Color(0.75, 0.6, 0.5), Vector2(1, 1))
	var hub := CylinderMesh.new()
	hub.top_radius = 0.3
	hub.bottom_radius = 0.3
	hub.height = 1.0
	hub.radial_segments = 6
	w._mesh(wheel, hub, Vector3.ZERO, wood, Vector3(0, 0, PI / 2))
	for i in 8:
		var a := i * TAU / 8.0
		var paddle := w._box(wheel, Vector3(0.9, 0.12, 0.7), Vector3(0, sin(a) * 1.5, cos(a) * 1.5), wood)
		paddle.rotation.x = -a
		var spoke := w._box(wheel, Vector3(0.1, 0.08, 1.5), Vector3(0, sin(a) * 0.75, cos(a) * 0.75), wood)
		spoke.rotation.x = -a
	w.spinners.append({"node": wheel, "speed": 0.9})
	for sack: Array in [["jutesack_closed", Vector2(34.4, -6.6), 0.3], ["jutesack_closed_alt", Vector2(35.2, -6.2), 1.2],
			["jutesack_open", Vector2(34.0, -5.6), 0.0], ["barrel_open", Vector2(36.4, -6.4), 0.0]]:
		Kit.place_solid(w, sack[0], ground(sack[1].x, sack[1].y), sack[2])
	w.add_location("MOLINO DEL RÍO", Vector3(37, -2, -10), Vector3(10, 10, 12))


# --- Campos y pastos ------------------------------------------------------------

func _build_fields() -> void:
	var stalk := BoxMesh.new()
	stalk.size = Vector3(0.05, 0.85, 0.05)
	for f: Rect2 in FIELDS:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = stalk
		var pts: Array[Transform3D] = []
		var x := f.position.x + 0.2
		while x < f.end.x:
			var z := f.position.y + 0.2
			while z < f.end.y:
				var px := x + rng.randf_range(-0.12, 0.12)
				var pz := z + rng.randf_range(-0.12, 0.12)
				var s := rng.randf_range(0.8, 1.15)
				var basis := Basis.from_euler(Vector3(rng.randf_range(-0.15, 0.15), rng.randf() * TAU, rng.randf_range(-0.15, 0.15))).scaled(Vector3(1, s, 1))
				pts.append(Transform3D(basis, Vector3(px, height(px, pz) + 0.4 * s, pz)))
				z += 0.4
			x += 0.5
		mm.instance_count = pts.size()
		for i in pts.size():
			mm.set_instance_transform(i, pts[i])
			mm.set_instance_color(i, Color(0.95, 0.78, 0.32).lerp(Color(0.8, 0.7, 0.25), rng.randf()))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = PS1Assets.vertex_colored("", Vector2.ONE, false)
		w.add_child(mmi)
		w.map_features.append({"pos": f.get_center(), "size": f.size, "rot": 0.0, "color": Color(0.75, 0.65, 0.3)})
	for bale: Array in [["haybale_wrapped", Vector2(29.0, -14.0), 1.5], ["haybale", Vector2(29.0, 8.0), 0.2],
			["haybale_wrapped_dry", Vector2(-17.5, 39.5), 0.8]]:
		Kit.place_solid(w, bale[0], ground(bale[1].x, bale[1].y), bale[2])
	w.add_location("CAMPOS DE TRIGO", Vector3(24, -2, 0), Vector3(9, 10, 40))
	w.add_location("CAMPOS DE TRIGO", Vector3(-25, -2, 38.5), Vector3(14, 10, 11))


func _build_pasture() -> void:
	_fence(PASTURE, [Vector2(39, 10), Vector2(39, 12)])
	var hut := ground(44, 35)
	w._house(hut, 3.5, 3.0, 2.4, PI, "thatch", Color(0.6, 0.45, 0.3))
	w.add_location("PASTOS", Vector3(43, -2, 18), Vector3(10, 10, 30))


## Valla de madera alrededor de un rectángulo, con huecos (puertas).
func _fence(rect: Rect2, gaps: Array) -> void:
	var wood := PS1Assets.material("wood", Color(0.8, 0.65, 0.5), Vector2(1, 1))
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for i in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		var length := a.distance_to(b)
		var steps := int(length / 2.0)
		for s in steps:
			var p0 := a.lerp(b, float(s) / steps)
			var p1 := a.lerp(b, float(s + 1) / steps)
			var mid := (p0 + p1) * 0.5
			var in_gap := false
			for g: Vector2 in gaps:
				if mid.distance_to(g) < 1.2:
					in_gap = true
			var h0 := height(p0.x, p0.y)
			w._box(w, Vector3(0.12, 1.1, 0.12), Vector3(p0.x, h0 + 0.55, p0.y), wood)
			if in_gap:
				continue
			var hm := height(mid.x, mid.y)
			var dir := (p1 - p0).normalized()
			var rot := atan2(-dir.y, dir.x)
			for rail_y: float in [0.45, 0.9]:
				w._box(w, Vector3(p0.distance_to(p1), 0.08, 0.06), Vector3(mid.x, hm + rail_y, mid.y), wood, rot)
			w._solid(Vector3(p0.distance_to(p1), 1.4, 0.2), Vector3(mid.x, hm + 0.7, mid.y), rot)


# --- Castillo -----------------------------------------------------------------

func _build_castle() -> void:
	var top := height(CASTLE.x, CASTLE.y)
	var stone := PS1Assets.material("stone", Color(0.85, 0.85, 0.82), Vector2(0.5, 0.5))
	var roof := PS1Assets.material("shingle", Color(0.6, 0.6, 0.75), Vector2(0.6, 0.6))
	var center := Vector3(CASTLE.x, top, CASTLE.y)
	# Torre del homenaje
	w._box(w, Vector3(5, 11, 5), center + Vector3(0, 5.5, -1), stone)
	w._solid(Vector3(5, 11, 5), center + Vector3(0, 5.5, -1))
	var spire := CylinderMesh.new()
	spire.top_radius = 0.0
	spire.bottom_radius = 3.9
	spire.height = 4.0
	spire.radial_segments = 4
	spire.rings = 1
	w._mesh(w, spire, center + Vector3(0, 13, -1), roof, Vector3(0, PI / 4, 0))
	for i in 4:
		var a := i * PI / 2
		w._box(w, Vector3(0.7, 1.2, 0.1), center + Vector3(sin(a) * 2.53, 8, -1 + cos(a) * 2.53), PS1Assets.flat(Color(0.06, 0.05, 0.05)), a)
	# Bandera de Sir Radzig
	w._box(w, Vector3(0.08, 2.0, 0.08), center + Vector3(0, 16, -1), PS1Assets.flat(Color(0.3, 0.2, 0.1)))
	w._box(w, Vector3(1.2, 0.7, 0.04), center + Vector3(0.6, 16.5, -1), PS1Assets.flat(Color(0.8, 0.12, 0.1)))
	w._box(w, Vector3(1.2, 0.2, 0.05), center + Vector3(0.6, 16.5, -1), PS1Assets.flat(Color(0.95, 0.9, 0.8)))
	# Muralla octogonal con puerta al sur
	var r := 6.0
	for i in 8:
		var a0 := i * TAU / 8.0 + PI / 8.0
		var a1 := (i + 1) * TAU / 8.0 + PI / 8.0
		var p0 := Vector2(sin(a0), cos(a0)) * r
		var p1 := Vector2(sin(a1), cos(a1)) * r
		var mid := (p0 + p1) * 0.5
		var gate := mid.y > r * 0.8
		var dir := (p1 - p0).normalized()
		var rot := atan2(-dir.y, dir.x)
		var seg_len := p0.distance_to(p1)
		var base := Vector3(CASTLE.x + mid.x, top, CASTLE.y + mid.y)
		if gate:
			for side: float in [-1.0, 1.0]:
				var post := base + Vector3(dir.x, 0, dir.y) * side * (seg_len * 0.5 - 0.6)
				w._box(w, Vector3(1.2, 4.0, 1.2), post + Vector3(0, 2.0, 0), stone)
				w._solid(Vector3(1.2, 4.0, 1.2), post + Vector3(0, 2.0, 0))
			w._box(w, Vector3(seg_len, 0.8, 1.0), base + Vector3(0, 3.6, 0), stone, rot)
			continue
		w._box(w, Vector3(seg_len + 0.4, 3.0, 0.9), base + Vector3(0, 1.5, 0), stone, rot)
		w._solid(Vector3(seg_len + 0.4, 3.0, 0.9), base + Vector3(0, 1.5, 0), rot)
	w.map_features.append({"pos": CASTLE, "size": Vector2(12, 12), "rot": 0.0, "color": Color(0.6, 0.6, 0.65), "round": true})
	w.add_location("CASTILLO DE SKALITZ", Vector3(0, -2, -38), Vector3(30, 20, 20))


# --- Mina de plata ------------------------------------------------------------

func _build_mine() -> void:
	var x := -32.5
	var z := -4.0
	var gy := height(x, z)
	var wood := PS1Assets.material("wood", Color(0.75, 0.6, 0.5), Vector2(1, 1))
	var dark := PS1Assets.flat(Color(0.02, 0.02, 0.02))
	# Boca de la mina (mira al este) con entibado de madera.
	w._box(w, Vector3(3.0, 3.0, 3.2), Vector3(x - 1.2, gy + 1.3, z), dark)
	w._solid(Vector3(3.0, 3.0, 3.2), Vector3(x - 1.4, gy + 1.3, z))
	for sz: float in [-1.4, 1.4]:
		w._box(w, Vector3(0.3, 2.8, 0.3), Vector3(x + 0.3, gy + 1.4, z + sz), wood)
	w._box(w, Vector3(0.35, 0.35, 3.4), Vector3(x + 0.3, gy + 2.85, z), wood)
	# Vías y vagoneta
	var iron := PS1Assets.flat(Color(0.3, 0.3, 0.32))
	for sz: float in [-0.45, 0.45]:
		w._box(w, Vector3(7, 0.06, 0.06), Vector3(x + 3.5, height(x + 3.5, z) + 0.05, z + sz), iron)
	var cart := Vector3(x + 4.5, height(x + 4.5, z), z)
	w._box(w, Vector3(1.2, 0.6, 0.9), cart + Vector3(0, 0.55, 0), wood)
	w._box(w, Vector3(1.0, 0.25, 0.7), cart + Vector3(0, 0.9, 0), PS1Assets.flat(Color(0.45, 0.45, 0.48)))
	w._solid(Vector3(1.2, 1.0, 0.9), cart + Vector3(0, 0.5, 0))
	# Escombrera
	var heap := CylinderMesh.new()
	heap.top_radius = 0.3
	heap.bottom_radius = 2.2
	heap.height = 1.4
	heap.radial_segments = 7
	heap.rings = 1
	var heap_pos := ground(x + 3, z + 5)
	w._mesh(w, heap, heap_pos + Vector3(0, 0.5, 0), PS1Assets.material("stone", Color(0.55, 0.52, 0.5), Vector2(1, 1)))
	w._cylinder_solid(1.8, 1.4, heap_pos + Vector3(0, 0.5, 0))
	# Vetas de plata que Henry puede picar.
	for spot: Vector2 in [Vector2(x + 1.5, z - 3.0), Vector2(x + 0.8, z + 3.2), Vector2(x - 0.5, z - 5.5)]:
		var node := ResourceNode.new()
		node.position = ground(spot.x, spot.y)
		w.add_child(node)
	w.map_features.append({"pos": Vector2(x - 1, z), "size": Vector2(3, 3.2), "rot": 0.0, "color": Color(0.1, 0.1, 0.1)})
	w.add_location("MINA DE PLATA", Vector3(-38, -2, -5), Vector3(20, 20, 30))


# --- Granja y carboneras ---------------------------------------------------------

func _build_farm() -> void:
	w._house(ground(-22, 28), 5.0, 4.0, 2.9, 0.0, "thatch", Color(0.6, 0.45, 0.3))
	w._house(ground(-28, 24), 6.0, 5.0, 3.6, PI / 2, "shingle", Color(0.55, 0.35, 0.3))
	_fence(Rect2(-17, 31, 6, 5), [Vector2(-14, 31)])
	Kit.place_solid(w, "hay_covered", ground(-25, 31), 0.3)
	for b: Array in [["haybale_wrapped", Vector2(-28.5, 34.5), 0.2], ["haybale_dry", Vector2(-26.8, 35.6), 1.1],
			["barrel", Vector2(-19.2, 26.2), 0.0], ["jutesack_closed_alt", Vector2(-20.1, 26.0), 0.5]]:
		Kit.place_solid(w, b[0], ground(b[1].x, b[1].y), b[2])
	w.add_location("GRANJA", Vector3(-22, -2, 31), Vector3(20, 10, 18))


func _build_charcoal_camp() -> void:
	var dirt := PS1Assets.material("dirt", Color(0.45, 0.4, 0.38), Vector2(1, 1))
	for spot: Vector2 in [Vector2(-36, 38), Vector2(-39, 42), Vector2(-33, 42)]:
		var p := ground(spot.x, spot.y)
		var dome := SphereMesh.new()
		dome.radius = 1.6
		dome.height = 2.0
		dome.radial_segments = 8
		dome.rings = 4
		w._mesh(w, dome, p, dirt)
		w._cylinder_solid(1.5, 1.6, p + Vector3(0, 0.4, 0))
		var smoke := CPUParticles3D.new()
		smoke.amount = 6
		smoke.lifetime = 3.0
		smoke.direction = Vector3.UP
		smoke.spread = 10.0
		smoke.gravity = Vector3(0.3, 0.6, 0)
		smoke.initial_velocity_min = 0.3
		smoke.initial_velocity_max = 0.6
		var puff := BoxMesh.new()
		puff.size = Vector3.ONE * 0.35
		smoke.mesh = puff
		smoke.material_override = PS1Assets.resolve(PS1Assets.flat(Color(0.45, 0.45, 0.48)))
		smoke.position = p + Vector3(0, 1.1, 0)
		w.add_child(smoke)
	var wood := PS1Assets.material("wood", Color.WHITE, Vector2(1, 1))
	for i in 4:
		var p := ground(-30.5, 37 + i * 0.5)
		w._box(w, Vector3(2.4, 0.4, 0.4), p + Vector3(0, 0.2 + (i % 2) * 0.35, 0), wood)
	w._solid(Vector3(2.4, 0.9, 2.0), ground(-30.5, 37.7) + Vector3(0, 0.45, 0))
	w.add_location("CARBONERAS", Vector3(-37, -2, 40), Vector3(20, 10, 16))


# --- Bosques ------------------------------------------------------------------

func _tree_spot_free(x: float, z: float) -> bool:
	if absf(x) < VILLAGE + 2.0 and absf(z) < VILLAGE + 2.0:
		return false
	if road_distance(x, z) < 3.2 or absf(x - river_x(z)) < 5.0:
		return false
	for f: Rect2 in FIELDS:
		if f.grow(1.5).has_point(Vector2(x, z)):
			return false
	if PASTURE.grow(1.5).has_point(Vector2(x, z)):
		return false
	if Vector2(x, z).distance_to(CASTLE) < 10.0 or Vector2(x, z).distance_to(Vector2(-32, -4)) < 8.0:
		return false
	if Rect2(-32, 20, 22, 18).has_point(Vector2(x, z)) or Rect2(-42, 34, 14, 12).has_point(Vector2(x, z)):
		return false
	if Vector2(x, z).distance_to(Vector2(37, -10)) < 6.0 or Vector2(x, z).distance_to(Vector2(44, 35)) < 4.0:
		return false
	return absf(x) < HALF - 1.5 and absf(z) < HALF - 1.5


func _build_forests() -> void:
	# [centro, radio, cantidad] de cada bosque, más árboles sueltos por todo el mapa.
	var forests := [
		[Vector2(34, -36), 13.0, 70], [Vector2(-36, -38), 11.0, 55], [Vector2(-40, 26), 8.0, 25],
		[Vector2(18, 36), 10.0, 30], [Vector2(-8, 40), 7.0, 14],
	]
	var spots: Array[Vector2] = []
	for f: Array in forests:
		for i in f[2] * 3:
			if spots.size() > 600:
				break
			var a := rng.randf() * TAU
			var r: float = sqrt(rng.randf()) * f[1]
			var p: Vector2 = f[0] + Vector2(cos(a), sin(a)) * r
			if _tree_spot_free(p.x, p.y) and _far_from(spots, p, 2.2):
				spots.append(p)
	for i in 70:
		var p := Vector2(rng.randf_range(-HALF, HALF), rng.randf_range(-HALF, HALF))
		if _tree_spot_free(p.x, p.y) and _far_from(spots, p, 3.0):
			spots.append(p)
	_plant(spots)
	w.add_location("BOSQUE", Vector3(34, -2, -36), Vector3(28, 20, 24))
	w.add_location("BOSQUE DE LOS LOBOS", Vector3(-36, -2, -40), Vector3(22, 20, 16))


func _far_from(spots: Array[Vector2], p: Vector2, d: float) -> bool:
	for s: Vector2 in spots:
		if s.distance_squared_to(p) < d * d:
			return false
	return true


## Árboles con MultiMesh (tronco + 3 conos): cientos de árboles en pocas llamadas.
func _plant(spots: Array[Vector2]) -> void:
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.14
	trunk.bottom_radius = 0.22
	trunk.height = 1.4
	trunk.radial_segments = 5
	trunk.rings = 1
	var layers: Array[MultiMesh] = []
	var trunk_mm := _multimesh(trunk, spots.size())
	for layer in 3:
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 1.25 - layer * 0.3
		cone.height = 1.5
		cone.radial_segments = 6
		cone.rings = 1
		layers.append(_multimesh(cone, spots.size()))
	var body := StaticBody3D.new()
	body.name = "ForestCollision"
	w.add_child(body)
	var greens := [Color(0.16, 0.32, 0.14), Color(0.22, 0.38, 0.16), Color(0.28, 0.40, 0.15), Color(0.13, 0.27, 0.15)]
	for i in spots.size():
		var p := spots[i]
		var s := rng.randf_range(0.9, 1.5)
		var base := Vector3(p.x, height(p.x, p.y) - 0.1, p.y)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s)
		trunk_mm.set_instance_transform(i, Transform3D(basis, base + Vector3(0, 0.7 * s, 0)))
		trunk_mm.set_instance_color(i, Color(0.6, 0.45, 0.35))
		var green: Color = greens[rng.randi() % greens.size()]
		for layer in 3:
			layers[layer].set_instance_transform(i, Transform3D(basis, base + Vector3(0, (1.7 + layer * 0.75) * s, 0)))
			layers[layer].set_instance_color(i, green)
		var cs := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = 0.28 * s
		shape.height = 2.0 * s
		cs.shape = shape
		cs.position = base + Vector3(0, s, 0)
		body.add_child(cs)
		w.map_features.append({"pos": p, "size": Vector2(1.6, 1.6) * s, "rot": 0.0,
			"color": Color(0.12, 0.26, 0.1), "round": true})
	var trunk_mi := MultiMeshInstance3D.new()
	trunk_mi.multimesh = trunk_mm
	trunk_mi.material_override = PS1Assets.vertex_colored("wood", Vector2(1, 1), false)
	w.add_child(trunk_mi)
	for mm: MultiMesh in layers:
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = PS1Assets.vertex_colored("", Vector2.ONE, false)
		w.add_child(mi)


func _multimesh(mesh: Mesh, count: int) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = count
	return mm


## Ríos y caminos para el minimapa.
func _build_map_lines() -> void:
	var river := PackedVector2Array()
	var z := -HALF
	while z <= HALF:
		river.append(Vector2(river_x(z), z))
		z += 4.0
	w.map_lines.append({"points": river, "color": Color(0.25, 0.4, 0.65), "width": 5.0})
	for pts: Array in ROADS:
		w.map_lines.append({"points": PackedVector2Array(pts), "color": Color(0.55, 0.42, 0.28), "width": 2.0})
