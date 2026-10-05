class_name PS1RiggedCharacter
extends Node3D
## Personaje PSX importado (FBX/GLB con rig Mixamo) con:
##  - textura repintada de estilo medieval (ver CharacterRepaint),
##  - material PS1 (jitter de vértices + texturas afines + Nearest),
##  - animaciones generadas por código sobre los huesos Mixamo con
##    interpolación NEAREST (ver ANIMS más abajo: andar, correr, atacar,
##    bloquear, morir, oficios, saludar...),
##  - arma opcional en la mano derecha.
## Expone la misma API que PS1Character: play(nombre, velocidad).

## Modelo con rig Mixamo (mixamorig_*).
@export_file("*.fbx", "*.glb", "*.gltf") var model_path := "res://assets/characters/Character_01.fbx"
## Clave de CharacterRepaint.OUTFITS.
@export var outfit := "henry"
@export var body_scale := 1.0
## "" (nada), "sword", "axe" o "hammer" (ver WeaponFactory).
@export var weapon := ""

## Un material por textura, compartido por todos los que la usan (WebGL
## no admite cientos de materiales distintos).
static var _material_cache := {}

var animation_player: AnimationPlayer
var skeleton: Skeleton3D

var _rig: Node3D
var _lower_l := Quaternion.IDENTITY
var _lower_r := Quaternion.IDENTITY
var _elbow_axis_l := Vector3.UP
var _elbow_axis_r := Vector3.UP

## Dirección del arma con los brazos en reposo (espacio del esqueleto, +Z = delante):
## el mango apunta adelante y algo abajo; el filo (+X del arma) hacia abajo.
const WEAPON_POINT := Vector3(0, -0.25, 1.0)
const WEAPON_EDGE := Vector3(0, -1, 0)
## Desplazamiento del arma en la mano, en el espacio del hueso (hacia la palma).
const WEAPON_OFFSET := Vector3(0, 0.08, 0.02)

## Velocidad (m/s) a la que cada animación de desplazamiento no patina,
## calculada con lo que avanzan los pies (ver _make_anim).
var stride_speed := {}

const BONES := [
	"mixamorig_Spine1", "mixamorig_Head",
	"mixamorig_LeftArm", "mixamorig_RightArm", "mixamorig_LeftForeArm", "mixamorig_RightForeArm",
	"mixamorig_LeftUpLeg", "mixamorig_RightUpLeg", "mixamorig_LeftLeg", "mixamorig_RightLeg",
	"mixamorig_RightHand",
]
## Muñeca relajada: fuera del combate el arma cuelga hacia abajo en vez de
## apuntar al frente (ver "wrist_r" y RELAXED).
const RELAXED := {"wrist_r": -0.95}


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
	_compute_arm_rest()
	_attach_weapon()
	_build_animations()
	play("idle")
	animation_player.seek(randf() * animation_player.current_animation_length, true)


func play(anim_name: String, speed := 1.0) -> void:
	if not animation_player.has_animation(anim_name):
		anim_name = "idle"
	animation_player.speed_scale = speed
	if animation_player.current_animation != anim_name:
		animation_player.play(anim_name)


## Para andar/correr/rodear: la animación va al ritmo de `speed_mps` para que
## los pies no patinen.
func play_moving(anim_name: String, speed_mps: float) -> void:
	var nominal: float = stride_speed.get(anim_name, 0.0)
	var scale_ := 1.0 if nominal <= 0.0 else clampf(speed_mps / nominal, 0.6, 1.6)
	play(anim_name, scale_)
	animation_player.speed_scale = scale_


## Reproduce desde el principio (ataques, golpes recibidos).
func play_once(anim_name: String, speed := 1.0) -> void:
	animation_player.speed_scale = speed
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
	w.transform = _weapon_grip()
	attach.add_child(w)


