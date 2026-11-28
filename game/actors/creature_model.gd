extends Node3D

const Art = preload("actor_art.gd")
const MODELS := {
	"hound": preload("res://art/cast/hound.glb"),
	"crab": preload("res://art/cast/crab.glb"),
	"fin": preload("res://art/cast/fin.glb"),
	"lizard": preload("res://art/cast/lizard.glb"),
	"elite": preload("res://art/cast/elite.glb"),
	"boss": preload("res://art/cast/boss.glb"),
}


var body: Node3D
var limbs: Array[Node3D] = []
var core: MeshInstance3D
var breath: MeshInstance3D
var phase := 0.0
var species := ""

func build(kind: String) -> void:
	species = kind
	body = MODELS.get(kind, MODELS.hound).instantiate()
	add_child(body)
	for joint: Node in body.get_children():
		if joint.name.begins_with("Walk"):
			limbs.append(joint)
	if kind == "lizard":
		breath = Art.taper(body,Vector3(0,0.45,-2.65),0.065,0.40,3.5,"f7b05d",6,true)
		breath.rotation.x = -PI/2
		breath.hide()
	if kind in ["boss","elite"]:
		core = Art.block(body,Vector3(0,2.34,-0.264),Vector3(.42,.079,.055),"b6d7d0",true)
		body.scale = Vector3.ONE*(1.12 if kind == "boss" else .85)

func pose(delta: float, speed: float, windup: float, strike: float, recoil: float, broken: bool) -> void:
	phase += delta*(4.4+speed*1.7)
	var gait := minf(speed*0.29,1.0)
	var step := sin(phase)*gait
	for i in limbs.size():
		limbs[i].rotation.x = step*(0.46 if i%2==0 else -0.46)
	body.position.y = absf(step)*0.065 - windup*0.12 + sin(strike*PI)*0.10
	if species=="fin":
		body.position.y += 0.09+0.07*sin(phase)+0.36*sin(strike*PI)
	body.rotation.x = -0.19*windup + 0.16*sin(strike*PI) - 0.22*recoil
	body.rotation.z = 0.08*step+recoil*0.085
	if breath!=null:
		breath.visible = strike>0.38
	if core!=null:
		core.material_override = Art.surface("ffc76a" if broken else "b6d7d0",true)
