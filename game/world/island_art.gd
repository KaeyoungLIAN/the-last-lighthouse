extends Node3D
## Static island dressing is instanced by silhouette and uses per-instance palette colors.

var _building_room := false
var _room_art: Array[Node3D] = []
var _batches: Dictionary = {}
var _geometry: Dictionary = {}
var _art_material := StandardMaterial3D.new()
var _gold_material := StandardMaterial3D.new()
var _solid := StaticBody3D.new()
var _blocked_circles := {}
var _blocked_boxes: Array[Rect2] = []

func prepare_art() -> void:
	# Import once and share the mesh resources with the island's spatial batches.
	var library := preload("res://art/models/landscape.glb").instantiate()
	for child in library.get_children():
		if child is MeshInstance3D:
			_geometry[String(child.name)] = child.mesh
	library.free()
	_art_material.vertex_color_use_as_albedo = true
	_art_material.roughness = 0.93
	_gold_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_gold_material.vertex_color_use_as_albedo = true
	_solid.name = "IslandObstacles"
	add_child(_solid)

func landscape_mesh(model_name: String) -> Mesh:
	return _geometry[model_name]

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
	st.set_color(Color.WHITE)
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
	# Stagger the slates, with a small projecting lip at the downhill edge.
	var rng := RandomNumberGenerator.new()
	rng.seed = 8137
	for side: float in [-1.0, 1.0]:
		for row in 8:
			var upper := row / 16.0
			var lower := (row + 1) / 16.0
			for tile in range(-1, 10):
				var start := (tile + .5 * (row % 2)) * .10 - .5
				var z0 := maxf(start, -.5) + .001
				var z1 := minf(start + .10, .5) - .001
				if z1 <= z0:
					continue
				var lip := rng.randf_range(.014, .023)
				var edge := lower + rng.randf_range(-.002, .002)
				var tl := Vector3(side * upper, .503 - 2.0 * upper, z0)
				var tr := Vector3(tl.x, tl.y, z1)
				var bl := Vector3(side * edge, .50 - 2.0 * edge + lip, z0)
				var br := Vector3(bl.x, bl.y, z1)
				var value := rng.randf_range(.82, 1.10)
				st.set_color(Color(value * .98, value, value * 1.01))
				_triangle(st,tl,tr,br,Vector3.UP)
				_triangle(st,tl,br,bl,Vector3.UP)
				st.set_color(Color(.69,.72,.71))
				_triangle(st,bl,br,br - Vector3.UP * lip,Vector3.RIGHT * side)
				_triangle(st,bl,br - Vector3.UP * lip,bl - Vector3.UP * lip,Vector3.RIGHT * side)
	return st.commit()

func _foliage(pine: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var last: Array[Vector3] = []
	var sides := 16 if pine else 10
	var radii := [.08, 1.0, .67, .05] if pine else [.27, .90, 1.0, .69, .12]
	var levels := [-.28, -.28, .07, .50] if pine else [-.48, -.30, .06, .37, .50]
	for band in radii.size():
		var ring: Array[Vector3] = []
		for i in sides:
			var angle := TAU * i / sides + (.09 * band if not pine else 0.0)
			var radius: float = radii[band] * (1.0 + .115 * sin(i * 2.34 + band * .65))
			var y: float = levels[band] + .045 * sin(i * 1.85 + band)
			if pine and band == 1:
				if i % 2 == 0:
					y -= .17
				else:
					radius *= .68
					y += .10
			ring.append(Vector3(radius*cos(angle),y,radius*sin(angle)))
		if band > 0:
			for i in sides:
				var j := (i + 1) % sides
				var outward := ring[i] + ring[j]
				outward.y = levels[band] + levels[band-1]
				var pigment := .73 + .065 * band + .052 * sin(i * 2.27 + band)
				st.set_color(Color(pigment, pigment, pigment * .98))
				_triangle(st,last[i],last[j],ring[j],outward)
				_triangle(st,last[i],ring[j],ring[i],outward)
		if band == 0 or band == radii.size()-1:
			var normal := Vector3.DOWN if band == 0 else Vector3.UP
			st.set_color(Color(.74,.76,.74) if band == 0 else Color.WHITE)
			for i in sides:
				_triangle(st,ring[i],ring[(i+1)%sides],Vector3.UP*levels[band],normal)
		last = ring
	return st.commit()

func model(form: String, pos: Vector3, dims: Vector3, html: String, yaw: float = 0.0, glow: bool = false, tilt: float = 0.0) -> void:
	if not _geometry.has(form):
		if form == "box":
			_geometry[form] = BoxMesh.new()
		elif form == "roof":
			_geometry[form] = _gable()
		elif form == "crown" or form == "pine":
			_geometry[form] = _foliage(form == "pine")
		else:
			var parts := form.split("_")
			_geometry[form] = _frustum(int(parts[0]),float(parts[1])/100.0)
	var key := "%s%s|%d,%d" % [form,("*" if glow else ""),floori(pos.x/64.0),floori(pos.z/64.0)]
	if _building_room:
		key += "|room"
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
		var form := key.get_slice("|",0)
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = true
		multimesh.mesh = _geometry[form.trim_suffix("*")]
		multimesh.instance_count = group.size()
		for i in group.size():
			multimesh.set_instance_transform(i,group[i][0])
			multimesh.set_instance_color(i,group[i][1])
		var node := MultiMeshInstance3D.new()
		node.multimesh = multimesh
		node.name = "IslandDressing" 
		node.material_override = _gold_material if form.ends_with("*") else _art_material
		add_child(node)
		if key.ends_with("|room"):
			node.hide()
			_room_art.append(node)
	_batches.clear()

func block_disc(loc: Vector3, radius: float, height: float) -> void:
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = loc + Vector3.UP * height * 0.5
	_solid.add_child(col)
	var circle := Vector3(loc.x,loc.z,radius)
	for z in range(floori((loc.z-radius)/16),floori((loc.z+radius)/16)+1):
		for x in range(floori((loc.x-radius)/16),floori((loc.x+radius)/16)+1):
			var cell := Vector2i(x,z)
			if not _blocked_circles.has(cell):
				_blocked_circles[cell] = []
			_blocked_circles[cell].append(circle)

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
	for disc: Vector3 in _blocked_circles.get(Vector2i((p/16.0).floor()),[]):
		if p.distance_squared_to(Vector2(disc.x,disc.y)) < disc.z * disc.z:
			return true
	return false
