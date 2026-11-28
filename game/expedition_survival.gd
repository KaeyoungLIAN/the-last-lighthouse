extends Node3D

const Geo = preload("res://world/expedition_geography.gd")
const Voyage = preload("res://expedition_voyage.gd")
const WeatherFX = preload("res://world/expedition_weather_fx.gd")
const PERIODS := {"snow":39.0,"tide":27.0,"volcano":22.0,"desert":30.0,"lake":44.0,"forest":25.0}
const CHANCE := {"snow":.80,"tide":.87,"volcano":.78,"desert":.82,"lake":.88,"forest":.85}
const OFFSET := {"snow":11,"tide":16,"volcano":7,"desert":24,"lake":0,"forest":16}
const CALM := {"snow":"还能看清旗子，顺着旗子走","tide":"浪大时上高岸","volcano":"踩黑色的石头过岩浆","desert":"到沙丘背面躲风","lake":"听到钟声，看看哪里有两圈水纹","forest":"能从倒木上过沟，也能走下面的小路"}
const WARN := {"snow":"雪旗被吹直了，大雪要来了","tide":"浪花越来越近，快上高岸","volcano":"地面亮起蓝圈，快走开，要打雷了","desert":"沙丘顶上开始扬沙，快找地方躲风","lake":"钟响了，湖面快起雾了","forest":"叶子都翻了过来，前面的木桥快晃起来了"}
const STORM := {"snow":"雪太大了，跟着旗子走","tide":"大浪来了，往高处走","volcano":"正在打雷，岩浆也涨了","desert":"风很大，到沙丘背面去","lake":"起雾了，朝有两圈水纹的钟声走","forest":"桥在晃，也可以走沟底的小路"}
const MOORING := Vector2(-250,8)
## 1 uses each region's ordinary odds. 0 suppresses outbreaks, 2 guarantees each timed event.
@export_range(0,2,.05) var weather_frequency := 1.0
var food := 100.0
var water := 100.0
var warmth := 0.0
var wet := 0.0
var rations := 2
var drinks := 2
var pantry: Dictionary = {}
var meal_zone := ""
var meal_until := 0.0
var extreme_time := 0.0
var rescue_count := 0
var last_rescue := Vector2.ZERO
var game
var fx := WeatherFX.new()
var active := true
var zone := ""
var phase := "calm"
var weather_strength := 0.0
var sheltered := false
var crested := false
var gaining_heat := 0.0
var entry_grace := 0.0
var grip_time := 0.0
var braced := 0.0
var grace := 0.0
var river_cooldown := 0.0
var exposure_pulse := 0.0
var last_cycle := -1
var warned := false
var discharged := false
var struck := false
var target_valid := false
var target := Vector2.ZERO
var part := 0.0
var episode := 0
var journey_time := 0.0
var pending_wash := 0.0
var surf_impulse := 0.0
var hold_point := Vector2.ZERO
var last_food_low := false
var last_water_low := false

func build(host) -> void:
	game = host
	add_child(fx)
	fx.build(host,MOORING)

func set_active(enabled: bool) -> void:
	active = enabled
	fx.set_active(enabled)
	if not enabled:
		target_valid = false
		fx.clear_strike()

func snapshot() -> Dictionary:
	return {"food":food,"water":water,"warmth":warmth,"wet":wet,"rations":rations,"drinks":drinks,
		"pantry":pantry.duplicate(),"meal_zone":meal_zone,"meal_until":meal_until,
		"extreme":extreme_time,"rescues":rescue_count,"shore":last_rescue,"washed":pending_wash>0.0}

func restore(data: Dictionary, legacy_hunts: Dictionary = {}, legacy_flags: Array = []) -> void:
	pantry.clear()
	var saved_stock = data.get("pantry")
	for id: String in Voyage.ORDER:
		if saved_stock is Dictionary:
			var amount = saved_stock.get(id,0)
			if amount is int and amount>0: pantry[id]=amount
		elif legacy_hunts.has(id) and not legacy_flags.has("village_taste_"+id):
			# Older journals remembered only the last hunt and the first hand-in.
			pantry[id]=1
	var saved_zone = data.get("meal_zone","")
	var saved_until = data.get("meal_until",0.0)
	meal_zone=saved_zone if saved_zone is String and Voyage.RECIPES.has(saved_zone) else ""
	meal_until=float(saved_until) if (saved_until is float or saved_until is int) and is_finite(float(saved_until)) else 0.0
	food = clampf(data.get("food",100.0),0,100)
	water = clampf(data.get("water",100.0),0,100)
	warmth = clampf(data.get("warmth",0.0),-100,100)
	wet = clampf(data.get("wet",0.0),0,100)
	rations = clampi(data.get("rations",2),0,6)
	drinks = clampi(data.get("drinks",2),0,4)
	extreme_time = clampf(data.get("extreme",0.0),0,180)
	rescue_count = maxi(data.get("rescues",0),0)
	last_rescue = data.get("shore",Vector2.ZERO)
	surf_impulse = 0.0
	pending_wash = .01 if data.get("washed",false) else 0.0
	grace = 5.0
	exposure_pulse = 0
	grip_time = 0
	braced = 0
	river_cooldown = 0
	last_food_low = food<25
	last_water_low = water<25
	_change_zone("")

