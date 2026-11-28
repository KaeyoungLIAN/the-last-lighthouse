extends RefCounted
## Local strata, waterworks and old growth. Each province shares one vertex-coloured surface.
const Geo = preload("expedition_geography.gd")
var world
var surface := SurfaceTool.new()
var rng := RandomNumberGenerator.new()

func build(owner_world) -> void:
	world=owner_world
	rng.seed=930180
	for province:String in Geo.ZONES:
		surface=SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		match province:
			"snow": _glacier()
			"tide": _sea_stacks()
			"volcano": _basalt()
			"desert": _yardangs()
			"lake": _drowned_aqueduct()
			"forest": _old_growth()
		var node:=MeshInstance3D.new()
		node.name="Landscape_"+province
		node.mesh=surface.commit()
		var stone:=ShaderMaterial.new()
		stone.shader=preload("expedition_scenery.gdshader")
		stone.set_shader_parameter("terrain_kind",Geo.ZONES.keys().find(province))
		node.material_override=stone
		node.visibility_range_end=215
		world.add_child(node)

func _at(p:Vector2) -> Vector3:
	return world._point(p.x,p.y)

func _face(a:Vector3,b:Vector3,c:Vector3,outward:Vector3,tint:Color) -> void:
	var n:=(c-a).cross(b-a)
	if n.length_squared()<.0000001:return
	var corners: Array[Vector3]=[a,b,c]
	if n.dot(outward)<0:
		n=-n
		corners=[a,c,b]
	var dye:=tint.srgb_to_linear().lerp(tint,.27)
	for v:Vector3 in corners:
		surface.set_normal(n.normalized())
		surface.set_color(dye)
		surface.add_vertex(v)

func _quad(a:Vector3,b:Vector3,c:Vector3,d:Vector3,outward:Vector3,tint:Color) -> void:
	_face(a,b,c,outward,tint)
	_face(a,c,d,outward,tint)

# A stratified outcrop. A slice specifies elevation, two radii and lateral offset.
# Vertical defects persist from one bed to the next, unlike a pile of rotated prisms.
func _outcrop(o:Vector3,yaw:float,slices:Array,dyes:Array,ragged:float,seed_angle:float,sides:=11) -> void:
	var along:=Vector3(cos(yaw),0,sin(yaw))
	var crosswise:=Vector3(-along.z,0,along.x)
	var prev:=PackedVector3Array()
	for k in slices.size():
		var s:Vector4=slices[k]
		var ring:=PackedVector3Array()
		var center:=o+along*s.w+Vector3.UP*s.x
		for j in sides:
			var t:=TAU*j/sides
			var fault:=sin(t*3.+seed_angle)+.46*cos(t*5.-seed_angle*.64)
			var radius:=1.+ragged*fault
			var lean:=.055*cos(t*2.+seed_angle+.52*k)
			var p:=center+along*cos(t)*s.y*radius+crosswise*sin(t)*s.z*(radius+lean)
			p.y += ragged*minf(s.y,s.z)*(.69*sin(t*2.+seed_angle)+.19*cos(t*4.+k))
			ring.append(p)
		if k>0:
			for j in sides:
				var next:=(j+1)%sides
				var tint:=Color(dyes[k-1]).lightened(.035*(.5+.5*sin(j*2.17+seed_angle)))
				_quad(prev[j],prev[next],ring[next],ring[j],ring[j]+ring[next]-2.*center,tint)
		if k==slices.size()-1:
			for j in sides:
				_face(ring[j],ring[(j+1)%sides],center+Vector3.UP*ragged,Vector3.UP,Color(dyes.back()))
		prev=ring

func _tube(path:Array,radii:Array,tint:Color,sides:=7) -> void:
	var old:=PackedVector3Array()
	var angle:float = rng.randf()*TAU
	for i in path.size():
		var mid:Vector3=path[i]
		var aim:Vector3=(path[mini(i+1,path.size()-1)]-path[maxi(0,i-1)]).normalized()
		var side:=aim.cross(Vector3.RIGHT)
		if side.length_squared()<.02:side=aim.cross(Vector3.FORWARD)
		side=side.normalized()
		var up:=aim.cross(side).normalized()
		var ring:=PackedVector3Array()
		for j in sides:
			var t:=TAU*j/sides+angle
			ring.append(mid+(side*cos(t)+up*sin(t))*float(radii[i]))
		if i>0:
			for j in sides:
				var n:=(j+1)%sides
				_quad(old[j],old[n],ring[n],ring[j],ring[j]+ring[n]-2.*mid,tint.lightened(.045*(j%3)))
		if i==path.size()-1:
			for j in sides:_face(ring[j],ring[(j+1)%sides],mid,aim,tint.lightened(.12))
		old=ring

