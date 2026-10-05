class_name PS1RiggedCharacter
extends Node3D
## Personaje PSX importado (FBX/GLB con rig Mixamo) con:
##  - textura repintada de estilo medieval (ver CharacterRepaint),
##  - material PS1 (jitter de vértices + texturas afines + Nearest),
##  - animaciones generadas por código sobre los huesos Mixamo con
##    interpolación NEAREST (idle, walk, run, talk, attack, hit),
##  - arma opcional en la mano derecha.
## Expone la misma API que PS1Character: play(nombre, velocidad).

## Modelo con rig Mixamo (mixamorig_*).
@export_file("*.fbx", "*.glb", "*.gltf") var model_path := "res://assets/characters/Character_01.fbx"
## Clave de CharacterRepaint.OUTFITS.
@export var outfit := "henry"
@export var body_scale := 1.0
## "" (nada), "sword", "axe" o "hammer" (ver WeaponFactory).
@export var weapon := ""

var animation_player: AnimationPlayer
var skeleton: Skeleton3D

var _rig: Node3D
var _lower_l := Quaternion.IDENTITY
var _lower_r := Quaternion.IDENTITY
var _elbow_axis_l := Vector3.UP
var _elbow_axis_r := Vector3.UP

## Colocación del arma respecto al hueso de la mano (rig Mixamo).
var weapon_grip := Transform3D(Basis.from_euler(Vector3(PI / 2, 0, 0)), Vector3(0, 0.08, 0.02))

const BONES := [
	"mixamorig_Spine1", "mixamorig_Head",
	"mixamorig_LeftArm", "mixamorig_RightArm", "mixamorig_LeftForeArm", "mixamorig_RightForeArm",
	"mixamorig_LeftUpLeg", "mixamorig_RightUpLeg", "mixamorig_LeftLeg", "mixamorig_RightLeg",
]


func _ready() -> void:
	scale = Vector3.ONE * body_scale
	_add_blob_shadow()
	_rig = (load(model_path) as PackedScene).instantiate()
	_rig.name = "Rig"
	_rig.rotation.y = PI # Mixamo mira hacia +Z; en el juego "adelante" es -Z.
	add_child(_rig)
	skeleton = _rig.find_child("Skeleton3D", true, false) as Skeleton3D
	for ap in _rig.find_children("*", "AnimationPlayer", true, false):
		ap.free() # La pose de importación no nos sirve.
	_apply_texture()
	_attach_weapon()
	_build_animations()
	play("idle")
	animation_player.seek(randf() * animation_player.current_animation_length, true)


func play(anim_name: String, speed := 1.0) -> void:
	animation_player.speed_scale = speed
	if animation_player.current_animation != anim_name:
		animation_player.play(anim_name)


## Reproduce desde el principio (ataques, golpes recibidos).
func play_once(anim_name: String) -> void:
	animation_player.speed_scale = 1.0
	animation_player.stop()
	animation_player.play(anim_name)


## Tinte breve (rojo al recibir daño, amarillo al preparar un ataque...).
func flash(color: Color, duration := 0.12) -> void:
	for mi: MeshInstance3D in _rig.find_children("*", "MeshInstance3D", true, false):
		var mat := mi.material_override as ShaderMaterial
		if mat:
			mat.set_shader_parameter("albedo", color)
	get_tree().create_timer(duration, false).timeout.connect(func() -> void:
		if not is_instance_valid(_rig):
			return
		for mi: MeshInstance3D in _rig.find_children("*", "MeshInstance3D", true, false):
			var mat := mi.material_override as ShaderMaterial
			if mat:
				mat.set_shader_parameter("albedo", Color.WHITE))


## Capa de render (1-20) de todas las mallas, sombra incluida.
func set_visual_layer(layer: int) -> void:
	for gi: GeometryInstance3D in find_children("*", "GeometryInstance3D", true, false):
		gi.layers = 1 << (layer - 1)


func _attach_weapon() -> void:
	if weapon == "":
		return
	var attach := BoneAttachment3D.new()
	attach.bone_name = "mixamorig_RightHand"
	skeleton.add_child(attach)
	var w := WeaponFactory.build(weapon)
	w.transform = weapon_grip
	attach.add_child(w)


# --- Textura -----------------------------------------------------------------

