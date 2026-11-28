extends RefCounted
## Indexed terrain tiles use the same triangles for rendering, collision and gameplay height queries.
const Geo := preload("expedition_geography.gd")
const OldSurvey := preload("island_survey.gd")
const TILE := 48
const WATER := -3.6
var _heights := {}
var _steps := {}
var _span_cells := {}
var _grade_cells := {}
var _flat_centers := {}
var _ground_material := ShaderMaterial.new()

func build(w) -> void:
	_ground_material.shader=preload("expedition_ground.gdshader")
	_ground_material.set_shader_parameter("ground_pigments",preload("res://art/terrain/ground_pigments.png"))
	_ground_material.set_shader_parameter("harbor_flagstones",preload("res://art/terrain/harbor_flagstones.png"))
	for id: String in Geo.ZONES:
		_flat_centers[id]=[]
		for pair: Array in [[Geo.CAMPS[id],7.0],[Geo.HUNTS[id],7.5],[Geo.ARENAS[id],13.0]]:
			var at: Vector2=pair[0]
			_flat_centers[id].append([at,pair[1],_relief(id,at)])
	for route: Array in Geo.ROUTES.values()+Geo.OUTER_ROUTES.values()+[Geo.LAKE_SHORE_ROAD]:
		_index_grade(w,route)
	# All terrain shares one surface. The 2 m survey around gameplay features
	# meets the 4 m backcountry grid at precisely interpolated boundary vertices.
	for z in range(floori(Geo.BOUNDS.position.y/TILE),ceili(Geo.BOUNDS.end.y/TILE)):
		for x in range(floori(Geo.BOUNDS.position.x/TILE),ceili(Geo.BOUNDS.end.x/TILE)):
			var center:=Vector2(x+.5,z+.5)*TILE
			if Geo.mainland_distance(center)<-57: continue
			var fine:=Rect2(-130,-171,422,353).has_point(center)
			for id: String in Geo.HUNTS:
				if center.distance_squared_to(Geo.HUNTS[id]) < 87*87: fine=true
			if center.distance_squared_to(Geo.LAKE_CENTER)<102*102: fine=true
			_steps[Vector2i(x,z)]=2 if fine else 4
	for tile: Vector2i in _steps:
		_make_tile(w,tile,_steps[tile])
	_forest_bridges(w)
	_lake_water(w)
	_lake_piers(w)


func _hill(p: Vector2,center: Vector2,width: Vector2) -> float:
	return maxf(0,1.0-((p-center)/width).length())

func _spine(p: Vector2,peak: Vector2,axis: float,width: Vector2) -> float:
	var q := (p-peak).rotated(axis)/width
	q.x += .18*q.y + .074*sin(q.y*6)
	var ledge := maxf(absf(q.x)*.97+absf(q.y)*.48, absf(q.y)*1.09+absf(q.x)*.44)
	var notch := .14*absf(sin(q.x*9.0+q.y*3.4))*minf(1.0,ledge*3.2)
	return maxf(0,1.0-ledge-notch)

func _caldera(p: Vector2) -> float:
	# An eroded shield volcano with a breached eastern lip, overlapping rim
	# fragments and a secondary western neck. The original glow vents lie in the bowl.
	var local:=(p-Vector2(-288,352)).rotated(-.22)
	var q:=local/Vector2(70,61)
	var radius:=q.length()
	if radius>1.65: return 0
	var angle:=q.angle()
	var radius_offset:=radius/(1.0+.090*sin(3*angle+.8)+.057*cos(5*angle-.35))
	var shield:=37.0*(1.0-smoothstep(.28,1.11,radius_offset))
	var bowl:=14.8*(1.0-smoothstep(.14,.37,radius_offset))
	var rim_r:=.36+.043*sin(angle*3-.4)+.025*cos(angle*7)
	var rim_profile:=exp(-pow((radius_offset-rim_r)/.11,2))
	var breach:=1.0-smoothstep(.11,.78,absf(wrapf(angle+.75,-PI,PI)))
	var rim_height:=16+7*sin(angle*3.0+.7)+3.5*cos(angle*7-.3)
	var rim:=rim_profile*rim_height*(1.0-.88*breach)
	var chute:=9.0*breach*(1.0-smoothstep(.48,1.06,radius_offset))
	var ramparts:=12.3*_spine(p,Vector2(-309,333),.40,Vector2(38,17))
	ramparts+=16.0*_spine(p,Vector2(-312,361),-.62,Vector2(38,17))
	ramparts+=12.5*_spine(p,Vector2(-281,375),.81,Vector2(32,17))
	var neck:=22.5*_spine(p,Vector2(-332,336),-.42,Vector2(30,22))
	var ribs:=4.1*sin(angle*7+radius*3.5)*smoothstep(.31,.50,radius_offset)*(1.0-smoothstep(.62,1.04,radius_offset))
	return maxf(0,shield-bowl+rim-chute+ramparts+neck+ribs)


