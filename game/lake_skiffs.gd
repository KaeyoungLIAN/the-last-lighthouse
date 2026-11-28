extends Node3D
## Three landing stages share a small clinker-built rowing skiff.
const Geo := preload("res://world/expedition_geography.gd")
const Art := preload("res://actors/actor_art.gd")
const PREFIX := "lake_jetty_"
const NAMES := ["西岸苇渡","南岸钟阶","东岸浮标","旧钟楼"]
var afloat := false
var origin := 0
var heading := 0.
var speed := 0.
var stroke := 0.
var boat_position := Vector2.ZERO
var craft: Array[Node3D] = []
var oars: Array = []

func build(game) -> void:
	for i in NAMES.size():
		var landing: Vector2=Geo.LAKE_LANDINGS[i] if i<3 else Geo.LAKE_ISLET+Vector2(-3.1,1.8)
		game._add_site(PREFIX+str(i),NAMES[i]+" · 借舟",landing)
		var model := Node3D.new()
		add_child(model)
		model.position = _water_point(_mooring(i))
		model.rotation.y = _bearing(Geo.LAKE_CENTER-_mooring(i))
		craft.append(model)
		_make_hull(model)
		var pair := []
		for side: float in [-1.,1.]:
			var joint := Art.joint(model,Vector3(.51*side,.48,-.04))
			Art.rod(joint,Vector3(-.18*side,.02,0),Vector3(1.13*side,-.27,.12),.035,.043,"b5915c")
			var paddle := Art.oval(joint,Vector3(1.16*side,-.28,.13),Vector3(.44,.095,.17),"bc8756")
			paddle.rotation.z = -.21*side
			pair.append(joint)
		oars.append(pair)

func _make_hull(boat: Node3D) -> void:
	boat.add_child(preload("res://art/greybay/rowing_skiff.glb").instantiate())

func _water_point(p: Vector2) -> Vector3:
	return Vector3(p.x,Geo.LAKE_LEVEL,p.y)

func _mooring(i: int) -> Vector2:
	if i==3: return Geo.LAKE_ISLET+Vector2(-8.5,4.8)
	var shore: Vector2 = Geo.LAKE_LANDINGS[i]
	var inside: Vector2 = Geo.LAKE_BEACONS[i]
	var p := shore
	for step in range(1,30):
		p = shore.lerp(inside,step/30.)
		if Geo.lake_distance(p)<-1.5: break
	return p

func _bearing(direction: Vector2) -> float:
	return atan2(-direction.x,-direction.y)

func board(i: int,game) -> void:
	if i<0 or i>=craft.size() or afloat: return
	afloat=true
	origin=i
	speed=0.
	boat_position=_mooring(i)
	heading=_bearing(Geo.LAKE_CENTER-boat_position)
	game.hero.cancel_draw()
	game.hero.input_enabled=false
	game.hero.camera_yaw=heading
	_seat(game)
	game._notice("W 划桨，A / D 掌舵；靠近岸边钟桩按 E 下船。","switch")

func _seat(game) -> void:
	var model:=craft[origin]
	model.position=_water_point(boat_position)+Vector3.UP*(.036*sin(stroke))
	model.rotation=Vector3(.015*cos(stroke),heading,.016*sin(stroke))
	game.hero.position=model.position+Vector3.UP*.22
	game.hero.model.rotation.y=heading

func step(delta: float,game) -> void:
	if not afloat: return
	var steering := float(Input.is_physical_key_pressed(KEY_A))-float(Input.is_physical_key_pressed(KEY_D))
	var rowing := Input.is_physical_key_pressed(KEY_W)
	heading+=steering*delta*1.36
	speed=move_toward(speed,5.3 if rowing else 0.,delta*(2.4 if rowing else 1.8))
	var next:=boat_position+Vector2(-sin(heading),-cos(heading))*speed*delta
	if Geo.lake_distance(next)<-.65 and next.distance_squared_to(Geo.LAKE_ISLET)>8.1*8.1: boat_position=next
	else: speed=0.
	stroke+=delta*(3.5 if rowing else .9)
	for i in 2:
		var joint: Node3D=oars[origin][i]
		joint.rotation.y=sin(stroke)*(.43 if rowing else .06)*(1 if i==0 else -1)
		joint.rotation.z=cos(stroke)*(.12 if rowing else .03)
	game.hero.camera_yaw=lerp_angle(game.hero.camera_yaw,heading,1.-exp(-2.8*delta))
	_seat(game)

func closest_landing() -> int:
	var closest:=origin
	for i in craft.size():
		if _mooring(i).distance_squared_to(boat_position)<_mooring(closest).distance_squared_to(boat_position): closest=i
	return closest

func can_land() -> bool:
	return afloat and _mooring(closest_landing()).distance_to(boat_position)<8.

func disembark(game) -> void:
	if not can_land(): return
	var index:=closest_landing()
	reset()
	game.hero.input_enabled=true
	game._place_hero(game.sites[PREFIX+str(index)])
	game._notice("已系好缆绳 · "+NAMES[index],"start")
	if index==3 and not game.taken.has("lake_soundings"):
		game.taken.append("lake_soundings")
		game.hero.oil=minf(40.,game.hero.oil+12.)
		game._notice("旧钟楼的箱子里有灯油。你把钟上的图案印进了记事本。","chime")
	game._save()

func reset() -> void:
	if afloat:
		craft[origin].position=_water_point(_mooring(origin))
		craft[origin].rotation=Vector3(0,_bearing(Geo.LAKE_CENTER-_mooring(origin)),0)
		for joint: Node3D in oars[origin]: joint.rotation=Vector3.ZERO
	afloat=false
