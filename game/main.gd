extends Node3D

const Island = preload("res://world/world.gd")
const Keeper = preload("res://actors/player.gd")
const Foe = preload("res://actors/enemy.gd")
const Interface = preload("res://ui/hud.gd")
const Journal = preload("res://journal.gd")
const Waymarks = preload("res://waymarks.gd")
const FieldProps = preload("res://field_props.gd")
const Soundscape = preload("res://soundscape.gd")
const Starwatch = preload("res://actors/starwatch_trial.gd")
const Voyage = preload("res://expedition_voyage.gd")
const Geo = preload("res://world/expedition_geography.gd")
const Prologue = preload("res://prologue.gd")
const PrologueCamera = preload("res://world/prologue_camera.gd")
var prologue_page := -1
var prologue_preview := false
var prologue_voiced := true
var library := preload("res://village_library.gd").new()
var trails := preload("res://exploration_trails.gd").new()
var voyage := Voyage.new()
var ferry := preload("res://lake_skiffs.gd").new()
var wetlands := preload("res://world/expedition_wetlands.gd").new()
var survival := preload("res://expedition_survival.gd").new()
var wilds := preload("res://expedition_encounters.gd").new()
var crests: Array = []
var hunted_today: Dictionary = {}
var _first_capture := ""
var volume_step := 2
var gentle_weather := false
const LEVELS := [-80.,-8.,0.]
const SHIP_SUPPLIES := {"beach":"沉船缆绳", "lake":"泵站密封圈", "volcano":"冷却窑铸件"}
const NAMES := {"village":"灰湾村","forest":"雾根林","beach":"月牙滩","lake":"镜湖泵站","volcano":"赤炉冷却窑","tower":"望潮岬灯塔"}
const MATERIALS := {"driftwood":["废铁",Vector2(-56,3)],"sap":["树脂",Vector2(-33,-8)],"scrap":["废铁",Vector2(5,-25)],"pitch":["树脂",Vector2(-19,-18)],"slag":["废铁",Vector2(44,-30)]}
const ENCOUNTERS := [
	["hound",Vector2(-30,-8)],["hound",Vector2(-20,-14)],["crab",Vector2(-60,5)],
	["fin",Vector2(8,-27)],["lizard",Vector2(43,-30)],["elite",Vector2(32,-30)]
]
var region_names := NAMES.merged(Island.Survey.REGION_NAMES)
var folk = preload("res://islanders.gd").new()
var bells = preload("res://tide_bells.gd").new()
var speaker := ""
var world = Island.new()
var hero = Keeper.new()
var hud = Interface.new()
var journal = Journal.new()
var marks = Waymarks.new()
var props = FieldProps.new()
var prop_positions := {}
var post_roads := preload("res://post_roads.gd").new()
var soundscape = Soundscape.new()
var starwatch = Starwatch.new()
var creatures := Node3D.new()
var coast_camera := Camera3D.new()
var sites: Dictionary = {}
var discovered: Array = ["village"]
var taken: Array = []
var defeated: Array = []
var harvested: Dictionary = {}
var iron := 0
var resin := 0
var time_elapsed := 650.0
var in_tower := false
var won := false
var screen := "title"
var near_site := ""
var has_save := false
var screen_tick := 0.0
var save_tick := 0.0
var ending_tick := -1.0
var world_day := 0.0
var tide_level := 0.0
var last_dry := Vector2(-38,36)
var checkpoint := "village"
var vent := CPUParticles3D.new()
var mirror_light: OmniLight3D

func _ready() -> void:
	add_child(world)
	add_child(marks)
	add_child(creatures)
	hero.world_ref = world
	add_child(hero)
	coast_camera.fov = 48
	add_child(coast_camera)
	_frame_cape()
	hero.died.connect(_hero_died)
	hero.struck.connect(func(): soundscape.cue("hit"))
	hero.combat_cue.connect(soundscape.cue)
	add_child(soundscape)
	add_child(hud)
	hud.action.connect(_on_action)
	_make_sites()
	add_child(folk)
	folk.build(self)
	add_child(bells)
	bells.build(self)
	add_child(starwatch)
	if world.POINTS.has("observatory"):
		_install_starwatch(world.POINTS["observatory"]+Vector2(-6,4))
	for id in ["camp","valve","winch","rescue","harbor","beach","lake","volcano"]:
		prop_positions[id] = _ground(sites[id])
	add_child(props)
	props.build(prop_positions,world)
	_build_effects()
	add_child(post_roads)
	post_roads.build(self)
	add_child(voyage)
	voyage.build(self)
	add_child(library)
	library.build(hero,world)
	_add_site(library.ENTRY_ID,"",library.DOOR) # The front door already has a painted sign.
	add_child(trails)
	trails.build(self)
	library.clue_selected.connect(_choose_lead)
	library.reader_changed.connect(_reading_changed)
	library.room_changed.connect(_library_changed)
	add_child(ferry)
	ferry.build(self)
	add_child(survival)
	survival.build(self)
	_load_preferences()
	add_child(wilds)
	wilds.build(hero,world,Geo.CAMPS)
	wilds.crest_earned.connect(_earn_crest)
	wilds.harvested.connect(_harvest_prey)
	wilds.net_cast.connect(func(caught: bool): hero.swing_net(caught,wilds.net_position))
	wilds.captured.connect(_record_capture)
	var verge := preload("res://world/expedition_verge.gd").new()
	add_child(verge)
	verge.build(world)
	add_child(wetlands)
	wetlands.build(world)
	has_save = not journal.read().is_empty()
	_place_hero(world.POINTS.spawn)
	_conditions()
	_show("title")

func _frame_cape() -> void:
	var tower: Vector3 = world.get_node("CapeLighthouse").global_position
	coast_camera.fov = 48
	coast_camera.set_cull_mask_value(2,true)
	coast_camera.position = tower + Vector3(-17,7,27)
	coast_camera.look_at(tower + Vector3.UP*8.2)

