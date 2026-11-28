extends SceneTree
## Follow the on-screen route from a fresh save using the keeper's actual movement and E input.
const Game:=preload("res://main.gd")
var game
var failures:=0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool,message: String) -> void:
	if not ok:
		failures+=1
		printerr("FAIL ",message)

func position2() -> Vector2:
	return Vector2(game.hero.position.x,game.hero.position.z)

func press_e() -> void:
	var key:=InputEventKey.new()
	key.keycode=KEY_E
	key.physical_keycode=KEY_E
	key.pressed=true
	game._unhandled_input(key)

func walk(points: PackedVector2Array) -> bool:
	for target: Vector2 in points:
		var budget:=int(position2().distance_to(target)*16)+60
		while position2().distance_to(target)>.26 and budget>0:
			await physics_frame
			var heading:=position2().direction_to(target)
			game.hero.velocity=Vector3(heading.x,0,heading.y)*6.8
			game.hero._move_on_ground(1./60.)
			budget-=1
		if budget<=0:
			printerr("Blocked at ",position2()," walking to ",target)
			return false
	return true

func run() -> void:
	game=Game.new()
	game.journal.path=OS.get_temp_dir().path_join("library-walk-%d.cfg"%OS.get_process_id())
	root.add_child(game)
	game.hud.action.emit("start")
	game.hud.action.emit("prologue_skip")
	await physics_frame
	game.hero.set_physics_process(false)
	check(game.trails.pin.is_empty(), "fresh explorer has no pinned route")
	game.hud.action.emit("map")
	game.hud.action.emit("track/library")
	check(game.trails.pin=="library" and game._objective().contains("图书馆"),"choose the library route")
	var route:PackedVector2Array=game.trails.route(position2(),game.library.DOOR)
	check(await walk(route),"first walk from spawn to the door")
	press_e()
	check(game.library.inside and game.hero.peaceful,"enter library and put weapons down")
	if not game.library.inside: game.free(); quit(1); return
	var desk:Vector2=game.library.CENTER+game.library.STATIONS.library_desk
	check(await walk(PackedVector2Array([desk])),"walk from entry to the desk")
	press_e()
	check(game.screen=="library_read" and game.library.read_entries.has("main"),"E opens the storm story")
	game.library.close_book()
	var aisle:Vector2=game.library.CENTER+Vector2(-.40,-1.50)
	var end_of_desk:Vector2=game.library.CENTER+Vector2(-.40,2.70)
	var shelf:Vector2=game.library.CENTER+game.library.STATIONS.library_west
	check(await walk(PackedVector2Array([end_of_desk,aisle,shelf])),"walk around the desk to the coast shelf")
	press_e()
	if game.library._tabs.get_child_count()>1:
		game.library._tabs.get_child(1).pressed.emit()
		game.library._track.pressed.emit()
	check(game.trails.pin=="tide" and game.screen=="play","mark the coast using the book")
	var exit:Vector2=game.library.CENTER+game.library.STATIONS.library_exit
	check(await walk(PackedVector2Array([aisle,end_of_desk,exit])),"walk back to exit")
	press_e()
	check(not game.library.inside and not game.hero.peaceful,"return to village")
	var note:Vector2=game.sites.field_note_tide
	var trail:PackedVector2Array=game.trails.route(position2(),note)
	check(trail.size()>15,"marked walking route to the bottle")
	check(await walk(trail),"follow shore clue from the library to the bottle")
	press_e()
	check(game.screen=="field_note" and game.taken.has("field_note_tide"),"open and keep the bottle message")
	game._save()
	game._restore()
	check(game.taken.has("field_note_tide") and game.library.read_entries.has("main"),"remember books and field finds after restart")
	game._show("notes")
	game.hud.action.emit("read_note/tide")
	check(game.screen=="field_note" and game.trails.current_note=="tide","re-read a found note")
	print("Fresh start -> library -> desk -> walk to the coast -> bottle -> journal restore. Failures: ",failures)
	for suffix in ["",".bak"]:
		if FileAccess.file_exists(game.journal.path+suffix): DirAccess.remove_absolute(game.journal.path+suffix)
	game.free()
	quit(1 if failures else 0)