func _relief(id: String,p: Vector2) -> float:
	var x := p.x
	var z := p.y
	var fold := .45*sin(x*.105+z*.064)+.50*cos(z*.122-x*.028)
	match id:
		"snow":
			var climb := clampf((-207-z)*.12,0,24)
			var west:=maxf(59*_spine(p,Vector2(-294,-347),-.64,Vector2(72,39)),41*_spine(p,Vector2(-278,-333),.59,Vector2(56,32)))
			var north:=maxf(76*_spine(p,Vector2(-241,-393),-.32,Vector2(78,47)),53*_spine(p,Vector2(-217,-382),.73,Vector2(63,39)))
			var east:=maxf(41*_spine(p,Vector2(-161,-356),.61,Vector2(58,38)),34*_spine(p,Vector2(-176,-342),-.52,Vector2(57,32)))
			return 4.0+climb+fold+maxf(west,maxf(north,east)) + 5.5*_hill(p,Vector2(-235,-351),Vector2(121,92))
		"tide":
			var high := 1.95+fold*.6+8*_hill(p,Vector2(-334,-76),Vector2(83,48))
			var pool := ((p-Vector2(-248,9))/Vector2(35,15)).length()
			var salt := lerpf(-1.58,high,smoothstep(.73,1.10,pool))
			if pool<1.12:
				var spit := 1.0-smoothstep(1.9,5.2,Geo.path_distance(p,Geo.TIDAL_SPIT))
				salt = maxf(salt,lerpf(-1.55,.11,spit))
			return salt
		"volcano":
			var h := 4.6+19*_hill(p,Vector2(-210,326),Vector2(95,89))+_caldera(p)+fold*.9
			var d := Geo.path_distance(p,Geo.LAVA_CREEK)
			return h-1.16*(1.0-smoothstep(1.1,5.3,d))
		"desert":
			var drift := .5+.5*sin((z-.23*x)*.116+1.75*sin(x*.038))
			return 2.65+6.8*pow(drift,1.9)+.7*sin(x*.055)+17*_hill(p,Vector2(403,359),Vector2(85,67))
		"lake":
			var h := 3.1+fold+15*_hill(p,Vector2(464,-63),Vector2(58,31))+18*_hill(p,Vector2(537,43),Vector2(38,68))
			var shore := Geo.lake_distance(p)
			h = lerpf(-2.1,h,smoothstep(-2.8,5.2,shore))
			var islet := 1.0-smoothstep(5.0,10.1,p.distance_to(Geo.LAKE_ISLET))
			for landing:Vector2 in Geo.LAKE_LANDINGS:
				if h>1.1 and p.distance_squared_to(landing)<225:
					h=lerpf(2.05,h,smoothstep(3.5,15,p.distance_to(landing)))
			return maxf(h,lerpf(-2.2,2.6,islet))
		"forest":
			var h := 5.6+fold+21*_hill(p,Vector2(323,-318),Vector2(90,86))+20*_hill(p,Vector2(391,-349),Vector2(54,55))
			var gorge := _hill(p,Vector2(279,-227),Vector2(15,23))
			return h-3.3*smoothstep(.0,.65,gorge)
	return 2.0

func _home_height(w,p: Vector2) -> float:
	var old_d:=OldSurvey.coast_distance(p)
	var lowland:=1.95+.40*sin(p.x*.134+p.y*.075)+.28*cos(p.y*.17-p.x*.04)
	if old_d < -70 and Geo.inlet_distance(p)>8: return lowland
	var old: float=w._land_height(p.x,p.y)
	if old_d>6: return old
	# Only the three tidal basins keep the former inlet shore. Everywhere
	# else the village plain continues outside the historical survey boundary.
	var joined:=smoothstep(-2.0,5.0,Geo.inlet_distance(p))*(1.0-smoothstep(-2.0,6.0,old_d))
	return lerpf(old,maxf(lowland,old),joined)

