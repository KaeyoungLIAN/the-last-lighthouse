extends Node3D

const Island = preload("res://world/world.gd")
const Keeper = preload("res://actors/player.gd")
const Foe = preload("res://actors/enemy.gd")
const Interface = preload("res://ui/hud.gd")
const Journal = preload("res://journal.gd")
const Waymarks = preload("res://waymarks.gd")
const FieldProps = preload("res://field_props.gd")
const Soundscape = preload("res://soundscape.gd")
const FUELS := ["beach","lake","volcano"]
const NAMES := {"village":"灰湾村","forest":"雾根林","beach":"月牙滩","lake":"镜湖泵站","volcano":"赤炉冷却窑","tower":"望潮岬灯塔"}
const MATERIALS := {"driftwood":["废铁",Vector2(-56,3)],"sap":["树脂",Vector2(-33,-8)],"scrap":["废铁",Vector2(5,-25)],"pitch":["树脂",Vector2(-19,-18)],"slag":["废铁",Vector2(44,-30)]}
const ENCOUNTERS := [
	["hound",Vector2(-30,-8)],["hound",Vector2(-20,-14)],["crab",Vector2(-60,5)],
	["fin",Vector2(8,-27)],["lizard",Vector2(43,-30)],["elite",Vector2(32,-30)]
]
var world = Island.new()
var hero = Keeper.new()
var hud = Interface.new()
var journal = Journal.new()
var marks = Waymarks.new()
var props = FieldProps.new()
var prop_positions := {}
var soundscape = Soundscape.new()
var creatures := Node3D.new()
var coast_camera := Camera3D.new()
var sites: Dictionary = {}
var discovered: Array = ["village"]
var taken: Array = []
var defeated: Array = []
var harvested: Dictionary = {}
var iron := 0
var resin := 0
var loaded := 0
var time_elapsed := 650.0
var in_tower := false
var won := false
var screen := "title"
var near_site := ""
var boss = null
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
	coast_camera.position = Vector3(77,19,60)
	coast_camera.look_at(Vector3(28,7,24))
	hero.died.connect(_hero_died)
	hero.struck.connect(func(): soundscape.cue("hit"))
	add_child(soundscape)
	add_child(hud)
	hud.action.connect(_on_action)
	_make_sites()
	for id in ["camp","valve","winch","rescue","harbor"]:
		prop_positions[id] = _ground(sites[id])
	add_child(props)
	props.build(prop_positions)
	_build_effects()
	has_save = not journal.read().is_empty()
	_place_hero(world.POINTS.spawn)
	_conditions()
	_show("title")

func _make_sites() -> void:
	for id in NAMES:
		_add_site(id, NAMES[id], world.POINTS[id])
	_add_site("winch","沉船绞盘",world.POINTS.beach + Vector2(3.4,3.6))
	_add_site("valve","泵站旁通阀",world.POINTS.lake + Vector2(-4.2,3.0))
	_add_site("camp","林间营火",Vector2(-18,-6))
	_add_site("rescue","村口的渔人",Vector2(-37,19))
	_add_site("harbor","灰湾引航灯",Vector2(-46,36))
	_add_site("exit","下塔石阶",Vector2(0,137))
	_add_site("mirror","聚光镜柄",world.POINTS.mirror)
	_add_site("beacon","灯芯",world.POINTS.beacon)
	for id in MATERIALS:
		_add_site(id,MATERIALS[id][0],MATERIALS[id][1],true)

func _add_site(id: String, caption: String, where: Vector2, resource: bool = false) -> void:
	var at := _walkable_near(where)
	sites[id] = at
	var tint := Color("a7e3c3") if resource else Color("f4c06d")
	marks.add_site(id,caption,_ground(at),tint,resource)

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
	var safe := _walkable_near(p)
	hero.global_position = _ground(safe) + Vector3.UP*0.12
	hero.velocity = Vector3.ZERO
	last_dry = safe
	hero.reset_physics_interpolation()

func _actor(kind: String, loc: Vector2, identity: String):
	var enemy = Foe.new()
	creatures.add_child(enemy)
	enemy.setup(kind,hero,world,_ground(_walkable_near(loc)) + Vector3.UP*0.08)
	enemy.fallen.connect(_foe_fallen.bind(identity))
	return enemy

