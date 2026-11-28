extends Control
## North-up survey chart, shared by the field HUD and the island map.

const Island := preload("res://world/world.gd")
const Geo := preload("res://world/expedition_geography.gd")
const Voyage := preload("res://expedition_voyage.gd")
const CORE_NAMES := {"village":"灰湾村", "forest":"雾根林", "beach":"月牙滩", "lake":"镜湖", "volcano":"赤炉火山", "tower":"望潮岬"}
const SEA := Color("#193941")
const LAND := Color("#445d57")
const INK := Color("#9cb3a6")
const GOLD := Color("#f0c477")
var names := CORE_NAMES.merged(Island.Survey.REGION_NAMES)
var expanded := false
var regional_chart := false
var view: Dictionary = {}
var chart_rect := Rect2()
var world_rect := Island.Survey.CHART_BOUNDS
static var terrain_ink: ImageTexture
static var water_edges: Array[PackedVector2Array]

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
	if large:
		world_rect = Island.Survey.CHART_BOUNDS if regional_chart else Geo.BOUNDS
	else:
		var focus: Vector2 = pts.get("tower",Vector2.ZERO) if view.get("in_tower",false) else view.get("pos",Vector2.ZERO)
		var local_size := Vector2(125,125) * available / maxf(available.x,available.y)
		world_rect = Rect2(focus-local_size*.5,local_size)
	var scale_factor := minf(available.x/world_rect.size.x, available.y/world_rect.size.y)
	chart_rect.size = world_rect.size*scale_factor
	chart_rect.position = (size-chart_rect.size)*0.5
	var grid := 36 if large else 19
	for x in range(0,ceili(size.x),grid):
		draw_line(Vector2(x,0),Vector2(x,size.y),Color(0.73,0.84,0.79,0.07))
	for y in range(0,ceili(size.y),grid):
		draw_line(Vector2(0,y),Vector2(size.x,y),Color(0.73,0.84,0.79,0.07))
	_draw_expedition_land()
	_draw_island(pts)
	_draw_expedition_routes()
	var active_route: PackedVector2Array = view.get("walking_route",PackedVector2Array())
	if active_route.size()>1:
		var line:=PackedVector2Array()
		for v in active_route: line.append(project(v))
		draw_polyline(line,Color("443b32"),3.7,true)
		draw_polyline(line,Color("f5d393"),1.9,true)
	var known: Array = view.get("discovered",[])
	var occupied: Array[Rect2] = []
	for id: String in names:
		if large and not regional_chart and id not in ["village"]: continue
		if not pts.has(id) or (id != "village" and not known.has(id) and not known.has(names[id])):
			continue
		var p := project(pts[id])
		_draw_marker(p, id, 6.5 if large else 3.6)
		if large:
			var name_text: String = names[id]
			var font := get_theme_default_font()
			var label_size := 13
			var width := font.get_string_size(name_text,HORIZONTAL_ALIGNMENT_LEFT,-1,label_size).x
			var hero_pos: Vector2 = view.get("pos",Vector2.ZERO)
			if view.get("in_tower",false) and pts.has("tower"):
				hero_pos=pts.tower
			var left_of_player := project(hero_pos).x >= p.x
			if not regional_chart: left_of_player=false
			var sx := clampf(p.x-width-13 if left_of_player else p.x+13,3,size.x-width-3)
			var base := Vector2(sx,clampf(p.y+5,20,size.y-4))
			for dy: int in [0,-16,16,-32,32]:
				var candidate := Rect2(Vector2(sx-2,clampf(p.y-9+dy,2,size.y-18)),Vector2(width+4,16))
				var overlaps := false
				for other in occupied:
					if other.intersects(candidate):
						overlaps = true
						break
				if not overlaps:
					base = candidate.position+Vector2(2,13)
					occupied.append(candidate)
					break
			draw_string_outline(font,base,name_text,HORIZONTAL_ALIGNMENT_LEFT,-1,label_size,4,Color("#193239"))
			draw_string(font,base,name_text,HORIZONTAL_ALIGNMENT_LEFT,-1,label_size,Color("#fff5db"))
	_draw_commissions()
	var library_point=view.get("library_door")
	if library_point is Vector2 and world_rect.has_point(library_point):
		var book:=project(library_point)
		var glyph:=Vector2(6.,4.) if large else Vector2(4.,3.)
		draw_rect(Rect2(book-glyph-Vector2.ONE,glyph*2+Vector2.ONE*2),SEA)
		draw_rect(Rect2(book-glyph,glyph*2),Color("ffe3ad"))
		draw_line(book+Vector2(0,-glyph.y),book+Vector2(0,glyph.y),SEA,1.5)
		if large and regional_chart:
			draw_string_outline(get_theme_default_font(),book+Vector2(8,-8),"图书馆",HORIZONTAL_ALIGNMENT_LEFT,-1,14,4,SEA)
			draw_string(get_theme_default_font(),book+Vector2(8,-8),"图书馆",HORIZONTAL_ALIGNMENT_LEFT,-1,14,GOLD)
	var target = view.get("tracked_point")
	if target is Vector2 and world_rect.has_point(target):
		var goal:=project(target)
		draw_arc(goal,7.0 if expanded else 5.5,0,TAU,28,GOLD,1.8,true)

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

