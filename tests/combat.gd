extends SceneTree

const Keeper = preload("res://actors/player.gd")
const Foe = preload("res://actors/enemy.gd")
const DT := 1.0/60.0
var hero := Keeper.new()
var failed := false

func _initialize() -> void:
	call_deferred("run")

func expect(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		printerr("FAIL ",message)

func spawn(kind: String, point: Vector3):
	var enemy := Foe.new()
	root.add_child(enemy)
	enemy.setup(kind,hero,null,point)
	enemy.set_physics_process(false)
	return enemy

func click() -> void:
	var attack := InputEventMouseButton.new()
	attack.button_index = MOUSE_BUTTON_LEFT
	attack.pressed = true
	hero._unhandled_input(attack)

func ticks(count: int) -> void:
	for i in count:
		hero._physics_process(DT)

func run() -> void:
	root.add_child(hero)
	hero.set_physics_process(false)
	hero.camera_yaw = 0
	await physics_frame
	var target = spawn("elite",Vector3.FORWARD*1.55)
	click()
	ticks(26)
	expect(target.hp==83.0,"left click lands first cut once")
	click()
	ticks(29)
	expect(target.hp==64.0,"second click reverses the cut")
	click()
	ticks(42)
	expect(target.hp==35.0 and target.intent==Foe.Intent.RECOVER,"third cut deals heavy damage and interrupts")
	ticks(60)
	click()
	ticks(28)
	expect(target.hp==20.0,"after finisher chain starts over")
	target.free()

	hero.reset_combat()
	hero.position = Vector3.ZERO
	var foe = spawn("hound",Vector3.FORWARD*1.27)
	foe._begin_windup(Vector3.BACK)
	expect(foe.warning.visible and foe.warning.mesh!=null,"attack paints its locked arc")
	hero.position = Vector3.FORWARD*2.4
	for i in 70: foe._physics_process(DT)
	expect(hero.hp==100,"crossing behind the warning avoids damage")
	foe.position = Vector3.FORWARD*1.27
	hero.position = Vector3.ZERO
	hero.rotation.y = 0
	foe._begin_windup(Vector3.BACK)
	while foe.intent==Foe.Intent.WINDUP:
		foe._physics_process(DT)
	var dodge := InputEventKey.new()
	dodge.physical_keycode = KEY_SPACE
	dodge.pressed = true
	hero._unhandled_input(dodge)
	ticks(1)
	foe._physics_process(DT)
	expect(hero.hp==100 and hero._counter_left>0,"last-moment dodge opens counter window")
	expect(foe.intent==Foe.Intent.RECOVER and not foe.warning.visible,"evaded attacker gives an opening")
	# End the roll beyond the foe; the buffered riposte should turn without camera input.
	click()
	for i in 38:
		hero.position = Vector3.FORWARD*2.35
		ticks(1)
	expect(foe.hp==5,"buffered riposte lands once")
	hero.reset_combat()
	hero.receive_hit(11)
	expect(hero.hp==89,"unguarded enemy hits still damage")
	foe.free()

	var crab = spawn("crab",Vector3.ZERO)
	crab._begin_windup(Vector3.FORWARD)
	expect(crab.receive_hit(15,false,Vector3.FORWARD)==7.0,"crab shell guards frontal light cuts")
	expect(crab.receive_hit(15,false,Vector3.BACK)==15.0,"flank bypasses guard")
	expect(crab.receive_hit(19,true,Vector3.FORWARD)==19.0 and crab.intent==Foe.Intent.RECOVER,"heavy cut breaks the crab's guard")
	crab.free()
	hero.free()
	if not failed:
		print("PASS three-cut chain, locked attack area, timed dodge, buffered riposte and crab guard")
	quit(1 if failed else 0)
