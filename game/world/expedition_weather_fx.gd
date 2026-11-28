extends Node3D
const Geo = preload("res://world/expedition_geography.gd")
const Art = preload("res://actors/actor_art.gd")
const BELL = preload("res://audio/tide_bell.wav")
const BIOMES := {"":0,"snow":1,"tide":2,"volcano":3,"desert":4,"lake":5,"forest":6}
const COLORS := {"snow":"f5f6eb","tide":"e2eddf","volcano":"6e5a58","desert":"d7bc88","lake":"b8d1bf","forest":"b2be7e"}
var particles := CPUParticles3D.new()
var sky := CanvasLayer.new()
var paint := ShaderMaterial.new()
var weather_mesh := QuadMesh.new()
var motes := StandardMaterial3D.new()
var previous_zone := "-"
var clock := 0.0
var wash_amount := 0.0
var mark := MeshInstance3D.new()
var bolt := MeshInstance3D.new()
var flash := 0.0
var rings: Array[MeshInstance3D] = []
var ferns: Array[Node3D] = []
var audio := AudioStreamPlayer.new()
var chime := AudioStreamPlayer3D.new()
var warning_sound: Dictionary = {}
var last_echo := -1
var post := Node3D.new()
var surf := Node3D.new()
var elapsed_gust := 0.0
var last_stage := ""
var liveliness := true
var reduced_effects := false:
	set(value):
		reduced_effects=value
		particles.amount=34 if value else 94
var creek_rim := MeshInstance3D.new()
var creek_paint := ShaderMaterial.new()
var cloth_material: ShaderMaterial
var cloth_gust := -1.0
var checked_cloth := false

func build(host,post_at: Vector2) -> void:
	var wash_layer := ColorRect.new()
	sky.layer=0
	add_child(sky)
	sky.add_child(wash_layer)
	wash_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wash_layer.mouse_filter=Control.MOUSE_FILTER_IGNORE
	paint.shader=preload("expedition_weather.gdshader")
	wash_layer.material=paint
	add_child(particles)
	particles.emitting=false
	particles.amount=34 if reduced_effects else 94
	particles.lifetime=1.7
	particles.fixed_fps=30
	particles.preprocess=.35
	particles.emission_shape=CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents=Vector3(9,2,9)
	particles.direction=Vector3(1,-.5,.15)
	particles.spread=22
	particles.local_coords=false
	particles.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	motes.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	motes.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED
	motes.cull_mode=BaseMaterial3D.CULL_DISABLED
	motes.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	var falloff:=Gradient.new()
	falloff.set_color(0,Color.WHITE)
	falloff.set_color(1,Color(1,1,1,0))
	falloff.add_point(.48,Color(1,1,1,.92))
	var fleck:=GradientTexture2D.new()
	fleck.width=24
	fleck.height=24
	fleck.gradient=falloff
	fleck.fill=GradientTexture2D.FILL_RADIAL
	fleck.fill_from=Vector2(.5,.5)
	fleck.fill_to=Vector2(1,.5)
	motes.albedo_texture=fleck
	weather_mesh.material=motes
	particles.mesh=weather_mesh
	for mesh in [mark,bolt]:
		add_child(mesh)
		mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.hide()
	add_child(audio)
	audio.volume_db=-18
	add_child(chime)
	chime.stream=BELL
	chime.unit_size=14
	chime.max_distance=75
	chime.volume_db=-5
	_build_mooring(host,post_at)
	_build_ferns(host)
	_build_ripples()
	_build_surf()
	_build_creek_warning(host)
	set_active(false)

func _build_mooring(host,p: Vector2) -> void:
	add_child(post)
	post.position=Vector3(p.x,host.world.ground_height(p.x,p.y),p.y)
	Art.taper(post,Vector3.UP*.84,.18,.14,1.7,"756045")
	Art.taper(post,Vector3.UP*1.56,.165,.16,.17,"dbcca1")
	Art.taper(post,Vector3.UP*1.77,.18,.11,.16,"ac6250")
	for i in 3:
		Art.taper(post,Vector3.UP*(1.17+i*.08),.195,.195,.051,"c6aa72")
	var eye:=TorusMesh.new()
	eye.inner_radius=.17
	eye.outer_radius=.204
	eye.rings=16
	eye.ring_segments=5
	var coil:=Art.part(post,eye,Vector3(.13,.99,.06),"b19868")
	coil.rotation.z=1.40

