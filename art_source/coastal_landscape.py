"""Rebuild the island mesh library with Blender 4.5 in background mode.

Coordinates are metres, Z up; building entrances face -Y (+Z in Godot).
Each named object becomes one vertex-painted mesh in the game's MultiMeshes.
"""
from math import cos, pi, sin, tau
from pathlib import Path
from random import Random

import bpy
import bmesh
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[1]
V = Vector
bpy.ops.wm.read_factory_settings(use_empty=True)
paint = bpy.data.materials.new("MAT_Coastal_Pigment")
paint.use_nodes = True
paint.use_backface_culling = False
bsdf = paint.node_tree.nodes.get("Principled BSDF")
bsdf.inputs["Roughness"].default_value = .88
attr = paint.node_tree.nodes.new("ShaderNodeVertexColor")
attr.layer_name = "Pigment"
paint.node_tree.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])


class Model:
    def __init__(self, name, seed):
        self.name = name
        self.rng = Random(seed)
        self.vertices, self.faces, self.colors = [], [], []
        self.smooth_faces = set()

    def face(self, points, color, gain=1):
        start = len(self.vertices)
        self.vertices.extend(points)
        self.faces.append(tuple(range(start, start + len(points))))
        rgb = [min(1, int(color[i:i+2], 16) / 255 * gain) for i in (0, 2, 4)]
        self.colors.append((*rgb, 1))

    def rings(self, rings, color, vary=.035, cap=None):
        self.face(list(reversed(rings[0])), color)
        for k, (lower, upper) in enumerate(zip(rings, rings[1:])):
            for i in range(len(lower)):
                j = (i + 1) % len(lower)
                self.face([lower[i], lower[j], upper[j], upper[i]], color,
                          self.rng.uniform(1-vary, 1+vary))
        self.face(rings[-1], cap or color)

    def lathe(self, x, y, levels, color, sides=16, cap=None):
        rings = [[(x+r*cos(tau*j/sides), y+r*sin(tau*j/sides), z)
                  for j in range(sides)] for z, r in levels]
        self.rings(rings, color, cap=cap)

    def branch(self, points, radii, color, sides=7):
        path = list(map(V, points))
        rings = []
        tangent = (path[-1]-path[0]).normalized()
        ref = V((0, 1, 0)) if abs(tangent.y) < .88 else V((1, 0, 0))
        for i, p in enumerate(path):
            axis = (path[min(i+1, len(path)-1)] - path[max(i-1, 0)]).normalized()
            u = axis.cross(ref).normalized()
            v = axis.cross(u)
            rings.append([p + (u*cos(tau*j/sides)+v*sin(tau*j/sides))*radii[i]
                          for j in range(sides)])
        self.rings(rings, color, .065)

    def beam(self, a, b, radius, color, sides=8):
        self.branch([a, b], [radius, radius], color, sides)

    def box(self, center, size, color):
        x,y,z = center
        w,d,h = (a*.5 for a in size)
        self.rings([[(x+sx*w,y+sy*d,z+k*h) for sx,sy in ((-1,-1),(1,-1),(1,1),(-1,1))]
                    for k in (-1,1)], color)

    def finish(self):
        mesh = bpy.data.meshes.new(self.name)
        mesh.from_pydata(self.vertices, [], self.faces)
        mesh.update()
        if self.name in ("SeaBent","Marram","SeaThrift","SeaKale"):
            # Godot's grass shader reads glTF's top-origin V as wind weight.
            uv=mesh.uv_layers.new(name="Wind")
            for loop in mesh.loops:
                height=mesh.vertices[loop.vertex_index].co.z
                uv.data[loop.index].uv=(.5,1-max(0,min(1,height)))
        layer = mesh.color_attributes.new(name="Pigment", type="BYTE_COLOR", domain="CORNER")
        for face, rgba in zip(mesh.polygons, self.colors):
            face.use_smooth = face.index in self.smooth_faces
            for index in face.loop_indices:
                layer.data[index].color_srgb = rgba
        if self.smooth_faces:
            bm = bmesh.new()
            bm.from_mesh(mesh)
            bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=.00001)
            bm.to_mesh(mesh)
            bm.free()
        obj = bpy.data.objects.new(self.name, mesh)
        bpy.context.collection.objects.link(obj)
        mesh.materials.append(paint)
        return obj


def canopy(m, center, radius, palette):
    # Overlapping, scalloped banks of growth. Cool undersides and sunlit crests
    # are painted independently so the silhouette survives distant mesh LODs.
    first_face = len(m.faces)
    n = 13
    phase = m.rng.random()*tau
    contour = [m.rng.uniform(.80, 1.18) for _ in range(n)]
    cx,cy,cz = center
    rx,ry,rz = radius
    rows = []
    for level,(w,z) in enumerate(((.30,-.68),(.87,-.47),(1,.07),(.72,.60),(.25,.91))):
        ring = []
        for i in range(n):
            a = i*tau/n+phase+.11*level
            r = w*contour[i]*m.rng.uniform(.94,1.06)
            ring.append((cx+rx*r*cos(a),cy+ry*r*sin(a),cz+rz*(z+m.rng.uniform(-.15,.15))))
        rows.append(ring)
    m.face(rows[0][::-1], palette[0])
    for k,(lower,upper) in enumerate(zip(rows,rows[1:])):
        for i in range(n):
            j=(i+1)%n
            m.face([lower[i],lower[j],upper[j]],palette[k],m.rng.uniform(.93,1.03))
            m.face([lower[i],upper[j],upper[i]],palette[k],m.rng.uniform(.96,1.06))
    m.face(rows[-1],palette[-1])
    m.smooth_faces.update(range(first_face,len(m.faces)))
    # Broad brush-like leaf sprays stand proud of the crown rather than
    # subdividing every leaf. Open gaps and curled tips catch grazing light.
    for j in range(15):
        a=j*2.4+phase
        side=V((-sin(a)*rx,cos(a)*ry,0))
        out=V((cos(a)*rx,sin(a)*ry,0))
        lift=m.rng.uniform(.05,.68)
        base=V(center)+out*(.77-.18*lift)+V((0,0,rz*lift))
        for t in (-1,0,1):
            end=base+out*(.40 if t==0 else .29)+side*.19*t+V((0,0,-.05*rz))
            mid=base.lerp(end,.48)+V((0,0,.14*rz))
            left=mid+side*.075; right=mid-side*.075
            m.face([base,right,end,mid],palette[3 if j%3 else 2],1.02)
            m.face([base,mid,end,left],palette[2],.98)


