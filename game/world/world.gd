extends "island_art.gd"
const Geo = preload("expedition_geography.gd")
const Survey = preload("island_survey.gd")
const CoastalPlants = preload("coastal_plants.gd")
const CREST_ORDER = preload("res://expedition_voyage.gd").ORDER
## Coordinates are metres. Positive x is east and positive z is south.
const POINTS := {
	"spawn":Vector2(-38,36), "village":Vector2(-40,31), "forest":Vector2(-30,-15),
	"beach":Vector2(-65,2), "lake":Vector2(6,-32), "volcano":Vector2(48,-35),
	"highmoor":Vector2(-7,-94), "observatory":Vector2(76,-112), "windmill":Vector2(153,-54),
	"outerport":Vector2(202,27), "saltworks":Vector2(110,83), "bellcape":Vector2(65,109),
	"tower":Vector2(41,32), "arena":Vector2(0,130), "mirror":Vector2(-6,128), "beacon":Vector2(0,123)
}
const RIVER := [Vector2(9,-48),Vector2(13,-40),Vector2(18,-32),Vector2(22,-24),Vector2(28,-20),Vector2(29,-12),Vector2(41,-7),Vector2(47,1),Vector2(58,8),Vector2(64,15),Vector2(87,29),Vector2(113,22),Vector2(140,24),Vector2(155,18),Vector2(175,15),Vector2(198,10),Vector2(240,-3),Vector2(260,-9)]
static var ROADS: Array = [
	[Vector2(-38,36),Vector2(-40,31),Vector2(-36,22),Vector2(-39,12),Vector2(-38,0),Vector2(-30,-9),Vector2(-30,-15)],
	[Vector2(-38,0),Vector2(-48,-6),Vector2(-59,-4),Vector2(-65,2)],
	[Vector2(-30,-15),Vector2(-17,-22),Vector2(-7,-23),Vector2(1,-28),Vector2(6,-32)],
	[Vector2(6,-32),Vector2(11,-26),Vector2(17,-24),Vector2(27,-24),Vector2(39,-30),Vector2(48,-35)],
	[Vector2(-40,31),Vector2(-29,29),Vector2(-22,24),Vector2(-11,25),Vector2(2,21),Vector2(16,24),Vector2(26,24),Vector2(41,32)],
	[Vector2(-30,-15),Vector2(-22,-7),Vector2(-17,3),Vector2(-5,8),Vector2(2,15),Vector2(2,21)]
] + Survey.EAST_ROADS
const TIDAL_TRACK := [Vector2(-40,31),Vector2(-47,27),Vector2(-54,15),Vector2(-60,8),Vector2(-65,2)]

var _expedition := preload("expedition_terrain.gd").new()
var _road_cells := {}
var _sun := DirectionalLight3D.new()
var _environment := Environment.new()
var _sky_material := ShaderMaterial.new()
var _water := MeshInstance3D.new()
var _tide := 0.0
var _beam := Node3D.new()
var _tower_optic: MeshInstance3D
var _lit_crystal := ShaderMaterial.new()
var _crest_register: Node3D
var _beacon_ritual := preload("beacon_ritual.gd").new()
var _crest_mask := 0
var _register_lit := false
var _tide_gate := StaticBody3D.new()
var _rng := RandomNumberGenerator.new()
var _last_daylight := -1.0
var _lantern_glass := ShaderMaterial.new()
var _lantern_halo := StandardMaterial3D.new()
var _lantern_poses: Array[Transform3D] = []
var _road_lights: Array[OmniLight3D] = []
var _inside_room := false
var _last_lamp_view := Vector3.INF
var _lamp_strength := 0.0

func _ready() -> void:
	_rng.seed = 29197
	prepare_art()
	_index_trails()
	_make_environment()
	_expedition.build(self)
	_make_landmarks()
	preload("outer_coast.gd").new().build(self)
	for id: String in Geo.ZONES:
		var camp: Vector2=Geo.CAMPS[id]
		var road: Array=Geo.ROUTES[id]
		var index:=road.find(camp)
		var side: Vector2=(road[index+1]-road[index-1]).normalized().orthogonal()
		var point:=camp-side*4.25
		_lamp(_point(point.x,point.y),2.85)
	_make_road_lamps()
	_dress_island()
	preload("expedition_landmarks.gd").new().build(self)
	var harbor_life := preload("res://world/harbor_life.gd").new()
	add_child(harbor_life)
	harbor_life.build(self)
	_building_room = true
	_make_arena()
	_building_room = false
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

