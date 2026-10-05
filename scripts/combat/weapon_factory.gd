class_name WeaponFactory
extends RefCounted
## Armas low-poly. El origen es el centro de la empuñadura y la hoja/mango
## apunta a +Y. Las espadas y la daga son mallas propias (_sword) con colores
## por vértice: hoja de sección romboidal con filos biselados, acanaladura y
## punta; guarda con gavilanes caídos; puño forrado; pomo de rueda o de bola.
## El resto de armas siguen hechas con cajas.

const STEEL := Color(0.72, 0.74, 0.78)
const DARK_STEEL := Color(0.42, 0.44, 0.48)
const WOOD := Color(0.42, 0.28, 0.16)
const LEATHER := Color(0.30, 0.18, 0.10)
const BRASS := Color(0.75, 0.58, 0.25)

## Medidas de cada espada (metros). Hoja: largo, ancho en la base y antes de la
## punta, grosor, largo de la punta y hasta dónde llega la acanaladura (0..1).
const SWORDS := {
	"arming": { # Espada de Martin: de armas, sencilla, guarda de latón.
		"blade_len": 0.78, "blade_w": 0.06, "blade_w_tip": 0.04, "thick": 0.013, "tip_len": 0.11,
		"fuller": 0.72, "guard_w": 0.23, "guard_t": 0.026, "guard_droop": 0.018,
		"grip_len": 0.16, "grip_r": 0.0165, "pommel": "wheel", "pommel_r": 0.032,
		"edge": Color(0.92, 0.94, 0.97), "flat": Color(0.68, 0.71, 0.76), "groove": Color(0.4, 0.42, 0.47),
		"guard": BRASS, "guard_dark": Color(0.52, 0.38, 0.15), "grip": LEATHER,
		"grip_light": Color(0.46, 0.3, 0.17), "pommel_col": BRASS,
	},
	"steel": { # Espada de acero: más larga y estrecha, guarda recta de hierro.
		"blade_len": 0.9, "blade_w": 0.056, "blade_w_tip": 0.034, "thick": 0.014, "tip_len": 0.14,
		"fuller": 0.6, "guard_w": 0.27, "guard_t": 0.024, "guard_droop": 0.004,
		"grip_len": 0.2, "grip_r": 0.016, "pommel": "pear", "pommel_r": 0.03,
		"edge": Color(0.95, 0.96, 0.99), "flat": Color(0.74, 0.77, 0.82), "groove": Color(0.45, 0.48, 0.53),
		"guard": DARK_STEEL, "guard_dark": Color(0.26, 0.27, 0.3), "grip": Color(0.16, 0.09, 0.05),
		"grip_light": Color(0.3, 0.18, 0.1), "pommel_col": DARK_STEEL,
	},
	"dagger": { # Daga: hoja corta y ancha, sin acanaladura, gavilanes cortos.
		"blade_len": 0.24, "blade_w": 0.042, "blade_w_tip": 0.03, "thick": 0.011, "tip_len": 0.07,
		"fuller": 0.0, "guard_w": 0.11, "guard_t": 0.02, "guard_droop": 0.01,
		"grip_len": 0.1, "grip_r": 0.014, "pommel": "wheel", "pommel_r": 0.022,
		"edge": Color(0.92, 0.94, 0.97), "flat": Color(0.66, 0.69, 0.74), "groove": Color(0.66, 0.69, 0.74),
		"guard": BRASS, "guard_dark": Color(0.52, 0.38, 0.15), "grip": LEATHER,
		"grip_light": Color(0.46, 0.3, 0.17), "pommel_col": BRASS,
	},
}


