extends Node3D
const Geog = preload("world/expedition_geography.gd")
const Beast = preload("actors/expedition_beast.gd")
const Art = preload("actors/actor_art.gd")

signal crest_earned(zone_id: String)
signal harvested(zone_id: String)
signal net_cast(caught: bool)
signal captured(zone_id: String)

const GUIDE := {
	"snow":{"prey":"霜羽松鸡","boss":"雪鬃盘角羊","crest":"雪绒纹章","trophy":"松鸡禽肉","hint":"贴近石柱，横闪避开冲角。盘角羊撞柱后会长时间露出侧腹。","catch_hint":"离松鸡三四步停下。等它收翅、低头啄雪时按 E 下网，贴得太近会把它惊飞。"},
	"tide":{"prey":"青壳潮蟹","boss":"沉锚寄居蟹","crest":"礁足纹章","trophy":"青壳蟹肉","hint":"潮环逼近脚边时闪避。拔锚翻身时，击打亮起的软腹。","catch_hint":"跟着横行的青蟹走。低潮它会伏沙，高水时缩螯的工夫短些。等壳沉下就按 E。"},
	"volcano":{"prey":"灰冠岩蜥","boss":"引雷角兽","crest":"余烬纹章","trophy":"岩蜥鲜肉","hint":"雷圈锁定脚下后横移，让追来的角兽踩进雷圈。","catch_hint":"在岩蜥近处守候。等它停步，压低身子贴住岩面时按 E 下网。"},
	"desert":{"prey":"沙帆兔","boss":"鸣砂巨蝎","crest":"背风纹章","trophy":"沙兔鲜肉","hint":"沙线锁定冲刺方向。把巨蝎引向硬砾石，侧闪后攻击卡住的尾针。","catch_hint":"沙帆兔受惊后会连跳两下。跟上它，在第二跳落地、伏低歇脚时按 E。"},
	"lake":{"prey":"银灯鳟","boss":"回声鳐","crest":"听澜纹章","trophy":"银灯鳟鱼","hint":"真身荡出连续两圈水纹。等第二圈过去，趁浅岸露背进攻。","catch_hint":"站在浅岸等鱼背浮上来。银灯鳟露出脊背时，朝跟前的水面按 E 下网。"},
	"forest":{"prey":"银背枝貂","boss":"冠枝角鹿","crest":"盘根纹章","trophy":"枝貂毛皮","hint":"角鹿先扫面前，再拨动侧面树枝。绕去未受风的一侧，趁鹿角低垂进攻。","catch_hint":"枝貂绕着林地折返。等它停住，昂起头嗅风时按 E 下网，紧追会把它赶走。"}
}
var keeper
var world
var bosses := {}
var prey := {}
var _crests: Array = []
var _hunted := {}
var _day := 0
var _running := false
var _net_recovery := 0.0
var net_position := Vector3.ZERO

func build(hero,island,_camps: Dictionary) -> void:
	keeper = hero
	world = island

func restore(crests: Array,hunted_today: Dictionary,day: int) -> void:
	_net_recovery=0.
	_crests = crests.duplicate()
	_hunted = hunted_today.duplicate()
	_day = day
	for table: Dictionary in [bosses,prey]:
		for id in table.keys():
			_retire(table,id)

func _retire(table: Dictionary,id: String) -> void:
	var actor = table[id]
	table.erase(id)
	if is_instance_valid(actor):
		actor.set_running(false)
		actor.remove_from_group("enemies" if actor.champion else "expedition_prey")
		actor.queue_free()

func tick(day: int,enabled: bool,weather: String="calm",daylight: float=.55,tide: float=.15) -> void:
	if not is_instance_valid(keeper):
		return
	_day = day
	if _running!=enabled:
		_running = enabled
		for actor in bosses.values()+prey.values():
			actor.set_physics_process(enabled)
	if not enabled:
		return
	var pos := Vector2(keeper.global_position.x,keeper.global_position.z)
	for id: String in GUIDE:
		_stream(id,true,pos)
		_stream(id,false,pos)
	for animal in bosses.values()+prey.values():
		animal.weather = weather
		animal.daylight = daylight
		animal.tide = tide

func _stream(id: String,big: bool,pos: Vector2) -> void:
	var table := bosses if big else prey
	var at: Vector2 = Geog.ARENAS[id] if big else Geog.HUNTS[id]
	var distance := pos.distance_squared_to(at)
	if table.has(id):
		if distance>66*66:
			_retire(table,id)
		return
	if distance>46*46 or (big and _crests.has(id)) or (not big and int(_hunted.get(id,-1))==_day):
		return
	var actor := Beast.new()
	table[id] = actor
	add_child(actor)
	actor.setup(id,big,GUIDE[id].boss if big else GUIDE[id].prey,keeper,world,Vector3(at.x,world.ground_height(at.x,at.y),at.y))
	actor.felled.connect(_on_felled)

