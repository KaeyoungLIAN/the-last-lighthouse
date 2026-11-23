extends "island_art.gd"
## Coordinates are metres. Positive x is east and positive z is south.
const POINTS := {
	"spawn":Vector2(-38,36), "village":Vector2(-40,31), "forest":Vector2(-30,-15),
	"beach":Vector2(-65,2), "lake":Vector2(6,-32), "volcano":Vector2(48,-35),
	"tower":Vector2(41,32), "arena":Vector2(0,130), "mirror":Vector2(-6,128), "beacon":Vector2(0,123)
}
const RIVER := [Vector2(9,-48),Vector2(13,-40),Vector2(18,-32),Vector2(22,-24),Vector2(28,-20),Vector2(29,-12),Vector2(41,-7),Vector2(47,1),Vector2(58,8),Vector2(64,15),Vector2(87,29)]
const ROADS := [
	[Vector2(-38,36),Vector2(-40,31),Vector2(-36,22),Vector2(-39,12),Vector2(-38,0),Vector2(-30,-9),Vector2(-30,-15)],
	[Vector2(-38,0),Vector2(-48,-6),Vector2(-59,-4),Vector2(-65,2)],
	[Vector2(-30,-15),Vector2(-17,-22),Vector2(-7,-23),Vector2(1,-28),Vector2(6,-32)],
	[Vector2(6,-32),Vector2(11,-26),Vector2(17,-24),Vector2(27,-24),Vector2(39,-30),Vector2(48,-35)],
	[Vector2(-40,31),Vector2(-29,29),Vector2(-22,24),Vector2(-11,25),Vector2(2,21),Vector2(16,24),Vector2(26,24),Vector2(41,32)],
	[Vector2(-30,-15),Vector2(-22,-7),Vector2(-17,3),Vector2(-5,8),Vector2(2,15),Vector2(2,21)]
]
const TIDAL_TRACK := [Vector2(-40,31),Vector2(-47,27),Vector2(-54,15),Vector2(-60,8),Vector2(-65,2)]
const OCEAN_SHADER := """
shader_type spatial;
render_mode cull_disabled, diffuse_lambert;
varying vec3 world_pos;
void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
}
void fragment() {
	vec2 p = world_pos.xz;
	if(p.y > 108.0 && p.y < 153.0 && abs(p.x)<22.0){discard;}
	float ripple = sin(p.x * .79 + p.y * .39 + TIME * 1.2 + sin(p.y * .31 + TIME * .33) * 1.6);
	float broken = sin(p.y * 1.09 - p.x * .23 + sin(p.x * .44) + TIME * .32);
	float glint = smoothstep(.91,.99,ripple) * smoothstep(.58,.94,broken);
	float broad = .5 + .5 * sin(p.x * .13 + p.y * .16 + sin(p.x*.075 + TIME * .13));
	ALBEDO = mix(vec3(.034,.205,.235), vec3(.063,.34,.34),broad) + vec3(.20,.31,.30) * glint;
	ROUGHNESS = .64;
	SPECULAR = .27;
}
"""

var _sun := DirectionalLight3D.new()
var _environment := Environment.new()
var _sky_material := ProceduralSkyMaterial.new()
var _water := MeshInstance3D.new()
var _tide := 0.0
var _beam := Node3D.new()
var _tide_gate := StaticBody3D.new()
var _rng := RandomNumberGenerator.new()
var _last_daylight := -1.0

func _ready() -> void:
	_rng.seed = 29197
	prepare_art()
	_make_environment()
	_make_terrain()
	_make_landmarks()
	_dress_island()
	_make_arena()
	finish_art()
	set_conditions(0.85,0.15,false)

func _path_distance(p: Vector2, path: Array) -> float:
	var best := INF
	for i in range(1,path.size()):
		var a: Vector2 = path[i-1]
		var ab: Vector2 = path[i] - a
		var offset := p - a
		var delta := offset - ab * clampf(offset.dot(ab) / ab.length_squared(),0.0,1.0)
		best = minf(best, delta.length_squared())
	return sqrt(best)

func _road_distance(p: Vector2) -> float:
	var best := INF
	for road: Array in ROADS:
		best = minf(best,_path_distance(p,road))
	return best

func _coast_distance(x: float,z: float) -> float:
	var angle := atan2(z / 64.0,x / 82.0)
	return (1.0 + 0.038*sin(5*angle+1.2) + 0.026*cos(9*angle) - Vector2(x/82.0,z/64.0).length())*66.0

func _lake_distance(x: float,z: float) -> float:
	return (Vector2((x-0.5)/18.3,(z+47.2)/10.2).length()-1.0)*12.5

func _bridge(p: Vector2) -> bool:
	return absf(p.y+24.0) < 2.05 and p.x > 15.4 and p.x < 29.4