func _backcountry(id: String,p: Vector2) -> float:
	var upland:=smoothstep(78,150,p.distance_to(Geo.HUNTS[id]))
	if upland<=0: return 0
	var fold:=.5+.5*sin(p.x*.034+p.y*.018+sin(p.y*.034)*.81)
	var long_ridge:=smoothstep(.10,.93,fold)
	match id:
		"snow": return upland*(2.1+8.4*long_ridge+2.6*sin(p.y*.069))
		"tide": return upland*(.65+1.25*long_ridge)
		"volcano": return upland*(2.3+7.4*long_ridge+2.0*sin(p.y*.06+p.x*.02))
		"desert": return upland*(1.2+5.8*long_ridge)
		"lake": return upland*(.70+5.1*long_ridge)
		"forest": return upland*(2.2+9.2*long_ridge)
	return 0

func _raw_height(w,p: Vector2,weights: Dictionary) -> float:
	var h:=0.0
	for id: String in weights:
		if id=="home":
			h+=_home_height(w,p)*float(weights[id])
			continue
		var local:=_relief(id,p)+_backcountry(id,p)
		for pair: Array in _flat_centers[id]:
			var radius: float=pair[1]
			var distance:=p.distance_to(pair[0])
			if distance<radius+8:
				local=lerpf(pair[2],local,smoothstep(radius,radius+8,distance))
		h+=local*float(weights[id])
	return h

func _index_grade(w,route: Array) -> void:
	var a: Vector2=route.front()
	var previous_h:=_raw_height(w,a,Geo.region_mix(a))
	for i in range(1,route.size()):
		var b: Vector2=route[i]
		var distance:=a.distance_to(b)
		var target:=_raw_height(w,b,Geo.region_mix(b))
		var current_h:=clampf(target,previous_h-distance*.25,previous_h+distance*.25)
		var info:=[a,b,previous_h,current_h]
		var low:=Vector2i(((a.min(b)-Vector2.ONE*11)/24).floor())
		var high:=Vector2i(((a.max(b)+Vector2.ONE*11)/24).floor())
		for j in range(low.y,high.y+1):
			for k in range(low.x,high.x+1):
				var cell:=Vector2i(k,j)
				if not _grade_cells.has(cell): _grade_cells[cell]=[]
				_grade_cells[cell].append(info)
		previous_h=current_h
		a=b


func _graded_height(p: Vector2,h: float) -> float:
	var dist := 121.0
	var elevation := h
	for span: Array in _grade_cells.get(Vector2i((p/24).floor()),[]):
		var a: Vector2 = span[0]
		var d: Vector2 = span[1]-a
		var t := clampf((p-a).dot(d)/d.length_squared(),0,1)
		var squared := p.distance_squared_to(a+d*t)
		if squared < dist:
			dist = squared
			elevation = lerpf(span[2],span[3],t)
	return lerpf(elevation,h,smoothstep(4.5,11.0,sqrt(dist)))

func _height(w,p: Vector2,weights: Dictionary) -> float:
	var coast:=Geo.mainland_distance(p)
	if coast < -5: return WATER
	var h:=_raw_height(w,p,weights)
	var home: float=weights.get("home",0.0)
	if home<.999:
		var grade:=_graded_height(p,h)
		# Natural shore and each dock control the lake waterline.
		if p.x>360 and Geo.lake_distance(p)<4: grade=h
		for landing: Vector2 in Geo.LAKE_LANDINGS:
			if p.distance_squared_to(landing)<6.2*6.2: grade=h
		h=lerpf(grade,h,home)
		if home>.001:
			var inlet:=Geo.inlet_distance(p)
			if inlet<5 and OldSurvey.coast_distance(p)<6:
				h=lerpf(w._land_height(p.x,p.y),h,smoothstep(-2.0,5.0,inlet))
	if p.distance_squared_to(Vector2(279,-225))<28.0*28.0:
		for span:Array in Geo.FOREST_BRIDGES:
			var a:Vector2=span[0]
			var d:Vector2=span[1]-a
			var t:=clampf((p-a).dot(d)/d.length_squared(),0.0,1.0)
			var dist:=p.distance_to(a+t*d)
			h-=3.7*sin(t*PI)*(1.0-smoothstep(1.45,7.8,dist))
	return lerpf(WATER,h,smoothstep(-3,8,coast))


