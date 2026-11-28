extends CharacterBody3D

signal died
signal struck
signal combat_cue(cue: String)
signal technique_landed(target: Node3D)

const Art = preload("actor_art.gd")
const KeeperModel = preload("keeper_model.gd")
const SWING_TIMES := [0.42,0.46,0.64]
const SWING_DAMAGE := [15.0,19.0,29.0]
const CUT_NAMES := ["横切","回锋","破势"]
const DODGE_TIME := 0.31
const CAMERA_LENGTH := 5.25
const BowArrow = preload("bow_arrow.gd")
const QUIVER := 12
const NET_STROKE := .61
var _net := preload("res://art/greybay/field_net.glb").instantiate() as Node3D
var _net_left := 0.0
var _net_yaw := 0.0
var _net_caught := false
var arrows := QUIVER
var bow_selected := false
var bow_draw := 0.0
var drawing := false
var _bow_switch := -1
var _bow_recovery := 0.0
var _bow_release := false
var _bow := Node3D.new()
var _shots := Node3D.new()
var sprint_scale := 1.0
var bow_sway := 0.0

var world_ref
var input_enabled := true
var peaceful := false
var hp := 100.0
var oil := 40.0
var lamp_mode := 1
var weapon_upgrade := false
var armor_upgrade := false
var camera_yaw := -0.7
var camera_pitch := deg_to_rad(16.0)
var camera := Camera3D.new()
var model := KeeperModel.new()
var _camera_distance := CAMERA_LENGTH
var _lens_shape := SphereShape3D.new()
var _dodge_dir := Vector3.FORWARD
var _dodge_left := 0.0
var _dodge_recovery := 0.0
var _attack_left := 0.0
var _attack_buffer := 0.0
var _dodge_buffer := 0.0
var _swing_connected := false
var _hurt_left := 0.0
var _swing_time := .42
var _combo_step := 0
var _combo_left := 0.0
var _counter_left := 0.0
var _counter_swing := false
var _counter_target: WeakRef
var _counter_facing := Vector3.FORWARD
var _evaded := false
var combat_text := ""
var _text_left := 0.0

func reset_combat() -> void:
	cancel_draw()
	_net_left = 0.0
	_net.hide()
	_bow_switch = -1
	_bow_recovery = 0
	for shot in _shots.get_children():
		shot.queue_free()
	_attack_left = 0.0
	_attack_buffer = 0.0
	_dodge_left = 0.0
	_dodge_buffer = 0.0
	_dodge_recovery = 0.0
	_hurt_left = 0.0
	_combo_left = 0.0
	_counter_left = 0.0
	_counter_target = null
	_text_left = 0.0
	combat_text = ""

func _ready() -> void:
	add_to_group("player")
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	collision_layer = 2
	collision_mask = 1
	Art.capsule(self, 0.32, 1.78)
	model.name = "Keeper"
	add_child(model)
	_build_bow()
	model.sword_arm.add_child(_net)
	_net.position = Vector3(.035,-.46,-.08)
	_net.scale = Vector3.ONE*1.16
	_net.hide()
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		mesh.set_layer_mask_value(2, true)
		mesh.set_layer_mask_value(1, false)
	model.rotation.y = camera_yaw
	camera.name = "FollowCamera"
	camera.fov = 64.0
	camera.near = 0.07
	camera.far = 480.0
	add_child(camera)
	camera.current = true
	_lens_shape.radius = 0.21
	_place_camera(CAMERA_LENGTH)

func get_forward() -> Vector3:
	return Vector3.FORWARD.rotated(Vector3.UP, camera_yaw)

func _build_bow() -> void:
	model.sword_arm.add_child(_bow)
	_bow.position = Vector3(0,-.42,-.10)
	for side: float in [-1.0,1.0]:
		Art.rod(_bow,Vector3.ZERO,Vector3(.035,side*.32,-.12),.05,.035,"a47c4a")
		Art.rod(_bow,Vector3(.035,side*.32,-.12),Vector3(.04,side*.56,.11),.037,.018,"b7a36f")
		Art.rod(_bow,Vector3(.04,side*.56,.11),Vector3(.04,0,.15),.011,.009,"ddd8b9")
	_bow.hide()
	add_child(_shots)
	_shots.top_level = true

func cancel_draw() -> void:
	drawing = false
	bow_draw = 0.0
	_bow_release = false

func bow_feedback(message: String) -> void:
	combat_text = message
	_text_left = 1.0