func resupply() -> void:
	food = 100
	water = 100
	rations = maxi(rations,3)
	drinks = maxi(drinks,2)
	warmth = move_toward(warmth,0,75)
	wet = 0
	extreme_time = 0
	last_food_low = false
	last_water_low = false

func consume(action: String) -> bool:
	if action=="eat":
		if rations<=0 or food>=99:
			game._notice("口粮袋空了，猎获或营地可补给。" if rations<=0 else "现在还很饱。")
			return false
		rations-=1
		food=minf(100,food+36)
		game._notice("吃下一份口粮 · 饱食 %d" % roundi(food),"pickup")
	elif action=="drink":
		if drinks<=0 or water>=99:
			game._notice("水囊空了，回营地装水。" if drinks<=0 else "现在不渴。")
			return false
		drinks-=1
		water=minf(100,water+42)
		game._notice("饮下一口水 · 饮水 %d" % roundi(water),"pickup")
	else:
		return false
	return true

func add_harvest(zone_id: String) -> void:
	if Geo.ZONES.has(zone_id):
		rations=mini(6,rations+1)
		pantry[zone_id]=int(pantry.get(zone_id,0))+1

func serve_meal(id: String, clock: float) -> bool:
	var available: int=pantry.get(id,0)
	if available<=0 or not Voyage.RECIPES.has(id): return false
	if available==1: pantry.erase(id)
	else: pantry[id]=available-1
	meal_zone=id
	meal_until=clock+Voyage.MEAL_MINUTES
	rations=mini(6,rations+2)
	return true

func meal_status(clock: float) -> String:
	if meal_zone.is_empty() or clock>=meal_until: return ""
	var minutes:=ceili(meal_until-clock)
	return "%s　余 %d 小时 %02d 分钟　%s" % [Voyage.RECIPES[meal_zone][0],floori(minutes/60.0),minutes%60,Voyage.RECIPES[meal_zone][2]]

func sprint_scale() -> float:
	return lerpf(.77,1.0,clampf(food/25.0,0,1))

func bow_sway() -> float:
	# Angular amplitude, in radians, applied by the bow after a sustained draw.
	return .043*(1.0-clampf(water/25.0,0,1))

func hud_text() -> String:
	var temp := "舒适"
	if warmth < -26: temp="寒冷"
	elif warmth > 26: temp="炎热"
	if gaining_heat<-.13: temp+="↓"
	elif gaining_heat>.13: temp+="↑"
	return "饱食 %d　饮水 %d　%s%s\nR 口粮 ×%d　T 水 ×%d" % [roundi(food),roundi(water),temp," · 湿衣" if wet>1 else "",rations,drinks]

func weather_text() -> String:
	if pending_wash>0: return "夜浪卷离沙脊 · 正漂向救援棚"
	if grip_time>0: return "盘根纹章抓住了桥缘 · E 攀回倒木"
	if zone=="": return ""
	if absf(warmth)>=76: return "体温濒危 · 尽快回到营棚遮蔽处"
	if braced>0: return "握紧避浪桩 · 留在桩边"
	if zone=="tide" and _position().distance_squared_to(MOORING)<10: return "E 抓住避浪桩"
	if sheltered: return "营棚背风 · 衣物正在晾干" if wet>1 else "背风处 · 体温趋于舒适"
	if phase=="warning": return WARN[zone]
	if phase=="storm": return STORM[zone]
	return CALM[zone]

func handle_interact() -> bool:
	if not active or not is_instance_valid(game) or game.in_tower: return false
	if grip_time>0:
		grip_time=0
		game._place_hero(hold_point)
		grace=4.0
		game._notice("借倒木边缘翻回桥面。","switch")
		return true
	if zone=="tide" and _position().distance_squared_to(MOORING)<10:
		braced=11.0
		game._notice("握稳桩绳，留在桩边可等这轮浪过去。","switch")
		return true
	return false

