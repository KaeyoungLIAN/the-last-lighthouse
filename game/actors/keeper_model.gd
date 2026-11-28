extends Node3D

const Art = preload("actor_art.gd")
const CAST := preload("res://art/cast/keeper.glb")
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
var slash_trail := MeshInstance3D.new()

func _ready() -> void:
	var cast := CAST.instantiate()
	for piece: Node in cast.get_children():
		piece.owner = null
	body = cast.get_node("KeeperBody")
	body.reparent(self, false)
	_build_slash_trail()
	for side: String in ["Left", "Right"]:
		var leg: Node3D = cast.get_node(side + "Boot")
		leg.reparent(body, false)
		leg.position = Vector3(-.16 if side == "Left" else .16, .73, 0)
		legs.append(leg)
	lamp_arm = cast.get_node("LeftSleeve")
	sword_arm = cast.get_node("RightSleeve")
	lamp_arm.reparent(body, false)
	sword_arm.reparent(body, false)
	lamp_arm.position = Vector3(-.326, 1.43, 0)
	sword_arm.position = Vector3(.326, 1.43, 0)
	scarf = cast.get_node("ScarfTail")
	scarf.reparent(body, false)
	scarf.position = Vector3(.135, 1.52, .125)
	scarf.rotation.z = .28
	pauldron = Art.taper(sword_arm,Vector3(0.035,-0.01,0),0.205,0.131,0.18,"6d8281")
	pauldron.visible = false
	lantern = cast.get_node("LampCage")
	lantern.reparent(lamp_arm, false)
	lantern.position = Vector3(-.03, -.44, -.09)
	cast.free()
	flame = Art.taper(lantern,Vector3(0,-0.275,0),0.102,0.115,0.216,"ffca70",12,true)
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

func _build_slash_trail() -> void:
	var ribbon := SurfaceTool.new()
	ribbon.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in range(19):
		var t := i / 18.0
		var direction := Vector3.FORWARD.rotated(Vector3.UP,lerpf(-.98,.98,t))
		var width := .135*sin(PI*t)
		ribbon.set_color(Color(.56,.86,.94,.5*sin(PI*t)))
		ribbon.add_vertex(direction*(1.42-width))
		ribbon.set_color(Color(1.0,.96,.77,.91*sin(PI*t)))
		ribbon.add_vertex(direction*1.42)
	var sheen := StandardMaterial3D.new()
	sheen.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sheen.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sheen.cull_mode = BaseMaterial3D.CULL_DISABLED
	sheen.vertex_color_use_as_albedo = true
	slash_trail.mesh = ribbon.commit()
	slash_trail.material_override = sheen
	slash_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(slash_trail)
	slash_trail.hide()

func animate(delta: float, speed: float, mode: int, slash: float, rolling: float, hurt: float, upgraded: bool, armored: bool, combo_step := 0, counter := false) -> void:
	step_phase += delta*(4.0 + speed*1.65)
	var stride := minf(speed*0.18,1.0)
	var wave := sin(step_phase)*stride
	legs[0].rotation.x = wave*0.57
	legs[1].rotation.x = -wave*0.57
	body.position.y = 0.035*absf(wave) - sin(rolling*PI)*0.33
	body.rotation.x = -sin(rolling*PI)*0.95
	body.rotation.z = sin(hurt*PI)*0.13
	body.rotation.y = 0
	scarf.rotation.x = wave*0.23 + stride*0.15
	lamp_arm.rotation.x = lerpf(lamp_arm.rotation.x, 1.31 if mode==2 else 0.16-wave*0.23, 1-exp(-delta*15))
	lantern.rotation.x = -lamp_arm.rotation.x - wave*0.11
	sword_arm.rotation.x = 0.15 + wave*0.31
	sword_arm.rotation.y = -0.56
	sword_arm.rotation.z = 0.17
	slash_trail.visible = slash>0.34 and slash<0.71
	if slash>0:
		var progress := 1.0-slash
		var cut := smoothstep(0.20, 0.58, progress)
		var rest := smoothstep(0.61, 1.0, progress)
		sword_arm.rotation.x = lerpf(0.68,0.14,rest)
		var sweep := lerpf(-1.18,1.05,cut) * (-1.0 if combo_step==1 else 1.0)
		sword_arm.rotation.y = lerpf(sweep,-0.56,rest)
		sword_arm.rotation.z = lerpf(0.76,0.10,rest)
		body.rotation.y = sweep*(.52 if combo_step==2 or counter else .26)*(1-rest)
		slash_trail.position.y = 1.03 if combo_step!=1 else 1.19
		slash_trail.rotation = Vector3(-.14,sweep*.64,.32 if combo_step==1 else -.28)
		var radius := (1.29 if upgraded else 1.0) * (1.16 if combo_step==2 or counter else 1.0)
		slash_trail.scale = Vector3.ONE*radius
		if combo_step==2 or counter:
			sword_arm.rotation.x += (1.0-cut)*1.24
			body.rotation.x += lerpf(-.20,.28,cut)*(1.0-rest)
	blade.visible = not upgraded
	spear.visible = upgraded
	pauldron.visible = armored
	flame.material_override = Art.surface("ffca70",true) if mode>0 else Art.surface("766651")
	light.visible = mode>0
	beam.visible = mode==2
