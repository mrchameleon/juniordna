extends Node2D

@export var radii: Vector2 = Vector2(20, 30)
@export var fill_color: Color = Color.WHITE
@export var stroke_color: Color = Color.BLACK
@export var stroke_thickness: float = 3.0

func _draw():
	var points = PackedVector2Array()
	var segments = 32
	for i in range(segments):
		var angle = (TAU / segments) * i
		points.append(Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, fill_color)
	draw_arc(Vector2.ZERO, max(radii.x, radii.y), 0, TAU, segments, stroke_color, stroke_thickness)
