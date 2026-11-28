extends Node3D

const Art = preload("actor_art.gd")
const MODELS := {
	"snow": [preload("res://art/cast/snow_prey.glb"), preload("res://art/cast/snow_champion.glb")],
	"tide": [preload("res://art/cast/tide_prey.glb"), preload("res://art/cast/tide_champion.glb")],
	"volcano": [preload("res://art/cast/volcano_prey.glb"), preload("res://art/cast/volcano_champion.glb")],
	"desert": [preload("res://art/cast/desert_prey.glb"), preload("res://art/cast/desert_champion.glb")],
	"lake": [preload("res://art/cast/lake_prey.glb"), preload("res://art/cast/lake_champion.glb")],
	"forest": [preload("res://art/cast/forest_prey.glb"), preload("res://art/cast/forest_champion.glb")],
}
var legs: Array[Node3D] = []
var region := ""
var champion := false
var pulse := 0.0
var weak: MeshInstance3D
var spine: Node3D

func build(zone: String, big: bool) -> void:
	region = zone
	champion = big
	spine = MODELS[zone][int(big)].instantiate()
	add_child(spine)
	for joint: Node in spine.get_children():
		if joint.name.begins_with("Walk"):
			legs.append(joint)
	if big:
		weak = Art.oval(spine,Vector3(0,1.04,-.46),Vector3(.33,.21,.34),"f8cc7c",true)
		weak.hide()
	scale = Vector3.ONE * (1.35 if big else .77)

func animate(delta: float,speed: float,charge: float,exposed: bool,impact: float) -> void:
	pulse += delta*(3.0+speed*2.7)
	var stride := sin(pulse)*minf(1.0,speed*.52)
	for i in legs.size():
		legs[i].rotation.x = stride*(.46 if i%3==0 else -.38)
	spine.position.y = .075*absf(stride) - .17*charge
	if region=="lake":
		spine.position.y += .14*sin(pulse)+.12
	if champion and region=="desert":
		spine.position.y -= charge*.65
	spine.rotation.x = -.21*charge+.30*impact
	spine.rotation.z = (.29 if exposed else .035*stride)+.09*impact
	if weak!=null:
		weak.visible = exposed
