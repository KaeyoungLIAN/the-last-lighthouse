extends Node3D
## A post stop becomes a travel destination the first time the keeper signs its book.

const STOPS := {
	"post_village":["灰湾村","village",Vector2(4.9,8.6)],
	"post_highmoor":["松风高地","highmoor",Vector2(2.6,4.4)],
	"post_mill":["风弦磨坊","windmill",Vector2(-4.8,-2.1)],
	"post_port":["雁尾港","outerport",Vector2(-3.5,4.9)],
	"post_salt":["白帆盐场","saltworks",Vector2(-3.9,-3.4)]
}
var at_stop := ""
var _materials := {}

func build(game) -> void:
	for id: String in STOPS:
		var info: Array = STOPS[id]
		if not game.world.POINTS.has(info[1]): continue
		var point: Vector2 = game.world.POINTS[info[1]] + info[2]
		game._add_site(id,info[0]+"邮驿",point)
		var base: Vector3 = game._ground(game.sites[id])
		_signpost(base)

func _board(center: Vector3,size: Vector3,tint: String,angle := 0.0) -> void:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh=mesh
	if not _materials.has(tint):
		var material := StandardMaterial3D.new()
		material.albedo_color=Color(tint)
		material.roughness=.89
		_materials[tint]=material
	node.material_override=_materials[tint]
	node.position=center
	node.rotation.z=angle
	add_child(node)

func _signpost(base: Vector3) -> void:
	# A red pillar box and a cream envelope stand out from the lantern silhouettes.
	_board(base+Vector3.UP*.30,Vector3(.35,.68,.35),"665747")
	_board(base+Vector3.UP*1.09,Vector3(.72,1.24,.60),"af604f")
	_board(base+Vector3.UP*1.75,Vector3(.84,.13,.72),"6b8079")
	_board(base+Vector3(0,1.46,.314),Vector3(.49,.065,.034),"464b48")
	_board(base+Vector3(0,1.11,.316),Vector3(.43,.25,.031),"e7d6a8")
	for side: float in [-1.0,1.0]:
		_board(base+Vector3(side*.103,1.14,.342),Vector3(.23,.028,.026),"a07d58",side*.51)

func _safe(game) -> bool:
	if game.in_tower or game.starwatch.active: return false
	for foe in get_tree().get_nodes_in_group("enemies"):
		if not foe.is_queued_for_deletion() and foe.hp>0 and foe.global_position.distance_squared_to(game.hero.global_position)<100.0:
			return false
	return true

func visit(id: String,game) -> void:
	if not _safe(game):
		game._notice("附近有影兽，等路上平静些再出发。")
		return
	at_stop=id
	if not game.taken.has(id):
		game.taken.append(id)
		game._save()
	game._show("post")

func timetable(game) -> Array:
	var entries := []
	for id: String in STOPS:
		if game.sites.has(id):
			entries.append([id,STOPS[id][0],game.taken.has(id) or id=="post_village",id==at_stop])
	return entries

func travel(id: String,game) -> void:
	if game.screen!="post" or at_stop==id or not game.sites.has(id) or not STOPS.has(id): return
	if id!="post_village" and not game.taken.has(id): return
	if not _safe(game) or game.hero.global_position.distance_to(game._ground(game.sites[at_stop]))>4.4: return
	_arrive(id,game)

func recall(game) -> void:
	if game.screen!="map" or not game.taken.has("bell_song") or game.harvested.get("bell_return",-1)==game._day_index(): return
	if not _safe(game):
		game._show("play")
		game._notice("归港号要在室外平静处吹响。")
		return
	# Charge on arrival, including a journey that crosses midnight.
	_arrive("post_village",game,true)

func _arrive(id: String,game,by_bell := false) -> void:
	var destination: Vector2 = game.sites[id]
	var distance := Vector2(game.hero.position.x,game.hero.position.z).distance_to(destination)
	game.time_elapsed += clampf(distance*.19,5,80)
	game._conditions()
	game._place_hero(destination+Vector2(0,1.35))
	if by_bell: game.harvested["bell_return"]=game._day_index()
	game._rebuild_encounters()
	game._discover()
	game._show("play")
	game._notice("已随邮班抵达"+str(STOPS[id][0]) if not by_bell else "归港号回响，你赶上了回灰湾的邮班。","chime")
	game._save()