func _make_sites() -> void:
	for id in NAMES:
		_add_site(id, NAMES[id], world.POINTS[id])
	_add_site("winch","沉船绞盘",world.POINTS.beach + Vector2(3.4,3.6))
	_add_site("valve","泵站旁通阀",world.POINTS.lake + Vector2(-4.2,3.0))
	_add_site("camp","林间营火",Vector2(-18,-6))
	_add_site("rescue","村口的渔人",Vector2(-37,19))
	_add_site("harbor","码头船具补给站",Vector2(-46,36))
	_add_site("exit","下塔石阶",Vector2(0,137))
	_add_site("mirror","聚光镜柄",world.POINTS.mirror)
	_add_site("beacon","六纹章灯座",world.POINTS.beacon)
	for id in MATERIALS:
		_add_site(id,MATERIALS[id][0],MATERIALS[id][1],true)

func _add_site(id: String, caption: String, where: Vector2, resource: bool = false) -> void:
	var at := _walkable_near(where)
	sites[id] = at
	var tint := Color("a7e3c3") if resource else Color("f4c06d")
	marks.add_site(id,caption,_ground(at),tint,resource)

func _install_starwatch(point: Vector2) -> void:
	_add_site(Starwatch.SITE,"星尺守灯盘",point)
	starwatch.install(hero,world,_walkable_near,_ground(sites[Starwatch.SITE]))
	starwatch.message.connect(_notice)
	starwatch.completed.connect(_finish_starwatch)

func _finish_starwatch() -> void:
	if taken.has(Starwatch.SITE):
		return
	taken.append(Starwatch.SITE)
	iron += 3
	resin += 2
	hero.oil = minf(40.0,hero.oil+10.0)
	_notice("两道灯影散尽，星尺镜已点亮。获得废铁 ×3、树脂 ×2，补油 10。","chime")
	_save()

func _build_effects() -> void:
	var steam := vent
	steam.name = "Steam"
	steam.amount = 26
	steam.lifetime = 1.25
	steam.direction = Vector3.UP
	steam.spread = 18
	steam.initial_velocity_min = 1.2
	steam.initial_velocity_max = 2.9
	steam.gravity = Vector3(0.7,0.3,0)
	steam.scale_amount_min = 0.3
	steam.scale_amount_max = 0.9
	var puff := SphereMesh.new()
	puff.radius = 0.42
	puff.height = 0.67
	puff.radial_segments = 5
	puff.rings = 2
	var smat := StandardMaterial3D.new()
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.albedo_color = Color(0.93,0.75,0.59,0.35)
	puff.material = smat
	steam.mesh = puff
	steam.position = _ground(sites.volcano)
	add_child(steam)
	mirror_light = OmniLight3D.new()
	mirror_light.position = _ground(world.POINTS.arena) + Vector3(0,3,0)
	mirror_light.light_color = Color("ffe3a0")
	mirror_light.omni_range = 15
	mirror_light.light_energy = 0
	add_child(mirror_light)

func _ground(p: Vector2) -> Vector3:
	return Vector3(p.x,world.ground_height(p.x,p.y),p.y)

func _walkable_near(p: Vector2) -> Vector2:
	if world.is_walkable(p.x,p.y):
		return p
	for radius in range(1,13):
		for n in 16:
			var trial := p + Vector2.RIGHT.rotated(n*TAU/16.0)*radius
			if world.is_walkable(trial.x,trial.y):
				return trial
	return p

func _place_hero(p: Vector2) -> void:
	hero.reset_combat()
	var safe := _walkable_near(p)
	hero.global_position = _ground(safe) + Vector3.UP*0.12
	hero.velocity = Vector3.ZERO
	last_dry = safe
	hero.reset_physics_interpolation()

func _actor(kind: String, loc: Vector2, identity: String):
	var enemy = Foe.new()
	enemy.name = identity
	creatures.add_child(enemy)
	enemy.setup(kind,hero,world,_ground(_walkable_near(loc)) + Vector3.UP*0.08)
	enemy.fallen.connect(_foe_fallen.bind(identity))
	return enemy

func _rebuild_encounters() -> void:
	wilds.restore(crests,hunted_today,_day_index())
	starwatch.reset(taken.has(Starwatch.SITE))
	for child in creatures.get_children():
		creatures.remove_child(child)
		child.queue_free()
	if not in_tower and not won:
		for i in ENCOUNTERS.size():
			var identity := "wild_" + str(i)
			if not defeated.has(identity):
				_actor(ENCOUNTERS[i][0],ENCOUNTERS[i][1],identity)
		if _night() and not defeated.has("night_hound"):
			_actor("hound",Vector2(-36,22),"night_hound")
		if not taken.has("rescue") and not defeated.has("net_hound"):
			_actor("hound",Vector2(-36,15),"net_hound")

func _foe_fallen(kind: String, identity: String) -> void:
	if not defeated.has(identity):
		defeated.append(identity)
		if kind in ["hound","fin"]:
			resin += 1
			_notice("获得树脂 ×1","pickup")
		else:
			var count := 2 if kind == "elite" else 1
			iron += count
			_notice("获得废铁 ×%s" % count,"pickup")
	_save()