## Busca la textura repintada (assets/characters/textures/<modelo>_<atuendo>.png).
## Si no existe, la genera al vuelo (usando el PNG original si está disponible).
func _apply_texture() -> void:
	var base := model_path.get_basename()
	var tex_path := "%s/textures/%s_%s.png" % [model_path.get_base_dir(), base.get_file(), outfit]
	for mi: MeshInstance3D in _rig.find_children("*", "MeshInstance3D", true, false):
		var tex: Texture2D
		if ResourceLoader.exists(tex_path):
			tex = load(tex_path)
		else:
			var original: Image = null
			if ResourceLoader.exists(base + ".png"):
				original = (load(base + ".png") as Texture2D).get_image()
			var img := CharacterRepaint.generate(mi, skeleton, CharacterRepaint.OUTFITS[outfit], original)
			tex = ImageTexture.create_from_image(img)
		mi.material_override = PS1Assets.textured(tex)


func _add_blob_shadow() -> void:
	var shadow := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.9, 0.9)
	shadow.mesh = quad
	shadow.material_override = PS1Assets.blob_shadow_material()
	shadow.rotation.x = -PI / 2
	shadow.position.y = 0.03
	add_child(shadow)


# --- Animaciones ---------------------------------------------------------------

func _build_animations() -> void:
	_compute_arm_rest()
	animation_player = AnimationPlayer.new()
	animation_player.name = "AnimationPlayer"
	add_child(animation_player)

	var lib := AnimationLibrary.new()
	lib.add_animation("idle", _make_anim(2.0, [
		{},
		{"spine": 0.03, "head": 0.03, "bob": -0.01, "elbow_l": 0.2, "elbow_r": 0.2},
	]))
	lib.add_animation("walk", _make_anim(0.64, [
		{"leg_l": 0.45, "leg_r": -0.35, "knee_r": 0.35, "arm_l": -0.35, "arm_r": 0.35},
		{"leg_l": 0.05, "leg_r": 0.0, "knee_r": 0.6, "bob": 0.03},
		{"leg_l": -0.35, "leg_r": 0.45, "knee_l": 0.35, "arm_l": 0.35, "arm_r": -0.35},
		{"leg_l": 0.0, "leg_r": 0.05, "knee_l": 0.6, "bob": 0.03},
	]))
	var run_base := {"spine": 0.22, "elbow_l": 1.2, "elbow_r": 1.2}
	lib.add_animation("run", _make_anim(0.44, [
		_merge(run_base, {"leg_l": 0.8, "knee_l": 0.3, "leg_r": -0.5, "knee_r": 0.9, "arm_l": -0.7, "arm_r": 0.7}),
		_merge(run_base, {"leg_l": 0.1, "leg_r": 0.2, "knee_r": 1.2, "bob": 0.06}),
		_merge(run_base, {"leg_r": 0.8, "knee_r": 0.3, "leg_l": -0.5, "knee_l": 0.9, "arm_r": -0.7, "arm_l": 0.7}),
		_merge(run_base, {"leg_r": 0.1, "leg_l": 0.2, "knee_l": 1.2, "bob": 0.06}),
	]))
	lib.add_animation("talk", _make_anim(1.2, [
		{"arm_r": 0.5, "elbow_r": 1.1, "head": 0.08},
		{"arm_r": 0.7, "elbow_r": 1.4, "head": 0.0},
		{"arm_r": 0.5, "elbow_r": 1.0, "head": -0.04},
		{"arm_r": 0.3, "elbow_r": 0.8, "head": 0.06},
	]))
	# attack: amago (0-0,45 s), golpe en 0,45 s, recuperación. Sin bucle.
	lib.add_animation("attack", _make_anim(0.9, [
		{"arm_r": 2.2, "elbow_r": 1.3, "spine": -0.08, "leg_l": 0.2},
		{"arm_r": 2.6, "elbow_r": 1.1, "spine": -0.15, "leg_l": 0.25},
		{"arm_r": 0.9, "elbow_r": 0.15, "spine": 0.3, "leg_l": 0.35, "knee_r": 0.3},
		{"arm_r": 0.5, "elbow_r": 0.3, "spine": 0.15, "leg_l": 0.2},
	], false))
	lib.add_animation("hit", _make_anim(0.4, [
		{"spine": -0.3, "head": -0.25, "arm_l": 0.4, "arm_r": 0.4, "knee_l": 0.2},
		{"spine": -0.12, "head": -0.1},
	], false))
	animation_player.add_animation_library("", lib)


