extends RefCounted
## Exterior establishing shots, composed above the lower narration panel.

static func frame(page: int, camera: Camera3D, world) -> void:
	var target: Vector3
	match page:
		0:
			var cape: Vector3 = world.get_node("CapeLighthouse").global_position
			camera.global_position = cape + Vector3(-23,5.3,30.2)
			target = cape + Vector3(2.7,4.0,-1.2)
			camera.fov = 48.0
			world.set_conditions(.15,.75,false)
		1:
			camera.global_position = Vector3(195.2,4.55,4.0)
			target = Vector3(204.5,1.15,8.6)
			camera.fov = 54.0
			world.set_conditions(.49,.64,false)
		_:
			var square: Vector3 = world._point(-37.0,30.0)
			camera.global_position = square + Vector3(-12,8.7,10.4)
			target = square + Vector3(2.7,.87,-2.6)
			camera.fov = 61.0
			world.set_conditions(.88,.34,false)
	camera.look_at(target)
	camera.make_current()
