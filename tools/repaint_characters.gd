extends SceneTree
## Herramienta: genera las texturas medievales de los personajes PSX.
##
##   godot --headless --path . -s tools/repaint_characters.gd
##
## Si pones las texturas originales junto a los FBX (assets/characters/Character_0X.png)
## se conservan las caras y los pliegues de la ropa; si no, se pinta todo proceduralmente.
## Resultado: assets/characters/textures/Character_0X_<atuendo>.png

## [modelo, atuendo]. Un mismo modelo puede tener varios atuendos.
const CAST := [
	["Character_01", "henry"],
	["Character_02", "herrero"],
	["Character_03", "cura"],
	["Character_04", "guardia"],
	["Character_05", "campesino"],
	["Character_05", "bandido"],
	["Character_03", "bandido"],
	["Character_04", "jefe"],
	["Character_02", "molinero"],
	["Character_05", "minero"],
	["Character_03", "pastor"],
	["Character_34_Female", "aldeana"],
	["Character_36_Female", "mercadera"],
	["Character_38_Female", "granjera"],
	["Character_Male_33", "bandido"],
	["Character_Male_35", "bandido"],
	["Character_Male_38", "campesino"],
]


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/characters/textures"))
	for entry: Array in CAST:
		_repaint(entry[0], entry[1])
	quit()


func _repaint(model: String, outfit: String) -> void:
	var path := "res://assets/characters/%s.fbx" % model
	if not ResourceLoader.exists(path):
		push_warning("No existe " + path)
		return
	var rig: Node = (load(path) as PackedScene).instantiate()
	var skeleton := rig.find_child("Skeleton3D", true, false) as Skeleton3D
	var original: Image = null
	var original_path := "res://assets/characters/%s.png" % model
	if FileAccess.file_exists(original_path):
		original = Image.load_from_file(ProjectSettings.globalize_path(original_path))
	for mi: MeshInstance3D in rig.find_children("*", "MeshInstance3D", true, false):
		var img := CharacterRepaint.generate(mi, skeleton, CharacterRepaint.OUTFITS[outfit], original)
		var out := "res://assets/characters/textures/%s_%s.png" % [model, outfit]
		img.save_png(ProjectSettings.globalize_path(out))
		print("Repintado %s -> %s (%s)" % [model, out, "con original" if original else "procedural"])
	rig.free()
