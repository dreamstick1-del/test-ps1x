extends Node
## Hojas de fotogramas para revisar las animaciones de PS1RiggedCharacter.
##
## Cada animación se dibuja muestra a muestra (15 fps) de perfil (fila de
## arriba) y de frente (fila de abajo), con líneas de referencia cada 0,5 m, y
## se imprime por consola:
##   pie_min / pie_max  altura del pie más bajo respecto al suelo (0 = apoyado)
##   zancada_vel        velocidad a la que andar/correr no patina
##   MANO_R             altura de la mano del arma en cada clave de los ataques
##
## Uso: añadir como autoload temporal en project.godot (después de Economy)
##   AnimSheets="*res://tools/anim_frame_sheets.gd"
## y ejecutar el juego con ventana. Las hojas se guardan en
## user://anim_sheets/sheet_NN.png (3 animaciones por hoja).
var out := ProjectSettings.globalize_path("user://anim_sheets/")
const Y0 := 100.0
const W := 960
const H := 520
const SPACING := 1.6

func wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout

func key(k: Key) -> void:
	var e := InputEventKey.new(); e.physical_keycode = k; e.keycode = k; e.pressed = true
	Input.parse_input_event(e); await wait(0.05)
	e = e.duplicate(); e.pressed = false; Input.parse_input_event(e); await wait(0.1)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(out)
	run()

