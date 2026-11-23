extends Control
## North-up survey chart, shared by the field HUD and the island map.

const Island := preload("res://world/world.gd")
const NAMES := {"village":"灰湾村", "forest":"雾根林", "beach":"月牙滩", "lake":"镜湖", "volcano":"赤炉火山", "tower":"望潮岬"}
const SEA := Color("#193941")
const LAND := Color("#445d57")
const INK := Color("#9cb3a6")
const GOLD := Color("#f0c477")
var expanded := false
var view: Dictionary = {}
var chart_rect := Rect2()
var world_rect := Rect2(-87,-68,174,136)

func update_chart(data: Dictionary) -> void:
	view = data
	queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true

func project(p: Vector2) -> Vector2:
	return chart_rect.position + (p - world_rect.position) / world_rect.size * chart_rect.size

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),SEA)
	var pts: Dictionary = view.get("points",{})
	var large := expanded
	var margin := Vector2(30,27) if large else Vector2(10,8)
	var available := size-margin*2
	var scale_factor := minf(available.x/world_rect.size.x, available.y/world_rect.size.y)
	chart_rect.size = world_rect.size*scale_factor
	chart_rect.position = (size-chart_rect.size)*0.5
	var grid := 36 if large else 19
	for x in range(0,ceili(size.x),grid):
		draw_line(Vector2(x,0),Vector2(x,size.y),Color(0.73,0.84,0.79,0.07))
	for y in range(0,ceili(size.y),grid):
		draw_line(Vector2(0,y),Vector2(size.x,y),Color(0.73,0.84,0.79,0.07))
	_draw_island(pts)
	var known: Array = view.get("discovered",[])
	for id: String in NAMES:
		if not pts.has(id) or (id != "village" and not known.has(id) and not known.has(NAMES[id])):
			continue
		var p := project(pts[id])
		_draw_marker(p, id, 6.5 if large else 3.6)
		if large:
			var name_text: String = NAMES[id]
			var font := get_theme_default_font()
			var label_size := 15
			var width := font.get_string_size(name_text,HORIZONTAL_ALIGNMENT_LEFT,-1,label_size).x
			var hero_pos: Vector2 = view.get("pos",Vector2.ZERO)
			if view.get("in_tower",false) and pts.has("tower"):
				hero_pos=pts.tower
			var left_of_player := project(hero_pos).x >= p.x
			var sx := clampf(p.x-width-13 if left_of_player else p.x+13,3,size.x-width-3)
			var base := Vector2(sx,clampf(p.y+5,20,size.y-4))
			draw_string_outline(font,base,name_text,HORIZONTAL_ALIGNMENT_LEFT,-1,label_size,4,Color("#193239"))
			draw_string(font,base,name_text,HORIZONTAL_ALIGNMENT_LEFT,-1,label_size,Color("#fff5db"))
	var player_pos: Vector2 = view.get("pos",Vector2.ZERO)
	if bool(view.get("in_tower",false)) and pts.has("tower"):
		player_pos = pts.tower
	var tip := project(player_pos).clamp(Vector2(7,7),size-Vector2(7,7))
	var v: Vector2 = view.get("heading",Vector2.UP)
	if v.is_zero_approx():
		v=Vector2.UP
	var forward := v.normalized()
	var side := Vector2(-forward.y, forward.x)
	var rad := 8.0 if large else 5.5
	var arrow := PackedVector2Array([tip+forward*rad,tip-forward*rad*.7+side*rad*.65,tip-forward*rad*.3,tip-forward*rad*.7-side*rad*.65])
	draw_circle(tip,rad+2,Color("#18333a"))
	draw_colored_polygon(arrow,Color("#fff2b1"))
	draw_string(get_theme_default_font(),Vector2(8,18),"N",HORIZONTAL_ALIGNMENT_LEFT,-1,13,GOLD)
	if large:
		draw_line(Vector2(13,22),Vector2(13,36),GOLD,1.5)
		draw_line(Vector2(13,22),Vector2(10,27),GOLD,1.5)
		draw_line(Vector2(13,22),Vector2(16,27),GOLD,1.5)

