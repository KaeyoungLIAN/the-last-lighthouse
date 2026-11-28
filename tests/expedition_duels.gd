extends SceneTree
## Play through whole fights on island terrain. Only the initial player spawn is placed.
## The headless display has no captured cursor, so feed mouse deltas to the same look handler.
const World = preload("res://world/world.gd")
const Keeper = preload("res://actors/player.gd")
const Wilds = preload("res://expedition_encounters.gd")
const Geo = preload("res://world/expedition_geography.gd")
const FPS := 60

var world := World.new()
var hero
var wilds
var held := {}
var hits := 0
var cues := {}
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func button(code: Key,down: bool) -> void:
	if bool(held.get(code,false))==down: return
	held[code] = down
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func mouse(down: bool) -> void:
	if bool(held.get("left",false))==down: return
	held["left"] = down
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = down
	Input.parse_input_event(click)
	Input.flush_buffered_events()

func aim_at(target: Vector3) -> void:
	var offset: Vector3 = target - (hero.global_position+Vector3.UP*1.52)
	var distance := Vector2(offset.x,offset.z).length()
	var yaw := atan2(-offset.x,-offset.z)
	var elevation := atan2(-offset.y,maxf(0.25,distance-1.15))
	var boom: float = hero.camera.global_position.distance_to(hero.global_position+Vector3.UP*1.52)
	var pitch := elevation+asin(clampf(1.15/maxf(.25,boom)*sin(elevation),-.99,.99))
	var pixels := Vector2(-angle_difference(hero.camera_yaw,yaw)/.0024,(pitch-hero.camera_pitch)/.0022)
	hero.turn_by_mouse(pixels.limit_length(39.0))

func walk_direction(direction: Vector3) -> void:
	var forward: Vector3 = hero.get_forward()
	var across := direction.dot(forward.cross(Vector3.UP))
	var ahead := direction.dot(forward)
	button(KEY_D,across>.37)
	button(KEY_A,across<-.37)
	button(KEY_W,ahead>.37)
	button(KEY_S,ahead<-.37)

func duel(zone: String,bow: bool) -> void:
	held.clear()
	cues.clear()
	hits = 0
	hero = Keeper.new()
	hero.world_ref = world
	root.add_child(hero)
	wilds = Wilds.new()
	root.add_child(wilds)
	wilds.build(hero,world,Geo.CAMPS)
	hero.struck.connect(func(): hits+=1)
	hero.combat_cue.connect(func(cue): cues[cue]=int(cues.get(cue,0))+1)
	# The ram and the keeper start on opposite sides of the arena's rock pillar.
	var spawn: Vector2 = Geo.ARENAS[zone]+(Vector2(6.65,3.75) if bow else Vector2(0,6.5))
	hero.global_position = Vector3(spawn.x,world.ground_height(spawn.x,spawn.y),spawn.y)
	wilds.restore([],{},0)
	wilds.tick(0,true)
	var beast = wilds.bosses[zone]
	button(KEY_2 if bow else KEY_1,true)
	var frames := 0
	var charges := 0
	var was_charging := false
	var saw_opening := false
	var dodged := false
	var bow_ranges := PackedFloat32Array()
	var escape := Vector3.ZERO
	while is_instance_valid(beast) and not beast.is_queued_for_deletion() and hero.hp>0 and frames<90*FPS:
		await physics_frame
		frames += 1
		if not is_instance_valid(beast) or beast.is_queued_for_deletion(): break
		var distance: float = (beast.global_position-hero.global_position).slide(Vector3.UP).length()
		aim_at(beast.global_position+Vector3.UP*.84)
		var charging: bool = beast.intent==beast.Foe.Intent.WINDUP
		var striking: bool = beast.intent==beast.Foe.Intent.STRIKE
		if charging and not was_charging:
			charges += 1
			dodged = false
			escape = beast.heading.cross(Vector3.UP)
			if escape.dot(hero.global_position-beast.home)>0:
				escape = -escape
		was_charging = charging
		saw_opening = saw_opening or beast.exposed
		button(KEY_SPACE,false)
		if bow:
			# Cross the locked charge on foot, choosing the side with more room in the arena.
			# Stop to aim once the ram is recovering. Drawing early would slow this sidestep.
			walk_direction(escape if charging or striking else Vector3.ZERO)
			button(KEY_SHIFT,charging or striking)
			if hero.bow_selected and hero.arrows>0:
				if not hero.drawing and not held.get("left",false) and hero._bow_recovery<=0 and beast.exposed and distance>=7.4:
					mouse(true)
				elif hero.drawing and hero.bow_draw>.98 and beast.exposed and distance>=7.4:
					bow_ranges.append(snappedf(distance,.1))
					mouse(false)
				elif hero.drawing and not beast.exposed:
					button(KEY_SPACE,true)
					mouse(false)
				elif not hero.drawing and held.get("left",false):
					mouse(false)
		else:
			button(KEY_W,distance>1.55)
			# Let the first wave land. On its repeat, dodge as the actual ring reaches the boots.
			var rim := lerpf(.65,beast.STRIKE_REACH.tide,1.0-beast.time_left/.70)
			if striking and charges>1 and distance-rim<1.05 and not dodged:
				button(KEY_D,true)
				button(KEY_SPACE,true)
				dodged = true
			else:
				button(KEY_D,false)
			if beast.exposed and distance<2.30 and frames%7==0:
				mouse(true)
			else:
				mouse(false)
	var won: bool = not is_instance_valid(beast) or beast.is_queued_for_deletion()
	print("DUEL %s %s  %.2fs  hp %.0f/100  hits %d  arrows %d/12  attacks %d  cues %s" %
		[zone,"bow" if bow else "melee",float(frames)/FPS,hero.hp,hits,12-hero.arrows,charges,cues])
	if bow: print("Release distances (m): ",bow_ranges)
	if not won or not saw_opening or charges==0:
		failures.append(zone+" did not finish through a natural opening")
	if bow and (hero.arrows<0 or cues.has("blade") or not cues.has("bow_loose")):
		failures.append("bow-only input or ammunition")
	if not bow and (hero.arrows!=12 or cues.has("bow_loose")):
		failures.append("melee-only input")
	mouse(false)
	for key: Key in [KEY_W,KEY_S,KEY_A,KEY_D,KEY_SHIFT,KEY_SPACE,KEY_1,KEY_2]:
		button(key,false)
	wilds.free()
	hero.free()
	await physics_frame

func run() -> void:
	root.add_child(world)
	await physics_frame
	await duel("tide",false)
	await duel("snow",true)
	world.free()
	if failures.is_empty():
		print("PASS live tide melee and snow bow duels with normal AI, terrain, player input and starting equipment")
	else:
		for error in failures: printerr("FAIL ",error)
	quit(0 if failures.is_empty() else 1)