func _position() -> Vector2:
	return Vector2(game.hero.position.x,game.hero.position.z)

func _change_zone(next: String) -> void:
	zone=next
	phase="calm"
	weather_strength=0
	entry_grace=3.0
	last_cycle=-1
	target_valid=false
	grip_time=0
	braced=0
	gaining_heat=0
	fx.clear_strike()

func _weather(clock: float) -> void:
	var period: float = PERIODS[zone]
	var shifted: float = clock+OFFSET[zone]
	episode=floori(shifted/period)
	part=fposmod(shifted,period)
	if episode!=last_cycle:
		last_cycle=episode
		warned=false
		struck=false
		discharged=false
		target_valid=false
		fx.clear_strike()
	var chance := clampf(float(CHANCE[zone])*weather_frequency,0,1)
	var roll := float(posmod(hash(Vector2i(zone.hash(),episode)),10000))/10000.0
	phase="calm"
	if roll>=chance: return
	var calm_len := period*.43
	var warning_len := 3.4 if zone!="forest" else 2.6
	if part<calm_len: return
	if part<calm_len+warning_len: phase="warning"
	elif part<period*.91: phase="storm"

func tick(delta: float,zone_id: String,crests: Array) -> void:
	if not active or delta<=0 or game.hero.hp<=0: return
	var p := _position()
	if not Geo.ZONES.has(zone_id): zone_id=""
	if zone!=zone_id: _change_zone(zone_id)
	journey_time+=delta
	grace=maxf(0,grace-delta)
	entry_grace=maxf(0,entry_grace-delta)
	river_cooldown=maxf(0,river_cooldown-delta)
	braced=maxf(0,braced-delta) if p.distance_squared_to(MOORING)<15 else 0
	if pending_wash>0:
		pending_wash-=delta
		_push(Vector2(-.3,1).normalized(),delta*3.8)
		fx.wash(maxf(0,pending_wash))
		if pending_wash<=0: _rescue()
		return
	if surf_impulse>0:
		_push(Vector2(-.3,1).normalized(),delta*surf_impulse*2.1)
		surf_impulse=maxf(0,surf_impulse-delta)
	crested=crests.has(zone)
	sheltered=zone!="" and Geo.sheltered(p)
	if zone!="":
		_weather(game.time_elapsed)
		if phase=="storm" and entry_grace>0: phase="warning"
	else:
		phase="calm"
	var target_strength := .17 if zone!="" else 0.0
	if phase=="warning": target_strength=.48
	if phase=="storm": target_strength=1.0
	if sheltered: target_strength*=.34
	weather_strength=move_toward(weather_strength,target_strength,delta*.48)
	_metabolism(delta,p)
	if zone!="": _hazards(delta,p)
	if game.hero.hp<=0: return
	fx.advance(delta,zone,phase,weather_strength,wind_strength(),p,game,crested,clampf(absf(warmth)/100.0,0,1),warmth<0)

func wind_strength() -> float:
	return weather_strength*(.64 if crested and zone=="desert" else 1.0)

func _metabolism(delta: float,p: Vector2) -> void:
	var sprint: bool = game.hero.velocity.length_squared()>31
	var sunny: bool = zone=="desert" and game.world_day>.48 and not sheltered
	var regional_meal := meal_zone if zone==meal_zone and game.time_elapsed<meal_until else ""
	var conserve_food: bool=(regional_meal=="forest" and sprint) or (regional_meal=="lake" and game.ferry.afloat)
	var food_cost := (.066 if sprint else .05)*(.5 if conserve_food else 1.0)
	food=maxf(0,food-delta*food_cost)
	var water_cost := ((7.0 if sunny else 4.0)+(1.6 if sprint else 0.0))/60.0
	water=maxf(0,water-delta*water_cost*(.5 if regional_meal=="desert" else 1.0))
	wet=maxf(0,wet-delta*(1.8 if sheltered else .30)*(2.0 if regional_meal=="tide" else 1.0))
	var before := warmth
	if sheltered or zone=="":
		warmth=move_toward(warmth,0,delta*(1.1 if sheltered else .26))
	else:
		var drift := 0.0
		if zone=="snow": drift=(-.25-.65*weather_strength)*(.66 if crested else 1.0)
		elif zone=="volcano":
			var rim := 1.0-smoothstep(4,43,Geo.path_distance(p,Geo.LAVA_CREEK))
			drift=(.13+.55*rim)*(.66 if crested else 1.0)
		elif sunny: drift=.37+(.21 if sprint else 0.0)
		if regional_meal in ["snow","volcano"]: drift*=.5
		if wet>1: drift-=.32*(wet/100.0)
		if is_zero_approx(drift): warmth=move_toward(warmth,0,.18*delta)
		else: warmth=clampf(warmth+delta*drift,-100,100)
	gaining_heat=(warmth-before)/delta
	if food<25 and not last_food_low: game._notice("有些饿了，长跑吃力。按 R 吃口粮。")
	if water<25 and not last_water_low: game._notice("水分不足，久瞄会不稳。按 T 喝水。")
	last_food_low=food<25
	last_water_low=water<25
	if absf(warmth)<76:
		extreme_time=0
		exposure_pulse=0
		return
	if extreme_time==0: game._notice("体温濒危，三十秒内进营棚避寒或降温。","discover")
	extreme_time+=delta
	if extreme_time>=30:
		exposure_pulse-=delta
		if exposure_pulse<=0:
			game.hero.receive_hit(minf(6,2+floorf((extreme_time-30)/18.0)))
			exposure_pulse=5.0

