extends CharacterBody3D
## Wild game and the six local champions share walkability, line of sight and dodge rules.
signal felled(zone_id: String, champion: bool)
const Foe = preload("enemy.gd")
const AnimalArt = preload("expedition_animal_art.gd")
const Warning = preload("attack_warning.gd")
const Art = preload("actor_art.gd")
const STRIKE_REACH := {"snow":8.0,"tide":4.8,"volcano":2.45,"desert":7.0,"lake":3.45,"forest":5.35}
const CHARGE := {"snow":1.25,"tide":1.55,"volcano":1.65,"desert":1.20,"lake":1.43,"forest":1.23}
const LIFE := {"snow":125.0,"tide":135.0,"volcano":118.0,"desert":122.0,"lake":108.0,"forest":125.0}
const NET_CUES := {
	"snow":["低头啄雪","等松鸡落地啄雪"],
	"tide":["缩螯伏沙","等青蟹收螯停步"],
	"volcano":["伏在岩面","等岩蜥伏上暖石"],
	"desert":["落地歇脚","跟住兔子的两次起跳"],
	"lake":["鱼背露出水面","留意鱼背 · 银灯鳟正在潜游"],
	"forest":["昂头嗅风","看枝貂折返时的停顿"]
}

var region := ""
var champion := false
var kind := "expedition"
var hit_radius := .47
var hp := 0.0
var max_hp := 0.0
var keeper
var world
var home := Vector3.ZERO
var intent := Foe.Intent.ROAM
var time_left := 0.0
var phase := 0.0
var recoil := 0.0
var heading := Vector3.FORWARD
var attack_origin := Vector3.ZERO
var aim := Vector3.ZERO
var field_point := Vector3.ZERO
var dealt := false
var hit_obstacle := false
var _can_hit_obstacle := true
var exposed := false
var weather := "calm"
var daylight := .55
var tide := .15
var hud_name := ""
var animal := AnimalArt.new()
var mark := Warning.new()
var echo := Warning.new()
var label := Label3D.new()
var impact_label := Label3D.new()
var _impact_left := 0.0
var _field_prop: Node3D
var _engaged := false
var _skill_fx := Node3D.new()

func setup(id: String,big: bool,caption: String,hero,island,at: Vector3) -> void:
	region = id
	champion = big
	hud_name = caption
	keeper = hero
	world = island
	home = at
	global_position = at
	collision_layer = 4
	collision_mask = 1
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	max_hp = float(LIFE[id]) if big else (20.0 if id=="tide" else 15.0)
	hp = max_hp
	hit_radius = .85 if big else .36
	Art.capsule(self,hit_radius,1.90 if big else .86)
	add_to_group("enemies" if big else "expedition_prey")
	add_child(animal)
	animal.build(id,big)
	add_child(mark)
	add_child(echo)
	add_child(label)
	label.position.y = 2.7 if big else 1.24
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 29
	label.pixel_size = .009
	label.outline_size = 6
	label.modulate = Color("ffdd98") if big else Color("b4dab8")
	label.text = caption
	label.hide()
	add_child(impact_label)
	impact_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	impact_label.font_size = 34
	impact_label.pixel_size = .012
	impact_label.outline_size = 8
	impact_label.no_depth_test = true
	impact_label.hide()
	phase = fposmod(at.x*.13+at.z*.21,TAU)
	if big and id in ["snow","desert","forest"]:
		_build_obstacle()
	add_child(_skill_fx)
	_skill_fx.top_level = true
	_skill_fx.hide()
	if big:
		_build_skill_effect()
	else:
		_build_spoor()

