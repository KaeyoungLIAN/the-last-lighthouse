extends SceneTree
## Exercises the public travel UI, lake save recovery and additive v0.3.5 migration.
const Game := preload("res://main.gd")
const Geo := preload("res://world/expedition_geography.gd")
var game
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool,label: String) -> void:
	if not ok:
		failures+=1
		printerr("FAIL ",label)

func interact() -> void:
	var key:=InputEventKey.new()
	key.keycode=KEY_E
	key.physical_keycode=KEY_E
	key.pressed=true
	game._unhandled_input(key)

func _run() -> void:
	game=Game.new()
	game.journal.path=OS.get_temp_dir().path_join("expedition-travel-%s.cfg" % OS.get_process_id())
	root.add_child(game)
	await physics_frame
	game.hud.action.emit("start")
	game.hud.action.emit("prologue_skip")
	for id: String in game.voyage.ORDER:
		game._place_hero(game.sites[game.voyage.DESK])
		interact()
		check(game.screen=="expedition","open departure chart")
		game.hud.action.emit("expedition/"+id)
		check(game.screen=="play" and game.trails.pin==game.trails.CREST+id and game.hud.state.tracked_point==Geo.ARENAS[id],"mark the chosen boss in "+id)
		check(Vector2(game.hero.position.x,game.hero.position.z).distance_to(game.voyage.HOME)<1.5,"chart must not move player")
		check(game.hud.state.walking_route.size()>5,"connected route to "+id)
		game._place_hero(Geo.ENTRANCES[id])
		game._discover()
		check(game.discovered.has("exp_"+id),"charted "+id)
		for stop: Dictionary in [Geo.ENTRANCES,Geo.CAMPS,Geo.HUNTS,Geo.ARENAS]:
			var p: Vector2=stop[id]
			check(game.world.is_walkable(p.x,p.y),"walkable "+id+" "+str(p))
		game._process(.2)
		var before: float=game.survival.water
		game._show("map")
		game._process(6.)
		check(is_equal_approx(game.survival.water,before),"map freezes metabolism")
		game.hud.action.emit("fieldguide")
		check(game.hud.state.guide_rows.size()==6,"six wildlife entries")
		for caption: String in ["标出猎场","追踪首领"]:
			var choices: Array = game.hud.menu_buttons.filter(func(b: Button): return b.text==caption)
			check(choices.size()==game.voyage.ORDER.size(),"one "+caption+" choice per region")
			if choices.size()!=game.voyage.ORDER.size(): continue
			var choice: Button = choices[game.voyage.ORDER.find(id)]
			check(not choice.disabled,"available "+caption+" in "+id)
			choice.pressed.emit()
			var target: Vector2 = Geo.HUNTS[id] if caption=="标出猎场" else Geo.ARENAS[id]
			check(game.screen=="play" and game.trails.destination(game)==target,"guide pin "+caption+" in "+id)
			if caption=="标出猎场":
				game.hud.action.emit("map")
				game.hud.action.emit("fieldguide")
		game._place_hero(game.sites["trailcamp_"+id])
		game.hero.arrows=2
		interact()
		check(game.screen=="expedition" and game.hero.arrows==12,"camp supplies")
		game.hud.action.emit("expedition/home")
		check(game.screen=="play" and game.trails.pin=="home" and game._expedition_zone()==id,"mark way home without leaving camp "+id)
	game._place_hero(game.sites.lake_jetty_0)
	interact()
	check(game.ferry.afloat,"board from shore")
	game.ferry.boat_position=game.ferry._mooring(2)
	game.ferry.step(.016,game)
	game._safe_shore()
	check(game.ferry.afloat and game.ferry.can_land(),"row to east quay")
	game._save()
	game._restore()
	check(not game.ferry.afloat and Vector2(game.hero.position.x,game.hero.position.z).distance_to(game.sites.lake_jetty_2)<1.5,"lake save returns to a real quay")
	interact()
	check(game.ferry.afloat,"can borrow another skiff")
	interact()
	check(not game.ferry.afloat and game.hero.input_enabled,"leave skiff via E")
	var old: Dictionary=game.journal.read()
	for key: String in ["survival","bow","arrows","crests","hunted_today"]: old.erase(key)
	old.taken=["forest","winch","beach"]
	game.journal.write(old)
	game._restore()
	check(game.hero.arrows==12 and game.crests.is_empty() and game.survival.water==100 and game.taken.has("beach"),"V5 inventory migration")
	for suffix: String in ["",".bak"]:
		if FileAccess.file_exists(game.journal.path+suffix):
			DirAccess.remove_absolute(game.journal.path+suffix)
	print("Expedition travel: six on-foot routes, stops, pause, lake skiffs, old journal. Failures: ",failures)
	game.free()
	quit(1 if failures else 0)
