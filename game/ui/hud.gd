extends CanvasLayer
## Canvas-only view. Gameplay owns progression, input capture and save decisions.

signal action(id: String)

const Chart := preload("res://ui/island_chart.gd")
const LighthouseMark := preload("res://ui/lighthouse_mark.gd")
const Voyage := preload("res://expedition_voyage.gd")
const Trails := preload("res://exploration_trails.gd")
const INK := Color("#f6f1df")
const SOFT := Color("#dddcc9")
const GOLD := Color("#f2cb91")
const PANEL := Color("#233837ed")
const EDGE := Color("#6d7970")
const FULL := Control.PRESET_FULL_RECT

var state: Dictionary = {}
var screen := "title"
var base := Control.new()
var play_layer := Control.new()
var menu := Control.new()
var region_label: Label
var clock_label: Label
var task_label: Label
var direction_label: Label
var bag_label: Label
var oil_label: Label
var hp_label: Label
var hp_bar: ProgressBar
var oil_bar: ProgressBar
var boss_box: PanelContainer
var boss_bar: ProgressBar
var boss_name: Label
var weather_label: Label
var travel_label: Label
var sights: Label
var show_core_map := false
var combat_hint: Label
var prompt_box: PanelContainer
var prompt_label: Label
var toast_box: PanelContainer
var toast_label: Label
var toast_timer := Timer.new()
var mini: Control
var full_map: Control
var craft_info: Label
var weapon_button: Button
var armor_button: Button
var menu_buttons: Array[Button] = []
var prologue_block: VBoxContainer
var body_font := SystemFont.new()
var title_font := SystemFont.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 5
	body_font.font_names=PackedStringArray(["Microsoft YaHei","Noto Sans CJK SC","PingFang SC","WenQuanYi Micro Hei","DengXian"])
	title_font.font_names=PackedStringArray(["Microsoft YaHei","Noto Sans CJK SC","PingFang SC","DengXian"])
	title_font.font_weight=700
	var theme_data := Theme.new()
	theme_data.default_font=body_font
	theme_data.default_font_size=17
	base.theme=theme_data
	add_child(base)
	base.set_anchors_and_offsets_preset(FULL)
	base.mouse_filter=Control.MOUSE_FILTER_IGNORE
	base.add_child(play_layer)
	play_layer.set_anchors_and_offsets_preset(FULL)
	play_layer.mouse_filter=Control.MOUSE_FILTER_IGNORE
	base.add_child(menu)
	menu.set_anchors_and_offsets_preset(FULL)
	_build_hud()
	toast_box = _panel(base,12,7)
	_place(toast_box,.5,1,-205,-138,205,-102)
	toast_label = _label(toast_box,"",16,INK,true)
	toast_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	toast_box.hide()
	add_child(toast_timer)
	toast_timer.one_shot=true
	toast_timer.timeout.connect(toast_box.hide)
	base.resized.connect(_resize)
	set_screen(screen)
	update_view(state)
	_resize()

func _box(fill: Color, edge: Color, px: int, py: int) -> StyleBoxFlat:
	var b:=StyleBoxFlat.new()
	b.bg_color=fill
	b.border_color=edge
	b.set_border_width_all(1)
	b.set_corner_radius_all(7)
	b.content_margin_left=px
	b.content_margin_right=px
	b.content_margin_top=py
	b.content_margin_bottom=py
	return b

func _panel(parent: Control, pad_x: int, pad_y: int) -> PanelContainer:
	var p:=PanelContainer.new()
	p.mouse_filter=Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel",_box(PANEL,EDGE,pad_x,pad_y))
	parent.add_child(p)
	return p

func _place(c: Control, ax: float, ay: float, l: float, t: float, r: float, b: float) -> void:
	c.anchor_left=ax
	c.anchor_right=ax
	c.anchor_top=ay
	c.anchor_bottom=ay
	c.offset_left=l
	c.offset_top=t
	c.offset_right=r
	c.offset_bottom=b

func _column(parent: Control, gap: int=8) -> VBoxContainer:
	var v:=VBoxContainer.new()
	v.mouse_filter=Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation",gap)
	parent.add_child(v)
	return v

