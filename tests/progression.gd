extends SceneTree
## Run with a fresh test journal. Warps skip walking time; all pickups use the same E interaction as regular play.
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
	for pair in [["beach","lake"],["volcano","lake"],["beach","volcano"]]:
		game.hud.action.emit("start")
		visit("tower")
		check(not game.taken.has("door"),"door locked before key")
		collect(pair[0])
		visit("forest")
		visit("tower")
		visit("tower")
		check(game.loaded == 1,"one can install")
		collect(pair[1])
		visit("tower")
		check(game.loaded == 2,"two cans install")
		visit("tower")
		check(game.in_tower,"tower access")
		visit("exit")
		check(not game.in_tower,"return from tower")
		visit("harbor")
		check(not game.taken.has("harbor"),"third fuel reserved for optional signal")
	visit("valve")
	collect("lake")
	visit("harbor")
	check(game.taken.has("harbor"),"optional harbor light")
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
	check(game.hero.hp>0 and game.checkpoint=="camp" and game.taken.has("forest"),"respawn retains inventory")
	visit("tower")
	visit("mirror")
	check(is_instance_valid(game.boss),"guardian spawns")
	var boss = game.boss
	game.hero.oil=0
	game.hero.lamp_mode=0
	boss.shell_open=0
	boss.receive_hit(500)
	check(boss.hp==boss.max_hp,"guarded boss resists")
	visit("mirror")
	check(boss.shell_open>0,"zero oil mirror opening")
	boss.receive_hit(500)
	check(game.taken.has("guardian"),"guardian victory")
	visit("beacon")
	check(game.won,"beacon lights")
	game._process(4.0)
	check(game.screen=="win","ending reached")
	game.hud.action.emit("quit")
	game.hud.action.emit("continue")
	check(game.won and game.loaded==2 and game.hero.weapon_upgrade and game.taken.has("guardian"),"read completed save")
	for ext in ["",".bak",".tmp"]:
		if FileAccess.file_exists(test_path+ext):
			DirAccess.remove_absolute(test_path+ext)
	if failures.is_empty():
		print("PASS tidal rescue, three fuel combinations, staged deposit, crafting, checkpoint, zero-oil mirror, victory and reload")
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