func _build_ferns(host) -> void:
	for span: Array in Geo.FOREST_BRIDGES:
		var end: Vector2=span[0]
		var at:=end+Vector2(.87,.75)
		var fern:=Art.joint(self,Vector3(at.x,host.world.ground_height(at.x,at.y),at.y))
		var fronds:=SurfaceTool.new()
		fronds.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in 8:
			var turn:=TAU*i/8.0
			var dir:=Vector3(cos(turn),0,sin(turn))
			var across:=Vector3(-sin(turn),0,cos(turn))
			for j in 5:
				var f:=j/5.0
				var stem:=dir*(.1+f*.70)+Vector3.UP*(.25+.42*sin(f*2.4))
				var width:=.19*(1.0-.75*f)
				for side: float in [-1,1]:
					for v in [stem,stem+across*side*width+dir*.18+Vector3.UP*.05,stem+dir*.23]:
						fronds.set_normal(Vector3.UP)
						fronds.add_vertex(v)
		var stems:=MeshInstance3D.new()
		stems.mesh=fronds.commit()
		var mat:=StandardMaterial3D.new()
		mat.cull_mode=BaseMaterial3D.CULL_DISABLED
		mat.albedo_color=Color("568864")
		stems.material_override=mat
		fern.add_child(stems)
		ferns.append(fern)

func _build_ripples() -> void:
	var torus:=TorusMesh.new()
	torus.inner_radius=.96
	torus.outer_radius=1.0
	torus.rings=48
	torus.ring_segments=4
	for anchor: Vector2 in Geo.LAKE_BEACONS:
		for i in 3:
			var ring:=MeshInstance3D.new()
			ring.mesh=torus
			ring.position=Vector3(anchor.x,.76+i*.018,anchor.y)
			ring.material_override=_ink(Color("c5e9da"))
			ring.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(ring)
			ring.hide()
			rings.append(ring)

func _ink(tint: Color) -> StandardMaterial3D:
	var mat:=StandardMaterial3D.new()
	mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	mat.albedo_color=tint
	return mat

func _build_surf() -> void:
	add_child(surf)
	var lines:=ImmediateMesh.new()
	lines.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 29:
		var x:=i*.45-6.5
		var z:=.25*sin(i*.59)
		var z1:=.25*sin((i+1)*.59)
		for p in [Vector3(x,0,z),Vector3(x+.45,0,z1),Vector3(x+.45,0,z1+.16),Vector3(x,0,z),Vector3(x+.45,0,z1+.16),Vector3(x,0,z+.16)]:
			lines.surface_add_vertex(p)
	lines.surface_end()
	for i in 3:
		var crest:=MeshInstance3D.new()
		crest.mesh=lines
		crest.position.z=i*.84
		crest.material_override=_ink(Color("dfebdd"))
		crest.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		surf.add_child(crest)
	surf.hide()

func _build_creek_warning(host) -> void:
	# Thin seams cross only the low, central stepping stone when the creek surges.
	var at: Vector2=Geo.COOL_STONES[1]
	var face:=PlaneMesh.new()
	face.size=Vector2(2.62,2.62)
	creek_rim.mesh=face
	creek_paint.shader=preload("expedition_hot_stone.gdshader")
	creek_rim.material_override=creek_paint
	creek_rim.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	creek_rim.position=Vector3(at.x,host.world.ground_height(at.x,at.y)+.30,at.y)
	add_child(creek_rim)
	creek_rim.hide()

func _set_flags(gust: float) -> void:
	if not checked_cloth:
		checked_cloth=true
		for flag in get_tree().get_nodes_in_group("expedition_wind_flags"):
			if flag is MeshInstance3D and flag.material_override is ShaderMaterial:
				cloth_material=flag.material_override
				break
	if cloth_material!=null and absf(gust-cloth_gust)>.025:
		cloth_material.set_shader_parameter("gust",gust)
		cloth_gust=gust

