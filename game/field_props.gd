extends Node3D
## Operating the winch and bypass valve changes the orientation of their handles.
var winch_arm := Node3D.new()
var valve_arm := Node3D.new()
var flame := OmniLight3D.new()
var harbor_lamp := OmniLight3D.new()
var fisherman := Node3D.new()
var camp_flame: MeshInstance3D
var harbor_glass: MeshInstance3D

func piece(parent: Node3D, mesh: Mesh, pos: Vector3, tint: String, glow := false) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(tint)
	if glow:
		mat.emission_enabled = true
		mat.emission = Color(tint)
		mat.emission_energy_multiplier = 1.8
	part.mesh = mesh
	part.material_override = mat
	part.position = pos
	parent.add_child(part)
	return part

func bar(parent: Node3D, pos: Vector3, size: Vector3, tint: String) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return piece(parent,mesh,pos,tint)

func cone(parent: Node3D,pos: Vector3,base: float,top: float,height: float,tint: String, glow := false) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = base
	mesh.top_radius = top
	mesh.height = height
	mesh.radial_segments = 8
	return piece(parent,mesh,pos,tint,glow)

func build(positions: Dictionary) -> void:
	var camp := Node3D.new()
	add_child(camp)
	camp.position = positions.camp
	for i in 8:
		cone(camp,Vector3(cos(i*TAU/8)*0.63,0.11,sin(i*TAU/8)*0.63),0.24,0.17,0.24,"61655d")
	for i in 3:
		bar(camp,Vector3(0,0.19+i*0.03,0),Vector3(1.15,0.18,0.21),"69513e").rotation.y = i*PI/3
	camp_flame = cone(camp,Vector3.UP*0.67,0.35,0.03,1.04,"ffac50",true)
	camp.add_child(flame)
	flame.position = Vector3.UP*1.1
	flame.omni_range = 8
	flame.light_color = Color("ffbf76")
	for id in ["winch","valve"]:
		var stand := Node3D.new()
		add_child(stand)
		stand.position = positions[id]
		bar(stand,Vector3.UP*0.48,Vector3(.85,.96,.48),"7c6446" if id=="winch" else "657e79")
		var arm := winch_arm if id == "winch" else valve_arm
		stand.add_child(arm)
		arm.position = Vector3(0,.98,.3)
		var circle := TorusMesh.new()
		circle.inner_radius=.32
		circle.outer_radius=.44
		circle.rings=12
		circle.ring_segments=5
		piece(arm,circle,Vector3.ZERO,"b9874e").rotation.x = PI/2
		for n in 3:
			bar(arm,Vector3.ZERO,Vector3(.80,.062,.06),"ad8d62").rotation.z = n*PI/3
		bar(arm,Vector3(.36,0,.12),Vector3(.13,.14,.28),"e4b96f")
	var post := Node3D.new()
	add_child(post)
	post.position = positions.harbor
	bar(post,Vector3.UP*1.2,Vector3(.26,2.4,.27),"665646")
	bar(post,Vector3.UP*2.4,Vector3(.77,.12,.69),"43504e")
	harbor_glass = cone(post,Vector3.UP*2.72,.24,.26,.54,"c8a767",true)
	cone(post,Vector3.UP*3.08,.46,.06,.3,"43504e")
	post.add_child(harbor_lamp)
	harbor_lamp.position = Vector3.UP*2.7
	harbor_lamp.light_color = Color("ffc17c")
	harbor_lamp.omni_range = 11
	add_child(fisherman)
	var skin := "b88565"
	cone(fisherman,Vector3.UP*.68,.39,.30,.83,"6a8285")
	cone(fisherman,Vector3(0,1.35,0),.23,.23,.41,skin)
	cone(fisherman,Vector3.UP*1.60,.38,.24,.17,"ab895c")
	for side: float in [-1.0,1.0]:
		bar(fisherman,Vector3(side*.18,.16,.06),Vector3(.21,.32,.39),"4d514b")
		bar(fisherman,Vector3(side*.32,.84,.09),Vector3(.17,.48,.19),"748b87").rotation.z = side*.19

func refresh(clock: float,flags: Array,positions: Dictionary) -> void:
	winch_arm.rotation.z = lerp_angle(winch_arm.rotation.z,2.2 if flags.has("winch") else 0.0,.17)
	valve_arm.rotation.z = lerp_angle(valve_arm.rotation.z,1.55 if flags.has("valve") else 0.0,.17)
	var flicker := 1.0 + .10*sin(clock*6.0) + .045*sin(clock*13.4)
	camp_flame.scale.y = flicker
	flame.light_energy = 1.5*flicker
	harbor_lamp.light_energy = 2.4 if flags.has("harbor") else 0.0
	harbor_glass.visible = flags.has("harbor")
	fisherman.position = positions.harbor+Vector3(1,0,0) if flags.has("rescue") else positions.rescue
	fisherman.rotation.z = 0.0 if flags.has("rescue") else -.46
