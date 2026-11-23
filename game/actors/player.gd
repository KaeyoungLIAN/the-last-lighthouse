extends CharacterBody3D

signal died
signal struck

const Art = preload("actor_art.gd")
const KeeperModel = preload("keeper_model.gd")
const ATTACK_TIME := 0.49
const DODGE_TIME := 0.31
const CAMERA_LENGTH := 5.25

var world_ref
var input_enabled := true
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

func _ready() -> void:
	add_to_group("player")
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	collision_layer = 2
	collision_mask = 1
	Art.capsule(self, 0.32, 1.78)
	model.name = "Keeper"
	add_child(model)
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

func set_daylight(daylight: float) -> void:
	model.light.light_energy = lerpf(1.8, 0.42, daylight)
	model.beam.light_energy = lerpf(4.2, 1.4, daylight)

func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled or hp <= 0:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_yaw = wrapf(camera_yaw - event.screen_relative.x*0.0024, -PI, PI)
		camera_pitch = clampf(camera_pitch + event.screen_relative.y*0.0022, -0.09, 0.88)
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		_attack_buffer = 0.2
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_F and oil>0:
			lamp_mode = 1 if lamp_mode==0 else 0
		elif event.physical_keycode==KEY_SPACE:
			_dodge_buffer = 0.15

func _physics_process(delta: float) -> void:
	if not input_enabled or hp<=0:
		velocity = Vector3.ZERO
		_attack_buffer = 0
		_dodge_buffer = 0
		if lamp_mode==2:
			lamp_mode = 1
		model.animate(delta,0,lamp_mode,0,0,0,weapon_upgrade,armor_upgrade)
		_update_camera(delta)
		return
	_hurt_left = maxf(0,_hurt_left-delta)
	_dodge_recovery = maxf(0,_dodge_recovery-delta)
	_dodge_left = maxf(0,_dodge_left-delta)
	_attack_left = maxf(0,_attack_left-delta)
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
	if oil>0 and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and _dodge_left<=0 and _attack_left<=0:
		lamp_mode = 2
	elif lamp_mode==2:
		lamp_mode = 1
	if _attack_buffer>0 and _attack_left<=0 and _dodge_left<=0 and lamp_mode!=2:
		_attack_buffer = 0
		_attack_left = ATTACK_TIME
		_swing_connected = false
	if _attack_left>0 and _attack_left<=ATTACK_TIME*0.63 and not _swing_connected:
		_swing_connected = true
		_strike()
	var speed := 6.8 if Input.is_physical_key_pressed(KEY_SHIFT) else 4.6
	if lamp_mode==2 or _attack_left>0:
		speed = 2.35
	var target_velocity := move_dir*speed
	velocity = velocity.move_toward(target_velocity,delta*34.0)
	if _dodge_left>0:
		velocity = _dodge_dir*9.6
	_move_on_ground(delta)
	model.rotation.y = lerp_angle(model.rotation.y, camera_yaw, 1-exp(-delta*21.0))
	if lamp_mode!=0:
		oil = maxf(0,oil-delta*(1.0 if lamp_mode==2 else 4.0/60.0))
		if oil<=0:
			lamp_mode = 0
	model.animate(delta,velocity.length(),lamp_mode,_attack_left/ATTACK_TIME,_dodge_left/DODGE_TIME,_hurt_left/0.58,weapon_upgrade,armor_upgrade)
	_update_camera(delta)

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
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or absf(enemy.global_position.y-global_position.y)>2.3:
			continue
		var offset: Vector3 = enemy.global_position-global_position
		offset.y = 0
		var reach := (2.45 if weapon_upgrade else 1.7) + float(enemy.hit_radius)
		if offset.length_squared() > reach*reach or get_forward().dot(offset.normalized()) < (0.47 if weapon_upgrade else 0.12):
			continue
		if has_clear_view(enemy.global_position + Vector3.UP):
			enemy.receive_hit(24.0 if weapon_upgrade else 18.0)

func has_clear_view(point: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*1.2, point, 1, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func receive_hit(amount: float) -> void:
	if not input_enabled or hp<=0 or _dodge_left>0 or _hurt_left>0:
		return
	hp = maxf(0,hp-amount*(0.75 if armor_upgrade else 1.0))
	_hurt_left = 0.58
	struck.emit()
	if hp<=0:
		_attack_left = 0
		died.emit()

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
	# Keep the lantern illuminating tight passages even when the near camera hides the coat.
	camera.set_cull_mask_value(2, _camera_distance > 0.95)
	_place_camera(_camera_distance)