func _tidal_inlet(p: Vector2) -> float:
	# Long, narrow cove intersecting the coast. At ebb the sandy spine emerges.
	return (Vector2((p.x+73.0)/28.0,(p.y-16.0)/9.6).length()-1.0)*10.0

func _land_height(x: float,z: float) -> float:
	var p := Vector2(x,z)
	var coast := _coast_distance(x,z)
	var wave := 0.40*sin(x*.134+z*.075) + 0.28*cos(z*.17-x*.04)
	var h := lerpf(-2.8,1.60+wave,smoothstep(-2.1,4.2,coast))
	var cone := Vector2((x-52.0)*.97,z+49.0).length()
	h += maxf(0.0,1.0-cone/19.0)*13.0 - maxf(0.0,1.0-cone/4.5)*4.8
	var lake := _lake_distance(x,z)
	if lake<3.8:
		h = lerpf(-1.6,h,smoothstep(-.8,3.8,lake))
	if z > -51.0 and z < 36.0 and x > 2.0:
		var dist := _path_distance(p,RIVER)
		h = lerpf(-1.6,h,smoothstep(1.4,4.0,dist))
	var cove := _tidal_inlet(p)
	if cove < 2.5:
		var spine := 1.0-smoothstep(1.7,3.6,_path_distance(p,TIDAL_TRACK))
		h = lerpf(lerpf(-1.7,0.01,spine),h,smoothstep(-1.1,2.5,cove))
	# Both bridge abutments blend into the upper bank before the deck collider begins.
	if absf(z+24.0) < 6.0:
		var ramp := maxf(1.0-smoothstep(2.05,5.0,absf(x-15.0)),1.0-smoothstep(2.05,5.0,absf(x-29.6)))
		var shoulder := 1.0-smoothstep(2.1,5.8,absf(z+24.0))
		h = lerpf(h,2.44,ramp*shoulder)
	return h

func ground_height(x: float,z: float) -> float:
	if z > 100.0:
		return 0.0
	if _bridge(Vector2(x,z)):
		return 2.42
	return _land_height(x,z)

func is_walkable(x: float,z: float) -> bool:
	var p := Vector2(x,z)
	if z>100.0:
		return p.distance_squared_to(POINTS.arena) < 15.1*15.1 and not blocked(p)
	if _bridge(p):
		return true
	if _coast_distance(x,z)<-0.2:
		return false
	var cove := _tidal_inlet(p)
	if cove < 0.8:
		if _tide > 0.55 or _path_distance(p,TIDAL_TRACK)>2.25:
			return false
	return _land_height(x,z) > lerpf(-0.65,0.53,_tide) + 0.006 and not blocked(p)

func _point(x: float,z: float) -> Vector3:
	return Vector3(x,ground_height(x,z),z)

func _terrain_color(x: float,z: float,h: float) -> Color:
	var p := Vector2(x,z)
	var coast := _coast_distance(x,z)
	var road := _road_distance(p)
	var color := Color("#739780")
	if x< -12 and z<11:
		color = Color("#648870")
	if Vector2(x+31,z+16).length()<23.0:
		color = Color("#547d62")
	if x>28.0 and z < -18.0 + sin(x*.14)*3.8:
		color = Color("#947561") if h<3.5 else Color("#765e58")
		var crater := Vector2(x-52,z+49).length()
		if crater < 3.7:
			color = Color("#f6974d")
	if coast<3.8 or (x < -54.0 and z>-12.0 and z<23.0) or _tidal_inlet(p)<3.0:
		color = Color("#d8bd91")
	if coast<-0.5:
		color = Color("#6baca1")
	if road<1.8 and h>0.6:
		color = Color("#bfa47d") if x<28.0 or z>-15 else Color("#bb9b7b")
	elif road<2.5 and h>0.6:
		color = color.lerp(Color("#b2b182"),.56)
	if p.distance_squared_to(POINTS.village)<48.0:
		color = Color("#aa9876")
	if h< -0.3:
		color = Color("#72988b")
	return color

func _make_terrain() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const STEP := 2
	var locations := {}
	var colors := {}
	for z in range(-76,77,STEP):
		for x in range(-96,97,STEP):
			var point := Vector3(x,_land_height(x,z),z)
			locations[Vector2i(x,z)] = point
			var pigment := _terrain_color(x,z,point.y)
			colors[Vector2i(x,z)] = pigment.srgb_to_linear().lerp(pigment,.27)
	for z in range(-76,76,STEP):
		for x in range(-96,96,STEP):
			var a: Vector3 = locations[Vector2i(x,z)]
			var b: Vector3 = locations[Vector2i(x+STEP,z)]
			var c: Vector3 = locations[Vector2i(x+STEP,z+STEP)]
			var e: Vector3 = locations[Vector2i(x,z+STEP)]
			var triangles := [[a,b,c],[a,c,e]] if (x+z)%4==0 else [[a,b,e],[b,c,e]]
			for tri: Array in triangles:
				var val := _rng.randf_range(.972,1.024)
				var normal: Vector3 = (tri[2]-tri[0]).cross(tri[1]-tri[0]).normalized()
				for point: Vector3 in tri:
					var col: Color = colors[Vector2i(point.x,point.z)]
					st.set_color(Color(col.r*val,col.g*val,col.b*val))
					st.set_normal(normal)
					st.add_vertex(point)
	var terrain := MeshInstance3D.new()
	terrain.name = "FacetedIsland"
	terrain.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.96
	terrain.material_override = mat
	add_child(terrain)
	terrain.create_trimesh_collision()

