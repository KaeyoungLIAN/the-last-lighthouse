extends RefCounted
## Silhouettes, local building traditions and midsize landscape props for the six expedition routes.
const G := preload("expedition_geography.gd")
const ACCENTS := {"snow":"#c67555","tide":"#689995","volcano":"#b78154","desert":"#b76653","lake":"#759ba2","forest":"#a29860"}
var w
var rng := RandomNumberGenerator.new()
var _flag_mesh: ArrayMesh
var _flag_cloth := ShaderMaterial.new()

func build(world) -> void:
	w=world
	rng.seed=821653
	_flag_cloth.shader=preload("expedition_flag.gdshader")
	_flag_mesh=_make_pennant()
	for id: String in G.ZONES:
		_shelter(id)
		_trail_marks(id)
	_snow()
	_tidal_shore()
	_volcanic_field()
	_dunes()
	_lakeside()
	_forest()
	_woodland_corridor()
	_groves()
	_mixed_roads()
	preload("expedition_formations.gd").new().build(w)

func _at(p: Vector2) -> Vector3:
	return w._point(p.x,p.y)

func _box(o: Vector3,offset: Vector3,dims: Vector3,tint: String,yaw:=0.0) -> void:
	w.model("box",o+offset,dims,tint,yaw)

func _beam(a: Vector3,b: Vector3,radius: float,tint: String,form:="box") -> void:
	var d:=b-a
	if d.length_squared()<.0001:return
	var aim:=d.normalized()
	w.model(form,(a+b)*.5,Vector3(radius,d.length(),radius),tint,atan2(-aim.z,aim.x),false,acos(clampf(aim.y,-1,1)))

func _rock(p: Vector2,dims: Vector3,tint: String,top:="#a6aaa0",angle:=0.0) -> void:
	var model_name := "ShoreStone"
	var modulation := Color(tint).lightened(.46)
	if p.y < -185 and p.x < -70:
		model_name = "SnowStone"
		modulation = Color(top).lightened(.60)
	elif p.y > 190 and p.x < -70:
		model_name = "LavaStone"
		modulation = Color.WHITE
	w.model(model_name, _at(p), dims, modulation.to_html(false), angle)

func _shelter(id: String) -> void:
	var at: Vector2=G.CAMPS[id]
	var origin:=_at(at)
	# A shelter sits across the quiet shoulder, with a porch facing its supply point.
	var road: Array=G.ROUTES[id]
	var ix:=road.find(at)
	var forward: Vector2=(road[ix+1]-road[ix-1]).normalized()
	var offset:=forward.orthogonal()*8.6
	var p:=at+offset
	var o:=_at(p)
	var outward:=Vector3(-offset.x,0,-offset.y).normalized()
	var side:=Vector3(outward.z,0,-outward.x)
	var yaw:=atan2(outward.x,outward.z)
	w.model(id.capitalize() + "Camp", o, Vector3.ONE, "#ffffff", yaw)
	if id == "desert":
		_well(origin+side*2.9)
	if id in ["snow", "lake", "forest"]:
		w.block_disc(o,2.12,3.2)
	# Stocked racks and a common lantern language connect the distant shelters to Greybay.
	var rack:=o+side*3.5+outward*1.1
	for sig:float in [-1.0,1.0]:
		_beam(rack+outward*sig*1.0,rack+outward*sig+Vector3.UP*2.1,.13,"#766747")
	_beam(rack+Vector3.UP*1.96-outward,rack+Vector3.UP*1.96+outward,.09,"#a08e65")
	for j in 3:
		var q:=rack+outward*(j*.59-.63)+Vector3.UP*1.48
		w.model("box",q,Vector3(.38,.85,.055),ACCENTS[id] if j%2==0 else "#d2bf93",yaw+PI*.5)
	w._barrel(o,side.x*3.25,side.z*3.25)
	var hearth:=_at(at+Vector2(side.x,side.z)*3.55)
	w.model("8_93",hearth+Vector3.UP*.24,Vector3(.83,.49,.83),"#666b62",yaw)
	w.model("6_22",hearth+Vector3.UP*.62,Vector3(.38,.64,.40),"#efa85c",yaw,true)
	for i in 4:
		w.model("box",hearth+Vector3.UP*.50,Vector3(1.10,.11,.15),"#735a43",i*1.10)
	_marker(id,G.ENTRANCES[id],G.ZONES[id],true)