func set_active(enabled: bool) -> void:
	liveliness=enabled
	sky.visible=enabled
	if not enabled:
		creek_rim.hide()
		particles.emitting=false
		surf.hide()
		clear_strike()
		for ring in rings: ring.hide()
		audio.stop()
		chime.stop()
		last_echo=-1
	previous_zone="-"

func wash(remaining: float) -> void:
	wash_amount=1.0 if remaining>0 else .75
	paint.set_shader_parameter("wash",wash_amount*(.27 if reduced_effects else 1.0))

func clear_strike() -> void:
	mark.hide()
	bolt.hide()
	flash=0.0

func _strip(mesh: ImmediateMesh,a: Vector3,b: Vector3,width: float) -> void:
	var tangent:=b-a
	var side:=Vector3(-tangent.z,0,tangent.x).normalized()*width
	if side.length_squared()<.0001: side=Vector3.RIGHT*width
	for v in [a-side,b-side,b+side,a-side,b+side,a+side]: mesh.surface_add_vertex(v)

func warn_strike(p: Vector2,world) -> void:
	var mesh:=ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 40:
		var a:=Vector2.from_angle(i*TAU/40)*3.45+p
		var b:=Vector2.from_angle((i+1)*TAU/40)*3.45+p
		_strip(mesh,Vector3(a.x,world.ground_height(a.x,a.y)+.14,a.y),Vector3(b.x,world.ground_height(b.x,b.y)+.14,b.y),.059)
	for i in 6:
		var v:=Vector2.from_angle(i*TAU/6+.27)
		var a:=p+v*.22
		for j in 4:
			var b:=p+v*(.66+j*.78)+v.orthogonal()*.22*sin(j*3.7+i)
			_strip(mesh,Vector3(a.x,world.ground_height(a.x,a.y)+.16,a.y),Vector3(b.x,world.ground_height(b.x,b.y)+.16,b.y),.052)
			a=b
	mesh.surface_end()
	mark.mesh=mesh
	mark.material_override=_ink(Color("b0dcec"))
	mark.show()

func strike(p: Vector2,world) -> void:
	var base:=Vector3(p.x,world.ground_height(p.x,p.y)+.10,p.y)
	var mesh:=ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var last:=base
	for i in range(1,10):
		var next:=base+Vector3(sin(i*2.6)*i*.26,i*1.7,cos(i*3.9)*.41)
		_strip(mesh,last,next,.11)
		if i==4 or i==7:
			_strip(mesh,last,last+Vector3(1.45,1.1,-.36),.066)
		last=next
	mesh.surface_end()
	bolt.mesh=mesh
	bolt.material_override=_ink(Color("ddf2ff"))
	bolt.show()
	mark.hide()
	flash=.33
	cue_warning("strike")

func cue_warning(kind: String) -> void:
	if DisplayServer.get_name()=="headless": return
	if not warning_sound.has(kind):
		var rng:=RandomNumberGenerator.new()
		rng.seed=kind.hash()
		var clip:=AudioStreamWAV.new()
		clip.format=AudioStreamWAV.FORMAT_16_BITS
		clip.mix_rate=12000
		var buffer:=PackedByteArray()
		buffer.resize(12000)
		var low:=0.0
		for i in 6000:
			var t:=i/12000.0
			low=lerpf(low,rng.randf_range(-1,1),.14)
			var sample:=low*exp(-3.2*t)*sin(PI*minf(1,t/.5))
			if kind=="volcano": sample+=sin(t*2100)*pow(maxf(0,sin(t*87)),10.0)*.19
			if kind=="strike": sample=low*exp(-6*t)*2.2+sin(174*t)*exp(-12*t)*.41
			if kind=="lake": sample=sin(1256*t)*exp(-9*t)*.37
			buffer.encode_s16(i*2,roundi(clampf(sample,-1,1)*26000))
		clip.data=buffer
		warning_sound[kind]=clip
	audio.stream=warning_sound[kind]
	audio.play()