func _glacier() -> void:
	# Blue seracs lean into the valley. Snow lips overhang the compressed turquoise strata.
	for fan:Array in [[Vector2(-239,-285),12,1.02],[Vector2(-244,-308),10,.76],[Vector2(-192,-236),6,.48]]:
		var center:Vector2=fan[0]
		var count:int=fan[1]
		var size:float=fan[2]
		for j in count:
			var t:=float(j)/maxi(1,count-1)
			var shift:=Vector2(.47,-.88)*(t-.5)*count*1.68*size+Vector2(-1.,-.36)*sin(t*PI)*2.3*size
			var p:=center+shift
			var h:float=(2.6+sin(t*PI)*3.5+rng.randf_range(0.,2.6))*size
			var width:float=rng.randf_range(1.52,2.44)*size
			var o:=_at(p)-Vector3.UP*.38
			_outcrop(o,-.81,[Vector4(-.5,width*1.2,2.0*size,0),Vector4(h*.30,width,2.12*size,.12),
				Vector4(h*.60,width*.92,1.92*size,.44),Vector4(h*.88,width*.79,1.67*size,.76),
				Vector4(h*.94,width*.89,1.72*size,.79),Vector4(h,width*.71,1.40*size,.81)],
				["#547986","#669eab","#8dbac3","#d4dfdf","#dfe7e4"],.15,j*.76,7)
			if j%3==1:world.block_disc(o,width*.76,h)
	for j in 18:
		var p:=Vector2(-232+rng.randf_range(-4,2),-286+rng.randf_range(-8,11))
		if world._road_distance(p)<3.5:continue
		var s:=rng.randf_range(.28,1.26)
		_outcrop(_at(p),-.76,[Vector4(-.18,s*1.3,s*.65,0),Vector4(.25*s,s,s*.6,.10),Vector4(.65*s,s*.54,s*.31,.15)],
			["#779aa6","#b5cfce"],.20,j)

# The undercut erodes right through a bedded slab; the rocks and the gap share the same contour.
func _sea_arch(o:Vector3,yaw:float,scale_factor:float) -> void:
	var u:=Vector3(cos(yaw),0,sin(yaw))
	var z:=Vector3(-u.z,0,u.x)
	var last:Array=[]
	var tones:=["#576e70","#768885","#a6a99b","#b2af94","#8a9980"]
	for i in 18:
		var x:float=lerpf(-7.7,7.7,float(i)/17)
		var hole:float=3.7*pow(maxf(0.,1.-pow(absf((x+.28)/4.36),2.0)),.63)-.48
		var upper:=4.89+.63*sin(x*.69)+.72*cos(x*.33)+.38*sin(x*1.46)
		upper-=2.85*smoothstep(5.0,8.0,absf(x+.35))
		var row:Array=[]
		for j in 6:
			var f:float=[0.,.29,.52,.63,.89,1.][j]
			var y:=lerpf(hole,upper,f)+sin(f*PI)*(.28*sin(.82*x+f*1.9)+.13*cos(1.87*x-.5*f))
			var width:=1.13+.25*cos(x*.74)+.28*sin(f*4.+x*.25)+f*.47+.15*cos(1.3*x-.5*f)
			var mid:=o+u*x*scale_factor+Vector3.UP*y*scale_factor
			row.append([mid+z*(width+.17*sin(x*.93+j*1.28))*scale_factor,mid-z*width*scale_factor])
			if i>0 and j>0:
				for side in 2:
					_quad(last[j-1][side],row[j-1][side],row[j][side],last[j][side],z if side==0 else -z,Color(tones[j-1]))
		if i>0:
			_quad(last[5][0],last[5][1],row[5][1],row[5][0],Vector3.UP,Color("#a9ac92"))
			_quad(last[0][0],last[0][1],row[0][1],row[0][0],Vector3.DOWN,Color("#687978"))
		if i==0 or i==17:
			for j in 5:_quad(row[j][0],row[j][1],row[j+1][1],row[j+1][0],u if i else -u,Color(tones[j]))
		last=row
	for x:float in [-5.8,5.8]:world.block_disc(o+u*x*scale_factor,1.42*scale_factor,4.6*scale_factor)