func _well(o: Vector3) -> void:
	for i in 12:
		var a:=TAU*i/12
		var radial:=Vector3(sin(a),0,cos(a))
		w.model("box",o+radial*.87+Vector3.UP*.42,Vector3(.50,.84,.33),"#b99e77" if i%2==0 else "#ac9476",a)
	for sign_:float in [-1.0,1.0]:
		w.model("box",o+Vector3(sign_*.89,1.71,0),Vector3(.14,2.06,.17),"#7e684a",0)
	_beam(o+Vector3(-.98,2.58,0),o+Vector3(.98,2.58,0),.15,"#907953")
	_beam(o+Vector3.UP*2.57,o+Vector3.UP*.70,.037,"#b89d74")
	w.model("8_100",o+Vector3.UP*.51,Vector3(.65,.055,.65),"#718e89")

func _marker(id: String,p: Vector2,label: String,tall:=false) -> void:
	var o:=_at(p+Vector2(2.9,2.4))
	w.model("7_84",o+Vector3.UP*.20,Vector3(.32,.4,.32),"#969486")
	w.model("box",o+Vector3.UP*1.16,Vector3(.18,2.32,.21),"#746549")
	w.model("box",o+Vector3(.19,1.77,0),Vector3(1.04,.34,.15),ACCENTS[id],.16)
	w.model("box",o+Vector3(.28,1.77,.075),Vector3(.42,.074,.08),"#ddd1a7",.16)
	if tall:
		var text:=Label3D.new()
		text.position=o+Vector3.UP*2.77
		text.text=label
		text.pixel_size=.011
		text.font_size=32
		text.outline_size=6
		text.modulate=Color("#f5e8c5")
		text.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		text.visibility_range_end=24
		w.add_child(text)

func _trail_marks(id: String) -> void:
	var route:Array=G.ROUTES[id]
	for i in range(route.find(G.ENTRANCES[id])+1,route.size()):
		var a:Vector2=route[i-1]
		var b:Vector2=route[i]
		var side:=a.direction_to(b).orthogonal()
		var steps:=maxi(1,ceili(a.distance_to(b)/17.0))
		for j in steps:
			var p:=a.lerp(b,(j+.50)/steps)+side*(3.4 if (j+i)%2==0 else -3.4)
			var o:=_at(p)
			if id=="snow":
				w.model("6_76",o+Vector3.UP*1.80,Vector3(.105,3.60,.105),"#73634c")
				var flag:=MeshInstance3D.new()
				flag.mesh=_flag_mesh
				flag.material_override=_flag_cloth
				flag.position=o+Vector3.UP*3.28
				flag.rotation.y=-.20+i*.10
				flag.add_to_group("expedition_wind_flags")
				w.add_child(flag)
			elif id=="tide":
				w.model("7_84",o+Vector3.UP*1.35,Vector3(.15,2.70,.15),"#706b59")
				for h:float in [.84,1.23,1.63,2.03]:
					w.model("7_96",o+Vector3.UP*h,Vector3(.151,.14,.151),"#dcd5ae")
			else:
				w.model("6_62",o+Vector3.UP*.36,Vector3(.54,.76,.49),"#979583",i)
				w.model("6_72",o+Vector3.UP*.85,Vector3(.32,.31,.30),ACCENTS[id],i+.57)
	_marker(id,G.ARENAS[id],{"snow":"刨雪石阵","tide":"沉锚礁台","volcano":"雷角冷台","desert":"硬砾盆地","lake":"浅水钟台","forest":"冠枝林场"}[id],false)