func advance(delta: float,id: String,phase: String,power: float,wind: float,p: Vector2,host,crest: bool,stress: float,is_cold: bool) -> void:
	if not liveliness: return
	clock+=delta
	if wash_amount>0: wash_amount=move_toward(wash_amount,0,delta*.90)
	var show_air:=id!="" or stress>.72 or wash_amount>0
	sky.visible=show_air
	if id!=previous_zone:
		particles.emitting=false
		previous_zone=id
		if id!="":
			motes.albedo_color=Color(COLORS[id])
			weather_mesh.size=Vector2(.062,.065) if id=="snow" else Vector2(.11,.036)
			particles.gravity=Vector3(1.0,-1.8,.05)
			particles.scale_amount_min=.5
			particles.scale_amount_max=1.28
	if show_air:
		paint.set_shader_parameter("biome",BIOMES.get(id,0))
		paint.set_shader_parameter("strength",wind*(.35 if reduced_effects else 1.0))
		paint.set_shader_parameter("severity",1.0 if phase=="storm" else .25)
		paint.set_shader_parameter("clock",clock)
		paint.set_shader_parameter("wash",wash_amount*(.27 if reduced_effects else 1.0))
		paint.set_shader_parameter("exposure",smoothstep(.71,1.0,stress)*(.40 if reduced_effects else 1.0))
		paint.set_shader_parameter("cold",1.0 if is_cold else 0.0)
	particles.emitting=id!="" and id!="lake" and (phase!="calm" or id=="snow")
	if particles.emitting:
		particles.global_position=host.hero.global_position+Vector3(-3,3.6,0)
		particles.initial_velocity_min=1.1+power*2.0
		particles.initial_velocity_max=3.2+power*4.7
	if phase!=last_stage:
		elapsed_gust=0.0
		last_stage=phase
	elapsed_gust+=delta
	if flash>0:
		flash-=delta
		if flash<=0 or (reduced_effects and flash<.20): bolt.hide()
	_set_flags(power if id=="snow" else .12)
	creek_rim.visible=id=="volcano" and phase!="calm"
	if creek_rim.visible:
		creek_paint.set_shader_parameter("flow",1.0 if phase=="storm" else .28)
	if id=="forest":
		for i in ferns.size():
			var pulse:=(phase=="warning" and (i==0 or elapsed_gust>1.6)) or (phase=="storm" and elapsed_gust>=i*3.6 and elapsed_gust<2.2+i*3.6)
			ferns[i].rotation.z=sin(clock*4.6+i)*.32 if pulse else sin(clock*.8)*.048
			var mesh: MeshInstance3D=ferns[i].get_child(0)
			var mat: StandardMaterial3D=mesh.material_override
			mat.albedo_color=Color("c5d5af") if pulse else Color("568864")
	surf.visible=id=="tide" and phase!="calm" and Geo.hazard_at(p)=="surf"
	if surf.visible:
		var at:=p+Vector2(.1,1)*(2.7-fposmod(clock,2.0)*2.1)
		surf.position=Vector3(at.x,maxf(host.world.ground_height(at.x,at.y),lerpf(-.65,.53,host.tide_level))+.13,at.y)
	_update_ripples(id,p,crest,host)

func _update_ripples(id: String,p: Vector2,crest: bool,host) -> void:
	var selected:=-1
	var best:=INF
	if id=="lake":
		for i in Geo.LAKE_BEACONS.size():
			var d:=p.distance_squared_to(Geo.LAKE_BEACONS[i])
			if d<best:
				best=d
				selected=i
	var phase:=fposmod(clock,4.6)
	for i in rings.size():
		var pulse:=phase-(i%3)*.62
		var lit:=floori(i/3.0)==selected and pulse>=0 and pulse<2.6 and (crest or i%3<2)
		rings[i].visible=lit
		if lit:
			var radius:=1.15+pulse*2.4
			rings[i].scale=Vector3(radius,.5,radius)
	var beat:=floori(phase/.62)
	if id=="lake" and selected>=0 and beat!=last_echo and beat<(3 if crest else 2):
		var at: Vector2=Geo.LAKE_BEACONS[selected]
		chime.position=Vector3(at.x,1.85,at.y)
		chime.pitch_scale=1.32 if beat==1 else .92
		if DisplayServer.get_name()!="headless": chime.play()
	last_echo=beat if id=="lake" else -1

func _exit_tree() -> void:
	audio.stop()
	chime.stop()