def spreading_tree(name, seed, cedar=False):
    m = Model(name,seed)
    wood = "746048" if cedar else "886c50"
    m.branch([(0,0,-.045),(-.013,.005,.16),(.026,0,.36),(.016,.009,.53),(.053,0,.73)],
             [.065,.049,.038,.027,.013],wood,9)
    for i in range(6):
        a = tau*i/6+.4
        m.branch([(.002,0,.13),(.056*cos(a),.056*sin(a),.035),
                  (.112*cos(a),.112*sin(a),-.006)],[.021,.023,.006],wood,5)
    tones = (["314f49","406956","547e61","769266"] if cedar else
             ["385b52","477761","648d68","89a56d"])
    count = 9 if cedar else 7
    for i in range(count):
        t = i/(count-1)
        a = i*2.40+seed*.72
        reach = (.23-.13*t) * m.rng.uniform(.9,1.22)
        base = V((.018,0,.33+.36*t))
        tip = V((cos(a)*reach+.035, sin(a)*reach,.54+.36*t))
        bend = base.lerp(tip,.55) - V((0,0,.047))
        m.branch([base,bend,tip],[.024-.009*t,.015,.005],wood,6)
        size = (.17-.034*t)*(1.16 if cedar else 1)
        canopy(m,tip,(size,size*.80,.095 if cedar else .12),tones)
        # Younger growth breaks the outer edge of each large crown.
        drift = V((cos(a+.72)*size*.66,sin(a+.72)*size*.66,.016))
        canopy(m,tip+drift,(size*.59,size*.51,.065),tones)
    return m.finish()


def fir(name, seed, snow=False):
    m = Model(name,seed)
    m.branch([(0,0,-.03),(0,0,.18),(.012,.005,.64),(.014,-.005,.99)],
             [.046,.034,.016,.003],"765f4d",8)
    # Folded, tapered needle sprays form distinct fingers with gaps between whorls.
    for level in range(8):
        f=level/8
        z=.31+level*.081
        length=(.244*(1-f)**.83+.018)
        for j in range(8 if level<5 else 6):
            a=j*tau/(8 if level<5 else 6)+level*1.68+m.rng.uniform(-.13,.13)
            d=V((cos(a),sin(a),0)); s=V((-sin(a),cos(a),0))
            l=length*m.rng.uniform(.83,1.13)
            start=V((.01,0,z))
            tip=start+d*l+V((0,0,-.047+.020*f))
            for twist in (-1,0,1):
                root=start+d*l*.20
                end=tip - d*(abs(twist)*l*.17)+s*(twist*l*.35)
                mid=root.lerp(end,.57)+V((0,0,.007))
                width=l*(.22 if twist==0 else .16)
                left,right=mid+s*width,mid-s*width
                crest=mid+V((0,0,.038*(1-f)+.012))
                tones = ["4b705a","648163","75926b"] if not snow else ["79968e","cad9cc","dce6db"]
                m.face([root,right,crest],tones[1])
                m.face([right,end,crest],tones[0])
                m.face([end,left,crest],tones[2])
                m.face([left,root,crest],tones[1])
                m.face([root,left,end,right],"345c50" if not snow else "56766c")
    return m.finish()


def rock(name, seed, colors):
    m=Model(name,seed)
    n=9
    lengths=[m.rng.uniform(.78,1.16) for _ in range(n)]
    rows=[]
    for k,(w,z) in enumerate(((.82,-.14),(1,.20),(.96,.31),(.77,.70),(.80,.74),(.53,.94))):
        row=[]
        for j in range(n):
            a=tau*j/n+.18
            r=w*lengths[j]*m.rng.uniform(.96,1.04)
            row.append((r*cos(a)-.09*z,r*sin(a)+.12*z,z+.09*cos(a+.4)+.035*sin(3*a)))
        rows.append(row)
    for k,(lo,hi) in enumerate(zip(rows,rows[1:])):
        for i in range(n):
            j=(i+1)%n
            m.face([lo[i],lo[j],hi[j],hi[i]],colors[k],m.rng.uniform(.87,1.06))
    m.face(rows[-1],colors[-1])
    return m.finish()


def prickly_pear():
    m=Model("DunePear",51)
    def pad(x,y,z,w,h,a):
        u=V((cos(a),sin(a),0)); v=V((-sin(a),cos(a),0)); up=V((0,0,1))
        center=V((x,y,z))
        rings=[]
        for k in range(1,8):
            t=pi*k/8
            rings.append([center+up*(-cos(t)*h)+(u*(w*cos(j*tau/12))+v*(w*.29*sin(j*tau/12)))*sin(t)
                          for j in range(12)])
        m.rings(rings,"79a17d",.045)
        for sign in (-1,1):
            for dz,dx in [(-.34,-.30),(-.34,.30),(.20,0),(.53,.34)]:
                p=center+up*dz*h+u*w*dx+v*sign*w*.28
                m.face([p-u*.022,p+u*.022,p+up*.046],"d9c782")
    for x,y,z,w,h,a in [(0,0,.51,.33,.65,.1),(.29,.06,1.11,.28,.47,.28),
                          (-.32,.06,.93,.25,.40,-.7),(.55,.12,1.46,.18,.28,-.8),
                          (-.46,.08,1.31,.18,.26,.25),(0,.2,1.34,.20,.37,1.12)]:
        pad(x,y,z,w,h,a)
        if z>1.29:
            m.lathe(x,y,[(z+h-.05,.035),(z+h+.015,.075),(z+h+.06,.04)],"ba6051",8)
    return m.finish()


