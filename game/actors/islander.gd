extends Node3D
const CAST := {
	"cartographer": preload("res://art/cast/cartographer.glb"),
	"postwoman": preload("res://art/cast/postwoman.glb"),
	"herbalist": preload("res://art/cast/herbalist.glb"),
	"ranger": preload("res://art/cast/ranger.glb"),
}
var role: String
var arm: Node3D
var chest: Node3D
var head: Node3D
var phase: float
var home_yaw: float
var target_yaw: float
var idle_glance: float
var greeting := false

func build(id: String, _coat: String, _skin: String) -> void:
	role = id
	phase = float(id.hash()%23)
	rotation.y = {"cartographer":-.7,"postwoman":1.15,"herbalist":.30,"ranger":-.95}[id]
	home_yaw = rotation.y
	target_yaw = home_yaw
	var cast: Node3D = CAST[id].instantiate()
	for piece: Node in cast.get_children():
		piece.owner = null
	chest = cast.get_node("Chest")
	head = cast.get_node("Head")
	arm = cast.get_node("GreetingArm")
	chest.reparent(self, false)
	head.reparent(chest, false)
	head.position.y = 1.52
	arm.reparent(chest, false)
	arm.position = Vector3(.247, 1.16, 0)
	cast.free()

func pose(clock: float,day: float,visitor: Vector3) -> void:
	var towards := visitor-global_position
	towards.y = 0.0
	var distance := towards.length_squared()
	# Use separate arrival and departure radii to avoid fidgeting on the threshold.
	greeting = distance < (36.0 if greeting else 25.0)
	if greeting and distance>.02:
		target_yaw = atan2(-towards.x,-towards.z)
	elif not greeting:
		target_yaw = home_yaw
	var rest := 1.0-smoothstep(.08,.64,day)
	var rhythm := sin(clock*(2.6 if role=="cartographer" else 1.65)+phase)
	chest.position.y = .010*rhythm
	idle_glance = sin(clock*.53+phase)*(.037 if greeting else .15)
	head.rotation.x = -.09*rest + (.06 if not greeting and role in ["cartographer","herbalist"] else 0.0)
	arm.rotation.x = .25 + .17*rhythm if role in ["cartographer","herbalist"] else .09+.13*rhythm
	arm.rotation.x -= .22*rest
	arm.rotation.z = sin(clock*1.29+phase)*.08

func _process(delta: float) -> void:
	rotation.y = rotate_toward(rotation.y,target_yaw,delta*2.65)
	var lead := clampf(angle_difference(rotation.y,target_yaw),-.40,.40) if greeting else 0.0
	head.rotation.y = lerp_angle(head.rotation.y,lead+idle_glance,1.0-exp(-delta*8.0))