func _make_environment() -> void:
	_environment.background_mode = Environment.BG_SKY
	_environment.sky = Sky.new()
	_sky_material.sky_curve = 0.32
	_sky_material.sun_angle_max = 2.0
	_sky_material.sun_curve = 0.09
	_environment.sky.sky_material = _sky_material
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	_environment.tonemap_white = 5.0
	_environment.fog_enabled = true
	_environment.fog_sky_affect = .21
	var env_node := WorldEnvironment.new()
	env_node.environment = _environment
	add_child(env_node)
	_sun.rotation_degrees = Vector3(-49,-38,0)
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 115
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	add_child(_sun)
	var sheet := PlaneMesh.new()
	sheet.size = Vector2(1450,1450)
	_water.mesh = sheet
	var shader := Shader.new()
	shader.code = OCEAN_SHADER
	var water_material := ShaderMaterial.new()
	water_material.shader = shader
	_water.material_override = water_material
	_water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_water)

func set_conditions(daylight: float,tide: float,lit: bool) -> void:
	_tide = clampf(tide,0.0,1.0)
	_water.position.y = lerpf(-.65,.53,_tide)
	_tide_gate.collision_layer = 1 if _tide>.55 else 0
	_beam.visible = lit
	if absf(daylight-_last_daylight)<0.002:
		return
	_last_daylight = daylight
	var t := clampf(daylight,0,1)
	_sun.light_energy = lerpf(0.14,0.59,t)
	_sun.light_color = Color("#b8d8ff").lerp(Color("#fff1da"),t)
	_environment.ambient_light_color = Color("#8192b5").lerp(Color("#e2eadf"),t)
	_environment.ambient_light_energy = lerpf(0.30,0.49,t)
	_environment.background_color = Color("#253d52").lerp(Color("#a8ccc5"),t)
	_sky_material.sky_top_color = Color("#14223e").lerp(Color("#7099b1"),t)
	_sky_material.sky_horizon_color = Color("#334354").lerp(Color("#d7d7ba"),t)
	_sky_material.ground_horizon_color = _sky_material.sky_horizon_color
	_sky_material.ground_bottom_color = Color("#1c353b")
	_environment.fog_light_color = Color("#213248").lerp(Color("#9dbcb2"),t)
	_environment.fog_density = lerpf(.013,.002,t)

func _process(delta: float) -> void:
	if _beam.visible:
		_beam.rotate_y(delta * 0.65)

func _box(base: Vector3, offset: Vector3, size: Vector3, color: String, angle: float = 0.0, glow: bool = false) -> void:
	model("box",base+offset,size,color,angle,glow)

func _round(base: Vector3, offset: Vector3, size: Vector3, color: String, form: String = "8_100", glow: bool = false) -> void:
	model(form,base+offset,size,color,0.0,glow)

func _house(p: Vector2, width: float, depth: float, wall: String, roof: String, chimney: bool = true) -> void:
	var o := _point(p.x,p.y)
	var h := width*.53
	_box(o,Vector3(0,h*.48,0),Vector3(width,h,depth),wall)
	_box(o,Vector3(0,.28,0),Vector3(width+.22,.62,depth+.22),"#77847b")
	model("roof",o+Vector3(0,h+width*.25,0),Vector3(width+1.05,width*.51,depth+1.1),roof)
	_box(o,Vector3(0,h+width*.49,0),Vector3(.18,.17,depth+1.15),"#415466")
	for x: float in [-.47,.47]:
		_box(o,Vector3(x*width,h*.49,depth*.51),Vector3(.18,h,.13),"#675944")
	for x: float in [-.29,.31]:
		_box(o,Vector3(x*width,h*.61,depth*.515),Vector3(width*.18,h*.33,.16),"#40565a")
		_box(o,Vector3(x*width,h*.61,depth*.515+.09),Vector3(width*.115,h*.24,.03),"#f7c477",0,true)
	_box(o,Vector3(0,.84,depth*.51),Vector3(width*.16,1.7,.2),"#574d41")
	_box(o,Vector3(0,.14,depth*.56),Vector3(width*.28,.22,.7),"#b9ac87")
	_box(o,Vector3(0,h*.76,depth*.51),Vector3(width,.13,.16),"#796047")
	# Exposed timbers and side windows keep cottages legible as the camera circles them.
	for sign_: float in [-1.0,1.0]:
		for z: float in [-.38,.10]:
			_box(o,Vector3(sign_*width*.51,h*.62,z*depth),Vector3(.13,h*.36,width*.21),"#56625b")
			_box(o,Vector3(sign_*(width*.51+.07),h*.61,z*depth),Vector3(.07,h*.25,width*.16),"#c3bd8f")
		for z: float in [-.47,-.18,.22,.47]:
			_box(o,Vector3(sign_*width*.504,h*.49,z*depth),Vector3(.14,h,.15),"#7d6c53")
		_box(o,Vector3(sign_*width*.505,h*.27,0),Vector3(.12,.12,depth),"#8d795a")
		_box(o,Vector3(sign_*width*.505,h*.93,0),Vector3(.19,.20,depth+.15),"#6d5b47")
	if chimney:
		_box(o,Vector3(width*.30,h+.85,-depth*.19),Vector3(.72,2.5,.85),"#887d70")
		_box(o,Vector3(width*.30,h+2.03,-depth*.19),Vector3(.86,.25,.98),"#585951")
	block_box(o,width,depth,h)

