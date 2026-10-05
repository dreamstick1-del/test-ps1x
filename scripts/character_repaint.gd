class_name CharacterRepaint
extends RefCounted
## "Repintado medieval" automático para los personajes PSX (rig Mixamo).
##
## Rasteriza cada triángulo de la malla en su espacio UV y decide el color de
## cada píxel según:
##   - la región del cuerpo (hueso con más peso: cabeza, torso, brazos, piernas, pies),
##   - la posición 3D del píxel en la pose de reposo (para dibujar cinturón,
##     bajo de la túnica, cuello, ojos, pelo, capucha, cruces del tabardo...).
## Si existe la textura original (Character_0X.png), la cabeza se conserva tal
## cual y la ropa se re-tiñe usando su luminancia, así se mantienen los pliegues.
## Sin original, todo se pinta proceduralmente.
##
## El resultado es una textura pequeña (128x128) con paleta reducida: PS1 pura.

enum Region { HEAD, TORSO, UPPER_ARM, FOREARM, HAND, THIGH, SHIN, FOOT }

const SIZE := 128

## Atuendos predefinidos. Claves opcionales: robe, mail, tabard, apron, hood, beard, bald.
const OUTFITS := {
	"henry": {
		"skin": Color(0.86, 0.66, 0.52), "hair": Color(0.30, 0.20, 0.11),
		"tunic": Color(0.55, 0.14, 0.10), "trim": Color(0.80, 0.62, 0.25),
		"sleeve": Color(0.82, 0.76, 0.62), "hose": Color(0.30, 0.26, 0.20),
		"boots": Color(0.20, 0.13, 0.08), "belt": Color(0.36, 0.23, 0.12),
	},
	"herrero": {
		"skin": Color(0.80, 0.58, 0.44), "hair": Color(0.20, 0.16, 0.13),
		"tunic": Color(0.42, 0.36, 0.27), "trim": Color(0.30, 0.25, 0.18),
		"sleeve": Color(0.42, 0.36, 0.27), "hose": Color(0.25, 0.25, 0.27),
		"boots": Color(0.17, 0.11, 0.07), "belt": Color(0.20, 0.14, 0.08),
		"apron": Color(0.33, 0.20, 0.11), "beard": Color(0.22, 0.17, 0.13),
	},
	"cura": {
		"skin": Color(0.84, 0.66, 0.54), "hair": Color(0.45, 0.42, 0.40),
		"tunic": Color(0.10, 0.10, 0.12), "trim": Color(0.75, 0.62, 0.30),
		"sleeve": Color(0.10, 0.10, 0.12), "hose": Color(0.10, 0.10, 0.12),
		"boots": Color(0.12, 0.09, 0.07), "belt": Color(0.85, 0.82, 0.72),
		"robe": true, "hood": Color(0.13, 0.13, 0.15),
	},
	"guardia": {
		"skin": Color(0.80, 0.60, 0.47), "hair": Color(0.25, 0.20, 0.15),
		"tunic": Color(0.58, 0.58, 0.62), "trim": Color(0.90, 0.85, 0.70),
		"sleeve": Color(0.58, 0.58, 0.62), "hose": Color(0.42, 0.13, 0.10),
		"boots": Color(0.15, 0.10, 0.07), "belt": Color(0.22, 0.14, 0.08),
		"mail": true, "tabard": Color(0.70, 0.12, 0.10), "hood": Color(0.55, 0.55, 0.60),
		"beard": Color(0.25, 0.20, 0.15),
	},
	"bandido": {
		"skin": Color(0.76, 0.55, 0.42), "hair": Color(0.15, 0.11, 0.08),
		"tunic": Color(0.30, 0.22, 0.15), "trim": Color(0.18, 0.13, 0.09),
		"sleeve": Color(0.24, 0.20, 0.16), "hose": Color(0.14, 0.13, 0.12),
		"boots": Color(0.13, 0.09, 0.06), "belt": Color(0.10, 0.07, 0.05),
		"hood": Color(0.45, 0.10, 0.08), "beard": Color(0.16, 0.12, 0.08),
	},
	"jefe": {
		"skin": Color(0.74, 0.54, 0.42), "hair": Color(0.10, 0.08, 0.07),
		"tunic": Color(0.50, 0.50, 0.54), "trim": Color(0.75, 0.60, 0.20),
		"sleeve": Color(0.50, 0.50, 0.54), "hose": Color(0.12, 0.12, 0.12),
		"boots": Color(0.10, 0.07, 0.05), "belt": Color(0.35, 0.25, 0.10),
		"mail": true, "tabard": Color(0.12, 0.12, 0.13), "cross": false,
		"hood": Color(0.40, 0.08, 0.06), "beard": Color(0.10, 0.08, 0.07),
	},
	"molinero": {
		"skin": Color(0.86, 0.68, 0.55), "hair": Color(0.6, 0.55, 0.5),
		"tunic": Color(0.85, 0.82, 0.74), "trim": Color(0.6, 0.55, 0.45),
		"sleeve": Color(0.88, 0.85, 0.78), "hose": Color(0.45, 0.4, 0.33),
		"boots": Color(0.25, 0.17, 0.1), "belt": Color(0.4, 0.3, 0.18),
		"apron": Color(0.95, 0.94, 0.9), "beard": Color(0.6, 0.55, 0.5),
	},
	"minero": {
		"skin": Color(0.62, 0.5, 0.42), "hair": Color(0.12, 0.1, 0.09),
		"tunic": Color(0.3, 0.3, 0.32), "trim": Color(0.2, 0.2, 0.2),
		"sleeve": Color(0.36, 0.34, 0.33), "hose": Color(0.22, 0.2, 0.18),
		"boots": Color(0.12, 0.09, 0.07), "belt": Color(0.3, 0.2, 0.1),
		"apron": Color(0.25, 0.17, 0.1), "hood": Color(0.85, 0.85, 0.82), "beard": Color(0.12, 0.1, 0.09),
	},
	"pastor": {
		"skin": Color(0.8, 0.6, 0.46), "hair": Color(0.5, 0.35, 0.2),
		"tunic": Color(0.6, 0.5, 0.36), "trim": Color(0.45, 0.35, 0.22),
		"sleeve": Color(0.85, 0.82, 0.7), "hose": Color(0.35, 0.3, 0.22),
		"boots": Color(0.22, 0.15, 0.09), "belt": Color(0.3, 0.22, 0.12),
		"hood": Color(0.3, 0.42, 0.28), "beard": Color(0.5, 0.35, 0.2),
	},
	"campesino": {
		"skin": Color(0.78, 0.56, 0.42), "hair": Color(0.45, 0.30, 0.15),
		"tunic": Color(0.38, 0.45, 0.25), "trim": Color(0.30, 0.35, 0.18),
		"sleeve": Color(0.75, 0.70, 0.56), "hose": Color(0.46, 0.38, 0.28),
		"boots": Color(0.24, 0.16, 0.10), "belt": Color(0.30, 0.22, 0.12),
		"hood": Color(0.50, 0.40, 0.26),
	},
}


