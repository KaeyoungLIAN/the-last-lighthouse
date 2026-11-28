extends SceneTree
## Exercise the normal E interaction, champion death signals and journal. Warps skip the walks.
const Game = preload("res://main.gd")
var game
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr("FAIL ",message)

func visit(id: String) -> void:
	game._place_hero(game.sites[id])
	var keypress := InputEventKey.new()
	keypress.keycode = KEY_E
	keypress.physical_keycode = KEY_E
	keypress.pressed = true
	game._unhandled_input(keypress)

func collect(id: String) -> void:
	if id == "beach": visit("winch")
	if id == "lake": visit("valve")
	if id == "volcano": game.time_elapsed = 652.8
	visit(id)
	check(game.taken.has(id),"collect " + id)

func _run() -> void:
	game = Game.new()
	var test_path := OS.get_temp_dir().path_join("last-lighthouse-test-%d.cfg" % OS.get_process_id())
	game.journal.path = test_path
	root.add_child(game)
	await physics_frame
	check(game.screen == "title","title screen")
	game.hud.action.emit("start")
	game.hud.action.emit("prologue_skip")
	for day in 2:
		game.time_elapsed = day * 1440.0 + 839.99
		game._process(.02)
	var night_patrols := 0
	for creature in game.creatures.get_children():
		if creature.kind=="hound" and creature.home.distance_to(game._ground(Vector2(-36,22))) < 1.0:
			night_patrols += 1
	check(night_patrols==1,"the living night patrol stays unique on the second night")
	game.time_elapsed = 650.0
	game._conditions()
	var reef := Vector2(-54,15)
	check(game.world.is_walkable(reef.x,reef.y),"exposed low-tide crossing")
	game._place_hero(reef)
	game.time_elapsed = 1000
	game._conditions()
	check(not game.world.is_walkable(reef.x,reef.y) and game.world_day < .1,"high tide and darkness")
	game._safe_shore()
	check(game.world.is_walkable(game.hero.position.x,game.hero.position.z),"stranded player returns to land")
	for material: String in ["beach","lake","volcano"]:
		game.hud.action.emit("start")
		game.hud.action.emit("prologue_skip")
		visit("harbor")
		check(not game.taken.has("harbor"),"repair needs a part")
		collect(material)
		visit("harbor")
		check(game.taken.count("harbor")==1 and not game.won,"one "+material+" part repairs the harbor boat")
		visit("harbor")
		check(game.taken.count("harbor")==1,"repair can only complete once")
		game._process(.02)
		check(not game.props.harbor_glass.visible and game.props.harbor_lamp.light_energy==0,"repairs leave port signal dark until the beacon is lit")
		visit("tower")
		check(not game.in_tower,"ship repairs leave the tower locked")
	visit("driftwood")
	visit("sap")
	visit("village")
	check(game.screen=="forge","forge menu")
	var clock_before: float = game.time_elapsed
	game._process(2.0)
	check(is_equal_approx(clock_before,game.time_elapsed),"menus freeze clocks")
	game.hud.action.emit("forge_weapon")
	check(game.hero.weapon_upgrade and game.iron==0 and game.resin==0,"craft and charge once")
	game.hud.action.emit("forge_weapon")
	check(game.iron==0 and game.resin==0,"repeat crafting is safe")
	game.hud.action.emit("rest")
	game.hud.action.emit("resume")
	visit("driftwood")
	check(game.iron==2,"materials renew at dawn")
	visit("camp")
	game.hero.receive_hit(500)
	await process_frame
	await process_frame
	check(game.hero.hp>0 and game.checkpoint=="camp" and game.hero.weapon_upgrade,"respawn retains crafted gear")
	game.hud.action.emit("start")
	game.hud.action.emit("prologue_skip")
	game.hud.action.emit("track/main")
	visit("tower")
	check(not game.in_tower and not game.won,"zero crests")
	game.hud.action.emit("track/crest_forest")
	game._refresh()
	check(game.hud.state.tracked_point==game.Geo.ARENAS.forest,"can select a different first champion")
	var route_order := ["forest","desert","volcano","lake","snow","tide"]
	var earned: Array = []
	for zone: String in route_order:
		game._place_hero(game.Geo.ARENAS[zone])
		game.wilds.tick(game._day_index(),true)
		var champion = game.wilds.bosses.get(zone)
		check(is_instance_valid(champion),"local champion spawns in "+zone)
		if not is_instance_valid(champion): continue
		# Weapon timing and openings are exercised by expedition_combat and expedition_duels.
		champion.receive_hit(1000.0, true)
		earned.append(zone)
		check(game.crests.count(zone)==1 and game.crests.size()==earned.size(),"real first kill credits only "+zone)
		check(game.journal.read().crests.has(zone),"first kill immediately saved "+zone)
		for plate_zone: String in route_order:
			var plate = game.world._crest_register.get_node("Crest_"+plate_zone)
			check(plate.visible==earned.has(plate_zone),"altar socket tracks "+plate_zone)
		champion.receive_hit(1000.0,true)
		game.wilds.crest_earned.emit(zone)
		game.wilds.crest_earned.emit("bogus")
		check(game.crests.size()==earned.size(),"repeated or unknown award ignored")
		game.wilds.tick(game._day_index(),true)
		check(not game.wilds.bosses.has(zone),"champion stays defeated "+zone)
		if earned.size()==3:
			game.hud.action.emit("continue")
			check(game.crests.size()==3 and game.crests.all(func(id): return earned.has(id)),"resume partial expedition")
		if earned.size()==5:
			visit("tower")
			check(not game.in_tower,"five different crests cannot enter")
			game._refresh()
			var dest = game.hud.state.tracked_point
			check(dest is Vector2 and game.Geo.zone_at(dest)=="tide","main map points into the last missing region")
			var corrupt: Dictionary = game.journal.read().duplicate(true)
			corrupt.crests.append_array(["bogus",21,earned[0],earned[0]])
			game.journal.write(corrupt)
			game.hud.action.emit("continue")
			check(game.crests.size()==5 and game.crests.all(func(id): return earned.has(id)),"journal normalizes bogus and duplicate crests")
			visit("tower")
			check(not game.in_tower,"invalid save entries cannot open tower")
	game._place_hero(game.sites.tower)
	game._refresh()
	check(game.hud.state.tracked_point==game.sites.tower,"completed collection points to the cape")
	visit("tower")
	check(game.in_tower and game.hero.peaceful and not game.won,"one E opens the peaceful mirror room before lighting")
	visit("exit")
	check(not game.in_tower and not game.won,"can leave before lighting")
	visit("tower")
	game.hud.action.emit("continue")
	check(game.in_tower and not game.won,"six-crest journal resumes in the unlit mirror room")
	game._place_hero(game.sites.beacon)
	game._refresh()
	check(not game._prompt("beacon").is_empty() and game._objective().contains("按 E"),"lamp core offers E")
	check(not game.world._crest_register.get_node("LensLight").visible,"assembled lamp awaits interaction")
	visit("beacon")
	check(game.won and game.in_tower and game.journal.read().won,"E lights and saves immediately inside the room")
	check(game.world._crest_register.get_node("LensLight").visible and game.props.harbor_glass.visible and game.props.harbor_lamp.light_energy>0,"altar and harbor illuminate together")
	var timer_after_lighting: float = game.ending_tick
	visit("beacon")
	check(is_equal_approx(game.ending_tick,timer_after_lighting),"second E does not restart the ceremony")
	game._process(1.0)
	check(game.in_tower and game.screen!="win","six sockets are shown first")
	game._process(1.1)
	check(not game.in_tower and game.screen!="win" and game.coast_camera.current,"next shot shows the outdoor beam")
	game._process(4.0)
	check(game.screen=="win","ending reached")
	game.hud.action.emit("continue")
	check(game.won and game.crests.size()==6,"all six crests retained after lighting and continue")
	for zone: String in route_order:
		game.survival.tick(.02,zone,game.crests)
		check(game.survival.crested,"permanent local protection for "+zone)
	check(game.ending_tick<=0 and game.screen=="play","completed save resumes exploration")
	_legacy_snapshots()
	for ext in ["",".bak",".tmp"]:
		if FileAccess.file_exists(test_path+ext):
			DirAccess.remove_absolute(test_path+ext)
	if failures.is_empty():
		print("PASS six champion awards, crest gating and map, optional repairs, crafting, checkpoint, lighting ceremony, migration and reload")
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _legacy_snapshots() -> void:
	# Old-format states carry the original mirror position, supply-machine counter and flags.
	var old := {"pos":game._ground(game.sites.beacon),"inside":true,"won":false,"loaded":2,
		"taken":["forest","door","beach","lake","awakened","guardian"],"iron":7,"weapon":true,
		"checkpoint":"camp","crests":["desert","forest","desert","bogus"],"walking_pin":"main"}
	_write_legacy(old)
	game.hud.action.emit("continue")
	var p := Vector2(game.hero.position.x,game.hero.position.z)
	check(not game.in_tower and p.distance_to(game.sites.tower)<9 and game.world.is_walkable(p.x,p.y),"legacy unfinished mirror save returns to cape")
	check(game.crests.size()==2 and game.crests.has("forest") and game.crests.has("desert"),"keep only genuine distinct region ids")
	check(game.iron==7 and game.hero.weapon_upgrade and game.checkpoint=="camp","legacy gear and checkpoint survive migration")
	visit("tower")
	check(not game.in_tower and not game.won,"old key, fuel and guardian flags cannot bypass the new gate")
	old.won=true
	old.inside=false
	old.pos=game._ground(game.world.POINTS.spawn)
	old.crests=["lake"]
	_write_legacy(old)
	game.hud.action.emit("continue")
	check(game.won and game.crests==["lake"] and game.screen=="play","legacy winner keeps ending and original tally")
	game._save()
	game.hud.action.emit("continue")
	check(game.won and game.crests==["lake"] and game.ending_tick<=0,"old victory survives another save and resume")

func _write_legacy(snapshot: Dictionary) -> void:
	var file := ConfigFile.new()
	file.set_value("game","version",1)
	file.set_value("game","state",snapshot)
	check(file.save(game.journal.path)==OK,"create representative version-one journal")
