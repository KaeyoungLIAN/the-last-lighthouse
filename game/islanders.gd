extends Node3D
## Commissions use the voyage's existing atomic inventory/flag snapshot.
const Art = preload("res://actors/actor_art.gd")
const PEOPLE := {
	"cartographer": ["殷荻", "绘海图的人", "village", Vector2(5.3,-3.4), "5f9690", "d2ad73"],
	"postwoman": ["陶铃", "跑海邮的船娘", "outerport", Vector2(-2.0,1.8), "a55241", "d6ae78"],
	"herbalist": ["闻芷", "磨坊药师", "windmill", Vector2(1.9,1.8), "76875e", "d6a373"],
	"ranger": ["费岑", "高地巡林员", "highmoor", Vector2(1.9,-1.8), "68788c", "ad7958"]
}
const REGIONS := {
	"village": ["灰湾村","village","灰湾村"],
	"outerport": ["雁尾港","beach","月牙滩"],
	"windmill": ["风弦磨坊","lake","镜湖泵站"],
	"highmoor": ["松风高地","forest","雾根林"],
	"observatory": ["星尺台","volcano","赤炉冷却窑"],
	"saltworks": ["白帆盐场","tower","望潮岬"]
}
const LOCATIONS := {
	"survey_plate": ["黄铜刻度盘","observatory",Vector2(-2.2,1.5)],
	"marsh_herb": ["盐蒿","saltworks",Vector2(2.2,-1.6)]
}
const COMMISSIONS := {
	"bearing": ["北针偏了半格","cartographer","survey_plate"],
	"letter": ["寄给山上的第一封信","postwoman","ranger"],
	"remedy": ["风磨下的盐蒿","herbalist","marsh_herb"]
}
var locations: Dictionary = {}
var regions: Dictionary = {}
var models: Dictionary = {}
var labels: Dictionary = {}
var objects: Dictionary = {}

func build(game) -> void:
	for region: String in REGIONS:
		var info: Array = REGIONS[region]
		var mapped: bool = game.world.POINTS.has(region)
		regions[region] = info[0] if mapped else info[2]
	for id: String in PEOPLE:
		var info: Array = PEOPLE[id]
		var at := _place(game,info[2],info[3])
		locations[id] = at
		var model := preload("res://actors/islander.gd").new()
		add_child(model)
		model.position = game._ground(at)
		model.build(id,info[4],info[5])
		models[id] = model
		_make_label(model,info[0],2.25,id)
	for id: String in LOCATIONS:
		var info: Array = LOCATIONS[id]
		var at := _place(game,info[1],info[2])
		locations[id] = at
		var object := Art.joint(self,game._ground(at))
		objects[id] = object
		_make_label(object,info[0],1.4,id)
		if id == "survey_plate":
			Art.taper(object,Vector3.UP*.41,.31,.25,.82,"78817a")
			Art.taper(object,Vector3.UP*.86,.44,.43,.12,"bc9a5e",12)
			for i in 12:
				var angle := i*TAU/12.0
				Art.block(object,Vector3(sin(angle)*.32,.93,cos(angle)*.32),Vector3(.023,.025,.10),"725a44").rotation.y = angle
			Art.rod(object,Vector3(-.20,.94,.15),Vector3(.22,.96,-.16),.036,.015,"526c6c")
		else:
			for i in 9:
				var stem := Vector3(sin(i*2.4)*.38,0,cos(i*2.4)*.38)
				var tip := stem + Vector3(stem.x*.44,.41+.19*sin(i),stem.z*.44)
				Art.rod(object,stem,tip,.025,.009,"7b9863")
				for j in 3:
					var leaf := Art.oval(object,stem.lerp(tip,.40+j*.22),Vector3(.19,.08,.11),"c0828c" if j==2 else "80b196")
					leaf.rotation.y = i+j

func _place(game,region: String,offset: Vector2) -> Vector2:
	var anchor: String = region if game.world.POINTS.has(region) else REGIONS[region][1]
	return game._walkable_near(game.world.POINTS[anchor] + offset)

func _make_label(parent: Node3D,caption: String,height: float,id: String) -> void:
	var label := Label3D.new()
	label.text = caption
	label.position.y = height
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 34
	label.pixel_size = .009
	label.outline_size = 7
	label.modulate = Color("f2d8a2")
	label.visible = false
	parent.add_child(label)
	labels[id] = label

func stage(id: String,flags: Array) -> int:
	for i in [3,2,1]:
		if flags.has("folk_%s_%d" % [id,i]): return i
	return 0

func advance(id: String,step: int,flags: Array) -> void:
	flags.append("folk_%s_%d" % [id,step])

func available(id: String,flags: Array) -> bool:
	if PEOPLE.has(id): return true
	return (id=="survey_plate" and stage("bearing",flags)==1) or (id=="marsh_herb" and stage("remedy",flags)==1)

func refresh(hero: Vector3,inside: bool,clock: float,day: float,flags: Array) -> void:
	visible = not inside
	if inside: return
	for id: String in locations:
		var at: Vector2 = locations[id]
		var near := Vector2(hero.x,hero.z).distance_squared_to(at)<95
		labels[id].visible = near and available(id,flags)
		if models.has(id) and near:
			models[id].pose(clock,day,hero)
		if id=="marsh_herb":
			objects[id].visible = stage("remedy",flags)<2

func prompt(id: String) -> String:
	if id in PEOPLE: return "与%s交谈" % PEOPLE[id][0]
	if id=="survey_plate": return "拓下刻度盘的方位线"
	return "采一束盐蒿"

