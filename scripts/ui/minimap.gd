extends Control
## Minimapa centrado en Henry (ventana de VIEW metros, norte arriba):
## río y caminos (map_lines), edificios, árboles y campos (map_features).

const VIEW := 40.0

var _world: DioramaWorld
var _player: Node3D
var _center := Vector2.ZERO


func _ready() -> void:
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(64, 64)
	size = custom_minimum_size
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	if _world == null:
		_world = get_tree().get_first_node_in_group("diorama_world") as DioramaWorld
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node3D
	queue_redraw()


func _to_map(p: Vector2) -> Vector2:
	return (p - _center) / VIEW * size + size * 0.5


func _draw() -> void:
	var s := size / VIEW
	if _player:
		_center = Vector2(_player.global_position.x, _player.global_position.z)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.24, 0.36, 0.18))
	if _world:
		var view := Rect2(_center - Vector2.ONE * VIEW * 0.6, Vector2.ONE * VIEW * 1.2)
		for line: Dictionary in _world.map_lines:
			var pts := PackedVector2Array()
			for p: Vector2 in line.points:
				pts.append(_to_map(p))
			draw_polyline(pts, line.color, maxf(line.width * s.x, 1.0))
		for f: Dictionary in _world.map_features:
			if not view.has_point(f.pos):
				continue
			var center := _to_map(f.pos)
			if f.get("round", false):
				draw_circle(center, maxf(f.size.x * s.x * 0.4, 1.0), f.color)
				continue
			# Rotación en Y del mundo = rotación -rot en el plano (x, z) del mapa.
			draw_set_transform(center, -f.rot, Vector2.ONE)
			var half: Vector2 = f.size * s * 0.5
			draw_rect(Rect2(-half, half * 2.0), f.color)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# Borde de la maqueta.
		var edge := DioramaWorld.WORLD_HALF
		draw_rect(Rect2(_to_map(Vector2(-edge, -edge)), Vector2.ONE * edge * 2.0 * s.x), Color(0.35, 0.22, 0.12), false, 2.0)
	if _player:
		var pos := size * 0.5
		var fwd3 := -_player.global_transform.basis.z
		var fwd := Vector2(fwd3.x, fwd3.z).normalized()
		var right := Vector2(-fwd.y, fwd.x)
		var tri := PackedVector2Array([pos + fwd * 4.0, pos - fwd * 2.5 + right * 2.5, pos - fwd * 2.5 - right * 2.5])
		draw_colored_polygon(tri, Color(1.0, 0.85, 0.2))
	draw_rect(Rect2(Vector2.ZERO, size), PS1Theme.BORDER, false, 1.0)
	draw_string(ThemeDB.fallback_font, Vector2(size.x * 0.5 - 3, 9), "N",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE)
