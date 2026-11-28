extends Node3D
const Survey := preload("res://world/island_survey.gd")
## Landmark glints remain small in the landscape. Only nearby captions are revealed.
var sites: Dictionary = {}

func add_site(id: String, caption: String, at: Vector3, tint: Color, material_spot: bool = false) -> void:
	var group := Node3D.new()
	group.position = at
	add_child(group)
	if material_spot:
		for j in 4:
			var piece := MeshInstance3D.new()
			var stone := PrismMesh.new()
			stone.size = Vector3(0.55, 0.34 + j * 0.075, 0.5)
			piece.mesh = stone
			piece.position = Vector3(cos(j*2.1)*0.43, 0.19, sin(j*2.1)*0.35)
			piece.rotation.y = j*0.76
			var surface := StandardMaterial3D.new()
			surface.albedo_color = tint.darkened(0.26)
			piece.material_override = surface
			group.add_child(piece)
	var spark := MeshInstance3D.new()
	var jewel := SphereMesh.new()
	jewel.radius = 0.115
	jewel.height = 0.41
	jewel.radial_segments = 4
	jewel.rings = 1
	spark.mesh = jewel
	spark.position.y = 1.45
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.emission_enabled = true
	mat.emission = tint
	mat.emission_energy_multiplier = 1.6
	spark.material_override = mat
	group.add_child(spark)
	var label := Label3D.new()
	label.text = caption
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 34
	label.pixel_size = 0.009
	label.outline_size = 7
	label.modulate = Color("fff1d1")
	label.outline_modulate = Color("102229")
	label.position.y = 2.05
	label.visible = false
	group.add_child(label)
	sites[id] = {"node":group,"label":label,"spark":spark}

func refresh(pos: Vector3, consumed: Array, indoor: bool, time: float) -> void:
	for id in sites:
		var s: Dictionary = sites[id]
		var obj: Node3D = s.node
		var inside := Survey.in_mirror_room(Vector2(obj.position.x,obj.position.z))
		obj.visible = inside == indoor and not consumed.has(id)
		if not obj.visible:
			continue
		var distance := Vector2(pos.x-obj.position.x,pos.z-obj.position.z).length()
		var camera := get_viewport().get_camera_3d()
		var label: Label3D = s.label
		label.visible = distance < 12.0 and camera != null and camera.global_position.distance_squared_to(label.global_position) > 9.0 and not camera.is_position_behind(label.global_position)
		s.spark.position.y = 1.45 + 0.09*sin(time*2.8 + obj.position.x)
		s.spark.rotation.y = time * 0.8
