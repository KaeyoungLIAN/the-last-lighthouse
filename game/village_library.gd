extends Node3D
## The building sits just north of the east road. Its reading room uses a separate floor
## and walkable footprint so island tides and hillside elevation never displace the reader.
signal reader_changed(open: bool)
signal room_changed(entered: bool)
signal clue_selected(id: String)

const Art = preload("res://actors/actor_art.gd")
const Geo = preload("res://world/expedition_geography.gd")
const Voyage = preload("res://expedition_voyage.gd")
const Wildlife = preload("res://expedition_encounters.gd")
const ENTRY_ID := "library_entry"
const EXIT_ID := "library_exit"
const CENTER := Vector2(-29.6,20.1)
const DOOR := Vector2(-29.6,23.8)
const ROOM := Vector3(-29.6,145.0,20.1)
const STATIONS := {
	"library_desk":Vector2(-2.35,2.60),"library_west":Vector2(-4.12,-1.6),
	"library_south":Vector2(0,-3.93),"library_east":Vector2(4.12,-1.6),EXIT_ID:Vector2(0,4.83)}
const COLLECTIONS := {
	"library_desk":["守塔人的交接本",["main"]],"library_west":["山路和潮滩",["snow","tide"]],
	"library_south":["火山和沙海",["volcano","desert"]],"library_east":["湖岸和林海",["lake","forest"]]}
const ENTRIES := {
	"main":["灰湾灯塔的六个空槽","守塔人的交接本","风暴后的第一夜，我登上了望潮岬。灯座的六个凹槽空了。你把手放在黄铜圈上，还能摸到雪绒、礁足、余烬、背风、听澜、盘根的刻痕。\n\n六枚纹章各在一位首领身上。地图上，三角是营地，圆圈是它们出没的位置。先去哪一处，由你决定。打开岛图里的六区手册，就能标出一位首领，看看它在什么时候会露出破绽。\n\n拿齐六枚，回望潮岬，从塔门上楼。走到六槽灯座旁按 E，让海上的人亲眼看见灰湾的光。"],
	"snow":["木箱上系着红围巾","费岑写给妹妹的话","你那条红围巾，哥先借走了。白脊岭一下雪，木箱和地上的石头就一个颜色。我把围巾系在箱子上，大家远远就能看见。\n\n从营地往猎场走，留心路边那抹红。我还在箱子上留了张纸。"],
	"tide":["漂流瓶里写了什么？","陶铃的送信记录","回浪湾那晚的事，我写在一张纸上，折好塞进了漂流瓶。要是有人来找那条船，看完就知道该往哪儿去了。\n\n瓶子就在营地去猎场的路边。你要去看，涨潮时记得往高处走。"],
	"volcano":["冷却水桶旁的留言","守旧窑的工人托人带回来的话","那晚刚出炉的船用铸件烫得拿不住，我们几个人忙到天亮。冷却水桶还在赤炉山上。\n\n从营地往猎场走，沿路就能找到。桶边那张留言也帮我看一眼。"],
	"desert":["井绳上的两个结","鸣砂海一个孩子的话","我爸去找走散的人了。我把水放在井边，又在井绳上打了两个结。他回来的时候，一眼就能认出来。\n\n井绳就在营地去猎场的路边。要是路过，去看看我在旁边写了什么。"],
	"lake":["给我妈的信还在邮袋里","一个船工托人捎的话","我在船上写了封信，想告诉我妈，我好得很。临走一摸口袋，才想起信还在旧邮袋里。\n\n邮袋落在沉钟湖边了。从营地往猎场走，就在路边。你经过的时候，能帮我看一眼吗？"],
	"forest":["路牌上是谁刻的记号？","费岑的巡林笔记","我跟那孩子平安回来了。他画的小脚印挺像，我顺手把它刻在了木牌上，还在旁边刻了个大的。\n\n从长青林海营地往猎场走，到路边找那块牌子。桥头的蕨叶翻白了，就去树根后歇会儿。"]}