func _sea_stacks() -> void:
	var o:=_at(Vector2(-299,-1))
	o.y=maxf(-.30,o.y)
	_sea_arch(o,1.27,1.18)
	for item:Array in [[Vector2(-312,4),3.9,2.1],[Vector2(-313,-1),2.7,1.55],[Vector2(-248,15),2.2,1.3],[Vector2(-264,20),3.4,2.8]]:
		var h:float=item[1]
		var radius:float=item[2]
		var q:=_at(item[0])
		q.y=maxf(-.62,q.y)
		_outcrop(q,1.3,[Vector4(-.7,radius*1.37,radius,0),Vector4(h*.28,radius*.76,radius*.52,-.20),
			Vector4(h*.58,radius*.93,radius*.63,-.25),Vector4(h*.66,radius,radius*.68,-.27),Vector4(h,radius*.65,radius*.58,-.42)],
			["#5f7773","#7e8982","#b1aa95","#8a9987"],.22,h)
	for j in 18:
		# Slumped tabular sandstone obscures the upright ends and leans into the tide cut.
		var u:=Vector2(cos(1.27),sin(1.27))
		var s:=rng.randf_range(.66,1.84)
		var end:=1.0 if j%2 else -1.0
		var pos:=Vector2(-299,-1)+u*end*rng.randf_range(5.6,10.25)+u.orthogonal()*rng.randf_range(-2.4,2.1)
		var q:=_at(pos)
		var high:=1.0+(.66 if j%3 else 1.6)
		_outcrop(q,1.17,[Vector4(-.28,s*1.15,s*.96,0),Vector4(.36*high,s*1.25,s*.88,.12),
			Vector4(.77*high,s*1.12,s*.80,.22),Vector4(high,s*.77,s*.63,.34)],
			["#647773","#859489","#a2ab98"],.26,j,8)
	for j in 11:
		var q:=_at(Vector2(-294,-2)+Vector2(rng.randf_range(-3.,3.),rng.randf_range(-8.,6.)))
		var s:=rng.randf_range(.33,1.13)
		_outcrop(q,1.3,[Vector4(-.22,s,s*.6,0),Vector4(.19*s,s,s*.57,.04),Vector4(.46*s,s*.61,s*.33,.09)],
			["#687a70","#90a28c"],.18,j)

func _basalt() -> void:
	# Hexagonal columns interlock on a fractured cooling front, growing into organ pipes.
	for group:Array in [[Vector2(-214,280),1.02,4],[Vector2(-187,297),.93,4],[Vector2(-163,237),.62,3]]:
		var center:Vector2=group[0]
		var size:float=group[1]
		var radius:int=group[2]
		for row in range(-radius,radius+1):
			for col in range(-radius,radius+1):
				if abs(row+col)>radius:continue
				var offset:=Vector2(1.46*col+.73*row,1.28*row)*size
				var p:=center+offset
				if world._road_distance(p)<4.2 or Geo.path_distance(p,Geo.LAVA_CREEK)<2.95:continue
				var fan:float=1.0-offset.length()/(1.54*(radius+1)*size)
				var h:=size*(1.0+maxf(0.,fan)*7.0+1.4*sin(row*.7)+rng.randf_range(.1,1.35))
				var r:=.86*size
				var q:=_at(p)
				var d:float=rng.randf_range(0,.16)
				_outcrop(q,PI/6,[Vector4(-.4,r,r,0),Vector4(h*.41,r*.97,r*.98,d),
					Vector4(h*.44,r*.92,r*.93,d),Vector4(h*.94,r*.95,r*.96,d*2),Vector4(h,r*.82,r*.87,d*2)],
					["#565760","#787276","#5e5d69","#8c7874"],.038,row+col*.8,6)
		var origin:=_at(center)
		if world._road_distance(center)>7.:world.block_disc(origin,2.52*size,4.2*size)
	_vents()
	# Fused sulphur crusts hug a few feet of the fumarole, sheltered from the molten run.
	for j in 22:
		var p:=Vector2(-209,279)+Vector2(rng.randf_range(-2.8,2.1),rng.randf_range(-4.8,4.2))
		if Geo.path_distance(p,Geo.LAVA_CREEK)<3.1:continue
		var s:=rng.randf_range(.21,.63)
		_outcrop(_at(p),p.x,[Vector4(-.13,s*1.5,s,0),Vector4(.22*s,s*1.42,s*.85,.05),Vector4(.63*s,s*.7,s*.49,.12)],
			["#91856a","#ceae69"],.19,j,6)