func _index_trails() -> void:
	var trails := ROADS + Geo.ROUTES.values() + Geo.OUTER_ROUTES.values() + [Geo.LAKE_SHORE_ROAD,Geo.TIDAL_SPIT,Geo.FOREST_BRANCH,Geo.MOSS_PATH]
	for route: Array in trails:
		for i in range(1,route.size()):
			var a: Vector2 = route[i-1]
			var b: Vector2 = route[i]
			var endpoints := PackedVector2Array([a,b])
			var from := Vector2i((a.min(b)-Vector2.ONE*8.0).floor())
			var to := Vector2i((a.max(b)+Vector2.ONE*8.0).ceil())
			for cz in range(floori(from.y/16.0),floori(to.y/16.0)+1):
				for cx in range(floori(from.x/16.0),floori(to.x/16.0)+1):
					var cell := Vector2i(cx,cz)
					if not _road_cells.has(cell):
						_road_cells[cell] = []
					_road_cells[cell].append(endpoints)

func _road_distance(p: Vector2) -> float:
	var cell := Vector2i((p/16.0).floor())
	var best := 8.0 * 8.0
	for seg: PackedVector2Array in _road_cells.get(cell,[]):
		var q := Geometry2D.get_closest_point_to_segment(p,seg[0],seg[1])
		best = minf(best,p.distance_squared_to(q))
	return sqrt(best)

func _coast_distance(x: float,z: float) -> float:
	return Survey.coast_distance(Vector2(x,z))

func _lake_distance(x: float,z: float) -> float:
	return (Vector2((x-0.5)/18.3,(z+47.2)/10.2).length()-1.0)*12.5

func _bridge(p: Vector2) -> bool:
	return (absf(p.y+24.0) < 2.05 and p.x > 15.4 and p.x < 29.4) or (absf(p.x-175.0)<2.05 and p.y>8.0 and p.y<22.0)

func _on_jetty(p: Vector2) -> bool:
	return absf(p.x-207)<1.82 and absf(p.y-13.33)<5.57

func _tidal_inlet(p: Vector2) -> float:
	# Long, narrow cove intersecting the coast. At ebb the sandy spine emerges.
	return (Vector2((p.x+73.0)/28.0,(p.y-16.0)/9.6).length()-1.0)*10.0

func _land_height(x: float,z: float) -> float:
	var p := Vector2(x,z)
	var coast := _coast_distance(x,z)
	var wave := 0.40*sin(x*.134+z*.075) + 0.28*cos(z*.17-x*.04)
	var h := lerpf(-2.8,1.60+wave,smoothstep(-2.1,4.2,coast))
	# Outer ridges rise gradually from the original lowlands. The salt pans remain level.
	var ridge := 1.0 - smoothstep(6,47,p.distance_to(POINTS.highmoor))
	var cliff := 1.0 - smoothstep(8,41,p.distance_to(POINTS.observatory))
	var cape := 1.0 - smoothstep(6,36,p.distance_to(POINTS.bellcape))
	var fields := 1.0 - smoothstep(5,48,p.distance_to(POINTS.windmill))
	h += (ridge*7.1 + cliff*9.0 + cape*6.8 + fields*3.1)*smoothstep(1.5,9.0,coast)
	var cone := Vector2((x-52.0)*.97,z+49.0).length()
	h += maxf(0.0,1.0-cone/19.0)*13.0 - maxf(0.0,1.0-cone/4.5)*4.8
	var lake := _lake_distance(x,z)
	if lake<3.8:
		h = lerpf(-1.6,h,smoothstep(-.8,3.8,lake))
	if z > -53.0 and z < 35.0 and x > 2.0:
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
	if absf(x-175.0)<5.0:
		var ramp := maxf(1.0-smoothstep(.8,4.8,absf(z-8)),1.0-smoothstep(.8,4.8,absf(z-22)))
		h = lerpf(h,2.0,ramp*(1.0-smoothstep(2.0,5.0,absf(x-175))))
	if p.x>98 and p.x<136 and p.y>83 and p.y<104:
		var edge := (p-Vector2(117,94)).abs()-Vector2(13.7,6.7)
		h = lerpf(h,1.65,1.0-smoothstep(0,4,maxf(edge.x,edge.y)))
	if absf(x-207)<4.5:
		var landing := (1.0-smoothstep(1.8,4.5,absf(x-207)))*(1.0-smoothstep(.7,4.5,absf(z-18.9)))
		h = lerpf(h,2.24,landing)
	return h

func _surface_height(x: float,z: float) -> float:
	return _expedition.terrain_height(Vector2(x,z))

func ground_height(x: float,z: float) -> float:
	var p:=Vector2(x,z)
	if Survey.in_mirror_room(p): return 0.0
	if _on_jetty(p): return 2.24
	if _bridge(p): return 2.0 if x>100 else 2.42
	return _expedition.surface(p)

func is_walkable(x: float,z: float) -> bool:
	var p:=Vector2(x,z)
	if Survey.in_mirror_room(p):
		return p.distance_squared_to(POINTS.arena)<15.1*15.1 and not blocked(p)
	if _bridge(p) or _on_jetty(p): return true
	if _tidal_inlet(p)<.8 and (_tide>.55 or _path_distance(p,TIDAL_TRACK)>2.25):
		return false
	var water:=lerpf(-.65,.53,_tide)
	if x>360 and Geo.lake_distance(p)<4.5: water=Geo.LAKE_LEVEL
	return _expedition.surface(p)>water+.015 and not blocked(p)