## Orientación del arma respecto al hueso de la mano para que, con el brazo
## caído, apunte hacia WEAPON_POINT con el filo hacia WEAPON_EDGE.
func _weapon_grip() -> Transform3D:
	var hand := skeleton.find_bone("mixamorig_RightHand")
	var hand_rot := Basis(_lower_r) * skeleton.get_bone_global_rest(hand).basis.orthonormalized()
	var y := WEAPON_POINT.normalized()
	var x := (WEAPON_EDGE - y * WEAPON_EDGE.dot(y)).normalized()
	var wanted := Basis(x, y, x.cross(y))
	return Transform3D(hand_rot.inverse() * wanted, WEAPON_OFFSET)


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
		if not _material_cache.has(tex_path):
			_material_cache[tex_path] = PS1Assets.textured(tex)
		mi.material_override = _material_cache[tex_path]


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
	# Altura de los pies en la pose de reposo (brazos bajados): ese es el suelo.
	var rest_local := {}
	var rots := _frame_rotations({})
	for bone_name: String in BONES:
		var b := skeleton.find_bone(bone_name)
		if b >= 0:
			rest_local[bone_name] = _local_rotation(b, rots[bone_name])
	_ground_foot_y = _feet_in_pose(rest_local).y
	animation_player = AnimationPlayer.new()
	animation_player.name = "AnimationPlayer"
	add_child(animation_player)

	var lib := AnimationLibrary.new()
	lib.add_animation("idle", _make_anim(2.0, [
		{},
		{"spine": 0.03, "head": 0.03, "elbow_l": 0.2, "elbow_r": 0.2},
	], true, RELAXED))
	lib.add_animation("walk", _make_anim(0.64, [
		{"leg_l": 0.45, "leg_r": -0.35, "knee_r": 0.35, "arm_l": -0.35, "arm_r": 0.35},
		{"leg_l": 0.05, "leg_r": 0.0, "knee_r": 0.6},
		{"leg_l": -0.35, "leg_r": 0.45, "knee_l": 0.35, "arm_l": 0.35, "arm_r": -0.35},
		{"leg_l": 0.0, "leg_r": 0.05, "knee_l": 0.6},
	], true, RELAXED))
	_record_stride("walk", 0.64)
	var run_base := {"spine": 0.22, "elbow_l": 1.2, "elbow_r": 1.2}
	lib.add_animation("run", _make_anim(0.44, [
		_merge(run_base, {"leg_l": 0.8, "knee_l": 0.3, "leg_r": -0.5, "knee_r": 0.9, "arm_l": -0.7, "arm_r": 0.7}),
		_merge(run_base, {"leg_l": 0.1, "leg_r": 0.2, "knee_r": 1.2, "lift": 0.05}),
		_merge(run_base, {"leg_r": 0.8, "knee_r": 0.3, "leg_l": -0.5, "knee_l": 0.9, "arm_r": -0.7, "arm_l": 0.7}),
		_merge(run_base, {"leg_r": 0.1, "leg_l": 0.2, "knee_l": 1.2, "lift": 0.05}),
	], true, RELAXED))
	_record_stride("run", 0.44)
	lib.add_animation("talk", _make_anim(1.2, [
		{"arm_r": 0.5, "elbow_r": 1.1, "head": 0.08},
		{"arm_r": 0.7, "elbow_r": 1.4, "head": 0.0},
		{"arm_r": 0.5, "elbow_r": 1.0, "head": -0.04},
		{"arm_r": 0.3, "elbow_r": 0.8, "head": 0.06},
	], true, RELAXED))
	# attack: amago (0-0,45 s), golpe en 0,45 s, recuperación. Sin bucle.
	lib.add_animation("attack", _make_anim(0.9, [
		{"arm_r": 2.2, "elbow_r": 1.3, "spine": -0.08, "leg_l": 0.2},
		{"arm_r": 2.6, "elbow_r": 1.1, "spine": -0.15, "leg_l": 0.25},
		{"arm_r": 1.15, "elbow_r": 0.1, "spine": 0.3, "leg_l": 0.35, "knee_r": 0.3},
		{"arm_r": 0.8, "elbow_r": 0.3, "spine": 0.15, "leg_l": 0.2},
	], false))
	# block: arma cruzada delante del cuerpo, un poco agachado.
	lib.add_animation("block", _make_anim(0.3, [
		{"arm_r": 1.3, "elbow_r": 1.5, "arm_l": 0.9, "elbow_l": 1.3, "spine": 0.12, "knee_l": 0.25, "knee_r": 0.25},
	], false))
	# attack_heavy: golpe por encima de la cabeza con amago largo (impacto en 0,8 s).
	lib.add_animation("attack_heavy", _make_anim(1.3, [
		{"arm_r": 2.4, "elbow_r": 1.4, "arm_l": 2.2, "elbow_l": 1.4, "spine": -0.1, "knee_l": 0.2, "knee_r": 0.2},
		{"arm_r": 2.9, "elbow_r": 1.6, "arm_l": 2.7, "elbow_l": 1.6, "spine": -0.25, "head": -0.1},
		{"arm_r": 2.9, "elbow_r": 1.6, "arm_l": 2.7, "elbow_l": 1.6, "spine": -0.28, "head": -0.12},
		{"arm_r": 1.1, "elbow_r": 0.1, "arm_l": 1.0, "elbow_l": 0.15, "out_r": -0.15, "out_l": -0.15, "spine": 0.45, "leg_l": 0.45, "knee_r": 0.5},
		{"arm_r": 0.95, "elbow_r": 0.2, "arm_l": 0.85, "elbow_l": 0.25, "out_r": -0.15, "out_l": -0.15, "spine": 0.38, "leg_l": 0.4, "knee_r": 0.45},
		{"arm_r": 0.4, "elbow_r": 0.3, "spine": 0.12, "leg_l": 0.15},
	], false))
	# attack_thrust: estocada con paso adelante (impacto en 0,4 s).
	lib.add_animation("attack_thrust", _make_anim(1.0, [
		{"arm_r": -0.2, "elbow_r": 1.7, "twist": 0.35, "spine": -0.05, "leg_r": -0.2},
		{"arm_r": -0.35, "elbow_r": 1.9, "twist": 0.45, "spine": -0.1, "leg_r": -0.25},
		{"arm_r": 1.5, "elbow_r": 0.1, "twist": -0.25, "spine": 0.25, "leg_l": 0.55, "knee_r": 0.4},
		{"arm_r": 1.4, "elbow_r": 0.2, "twist": -0.2, "spine": 0.2, "leg_l": 0.5, "knee_r": 0.35},
		{"arm_r": 0.6, "elbow_r": 0.6, "spine": 0.05, "leg_l": 0.1},
	], false))
	# Pasos laterales (rodear al rival) y hacia atrás.
	for side in [["strafe_l", 1.0], ["strafe_r", -1.0]]:
		var k: float = side[1]
		var guard := {"arm_r": 0.9, "elbow_r": 1.0, "arm_l": 0.5, "elbow_l": 1.2, "spine": 0.12, "twist": 0.15 * k}
		lib.add_animation(side[0], _make_anim(0.6, [
			_merge(guard, {"side_l": 0.5 * k if k > 0 else 0.05, "side_r": 0.5 * -k if k < 0 else 0.05, "knee_l": 0.25, "knee_r": 0.25}),
			_merge(guard, {"side_l": 0.05, "side_r": 0.05, "knee_l": 0.35, "knee_r": 0.35}),
			_merge(guard, {"side_l": 0.3 * -k if k < 0 else 0.0, "side_r": 0.3 * k if k > 0 else 0.0, "knee_l": 0.25, "knee_r": 0.25}),
			_merge(guard, {"knee_l": 0.3, "knee_r": 0.3}),
		]))
		_record_stride(side[0], 0.6)
	lib.add_animation("walk_back", _make_anim(0.72, [
		{"leg_l": -0.3, "leg_r": 0.3, "knee_l": 0.5, "arm_r": 0.9, "elbow_r": 1.0, "spine": 0.1},
		{"leg_l": 0.0, "leg_r": 0.05, "knee_l": 0.2, "arm_r": 0.9, "elbow_r": 1.0, "spine": 0.1},
		{"leg_l": 0.3, "leg_r": -0.3, "knee_r": 0.5, "arm_r": 0.9, "elbow_r": 1.0, "spine": 0.1},
		{"leg_l": 0.05, "leg_r": 0.0, "knee_r": 0.2, "arm_r": 0.9, "elbow_r": 1.0, "spine": 0.1},
	]))
	_record_stride("walk_back", 0.72)
	# taunt: provoca al rival levantando el arma.
	lib.add_animation("taunt", _make_anim(1.0, [
		{"arm_r": 2.6, "elbow_r": 0.4, "out_r": 0.3, "spine": -0.15, "head": -0.15, "arm_l": 0.3, "out_l": 0.5},
		{"arm_r": 2.9, "elbow_r": 0.2, "out_r": 0.2, "spine": -0.2, "head": -0.2, "arm_l": 0.3, "out_l": 0.6},
		{"arm_r": 2.5, "elbow_r": 0.5, "out_r": 0.3, "spine": -0.15, "head": -0.15, "arm_l": 0.3, "out_l": 0.5},
		{"arm_r": 1.0, "elbow_r": 1.0, "spine": 0.05},
	], false))
	# death: se le doblan las rodillas (luego el script lo tumba hacia atrás).
	lib.add_animation("death", _make_anim(0.6, [
		{"spine": -0.35, "head": -0.3, "arm_l": 0.5, "arm_r": 0.6, "out_l": 0.4, "out_r": 0.4, "knee_l": 0.3},
		{"spine": 0.3, "head": 0.4, "arm_l": 0.2, "arm_r": 0.2, "leg_l": 0.6, "leg_r": 0.5, "knee_l": 1.2, "knee_r": 1.3},
		{"spine": 0.45, "head": 0.6, "arm_l": 0.0, "arm_r": 0.1, "out_l": 0.2, "out_r": 0.2, "leg_l": 0.9, "leg_r": 0.9,
			"knee_l": 1.8, "knee_r": 1.8},
	], false, {"wrist_r": -0.5}))
	# --- Vida del pueblo ---
	lib.add_animation("wave", _make_anim(1.2, [
		{"arm_r": 2.7, "out_r": 0.5, "elbow_r": 0.5, "head": -0.05},
		{"arm_r": 2.7, "out_r": 0.2, "elbow_r": 1.0, "head": -0.05},
		{"arm_r": 2.7, "out_r": 0.5, "elbow_r": 0.5, "head": -0.05},
		{"arm_r": 2.7, "out_r": 0.2, "elbow_r": 1.0, "head": -0.05},
		{"arm_r": 0.3, "elbow_r": 0.4},
	], false))
	lib.add_animation("look_around", _make_anim(3.0, [
		{"head_turn": 0.0},
		{"head_turn": 0.6, "twist": 0.1},
		{"head_turn": 0.6, "twist": 0.1, "head": 0.05},
		{"head_turn": -0.6, "twist": -0.1},
		{"head_turn": -0.6, "twist": -0.1, "head": -0.05},
		{"head_turn": 0.0, "elbow_l": 0.2, "elbow_r": 0.2},
	], false, RELAXED))
	# hammer: martillea en el yunque (herrero, minero).
	lib.add_animation("hammer", _make_anim(0.9, [
		{"arm_r": 2.3, "elbow_r": 1.6, "arm_l": 0.9, "elbow_l": 0.9, "spine": 0.2, "head": 0.3},
		{"arm_r": 2.5, "elbow_r": 1.5, "arm_l": 0.9, "elbow_l": 0.9, "spine": 0.18, "head": 0.3},
		{"arm_r": 1.0, "elbow_r": 0.6, "arm_l": 0.9, "elbow_l": 0.9, "spine": 0.35, "head": 0.4},
		{"arm_r": 1.1, "elbow_r": 0.7, "arm_l": 0.9, "elbow_l": 0.9, "spine": 0.32, "head": 0.4},
	]))
	# hoe: cava o rastrilla (campesinos).
	lib.add_animation("hoe", _make_anim(1.6, [
		{"arm_r": 1.9, "arm_l": 1.7, "elbow_r": 0.8, "elbow_l": 0.9, "spine": 0.1, "leg_l": 0.3, "knee_r": 0.2},
		{"arm_r": 1.1, "arm_l": 0.9, "elbow_r": 0.3, "elbow_l": 0.4, "spine": 0.5, "head": 0.3, "leg_l": 0.35, "knee_r": 0.35},
		{"arm_r": 0.8, "arm_l": 0.7, "elbow_r": 0.6, "elbow_l": 0.6, "spine": 0.45, "head": 0.3, "twist": 0.2, "leg_l": 0.35, "knee_r": 0.35},
		{"arm_r": 1.3, "arm_l": 1.1, "elbow_r": 0.6, "elbow_l": 0.6, "spine": 0.25, "leg_l": 0.3, "knee_r": 0.25},
	]))
	lib.add_animation("pray", _make_anim(3.0, [
		{"arm_r": 0.8, "arm_l": 0.8, "elbow_r": 1.9, "elbow_l": 1.9, "out_r": -0.25, "out_l": -0.25, "head": 0.35, "spine": 0.08},
		{"arm_r": 0.85, "arm_l": 0.85, "elbow_r": 1.9, "elbow_l": 1.9, "out_r": -0.25, "out_l": -0.25, "head": 0.4, "spine": 0.1},
	], true, RELAXED))
	# call: el mercader pregona su género.
	lib.add_animation("call", _make_anim(1.6, [
		{"arm_l": 1.3, "out_l": 0.4, "elbow_l": 0.4, "arm_r": 0.6, "elbow_r": 1.2, "head": -0.12, "twist": 0.2},
		{"arm_l": 1.6, "out_l": 0.6, "elbow_l": 0.3, "arm_r": 0.6, "elbow_r": 1.2, "head": -0.15, "twist": 0.3},
		{"arm_l": 0.6, "out_l": 0.2, "elbow_l": 0.6, "arm_r": 1.3, "out_r": 0.4, "elbow_r": 0.4, "head": -0.1, "twist": -0.2},
		{"arm_l": 0.6, "out_l": 0.2, "elbow_l": 0.6, "arm_r": 1.6, "out_r": 0.6, "elbow_r": 0.3, "head": -0.12, "twist": -0.3},
	], true, RELAXED))
	# guard: de pie, firme, con el arma al frente (guardias).
	lib.add_animation("guard", _make_anim(2.4, [
		{"arm_r": 0.7, "elbow_r": 1.3, "arm_l": 0.3, "elbow_l": 0.5, "head_turn": 0.2},
		{"arm_r": 0.7, "elbow_r": 1.3, "arm_l": 0.3, "elbow_l": 0.5, "head_turn": -0.2},
	]))
	# cower: se encoge y se tapa la cabeza (durante el asalto).
	lib.add_animation("cower", _make_anim(0.5, [
		{"arm_l": 2.6, "arm_r": 2.6, "elbow_l": 2.1, "elbow_r": 2.1, "out_l": -0.2, "out_r": -0.2, "spine": 0.55, "head": 0.5,
			"leg_l": 0.7, "leg_r": 0.7, "knee_l": 1.4, "knee_r": 1.4},
		{"arm_l": 2.6, "arm_r": 2.6, "elbow_l": 2.1, "elbow_r": 2.1, "out_l": -0.2, "out_r": -0.2, "spine": 0.6, "head": 0.55,
			"leg_l": 0.7, "leg_r": 0.7, "knee_l": 1.4, "knee_r": 1.4},
	], true, RELAXED))
	lib.add_animation("cheer", _make_anim(0.8, [
		{"arm_l": 2.5, "arm_r": 2.5, "out_l": 0.9, "out_r": 0.9, "elbow_l": 0.2, "elbow_r": 0.2, "head": -0.2, "lift": 0.05},
		{"arm_l": 2.2, "arm_r": 2.2, "out_l": 1.1, "out_r": 1.1, "elbow_l": 0.6, "elbow_r": 0.6, "head": -0.1, "knee_l": 0.3, "knee_r": 0.3},
	], true, RELAXED))
	lib.add_animation("hit", _make_anim(0.4, [
		{"spine": -0.3, "head": -0.25, "arm_l": 0.4, "arm_r": 0.4, "knee_l": 0.2},
		{"spine": -0.12, "head": -0.1},
	], false, RELAXED))
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
	# Separar del cuerpo (brazos o piernas hacia los lados): positivo = hacia fuera.
	# Se aplica con el miembro colgando, antes de girarlo hacia delante, para que
	# "fuera" signifique lo mismo con el brazo caído, horizontal o en alto.
	# (El lado izquierdo del rig Mixamo es +X.)
	var out_l := func(a: float) -> Quaternion: return Quaternion(Vector3.BACK, a)
	var out_r := func(a: float) -> Quaternion: return Quaternion(Vector3.BACK, -a)
	var turn := func(a: float) -> Quaternion: return Quaternion(Vector3.UP, a)
	return {
		"mixamorig_Spine1": turn.call(f.get("twist", 0.0)) * Quaternion(Vector3.RIGHT, f.get("spine", 0.0)),
		"mixamorig_Head": turn.call(f.get("head_turn", 0.0)) * Quaternion(Vector3.RIGHT, f.get("head", 0.0)),
		"mixamorig_LeftArm": fwd.call(f.get("arm_l", 0.0)) * out_l.call(f.get("out_l", 0.0)) * _lower_l,
		"mixamorig_RightArm": fwd.call(f.get("arm_r", 0.0)) * out_r.call(f.get("out_r", 0.0)) * _lower_r,
		"mixamorig_LeftForeArm": Quaternion(_elbow_axis_l, f.get("elbow_l", 0.15)),
		"mixamorig_RightForeArm": Quaternion(_elbow_axis_r, f.get("elbow_r", 0.15)),
		"mixamorig_LeftUpLeg": fwd.call(f.get("leg_l", 0.0)) * out_l.call(f.get("side_l", 0.0)),
		"mixamorig_RightUpLeg": fwd.call(f.get("leg_r", 0.0)) * out_r.call(f.get("side_r", 0.0)),
		"mixamorig_LeftLeg": Quaternion(Vector3.RIGHT, f.get("knee_l", 0.0)),
		"mixamorig_RightLeg": Quaternion(Vector3.RIGHT, f.get("knee_r", 0.0)),
		# Muñeca: positivo levanta la punta del arma, negativo la baja.
		"mixamorig_RightHand": Quaternion(_elbow_axis_r, f.get("wrist_r", 0.0)),
	}


