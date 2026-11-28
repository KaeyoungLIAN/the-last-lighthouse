extends Node3D
## Sheltered rafts of lily pads hug the inner shore, leaving rowing lanes open.
const Geo := preload("expedition_geography.gd")
var insects := MultiMesh.new()
var mote_material := StandardMaterial3D.new()
var elapsed := 0.
var rng := RandomNumberGenerator.new()
var colonies: Array[Vector3] = []
var _world

func build(world) -> void:
	_world=world
	rng.seed=260411
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for anchor in [Vector2(392,-7),Vector2(401,43),Vector2(472,-27),Vector2(492,31),Vector2(449,55)]:
		for i in 26:
			var point:Vector2=anchor+Vector2(rng.randfn(0,4.),rng.randfn(0,2.7))
			if Geo.lake_distance(point)>-.65 or world.ground_height(point.x,point.y)>Geo.LAKE_LEVEL-.06: continue
			var foot:=Vector3(point.x,Geo.LAKE_LEVEL+.055+rng.randf_range(0,.015),point.y)
			var radius:=rng.randf_range(.21,.51)
			var facing:=rng.randf()*TAU
			var leaf:=Color("82a58a").lerp(Color("a3af77"),rng.randf())
			for lobe in 9:
				var a:=facing+.42+lobe*(TAU-.72)/9.
				var b:=facing+.42+(lobe+1)*(TAU-.72)/9.
				var left:=foot+Vector3(cos(a)*radius,.008,sin(a)*radius*.82)
				var right:=foot+Vector3(cos(b)*radius,.008,sin(b)*radius*.82)
				_triangle(st,foot,left,right,leaf.darkened(.05 if lobe%2==0 else 0.))
			if i%5!=0: continue
			var flower:=foot+Vector3.UP*.055
			for petal in 7:
				var out:=Vector3(cos(facing+TAU*petal/7.),0,sin(facing+TAU*petal/7.))
				var flank:=out.cross(Vector3.UP)*radius*.145
				var middle:=flower+out*radius*.28+Vector3.UP*.043
				var tip:=flower+out*radius*.51+Vector3.UP*.082
				_triangle(st,flower,middle+flank,tip,Color("f6d7c1"))
				_triangle(st,flower,tip,middle-flank,Color("f0b6ad"))
	var surface:=StandardMaterial3D.new()
	surface.vertex_color_use_as_albedo=true
	surface.cull_mode=BaseMaterial3D.CULL_DISABLED
	surface.roughness=.88
	var bed:=MeshInstance3D.new()
	bed.mesh=st.commit()
	bed.material_override=surface
	bed.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bed)
	for id: String in ["forest","lake"]:
		for point: Vector2 in [Geo.CAMPS[id],Geo.HUNTS[id],Geo.ENTRANCES[id]]:
			colonies.append(Vector3(point.x,world.ground_height(point.x,point.y),point.y))
	insects.transform_format=MultiMesh.TRANSFORM_3D
	var mesh:=SphereMesh.new()
	mesh.radius=.035
	mesh.height=.066
	mesh.radial_segments=5
	mesh.rings=2
	insects.mesh=mesh
	insects.instance_count=24
	var lights:=MultiMeshInstance3D.new()
	lights.multimesh=insects
	mote_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mote_material.albedo_color=Color("fff0a3")
	lights.material_override=mote_material
	lights.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lights)

func _triangle(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,color: Color) -> void:
	st.set_color(color.srgb_to_linear())
	st.set_normal(Vector3.UP)
	for p: Vector3 in [a,b,c]: st.add_vertex(p)

func advance(delta: float,daylight: float,p: Vector2) -> void:
	if colonies.is_empty(): return
	var nearest:=colonies[0]
	for c in colonies:
		if Vector2(c.x,c.z).distance_squared_to(p)<Vector2(nearest.x,nearest.z).distance_squared_to(p): nearest=c
	if daylight>.70 or Vector2(nearest.x,nearest.z).distance_squared_to(p)>70*70:
		insects.visible_instance_count=0
		return
	elapsed+=delta
	insects.visible_instance_count=insects.instance_count
	for i in insects.instance_count:
		var angle:=i*2.39996
		var x:=nearest.x+cos(angle)*(4.+i*.31)+sin(elapsed*.53+angle)*.66
		var z:=nearest.z+sin(angle)*(4.+i*.31)+cos(elapsed*.39+angle)*.66
		var y:float=_world.ground_height(x,z)+.82+.51*sin(elapsed*.64+angle)
		var size:=.42+.58*smoothstep(-.7,.72,sin(elapsed*1.42+i*1.9))
		insects.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*size),Vector3(x,y,z)))