func objective(id: String,step: int) -> String:
	match id:
		"bearing":
			return "去%s拓下黄铜刻度盘。" % regions.observatory if step==1 else "把方位拓片带回灰湾村交给殷荻。"
		"letter":
			return "把蓝封信亲手交给%s的巡林员费岑。" % regions.highmoor
		"remedy":
			return "去%s采粉尖的盐蒿。" % regions.saltworks if step==1 else "把盐蒿带回%s交给闻芷。" % regions.windmill
	return ""

func targets(flags: Array) -> Dictionary:
	var active := {}
	var number := 0
	for id: String in COMMISSIONS:
		number += 1
		var step := stage(id,flags)
		if step not in [1,2]: continue
		var job: Array = COMMISSIONS[id]
		var site: String = job[2] if step==1 else job[1]
		active[id] = {"site":site,"pos":locations[site],"number":number}
	return active

func _bearing(origin: Vector2,destination: Vector2) -> String:
	var offset := destination-origin
	var meters := roundi(offset.length())
	if meters<3: return "近旁 · %d 米" % meters
	var direction := posmod(roundi(atan2(offset.x,-offset.y)/(PI/4.0)),8)
	return "%s · %d 米" % [["北","东北","东","东南","南","西南","西","西北"][direction],meters]

func ledger(flags: Array,active: Dictionary,origin: Vector2,inside: bool) -> Array:
	var rows := []
	for id: String in COMMISSIONS:
		var job: Array = COMMISSIONS[id]
		var giver: Array = PEOPLE[job[1]]
		var step := stage(id,flags)
		var line := objective(id,step)
		if step==0: line = "%s · 找%s询问" % [regions[giver[2]],giver[0]]
		elif step==3: line = "已办妥"
		else:
			line += "\n" + ("从塔门向外 · " if inside else "") + _bearing(origin,active[id].pos)
		rows.append(["%d  %s" % [rows.size()+1,job[0]],line])
	return rows

func conversation(id: String,flags: Array,night: bool) -> Dictionary:
	var person: Array = PEOPLE[id]
	var line := ""
	var action := ""
	var job := {"cartographer":"bearing","postwoman":"letter","herbalist":"remedy","ranger":"letter"}[id] as String
	var step := stage(job,flags)
	match id:
		"cartographer":
			line = "这张海图画了十一年。你看，雨水把北边那条方位线吃掉了。" if not night else "靠星光量出来的数，我才敢往海图上落墨。"
			if step==0:
				line += " 去%s的黄铜刻度盘，替我用炭把原线拓回来吧。" % regions.observatory
				action = "接过炭条"
			elif step==2:
				line = "压痕还在，果然偏了半格。给你两片备用铜板，当废铁收着。"
				action = "交出拓片 · 领取废铁 ×2"
		"postwoman":
			line = "帆补好了，北上那袋信却赶不上潮。我弟费岑守着%s，他等的是一封报平安的家书。" % regions.highmoor
			if step==0: action = "替陶铃送信"
			elif step==3: line = "收条上那道歪勾，一看就是阿岑的字。下回出海，我可以放心了。"
		"herbalist":
			line = "磨石碾药也磨面，我得把两副石臼分开。盐蒿只摘粉尖，根留下，入秋还会发。"
			if step==0:
				line += " 帮我从%s带一束回来，我用封药的松脂换。" % regions.saltworks
				action = "帮忙采盐蒿"
			elif step==2:
				line = "对，就是这股咸香。叶子留着熬膏，这三块净松脂给你修补装备。"
				action = "交出盐蒿 · 领取树脂 ×3"
		"ranger":
			line = "松鸦落在低枝，明天风就大。你往高处走，要记好来时的灯标。" if not night else "过了这个点，我只听铃，不吹哨。雾里声音能传很远。"
			if step==1:
				line = "蓝封口！我认得阿姐打的绳结。她平安就好。巡路拆下的铁环给你带走。"
				action = "递上家书 · 领取废铁 ×3"
			elif step==3: line = "我打算用木头刻一只小燕，下趟让阿姐带回船上。"
	if id=="cartographer" and not flags.has("visited_library"):
		line += "\n\n你师傅的交接本在图书馆。总有人问我那六个圆圈是什么意思，他在本子里答得比我好。"
	if id=="postwoman" and not flags.has("harbor") and step==0:
		line += "\n\n灰湾码头也在收修船的东西。沉船的缆绳、泵站的密封圈、旧窑的铸件，顺路带一件就够。"
	if step in [1,2] and action.is_empty() and id!="ranger": line += "\n\n"+objective(job,step)
	if step==3 and id in ["cartographer","herbalist"]: line += " 上回的忙，多谢了。"
	return {"name":person[0],"role":person[1],"line":line,"action":action,"job":job}

func reply(id: String,game) -> void:
	var speech := conversation(id,game.taken,game._night())
	if speech.action.is_empty(): return
	var job: String = speech.job
	var step := stage(job,game.taken)
	if step==0:
		advance(job,1,game.taken)
		game._notice(objective(job,1),"start")
	else:
		advance(job,3,game.taken)
		if job=="remedy": game.resin += 3
		else: game.iron += 2 if job=="bearing" else 3
		game._notice("委托完成 · "+str(COMMISSIONS[job][0]),"chime")
	game._save()

func gather(id: String,game) -> void:
	var job := "bearing" if id=="survey_plate" else "remedy"
	if stage(job,game.taken)!=1: return
	advance(job,2,game.taken)
	game._notice(("获得方位拓片。 " if job=="bearing" else "采到一束盐蒿。 ")+objective(job,2),"pickup")
	game._save()