func _show(next: String) -> void:
	screen = next
	var playing := next == "play"
	if next == "prologue":
		PrologueCamera.frame(prologue_page,coast_camera,world)
		coast_camera.make_current()
		_voice_page()
	elif next in ["title","win"]:
		_frame_cape()
		coast_camera.make_current()
		world.set_conditions(0.38 if next == "title" else 0.22,tide_level,won)
	else:
		hero.camera.make_current()
		_conditions()
	if next != "prologue": soundscape.end_narration()
	if not playing: hero.cancel_draw()
	hero.input_enabled = playing and ending_tick < 0 and not ferry.afloat
	hero.process_mode = Node.PROCESS_MODE_INHERIT if playing else Node.PROCESS_MODE_DISABLED
	creatures.process_mode = hero.process_mode if not library.inside else Node.PROCESS_MODE_DISABLED
	wilds.tick(_day_index(),playing and not in_tower and not ferry.afloat and not library.inside)
	survival.set_active(playing and not in_tower and not library.inside)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if playing else Input.MOUSE_MODE_VISIBLE
	_refresh()
	hud.set_screen(next)

func _new_game() -> void:
	ferry.reset()
	library.restore({})
	hero.peaceful=false
	trails.restore("")
	prologue_page = 0
	prologue_preview = false
	voyage.tracking = 0
	speaker = ""
	discovered = ["village"]
	taken = []
	library.sync_field_notes(taken)
	defeated = []
	harvested = {}
	crests = []
	hunted_today = {}
	survival.restore({})
	hero.arrows = 12
	hero.bow_selected = false
	iron = 0
	resin = 0
	time_elapsed = 650.0
	in_tower = false
	won = false
	world.set_beacon_crests(crests, won)
	ending_tick = -1
	checkpoint = "village"
	hero.hp = 100
	hero.oil = 40
	hero.lamp_mode = 1
	hero.weapon_upgrade = false
	hero.armor_upgrade = false
	var village_lane := Vector2(-27.6,28.0)
	var square_direction := Vector2(-37,28.5)-village_lane
	hero.camera_yaw = atan2(-square_direction.x,-square_direction.y)
	hero.camera_pitch = .20
	_conditions()
	_place_hero(village_lane)
	_rebuild_encounters()
	_show("prologue")
	_save()

func _voice_page() -> void:
	soundscape.narrate(Prologue.PAGES[prologue_page].voice if prologue_voiced else null)

func _leave_prologue() -> void:
	prologue_page = -1
	if prologue_preview:
		prologue_preview = false
		_show("title")
		return
	_show("play")
	_notice("WASD 移动　·　鼠标转向　·　M 查看岛图","start")
	_save()

func _on_action(id: String) -> void:
	if screen == "prologue":
		match id:
			"prologue_next","prologue_back":
				if id == "prologue_back" and prologue_page == 0: return
				if id == "prologue_next" and prologue_page == Prologue.PAGES.size()-1:
					_leave_prologue()
					return
				prologue_page += 1 if id == "prologue_next" else -1
				_show("prologue")
				if not prologue_preview: _save()
			"prologue_skip": _leave_prologue()
			"prologue_voice":
				prologue_voiced = not prologue_voiced
				_store_preferences()
				_show("prologue")
			"quit":
				if not prologue_preview: _save()
				prologue_preview = false
				prologue_page = -1
				_show("title")
		return
	if id == "prologue_replay" and screen == "title" and has_save:
		prologue_preview = true
		prologue_page = 0
		_show("prologue")
		return
	if id.begins_with("track/"):
		var lead:=id.trim_prefix("track/")
		if not trails.valid_pin(lead): return
		voyage.tracking = 0
		trails.set_pin(lead,self)
		_show("play")
		_save()
		return
	if id.begins_with("read_note/") and screen=="notes":
		var note:=id.trim_prefix("read_note/")
		if taken.has(trails.PREFIX+note) and trails.NOTES.has(note):
			trails.current_note=note
			_show("field_note")
		return
	if id.begins_with("expedition/"):
		voyage.travel(id.trim_prefix("expedition/"),self)
		return
	if id.begins_with("cook/"):
		voyage.cook(self,id.trim_prefix("cook/"))
		return
	if id.begins_with("tide_note_"):
		bells.strike(id.trim_prefix("tide_note_").to_int(),self)
		return
	if id.begins_with("ride/"):
		post_roads.travel(id.trim_prefix("ride/"),self)
		return
	if id=="bell_return":
		post_roads.recall(self)
		return
	match id:
		"notes": _show("notes")
		"settings": _show("settings")
		"volume","gentle_weather":
			if screen=="settings":
				if id=="volume": volume_step=(volume_step+1)%LEVELS.size()
				else: gentle_weather=not gentle_weather
				_apply_preferences()
				_store_preferences()
				_show("settings")
		"fieldguide": _show("fieldguide")
		"village_cook": voyage.cook(self)
		"village_recipes":
			if screen=="expedition" and near_site==Voyage.DESK: _show("recipes")
		"back_recipes":
			if screen=="recipes": _show("expedition")
		"folk_reply": _finish_conversation()
		"folk_journal": _show("folk_journal")
		"start": _new_game()
		"continue": _restore()
		"resume": _show("play")
		"map": _show("map")
		"forge_weapon","forge_armor","rest":
			if screen == "forge":
				_forge(id)
		"quit":
			if screen == "title":
				get_tree().quit()
			else:
				_save()
				_show("title")

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if ending_tick >= 0:
		return
	if screen == "prologue":
		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_leave_prologue()
		return
	if screen == "recipes" and event.keycode == KEY_ESCAPE:
		_show("expedition")
		return
	if screen=="library_read":
		if event.keycode==KEY_ESCAPE: library.close_book()
		return
	if screen == "tide_bells" and event.keycode in [KEY_1,KEY_2,KEY_3]:
		bells.strike(event.keycode-KEY_1,self)
		return
	if screen=="post" and event.keycode==KEY_ESCAPE:
		_show("play")
		return
	match event.keycode:
		KEY_ESCAPE:
			if screen == "play":
				_show("pause")
			elif screen in ["map","forge","pause","folk_talk","folk_journal","tide_bells","expedition","fieldguide","settings","notes","field_note"]:
				_show("play")
		KEY_R,KEY_T:
			if screen == "play":
				survival.consume("eat" if event.keycode == KEY_R else "drink")
				_refresh()
				_save()
		KEY_Q:
			if screen=="play" and not _expedition_zone().is_empty() and not ferry.afloat:
				trails.restore("")
				voyage.tracking=voyage.tracking%3+1
				_refresh()
		KEY_J:
			if screen == "play": _show("folk_journal")
			elif screen == "folk_journal": _show("play")
		KEY_M:
			if screen == "play":
				_show("map")
			elif screen == "map":
				_show("play")
		KEY_E:
			if screen == "folk_talk":
				_finish_conversation()
			elif screen == "play":
				if library.inside:
					library.interact(library.nearby())
					return
				if ferry.afloat:
					ferry.disembark(self)
					return
				if survival.handle_interact():
					_refresh()
					return
				_nearest()
				if near_site.is_empty() and not wilds.net_prompt().is_empty():
					wilds.cast_net()
				else: _interact(near_site)
				_refresh()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and screen == "play" and ending_tick < 0 and is_instance_valid(hud) and hud.is_inside_tree():
		_show("pause")
	if what == NOTIFICATION_WM_CLOSE_REQUEST and screen not in ["title","win"] and not prologue_preview and is_node_ready():
		_save()