func _draw_marker(p: Vector2, id: String, rad: float) -> void:
	draw_circle(p,rad+1.8,Color("#1c3233"))
	match id:
		"village":
			draw_colored_polygon(PackedVector2Array([p+Vector2(-rad,0),p+Vector2(0,-rad),p+Vector2(rad,0),p+Vector2(rad*.7,rad*.8),p+Vector2(-rad*.7,rad*.8)]),Color("#dce5d3"))
		"tower":
			draw_colored_polygon(PackedVector2Array([p+Vector2(0,-rad),p+Vector2(rad,rad),p+Vector2(-rad,rad)]),Color("#f3ca83"))
		"forest":
			draw_circle(p,rad,Color("#cdd4aa"))
		_:
			draw_colored_polygon(PackedVector2Array([p+Vector2(0,-rad),p+Vector2(rad,0),p+Vector2(0,rad),p+Vector2(-rad,0)]),Color("#c7dad7"))

func _ellipse(center: Vector2, radii: Vector2) -> PackedVector2Array:
	var ring := PackedVector2Array()
	for i in 65:
		var angle := float(i)/64.0*TAU
		ring.append(project(center+Vector2(cos(angle),sin(angle))*radii))
	return ring

func _draw_island(pts: Dictionary) -> void:
	var shore := PackedVector2Array()
	for i in 97:
		var angle := float(i)/96.0*TAU
		var r := 1.0 + .038*sin(5.0*angle+1.2) + .026*cos(9.0*angle)
		shore.append(project(Vector2(cos(angle)*82.0,sin(angle)*64.0)*r))
	var inlet := _ellipse(Vector2(-73,16),Vector2(28,9.6))
	var coast := Geometry2D.clip_polygons(shore,inlet)
	for polygon in coast:
		draw_colored_polygon(polygon,LAND)
		polygon.append(polygon[0])
		draw_polyline(polygon,INK,1.5 if expanded else 1.0,true)
	if expanded:
		var center := project(Vector2.ZERO)
		for k in [1.05,1.10]:
			var surf := PackedVector2Array()
			for p in shore:
				surf.append(center+(p-center)*float(k))
			draw_polyline(surf,Color(0.58,0.72,0.71,0.18),1.2,true)
	var lake := _ellipse(Vector2(.5,-47.2),Vector2(18.3,10.2))
	draw_colored_polygon(lake,SEA)
	draw_polyline(lake,INK,1.0,true)
	var river := PackedVector2Array()
	for v: Vector2 in Island.RIVER:
		river.append(project(v))
	draw_polyline(river,SEA,maxf(2,3.6*chart_rect.size.x/world_rect.size.x),true)
	var known: Array = view.get("discovered",[])
	for route: Array in Island.ROADS:
		for i in range(1,route.size()):
			var midpoint: Vector2 = (route[i-1]+route[i])*.5
			var seen := false
			for id: String in NAMES:
				if pts.has(id) and (id == "village" or known.has(id)) and midpoint.distance_to(pts[id]) < 34.0:
					seen = true
					break
			if seen:
				draw_line(project(route[i-1]),project(route[i]),Color("#aa9f7b"),1.5 if expanded else 1.0,true)
	if known.has("beach"):
		var low := str(view.get("tide","")).contains("低")
		for i in range(1,Island.TIDAL_TRACK.size()):
			draw_dashed_line(project(Island.TIDAL_TRACK[i-1]),project(Island.TIDAL_TRACK[i]),GOLD if low else Color("#7a9a98"),1.5,4.0)
	if expanded:
		if known.has("forest"):
			for tree in [Vector2(-45,-24),Vector2(-40,-26),Vector2(-38,-22),Vector2(-53,-12),Vector2(-21,-31),Vector2(-25,-28)]:
				var t := project(tree)
				draw_polyline(PackedVector2Array([t+Vector2(-3,2),t+Vector2(0,-4),t+Vector2(3,2)]),INK,1.3,true)
		if known.has("village") and pts.has("village"):
			for offset in [Vector2(4,8),Vector2(8,10),Vector2(10,6)]:
				draw_rect(Rect2(project(pts.village+offset),Vector2(5,3)),INK)
	if expanded and known.has("volcano"):
		for radius in [6,10,14]:
			draw_polyline(_ellipse(Vector2(52,-49),Vector2(radius,radius*.72)),Color("#9b8f71"),1.0,true)