func _lamp(base: Vector3, height: float = 2.4) -> void:
	_box(base,Vector3(0,height*.5,0),Vector3(.21,height,.21),"#57493a")
	_box(base,Vector3(.32,height,0),Vector3(.79,.17,.18),"#66533c")
	_box(base,Vector3(.59,height-.35,0),Vector3(.45,.58,.45),"#523f31")
	_box(base,Vector3(.59,height-.35,0),Vector3(.5,.34,.5),"#ffd886",0,true)
	model("4_0",base+Vector3(.59,height-.01,0),Vector3(.44,.3,.44),"#495052",PI*.25)

func _barrel(base: Vector3, x: float, z: float, marked: bool = false) -> void:
	var ctr := Vector3(x,.63,z)
	_round(base,ctr,Vector3(.50,1.24,.50),"#9f7351")
	for y: float in [.23,.94]:
		_round(base,Vector3(x,y,z),Vector3(.53,.13,.53),"#4b5955")
	if marked:
		_box(base,Vector3(x,.66,z+.49),Vector3(.41,.40,.06),"#efc57b",0,true)

func _make_landmarks() -> void:
	# A warm crescent of buildings frames the first northbound road.
	_house(Vector2(-46,35),5.8,5.4,"#d5bea0","#536e7b")
	_house(Vector2(-49,29),4.7,4.8,"#e7cba3","#61727b",false)
	_house(Vector2(-43,43),5.4,5.3,"#c6b897","#97654e")
	_house(Vector2(-30,36),5.4,4.9,"#eac7a1","#586d7a")
	_house(Vector2(-35,45),4.7,5.6,"#ceba95","#645f64",false)
	var forge := _point(-43.3,26.7)
	_box(forge,Vector3(0,.7,0),Vector3(3.4,1.4,2.3),"#595c58")
	_box(forge,Vector3(0,1.39,0),Vector3(2.7,.28,1.8),"#ea8848",0,true)
	_round(forge,Vector3(-1.5,2.25,-.35),Vector3(.71,4.5,.71),"#5c6260","6_70")
	_round(forge,Vector3(-1.5,4.55,-.35),Vector3(.68,.24,.68),"#333f41")
	var anvil := _point(-40.9,29.4)
	_round(anvil,Vector3.UP*.4,Vector3(.62,.82,.62),"#77573f")
	_box(anvil,Vector3.UP*.92,Vector3(1.34,.3,.54),"#444f52")
	_box(anvil,Vector3(-.49,1.08,0),Vector3(.74,.14,.35),"#68787a")
	_village_details()
	_lamp(_point(-37.0,31.7))
	_lamp(_point(-38.7,20.9))
	_lamp(_point(-46.5,25.3),1.7)
	for i in 5:
		_barrel(_point(-50.8 + i*.86,39.0),0,0)
	var hut := Vector2(-32.2,-19.1)
	_house(hut,4.3,3.8,"#aaa584","#4c6254",false)
	var keypost := _point(-31.6,-15.8)
	_box(keypost,Vector3(0,.72,0),Vector3(.21,1.44,.20),"#775a3c")
	_box(keypost,Vector3(0,1.25,0),Vector3(.78,.48,.26),"#cfa958")
	_lamp(_point(-28.1,-17.0),1.8)
	_wreck()
	_pump_and_bridge()
	_kiln()
	_lighthouse()
	for p: Vector2 in [Vector2(-57,9),Vector2(-49,22)]:
		var post := _point(p.x,p.y)
		_box(post,Vector3(0,1.15,0),Vector3(.24,2.4,.26),"#706952")
		for y: float in [.7,1.3,1.9]:
			_box(post,Vector3(0,y,0),Vector3(.29,.18,.31),"#e8d9ab")
	_tide_gate.name = "HighTidePassage"
	add_child(_tide_gate)
	var shape := BoxShape3D.new()
	shape.size = Vector3(5.15,2.2,0.65)
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3(-54,.32,15)
	col.rotation.y = -.48
	_tide_gate.add_child(col)