func _yardangs() -> void:
	# Wind scoops out the soft underbeds and leaves unbroken dark capstone on the fins.
	for item:Array in [[Vector2(342,281),1.02,1.0],[Vector2(350,287),.82,.80],[Vector2(338,284),.55,.68],
		[Vector2(353,258),1.06,1.2],[Vector2(305,232),.58,.9],[Vector2(298,228),.42,.75]]:
		var p:Vector2=item[0]
		var s:float=item[1]
		var l:float=item[2]*s
		_outcrop(_at(p),.55,[Vector4(-1,4.45*l,2.65*s,0),Vector4(.80*s,3.8*l,2.1*s,.42*s),
			Vector4(2.26*s,2.7*l,1.16*s,.77*s),Vector4(3.30*s,2.36*l,1.09*s,.97*s),
			Vector4(3.86*s,3.22*l,1.69*s,.82*s),Vector4(4.19*s,3.38*l,1.74*s,.78*s),
			Vector4(4.55*s,3.59*l,1.68*s,.67*s),Vector4(5.96*s,3.06*l,1.38*s,.79*s),
			Vector4(6.32*s,2.71*l,1.20*s,1.03*s)],["#bd946f","#a77555","#a87452","#c69969","#8c634d","#d4ac79","#ba8e69","#dfb98a"],.22,p.y,14)
		world.block_disc(_at(p),1.30*s,5.2*s)
	for j in 16:
		var p:=Vector2(339,277)+Vector2(rng.randf_range(-6.5,8.),rng.randf_range(-2.0,7.))
		if world._road_distance(p)<3.0:continue
		var s:=rng.randf_range(.3,1.14)
		_outcrop(_at(p),.55,[Vector4(-.26,s*1.68,s,0),Vector4(.39*s,s*1.49,s*.84,0),Vector4(.61*s,s*1.24,s*.65,.16)],
			["#ab7f5d","#c7a179"],.24,j,7)

func _drowned_aqueduct() -> void:
	# A broken causeway comes out of the western water in three step-down arches. The
	# collapsed eastern spans finish below the bells; their silhouettes stay separate.
	var o:=Vector3(407,Geo.LAKE_LEVEL-.18,6)
	var u:=Vector3(.61,0,.79)
	var z:=Vector3(-u.z,0,u.x)
	for i in 4:
		var mid:=o+u*4.65*i
		var h:=1.25-.22*i
		_outcrop(mid,.88,[Vector4(-2.1,1.32,.94,0),Vector4(.25,1.14,.82,0),Vector4(h,1.05,.77,0)],
			["#6c8076","#91978a"],.077,i,8)
		for j in 3:
			world.model("box",mid+Vector3.UP*(h+.064+j*.20),Vector3(1.65-.07*j,.17,1.26),"#adb0a0" if j==0 else "#8a9788",-.66)
		if i==3:break
		var center:=mid+u*2.33+Vector3.UP*(h-.27)
		for j in 11:
			if i==2 and j in [4,5,6]:continue
			var a:=PI*(j+.025)/11.0
			var b:=PI*(j+.975)/11.0
			var radius:=1.87
			var outer:=2.36+.10*float(j==5)
			var corners:Array[Vector3]=[center+(u*cos(a)+Vector3.UP*sin(a))*radius,center+(u*cos(b)+Vector3.UP*sin(b))*radius,
				center+(u*cos(b)+Vector3.UP*sin(b))*outer,center+(u*cos(a)+Vector3.UP*sin(a))*outer]
			var tint:=Color("#98a190").lightened(float((j+i)%3)*.048)
			for sig:float in [-1.,1.]:
				_quad(corners[0]+z*sig*.61,corners[1]+z*sig*.61,corners[2]+z*sig*.61,corners[3]+z*sig*.61,z*sig,tint)
			for k in 4:
				var n:=(k+1)%4
				var outside:Vector3=(corners[k]+corners[n])*.5-(corners[0]+corners[2])*.5
				_quad(corners[k]-z*.61,corners[n]-z*.61,corners[n]+z*.61,corners[k]+z*.61,outside,tint.darkened(.10))
	for tree:Array in [[Vector2(379,-2.5),7.8],[Vector2(387,-4),6.4],[Vector2(374,18),5.7],[Vector2(397,56),6.2],[Vector2(456,71),5.9]]:
		_willow(tree[0],tree[1])

