class_name WeaponFactory
extends RefCounted
## Armas low-poly hechas con cajas. El origen es el centro de la empuñadura y
## la hoja/mango apunta a +Y.

const STEEL := Color(0.72, 0.74, 0.78)
const DARK_STEEL := Color(0.42, 0.44, 0.48)
const WOOD := Color(0.42, 0.28, 0.16)
const LEATHER := Color(0.30, 0.18, 0.10)
const BRASS := Color(0.75, 0.58, 0.25)


static func build(kind: String) -> Node3D:
	var root := Node3D.new()
	root.name = kind.capitalize()
	match kind:
		"sword":
			_part(root, Vector3(0.035, 0.17, 0.035), Vector3(0, 0, 0), LEATHER)
			_part(root, Vector3(0.055, 0.05, 0.055), Vector3(0, -0.11, 0), BRASS)
			_part(root, Vector3(0.24, 0.035, 0.05), Vector3(0, 0.1, 0), BRASS)
			_part(root, Vector3(0.055, 0.74, 0.012), Vector3(0, 0.49, 0), STEEL)
			_part(root, Vector3(0.012, 0.62, 0.018), Vector3(0, 0.44, 0), DARK_STEEL)
			var tip := PrismMesh.new()
			tip.size = Vector3(0.055, 0.1, 0.012)
			_mesh(root, tip, Vector3(0, 0.91, 0), STEEL)
		"axe":
			_part(root, Vector3(0.04, 0.75, 0.04), Vector3(0, 0.25, 0), WOOD)
			_part(root, Vector3(0.05, 0.2, 0.025), Vector3(0.07, 0.55, 0), DARK_STEEL)
			_part(root, Vector3(0.05, 0.26, 0.02), Vector3(0.12, 0.55, 0), STEEL)
		"hammer":
			_part(root, Vector3(0.04, 0.55, 0.04), Vector3(0, 0.18, 0), WOOD)
			_part(root, Vector3(0.2, 0.09, 0.09), Vector3(0, 0.45, 0), DARK_STEEL)
	return root


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