func _label(parent: Control, message: String, px: int, color: Color=INK, wrap: bool=false) -> Label:
	var l:=Label.new()
	l.text=message
	l.mouse_filter=Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size",px)
	l.add_theme_color_override("font_color",color)
	if wrap:
		l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	return l

func _bar(parent: Control, color: Color, maximum: float, height: int) -> ProgressBar:
	var bar:=ProgressBar.new()
	bar.max_value=maximum
	bar.show_percentage=false
	bar.custom_minimum_size.y=height
	bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var back:=_box(Color("#334b50"),Color.TRANSPARENT,0,0)
	var fill:=_box(color,Color.TRANSPARENT,0,0)
	back.set_border_width_all(0)
	fill.set_border_width_all(0)
	back.set_corner_radius_all(0)
	fill.set_corner_radius_all(0)
	bar.add_theme_stylebox_override("background",back)
	bar.add_theme_stylebox_override("fill",fill)
	parent.add_child(bar)
	return bar

func _field_value(parent: Control, caption: String) -> Label:
	var line:=HBoxContainer.new()
	line.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)
	_label(line,caption,14,SOFT).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	return _label(line,"",14,INK)

func _build_hud() -> void:
	var loc:=_panel(play_layer,15,9)
	_place(loc,0,0,20,16,220,72)
	var lv:=_column(loc,1)
	region_label=_label(lv,"",21,INK)
	clock_label=_label(lv,"",14,SOFT)
	weather_label=_label(lv,"",14,GOLD,true)
	var status:=_panel(play_layer,15,10)
	_place(status,0,1,20,-101,262,-16)
	status.grow_vertical=Control.GROW_DIRECTION_BEGIN
	var sv:=_column(status,4)
	hp_label=_field_value(sv,"生命")
	hp_bar=_bar(sv,Color("#8fc4ae"),100,6)
	oil_label=_field_value(sv,"提灯")
	oil_bar=_bar(sv,GOLD,40,6)
	travel_label=_label(sv,"",14,INK,true)
	travel_label.custom_minimum_size.x=224
	sights=_label(play_layer,"",22,GOLD)
	_place(sights,.5,.5,-23,-18,23,18)
	sights.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	sights.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	sights.add_theme_color_override("font_outline_color",Color("#20343d"))
	sights.add_theme_constant_override("outline_size",4)
	var nav:=_panel(play_layer,7,6)
	_place(nav,1,0,-209,16,-20,170)
	var nv:=_column(nav,3)
	mini=Chart.new()
	mini.custom_minimum_size=Vector2(166,124)
	nv.add_child(mini)
	var nt:=_label(nv,"M 地图   J 记事本   Esc 暂停",14,SOFT)
	nt.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	var goal:=_panel(play_layer,14,9)
	_place(goal,1,1,-349,-80,-20,-16)
	goal.grow_vertical=Control.GROW_DIRECTION_BEGIN
	var gv:=_column(goal,4)
	task_label=_label(gv,"",16,INK,true)
	direction_label=_label(gv,"",14,GOLD,true)
	bag_label=_label(gv,"",14,GOLD)
	prompt_box=_panel(play_layer,14,8)
	_place(prompt_box,.5,1,-179,-64,179,-26)
	prompt_label=_label(prompt_box,"",17,GOLD,true)
	prompt_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	boss_box=_panel(play_layer,15,8)
	_place(boss_box,.5,0,-149,17,149,70)
	var bv:=_column(boss_box,4)
	boss_name=_label(bv,"区域首领",17)
	boss_name.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	boss_bar=_bar(bv,Color("#dd8b6c"),1,6)
	combat_hint = _label(play_layer,"",16,GOLD)
	_place(combat_hint,.5,0,-218,82,218,109)
	combat_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combat_hint.add_theme_color_override("font_outline_color",Color("#162328"))
	combat_hint.add_theme_constant_override("outline_size",5)

