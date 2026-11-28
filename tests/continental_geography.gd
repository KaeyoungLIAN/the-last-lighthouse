extends SceneTree
## Full-keeper movement and flood-fill checks for the continuous mainland at high tide.
const Geo := preload("res://world/expedition_geography.gd")
const World := preload("res://world/world.gd")
const Keeper := preload("res://actors/player.gd")
var world := World.new()
var keeper := Keeper.new()
var failures: Array[String]=[]

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.add_child(world)
	world.set_conditions(.85,1.0,false)
	keeper.world_ref=world
	root.add_child(keeper)
	keeper.set_physics_process(false)
	await physics_frame
	_check_single_landmass()
	for id: String in Geo.ZONES:
		await _walk(id+" approach",Geo.ROUTES[id])
	for id: String in Geo.OUTER_ROUTES:
		var route: Array=Geo.OUTER_ROUTES[id]
		await _walk(id,route)
		# Walk parallel cross-country transects, independently of the marked trail.
		var middle:=floori(route.size()*.5)
		var a: Vector2=route[middle-1]
		var b: Vector2=route[middle+1]
		var side:=a.direction_to(b).orthogonal()
		for offset: float in [-24.0,24.0]:
			await _walk(id+" off-road "+str(offset),[a+side*offset,b+side*offset])
	for failure: String in failures:
		printerr("FAIL ",failure)
	print("Continental survey: six approaches, six adjoining trails, twelve cross-country passages; failures: ",failures.size())
	keeper.free()
	world.free()
	quit(1 if failures else 0)

func _check_single_landmass() -> void:
	const GRID:=6
	var land: Dictionary={}
	for z in range(-504,486,GRID):
		for x in range(-462,612,GRID):
			var p:=Vector2(x,z)
			if not World.Survey.in_mirror_room(p) and world.is_walkable(x,z):
				land[Vector2i(x,z)]=true
	var start:=Vector2i(-36,36)
	var seen:={start:true}
	var queue: Array[Vector2i]=[start]
	var index:=0
	while index<queue.size():
		var cell:=queue[index]
		index+=1
		for step: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next:=cell+step*GRID
			if land.has(next) and not seen.has(next):
				seen[next]=true
				queue.append(next)
	var covered:=float(seen.size())/maxi(1,land.size())
	print("Mainland flood fill at ",GRID," m spacing: ",seen.size()*GRID*GRID," m², ",snappedf(covered*100,.01),"% of walkable terrain")
	if covered<.985: failures.append("walkable land splits into disconnected masses")
	for id: String in Geo.CAMPS:
		var camp:=Vector2i((Vector2(Geo.CAMPS[id])/GRID).round())*GRID
		if not seen.has(camp): failures.append(id+" is unreachable from the village")
	for p: Vector2 in Geo.mainland_outline():
		if not Geo.BOUNDS.has_point(p):
			failures.append("coast outside chart: "+str(p))
			break
	var sequence: Array[String]=[]
	for z in range(-340,341,6):
		var id:=Geo.zone_at(Vector2(-266,z))
		if sequence.is_empty() or sequence.back()!=id: sequence.append(id)
	if sequence!=["snow","tide","volcano"]:
		failures.append("Western climatic sequence "+str(sequence))

func _walk(label: String,route: Array) -> void:
	var start: Vector2=route.front()
	keeper.position=world._point(start.x,start.y)
	for i in range(1,route.size()):
		var goal: Vector2=route[i]
		var here:=Vector2(keeper.position.x,keeper.position.z)
		var budget:=ceili(here.distance_to(goal)*13)+110
		while budget>0 and here.distance_to(goal)>.24:
			var dir:=here.direction_to(goal)
			keeper.velocity=Vector3(dir.x,0,dir.y)*7
			keeper._move_on_ground(1./60)
			here=Vector2(keeper.position.x,keeper.position.z)
			budget-=1
			await physics_frame
		if budget==0:
			failures.append(label+" blocked at "+str(here)+" toward "+str(goal))
			return