func _point(x: float,z: float) -> Vector3:
	return Vector3(x,ground_height(x,z),z)

func _terrain_color(x: float,z: float,h: float) -> Color:
	var p := Vector2(x,z)
	var coast := _coast_distance(x,z)
	var color := Color("#739780")
	if x< -12 and z<11:
		color = Color("#648870")
	if Vector2(x+31,z+16).length()<23.0:
		color = Color("#547d62")
	if p.distance_to(Vector2(52,-49)) < 30.0 and x>28.0 and z < -18.0 + sin(x*.14)*3.8:
		color = Color("#947561") if h<3.5 else Color("#765e58")
		var crater := Vector2(x-52,z+49).length()
		if crater < 3.7:
			color = Color("#f6974d")
	if p.distance_to(POINTS.highmoor)<37:
		color = color.lerp(Color("#69917a"),.75)
	if p.distance_to(POINTS.observatory)<39:
		color = color.lerp(Color("#889aa3"),.76)
	if p.distance_to(POINTS.saltworks)<34:
		color = color.lerp(Color("#c7c09a"),.83)
	if p.distance_to(POINTS.windmill)<43:
		color = color.lerp(Color("#adb06c"),.73)
	if (coast<3.8 and Geo.inlet_distance(p)<4.0) or (x < -54.0 and z>-12.0 and z<23.0) or _tidal_inlet(p)<3.0:
		color = Color("#d8bd91")
	if x>16 and x<46 and z>33 and z<65 and coast<3.8:
		color = Color("#99998c").lerp(Color("#ccbe98"),smoothstep(-.4,2.5,coast))
	if coast<-0.5 and Geo.inlet_distance(p)<-1.0:
		color = Color("#6baca1")
	if p.distance_squared_to(POINTS.village)<48.0:
		color = Color("#aa9876")
	if h< -0.3:
		color = Color("#72988b")
	return color

func _make_environment() -> void:
	_environment.background_mode = Environment.BG_SKY
	_environment.sky = Sky.new()
	_sky_material.shader = preload("res://world/coastal_sky.gdshader")
	_sky_material.set_shader_parameter("cloud_study", preload("res://art/atmosphere/cloud_study.png"))
	_environment.sky.sky_material = _sky_material
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	_environment.tonemap_white = 5.0
	_environment.fog_enabled = true
	_environment.fog_sky_affect = .10
	var env_node := WorldEnvironment.new()
	env_node.environment = _environment
	add_child(env_node)
	_sun.name = "LGT_Key_CoastalSky"
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 115
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	add_child(_sun)
	var sheet := PlaneMesh.new()
	sheet.size = Vector2(1450,1450)
	_water.mesh = sheet
	var water_material := ShaderMaterial.new()
	water_material.shader = preload("coastal_water.gdshader")
	water_material.set_shader_parameter("seabed", preload("res://art/terrain/coastal_bathymetry.png"))
	_water.material_override = water_material
	_water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_water)

func set_conditions(daylight: float,tide: float,lit: bool) -> void:
	_tide = clampf(tide,0.0,1.0)
	_water.position.y = lerpf(-.65,.53,_tide)
	_tide_gate.collision_layer = 1 if _tide>.55 else 0
	if _beam.visible != lit:
		_beam.visible = lit
		_tower_optic.material_override = _lit_crystal if lit else null
	if absf(daylight-_last_daylight)<0.002:
		return
	_last_daylight = daylight
	var t := clampf(daylight,0,1)
	var was_dark := _lamp_strength > .001
	_lamp_strength = 1.0 - smoothstep(0.10,0.62,t)
	_lantern_glass.set_shader_parameter("flame",_lamp_strength)
	_lantern_halo.albedo_color = Color(1.0,.66,.34,_lamp_strength)
	for light in _road_lights:
		light.light_energy = 4.0 * _lamp_strength
		if _lamp_strength <= .001:
			light.hide()
	if not was_dark:
		_last_lamp_view = Vector3.INF
	var sunset := 1.0 - smoothstep(.0,.51,absf(t-.44))
	var elevation := lerpf(15.,50.,smoothstep(.32,1.,t)) + 16.*(1.-smoothstep(.02,.27,t))
	_sun.rotation_degrees = Vector3(-elevation,lerpf(-77.,-38.,t),0)
	_sun.light_energy = lerpf(.22,.68,t)
	_sun.light_color = Color("#b6d0fa").lerp(Color("#fff0d4"),t).lerp(Color("#ffc48e"),sunset*.84)
	_environment.ambient_light_color = Color("#adbad7").lerp(Color("#d6e5e7"),t)
	_environment.ambient_light_energy = lerpf(.38,.60,t)
	_sky_material.set_shader_parameter("daylight",t)
	_environment.fog_light_color = Color("#354960").lerp(Color("#c6d6d4"),t).lerp(Color("#d1a7a4"),sunset*.70)
	_environment.fog_density = lerpf(.0095,.0022,t)