func update_view(data: Dictionary) -> void:
	var previous_save: bool=state.get("has_save",false)
	state=data.duplicate(false)
	if not is_node_ready() and hp_label==null:
		return
	var hp: float=state.get("hp",100.0)
	var oil: float=state.get("oil",40.0)
	var mode: int=clampi(int(state.get("lamp",0)),0,2)
	hp_bar.value=hp
	oil_bar.value=oil
	hp_label.text="%d / 100" % ceili(hp)
	oil_label.text="%s    %d / 40" % [["收灯","挂灯","举灯"][mode],ceili(oil)]
	region_label.text=str(state.get("region","灰湾村"))
	clock_label.text="%s  ·  %s" % [state.get("day","白昼"),state.get("tide","低潮")]
	weather_label.text=str(state.get("weather",""))
	weather_label.visible=not weather_label.text.is_empty()
	travel_label.text=str(state.get("field_status",""))
	travel_label.visible=not state.get("in_tower",false)
	sights.visible=state.get("bow",false) and not state.get("afloat",false)
	sights.text="◉" if state.get("draw",0.)>=.97 else "+"
	task_label.text=str(state.get("objective","自由探索灰湾"))
	direction_label.text=str(state.get("directions",""))
	direction_label.visible=not direction_label.text.is_empty()
	var in_library: bool=state.get("in_library",false)
	for panel_item: Control in [mini,hp_bar,task_label]:
		panel_item.get_parent().get_parent().visible=not in_library
	clock_label.visible=not in_library
	if in_library:
		travel_label.hide()
		sights.hide()
		weather_label.hide()
	var crest_count: int = state.get("crests",[]).size()
	bag_label.text = "灯座纹章  %d / 6" % crest_count
	if state.get("bow",false) or not str(state.get("zone","")).is_empty():
		bag_label.text += "　短箭 %d/12" % int(state.get("arrows",12))
	elif int(state.get("salvage",0))>0 and not state.get("taken",[]).has("harbor"):
		bag_label.text += "　修船物料 ×%d" % int(state.salvage)
	boss_name.text=state.get("boss_name","区域首领")
	boss_bar.value=float(state.get("boss_hp",-1))
	boss_box.visible=float(state.get("boss_hp",-1))>=0
	combat_hint.text = str(state.get("combat_hint",""))
	var prompt := str(state.get("prompt",""))
	prompt_label.text="E  ·  "+prompt if not prompt.is_empty() else ""
	prompt_box.visible=not prompt_label.text.is_empty()
	mini.update_chart(state)
	if is_instance_valid(full_map):
		full_map.update_chart(state)
	if screen=="forge":
		_update_forge()
	if screen=="title" and previous_save!=bool(state.get("has_save",false)):
		set_screen("title")

func toast(message: String) -> void:
	if toast_label==null:
		return
	toast_label.text=message
	toast_box.show()
	toast_timer.start(3.0)

func _resize() -> void:
	if prompt_box==null:
		return
	if base.size.x<1050:
		_place(prompt_box,.5,1,-170,-172,170,-132)
		_place(toast_box,.5,1,-184,-221,184,-182)
	else:
		_place(prompt_box,.5,1,-179,-64,179,-26)
		_place(toast_box,.5,1,-205,-138,205,-102)
	if is_instance_valid(full_map):
		full_map.custom_minimum_size=Vector2(minf(620,base.size.x-96),minf(350,base.size.y-175))
	if is_instance_valid(prologue_block):
		_fit_prologue()

func _fit_prologue() -> void:
	var half_width := minf(492.,base.size.x*.43)
	var bottom := -clampf(base.size.y*.052,22.,44.)
	_place(prologue_block,.5,1,-half_width,bottom,half_width,bottom)

