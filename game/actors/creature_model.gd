extends Node3D

const Art = preload("actor_art.gd")

var body: Node3D
var limbs: Array[Node3D] = []
var crest: MeshInstance3D
var warning: MeshInstance3D
var core: MeshInstance3D
var breath: MeshInstance3D
var phase := 0.0
var species := ""

func build(kind: String) -> void:
	species = kind
	body = Art.joint(self,Vector3.ZERO)
	match kind:
		"crab": _crab()
		"fin": _fin()
		"lizard": _lizard()
		"boss","elite": _guardian(kind=="boss")
		_: _hound()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.80
	ring.outer_radius = 0.85
	ring.rings = 32
	ring.ring_segments = 4
	warning = Art.part(self,ring,Vector3.UP*0.06,"f19b5c",true)
	warning.scale.y = 0.18
	warning.visible = false

func _eyes(y: float, z: float, spacing: float, color: String) -> void:
	for side: float in [-1.0,1.0]:
		Art.oval(body,Vector3(spacing*side,y,z),Vector3(0.115,0.071,0.080),color,true)

func _legs(count: int, w: float, y: float, length_z: float, color: String, wide: bool = false) -> void:
	for row in count:
		var z := lerpf(-length_z,length_z,float(row)/maxi(1,count-1))
		for side: float in [-1.0,1.0]:
			var pivot := Art.joint(body,Vector3(side*w,y,z))
			var knee := Vector3(side*(0.29 if wide else 0.03),-y*0.40,0.07)
			var toe := Vector3(side*(0.49 if wide else 0.05),-y+0.05,-0.085)
			Art.rod(pivot,Vector3.ZERO,knee,0.087,0.060,color)
			Art.rod(pivot,knee,toe,0.061,0.029,color)
			limbs.append(pivot)

func _hound() -> void:
	Art.oval(body,Vector3(0,0.63,0.03),Vector3(0.72,0.70,1.30),"314643")
	Art.oval(body,Vector3(0,0.81,-0.49),Vector3(0.56,0.63,0.62),"2c4143")
	Art.oval(body,Vector3(0,0.70,-0.79),Vector3(0.42,0.29,0.44),"43504b")
	for side: float in [-1.0,1.0]:
		Art.rod(body,Vector3(0.18*side,0.98,-0.47),Vector3(0.24*side,1.31,-0.38),0.114,0.008,"527266")
	for i in 4:
		var z := -0.24+i*0.20
		Art.rod(body,Vector3(0,0.88,z),Vector3(0,1.10-i*0.045,z+0.10),0.10,0.008,"7e9d70")
	Art.rod(body,Vector3(0,0.64,0.57),Vector3(0,0.91,1.08),0.13,0.025,"3b554c")
	_eyes(0.88,-0.728,0.19,"a6efa8")
	_legs(2,0.21,0.48,0.32,"34443e")

func _crab() -> void:
	Art.oval(body,Vector3(0,0.46,0.07),Vector3(1.30,0.72,1.01),"a76b4d")
	Art.taper(body,Vector3(0,0.72,0.14),0.46,0.21,0.37,"d79e6b",7)
	_legs(3,0.38,0.37,0.26,"975b46",true)
	for side: float in [-1.0,1.0]:
		var pivot := Art.joint(body,Vector3(side*0.49,0.49,-0.26))
		Art.rod(pivot,Vector3.ZERO,Vector3(side*0.27,0.07,-0.22),0.092,0.11,"91543c")
		Art.oval(pivot,Vector3(side*0.29,0.12,-0.32),Vector3(0.39,0.33,0.40),"c98050")
		Art.rod(pivot,Vector3(side*0.21,0.12,-0.43),Vector3(side*0.28,0.13,-0.70),0.088,0.012,"dfa574")
		limbs.append(pivot)
	_eyes(0.61,-0.40,0.243,"ffcb8e")