func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera:
		var p := camera.global_position
		var indoor := Survey.in_mirror_room(Vector2(p.x,p.z))
		if indoor != _inside_room:
			_inside_room = indoor
			for item: Node3D in _room_art:
				item.visible = indoor
			_water.material_override.set_shader_parameter("inside_mirror_room",indoor)
	if _beam.visible:
		_beam.rotate_y(delta * 0.65)
	if _lamp_strength > .001:
		_update_nearby_lamps()

func _update_nearby_lamps() -> void:
	# Leave room in Compatibility's per-mesh light budget for the keeper and quest lights.
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var eye := to_local(camera.global_position)
	if eye.distance_squared_to(_last_lamp_view) < .36:
		return
	_last_lamp_view = eye
	var nearest := _road_lights.duplicate()
	nearest.sort_custom(func(a: OmniLight3D,b: OmniLight3D):
		return eye.distance_squared_to(a.position) < eye.distance_squared_to(b.position))
	for i in nearest.size():
		var light: OmniLight3D = nearest[i]
		light.visible = i < 3 and eye.distance_squared_to(light.position) < 25.0*25.0

func _box(base: Vector3, offset: Vector3, size: Vector3, color: String, angle: float = 0.0, glow: bool = false) -> void:
	model("box",base+offset,size,color,angle,glow)

func _round(base: Vector3, offset: Vector3, size: Vector3, color: String, form: String = "8_100", glow: bool = false) -> void:
	model(form,base+offset,size,color,0.0,glow)

const PILOT_COTTAGE := preload("res://art/greybay/pilot.glb")
const POTTER_COTTAGE := preload("res://art/greybay/potter.glb")
const SAIL_LOFT := preload("res://art/greybay/loft.glb")
const FIELD_CABIN := preload("res://art/greybay/cabin.glb")

func _house(p: Vector2, width: float, depth: float, scene: PackedScene) -> void:
	var base := _point(p.x,p.y)
	var cottage := scene.instantiate() as Node3D
	cottage.position = base
	cottage.scale = Vector3(width, width, depth) / 5.0
	add_child(cottage)
	block_box(base, width, depth, width * .53)

func _lamp(base: Vector3, height: float = 3.0) -> void:
	# Each bracket points inwards over the nearest trail, including at bends.
	var foot := Vector2(base.x,base.z)
	var toward := Vector2(INF,INF)
	for road: Array in ROADS+Geo.ROUTES.values():
		for i in range(1,road.size()):
			var offset := Geometry2D.get_closest_point_to_segment(foot,road[i-1],road[i]) - foot
			if offset.length_squared() < toward.length_squared():
				toward = offset
	var forward := Vector3(toward.x,0,toward.y).normalized()
	var yaw := atan2(-forward.z,forward.x)
	var arm := base + Vector3.UP * height
	var lens := arm + forward * .88 - Vector3.UP * .58

	# Granite shoe, tarred mast and salt-weathered enamel wayfinding band.
	model("8_84", base + Vector3.UP * .15, Vector3(.32,.40,.32), "#777b6f", yaw)
	model("8_68", base + Vector3.UP * (height*.5), Vector3(.155,height,.155), "#73553d", yaw)
	for y: float in [.40,.51,height-.16]:
		model("8_100",base+Vector3.UP*y,Vector3(.156,.065,.156),"#465251",yaw)
	model("8_96",base+Vector3.UP*1.24,Vector3(.141,.27,.141),"#d3c399",yaw)
	model("8_96",base+Vector3.UP*1.19,Vector3(.143,.065,.143),"#51746e",yaw)
	model("box",arm+forward*.40,Vector3(1.15,.14,.15),"#495c58",yaw)
	model("box",arm+forward*.29-Vector3.UP*.23,Vector3(.79,.085,.095),"#677974",yaw,false,-.61)
	model("8_100",arm+forward*.88-Vector3.UP*.10,Vector3(.043,.20,.043),"#a38755",yaw)
	# Flared verdigris hood, brass edging, a six-sided ribbed chimney and oil reservoir.
	model("6_22",lens+Vector3.UP*.32,Vector3(.36,.23,.36),"#526f68",yaw)
	model("6_100",lens+Vector3.UP*.21,Vector3(.366,.038,.366),"#b19259",yaw)
	model("6_85",lens-Vector3.UP*.26,Vector3(.205,.12,.205),"#4c5e58",yaw)
	model("6_100",lens-Vector3.UP*.20,Vector3(.256,.052,.256),"#ae8b55",yaw)
	for i in 6:
		var angle := TAU*i/6.0 - yaw
		var rib := Vector3(cos(angle),0,sin(angle))*.241
		model("box",lens+rib,Vector3(.033,.42,.033),"#475852",yaw)
	_lantern_poses.append(Transform3D(Basis(Vector3.UP,yaw).scaled_local(Vector3(.232,.40,.232)),lens))
	block_disc(base,.21,height)

	var light := OmniLight3D.new()
	light.hide()
	light.name = "RoadLantern"
	light.position = lens
	light.light_color = Color("#ffc17b")
	light.omni_range = 8.5
	light.omni_attenuation = 1.15
	light.distance_fade_enabled = true
	light.distance_fade_begin = 17.0
	light.distance_fade_length = 8.0
	add_child(light)
	_road_lights.append(light)