func _process(delta: float) -> void:
	if screen != "play":
		return
	if library.inside:
		screen_tick-=delta
		if screen_tick<=0.:
			screen_tick=.10
			_refresh()
		return
	if ending_tick >= 0:
		ending_tick -= delta
		if in_tower and ending_tick <= 3.0:
			_travel(false)
			_place_hero(world.POINTS.spawn)
			hero.camera_yaw = -1.56
			_frame_cape()
			coast_camera.make_current()
			_save()
		if ending_tick <= 0:
			ending_tick = -1
			_show("win")
		return
	var was_night := _night()
	starwatch.tick(delta)
	time_elapsed += delta
	_conditions()
	var region_id := _expedition_zone()
	if not in_tower:
		survival.tick(delta,region_id,crests)
	hero.sprint_scale=survival.sprint_scale()
	hero.bow_sway=survival.bow_sway()
	ferry.step(delta,self)
	wetlands.advance(delta,world_day,Vector2(hero.position.x,hero.position.z))
	wilds.tick(_day_index(),not in_tower and not ferry.afloat,survival.phase,world_day,tide_level)
	if _night() and not was_night and not in_tower and not won and not defeated.has("night_hound") and not creatures.has_node("night_hound"):
		_actor("hound",Vector2(-36,22),"night_hound")
	mirror_light.light_energy = move_toward(mirror_light.light_energy,0,delta*0.8)
	vent.emitting = _vent_hot()
	screen_tick -= delta
	save_tick -= delta
	if screen_tick <= 0:
		screen_tick = 0.10
		_safe_shore()
		_discover()
		_refresh()
	if save_tick <= 0:
		_save()

func _conditions() -> void:
	var clock := fposmod(time_elapsed,1440.0)
	if clock < 720: world_day = 1.0
	elif clock < 840: world_day = 1.0 - smoothstep(720,840,clock)
	elif clock < 1320: world_day = 0.0
	else: world_day = smoothstep(1320,1440,clock)
	var tide_clock := fposmod(time_elapsed,600.0)
	if tide_clock < 180: tide_level = 0.0
	elif tide_clock < 300: tide_level = smoothstep(180,300,tide_clock)
	elif tide_clock < 480: tide_level = 1.0
	else: tide_level = 1.0 - smoothstep(480,600,tide_clock)
	hero.set_daylight(world_day)
	world.set_conditions(world_day,tide_level,won)

func _night() -> bool:
	return fposmod(time_elapsed,1440.0) >= 840 and fposmod(time_elapsed,1440.0) < 1320

func _vent_hot() -> bool:
	return fposmod(time_elapsed,6.0) < 3.4

func _expedition_zone() -> String:
	if in_tower or library.inside: return ""
	return Geo.zone_at(Vector2(hero.position.x,hero.position.z))

func _earn_crest(zone: String) -> void:
	if not Voyage.ORDER.has(zone) or crests.has(zone): return
	crests.append(zone)
	world.set_beacon_crests(crests, won)
	if not won and (trails.pin == trails.CREST+zone or (_all_crests() and trails.pin.is_empty())):
		trails.restore(trails.MAIN)
	if _all_crests() and not won:
		_notice("六枚纹章已集齐。回望潮岬，登塔点亮六纹章灯座。","chime")
	else:
		_notice("获得%s纹章 · %d/%d。它会在%s护佑你。" % [Voyage.CRESTS[zone],crests.size(),Voyage.ORDER.size(),Voyage.NAMES[zone]],"chime")
	_refresh()
	_save()

func _record_capture(zone: String) -> void:
	if not taken.has("capture_"+zone):
		taken.append("capture_"+zone)
		_first_capture = zone

func _harvest_prey(zone: String) -> void:
	if hunted_today.get(zone,-1) == _day_index(): return
	hunted_today[zone] = _day_index()
	survival.add_harvest(zone)
	if _first_capture == zone:
		var total := 0
		for id: String in Voyage.ORDER:
			if taken.has("capture_"+id): total += 1
		_notice("首次网获%s　·　六地捕获记录 %d/6" % [wilds.GUIDE[zone].prey,total],"chime")
	else:
		_notice("收获%s　·　可带回村口图桌备粮" % wilds.GUIDE[zone].trophy,"pickup")
	_first_capture = ""
	if trails.pin == trails.HUNT+zone: trails.restore("")
	_save()

