extends MeshInstance3D
## A locked, ground-following threat area. UV.y runs from the attacker to the rim.

var paint := ShaderMaterial.new()

func _ready() -> void:
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	paint.shader = preload("attack_warning.gdshader")
	material_override = paint
	hide()

func place(origin: Vector3, direction: Vector3, radius: float, angle: float, world) -> void:
	global_transform = Transform3D(Basis.IDENTITY, origin)
	var shape := SurfaceTool.new()
	shape.begin(Mesh.PRIMITIVE_TRIANGLES)
	const SLICES := 24
	const BANDS := 5
	for band in range(BANDS + 1):
		var fraction := float(band) / BANDS
		for i in range(SLICES + 1):
			var side := float(i) / SLICES
			var offset := direction.rotated(Vector3.UP,lerpf(-angle,angle,side)) * radius * fraction
			if world != null:
				offset.y = world.ground_height(origin.x+offset.x,origin.z+offset.z) - origin.y
			shape.set_uv(Vector2(side,fraction))
			shape.add_vertex(offset+Vector3.UP*.11)
	for band in BANDS:
		for i in SLICES:
			var a := band*(SLICES+1)+i
			var b := a+SLICES+1
			for index in [a,b,b+1,a,b+1,a+1]:
				shape.add_index(index)
	mesh = shape.commit()
	set_charge(0.0)
	show()

func set_charge(fraction: float) -> void:
	paint.set_shader_parameter("charge",fraction)