func _make_road_lamps() -> void:
	# Keep the tidal shortcut clear and mark both dry ends of the lake bridge.
	for foot: Vector2 in [
		Vector2(-35.7,5.5),Vector2(-36.1,-6.5),Vector2(-51.1,-2.8),Vector2(-62.6,-4.0),
		Vector2(-23.5,-15.4),Vector2(-2.3,-22.9),Vector2(15.0,-26.9),Vector2(30.8,-23.0),
		Vector2(43.4,-35.4),Vector2(-24.8,29.2),Vector2(-7.2,26.6),Vector2(11.6,20.4),
		Vector2(30.8,29.5),Vector2(-16.3,-1.4),Vector2(0.3,9.7)
	]:
		_lamp(_point(foot.x,foot.y))
	for route: Array in Survey.EAST_ROADS:
		var distance_left := 12.0
		for i in range(1,route.size()):
			var a: Vector2 = route[i-1]
			var segment: Vector2 = route[i]-a
			var dir := segment.normalized()
			while distance_left < segment.length():
				var foot := a + dir*distance_left + dir.orthogonal()*2.75
				if is_walkable(foot.x,foot.y) and not _bridge(foot) and _road_distance(foot)>1.95 and not _at_outer_plaza(foot):
					_lamp(_point(foot.x,foot.y))
				distance_left += 18.0
			distance_left -= segment.length()
	_lantern_glass.shader = preload("road_lantern_glass.gdshader")
	var glass := MultiMesh.new()
	glass.transform_format = MultiMesh.TRANSFORM_3D
	glass.mesh = _frustum(6,1.0)
	glass.instance_count = _lantern_poses.size()
	for i in _lantern_poses.size():
		glass.set_instance_transform(i,_lantern_poses[i])
	var panes := MultiMeshInstance3D.new()
	panes.name = "LanternGlass"
	panes.multimesh = glass
	panes.material_override = _lantern_glass
	add_child(panes)
	_make_lantern_halos()

func _make_lantern_halos() -> void:
	var falloff := Gradient.new()
	falloff.offsets = PackedFloat32Array([0.0,.22,.49,.77,1.0])
	falloff.colors = PackedColorArray([
		Color(1,1,1,.40),Color(1,1,1,.21),Color(1,1,1,.075),
		Color(1,1,1,.016),Color(1,1,1,0.0)])
	var haze := GradientTexture2D.new()
	haze.gradient = falloff
	haze.fill = GradientTexture2D.FILL_RADIAL
	haze.fill_from = Vector2(.5,.5)
	haze.fill_to = Vector2(1.0,.5)
	_lantern_halo.albedo_texture = haze
	_lantern_halo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_lantern_halo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_lantern_halo.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_lantern_halo.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var veil := QuadMesh.new()
	veil.size = Vector2(1.9,1.9)
	var halos := MultiMesh.new()
	halos.transform_format = MultiMesh.TRANSFORM_3D
	halos.mesh = veil
	halos.instance_count = _lantern_poses.size()
	for i in _lantern_poses.size():
		halos.set_instance_transform(i,Transform3D(Basis.IDENTITY,_lantern_poses[i].origin))
	var glow := MultiMeshInstance3D.new()
	glow.name = "LanternHalos"
	glow.multimesh = halos
	glow.material_override = _lantern_halo
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glow)

func _barrel(base: Vector3, x: float, z: float) -> void:
	model("OilCask", base + Vector3(x,0,z), Vector3.ONE, "#ffffff")