func _safe_shore() -> void:
	if ferry.afloat: return
	var p := Vector2(hero.position.x,hero.position.z)
	if not world.is_walkable(p.x,p.y) or hero.position.y < world.ground_height(p.x,p.y)-2.0:
		if not world.is_walkable(last_dry.x,last_dry.y):
			last_dry = Geo.safe_return(p) if not _expedition_zone().is_empty() else (sites.beach if not in_tower else Vector2(0,135))
		_place_hero(last_dry)
		_notice("已回到最近的干地。")
	else:
		last_dry = p

func _discover() -> void:
	if in_tower:
		return
	var pos := Vector2(hero.position.x,hero.position.z)
	var zone := _expedition_zone()
	if not zone.is_empty() and not discovered.has("exp_"+zone):
		discovered.append("exp_"+zone)
		_notice("发现 · "+Voyage.NAMES[zone],"discover")
	for id in region_names:
		if not discovered.has(id) and pos.distance_to(world.POINTS[id]) < lerpf(9,17,world_day):
			discovered.append(id)
			_notice("发现  ·  " + str(region_names[id]),"discover")

func _day_index() -> int:
	return floori(time_elapsed/1440.0)

func _available(id: String) -> bool:
	if id.begins_with(trails.PREFIX): return true
	if id in post_roads.STOPS: return true
	if id in MATERIALS:
		return harvested.get(id,-1) < _day_index()
	if id == "mirror": return in_tower
	if id == "beacon": return in_tower and not won and _all_crests()
	if id in ["exit","tower","village","camp"]: return true
	return not taken.has(id)

func _nearest() -> void:
	if library.inside:
		near_site=library.nearby()
		return
	var p := Vector2(hero.position.x,hero.position.z)
	var best := 3.25
	near_site = ""
	for id in sites:
		var location: Vector2 = sites[id]
		if Island.Survey.in_mirror_room(location) != in_tower or not _available(id):
			continue
		var d := p.distance_to(location)
		if d < best:
			near_site = id
			best = d

	if not in_tower:
		for id: String in folk.locations:
			var d := p.distance_to(folk.locations[id])
			if d < best and folk.available(id,taken):
				best = d
				near_site = id

		if p.distance_to(bells.spot) < best:
			near_site = bells.SITE

func _prompt(id: String) -> String:
	if library.inside or id==library.ENTRY_ID: return library.prompt(id)
	if id.begins_with(trails.PREFIX): return "看看"+str(trails.NOTES[id.trim_prefix(trails.PREFIX)][0])
	if ferry.afloat: return "系舟上岸" if ferry.can_land() else ""
	if id.begins_with(ferry.PREFIX): return "借舟 · W 划桨，A / D 掌舵"
	if id.is_empty() and not in_tower: return wilds.net_prompt()
	if id == Voyage.DESK: return "看地图，挑一条想走的路"
	if id.begins_with(Voyage.PREFIX): return "到营地吃饭、装水、补箭"
	if id==bells.SITE: return "拉钟绳" if not taken.has("bell_song") else "再看一次敲钟顺序"
	if folk.locations.has(id): return folk.prompt(id)
	if id in post_roads.STOPS: return str(post_roads.STOPS[id][0])+"邮驿 · 登记与搭乘邮班"
	match id:
		Starwatch.SITE:
			return "" if starwatch.active else "点燃守灯盘 · 两轮试炼"
		"village": return "铁匠铺 · 补油与打造"
		"camp": return "在营火休息并设为归返处"
		"rescue": return "扶起渔人"
		"harbor": return "交付一份修船物料" if _salvage() > 0 else "查看码头的修船清单"
		"forest": return "读守塔人的巡岛笔记"
		"winch": return "转动沉船绞盘"
		"valve": return "松开旁通阀"
		"beach": return "收起沉船缆绳" if taken.has("winch") else "舱盖卡住了 · 找旁边的绞盘"
		"lake": return "取下备用密封圈" if taken.has("valve") else "水压过高 · 找旁边的阀门"
		"volcano": return "喷口正在泄压 · 等待蒸汽散开" if _vent_hot() else "取出冷却窑铸件"
		"tower":
			if won or _all_crests(): return "登上望潮岬镜室"
			return "查看纹章塔门（%d/%d）" % [crests.size(),Voyage.ORDER.size()]
		"mirror": return "转动聚光镜"
		"beacon": return "以六枚纹章点亮灯塔"
		"exit": return "下塔返回望潮岬"
	if id in MATERIALS:
		return "收集" + str(MATERIALS[id][0]) + " ×2"
	return ""

func _finish_conversation() -> void:
	if screen != "folk_talk": return
	_show("play")
	folk.reply(speaker,self)
	_refresh()

