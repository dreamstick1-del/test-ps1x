class_name VolumeFoliage
extends RefCounted
## Follaje con volumen, como los bloques de hojas de Minecraft pero con formas
## orgánicas: la copa es un racimo de "nubes" (esferoides deformados) y el pino
## una pila de conos caídos. Cada forma tiene dos capas:
##   - piel exterior con la textura de hojas/agujas y sus huecos transparentes
##   - capa interior más pequeña y oscura, que se ve a través de los huecos
## La textura se repite por la superficie (UV cilíndricas), así que las hojas
## mantienen su tamaño real por grande que sea la copa.

const LEAF_SIZE := 1.4 ## Metros que ocupa una repetición de la textura de hojas.
const NEEDLE_SIZE := 2.8 ## Ídem para las agujas (más grandes: se leen mejor de cerca).


## Copa de hoja ancha: 4 nubes solapadas alrededor de las ramas del tronco.
static func crown() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var blobs := [
		[Vector3(0.0, 3.1, 0.0), Vector3(1.9, 1.45, 1.9)],
		[Vector3(0.95, 2.6, 0.4), Vector3(1.25, 1.05, 1.25)],
		[Vector3(-0.8, 2.75, -0.7), Vector3(1.3, 1.05, 1.3)],
		[Vector3(0.15, 4.0, -0.25), Vector3(1.15, 0.95, 1.15)],
	]
	var i := 0
	for b: Array in blobs:
		_blob(st, b[0], b[1] * 0.72, Color(0.42, 0.45, 0.38), i * 17) # interior en sombra
		_blob(st, b[0], b[1], Color(1, 1, 1), i * 17)
		i += 1
	st.generate_normals()
	return st.commit()


## Pino: 6 pisos de conos que caen como faldas, del más ancho abajo al más
## estrecho arriba, más una punta.
static func pine() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tiers := 6
	for t in tiers:
		var f := float(t) / (tiers - 1)
		var y := 0.8 + t * 0.62
		var radius := lerpf(1.65, 0.45, f)
		var height := lerpf(1.05, 0.8, f)
		_cone(st, y, radius * 0.62, height * 0.85, Color(0.38, 0.42, 0.4), t * 5) # interior
		_cone(st, y, radius, height, Color(1, 1, 1), t * 5)
	_cone(st, 0.8 + tiers * 0.62, 0.3, 0.8, Color(1, 1, 1), 99)
	st.generate_normals()
	return st.commit()


## Esferoide de baja resolución deformado con "bultos" (forma de nube).
static func _blob(st: SurfaceTool, center: Vector3, radii: Vector3, color: Color, seed_value: int,
		segments := 10, rings := 6) -> void:
	var points := []
	for r in rings + 1:
		var row := []
		var phi := PI * r / rings
		for s in segments + 1:
			var theta := TAU * s / segments
			var dir := Vector3(sin(phi) * cos(theta), cos(phi), sin(phi) * sin(theta))
			var bump := 1.0 + 0.16 * sin(theta * 3.0 + seed_value) * sin(phi * 2.0 + seed_value * 0.7) \
				+ 0.08 * sin(theta * 5.0 - seed_value * 1.3)
			if r == 0 or r == rings:
				bump = 1.0
			var p := center + dir * radii * bump
			if r == rings:
				p.y = center.y - radii.y * 0.55 # Base algo aplanada, como una copa real.
			# UV cilíndricas en metros: la textura no se estira con el tamaño.
			var circumference := TAU * maxf(radii.x, radii.z)
			var uv := Vector2(float(s) / segments * circumference / LEAF_SIZE, -p.y / LEAF_SIZE)
			row.append([p, uv])
		points.append(row)
	for r in rings:
		for s in segments:
			_quad(st, points[r][s], points[r][s + 1], points[r + 1][s + 1], points[r + 1][s], color)


## Cono abierto por abajo, con el borde inferior ondulado y algo caído.
static func _cone(st: SurfaceTool, base_y: float, radius: float, height: float, color: Color,
		seed_value: int, segments := 10) -> void:
	var apex := Vector3(0, base_y + height, 0)
	var rim := []
	var mid := []
	for s in segments + 1:
		var theta := TAU * s / segments + seed_value
		var wobble := 1.0 + 0.12 * sin(theta * 4.0 + seed_value)
		var dir := Vector3(cos(theta), 0, sin(theta))
		var droop := -0.28 * absf(sin(theta * 2.0 + seed_value)) - 0.1
		var p_rim := dir * radius * wobble + Vector3(0, base_y + droop, 0)
		var p_mid := dir * radius * 0.55 * wobble + Vector3(0, base_y + height * 0.5, 0)
		var u := float(s) / segments * TAU * radius / NEEDLE_SIZE
		var v := height / NEEDLE_SIZE * 1.3
		rim.append([p_rim, Vector2(u, v)])
		mid.append([p_mid, Vector2(u * 0.55, v * 0.5)])
	for s in segments:
		_quad(st, mid[s], mid[s + 1], rim[s + 1], rim[s], color)
		_tri(st, [apex, Vector2((mid[s][1].x + mid[s + 1][1].x) * 0.5, 0.0)], mid[s + 1], mid[s], color)


static func _quad(st: SurfaceTool, a: Array, b: Array, c: Array, d: Array, color: Color) -> void:
	_tri(st, a, b, c, color)
	_tri(st, a, c, d, color)


static func _tri(st: SurfaceTool, a: Array, b: Array, c: Array, color: Color) -> void:
	for v: Array in [a, c, b]:
		st.set_color(color)
		st.set_uv(v[1])
		st.add_vertex(v[0])