func _gradient(fade_right: bool) -> void:
	if screen == "title":
		var painting := TextureRect.new()
		painting.texture = preload("res://art/return_to_greybay.webp")
		painting.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		painting.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		painting.mouse_filter = Control.MOUSE_FILTER_IGNORE
		menu.add_child(painting)
		painting.set_anchors_and_offsets_preset(FULL)
	var rect:=TextureRect.new()
	var colors:=PackedColorArray([Color("#172c32ed"),Color("#223b40c4"),Color("#2643474d"),Color("#26434700")]) if fade_right else PackedColorArray([Color("#172b2be8"),Color("#1b3235e8")])
	var grad:=Gradient.new()
	grad.colors=colors
	if fade_right:
		grad.offsets=PackedFloat32Array([0,.30,.49,.88])
	var texture:=GradientTexture2D.new()
	texture.gradient=grad
	texture.fill_to=Vector2(1,0)
	rect.texture=texture
	rect.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	rect.mouse_filter=Control.MOUSE_FILTER_IGNORE
	menu.add_child(rect)
	rect.set_anchors_and_offsets_preset(FULL)

func _button(parent: Control, caption: String, id: String, primary: bool=false) -> Button:
	var b:=Button.new()
	b.text=caption
	b.alignment=HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size=Vector2(0,40)
	b.add_theme_font_size_override("font_size",17)
	var fg:=Color("#152c30") if primary else INK
	b.add_theme_color_override("font_color",fg)
	b.add_theme_color_override("font_focus_color",fg)
	b.add_theme_color_override("font_hover_color",Color("#172c2e") if primary else Color.WHITE)
	b.add_theme_color_override("font_pressed_color",Color("#132a2c"))
	b.add_theme_color_override("font_disabled_color",Color("#9bafb2"))
	b.add_theme_stylebox_override("normal",_box(GOLD if primary else Color("#203c43ed"),GOLD if primary else EDGE,15,5))
	b.add_theme_stylebox_override("hover",_box(Color("#ffdc9d") if primary else Color("#33535b"),GOLD,15,5))
	b.add_theme_stylebox_override("pressed",_box(Color("#cab78a"),GOLD,15,5))
	b.add_theme_stylebox_override("disabled",_box(Color("#203438"),Color("#3b5053"),15,5))
	var focused:=_box(Color.TRANSPARENT,Color("#fff4cd"),15,5)
	focused.draw_center=false
	focused.set_border_width_all(2)
	b.add_theme_stylebox_override("focus",focused)
	parent.add_child(b)
	menu_buttons.append(b)
	b.pressed.connect(_fire.bind(id))
	return b

func _fire(id: String) -> void:
	if id=="map_scale" and is_instance_valid(full_map):
		show_core_map=not show_core_map
		set_screen("map")
		return
	action.emit(id)

func _bind_focus() -> void:
	var active: Array[Button]=[]
	for b in menu_buttons:
		if not b.disabled:
			active.append(b)
	if active.is_empty():
		return
	for i in active.size():
		var b:=active[i]
		var before:=b.get_path_to(active[posmod(i-1,active.size())])
		var after:=b.get_path_to(active[(i+1)%active.size()])
		b.focus_neighbor_top=before
		b.focus_previous=before
		b.focus_neighbor_bottom=after
		b.focus_next=after
	var owner:=get_viewport().gui_get_focus_owner()
	if owner not in active:
		active[0].grab_focus()

func set_screen(next: String) -> void:
	screen=next
	if not base.is_inside_tree():
		return
	for child in menu.get_children():
		menu.remove_child(child)
		child.queue_free()
	menu_buttons.clear()
	prologue_block=null
	full_map=null
	craft_info=null
	weapon_button=null
	armor_button=null
	play_layer.visible=screen=="play"
	menu.visible=not play_layer.visible
	if not menu.visible:
		return
	if screen!="forge":
		toast_box.hide()
	if screen in ["tide_bells","library_read"]: return
	if screen=="prologue":
		_prologue()
		_bind_focus()
		return
	_gradient(screen=="title" or screen=="win")
	if screen=="title" or screen=="win":
		_cover()
	elif screen=="map":
		_atlas()
	elif screen in ["folk_talk","folk_journal"]:
		_islanders()
	elif screen in ["expedition","fieldguide"]:
		_expedition_menu()
	elif screen=="recipes":
		_recipes()
	elif screen in ["field_note","notes"]:
		_notes()
	else:
		_dialog()
	_bind_focus()
	for button in menu_buttons:
		if not button.disabled:
			button.grab_focus()
			break