func _make_pennant() -> ArrayMesh:
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 8:
		var a:=float(i)/8.0
		var b:=float(i+1)/8.0
		for uv:Vector2 in [Vector2(a,0),Vector2(b,0),Vector2(b,1),Vector2(a,0),Vector2(b,1),Vector2(a,1)]:
			var h:=lerpf(.53,.29,uv.x)
			st.set_uv(uv)
			st.set_normal(Vector3.BACK)
			st.add_vertex(Vector3(uv.x*1.53,-h*uv.y-.11*uv.x,0))
	return st.commit()

func _snow() -> void:
	for k in 61:
		var ridge:=Vector2(-300+rng.randf_range(-29,35),-338+rng.randf_range(-40,24))
		if k%3==1: ridge=Vector2(-235+rng.randf_range(-37,38),-400+rng.randf_range(-25,29))
		_rock(ridge,Vector3(rng.randf_range(2.5,7.8),rng.randf_range(3.8,11.0),rng.randf_range(2.4,5.1)),"#667781","#dce5e2",rng.randf()*TAU)
	for i in 12:
		var t:=float(i)*TAU/12
		var p:Vector2=G.ARENAS.snow+Vector2(cos(t)*17.8,sin(t)*16.5)
		if w._road_distance(p)<4.0:continue
		_rock(p,Vector3(1.5+rng.randf(),3.0+2.5*rng.randf(),1.15),"#788393","#e8e9e0",t)
	for i in 8:
		var p:Vector2=G.HUNTS.snow+Vector2(-9.0-i*.87,2+sin(i*.8)*.58)
		var o:=_at(p)
		for toe in 3:
			var a:=(toe-1)*.62
			w.model("box",o+Vector3(.10*sin(a),.028,.10*cos(a)),Vector3(.052,.032,.21),"#8097a0",a)

func _tidal_shore() -> void:
	var o:=_at(Vector2(-246,17))
	for k in 11:
		var x:=(k-5)*.91
		var width:=2.31*(1.0-.70*pow(absf(x)/4.58,2))
		_box(o,Vector3(x,.23,0),Vector3(.88,.43,width*1.72),"#927255")
		for sig:float in [-1.0,1.0]:
			_beam(o+Vector3(x,.21,sig*width*.45),o+Vector3(x,1.12+.28*sin(k*1.8),sig*width),.17,"#806049")
			if k%4!=1: _box(o,Vector3(x,.57,sig*width*.86),Vector3(.95,.31,.17),"#9c7854")
	_beam(o+Vector3(.3,.24,0),o+Vector3(-1.25,6.10,.66),.19,"#706148","7_65")
	_beam(o+Vector3(-2.63,4.41,.54),o+Vector3(1.42,4.56,.46),.12,"#977858")
	_beam(o+Vector3(-1.2,5.95,.64),o+Vector3(3.9,.60,1.2),.024,"#786c56")
	for j in 17:
		var p:=Vector2(-329+rng.randf_range(-47,24),32+rng.randf_range(-15,47))
		_rock(p,Vector3(rng.randf_range(1.7,5.3),rng.randf_range(.8,2.38),rng.randf_range(1.2,2.7)),"#6e7873","#a8aaa0",rng.randf()*TAU)
	var anchor:=_at(Vector2(-326,-35))
	_beam(anchor+Vector3(-.65,.33,0),anchor+Vector3(.77,3.4,.12),.27,"#535c5f")
	_beam(anchor+Vector3(-.95,.95,-.06),anchor+Vector3(1.55,.38,.14),.24,"#576065")