func _village_details() -> void:
	# The striped market awning and smithy pennants break up the roofline at spawn.
	var stall := _point(-32.1,31.3)
	for x: float in [-1.35,1.35]:
		for z: float in [-.59,.59]:
			_box(stall,Vector3(x,1.12,z),Vector3(.13,2.24,.13),"#69583f")
	for k in 7:
		var pos := Vector3((k-3)*.45,2.30,0)
		_box(stall,pos,Vector3(.46,.14,1.75),"#ab6a52" if k%2==0 else "#d8c495")
		_box(stall,pos+Vector3(0,-.17,.81),Vector3(.46,.33,.10),"#ab6a52" if k%2==0 else "#d8c495")
	_box(stall,Vector3.UP*.83,Vector3(2.85,.23,1.12),"#9c7d55")
	for k in 3:
		_round(stall,Vector3(k*.7-.7,1.04,.1),Vector3(.27,.28,.23),"#a76840","6_65")
	var banner := _point(-42,32.3)
	_box(banner,Vector3(0,1.80,0),Vector3(.14,3.6,.15),"#695740")
	_box(banner,Vector3(.53,3.35,0),Vector3(1.18,.14,.15),"#8d7852")
	_box(banner,Vector3(.57,2.67,0),Vector3(.88,1.28,.08),"#ab664f")
	_box(banner,Vector3(.57,2.71,.065),Vector3(.42,.13,.04),"#e5c085")
	for k in 10:
		var x := -40.8+sin(k*1.31)*1.7
		var z := 32+k*.68
		model("6_93",_point(x,z)+Vector3.UP*.035,Vector3(.44,.08,.28),"#ab9f82",k*.83)

func _wreck() -> void:
	var o := _point(-67.6,-1.8)
	# The grounded hull exposes its ribs on one side.
	for i in 7:
		var x := (i-3)*1.02
		var wide := 1.53*(1.0-.54*pow(absf(x)/3.1,2.0))
		_box(o,Vector3(x,.72,-wide),Vector3(1.08,1.09,.22),"#80593e")
		model("box",o+Vector3(x,.58,wide),Vector3(.20,1.42,.23),"#775038",0,false,-.18)
		_box(o,Vector3(x,.19,0),Vector3(1.08,.34,wide*1.96),"#ad8960")
	model("box",o+Vector3(-.85,2.26,0),Vector3(.29,4.85,.3),"#675238",0,false,-.21)
	_box(o,Vector3(-.46,3.68,0),Vector3(2.75,.17,.20),"#745a41")
	_box(o,Vector3(.26,3.12,0),Vector3(1.19,1.04,.09),"#c3b497")
	_barrel(_point(-64.4,.5),0,0,true)
	_barrel(_point(-66.0,.35),0,0)
	block_box(o,6.7,2.35,1.0)

func _pump_and_bridge() -> void:
	var base := _point(3.0,-35.8)
	_house(Vector2(1.0,-35.8),3.7,3.45,"#b8c4b1","#667a7b",false)
	_box(base,Vector3(2.4,.50,0),Vector3(2.3,1.0,1.5),"#737f77")
	_round(base,Vector3(2.4,1.6,0),Vector3(.7,1.3,.7),"#568983")
	_box(base,Vector3(2.4,2.3,-1.09),Vector3(.26,.30,2.4),"#52696a")
	_barrel(_point(7.7,-33.2),0,0,true)
	for i in 20:
		var x := 15.3+i*.74
		_box(Vector3(x,2.31,-24),Vector3.ZERO,Vector3(.70,.22,4.12),"#a68964")
	for z: float in [-26.0,-22.0]:
		_box(Vector3(22.4,3.20,z),Vector3.ZERO,Vector3(14.6,.17,.17),"#725c48")
		for i in 6:
			_box(Vector3(15.5+i*2.8,1.8,z),Vector3.ZERO,Vector3(.23,3.3,.23),"#6d624e")
	var bridge := StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(14.8,.18,4.16)
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3(22.3,2.33,-24.0)
	bridge.add_child(col)
	add_child(bridge)

