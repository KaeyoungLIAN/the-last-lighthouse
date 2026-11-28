extends SceneTree
## Follow the animals on their own terrain, then cast with the player's E input.
const Main=preload("res://main.gd")
const Geo=preload("res://world/expedition_geography.gd")
var game=Main.new()
var events: Array[String]=[]
var errors: Array[String]=[]

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool,note: String) -> void:
	if not ok:
		errors.append(note)
		printerr("FAIL ",note)

func interact() -> void:
	var key:=InputEventKey.new()
	key.keycode=KEY_E
	key.pressed=true
	game._unhandled_input(key)

func approach(beast) -> bool:
	var at: Vector2=Vector2(beast.position.x,beast.position.z)
	for i in 16:
		var p:=at+Vector2.from_angle(i*TAU/16)*3.54
		if not game.world.is_walkable(p.x,p.y): continue
		game._place_hero(p)
		game._nearest()
		if game.near_site.is_empty() and not game.wilds.net_prompt().is_empty():
			return true
	return false

func run() -> void:
	var path:=OS.get_temp_dir().path_join("field-net-%s.cfg" % OS.get_process_id())
	game.journal.path=path
	root.add_child(game)
	game._on_action("start")
	game._on_action("prologue_skip")
	game.set_process(false)
	game.hero.set_physics_process(false)
	var wilds=game.wilds
	wilds.net_cast.connect(func(caught): events.append("cast" if caught else "miss"))
	wilds.captured.connect(func(id): events.append("net/"+id))
	wilds.harvested.connect(func(id): events.append("food/"+id))
	await physics_frame
	var day:int=game._day_index()
	for id: String in Geo.HUNTS:
		game._place_hero(Geo.HUNTS[id])
		wilds.tick(day,true)
		var beast=wilds.prey[id]
		beast.set_physics_process(false)
		check(approach(beast),"walkable bank or verge to observe "+id)
		beast.phase=0.0
		var dt:=1./60.
		var saw_wait:=false
		var saw_window:=false
		var prior:int=events.size()
		game.survival.rations=1
		for i in 700:
			beast._physics_process(dt)
			wilds._physics_process(dt)
			if not approach(beast): continue
			if not saw_wait and not beast.net_window():
				interact()
				interact()
				check(events.slice(prior)==["miss"],"early and immediate repeated throw "+id)
				check(not game.hunted_today.has(id),"miss gives no reward "+id)
				saw_wait=true
			elif saw_wait and beast.net_window() and wilds._net_recovery<=0.:
				check(wilds.net_prompt().contains("现在下网"),"visible opportunity "+id)
				interact()
				saw_window=true
				break
		check(saw_wait and saw_window,"natural observation cycle "+id)
		check(events.slice(prior)==["miss","cast","net/"+id,"food/"+id],"one cast and one harvest "+id)
		check(game.taken.has("capture_"+id) and game.hunted_today.get(id,-1)==day,"capture recorded "+id)
		check(game.survival.rations==2,"field ration from "+id)
		if saw_window and is_instance_valid(beast):
			check(beast.collision_layer==0 and not beast.is_in_group("expedition_prey"),"scoop disables hit target "+id)
			if id=="snow":
				for step in 28: await physics_frame
				check(not is_instance_valid(beast),"scoop animation ends after one catch")
		wilds.tick(day,true)
		check(not wilds.prey.has(id),"no second animal on the same day "+id)
		# A second region is a new encounter after the previous throw has been retrieved.
		wilds._physics_process(1.)

	game._place_hero(game.sites[game.voyage.DESK])
	game._interact(game.voyage.DESK)
	game._on_action("village_cook")
	check(game.taken.has("village_taste_snow"),"cook netted game at the village table")
	game._on_action("resume")
	game._save()
	game._on_action("continue")
	for id: String in Geo.HUNTS:
		check(game.taken.has("capture_"+id) and game.hunted_today.get(id,-1)==day,"restore "+id)

	game._place_hero(Geo.HUNTS.lake)
	wilds.tick(day+1,true)
	var fish=wilds.prey.lake
	fish.set_physics_process(false)
	check(approach(fish),"next day's fish returns")
	var bank:Vector3=game.hero.global_position
	var wall:=StaticBody3D.new()
	var collision:=CollisionShape3D.new()
	var slab:=BoxShape3D.new()
	slab.size=Vector3(2.0,4.,2.0)
	collision.shape=slab
	wall.add_child(collision)
	root.add_child(wall)
	wall.position=(bank+fish.global_position)*.5+Vector3.UP
	await physics_frame
	check(wilds.net_prompt().is_empty() and not wilds.cast_net(),"cannot cast through rock")
	wall.free()
	game._place_hero(Geo.HUNTS.lake+Vector2(8.,0))
	check(wilds.net_prompt().is_empty() and not wilds.cast_net(),"cannot net beyond reach")
	var prior:=events.size()
	fish.receive_hit(100.)
	check(events.slice(prior)==["food/lake"],"weapon harvest does not credit a net catch")

	game.free()
	for ext in ["",".bak",".tmp"]:
		if FileAccess.file_exists(path+ext): DirAccess.remove_absolute(path+ext)
	if errors.is_empty(): print("PASS six field captures, timing, reach, occlusion, journal, daily yield and village table")
	quit(0 if errors.is_empty() else 1)
