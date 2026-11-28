extends SceneTree
## Isolate weapon input and hit geometry on a level field; real terrain has its own traversal tests.
const Keeper = preload("res://actors/player.gd")
const Encounters = preload("res://expedition_encounters.gd")
const Geo = preload("res://world/expedition_geography.gd")
const DT := 1.0/60.0

class Field:
	extends Node3D
	func ground_height(_x: float,_z: float) -> float: return 0.0
	func is_walkable(_x: float,_z: float) -> bool: return true

var hero := Keeper.new()
var wilds := Encounters.new()
var ground := Field.new()
var crests: Array = []
var catches: Array = []
var errors: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func expect(ok: bool,note: String) -> void:
	if not ok:
		errors.append(note)
		printerr("FAIL ",note)

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	hero._unhandled_input(event)

func mouse(pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	hero._unhandled_input(event)

func place(point: Vector2) -> void:
	hero.global_position = Vector3(point.x,0,point.y)
	hero.reset_combat()
	hero.camera_yaw = 0
	hero._place_camera(5.25)

func shoot(target,aim_height: float) -> void:
	mouse(true)
	for i in 45: await physics_frame
	hero.camera.look_at(target.global_position+Vector3.UP*aim_height)
	mouse(false)
	for i in 30: await physics_frame

func run() -> void:
	root.add_child(ground)
	root.add_child(hero)
	root.add_child(wilds)
	hero.world_ref = ground
	wilds.build(hero,ground,Geo.CAMPS)
	wilds.crest_earned.connect(func(id): crests.append(id))
	wilds.harvested.connect(func(id): catches.append(id))
	wilds.restore([],{},2)
	await physics_frame
	for id: String in Encounters.GUIDE:
		place(Geo.HUNTS[id]+Vector2(0,9))
		wilds.tick(2,true)
		key(KEY_2)
		await physics_frame
		await shoot(wilds.prey[id],.38)
		expect(catches.count(id)==1,"draw, release and harvest "+id)

		place(Geo.ARENAS[id]+Vector2(0,3))
		wilds.tick(2,true)
		var beast = wilds.bosses[id]
		beast.set_physics_process(false)
		beast._engaged = true
		beast._begin(Vector3.BACK)
		expect(beast.mark.visible,"telegraph "+id)
		var life := hero.hp
		hero.position = beast.home+Vector3.RIGHT*13.0
		for i in 190: beast._physics_process(DT)
		expect(hero.hp==life,"escaped the locked attack "+id)
		beast._begin(Vector3.BACK)
		beast.time_left = 0
		beast._physics_process(DT)
		beast.time_left = 0
		beast._physics_process(DT)
		expect(beast.exposed and not beast.mark.visible,"vulnerability after strike "+id)
		place(Vector2(beast.global_position.x,beast.global_position.z+1.45))
		key(KEY_1)
		await physics_frame
		for cut in 6:
			mouse(true)
			for i in (44 if cut%3==2 else 28): await physics_frame
			if not is_instance_valid(beast): break
		expect(crests.count(id)==1 and not wilds.bosses.has(id),"melee and first-kill crest "+id)

	wilds.restore([],{},3)
	for id: String in Encounters.GUIDE:
		place(Geo.ARENAS[id]+Vector2(0,9))
		wilds.tick(3,true)
		var beast = wilds.bosses[id]
		beast.set_physics_process(false)
		beast.exposed = true
		hero.arrows = hero.QUIVER
		key(KEY_2)
		await physics_frame
		for i in 6:
			await shoot(beast,.9)
			if not is_instance_valid(beast): break
		expect(not wilds.bosses.has(id) and hero.arrows>=6,"bow-only weak point "+id)

	wilds.restore(crests,{"lake":3},3)
	place(Geo.ARENAS.lake)
	wilds.tick(3,true)
	expect(not wilds.bosses.has("lake"),"recorded first kill survives reload")
	place(Geo.HUNTS.lake)
	wilds.tick(3,true)
	expect(not wilds.prey.has("lake"),"daily catch survives reload")
	wilds.tick(4,true)
	wilds.prey.lake.phase = .5
	expect(wilds.cast_net(),"fresh day fish net from bank")
	var arrows := hero.arrows
	mouse(true)
	await physics_frame
	key(KEY_SPACE)
	mouse(false)
	await physics_frame
	expect(not hero.drawing and hero.arrows==arrows,"dodge cancels draw without using ammunition")
	wilds.free()
	hero.free()
	ground.free()
	if errors.is_empty():
		print("PASS six prey, six boss warnings and openings, melee and bow first kills, crest restore, net and dodge cancellation")
	quit(0 if errors.is_empty() else 1)
