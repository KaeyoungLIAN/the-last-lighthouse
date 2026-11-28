"""Blender 4.5 source for the three outer-coast landmarks. Y is up in the authored coordinates."""
from pathlib import Path
from tempfile import TemporaryDirectory
from math import cos, sin, pi, tau
import sys
import bpy
from mathutils import Vector
bpy.ops.wm.read_factory_settings(use_empty=True)
sys.dont_write_bytecode=True
sys.path.insert(0,str(Path(__file__).resolve().parent))
from painted_mesh import Part, painted_material, xyz
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/"game"/"art"/"outer_coast"
OUT.mkdir(exist_ok=True,parents=True)
chalk="e4dac0"
iron="485858"
bronze="aa8256"
gold="cca86a"
slate="607979"
oldwood="886c51"
darkwood="625143"
canvas="e6d7b6"
stone=["8b958e","9d9f8e","b2ad95","89968e","a2a38d","b3ac98"]

def timber(p,a,b,width,depth,color):
    start,end=Vector(a),Vector(b)
    axis=(end-start).normalized()
    ref=Vector((0,0,1)) if abs(axis.z)<.90 else Vector((1,0,0))
    u=axis.cross(ref).normalized()*width/2
    v=axis.cross(u).normalized()*depth/2
    p.rings([[tuple(pt+u*x+v*y) for x,y in [(-1,-.87),(-.87,-1),(.87,-1),(1,-.87),
                (1,.87),(.87,1),(-.87,1),(-1,.87)]] for pt in (start,end)],color,False)

def box(p,x,y,z,w,h,d,c):
    timber(p,(x,y-h/2,z),(x,y+h/2,z),w,d,c)

def stone_course(p,y,radius,r2,height,count,phase,colors):
    for j in range(count):
        a=(j+phase)*tau/count
        b=a+tau/count-.012
        arc=[a,(a+b)/2,b]
        rings=[]
        for h,r in [(y,radius-.022),(y+.025,radius),(y+height-.026,r2),(y+height,r2-.020)]:
            outline=[(r*sin(t),h,r*cos(t)) for t in arc]
            outline+= [((r-.125)*sin(t),h,(r-.125)*cos(t)) for t in reversed(arc)]
            rings.append(outline)
        p.rings(rings,colors[(j*5+int(y*10))%len(colors)],False)

def circular(p,center,u,v,radius,thick,color,span=(0,tau),count=72):
    center,u,v=map(Vector,(center,u,v))
    points=[tuple(center+radius*(u*cos(span[0]+(span[1]-span[0])*j/count)+v*sin(span[0]+(span[1]-span[0])*j/count))) for j in range(count+1)]
    p.sweep(points,[thick]*(count+1),color,8)

def export(name,parts,offset,assembly=None):
    with TemporaryDirectory() as tmp:
        mat,tiles,n=painted_material(name,[c for p in parts for c in p.colors],tmp)
    objs=[p.finish(mat,tiles,n) for p in parts]
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs: o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+".glb")),export_format="GLB",use_selection=True,
                              export_animations=False,export_cameras=False,export_lights=False)
    collection=bpy.data.collections.new(name.replace("_"," ").title())
    bpy.context.scene.collection.children.link(collection)
    for o in objs:
        o.users_collection[0].objects.unlink(o)
        collection.objects.link(o)
        o.location+=Vector(xyz(offset))
        if assembly and o.name in assembly: o.location+=Vector(xyz(assembly[o.name]))