func _build_skill_effect() -> void:
	var tint: String = {"snow":"d8eee9","tide":"92dfdb","volcano":"afdffd","desert":"dda965","lake":"99eee3","forest":"b8cc80"}[region]
	if region=="volcano":
		var bolts := [Vector3.UP*7,Vector3(.45,5,.18),Vector3(-.32,3.3,-.14),Vector3(.28,2.2,.13),Vector3.ZERO]
		for i in range(1,bolts.size()):
			var branch := Art.rod(_skill_fx,bolts[i-1],bolts[i],.066,.039,tint)
			branch.material_override = Art.surface(tint,true)
	else:
		var ring := TorusMesh.new()
		ring.inner_radius = .84
		ring.outer_radius = 1.0
		ring.rings = 32
		ring.ring_segments = 4
		Art.part(_skill_fx,ring,Vector3.ZERO,tint,true)

func _build_spoor() -> void:
	var spoor := Node3D.new()
	add_child(spoor)
	spoor.top_level = true
	spoor.global_position = home
	for i in 7:
		var point := Vector3(sin(i*.78)*1.4,0,float(i)*.70-2.0)
		point.y = world.ground_height(home.x+point.x,home.z+point.z)-home.y+.05
		if region=="forest":
			Art.taper(spoor,point+Vector3.UP*.08,.12,.025,.19,"9c7248",6)
		elif region=="lake" or region=="tide":
			var ripple := TorusMesh.new()
			ripple.inner_radius = .13
			ripple.outer_radius = .15
			ripple.rings = 16
			ripple.ring_segments = 3
			Art.part(spoor,ripple,point,"a3c5ab").scale.y=.3
		else:
			for toe in 3:
				var print_mark := Art.oval(spoor,point+Vector3((toe-1)*.057,0,absf(toe-1)*.025),Vector3(.053,.017,.17),"9b9991" if region=="snow" else "8c795d")
				print_mark.rotation.y = (toe-1)*.35

func _build_obstacle() -> void:
	_field_prop = Node3D.new()
	add_child(_field_prop)
	_field_prop.top_level = true
	field_point = home+Vector3(2.5,0,1.4)
	field_point.y = world.ground_height(field_point.x,field_point.z)
	_field_prop.global_position = field_point
	if region=="forest":
		Art.rod(_field_prop,Vector3.ZERO,Vector3(.14,1.48,0),.40,.27,"705238")
		Art.rod(_field_prop,Vector3(.10,.94,0),Vector3(.69,1.84,-.20),.23,.12,"806444")
	else:
		Art.taper(_field_prop,Vector3.UP*.35,.9,.64,.78,"868b86" if region=="snow" else "9b8373",6)
		Art.taper(_field_prop,Vector3.UP*.83,.62,.30,.55,"d5d9c7" if region=="snow" else "b09b83",5)

func set_running(on: bool) -> void:
	set_physics_process(on)
	visible = on
	collision_layer = 4 if on else 0

func _physics_process(delta: float) -> void:
	if hp<=0 or not keeper.input_enabled or keeper.hp<=0:
		return
	var offset: Vector3 = (keeper.global_position-global_position).slide(Vector3.UP)
	var dist := offset.length()
	label.visible = dist<15.0
	if _impact_left>0:
		_impact_left = maxf(0,_impact_left-delta)
		impact_label.position = Vector3(.32,(3.22 if champion else 1.60)+.44*(1.0-_impact_left/.64),0)
		impact_label.modulate.a = minf(1.0,_impact_left/.18)
		impact_label.visible = _impact_left>0
	phase += delta
	recoil = maxf(0.0,recoil-delta*4.0)
	var travel := Vector3.ZERO
	if champion:
		travel = _decide(delta,offset,dist)
	else:
		var opening := net_window()
		travel = _forage(offset,dist,opening)
		label.text = hud_name+" · "+str(NET_CUES[region][0]) if opening and dist<8.0 else hud_name
		# The lifted muzzle, folded body or peck should read before the player looks at the prompt.
		var lean := 0.0
		if opening:
			match region:
				"snow": lean = -.24-.10*sin(phase*9.0)
				"forest": lean = .24
				"desert","volcano": lean = -.13
		animal.rotation.x = lerp_angle(animal.rotation.x,lean,1.0-exp(-delta*13.0))
	var previous := global_position
	if travel.length_squared()>.001:
		var next := global_position+travel*delta
		if world.is_walkable(next.x,next.z):
			velocity = travel
			move_and_slide()
		if not world.is_walkable(global_position.x,global_position.z):
			global_position = previous
		global_position.y = world.ground_height(global_position.x,global_position.z)
		if intent!=Foe.Intent.WINDUP:
			rotation.y = lerp_angle(rotation.y,atan2(-travel.x,-travel.z),1-exp(-delta*12))
	animal.animate(delta,previous.distance_to(global_position)/maxf(.001,delta),_charge_fraction(),exposed,recoil)

