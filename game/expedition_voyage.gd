extends Node3D
## One physical chart table starts an expedition. Field camps supply the return passage.
const Geo := preload("res://world/expedition_geography.gd")
const Art := preload("res://actors/actor_art.gd")
const DESK := "voyage_desk"
const PREFIX := "trailcamp_"
const HOME := Vector2(-37.4,35.6)
const ORDER := ["snow","tide","volcano","desert","lake","forest"]
const NAMES := {"snow":"白脊岭","tide":"回浪湾","volcano":"赤炉山","desert":"鸣砂海","lake":"沉钟湖","forest":"长青林海"}
const BEARINGS := {"snow":"西北 · 雪山","tide":"正西 · 潮汐滩","volcano":"西南 · 火山","desert":"东南 · 沙漠","lake":"正东 · 大湖","forest":"东北 · 林海"}
const HINTS := {
	"snow":"看不清路时，找下一面旗子","tide":"先看看高岸在哪儿。夜里浪大，往高处走",
	"volcano":"绕开岩浆。地上出现蓝线，赶紧跑开","desert":"到沙丘背风的那边去，营地可以装水",
	"lake":"听见钟声，再看看水面。真的钟旁边有两圈水纹","forest":"桥边的蕨叶翻白了，先在树后等风过去"
}
const COLORS := {"snow":"b6d9ea","tide":"80c4af","volcano":"d78a71","desert":"e1bd7e","lake":"8ab9cd","forest":"9dbb83"}
const CRESTS := {"snow":"雪绒","tide":"礁足","volcano":"余烬","desert":"背风","lake":"听澜","forest":"盘根"}
const MEAL_MINUTES := 360.0
const RECIPES := {
	"snow":["姜汤焖松鸡","松鸡禽肉","在白脊岭，风雪造成的降温减半。"],
	"tide":["潮蟹米粥","青壳蟹肉","在回浪湾，湿衣的晾干速度加倍。"],
	"volcano":["凉拌岩蜥丝","岩蜥鲜肉","在赤炉山，地热造成的升温减半。"],
	"desert":["沙兔清汤","沙兔鲜肉","在鸣砂海，饮水消耗减半。"],
	"lake":["烟熏银灯鳟","银灯鳟鱼","在沉钟湖划船时，饱食消耗减半。"],
	"forest":["山菌烤饼","枝貂毛皮换山菌","在长青林海奔跑时，饱食消耗减半。"]
}
var table_marks := {}
var shade_flags := {}
var tracking := 0
const GOALS := ["营地","猎场","首领出没的地方"]

func build(game) -> void:
	game._add_site(DESK,"远征图桌",HOME)
	var at: Vector3 = game._ground(game.sites[DESK])
	var desk := Art.joint(self,at + Vector3(.70,0,-.6))
	desk.rotation.y = -.18
	var chart := preload("res://art/greybay/voyage_chart.glb").instantiate() as Node3D
	chart.name = "GreybayChartTable"
	desk.add_child(chart)
	var landing_net := preload("res://art/greybay/field_net.glb").instantiate() as Node3D
	landing_net.name = "HangingDipNet"
	desk.add_child(landing_net)
	landing_net.position = Vector3(.57,.906,.552)
	landing_net.rotation = Vector3(-1.42,.08,-.19)
	for mesh: MeshInstance3D in landing_net.find_children("*","MeshInstance3D",true,false):
		mesh.visibility_range_end = 28.0
	for id: String in ORDER:
		table_marks[id] = chart.get_node("ChartToken_" + id)
		shade_flags[id] = chart.get_node("CatchPennant_" + id)
	update_keepsakes([],[])
	for id: String in ORDER:
		game._add_site(PREFIX+id,NAMES[id]+"的营地",Geo.CAMPS[id])

func update_keepsakes(crests: Array,flags: Array) -> void:
	for id: String in ORDER:
		table_marks[id].visible=crests.has(id)
		shade_flags[id].visible=flags.has("village_taste_"+id)

func cook(game, id: String = "") -> void:
	if game.screen not in ["expedition","recipes"] or game.in_tower or game.near_site!=DESK: return
	var pos:=Vector2(game.hero.position.x,game.hero.position.z)
	if pos.distance_to(HOME)>3.6: return
	if id.is_empty():
		for region: String in ORDER:
			if game.survival.pantry.get(region,0)>0:
				id=region
				break
	if not RECIPES.has(id) or not game.survival.serve_meal(id,game.time_elapsed): return
	game.hero.oil=minf(40.,game.hero.oil+10.)
	var first_taste: bool=not game.taken.has("village_taste_"+id)
	if first_taste: game.taken.append("village_taste_"+id)
	game._save()
	game._show(game.screen)
	var note: String="闻芷端来%s，把路粮和灯油交给你。" % RECIPES[id][0]
	if first_taste: note+="桌边挂起了%s的彩旗。" % NAMES[id]
	game._notice(note,"chime")

func camp_id(site: String) -> String:
	return site.trim_prefix(PREFIX) if site.begins_with(PREFIX) else ""

func use_site(id: String,game) -> bool:
	if id != DESK and camp_id(id).is_empty(): return false
	if game.in_tower: return true
	if id != DESK:
		game.survival.resupply()
		game.hero.arrows = 12
		game.checkpoint = id
		if not game.taken.has("exp_camp_seen_"+camp_id(id)): game.taken.append("exp_camp_seen_"+camp_id(id))
		game._save()
	game._show("expedition")
	return true

func travel(destination: String,game) -> void:
	if game.screen != "expedition" or game.in_tower: return
	var homebound := destination == "home"
	var site: String = game.near_site
	if homebound:
		if camp_id(site).is_empty(): return
	elif site != DESK or not ORDER.has(destination): return
	var p := Vector2(game.hero.position.x,game.hero.position.z)
	if not game.sites.has(site) or p.distance_to(game.sites[site])>3.6: return
	tracking=0
	var pin: String = game.trails.HOME
	if not homebound:
		pin = destination if game.crests.has(destination) else game.trails.CREST+destination
	game.trails.set_pin(pin,game)
	game._show("play")
	game._save()

func tracked_kind(zone: String,game) -> int:
	if tracking>0: return tracking-1
	if not game.taken.has("exp_camp_seen_"+zone): return 0
	if game.hunted_today.get(zone,-1)!=game._day_index(): return 1
	return 0 if game.crests.has(zone) else 2

func target(zone: String,game) -> Vector2:
	match tracked_kind(zone,game):
		0: return Geo.CAMPS[zone]
		1: return Geo.HUNTS[zone]
	return Geo.ARENAS[zone]

func objective(zone: String,p: Vector2,game) -> String:
	var offset:=target(zone,game)-p
	var wind_rose:=["北","东北","东","东南","南","西南","西","西北"]
	var bearing:String=wind_rose[posmod(roundi(atan2(offset.x,-offset.y)/(PI/4)),8)]
	return "%s　%s %d 米　·　Q 换目标" % [GOALS[tracked_kind(zone,game)],bearing,roundi(offset.length())]
