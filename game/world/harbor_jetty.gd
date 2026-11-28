extends MeshInstance3D
## The dock is drawn in local metres around the centre of its existing collision deck.
const TIMBER := preload("res://art/greybay/jetty_timber.png")
const WHITE_PATCH := Vector2(.5, .95)
var timber := SurfaceTool.new()
var fittings := SurfaceTool.new()

func _init() -> void:
	timber.begin(Mesh.PRIMITIVE_TRIANGLES)
	fittings.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wood := StandardMaterial3D.new()
	wood.albedo_texture = TIMBER
	wood.vertex_color_use_as_albedo = true
	wood.vertex_color_is_srgb = true
	wood.roughness = .86
	timber.set_material(wood)
	var iron := StandardMaterial3D.new()
	iron.vertex_color_use_as_albedo = true
	iron.vertex_color_is_srgb = true
	iron.metallic = .61
	iron.roughness = .54
	fittings.set_material(iron)
	var rng := RandomNumberGenerator.new()
	rng.seed = 15113
	for i in 36:
		var z := -5.425 + i * .31
		var gray := rng.randf_range(.88, 1.0)
		_board(Vector3(0, 0, z), Vector3(3.65,.22,.298), i % 8, Color(gray,gray,gray))
		for side in [-1.0, 1.0]:
			var nail := Vector3(side * (1.52 + rng.randf_range(-.025,.025)), .113, z)
			_rail(fittings, [nail, nail + Vector3.UP*.011], .022, Color("69706a"), 6)
	for side in [-1.0, 1.0]:
		_board(Vector3(side*1.54,-.25,0),Vector3(.21,.30,11.12),4,Color("a7a69e"))
		for bay in 5:
			var z := -5.06 + bay * 2.46
			var p := Vector3(side*1.66,0,z)
			var top := .54 if bay == 0 or bay == 3 else .22
			# The wet tide line is below the dry, sun-bleached timber.
			_rail(timber, [p + Vector3.DOWN*3.35, p + Vector3.DOWN*1.74], .14, Color("4f6158"), 10)
			_rail(timber, [p + Vector3.DOWN*1.74, p + Vector3.UP*top], .14, Color("726e60"), 10)
			var cap := p + Vector3.UP*top
			_rail(fittings, [cap - Vector3.UP*.095, cap - Vector3.UP*.052], .145, Color("6f756e"), 10)
			_disk(cap + Vector3.UP*.002, .14, Color("877961"))
			if top > .3:
				var lashing := PackedVector3Array()
				for step in 42:
					var a := step * TAU / 14.0
					lashing.append(p + Vector3(cos(a)*.153,.24 + step*.0024,sin(a)*.153))
				_rail(timber,lashing,.021,Color("a08862"),6)
	# Extra line is coiled by the bollard, tucked outside the walking lane.
	var rope := PackedVector3Array()
	for step in 80:
		var a := step * TAU / 22.0
		var radius := .135 + step*.0031
		rope.append(Vector3(-1.13 + cos(a)*radius,.145,-4.46 + sin(a)*radius*.76))
	rope.append(Vector3(-1.50,.15,-4.76))
	rope.append(Vector3(-1.67,.28,-4.91))
	_rail(timber,rope,.026,Color("a9936d"),7)
	var combined := timber.commit()
	fittings.commit(combined)
	mesh = combined

func _triangle(surface: SurfaceTool, points: Array, uv: Array, normal: Vector3, color: Color) -> void:
	var outward: bool = (points[1]-points[0]).cross(points[2]-points[0]).dot(normal) > 0
	for idx in ([0,2,1] if outward else [0,1,2]):
		surface.set_normal(normal)
		surface.set_color(color)
		surface.set_uv(uv[idx])
		surface.add_vertex(points[idx])

func _quad(surface: SurfaceTool, corners: Array, uv: Array, normal: Vector3, color: Color) -> void:
	for t in [[0,1,2],[0,2,3]]:
		_triangle(surface,[corners[t[0]],corners[t[1]],corners[t[2]]],[uv[t[0]],uv[t[1]],uv[t[2]]],normal,color)

func _board(center: Vector3, size: Vector3, strip: int, color: Color) -> void:
	var half := size * .5
	var caps := []
	for level in [-half.y, half.y-.014, half.y]:
		var lip: float = .014 if level == half.y else 0.0
		var ring := []
		for sign_pair in [Vector2(-1,-1),Vector2(-1,1),Vector2(1,1),Vector2(1,-1)]:
			ring.append(center+Vector3(sign_pair.x*(half.x-lip),level,sign_pair.y*(half.z-lip)))
		caps.append(ring)
	var uv := []
	for v: Vector3 in caps[2]:
		var s := (v-center)/size + Vector3.ONE*.5
		var along := s.x if size.x>=size.z else s.z
		var across := s.z if size.x>=size.z else s.x
		uv.append(Vector2(.016 + .968*along,(strip+.07+.86*across)/9.0))
	_quad(timber,caps[2],uv,Vector3.UP,color)
	for i in 4:
		var j := (i+1)%4
		var mid: Vector3 = (caps[0][i]+caps[0][j])*.5-center
		var face_normal := Vector3(mid.x,0,mid.z).normalized()
		var grain := [Vector2(.02,(strip+.15)/9),Vector2(.98,(strip+.15)/9),Vector2(.98,(strip+.70)/9),Vector2(.02,(strip+.70)/9)]
		for k in 2:
			var normal := face_normal if k==0 else (face_normal+Vector3.UP).normalized()
			_quad(timber,[caps[k][i],caps[k][j],caps[k+1][j],caps[k+1][i]],grain,normal,color)

func _rail(surface: SurfaceTool, path: PackedVector3Array, radius: float, color: Color, sides: int) -> void:
	var rings := []
	for i in path.size():
		var axis := (path[mini(i+1,path.size()-1)]-path[maxi(0,i-1)]).normalized()
		var ref_dir := Vector3.FORWARD if absf(axis.dot(Vector3.UP))>.92 else Vector3.UP
		var u := axis.cross(ref_dir).normalized()
		var v := axis.cross(u)
		var ring := PackedVector3Array()
		for j in sides:
			var a := TAU*j/sides
			ring.append(path[i] + radius*(cos(a)*u+sin(a)*v))
		rings.append(ring)
	for i in range(path.size()-1):
		for j in sides:
			var k := (j+1)%sides
			var normal: Vector3 = (rings[i][j]+rings[i][k]-2.0*path[i]).normalized()
			_quad(surface,[rings[i][j],rings[i][k],rings[i+1][k],rings[i+1][j]],
				[WHITE_PATCH,WHITE_PATCH,WHITE_PATCH,WHITE_PATCH],normal,color)
	if surface == fittings and sides == 6:
		for j in sides:
			_triangle(surface,[path[-1],rings[-1][j],rings[-1][(j+1)%sides]],
				[WHITE_PATCH,WHITE_PATCH,WHITE_PATCH],Vector3.UP,color)

func _disk(center: Vector3, radius: float, color: Color) -> void:
	for i in 10:
		var a := TAU*i/10
		var b := TAU*(i+1)/10
		_triangle(timber,[center,center + Vector3(cos(a),0,sin(a))*radius,center + Vector3(cos(b),0,sin(b))*radius],
			[WHITE_PATCH,WHITE_PATCH,WHITE_PATCH],Vector3.UP,color)