func _draw_expedition_land() -> void:
	if terrain_ink==null:
		terrain_ink=_paint_land()
		water_edges=Geo.inland_water_outlines()
	var area:=Rect2(project(Geo.BOUNDS.position),chart_rect.size*Geo.BOUNDS.size/world_rect.size)
	draw_texture_rect(terrain_ink,area,false)
	for water in water_edges:
		var edge:=PackedVector2Array()
		for point in water: edge.append(project(point))
		if edge.size()>2: draw_colored_polygon(edge,SEA)
	var lake:=_ellipse(Geo.LAKE_CENTER,Geo.LAKE_RADII)
	draw_colored_polygon(lake,SEA.lightened(.075))
	draw_polyline(lake,INK,1.,true)
	draw_colored_polygon(_ellipse(Geo.LAKE_ISLET,Vector2(7,6)),Color("9ca78a"))

static func _paint_land() -> ImageTexture:
	const WIDTH:=270
	const HEIGHT:=250
	var image:=Image.create(WIDTH,HEIGHT,false,Image.FORMAT_RGBA8)
	for y in HEIGHT:
		for x in WIDTH:
			var p:=Geo.BOUNDS.position+(Vector2(x+.5,y+.5)/Vector2(WIDTH,HEIGHT))*Geo.BOUNDS.size
			var coast:=Geo.mainland_distance(p)
			if coast< -2.: continue
			var mix_weights:=Geo.region_mix(p)
			var color:=Color(0,0,0,1)
			for id: String in mix_weights:
				var pigment:=LAND if id=="home" else LAND.lerp(Color(Voyage.COLORS.get(id,"91aa94")),.49)
				var weight:=float(mix_weights[id])
				color.r+=pigment.r*weight
				color.g+=pigment.g*weight
				color.b+=pigment.b*weight
			if coast<5.: color=color.lerp(INK,.68)
			image.set_pixel(x,y,color)
	return ImageTexture.create_from_image(image)

func _draw_expedition_routes() -> void:
	var font := get_theme_default_font()
	var overview := expanded and not regional_chart
	for road: Array in Geo.OUTER_ROUTES.values():
		var line:=PackedVector2Array()
		for point: Vector2 in road: line.append(project(point))
		draw_polyline(line,Color("c8b88c"),1.4,true)
	for id: String in Voyage.ORDER:
		var road: Array = Geo.ROUTES[id]
		var ink := Color(Voyage.COLORS[id])
		for i in range(1,road.size()):
			var a: Vector2 = road[i-1]
			var b: Vector2 = road[i]
			if world_rect.grow(55).has_point(a) or world_rect.grow(55).has_point(b):
				draw_line(project(a),project(b),ink.darkened(.18),1.55 if overview else 1.75,true)
		var camp: Vector2 = Geo.CAMPS[id]
		var arena: Vector2 = Geo.ARENAS[id]
		if world_rect.has_point(camp):
			var c := project(camp)
			var r := 3.3 if expanded else 3.
			draw_colored_polygon(PackedVector2Array([c+Vector2(0,-r*1.3),c+Vector2(-r,r),c+Vector2(r,r)]),Color("fff1c4"))
		if world_rect.has_point(arena):
			var p := project(arena)
			draw_circle(p,4.0,SEA)
			draw_arc(p,3.15,0,TAU,16,ink,1.65,true)
			if id in view.get("crests",[]): draw_circle(p,1.9,GOLD)
		if overview:
			var text: String = Voyage.NAMES[id]
			var width := font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x
			var offset := Vector2(-width*.5,-8) if id not in ["tide","lake"] else Vector2(-width*.5,17)
			var at := project(Geo.CENTERS[id])+offset
			_landmark(id,at+Vector2(width*.5,-23.),ink)
			draw_string_outline(font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,16,5,SEA)
			draw_string(font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("fff1db"))

