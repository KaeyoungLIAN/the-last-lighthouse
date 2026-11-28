extends Node3D
## Operating the winch and bypass valve changes the orientation of their handles.
var winch_arm := Node3D.new()
var valve_arm := Node3D.new()
var flame := OmniLight3D.new()
var harbor_lamp := OmniLight3D.new()
var fisherman := Node3D.new()
var camp_flame: MeshInstance3D
var harbor_glass: MeshInstance3D
const Art = preload("res://actors/actor_art.gd")
var salvage_items := {}


func _model(parent: Node3D, mesh: Mesh, at := Vector3.ZERO) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.position = at
	parent.add_child(part)
	return part

func _ring(parent: Node3D, center: Vector3, inner: float, outer: float, color: String) -> void:
	var hoop := TorusMesh.new()
	hoop.inner_radius = inner
	hoop.outer_radius = outer
	hoop.rings = 24
	hoop.ring_segments = 6
	Art.part(parent, hoop, center, color)

func _place_salvage(positions: Dictionary) -> void:
	for site: String in ["beach", "lake", "volcano"]:
		var tray := Art.joint(self, positions[site] + Vector3(.46,0,-.20))
		Art.block(tray, Vector3.UP*.16, Vector3(1.18,.28,.89), "785b42")
		for side: float in [-1.,1.]:
			Art.block(tray, Vector3(0,.34,side*.43), Vector3(1.21,.13,.055), "a38560")
		var item := Art.joint(tray, Vector3.UP*.30)
		salvage_items[site] = item
		match site:
			"beach":
				for turn in 4:
					_ring(item, Vector3(-.10,.043+turn*.076,0), .20, .30, "c09a66")
				Art.rod(item, Vector3(.11,.29,.12), Vector3(.48,.08,.26), .046,.034,"b68d5d")
			"lake":
				_ring(item, Vector3(0,.060,0), .20,.34,"b58f5d")
				_ring(item, Vector3(0,.15,0), .23,.30,"527a75")
			"volcano":
				Art.block(item, Vector3.UP*.11, Vector3(.70,.18,.39), "69716e")
				for side: float in [-1.,1.]:
					Art.block(item, Vector3(side*.27,.25,0), Vector3(.15,.28,.37), "89918a")
				Art.rod(item, Vector3(-.41,.33,0), Vector3(.41,.33,0), .073,.073,"a48a63")

func build(positions: Dictionary, world) -> void:
	_place_salvage(positions)
	var camp := _model(self, world.landscape_mesh("CampHearth"), positions.camp)
	camp_flame = _model(camp, world.landscape_mesh("HearthFlame"), Vector3.UP*.26)
	var coals := StandardMaterial3D.new()
	coals.vertex_color_use_as_albedo = true
	coals.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	camp_flame.material_override = coals
	camp.add_child(flame)
	flame.position = Vector3.UP*1.1
	flame.omni_range = 8
	flame.light_color = Color("ffbf76")
	for id in ["winch","valve"]:
		var body_name := "WreckWinch" if id == "winch" else "BypassBody"
		var wheel_name := "WinchWheel" if id == "winch" else "BypassWheel"
		var stand := _model(self, world.landscape_mesh(body_name), positions[id])
		var arm := winch_arm if id == "winch" else valve_arm
		stand.add_child(arm)
		arm.position = Vector3(0,.98,.33)
		_model(arm, world.landscape_mesh(wheel_name))
	var post := _model(self, world.landscape_mesh("PilotLantern"), positions.harbor)
	var chimney := CylinderMesh.new()
	chimney.bottom_radius = .24
	chimney.top_radius = .26
	chimney.height = .54
	chimney.radial_segments = 8
	harbor_glass = _model(post, chimney, Vector3.UP*2.72)
	var lens := StandardMaterial3D.new()
	lens.albedo_color = Color("c8a767")
	lens.emission_enabled = true
	lens.emission = Color("c8a767")
	lens.emission_energy_multiplier = 1.8
	harbor_glass.material_override = lens
	post.add_child(harbor_lamp)
	harbor_lamp.position = Vector3.UP*2.7
	harbor_lamp.light_color = Color("ffc17c")
	harbor_lamp.omni_range = 11
	add_child(fisherman)
	var cast := preload("res://art/cast/fisherman.glb").instantiate()
	fisherman.add_child(cast)
	cast.get_node("Head").position.y = 1.52
	cast.get_node("GreetingArm").position = Vector3(.247, 1.16, 0)

func refresh(clock: float,flags: Array,positions: Dictionary,tower_lit: bool) -> void:
	winch_arm.rotation.z = lerp_angle(winch_arm.rotation.z,2.2 if flags.has("winch") else 0.0,.17)
	valve_arm.rotation.z = lerp_angle(valve_arm.rotation.z,1.55 if flags.has("valve") else 0.0,.17)
	var flicker := 1.0 + .10*sin(clock*6.0) + .045*sin(clock*13.4)
	camp_flame.scale.y = flicker
	flame.light_energy = 1.5*flicker
	harbor_lamp.light_energy = 2.4 if tower_lit else 0.0
	harbor_glass.visible = tower_lit
	for site: String in salvage_items:
		salvage_items[site].visible = not flags.has(site)
	fisherman.position = positions.harbor+Vector3(1,0,0) if flags.has("rescue") else positions.rescue
	fisherman.rotation.z = 0.0 if flags.has("rescue") else -.46
