extends RefCounted
## The same survey defines the coastline, named trailheads, charts and collision domain.

const CENTER := Vector2(75,-9)
const RADII := Vector2(163,146)
const CHART_BOUNDS := Rect2(-104,-174,355,329)
const REGION_NAMES := {
	"highmoor":"松风高地", "observatory":"星尺台", "windmill":"风弦磨坊",
	"outerport":"雁尾港", "saltworks":"白帆盐场", "bellcape":"潮钟岬"
}
const EAST_ROADS := [
	[Vector2(-30,-15), Vector2(-23,-18), Vector2(-25,-30), Vector2(-38,-39), Vector2(-24,-60), Vector2(-25,-78), Vector2(-7,-94)],
	[Vector2(-7,-94), Vector2(13,-104), Vector2(30,-100), Vector2(50,-114), Vector2(76,-112)],
	[Vector2(76,-112), Vector2(102,-99), Vector2(118,-79), Vector2(137,-76), Vector2(153,-54)],
	[Vector2(48,-35), Vector2(66,-32), Vector2(88,-49), Vector2(109,-45), Vector2(129,-57), Vector2(153,-54)],
	[Vector2(153,-54), Vector2(169,-36), Vector2(165,-14), Vector2(175,4), Vector2(175,26), Vector2(188,33), Vector2(202,27)],
	[Vector2(202,27), Vector2(186,48), Vector2(161,50), Vector2(147,68), Vector2(123,70), Vector2(110,83)],
	[Vector2(110,83), Vector2(99,91), Vector2(84,94), Vector2(65,109)],
	[Vector2(65,109), Vector2(53,88), Vector2(57,72), Vector2(48,54), Vector2(41,32)],
	[Vector2(41,32), Vector2(63,44), Vector2(81,42), Vector2(95,59), Vector2(110,83)]
]

static func radius_at(angle: float) -> float:
	var south_bay := exp(-pow((angle-2.02)/.30,2.0))
	# A narrow inlet reaches the west side of the old lighthouse, leaving the cape trails on its east bank.
	var beacon_inlet := exp(-pow((angle-2.17)/.15,2.0))
	var northeast_shelf := exp(-pow((angle+.94)/1.25,2.0))
	return 1.0 + .038*sin(5*angle+1.2) + .026*cos(9*angle) - .21*south_bay - .43*beacon_inlet + .037*northeast_shelf

static func coast_distance(p: Vector2) -> float:
	var normalized := (p - CENTER) / RADII
	return (radius_at(normalized.angle()) - normalized.length()) * 143.0

static func shore_point(angle: float) -> Vector2:
	var d := Vector2.from_angle(angle)
	return CENTER + d * RADII * radius_at(d.angle())

static func in_mirror_room(p: Vector2) -> bool:
	return p.distance_squared_to(Vector2(0,130)) <= 19.0 * 19.0

static func coast_crossing(land: Vector2, sea: Vector2) -> Vector2:
	for i in 12:
		var mid := (land+sea)*.5
		if coast_distance(mid)>0:
			land = mid
		else:
			sea = mid
	return (land+sea)*.5
