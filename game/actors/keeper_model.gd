extends Node3D

const Art = preload("actor_art.gd")
const COAT := "d89b35"
const OILSKIN := "f2b848"
const LEATHER := "754434"
const NAVY := "263d4b"
const BRASS := "e3b75d"

var body: Node3D
var legs: Array[Node3D] = []
var lamp_arm: Node3D
var sword_arm: Node3D
var lantern: Node3D
var flame: MeshInstance3D
var blade: MeshInstance3D
var spear: Node3D
var pauldron: MeshInstance3D
var scarf: MeshInstance3D
var light: OmniLight3D
var beam: SpotLight3D
var step_phase := 0.0

func _ready() -> void:
	body = Art.joint(self, Vector3.ZERO)
	for x: float in [-0.16, 0.16]:
		var leg := Art.joint(body, Vector3(x, 0.73, 0))
		Art.taper(leg, Vector3(0,-0.20,0), 0.104, 0.122, 0.42, NAVY)
		Art.taper(leg, Vector3(0,-0.47,0), 0.125, 0.112, 0.26, "34383b")
		Art.oval(leg, Vector3(0,-0.62,-0.057), Vector3(0.26,0.19,0.38), "413934")
		legs.append(leg)
	Art.taper(body, Vector3(0,0.92,0),0.38,0.29,0.57,COAT,10).scale.z = 0.76
	Art.taper(body, Vector3(0,1.27,0),0.285,0.34,0.43,COAT,10).scale.z = 0.79
	Art.taper(body, Vector3(0,1.43,0),0.45,0.22,0.22,OILSKIN,10).scale.z = 0.75
	Art.taper(body, Vector3(0,1.086,0),0.313,0.303,0.07,LEATHER,10).scale.z = 0.77
	Art.block(body, Vector3(-0.15,1.02,0.19),Vector3(0.21,0.16,0.11),LEATHER)
	Art.rod(body, Vector3(-0.24,1.45,0.19), Vector3(0.22,1.08,0.17),0.045,0.038,LEATHER)
	Art.taper(body, Vector3(0,1.52,0),0.205,0.19,0.13,"ab4b3c")
	scarf = Art.block(body, Vector3(0.14,1.37,0.25),Vector3(0.13,0.32,0.045),"bd5343")
	scarf.rotation.z = 0.28
	Art.oval(body, Vector3(0,1.72,-0.025),Vector3(0.39,0.42,0.36),"d89971")
	Art.oval(body, Vector3(0,1.77,0.055),Vector3(0.395,0.33,0.32),"574540")
	Art.oval(body, Vector3(0,1.68,-0.195),Vector3(0.09,0.10,0.10),"d99e75")
	for x: float in [-0.085,0.085]:
		Art.block(body,Vector3(x,1.74,-0.19),Vector3(0.047,0.026,0.022),NAVY)
	Art.taper(body,Vector3(0,1.866,-0.025),0.318,0.218,0.095,"244956",10).scale.z=1.04
	Art.taper(body,Vector3(0,1.941,0.012),0.209,0.145,0.125,"315763",10)
	Art.taper(body,Vector3(0,1.895,0.005),0.212,0.212,0.031,BRASS,10)
	lamp_arm = _arm(-1.0)
	sword_arm = _arm(1.0)
	pauldron = Art.taper(sword_arm,Vector3(0.035,-0.01,0),0.205,0.131,0.18,"6d8281")
	pauldron.visible = false
	lantern = Art.joint(lamp_arm,Vector3(-0.03,-0.44,-0.09))
	Art.rod(lantern,Vector3(-0.076,-0.12,0),Vector3(-0.054,0,0),0.016,0.014,BRASS)
	Art.rod(lantern,Vector3(0.076,-0.12,0),Vector3(0.054,0,0),0.016,0.014,BRASS)
	Art.taper(lantern,Vector3(0,-0.14,0),0.148,0.079,0.065,NAVY,6)
	flame = Art.taper(lantern,Vector3(0,-0.275,0),0.10,0.118,0.22,"ffca70",6,true)
	Art.taper(lantern,Vector3(0,-0.415,0),0.113,0.14,0.07,NAVY,6)
	for i in 4:
		var v := Vector3(cos(i*PI/2.0),0,sin(i*PI/2.0))
		Art.rod(lantern,v*0.115+Vector3.DOWN*0.38,v*0.123+Vector3.DOWN*0.17,0.012,0.013,LEATHER)
	light = OmniLight3D.new()
	lantern.add_child(light)
	light.position.y = -0.29
	light.light_color = Color("ffd197")
	light.omni_range = 8.5
	light.light_energy = 2.0
	beam = SpotLight3D.new()
	add_child(beam)
	beam.position = Vector3(-0.36,1.4,-0.3)
	beam.light_color = Color("ffdfaf")
	beam.light_energy = 5.0
	beam.spot_angle = 35
	beam.spot_range = 7.5
	var hilt := Art.joint(sword_arm,Vector3(0,-0.46,-0.08))
	Art.rod(hilt,Vector3(0,0,0.11),Vector3(0,0,-0.12),0.041,0.038,LEATHER)
	Art.block(hilt,Vector3(0,0,-0.14),Vector3(0.25,0.048,0.055),BRASS)
	blade = Art.taper(hilt,Vector3(0,0,-0.49),0.076,0.012,0.69,"d5e3df",4)
	blade.rotation.x = -PI/2
	blade.scale.z = 0.36
	spear = Art.joint(hilt,Vector3.ZERO)
	Art.rod(spear,Vector3(0,0,0.34),Vector3(0,0,-0.89),0.033,0.03,LEATHER)
	Art.rod(spear,Vector3(0,0,-0.86),Vector3(0,0,-1.22),0.072,0.004,"c8d8d5")
	Art.rod(spear,Vector3(0,0,-0.9),Vector3(-0.11,0,-0.77),0.041,0.012,"acbdb8")
	spear.visible = false