func _pigment(id: String,p: Vector2,h: float,n: Vector3) -> Color:
	var coast := Geo.mainland_distance(p)
	var speckle := .5+.5*sin(p.x*.142+p.y*.072+sin(p.y*.13))
	var col := Color.WHITE
	match id:
		"snow":
			col = Color("#677987").lerp(Color("#9cadaf"),smoothstep(.61,.96,n.y)*smoothstep(4.5,14,h))
			col = col.lerp(Color("#b3b9af"),.12*speckle)
		"tide":
			col = Color("#879b87").lerp(Color("#c5b68f"),smoothstep(-.15,2.05,h))
			col = col.lerp(Color("#739281"),smoothstep(2.6,5.0,h)*.9)
		"volcano":
			col = Color("#65565d").lerp(Color("#987760"),speckle*.68+smoothstep(22,57,h)*.23)
			if h>23.0:
				var talus:=Color("#67646b").lerp(Color("#8e6d63"),speckle*.58)
				col=col.lerp(talus,(1.0-smoothstep(.61,.88,n.y))*.85)
			if Geo.path_distance(p,Geo.LAVA_CREEK)<5.0: col = Color("#4f4549")
		"desert":
			col = Color("#ae855e").lerp(Color("#c8ab85"),.12+.75*clampf(n.y-.60,0,1)+speckle*.29)
		"lake":
			col = Color("#82a282").lerp(Color("#aec29a"),.56*speckle)
			if Geo.lake_distance(p)<4.0: col = Color("#bfba91")
		"forest":
			col = Color("#476f5d").lerp(Color("#729568"),speckle*.76)
	if coast<3.2:
		col = col.lerp(Color("#b4ab94") if id!="volcano" else Color("#504b4e"),1.0-smoothstep(-.7,3.2,coast))
	return col.srgb_to_linear().lerp(col,.27)

func _sample(w,key: Vector2i,weights: Dictionary) -> float:
	if _heights.has(key): return _heights[key]
	var p:=Vector2(key)
	var h: float
	if key.x%TILE==0 and key.y%4!=0 and _coarse_edge(key,Vector2i.LEFT):
		h=.5*(_sample(w,key+Vector2i.UP*2,Geo.region_mix(p+Vector2.UP*2))+_sample(w,key+Vector2i.DOWN*2,Geo.region_mix(p+Vector2.DOWN*2)))
	elif key.y%TILE==0 and key.x%4!=0 and _coarse_edge(key,Vector2i.UP):
		h=.5*(_sample(w,key+Vector2i.LEFT*2,Geo.region_mix(p+Vector2.LEFT*2))+_sample(w,key+Vector2i.RIGHT*2,Geo.region_mix(p+Vector2.RIGHT*2)))
	else:
		h=_height(w,p,weights)
	_heights[key]=h
	return h

func _coarse_edge(key: Vector2i,other: Vector2i) -> bool:
	var tile:=Vector2i((Vector2(key)/TILE).floor())
	return _steps.get(tile,4)==4 or _steps.get(tile+other,4)==4

