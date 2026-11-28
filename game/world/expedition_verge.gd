extends Node3D
## The same terrain survey drives the near-camera plants and the trails they fringe.
const Geo := preload("expedition_geography.gd")
const Coast := preload("coastal_plants.gd")

class VergePlants extends Coast:
	func make_species(id: String, secondary: bool) -> int:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		match id:
			"snow":
				if secondary: _cushion(st,Color("738b80"),Color("c9c3a5"),.15)
				else: _shale(st)
			"tide":
				if secondary: _shells(st)
				else: _wrack(st)
			"volcano":
				if secondary: _shards(st)
				else: _scoria(st)
			"desert":
				if secondary: _thorn(st)
				else: _agave(st)
			"lake":
				if secondary: _sedge(st)
				else: _rushes(st)
			"forest":
				if secondary: _waxcaps(st)
				else: _ferns(st)
		_meshes.append(st.commit())
		return _meshes.size()-1

	func _facet(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,color: Color) -> void:
		var normal := (c-a).cross(b-a).normalized()
		if normal.y < 0:
			normal = -normal
		for v: Vector3 in [a,b,c]:
			_vertex(st,v,normal.lerp(Vector3.UP,.23).normalized(),color)

	func _leaf(st: SurfaceTool,a: Vector3,b: Vector3,width: float,color: Color) -> void:
		var side := (b-a).cross(Vector3.UP).normalized()*width
		var mid := a.lerp(b,.53)
		var vein := mid+Vector3.UP*width*.35
		_facet(st,a,vein,mid+side,color)
		_facet(st,mid+side,vein,b,color.lightened(.07))
		_facet(st,a,mid-side,vein,color.darkened(.12))
		_facet(st,vein,mid-side,b,color)

	func _seed(st: SurfaceTool,center: Vector3,radius: float,height: float,tint: Color) -> void:
		for j in 6:
			var a := center+Vector3(cos(j*TAU/6),0,sin(j*TAU/6))*radius
			var b := center+Vector3(cos((j+1)*TAU/6),0,sin((j+1)*TAU/6))*radius
			_facet(st,a,b,center+Vector3.UP*height,tint.lightened(.025*j))
			_facet(st,a,center-Vector3.UP*height*.69,b,tint.darkened(.08))

	func _cushion(st: SurfaceTool,leaf_color: Color,accent: Color,height: float) -> void:
		for i in 15:
			var dir := Vector3(cos(i*2.40),0,sin(i*2.40))
			var start := dir*.12
			var tip := dir*(.31+.10*sin(i))+Vector3.UP*(height+.11*cos(i))
			_leaf(st,start,tip,.065,leaf_color.lightened((i%4)*.025))
			if i%3 == 1:
				_seed(st,tip+Vector3.UP*.035,.055,.055,accent)

	func _ferns(st: SurfaceTool) -> void:
		for i in 7:
			var axis := Vector3(cos(i*2.41),0,sin(i*2.41))
			var lateral := axis.cross(Vector3.UP)
			var tip := axis*.69+Vector3.UP*(.54+.16*cos(i))
			_leaf(st,Vector3.ZERO,tip,.024,Color("8ba476"))
			for j in 6:
				var t := .15+.12*j
				var p := tip*t+Vector3.UP*sin(t*PI)*.11
				var length := .22*sin(t*PI)+.03
				for signum: float in [-1.,1.]:
					_leaf(st,p,p+(axis*.36+lateral*signum)*length+Vector3.UP*.035,.036*(1.-.45*t),Color("659276").lightened(.14*t))

	func _rushes(st: SurfaceTool) -> void:
		for i in 9:
			var dir := Vector3(cos(i*2.4),0,sin(i*2.4))
			var p := dir*(.10+.12*absf(sin(i)))
			var height := .58+.38*absf(cos(i))
			_leaf(st,p,p+dir*.36+Vector3.UP*height*.78,.043,Color("82a079"))
			if i%2==0:
				var top := p+Vector3.UP*height+dir*.06
				_leaf(st,p,top,.015,Color("8d9565"))
				_seed(st,top,.048,.14,Color("a16e4f"))

	func _shells(st: SurfaceTool) -> void:
		for i in 4:
			var center := Vector3(sin(i*2.3)*.25,.018,cos(i*2.3)*.22)
			var radius := .13+.035*(i%2)
			for j in 8:
				var angle := -.96+j*.24
				var a := center+Vector3(sin(angle),.18,cos(angle))*radius
				var b := center+Vector3(sin(angle+.24),.18,cos(angle+.24))*radius
				var ridge := center.lerp((a+b)*.5,.66)+Vector3.UP*.035
				var tint := Color("efd5b6") if (i+j)%2==0 else Color("cdac9e")
				_facet(st,center,ridge,a,tint)
				_facet(st,center,b,ridge,tint.darkened(.09))
				_facet(st,a,ridge,b,tint.lightened(.08))


	func _shale(st:SurfaceTool) -> void:
		for i in 6:
			var a:=i*2.40
			var f:=Vector3(cos(.26+i*.14),0,sin(.26+i*.14))
			var side:=Vector3(-f.z,0,f.x)
			var o:=Vector3(cos(a)*.46,.025,sin(a)*.29)
			var r:=.20+.13*absf(cos(i))
			var top:=o+f*.09+Vector3.UP*(.095+.070*cos(i))
			var toe:=o-f*r
			var left:=o+f*.09+side*r*.53
			var right:=o+f*.14-side*r*.59
			var edge:=o+f*r*1.13+Vector3.UP*.03
			_facet(st,toe,left,top,Color("88999b"))
			_facet(st,toe,top,right,Color("74888e"))
			_facet(st,left,edge,top,Color("b1bfc0"))
			_facet(st,top,edge,right,Color("95a8ac"))

	func _wrack(st:SurfaceTool) -> void:
		for i in 6:
			var f:=Vector3(cos(i*.49),0,sin(i*.49))
			var side:=Vector3(-f.z,0,f.x)
			var o:=(i-2.5)*side*.05
			var tip:=o+f*(.45+.18*sin(i))+side*.14
			var mid:=o.lerp(tip,.55)+Vector3.UP*(.09+.04*sin(i))
			var tint:=Color("637a56").lightened(.035*(i%3))
			_leaf(st,o,mid,.043,tint)
			_leaf(st,mid,tip+Vector3.UP*.03,.052,tint)
			for k in 3:
				var bud:=o.lerp(tip,.25+.21*k)+Vector3.UP*.065
				_leaf(st,bud,bud+side*(.15-.03*k)+f*.12,.045,tint)
				if (i+k)%3==1:_seed(st,bud+side*.055,.054,.046,Color("9c985f"))

	func _scoria(st:SurfaceTool) -> void:
		for k in 3:
			var o:=Vector3(cos(k*2.4)*.31,.006,sin(k*2.4)*.24)
			var r:=.27-.056*k
			for i in 7:
				var f:=Vector3(cos(i*TAU/7),0,sin(i*TAU/7))
				var g:=Vector3(cos((i+1)*TAU/7),0,sin((i+1)*TAU/7))
				var crest:=o+f*r*.74+Vector3.UP*r*(.55+.16*sin(i))
				var next:=o+g*r*.74+Vector3.UP*r*(.55+.16*sin(i+1))
				var pit:=o+Vector3.UP*r*.29+f*r*.26
				_facet(st,o+f*r,o+g*r,crest,Color("5d4f50"))
				_facet(st,crest,o+g*r,next,Color("76615c"))
				_facet(st,crest,next,pit,Color("8b7166"))
				_facet(st,pit,next,o+Vector3.UP*r*.25,Color("4e4548"))

	func _shards(st:SurfaceTool) -> void:
		for k in 5:
			var f:=Vector3(cos(k*2.4),0,sin(k*2.4))
			var side:=Vector3(-f.z,0,f.x)
			var o:=f*.20
			var tip:=o+f*.15+Vector3.UP*(.17+.28*absf(sin(k*2)))
			var ridge:=o+side*.037+Vector3.UP*.18
			_facet(st,o-f*.07-side*.10,tip,ridge,Color("514e59"))
			_facet(st,ridge,tip,o+side*.10,Color("857680"))
			_facet(st,o+side*.10,tip,o+f*.15,Color("58555e"))

	func _agave(st:SurfaceTool) -> void:
		for i in 10:
			var f:=Vector3(cos(i*2.40),0,sin(i*2.40))
			var inner:=i>=6
			var bend:=f*(.15 if inner else .27)+Vector3.UP*(.34 if inner else .23)
			var tip:=f*(.29 if inner else .63)+Vector3.UP*(.49+.09*cos(i) if inner else .12+.16*cos(i))
			var side:=f.cross(Vector3.UP)*(.066 if inner else .085)
			var ridge:=bend+Vector3.UP*.033
			var tint:=Color("7c9679") if inner else Color("899779")
			_facet(st,Vector3.ZERO,bend+side,ridge,tint.darkened(.16))
			_facet(st,Vector3.ZERO,ridge,bend-side,tint)
			_facet(st,bend+side,tip,ridge,tint)
			_facet(st,ridge,tip,bend-side,tint.lightened(.13))

	func _thorn(st:SurfaceTool) -> void:
		for i in 8:
			var f:=Vector3(cos(i*2.41),0,sin(i*2.41))
			var foot:=f*.08
			var joint:=f*(.18+.06*sin(i))+Vector3.UP*.36
			var tip:=f*(.34+.12*sin(i))+Vector3.UP*(.63+.32*cos(i))
			_leaf(st,foot,joint,.032,Color("897958"))
			_leaf(st,joint,tip,.019,Color("ad9265"))
			_leaf(st,joint,joint+f*.24+Vector3.UP*.10,.016,Color("a58a61"))
			if i in [1,5]:_seed(st,tip,.045,.091,Color("c68b65"))

	func _sedge(st:SurfaceTool) -> void:
		for i in 7:
			var f:=Vector3(cos(i*2.40),0,sin(i*2.40))
			var mid:=f*.30+Vector3.UP*(.37+.10*sin(i))
			var tip:=f*(.53+.11*cos(i))+Vector3.UP*.10
			_leaf(st,Vector3.ZERO,mid,.067,Color("758972"))
			_leaf(st,mid,tip,.056,Color("9dae90"))

	func _waxcaps(st:SurfaceTool) -> void:
		for i in 4:
			var foot:=Vector3(cos(i*2.40)*.28,0,sin(i*2.40)*.27)
			var top:=foot+Vector3(.03,.19+.09*cos(i),.021)
			for dir:Vector3 in [Vector3.RIGHT,Vector3.BACK]:
				_facet(st,foot-dir*.021,foot+dir*.021,top+dir*.027,Color("bda68b"))
				_facet(st,foot-dir*.021,top+dir*.027,top-dir*.027,Color("bda68b"))
			_seed(st,top,.13+.03*sin(i),.085,Color("c58764"))