## Genera la textura repintada para la malla de un personaje Mixamo.
## original puede ser null (pintado 100% procedural).
static func generate(mesh_instance: MeshInstance3D, skeleton: Skeleton3D, outfit: Dictionary,
		original: Image = null) -> Image:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	if original:
		original = original.duplicate()
		original.convert(Image.FORMAT_RGBA8)
		original.resize(SIZE, SIZE, Image.INTERPOLATE_BILINEAR)

	var ctx := _Context.new(skeleton, outfit, original)
	var mesh := mesh_instance.mesh
	var skin := mesh_instance.skin
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var influences := bones.size() / verts.size()

		# Pose de reposo de cada vértice + hueso dominante.
		var rest_pos := PackedVector3Array()
		var rest_nrm := PackedVector3Array()
		var dominant := PackedInt32Array()
		rest_pos.resize(verts.size())
		rest_nrm.resize(verts.size())
		dominant.resize(verts.size())
		for v in verts.size():
			var xf := Transform3D(Basis(), Vector3.ZERO)
			var acc_p := Vector3.ZERO
			var acc_n := Vector3.ZERO
			var best_w := -1.0
			var best_bone := 0
			for k in influences:
				var w := weights[v * influences + k]
				if w <= 0.0:
					continue
				var bind := bones[v * influences + k]
				var bone := _bind_bone(skin, skeleton, bind)
				xf = skeleton.get_bone_global_rest(bone) * skin.get_bind_pose(bind)
				acc_p += xf * verts[v] * w
				acc_n += xf.basis * normals[v] * w
				if w > best_w:
					best_w = w
					best_bone = bone
			rest_pos[v] = acc_p
			rest_nrm[v] = acc_n.normalized()
			dominant[v] = best_bone

		if indices.is_empty():
			indices.resize(verts.size())
			for i in verts.size():
				indices[i] = i
		for t in range(0, indices.size(), 3):
			var a := indices[t]
			var b := indices[t + 1]
			var c := indices[t + 2]
			var region := ctx.region_for([dominant[a], dominant[b], dominant[c]])
			_raster_triangle(img, ctx, region,
				[uvs[a] * SIZE, uvs[b] * SIZE, uvs[c] * SIZE],
				[rest_pos[a], rest_pos[b], rest_pos[c]],
				[rest_nrm[a], rest_nrm[b], rest_nrm[c]])

	_dilate(img, 2)
	return img