def mill_opening(p,angle,r,y,w,h,door=False):
    # Inset arched opening in a tangent frame, with stone voussoirs.
    def point(x,u,f):
        return (r*sin(angle)+cos(angle)*x+sin(angle)*f,y+u,r*cos(angle)-sin(angle)*x+cos(angle)*f)
    radius=w/2
    rise=h-radius
    outline=[point(-radius,0,.002),point(radius,0,.002)]
    outline.extend(point(radius*cos(j*pi/16),rise+radius*sin(j*pi/16),.002) for j in range(17))
    p.panel(outline,"585e55" if door else "638183",.036,axis=2 if abs(cos(angle))>.7 else 0)
    for s in (-1,1):
        p.sweep([point(s*radius,0,.048),point(s*radius,rise,.048)],[.073,.070],"c7b99b" if door else oldwood,8)
    for j in range(10):
        a=j*pi/10
        b=(j+1)*pi/10-.012
        q=[point(rr*cos(t),rise+rr*sin(t),.065) for rr,t in [(radius-.025,a),(radius+.115,a),(radius+.115,b),(radius-.025,b)]]
        p.panel(q,["c8b99b","cabca0","bba98a"][j%3],.053)
    if door:
        for j in range(9):
            x=(j-4)*w/9
            top=rise+(radius**2-x**2)**.5-.06
            timber(p,point(x,.035,.061),point(x,top,.061),w/9-.011,.053,["5c8078","698981","597870"][j%3])
        for yy in [.31,1.07]:
            timber(p,point(-radius+.05,yy,.091),point(radius-.05,yy,.091),.073,.056,darkwood)
        p.oval(point(.31,.84,.133),(.051,.069,.049),gold)
    else:
        for x in [-w*.20,w*.20]:
            timber(p,point(x,0,.064),point(x,rise+(radius**2-x**2)**.5,.064),.049,.04,oldwood)
        timber(p,point(-radius,rise*.70,.065),point(radius,rise*.70,.065),.051,.041,oldwood)
        timber(p,point(-radius-.14,-.046,.06),point(radius+.14,-.046,.06),.14,.28,"beac88")

def windmill():
    p=Part("MillTower")
    p.loft([(-.22,2.71,2.71),(.13,2.76,2.76),(.68,2.73,2.73),(.77,2.65,2.65),
            (2.0,2.56,2.56),(3.82,2.36,2.36),(5.83,2.10,2.10),(6.73,2.00,2.00)],
           ["969886","92988b","b8b39e",chalk,"e2d6b8","dfd2b4",chalk],36)
    for j in range(3):
        stone_course(p,-.13+j*.298,2.81-j*.013,2.805-j*.013,.276,29,j*.5,stone)
    for base,r in [(2.44,2.53),(4.75,2.26),(6.52,2.058)]:
        p.loft([(base,r,r),(base+.035,r+.035,r+.035),(base+.117,r+.035,r+.035),(base+.149,r,r)],
               ["7f6d58","9e8766","aca087"],36)
    for j in range(18):
        a=j*tau/18
        y=5.98
        r=2.08
        timber(p,(r*sin(a),y,r*cos(a)),((r+.21)*sin(a),6.51,(r+.21)*cos(a)),.125,.132,oldwood)
    p.loft([(6.44,2.06,2.06),(6.56,2.30,2.30),(6.65,2.35,2.35),(6.80,2.33,2.33),
            (7.17,2.08,2.08),(7.52,1.60,1.60),(7.73,1.05,1.05),(7.90,.49,.49),(8.01,.19,.19)],
           [oldwood,"5a706c",iron,"866d58","ab755d","996c59","9f7760","8b6c58"],36)
    for i,(y,outer,inner,rise) in enumerate([(6.79,2.36,2.10,.39),(7.14,2.15,1.62,.40),(7.50,1.68,1.07,.26),(7.72,1.12,.49,.211)]):
        stone_course(p,y,outer,inner,rise,30,i*.5,["9c6356","ae7962","b58166","936b5d","a67862"])
    p.loft([(7.93,.44,.44),(8.05,.22,.22),(8.09,.16,.16),(8.34,.055,.055)],["68877f",gold,bronze],20)
    mill_opening(p,0,2.659,.09,1.28,2.03,True)
    for a in [1.36,-1.26,3.12]:
        mill_opening(p,a,2.40,2.71,.71,1.07)
    for i in range(3):
        box(p,0,.108-i*.066,2.80+i*.235,1.62,.258,.42,stone[(i+1)%6])
    p.sweep([(0,5.90,1.89),(0,5.90,2.30),(0,5.90,2.56)],[.43,.337,.255],["66685d",bronze],18)
    rotor=Part("SailWheel")
    rotor.origin=(0,5.90,2.63)
    for i in range(4):
        a=i*pi/2+.33
        def sail(x,y,z):
            return (x*cos(a)-y*sin(a),x*sin(a)+y*cos(a),z)
        timber(rotor,sail(0,-.21,0),sail(0,4.79,0),.155,.185,oldwood)
        timber(rotor,sail(.21,1.55,0),sail(.82,4.73,0),.055,.069,oldwood)
        for j in range(8):
            h=1.48+j*.432
            w=.30+.075*j
            timber(rotor,sail(-.067,h,.064),sail(w+.10,h,.064),.057,.063,"a78a65")
            if j>=7: break
            # Sails billow between the bolt ropes. Outer panel carries the mill's red stripe.
            rings=[]
            for u in [0,.5,1]:
                yy=h+.043+.384*u
                ww=w+.075*u
                rings.append([sail(x,yy,z) for x,z in [(.092,.05),(ww*.55,.118+.032*sin(pi*u)),(ww,.042),
                                                       (ww,.021),(ww*.55,.093+.032*sin(pi*u)),(.092,.022)]])
            rotor.rings(rings,"ae705b" if j==5 else ["dccbab","eaddbb","e4d4b4"][j%3],False)
    rotor.sweep([(0,0,-.19),(0,0,.13),(0,0,.21),(0,0,.297)],[.31,.344,.237,.124],[iron,bronze,gold],20)
    export("windmill",[p,rotor],(-10,0,0))