func _prologue() -> void:
	var ramp := Gradient.new()
	ramp.offsets=PackedFloat32Array([0.,.38,.68,1.])
	ramp.colors=PackedColorArray([Color("#10272a00"),Color("#10272a05"),Color("#10272ad4"),Color("#102329fa")])
	var texture:=GradientTexture2D.new()
	texture.gradient=ramp
	texture.fill_to=Vector2.DOWN
	var shade:=TextureRect.new()
	shade.texture=texture
	shade.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	menu.add_child(shade)
	shade.set_anchors_and_offsets_preset(FULL)

	prologue_block=_column(menu,8)
	prologue_block.grow_vertical=Control.GROW_DIRECTION_BEGIN
	_fit_prologue()
	var page:=int(state.get("prologue_page",0))
	var count:=int(state.get("prologue_count",3))
	var header:=HBoxContainer.new()
	header.alignment=BoxContainer.ALIGNMENT_BEGIN
	header.add_theme_constant_override("separation",12)
	prologue_block.add_child(header)
	_label(header,str(state.get("prologue_caption","")),17,GOLD)
	var number:=_label(header,"%d / %d" % [page+1,count],16,SOFT)
	number.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	number.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	var heading:=_label(prologue_block,str(state.get("prologue_title","")),34,INK,true)
	heading.add_theme_font_override("font",title_font)
	var story:=_label(prologue_block,str(state.get("prologue_text","")),22,INK,true)
	story.add_theme_constant_override("line_spacing",6)
	story.add_theme_color_override("font_shadow_color", Color("#172825"))
	story.add_theme_constant_override("shadow_offset_y",1)

	var actions:=HBoxContainer.new()
	actions.add_theme_constant_override("separation",12)
	prologue_block.add_child(actions)
	var preview:=bool(state.get("prologue_preview",false))
	_button(actions,"结束回看" if preview else "跳过序章","prologue_skip")
	var voice:=_button(actions,"旁白 开" if state.get("prologue_voiced",true) else "旁白 关","prologue_voice")
	voice.tooltip_text="切换语音朗读"
	var space:=Control.new()
	space.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	actions.add_child(space)
	if page>0:
		_button(actions,"上一幕","prologue_back")
	var next_caption:="下一幕"
	if page+1==count:
		next_caption="返回标题" if preview else "走进灰湾"
	var advance:=_button(actions,next_caption,"prologue_next",true)
	advance.grab_focus()

func _islanders() -> void:
	var center := CenterContainer.new()
	menu.add_child(center)
	center.set_anchors_and_offsets_preset(FULL)
	var panel := _panel(center,24,20)
	panel.custom_minimum_size.x = minf(470,base.size.x-42)
	var column := _column(panel,9)
	if screen=="folk_journal":
		_label(column,"我的记事本",30)
		_label(column,"灯塔已经重新亮了。" if state.get("won",false) else "风暴过后，望潮岬失了光。交接本上画着六个空槽，每一枚纹章都在一位区域首领身上。",16,INK,true)
		_label(column,"灯座纹章　%d / 6" % state.get("crests",[]).size(),17,GOLD)
		_label(column,str(state.get("objective","")),16,GOLD,true)
		for row: Array in state.get("folk_jobs",[]):
			_label(column,row[0],19,GOLD)
			_label(column,row[1],16,SOFT,true)
		var options:=HBoxContainer.new()
		column.add_child(options)
		_button(options,"村民的留言","notes")
		_button(options,"野外手册","fieldguide")
		if not state.get("in_tower",false):
			_button(column,"标出点灯路线" if not state.get("won",false) else "标出回村路线","track/main" if not state.get("won",false) else "track/home")
			if not state.get("taken",[]).has("harbor"):
				_button(column,"支线 · 给码头送一份修船物料","track/"+Trails.HARBOR)
			else:
				_label(column,"码头已收到了修船物料",15,SOFT)
		_button(column,"合上记事本 · J","resume",true)
	else:
		var speech: Dictionary = state.get("folk_speech",{})
		_label(column,speech.get("role",""),16,GOLD)
		_label(column,speech.get("name",""),30)
		_label(column,speech.get("line",""),19,INK,true)
		var reply: String = speech.get("action","")
		if not reply.is_empty():
			_button(column,reply+" · E","folk_reply",true)
		_button(column,"下次再聊 · Esc","resume",reply.is_empty())

