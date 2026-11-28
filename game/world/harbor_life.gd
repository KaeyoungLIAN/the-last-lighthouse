extends Node3D
## Seabirds and wind-tugged bunting give the settlements movement at walking distance.

const COLORS := ["df906f","ecc77d","84b6ac","e9ddba","bd8584"]
var _gulls := MultiMesh.new()
var _roosts: Array[Vector3] = []
var _time := 0.0

func build(island) -> void:
	var flags := SurfaceTool.new()
	flags.begin(Mesh.PRIMITIVE_TRIANGLES)
	_bunting(island,flags,Vector2(-41.5,35.8),Vector2(-32.6,33.0),3.8)
	_bunting(island,flags,Vector2(-47,23.7),Vector2(-40.9,23.2),3.4)
	for id in ["outerport","windmill","bellcape"]:
		if island.POINTS.has(id):
			var town: Vector2 = island.POINTS[id]
			_bunting(island,flags,town+Vector2(-5.8,4.6),town+Vector2(4.7,5.6),3.6)
	var fabric := MeshInstance3D.new()
	fabric.mesh = flags.commit()
	var material := ShaderMaterial.new()
	material.shader = preload("res://world/harbor_cloth.gdshader")
	fabric.material_override = material
	add_child(fabric)

	var waters := [Vector2(-65,22),Vector2(8,-42),Vector2(50,32)]
	if island.POINTS.has("outerport"):
		waters.append(island.POINTS.outerport)
	for p: Vector2 in waters:
		_roosts.append(Vector3(p.x,island.ground_height(p.x,p.y)+9.0,p.y))
	_gulls.transform_format = MultiMesh.TRANSFORM_3D
	_gulls.mesh = island.landscape_mesh("HerringGull")
	_gulls.instance_count = _roosts.size()*3
	var flock := MultiMeshInstance3D.new()
	flock.multimesh = _gulls
	flock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(flock)
	_process(0)

func _beam(island,a: Vector3,b: Vector3,radius: float,color: String) -> void:
	var span := b-a
	var lateral := Vector2(span.x,span.z).length()
	island.model("5_100",(a+b)*.5,Vector3(radius,span.length(),radius),color,
		atan2(-span.z,span.x),false,atan2(lateral,span.y))

func _line_point(a: Vector3,b: Vector3,t: float) -> Vector3:
	return a.lerp(b,t)-Vector3.UP*(1.7*t*(1.0-t))

func _bunting(island,st: SurfaceTool,left: Vector2,right: Vector2,height: float) -> void:
	var a := Vector3(left.x,island.ground_height(left.x,left.y)+height,left.y)
	var b := Vector3(right.x,island.ground_height(right.x,right.y)+height+.16,right.y)
	for top: Vector3 in [a,b]:
		_beam(island,top-Vector3.UP*(height+.4),top+Vector3.UP*.12,.062,"#867455")
		island.model("6_46",top+Vector3.UP*.16,Vector3(.085,.12,.085),"#bf965e")
	var count := ceili(left.distance_to(right)/.69)
	for i in count:
		var t := float(i)/count
		var start := _line_point(a,b,t)
		var end := _line_point(a,b,float(i+1)/count)
		_beam(island,start,end,.014,"#7f694d")
		var c := Color(COLORS[i % COLORS.size()]).srgb_to_linear()
		var center := (start+end)*.5 + Vector3(.06,-.43-.09*sin(i*3.4),.10)
		for part in 3:
			st.set_color(c)
			st.set_normal(Vector3(.22,.7,.6).normalized())
			st.set_uv(Vector2(0,1 if part==2 else 0))
			st.add_vertex([start.lerp(end,.09),start.lerp(end,.88),center][part])

func _process(delta: float) -> void:
	_time += delta
	for i in _gulls.instance_count:
		var t := _time*(.15+.013*(i%3))+i*2.13
		var roost: Vector3 = _roosts[floori(i/3.0)]
		var radius := 10.0+(i%3)*2.3
		var p := roost+Vector3(cos(t)*radius,sin(t*1.91+i)*1.2+(i%3)*.9,sin(t)*radius*.71)
		var basis := Basis(Vector3.UP,atan2(sin(t),-cos(t)*.71))*Basis(Vector3.BACK,.17+.13*sin(t*2.0))
		_gulls.set_instance_transform(i,Transform3D(basis,p))