func _interact(id: String) -> void:
	if library.inside or id==library.ENTRY_ID:
		library.interact(id)
		return
	if trails.read_field(id,self): return
	if id.begins_with(ferry.PREFIX):
		ferry.board(id.trim_prefix(ferry.PREFIX).to_int(),self)
		return
	if voyage.use_site(id,self): return
	if id==bells.SITE:
		bells.open(self)
		return
	if folk.locations.has(id):
		if not folk.available(id,taken): return
		if id in folk.PEOPLE:
			speaker = id
			_show("folk_talk")
		else:
			folk.gather(id,self)
		return
	if id in post_roads.STOPS:
		post_roads.visit(id,self)
		return
	if id == "" or not _available(id): return
	match id:
		Starwatch.SITE:
			if not starwatch.active:
				starwatch.start()
			return
		"village":
			survival.resupply()
			hero.arrows = 12
			hero.oil = 40
			hero.hp = 100
			checkpoint = "village"
			_show("forge")
		"camp":
			survival.resupply()
			hero.arrows = 12
			checkpoint = "camp"
			hero.hp = 100
			if not taken.has("camp_oil"):
				taken.append("camp_oil")
				hero.oil = minf(40,hero.oil+20)
			_notice("林间营火已记录 · 体力恢复","start")
		"rescue":
			for creature in creatures.get_children():
				if creature.hp > 0 and creature.global_position.distance_to(hero.global_position)<4.3 and creature.intent!=creature.Intent.REPELLED:
					_notice("渔人身边有影兽。举灯逼退它，或出刀解围。")
					return
			taken.append(id)
			resin += 2
			_notice("渔人回到港边，留下了两份补网的树脂。","start")
		"harbor":
			if _salvage() == 0:
				_notice("渔船待修。沉船的缆绳、泵站的密封圈、冷却窑的铸件，送来任意一份即可。")
				return
			taken.append(id)
			_notice("物料已交给船匠，灰湾的渔船可以检修了。","chime")
		"forest":
			taken.append(id)
			_notice("巡岛笔记：六区各有一位守章首领。村里的图桌标着前往它们领地的路。","discover")
		"winch","valve":
			taken.append(id)
			_notice("舱盖升起 · 可取沉船缆绳" if id == "winch" else "压力退去 · 可取备用密封圈","switch")
		"beach","lake","volcano":
			if id == "beach" and not taken.has("winch"):
				_notice("顺着断桅边的绳索找绞盘。")
				return
			if id == "lake" and not taken.has("valve"):
				_notice("沿泵房外侧的管道找旁通阀。")
				return
			if id == "volcano" and _vent_hot():
				_notice("烫手！等喷口的蒸汽散去。")
				return
			taken.append(id)
			var hint := "可送到灰湾码头修船。" if not taken.has("harbor") else "已收进物料袋。"
			_notice("找到%s。%s" % [SHIP_SUPPLIES[id],hint],"pickup")
		"tower": _tower()
		"exit": _travel(false)
		"mirror":
			mirror_light.light_energy = 3.4
			_notice("镜光落向北侧的六纹章灯座。","switch")
		"beacon":
			won = true
			world.set_beacon_crests(crests, true)
			world.play_crest_ritual()
			world.set_conditions(.22,tide_level,true)
			props.refresh(time_elapsed,taken,prop_positions,true)
			hero.input_enabled = false
			hero.reset_combat()
			ending_tick = 4.8
			marks.hide()
			hud.play_layer.hide()
			var altar := _ground(sites.beacon)
			coast_camera.set_cull_mask_value(2,false)
			coast_camera.position = altar + Vector3(1.1,3.1,3.15)
			coast_camera.look_at(altar + Vector3(0,1.60,-2.1))
			coast_camera.make_current()
			_notice("六纹章共鸣。望潮岬的光重新照到了灰湾。","win")
		_:
			if id in MATERIALS:
				harvested[id] = _day_index()
				if MATERIALS[id][0] == "废铁": iron += 2
				else: resin += 2
				_notice("获得%s ×2" % MATERIALS[id][0],"pickup")
	_save()

func _all_crests() -> bool:
	for zone: String in Voyage.ORDER:
		if not crests.has(zone): return false
	return true

func _tower() -> void:
	if not won and not _all_crests():
		var missing := PackedStringArray()
		for zone: String in Voyage.ORDER:
			if not crests.has(zone): missing.append(Voyage.NAMES[zone])
		_notice("塔门上还有 %d 道暗纹。去%s击败首领。" % [missing.size(),"、".join(missing)])
		return
	_travel(true)
	_notice("塔灯长明。按 E 可从石阶返回望潮岬。" if won else "六道纹章开启了镜室。走到前方灯座，按 E 点灯。","start")

func _travel(inside: bool) -> void:
	in_tower = inside
	hero.peaceful = inside
	if inside:
		_place_hero(Vector2(0,135))
		hero.camera_yaw = 0
	else:
		_place_hero(world.POINTS.tower + Vector2(-1,2))
	_rebuild_encounters()

func _forge(id: String) -> void:
	if id == "rest":
		time_elapsed = (floorf(time_elapsed/1440.0)+1.0)*1440.0
		hero.hp = 100
		hero.oil = 40
		_conditions()
		_rebuild_encounters()
		_notice("天亮了 · 灯壶已补满","start")
	else:
		var blade := id == "forge_weapon"
		if (blade and hero.weapon_upgrade) or (not blade and hero.armor_upgrade):
			_notice("这件装备已经穿戴。")
			return
		var cost := 2 if blade else 4
		if iron < cost or resin < 2:
			_notice("材料不足 · 海滩找废铁，林中找树脂。")
			return
		iron -= cost
		resin -= 2
		if blade: hero.weapon_upgrade = true
		else: hero.armor_upgrade = true
		_notice("钩刃短矛已装备" if blade else "炉背护肩已装备","switch")
	_save()
	_refresh()

func _hero_died() -> void:
	call_deferred("_revive")

func _revive() -> void:
	ferry.reset()
	hero.input_enabled=screen=="play"
	hero.hp = 100
	hero.oil = maxf(hero.oil,12)
	if in_tower:
		_place_hero(Vector2(0,135))
	else:
		_place_hero(sites.get(checkpoint,world.POINTS.spawn) if checkpoint != "village" else world.POINTS.spawn)
		survival.resupply()
	_rebuild_encounters()
	_notice("重新站起 · 已得的纹章和装备都在","start")
	_save()

func _salvage() -> int:
	var count := 0
	for id in SHIP_SUPPLIES:
		if taken.has(id): count += 1
	return maxi(0,count - int(taken.has("harbor")))

