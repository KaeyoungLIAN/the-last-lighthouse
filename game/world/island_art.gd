extends Node3D
## Static island dressing is instanced by silhouette and uses per-instance palette colors.

var _batches: Dictionary = {}
var _geometry: Dictionary = {}
var _art_material := StandardMaterial3D.new()
var _gold_material := StandardMaterial3D.new()
var _solid := StaticBody3D.new()
var _blocked_circles: Array[Vector3] = []
var _blocked_boxes: Array[Rect2] = []

func prepare_art() -> void:
	_art_material.vertex_color_use_as_albedo = true
	_art_material.roughness = 0.93
	_gold_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_gold_material.vertex_color_use_as_albedo = true
	_solid.name = "IslandObstacles"
	add_child(_solid)

func _triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, outward: Vector3) -> void:
	var normal := (c - a).cross(b - a).normalized()
	var points := [a, b, c]
	if normal.dot(outward) < 0.0:
		normal = -normal
		points = [a, c, b]
	for point: Vector3 in points:
		st.set_normal(normal)
		st.add_vertex(point)

func _frustum(sides: int, top: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in sides:
		var t := float(i) * TAU / sides
		var u := float(i + 1) * TAU / sides
		var a := Vector3(cos(t), -0.5, sin(t))
		var b := Vector3(cos(u), -0.5, sin(u))
		var c := Vector3(b.x * top, 0.5, b.z * top)
		var e := Vector3(a.x * top, 0.5, a.z * top)
		var side := Vector3(a.x + b.x, 0, a.z + b.z)
		_triangle(st, a, b, c, side)
		if top > 0.001:
			_triangle(st, a, c, e, side)
			_triangle(st, Vector3.UP * 0.5, e, c, Vector3.UP)
		_triangle(st, Vector3.DOWN * 0.5, a, b, Vector3.DOWN)
	return st.commit()

func _gable() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a := Vector3(-0.5, -0.5, -0.5)
	var b := Vector3(0.5, -0.5, -0.5)
	var c := Vector3(0.0, 0.5, -0.5)
	var dz := Vector3.BACK
	_triangle(st, a,b,c,Vector3.FORWARD)
	_triangle(st, a+dz,b+dz,c+dz,Vector3.BACK)
	for pair: Array in [[a,c],[c,b],[b,a]]:
		var p: Vector3 = pair[0]
		var q: Vector3 = pair[1]
		var face := Vector3(p.x+q.x,(p.y+q.y) + 0.1,0)
		_triangle(st,p,q,q+dz,face)
		_triangle(st,p,q+dz,p+dz,face)
	return st.commit()

func model(form: String, pos: Vector3, dims: Vector3, html: String, yaw: float = 0.0, glow: bool = false, tilt: float = 0.0) -> void:
	if not _geometry.has(form):
		if form == "box":
			_geometry[form] = BoxMesh.new()
		elif form == "roof":
			_geometry[form] = _gable()
		else:
			var parts := form.split("_")
			_geometry[form] = _frustum(int(parts[0]),float(parts[1])/100.0)
	var key := form + ("*" if glow else "")
	if not _batches.has(key):
		_batches[key] = []
	var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.FORWARD, tilt) * Basis.from_scale(dims)
	var color := Color(html)
	if not glow:
		color = color.srgb_to_linear().lerp(color,.27)
	_batches[key].append([Transform3D(basis,pos), color])

func finish_art() -> void:
	for key: String in _batches:
		var group: Array = _batches[key]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = true
		multimesh.mesh = _geometry[key.trim_suffix("*")]
		multimesh.instance_count = group.size()
		for i in group.size():
			multimesh.set_instance_transform(i,group[i][0])
			multimesh.set_instance_color(i,group[i][1])
		var node := MultiMeshInstance3D.new()
		node.multimesh = multimesh
		node.name = "IslandDressing" 
		node.material_override = _gold_material if key.ends_with("*") else _art_material
		add_child(node)
	_batches.clear()

func block_disc(loc: Vector3, radius: float, height: float) -> void:
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = loc + Vector3.UP * height * 0.5
	_solid.add_child(col)
	_blocked_circles.append(Vector3(loc.x,loc.z,radius))

func block_box(loc: Vector3, width: float, depth: float, height: float) -> void:
	var shape := BoxShape3D.new()
	shape.size = Vector3(width,height,depth)
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = loc + Vector3.UP * height * 0.5
	_solid.add_child(col)
	_blocked_boxes.append(Rect2(Vector2(loc.x - width * 0.5, loc.z - depth * 0.5),Vector2(width,depth)))

func blocked(p: Vector2) -> bool:
	for box in _blocked_boxes:
		if box.has_point(p):
			return true
	for disc in _blocked_circles:
		if p.distance_squared_to(Vector2(disc.x,disc.y)) < disc.z * disc.z:
			return true
	return false
