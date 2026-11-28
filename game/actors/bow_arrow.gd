extends Node3D
## A swept shot uses the same solid-world mask as the keeper's melee sight check.
const Art = preload("actor_art.gd")
var keeper
var velocity := Vector3.ZERO
var remaining := 1.4
var resting := false
var damage := 0.0

func launch(owner_actor, origin: Vector3, direction: Vector3, strength: float) -> void:
	keeper = owner_actor
	global_position = origin
	velocity = direction * lerpf(28,40,strength)
	damage = lerpf(11,21,strength)
	Art.rod(self,Vector3(0,0,.42),Vector3(0,0,-.15),.025,.018,"b7844d")
	Art.rod(self,Vector3(0,0,-.12),Vector3(0,0,-.28),.065,.004,"b8d7d3")
	for i in 3:
		var fin := Art.block(self,Vector3(0,0,.35),Vector3(.10,.018,.14),"eac78b")
		fin.rotation.z = i*PI/3
	look_at(origin+direction)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(keeper) or not keeper.input_enabled:
		return
	remaining -= delta
	if remaining<=0:
		queue_free()
		return
	if resting:
		if keeper.arrows < keeper.QUIVER and keeper.global_position.distance_squared_to(global_position)<2.8 and _area_clear():
			keeper.arrows += 1
			keeper.bow_feedback("拾回一支箭")
			queue_free()
		return
	var end := global_position + velocity * delta
	var ray := PhysicsRayQueryParameters3D.create(global_position,end,5,[keeper.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty():
		global_position = end
		return
	global_position = hit.position
	var target = hit.collider
	if target.has_method("receive_hit"):
		var dealt := 0.0
		var exposed := false
		if target.has_method("arrow_hit"):
			exposed = target.exposed
			dealt = target.arrow_hit(damage,keeper.global_position)
		elif target.kind!="crab" or target.intent==target.Intent.RECOVER or -target.global_basis.z.dot((keeper.global_position-target.global_position).normalized())<.45:
			exposed = target.kind=="boss" and target.shell_open>0
			dealt = target.receive_hit(damage,false,keeper.global_position)
			if dealt>0 and target.kind in ["hound","fin"] and target.intent==target.Intent.WINDUP:
				target.stagger(.60)
		if dealt<=0:
			keeper.combat_cue.emit("shell")
			keeper.bow_feedback("弹开  ·  等待亮起的破绽")
		else:
			keeper.combat_cue.emit("strong_hit" if exposed else "hit")
			keeper.bow_feedback(("破绽命中  −%d" if exposed else "箭中  −%d") % ceili(dealt))
		queue_free()
	else:
		resting = true
		remaining = 45

func _area_clear() -> bool:
	for foe in get_tree().get_nodes_in_group("enemies"):
		if not foe.is_queued_for_deletion() and foe.hp>0 and keeper.global_position.distance_squared_to(foe.global_position)<64.0:
			return false
	return true
