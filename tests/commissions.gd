extends SceneTree
## Exercise the same E, Esc, and J handlers a player uses. Uses a private journal.
var game
var errors: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool,context: String) -> void:
	if not ok:
		errors.append(context)
		printerr("FAIL ",context)

func press(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	game._unhandled_input(event)

func visit(id: String) -> void:
	game._place_hero(game.folk.locations[id])
	game._nearest()
	check(game.near_site == id,"nearest interaction for "+id+" was "+game.near_site)
	press(KEY_E)

func run() -> void:
	game = preload("res://main.gd").new()
	var path := OS.get_temp_dir().path_join("lighthouse-commissions-%d.cfg" % OS.get_process_id())
	game.journal.path = path
	root.add_child(game)
	await physics_frame
	game._on_action("start")
	game.hud.action.emit("prologue_skip")
	check(game.folk.models.size()==4,"four modeled islanders")
	check(game.hud.mini.view.folk_targets.is_empty(),"unaccepted jobs leave chart clear")
	check(game.folk._bearing(Vector2.ZERO,Vector2(3,-4))=="东北 · 5 米","north-up bearing and distance")
	for id: String in game.folk.locations:
		var p: Vector2 = game.folk.locations[id]
		check(game.world.is_walkable(p.x,p.y),"reachable "+id)
	check(not game.folk.available("survey_plate",game.taken),"survey disabled before accepting")
	visit("cartographer")
	check(game.screen=="folk_talk" and game.hud.state.folk_speech.name=="殷荻","open conversation")
	press(KEY_ESCAPE)
	check(game.screen=="play" and game.folk.stage("bearing",game.taken)==0,"cancel declines")
	visit("cartographer")
	press(KEY_E)
	check(game.folk.stage("bearing",game.taken)==1,"accept survey")
	visit("postwoman")
	press(KEY_E)
	var targets: Dictionary = game.hud.mini.view.folk_targets
	check(targets.size()==2 and targets.bearing.pos==game.folk.locations.survey_plate and targets.letter.pos==game.folk.locations.ranger,"simultaneous job rings at correct positions")
	press(KEY_M)
	check(game.hud.full_map.view.folk_targets==targets,"expanded chart uses matching job rings")
	press(KEY_M)
	press(KEY_J)
	check(game.screen=="folk_journal" and game.hud.state.folk_jobs.size()==3,"commission journal")
	var p := Vector2(game.hero.position.x,game.hero.position.z)
	var guide: String = game.hud.state.folk_jobs[0][1]
	check(guide.contains(game.folk.regions.observatory) and guide.contains(game.folk._bearing(p,targets.bearing.pos)),"journal names region and gives bearing in metres")
	press(KEY_J)
	visit("survey_plate")
	check(game.folk.stage("bearing",game.taken)==2,"rub the dial")
	check(game.hud.mini.view.folk_targets.bearing.pos==game.folk.locations.cartographer,"return marker replaces collection marker")
	game.taken.clear()
	game._restore()
	check(game.folk.stage("bearing",game.taken)==2,"save and restore mid-quest")
	visit("cartographer")
	press(KEY_E)
	check(game.iron==2,"turn in survey")
	check(not game.hud.mini.view.folk_targets.has("bearing") and game.hud.mini.view.folk_targets.has("letter"),"finished ring removed independently")
	visit("cartographer")
	press(KEY_E)
	check(game.iron==2,"survey reward only once")
	visit("postwoman")
	press(KEY_E)
	visit("ranger")
	press(KEY_E)
	check(game.iron==5 and game.folk.stage("letter",game.taken)==3,"deliver letter to another islander")
	visit("herbalist")
	press(KEY_E)
	visit("marsh_herb")
	check(game.folk.stage("remedy",game.taken)==2 and not game.folk.objects.marsh_herb.visible,"pick and remove herb")
	visit("herbalist")
	press(KEY_E)
	check(game.resin==3,"herbalist reward")
	check(game.hud.mini.view.folk_targets.is_empty(),"completed jobs have no map targets")
	game.iron = 0
	game.resin = 0
	game._restore()
	check(game.iron==5 and game.resin==3 and game.folk.stage("remedy",game.taken)==3,"completed jobs and rewards persist")
	game._on_action("start")
	game.hud.action.emit("prologue_skip")
	check(game.folk.stage("remedy",game.taken)==0 and game.folk.objects.marsh_herb.visible,"fresh voyage resets jobs")
	for ext in ["",".bak",".tmp"]:
		if FileAccess.file_exists(path+ext):
			DirAccess.remove_absolute(path+ext)
	root.remove_child(game)
	game.free()
	if errors.is_empty(): print("PASS four islanders, three commissions, interaction priority, journal, cancel, save/reload and one-time rewards")
	quit(0 if errors.is_empty() else 1)