static func _bind_bone(skin: Skin, skeleton: Skeleton3D, bind: int) -> int:
	var bone := skin.get_bind_bone(bind)
	if bone < 0:
		bone = skeleton.find_bone(skin.get_bind_name(bind))
	return maxi(bone, 0)


static func _raster_triangle(img: Image, ctx: _Context, region: Region, uv: Array, pos: Array,
		nrm: Array) -> void:
	var p0: Vector2 = uv[0]
	var p1: Vector2 = uv[1]
	var p2: Vector2 = uv[2]
	var area := (p1 - p0).cross(p2 - p0)
	if absf(area) < 1e-6:
		return
	var min_x := clampi(int(floor(minf(p0.x, minf(p1.x, p2.x)))) - 1, 0, SIZE - 1)
	var max_x := clampi(int(ceil(maxf(p0.x, maxf(p1.x, p2.x)))) + 1, 0, SIZE - 1)
	var min_y := clampi(int(floor(minf(p0.y, minf(p1.y, p2.y)))) - 1, 0, SIZE - 1)
	var max_y := clampi(int(ceil(maxf(p0.y, maxf(p1.y, p2.y)))) + 1, 0, SIZE - 1)
	var eps := -0.6 / sqrt(absf(area)) # Margen para no dejar huecos en las costuras.
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var p := Vector2(x + 0.5, y + 0.5)
			var w0 := (p1 - p).cross(p2 - p) / area
			var w1 := (p2 - p).cross(p0 - p) / area
			var w2 := 1.0 - w0 - w1
			if w0 < eps or w1 < eps or w2 < eps:
				continue
			var world: Vector3 = pos[0] * w0 + pos[1] * w1 + pos[2] * w2
			var n: Vector3 = (nrm[0] * w0 + nrm[1] * w1 + nrm[2] * w2).normalized()
			img.set_pixel(x, y, ctx.paint(region, world, n, x, y))


## Extiende los bordes pintados hacia el fondo para evitar costuras negras.
static func _dilate(img: Image, passes: int) -> void:
	for i in passes:
		var src := img.duplicate() as Image
		for y in SIZE:
			for x in SIZE:
				if src.get_pixel(x, y).a > 0.0:
					continue
				for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var q := Vector2i(x, y) + o
					if q.x >= 0 and q.y >= 0 and q.x < SIZE and q.y < SIZE and src.get_pixelv(q).a > 0.0:
						img.set_pixel(x, y, src.get_pixelv(q))
						break