func _make_landmarks() -> void:
	# A warm crescent of buildings frames the first northbound road.
	_house(Vector2(-46,35),5.8,5.4,SAIL_LOFT)
	_house(Vector2(-49,29),4.7,4.8,PILOT_COTTAGE)
	_house(Vector2(-43,43),5.4,5.3,POTTER_COTTAGE)
	_house(Vector2(-30,36),5.4,4.9,PILOT_COTTAGE)
	_house(Vector2(-35,45),4.7,5.6,SAIL_LOFT)
	var forge := preload("res://art/greybay/harbor_smithy.glb").instantiate() as Node3D
	forge.position = _point(-43.3,26.7)
	add_child(forge)
	var anvil := _point(-40.9,29.4)
	_round(anvil,Vector3.UP*.4,Vector3(.62,.82,.62),"#77573f")
	_box(anvil,Vector3.UP*.92,Vector3(1.34,.3,.54),"#444f52")
	_box(anvil,Vector3(-.49,1.08,0),Vector3(.74,.14,.35),"#68787a")
	_village_details()
	_lamp(_point(-36.5,33.5))
	_lamp(_point(-38.7,20.9))
	_lamp(_point(-46.5,25.3),2.5)
	for i in 5:
		_barrel(_point(-50.8 + i*.86,39.0),0,0)
	var hut := Vector2(-32.2,-19.1)
	_house(hut,4.3,3.8,FIELD_CABIN)
	var keypost := _point(-31.6,-15.8)
	_box(keypost,Vector3(0,.72,0),Vector3(.21,1.44,.20),"#775a3c")
	_box(keypost,Vector3(0,1.25,0),Vector3(.78,.48,.26),"#cfa958")
	_lamp(_point(-32.8,-13.2),2.7)
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
	var stall := preload("res://art/greybay/fish_market.glb").instantiate() as Node3D
	stall.position = _point(-32.1,31.3)
	add_child(stall)
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
	var wreck := preload("res://art/greybay/wrecked_lugger.glb").instantiate() as Node3D
	wreck.position = o
	wreck.rotation.y = PI * .5
	wreck.scale = Vector3(2.10, 2.12, 1.92)
	add_child(wreck)
	_barrel(_point(-66.0,.35),0,0)
	block_box(o,6.7,2.35,1.0)

func _pump_and_bridge() -> void:
	var base := _point(3.0,-35.8)
	_house(Vector2(1.0,-35.8),3.7,3.45,FIELD_CABIN)
	model("PumpWorks", base + Vector3.RIGHT * 2.4, Vector3.ONE, "#ffffff")
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
	model("CoastKiln", o, Vector3.ONE, "#ffffff")
	block_disc(o,1.75,2.7)
	_barrel(_point(45.8,-37.3),0,0)
	for x: float in [46.1,47.6,49.1]:
		model("6_100",_point(x,-39.3)+Vector3.UP*.55,Vector3(.39,1.12,.43),"#514d49",.2)

func _lighthouse() -> void:
	var o := _point(41,27.2)
	var tower := preload("res://art/lighthouse/cape_lighthouse.glb").instantiate() as Node3D
	tower.name = "CapeLighthouse"
	add_child(tower)
	tower.position = o
	_tower_optic = tower.get_node("FresnelLens") as MeshInstance3D
	_lit_crystal.shader = preload("res://art/lighthouse/fresnel_lit.gdshader")
	_lamp(o+Vector3(1.72,0,2.57),2.4)
	block_disc(o,2.94,12.9)
	add_child(_beam)
	_beam.position = o+Vector3.UP*14.25
	var lens := OmniLight3D.new()
	lens.light_color = Color("#ffc66d")
	lens.light_energy = 3.1
	lens.omni_range = 19.0
	_beam.add_child(lens)
	var beam_section := QuadMesh.new()
	beam_section.size = Vector2(34.0,11.0)
	beam_section.center_offset = Vector3.RIGHT * 17.0
	var mist := ShaderMaterial.new()
	mist.shader = preload("res://art/lighthouse/sea_mist_beam.gdshader")
	for angle: float in [0.0,PI]:
		var shaft := MeshInstance3D.new()
		shaft.mesh = beam_section
		shaft.rotation.y = angle
		shaft.extra_cull_margin = 5.5
		shaft.material_override = mist
		shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_beam.add_child(shaft)

func _tree(p: Vector2, height: float, broad: bool) -> void:
	var o := _point(p.x,p.y)
	var yaw := _rng.randf() * TAU
	var species := "SilverFir"
	if broad:
		species = "CapePine" if _rng.randi_range(0,2) == 1 else "BayPine"
	model(species, o, Vector3.ONE * height, "#ffffff", yaw)
	block_disc(o,height*.073,height*.54)

func _at_outer_plaza(p: Vector2) -> bool:
	for id: String in Survey.REGION_NAMES:
		if p.distance_squared_to(POINTS[id])<6.1*6.1:
			return true
	return false

func _distant_rocks() -> void:
	for i in 31:
		var angle := i * 2.4
		var p := Survey.shore_point(angle) + Vector2.from_angle(angle)*_rng.randf_range(12,24)
		if Survey.in_mirror_room(p) or Geo.inlet_distance(p)>-3.5: continue
		var height := _rng.randf_range(2.7,9.4)
		if p.distance_squared_to(POINTS.tower)<40.0*40.0:
			# Low skerries leave the sightline across the narrow lighthouse inlet open.
			model("ShoreStone",Vector3(p.x,-.49,p.y),Vector3(height*.46,1.42,height*.29),"#adb4ad",angle)
			continue
		model("ShoreStone",Vector3(p.x,-height*.17,p.y),Vector3(height*.62,height,height*.53),"#a3afa6",angle)

