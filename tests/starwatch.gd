extends SceneTree

const Game = preload("res://main.gd")
const DT := 1.0/60.0
var game
var trial
var failed := false

func _initialize() -> void:
	call_deferred("run")

func expect(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		printerr("FAIL ",message)

func use_site(id: String) -> void:
	game._place_hero(game.sites[id])
	var interact := InputEventKey.new()
	interact.physical_keycode = KEY_E
	interact.keycode = KEY_E
	interact.pressed = true
	game._unhandled_input(interact)

func approach() -> void:
	var target: Vector3 = trial.fighter.global_position
	game._place_hero(Vector2(target.x,target.z+1.5))
	var direction: Vector3 = (target-game.hero.global_position).slide(Vector3.UP)
	game.hero.camera_yaw = atan2(-direction.x,-direction.z)
	trial.fighter.set_physics_process(false)

func swing(frames: int) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	game.hero._unhandled_input(event)
	for i in frames:
		game.hero._physics_process(DT)

func run() -> void:
	game = Game.new()
	var path := OS.get_temp_dir().path_join("starwatch-test-%d.cfg" % OS.get_process_id())
	game.journal.path = path
	root.add_child(game)
	await physics_frame
	game.hud.action.emit("start")
	game.hud.action.emit("prologue_skip")
	trial = game.starwatch
	if not game.sites.has(trial.SITE):
		# The combat worktree can be exercised before merging the northern map.
		game._install_starwatch(Vector2(-6,8))
	var origin: Vector2 = game.sites[trial.SITE]
	use_site(trial.SITE)
	expect(trial.active and trial.wave==1 and game.near_site==trial.SITE,"E lights the starwatch beacon")
	var first = trial.fighter
	use_site(trial.SITE)
	expect(trial.fighter==first,"pressing E again leaves one echo")
	game.hero.position = trial.position+Vector3.RIGHT*18
	trial.tick(.1)
	expect(not trial.active and first.is_queued_for_deletion() and not game.taken.has(trial.SITE),"retreat cleans up without claiming reward")

	use_site(trial.SITE)
	game.hud.action.emit("quit")
	game.hud.action.emit("continue")
	expect(not trial.active and not game.taken.has(trial.SITE),"reloading an unfinished challenge permits retry")
	use_site(trial.SITE)
	var before: float = trial.seconds
	game._show("pause")
	game._process(4.0)
	expect(trial.seconds==before,"pausing freezes the wick")
	game._show("play")
	trial.tick(100.0)
	expect(not trial.active and not game.taken.has(trial.SITE),"wick expiration permits retry")
	use_site(trial.SITE)
	var initial_iron: int = game.iron
	var initial_resin: int = game.resin
	approach()
	for i in 3: swing(90)
	expect(trial.fighter.hp<=0 and not trial.charged,"three isolated cuts remove a hound without charging")
	trial.tick(DT)
	expect(trial.wave==2 and trial.fighter.kind=="elite","defeating the first echo advances to the sentinel")
	approach()
	for i in 7: swing(90)
	trial.tick(DT)
	expect(trial.active and not trial.charged and trial.fighter.hp>0,"beating both waves without a technique calls a fresh echo")
	approach()
	swing(27)
	swing(30)
	swing(43)
	expect(trial.charged,"player's third connected cut charges the lens")
	for i in 3: swing(55)
	trial.tick(DT)
	expect(not trial.active and game.taken.has(trial.SITE),"charged lens and final defeat clear the challenge")
	expect(game.iron==initial_iron+3 and game.resin==initial_resin+2,"exactly one completion reward, no farmed enemy loot")
	game.hud.action.emit("quit")
	game.hud.action.emit("continue")
	game._place_hero(origin)
	game._nearest()
	expect(game.taken.has(trial.SITE) and game.near_site!=trial.SITE and not trial.active,"cleared lens persists and cannot intercept E")
	game._interact(trial.SITE)
	expect(game.iron==initial_iron+3 and not trial.active,"completed challenge cannot reward twice")
	game.queue_free()
	await process_frame
	for ext in ["",".bak",".tmp"]:
		if FileAccess.file_exists(path+ext):
			DirAccess.remove_absolute(path+ext)
	if not failed:
		print("PASS E beacon, retreat, retry, reload, timeout, two combat waves, third cut and one-time award")
	quit(1 if failed else 0)