func _landmark(id: String,c: Vector2,ink: Color) -> void:
	var shade:=ink.darkened(.28)
	match id:
		"snow","volcano":
			for i in 2:
				var p:=c+Vector2(-5+8*i,2-2*i)
				var top:=p+Vector2(0,-6-i*2)
				draw_colored_polygon(PackedVector2Array([p+Vector2(-8,5),top,p+Vector2(9,5)]),shade)
				draw_polyline(PackedVector2Array([p+Vector2(-8,5),top,p+Vector2(9,5)]),ink,1.3,true)
				if id=="snow": draw_line(top+Vector2(-2,2),top+Vector2(2.5,3.5),Color("eef0d6"),2.,true)
		"forest":
			for i in 3:
				var p:=c+Vector2((i-1)*5,2*abs(i-1))
				draw_colored_polygon(PackedVector2Array([p+Vector2(0,-7),p+Vector2(-5,3),p+Vector2(5,3)]),ink if i==1 else shade)
		"desert","tide":
			for i in 2:
				var points:=PackedVector2Array()
				for j in 13: points.append(c+Vector2(j*1.9-11,2.2*sin(j*.5+i)+i*4.))
				draw_polyline(points,ink,1.6,true)
		"lake":
			draw_rect(Rect2(c+Vector2(-3,-4),Vector2(6,9)),shade)
			draw_colored_polygon(PackedVector2Array([c+Vector2(-6,-4),c+Vector2(0,-9),c+Vector2(6,-4)]),ink)
			draw_line(c+Vector2(-9,6),c+Vector2(9,6),ink,1.,true)

func _draw_commissions() -> void:
	var targets: Dictionary = view.get("folk_targets",{})
	var ink := Color("#8fe4d2")
	var outline := Color("#17353b")
	for target: Dictionary in targets.values():
		var point := project(target.pos)
		var radius := 10.0 if expanded else 5.4
		draw_arc(point,radius,0,TAU,32,outline,4.6,true)
		draw_arc(point,radius,0,TAU,32,ink,2.1,true)
		if expanded:
			var font := get_theme_default_font()
			var origin := point+Vector2(7,-6)
			draw_circle(origin+Vector2(4,-4),7.0,outline)
			draw_string(font,origin,str(target.number),HORIZONTAL_ALIGNMENT_LEFT,-1,12,ink)

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
	var lake := _ellipse(Vector2(.5,-47.2),Vector2(18.3,10.2))
	draw_colored_polygon(lake,SEA)
	draw_polyline(lake,INK,1.0,true)
	var river := PackedVector2Array()
	var previous: Vector2 = Island.RIVER[0]
	for v: Vector2 in Island.RIVER:
		if Island.Survey.coast_distance(v)<=0:
			river.append(project(Island.Survey.coast_crossing(previous,v)))
			break
		river.append(project(v))
		previous = v
	draw_polyline(river,SEA,maxf(2,3.6*chart_rect.size.x/world_rect.size.x),true)
	var known: Array = view.get("discovered",[])
	for route: Array in Island.ROADS:
		for i in range(1,route.size()):
			var midpoint: Vector2 = (route[i-1]+route[i])*.5
			var seen := false
			for id: String in names:
				if pts.has(id) and (id == "village" or known.has(id)) and midpoint.distance_to(pts[id]) < 34.0:
					seen = true
					break
			var trail_color := Color("#c2ad82") if seen else Color("#718178")
			draw_line(project(route[i-1]),project(route[i]),trail_color,1.5 if expanded else 1.0,true)
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