func _make_tile(w,tile: Vector2i,step: int) -> void:
	var origin:=tile*TILE
	var side:=floori(float(TILE)/step)+1
	var xyz:=PackedVector3Array()
	var norms:=PackedVector3Array()
	var colors:=PackedColorArray()
	var uv:=PackedVector2Array()
	var uv2:=PackedVector2Array()
	var weights4:=PackedByteArray()
	var indices:=PackedInt32Array()
	var blends:Array[Dictionary]=[]
	var has_land:=false
	for j in side:
		for i in side:
			var key:=origin+Vector2i(i,j)*step
			var p:=Vector2(key)
			var mix:=Geo.region_mix(p)
			var h:=_sample(w,key,mix)
			blends.append(mix)
			has_land=has_land or h>-.90
			xyz.append(Vector3(p.x,h,p.y))
			uv.append(Vector2(w._road_distance(p),h))
			uv2.append(Vector2(mix.get("lake",0.0),mix.get("forest",0.0)))
			for id: String in ["snow","tide","volcano","desert"]:
				weights4.append(roundi(255*mix.get(id,0.0)))
			if i>0 and j>0:
				var k:=i+j*side
				indices.append_array(PackedInt32Array([k-side-1,k-side,k,k-side-1,k,k-1]))
	if not has_land: return
	for j in side:
		for i in side:
			var k:=i+j*side
			var dx:=xyz[mini(side-1,i+1)+j*side]-xyz[maxi(0,i-1)+j*side]
			var dz:=xyz[i+mini(side-1,j+1)*side]-xyz[i+maxi(0,j-1)*side]
			var normal:=dz.cross(dx).normalized()
			var v:=xyz[k]
			var p:=Vector2(v.x,v.z)
			if i==0 or j==0 or i==side-1 or j==side-1:
				# Neighbouring tiles, including mixed-resolution edges, shade their shared vertex identically.
				var key:=Vector2i(p)
				var east:=_sample(w,key+Vector2i.RIGHT*2,Geo.region_mix(p+Vector2.RIGHT*2))
				var west:=_sample(w,key+Vector2i.LEFT*2,Geo.region_mix(p+Vector2.LEFT*2))
				var south:=_sample(w,key+Vector2i.DOWN*2,Geo.region_mix(p+Vector2.DOWN*2))
				var north:=_sample(w,key+Vector2i.UP*2,Geo.region_mix(p+Vector2.UP*2))
				normal=Vector3(west-east,4.0,north-south).normalized()
			norms.append(normal)
			var color:=Color(0,0,0,0)
			for id: String in blends[k]:
				var pigment: Color
				if id=="home":
					var c: Color=w._terrain_color(p.x,p.y,v.y)
					pigment=c.srgb_to_linear().lerp(c,.27)
				else:
					pigment=_pigment(id,p,v.y,normal)
				color+=pigment*float(blends[k][id])
			colors.append(color)
	var arr:=[]
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX]=xyz
	arr[Mesh.ARRAY_NORMAL]=norms
	arr[Mesh.ARRAY_COLOR]=colors
	arr[Mesh.ARRAY_TEX_UV]=uv
	arr[Mesh.ARRAY_TEX_UV2]=uv2
	arr[Mesh.ARRAY_CUSTOM0]=weights4
	arr[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arr,[],{},Mesh.ARRAY_CUSTOM_RGBA8_UNORM<<Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	var node:=MeshInstance3D.new()
	node.name="Mainland_%d_%d" % [origin.x,origin.y]
	node.mesh=mesh
	node.material_override=_ground_material
	w.add_child(node)
	node.create_trimesh_collision()

func terrain_height(p: Vector2) -> float:
	var tile:=Vector2i((p/TILE).floor())
	var step: int=_steps.get(tile,4)
	var a:=Vector2i((p/step).floor())*step
	var c:=a+Vector2i(step,step)
	if not _heights.has(a) or not _heights.has(c): return WATER
	var t:=(p-Vector2(a))/step
	var middle:=a+Vector2i(step,0) if t.x>=t.y else a+Vector2i(0,step)
	if not _heights.has(middle): return WATER
	return _heights[a]*(1.0-maxf(t.x,t.y))+_heights[middle]*absf(t.x-t.y)+_heights[c]*minf(t.x,t.y)


func surface(p: Vector2) -> float:
	var terrain := terrain_height(p)
	for span: Array in _span_cells.get(Vector2i((p/16.0).floor()),[]):
		var a: Vector2=span[0]
		var b: Vector2=span[1]
		var d := b-a
		var along := clampf((p-a).dot(d)/d.length_squared(),0,1)
		var width := p.distance_to(a+d*along)
		var half: float = span[4]
		if width<=half:
			var h := lerpf(span[2],span[3],along)
			terrain=maxf(terrain,h)
	return terrain

func _register(a: Vector2,b: Vector2,ha: float,hb: float,half: float) -> void:
	var info := [a,b,ha,hb,half]
	var low := Vector2i(((a.min(b)-Vector2.ONE*half)/16).floor())
	var high := Vector2i(((a.max(b)+Vector2.ONE*half)/16).floor())
	for j in range(low.y,high.y+1):
		for i in range(low.x,high.x+1):
			var k := Vector2i(i,j)
			if not _span_cells.has(k): _span_cells[k]=[]
			_span_cells[k].append(info)


func _add_span(w,a: Vector2,b: Vector2,ha: float,hb: float,half: float,side: Vector2,index: int,id: String) -> void:
	var center := (a+b)*.5
	var h := (ha+hb)*.5
	var tangent := (b-a).normalized()
	var yaw := atan2(tangent.x,tangent.y)
	_register(a,b,ha,hb,half)
	if id=="windfall":
		w.model("box",Vector3(center.x,h-.10,center.y),Vector3(half*1.89,.21,a.distance_to(b)+.025),"#8d8166" if index%4 else "#718061",yaw)
		if index%5==0:
			for sign_:float in [-1.0,1.0]:
				var q:=center+side*sign_*(half-.18)
				w.model("box",Vector3(q.x,h+.06,q.y),Vector3(.46,.13,.105),"#a2956c",yaw)
	else:
		w.model("box",Vector3(center.x,h-.14,center.y),Vector3(half*2,.28,a.distance_to(b)+.045),"#a18b67" if index%3 else "#92795a",yaw)
		if index%4==0:
			for sign_: float in [-1.0,1.0]:
				var q := center+side*(half-.12)*sign_
				w.model("7_91",Vector3(q.x,h-1.08,q.y),Vector3(.16,4.1,.16),"#6e6654",yaw)
				w.model("7_100",Vector3(q.x,h+.79,q.y),Vector3(.17,.23,.17),"#d1bf94",yaw)
	# Collision follows the local deck pitch, including the landing at either end.
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size=Vector3(half*2.0,.16,a.distance_to(b)+.08)
	col.shape=shape
	col.position=Vector3(center.x,h-.08,center.y)
	col.rotation=Vector3(-atan2(hb-ha,a.distance_to(b)),yaw,0)
	w._solid.add_child(col)

func _forest_bridges(w) -> void:
	for span: Array in Geo.FOREST_BRIDGES:
		var a: Vector2=span[0]
		var b: Vector2=span[1]
		var dir := a.direction_to(b)
		var side := dir.orthogonal()
		var length := a.distance_to(b)
		var steps := ceili(length/.88)
		for i in steps:
			var pa:=a.lerp(b,float(i)/steps)
			var pb:=a.lerp(b,float(i+1)/steps)
			var ha:=lerpf(terrain_height(a),terrain_height(b),float(i)/steps)+.18*sin(PI*i/steps)
			var hb:=lerpf(terrain_height(a),terrain_height(b),float(i+1)/steps)+.18*sin(PI*(i+1)/steps)
			_add_span(w,pa,pb,ha,hb,1.8,side,i,"windfall")
		for flank:float in [-1.0,1.0]:
			var mid:=(a+b)*.5+side*flank*1.46
			w.model("box",Vector3(mid.x,(terrain_height(a)+terrain_height(b))*.5-.50,mid.y),Vector3(.58,.85,length+.7),"#635842",atan2(dir.x,dir.y))

func _lake_water(w) -> void:
	var surface := PlaneMesh.new()
	surface.size = Geo.LAKE_RADII*2.14
	var lake := MeshInstance3D.new()
	lake.mesh=surface
	lake.position=Vector3(Geo.LAKE_CENTER.x,Geo.LAKE_LEVEL,Geo.LAKE_CENTER.y)
	var mat:=ShaderMaterial.new()
	mat.shader=preload("expedition_lake.gdshader")
	mat.set_shader_parameter("seabed", preload("res://art/terrain/coastal_bathymetry.png"))
	lake.material_override=mat
	lake.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.add_child(lake)

func _lake_piers(w) -> void:
	for landing:Vector2 in Geo.LAKE_LANDINGS:
		var dir:=landing.direction_to(Geo.LAKE_CENTER)
		var side:=dir.orthogonal()
		var start_h:=terrain_height(landing)+.045
		for i in 12:
			var a:=landing+dir*i*.78
			var b:=a+dir*.78
			var ha:=lerpf(start_h,1.14,smoothstep(0,1,float(i)/12))
			var hb:=lerpf(start_h,1.14,smoothstep(0,1,float(i+1)/12))
			_add_span(w,a,b,ha,hb,1.36,side,i,"lake")