## Convierte una rotación expresada en el espacio del modelo (pose de reposo)
## a la rotación local del hueso: L' = L * G^-1 * R * G.
func _local_rotation(bone: int, model_rot: Quaternion) -> Quaternion:
	var g := skeleton.get_bone_global_rest(bone).basis.get_rotation_quaternion()
	var l := skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()
	return (l * (g.inverse() * model_rot * g)).normalized()


## Construye la animación a partir de poses clave (diccionarios de ángulos):
##  - se muestrea a FPS (15) interpolando entre claves y con interpolación
##    NEAREST entre muestras: movimiento entrecortado como en PS1, pero con
##    poses intermedias;
##  - `base` se mezcla bajo cada clave (p. ej. RELAXED para la muñeca);
##  - la altura de la cadera se calcula en cada muestra para que el pie más bajo
##    toque el suelo (nada de pies hundidos o flotando). "lift" eleva al
##    personaje por encima del suelo (fase de vuelo al correr, saltos).
## Las claves se reparten a partes iguales en `length`.
func _make_anim(length: float, frames: Array, loop := true, base := {}) -> Animation:
	if not base.is_empty():
		frames = frames.map(func(f: Dictionary) -> Dictionary: return _merge(base, f))
	var anim := Animation.new()
	anim.length = length
	anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	var step := length / frames.size()
	var last_key := length if loop else step * (frames.size() - 1)
	var samples: Array[float] = []
	var t := 0.0
	while t < last_key - 0.001 or (not loop and samples.is_empty()):
		samples.append(t)
		t += 1.0 / FPS
	if not loop and frames.size() > 1:
		samples.append(last_key)
	# Las claves exactas siempre se incluyen (el golpe de un ataque cae en su clave).
	for i in frames.size():
		var kt := i * step
		if kt <= last_key + 0.001 and not samples.any(func(v: float) -> bool: return absf(v - kt) < 0.02):
			samples.append(kt)
	samples.sort()

	var rig_path := "Rig/%s" % _rig.get_path_to(skeleton)
	var tracks := {}
	for bone_name: String in BONES:
		if skeleton.find_bone(bone_name) < 0:
			continue
		var idx := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(idx, NodePath("%s:%s" % [rig_path, bone_name]))
		anim.track_set_interpolation_type(idx, Animation.INTERPOLATION_NEAREST)
		tracks[bone_name] = idx
	var hips := skeleton.find_bone("mixamorig_Hips")
	var hips_idx := -1
	if hips >= 0:
		hips_idx = anim.add_track(Animation.TYPE_POSITION_3D)
		anim.track_set_path(hips_idx, NodePath("%s:mixamorig_Hips" % rig_path))
		anim.track_set_interpolation_type(hips_idx, Animation.INTERPOLATION_NEAREST)

	var foot_min_z := INF
	var foot_max_z := -INF
	var foot_min_x := INF
	var foot_max_x := -INF
	for st: float in samples:
		var f := _sample_pose(frames, st / step, loop)
		var rots := _frame_rotations(f)
		var local := {}
		for bone_name: String in tracks:
			local[bone_name] = _local_rotation(skeleton.find_bone(bone_name), rots[bone_name])
			anim.rotation_track_insert_key(tracks[bone_name], st, local[bone_name])
		if hips_idx >= 0:
			var feet := _feet_in_pose(local)
			var rest := skeleton.get_bone_rest(hips).origin
			var lift: float = f.get("lift", 0.0)
			var y := _ground_foot_y - feet.y + lift / _skeleton_scale()
			anim.position_track_insert_key(hips_idx, st, rest + Vector3(0, y, 0))
			foot_min_z = minf(foot_min_z, feet.z)
			foot_max_z = maxf(foot_max_z, feet.z)
			foot_min_x = minf(foot_min_x, feet.x)
			foot_max_x = maxf(foot_max_x, feet.x)
	_last_stride = maxf(foot_max_z - foot_min_z, foot_max_x - foot_min_x) * _skeleton_scale()
	_reset_pose()
	return anim