static func build(kind: String) -> Node3D:
	var root := Node3D.new()
	root.name = kind.capitalize()
	match kind:
		"sword":
			_sword(root, SWORDS["arming"])
		"axe":
			_part(root, Vector3(0.04, 0.75, 0.04), Vector3(0, 0.25, 0), WOOD)
			_part(root, Vector3(0.05, 0.2, 0.025), Vector3(0.07, 0.55, 0), DARK_STEEL)
			_part(root, Vector3(0.05, 0.26, 0.02), Vector3(0.12, 0.55, 0), STEEL)
		"hammer":
			_part(root, Vector3(0.04, 0.55, 0.04), Vector3(0, 0.18, 0), WOOD)
			_part(root, Vector3(0.2, 0.09, 0.09), Vector3(0, 0.45, 0), DARK_STEEL)
		"sword_steel":
			_sword(root, SWORDS["steel"])
		"mace":
			_part(root, Vector3(0.04, 0.58, 0.04), Vector3(0, 0.19, 0), WOOD)
			_part(root, Vector3(0.05, 0.08, 0.05), Vector3(0, -0.08, 0), LEATHER)
			_part(root, Vector3(0.13, 0.15, 0.13), Vector3(0, 0.52, 0), DARK_STEEL)
			for a in 4:
				var flange := _part(root, Vector3(0.03, 0.15, 0.09), Vector3(0, 0.52, 0), STEEL)
				flange.rotation.y = a * PI / 4
				flange.position += Vector3(cos(a * PI / 4), 0, sin(a * PI / 4)) * 0.0
		"spear":
			_part(root, Vector3(0.035, 1.7, 0.035), Vector3(0, 0.45, 0), WOOD)
			_part(root, Vector3(0.05, 0.06, 0.05), Vector3(0, 1.3, 0), DARK_STEEL)
			var head := PrismMesh.new()
			head.size = Vector3(0.07, 0.24, 0.015)
			_mesh(root, head, Vector3(0, 1.45, 0), STEEL)
		"dagger":
			_sword(root, SWORDS["dagger"])
		"shield":
			# Escudo redondo de tablas con umbo de hierro; origen en el asa, mira a +Z.
			for i in 5:
				_part(root, Vector3(0.11, 0.56 - absf(i - 2) * 0.09, 0.03), Vector3(-0.22 + i * 0.11, 0, 0),
					WOOD.lightened(0.08 * (i % 2)))
			_part(root, Vector3(0.56, 0.04, 0.035), Vector3(0, 0.2, 0.002), DARK_STEEL)
			_part(root, Vector3(0.56, 0.04, 0.035), Vector3(0, -0.2, 0.002), DARK_STEEL)
			_part(root, Vector3(0.12, 0.12, 0.06), Vector3(0, 0, 0.03), STEEL)
			_part(root, Vector3(0.2, 0.2, 0.01), Vector3(0, 0, 0.02), Color(0.7, 0.14, 0.1))
	return root


# --- Mano en primera persona ------------------------------------------------------

## Puño de Henry cerrado sobre la empuñadura (origen = centro del puño, el arma
## sale hacia +Y) con el antebrazo hacia atrás: muñequera de cuero y manga de
## gambesón. Mallas propias con facetas planas.
static func build_hand() -> Node3D:
	var root := Node3D.new()
	root.name = "Hand"
	var skin := Color(0.86, 0.64, 0.5)
	var skin_dark := Color(0.66, 0.46, 0.36)
	var leather := Color(0.36, 0.22, 0.12)
	var cloth := Color(0.8, 0.74, 0.6)
	var cloth_dark := Color(0.6, 0.54, 0.42)
	# Puño: prisma octogonal achatado alrededor del puño del arma, con los
	# nudillos (lado +Z) más marcados.
	var rings: Array = []
	var colors: Array = []
	for p: Array in [[-0.052, 0.78], [-0.04, 1.0], [0.04, 1.0], [0.052, 0.8]]:
		var ring := PackedVector3Array()
		var cols := []
		for i in 8:
			var a := TAU * (i + 0.5) / 8.0
			var knuckle := 1.12 if sin(a) > 0.3 else 1.0
			ring.append(Vector3(cos(a) * 0.042 * p[1], p[0], sin(a) * 0.046 * p[1] * knuckle + 0.006))
			cols.append(skin if sin(a) > -0.4 else skin_dark)
		rings.append(ring)
		colors.append(cols)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_loft(st, rings, colors)
	_cap(st, rings[0], colors[0], Vector3(0, -0.06, 0.006))
	_cap(st, rings.back(), colors.back(), Vector3(0, 0.06, 0.006))
	_add_piece(root, _commit(st), "Fist")
	# Antebrazo: de la muñeca al codo, hacia atrás y abajo.
	var wrist := Vector3(0.0, -0.045, 0.03)
	var elbow := Vector3(0.03, -0.2, 0.36)
	var dir := (elbow - wrist).normalized()
	var side := dir.cross(Vector3.RIGHT).normalized()
	var up := side.cross(dir).normalized()
	rings = []
	colors = []
	# [posición 0..1 a lo largo, radio, color, color sombra]
	for p: Array in [[0.0, 0.034, skin, skin_dark], [0.06, 0.04, leather, leather.darkened(0.3)],
			[0.3, 0.043, leather, leather.darkened(0.3)], [0.36, 0.05, cloth, cloth_dark],
			[1.0, 0.058, cloth, cloth_dark]]:
		var c := wrist.lerp(elbow, p[0])
		var ring := PackedVector3Array()
		var cols := []
		for i in 6:
			var a := TAU * i / 6.0
			ring.append(c + (side * cos(a) + up * sin(a)) * p[1])
			cols.append(p[2] if sin(a) > -0.3 else p[3])
		rings.append(ring)
		colors.append(cols)
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_loft(st, rings, colors, dir, wrist)
	_cap(st, rings.back(), colors.back(), elbow + dir * 0.02)
	_add_piece(root, _commit(st), "Forearm")
	return root


