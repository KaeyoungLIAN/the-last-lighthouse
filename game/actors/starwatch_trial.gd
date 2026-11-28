extends Node3D
## The keeper feeds light back into an astronomical lens by landing a finisher or riposte.
const Art = preload("actor_art.gd")
const Foe = preload("enemy.gd")
const SITE := "starwatch_trial"
const RADIUS := 15.0

signal message(text: String, cue: String)
signal completed

var active := false
var wave := 0
var seconds := 0.0
var charged := false
var fighter
var hero
var world
var nearest_dry: Callable
var lens: MeshInstance3D
var hoops: Node3D

func install(keeper, island, dry_land: Callable, where: Vector3) -> void:
	hero = keeper
	world = island
	nearest_dry = dry_land
	position = where
	hero.technique_landed.connect(_on_technique)
	Art.taper(self,Vector3.UP*.17,.66,.58,.38,"767b72",10)
	Art.taper(self,Vector3.UP*.64,.25,.19,.65,"475e5b",8)
	Art.taper(self,Vector3.UP*.97,.36,.39,.12,"b49763",10)
	hoops = Node3D.new()
	add_child(hoops)
	hoops.position.y = 1.49
	for tilt in [-.54,.54]:
		var hoop := TorusMesh.new()
		hoop.inner_radius = .52
		hoop.outer_radius = .55
		hoop.rings = 30
		hoop.ring_segments = 5
		var rim := Art.part(hoops,hoop,Vector3.ZERO,"b79a61")
		rim.rotation = Vector3(PI*.5,tilt,0)
	lens = Art.oval(hoops,Vector3.ZERO,Vector3(.61,.61,.61),"527979")
	for side: float in [-1.0,1.0]:
		Art.rod(self,Vector3(side*.24,.98,0),Vector3(side*.52,1.52,0),.054,.041,"607970")

func reset(cleared: bool) -> void:
	active = false
	charged = false
	wave = 0
	seconds = 0
	if is_instance_valid(fighter):
		fighter.set_physics_process(false)
		if fighter.is_in_group("enemies"):
			fighter.remove_from_group("enemies")
		fighter.queue_free()
	fighter = null
	if is_instance_valid(lens):
		lens.material_override = Art.surface("ace8d5",true) if cleared else Art.surface("527979")

func start() -> void:
	if active:
		return
	active = true
	wave = 1
	seconds = 55
	charged = false
	lens.material_override = Art.surface("e1ad5f",true)
	_send_echo()
	message.emit("有两拨怪物。连打三刀，或者躲开攻击后马上还手，就能让镜片亮起来。","switch")

func _send_echo() -> void:
	var offset := Vector2(-4,4) if wave==1 else Vector2(3,-5)
	var at: Vector2 = nearest_dry.call(Vector2(position.x,position.z)+offset)
	fighter = Foe.new()
	add_child(fighter)
	fighter.setup("hound" if wave==1 else "elite",hero,world,Vector3(at.x,world.ground_height(at.x,at.y)+.08,at.y))
	fighter.intent = Foe.Intent.CHASE

func _on_technique(target: Node3D) -> void:
	if active and target==fighter and not charged:
		charged = true
		lens.material_override = Art.surface("9ce2cd",true)
		message.emit("镜片已蓄光。守住灯盘，击退余下灯影。","chime")

func tick(delta: float) -> void:
	if not active:
		return
	seconds -= delta
	hoops.rotate_y(delta*(1.1 if charged else .55))
	if hero.hp<=0 or hero.global_position.distance_squared_to(global_position)>RADIUS*RADIUS or seconds<=0:
		reset(false)
		message.emit("守灯中断。回到星尺台守灯盘，可重新点火。","switch")
		return
	if is_instance_valid(fighter) and not fighter.is_queued_for_deletion():
		return
	if wave==2 and charged:
		reset(true)
		completed.emit()
	elif wave==1:
		wave = 2
		seconds += 12
		_send_echo()
		message.emit("第二轮 · 守镜影卫。留意它收势后的第二击。","discover")
	else:
		_send_echo()
		message.emit("镜片还没亮。试着连打三刀，或躲开攻击后马上点左键。","switch")

func objective() -> String:
	return "守灯挑战 %d/2  ·  %d 秒\n%s" % [wave,ceili(seconds),"镜片亮了，打退剩下的怪物" if charged else "连打三刀，或躲开攻击后还手"]