func _cover() -> void:
	var center:=CenterContainer.new()
	menu.add_child(center)
	center.anchor_left=.055
	center.anchor_right=.055
	center.anchor_bottom=1
	center.offset_right=406
	var v:=_column(center,8)
	v.custom_minimum_size.x=386
	v.add_child(LighthouseMark.new())
	var heading:=_label(v,"最后一座灯塔" if screen=="title" else "灯塔已点亮",48,INK)
	heading.add_theme_font_override("font",title_font)
	_label(v,"六纹归灯   /   "+str(ProjectSettings.get_setting("application/config/version","")) if screen=="title" else "渔船回来了",16,GOLD)
	var brief:="望潮岬的灯灭了，最后一批渔船还在等归港的信号。你师傅在灰湾图书馆留了一本交接簿，第一页画着六个空槽。" if screen=="title" else "六枚纹章在灯座上亮起，灰湾码头的引航灯也应声发光。岸上的人听见了第一艘渔船的回号。"
	var lead:=_label(v,brief,17,SOFT,true)
	lead.custom_minimum_size.y=52
	if screen=="win":
		_button(v,"返回主菜单","quit",true)
		return
	if state.get("has_save",false):
		_button(v,"继续旅程","continue",true)
		_button(v,"回看序章","prologue_replay")
		_button(v,"重新开始（覆盖存档）","start")
	else:
		_button(v,"开始旅程","start",true)
	_button(v,"退出游戏","quit")

func _dialog() -> void:
	var center:=CenterContainer.new()
	menu.add_child(center)
	center.set_anchors_and_offsets_preset(FULL)
	var panel:=_panel(center,25,18)
	panel.custom_minimum_size.x=464
	var v:=_column(panel,8)
	if screen=="settings":
		_label(v,"声音与天气",30)
		_button(v,"总音量　"+["静音","轻声","标准"][state.get("volume_step",2)],"volume")
		_button(v,"柔和天气画面　"+("开" if state.get("gentle_weather",false) else "关"),"gentle_weather")
		_label(v,"柔和模式减轻闪光与天气粒子。雪旗、波纹和地面预警仍然可见。",15,SOFT,true)
		_button(v,"回到旅程","resume",true)
		return
	if screen=="post":
		_label(v,"海岸邮驿",31)
		_label(v,"沿途登记红邮筒，便能搭邮班往返。",16,SOFT)
		for stop: Array in state.get("post_stops",[]):
			var suffix := "  ·  本站" if stop[3] else ("" if stop[2] else "  ·  尚未登记")
			_button(v,stop[1]+suffix,"ride/"+str(stop[0])).disabled = stop[3] or not stop[2]
		_button(v,"离开邮驿","resume",true)
		return
	if screen=="forge":
		_label(v,"灰湾铁匠铺",32)
		craft_info=_label(v,"",16,GOLD)
		weapon_button=_button(v,"","forge_weapon")
		armor_button=_button(v,"","forge_armor")
		_button(v,"休整补给","rest")
		_button(v,"回到村庄","resume")
		_update_forge()
		return
	_label(v,"旅程已暂停",32)
	_label(v,"WASD 移动  ·  Shift 奔跑  ·  空格闪避",15,SOFT)
	_label(v,"鼠标转向  ·  左键命中后再点可接三段连击  ·  右键举灯",15,SOFT)
	_label(v,"光圈快到边上时按空格躲开，马上点左键就能反击。",15,GOLD)
	_label(v,"F 挂灯或收灯  ·  E 交互  ·  M 岛图  ·  Esc 暂停",15,SOFT)
	_label(v,"1 近战 / 2 短弓　按住左键拉弓、松开发射　R 吃饭 / T 喝水",15,SOFT)
	_button(v,"继续探索","resume",true)
	_button(v,"展开岛图","map")
	_button(v,"岛民来托 · J","folk_journal")
	_button(v,"声音与天气","settings")
	_button(v,"返回主菜单","quit")