func _rebuild_encounters() -> void:
	for child in creatures.get_children():
		creatures.remove_child(child)
		child.queue_free()
	boss = null
	if in_tower:
		if taken.has("awakened") and not taken.has("guardian"):
			boss = _actor("boss",Vector2(1,126),"guardian")
	elif not won:
		for i in ENCOUNTERS.size():
			var identity := "wild_" + str(i)
			if not defeated.has(identity):
				_actor(ENCOUNTERS[i][0],ENCOUNTERS[i][1],identity)
		if _night() and not defeated.has("night_hound"):
			_actor("hound",Vector2(-36,22),"night_hound")
		if not taken.has("rescue") and not defeated.has("net_hound"):
			_actor("hound",Vector2(-36,15),"net_hound")

func _foe_fallen(kind: String, identity: String) -> void:
	if kind == "boss":
		if not taken.has("guardian"):
			taken.append("guardian")
		boss = null
		_notice("影壳破碎了。走到灯芯旁，亲手点灯。","chime")
	elif not defeated.has(identity):
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
	if next in ["title","win"]:
		coast_camera.make_current()
		world.set_conditions(0.38 if next == "title" else 0.22,tide_level,won)
	else:
		hero.camera.make_current()
		_conditions()
	hero.input_enabled = playing and ending_tick < 0
	hero.process_mode = Node.PROCESS_MODE_INHERIT if playing else Node.PROCESS_MODE_DISABLED
	creatures.process_mode = hero.process_mode
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if playing else Input.MOUSE_MODE_VISIBLE
	_refresh()
	hud.set_screen(next)

func _new_game() -> void:
	discovered = ["village"]
	taken = []
	defeated = []
	harvested = {}
	iron = 0
	resin = 0
	loaded = 0
	time_elapsed = 650.0
	in_tower = false
	won = false
	ending_tick = -1
	checkpoint = "village"
	hero.hp = 100
	hero.oil = 40
	hero.lamp_mode = 1
	hero.weapon_upgrade = false
	hero.armor_upgrade = false
	hero.camera_yaw = -0.70
	_conditions()
	_place_hero(world.POINTS.spawn)
	_rebuild_encounters()
	_show("play")
	_notice("守塔人的钥匙在雾根林小屋。按 M 查看岛图。","start")
	_save()

func _on_action(id: String) -> void:
	match id:
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
	match event.keycode:
		KEY_ESCAPE:
			if screen == "play":
				_show("pause")
			elif screen in ["map","forge","pause"]:
				_show("play")
		KEY_M:
			if screen == "play":
				_show("map")
			elif screen == "map":
				_show("play")
		KEY_E:
			if screen == "play":
				_nearest()
				_interact(near_site)
				_refresh()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and screen == "play" and ending_tick < 0 and is_instance_valid(hud) and hud.is_inside_tree():
		_show("pause")
	if what == NOTIFICATION_WM_CLOSE_REQUEST and screen in ["play","pause","forge","map"]:
		_save()

func _process(delta: float) -> void:
	if screen != "play":
		return
	if ending_tick >= 0:
		ending_tick -= delta
		if ending_tick <= 0:
			ending_tick = -1
			_show("win")
		return
	var was_night := _night()
	time_elapsed += delta
	_conditions()
	if _night() and not was_night and not in_tower and not won and not defeated.has("night_hound"):
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

func _safe_shore() -> void:
	var p := Vector2(hero.position.x,hero.position.z)
	if not world.is_walkable(p.x,p.y) or hero.position.y < world.ground_height(p.x,p.y)-2.0:
		if not world.is_walkable(last_dry.x,last_dry.y):
			last_dry = sites.beach if not in_tower else Vector2(0,135)
		_place_hero(last_dry)
		_notice("已回到最近的干地。")
	else:
		last_dry = p

func _discover() -> void:
	if in_tower:
		return
	var pos := Vector2(hero.position.x,hero.position.z)
	for id in NAMES:
		if not discovered.has(id) and pos.distance_to(world.POINTS[id]) < lerpf(9,17,world_day):
			discovered.append(id)
			_notice("发现  ·  " + str(NAMES[id]),"discover")

func _day_index() -> int:
	return floori(time_elapsed/1440.0)

func _available(id: String) -> bool:
	if id in MATERIALS:
		return harvested.get(id,-1) < _day_index()
	if id == "mirror": return not taken.has("guardian")
	if id == "beacon": return taken.has("guardian") and not won
	if id in ["exit","tower","village","camp"]: return true
	return not taken.has(id)