func _volcanic_field() -> void:
	for i in 170:
		var centers: Array[Vector2]=[Vector2(-274,330),Vector2(-264,287),Vector2(-183,318),Vector2(-290,377)]
		var p:Vector2=centers[i%4]+Vector2(rng.randf_range(-9,9),rng.randf_range(-9,9))
		if w._road_distance(p)<4.6 or p.distance_to(G.ARENAS.volcano)<15:continue
		var o:=_at(p)
		var h:=rng.randf_range(1.55,7.4)
		w.model("6_100",o+Vector3.UP*h*.42,Vector3(.88,h,.88),"#64616b" if i%3 else "#79717a",PI/6)
		w.model("6_89",o+Vector3.UP*h*.94,Vector3(.89,h*.065,.89),"#8a7a76",PI/6)
	var flow:=SurfaceTool.new()
	flow.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mat:=ShaderMaterial.new()
	mat.shader=preload("expedition_lava.gdshader")
	for i in range(1,G.LAVA_CREEK.size()):
		var a:Vector2=G.LAVA_CREEK[i-1]
		var b:Vector2=G.LAVA_CREEK[i]
		var side:=a.direction_to(b).orthogonal()
		var steps:=ceili(a.distance_to(b)/1.35)
		for j in steps:
			var pa:=a.lerp(b,float(j)/steps)
			var pb:=a.lerp(b,float(j+1)/steps)
			for strip in 5:
				var lo:=(strip/5.0-.5)*5.75
				var hi:=((strip+1)/5.0-.5)*5.75
				var h0:=_at(pa+side*lo)+Vector3.UP*.17
				var h1:=_at(pa+side*hi)+Vector3.UP*.17
				var h2:=_at(pb+side*hi)+Vector3.UP*.17
				var h3:=_at(pb+side*lo)+Vector3.UP*.17
				var vertices: Array[Vector3]=[h0,h1,h2,h0,h2,h3]
				var widths: Array[float]=[lo,hi,hi,lo,hi,lo]
				for k in 6:
					flow.set_uv(Vector2(widths[k]/5.75+.5,0))
					flow.set_normal(Vector3.UP)
					flow.add_vertex(vertices[k])
	var inst:=MeshInstance3D.new()
	inst.name="BasaltLavaRun"
	inst.mesh=flow.commit()
	inst.material_override=mat
	inst.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.add_child(inst)
	for p:Vector2 in G.COOL_STONES:
		_rock(p,Vector3(1.18,.62,1.04),"#58555c","#8b8384",p.x)
	for i in 7:
		var t:=TAU*i/7
		var p:=Vector2(-288,352)+Vector2(cos(t)*11,sin(t)*9)
		w.model("7_91",_at(p)+Vector3.UP*.22,Vector3(3.9,.58,2.80),"#df7043",t,true)

func _dunes() -> void:
	for i in 23:
		var p:=Vector2(374+rng.randf_range(-9,23),312+rng.randf_range(0,20))
		var h:=rng.randf_range(2.6,7.5)
		var o:=_at(p)
		w.model("6_69",o+Vector3.UP*h*.43,Vector3(2.6,h,1.9),"#ad8061",i*.76)
		w.model("6_98",o+Vector3.UP*h*.83,Vector3(1.99,h*.13,1.52),"#d1ad81",i*.76)
		w.model("6_61",o+Vector3.UP*h*.99,Vector3(2.13,h*.26,1.65),"#ba9470",i*.76)
	var arch:=_at(Vector2(334,250))
	for sig:float in [-1.0,1.0]:
		w.model("7_72",arch+Vector3(sig*3.75,2.65,0),Vector3(1.8,5.8,1.28),"#aa795b",sig*.72)
		w.model("7_91",arch+Vector3(sig*3.67,4.94,0),Vector3(1.61,.57,1.29),"#d3b385",sig*.72)
	_beam(arch+Vector3(-3.6,5.70,0),arch+Vector3(-.1,6.68,.04),.89,"#c6a079","6_87")
	_beam(arch+Vector3(.1,6.68,.04),arch+Vector3(3.6,5.65,0),.92,"#c6a079","6_87")