# --- Espadas ---------------------------------------------------------------------

## Cada pieza es una malla aparte: el arma en primera persona se dibuja sin
## test de profundidad y Godot ordena las piezas de atrás adelante.
static func _sword(root: Node3D, d: Dictionary) -> void:
	var guard_y: float = d.grip_len * 0.5 + d.guard_t * 0.5
	var blade_y: float = guard_y + d.guard_t * 0.5
	_add_piece(root, _blade_mesh(d, blade_y), "Blade")
	_add_piece(root, _guard_mesh(d, guard_y), "Guard")
	_add_piece(root, _grip_mesh(d), "Grip")
	_add_piece(root, _pommel_mesh(d, -d.grip_len * 0.5), "Pommel")


## Hoja: sección de 10 puntos (filo, bisel, acanaladura, acanaladura, bisel,
## filo, y lo mismo por detrás). La acanaladura se hunde y se oscurece, y se
## cierra antes de la punta; los filos son más claros (afilados).
static func _blade_mesh(d: Dictionary, y0: float) -> ArrayMesh:
	var len_: float = d.blade_len
	var t: float = d.thick
	# [altura relativa 0..1 del tramo recto, ancho, ¿acanaladura abierta?]
	var stations := [[0.0, d.blade_w, true], [0.35, lerpf(d.blade_w, d.blade_w_tip, 0.4), true],
		[d.fuller, lerpf(d.blade_w, d.blade_w_tip, d.fuller * 0.9), true],
		[minf(d.fuller + 0.08, 0.98), lerpf(d.blade_w, d.blade_w_tip, 0.85), false], [1.0, d.blade_w_tip, false]]
	if d.fuller <= 0.0:
		stations = [[0.0, d.blade_w, false], [0.6, lerpf(d.blade_w, d.blade_w_tip, 0.6), false],
			[1.0, d.blade_w_tip, false]]
	var straight: float = len_ - d.tip_len
	var rings: Array = []
	var colors: Array = []
	for st: Array in stations:
		var y: float = y0 + st[0] * straight
		var w: float = st[1] * 0.5
		var open: bool = st[2]
		var groove_z := t * (0.18 if open else 0.5)
		var gc: Color = d.groove if open else d.flat
		var pts := PackedVector3Array([
			Vector3(-w, y, 0), Vector3(-w * 0.55, y, t * 0.5), Vector3(-w * 0.16, y, groove_z),
			Vector3(w * 0.16, y, groove_z), Vector3(w * 0.55, y, t * 0.5), Vector3(w, y, 0),
			Vector3(w * 0.55, y, -t * 0.5), Vector3(w * 0.16, y, -groove_z), Vector3(-w * 0.16, y, -groove_z),
			Vector3(-w * 0.55, y, -t * 0.5)])
		rings.append(pts)
		colors.append([d.edge, d.flat, gc, gc, d.flat, d.edge, d.flat, gc, gc, d.flat])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_loft(st, rings, colors)
	_cap(st, rings[0], colors[0], Vector3(0, y0 - 0.01, 0))
	# Punta: el filo sigue hasta el extremo; las caras se cierran en un punto.
	_cap(st, rings.back(), colors.back(), Vector3(0, y0 + len_, 0), d.edge)
	return _commit(st)


