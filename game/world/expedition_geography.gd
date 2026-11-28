extends RefCounted
## North-up expedition survey. All positions are world metres (x,z), independent of the old island IDs.
const BOUNDS := Rect2(-459,-503,1065,987)
const ZONES := {"snow":"白脊岭","tide":"回浪湾","volcano":"赤炉山","desert":"鸣砂海","lake":"沉钟湖","forest":"长青林海"}
const CENTERS := {"snow":Vector2(-216,-309),"tide":Vector2(-292,4),"volcano":Vector2(-213,297),"desert":Vector2(341,300),"lake":Vector2(433,14),"forest":Vector2(315,-292)}
const RADII := {"snow":Vector2(155,150),"tide":Vector2(142,110),"volcano":Vector2(152,133),"desert":Vector2(151,146),"lake":Vector2(145,133),"forest":Vector2(151,150)}
const ENTRANCES := {"snow":Vector2(-139,-214),"tide":Vector2(-177,0),"volcano":Vector2(-126,218),"desert":Vector2(255,216),"lake":Vector2(314,29),"forest":Vector2(220,-196)}
const CAMPS := {"snow":Vector2(-171,-247),"tide":Vector2(-209,-8),"volcano":Vector2(-156,248),"desert":Vector2(282,234),"lake":Vector2(355,51),"forest":Vector2(248,-211)}
const HUNTS := {"snow":Vector2(-217,-276),"tide":Vector2(-282,-3),"volcano":Vector2(-199,273),"desert":Vector2(322,266),"lake":Vector2(385,58),"forest":Vector2(286,-244)}
const ARENAS := {"snow":Vector2(-249,-320),"tide":Vector2(-315,-35),"volcano":Vector2(-224,312),"desert":Vector2(359,298),"lake":Vector2(430,77),"forest":Vector2(327,-279)}
const ROUTES := {
	"snow":[Vector2(-7,-94),Vector2(-26,-109),Vector2(-53,-126),Vector2(-87,-156),Vector2(-115,-184),ENTRANCES.snow,Vector2(-162,-223),CAMPS.snow,Vector2(-195,-250),HUNTS.snow,Vector2(-221,-301),ARENAS.snow],
	"tide":[Vector2(-65,2),Vector2(-60,-6),Vector2(-72,-11),Vector2(-101,-16),Vector2(-134,-16),ENTRANCES.tide,CAMPS.tide,Vector2(-229,-24),Vector2(-252,-31),Vector2(-269,-18),HUNTS.tide,Vector2(-297,-14),ARENAS.tide],
	"volcano":[Vector2(-29,29),Vector2(-24,43),Vector2(-32,58),Vector2(-52,69),Vector2(-65,81),Vector2(-78,125),Vector2(-105,176),ENTRANCES.volcano,Vector2(-148,224),CAMPS.volcano,Vector2(-181,251),HUNTS.volcano,Vector2(-199,294),ARENAS.volcano],
	"desert":[Vector2(110,83),Vector2(135,103),Vector2(159,130),Vector2(189,152),Vector2(217,179),ENTRANCES.desert,CAMPS.desert,Vector2(299,249),HUNTS.desert,Vector2(346,270),ARENAS.desert],
	"lake":[Vector2(202,27),Vector2(213,38),Vector2(238,42),Vector2(274,37),ENTRANCES.lake,Vector2(333,38),CAMPS.lake,HUNTS.lake,Vector2(405,70),ARENAS.lake],
	"forest":[Vector2(153,-54),Vector2(165,-63),Vector2(164,-87),Vector2(174,-114),Vector2(184,-146),Vector2(201,-170),ENTRANCES.forest,CAMPS.forest,Vector2(267,-224),HUNTS.forest,Vector2(307,-253),ARENAS.forest]
}
const LAKE_LEVEL := .68
const LAKE_CENTER := Vector2(446,13)
const LAKE_RADII := Vector2(63,50)
const TIDAL_SPIT := [Vector2(-218,-14),Vector2(-237,3),Vector2(-251,8),Vector2(-270,5),HUNTS.tide]
const FOREST_BRANCH := [Vector2(263,-220),Vector2(271,-211),Vector2(286,-216),Vector2(297,-230),HUNTS.forest]
const LAKE_SHORE_ROAD := [CAMPS.lake,Vector2(362,51),Vector2(369,43),Vector2(366,25),Vector2(369,-13),Vector2(393,-42),Vector2(437,-50),Vector2(481,-42),Vector2(510,-20),Vector2(521,11),Vector2(510,45),Vector2(478,65),ARENAS.lake]