def observatory():
    p=Part("SurveyInstrument")
    p.loft([(-.27,3.01,3.01),(.08,3.00,3.00),(.27,2.96,2.96),(.32,2.79,2.79),
            (.48,2.72,2.72),(.53,2.65,2.65)],["808d89","a3a797","c1baa2","919e96","c4c1a8"],40)
    circular(p,(0,.55,0),(1,0,0),(0,0,1),2.36,.034,bronze)
    for i in range(32):
        a=tau*i/32
        r=2.04 if i%4==0 else 2.23
        p.sweep([(r*sin(a),.551,r*cos(a)),(2.49*sin(a),.551,2.49*cos(a))],
                [.019,.017],gold if i%4==0 else slate,6)
    for s in (-1,1):
        timber(p,(s*.80,.55,0),(s*.257,2.85,0),.275,.344,"67817b")
    p.loft([(.52,.89,.89),(.62,.94,.94),(.70,.88,.88),(.79,.738,.738),(.89,.747,.747),
            (2.46,.437,.437),(2.58,.574,.574),(2.70,.556,.556),(2.78,.37,.37)],
           [slate,bronze,iron,gold,"748a82",bronze,"67817c",iron],22)
    center=Vector((0,4.05,0))
    u=Vector((1,0,0)); v=Vector((0,1,0)); axis=Vector((0,0,1))
    # Graduated meridian, a second oblique ecliptic and their gimballed telescope.
    for r,thick,col,z in [(3.45,.105,bronze,-.035),(3.31,.074,"d6b677",.087),(3.54,.036,slate,.020)]:
        circular(p,center+axis*z,u,v,r,thick,col,span=(0,tau),count=112)
    for i in range(96):
        a=tau*i/96
        n=u*cos(a)+v*sin(a)
        r=3.064 if i%8==0 else (3.166 if i%4==0 else 3.251)
        p.sweep([tuple(center+n*r+axis*.084),tuple(center+n*3.445+axis*.084)],
                [.028 if i%8==0 else .012,.012],gold,6)
    tilted=Vector((0,.49,.87)).normalized()
    circular(p,center,u,tilted,2.49,.061,"7b9890",count=68)
    ring_u=Vector((.73,.27,.63)).normalized()
    ring_v=ring_u.cross(Vector((0,1,0))).normalized()
    circular(p,center,ring_u,ring_v,1.24,.040,gold,count=48)
    tube=Vector((.824,.536,.190)).normalized()
    def loc(t): return tuple(center+t*tube)
    p.sweep([loc(-2.37),loc(-2.10),loc(-2.03),loc(-1.19),loc(-1.09),loc(.188),loc(.292),loc(1.79),loc(2.03),loc(2.171)],
            [.126,.132,.145,.151,.199,.218,.259,.276,.345,.344],[bronze,iron,slate,gold,"48696d",bronze,"668482",bronze,gold],28)
    p.sweep([loc(2.172),loc(2.187)],[.296,.291],"9ac5ba",32)
    p.sweep([(-.25,2.55,0),(-.25,3.174,0),(-.80,3.69,0)],[.103,.118,.097],bronze)
    p.oval((0,4.04,.109),(.296,.296,.227),bronze)
    p.oval((0,4.04,.247),(.211,.211,.124),"698c84")
    export("star_survey",[p],(0,0,0))

