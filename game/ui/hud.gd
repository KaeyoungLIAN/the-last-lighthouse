extends CanvasLayer
## Canvas-only view. Gameplay owns progression, input capture and save decisions.

signal action(id: String)

const Chart := preload("res://ui/island_chart.gd")
const LighthouseMark := preload("res://ui/lighthouse_mark.gd")
const INK := Color("#f6f1df")
const SOFT := Color("#c0d4d1")
const GOLD := Color("#f2c983")
const PANEL := Color("#142a30ee")
const EDGE := Color("#50686b")
const FULL := Control.PRESET_FULL_RECT

var state: Dictionary = {}
var screen := "title"
var base := Control.new()
var play_layer := Control.new()
var menu := Control.new()
var region_label: Label
var clock_label: Label
var task_label: Label
var bag_label: Label
var oil_label: Label
var hp_label: Label
var hp_bar: ProgressBar
var oil_bar: ProgressBar
var boss_box: PanelContainer
var boss_bar: ProgressBar
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
	b.set_corner_radius_all(3)
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
	var status:=_panel(play_layer,15,10)
	_place(status,0,1,20,-101,262,-16)
	status.grow_vertical=Control.GROW_DIRECTION_BEGIN
	var sv:=_column(status,4)
	hp_label=_field_value(sv,"生命")
	hp_bar=_bar(sv,Color("#8fc4ae"),100,6)
	oil_label=_field_value(sv,"提灯")
	oil_bar=_bar(sv,GOLD,40,6)
	var nav:=_panel(play_layer,7,6)
	_place(nav,1,0,-209,16,-20,170)
	var nv:=_column(nav,3)
	mini=Chart.new()
	mini.custom_minimum_size=Vector2(166,124)
	nv.add_child(mini)
	var nt:=_label(nv,"M  岛图    Esc  暂停",14,SOFT)
	nt.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	var goal:=_panel(play_layer,14,9)
	_place(goal,1,1,-349,-80,-20,-16)
	goal.grow_vertical=Control.GROW_DIRECTION_BEGIN
	var gv:=_column(goal,4)
	task_label=_label(gv,"",16,INK,true)
	bag_label=_label(gv,"",14,GOLD)
	prompt_box=_panel(play_layer,14,8)
	_place(prompt_box,.5,1,-179,-64,179,-26)
	prompt_label=_label(prompt_box,"",17,GOLD,true)
	prompt_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	boss_box=_panel(play_layer,15,8)
	_place(boss_box,.5,0,-149,17,149,70)
	var bv:=_column(boss_box,4)
	var enemy:=_label(bv,"灯塔守护者",17)
	enemy.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	boss_bar=_bar(bv,Color("#dd8b6c"),1,6)

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
	task_label.text=str(state.get("objective","寻找守塔人的钥匙"))
	bag_label.text="塔钥匙 %s    燃料 %d    已装 %d/2" % ["✓" if state.get("key",false) else "—",int(state.get("fuel",0)),int(state.get("loaded",0))]
	boss_bar.value=float(state.get("boss_hp",-1))
	boss_box.visible=float(state.get("boss_hp",-1))>=0
	prompt_label.text=str(state.get("prompt",""))
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

func _gradient(fade_right: bool) -> void:
	var rect:=TextureRect.new()
	var colors:=PackedColorArray([Color("#0b2029f7"),Color("#102831ed"),Color("#132c36a6"),Color("#122a330d")]) if fade_right else PackedColorArray([Color("#0b1e26e8"),Color("#0d252fe8")])
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
	_gradient(screen=="title" or screen=="win")
	if screen=="title" or screen=="win":
		_cover()
	elif screen=="map":
		_atlas()
	else:
		_dialog()
	_bind_focus()
	for button in menu_buttons:
		if not button.disabled:
			button.grab_focus()
			break

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
	_label(v,"THE LAST LIGHTHOUSE" if screen=="title" else "望潮岬  ·  航路重开",16,GOLD)
	var brief:="提上油灯，穿过雾林，找回照亮灰湾的光。" if screen=="title" else "光束越过河口，灰湾的渔船重新驶向岸边。"
	var lead:=_label(v,brief,17,SOFT,true)
	lead.custom_minimum_size.y=52
	if screen=="win":
		_button(v,"返回主菜单","quit",true)
		return
	if state.get("has_save",false):
		_button(v,"继续旅程","continue",true)
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
	_label(v,"鼠标转向  ·  左键攻击  ·  右键举灯",15,SOFT)
	_label(v,"F 挂灯或收灯  ·  E 交互  ·  M 岛图  ·  Esc 暂停",15,SOFT)
	_button(v,"继续探索","resume",true)
	_button(v,"展开岛图","map")
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
	_label(v,"灰湾岛图",28)
	full_map=Chart.new()
	full_map.expanded=true
	var viewport_size:=get_viewport().get_visible_rect().size
	full_map.custom_minimum_size=Vector2(minf(620,viewport_size.x-96),minf(350,viewport_size.y-175))
	v.add_child(full_map)
	full_map.update_chart(state)
	_label(v,"箭头为当前位置。靠近地标后，岛图会记下名称与道路。",15,SOFT,true)
	_button(v,"收起岛图","resume",true)