func _on_felled(id: String,big: bool) -> void:
	if big:
		var fallen_at: Vector3 = bosses[id].global_position
		bosses.erase(id)
		if not _crests.has(id):
			_crests.append(id)
			_show_crest(id,fallen_at)
			crest_earned.emit(id)
	else:
		prey.erase(id)
		if int(_hunted.get(id,-1))!=_day:
			_hunted[id] = _day
			harvested.emit(id)

func _show_crest(id: String,fallen_at: Vector3) -> void:
	var crest := Node3D.new()
	add_child(crest)
	crest.global_position = fallen_at+Vector3.UP*1.0
	var face := Art.joint(crest,Vector3.ZERO)
	var disc := Art.taper(face,Vector3.ZERO,.31,.31,.09,"b3985b",12)
	disc.rotation.x = PI*.5
	var center := Art.taper(face,Vector3(0,0,.057),.25,.25,.025,"476b65",10)
	center.rotation.x = PI*.5
	var symbols := {
		"snow":[Vector2(-.18,-.10),Vector2(-.04,.14),Vector2(.04,.02),Vector2(.13,.14),Vector2(.20,-.10)],
		"tide":[Vector2(-.20,-.02),Vector2(-.09,.06),Vector2(.0,-.02),Vector2(.10,.06),Vector2(.2,-.02)],
		"volcano":[Vector2(.09,.18),Vector2(-.08,.01),Vector2(.055,.01),Vector2(-.10,-.18)],
		"desert":[Vector2(-.18,-.04),Vector2(.08,-.04),Vector2(.12,.03),Vector2(.04,.11)],
		"lake":[Vector2(-.18,.055),Vector2(-.09,-.06),Vector2(.04,-.10),Vector2(.18,.055)],
		"forest":[Vector2(-.12,-.16),Vector2(.0,-.01),Vector2(-.11,.12),Vector2(.0,-.01),Vector2(.14,.15)]}
	var knots: Array = symbols[id]
	for i in range(1,knots.size()):
		var a: Vector2 = knots[i-1]
		var b: Vector2 = knots[i]
		Art.rod(face,Vector3(a.x,a.y,.085),Vector3(b.x,b.y,.085),.023,.020,"f1d09b")
	var title := Label3D.new()
	crest.add_child(title)
	title.position.y=.48
	title.text=GUIDE[id].crest
	title.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	title.modulate=Color("ffdf92")
	title.font_size=38
	title.pixel_size=.009
	var toward: Vector3 = (keeper.global_position-crest.global_position).slide(Vector3.UP)
	face.rotation.y = atan2(toward.x,toward.z)
	var lift := crest.create_tween()
	lift.tween_property(crest,"position:y",crest.position.y+.68,.43).set_trans(Tween.TRANS_SINE)
	lift.tween_interval(1.65)
	lift.tween_property(crest,"scale",Vector3.ONE*.035,.24)
	lift.tween_callback(crest.queue_free)

func describe(id: String) -> Dictionary:
	return GUIDE.get(id,{})

func _near_champion():
	for actor in bosses.values():
		if actor._engaged and keeper.global_position.distance_squared_to(actor.global_position)<24.0*24.0:
			return actor
	return null

func status_text() -> String:
	var actor = _near_champion()
	if actor==null: return ""
	return "破绽已开 · 近战或短弓" if actor.exposed else GUIDE[actor.region].hint

func boss_fraction() -> float:
	var actor = _near_champion()
	return actor.hp/actor.max_hp if actor!=null else -1.0

func boss_title() -> String:
	var actor = _near_champion()
	return actor.hud_name if actor!=null else ""

func _physics_process(delta: float) -> void:
	if _running and _net_recovery>0.:
		_net_recovery=maxf(0.,_net_recovery-delta)

func _net_target() -> Beast:
	if not _running or not is_instance_valid(keeper) or not keeper.input_enabled or keeper.hp<=0.:
		return null
	var closest: Beast
	var best := 4.4*4.4
	for target: Beast in prey.values():
		var distance: float=keeper.global_position.distance_squared_to(target.global_position)
		if distance<best and target.hp>0. and keeper.has_clear_view(target.global_position+Vector3.UP*.45):
			best=distance
			closest=target
	return closest

func net_prompt() -> String:
	var target:=_net_target()
	if target==null: return ""
	if _net_recovery>0.: return "收回抄网…"
	var cue: Array=Beast.NET_CUES[target.region]
	return str(cue[0])+" · 现在下网" if target.net_window() else str(cue[1])

func cast_net() -> bool:
	var target:=_net_target()
	if target==null: return false
	if _net_recovery>0.: return true
	var caught:=target.net_window()
	_net_recovery=.65 if caught else .88
	net_position=target.global_position
	net_cast.emit(caught)
	if caught: captured.emit(target.region)
	target.resolve_net(caught)
	return true