func _nearest() -> void:
	var p := Vector2(hero.position.x,hero.position.z)
	var best := 3.25
	near_site = ""
	for id in sites:
		var location: Vector2 = sites[id]
		if (location.y > 100) != in_tower or not _available(id):
			continue
		var d := p.distance_to(location)
		if d < best:
			near_site = id
			best = d

func _prompt(id: String) -> String:
	match id:
		"village": return "铁匠铺 · 补油与打造"
		"camp": return "在营火休息并设为归返处"
		"rescue": return "扶起渔人"
		"harbor": return "把多余的第三罐燃料交给码头"
		"forest": return "取下守塔人的黄铜钥匙"
		"winch": return "转动沉船绞盘"
		"valve": return "松开旁通阀"
		"beach": return "取出沉船油罐" if taken.has("winch") else "舱盖卡住了 · 找旁边的绞盘"
		"lake": return "取出泵站油罐" if taken.has("valve") else "水压过高 · 找旁边的阀门"
		"volcano": return "喷口正在泄压 · 等待蒸汽散开" if _vent_hot() else "卸下冷却窑油罐"
		"tower":
			if not taken.has("door"): return "用黄铜钥匙开门" if taken.has("forest") else "查看塔门锁"
			if loaded < 2: return "给供油机装罐（%d/2）" % loaded
			return "登上镜室"
		"mirror": return "转动镜架 · 驱散影壳" if taken.has("awakened") else "转动镜架 · 唤醒守护者"
		"beacon": return "点亮最后一座灯塔"
		"exit": return "下塔返回望潮岬"
	if id in MATERIALS:
		return "收集" + str(MATERIALS[id][0]) + " ×2"
	return ""

func _interact(id: String) -> void:
	if id == "" or not _available(id): return
	match id:
		"village":
			hero.oil = 40
			hero.hp = 100
			checkpoint = "village"
			_show("forge")
		"camp":
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
			if loaded < 2 or _fuel() < 3:
				_notice("先为灯塔装满两罐燃料，再把第三罐送到码头。")
				return
			taken.append(id)
			_notice("引航灯亮起，渔船多了一处归港的路标。","chime")
		"forest":
			taken.append(id)
			_notice("黄铜钥匙入手 · 可以打开望潮岬塔门","chime")
		"winch","valve":
			taken.append(id)
			_notice("舱盖升起 · 可取沉船油罐" if id == "winch" else "压力退去 · 可取泵站油罐","switch")
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
			_notice("封装燃料入手（%d/3）" % _fuel(),"chime")
		"tower": _tower()
		"exit": _travel(false)
		"mirror":
			if not taken.has("awakened"):
				taken.append("awakened")
				_rebuild_encounters()
			if is_instance_valid(boss):
				boss.break_shell()
				mirror_light.light_energy = 3.4
				_notice("镜面聚光 · 影壳张开，趁现在进攻！","switch")
		"beacon":
			if not taken.has("guardian"): return
			won = true
			_travel(false)
			_place_hero(world.POINTS.spawn)
			hero.camera_yaw = -1.56
			hero.input_enabled = false
			ending_tick = 3.0
			coast_camera.make_current()
			world.set_conditions(0.22,tide_level,true)
			_notice("两盏灯在海面接力，最后一艘渔船也进了港。" if taken.has("harbor") else "光越过河口，灰湾村的船回港了。","win")
		_:
			if id in MATERIALS:
				harvested[id] = _day_index()
				if MATERIALS[id][0] == "废铁": iron += 2
				else: resin += 2
				_notice("获得%s ×2" % MATERIALS[id][0],"pickup")
	_save()

func _tower() -> void:
	if not taken.has("forest"):
		_notice("铜锁上刻着树形记号。钥匙在雾根林小屋。")
	elif not taken.has("door"):
		taken.append("door")
		_notice("塔门已开 · 再按 E 给供油机装罐","switch")
	elif loaded < 2:
		var amount := mini(_fuel() - loaded,2-loaded)
		if amount > 0:
			loaded += amount
			_notice("供油机 %d/2 · %s" % [loaded,"升降机已就绪" if loaded == 2 else "还缺一罐"],"switch")
		else: _notice("还需 %d 罐塔用燃料。" % (2-loaded))
	else:
		_travel(true)
		_notice("镜室 · 拉动左边的镜柄，照开守护者的影壳。","start")