func net_window() -> bool:
	if champion or hp<=0.: return false
	var dist: float=(keeper.global_position-global_position).slide(Vector3.UP).length()
	match region:
		"snow": return dist>=3.25 and animal.position.y<.20 and sin(phase*1.48)<-.20
		"tide": return sin(phase*.65)<-.15 if tide<.65 else sin(phase*1.18)>.52
		"volcano": return cos(phase*.85)<.28
		"desert": return dist<4.4 and fposmod(phase,2.20)>=1.27
		"lake": return sin(phase*1.8)>-.18
		"forest": return dist>=2.5 and absf(sin(phase*.48))>.86
	return false

func _forage(offset: Vector3,dist: float,opening: bool) -> Vector3:
	var wander := home + Vector3(cos(phase*.39)*2.7,0,sin(phase*.50)*1.65)
	var from_home := (global_position-home).slide(Vector3.UP)
	var flee := -offset.normalized() if from_home.length_squared()<30 else -from_home.normalized()
	match region:
		"snow":
			var flush := dist<3.25 and from_home.length()<4.8
			if weather=="storm":
				wander = home+Vector3(-1.75,0,.75)
			animal.position.y = move_toward(animal.position.y, .82 if flush else 0.0,.12)
			if flush: return flee*3.4
			if opening: return Vector3.ZERO
		"tide":
			if tide>.65:
				wander = home+Vector3(1.5,0,-1.0)
			animal.position.y = -.12 if opening else 0.
			if opening: return Vector3.ZERO
			if dist<3.0:
				return flee.rotated(Vector3.UP,.72)*1.55
		"volcano":
			animal.position.y = -.11 if opening else 0.
			if opening: return Vector3.ZERO
			if dist<2.8: return flee*2.65
			if weather=="storm":
				wander = home+Vector3(-1.1,0,-2.25)
		"desert":
			# Two .635 s bounds followed by a low crouch long enough for a hand net.
			var hop := absf(sin(fposmod(phase,2.20)*PI/.635))
			var bolts := dist<4.4
			if opening:
				animal.position.y = -.11
				return Vector3.ZERO
			animal.position.y = hop*.31 if bolts else -.11
			if bolts: return flee*hop*3.4
			if daylight>.8: wander = home+Vector3(.4,0,.6)
		"lake":
			animal.position.y = .08 + .23*sin(phase*1.8)
		"forest":
			var circuit := sin(phase*.48)
			wander = home+Vector3(circuit*3.1,0,sin(phase*.96))
			if dist<2.5: return flee*3.05
			if weather=="storm" or opening: return Vector3.ZERO
	var approach := (wander-global_position).slide(Vector3.UP)
	return approach.limit_length(.74) if approach.length_squared()>.04 else Vector3.ZERO

func resolve_net(caught: bool) -> void:
	if champion or hp<=0.: return
	if not caught:
		recoil=.8
		_show_impact("扑空",Color("e2c494"))
		return
	hp=0.
	collision_layer=0
	collision_mask=0
	set_physics_process(false)
	label.hide()
	impact_label.hide()
	remove_from_group("expedition_prey")
	felled.emit(region,false)
	var scoop:=create_tween()
	scoop.tween_method(_draw_into_net.bind(global_position,animal.scale),0.,1.,.34)
	scoop.tween_callback(queue_free)