func _outer_groves() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 52106
	for grove: Vector2 in [Vector2(-44,-78),Vector2(-11,-111),Vector2(19,-83),Vector2(38,-116),Vector2(88,-128),Vector2(118,-99),Vector2(132,-70),Vector2(181,-50),Vector2(199,-20),Vector2(137,4),Vector2(183,54),Vector2(157,63),Vector2(81,72),Vector2(53,84),Vector2(29,73),Vector2(3,58)]:
		for i in 18:
			var p := grove+Vector2(rng.randf_range(-12,12),rng.randf_range(-12,12))
			if _dressing_allowed(p):
				_tree(p,rng.randf_range(3.8,7.5),rng.randf()<.40)
	for i in 850:
		var p := Vector2(rng.randf_range(-86,228),rng.randf_range(-151,131))
		if (p.x<65 and absf(p.y)<55) or not _dressing_allowed(p):
			continue
		_small_rock(p,rng.randf_range(.18,.92),"#8e958a" if p.y<0 else "#afa88e")

func _small_rock(p: Vector2, size: float, shade: String) -> void:
	model("ShoreStone",_point(p.x,p.y),Vector3(size*.95,size*.79,size*.68),shade,_rng.randf()*TAU)

func _dressing_allowed(p: Vector2) -> bool:
	if p.distance_squared_to(Vector2(-10,-102))<42 or _road_distance(p)<3.45 or _path_distance(p,TIDAL_TRACK)<3.1 or not is_walkable(p.x,p.y):
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
	_outer_groves()
	_scatter_ground_cover()
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

func _scatter_ground_cover() -> void:
	var plants := CoastalPlants.new()
	plants.load_meadow(self)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4163
	for i in 4700:
		var center := Vector2(rng.randf_range(-87,224), rng.randf_range(-151,134))
		if Survey.coast_distance(center)<1.5:
			continue
		var flower_patch := rng.randf() < .14
		for tuft in rng.randi_range(3,7):
			var p := center + Vector2.from_angle(rng.randf()*TAU) * rng.randf_range(0,2.8)
			_plant_at(plants, rng, p, flower_patch)

	# Irregular drifts along both verges leave the compacted trail open.
	for road: Array in ROADS:
		for i in range(1,road.size()):
			var start: Vector2 = road[i-1]
			var segment: Vector2 = road[i] - start
			var forward := segment.normalized()
			for side: float in [-1.0,1.0]:
				var along := rng.randf_range(0,.9)
				while along < segment.length():
					var shoulder := forward.orthogonal() * side
					var center := start + forward * along + shoulder * rng.randf_range(2.2,3.3)
					var flowering := rng.randf() < .19
					for j in rng.randi_range(3,7):
						var p := center + forward * rng.randf_range(-1.3,1.3) + shoulder * rng.randf_range(-.55,1.35)
						_plant_at(plants,rng,p,flowering)
					along += rng.randf_range(2.1,6.8)
	plants.finish(self)

func _plant_at(plants: CoastalPlants, rng: RandomNumberGenerator, p: Vector2, flowering: bool) -> void:
	if _bridge(p) or _at_outer_plaza(p) or (p.x>27 and p.y< -19 and p.distance_to(Vector2(52,-49))<28) or p.distance_squared_to(POINTS.village)<34:
		return
	var height := _land_height(p.x,p.y)
	if height < .89 or _road_distance(p) < 2.12 or _path_distance(p,TIDAL_TRACK)<2.3 or blocked(p):
		return
	var kind := CoastalPlants.Kind.MEADOW
	if _coast_distance(p.x,p.y)<5.5 or (p.x < -54 and p.y>-12 and p.y<23):
		kind = CoastalPlants.Kind.DUNE
	elif flowering and rng.randf() < .47:
		kind = CoastalPlants.Kind.BLOOM
	elif rng.randf() < .16:
		kind = CoastalPlants.Kind.ROSETTE
	var size := rng.randf_range(.64,1.19)
	var angle := rng.randf()*TAU
	# Keep the short paved spurs clear while retaining the seeded meadow beyond them.
	if p.distance_squared_to(Vector2(-29.3,26.1)) < 27.0:
		var near_library := Geometry2D.get_closest_point_to_segment(p,Vector2(-29,29),Vector2(-29.6,23.15))
		if p.distance_squared_to(near_library) < 2.9:
			return
	if p.distance_squared_to(Vector2(41,31.2)) < 4.0:
		return
	plants.plant(kind,Vector3(p.x,height-.04,p.y),size,angle)