func _arm(side: float) -> Node3D:
	var arm := Art.joint(body,Vector3(0.326*side,1.43,0))
	Art.rod(arm,Vector3(0,0,0),Vector3(0.055*side,-0.32,-0.03),0.135,0.089,COAT)
	Art.rod(arm,Vector3(0.055*side,-0.30,-0.03),Vector3(0.025*side,-0.41,-0.085),0.09,0.076,NAVY)
	Art.oval(arm,Vector3(0.025*side,-0.429,-0.085),Vector3(0.14,0.14,0.15),LEATHER)
	return arm

func animate(delta: float, speed: float, mode: int, slash: float, rolling: float, hurt: float, upgraded: bool, armored: bool) -> void:
	step_phase += delta*(4.0 + speed*1.65)
	var stride := minf(speed*0.18,1.0)
	var wave := sin(step_phase)*stride
	legs[0].rotation.x = wave*0.57
	legs[1].rotation.x = -wave*0.57
	body.position.y = 0.035*absf(wave) - sin(rolling*PI)*0.33
	body.rotation.x = -sin(rolling*PI)*0.95
	body.rotation.z = sin(hurt*PI)*0.13
	scarf.rotation.x = wave*0.23 + stride*0.15
	lamp_arm.rotation.x = lerpf(lamp_arm.rotation.x, 1.31 if mode==2 else 0.16-wave*0.23, 1-exp(-delta*15))
	lantern.rotation.x = -lamp_arm.rotation.x - wave*0.11
	sword_arm.rotation.x = 0.15 + wave*0.31
	sword_arm.rotation.y = -0.56
	sword_arm.rotation.z = 0.17
	if slash>0:
		var progress := 1.0-slash
		var cut := smoothstep(0.20, 0.58, progress)
		var rest := smoothstep(0.61, 1.0, progress)
		sword_arm.rotation.x = lerpf(0.68,0.14,rest)
		sword_arm.rotation.y = lerpf(lerpf(-1.18,1.05,cut),-0.56,rest)
		sword_arm.rotation.z = lerpf(0.76,0.10,rest)
	blade.visible = not upgraded
	spear.visible = upgraded
	pauldron.visible = armored
	flame.material_override = Art.surface("ffca70",true) if mode>0 else Art.surface("766651")
	light.visible = mode>0
	beam.visible = mode==2