func _draw_into_net(progress: float, start: Vector3, original_size: Vector3) -> void:
	# Credit the catch immediately; only its silhouette follows the moving hoop.
	if not is_instance_valid(keeper) or not keeper.input_enabled or keeper.global_position.distance_squared_to(start)>36.:
		hide()
		queue_free()
		return
	var glide:=smoothstep(.06,.98,progress)
	global_position=start.lerp(keeper.get_net_mouth(),glide)+Vector3.UP*(sin(glide*PI)*.32)
	animal.scale=original_size*lerpf(1.,.14,smoothstep(.13,1.,progress))

func _decide(delta: float,offset: Vector3,dist: float) -> Vector3:
	time_left = maxf(0,time_left-delta)
	if keeper.global_position.distance_squared_to(home)>30.0*30.0:
		if _engaged:
			_engaged = false
			hp = max_hp
			_hide_warning()
			intent = Foe.Intent.ROAM
			exposed = false
		return (home-global_position).slide(Vector3.UP).limit_length(3.0)
	if not _engaged and dist<16.0 and keeper.has_clear_view(global_position+Vector3.UP):
		_engaged = true
		intent = Foe.Intent.CHASE
	if not _engaged:
		return Vector3.ZERO
	if intent==Foe.Intent.RECOVER:
		if time_left<=0:
			exposed = false
			intent = Foe.Intent.CHASE
		return Vector3.ZERO
	if intent==Foe.Intent.WINDUP:
		mark.set_charge(_charge_fraction())
		if echo.visible: echo.set_charge(_charge_fraction())
		if time_left<=0:
			intent = Foe.Intent.STRIKE
			time_left = .70
			dealt = false
			_skill_fx.show()
			_skill_fx.global_position = aim+Vector3.UP*.22
		if region=="volcano":
			return heading*2.4
		return Vector3.ZERO
	if intent==Foe.Intent.STRIKE:
		return _execute(delta)
	var trigger := 7.8 if region in ["snow","volcano","desert"] else 4.6
	if dist<trigger and keeper.has_clear_view(global_position+Vector3.UP):
		if region=="snow" and weather=="storm":
			return Vector3.ZERO
		_begin(offset)
		return Vector3.ZERO
	return offset.normalized()*3.65

func _begin(offset: Vector3) -> void:
	heading = offset.normalized() if offset.length_squared()>.001 else Vector3.FORWARD
	rotation.y = atan2(-heading.x,-heading.z)
	attack_origin = global_position
	aim = keeper.global_position if region=="volcano" else attack_origin
	aim.y = world.ground_height(aim.x,aim.z)
	time_left = CHARGE[region]
	intent = Foe.Intent.WINDUP
	hit_obstacle = false
	_can_hit_obstacle = _field_prop==null or attack_origin.distance_to(field_point)>1.65
	var aperture := PI
	if region in ["snow","desert"]: aperture = .21
	elif region=="forest": aperture = .77
	mark.place(aim,heading,STRIKE_REACH[region],aperture,world)
	if region=="lake":
		# A lone ripple beside the ray is a reflection. The true source pulses twice.
		var decoy := aim + heading.cross(Vector3.UP)*4.1
		decoy.y = world.ground_height(decoy.x,decoy.z)
		echo.place(decoy,heading,2.25,PI,world)
	elif region=="forest":
		echo.place(aim,heading.rotated(Vector3.UP,1.65),STRIKE_REACH[region],.63,world)