func _lakeside() -> void:
	var o:=_at(G.LAKE_ISLET+Vector2(2.8,-2.1))
	w.model("8_93",o+Vector3.UP*.58,Vector3(2.55,1.16,2.38),"#92968a",PI/8)
	w.model("box",o+Vector3.UP*2.35,Vector3(3.22,3.48,2.96),"#b9b49b")
	w.model("box",o+Vector3.UP*4.12,Vector3(3.60,.34,3.40),"#878f87")
	for x:float in [-1.42,1.42]:
		for z:float in [-1.27,1.27]:
			w.model("box",o+Vector3(x,5.68,z),Vector3(.34,3.0,.34),"#75877f")
	w.model("8_56",o+Vector3.UP*5.45,Vector3(.85,1.45,.85),"#74968a")
	w.model("8_89",o+Vector3.UP*4.80,Vector3(.99,.21,.99),"#9baf97")
	w.model("4_10",o+Vector3.UP*8.40,Vector3(2.88,2.67,2.88),"#63828a",PI/4)
	w.model("6_34",o+Vector3.UP*10.18,Vector3(.16,1.0,.16),"#a78b5e")
	w.block_disc(o,1.48,7.0)
	# The drowned settlement is legible from the western jetty, with the ridge and a broken gable above the water.
	var lost:=Vector3(429.0,G.LAKE_LEVEL+.27,25.0)
	w.model("roof",lost,Vector3(7.3,2.84,6.12),"#638082",-.36,false,.14)
	w.model("box",lost+Vector3(2.79,.99,-1.45),Vector3(.83,2.65,.82),"#93978a",-.36,false,.11)
	w.model("roof",Vector3(433,G.LAKE_LEVEL+.07,33),Vector3(4.9,1.56,3.90),"#80918c",-.41,false,-.13)
	_fishing_jetty()
	_reed_banks()
	for i in G.LAKE_BEACONS.size():
		var p:Vector2=G.LAKE_BEACONS[i]
		var buoy:=Vector3(p.x,G.LAKE_LEVEL,p.y)
		w.model("8_90",buoy+Vector3.UP*.16,Vector3(.92,.65,.92),"#ae8660",PI/8)
		w.model("7_72",buoy+Vector3.UP*1.22,Vector3(.15,2.08,.15),"#697b71",i)
		w.model("6_54",buoy+Vector3.UP*1.81,Vector3(.44,.64,.44),"#89a292",i)
		w.model("5_0",buoy+Vector3.UP*2.48,Vector3(.35,.58,.35),"#d6bd8a",i)
	for shore:Vector2 in G.LAKE_LANDINGS:
		var toward:=shore.direction_to(G.LAKE_CENTER)
		var side:=toward.orthogonal()
		var post:=_at(shore+side*2.1)
		w.model("7_83",post+Vector3.UP*1.14,Vector3(.18,2.27,.18),"#83715a")
		w.model("box",post+Vector3.UP*1.85,Vector3(.86,.33,.15),"#769795")
		for j in 3:
			var q:=_at(shore+side*(2.6+j*.57))
			w.model("7_93",q+Vector3.UP*.21,Vector3(.28,.33,.28),"#ad936d")

func _forest() -> void:
	for i in 10:
		var t:=TAU*i/10
		var p:Vector2=G.ARENAS.forest+Vector2(cos(t)*19.5,sin(t)*19)
		if w._road_distance(p)<5:continue
		_cedar(p,12.6+rng.randf()*5.4)
	for i in 7:
		var p:=Vector2(276,-222)+Vector2(rng.randf_range(-7,8),rng.randf_range(-5,7))
		if w._road_distance(p)<2.2:continue
		_rock(p,Vector3(rng.randf_range(.86,2.0),1.0,rng.randf_range(.8,1.7)),"#687567","#8ca16d",i)
	var stump:=_at(Vector2(300,-235))
	w.model("9_76",stump+Vector3.UP*1.13,Vector3(1.64,2.29,1.41),"#77654d",.3)
	w.model("9_95",stump+Vector3.UP*2.30,Vector3(1.26,.08,1.07),"#b39c72",.3)
	w.model("8_93",stump+Vector3.UP*2.36,Vector3(.79,.045,.69),"#897953",.3)

func _cedar(p:Vector2,h:float) -> void:
	var o:=_at(p)
	w.model("Cedar",o,Vector3.ONE*h,"#ffffff",p.x)
	w.block_disc(o,h*.064,h*.55)

