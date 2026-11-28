extends Node3D
## Routes use the paths the player can actually walk, including the six overland passes.
const Geo := preload("res://world/expedition_geography.gd")
const Art := preload("res://actors/actor_art.gd")
const NOTES := {
	"snow":["木箱里的红围巾","找一条红围巾","木箱上写着：雪一下大，对面的路就看不清了。我把妹妹的红围巾绑在箱子上。看到红色，左转就能找到屋子。","松风高地的费岑"],
	"tide":["漂流瓶","找岸边的漂流瓶","瓶子里夹着陶铃写的纸条：昨晚我看不见灯塔，只能听浪。浪一阵比一阵响，我就带大家上了高岸。一船人都在这儿。","送信的陶铃"],
	"volcano":["冷却水桶","找岩石上的水桶","桶边有个歪歪扭扭的箭头。窑工写着：那天我把两桶水都浇在滚烫的铸件上。给船厂留的那一件还在旧窑。要去拿，等白汽散了再靠近。","守旧窑的工人"],
	"desert":["打了结的井绳","找井边的绳结","井绳上打了两个结。旁边的小孩写着：爸爸出去找走散的人了。我给他留了一壶，也给下一个来的人留了一壶。你渴了就喝。","住在井边的一家人"],
	"lake":["旧邮袋","找湖边的邮袋","邮袋里有一封没送到的信：妈，我平安。灯灭以后，我跟着钟声把船划回来了。明天我再去接你。信上的墨已经干了。","一位船工"],
	"forest":["刻了记号的木牌","找树下的木牌","木牌背面刻着一大一小两个脚印。费岑在下面写：大桥被吹断了，我背着孩子从沟底绕了回来。看见桥在晃，就走下面那条路。","巡林员费岑"]
}
const MAIN := "main"
const LIBRARY := "library"
const HOME := "home"
const CREST := "crest_"
const HUNT := "hunt_"
const HARBOR := "harbor_supply"
const PREFIX := "field_note_"
const COMPASS := ["北","东北","东","东南","南","西南","西","西北"]
var pin := ""
var graph := AStar2D.new()
var nodes_by_position := {}
var cached_path := PackedVector2Array()
var last_start := -1
var last_goal := -1
var current_note := ""

func build(game) -> void:
	for path: Array in game.world.ROADS: _add_route(path)
	for path: Array in Geo.ROUTES.values(): _add_route(path)
	for path: Array in Geo.OUTER_ROUTES.values(): _add_route(path)
	_add_route([Vector2(-29,29),Vector2(-29.6,26.5),game.library.DOOR])
	for id: String in NOTES:
		var path: Array = Geo.ROUTES[id]
		var at: int = path.find(Geo.CAMPS[id])
		var a: Vector2 = path[at]
		var b: Vector2 = path[at+1]
		var p := a.lerp(b,.73)+a.direction_to(b).orthogonal()*1.9
		game._add_site(PREFIX+id,NOTES[id][0],p)
		_make_object(id,game._ground(game.sites[PREFIX+id]))

func _point(pos: Vector2) -> int:
	var k := Vector2i((pos*10.).round())
	if nodes_by_position.has(k): return nodes_by_position[k]
	var id := graph.get_available_point_id()
	graph.add_point(id,pos)
	nodes_by_position[k]=id
	return id

func _add_route(path: Array) -> void:
	if path.size()<2: return
	var prev := _point(path[0])
	for i in range(1,path.size()):
		var a: Vector2 = path[i-1]
		var b: Vector2 = path[i]
		var steps := maxi(1,ceili(a.distance_to(b)/5.))
		for j in range(1,steps+1):
			var next := _point(a.lerp(b,float(j)/steps))
			if prev!=next and not graph.are_points_connected(prev,next): graph.connect_points(prev,next)
			prev=next

