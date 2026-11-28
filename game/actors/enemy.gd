extends CharacterBody3D

signal fallen(kind: String)

const Art = preload("actor_art.gd")
const Creature = preload("creature_model.gd")
const AttackWarning = preload("attack_warning.gd")
const STRIKE_TIME := .34
enum Intent { ROAM, CHASE, WINDUP, STRIKE, RECOVER, REPELLED, RETURN }

var kind := "hound"
var hero
var world_ref
var home := Vector3.ZERO
var hp := 40.0
var max_hp := 40.0
var hit_radius := 0.48
var speed := 2.8
var damage := 11.0
var reach := 1.65
var windup := 0.70
var intent := Intent.ROAM
var time_left := 0.0
var shell_open := 0.0
var model := Creature.new()
var warning := AttackWarning.new()
var _sight_radius := 10.0
var _light_time := 0.0
var _hit_stun := 0.0
var _strike_dir := Vector3.FORWARD
var _strike_origin := Vector3.ZERO
var _charge_duration := 1.0
var _dealt := false
var _second_attack := false
var _patrol_phase := 0.0
var _configured := false

func setup(species: String, keeper, world, origin: Vector3) -> void:
	kind = species
	hero = keeper
	world_ref = world
	home = origin
	global_position = home
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	collision_layer = 4
	collision_mask = 1
	add_to_group("enemies")
	match kind:
		"crab":
			max_hp = 49
			speed = 1.85
			reach = 1.85
			damage = 14
			hit_radius = 0.64
		"fin":
			max_hp = 36
			speed = 3.3
			reach = 2.4
			windup = 0.75
		"lizard":
			max_hp = 49
			speed = 2.15
			reach = 4.4
			damage = 15
			windup = 1.0
		"elite":
			max_hp = 98
			speed = 2.45
			reach = 2.55
			damage = 17
			windup = 0.91
			hit_radius = 0.65
		"boss":
			max_hp = 168
			speed = 2.5
			reach = 2.77
			damage = 19
			windup = 1.05
			hit_radius = 0.80
			_sight_radius = 28.0
	hp = max_hp
	add_child(model)
	model.build(kind)
	add_child(warning)
	Art.capsule(self,hit_radius,3.1 if kind=="boss" else maxf(1.45,hit_radius*2))
	_patrol_phase = fmod(absf(home.x*0.55+home.z*0.71),TAU)
	_configured = true

func break_shell() -> void:
	if kind=="boss" and hp>0:
		shell_open = 4.2
		time_left = 0.95
		intent = Intent.RECOVER
		_second_attack = false
		warning.hide()

func stagger(duration: float) -> void:
	if hp<=0 or (kind=="boss" and shell_open<=0):
		return
	_second_attack = false
	intent = Intent.RECOVER
	time_left = duration
	warning.hide()

func receive_hit(amount: float, heavy := false, attacker := Vector3.INF) -> float:
	if hp<=0 or is_queued_for_deletion():
		return 0.0
	if kind=="boss" and shell_open<=0:
		_hit_stun = 0.08
		return 0.0
	if kind=="crab" and not heavy and attacker!=Vector3.INF and intent in [Intent.CHASE,Intent.WINDUP]:
		var incoming := (attacker-global_position).slide(Vector3.UP).normalized()
		if incoming.dot(-global_basis.z) > .45:
			amount = ceilf(amount * .42)
	var before := hp
	hp = maxf(0,hp-amount)
	_hit_stun = 0.24
	if hp<=0:
		remove_from_group("enemies")
		fallen.emit(kind)
		queue_free()
	elif heavy:
		stagger(.92)
	elif intent==Intent.ROAM:
		intent = Intent.CHASE
	return before-hp