var inside := false
var tracked := ""
var read_entries: Array = []
var reading := false
var _book := ""
var _page := ""
var _hero
var _world
var _room := Node3D.new()
var _reader := CanvasLayer.new()
var _paper: PanelContainer
var _book_title: Label
var _entry_title: Label
var _byline: Label
var _body: Label
var _region_notes: VBoxContainer
var _region_title: Label
var _plates: Array[AtlasTexture] = []
var _specimen_captions: Array[Label] = []
var _terrain: Label
var _animal: Label
var _champion: Label
var _log_status: Label
var _hunt_button: Button
var _boss_button: Button
var _known_crests: Array = []
var _journal_flags: Array = []
var _tabs: HBoxContainer
var _scroll: ScrollContainer
var _track: Button
var _return: Button
var _unit := BoxMesh.new()
var _obstacles: Array[Rect2] = []
var _font := SystemFont.new()
var _note_cards := {}

func build(keeper,island) -> void:
	_hero = keeper
	_world = island
	_font.font_names = PackedStringArray(["Microsoft YaHei","Noto Sans CJK SC","PingFang SC"])
	_exterior()
	add_child(_room)
	_room.position = ROOM
	_interior()
	_room.hide()
	_build_reader()

func snapshot() -> Dictionary:
	return {"read":read_entries.duplicate(),"tracked":tracked}

func survey_progress(crests: Array, flags: Array) -> void:
	_known_crests = crests
	_journal_flags = flags

func restore(data: Dictionary) -> void:
	if reading:
		reading = false
		_reader.hide()
	if inside:
		leave(false)
	read_entries.clear()
	var saved = data.get("read",[])
	if saved is Array:
		for id in saved:
			if id is String and ENTRIES.has(id) and not read_entries.has(id):
				read_entries.append(id)
	var saved_track = data.get("tracked","")
	tracked = saved_track if saved_track is String and ENTRIES.has(saved_track) else ""

func enter() -> void:
	if inside: return
	inside = true
	_room.show()
	_hero.world_ref = self
	_hero.reset_combat()
	_hero.global_position = ROOM+Vector3(0,.03,2.80)
	_hero.velocity = Vector3.ZERO
	_hero.camera_yaw = 0.0
	_hero.camera_pitch = .24
	_hero.reset_physics_interpolation()
	room_changed.emit(true)

func leave(notify := true) -> void:
	if not inside: return
	if reading: close_book()
	inside = false
	_room.hide()
	_hero.world_ref = _world
	_hero.reset_combat()
	_hero.global_position = Vector3(DOOR.x,_world.ground_height(DOOR.x,DOOR.y)+.06,DOOR.y+.35)
	_hero.velocity = Vector3.ZERO
	_hero.camera_yaw = PI
	_hero.reset_physics_interpolation()
	if notify: room_changed.emit(false)

func nearby() -> String:
	if not is_instance_valid(_hero): return ""
	var p := Vector2(_hero.global_position.x,_hero.global_position.z)
	if not inside:
		return ENTRY_ID if p.distance_to(DOOR)<3.25 else ""
	var local := p-Vector2(ROOM.x,ROOM.z)
	var closest := 1.72
	var found := ""
	for id: String in STATIONS:
		var dist := local.distance_to(STATIONS[id])
		if dist<closest:
			closest = dist
			found = id
	return found

func prompt(id: String) -> String:
	if id==ENTRY_ID: return "进灰湾图书馆"
	if id==EXIT_ID: return "出门，回到灰湾村"
	if COLLECTIONS.has(id): return "读《%s》" % COLLECTIONS[id][0]
	return ""