func _kiln() -> void:
	var o := _point(51.4,-37.7)
	_round(o,Vector3.UP*1.40,Vector3(2.02,2.8,2.02),"#645b52","8_69")
	_round(o,Vector3.UP*2.97,Vector3(1.38,.5,1.38),"#8a7764","8_85")
	_round(o,Vector3.UP*3.32,Vector3(.89,.36,.89),"#4c5254")
	_box(o,Vector3(0,.74,1.64),Vector3(1.18,1.4,.43),"#383e3b")
	_box(o,Vector3(0,.60,1.88),Vector3(.84,.78,.06),"#ef9159",0,true)
	block_disc(o,1.75,2.7)
	_barrel(_point(47.0,-36.8),0,0,true)
	_barrel(_point(45.8,-37.3),0,0)
	for x: float in [46.1,47.6,49.1]:
		model("6_100",_point(x,-39.3)+Vector3.UP*.55,Vector3(.39,1.12,.43),"#514d49",.2)

func _lighthouse() -> void:
	var o := _point(41,27.2)
	_round(o,Vector3.UP*.43,Vector3(3.88,.86,3.88),"#788176","12_92")
	_round(o,Vector3.UP*2.3,Vector3(3.08,3.22,3.08),"#dfd3b5","12_92")
	_round(o,Vector3.UP*5.06,Vector3(2.84,2.35,2.84),"#b96c56","12_90")
	_round(o,Vector3.UP*7.69,Vector3(2.55,2.94,2.55),"#e3d9b9","12_88")
	_round(o,Vector3.UP*10.15,Vector3(2.25,2.05,2.25),"#ae604d","12_90")
	_round(o,Vector3.UP*11.95,Vector3(2.04,1.63,2.04),"#ded2b5","12_92")
	_round(o,Vector3.UP*12.83,Vector3(2.95,.4,2.95),"#4f6465","12_100")
	for i in 12:
		var t := TAU*i/12.0
		var v := Vector3(cos(t),0,sin(t))
		_box(o,v*2.70+Vector3.UP*13.39,Vector3(.13,1,.13),"#4a6061")
		_box(o,v*1.70+Vector3.UP*14.13,Vector3(.19,2.3,.19),"#50635f")
	_round(o,Vector3.UP*14.08,Vector3(1.45,2.12,1.45),"#96aaa0","12_100")
	_round(o,Vector3.UP*15.85,Vector3(2.55,1.60,2.55),"#6d655a","12_9")
	_round(o,Vector3.UP*16.96,Vector3(.22,1.06,.22),"#464f4e","6_0")
	for dz: float in [-1.0,1.0]:
		_box(o,Vector3(0,7.25,2.48*dz),Vector3(.6,1.06,.16),"#425459")
	_box(o,Vector3(0,1.34,2.96),Vector3(1.82,2.53,.22),"#5d5850")
	_box(o,Vector3(0,1.19,3.1),Vector3(1.29,2.1,.15),"#7b6850")
	_lamp(o+Vector3(1.72,0,2.57),2.4)
	block_disc(o,2.94,12.9)
	add_child(_beam)
	_beam.position = o+Vector3.UP*14.25
	var lens := OmniLight3D.new()
	lens.light_color = Color("#ffc66d")
	lens.light_energy = 3.1
	lens.omni_range = 19.0
	_beam.add_child(lens)
	for sign_: float in [-1.0,1.0]:
		var cone := CylinderMesh.new()
		cone.radial_segments = 12
		cone.top_radius = 5.5
		cone.bottom_radius = .58
		cone.height = 34.0
		var shaft := MeshInstance3D.new()
		shaft.mesh = cone
		shaft.position.x = sign_*17.0
		shaft.rotation.z = -sign_*PI*.5
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1,.80,.38,.14)
		shaft.material_override = mat
		shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_beam.add_child(shaft)

func _tree(p: Vector2, height: float, broad: bool) -> void:
	var o := _point(p.x,p.y)
	var radius := height * .28
	var yaw := _rng.randf()*TAU
	model("6_67",o+Vector3.UP*height*.29,Vector3(height*.074,height*.58,height*.074),"#69583c",yaw)
	if broad:
		var green: String = ["#407c62","#578665","#4c8264"][_rng.randi_range(0,2)]
		model("7_80",o+Vector3.UP*height*.64,Vector3(radius,height*.34,radius*.89),green,yaw)
		model("7_14",o+Vector3.UP*height*.86,Vector3(radius*.81,height*.28,radius*.75),"#709a6e",yaw)
		model("6_30",o+Vector3(radius*.61,height*.62,radius*.12),Vector3(radius*.65,height*.38,radius*.64),"#63946b",yaw+.5)
	else:
		model("7_0",o+Vector3.UP*height*.52,Vector3(radius,height*.57,radius),"#385e50",yaw)
		model("7_0",o+Vector3.UP*height*.70,Vector3(radius*.84,height*.56,radius*.83),"#48745b",yaw+.22)
		model("7_0",o+Vector3.UP*height*.87,Vector3(radius*.56,height*.40,radius*.55),"#5e8969",yaw)
	block_disc(o,height*.073,height*.54)