func _update_forge() -> void:
	if not is_instance_valid(craft_info):
		return
	var iron:=int(state.get("iron",0))
	var resin:=int(state.get("resin",0))
	craft_info.text="持有材料     废铁 %d     树脂 %d" % [iron,resin]
	var weapon:=bool(state.get("weapon",false))
	var armor:=bool(state.get("armor",false))
	weapon_button.text="钩刃短矛     "+("已打造" if weapon else "废铁 2  ·  树脂 2")
	armor_button.text="炉背护肩     "+("已打造" if armor else "废铁 4  ·  树脂 2")
	weapon_button.disabled=weapon or iron<2 or resin<2
	armor_button.disabled=armor or iron<4 or resin<2
	_bind_focus()

func _atlas() -> void:
	var center:=CenterContainer.new()
	menu.add_child(center)
	center.set_anchors_and_offsets_preset(FULL)
	var shell:=_panel(center,18,12)
	var v:=_column(shell,6)
	_label(v,"灰湾村和周边" if show_core_map else "全岛步行地图",28)
	full_map=Chart.new()
	full_map.expanded=true
	full_map.regional_chart=show_core_map
	var viewport_size:=get_viewport().get_visible_rect().size
	full_map.custom_minimum_size=Vector2(minf(620,viewport_size.x-96),minf(350,viewport_size.y-175))
	v.add_child(full_map)
	full_map.update_chart(state)
	if not state.get("walking_route",PackedVector2Array()).is_empty():
		_label(v,str(state.get("objective","")),16,GOLD,true)
	_label(v,"书本是图书馆，三角是营地，空圈是首领，金色实心圈是已取得的纹章。选定目的地后，金线会标出路线。",15,SOFT,true)
	var navigation:=HBoxContainer.new()
	v.add_child(navigation)
	_button(navigation,"看全境" if show_core_map else "放大灰湾","map_scale")
	_button(navigation,"六地手册","fieldguide")
	if not state.get("in_tower",false) and not state.get("in_library",false):
		_button(navigation,"标出图书馆","track/library")
	if not state.get("in_tower",false) and not state.get("won",false):
		_button(navigation,"追踪主线","track/main")
	if not str(state.get("story_pin","")).is_empty():
		_button(navigation,"清除路线","track/")
	_button(v,"收起岛图","resume",true)
	if state.get("can_recall",false):
		var ready: bool=state.get("bell_ready",false)
		_button(v,"吹响归港号 · 返回灰湾" if ready else "归港号 · 明日再启","bell_return").disabled=not ready

func _expedition_menu() -> void:
	var center:=CenterContainer.new()
	menu.add_child(center)
	center.set_anchors_and_offsets_preset(FULL)
	var panel:=_panel(center,22,16)
	panel.custom_minimum_size.x=minf(640.,base.size.x-42.)
	var v:=_column(panel,7)
	if screen=="fieldguide":
		_label(v,"六区野外手册　%d / 6" % state.get("crests",[]).size(),29)
		var guide: Array = state.get("guide_rows",[])
		for index in guide.size():
			var row: Array = guide[index]
			var id: String = Voyage.ORDER[index]
			var claimed: bool = state.get("crests",[]).has(id)
			var line := HBoxContainer.new()
			v.add_child(line)
			var recorded: bool=state.get("taken",[]).has("capture_"+id)
			var title := _label(line,str(row[0])+(" · 已网获" if recorded else ""),17,GOLD)
			title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			var hunt:=_button(line,"标出猎场","track/"+Trails.HUNT+id)
			hunt.disabled=state.get("in_tower",false)
			var button := _button(line,"已取得" if claimed else "追踪首领","track/"+Trails.CREST+id)
			button.disabled = claimed or state.get("in_tower",false)
			_label(v,row[1],14,SOFT,true)
		if state.get("taken",[]).has("lake_soundings"):
			_label(v,"湖心钟印　·　已登上沉钟湖旧钟楼",14,GOLD)
		_button(v,"合上手册","resume",true)
		return
	var camp: String = state.get("camp","")
	if not camp.is_empty():
		_label(v,Voyage.NAMES[camp]+"的营地",29)
		_label(v,"饭、水和箭都补好了。下次在野外倒下，你会回到这里。",16,SOFT,true)
		_label(v,Voyage.HINTS[camp],17,GOLD)
		_button(v,"继续沿小路探索","resume",true)
		_button(v,"在地图上标出回村的路","expedition/home")
		return
	_label(v,"村口的地图",31)
	_label(v,"六条路都能从灰湾出发。选一处，地图会标出通往首领的路，也可以在六区手册里另选一处。",16,SOFT,true)
	_button(v,"标出图书馆","track/library")
	_button(v,"闻芷的六地食谱","village_recipes")
	var grid:=GridContainer.new()
	grid.columns=2
	grid.add_theme_constant_override("h_separation",8)
	grid.add_theme_constant_override("v_separation",6)
	v.add_child(grid)
	for id: String in Voyage.ORDER:
		var goal: String = "寻访留言" if state.get("crests",[]).has(id) else Voyage.CRESTS[id]+"纹章"
		var button:=_button(grid,Voyage.NAMES[id]+"　"+goal,"expedition/"+id)
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_button(v,"留在灰湾","resume")