## Guarda: barra octogonal a lo largo de X, más gruesa en el centro (con una
## pequeña lengüeta sobre la hoja) y con los extremos ensanchados y caídos
## hacia la hoja.
static func _guard_mesh(d: Dictionary, y: float) -> ArrayMesh:
	var hw: float = d.guard_w * 0.5
	var t: float = d.guard_t
	var droop: float = d.guard_droop
	# [x relativa -1..1, alto (Y), fondo (Z), subida hacia la hoja]
	var prof := [[-1.0, 0.8, 0.9, 1.0], [-0.92, 1.05, 1.05, 0.85], [-0.75, 0.62, 0.8, 0.45],
		[-0.22, 0.8, 1.0, 0.0], [-0.12, 1.25, 1.35, 0.0], [0.12, 1.25, 1.35, 0.0], [0.22, 0.8, 1.0, 0.0],
		[0.75, 0.62, 0.8, 0.45], [0.92, 1.05, 1.05, 0.85], [1.0, 0.8, 0.9, 1.0]]
	var rings: Array = []
	var colors: Array = []
	for p: Array in prof:
		var x: float = p[0] * hw
		var hy: float = t * 0.5 * p[1]
		var hz: float = t * 0.5 * p[2]
		var cy: float = y + droop * p[3]
		var ring := PackedVector3Array()
		var cols := []
		for i in 8:
			var a := TAU * (i + 0.5) / 8.0
			ring.append(Vector3(x, cy + sin(a) * hy, cos(a) * hz))
			cols.append(d.guard if sin(a) > -0.2 else d.guard_dark)
		rings.append(ring)
		colors.append(cols)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_loft(st, rings, colors, Vector3.RIGHT, Vector3(0, y, 0))
	_cap(st, rings[0], colors[0], Vector3(-hw - t * 0.25, y + droop, 0))
	_cap(st, rings.back(), colors.back(), Vector3(hw + t * 0.25, y + droop, 0))
	return _commit(st)


## Puño: hexagonal, algo más grueso en el centro, con anillos de color alterno
## que imitan el cordón de cuero enrollado y una virola en cada extremo.
static func _grip_mesh(d: Dictionary) -> ArrayMesh:
	var hl: float = d.grip_len * 0.5
	var r: float = d.grip_r
	var n := 9
	var rings: Array = []
	var colors: Array = []
	for i in n:
		var f := float(i) / (n - 1)
		var y := lerpf(-hl, hl, f)
		var swell := 1.0 + 0.12 * sin(f * PI)
		var ferrule := i == 0 or i == n - 1
		var rr := r * (1.15 if ferrule else swell)
		var ring := PackedVector3Array()
		var cols := []
		for k in 6:
			var a := TAU * k / 6.0 + (0.5 if i % 2 == 1 else 0.0) # giro alterno: aspecto de cordón
			ring.append(Vector3(cos(a) * rr, y, sin(a) * rr))
			if ferrule:
				cols.append(d.guard_dark)
			else:
				cols.append(d.grip_light if (i + k) % 2 == 0 else d.grip)
		rings.append(ring)
		colors.append(cols)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_loft(st, rings, colors)
	return _commit(st)


## Pomo: "wheel" = rueda achatada (eje Z) con remache; "pear" = pera de 8 lados.
static func _pommel_mesh(d: Dictionary, top_y: float) -> ArrayMesh:
	var r: float = d.pommel_r
	var col: Color = d.pommel_col
	var dark: Color = d.guard_dark
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if d.pommel == "wheel":
		var cy := top_y - r * 0.95
		var rings: Array = []
		var colors: Array = []
		# [z, radio]: cara biselada, canto, cara biselada.
		for p: Array in [[-0.42, 0.72], [-0.3, 1.0], [0.3, 1.0], [0.42, 0.72]]:
			var ring := PackedVector3Array()
			var cols := []
			for i in 8:
				var a := TAU * (i + 0.5) / 8.0
				ring.append(Vector3(cos(a) * r * p[1], cy + sin(a) * r * p[1], p[0] * r))
				cols.append(col if absf(p[0]) < 0.4 else dark)
			rings.append(ring)
			colors.append(cols)
		_loft(st, rings, colors, Vector3.BACK, Vector3(0, cy, 0))
		_cap(st, rings[0], colors[0], Vector3(0, cy, -0.5 * r), col)
		_cap(st, rings.back(), colors.back(), Vector3(0, cy, 0.5 * r), col)
	else:
		var rings: Array = []
		var colors: Array = []
		# [y relativa (hacia abajo), radio]
		for p: Array in [[0.0, 0.45], [-0.5, 0.95], [-1.25, 1.0], [-1.85, 0.6]]:
			var ring := PackedVector3Array()
			var cols := []
			for i in 8:
				var a := TAU * i / 8.0
				ring.append(Vector3(cos(a) * r * p[1], top_y + p[0] * r, sin(a) * r * p[1]))
				cols.append(col if i % 2 == 0 else dark)
			rings.append(ring)
			colors.append(cols)
		_loft(st, rings, colors)
		_cap(st, rings.back(), colors.back(), Vector3(0, top_y - 2.15 * r, 0), dark)
	return _commit(st)