def bell_frame():
    p=Part("FogBell")
    p.loft([(-.23,3.57,2.72),(.075,3.61,2.78),(.217,3.52,2.68),(.278,3.37,2.55)],
           ["838c82","a6a58f","bab297"],28)
    for side in (-1,1):
        x=side*2.04
        p.loft([(.23,.573,.53,0,x),(.38,.586,.543,0,x),(.91,.483,.458,0,x),
                (1.02,.493,.465,0,x),(1.09,.424,.397,0,x)],
               ["828c82","9ca291","8a9385","c4b89b"],8)
        timber(p,(x,.56,0),(x,5.82,0),.40,.455,oldwood)
        for z in [-.19,.19]:
            timber(p,(x,3.91,z),(side*1.16,5.50,z),.205,.156,"a18360")
        for y in [1.26,1.39,4.12,5.26]:
            box(p,x,y,0,.443,.083,.489,iron)
        for z in [-.255,.255]:
            for y in [1.25,4.19,5.53]:
                p.sweep([(x,y,z-.026),(x,y,z+.023)],[.052,.052],gold,8)
    box(p,0,5.58,0,4.98,.421,.53,oldwood)
    # Copper flashing protects the transverse yoke and extends past both end-grain cuts.
    for side in (-1,1):
        panel=[(-2.59,5.923,0),(2.59,5.923,0),(2.59,5.759,side*.41),(-2.59,5.759,side*.41)]
        p.panel(panel,"607f78",depth=-.042,axis=1)
        for i in range(7):
            x=-2.46+i*.82
            p.sweep([(x,5.934,0),(x,5.771,side*.41)],[.018,.018],"91a292",6)
    p.sweep([(-.486,5.41,0),(.486,5.41,0)],[.132,.132],iron,16)
    for s in (-1,1):
        circular(p,(s*.238,5.13,0),(1,0,0),(0,1,0),.233,.059,bronze,count=24)
    # Revolved bell profile doubles back into the interior so the mouth reads hollow.
    p.loft([(5.10,.25,.25),(4.997,.53,.53),(4.90,.633,.633),(4.79,.672,.672),
            (4.644,.689,.689),(4.55,.698,.698),(4.485,.716,.716),(4.37,.728,.728),
            (4.06,.777,.777),(3.71,.886,.886),(3.40,1.061,1.061),(3.215,1.25,1.25),
            (3.156,1.335,1.335),(3.068,1.369,1.369),(3.017,1.33,1.33),(3.020,1.191,1.191),
            (3.19,1.112,1.112),(3.43,.909,.909),(3.99,.636,.636),(4.56,.459,.459),(4.69,.215,.215)],
           ["947958","768a79","93a193","59796f","b09a6e","597a71","8f9e8b","789789","719183",
            "739286","86a092","ac9e78","6a8a80","d0b786","8e927a","667e74","5a756d","4f6862","536960","536960"],48)
    p.sweep([(0,4.67,0),(.084,3.22,.02),(.11,2.815,.047)],[.078,.074,.09],bronze,15)
    p.oval((.109,2.882,.046),(.175,.206,.175),bronze)
    for i in range(18):
        a=tau*i/18
        # Repeating cast lozenges around the shoulder of the bell.
        def point(rad,h,angle): return (rad*sin(angle),h,rad*cos(angle))
        p.panel([point(.766,4.323,a),point(.763,4.238,a+.037),point(.783,4.138,a),point(.763,4.238,a-.037)],gold,.012)
    p.sweep([(1.63,5.53,.13),(1.66,4.373,.16),(1.51,3.11,.173),(1.49,2.02,.173),(1.66,1.70,.18)],
            [.032,.034,.031,.030,.045],"b19874",8)
    circular(p,(1.67,1.57,.183),(1,0,0),(0,1,0),.139,.029,"b19874",count=20)
    export("cape_bell",[p],(10,0,0))

windmill()
observatory()
bell_frame()
for image in bpy.data.images:
    if image.packed_file: image.filepath_raw="//"+image.name
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=="VIEW_3D":
            area.spaces.active.shading.color_type="TEXTURE"
            region=area.spaces.active.region_3d
            region.view_distance=26
            region.view_location=(0,0,4.1)
            region.view_rotation=Vector((-.24,.88,-.37)).to_track_quat("-Z","Y")
bpy.ops.object.select_all(action="DESELECT")
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/"art_source"/"Outer_Coast.blend"),compress=True)