func _objective() -> String:
	if library.inside: return "三面书架收录六地见闻，桌上放着守塔人的交接本"
	if ferry.afloat: return "W 划桨 · A / D 掌舵 · 靠岸按 E 系舟"
	if starwatch.active: return starwatch.objective()
	if in_tower:
		return "灯塔已经点亮，沿石阶下塔" if won else "到六纹章灯座前按 E，点亮灯塔"
	if trails.destination(self) is Vector2: return trails.label(self)
	var zone := _expedition_zone()
	if not zone.is_empty() and voyage.tracking>0:
		return voyage.objective(zone,Vector2(hero.position.x,hero.position.z),self)
	if won: return "灯塔已经点亮"
	if _all_crests(): return "六枚纹章已集齐。回望潮岬登塔点灯"
	if not zone.is_empty(): return "%s　·　Q 可选营地、猎场或首领" % Voyage.NAMES[zone]
	return "击败六区首领，收集纹章（%d/%d）" % [crests.size(),Voyage.ORDER.size()]

func _refresh() -> void:
	library.survey_progress(crests,taken)
	voyage.update_keepsakes(crests,taken)
	bells.sync(taken)
	folk.refresh(hero.position,in_tower,time_elapsed,world_day,taken)
	if screen == "prologue":
		for label: Label3D in folk.labels.values(): label.hide()
	_nearest()
	var p := Vector2(hero.position.x,hero.position.z)
	var region := "灰湾原野"
	var closest := 44.0
	for id in region_names:
		var distance := p.distance_to(world.POINTS[id])
		var radius := 25.0 if NAMES.has(id) else 44.0
		if distance < minf(closest,radius):
			closest = distance
			region = region_names[id]
	var expedition_zone := _expedition_zone()
	if not expedition_zone.is_empty(): region = Voyage.NAMES[expedition_zone]
	var hidden := taken.duplicate()
	for id: String in post_roads.STOPS:
		hidden.erase(id)
	for id in MATERIALS:
		if not _available(id): hidden.append(id)
	if not _available("mirror"): hidden.append("mirror")
	if not _available("beacon"): hidden.append("beacon")
	marks.visible=not library.inside and screen!="prologue"
	marks.refresh(hero.position,hidden,in_tower,time_elapsed)
	props.refresh(time_elapsed,taken,prop_positions,won)
	var facing: Vector3 = hero.get_forward()
	var phase := fposmod(time_elapsed,1440.0)
	var tide_clock := fposmod(time_elapsed,600.0)
	var active_folk: Dictionary = folk.targets(taken)
	var b_hp := -1.0
	var combat_hint: String = hero.combat_text
	if combat_hint.is_empty():
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if not enemy.is_queued_for_deletion() and enemy.global_position.distance_squared_to(hero.global_position)<48.0:
				combat_hint = "左键连续出刀   ·   光圈抵达边沿时按空格闪避"
				break
	if not expedition_zone.is_empty(): b_hp = wilds.boss_fraction()
	if hero.combat_text.is_empty() and not expedition_zone.is_empty() and not wilds.status_text().is_empty():
		combat_hint = wilds.status_text()
	var goal_position = trails.destination(self)
	var walking_route:=PackedVector2Array()
	if goal_position is Vector2:
		walking_route=trails.route(p,goal_position)
	if not (goal_position is Vector2) and not expedition_zone.is_empty() and voyage.tracking>0:
		goal_position=voyage.target(expedition_zone,self)
	var page: Dictionary = Prologue.PAGES[prologue_page] if screen == "prologue" else {}
	hud.update_view({"hp":hero.hp,"oil":hero.oil,"salvage":_salvage(),"lamp":hero.lamp_mode,
		"prologue_page":prologue_page,"prologue_count":Prologue.PAGES.size(),"prologue_preview":prologue_preview,
		"prologue_voiced":prologue_voiced,"prologue_title":page.get("title",""),
		"prologue_text":page.get("text",""),"prologue_caption":page.get("caption",""),
		"in_library":library.inside,"library_door":library.DOOR,"walking_route":walking_route,
		"directions":trails.direction(walking_route),"note_id":trails.current_note,"story_pin":trails.pin,
		"gentle_weather":gentle_weather,"volume_step":volume_step,
		"recipe_stock":survival.pantry,"meal_status":survival.meal_status(time_elapsed),
		"guide_rows":_field_rows() if screen=="fieldguide" else [],"afloat":ferry.afloat,
		"boss_name":wilds.boss_title() if not expedition_zone.is_empty() else "",
		"zone":expedition_zone,"crests":crests,"camp":voyage.camp_id(near_site),
		"tracked_point":goal_position,
		"field_status":survival.hud_text(),"weather":survival.weather_text() if not in_tower else "",
		"bow":hero.bow_selected,"draw":hero.bow_draw,"arrows":hero.arrows,
		"post_stops":post_roads.timetable(self) if screen=="post" else [],
		"can_recall":taken.has("bell_song") and not in_tower and not ferry.afloat,"bell_ready":harvested.get("bell_return",-1)!=_day_index(),
		"day":"白昼" if phase<720 else ("黄昏" if phase<840 else ("黑夜" if phase<1320 else "黎明")),
		"tide":"低潮" if tide_clock<180 else ("涨潮" if tide_clock<300 else ("高潮" if tide_clock<480 else "落潮")),
		"pos":library.DOOR if library.inside else p,"heading":Vector2(facing.x,facing.z),"region":"灰湾图书馆" if library.inside else ("灯塔镜室" if in_tower else region),
		"objective":_objective(),"prompt":_prompt(near_site),"discovered":discovered,"taken":taken,"points":world.POINTS,
		"iron":iron,"resin":resin,"weapon":hero.weapon_upgrade,"armor":hero.armor_upgrade,
		"combat_hint":combat_hint,
		"folk_speech":folk.conversation(speaker,taken,_night()) if screen=="folk_talk" else {},
		"folk_targets":active_folk,
		"folk_jobs":folk.ledger(taken,active_folk,world.POINTS.tower if in_tower else p,in_tower) if screen=="folk_journal" else [],
		"boss_hp":b_hp,"has_save":has_save,"in_tower":in_tower,"won":won})