func _ribbon(path:Array,widths:Array,side:Vector3,tint:Color) -> void:
	for i in range(1,path.size()):
		var a:Vector3=path[i-1]
		var b:Vector3=path[i]
		var n:=(b-a).cross(side).normalized()
		if n.y<0:n=-n
		var offset:=n*maxf(float(widths[i])*.10,.012)
		_quad(a-side*float(widths[i-1]),a+offset,b+offset,b-side*float(widths[i]),n,tint)
		_quad(a+offset,a+side*float(widths[i-1]),b+side*float(widths[i]),b+offset,n,tint.lightened(.055))

func _willow(p:Vector2,h:float) -> void:
	var o:=_at(p)
	if o.y<Geo.LAKE_LEVEL:o.y=Geo.LAKE_LEVEL-.19
	var trunk:=Vector3(.15*h,h*.54,.09*h)
	_tube([o-Vector3.UP*.36,o+Vector3.UP*h*.22,o+trunk],[h*.08,h*.066,h*.046],Color("#706f59"),8)
	world.block_disc(o,h*.066,h*.46)
	for k in 8:
		var t:=k*2.40+p.x
		var f:=Vector3(cos(t),0,sin(t))
		var side:=Vector3(-f.z,0,f.x)
		var branch:=o+trunk-Vector3.UP*h*rng.randf_range(.04,.14)
		var elbow:=branch+f*h*.23+Vector3.UP*h*.19
		var top:=branch+f*h*rng.randf_range(.37,.55)+Vector3.UP*h*(.28+.05*cos(k))
		_tube([branch,elbow,top],[h*.037,h*.027,.065],Color("#777b60"),6)
		world.model("crown",elbow.lerp(top,.6)+Vector3.UP*.42,Vector3(h*.22,h*.22,h*.19),"#8ca282" if k%2 else "#819b7d",t)
		for j in 9:
			var a:=top+f*rng.randf_range(-.45,.52)+side*rng.randf_range(-h*.19,h*.19)+Vector3.UP*rng.randf_range(-.3,.65)
			var mid:=a+f*h*.08-Vector3.UP*h*rng.randf_range(.11,.19)
			var end:=mid-f*rng.randf_range(.04,.31)-Vector3.UP*h*rng.randf_range(.23,.53)
			var across:=(side+f*(j%3-.9)).normalized()
			_ribbon([a,mid,mid.lerp(end,.66)+f*.14,end],[.02,.070*h/6,.043*h/6,0.0],across,Color(["#8da787","#85a382","#a8b88c"][j%3]))

func _old_growth() -> void:
	for tree:Array in [[Vector2(296,-242),15.3],[Vector2(295,-259),14.6],[Vector2(313,-264),16.8],
		[Vector2(277,-225),12.5],[Vector2(258,-208),13.2],[Vector2(235,-215),11.8]]:
		var p:Vector2=tree[0]
		if world._road_distance(p)>4.55:_fig(p,tree[1])
	# One snapped nurse log has a visible heartwood break, fungal brackets and a moss seam.
	var a:=_at(Vector2(290,-247))
	var b:=_at(Vector2(296,-253))
	if world._road_distance(Vector2(290,-247))<3.0:
		a=_at(Vector2(288,-253))
		b=_at(Vector2(295,-258))
	a.y+=.62
	b.y+=.77
	var mid:=a.lerp(b,.5)+Vector3.UP*.16
	_tube([a,mid,b],[.51,.66,.57],Color("#685c49"),10)
	var dir:=(b-a).normalized()
	_tube([b,b+dir*.022],[.47,.46],Color("#aa8b64"),10)
	_tube([b+dir*.026,b+dir*.035],[.29,.26],Color("#80684c"),9)
	for j in 6:
		var q:=a.lerp(b,.10+j*.14)+Vector3.UP*.51
		world.model("crown",q,Vector3(.66,.21,.43),"#8b9a64",j)
		if j%2==0:_bracket(q+Vector3(.32,-.22,.38),.32,j)