func _make_arena() -> void:
	var o := Vector3(0,0,130)
	var gallery := preload("res://art/lighthouse/optics_gallery.glb").instantiate() as Node3D
	gallery.name = "OpticsGallery"
	gallery.position = o
	add_child(gallery)
	gallery.hide()
	_room_art.append(gallery)
	var fanlight := OmniLight3D.new()
	fanlight.name = "MeridianGlassFill"
	fanlight.position = Vector3(0,3.8,-13.7)
	fanlight.light_color = Color("#98cfc7")
	fanlight.light_energy = .72
	fanlight.omni_range = 10.0
	gallery.add_child(fanlight)
	_round(o,Vector3.DOWN*.70,Vector3(17,1.34,17),"#484e50","24_100")
	_round(o,Vector3.DOWN*.035,Vector3(14.4,.05,14.4),"#606361","24_100")
	_round(o,Vector3.DOWN*.027,Vector3(10.7,.035,10.7),"#5d5f5d","24_100")
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
		if i%4==0 and i!=16:
			var pillar := o+v*15.3
			_round(pillar,Vector3.UP*1.86,Vector3(.72,3.8,.72),"#686c68")
			_round(pillar,Vector3.UP*3.88,Vector3(.78,.29,.78),"#9e916d")
			var sill := pillar - v*.58 + Vector3.UP*4.06
			_round(sill,Vector3.ZERO,Vector3(.30,.12,.30),"#776850")
			_round(sill,Vector3.UP*.28,Vector3(.18,.42,.18),"#e4b974","8_100",true)
			for rib in 4:
				var bearing := t + TAU*rib/4.0
				var corner := Vector3(sin(bearing),0,cos(bearing))*.209
				_round(sill,corner+Vector3.UP*.27,Vector3(.025,.44,.025),"#554f42")
			_round(sill,Vector3.UP*.54,Vector3(.29,.16,.29),"#806e50","8_55")
	_round(o,Vector3.UP*10.95,Vector3(17,.68,17),"#363e41","32_100")
	for j in 4:
		var ang := j*TAU/4.0 + PI/4.0
		var torch := OmniLight3D.new()
		torch.name = "GalleryWallLamp%d" % j
		torch.position = o+Vector3(cos(ang)*14.24,4.35,sin(ang)*14.24)
		torch.light_color = Color("#fbc38e")
		torch.light_energy = 1.7
		torch.omni_range = 17.0
		add_child(torch)
		torch.hide()
		_room_art.append(torch)
	# Split the high wall into masonry rings with inset brass lantern panels.
	for k in 24:
		var ang := TAU*k/24.0
		var out := Vector3(sin(ang),0,cos(ang))
		for y: float in [2.0,5.8,8.8]:
			model("box",o+out*15.72+Vector3.UP*y,Vector3(4.22,.16,.22),"#79796e",ang)
		if k%3==0 and k!=12:
			model("LanternWindow", o+out*15.20+Vector3.UP*4.24, Vector3.ONE, "#ffffff", ang+PI)
	model("CompassInlay", o, Vector3.ONE, "#ffffff")
	var mirror := Vector3(-7.3,0,127)
	model("Heliostat", mirror, Vector3.ONE, "#ffffff", -.54)
	var burner := Vector3(0,0,120.6)
	model("BeaconBurner", burner, Vector3.ONE, "#ffffff")
	_crest_register = preload("res://art/lighthouse/crest_register.glb").instantiate() as Node3D
	_crest_register.name = "BeaconRegister"
	_crest_register.position = burner
	add_child(_crest_register)
	var light := OmniLight3D.new()
	light.name = "LensLight"
	light.position.y = 2.66
	light.light_color = Color("#ffcd78")
	light.light_energy = 1.7
	light.omni_range = 5.0
	_crest_register.add_child(light)
	_beacon_ritual.prepare(_crest_register,light)
	_crest_register.hide()
	_room_art.append(_crest_register)
	_refresh_beacon_register()

func set_beacon_crests(crests: Array, lit: bool) -> void:
	var mask := 0
	for i in CREST_ORDER.size():
		if crests.has(CREST_ORDER[i]):
			mask |= 1 << i
	if mask == _crest_mask and lit == _register_lit:
		return
	_crest_mask = mask
	_register_lit = lit
	if _crest_register:
		if not lit:
			_beacon_ritual.stop()
		_refresh_beacon_register()

func play_crest_ritual() -> void:
	if _crest_register and _register_lit:
		_beacon_ritual.play()

func _refresh_beacon_register() -> void:
	for i in CREST_ORDER.size():
		var plate := _crest_register.get_node("Crest_" + CREST_ORDER[i]) as MeshInstance3D
		plate.visible = (_crest_mask & (1 << i)) != 0
	var lit_glass := _crest_register.get_node("LitGlass") as MeshInstance3D
	var dormant_glass := _crest_register.get_node("DormantGlass") as MeshInstance3D
	var light := _crest_register.get_node("LensLight") as OmniLight3D
	lit_glass.visible = _register_lit
	dormant_glass.visible = not _register_lit
	light.visible = _register_lit