func _notice(message: String, cue: String = "") -> void:
	hud.toast(message)
	if cue != "": soundscape.cue(cue)

func _choose_lead(id: String) -> void:
	trails.set_pin(id,self)
	_save()

func _reading_changed(opened: bool) -> void:
	_show("library_read" if opened else "play")
	_save()

func _library_changed(entered: bool) -> void:
	if entered and not taken.has("visited_library"):
		taken.append("visited_library")
	if entered and trails.pin=="library": trails.restore("")
	if not entered: last_dry=library.DOOR
	hero.peaceful=entered
	_show("play")
	if entered: _notice("左边是交接本，三面书架各藏两地的记录。靠近按 E 翻阅。")
	_save()

func _field_rows() -> Array:
	var rows := []
	for id: String in Voyage.ORDER:
		var entry: Dictionary = wilds.describe(id)
		rows.append([Voyage.NAMES[id]+"　"+("◆ " if crests.has(id) else "◇ ")+Voyage.CRESTS[id]+"纹章",
			"%s　/　%s　·　%s" % [entry.prey,entry.boss,entry.hint]])
	return rows

func _load_preferences() -> void:
	var pref:=ConfigFile.new()
	if pref.load("user://expedition-preferences.cfg")==OK:
		volume_step=clampi(pref.get_value("audio","volume_step",2),0,2)
		gentle_weather=pref.get_value("view","gentle_weather",false)
		prologue_voiced=pref.get_value("audio","prologue_voiced",true)
	_apply_preferences()

func _store_preferences() -> void:
	var pref := ConfigFile.new()
	pref.set_value("view","gentle_weather",gentle_weather)
	pref.set_value("audio","volume_step",volume_step)
	pref.set_value("audio","prologue_voiced",prologue_voiced)
	pref.save("user://expedition-preferences.cfg")

func _apply_preferences() -> void:
	AudioServer.set_bus_volume_db(0,LEVELS[volume_step])
	survival.fx.set("reduced_effects",gentle_weather)

func _save() -> void:
	save_tick = 12.0
	var safe_pos: Vector3 = _ground(sites[ferry.PREFIX+str(ferry.closest_landing())]) if ferry.afloat else hero.position
	if library.inside: safe_pos=_ground(library.DOOR)
	has_save = journal.write({"pos":safe_pos,"yaw":hero.camera_yaw,"hp":hero.hp,"oil":hero.oil,"lamp":hero.lamp_mode,
		"library":library.snapshot(),"walking_pin":trails.pin,"prologue_page":prologue_page,
		"crests":crests,"hunted_today":hunted_today,"survival":survival.snapshot(),"arrows":hero.arrows,"bow":hero.bow_selected,
		"weapon":hero.weapon_upgrade,"armor":hero.armor_upgrade,"iron":iron,"resin":resin,"taken":taken,
		"discovered":discovered,"harvested":harvested,"defeated":defeated,
		"clock":time_elapsed,"inside":in_tower,"won":won,"checkpoint":checkpoint})
	if not has_save: hud.toast("存档写入失败，请检查本地存储。")

func _restore() -> void:
	var data: Dictionary = journal.read()
	if data.is_empty():
		_notice("没有找到存档。")
		return
	ferry.reset()
	library.restore(data.get("library",{}))
	hero.peaceful=false
	trails.restore(data.get("walking_pin",""))
	var saved_page = data.get("prologue_page",-1)
	prologue_page = saved_page if saved_page is int and saved_page >= 0 and saved_page < Prologue.PAGES.size() else -1
	prologue_preview = false
	discovered = data.get("discovered",["village"])
	taken = data.taken
	library.sync_field_notes(taken)
	defeated = data.get("defeated",[])
	harvested = data.get("harvested",{})
	crests = []
	var saved_crests = data.get("crests",[])
	if saved_crests is Array:
		for zone in saved_crests:
			if zone is String and Voyage.ORDER.has(zone) and not crests.has(zone):
				crests.append(zone)
	hunted_today = data.get("hunted_today",{})
	survival.restore(data.get("survival",{}),hunted_today,taken)
	voyage.tracking = 0
	hero.arrows = clampi(data.get("arrows",12),0,12)
	hero.bow_selected = data.get("bow",false)
	iron = data.get("iron",0)
	resin = data.get("resin",0)
	time_elapsed = data.get("clock",650.0)
	won = data.get("won",false)
	var was_inside: bool = data.get("inside",false)
	in_tower = was_inside and (won or _all_crests())
	hero.peaceful = in_tower
	world.set_beacon_crests(crests, won)
	checkpoint = data.get("checkpoint","village")
	hero.hp = clampf(data.get("hp",100),1,100)
	hero.oil = clampf(data.get("oil",40),0,40)
	hero.lamp_mode = mini(data.get("lamp",1),1) if hero.oil>0 else 0
	hero.weapon_upgrade = data.get("weapon",false)
	hero.armor_upgrade = data.get("armor",false)
	hero.camera_yaw = data.get("yaw",-0.7)
	ending_tick = -1
	_conditions()
	var saved_pos: Vector3 = data.pos
	var resume_pos := Vector2(saved_pos.x,saved_pos.z)
	var moved_to_cape := not in_tower and (was_inside or Island.Survey.in_mirror_room(resume_pos))
	if moved_to_cape:
		resume_pos = world.POINTS.tower + Vector2(-1,2)
	elif not in_tower and not Geo.zone_at(resume_pos).is_empty() and not world.is_walkable(resume_pos.x,resume_pos.y):
		resume_pos = Geo.safe_return(resume_pos)
	_place_hero(resume_pos)
	_rebuild_encounters()
	if prologue_page >= 0:
		_show("prologue")
		return
	_show("play")
	_notice("已回到望潮岬。带齐六区首领的纹章即可再次登塔。" if moved_to_cape else "回到上次停下的地方了。","start")