func _shoot() -> void:
	var center := get_viewport().get_visible_rect().size*.5
	var focal := center.y / tan(deg_to_rad(camera.fov)*.5)
	var spread := (1.0-bow_draw)*14.0 + tan(maxf(0.0,bow_sway))*focal
	center += Vector2(randf_range(-spread,spread),randf_range(-spread,spread))
	var eye := camera.project_ray_origin(center)
	var far := eye+camera.project_ray_normal(center)*39.0
	var query := PhysicsRayQueryParameters3D.create(eye,far,5,[get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var aim: Vector3 = hit.get("position",far)
	var origin := global_position + Vector3.UP*1.32 + get_forward()*.43
	var shot := BowArrow.new()
	_shots.add_child(shot)
	shot.launch(self,origin,origin.direction_to(aim),bow_draw)
	combat_cue.emit("bow_loose")
	arrows -= 1
	_bow_recovery = .43
	cancel_draw()

func set_daylight(daylight: float) -> void:
	model.light.light_energy = lerpf(1.8, 0.42, daylight)
	model.beam.light_energy = lerpf(4.2, 1.4, daylight)

func turn_by_mouse(pixels: Vector2) -> void:
	camera_yaw = wrapf(camera_yaw - pixels.x*.0024,-PI,PI)
	# A raised bow can reach an exposed target uphill from the keeper.
	camera_pitch = clampf(camera_pitch + pixels.y*.0022,-.53 if bow_selected else -.09,.88)

func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled or hp <= 0:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		turn_by_mouse(event.screen_relative)
	elif peaceful or _net_left > 0.0:
		return
	elif event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:
			cancel_draw()
		elif event.button_index==MOUSE_BUTTON_LEFT:
			if bow_selected:
				if event.pressed and arrows<=0:
					bow_feedback("箭袋已空  ·  1 切回近战")
				elif event.pressed and _bow_recovery<=0 and _dodge_left<=0 and lamp_mode!=2:
					drawing = true
				elif not event.pressed and drawing:
					_bow_release = true
			elif event.pressed:
				_attack_buffer = .36 if _counter_left>0 else .21
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_F and oil>0:
			lamp_mode = 1 if lamp_mode==0 else 0
		elif event.physical_keycode==KEY_SPACE:
			_dodge_buffer = 0.15
			cancel_draw()
		elif event.physical_keycode in [KEY_1,KEY_2]:
			_bow_switch = 1 if event.physical_keycode==KEY_2 else 0
			cancel_draw()

func _physics_process(delta: float) -> void:
	if not input_enabled or hp<=0:
		cancel_draw()
		velocity = Vector3.ZERO
		_attack_buffer = 0
		_dodge_buffer = 0
		if lamp_mode==2:
			lamp_mode = 1
		model.animate(delta,0,lamp_mode,0,0,0,weapon_upgrade,armor_upgrade)
		_show_equipped_weapon()
		_update_camera(delta)
		return
	_hurt_left = maxf(0,_hurt_left-delta)
	_net_left = maxf(0,_net_left-delta)
	_dodge_recovery = maxf(0,_dodge_recovery-delta)
	_dodge_left = maxf(0,_dodge_left-delta)
	_attack_left = maxf(0,_attack_left-delta)
	_bow_recovery = maxf(0,_bow_recovery-delta)
	if _bow_switch>=0 and _attack_left<=0 and _dodge_left<=0:
		bow_selected = _bow_switch==1
		_bow_switch = -1
		_attack_buffer = 0
	if drawing:
		bow_draw = minf(1.0,bow_draw+delta/.7)
		if _bow_release:
			_shoot()
	_combo_left = maxf(0,_combo_left-delta)
	_counter_left = maxf(0,_counter_left-delta)
	_text_left = maxf(0,_text_left-delta)
	if _text_left<=0:
		combat_text = ""
	_attack_buffer = maxf(0,_attack_buffer-delta)
	_dodge_buffer = maxf(0,_dodge_buffer-delta)
	var forward := get_forward()
	var right := forward.cross(Vector3.UP)
	var stick := Vector2(
		int(Input.is_physical_key_pressed(KEY_D))-int(Input.is_physical_key_pressed(KEY_A)),
		int(Input.is_physical_key_pressed(KEY_W))-int(Input.is_physical_key_pressed(KEY_S))).limit_length()
	var move_dir := right*stick.x + forward*stick.y
	if _dodge_buffer>0 and _dodge_recovery<=0:
		_dodge_buffer = 0
		_dodge_dir = move_dir if stick.length_squared()>0.01 else forward
		_dodge_left = DODGE_TIME
		_dodge_recovery = 0.82 + (0.2 if armor_upgrade else 0.0)
		_attack_left = 0
		_attack_buffer = 0
		_evaded = false
		_combo_left = 0
	if not peaceful and oil>0 and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and _dodge_left<=0 and _attack_left<=0:
		lamp_mode = 2
	elif lamp_mode==2:
		lamp_mode = 1
	if _attack_buffer>0 and _attack_left<=0 and _dodge_left<=0 and lamp_mode!=2:
		_attack_buffer = 0
		_counter_swing = _counter_left>0
		if _counter_swing:
			_counter_facing = forward
			var target = _counter_target.get_ref() if _counter_target!=null else null
			if is_instance_valid(target) and not target.is_queued_for_deletion():
				var bearing: Vector3 = (target.global_position-global_position).slide(Vector3.UP)
				if bearing.length_squared()>.001 and bearing.length_squared()<36:
					_counter_facing = bearing.normalized()
		_counter_left = 0
		_combo_step = (_combo_step+1)%3 if _combo_left>0 and not _counter_swing else 0
		_combo_left = 0
		_swing_time = .47 if _counter_swing else float(SWING_TIMES[_combo_step])
		_attack_left = _swing_time
		_swing_connected = false
		combat_cue.emit("blade")
	if _attack_left>0 and _attack_left<=_swing_time*0.62 and not _swing_connected:
		_swing_connected = true
		_strike()
	var speed := 6.8*sprint_scale if Input.is_physical_key_pressed(KEY_SHIFT) else 4.6
	if lamp_mode==2 or _attack_left>0 or drawing:
		speed = 2.35
	var target_velocity := move_dir*speed
	velocity = velocity.move_toward(target_velocity,delta*34.0)
	if _dodge_left>0:
		velocity = _dodge_dir*9.6
	elif _attack_left>_swing_time*.58 and _attack_left<_swing_time*.81 and (_counter_swing or _combo_step==2):
		velocity = _counter_facing*5.2 if _counter_swing else forward*3.3
	_move_on_ground(delta)
	var attack_yaw := atan2(-_counter_facing.x,-_counter_facing.z) if _counter_swing and _attack_left>0 else camera_yaw
	if _net_left > 0.0: attack_yaw = _net_yaw
	model.rotation.y = lerp_angle(model.rotation.y,attack_yaw,1-exp(-delta*21.0))
	if lamp_mode!=0 and not peaceful:
		oil = maxf(0,oil-delta*(1.0 if lamp_mode==2 else 4.0/60.0))
		if oil<=0:
			lamp_mode = 0
	model.animate(delta,velocity.length(),lamp_mode,_attack_left/_swing_time,_dodge_left/DODGE_TIME,_hurt_left/0.58,weapon_upgrade,armor_upgrade,_combo_step,_counter_swing)
	_show_equipped_weapon()
	if _bow.visible:
		model.sword_arm.rotation = Vector3(.52+bow_draw*.36,-.57,.36)
	elif _net.visible:
		var progress := 1.0 - _net_left/NET_STROKE
		var dip := smoothstep(.10,.43,progress)
		var lift := smoothstep(.48,.93,progress)
		model.sword_arm.rotation = Vector3(.30-.94*dip+1.26*lift,-1.16+1.32*dip-.54*lift,.35-.18*lift)
		model.body.rotation.x += .23*(dip-lift)
		_net.rotation.z = -.27+.49*lift if _net_caught else -.27+.81*lift
	_update_camera(delta)

func swing_net(caught: bool, target: Vector3) -> void:
	cancel_draw()
	_attack_buffer = 0.0
	_dodge_buffer = 0.0
	_attack_left = 0.0
	_net_left = NET_STROKE
	_net_caught = caught
	var offset := target-global_position
	_net_yaw = atan2(-offset.x,-offset.z)
	_show_equipped_weapon()

func get_net_mouth() -> Vector3:
	return _net.to_global(Vector3(0,0,-.66))

func _show_equipped_weapon() -> void:
	_net.visible = _net_left > 0.0 and not peaceful
	_bow.visible = bow_selected and not peaceful and not _net.visible
	model.blade.get_parent().visible = not bow_selected and not peaceful and not _net.visible

func _move_on_ground(delta: float) -> void:
	if world_ref==null:
		move_and_slide()
		return
	var before := global_position
	var next := before + velocity*delta
	if not world_ref.is_walkable(next.x,next.z):
		if world_ref.is_walkable(next.x,before.z):
			velocity.z = 0
		elif world_ref.is_walkable(before.x,next.z):
			velocity.x = 0
		else:
			velocity = Vector3.ZERO
	move_and_slide()
	if not world_ref.is_walkable(global_position.x,global_position.z):
		global_position = before
	else:
		global_position.y = world_ref.ground_height(global_position.x,global_position.z)

func _strike() -> void:
	var heavy := _counter_swing or _combo_step==2
	var base_damage := 35.0 if _counter_swing else float(SWING_DAMAGE[_combo_step])
	var landed := 0.0
	var guarded := false
	var found_opening := false
	var targets := get_tree().get_nodes_in_group("enemies")+get_tree().get_nodes_in_group("expedition_prey")
	for enemy in targets:
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or absf(enemy.global_position.y-global_position.y)>2.3:
			continue
		var offset: Vector3 = enemy.global_position-global_position
		offset.y = 0
		var reach := (2.45 if weapon_upgrade else 1.7) + float(enemy.hit_radius) + (.35 if heavy else 0.0)
		var attack_dir := _counter_facing if _counter_swing else get_forward()
		if offset.length_squared() > reach*reach or attack_dir.dot(offset.normalized()) < (0.47 if weapon_upgrade else 0.12):
			continue
		if has_clear_view(enemy.global_position + Vector3.UP):
			var opening: bool = enemy.exposed if enemy.has_method("arrow_hit") else (enemy.kind=="boss" and enemy.shell_open>0)
			var dealt: float = enemy.receive_hit(base_damage*(1.32 if weapon_upgrade else 1.0),heavy,global_position)
			found_opening = found_opening or (opening and dealt>0)
			if heavy and dealt>0:
				technique_landed.emit(enemy)
			landed += dealt
			guarded = guarded or dealt<=0
	if landed > 0:
		_combo_left = .82 if not heavy else 0.0
		var technique := "回身反击" if _counter_swing else str(CUT_NAMES[_combo_step])
		combat_text = "%s  −%d" % [technique,ceili(landed)]
		if _combo_left>0:
			combat_text += "    左键接招"
		_text_left = .82
		combat_cue.emit("strong_hit" if heavy or found_opening else "hit")
	elif guarded:
		combat_text = "攻击被挡下了  ·  侧闪，等对方露出破绽"
		_text_left = 1.65
		combat_cue.emit("shell")

func has_clear_view(point: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*1.2, point, 1, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func receive_hit(amount: float, attacker: Node3D = null) -> bool:
	if not input_enabled or hp<=0:
		return false
	if _dodge_left>0:
		if not _evaded and _dodge_left>=DODGE_TIME-.15:
			_evaded = true
			_counter_left = 1.0
			_counter_target = weakref(attacker) if attacker!=null else null
			_text_left = _counter_left
			combat_text = "险避成功    左键回身反击"
			combat_cue.emit("chime")
			return true
		return false
	if _hurt_left>0:
		return false
	hp = maxf(0,hp-amount*(0.75 if armor_upgrade else 1.0))
	cancel_draw()
	_combo_left = 0
	_counter_left = 0
	_attack_left = 0
	_hurt_left = 0.58
	struck.emit()
	if hp<=0:
		_attack_left = 0
		died.emit()
	return false

func _orbit_offset() -> Vector3:
	return -get_forward()*cos(camera_pitch) + Vector3.UP*sin(camera_pitch)

func _place_camera(distance: float) -> void:
	var focus := global_position+Vector3.UP*1.52
	camera.global_position = focus+_orbit_offset()*distance
	camera.look_at(focus+get_forward()*1.15,Vector3.UP)

func _update_camera(delta: float) -> void:
	var focus := global_position+Vector3.UP*1.52
	var orbit := _orbit_offset()
	var sweep := PhysicsShapeQueryParameters3D.new()
	sweep.shape = _lens_shape
	sweep.collision_mask = 1
	sweep.exclude = [get_rid()]
	sweep.transform.origin = focus
	sweep.motion = orbit*CAMERA_LENGTH
	var fractions := get_world_3d().direct_space_state.cast_motion(sweep)
	var allowed := CAMERA_LENGTH
	if not fractions.is_empty() and fractions[0]<1.0:
		allowed = maxf(0.22,CAMERA_LENGTH*fractions[0]-0.08)
	if world_ref!=null:
		for step in range(1,9):
			var sample_dist := allowed*step/8.0
			var point := focus+orbit*sample_dist
			if point.y<float(world_ref.ground_height(point.x,point.z))+0.26:
				allowed = maxf(0.22,allowed*(step-1)/8.0)
				break
	_camera_distance = minf(allowed,lerpf(_camera_distance,allowed,1-exp(-delta*6.0)))
	_place_camera(_camera_distance)
	# Hide the keeper's mesh when an uphill shot would otherwise pass visually through the hat.
	# The lantern light, collision sweep and arrow origin stay attached to the keeper.
	var show_keeper := _camera_distance>.95
	if show_keeper and bow_selected and (drawing or _bow_recovery>0):
		var ray := -camera.global_basis.z
		var planar_ray := Vector2(ray.x,ray.z)
		var to_keeper := global_position-camera.global_position
		var along := Vector2(to_keeper.x,to_keeper.z).dot(planar_ray)/maxf(.001,planar_ray.length_squared())
		var at_keeper := camera.global_position+ray*along-global_position
		show_keeper = along<0.0 or Vector2(at_keeper.x,at_keeper.z).length()>.43 or at_keeper.y>2.12 or at_keeper.y<0
	camera.set_cull_mask_value(2,show_keeper)