func _physics_process(delta: float) -> void:
	if not _configured or hp<=0 or not is_instance_valid(hero):
		return
	if not hero.input_enabled or hero.hp<=0:
		velocity = Vector3.ZERO
		return
	_hit_stun = maxf(0,_hit_stun-delta)
	time_left = maxf(0,time_left-delta)
	shell_open = maxf(0,shell_open-delta)
	var offset: Vector3 = hero.global_position-global_position
	var height_gap := absf(offset.y)
	offset.y = 0
	var distance := offset.length()
	var toward := offset.normalized()
	var home_delta := home-global_position
	home_delta.y = 0
	var too_far := kind!="boss" and (home_delta.length()>16 or distance>_sight_radius+5)
	if intent!=Intent.ROAM and intent!=Intent.RETURN and (too_far or height_gap>3.8):
		intent=Intent.RETURN
	_update_light(delta,toward,distance,height_gap)
	var travel := Vector3.ZERO
	match intent:
		Intent.ROAM:
			if distance<_sight_radius and height_gap<3 and hero.has_clear_view(global_position+Vector3.UP):
				intent = Intent.CHASE
			else:
				_patrol_phase += delta*0.39
				var target := home + Vector3(cos(_patrol_phase),0,sin(_patrol_phase))*1.35
				var shift := target-global_position
				shift.y = 0
				if kind!="boss" and shift.length()>0.28:
					travel = shift.normalized()*0.64
		Intent.RETURN:
			if home_delta.length()<0.7:
				intent = Intent.ROAM
			else:
				travel = home_delta.normalized()*speed
		Intent.CHASE:
			_face(toward,delta)
			if distance<=reach and _has_attack_slot() and hero.has_clear_view(global_position+Vector3.UP):
				_begin_windup(toward)
			elif distance < reach+.7 and not _has_attack_slot():
				# Waiting attackers circle instead of standing inside the lead attacker.
				travel = toward.cross(Vector3.UP) * speed * (.65 if _patrol_phase < PI else -.65)
			else:
				travel = toward*speed
		Intent.WINDUP:
			if time_left<=0:
				intent=Intent.STRIKE
				time_left=STRIKE_TIME
				_dealt=false
		Intent.STRIKE:
			travel = _strike_dir * _lunge_speed()
			var in_arc: Vector3 = (hero.global_position-_strike_origin).slide(Vector3.UP)
			var advanced := maxf(0,(global_position-_strike_origin).dot(_strike_dir))
			if not _dealt and in_arc.length()<=reach+.5+advanced and height_gap<2.4 and _strike_dir.dot(in_arc.normalized())>=_attack_cone() and hero.has_clear_view(global_position+Vector3.UP):
				_dealt = true
				if hero.receive_hit(damage,self):
					stagger(.84)
					travel = Vector3.ZERO
			if intent==Intent.STRIKE and time_left<=0:
				intent=Intent.RECOVER
				time_left=0.41 if _second_attack else 1.15
		Intent.RECOVER:
			if kind=="lizard" and distance<reach*.6 and time_left>.48:
				travel = -toward * speed * .7
			if time_left<=0:
				if _second_attack and distance<=reach+1:
					_second_attack=false
					_begin_windup(toward,true)
				else:
					_second_attack=false
					intent=Intent.CHASE
		Intent.REPELLED:
			travel = -toward*2.4
			if time_left<=0:
				intent=Intent.CHASE
	if travel.length_squared()>0.01 and intent not in [Intent.STRIKE,Intent.REPELLED,Intent.RECOVER]:
		_face(travel.normalized(),delta)
	_move(travel,delta)
	var anticipation := (1.0-time_left/_charge_duration) if intent==Intent.WINDUP else 0.0
	var strike_pose := time_left/STRIKE_TIME if intent==Intent.STRIKE else 0.0
	warning.visible = intent==Intent.WINDUP or intent==Intent.STRIKE
	if warning.visible:
		warning.set_charge(anticipation if intent==Intent.WINDUP else 1.0)
	model.pose(delta,velocity.length(),clampf(anticipation,0.035,1.0) if intent==Intent.WINDUP else 0.0,strike_pose,_hit_stun/0.24,shell_open>0)

func _update_light(delta: float, toward: Vector3, distance: float, height_gap: float) -> void:
	if kind not in ["hound","fin","elite","boss"] or hero.lamp_mode!=2 or distance>6+hit_radius or height_gap>2.6:
		_light_time=0
		return
	if hero.get_forward().dot(-toward)<cos(deg_to_rad(35)) or not hero.has_clear_view(global_position+Vector3.UP):
		_light_time=0
		return
	if intent==Intent.REPELLED or (kind=="boss" and shell_open>0):
		return
	_light_time += delta
	if _light_time>=1.0:
		_light_time=0
		if kind=="boss":
			break_shell()
		else:
			intent = Intent.REPELLED
			time_left=1.5
			_second_attack=false

func _attack_cone() -> float:
	if kind=="lizard":
		return 0.89
	return -0.05 if kind in ["boss","crab"] else 0.32

func _lunge_speed() -> float:
	if kind in ["hound","fin","elite"]:
		return 4.3
	return 5.3 if kind=="boss" and hp<=max_hp*.5 else 0.0

func _has_attack_slot() -> bool:
	var count := 0
	for peer in get_tree().get_nodes_in_group("enemies"):
		if peer!=self and peer.intent in [Intent.WINDUP,Intent.STRIKE] and global_position.distance_squared_to(peer.global_position)<81.0:
			count+=1
	return count<2

func _begin_windup(toward: Vector3, followup := false) -> void:
	intent = Intent.WINDUP
	_strike_dir = toward if toward.length_squared()>0.001 else -global_basis.z
	rotation.y = atan2(-_strike_dir.x,-_strike_dir.z)
	_strike_origin = global_position
	_charge_duration = windup*(0.67 if followup else 1.0)
	time_left = _charge_duration
	warning.place(_strike_origin,_strike_dir,reach+.5+_lunge_speed()*STRIKE_TIME,acos(_attack_cone()),world_ref)
	if not followup:
		_second_attack=kind=="elite" or (kind=="boss" and hp<max_hp*0.5)

func _face(direction: Vector3, delta: float) -> void:
	if direction.length_squared()>0.001:
		rotation.y = lerp_angle(rotation.y,atan2(-direction.x,-direction.z),1-exp(-delta*10))

func _move(travel: Vector3, delta: float) -> void:
	var before := global_position
	var target := before+travel*delta
	velocity = travel
	if world_ref!=null and not world_ref.is_walkable(target.x,target.z):
		velocity = Vector3.ZERO
	move_and_slide()
	if world_ref!=null:
		if not world_ref.is_walkable(global_position.x,global_position.z):
			global_position = before
		global_position.y = world_ref.ground_height(global_position.x,global_position.z)