func _travel(inside: bool) -> void:
	in_tower = inside
	if inside:
		_place_hero(Vector2(0,135))
		hero.camera_yaw = 0
		hero.oil = 40
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
	hero.hp = 100
	hero.oil = maxf(hero.oil,12)
	if in_tower:
		_place_hero(Vector2(0,135))
	else:
		_place_hero(sites.camp if checkpoint == "camp" else world.POINTS.spawn)
	_rebuild_encounters()
	_notice("重新站起 · 钥匙、燃料和装备都保留了","start")
	_save()

func _fuel() -> int:
	var count := 0
	for id in FUELS:
		if taken.has(id): count += 1
	return count

func _objective() -> String:
	if won: return "灯塔已经点亮"
	if taken.has("guardian"): return "登上灯台，点亮灯芯"
	if in_tower: return "用镜架或举灯破壳，击败守护者" if taken.has("awakened") else "转动镜架，让光照进镜室"
	if loaded == 2: return "从望潮岬塔门登上镜室"
	if not taken.has("forest"): return "沿村北的路进雾根林，找守塔人的钥匙"
	if _fuel() < 2: return "寻找两罐燃料 · 沉船、泵站或冷却窑"
	return "前往望潮岬，启动灯塔供油机"

func _refresh() -> void:
	_nearest()
	var p := Vector2(hero.position.x,hero.position.z)
	var region := "灰湾原野"
	var closest := 25.0
	for id in NAMES:
		var distance := p.distance_to(world.POINTS[id])
		if distance < closest:
			closest = distance
			region = NAMES[id]
	var hidden := taken.duplicate()
	for id in MATERIALS:
		if not _available(id): hidden.append(id)
	if not _available("mirror"): hidden.append("mirror")
	if not _available("beacon"): hidden.append("beacon")
	marks.refresh(hero.position,hidden,in_tower,time_elapsed)
	props.refresh(time_elapsed,taken,prop_positions)
	var facing: Vector3 = hero.get_forward()
	var phase := fposmod(time_elapsed,1440.0)
	var tide_clock := fposmod(time_elapsed,600.0)
	var b_hp := -1.0
	if is_instance_valid(boss): b_hp = float(boss.hp)/maxf(1,boss.max_hp)
	hud.update_view({"hp":hero.hp,"oil":hero.oil,"key":taken.has("forest"),"fuel":_fuel(),"loaded":loaded,"lamp":hero.lamp_mode,
		"day":"白昼" if phase<720 else ("黄昏" if phase<840 else ("黑夜" if phase<1320 else "黎明")),
		"tide":"低潮" if tide_clock<180 else ("涨潮" if tide_clock<300 else ("高潮" if tide_clock<480 else "落潮")),
		"pos":p,"heading":Vector2(facing.x,facing.z),"region":"灯塔镜室" if in_tower else region,
		"objective":_objective(),"prompt":_prompt(near_site),"discovered":discovered,"taken":taken,"points":world.POINTS,
		"iron":iron,"resin":resin,"weapon":hero.weapon_upgrade,"armor":hero.armor_upgrade,
		"boss_hp":b_hp,"has_save":has_save,"in_tower":in_tower,"won":won})

func _notice(message: String, cue: String = "") -> void:
	hud.toast(message)
	if cue != "": soundscape.cue(cue)

func _save() -> void:
	save_tick = 12.0
	has_save = journal.write({"pos":hero.position,"yaw":hero.camera_yaw,"hp":hero.hp,"oil":hero.oil,"lamp":hero.lamp_mode,
		"weapon":hero.weapon_upgrade,"armor":hero.armor_upgrade,"iron":iron,"resin":resin,"taken":taken,
		"loaded":loaded,"discovered":discovered,"harvested":harvested,"defeated":defeated,
		"clock":time_elapsed,"inside":in_tower,"won":won,"checkpoint":checkpoint})
	if not has_save: hud.toast("存档写入失败，请检查本地存储。")

func _restore() -> void:
	var data: Dictionary = journal.read()
	if data.is_empty():
		_notice("找不到可读取的航程。")
		return
	discovered = data.get("discovered",["village"])
	taken = data.taken
	defeated = data.get("defeated",[])
	harvested = data.get("harvested",{})
	iron = data.get("iron",0)
	resin = data.get("resin",0)
	loaded = clampi(data.get("loaded",0),0,2)
	time_elapsed = data.get("clock",650.0)
	won = data.get("won",false)
	in_tower = data.get("inside",false)
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
	_place_hero(Vector2(saved_pos.x,saved_pos.z))
	_rebuild_encounters()
	_show("play")
	_notice("已继续上次的航程","start")
