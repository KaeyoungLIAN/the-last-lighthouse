extends RefCounted
## Harbour works, survey instruments and wayfinding on the outer island.
const Survey := preload("island_survey.gd")
var w

func build(world) -> void:
	w = world
	_highmoor()
	_observatory()
	_mill()
	_port()
	_saltworks()
	_bell()
	_crossing()
	_sign(Vector2(-33,-36),"松风高地 · 星尺台")
	_sign(Vector2(69,-31),"风弦磨坊")
	_sign(Vector2(49,49),"潮钟岬 · 白帆盐场")
	_sign(Vector2(171,1),"东汊栈桥 · 雁尾港")
	_sign(Vector2(126,73),"雁尾港")
	for id: String in Survey.REGION_NAMES:
		var p: Vector2 = w.POINTS[id]
		var offset := Vector2(5,4) if id=="observatory" else Vector2(-3.8,4.6)
		_sign(p+offset,Survey.REGION_NAMES[id])

func _sign(p: Vector2, caption: String) -> void:
	var o: Vector3 = w._point(p.x,p.y)
	w._box(o,Vector3.UP*1.03,Vector3(.18,2.04,.18),"#71634b")
	w._box(o,Vector3.UP*1.75,Vector3(2.72,.59,.15),"#4f6b66")
	w._box(o,Vector3.UP*2.07,Vector3(2.85,.085,.22),"#a68b62")
	for side: float in [-1.0,1.0]:
		var text := Label3D.new()
		text.text = caption
		text.position = o + Vector3(0,1.75,side*.09)
		text.rotation.y = 0.0 if side>0.0 else PI
		text.double_sided = false
		text.pixel_size = .006
		text.font_size = 66
		text.outline_size = 2
		text.modulate = Color("#f5e4bb")
		text.visibility_range_end = 25
		w.add_child(text)
		for x: float in [-1.24,1.24]:
			w._box(o,Vector3(x,1.75,side*.08),Vector3(.065,.065,.03),"#cba76c")

func _highmoor() -> void:
	var o: Vector3 = w._point(-10,-102)
	var marker := preload("res://art/greybay/moor_triangulation.glb").instantiate() as Node3D
	marker.position = o
	w.add_child(marker)
	w.block_disc(o,1.7,3.8)
	for j in 4:
		var rock: Vector3 = w._point(-19+j*4,-106-sin(j)*2)
		w.model("ShoreStone",rock,Vector3(1.65,1.37,1.24),"#b4b9a9",j*.93)

func _observatory() -> void:
	var o: Vector3 = w._point(77,-122)
	var landmark := preload("res://art/outer_coast/star_survey.glb").instantiate() as Node3D
	landmark.position = o
	w.add_child(landmark)
	w.block_disc(o,2.9,4.0)

func _mill() -> void:
	var o: Vector3 = w._point(155,-64)
	var landmark := preload("res://art/outer_coast/windmill.glb").instantiate() as Node3D
	landmark.position = o
	landmark.get_node("SailWheel").set_script(preload("mill_sails.gd"))
	w.add_child(landmark)
	w.block_disc(o,2.52,6.8)
	for i in 6:
		var p: Vector3 = w._point(163+i*1.7,-65)
		w.model("7_77",p+Vector3.UP*.45,Vector3(.49,.79,.46),"#b6a079",i*.44)
		w.model("7_42",p+Vector3.UP*.84,Vector3(.38,.18,.35),"#c3ad86",i*.44)
		w.model("6_88",p+Vector3.UP*.94,Vector3(.14,.05,.14),"#806d50",i*.44)
		w.model("6_65",p+Vector3.UP*1.0,Vector3(.19,.09,.19),"#c5b18d",i*.44)


func _port() -> void:
	w._house(Vector2(211,26),6.7,4.1,w.SAIL_LOFT)
	w._house(Vector2(198,17),4.7,3.6,w.POTTER_COTTAGE)
	# Moor the lugger in the deep channel. The water node follows the tide.
	var lugger := preload("res://art/greybay/harbor_lugger.glb").instantiate() as Node3D
	lugger.position = Vector3(203.4,-.23,8.35)
	lugger.rotation.y = 1.88
	lugger.scale = Vector3.ONE * 1.63
	w._water.add_child(lugger)
	var jetty := preload("harbor_jetty.gd").new()
	jetty.name = "HarborJetty"
	jetty.position = Vector3(207,2.13,13.33)
	w.add_child(jetty)
	var deck := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.65,.22,11.14)
	deck.shape = shape
	deck.position = Vector3(207,2.13,13.33)
	w._solid.add_child(deck)
	var crane := preload("res://art/greybay/harbor_davit.glb").instantiate() as Node3D
	crane.position = w._point(211,17)
	w.add_child(crane)

func _saltworks() -> void:
	for j in 2:
		for i in 3:
			var q: Vector3 = w._point(115+i*6.4,92+j*5.5)
			var pan := preload("res://art/greybay/evaporation_pan.glb").instantiate() as Node3D
			pan.position = q
			pan.rotation.y = PI if (i+j)%2 else 0.0
			w.add_child(pan)
			w.block_box(q,5.52,4.60,.32)
	for i in 5:
		var heap := preload("res://art/greybay/salt_harvest.glb").instantiate() as Node3D
		heap.position = w._point(105+i*1.8,95)
		heap.rotation.y = i*.67
		heap.scale = Vector3.ONE * (1.0 + .065*sin(i*1.74))
		w.add_child(heap)

func _bell() -> void:
	var o: Vector3 = w._point(64,119)
	var landmark := preload("res://art/outer_coast/cape_bell.glb").instantiate() as Node3D
	landmark.position = o
	w.add_child(landmark)
	w.block_box(o,4.6,1.15,5.7)

func _crossing() -> void:
	for i in 22:
		var q := Vector3(175,1.88,8.0+i*.66)
		w._box(q,Vector3.ZERO,Vector3(4.25,.24,.64),"#ad906e")
	for side: float in [-1.0,1.0]:
		var x := 175.0 + side*2.10
		w._box(Vector3(x,2.89,15),Vector3.ZERO,Vector3(.15,.17,14.6),"#80735e")
		for i in 6:
			w._box(Vector3(x,1.4,8.0+i*2.8),Vector3.ZERO,Vector3(.22,3.18,.22),"#686959")
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4.25,.22,14.6)
	collider.shape = shape
	collider.position = Vector3(175,1.89,15)
	w._solid.add_child(collider)