def cooperage():
    m=Model("OilCask",102)
    n=16
    for i in range(n):
        angles=[tau*(i+.020)/n,tau*(i+.98)/n]
        rows=[[(r*cos(a),r*sin(a),z) for a in angles] for z,r in
              [(0,.425),(.12,.469),(.47,.52),(.77,.52),(1.10,.47),(1.23,.425)]]
        dye=m.rng.choice(["926b49","ab8052","987350","a9794b"])
        for lower,upper in zip(rows,rows[1:]):
            m.face([lower[0],lower[1],upper[1],upper[0]],dye)
    for z,r in ((.14,.479),(.40,.52),(.85,.521),(1.10,.48)):
        m.lathe(0,0,[(z-.03,r),(z-.022,r+.006),(z+.032,r+.006),(z+.039,r)],"586563",n)
    m.lathe(0,0,[(1.18,.422),(1.215,.422)],"ab855c",n)
    for x in (-.24,-.082,.082,.24):
        m.box((x,0,1.216),(.009,2*(.414**2-x*x)**.5,.004),"735d48")
    m.lathe(.145,-.16,[(1.215,.059),(1.232,.055)],"806344",10)
    return m.finish()


def rose(m, center, size, color):
    x,y,z=center
    for j in range(8):
        a=tau*j/8
        r=size if j%2==0 else size*.61
        tip=(x+r*cos(a),y,z+r*sin(a))
        shoulder=(x+.21*size*cos(a+.69),y+.012,z+.21*size*sin(a+.69))
        other=(x+.21*size*cos(a-.69),y+.012,z+.21*size*sin(a-.69))
        m.face([tip,shoulder,center],color)
        m.face([tip,center,other],color,.72)