func _merge(a: Dictionary, b: Dictionary) -> Dictionary:
	var r := a.duplicate()
	r.merge(b, true)
	return r


## Calcula cómo bajar los brazos desde la pose de reposo (T-pose o A-pose).
func _compute_arm_rest() -> void:
	for side in ["Left", "Right"]:
		var arm := _bone_global_pos("mixamorig_%sArm" % side)
		var fore := _bone_global_pos("mixamorig_%sForeArm" % side)
		var dir := (fore - arm).normalized()
		var target := Vector3(signf(dir.x) * 0.22, -1.0, 0.0).normalized()
		var lower := Quaternion(dir, target)
		# Eje del codo: girar el antebrazo hacia delante (+Z del modelo).
		var elbow_axis := dir.cross(Vector3.BACK).normalized()
		if side == "Left":
			_lower_l = lower
			_elbow_axis_l = elbow_axis
		else:
			_lower_r = lower
			_elbow_axis_r = elbow_axis


func _bone_global_pos(bone_name: String) -> Vector3:
	return skeleton.get_bone_global_rest(skeleton.find_bone(bone_name)).origin


## Rotaciones en el espacio del modelo (pose de reposo) para cada hueso.
## Ángulos en radianes; positivo = hacia delante.
func _frame_rotations(f: Dictionary) -> Dictionary:
	var fwd := func(a: float) -> Quaternion: return Quaternion(Vector3.RIGHT, -a)
	return {
		"mixamorig_Spine1": Quaternion(Vector3.RIGHT, f.get("spine", 0.0)),
		"mixamorig_Head": Quaternion(Vector3.RIGHT, f.get("head", 0.0)),
		"mixamorig_LeftArm": fwd.call(f.get("arm_l", 0.0)) * _lower_l,
		"mixamorig_RightArm": fwd.call(f.get("arm_r", 0.0)) * _lower_r,
		"mixamorig_LeftForeArm": Quaternion(_elbow_axis_l, f.get("elbow_l", 0.15)),
		"mixamorig_RightForeArm": Quaternion(_elbow_axis_r, f.get("elbow_r", 0.15)),
		"mixamorig_LeftUpLeg": fwd.call(f.get("leg_l", 0.0)),
		"mixamorig_RightUpLeg": fwd.call(f.get("leg_r", 0.0)),
		"mixamorig_LeftLeg": Quaternion(Vector3.RIGHT, f.get("knee_l", 0.0)),
		"mixamorig_RightLeg": Quaternion(Vector3.RIGHT, f.get("knee_r", 0.0)),
	}


## Convierte una rotación expresada en el espacio del modelo (pose de reposo)
## a la rotación local del hueso: L' = L * G^-1 * R * G.
func _local_rotation(bone: int, model_rot: Quaternion) -> Quaternion:
	var g := skeleton.get_bone_global_rest(bone).basis.get_rotation_quaternion()
	var l := skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()
	return (l * (g.inverse() * model_rot * g)).normalized()


func _make_anim(length: float, frames: Array, loop := true) -> Animation:
	var anim := Animation.new()
	anim.length = length
	anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	var step := length / frames.size()
	var rig_path := "Rig/%s" % _rig.get_path_to(skeleton)

	for bone_name: String in BONES:
		var bone := skeleton.find_bone(bone_name)
		if bone < 0:
			continue
		var idx := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(idx, NodePath("%s:%s" % [rig_path, bone_name]))
		anim.track_set_interpolation_type(idx, Animation.INTERPOLATION_NEAREST)
		for i in frames.size():
			var rot: Quaternion = _frame_rotations(frames[i])[bone_name]
			anim.rotation_track_insert_key(idx, i * step, _local_rotation(bone, rot))

	var hips := skeleton.find_bone("mixamorig_Hips")
	if hips >= 0:
		var idx := anim.add_track(Animation.TYPE_POSITION_3D)
		anim.track_set_path(idx, NodePath("%s:mixamorig_Hips" % rig_path))
		anim.track_set_interpolation_type(idx, Animation.INTERPOLATION_NEAREST)
		var rest := skeleton.get_bone_rest(hips).origin
		for i in frames.size():
			anim.position_track_insert_key(idx, i * step, rest + Vector3(0, frames[i].get("bob", 0.0), 0))
	return anim
