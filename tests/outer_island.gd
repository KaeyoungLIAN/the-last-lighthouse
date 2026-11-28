extends SceneTree
## High-water area survey and continuous keeper movement along every old and new trail.
const World := preload("res://world/world.gd")
const Player := preload("res://actors/player.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := World.new()
	root.add_child(world)
	world.set_conditions(1.0,1.0,false)
	var keeper := Player.new()
	keeper.world_ref = world
	root.add_child(keeper)
	keeper.set_physics_process(false)
	await physics_frame
	var square_metres := 0
	for z in range(-192,171,2):
		for x in range(-128,289,2):
			# Count the original island inside its surveyed shore; the six new
			# approaches and neighbouring landfalls now also enter this rectangle.
			var at := Vector2(x,z)
			if World.Survey.coast_distance(at)>=-.2 and not World.Survey.in_mirror_room(at) and world.is_walkable(x,z):
				square_metres += 4
	if square_metres < 13360 * 4.85 or square_metres > 13360 * 5.15:
		failures.append("High-water area %d" % square_metres)
	for id: String in World.Survey.REGION_NAMES:
		var p: Vector2 = World.POINTS[id]
		for j in 12:
			var q := p+Vector2.from_angle(TAU*j/12)*3.8
			if not world.is_walkable(q.x,q.y):
				failures.append("Blocked station %s %s" % [id,q])
	if not _river_reaches_sea(world):
		failures.append("Lake and eastern river mouth are disconnected at low tide")
	if world._surface_height(37,43)>=-.65:
		failures.append("Lighthouse inlet does not reach the cape")
	var routes := World.ROADS.duplicate()
	routes.append([World.POINTS.tower,Vector2(37,37)])
	for route: Array in routes:
		var start: Vector2 = route.front()
		keeper.position = world._point(start.x,start.y)
		for i in range(1,route.size()):
			var goal: Vector2 = route[i]
			var position_2d := Vector2(keeper.position.x,keeper.position.z)
			var budget := ceili(position_2d.distance_to(goal)*16.0)+55
			while position_2d.distance_to(goal)>.18 and budget>0:
				var dir := position_2d.direction_to(goal)
				keeper.velocity = Vector3(dir.x,0,dir.y)*6.8
				keeper._move_on_ground(1.0/60)
				position_2d = Vector2(keeper.position.x,keeper.position.z)
				budget -= 1
				await physics_frame
			if budget==0:
				failures.append("Blocked trail %s toward %s" % [position_2d,goal])
				break
	print("Survey at high tide: ",square_metres," sq m; six outer trailheads, all fifteen trails and the cape lookout.")
	for failure in failures:
		printerr("FAIL ",failure)
	keeper.free()
	world.free()
	quit(0 if failures.is_empty() else 1)

func _river_reaches_sea(world: World) -> bool:
	var queue: Array[Vector2i] = [Vector2i(World.RIVER.front())]
	var visited := {}
	var index := 0
	while index<queue.size():
		var p := queue[index]
		index += 1
		if World.Survey.coast_distance(Vector2(p)) < -5:
			return true
		for direction: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var q := p+direction
			if not visited.has(q):
				visited[q] = true
				if world._surface_height(q.x,q.y)<-.65:
					queue.append(q)
	return false