func valid_pin(value: String) -> bool:
	return value in [MAIN,LIBRARY,HOME,HARBOR,""] or NOTES.has(value) or (
		value.begins_with(CREST) and Geo.ZONES.has(value.trim_prefix(CREST))) or (
		value.begins_with(HUNT) and Geo.ZONES.has(value.trim_prefix(HUNT)))

func restore(value: String) -> void:
	pin = value if valid_pin(value) else ""
	last_start=-1
	last_goal=-1
	cached_path.clear()

func set_pin(value: String, game) -> void:
	restore(value)
	if pin==LIBRARY: game._notice("地图上标好了图书馆。","switch")
	elif pin==MAIN or pin.begins_with(CREST) or pin.begins_with(HUNT) or pin==HARBOR:
		game._notice(label(game),"switch")
	elif pin==HOME: game._notice("回村的路已经标在地图上。","switch")
	elif NOTES.has(pin): game._notice("路线已标好，去"+game.voyage.NAMES[pin]+("的营地。" if game.taken.has(PREFIX+pin) else "，"+str(NOTES[pin][1])+"。"),"switch")

func main_site(game) -> String:
	if pin.begins_with(CREST):
		var chosen := pin.trim_prefix(CREST)
		if not game.crests.has(chosen): return pin
	if game.won: return ""
	for zone: String in game.voyage.ORDER:
		if not game.crests.has(zone): return CREST+zone
	return "tower"

func _harbor_site(game) -> String:
	if game.taken.has("harbor"): return ""
	for site: String in ["beach","lake","volcano"]:
		if game.taken.has(site): return "harbor"
	return "beach" if game.taken.has("winch") else "winch"

func destination(game) -> Variant:
	if game.in_tower or game.library.inside or game.ferry.afloat: return null
	if pin==LIBRARY: return game.library.DOOR
	if pin==HOME: return game.sites[game.voyage.DESK]
	if pin==HARBOR: return game.sites.get(_harbor_site(game))
	if pin.begins_with(HUNT): return Geo.HUNTS[pin.trim_prefix(HUNT)]
	if pin==MAIN or pin.begins_with(CREST):
		var id := main_site(game)
		if id.begins_with(CREST): return Geo.ARENAS[id.trim_prefix(CREST)]
		return game.sites.get(id)
	if NOTES.has(pin): return Geo.CAMPS[pin] if game.taken.has(PREFIX+pin) else game.sites[PREFIX+pin]
	return null

func route(p: Vector2,dest: Vector2) -> PackedVector2Array:
	var a :=graph.get_closest_point(p)
	var b :=graph.get_closest_point(dest)
	if a!=last_start or b!=last_goal:
		last_start=a
		last_goal=b
		cached_path=graph.get_point_path(a,b)
	var result := PackedVector2Array([p])
	# Within a few metres of the destination there is no reason to turn back to the trail.
	if p.distance_to(dest)>9.:
		for v in cached_path:
			if result[-1].distance_squared_to(v)>1.: result.append(v)
	result.append(dest)
	return result

func label(game) -> String:
	if pin.begins_with(HUNT):
		var zone := pin.trim_prefix(HUNT)
		return "%s猎场 · 寻找%s" % [Geo.ZONES[zone],game.wilds.describe(zone).prey]
	match pin:
		LIBRARY: return "去村里的图书馆"
		HOME: return "回灰湾村"
		HARBOR:
			match _harbor_site(game):
				"winch": return "船具补给 · 到月牙滩转动沉船绞盘"
				"beach": return "船具补给 · 收起旧船舱里的缆绳"
				"harbor": return "把修船物料送到灰湾码头的船具补给站"
			return "船具补给已完成"
	if pin==MAIN or pin.begins_with(CREST):
		var next := main_site(game)
		if next == "tower": return "六枚纹章已集齐 · 返回望潮岬，从塔门登塔"
		if next.begins_with(CREST):
			var zone := next.trim_prefix(CREST)
			var entry: Dictionary = game.wilds.describe(zone)
			return "前往%s，击败%s取得%s" % [Geo.ZONES[zone],entry.boss,entry.crest]
		if game.won: return "六槽灯座已点亮"
	if NOTES.has(pin):
		return "去"+game.voyage.NAMES[pin]+"的营地" if game.taken.has(PREFIX+pin) else NOTES[pin][1]
	return ""