func _groves() -> void:
	for id:String in G.ZONES:
		var center:Vector2=G.CENTERS[id]
		var r:Vector2=G.RADII[id]
		var clusters:int={"snow":23,"forest":38,"tide":10,"desert":10,"volcano":12,"lake":24}[id]
		for i in clusters:
			var v:=Vector2.from_angle(rng.randf()*TAU)*sqrt(rng.randf())*.89
			var patch:=center+v*r*1.12
			for j in rng.randi_range(4,9):
				var p:=patch+Vector2(rng.randf_range(-11,11),rng.randf_range(-11,11))
				if not _flora_ok(id,p):continue
				var h:=rng.randf_range(4.7,9.6)
				match id:
					"snow":
						w.model("SnowFir",_at(p),Vector3.ONE*h,"#ffffff",p.x)
					"forest": _cedar(p,h*1.5)
					"lake": w._tree(p,h,true)
					"desert":
						if j%4==0:
							w.model("DunePear",_at(p),Vector3.ONE*(.85+h*.032),"#ffffff",p.x)
						else: _rock(p,Vector3(1.3,.66,.76),"#ba936b","#c7ac86",j)
					"volcano": _rock(p,Vector3(1.4,h*.35,1.2),"#68636c","#837879",j)
					"tide": _rock(p,Vector3(h*.32,h*.17,h*.23),"#77847a","#9fa89a",j)

func _flora_ok(id:String,p:Vector2) -> bool:
	if G.mainland_distance(p)<4.0 or float(G.region_mix(p).get(id,0.0))<.25:return false
	if w._road_distance(p)<4.6 or not w.is_walkable(p.x,p.y):return false
	for at:Vector2 in [G.CAMPS[id],G.ARENAS[id],G.HUNTS[id],G.ENTRANCES[id]]:
		if at.distance_squared_to(p)<17.0*17.0:return false
	return G.hazard_at(p)=="" and (id!="lake" or G.lake_distance(p)>5)

func _fishing_jetty() -> void:
	var anchor:Vector2=G.LAKE_LANDINGS[0]
	var dir:=anchor.direction_to(G.LAKE_CENTER)
	var side:=dir.orthogonal()
	var f:=Vector3(dir.x,0,dir.y)
	var v:=Vector3(side.x,0,side.y)
	var land:=_at(anchor)
	var quay:=Vector3(anchor.x,1.14,anchor.y)+f*8
	for sign_:float in [-1.0,1.0]:
		w.model("box",quay+v*sign_*1.16-f*1.5-Vector3.UP*.26,Vector3(.23,.39,5.6),"#675e4d",atan2(dir.x,dir.y))
		for i in 4:
			var pile:=quay+v*sign_*1.30+f*(i*1.55-3.3)
			w.model("8_92",pile-Vector3.UP*.44,Vector3(.23,2.5,.23),"#716654")
			w.model("8_99",pile+Vector3.UP*.58,Vector3(.24,.19,.24),"#b9a583")
			w.model("8_99",pile+Vector3.UP*.36,Vector3(.24,.07,.24),"#8e9a83")
	# Nets hung to dry, with lower corks and a taut headline.
	var rack:=land-v*3.9+f*.65
	var left:=rack-f*2.1+Vector3.UP*2.21
	var right:=rack+f*2.1+Vector3.UP*2.21
	for end:Vector3 in [left,right]: _beam(end-Vector3.UP*2.34,end+Vector3.UP*.28,.15,"#776a50","7_88")
	_beam(left,right,.084,"#97815f")
	for i in 12:
		var q:=left+f*(i*.34)
		_beam(q,q+f*.54-Vector3.UP*1.30,.026,"#a99a76")
		if i>1: _beam(q,q-f*.54-Vector3.UP*1.3,.026,"#a99a76")
		if i%3==0:w.model("7_85",q-Vector3.UP*.08,Vector3(.105,.23,.12),"#ae8566",i)
	for i in 4:
		var q:=rack+v*(.5+i*.38)
		w.model("8_86",q+Vector3.UP*.36,Vector3(.35,.72,.35),"#a58d69",i)
		w.model("8_99",q+Vector3.UP*.57,Vector3(.34,.08,.34),"#72776b",i)
	# An overturned spare dinghy rests clear of the three usable moorings.
	var hull:=_at(anchor-side*5.8-dir*3.1)
	for i in 9:
		var len:=(i-4)*.43
		var beam_width:=1.08*(1.0-.79*pow(absf(len)/1.74,1.65))
		var c:=hull+f*len
		w.model("box",c+Vector3.UP*.33,Vector3(beam_width*2,.45,.46),"#8f7557" if i%3 else "#ab8e6c",atan2(dir.x,dir.y))
		w.model("box",c+Vector3.UP*.60,Vector3(beam_width,.13,.46),"#91a39a",atan2(dir.x,dir.y))
		w.model("box",c+Vector3.UP*.70,Vector3(.13,.14,.46),"#776149",atan2(dir.x,dir.y))

