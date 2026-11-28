extends SceneTree
## Walk from the new-game spawn to all reading stations and use the production HUD, input and journal.
var game
var lib
var held := {}
var failures: Array[String] = []
var walk_frames := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool,context: String) -> void:
	if not ok:
		failures.append(context)
		printerr("FAIL ",context)

func key(code: Key,down: bool) -> void:
	if bool(held.get(code,false))==down: return
	held[code] = down
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func tap(code: Key) -> void:
	key(code,true)
	key(code,false)

func walk(target: Vector2,tolerance := .32) -> void:
	var hero = game.hero
	var arrived := false
	for n in 260:
		var pos := Vector2(hero.position.x,hero.position.z)
		var toward := target-pos
		if toward.length()<tolerance:
			arrived = true
			break
		toward = toward.normalized()
		var forward: Vector3 = hero.get_forward()
		var side: Vector3 = forward.cross(Vector3.UP)
		var direction := Vector3(toward.x,0,toward.y)
		key(KEY_W,direction.dot(forward)>.35)
		key(KEY_S,direction.dot(forward)<-.35)
		key(KEY_D,direction.dot(side)>.35)
		key(KEY_A,direction.dot(side)<-.35)
		await physics_frame
		walk_frames+=1
	for code in [KEY_W,KEY_S,KEY_A,KEY_D]: key(code,false)
	for n in 8: await physics_frame
	check(arrived,"walk to %s, reached %s" % [target,hero.position])

func station(id: String) -> void:
	var origin := Vector2(lib.ROOM.x,lib.ROOM.z)
	await walk(origin+lib.STATIONS[id],.37)
	check(lib.nearby()==id,"walk into range of "+id)
	tap(KEY_E)
	await process_frame

func check_regional_routes(shelf: String,pages: Array) -> void:
	for index in pages.size():
		var zone: String = pages[index]
		for prefix: String in ["hunt_","crest_"]:
			if not lib.reading:
				tap(KEY_E)
				await process_frame
			if index>0: lib._tabs.get_child(index).pressed.emit()
			check(lib._entry_title.text==lib.ENTRIES[zone][0],"select field entry for "+zone)
			var guide: Dictionary = game.wilds.GUIDE[zone]
			check(lib._region_title.text.contains(game.voyage.NAMES[zone]) and lib._terrain.text.contains(game.voyage.HINTS[zone]),"regional terrain for "+zone)
			check(lib._champion.text.contains(guide.boss) and lib._champion.text.contains(guide.hint),"champion and opening for "+zone)
			check(lib._animal.text.contains(guide.prey) and lib._animal.text.contains(guide.catch_hint),"animal and capture timing for "+zone)
			var choice: Button = lib._hunt_button if prefix=="hunt_" else lib._boss_button
			check(choice.is_visible_in_tree() and not choice.disabled,shelf+" offers "+prefix+zone)
			choice.pressed.emit()
			check(game.screen=="play" and game.trails.pin==prefix+zone,"shelf tracks "+prefix+zone)
			check(game.journal.read().get("walking_pin","")==prefix+zone,"saved shelf route "+prefix+zone)
	# Leave the book open at its initial page for the letter-clue keyboard flow below.
	if not lib.reading:
		tap(KEY_E)
		await process_frame

func run() -> void:
	game = preload("res://main.gd").new()
	var path := OS.get_temp_dir().path_join("lighthouse-library-%d.cfg" % OS.get_process_id())
	game.journal.path = path
	root.add_child(game)
	lib = game.library
	await physics_frame
	game._on_action("start")
	game.hud.action.emit("prologue_skip")
	await walk(Vector2(-40,31))
	await walk(Vector2(-29,29))
	await walk(lib.DOOR,.75)
	var outdoor_frames := walk_frames
	check(lib.nearby()==lib.ENTRY_ID,"enter prompt at library door")
	tap(KEY_E)
	await process_frame
	check(lib.inside and game.hero.peaceful and game.hero.world_ref==lib,"E enters reading room")
	if lib.inside:
		var origin := Vector2(lib.ROOM.x,lib.ROOM.z)
		for name_key: String in ["library_desk","library_west","library_south","library_east"]:
			# The west shelf is behind the desk. Use the aisle to get around the furniture.
			if name_key=="library_west":
				await walk(origin+Vector2(-.40,2.70))
				await walk(origin+Vector2(-.40,-1.50))
			await station(name_key)
			var pages: Array = lib.COLLECTIONS[name_key][1]
			check(game.screen=="library_read" and lib.reading and lib._reader.visible,"open "+name_key)
			check(lib._entry_title.text==lib.ENTRIES[pages[0]][0],"first page "+name_key)
			if pages.size()>1:
				await check_regional_routes(name_key,pages)
				lib._tabs.get_child(1).pressed.emit()
				check(lib._entry_title.text==lib.ENTRIES[pages[1]][0],"second page "+name_key)
			tap(KEY_ENTER)
			await process_frame
			check(game.screen=="play" and game.trails.pin==pages[-1],"choose walking direction "+str(pages[-1]))
		check(lib.read_entries.size()==7,"all seven reading flags")
		lib.sync_field_notes(["field_note_snow","field_note_lake"])
		var visible_cards := 0
		for card in lib._note_cards.values():
			if card.visible: visible_cards+=1
		check(visible_cards==2 and lib._note_cards.snow.visible and lib._note_cards.lake.visible,"two unique returned letters on the board")
		lib.sync_field_notes([])
		for card in lib._note_cards.values(): check(not card.visible,"reset board")
		# The camera sphere and player capsule must remain on the room side of its walls.
		game.hero.turn_by_mouse(Vector2(-PI*.5/.0024,0))
		for n in 22: await physics_frame
		var eye: Vector3 = game.hero.camera.global_position-lib.ROOM
		check(absf(eye.x)<5.68 and absf(eye.z)<5.45 and eye.y<4.36,"camera clipped to indoor walls")
		await walk(origin+Vector2(.50,2.65))
		await station(lib.EXIT_ID)
		check(not lib.inside and game.hero.world_ref==game.world and not game.hero.peaceful,"exit to village on foot")
		check(Vector2(game.hero.position.x,game.hero.position.z).distance_to(lib.DOOR)<1,"exit lands by door")
		tap(KEY_E)
		await process_frame
		await station("library_desk")
		tap(KEY_ESCAPE)
		await process_frame
		check(game.screen=="play" and not lib.reading,"Esc closes only the book")
		game._save()
		var saved: Dictionary = game.journal.read()
		check(saved.library.read.size()==7 and saved.library.tracked=="forest","journal holds returns and reading history")
		check(saved.pos.y<lib.ROOM.y-30,"interior autosave stores island landing")
		game._restore()
		check(not lib.inside and not game.hero.peaceful and lib.tracked=="forest" and game.trails.pin=="forest","continue outside with tracked clue")
		lib.restore({"read":["snow","wrong","snow",12],"tracked":"wrong"})
		check(lib.read_entries==["snow"] and lib.tracked=="","invalid journal entries skipped")
		lib.restore({})
		check(lib.read_entries.is_empty() and lib.tracked.is_empty(),"legacy save without library state")
	print("Library: village door in ",snappedf(outdoor_frames/60.,.1)," s, walked to four stations and exit; failures ",failures)
	for suffix in ["",".tmp",".bak"]:
		if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)
	quit(0 if failures.is_empty() else 1)