## Une anillos consecutivos (mismo número de puntos) con caras planas.
## `axis`: eje largo de la pieza (Vector3.UP, RIGHT o BACK) para orientar las caras.
static func _loft(st: SurfaceTool, rings: Array, colors: Array, axis := Vector3.UP, axis_point := Vector3.ZERO) -> void:
	for r in rings.size() - 1:
		var a: PackedVector3Array = rings[r]
		var b: PackedVector3Array = rings[r + 1]
		var ca: Array = colors[r]
		var cb: Array = colors[r + 1]
		var n := a.size()
		for i in n:
			var j := (i + 1) % n
			var c := (a[i] + a[j] + b[i] + b[j]) * 0.25 - axis_point
			var out := c - axis * c.dot(axis) # hacia fuera del eje
			_tri(st, [a[i], a[j], b[j]], [ca[i], ca[j], cb[j]], out)
			_tri(st, [a[i], b[j], b[i]], [ca[i], cb[j], cb[i]], out)


## Cierra un anillo con un abanico hacia `apex` (que queda hacia fuera).
static func _cap(st: SurfaceTool, ring: PackedVector3Array, cols: Array, apex: Vector3,
		apex_color := Color(0, 0, 0, 0)) -> void:
	var centroid := Vector3.ZERO
	for v in ring:
		centroid += v
	centroid /= ring.size()
	var n := ring.size()
	for i in n:
		var j := (i + 1) % n
		var ac: Color = apex_color if apex_color.a > 0.0 else cols[i]
		var mid := (ring[i] + ring[j]) * 0.5
		var out := (apex - centroid).normalized() + (mid - centroid).normalized() * 0.3
		_tri(st, [ring[i], ring[j], apex], [cols[i], cols[j], ac], out)


## Triángulo orientado según `out`. Godot toma como cara delantera la de
## vértices en sentido horario.
static func _tri(st: SurfaceTool, p: Array, c: Array, out: Vector3) -> void:
	var n := (p[1] - p[0] as Vector3).cross(p[2] - p[0])
	var order := [0, 1, 2] if n.dot(out) < 0.0 else [0, 2, 1]
	# Normal de la cara para todos sus vértices: facetas planas, como en PS1.
	var face_n := n.normalized() * (1.0 if n.dot(out) >= 0.0 else -1.0)
	for k: int in order:
		st.set_normal(face_n)
		st.set_color(c[k])
		st.add_vertex(p[k])


static func _commit(st: SurfaceTool) -> ArrayMesh:
	return st.commit()


static func _add_piece(root: Node3D, mesh: ArrayMesh, piece_name: String) -> void:
	var mi := MeshInstance3D.new()
	mi.name = piece_name
	mi.mesh = mesh
	mi.material_override = PS1Assets.vertex_color_flat()
	root.add_child(mi)


## Convierte todas las piezas al material de "viewmodel" (siempre visible).
static func make_viewmodel(root: Node3D) -> void:
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mi.material_override == PS1Assets.vertex_color_flat():
			mi.material_override = PS1Assets.viewmodel_vertex_color()
		else:
			var src := mi.material_override as ShaderMaterial
			mi.material_override = PS1Assets.viewmodel(src.get_shader_parameter("albedo"))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func _part(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	PS1Assets.setup_box(mi, size, PS1Assets.flat(color))
	mi.position = pos
	parent.add_child(mi)
	return mi


static func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = PS1Assets.resolve(PS1Assets.flat(color))
	parent.add_child(mi)
	return mi