func _reed_banks() -> void:
	var banks: Array[Vector2]=[Vector2(386,27),Vector2(390,-10),Vector2(398,44),Vector2(414,55),Vector2(462,57),Vector2(501,32),Vector2(506,-1)]
	for center:Vector2 in banks:
		for j in 27:
			var p:=center+Vector2(rng.randf_range(-4.2,4.2),rng.randf_range(-2.9,2.9))
			if G.lake_distance(p)<-5.8 or w._road_distance(p)<2.9:continue
			var root_h:=maxf(G.LAKE_LEVEL-.35,w.ground_height(p.x,p.y))
			var o:=Vector3(p.x,root_h,p.y)
			for k in 3:
				var h:=rng.randf_range(.83,1.90)
				var top:=o+Vector3(rng.randf_range(-.26,.26),h,rng.randf_range(-.23,.23))
				_beam(o+Vector3(k*.072,0,0),top,.05,"#8a9a6d","4_22")
				if k==1: w.model("7_73",top-Vector3.UP*.17,Vector3(.066,.36,.066),"#967859",j)
	for p:Vector2 in [Vector2(370,-8),Vector2(359,14),Vector2(371,34),Vector2(400,65),Vector2(365,63),Vector2(430,-54),Vector2(479,-38)]:
		if w._road_distance(p)>5.3 and p.distance_to(G.CAMPS.lake)>12 and p.distance_to(G.HUNTS.lake)>10:
			w._tree(p,rng.randf_range(8.2,13.6),true)

func _woodland_corridor() -> void:
	var route:Array=G.ROUTES.forest
	for i in range(route.find(G.ENTRANCES.forest)+1,route.size()):
		var a:Vector2=route[i-1]
		var b:Vector2=route[i]
		var f:=a.direction_to(b)
		var s:=f.orthogonal()
		var stations:=ceili(a.distance_to(b)/8)
		for j in stations:
			for sig:float in [-1.0,1.0]:
				var p:=a.lerp(b,(j+.25+rng.randf()*.48)/stations)+s*sig*rng.randf_range(7.1,12.2)
				if w._road_distance(p)<5.8 or p.distance_to(G.CAMPS.forest)<15 or p.distance_to(G.ARENAS.forest)<14 or p.distance_to(G.HUNTS.forest)<9:continue
				if (i+j)%3==0: _cedar(p,rng.randf_range(10.6,17.6))
				else: _fir(p,rng.randf_range(10.2,16.5))
	for tree:Vector2 in [Vector2(263,-236),Vector2(254,-226),Vector2(283,-232),Vector2(294,-210),Vector2(287,-204),Vector2(304,-260)]:
		if w._road_distance(tree)>4.9: _fir(tree,rng.randf_range(10.4,15.7))
	for span:Array in G.FOREST_BRIDGES:
		var a:Vector2=span[0]
		var b:Vector2=span[1]
		var v:=a.direction_to(b).orthogonal()
		for sig:float in [-1.0,1.0]:
			var q:=a+v*2.4*sig
			var root:=_at(q)
			for j in 5:
				var twig:=q+v*sig*(1.1+j*.50)+a.direction_to(b)*(sin(j*2.4)*1.5-.62)
				var tip:=_at(twig)+Vector3.UP*.15
				_beam(root+Vector3.UP*(.65+j*.12),tip,.22+j*.032,"#79674f","7_56")
				_beam(root+Vector3.UP*(.76+j*.12),tip+Vector3.UP*.11,.12,"#849268","6_50")
			var middle:=(a+b)*.5+v*1.30*sig
			var counter:=(_at(a).y+_at(b).y)*.5
			w.model("box",Vector3(middle.x,counter+.03,middle.y),Vector3(.41,.095,a.distance_to(b)*.62),"#849465",atan2(b.x-a.x,b.y-a.y))
	for p:Vector2 in [Vector2(282,-219),Vector2(290,-223),Vector2(272,-232)]:
		var o:=_at(p)
		for j in 3:
			var q:=o+Vector3(j*.46,j*.025,sin(j)*.34)
			w.model("7_79",q+Vector3.UP*.16,Vector3(.075,.32,.075),"#b2a58d")
			w.model("8_20",q+Vector3.UP*.37,Vector3(.26,.18,.24),"#b58e69",j)