const FPS := 15.0
var _ground_foot_y := 0.0
var _last_stride := 0.0


## Pose interpolada en la posición `k` (en claves, 1.5 = mitad entre la 1 y la 2).
func _sample_pose(frames: Array, k: float, loop: bool) -> Dictionary:
	var n := frames.size()
	var i := floori(k)
	var u := k - i
	var a: Dictionary = frames[clampi(i, 0, n - 1) if not loop else posmod(i, n)]
	if u < 0.001 or (not loop and i >= n - 1):
		return a
	var b: Dictionary = frames[posmod(i + 1, n) if loop else mini(i + 1, n - 1)]
	var out := {}
	for key: String in a.keys() + b.keys():
		var d := 0.15 if key.begins_with("elbow") else 0.0
		out[key] = lerpf(a.get(key, d), b.get(key, d), u)
	return out


## Aplica la pose al esqueleto y devuelve (x, y, z) del pie más bajo en el
## espacio del esqueleto: y = altura mínima; x/z = posición del pie izquierdo
## (para medir la zancada).
func _feet_in_pose(local: Dictionary) -> Vector3:
	for bone_name: String in local:
		skeleton.set_bone_pose_rotation(skeleton.find_bone(bone_name), local[bone_name])
	var hips := skeleton.find_bone("mixamorig_Hips")
	if hips >= 0:
		skeleton.set_bone_pose_position(hips, skeleton.get_bone_rest(hips).origin)
	skeleton.force_update_all_bone_transforms()
	var lowest := INF
	for bn in ["mixamorig_LeftFoot", "mixamorig_RightFoot", "mixamorig_LeftToeBase", "mixamorig_RightToeBase",
			"mixamorig_LeftToe_End", "mixamorig_RightToe_End"]:
		var b := skeleton.find_bone(bn)
		if b >= 0:
			lowest = minf(lowest, skeleton.get_bone_global_pose(b).origin.y)
	var left := skeleton.find_bone("mixamorig_LeftFoot")
	var lp := skeleton.get_bone_global_pose(left).origin if left >= 0 else Vector3.ZERO
	return Vector3(lp.x, lowest, lp.z)


## Velocidad sin patinar de la última animación construida: el pie de apoyo
## recorre la zancada en medio ciclo.
func _record_stride(anim_name: String, length: float) -> void:
	stride_speed[anim_name] = 2.0 * _last_stride / length


func _reset_pose() -> void:
	for b in skeleton.get_bone_count():
		skeleton.set_bone_pose_rotation(b, skeleton.get_bone_rest(b).basis.get_rotation_quaternion())
		skeleton.set_bone_pose_position(b, skeleton.get_bone_rest(b).origin)


## Escala del esqueleto respecto al mundo (los FBX pueden venir en centímetros).
func _skeleton_scale() -> float:
	return skeleton.global_transform.basis.get_scale().y / global_transform.basis.get_scale().y