func direction(path: PackedVector2Array) -> String:
	if path.size()<2: return ""
	var turn:=path[-1]
	var total:=0.
	var have_turn:=false
	for i in range(1,path.size()):
		total+=path[i-1].distance_to(path[i])
		if not have_turn and total>=10.:
			turn=path[i]
			have_turn=true
	if total<3.5: return "已到达地图标记处"
	var offset:=turn-path[0]
	var bearing: String=COMPASS[posmod(roundi(atan2(offset.x,-offset.y)/(PI/4)),8)]
	return "往"+bearing+"走，沿路约 %d 米" % roundi(total)

func read_field(id: String,game) -> bool:
	if not id.begins_with(PREFIX): return false
	current_note=id.trim_prefix(PREFIX)
	if not NOTES.has(current_note): return false
	if not game.taken.has(id): game.taken.append(id)
	game.library.sync_field_notes(game.taken)
	if pin==current_note: restore("")
	game._show("field_note")
	game._save()
	return true

func _make_object(id: String,base: Vector3) -> void:
	var o:=Art.joint(self,base)
	match id:
		"snow":
			for i in 5: Art.block(o,Vector3((i-2)*.24,.31,0),Vector3(.23,.61,.75),"947354")
			Art.block(o,Vector3(-.21,.65,.06),Vector3(.33,.052,.78),"af5140")
			Art.block(o,Vector3(-.21,.48,.4),Vector3(.31,.34,.035),"b75b4d")
		"tide":
			Art.block(o,Vector3.ZERO,Vector3(.98,.16,.66),"858b77")
			var bottle:=Art.joint(o,Vector3(0,.14,0))
			bottle.rotation.z=.56
			Art.taper(bottle,Vector3.UP*.20,.14,.13,.36,"6eafa3",8)
			Art.taper(bottle,Vector3.UP*.41,.13,.06,.08,"80b5ae",8)
			Art.taper(bottle,Vector3.UP*.49,.06,.06,.10,"dac292",8)
		"volcano","desert":
			Art.taper(o,Vector3.UP*.28,.27,.34,.55,"927055",10)
			Art.taper(o,Vector3.UP*.55,.34,.34,.05,"66655c",10)
			Art.taper(o,Vector3.UP*.58,.28,.28,.02,"80b7b4",10)
			var last:=Vector3(-.31,.57,0)
			for j in range(1,9):
				var a:=PI*(1.-j/8.)
				var next:=Vector3(cos(a)*.31,.57+sin(a)*.35,0)
				Art.rod(o,last,next,.03,.03,"bca77b" if id=="desert" else "555c56")
				last=next
			if id=="desert":
				for i in 12:
					var a:=TAU*i/12
					var b:=TAU*(i+1)/12
					Art.rod(o,Vector3(.48+cos(a)*.31,.06,sin(a)*.30),Vector3(.48+cos(b)*.31,.06,sin(b)*.30),.06,.06,"c5a77a")
		"lake":
			Art.oval(o,Vector3(0,.3,0),Vector3(1.05,.52,.67),"a8624a")
			Art.block(o,Vector3(0,.42,.18),Vector3(.68,.12,.39),"ceb38b")
			Art.block(o,Vector3(-.15,.44,.29),Vector3(.08,.12,.22),"b88d4c")
		"forest":
			Art.rod(o,Vector3.ZERO,Vector3(-.08,1.42,.01),.10,.08,"7c624b")
			Art.block(o,Vector3(0,1.2,0),Vector3(.97,.42,.09),"ac9066")
			for x: float in [-.23,.17]:
				Art.oval(o,Vector3(x,1.2,.055),Vector3(.19,.26,.035),"6f6550")