var plants:=VergePlants.new()
var rng:=RandomNumberGenerator.new()
var species:Dictionary={}

func build(world) -> void:
	name="ExpeditionWaysides"
	rng.seed=603127
	for id:String in Geo.ZONES:
		species[id]=[plants.make_species(id,false),plants.make_species(id,true)]
	for id:String in Geo.ZONES:
		var route:Array=Geo.ROUTES[id]
		_plant_route(world,route.slice(maxi(0,route.find(Geo.ENTRANCES[id])-2)),false)
	for route:Array in Geo.OUTER_ROUTES.values():_plant_route(world,route,true)
	_plant_route(world,Geo.LAKE_SHORE_ROAD,true)
	_plant_route(world,Geo.TIDAL_SPIT,false)
	plants.finish(self)
	plants=null

func _pick(mix:Dictionary) -> String:
	var t:=rng.randf()
	for key:String in mix:
		t-=float(mix[key])
		if t<=0:return key
	return str(mix.keys().back())

func _plant_route(world,path:Array,open_country:bool) -> void:
	for i in range(1,path.size()):
		var a:Vector2=path[i-1]
		var b:Vector2=path[i]
		var f:=a.direction_to(b)
		var side:=f.orthogonal()
		var distance:=a.distance_to(b)
		var step:=rng.randf_range(.5,4.2)
		while step<distance:
			var sign_:float=-1.0 if rng.randf()<.5 else 1.0
			var mid:=a+f*step+side*sign_*rng.randf_range(3.35,12.5 if open_country else 8.4)
			step+=rng.randf_range(8.0,18.5) if open_country else rng.randf_range(3.4,8.8)
			var mix:=Geo.region_mix(mid)
			var id:=_pick(mix)
			if not species.has(id):continue
			var dense:=id in ["tide","lake","forest"]
			var secondary:=rng.randf()<(.37 if dense else .22)
			var kind:int=species[id][1 if secondary else 0]
			var count:=rng.randi_range(5,12) if dense else rng.randi_range(2,6)
			# Wrack follows tide marks, scree falls in fans and undergrowth banks occupy
			# only one shoulder at a time; the intervals between colonies stay open.
			var along:float=rng.randf_range(1.65,4.5)
			var depth:float=rng.randf_range(.55,2.30)
			for k in count:
				var p:=mid+f*rng.randfn(0.,along*.60)+side*rng.randfn(0.,depth*.62)
				if not world.is_walkable(p.x,p.y) or world._road_distance(p)<1.55:continue
				var y:float=world.ground_height(p.x,p.y)
				if y<.40 or (id=="lake" and Geo.lake_distance(p)<.85):continue
				if id=="tide" and y>2.8 and not secondary:continue
				if id=="volcano" and Geo.hazard_at(p)=="lava":continue
				var angle:=rng.randf()*TAU
				if id in ["tide","snow"]:angle=f.angle()+rng.randf_range(-.42,.42)
				plants.plant(kind,Vector3(p.x,y+.013,p.y),rng.randf_range(.66,1.54),angle)