const OldSurvey := preload("island_survey.gd")
const LAND_CENTER := Vector2(65,-12)
const LAND_RADII := Vector2(493,450)
const OUTER_ROUTES := {
	"snow_tide":[CAMPS.snow,Vector2(-162,-223),Vector2(-174,-217),Vector2(-191,-216),Vector2(-212,-197),Vector2(-221,-171),Vector2(-243,-140),Vector2(-253,-111),Vector2(-246,-80),Vector2(-234,-55),Vector2(-229,-24),CAMPS.tide],
	"tide_volcano":[CAMPS.tide,Vector2(-211,17),Vector2(-229,40),Vector2(-243,70),Vector2(-240,98),Vector2(-222,125),Vector2(-211,157),Vector2(-198,181),Vector2(-189,202),Vector2(-163,219),Vector2(-148,224),CAMPS.volcano],
	"volcano_desert":[CAMPS.volcano,Vector2(-132,263),Vector2(-96,268),Vector2(-62,254),Vector2(-19,257),Vector2(20,275),Vector2(58,284),Vector2(98,276),Vector2(132,254),Vector2(172,250),Vector2(210,260),Vector2(247,251),CAMPS.desert],
	"desert_lake":[CAMPS.desert,Vector2(294,207),Vector2(322,188),Vector2(339,162),Vector2(349,131),Vector2(368,109),Vector2(371,81),Vector2(362,63),CAMPS.lake],
	"lake_forest":[CAMPS.lake,Vector2(333,38),Vector2(328,12),Vector2(332,-17),Vector2(324,-48),Vector2(317,-77),Vector2(300,-101),Vector2(296,-129),Vector2(279,-156),Vector2(263,-181),CAMPS.forest],
	"forest_snow":[CAMPS.forest,Vector2(226,-228),Vector2(197,-248),Vector2(165,-257),Vector2(126,-276),Vector2(89,-285),Vector2(51,-280),Vector2(16,-263),Vector2(-20,-262),Vector2(-54,-271),Vector2(-86,-259),Vector2(-116,-245),Vector2(-145,-241),CAMPS.snow]
}
# Tidal pockets keep the old cape, wreck and estuary open where the lowlands join the continent.
const INLETS := [
	[Vector2(9,106),Vector2(45,82),.30],
	[Vector2(-88,15),Vector2(36,16),-.07],
	[Vector2(235,2),Vector2(48,20),-.31]
]

static func _outer_radius(a: float) -> float:
	var d := Vector2.from_angle(a).abs()
	var squircle := pow(pow(d.x,3.0)+pow(d.y,3.0),-1.0/3.0)
	var tidal_bay := .195*exp(-pow(wrapf(a-3.05,-PI,PI)/.095,2))
	var coast := 1.0+.021*sin(3*a+.4)+.019*cos(5*a-.7)+.016*sin(9*a+1.1)+.009*cos(15*a)
	return squircle*(coast-tidal_bay)

static func mainland_distance(p: Vector2) -> float:
	var q := (p-LAND_CENTER)/LAND_RADII
	return (_outer_radius(q.angle())-q.length())*LAND_RADII.y

static func mainland_outline() -> PackedVector2Array:
	var ring := PackedVector2Array()
	for i in 321:
		var a := TAU*i/320.0
		ring.append(LAND_CENTER+Vector2.from_angle(a)*LAND_RADII*_outer_radius(a))
	return ring

static func inlet_distance(p: Vector2) -> float:
	var best := INF
	for inlet: Array in INLETS:
		var radius: Vector2=inlet[1]
		var local := (p-Vector2(inlet[0])).rotated(-inlet[2])/radius
		best=minf(best,(local.length()-1.0)*minf(radius.x,radius.y))
	return best

static func inland_water_outlines() -> Array[PackedVector2Array]:
	var old := PackedVector2Array()
	for i in 360: old.append(OldSurvey.shore_point(TAU*i/360.0))
	var outlines: Array[PackedVector2Array]=[]
	for inlet: Array in INLETS:
		var ring := PackedVector2Array()
		for i in 128:
			ring.append(Vector2(inlet[0])+(Vector2.from_angle(TAU*i/128.0)*Vector2(inlet[1])).rotated(inlet[2]))
		for polygon in Geometry2D.clip_polygons(ring,old):
			if not Geometry2D.is_polygon_clockwise(polygon):
				outlines.append(polygon)
	# Mean-water survey of the old wreck's inner cove and the western salt pool.
	for pool: Array in [[Vector2(-73,16),Vector2(27.5,9.4)],[Vector2(-248,9),Vector2(32,14)]]:
		var bank:=PackedVector2Array()
		for i in 90:
			bank.append(Vector2(pool[0])+Vector2.from_angle(TAU*i/90.0)*Vector2(pool[1]))
		outlines.append(bank)
	return outlines

