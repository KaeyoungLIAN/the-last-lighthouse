extends SceneTree
var game
var errors: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool,message: String) -> void:
	if not ok:
		errors.append(message)
		printerr("FAIL ",message)

func press(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	game._unhandled_input(event)

func run() -> void:
	game = preload("res://main.gd").new()
	var path := OS.get_temp_dir().path_join("cape-song-%d.cfg" % OS.get_process_id())
	game.journal.path = path
	root.add_child(game)
	await physics_frame
	game._new_game()
	game.hud.action.emit("prologue_skip")
	game._place_hero(game.bells.spot)
	game._nearest()
	check(game.near_site==game.bells.SITE,"playing spot reachable via normal E")
	press(KEY_E)
	check(game.screen=="tide_bells" and game.bells.lens.current,"frame the three bells")
	var rates := []
	for sound in game.bells.sounds:
		check(sound.stream!=null and sound.stream.get_length()>1,"playable bell audio")
		rates.append(sound.pitch_scale)
	check(rates[0]<rates[1] and rates[1]<rates[2],"three distinct, ordered pitches")
	game._on_action("tide_note_1")
	check(game.bells.step==1,"button rings middle bell")
	press(KEY_1)
	check(game.bells.step==0 and game.bells.report.text.contains("顺序不对"),"miss and retry")
	press(KEY_2)
	press(KEY_ESCAPE)
	check(game.screen=="play" and game.hero.camera.current,"exit restores camera")
	press(KEY_E)
	check(game.bells.step==0,"reenter resets incomplete score")
	for key in [KEY_2,KEY_3,KEY_1]: press(key)
	check(game.bells.step==3 and game.taken.has("bell_song") and game.iron==2,"solve, enable return voyage and award scrap")
	check(game.bells.pennant.visible and game.bells.choices[0].disabled,"completion is visible")
	press(KEY_1)
	game._on_action("tide_note_1")
	check(game.iron==2,"repeat notes cannot claim twice")
	press(KEY_ESCAPE)
	game.iron=0
	game.taken.clear()
	game._restore()
	check(game.iron==2 and game.taken.has("bell_song") and game.bells.pennant.visible,"reward and completion survive reload")
	press(KEY_E)
	check(game.screen=="tide_bells" and game.hud.menu_buttons.size()==1,"revisiting shows completed inscription")
	for ext in ["",".bak",".tmp"]:
		if FileAccess.file_exists(path+ext): DirAccess.remove_absolute(path+ext)
	root.remove_child(game)
	game.free()
	if errors.is_empty(): print("PASS chime score, distinct pitches, wrong notes, cancel and retry, persistent one-time reward")
	quit(0 if errors.is_empty() else 1)