def hut(name, seed, region, wall, tile, accent):
    m=Model(name,seed)
    w,d=2.48,1.80
    beam="6c5342"; trim="ad8b60"; shadow="474f4e"
    eave=2.65
    rise={"snow":2.08,"forest":1.28,"lake":1.45}[region]
    m.box((0,0,.14),(w*2+.14,d*2+.14,.42),"88847a")
    m.box((0,0,1.44),(w*2,d*2,2.47),wall)
    # Both gables have actual infill; projecting rafters cast thin edge shadows.
    for sign in (-1,1):
        y=sign*d
        tri=[(-w,y,eave),(w,y,eave),(0,y,eave+rise*.87)]
        m.face(tri if sign==-1 else tri[::-1],wall)
        m.box((0,y,2.57),(w*2+.14,.17,.16),beam)
        for x in (-w+.03,-.67,.67,w-.03):
            m.box((x,y,1.43),(.14,.15,2.53),beam)
        m.beam((-w,y,2.62),(0,y,eave+rise*.89),.085,beam,4)
        m.beam((w,y,2.62),(0,y,eave+rise*.89),.085,beam,4)
        m.box((0,y,eave+rise*.36),(.12,.15,rise*.72),beam)
    for sign in (-1,1):
        for i in range(7):
            m.box((sign*w,(i-3)*.51,1.38),(.12,.043,2.42),trim)
    roofw=w+.48
    def height(x):
        return eave+rise-abs(x)/roofw*rise
    for sig in (-1,1):
        def pt(x,y,dz=0):
            return (sig*x,y,height(x)+dz)
        deck=[pt(0,-2.20),pt(roofw,-2.20),pt(roofw,2.20),pt(0,2.20)]
        m.face(deck if sig==1 else deck[::-1],beam)
        m.box((sig*(w-.02),0,2.52),(.16,4.49,.15),beam)
        for course in range(7):
            top=course*roofw/7; toe=(course+1)*roofw/7
            for k in range(-1,9):
                lo=max(-2.20,-2.20+(k+(course%2)*.5)*.55)
                hi=min(2.20,-2.20+(k+1+(course%2)*.5)*.55)
                if hi-lo<.06: continue
                edge=toe+m.rng.uniform(.002,.027)
                a,b,c,f=pt(top,lo,.021),pt(edge,lo,.067),pt(edge,hi-.007,.067),pt(top,hi-.007,.021)
                panel=[a,b,c,f]
                m.face(panel if sig==1 else panel[::-1],tile,m.rng.uniform(.87,1.10))
                lip=[b,pt(edge,lo,.005),pt(edge,hi-.007,.005),c]
                m.face(lip if sig==1 else lip[::-1],tile,.73)
        for y in (-2.21,2.21):
            m.beam(pt(0,y),pt(roofw,y),.089,trim,5)
    m.beam((0,-2.30,eave+rise+.047),(0,2.30,eave+rise+.047),.11,accent,10)
    # Recessed doorway, paneled shutters and inset honey-coloured panes.
    m.box((0,-1.84,1.10),(1.12,.16,2.12),shadow)
    for i in range(6):
        m.box(((i-2.5)*.158,-1.952,1.09),(.151,.08,1.96),accent)
    for z in (.34,1.77):
        m.box((0,-2.01,z),(.99,.06,.068),trim)
    m.box((.30,-2.04,.99),(.11,.09,.09),"d9b778")
    for sign in (-1,1):
        x=sign*1.53
        m.box((x,-1.86,1.60),(1.09,.15,.97),shadow)
        for i in (-1,1):
            for j in (-1,1):
                m.box((x+.222*i,-1.96,1.60+j*.188),(.390,.05,.32),"e3bd75")
        m.box((x,-1.94,1.07),(1.24,.37,.105),trim)
        for k in range(3):
            m.box((x+.61*sign,-1.88,1.28+k*.28),(.19,.10,.245),accent)
    m.box((0,-1.96,2.34),(1.16,.12,.27),trim)
    rose(m,(0,-2.038,2.34),.13,"f0dbab")
    # Fieldstone chimney with an overhanging cap and a shadowed flue.
    x,y=1.57,.83
    for j in range(7):
        z=height(x)-.38+j*.185
        m.box((x,y,z),(.60,.66,.177),"867f71" if j%2 else "9c8b76")
    z+=.145
    m.box((x,y,z),(.75,.79,.14),trim)
    m.box((x,y,z+.075),(.41,.43,.018),shadow)
    if region=="forest":
        # Bracket fungi and moss sit on the damp leeward eave.
        for i in range(12):
            x=-m.rng.uniform(1.3,2.82); y=m.rng.uniform(-1.9,1.9)
            canopy(m,(x,y,height(x)+.04),(.19,.24,.08),["61704c","718158","83905d","9aa46c"])
        # A lean-to protects split wood on the forest side.
        for y in (-1.23,1.20):
            m.beam((3.52,y,-.12),(3.52,y,1.60),.09,beam)
        for j in range(8):
            y=-1.46+j*.40
            m.face([(2.36,y,2.17),(3.69,y,1.59),(3.69,y+.39,1.59),(2.36,y+.39,2.17)],tile)
        for j in range(14):
            x=2.74+(j%3)*.28; z=.18+(j//3)*.24; y=-.98+(j%2)*.08
            m.beam((x,y,z),(x,y+1.98,z),.145,beam,9)
            m.beam((x,y-.015,z),(x,y-.019,z),.125,"c4a17c",9)
    if region=="snow":
        for j in range(17):
            y=m.rng.uniform(-2.04,2.04)
            m.branch([(roofw,y,eave+.05),(roofw+.015,y,eave-m.rng.uniform(.10,.40))],[.045,.003],"bcd5d2",5)
    if region=="lake":
        for j in range(4):
            m.lathe(-2.8,-.57+j*.39,[(-.12,.105),(.48,.12),(.55,.09)],"7f6b53",8)
        # The beacon cupola is visible over the roof from the far bank.
        base=eave+rise-.26
        m.lathe(0,.4,[(base,.56),(base+.20,.56),(base+.24,.44),(base+.80,.42)],
                "aebf9c",8)
        for j in range(8):
            a=tau*j/8
            m.beam((.43*cos(a),.4+.43*sin(a),base+.20),(.43*cos(a),.4+.43*sin(a),base+.81),.040,beam)
        m.lathe(0,.40,[(base+.78,.64),(base+.87,.68),(base+1.26,.17),(base+1.39,.067)],
                "66867d",8)
        for j in range(3):
            x=2.42+j*.54
            m.box((x,-.05,.18),(.49,3.61,.12),"957752")
        for y in (-1.38,1.40):
            m.beam((3.58,y,-.18),(3.58,y,.94),.094,beam)
        m.branch([(3.58,-1.38,.86),(3.58,0,.68),(3.58,1.40,.86)],[.027]*3,trim)
    return m.finish()


def tent(name, seed, desert):
    m=Model(name,seed)
    hues=["ad6852","d8b98d","c48160"] if desert else ["538882","cec7a5","68978c"]
    pole="856549"
    for x in (-2.62,2.62):
        for y in (-1.70,1.70):
            m.beam((x,y,-.07),(x,y,3.03),.088,pole)
            m.beam((x,y,2.94),(x*1.24,y*1.30,.12),.018,"b39568",5)
            m.beam((x*1.24,y*1.30,-.04),(x*1.24,y*1.30,.29),.056,pole)
    for y in (-1.81,1.81):
        m.beam((0,y,-.03),(0,y,4.23 if desert else 3.86),.083,pole)
    def h(x,y):
        return 2.85+(1.31 if desert else .94)*(1-abs(x)/2.91)**1.55-.22*(1-(y/2.05)**2)
    for j in range(12):
        x0=-2.91+j*.485; x1=x0+.485
        col=hues[[0,0,2,1,1,2][j%6]]
        for k in range(6):
            y0=-2.05+k*4.10/6; y1=y0+4.10/6
            m.face([(x0,y0,h(x0,y0)),(x1,y0,h(x1,y0)),(x1,y1,h(x1,y1)),(x0,y1,h(x0,y1))],col)
        for s in (-1,1):
            y=2.05*s; mid=(x0+x1)*.5
            edge=[(x0,y,h(x0,y)),(mid,y,h(mid,y)-.29),(x1,y,h(x1,y))]
            m.face(edge if s==-1 else edge[::-1],col,.92)
            m.branch([(mid,y,h(mid,y)-.27),(mid+.009,y,h(mid,y)-.40)],[.025,.013],"d1ae74",5)
    m.box((-1.65,.45,.69),(1.6,.91,.12),pole)
    for x in (-2.21,-1.13):
        for y in (.12,.78):
            m.beam((x,y,0),(x,y,.65),.064,pole)
    for j in range(5):
        x=-1.42+.56*(j%3); y=-.57+.63*(j//3)
        r=.22+.05*(j%2)
        if desert:
            m.lathe(x,y,[(0,r*.65),(.10,r),(.35,r*1.13),(.57,r*.72),(.64,r*.61),(.67,r*.77)],
                    ["ba805c","a06a51","c4a076"][j%3],14)
        else:
            # Hoop-framed creels with spaced wicker slats.
            for k in range(12):
                a=tau*k/12
                m.branch([(x+r*cos(a),y+r*sin(a),.03),(x+r*1.18*cos(a),y+r*1.18*sin(a),.31),
                          (x+r*.79*cos(a),y+r*.79*sin(a),.49)],[.017,.018,.016],"ad8d61",5)
            for z,rad in ((.06,r),(.26,r*1.16),(.45,r*.85)):
                m.lathe(x,y,[(z,rad),(z+.036,rad)],"927450",12)
    if desert:
        # A striped windbreak hangs low on the leeward side of the tent.
        for j in range(10):
            x=-2.6+j*.52
            for row,col in enumerate(["bb7556","e0bd92","80564b","d2a06d","ad6b51"]):
                h=.92+row*.36
                y=1.68-.19*sin(pi*j/10)
                m.face([(x,y,h),(x+.52,y-.019,h+.018),(x+.52,y+.014,h+.37),(x,y+.020,h+.36)],col)
        for j in range(3):
            x=1.13+j*.25
            m.beam((x,-.7,.18),(x,.49,.18),.142,["9e5f4d","719591","b59669"][j],14)
    else:
        # A slung landing net and cork floats identify the tidal shelter from the trail.
        def web(t,u):
            return (-2.56, -1.53+3.06*t, 2.40-.40*sin(t*pi)-u*.99)
        for j in range(11):
            t=j/10
            m.beam(web(t,0),web(t,1),.014,"b19c77",4)
            if j%2==0:
                x,y,z=web(t,0)
                m.lathe(x,y,[(z-.07,.040),(z-.028,.07),(z+.060,.062)],"bb885d",8)
        for j in range(6):
            for k in range(10):
                m.beam(web(k/10,j/5),web((k+1)/10,j/5),.013,"a39374",4)
    return m.finish()


def furnace(name, station):
    m=Model(name,82)
    r=1.65 if station else 1.38
    m.lathe(0,0,[(-.30,r),(.24,r*1.14),(.39,r*1.14),(.50,r),(1.62,r),(2.49,r*.86),
                 (2.81,r*.66),(3.07,r*.56)],"70695e",20)
    # Individually laid refractory bricks carry up into a banded copper flue.
    for k in range(9):
        z=.43+k*.242
        radius=r*(1-.29*max(0,z-1.60))
        for j in range(20):
            a=tau*(j+.5*(k%2))/20; b=a+tau*.963/20
            if z<1.53 and abs(cos((a+b)/2))<.39 and sin(a)<0: continue
            radial=lambda t,rr,zz: (rr*cos(t),rr*sin(t),zz)
            m.face([radial(a,radius+.022,z),radial(b,radius+.022,z),
                    radial(b,radius+.006,z+.224),radial(a,radius+.006,z+.224)],
                   m.rng.choice(["817467","8b7767","998371","7d736b"]))
    m.lathe(0,0,[(2.81,r*.70),(2.98,r*.73),(3.03,r*.55),(3.37,r*.46),
                 (3.45,r*.53),(3.55,r*.52)],"596e69",20,cap="414747")
    m.box((0,-r+.03,.87),(1.24,.30,1.44),"3c4140")
    for j in range(11):
        a=pi*j/10
        x=.65*cos(a); z=1.27+.51*sin(a)
        m.beam((x,-r-.16,z),(x,-r+.02,z),.143,"b19173",6)
    m.box((0,-r-.137,.79),(.99,.07,.83),"b2613c")
    for j in range(7):
        x=(j-3)*.138
        m.beam((x,-r-.20,.37),(x,-r-.20,1.29),.031,"4b5050")
    if not station:
        for x in (-2.22,2.22):
            for y in (-1.54,1.54):
                m.beam((x,y,-.08),(x,y,3.21),.13,"656461",8)
            m.beam((x,-1.76,3.20),(x,1.76,3.20),.15,"7e705b")
        for j in range(9):
            x=-2.5+j*.58
            m.box((x,.23,3.37+.10*sin(j*.45)),(.61,4.10,.14),"88786b")
        m.lathe(0,0,[(3.50,.60),(4.18,.53),(4.23,.63),(4.39,.60)],"566b68",16,cap="363f41")
    return m.finish()


def pump():
    m=Model("PumpWorks",38)
    m.box((0,0,.26),(2.26,1.76,.58),"89877a")
    m.box((0,0,.62),(2.12,1.57,.17),"626e6b")
    m.lathe(-.29,0,[(.7,.65),(.86,.66),(.96,.52),(1.59,.54),(1.72,.61),(1.84,.48)],
            "568d84",20)
    for j in range(12):
        a=tau*j/12
        m.lathe(-.29+.54*cos(a),.54*sin(a),[(1.714,.046),(1.772,.042)],"b49c72",6)
    m.branch([(-.29,0,1.8),(-.29,0,2.17),(-.29,.15,2.37),(-.29,.43,2.40),
              (-.29,1.59,2.40),(-.29,1.82,2.20),(-.29,1.82,1.52)],[.18]*7,"627d79",14)
    m.beam((-.29,.81,2.40),(-.29,.90,2.40),.245,"b59a6e",16)
    m.beam((-.29,-.41,1.27),(-.29,-.80,1.27),.095,"ad9471")
    for j in range(16):
        a=tau*j/16; b=tau*(j+1)/16
        def rim(t):
            return (-.29+.38*cos(t),-.84,1.27+.38*sin(t))
        m.beam(rim(a),rim(b),.046,"a95443")
        if j%4==0: m.beam((-.29,-.84,1.27),rim(a),.032,"995544")
    return m.finish()


def hoop(m, center, rx, rz, radius, color, count=36):
    x,y,z=center
    for i in range(count):
        a=i*tau/count; b=(i+1)*tau/count
        m.beam((x+rx*cos(a),y,z+rz*sin(a)),(x+rx*cos(b),y,z+rz*sin(b)),radius,color)


def heliostat():
    m=Model("Heliostat",131)
    brass="b5975e"; dark="4a6766"
    m.lathe(0,0,[(-.04,1.14),(.12,1.15),(.18,1.03),(.31,1.01),(.39,.84)],"8a8578",22)
    m.lathe(0,0,[(.38,.72),(.52,.71),(.62,.46),(.76,.43),(.82,.52)],dark,20)
    for s in (-1,1):
        m.branch([(s*.28,0,.73),(s*.84,0,.98),(s*1.06,0,1.57),(s*1.06,0,2.01)],
                 [.14,.109,.087,.084],brass)
    m.beam((-1.20,0,2.05),(1.20,0,2.05),.105,dark,16)
    m.beam((1.16,0,2.05),(1.27,0,2.05),.16,brass,16)
    m.beam((1.23,0,2.05),(1.25,-.27,1.83),.046,brass)
    m.beam((1.21,-.28,1.82),(1.49,-.28,1.82),.060,"865e46")
    # Curved facets share a focus; a dark rear plate and twin inlaid beads define the rim.
    for i in range(32):
        a=tau*i/32; b=tau*(i+1)/32
        def point(t,r):
            return (r*cos(t),-.135+r*r*.15,2.06+r*sin(t)*.90)
        for size in (.52,1.0):
            inset=0 if size<1 else .52
            corners=[point(a,inset),point(a,size),point(b,size),point(b,inset)]
            m.face(corners[:3] if inset==0 else corners,
                   ["9cbfc2","a4c8c9","96bfc4","a9cbca"][(i//3)%4])
    hoop(m,(0,.015,2.06),1.04,.936,.073,brass)
    hoop(m,(0,-.03,2.06),.976,.885,.027,"dbc79a")
    for i in range(16):
        a=tau*i/16
        m.beam((.98*cos(a),.12,2.06+.88*sin(a)),(0,.18,2.06),.028,dark)
    m.beam((0,.13,2.06),(0,.23,2.06),.23,brass,18)
    return m.finish()


def optical_burner():
    m=Model("BeaconBurner",231)
    m.lathe(0,0,[(-.04,1.61),(.16,1.67),(.23,1.62),(.32,1.47),(.43,1.41),
                 (.47,1.32)],"8f8673",24)
    m.lathe(0,0,[(.46,1.15),(.58,1.21),(.67,.97),(1.47,.91),(1.53,1.02),
                 (1.62,.97),(1.82,.74)],"4e7470",24)
    for i in range(16):
        a=tau*i/16
        m.branch([(.97*cos(a),.97*sin(a),.64),(.94*cos(a),.94*sin(a),1.48)],
                 [.036,.033],"a49575",6)
    m.lathe(0,0,[(1.68,.63),(1.80,.70),(1.89,1.04),(1.97,1.06),(2.09,.77),
                 (2.15,.51),(2.26,.53)],"bc975e",28)
    for i in range(6):
        a=tau*i/6
        m.branch([(.66*cos(a),.66*sin(a),2.09),(.80*cos(a),.80*sin(a),2.36),
                  (.78*cos(a),.78*sin(a),2.99),(.60*cos(a),.60*sin(a),3.27)],
                 [.049,.045,.039,.035],"a88e62")
    # Crown bands are hollow: the game's luminous wick remains visible from every side.
    for z,r in [(2.26,.76),(3.01,.80),(3.27,.61)]:
        for i in range(32):
            a=tau*i/32; b=tau*(i+1)/32
            m.beam((r*cos(a),r*sin(a),z),(r*cos(b),r*sin(b),z),.037,"b99a68",6)
    return m.finish()


def tower_window():
    m=Model("LanternWindow",55)
    copper="697f78"; glass="86aaa9"; stone="a49b83"
    m.box((0,0,.91),(2.05,.17,1.82),copper)
    m.box((0,-.105,.94),(1.81,.07,1.65),glass)
    for i in range(16):
        a=pi*i/16; b=pi*(i+1)/16
        def arch(t,r,y):
            return (r*cos(t),y,1.82+r*sin(t))
        m.face([(0,-.18,1.82),arch(a,.92,-.18),arch(b,.92,-.18)],glass)
        m.face([arch(a,.93,-.20),arch(a,1.19,-.20),arch(b,1.19,-.20),arch(b,.93,-.20)],
               stone,m.rng.uniform(.89,1.08))
        if i%4==0:
            m.beam((0,-.20,1.82),arch(a,.95,-.20),.034,copper)
    for s in (-1,1):
        for k in range(7):
            m.box((s*1.052,-.09,.13+k*.262),(.255,.32,.249),stone)
        m.box((s*.43,-.17,.91),(.064,.08,1.82),copper)
    for z in (.68,1.82):
        m.box((0,-.175,z),(1.90,.09,.068),copper)
    m.box((0,-.08,-.04),(2.55,.51,.18),stone)
    return m.finish()


def compass_floor():
    m=Model("CompassInlay",333)
    for radius,width in [(3.6,.040),(3.79,.075),(8.70,.065),(9.08,.035),(13.9,.11)]:
        for j in range(96):
            a=tau*j/96; b=tau*(j+1)/96
            def pt(t,r): return (r*cos(t),r*sin(t),.019)
            m.face([pt(a,radius),pt(a,radius+width),pt(b,radius+width),pt(b,radius)],"b49b6c")
    for i in range(16):
        a=tau*i/16
        r=8.30 if i%4==0 else (5.78 if i%2==0 else 3.21)
        tip=(r*cos(a),r*sin(a),.022)
        for sign in (-1,1):
            t=a+sign*.33
            corners=[(0,0,.022),tip,(1.98*cos(t),1.98*sin(t),.022)]
            m.face(corners if sign==1 else corners[::-1],"b09d73" if sign==1 else "698a83")
    return m.finish()


def field_mechanism(winch):
    m=Model("WreckWinch" if winch else "BypassBody",311)
    m.box((0,0,.081),(1.18,.86,.19),"787b71")
    if winch:
        for x in (-.43,.43):
            m.beam((x,-.29,.16),(x,0,.91),.11,"8a6749",6)
            m.beam((x,.31,.16),(x,0,.91),.11,"987654",6)
        m.beam((-.54,0,.87),(.54,0,.87),.087,"656d69",12)
        for x in (-.38,.38):
            m.beam((x-.04,0,.87),(x+.04,0,.87),.35,"576968",18)
        for i in range(14):
            x=-.32+i*.048
            m.beam((x,0,.87),(x+.047,0,.87),.243+(.007 if i%2 else 0),"af976f",14)
    else:
        m.lathe(0,0,[(.16,.44),(.25,.44),(.30,.36),(.72,.32),(.77,.41),
                      (.86,.40),(.92,.26),(1.17,.22)],"698b81",16)
        for i in range(8):
            a=tau*i/8
            m.lathe(.35*cos(a),.35*sin(a),[(.854,.043),(.91,.041)],"b39a6d",6)
        m.branch([(-.17,0,.50),(-.47,0,.51),(-.65,0,.36),(-.65,0,-.08)],
                 [.145]*4,"807e6c",12)
    m.beam((0,.04,.98),(0,-.33,.98),.10,"aa9062",12)
    return m.finish()


def wheel(winch):
    m=Model("WinchWheel" if winch else "BypassWheel",316)
    r=.42
    hoop(m,(0,0,0),r,r,.043,"94714e" if winch else "ab604d",24)
    for j in range(6):
        a=tau*j/6
        m.beam((0,0,0),(r*cos(a),0,r*sin(a)),.035,"b19664" if winch else "9d6752")
        if winch:
            m.beam((r*cos(a),0,r*sin(a)),((r+.105)*cos(a),0,(r+.105)*sin(a)),.049,"996e4c")
    m.beam((0,.052,0),(0,-.064,0),.091,"c8a46a",10)
    m.beam((r,0,0),(r,-.17,0),.045,"d3b371",10)
    return m.finish()


def firepit():
    m=Model("CampHearth",381)
    for i in range(11):
        a=i*tau/11
        x=.58*cos(a); y=.58*sin(a)
        m.lathe(x,y,[(-.08,.18),(.08,.20),(.18+m.rng.uniform(0,.06),.146)],"807d6d",7)
    for j in range(5):
        a=j*.92
        p=(.53*cos(a),.53*sin(a),.11)
        q=(-.53*cos(a),-.53*sin(a),.23)
        m.beam(p,q,.093,"72553d",8)
        m.beam(p,(p[0]*1.019,p[1]*1.019,p[2]),.083,"b18a5e",8)
    for i in range(8):
        x=m.rng.uniform(-.29,.29); y=m.rng.uniform(-.29,.29)
        m.lathe(x,y,[(.23,.07),(.27,.09),(.34,.029)],"da8951",7)
    m.finish()
    f=Model("HearthFlame",383)
    for j in range(6):
        a=j*2.4
        x=.16*cos(a); y=.16*sin(a)
        h=.71 if j==0 else .33+.25*(j%2)
        f.branch([(x,y,0),(x*.74,y*.76,.13),(x+.050,y,h*.58),(x-.068,y+.039,h)],
                 [.053,.112,.074,.008],"f4bd65" if j%2 else "e8944b",7)
    f.finish()


def pilot_light():
    m=Model("PilotLantern",318)
    m.lathe(0,0,[(-.12,.31),(.26,.33),(.35,.22),(.48,.18),(2.18,.13),(2.28,.20)],"896e50",8)
    for z in (.43,.65,1.90,2.12):
        m.lathe(0,0,[(z,.19),(z+.061,.19)],"536866",8)
    m.lathe(0,0,[(2.25,.19),(2.34,.39),(2.42,.38),(2.49,.28)],"658178",8)
    for j in range(8):
        a=j*tau/8
        m.beam((.275*cos(a),.275*sin(a),2.42),(.292*cos(a),.292*sin(a),2.99),.018,"8b795b")
    m.lathe(0,0,[(2.98,.33),(3.03,.43),(3.09,.40),(3.27,.18),(3.30,.12),(3.43,.055)],"58756c",8)
    m.finish()


def coastal_plants(name, seed):
    m=Model(name,seed)
    succulent=name=="SeaKale"
    sand=name=="Marram"
    tones=(["5c8278","76a28e","9ab79a"] if succulent else
           ["7b865c","a5a064","c8ba80"] if sand else ["5e805d","83a477","a5bb86"])
    for i in range(15 if not succulent else 12):
        a=i*2.4+m.rng.uniform(-.15,.15)
        u=V((cos(a),sin(a),0)); side=V((-u.y,u.x,0))
        foot=u*m.rng.uniform(.025,.17)
        h=m.rng.uniform(.35,.67)*(1.18 if sand else .60 if succulent else 1)
        reach=m.rng.uniform(.14,.34)
        width=m.rng.uniform(.085,.15) if succulent else m.rng.uniform(.024,.045)
        rings=[]
        for j,(spread,lift,thick) in enumerate([(0,0,.32),(.17,.51,.84),(.50,.87,1),(.79,1,.61),(1,.88,.025)]):
            v=foot+u*reach*spread+V((0,0,lift*h))
            s=side*width*thick
            rings.append([v-s,v+V((0,0,width*.28))+u*.015,v+s])
        for j,(low,high) in enumerate(zip(rings,rings[1:])):
            m.face([low[0],high[0],high[1],low[1]],tones[0 if j<2 else 1])
            m.face([low[1],high[1],high[2],low[2]],tones[1 if j<3 else 2])
    if sand or name=="SeaThrift":
        for j in range(4):
            a=tau*j/4+.38
            h=.63+.17*sin(a)
            base=V((.11*cos(a),.11*sin(a),0))
            tip=base+V((.11*cos(a),.11*sin(a),h))
            m.branch([base,base.lerp(tip,.6),tip],[.012,.009,.007],"85916b",4)
            if sand:
                for k in range(6):
                    s=-1 if k%2 else 1
                    p=tip+V((0,0,k*.027))
                    m.branch([p,p+V((s*.027,0,.040)),p+V((s*.035,0,.074))],[.010,.019,.002],"c9ae75",4)
            else:
                for k in range(7):
                    t=k*2.4; r=.040 if k else 0
                    x,y,z=tip+V((r*cos(t),r*sin(t),.021 if k==0 else 0))
                    for petal in range(5):
                        b=tau*petal/5
                        u=V((cos(b),sin(b),0)); v=V((-sin(b),cos(b),0)); c=V((x,y,z))
                        m.face([c,c+u*.024-v*.012,c+u*.037+V((0,0,.009)),c+u*.022+v*.012],
                               "dcb8b2" if j%2 else "ece1c8")
    m.finish()


def gull():
    m=Model("HerringGull",79)
    m.branch([(0,-.34,.015),(0,-.11,.052),(0,.15,.09),(0,.26,.13),(0,.35,.12)],
             [.025,.095,.099,.085,.049],"dddac9",10)
    m.branch([(0,.33,.108),(0,.42,.107),(0,.445,.09)],[.044,.031,.009],"c9a15b",7)
    for s in (-1,1):
        m.beam((s*.066,.29,.153),(s*.070,.29,.153),.015,"404747",8)
        rows=[]
        for x,y,z,chord in [(.024,0,.086,.25),(.28,.05,.17,.24),(.50,.10,.21,.22),(.71,.04,.17,.17),(.98,-.09,.102,.015)]:
            rows.append([(s*x,y+chord*.45,z),(s*x,y,z+.03),(s*x,y-chord*.66,z-.018)])
        for j,(lo,hi) in enumerate(zip(rows,rows[1:])):
            for k in range(2):
                panels=[lo[k],lo[k+1],hi[k+1],hi[k]]
                m.face(panels if s==1 else panels[::-1],"52606a" if j==3 else "a1b1b4")
        for j in range(5):
            x=.43+j*.09; y=.02-j*.022
            m.face([(s*x,y,.183),(s*(x+.07),y,.170),(s*(x+.12),y-.20+j*.011,.115),
                    (s*(x+.068),y-.215+j*.011,.114)],"65737b" if j>1 else "a6b4b6")
    m.face([(-.045,-.15,.06),(-.14,-.41,.025),(0,-.45,.028),(.14,-.41,.025),(.045,-.15,.06)],"c4cccb")
    m.finish()


for name,seed,cedar in [("BayPine",2,False),("CapePine",7,False),("Cedar",13,True)]:
    spreading_tree(name,seed,cedar)
fir("SilverFir",26)
fir("SnowFir",76,True)
prickly_pear()
rock("ShoreStone",4,["9dacac","c3c1a7","aab5a8","d5cead","b8c1a5"])
rock("SnowStone",19,["62767e","97aaa9","82979e","bbc8c8","e0e7de"])
rock("LavaStone",12,["615b63","826e6a","736973","9a7d73","898185"])
rock("DuneStone",9,["9b795b","c39b70","bb916b","ddbd8d","d1b58b"])
cooperage()
hut("SnowCamp",30,"snow","9ca9a3","cedbd8","ae6a52")
hut("LakeCamp",32,"lake","d5c6a5","668688","527f7a")
hut("ForestCamp",34,"forest","b6ac8a","758467","7c6248")
tent("TideCamp",41,False)
tent("DesertCamp",43,True)
furnace("VolcanoCamp",False)
furnace("CoastKiln",True)
pump()
heliostat()
optical_burner()
tower_window()
compass_floor()
field_mechanism(True)
field_mechanism(False)
wheel(True)
wheel(False)
firepit()
pilot_light()
for name,seed in [("SeaBent",46),("Marram",52),("SeaThrift",64),("SeaKale",78)]:
    coastal_plants(name,seed)
gull()
out = ROOT / "game/art/models/landscape.glb"
out.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(out),export_format="GLB",export_yup=True,
                          export_animations=False,export_vertex_color="ACTIVE")

# Stage the editable source as a collection of full-size models. The runtime
# export above keeps every local origin at its intended pivot.
rows = [
    ("Camp shelters", ["SnowCamp","TideCamp","VolcanoCamp","DesertCamp","LakeCamp","ForestCamp"], 8.9,14),
    ("Coastal vegetation", ["BayPine","CapePine","Cedar","SilverFir","SnowFir","DunePear"], 8.9,5),
    ("Lighthouse instruments", ["CoastKiln","PumpWorks","Heliostat","BeaconBurner","LanternWindow","PilotLantern"], 6.3,-3),
    ("Supplies and machinery", ["ShoreStone","SnowStone","LavaStone","OilCask","WreckWinch","WinchWheel","BypassBody","BypassWheel","CampHearth","HearthFlame"], 3.3,-8),
    ("Mirror chamber", ["CompassInlay"], 1,-26),
    ("Coastal meadow and wildlife", ["SeaBent","Marram","SeaThrift","SeaKale","HerringGull"], 2.2,-11)
]
for title,names,spacing,y in rows:
    group=bpy.data.collections.new(title)
    bpy.context.scene.collection.children.link(group)
    for i,name in enumerate(names):
        obj=bpy.data.objects[name]
        obj.location=(spacing*(i-(len(names)-1)*.5),y,0)
        if title=="Coastal vegetation" and name!="DunePear":
            obj.scale=(7,7,7)
        for old in list(obj.users_collection):
            old.objects.unlink(obj)
        group.objects.link(obj)
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=="VIEW_3D":
            space=area.spaces.active
            space.overlay.show_overlays=False
            space.shading.color_type='VERTEX'
            space.region_3d.view_rotation=V((-.32,-1,.63)).to_track_quat('Z','Y')
            space.region_3d.view_distance=61
            space.region_3d.view_location=(0,2,1.2)
native=ROOT/"art_source"/"Coastal_Landscape.blend"
native.parent.mkdir(parents=True,exist_ok=True)
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(native),compress=True)