func _bracket(p:Vector3,size:float,yaw:float) -> void:
	_outcrop(p,yaw,[Vector4(-.08*size,.85*size,.64*size,0),Vector4(.03*size,size,size*.76,0),
		Vector4(.23*size,size*.90,size*.60,-.03),Vector4(.43*size,size*.50,size*.36,-.04)],
		["#dbc49a","#c79b72","#977056"],.09,yaw,9)

func _fig(p:Vector2,h:float) -> void:
	var o:=_at(p)
	var lean:=Vector3(cos(p.x),0,sin(p.x))*h*.06
	var bark:=Color("#726447")
	var trunk_top:=o+lean+Vector3.UP*h*.76
	_tube([o-Vector3.UP*.75,o+Vector3.UP*h*.23,o+lean*.58+Vector3.UP*h*.54,trunk_top],
		[h*.101,h*.077,h*.063,h*.029],bark,12)
	world.block_disc(o,h*.075,h*.72)
	for i in 9:
		var a:=TAU*i/9+p.x
		var f:=Vector3(cos(a),0,sin(a))
		var side:=Vector3(-f.z,0,f.x)
		var foot2:=p+Vector2(f.x,f.z)*h*(.24+.04*cos(i))
		var toe:=_at(foot2)+Vector3.UP*.10
		var flank:=o+f*h*.11+Vector3.UP*h*.15
		var top:=o+f*h*.057+Vector3.UP*h*(.27+.09*sin(i))
		_face(top,flank+side*.44,toe,side,bark.lightened(.06))
		_face(top,toe,flank-side*.44,-side,bark)
		_face(top,o+side*.44+f*.69,flank+side*.44,side,bark.darkened(.07))
		_face(top,flank-side*.44,o-side*.44+f*.69,-side,bark.darkened(.14))
		_tube([flank,flank.lerp(toe,.58)-Vector3.UP*.30,toe],[.34,.21,.08],Color("#807858"),6)
		var limb:=o+lean*.74+Vector3.UP*h*(.48+.13*sin(i))
		var knee:=limb+f*h*.15+Vector3.UP*h*.16
		var tip:=limb+f*h*(.27+.075*sin(2.*i))+Vector3.UP*h*.28
		_tube([limb,knee,tip],[h*.051,h*.034,.14],bark,7)
		world.model("crown",tip+Vector3.UP*.35,Vector3(h*.21,h*.28,h*.19),["#4b7056","#60845e","#749064"][i%3],a)
		if i%3==1:
			for j in 5:
				var q:=tip+side*(j-2)*.42
				_ribbon([q,q+f*.24-Vector3.UP*1.8,q-f*.10-Vector3.UP*(2.45+.78*cos(j))],
					[.12,.14,.005],side,Color("#839575"))
		if i%3==0:
			_bracket(o+f*h*.084+Vector3.UP*(.85+.45*(i%4)),.51,a)
			_bracket(o+f*h*.080+side*.22+Vector3.UP*(1.10+.45*(i%4)),.34,a)
	world.model("crown",trunk_top+Vector3.UP*h*.11,Vector3(h*.29,h*.27,h*.26),"#698a60",p.y)

func _vents() -> void:
	var veil:=ShaderMaterial.new()
	veil.shader=preload("expedition_steam.gdshader")
	for item:Array in [[Vector2(-216,281),6.5,.53],[Vector2(-188,298),7.8,.17],[Vector2(-182,243),5.2,.81]]:
		var plume:=MeshInstance3D.new()
		var plane:=QuadMesh.new()
		var h:float=item[1]
		plane.size=Vector2(h*.50,h)
		plume.mesh=plane
		plume.material_override=veil
		plume.position=_at(item[0])+Vector3.UP*(h*.5+1.85)
		plume.set_instance_shader_parameter("phase",item[2])
		plume.extra_cull_margin=h*.4
		plume.visibility_range_end=96
		plume.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(plume)