func _execute(delta: float) -> Vector3:
	var travel := Vector3.ZERO
	var reach: float = STRIKE_REACH[region]
	var offset: Vector3 = (keeper.global_position-aim).slide(Vector3.UP)
	var dist := offset.length()
	var touches := false
	var beat := 1.0-time_left/.70
	if region!="volcano":
		var radius := maxf(.24,reach*beat)
		var origin := aim
		if region=="lake": radius = maxf(.22,fposmod(beat*2.0,1.0)*reach)
		if region in ["snow","desert","forest"]:
			radius = .35+beat*1.14
			origin = global_position
		_skill_fx.global_position = origin+Vector3.UP*.12
		_skill_fx.scale = Vector3(radius,.28,radius)
	match region:
		"snow","desert":
			travel = heading*reach/.70
			touches = (keeper.global_position-global_position).slide(Vector3.UP).length()<1.48
			if global_position.distance_to(field_point)>1.65:
				_can_hit_obstacle = true
			if _can_hit_obstacle and global_position.distance_to(field_point)<1.28:
				hit_obstacle = true
				time_left = 0
		"volcano":
			touches = dist<=reach
			hit_obstacle = global_position.distance_to(aim)<reach
		"tide":
			var rim := lerpf(.65,reach,1.0-time_left/.70)
			touches = absf(dist-rim)<.67
			mark.set_charge(rim/reach)
		"lake":
			var rim := fposmod((.70-time_left)/.35,1.0)*reach
			mark.set_charge(rim/reach)
			touches = absf(dist-rim)<.68
		"forest":
			if is_instance_valid(_field_prop):
				_field_prop.rotation.z = .15*sin(beat*TAU*2.0)*(1.0-beat)
				hit_obstacle = global_position.distance_to(field_point)<1.8
			var dir := heading if time_left>.34 else heading.rotated(Vector3.UP,1.65)
			touches = dist<=reach and dir.dot(offset.normalized())>cos(.73)
			if time_left<=.34: mark.hide()
	if touches and not dealt and absf(keeper.global_position.y-aim.y)<2.8 and keeper.has_clear_view(global_position+Vector3.UP):
		dealt = true
		if keeper.receive_hit(16.0,self):
			hit_obstacle = true
			time_left = 0
	if time_left<=0:
		exposed = true
		intent = Foe.Intent.RECOVER
		time_left = 3.2 if hit_obstacle else (2.1 if region in ["lake","forest","tide"] else 1.45)
		_hide_warning()
		return Vector3.ZERO
	return travel

func _charge_fraction() -> float:
	return clampf(1.0-time_left/float(CHARGE[region]),0.0,1.0) if intent==Foe.Intent.WINDUP else 0.0

func _hide_warning() -> void:
	mark.hide()
	echo.hide()
	_skill_fx.hide()
	if is_instance_valid(_field_prop):
		_field_prop.rotation.z = 0

func arrow_hit(amount: float,attacker: Vector3) -> float:
	if champion and not exposed:
		var side := (attacker-global_position).slide(Vector3.UP).normalized()
		if region in ["tide","volcano","lake"] or (-global_basis.z).dot(side)>.45:
			_show_impact("弹开",Color("acbcc3"))
			return 0.0
	return receive_hit(amount,false,attacker)

func receive_hit(amount: float,heavy := false,_attacker := Vector3.INF) -> float:
	if hp<=0 or is_queued_for_deletion():
		return 0.0
	if champion and not _engaged:
		_engaged = true
		intent = Foe.Intent.CHASE
	if champion:
		amount *= (1.48 if heavy else 1.20) if exposed else .42
	var before := hp
	hp = maxf(0,hp-amount)
	recoil = 1.0
	_show_impact(("破绽  −%d" if exposed else "−%d") % ceili(before-hp),Color("ffe09a") if exposed else Color("f6f4dc"))
	if hp<=0:
		remove_from_group("enemies" if champion else "expedition_prey")
		felled.emit(region,champion)
		queue_free()
	return before-hp

func _show_impact(words: String,tint: Color) -> void:
	_impact_left = .64
	impact_label.position = Vector3(.32,3.22 if champion else 1.60,0)
	impact_label.text = words
	impact_label.modulate = tint
	impact_label.show()