func _fin() -> void:
	Art.oval(body,Vector3(0,0.58,0),Vector3(0.67,0.86,1.33),"487071")
	Art.oval(body,Vector3(0,0.54,-0.50),Vector3(0.69,0.52,0.69),"648779")
	Art.rod(body,Vector3(0,0.8,-0.06),Vector3(0,1.34,0.32),0.21,0.012,"a3ceb0")
	for side: float in [-1.0,1.0]:
		var fin := Art.rod(body,Vector3(side*0.23,0.48,0.12),Vector3(side*0.81,0.27,0.52),0.18,0.02,"8ebda5")
		fin.scale.z = 0.5
	Art.rod(body,Vector3(0,0.48,0.50),Vector3(0,0.76,1.04),0.155,0.015,"82ab91")
	_eyes(0.67,-0.77,0.15,"9beada")

func _lizard() -> void:
	Art.oval(body,Vector3(0,0.44,0.05),Vector3(0.90,0.60,1.42),"5b5049")
	Art.oval(body,Vector3(0,0.46,-0.69),Vector3(0.67,0.42,0.74),"6e5447")
	for i in 4:
		var z := -0.38 + i*0.26
		Art.rod(body,Vector3(0,0.65,z),Vector3(0,0.93,z+0.09),0.11,0.012,"dc884b")
	Art.rod(body,Vector3(0,0.38,0.60),Vector3(0.11,0.15,1.46),0.19,0.018,"805c4e")
	_eyes(0.56,-1.0,0.17,"ffb760")
	_legs(2,0.29,0.30,0.39,"595049",true)
	breath = Art.taper(body,Vector3(0,0.45,-2.65),0.065,0.40,3.5,"f7b05d",6,true)
	breath.rotation.x = -PI/2
	breath.visible = false

func _guardian(boss: bool) -> void:
	var metal := "40515b" if boss else "4c514d"
	var mantle := "526b75" if boss else "546653"
	var rim := "b79c62" if boss else "8b926b"
	Art.taper(body,Vector3(0,0.91,0),0.61,0.40,1.15,metal,8).scale.z = 0.8
	Art.taper(body,Vector3(0,1.66,0),0.42,0.60,0.76,metal,8).scale.z = 0.78
	Art.taper(body,Vector3(0,1.98,0),0.78,0.37,0.44,mantle,8).scale.z = 0.82
	Art.oval(body,Vector3(0,2.32,-0.01),Vector3(0.66,0.60,0.57),metal)
	core = Art.block(body,Vector3(0,2.34,-0.282),Vector3(0.42,0.09,0.061),"b6d7d0",true)
	Art.taper(body,Vector3(0,2.54,0),0.44,0.32,0.12,rim,8)
	for side: float in [-1.0,1.0]:
		Art.rod(body,Vector3(0.55*side,1.93,0),Vector3(0.68*side,1.17,-0.12),0.21,0.15,mantle)
		Art.rod(body,Vector3(0.31*side,2.51,0),Vector3(0.43*side,2.90,0.12),0.08,0.016,rim)
	Art.rod(body,Vector3(0.7,0.12,-0.23),Vector3(0.7,2.75,-0.17),0.057,0.071,rim)
	if boss:
		Art.rod(body,Vector3(0.7,2.68,-0.17),Vector3(1.24,2.41,-0.18),0.20,0.02,"b9c6bf")
		for i in 3:
			Art.block(body,Vector3(0,1.25+i*0.20,-0.362),Vector3(0.30-i*0.05,0.08,0.04),"d4b36c")
	else:
		Art.rod(body,Vector3(0.70,2.23,-0.17),Vector3(1.11,2.69,-0.13),0.11,0.02,rim)
	_legs(2,0.29,0.42,0.06,metal)
	body.scale = Vector3.ONE*(1.12 if boss else 0.85)

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
	warning.visible = windup>0
	warning.scale.x = 1+windup*0.44
	warning.scale.z = warning.scale.x
	if breath!=null:
		breath.visible = strike>0.38
	if core!=null:
		core.material_override = Art.surface("ffc76a" if broken else "b6d7d0",true)
