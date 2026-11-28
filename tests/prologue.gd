extends SceneTree
## New voyages, interrupted stories, title replays and pre-prologue saves.
const Game = preload("res://main.gd")
var game
var journal_path: String
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL ",message)

func launch() -> void:
	game = Game.new()
	game.journal.path = journal_path
	root.add_child(game)

func press_key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event)

func snapshot_hashes() -> PackedStringArray:
	var result := PackedStringArray()
	for suffix: String in ["",".bak"]:
		var path := journal_path+suffix
		result.append(FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "")
	return result

func check_story(page: int) -> void:
	check(game.screen=="prologue" and game.prologue_page==page,"story page %d"%page)
	var passage: Dictionary=game.Prologue.PAGES[page]
	check(game.hud.state.prologue_text==passage.text and not passage.text.is_empty(),"caption follows the selected passage")
	check(passage.voice is AudioStream and passage.voice.get_length()>1.0,"narration clip available for this page")
	check(not game.hero.input_enabled and not game.survival.active,"reading suspends the keeper and survival")
	check(not game.hud.play_layer.visible,"gameplay HUD hidden while reading")
	var focus := root.gui_get_focus_owner()
	check(focus is Button and focus.is_visible_in_tree(),"a reading control has keyboard focus")

func check_free_play() -> void:
	check(game.screen=="play" and game.hero.input_enabled and game.survival.active,"keeper has control")
	check(game.trails.pin.is_empty() and game.hud.state.tracked_point==null,"no automatic destination")
	check(game.hud.state.walking_route.is_empty(),"the map starts without a route")
	check(game.hud.state.objective.contains("首领") or game.hud.state.objective.contains("探索"),"HUD explains the open journey")

func run() -> void:
	journal_path=OS.get_temp_dir().path_join("greybay-prologue-%d.cfg"%OS.get_process_id())
	launch()
	game.hud.action.emit("start")
	await process_frame
	check_story(0)
	var clock_at_start: float=game.time_elapsed
	var keeper_at_start: Vector3=game.hero.position
	for key: Key in [KEY_M, KEY_J, KEY_E, KEY_2]:
		press_key(key)
	game._process(3.0)
	await physics_frame
	check(game.screen=="prologue" and game.prologue_page==0,"gameplay keys cannot dismiss or bypass the story")
	check(game.hero.position.is_equal_approx(keeper_at_start) and is_equal_approx(game.time_elapsed,clock_at_start),"reading holds position and game clock")
	check(not game.hero.bow_selected and game.library.read_entries.is_empty(),"combat and interactions stay inactive")

	press_key(KEY_ENTER)
	await process_frame
	check_story(1)
	game.hud.action.emit("prologue_back")
	check_story(0)
	game.hud.action.emit("prologue_next")
	check(game.journal.read().get("prologue_page",-1)==1,"page turn saved before leaving the application")
	game.free()
	launch()
	game.hud.action.emit("continue")
	await process_frame
	check_story(1)
	game.hud.action.emit("prologue_next")
	check_story(2)
	game.hud.action.emit("prologue_next")
	check_free_play()
	check(game.journal.read().get("prologue_page",0)==-1,"story completion persisted")
	game.hud.action.emit("quit")
	game.hud.action.emit("continue")
	check_free_play()
	for zone: String in game.voyage.ORDER:
		game.hud.action.emit("map")
		game.hud.action.emit("track/hunt_"+zone)
		check(game.hud.state.tracked_point==game.Geo.HUNTS[zone],"opt in to any hunting ground before visiting the library: "+zone)
		game.hud.action.emit("map")
		game.hud.action.emit("track/crest_"+zone)
		check(game.hud.state.tracked_point==game.Geo.ARENAS[zone],"opt in to any champion before visiting the library: "+zone)
	game.hud.action.emit("map")
	game.hud.action.emit("track/hunt_snow")
	game.wilds.crest_earned.emit("tide")
	check(game.trails.pin=="hunt_snow" and game.hud.state.tracked_point==game.Geo.HUNTS.snow,"an unrelated crest preserves the player's selected trail")

	game.hud.action.emit("quit")
	var completed_hashes := snapshot_hashes()
	game.hud.action.emit("prologue_replay")
	check_story(0)
	game.hud.action.emit("prologue_next")
	game.hud.action.emit("prologue_next")
	game.hud.action.emit("prologue_next")
	check(game.screen=="title" and snapshot_hashes()==completed_hashes,"replaying the complete story preserves the journey and its backup")
	game.hud.action.emit("prologue_replay")
	press_key(KEY_ESCAPE)
	check(game.screen=="title" and snapshot_hashes()==completed_hashes,"skipping a replay returns safely to title")
	game.hud.action.emit("continue")
	check(game.screen=="play" and game.trails.pin=="hunt_snow","continue restores a chosen hunting route")

	var legacy := {"pos":keeper_at_start,"taken":[],"walking_pin":"library","iron":7}
	check(game.journal.write(legacy),"create a journey saved before the prologue existed")
	game.hud.action.emit("continue")
	check(game.screen=="play" and game.trails.pin=="library" and game.iron==7,"legacy journey keeps progress and its chosen route")
	game._new_game()
	check_story(0)
	press_key(KEY_ESCAPE)
	check_free_play()
	game.hud.action.emit("quit")
	game.hud.action.emit("continue")
	check_free_play()
	for zone: String in game.voyage.ORDER:
		game.wilds.crest_earned.emit(zone)
		if game.crests.size()<6:
			check(game.trails.pin.is_empty() and game.hud.state.walking_route.is_empty(),"free exploration stays unpinned after earning "+zone)
	check(game.hud.state.tracked_point==game.sites.tower,"six untracked crests point home to the beacon")
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(journal_path+suffix): DirAccess.remove_absolute(journal_path+suffix)
	game.free()
	print("Opening story, free exploration, resume, replay and legacy navigation. Failures: ",failures)
	quit(1 if failures else 0)