func floor_box(world: Node3D, center: Vector3, size: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = size; mi.mesh = bm
	var m := StandardMaterial3D.new(); m.albedo_color = color; m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = m
	mi.position = center
	world.add_child(mi)

func label(world: Node3D, text: String, pos: Vector3, color := Color.WHITE) -> Label3D:
	var l := Label3D.new(); l.text = text; l.position = pos; l.pixel_size = 0.004; l.font_size = 40
	l.modulate = color; l.outline_size = 8; l.no_depth_test = true
	world.add_child(l)
	return l

func run() -> void:
	await wait(1.5)
	await key(KEY_ENTER); await wait(0.4)
	await key(KEY_ENTER); await wait(1.5)
	var world: Node3D = get_tree().get_first_node_in_group("diorama_world")
	var p: Node3D = get_tree().get_first_node_in_group("player")
	p.global_position = Vector3(40, 0.5, 40)

	# Escenario limpio en el cielo.
	var stage := Node3D.new(); world.add_child(stage)
	floor_box(stage, Vector3(0, Y0 + 3.0 - 0.05, 0), Vector3(14, 0.1, 1.2), Color(0.35, 0.33, 0.3))  # fila perfil (arriba)
	floor_box(stage, Vector3(0, Y0 - 0.05, 0), Vector3(14, 0.1, 1.2), Color(0.35, 0.33, 0.3))        # fila frente
	floor_box(stage, Vector3(0, Y0 + 1.5, -3), Vector3(30, 8, 0.2), Color(0.55, 0.62, 0.7))          # fondo
	for row_y in [Y0, Y0 + 3.0]:
		for h in [0.5, 1.0, 1.5]:
			floor_box(stage, Vector3(0, row_y + h, -2.8), Vector3(14, 0.012, 0.01), Color(0.4, 0.45, 0.55))
	var light := DirectionalLight3D.new(); light.rotation_degrees = Vector3(-35, 30, 0); stage.add_child(light)

	var vp := SubViewport.new(); vp.size = Vector2i(W, H); vp.world_3d = world.get_world_3d()
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var cam := Camera3D.new(); cam.projection = Camera3D.PROJECTION_ORTHOGONAL; cam.size = 5.2
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	vp.add_child(cam)
	cam.global_position = Vector3(0, Y0 + 2.25, 10); cam.current = true

	var probe := PS1RiggedCharacter.new()
	probe.model_path = "res://assets/characters/Character_05.fbx"; probe.outfit = "bandido"; probe.weapon = "axe"
	stage.add_child(probe); probe.global_position = Vector3(0, Y0 + 50, 0)
	await wait(0.3)
	var lib: AnimationLibrary = probe.animation_player.get_animation_library("")
	var names: Array = Array(lib.get_animation_list())
	var sk: Skeleton3D = probe.skeleton
	for bn in ["mixamorig_LeftFoot", "mixamorig_RightFoot", "mixamorig_LeftToeBase", "mixamorig_RightToeBase", "mixamorig_RightHand", "mixamorig_Hips"]:
		if sk.find_bone(bn) < 0: print("FALTA HUESO ", bn)
	# Altura de referencia de los pies en reposo (pose idle t=0).
	var base := _measure(probe, "idle", 0.0)
	print("BASE pies y=", snappedf(base.foot_min, 0.001), " mano_r=", base.hand)
	var sheet_imgs: Array[Image] = []
	for anim_name: String in names:
		var anim := lib.get_animation(anim_name)
		var times: Array = []
		for k in anim.track_get_key_count(0): times.append(anim.track_get_key_time(0, k))
		# Medidas
		var shown: Array = times
		if times.size() > 12:
			shown = []
			for q in 12: shown.append(times[int(round(q * (times.size() - 1) / 11.0))])
		var line := "ANIM %-14s len=%.2f loop=%s keys=%d |" % [anim_name, anim.length, anim.loop_mode != Animation.LOOP_NONE, times.size()]
		var lo := INF; var hi := -INF; var worst := 0.0
		for t: float in times:
			var m := _measure(probe, anim_name, t)
			var d: float = m.foot_min - base.foot_min
			lo = minf(lo, d); hi = maxf(hi, d)
		line += " pie_min=%+.3f pie_max=%+.3f zancada_vel=%s" % [lo, hi, probe.stride_speed.get(anim_name, "-")]
		print(line)
		if anim_name.begins_with("attack"):
			var hy := []
			for t: float in times: hy.append(snappedf(_measure(probe, anim_name, t).hand.y - base.hand.y, 0.01))
			print("   MANO_R altura por clave=", hy, " tiempos=", times.map(func(v): return snappedf(v, 0.01)))
		# Hoja visual
		var n := shown.size()
		var spacing := minf(SPACING, 8.6 / maxf(n - 1, 1))
		var chars := []
		var x0 := -spacing * (n - 1) * 0.5
		var labels := []
		labels.append(label(stage, anim_name, Vector3(-5.6, Y0 + 4.95, 0), Color(1, 0.85, 0.3)))
		for i in n:
			for row in 2:
				var c := PS1RiggedCharacter.new()
				c.model_path = "res://assets/characters/Character_05.fbx"; c.outfit = "bandido"; c.weapon = "axe"
				stage.add_child(c)
				var pos := Vector3(x0 + i * spacing, Y0 + (3.0 if row == 0 else 0.0), 0)
				c.global_position = pos
				if row == 0: c.look_at(pos + Vector3(1, 0, 0), Vector3.UP)  # perfil, mira a la derecha
				else: c.look_at(pos + Vector3(0, 0, 1), Vector3.UP)          # de frente
				chars.append([c, shown[i]])
			labels.append(label(stage, "%.2f" % shown[i], Vector3(x0 + i * spacing, Y0 + 2.2, 0.5)))
		await wait(0.15)
		for pair in chars:
			var c: PS1RiggedCharacter = pair[0]
			c.play_once(anim_name); c.animation_player.seek(pair[1] + 0.001, true); c.animation_player.speed_scale = 0.0
		await wait(0.15)
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		sheet_imgs.append(img)
		for pair in chars: pair[0].queue_free()
		for l in labels: l.queue_free()
		await wait(0.05)
	# Juntar de 3 en 3
	var page := 0
	for i in range(0, sheet_imgs.size(), 3):
		var count := mini(3, sheet_imgs.size() - i)
		var big := Image.create(W, H * count, false, sheet_imgs[i].get_format())
		for j in count:
			big.blit_rect(sheet_imgs[i + j], Rect2i(0, 0, W, H), Vector2i(0, H * j))
		big.save_png(out + "sheet_%02d.png" % page)
		page += 1
	print("DONE ", names.size(), " animaciones -> ", out)
	get_tree().quit()

func _measure(c: PS1RiggedCharacter, anim_name: String, t: float) -> Dictionary:
	c.play_once(anim_name)
	c.animation_player.seek(t + 0.001, true)
	c.animation_player.speed_scale = 0.0
	var sk := c.skeleton
	sk.force_update_all_bone_transforms()
	var g := func(bn: String) -> Vector3:
		return sk.global_transform * sk.get_bone_global_pose(sk.find_bone(bn)).origin - c.global_position
	var lf: Vector3 = g.call("mixamorig_LeftToeBase"); var rf: Vector3 = g.call("mixamorig_RightToeBase")
	var lh: Vector3 = g.call("mixamorig_LeftFoot"); var rh: Vector3 = g.call("mixamorig_RightFoot")
	var fwd := -c.global_transform.basis.z
	return {"foot_min": minf(minf(lf.y, rf.y), minf(lh.y, rh.y)), "hips": g.call("mixamorig_Hips").y,
		"zl": lh.dot(fwd), "zr": rh.dot(fwd), "hand": g.call("mixamorig_RightHand")}