## Datos del esqueleto y del atuendo usados al pintar cada píxel.
class _Context:
	var skeleton: Skeleton3D
	var o: Dictionary
	var original: Image
	var head_y: float
	var head_top: float
	var head_x: float
	var head_z: float
	var neck_y: float
	var hips_y: float
	var chest_y: float
	var knee_y: float
	var rng := RandomNumberGenerator.new()

	func _init(sk: Skeleton3D, outfit: Dictionary, orig: Image) -> void:
		skeleton = sk
		o = outfit
		original = orig
		rng.seed = hash(str(outfit))
		var head := _bone_pos("mixamorig_Head")
		head_y = head.y
		head_x = head.x
		head_z = head.z
		head_top = _bone_pos("mixamorig_HeadTop_End").y
		neck_y = _bone_pos("mixamorig_Neck").y
		hips_y = _bone_pos("mixamorig_Hips").y
		chest_y = _bone_pos("mixamorig_Spine2").y
		knee_y = _bone_pos("mixamorig_LeftLeg").y

	func _bone_pos(bone_name: String) -> Vector3:
		var b := skeleton.find_bone(bone_name)
		return skeleton.get_bone_global_rest(b).origin if b >= 0 else Vector3.ZERO

	func region_for(bone_ids: Array) -> Region:
		var votes := {}
		for b: int in bone_ids:
			var r := _bone_region(skeleton.get_bone_name(b))
			votes[r] = votes.get(r, 0) + 1
		var best: Region = Region.TORSO
		var best_votes := 0
		for r: Region in votes:
			if votes[r] > best_votes:
				best = r
				best_votes = votes[r]
		return best

	func _bone_region(n: String) -> Region:
		if n.contains("Head") or n.contains("Neck"):
			return Region.HEAD
		if n.contains("Hand"):
			return Region.HAND
		if n.contains("ForeArm"):
			return Region.FOREARM
		if n.contains("Arm"):
			return Region.UPPER_ARM
		if n.contains("UpLeg"):
			return Region.THIGH
		if n.contains("Leg"):
			return Region.SHIN
		if n.contains("Foot") or n.contains("Toe"):
			return Region.FOOT
		return Region.TORSO

	## Devuelve el color final de un píxel.
	func paint(region: Region, p: Vector3, n: Vector3, px: int, py: int) -> Color:
		var orig := original.get_pixel(px, py) if original else Color(0, 0, 0, 0)
		var c: Color
		var material := "cloth"
		match region:
			Region.HEAD:
				if original and not o.has("hood"):
					return _quantize(orig.lerp(Color(orig.get_luminance(), orig.get_luminance(), orig.get_luminance()), 0.15))
				c = _head(p, n)
				material = "skin"
			Region.HAND:
				c = o.skin
				material = "skin"
			Region.UPPER_ARM, Region.FOREARM:
				c = o.sleeve
				if o.get("mail", false):
					material = "mail"
				if region == Region.FOREARM and _is_cuff(p):
					c = o.trim
			Region.TORSO:
				c = _torso(p, n)
				if o.get("mail", false) and c == o.tunic:
					material = "mail"
			Region.THIGH:
				c = _thigh(p, n)
				if o.get("mail", false) and c == o.tunic:
					material = "mail"
			Region.SHIN:
				if o.get("robe", false) and p.y > 0.12:
					c = o.tunic
				elif p.y < knee_y - 0.18:
					c = o.boots
					material = "leather"
				else:
					c = o.hose
			Region.FOOT:
				c = o.boots
				material = "leather"
		return _quantize(_shade(c, material, n, orig, px, py))

	func _is_cuff(p: Vector3) -> bool:
		# Puño: los últimos centímetros del antebrazo, junto a la muñeca.
		var hand_l := _bone_pos("mixamorig_LeftHand")
		var hand_r := _bone_pos("mixamorig_RightHand")
		return minf(p.distance_to(hand_l), p.distance_to(hand_r)) < 0.035

	func _torso(p: Vector3, n: Vector3) -> Color:
		var front := n.z > 0.25
		# Cinturón
		if p.y > hips_y + 0.02 and p.y < hips_y + 0.07:
			return o.belt
		# Escote en V
		var dx := absf(p.x - head_x)
		if front and p.y > neck_y - 0.10 and dx < (p.y - (neck_y - 0.10)) * 0.6:
			return o.skin
		if p.y > neck_y - 0.02 and not o.get("mail", false):
			return o.skin
		if o.has("tabard") and absf(n.x) < 0.6 and dx < 0.14 and p.y < neck_y - 0.06:
			if front and o.get("cross", true) and (dx < 0.018 or absf(p.y - (chest_y + 0.02)) < 0.018) \
					and p.y > hips_y + 0.12:
				return o.trim # cruz
			return o.tabard
		if o.has("apron") and front and p.y < chest_y + 0.05 and dx < 0.15:
			return o.apron
		return o.tunic

	func _thigh(p: Vector3, n: Vector3) -> Color:
		var hem := hips_y - 0.30
		if o.get("robe", false):
			return o.tunic
		if p.y > hem + 0.03:
			if o.has("tabard") and absf(n.x) < 0.6 and absf(p.x - head_x) < 0.14:
				return o.tabard
			if o.has("apron") and n.z > 0.25:
				return o.apron
			return o.tunic
		if p.y > hem:
			return o.trim
		return o.hose

	func _head(p: Vector3, n: Vector3) -> Color:
		var h := head_top - head_y
		var eye_y := head_y + h * 0.48
		var dx := p.x - head_x
		var front := n.z > 0.45 and p.z > head_z
		var face_zone := front and absf(dx) < 0.075 and p.y < eye_y + h * 0.28 and p.y > head_y - 0.02
		if o.has("hood") and not face_zone and p.y > neck_y - 0.02:
			return o.hood
		if p.y < neck_y + 0.02:
			return o.skin
		if front:
			# Ojos y cejas
			if absf(absf(dx) - h * 0.17) < h * 0.045:
				if absf(p.y - eye_y) < h * 0.028:
					return Color(0.08, 0.06, 0.05)
				if absf(p.y - (eye_y + h * 0.1)) < h * 0.018:
					return o.hair.darkened(0.2)
			# Boca
			if absf(dx) < h * 0.09 and absf(p.y - (eye_y - h * 0.32)) < h * 0.02:
				return o.skin.darkened(0.45)
			if o.has("beard") and p.y < eye_y - h * 0.16 and absf(dx) < 0.08:
				return o.beard
		if o.get("bald", false):
			return o.skin
		# Pelo: parte superior, nuca y laterales por encima de las orejas.
		if p.y > eye_y + h * 0.26:
			return o.hair
		if n.z < -0.15 and p.y > neck_y + 0.03:
			return o.hair
		if absf(n.x) > 0.7 and p.y > eye_y + h * 0.05:
			return o.hair
		return o.skin

	func _shade(c: Color, material: String, n: Vector3, orig: Color, px: int, py: int) -> Color:
		var noise := rng.randf_range(-0.035, 0.035)
		match material:
			"mail":
				# Anillas: patrón de cuadrícula alternada.
				var ring := 0.12 if (px + py * 2) % 3 == 0 else -0.05
				c = c.lightened(ring) if ring > 0 else c.darkened(-ring)
			"leather":
				noise *= 1.5
			"cloth":
				if (px + py) % 7 == 0:
					noise -= 0.03
		if orig.a > 0.5 and original:
			# Re-teñido: conserva los pliegues de la ropa original.
			var lum := clampf(orig.get_luminance(), 0.05, 1.0)
			var fold := clampf(0.55 + lum * 0.9, 0.55, 1.25)
			c = Color(c.r * fold, c.g * fold, c.b * fold)
		else:
			# Oclusión falsa: las caras que miran hacia abajo, más oscuras.
			c = c.darkened(clampf(-n.y, 0.0, 1.0) * 0.25)
		return Color(clampf(c.r + noise, 0, 1), clampf(c.g + noise, 0, 1), clampf(c.b + noise * 0.8, 0, 1), 1.0)

	## 15 bits de color, como la VRAM de la PS1.
	func _quantize(c: Color) -> Color:
		return Color(floorf(c.r * 31.0 + 0.5) / 31.0, floorf(c.g * 31.0 + 0.5) / 31.0,
			floorf(c.b * 31.0 + 0.5) / 31.0, 1.0)