func interact(id: String) -> bool:
	if id=="" or id!=nearby(): return false
	if id==ENTRY_ID:
		enter()
	elif id==EXIT_ID:
		leave()
	elif COLLECTIONS.has(id):
		_book = id
		reading = true
		_reader.show()
		_open_page(COLLECTIONS[id][1][0])
		reader_changed.emit(true)
	else: return false
	return true

func close_book() -> void:
	if not reading: return
	reading = false
	_reader.hide()
	reader_changed.emit(false)

func ground_height(_x: float,_z: float) -> float:
	return ROOM.y

func is_walkable(x: float,z: float) -> bool:
	var spot := Vector2(x-ROOM.x,z-ROOM.z)
	if absf(spot.x)>5.48 or absf(spot.y)>5.18: return false
	for obstacle in _obstacles:
		if obstacle.has_point(spot): return false
	return true

func _box(parent: Node3D,at: Vector3,size: Vector3,tint: String,glow := false) -> MeshInstance3D:
	var piece := Art.part(parent,_unit,at,tint,glow)
	piece.scale = size
	return piece

func _solid(parent: Node3D,at: Vector3,size: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	parent.add_child(body)
	body.position = at
	body.add_child(collision)

func _sign(parent: Node3D,caption: String,at: Vector3,width: float) -> void:
	_box(parent,at,Vector3(width,.54,.13),"304e50")
	for y: float in [-.23,.23]:
		_box(parent,at+Vector3(0,y,.071),Vector3(width-.08,.023,.02),"bd9b5d")
	var label := Label3D.new()
	parent.add_child(label)
	label.font = _font
	label.text = caption
	label.font_size = 42
	label.pixel_size = .0071
	label.modulate = Color("ffe3a4")
	label.outline_size = 2
	label.position = at+Vector3(0,0,.079)

func _window(parent: Node3D,at: Vector3,width: float,height: float) -> void:
	_box(parent,at,Vector3(width+.23,height+.23,.15),"536d66")
	_box(parent,at+Vector3.BACK*.085,Vector3(width,height,.08),"c0b890")
	for i in 3:
		_box(parent,at+Vector3((i-1)*width*.32,0,.145),Vector3(.047,height,.05),"54615a")
	_box(parent,at+Vector3(0,.06,.15),Vector3(width,.055,.05),"54615a")
	_box(parent,at+Vector3(0,-height*.5-.11,.16),Vector3(width+.37,.13,.35),"677b70")

func _exterior() -> void:
	var house := Node3D.new()
	add_child(house)
	house.position = Vector3(CENTER.x,_world.ground_height(CENTER.x,CENTER.y),CENTER.y)
	house.add_child(preload("res://art/greybay/library.glb").instantiate())
	var painted_gable := MeshInstance3D.new()
	painted_gable.name = "TidalFrontispiece"
	painted_gable.mesh = preload("res://art/greybay/library_gable_paint.tres")
	painted_gable.position = Vector3(0,4.33,2.828)
	painted_gable.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	house.add_child(painted_gable)
	_solid(house,Vector3(0,2.29,0),Vector3(7.13,4.8,5.61))
	_sign(house,"灰湾图书馆",Vector3(0,3.21,3.05),3.70)
	var plaque := Node3D.new()
	house.add_child(plaque)
	plaque.position = Vector3(-2.68,0,3.72)
	plaque.rotation.y = -.49
	_box(plaque,Vector3.UP*.68,Vector3(.13,1.48,.15),"75654b")
	_sign(plaque,"图书馆入口",Vector3.UP*1.55,1.95)
	_pack_boxes(house)

func _interior() -> void:
	_room.name = "ReadingRoom"
	_box(_room,Vector3(0,-.15,0),Vector3(11.55,.22,11.0),"6d5b45")
	_solid(_room,Vector3(0,-.12,0),Vector3(11.65,.24,11.0))
	for i in 23:
		for j in 4:
			_box(_room,Vector3((j-1.5)*2.85,-.02,(i-11)*.47),Vector3(2.83,.042,.457),
				["a58b62","a98e66","b2976d","9b8462"][(i*7+j*13+i*j)%4])
	for side: float in [-1.0,1.0]:
		_wall(Vector3(0,0,side*5.48),PI if side>0 else 0.0,11.65)
		_wall(Vector3(side*5.75,0,0),-side*PI*.5,11.1)
	_solid(_room,Vector3.UP*4.45,Vector3(11.64,.24,11.05))
	_box(_room,Vector3.UP*4.45,Vector3(11.64,.24,11.05),"958569")
	for z: float in [-4.65,-2.55,0.0,2.55,4.65]:
		_box(_room,Vector3(0,4.19,z),Vector3(11.63,.29,.20),"624e39")
	_window(_room,Vector3(-3.92,2.24,-5.31),1.84,1.47)
	# Put the shelves along different walls, leaving the middle and door unobstructed.
	_shelf(Vector3(-5.22,0,-1.53),PI*.5,"山路和潮滩",0)
	_shelf(Vector3(0,0,-4.95),0.0,"火山和沙海",1)
	_shelf(Vector3(5.22,0,-1.53),-PI*.5,"湖岸和林海",2)
	_obstacles.append_array([Rect2(-5.64,-3.43,.90,3.81),Rect2(-2.02,-5.42,4.04,.94),
		Rect2(4.74,-3.43,.90,3.81),Rect2(-3.70,1.03,2.70,1.20)])
	_desk()
	var doorway := Art.joint(_room,Vector3(0,0,5.28))
	doorway.rotation.y = PI
	_box(doorway,Vector3.UP*1.30,Vector3(1.90,2.60,.15),"5a5849")
	_box(doorway,Vector3(0,1.23,.12),Vector3(1.62,2.46,.10),"89734f")
	for x: float in [-.39,.39]:
		_box(doorway,Vector3(x,1.50,.20),Vector3(.56,1.33,.06),"a58c65")
	_box(doorway,Vector3(-.58,1.22,.21),Vector3(.12,.18,.09),"d3b56f")
	_sign(doorway,"回灰湾村",Vector3(0,2.95,.12),2.35)
	_lamp(Vector3(.70,3.32,-.90),10.0,1.65)
	_lamp(Vector3(-2.80,3.37,2.16),5.7,.97)
	var rug := Vector3(.53,.022,.26)
	_box(_room,rug,Vector3(2.80,.025,5.35),"426866")
	for x: float in [-1.27,1.27]:
		_box(_room,rug+Vector3(x,.018,0),Vector3(.073,.010,5.19),"ba9e63")
	for z: float in [-2.54,2.54]:
		_box(_room,rug+Vector3(0,.018,z),Vector3(2.56,.010,.073),"ba9e63")
	_pack_boxes(_room)
	_field_board()

func _field_board() -> void:
	var board := Art.joint(_room,Vector3(3.91,1.98,-5.22))
	_box(board,Vector3.ZERO,Vector3(2.70,1.76,.12),"736044")
	_box(board,Vector3(0,0,.068),Vector3(2.54,1.61,.035),"b59a6f")
	_sign(board,"大家捎回来的留言",Vector3(0,1.18,.01),2.9)
	var colors := ["c8e1e4","a6d2c3","e5ae8c","e8cf8b","adc1d9","bbcca1"]
	for i in Geo.ZONES.size():
		var id: String = Geo.ZONES.keys()[i]
		var card := Art.joint(board,Vector3((i%3-1)*.78,(.38 if i<3 else -.37),.105))
		card.rotation.z = .045 if i%2==0 else -.06
		_box(card,Vector3.ZERO,Vector3(.62,.61,.035),colors[i])
		_box(card,Vector3(0,.245,.034),Vector3(.048,.048,.025),"7b603e")
		for j in 3:
			_box(card,Vector3(-.02,-j*.077+.01,.024),Vector3(.30 if j<2 else .19,.015,.015),"817b67")
		_note_cards[id] = card
		card.hide()

func sync_field_notes(flags: Array) -> void:
	for id: String in _note_cards:
		_note_cards[id].visible = flags.has("field_note_"+id)

func _wall(at: Vector3,yaw: float,width: float) -> void:
	var face := Art.joint(_room,at)
	face.rotation.y = yaw
	_solid(face,Vector3.UP*2.2,Vector3(width,4.4,.20))
	_box(face,Vector3.UP*2.2,Vector3(width,4.4,.20),"d4c8a4")
	_box(face,Vector3(0,.63,.12),Vector3(width,1.26,.10),"647970")
	for h: float in [.13,1.21,4.08]:
		_box(face,Vector3(0,h,.19),Vector3(width,.13,.13),"64553e")
	for i in 11:
		_box(face,Vector3((i-5)*1.02,.65,.20),Vector3(.042,1.06,.034),"849087")

func _shelf(at: Vector3,yaw: float,title: String,variant: int) -> void:
	var case := Art.joint(_room,at)
	case.rotation.y = yaw
	var span := 3.78
	_solid(case,Vector3.UP*1.24,Vector3(span,2.48,.67))
	_box(case,Vector3(0,1.26,-.29),Vector3(span,2.49,.15),"61533e")
	for x: float in [-1.85,0.0,1.85]:
		_box(case,Vector3(x,1.27,0),Vector3(.11,2.53,.68),"9b8057")
	for h: float in [.20,.91,1.62,2.33,2.55]:
		_box(case,Vector3(0,h,0),Vector3(span+.09,.10,.74),"94734d")
	var colors := ["834f44","586f68","7a8159","53657a","a67b4e","786879","917958"]
	for row in 3:
		for section in 2:
			for i in 7:
				var seed_value := row*3+i*7+section*5+variant*13
				var h := .37+float(seed_value%6)*.035
				var w := .146+.018*float(seed_value%4)
				var x := (-1.68 if section==0 else .17)+i*.225
				var low := .256+row*.71
				_box(case,Vector3(x,low+h*.5,.066),Vector3(w,h,.38),colors[(seed_value+row+i)%7])
				_box(case,Vector3(x,low+h*.73,.264),Vector3(w*.74,.027,.015),"d4bd85")
	_sign(case,title,Vector3(0,2.86,.02),2.68)

func _desk() -> void:
	var desk := Art.joint(_room,Vector3(-2.35,0,1.63))
	desk.add_child(preload("res://art/greybay/keepers_logbook.glb").instantiate())
	_solid(desk,Vector3.UP*.52,Vector3(2.60,1.04,1.10))
	_sign(desk,"守塔人的交接本",Vector3(0,.79,.59),2.30)

func _lamp(at: Vector3,reach: float,energy: float) -> void:
	var lamp := Art.joint(_room,at)
	Art.rod(lamp,Vector3.ZERO,Vector3.UP*(4.28-at.y),.025,.025,"725c3e")
	Art.taper(lamp,Vector3.DOWN*.14,.28,.16,.28,"d9bc7c",8,true)
	Art.taper(lamp,Vector3.DOWN*.32,.20,.29,.075,"786548")
	Art.taper(lamp,Vector3.UP*.04,.32,.11,.17,"6d705e")
	var light := OmniLight3D.new()
	lamp.add_child(light)
	light.position.y = -.42
	light.light_color = Color("ffe1ad")
	light.light_energy = energy
	light.omni_range = reach
	light.omni_attenuation = .62

func _pack_boxes(host: Node3D) -> void:
	# Static book spines, roof tiles and trim can share one draw call per material.
	var groups := {}
	var inverse := host.global_transform.affine_inverse()
	for node in host.find_children("*","MeshInstance3D",true,false):
		if node.mesh!=_unit: continue
		var mat: Material = node.material_override
		if not groups.has(mat): groups[mat] = []
		groups[mat].append(inverse*node.global_transform)
		node.free()
	for mat: Material in groups:
		var poses: Array = groups[mat]
		var batch := MultiMesh.new()
		batch.transform_format = MultiMesh.TRANSFORM_3D
		batch.mesh = _unit
		batch.instance_count = poses.size()
		for i in poses.size(): batch.set_instance_transform(i,poses[i])
		var display := MultiMeshInstance3D.new()
		display.multimesh = batch
		display.material_override = mat
		host.add_child(display)

func _label(parent: Control,points: int,ink: String) -> Label:
	var item := Label.new()
	item.add_theme_font_override("font",_font)
	item.add_theme_font_size_override("font_size",points)
	item.add_theme_color_override("font_color",Color(ink))
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(item)
	return item

func _panel_style(fill: String,border: String,padding: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(fill)
	style.border_color = Color(border)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
		style.set_content_margin(side,padding)
	return style

func _button(parent: Control,caption: String,primary: bool) -> Button:
	var button := Button.new()
	parent.add_child(button)
	button.text = caption
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font",_font)
	button.add_theme_font_size_override("font_size",16)
	button.add_theme_stylebox_override("normal",_panel_style("375955" if primary else "eee2c7","6f7c68" if primary else "ae9b75",8))
	button.add_theme_stylebox_override("hover",_panel_style("486d65" if primary else "f8efd9","807758",8))
	button.add_theme_stylebox_override("pressed",_panel_style("3c5750" if primary else "d3c299","91835f",8))
	button.add_theme_stylebox_override("disabled",_panel_style("d4c49e","9a8969",8))
	for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
		button.add_theme_color_override(state,Color("fff3d5" if primary else "3a443b"))
	button.add_theme_color_override("font_disabled_color",Color("4c4a37"))
	return button

func _build_reader() -> void:
	_reader.name = "LibraryReader"
	_reader.layer = 16
	add_child(_reader)
	var shade := ColorRect.new()
	_reader.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(.07,.105,.086,.78)
	var center := CenterContainer.new()
	shade.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_paper = PanelContainer.new()
	center.add_child(_paper)
	var stock := _panel_style("f1e7cd","ac9971",24)
	stock.shadow_color = Color(0,0,0,.38)
	stock.shadow_size = 12
	_paper.add_theme_stylebox_override("panel",stock)
	var column := VBoxContainer.new()
	_paper.add_child(column)
	column.add_theme_constant_override("separation",9)
	_book_title = _label(column,16,"546957")
	_tabs = HBoxContainer.new()
	column.add_child(_tabs)
	_tabs.add_theme_constant_override("separation",8)
	_scroll = ScrollContainer.new()
	column.add_child(_scroll)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	var article := VBoxContainer.new()
	_scroll.add_child(article)
	article.add_theme_constant_override("separation",7)
	article.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_region_notes = VBoxContainer.new()
	article.add_child(_region_notes)
	_region_notes.add_theme_constant_override("separation",9)
	_region_title = _label(_region_notes,26,"2e524b")
	var figures := HBoxContainer.new()
	_region_notes.add_child(figures)
	for role in 2:
		var card := VBoxContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		figures.add_child(card)
		var plate := AtlasTexture.new()
		plate.atlas = preload("res://art/fieldguide/specimens.png")
		plate.filter_clip = true
		_plates.append(plate)
		var picture := TextureRect.new()
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.custom_minimum_size.y = 110
		picture.texture = plate
		card.add_child(picture)
		var caption := _label(card,15,"435a4f")
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_specimen_captions.append(caption)
	_terrain = _label(_region_notes,18,"414b40")
	_champion = _label(_region_notes,18,"5e4133")
	_animal = _label(_region_notes,18,"2d514a")
	_log_status = _label(_region_notes,15,"566647")
	_region_notes.add_child(HSeparator.new())
	_entry_title = _label(article,29,"323d36")
	_byline = _label(article,15,"71674f")
	var rule := HSeparator.new()
	article.add_child(rule)
	_body = _label(article,18,"3f4236")
	_body.add_theme_constant_override("line_spacing",4)
	var actions := HFlowContainer.new()
	column.add_child(actions)
	actions.add_theme_constant_override("h_separation",8)
	actions.add_theme_constant_override("v_separation",6)
	_hunt_button = _button(actions,"标出猎场",true)
	_hunt_button.pressed.connect(_mark_region.bind("hunt_"))
	_boss_button = _button(actions,"标出首领",false)
	_boss_button.pressed.connect(_mark_region.bind("crest_"))
	_track = _button(actions,"我去看看",true)
	_track.pressed.connect(_choose_clue)
	_return = _button(actions,"合上书  Esc",false)
	_return.pressed.connect(close_book)
	get_viewport().size_changed.connect(_resize_reader)
	_resize_reader()
	_reader.hide()

func _resize_reader() -> void:
	var space := get_viewport().get_visible_rect().size
	_paper.custom_minimum_size.x = clampf(space.x-28,255,740)
	_scroll.custom_minimum_size.y = clampf(space.y-250,96,390)

func _open_page(id: String) -> void:
	_page = id
	if not read_entries.has(id): read_entries.append(id)
	var collection: Array = COLLECTIONS[_book]
	_book_title.text = "灰湾图书馆　／　"+str(collection[0])
	var regional := Wildlife.GUIDE.has(id)
	_region_notes.visible = regional
	_hunt_button.visible = regional
	_boss_button.visible = regional
	if regional:
		var entry: Dictionary = Wildlife.GUIDE[id]
		for role in 2:
			_plates[role].region = Rect2(role*320,Voyage.ORDER.find(id)*170,320,170)
		_specimen_captions[0].text = "猎物　"+str(entry.prey)
		_specimen_captions[1].text = "首领　"+str(entry.boss)
		_region_title.text = "%s　·　%s" % [Voyage.NAMES[id],Voyage.BEARINGS[id]]
		_terrain.text = "地形笔记　" + Voyage.HINTS[id]
		_champion.text = "%s · %s\n%s" % [entry.boss,entry.crest,entry.hint]
		_animal.text = "%s · 猎场观察\n%s　猎获为%s，可补一份路粮。" % [entry.prey,entry.get("catch_hint","留心猎物的脚步和停顿。"),entry.trophy]
		_log_status.text = ("已取得纹章" if _known_crests.has(id) else "尚未取得纹章")+"　／　"+("已有收网记录" if _journal_flags.has("capture_"+id) else "尚无收网记录")
		_boss_button.disabled = _known_crests.has(id)
	_entry_title.text = ENTRIES[id][0]
	_byline.text = ENTRIES[id][1]
	_body.text = ENTRIES[id][2]
	_track.text = "追踪点灯主线" if id=="main" else "标出留言地点"
	_scroll.scroll_vertical = 0
	for tab in _tabs.get_children():
		_tabs.remove_child(tab)
		tab.queue_free()
	var pages: Array = collection[1]
	_tabs.visible = pages.size()>1
	for page_id: String in pages:
		var tab := _button(_tabs,Geo.ZONES.get(page_id,"交接本"),false)
		tab.disabled = page_id==id
		tab.pressed.connect(_open_page.bind(page_id))
	_track.grab_focus()

func _mark_region(prefix: String) -> void:
	if not reading or not Wildlife.GUIDE.has(_page) or prefix not in ["hunt_","crest_"]: return
	if prefix == "crest_" and _known_crests.has(_page): return
	var destination := prefix+_page
	close_book()
	clue_selected.emit(destination)

func _choose_clue() -> void:
	if not reading: return
	tracked = _page
	close_book()
	clue_selected.emit(tracked)