func _distant_rocks() -> void:
	for info: Vector3 in [Vector3(-99,5,-30),Vector3(-109,9,-38),Vector3(-104,5.5,-35),Vector3(76,4,-70),Vector3(84,7,-82),Vector3(92,4,-72),Vector3(103,11,13),Vector3(97,6,15),Vector3(101,5,21),Vector3(31,6,78),Vector3(34,3,72)]:
		model("6_32",Vector3(info.x,info.y*.36,info.z),Vector3(info.y*.56,info.y,info.y*.42),"#687f7b",info.x)
	for i in 13:
		var angle := _rng.randf()*TAU
		var r := _rng.randf_range(116,190)
		var loc := Vector3(cos(angle)*r,_rng.randf_range(24,45),sin(angle)*r)
		for j in 3:
			var lump := loc+Vector3(j*4.1,absf(j-1)*-.7,j*.6)
			model("8_67",lump,Vector3(7.1,2.7-j*.28,3.9),"#c4d0cd",angle)
			model("8_29",lump+Vector3.UP*1.43,Vector3(4.5,1.5,2.9),"#e0e2d4",angle)

func _small_rock(p: Vector2, size: float, shade: String) -> void:
	model("6_46",_point(p.x,p.y)+Vector3.UP*size*.29,Vector3(size*.95,size*.79,size*.68),shade,_rng.randf()*TAU)

func _dressing_allowed(p: Vector2) -> bool:
	if _road_distance(p)<3.45 or _path_distance(p,TIDAL_TRACK)<3.1 or not is_walkable(p.x,p.y):
		return false
	for spot: Vector2 in POINTS.values():
		if spot.distance_squared_to(p)<30.0:
			return false
	return true

func _dress_island() -> void:
	# Authored groves leave sightlines from the village to the crater and the tower.
	for grove: Vector3 in [
		Vector3(-49,28,-21), Vector3(-35,25,-34),Vector3(-17,23,-32),Vector3(-15,15,-9),
		Vector3(-46,17,-11),Vector3(-53,11,0),Vector3(-38,10,5),Vector3(3,12,-9),
		Vector3(14,10,7),Vector3(21,9,36),Vector3(-9,13,36),Vector3(-31,7,48),
		Vector3(-64,9,-12),Vector3(56,8,27),Vector3(45,6,10),Vector3(14,7,-48),Vector3(-23,13,-46)
	]:
		for i in int(grove.y):
			var p := Vector2(grove.x+_rng.randf_range(-10.0,10.0),grove.z+_rng.randf_range(-9.0,9.0))
			if _dressing_allowed(p):
				_tree(p,_rng.randf_range(3.6,7.9),_rng.randf()<.54)
	for i in 2000:
		var p := Vector2(_rng.randf_range(-78.0,78.0),_rng.randf_range(-63.0,61.0))
		var height := _land_height(p.x,p.y)
		if height<.25 or blocked(p) or _bridge(p):
			continue
		var rd := _road_distance(p)
		if rd < 1.26:
			if _rng.randf() < .30:
				var offset := _point(p.x,p.y)
				model("6_74",offset+Vector3.UP*.032,Vector3(.36,.072,.24),"#b5ab8d",_rng.randf()*TAU)
			continue
		if p.x>27.0 and p.y< -19.0:
			_small_rock(p,_rng.randf_range(.35,1.35),"#6c6061")
		elif _coast_distance(p.x,p.y)<4.0 or (p.x< -54 and p.y>-9 and p.y<22):
			if _rng.randf()<.56:
				_small_rock(p,_rng.randf_range(.21,.67),"#a7aa93")
		elif _rng.randf()<.83:
			var o := _point(p.x,p.y)
			var color: String = ["#648254","#8fa565","#83985f","#80995e"][_rng.randi_range(0,3)]
			for j in 3:
				var h := _rng.randf_range(.28,.72)
				model("3_0",o+Vector3(j*.15,h*.5,cos(j)*.14),Vector3(.14,h,.11),color,_rng.randf()*TAU,false,_rng.randf_range(-.27,.27))
			if _rng.randf()<.12 and p.x>-55:
				model("5_34",o+Vector3(.18,.47,.02),Vector3(.11,.17,.12),"#eadbb0",0)
	for i in 56:
		var a := _rng.randf()*TAU
		var p := Vector2(.5+cos(a)*19.7,-47.2+sin(a)*11.4)
		if _bridge(p) or p.distance_to(POINTS.lake)<3.0:
			continue
		var o := _point(p.x,p.y)
		for j in 3:
			model("4_22",o+Vector3(j*.17,.56,j*.08),Vector3(.07,1.28,.07),"#ad9a64",j*.5,false,.12)
	for p: Vector2 in [Vector2(-36,15),Vector2(-43,-3),Vector2(-14,-22),Vector2(10,-25),Vector2(13,22),Vector2(34,28)]:
		var post := _point(p.x,p.y)
		_box(post,Vector3(0,.91,0),Vector3(.19,1.84,.19),"#79664a")
		_box(post,Vector3(.24,1.48,0),Vector3(1.13,.25,.16),"#c19f6c",.27)
	_distant_rocks()

