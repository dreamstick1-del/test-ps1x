extends Control
## Minimapa 2D del diorama: dibuja las huellas registradas por DioramaWorld y
## una flecha con la posición y orientación de Henry.

const WORLD_SIZE := 36.0

var _world: DioramaWorld
var _player: Node3D


func _ready() -> void:
	custom_minimum_size = Vector2(64, 64)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	if _world == null:
		_world = get_tree().get_first_node_in_group("diorama_world") as DioramaWorld
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node3D
	queue_redraw()


func _to_map(p: Vector2) -> Vector2:
	return (p / WORLD_SIZE + Vector2(0.5, 0.5)) * size


func _draw() -> void:
	var s := size / WORLD_SIZE
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.24, 0.36, 0.18))
	if _world:
		for f: Dictionary in _world.map_features:
			var center := _to_map(f.pos)
			if f.get("round", false):
				draw_circle(center, maxf(f.size.x * s.x * 0.4, 1.0), f.color)
				continue
			# Rotación en Y del mundo = rotación -rot en el plano (x, z) del mapa.
			draw_set_transform(center, -f.rot, Vector2.ONE)
			var half: Vector2 = f.size * s * 0.5
			draw_rect(Rect2(-half, half * 2.0), f.color)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _player:
		var pos := _to_map(Vector2(_player.global_position.x, _player.global_position.z))
		var fwd3 := -_player.global_transform.basis.z
		var fwd := Vector2(fwd3.x, fwd3.z).normalized()
		var right := Vector2(-fwd.y, fwd.x)
		var tri := PackedVector2Array([pos + fwd * 4.0, pos - fwd * 2.5 + right * 2.5, pos - fwd * 2.5 - right * 2.5])
		draw_colored_polygon(tri, Color(1.0, 0.85, 0.2))
	draw_rect(Rect2(Vector2.ZERO, size), PS1Theme.BORDER, false, 1.0)
	draw_string(ThemeDB.fallback_font, Vector2(size.x * 0.5 - 3, 9), "N",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE)
