extends RefCounted

## Shared, flat-faceted geometry for the keeper and the island fauna.
static var palette := {}

static func surface(color: String, glow := false) -> StandardMaterial3D:
	var key := color + ("*" if glow else "")
	if palette.has(key):
		return palette[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color)
	mat.roughness = 0.85
	if glow:
		mat.emission_enabled = true
		mat.emission = Color(color)
		mat.emission_energy_multiplier = 1.6
	palette[key] = mat
	return mat

static func joint(parent: Node3D, at: Vector3) -> Node3D:
	var pivot := Node3D.new()
	parent.add_child(pivot)
	pivot.position = at
	return pivot

static func part(parent: Node3D, mesh: Mesh, at: Vector3, color: String, glow := false) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = surface(color, glow)
	parent.add_child(node)
	node.position = at
	return node

static func block(parent: Node3D, at: Vector3, size: Vector3, color: String, glow := false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return part(parent, mesh, at, color, glow)

static func oval(parent: Node3D, at: Vector3, size: Vector3, color: String, glow := false) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radial_segments = 9
	mesh.rings = 4
	var node := part(parent, mesh, at, color, glow)
	node.scale = size
	return node

static func taper(parent: Node3D, at: Vector3, bottom: float, top: float, height: float, color: String, sides := 8, glow := false) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.radial_segments = sides
	mesh.rings = 0
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	return part(parent, mesh, at, color, glow)

static func rod(parent: Node3D, start: Vector3, end: Vector3, bottom: float, top: float, color: String) -> MeshInstance3D:
	var axis := end - start
	var node := taper(parent, (start + end) * 0.5, bottom, top, axis.length(), color, 6)
	node.quaternion = Quaternion(Vector3.UP, axis.normalized())
	return node

static func capsule(parent: CharacterBody3D, radius: float, height: float) -> void:
	var shape := CapsuleShape3D.new()
	shape.radius = radius
	shape.height = height
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = height * 0.5 + 0.035
	parent.add_child(collision)