static func region_mix(p: Vector2) -> Dictionary:
	var old_d := OldSurvey.coast_distance(p)
	var home := smoothstep(-93,-16,old_d)
	if home >= .99999:
		return {"home":1.0}
	# A broad, winding ecotone is shared by the visible terrain, weather and chart.
	var q := p+Vector2(10*sin(p.y*.016)+5*sin(p.x*.022+p.y*.009),9*sin(p.x*.014)-5*cos(p.y*.021))
	var nearest := ""
	var shortest := INF
	for id: String in ZONES:
		var dist := q.distance_squared_to(CENTERS[id])
		if dist<shortest:
			shortest=dist
			nearest=id
	var mix := {nearest:1.0}
	var total := 1.0
	for id: String in ZONES:
		if id==nearest: continue
		var apart: float=Vector2(CENTERS[id]).distance_to(CENTERS[nearest])
		var margin := (q.distance_squared_to(CENTERS[id])-shortest)/(2.0*apart)
		if margin<59:
			var weight := 1.0-smoothstep(0,59,margin)
			mix[id]=weight
			total+=weight
	for id: String in mix:
		mix[id]=mix[id]*(1.0-home)/total
	if home>0.0: mix["home"]=home
	return mix

static func zone_at(p: Vector2) -> String:
	if mainland_distance(p)<0: return ""
	var mix:=region_mix(p)
	var best: String="home"
	for id: String in mix:
		if mix[id]>mix.get(best,0.0): best=id
	return "" if best=="home" else best

static func sheltered(p: Vector2) -> bool:
	for id: String in CAMPS:
		if p.distance_squared_to(CAMPS[id]) < 10.0*10.0 or p.distance_squared_to(ENTRANCES[id]) < 6.5*6.5:
			return true
	return false

static func safe_return(p: Vector2) -> Vector2:
	var nearest := Vector2(-38,36)
	for spot: Vector2 in CAMPS.values():
		if p.distance_squared_to(spot)<p.distance_squared_to(nearest):
			nearest = spot
	return nearest

static func lake_distance(p: Vector2) -> float:
	var q := (p-LAKE_CENTER)/LAKE_RADII
	return (q.length()-1.0-.025*sin(q.angle()*5.0))*50

const LAVA_CREEK := [Vector2(-174,225),Vector2(-174,237),Vector2(-184,243),Vector2(-196,250),Vector2(-215,248),Vector2(-236,258),Vector2(-220,273),Vector2(-208,290),Vector2(-224,305),Vector2(-239,320),Vector2(-256,329)]
const COOL_STONES := [Vector2(-211,287),Vector2(-208,290),Vector2(-205,293)]
const FOREST_BRIDGES := [[Vector2(269,-226),Vector2(283,-241)],[Vector2(271,-211),Vector2(286,-216)]]
const MOSS_PATH := [Vector2(270,-219),Vector2(278,-220),Vector2(285,-225),Vector2(293,-234),HUNTS.forest]
const LAKE_BEACONS := [Vector2(388,8),Vector2(448,40),Vector2(495,8)]
const LAKE_LANDINGS := [Vector2(378,8),Vector2(447,71),Vector2(517,8)]

static func path_distance(p: Vector2,path: Array) -> float:
	var best := INF
	for i in range(1,path.size()):
		var foot := Geometry2D.get_closest_point_to_segment(p,path[i-1],path[i])
		best = minf(best,p.distance_squared_to(foot))
	return sqrt(best)

static func hazard_at(p: Vector2) -> String:
	var id := zone_at(p)
	if id=="tide" and ((path_distance(p,TIDAL_SPIT)<7 and p.x < -227 and p.x > -278) or p.distance_squared_to(Vector2(-319,-31))<5.8*5.8):
		return "surf"
	if id=="volcano" and path_distance(p,LAVA_CREEK)<2.8:
		for stone: Vector2 in COOL_STONES:
			if p.distance_squared_to(stone)<1.15*1.15:
				return ""
		return "lava"
	if id=="forest":
		for span: Array in FOREST_BRIDGES:
			if path_distance(p,span)<1.65:
				return "bridge"
	return ""

static func moss_landing(p: Vector2) -> Vector2:
	var best: Vector2 = MOSS_PATH[0]
	for v: Vector2 in MOSS_PATH:
		if v.distance_squared_to(p)<best.distance_squared_to(p):
			best = v
	return best

const LAKE_ISLET := Vector2(447,23)