func _make_arena() -> void:
	var o := Vector3(0,0,130)
	_round(o,Vector3.DOWN*.70,Vector3(17,1.34,17),"#484e50","24_100")
	_round(o,Vector3.DOWN*.035,Vector3(14.4,.05,14.4),"#606361","24_100")
	_round(o,Vector3.DOWN*.005,Vector3(10.7,.035,10.7),"#5d5f5d","24_100")
	var shape := CylinderShape3D.new()
	shape.radius = 16.6
	shape.height = 1.5
	var floor_col := CollisionShape3D.new()
	floor_col.shape = shape
	floor_col.position = o+Vector3.DOWN*.75
	_solid.add_child(floor_col)
	for i in 32:
		var t := TAU*i/32.0
		var v := Vector3(sin(t),0,cos(t))
		var h := 10.6
		var wall := o+v*16.18
		model("box",wall+Vector3.UP*h*.5,Vector3(3.4,h,.94),"#586060",t)
		model("box",wall+Vector3.UP*(h+.10),Vector3(3.5,.34,1.1),"#7d8177",t)
		var brick := BoxShape3D.new()
		brick.size = Vector3(3.46,h,.88)
		var wall_col := CollisionShape3D.new()
		wall_col.shape = brick
		wall_col.rotation.y = t
		wall_col.position = wall + Vector3.UP*h*.5
		_solid.add_child(wall_col)
		model("box",o+v*11.8+Vector3.UP*.025,Vector3(1.93,.035,.16),"#9c916c",t)
		if i%4==0:
			var pillar := o+v*15.3
			_round(pillar,Vector3.UP*1.86,Vector3(.72,3.8,.72),"#686c68")
			_round(pillar,Vector3.UP*3.88,Vector3(.78,.29,.78),"#9e916d")
			model("6_0",pillar+Vector3.UP*4.26,Vector3(.48,.7,.48),"#ffb766",t,true)
	_round(o,Vector3.UP*10.95,Vector3(17,.68,17),"#363e41","32_100")
	for j in 4:
		var ang := j*TAU/4.0 + .8
		var torch := OmniLight3D.new()
		torch.position = o+Vector3(cos(ang)*11,3.9,sin(ang)*11)
		torch.light_color = Color("#fbc38e")
		torch.light_energy = 1.7
		torch.omni_range = 17.0
		add_child(torch)
	# Split the high wall into masonry rings with inset brass lantern panels.
	for k in 24:
		var ang := TAU*k/24.0
		var out := Vector3(sin(ang),0,cos(ang))
		for y: float in [2.0,5.8,8.8]:
			model("box",o+out*15.72+Vector3.UP*y,Vector3(4.22,.16,.22),"#79796e",ang)
		if k%3==0:
			var w := o+out*15.55
			model("box",w+Vector3.UP*5.9,Vector3(1.79,3.3,.33),"#8d826b",ang)
			model("box",w-out*.19+Vector3.UP*5.94,Vector3(1.36,2.88,.13),"#698a90",ang,true)
			model("box",w-out*.29+Vector3.UP*5.94,Vector3(.13,2.89,.12),"#746c5e",ang)
			model("box",w-out*.29+Vector3.UP*5.97,Vector3(1.37,.13,.12),"#746c5e",ang)
	var mirror := Vector3(-7.3,0,127)
	_round(mirror,Vector3.UP*.22,Vector3(1.23,.46,1.23),"#8b8774")
	_box(mirror,Vector3.UP*1.31,Vector3(.34,2.1,.40),"#996f46")
	model("box",mirror+Vector3.UP*1.95,Vector3(1.90,1.40,.20),"#c5a96d",-.54,false,.15)
	model("box",mirror+Vector3(.04,1.95,.13),Vector3(1.60,1.14,.13),"#98ced1",-.54,true,.15)
	var burner := Vector3(0,0,120.6)
	_round(burner,Vector3.UP*.31,Vector3(1.8,.62,1.8),"#92836a","10_90")
	_round(burner,Vector3.UP*1.08,Vector3(1.18,1.2,1.18),"#665d52","10_85")
	_round(burner,Vector3.UP*1.95,Vector3(1.34,.66,1.34),"#bb9862","10_72")
	for x: float in [-1.,1.]:
		_box(burner,Vector3(x*.77,2.64,0),Vector3(.17,1.66,.19),"#817350")
	model("6_30",burner+Vector3.UP*2.70,Vector3(.54,1.23,.54),"#ffd598",0,true)