func _fir(p:Vector2,h:float) -> void:
	var o:=_at(p)
	w.model("SilverFir",o,Vector3.ONE*h,"#ffffff",p.x*.4)
	w.block_disc(o,h*.043,h*.56)

# The paths between the six camps pass mixed stands before either province dominates.
# Keep trees away from the travel lane and protected camp/encounter centres.
func _mixed_roads() -> void:
	var paths: Array=G.OUTER_ROUTES.values().duplicate()
	for id:String in G.ZONES:
		var route:Array=G.ROUTES[id]
		paths.append(route.slice(maxi(route.find(G.ENTRANCES[id])-3,0),route.find(G.CAMPS[id])+1))
	for path:Array in paths:
		var gap:=rng.randf_range(8.,22.)
		for ix in range(1,path.size()):
			var a:Vector2=path[ix-1]
			var b:Vector2=path[ix]
			var f:=a.direction_to(b)
			var side:=f.orthogonal()
			var length:=a.distance_to(b)
			while gap<length:
				var sig:=1.0 if rng.randf()>.5 else -1.0
				var p:=a+f*gap+side*sig*rng.randf_range(10.0,23.0)
				gap+=rng.randf_range(22.0,45.0)
				for j in rng.randi_range(3,7):
					var q:=p+f*rng.randfn(0,3.6)+side*rng.randfn(0,2.4)
					var blend:=G.region_mix(q)
					var pick:=rng.randf()
					var habitat: String="home"
					for candidate:String in blend:
						pick-=float(blend[candidate])
						if pick<=0:
							habitat=candidate
							break
					if habitat=="home" or not _flora_ok(habitat,q):continue
					_wayside(q,habitat,rng.randf_range(.64,1.36),j)
			gap-=length

func _wayside(p:Vector2,habitat:String,s:float,variant:int) -> void:
	var o:=_at(p)
	match habitat:
		"snow":
			if variant==0: _fir(p,6.5*s)
			else: _rock(p,Vector3(1.96*s,1.22*s,.98*s),"#829399","#c6d1cd",p.x*.05)
		"tide":
			_rock(p,Vector3(2.04*s,.52*s,1.20*s),"#72877d","#a0a995",1.17+.14*variant)
		"volcano":
			for j in 4:
				var q:=o+Vector3(.75*(j%2),0,.72*(j/2))
				var h:=s*(.59+.55*absf(cos(j+variant)))
				w.model("6_94",q+Vector3.UP*h*.39,Vector3(s*.49,h,s*.48),"#68636b",.52)
		"desert":
			_rock(p,Vector3(1.71*s,.67*s,.89*s),"#bb9675","#c8aa80",.54)
			if variant==0:w.model("6_93",o+Vector3(.15,1.03*s,.14),Vector3(.86*s,.34*s,.52*s),"#b6936c",.54)
		"lake":
			if variant<2:w._tree(p,7.2*s,true)
			else:_rock(p,Vector3(1.53*s,.63*s,.95*s),"#829487","#a5af96",p.x)
		"forest":
			if variant%3==0:_fir(p,10.2*s)
			else:_cedar(p,10.5*s)