func _recipes() -> void:
	var center:=CenterContainer.new()
	menu.add_child(center)
	center.set_anchors_and_offsets_preset(FULL)
	var panel:=_panel(center,23,16)
	panel.custom_minimum_size.x=minf(825.,base.size.x-48.)
	var column:=_column(panel,7)
	_label(column,"闻芷的六地食谱",30)
	_label(column,"每道菜用一份猎获，备两份路粮、添十格灯油。趁热吃下，行路效果持续六个游戏小时，吃下一道菜会替换前一道。",16,SOFT,true)
	var status: String=state.get("meal_status","")
	if not status.is_empty(): _label(column,status,16,GOLD,true)
	var grid:=GridContainer.new()
	grid.columns=2
	grid.add_theme_constant_override("h_separation",18)
	grid.add_theme_constant_override("v_separation",8)
	column.add_child(grid)
	var pantry: Dictionary=state.get("recipe_stock",{})
	for id: String in Voyage.ORDER:
		var dish: Array=Voyage.RECIPES[id]
		var amount: int=pantry.get(id,0)
		var card:=_column(grid,2)
		card.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		var cook:=_button(card,"做"+str(dish[0]),"cook/"+id)
		cook.disabled=amount<=0
		_label(card,"%s　·　现有 %d 份" % [dish[1],amount],15,INK,true)
		_label(card,dish[2],15,SOFT,true)
	_button(column,"回到图桌","back_recipes",true)

func _notes() -> void:
	var center:=CenterContainer.new()
	menu.add_child(center)
	center.set_anchors_and_offsets_preset(FULL)
	var panel:=_panel(center,24,20)
	panel.custom_minimum_size.x=minf(545.,base.size.x-48.)
	var v:=_column(panel,10)
	if screen=="field_note":
		var id:String=state.get("note_id","")
		if Trails.NOTES.has(id):
			var note:Array=Trails.NOTES[id]
			_label(v,Voyage.NAMES[id]+" · 村民的留言",15,GOLD)
			_label(v,note[0],28)
			_label(v,note[2],19,INK,true)
			_label(v,note[3],15,SOFT)
			_label(v,"已经记下来了。按 J 可以再读，回图书馆也能在墙上看到这张留言。",14,SOFT,true)
		_button(v,"收好，接着走","resume",true)
		return
	_label(v,"村民的留言",29)
	for id: String in Voyage.ORDER:
		if state.get("taken",[]).has(Trails.PREFIX+id):
			_button(v,str(Trails.NOTES[id][0])+"　·　"+Voyage.NAMES[id],"read_note/"+id)
		else:
			_button(v,"去"+Voyage.NAMES[id]+"，"+str(Trails.NOTES[id][1]),"track/"+id)
	_button(v,"合上记事本","resume",true)


