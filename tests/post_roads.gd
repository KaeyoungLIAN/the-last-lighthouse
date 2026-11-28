extends SceneTree

var game
var errors: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, note: String) -> void:
	if not ok:
		errors.append(note)
		printerr("FAIL ",note)

func use_stop(id: String) -> void:
	game._place_hero(game.sites[id])
	var press := InputEventKey.new()
	press.keycode=KEY_E
	press.pressed=true
	game._unhandled_input(press)
	check(game.screen=="post" and game.post_roads.at_stop==id,"signed in at "+id)

func run() -> void:
	game=preload("res://main.gd").new()
	var file := OS.get_temp_dir().path_join("greybay-stations-%s.cfg" % OS.get_process_id())
	game.journal.path=file
	root.add_child(game)
	game._on_action("start")
	game.hud.action.emit("prologue_skip")
	use_stop("post_village")
	game._on_action("ride/post_port")
	check(game.screen=="post","an unregistered route stays closed")
	game._on_action("resume")
	for id in ["post_highmoor","post_mill","post_port","post_salt"]:
		use_stop(id)
		game._on_action("resume")
	use_stop("post_port")
	var clock_before: float=game.time_elapsed
	game._on_action("ride/post_mill")
	check(game.screen=="play" and game.time_elapsed>clock_before,"a mail coach advances the island clock")
	check(game.hero.position.distance_to(game._ground(game.sites.post_mill))<2.0,"arrived at the selected stop")
	game.taken.append("bell_song")
	game._place_hero(game.sites.starwatch_trial)
	game._interact("starwatch_trial")
	game._show("map")
	game._on_action("bell_return")
	check(game.starwatch.active and not game.harvested.has("bell_return"),"a challenge blocks recall without spending the daily charge")
	game.starwatch.reset(false)
	game._place_hero(game.sites.post_mill)
	game._show("map")
	game._on_action("bell_return")
	check(game.hero.position.distance_to(game._ground(game.sites.post_village))<2.0,"bell returns to Greybay")
	game._restore()
	check(game.taken.has("post_salt") and game.harvested.get("bell_return",-1)==game._day_index(),"return and stations persist")
	game._place_hero(game.sites.post_salt)
	game._show("map")
	game._on_action("bell_return")
	check(game.screen=="map","the return can only be used once per day")
	root.remove_child(game)
	game.free()
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(file+suffix): DirAccess.remove_absolute(file+suffix)
	if errors.is_empty(): print("PASS discovery-gated post routes, clock, return bell and persistent daily limit")
	quit(0 if errors.is_empty() else 1)
