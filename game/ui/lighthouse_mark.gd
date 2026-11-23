extends Control
## Lighthouse and rotating optic motif on the main menu.
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	custom_minimum_size=Vector2(80,54)

func _draw() -> void:
	var ink:=Color("#e5c990")
	var tint:=Color(0.92,0.79,0.51,0.43)
	draw_arc(Vector2(30,26),22,PI*.84,PI*2.16,48,tint,1.2,true)
	draw_colored_polygon(PackedVector2Array([Vector2(26,23),Vector2(34,23),Vector2(38,44),Vector2(22,44)]),ink)
	draw_rect(Rect2(24,17,12,6),ink,false,1.4)
	draw_polyline(PackedVector2Array([Vector2(22,16),Vector2(30,11),Vector2(38,16),Vector2(22,16)]),ink,1.5,true)
	draw_line(Vector2(30,11),Vector2(30,8),ink,1.3)
	draw_line(Vector2(38,18),Vector2(72,11),tint,1.0)
	draw_line(Vector2(38,20),Vector2(72,23),tint,1.0)
	draw_line(Vector2(22,18),Vector2(1,14),tint,1.0)
	draw_line(Vector2(21,47),Vector2(40,47),ink,1.3)