func _push(dir: Vector2,length: float) -> void:
	var p:=_position()
	var next:=p+dir*minf(length,.34)
	if game.world.is_walkable(next.x,next.y):
		var at:=Vector3(next.x,game.world.ground_height(next.x,next.y),next.y)
		if absf(at.y-game.hero.position.y)<.75: game.hero.position=at

func _hazards(delta: float,p: Vector2) -> void:
	var hazard := Geo.hazard_at(p)
	if grip_time>0:
		grip_time-=delta
		if p.distance_to(hold_point)>3.2: grip_time=0
		elif grip_time<=0: _drop_to_moss(p)
	if phase=="warning" and not warned and not sheltered:
		warned=true
		if zone=="volcano":
			target=p
			target_valid=true
			fx.warn_strike(target,game.world)
		fx.cue_warning(zone)
	if sheltered or grace>0: return
	if zone=="volcano":
		var overtopped:=phase=="storm" and p.distance_squared_to(Geo.COOL_STONES[1])<1.15*1.15
		if (hazard=="lava" or overtopped) and river_cooldown<=0:
			game.hero.receive_hit(13 if phase=="storm" else 8)
			river_cooldown=2.1
			game._notice("踩进熔溪！快踏上深色冷却石。")
		if phase=="storm" and target_valid and not discharged:
			discharged=true
			fx.strike(target,game.world)
			if p.distance_squared_to(target)<3.45*3.45: game.hero.receive_hit(18)
	if phase!="storm": return
	if zone=="desert":
		_push(Vector2(.94,-.34),delta*1.35*wind_strength())
	elif zone=="tide" and hazard=="surf" and braced<=0 and not struck:
		struck=true
		if game.world_day<.36 and game.tide_level>.35:
			pending_wash=.8
			fx.wash(pending_wash)
			game._notice("夜浪卷上沙脊，水流正把你带向下游。","switch")
		else:
			wet=maxf(wet,38)
			surf_impulse=.68 if crested else 1.0
			game._notice("一排小浪打湿了靴子。" if not crested else "礁足纹章稳住了脚步。")
	elif zone=="forest" and hazard=="bridge" and not struck:
		# Wind reaches the leeward span later. Its nearby ferns show the delayed pulse.
		var span:int=0 if Geo.path_distance(p,Geo.FOREST_BRIDGES[0])<1.65 else 1
		var age:=part-(float(PERIODS.forest)*.43+2.6)-span*3.6
		if age<0 or age>2.2: return
		struck=true
		if crested:
			grip_time=4
			hold_point=p
			game._notice("盘根纹章扣住桥缘 · 按 E 攀回！","switch")
		else: _drop_to_moss(p)

func _drop_to_moss(p: Vector2) -> void:
	game._place_hero(Geo.moss_landing(p))
	grace=3
	game._notice("枝桥一晃，落到下层苔径。可沿根坡回到主路。","switch")

func _rescue() -> void:
	last_rescue=Geo.CAMPS.tide
	game.time_elapsed+=28.0
	game._conditions()
	game._place_hero(last_rescue)
	wet=100
	warmth=maxf(-90,warmth-13)
	rescue_count+=1
	grace=12
	struck=true
	fx.wash(0)
	game._notice("在下游救援棚上岸了。背包齐全，烘干湿衣再走。","start")
	game._save()
