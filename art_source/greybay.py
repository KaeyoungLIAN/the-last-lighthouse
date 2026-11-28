"""Build the Greybay architectural kit with Blender 4.5 in background mode."""
import bpy
import bmesh
from functools import wraps
import json
import struct
import random
from contextlib import contextmanager
from pathlib import Path
from mathutils import Vector, Matrix
from math import cos, sin, pi, sqrt
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "game" / "art" / "greybay"
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
V = Vector
TAU = 2 * pi
oak = "765742"
dark = "494641"
brass = "c5a270"
ivory = "ead9b5"
slate = "516d70"
teal = "598781"
iron = "465555"
slab = "9d9985"
tile_red = "ac6350"
stone_colors = ["9d9f8f", "969b8d", "adab96", "8d978c", "a8a793"]


def grain_material(name, mode):
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    tree = material.node_tree
    shader = tree.nodes.get("Principled BSDF")
    shader.inputs["Roughness"].default_value = .76 if mode != "metal" else .42
    if mode == "metal":
        shader.inputs["Metallic"].default_value = .45
    n = 128
    y, x = np.mgrid[0:n, 0:n] * TAU / n
    rng = np.random.default_rng(7)
    grain = .967 + .012*np.sin(x*3+y+np.cos(y*2)) + .009*np.sin(7*y+np.sin(x)) + rng.uniform(-.014,.014,(n,n))
    if mode == "wood":
        grain -= .055 * (np.cos(11*y + 1.3*np.cos(x + y) + .55*np.sin(3*x))**8)
        grain -= .023 * (np.cos(27*y + np.cos(2*x + y))**8)
    pixels = np.empty((n,n,4), dtype=np.float32)
    pixels[:,:,:3] = np.clip(grain[:,:,None], 0, 1)
    pixels[:,:,3] = 1
    image = bpy.data.images.new(name + "_brush", n, n, alpha=False)
    image.pixels.foreach_set(pixels.ravel())
    image.pack()
    texture = tree.nodes.new("ShaderNodeTexImage")
    texture.image = image
    tree.links.new(texture.outputs["Color"], shader.inputs["Base Color"])
    return material


mats = [grain_material("MAT_LimewashAndSlate", "stone"), grain_material("MAT_OiledTimber", "wood"),
        grain_material("MAT_PatinatedFittings", "metal")]
glass = bpy.data.materials.new("MAT_HoneyGlass")
glass.use_nodes = True
g = glass.node_tree.nodes.get("Principled BSDF")
g.inputs["Emission Color"].default_value = (1, .49, .15, 1)
g.inputs["Emission Strength"].default_value = .19
g.inputs["Roughness"].default_value = .28
mats.append(glass)


class Mesh:
    def __init__(self, seed):
        self.rng = random.Random(seed)
        self.vertices, self.faces, self.colors, self.slots, self.uvs = [], [], [], [], []
        self.groups = []
        self.group = "Structure"
        self.frame = Matrix.Identity(4)

    @contextmanager
    def frame_at(self, position, yaw):
        previous = self.frame
        self.frame = previous @ Matrix.Translation(position) @ Matrix.Rotation(yaw, 4, "Y")
        try:
            yield
        finally:
            self.frame = previous

    def face(self, points, color, slot=0, direction=None):
        points = [V(p) for p in points]
        normal = (points[1]-points[0]).cross(points[2]-points[0])
        if normal.length < .000001:
            return
        if direction is not None and normal.dot(V(direction)) < 0:
            points.reverse()
        uv_axis = max(range(3), key=lambda i: abs(normal[i]))
        axes = [(2,1),(2,0),(0,1)][uv_axis]
        if slot == 1 and uv_axis != 1:
            spans = [max(p[i] for p in points)-min(p[i] for p in points) for i in axes]
            if spans[1] > spans[0]:
                axes = axes[::-1]
        self.uvs.extend([(p[axes[0]]*.83, p[axes[1]]*.85) for p in points])
        idx = len(self.vertices)
        for p in points:
            q = self.frame @ p
            self.vertices.append((q.x,-q.z,q.y))
        self.faces.append(tuple(range(idx, idx+len(points))))
        rgb = tuple(int(color[i:i+2],16)/255 for i in (0,2,4))
        self.colors.extend([(*rgb,1)]*len(points))
        self.slots.append(slot)
        self.groups.append(self.group)

    def solid(self, points, polygons, color, slot=0):
        points = [V(p) for p in points]
        center = sum(points, V((0,0,0))) / len(points)
        for poly in polygons:
            p = [points[i] for i in poly]
            self.face(p, color, slot, sum(p,V((0,0,0)))/len(p)-center)

    def loft(self, rings, color, slot=0):
        rings = [[V(p) for p in ring] for ring in rings]
        n = len(rings[0])
        points = sum(rings,[])
        ends = [list(range(n)),list(range(len(points)-n,len(points)))]
        sides = [[j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i]
                 for j in range(len(rings)-1) for i in range(n)]
        self.solid(points, ends + sides, color, slot)

    def box(self, center, size, color, slot=0, bevel=0):
        x,y,z = center
        a,b,c = (n/2 for n in size)
        bevel = min(bevel,a*.7,b*.7,c*.7)
        if bevel:
            profiles = [(-b,bevel*.45),(-b+bevel,0),(b-bevel,0),(b,bevel*.45)]
        else:
            profiles = [(-b,0),(b,0)]
        rings = []
        for h, edge in profiles:
            u, v = a-edge, c-edge
            k = bevel*.6
            border = [(-u,-v+k),(-u+k,-v),(u-k,-v),(u,-v+k),(u,v-k),(u-k,v),(-u+k,v),(-u,v-k)] if k else [(-u,-v),(u,-v),(u,v),(-u,v)]
            rings.append([(x+i,y+h,z+j) for i,j in border])
        self.loft(rings,color,slot)

    def rod(self, a,b,r,color,slot=1,n=6,end=None):
        a,b = V(a),V(b)
        axis = (b-a).normalized()
        helper = V((0,0,1)) if abs(axis.z)<.8 else V((0,1,0))
        u = axis.cross(helper).normalized()
        v = axis.cross(u)
        self.loft([[p + (u*cos(i*TAU/n)+v*sin(i*TAU/n))*rad for i in range(n)]
                   for p,rad in ((a,r),(b,r if end is None else end))], color,slot)

    def export(self, name):
        data = bpy.data.meshes.new(name)
        data.from_pydata(self.vertices,[],self.faces)
        data.update()
        ob = bpy.data.objects.new(name,data)
        bpy.context.collection.objects.link(ob)
        for mat in mats:
            data.materials.append(mat)
        data.polygons.foreach_set("material_index",self.slots)
        color = data.color_attributes.new(name="Pigment",type="BYTE_COLOR", domain="CORNER")
        for element, rgb in zip(color.data,self.colors):
            element.color_srgb = rgb
        uv = data.uv_layers.new(name="BrushUV")
        uv.data.foreach_set("uv",np.array(self.uvs,dtype=np.float32).ravel())
        bpy.ops.object.select_all(action="DESELECT")
        ob.select_set(True)
        bpy.context.view_layer.objects.active=ob
        bpy.ops.export_scene.gltf(filepath=str(OUT/(name+".glb")),use_selection=True,
                                  export_vertex_color="ACTIVE", export_animations=False,
                                  export_cameras=False, export_lights=False, export_yup=True)
        share_brush_textures(OUT / (name + ".glb"))
        bpy.data.objects.remove(ob,do_unlink=True)
        bpy.data.meshes.remove(data)
        self.make_source(name)


    def make_source(self, name):
        collection=bpy.data.collections.new(name.replace("_"," ").title())
        bpy.context.scene.collection.children.link(collection)
        offsets={"pilot":(-9,0),"potter":(0,0),"loft":(9,0),"cabin":(-9,9),"library":(0,9),
                 "harbor_lugger":(7,8),"wrecked_lugger":(10,8),"rowing_skiff":(13,8),
                 "moor_triangulation":(-9,18),"evaporation_pan":(0,18),"salt_harvest":(6,18),
                 "harbor_davit":(10,18),"fish_market":(-5,-6),"harbor_smithy":(0,-6),"keepers_logbook":(5,-6)}
        origin=bpy.data.objects.new(collection.name,None)
        origin.empty_display_size=.25
        collection.objects.link(origin)
        origin.location=(*offsets[name],0)
        for group in dict.fromkeys(self.groups):
            vertices,faces,colors,uvs,slots=[],[],[],[],[]
            for index,face in enumerate(self.faces):
                if self.groups[index]!=group:
                    continue
                start=len(vertices)
                vertices.extend(self.vertices[i] for i in face)
                faces.append(tuple(range(start,start+len(face))))
                slots.append(self.slots[index])
                colors.extend(self.colors[i] for i in face)
                uvs.extend(self.uvs[i] for i in face)
            data=bpy.data.meshes.new(group)
            data.from_pydata(vertices,[],faces)
            data.update()
            for mat in mats:
                data.materials.append(mat)
            data.polygons.foreach_set("material_index",slots)
            pigment=data.color_attributes.new(name="Pigment",type="BYTE_COLOR",domain="CORNER")
            for el,col in zip(pigment.data,colors):
                el.color_srgb=col
            uv=data.uv_layers.new(name="BrushUV")
            uv.data.foreach_set("uv",np.asarray(uvs,dtype=np.float32).ravel())
            bm=bmesh.new()
            bm.from_mesh(data)
            bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.00001)
            bm.to_mesh(data)
            bm.free()
            piece=bpy.data.objects.new(name.replace("_"," ").title()+" - "+group,data)
            collection.objects.link(piece)
            piece.parent=origin


def source_part(name):
    def decorate(fn):
        @wraps(fn)
        def grouped(m,*args,**kwargs):
            prev=m.group
            m.group=name
            try:
                return fn(m,*args,**kwargs)
            finally:
                m.group=prev
        return grouped
    return decorate


def share_brush_textures(path):
    """Keep a single imported brush per surface, shared by each kit mesh."""
    glb = path.read_bytes()
    size = struct.unpack_from("<I", glb, 12)[0]
    doc = json.loads(glb[20:20+size])
    binary = glb[28+size:]
    image_views = {}
    for image in doc.get("images", []):
        index = image.pop("bufferView")
        view = doc["bufferViews"][index]
        start = view.get("byteOffset",0)
        filename = image["name"] + ".png"
        texture = OUT / filename
        pixels = binary[start:start+view["byteLength"]]
        if not texture.exists() or texture.read_bytes() != pixels:
            texture.write_bytes(pixels)
        image_views[index] = filename
        image["uri"] = filename
        image.pop("mimeType",None)
    new_views = []
    new_bin = bytearray()
    indices = {}
    for i, view in enumerate(doc["bufferViews"]):
        if i in image_views:
            continue
        start = view.get("byteOffset",0)
        indices[i] = len(new_views)
        view["byteOffset"] = len(new_bin)
        new_bin.extend(binary[start:start+view["byteLength"]])
        new_bin.extend(bytes(-len(new_bin)%4))
        new_views.append(view)
    for accessor in doc["accessors"]:
        accessor["bufferView"] = indices[accessor["bufferView"]]
    doc["bufferViews"] = new_views
    doc["buffers"][0]["byteLength"] = len(new_bin)
    header = json.dumps(doc, separators=(",",":")).encode()
    header += b" " * (-len(header)%4)
    path.write_bytes(struct.pack("<4sII",b"glTF",2,28+len(header)+len(new_bin))+
                     struct.pack("<I4s",len(header),b"JSON")+header+
                     struct.pack("<I4s",len(new_bin),b"BIN\0")+new_bin)


@source_part("Roof tiles and verges")
def cushion_roof(m,w,d,eaves,rise,color):
    """Curved roof planes; overlapping staggered slate ends show in silhouette."""
    run = w/2+.37
    end = d/2+.38
    def height(x):
        t = max(0,1-abs(x)/run)
        return eaves + rise*(.78*t+.22*t*t)
    for side in (-1,1):
        parts = 7
        for row in range(parts):
            x0 = side*run*(row/parts)
            x1 = side*run*((row+1)/parts)
            m.face([(x0,height(x0),-end),(x0,height(x0),end),
                    (x1,height(x1),end),(x1,height(x1),-end)],dark,0,(0,1,0))
            count = round(d/.42)
            dz = 2*end/count
            for col in range(-1,count):
                start = max(-end,-end+(col+.5*(row%2))*dz)
                stop = min(end,-end+(col+1+.5*(row%2))*dz)
                if stop-start < .05:
                    continue
                a,b = start+.008,stop-.008
                lip = m.rng.uniform(.028,.053)
                out = x1 + side*lip
                corner = min((b-a)*.17,.065)
                cut = [(x0,a),(x0,b),(out-side*.052,b),(out,b-corner),
                       (out,a+corner),(out-side*.052,a)]
                top = [(x,height(x)+(.048 if abs(x-x0)>.01 else .020),z) for x,z in cut]
                m.loft([[(x,y-.05,z) for x,y,z in top],top],tint(color,m.rng.uniform(-.053,.065)))
        for z in (-end,end):
            for span in range(3):
                a,b = run*span/3,run*(span+1)/3
                m.rod((side*a,height(a)-.075,z),(side*b,height(b)-.075,z),.096,ivory,1,4)
        m.rod((side*run,height(run)-.085,-end),(side*run,height(run)-.085,end),.089,oak,1,6)
    for i in range(12):
        a = -end+2*end*i/12
        b = -end+2*end*(i+1)/12
        m.rod((0,height(0)+.031,a),(0,height(0)+.031,b+.015),.109,tint(color,.08+(i%3)*.017),0,8,.12)
    return height(0)


def tint(hex_color, delta):
    return ''.join(f'{max(0,min(255,round(int(hex_color[i:i+2],16)*(1+delta)))):02x}' for i in (0,2,4))


def arch_outline(half,base,spring,rise,segments=12):
    return [(-half,base),(half,base)]+[(half*cos(i*pi/segments),spring+rise*sin(i*pi/segments)) for i in range(segments+1)]


def panel(m, outline, z, thickness, color, slot=0):
    m.loft([[(x,y,d) for x,y in outline] for d in (z,z+thickness)],color,slot)


@source_part("Windows and shutters")
def arched_window(m, x, y, z, w, h, shutters=False):
    """Recess surround, fanlight, muntins, sill and open louvered shutters."""
    with m.frame_at((x,y,z),0):
        for trim, depth, margin in ((dark,.035,.095),(ivory,.071,.057),("c3ac78",.093,.018),("e8c484",.109,0)):
            outline = arch_outline(w/2+margin,-h*.5-margin,h*.20,h*.30+margin)
            panel(m,outline,depth,.023,trim,3 if not margin else 0)
        for bar in (-.25,.25):
            m.box((w*bar,-h*.155,.15),(.032,h*.69,.026),iron,1)
        m.box((0,h*.185,.15),(w,.05,.035),iron,1)
        m.box((0,-h*.135,.151),(w,.035,.032),oak,1)
        for a in (pi*.25,pi*.5,pi*.75):
            m.rod((0,h*.185,.151),(cos(a)*w/2,h*.2+sin(a)*h*.3,.151),.017,iron,1,4)
        m.box((0,-h*.5-.12,.115),(w+.34,.13,.29),slab,0,.023)
        if shutters:
            for side in (-1,1):
                xx=side*(w*.5+.22)
                m.box((xx,-.04,.047),(.29,h*.87,.069),teal,1,.018)
                for j in range(8):
                    m.box((xx,-h*.38+j*h*.095,.098),(.232,.042,.043),"7e9b88",1)


@source_part("Door and threshold")
def entrance(m,front,h,lib,paint):
    size = 1.58 if lib else 1.05
    foot = .31 if lib else .19
    top = min(2.07,h-.37)
    for w,d,c in [(size+.30,.041,slab),(size+.16,.073,ivory),(size+.055,.113,dark),(size,.14,paint)]:
        panel(m,arch_outline(w/2,foot,top-.28,.37),front+d,.04,c,1)
    with m.frame_at((0,0,front+.185),0):
        for j in range(7):
            x=(j-3)*size/7
            limit = top-.28 + .37*sqrt(max(0,1-(2*x/size)**2))-.06
            m.box((x,(foot+limit)*.5,.018),(size/7-.011,limit-foot,.04),tint(paint,.033*(j%3)),1)
        for y in (.49,1.54):
            m.box((-.29*size,y,.055),(.36*size,.057,.035),iron,2,.013)
        m.rod((size*.32,1.03,.054),(size*.32,1.03,.15),.046,brass,2,8)
        for j in range(3 if lib else 2):
            m.box((0,foot-.07-j*.102,.11+j*.21),(size+.42+j*.16,.19,.42),tint(slab,.04*j),0,.024)


@source_part("Chimney")
def chimney(m, x,z, y):
    m.box((x,y+.50,z),(.6,1.32,.67),"957d6b",0,.021)
    for row in range(6):
        for side in (-1,1):
            for i in range(2):
                m.box((x+(i-.5)*.30,y-.02+row*.215,z+side*.335),(.281,.192,.026),
                      m.rng.choice(["a48670","ab8c74","947f70","ac917a"]),0)
    m.box((x,y+1.13,z),(.79,.14,.84),ivory,0,.025)
    for i in (-1,1):
        m.rod((x+i*.157,y+1.19,z),(x+i*.157,y+1.56,z),.132,tile_red,0,9,.116)
        m.rod((x+i*.157,y+1.50,z),(x+i*.157,y+1.62,z),.146,tint(tile_red,-.1),0,9)
        m.rod((x+i*.157,y+1.621,z),(x+i*.157,y+1.627,z),.084,dark,0,9)


@source_part("Dormer")
def dormer(m,side,run,eaves,rise,z,paint):
    at = (side*run*.72, eaves+rise*.31, z)
    with m.frame_at(at,side*pi/2):
        m.box((0,.24,-.48),(1.22,.85,1.02),ivory,0)
        top = [(-.78,.58,0),(0,1.17,0),(.78,.58,0)]
        m.loft([[(x,y,z) for x,y,_ in top] for z in (-1.24,.17)],paint,0)
        arched_window(m,0,.37,.035,.59,.65)
        for k in (-1,1):
            m.rod((0,1.17,.19),(k*.8,.56,.19),.072,ivory,1,4)
            m.rod((k*.78,.56,.19),(k*.78,.56,-1.24),.069,oak,1,4)


def house(name, kind):
    lib = kind=="library"
    hut = kind=="cabin"
    loft = kind=="loft"
    red = kind=="potter"
    m=Mesh({"library":67,"cabin":88,"loft":32,"potter":27,"pilot":55}[kind])
    w,d,h = (7.13,5.61,3.25) if lib else (5,5,2.65)
    front = d/2
    rise = w*(.37 if lib else (.39 if hut else .49))
    plaster = {"potter":"edceac","loft":"ded4b8","pilot":"ebd9b5","cabin":"bdc3a6","library":"e1d7b9"}[kind]
    roof = {"potter":"b06c54","loft":"637f83","pilot":"af6551","cabin":"687d68","library":"52807e"}[kind]
    m.box((0,h/2-.04,0),(w,h+.08,d),plaster,0,.035)
    m.box((0,.18,0),(w+.16,.72,d+.16),"788478",0,.03)
    m.loft([[(-w/2,h-.02,z),(0,h+rise*.94,z),(w/2,h-.02,z)] for z in (-front,front)],plaster,0)
    for location, orientation, width in [((0,0,front),0,w), ((w/2,0,0),pi/2,d),
                                         ((0,0,-front),pi,w),((-w/2,0,0),-pi/2,d)]:
        with m.frame_at(location,orientation):
            for row in range(3):
                count = round(width/.57)
                step = width/count
                for col in range(-1,count):
                    a = max(-width/2-.08,-width/2+(col+.5*(row%2))*step-.08)
                    b = min(width/2+.08,-width/2+(col+1+.5*(row%2))*step-.08)
                    if b-a>.08:
                        m.box(((a+b)/2,-.04+row*.21,.093),(b-a-.016,.20,.09),
                              m.rng.choice(stone_colors),0,.017)
            m.box((0,.53,.078),(width+.22,.11,.16),slab,0,.019)
            m.box((0,h-.085,.045),(width+.11,.14,.16),oak,1,.025)
            for k in (-1,1):
                for j in range(6):
                    m.box((k*(width/2-.108),.72+j*(h-.68)/6,.048),
                          (.29 if j%2 else .45,(h-.74)/6,.11),tint(plaster,-.1+.024*(j%3)),0,.013)
            if abs(orientation)==pi/2:
                for sx in (-.245,.245):
                    arched_window(m,sx*width,h*.57,.025,.86,1.05,not lib)
            else:
                for sx in (-.31,.31):
                    arched_window(m,sx*width,h*.56,.025,1.18 if lib else .76,1.37 if lib else 1.03,not lib)
                if orientation:
                    arched_window(m,0,h+.34,.025,.66,.72)
    ridge=cushion_roof(m,w,d,h+.045,rise,roof)
    entrance(m,front,h,lib,"517b75" if not loft else "90694d")
    if not hut:
        dormer(m,-1,w/2+.37,h+.045,rise,-.20 if not lib else .32,roof)
    if red or kind=="pilot" or lib:
        chimney(m,w*.25,-d*.23,h+rise*.60)
    m.group="Roof and gable fittings"
    # Loft hoists, a net-drying canopy and a roof lantern distinguish the trades.
    if loft:
        m.box((0,h+.67,front+.049),(1.22,1.08,.12),oak,1,.023)
        for k in range(6):
            m.box(((k-2.5)*.18,h+.67,front+.125),(.164,1.04,.07),tint(teal,.06*(k%3)),1)
        m.rod((0,h+1.40,front-.04),(0,h+1.40,front+.90),.084,oak)
        m.rod((0,h+.93,front+.17),(0,h+1.4,front+.73),.06,oak)
        m.rod((-.075,h+1.21,front+.79),(.075,h+1.21,front+.79),.147,brass,2,12)
        m.rod((0,h+1.20,front+.90),(0,h-.01,front+.90),.018,oak)
    elif lib:
        z = .13
        m.rod((0,ridge-.19,z),(0,ridge+.19,z),.62,teal,2,8)
        m.rod((0,ridge+.19,z),(0,ridge+.78,z),.46,"ecce8c",3,8)
        for i in range(8):
            a=i*TAU/8
            x,zz=.465*cos(a),z+.465*sin(a)
            m.rod((x,ridge+.16,zz),(x,ridge+.82,zz),.049,slate,2,5)
        m.rod((0,ridge+.78,z),(0,ridge+.9,z),.62,brass,2,8)
        m.rod((0,ridge+.9,z),(0,ridge+1.36,z),.67,teal,2,8,.08)
        m.rod((0,ridge+1.31,z),(0,ridge+1.73,z),.058,brass,2,8,.015)
        # Open book carved into the front gable.
        for s in (-1,1):
            m.face([(0,h+.63,front+.05),(s*.67,h+.80,front+.05),(s*.65,h+1.39,front+.05),
                    (s*.24,h+1.41,front+.05),(0,h+1.23,front+.05)],brass,2,(0,0,1))
            for j in range(3):
                m.rod((s*.10,h+.84+j*.12,front+.065),(s*.52,h+.98+j*.12,front+.065),.016,ivory,0,4)
    else:
        arched_window(m,0,h+.59,front+.015,.66,.81)
        if not hut:
            for col in range(9):
                a=(col-4.5)*.20
                top=[(a,2.36,front+.08),(a+.20,2.36,front+.08),
                     (a+.20,2.15,front+.71),(a,2.15,front+.71)]
                colr=ivory if col%2 else ("ba745b" if red else "6e968a")
                m.loft([[(x,y-.039,z) for x,y,z in top],top],colr)
                m.face([(a,2.15,front+.711),(a+.2,2.15,front+.711),(a+.2,2.05,front+.711),
                        (a+.155,1.985,front+.711),(a+.045,1.985,front+.711),(a,2.05,front+.711)],colr,0,(0,0,1))
            for s in (-1,1):
                m.rod((s*.81,1.77,front+.025),(s*.81,2.13,front+.66),.045,iron,2)
    if red:
        with m.frame_at((w*.5,0,0),pi*.5):
            m.box((.07,.85,.24),(1.78,.08,.43),oak,1,.025)
            for s in (-1,1):
                m.rod((s*.68,.42,.08),(s*.68,.84,.36),.055,oak)
            for i,r in enumerate([.18,.14,.204,.12,.105]):
                x=(i-2)*.315
                palette=[tile_red,teal,"c29466","a76d52","9a7655"]
                turning(m,x,.24,[(.9,r*.61),(1.03,r),(1.13,r*.85),(1.20,r*.58),(1.24,r*.68)],palette[i],0,12)
                turning(m,x,.24,[(1.236,r*.46),(1.245,r*.46)],dark,0,12)
    if kind=="pilot":
        turning(m,0,-d*.29,[(ridge-.09,.055),(ridge+.60,.029)],brass,2,8)
        m.rod((-.41,ridge+.42,-d*.29),(.42,ridge+.42,-d*.29),.025,brass,2,6)
        m.face([(-.43,ridge+.42,-d*.29),(-.24,ridge+.54,-d*.29),(-.24,ridge+.31,-d*.29)],brass,2,(0,0,1))
        m.face([(.25,ridge+.42,-d*.29),(.44,ridge+.56,-d*.29),(.44,ridge+.31,-d*.29)],teal,2,(0,0,1))
    if not hut and not lib:
        for x in (-w*.31,w*.31):
            y=h*.56-.80
            m.box((x,y,front+.19),(.96,.21,.31),tint(teal,-.08),1,.02)
            for i in range(11):
                xx=x+(.075*(i-5)); z=front+.19+.045*sin(i*2.7)
                yy=y+.22+.06*cos(i*2.71)
                for way in (-1,1):
                    m.face([(xx,y+.11,z),(xx+way*.092,yy-.031,z+.02),
                            (xx+way*.087,yy+.048,z+.03),(xx+.014*way,yy,z+.02)],
                           ["769165","8c9b62"][i%2],0,(0,0,1))
                if i%2==0:
                    turning(m,xx,z,[(yy-.012,.035),(yy+.019,.059),(yy+.065,.033)],
                            ["e8c38a","c98678","dca28d"][i%3],0,6)
    m.export(name)


def coastline_boat(name, wreck):
    """Clinker strakes wrap a varying station profile, with a broken starboard rail on the wreck."""
    m = Mesh(72 if wreck else 34)
    stations = [-1.98,-1.79,-1.5,-1.10,-.55,.03,.63,1.14,1.52,1.78]
    widths = [.022,.236,.45,.57,.615,.616,.573,.485,.35,.25]
    keel = [.32,.156,.016,-.08,-.11,-.11,-.08,-.015,.11,.23]
    rises = [.80,.71,.62,.56,.505,.505,.52,.55,.60,.66]
    def hull_point(side,i,t):
        return V((side*widths[i]*(.12+.88*sqrt(t)),keel[i]+(rises[i]-keel[i])*t,stations[i]))
    hues = ["765747","95684e","ae7a54","af7856","567e79","608e86","d9c399"]
    if wreck:
        hues = ["5f5948","82745b","8f7c60","9b8162","7f8a75","87937b","b6aa86"]
    for side in (-1,1):
        for i in range(len(stations)-1):
            for j in range(7):
                if wreck and side==1 and ((i in [1,2,3] and j>=2) or (i in [4,5] and j>=4) or (i==6 and j>=5)):
                    continue
                lo,hi = j/7,(j+1)/7
                a,b = hull_point(side,i,lo),hull_point(side,i+1,lo)
                c,d = hull_point(side,i+1,hi),hull_point(side,i,hi)
                offset=V((side*.013,-.012,0))
                m.loft([[a,b,c,d],[a+offset,b+offset,c+offset*.3,d+offset*.3]],
                       tint(hues[j],m.rng.uniform(-.04,.032)),1)
            if not wreck or side<0 or i>=7:
                a,b=hull_point(side,i,1),hull_point(side,i+1,1)
                m.rod(a,b,.035,"c1a275" if wreck else "e9cfa3")
        for i in range(1,len(stations)-1):
            for j in range(3):
                a,b = hull_point(side,i,j/3),hull_point(side,i,(j+1)/3)
                a.x *= .91
                b.x *= .91
                if wreck and i in (1,4) and j==2 and side>0:
                    b=a.lerp(b,.47)
                m.rod(a,b,.036,"756147" if wreck else "b38e60")
    for i in range(1,len(stations)-1):
        z=stations[i]
        m.box((0,keel[i]+.12,z),(widths[i]*1.06,.055,.42),
              m.rng.choice(["94765b","9b7b5c","a48967"]),1,.009)
    # The stern transom joins the strakes with a varnished top cap.
    for i in (0,len(stations)-1):
        for j in range(7):
            ring=[hull_point(side,i,t) for side,t in [(-1,j/7),(1,j/7),(1,(j+1)/7),(-1,(j+1)/7)]]
            m.face(ring,hues[j],1,(0,0,1 if i else -1))
    m.group="Thwarts and deck fittings"
    if not wreck:
        for z,width in [(-.77,.98),(.54,1.05)]:
            m.box((0,.39,z),(width,.075,.235),"cba77b",1,.021)
            for sign in (-1,1):
                m.rod((sign*width*.42,.430,z),(sign*width*.42,.437,z),.018,brass,2,7)
        for side in (-1,1):
            m.rod((side*.597,.48,-.04),(side*.597,.61,-.04),.031,brass,2,7)
        # A mooring warp coiled on the foredeck; a cage protects the bow lamp.
        m.box((0,.54,-1.43),(.48,.062,.30),oak,1,.016)
        for j in range(38):
            a,b=j*.46,(j+1)*.46
            r0,r1=.046+.004*j,.046+.004*(j+1)
            m.rod((cos(a)*r0,.588,-1.40+sin(a)*r0*.62),(cos(b)*r1,.588,-1.40+sin(b)*r1*.62),.013,"c3aa7d",1,4)
        for y,r,c,slot in [(.62,.102,iron,2),(.70,.076,"ffcf7c",3),(.79,.098,brass,2)]:
            m.rod((0,y,-1.68),(0,y+.075,-1.68),r,c,slot,8)
        for j in range(4):
            x,z=.079*cos(j*pi/2),-1.68+.079*sin(j*pi/2)
            m.rod((x,.68,z),(x,.81,z),.009,iron,2,5)
    else:
        m.rod((0,.14,-.29),(-.17,2.24,-.53),.081,"73634e",1,9,.047)
        m.rod((-.12,1.85,-1.04),(-.10,1.68,.31),.049,oak)
        for j in range(10):
            a,b=j/10,(j+1)/10
            def sheet(t,v):
                return (-.12+.14*sin(t*pi)*v,1.85-.17*t-v*(.59+.17*cos(9*t)+.13*sin(21*t)),-1.04+t*1.32)
            face=[sheet(a,0),sheet(b,0),sheet(b,1),sheet(a,1)]
            m.face(face,["ccb99a","bfae93","cebc9e"][j%3],0,(1,0,0))
        for x,z in [(-.4,-1.42),(.51,1.12),(-.4,.85)]:
            points=[V((x,.55,z)).lerp(V((-.16,2.15,-.53)),k/6)-V((0,.09*sin(pi*k/6),0)) for k in range(7)]
            for a,b in zip(points,points[1:]):
                m.rod(a,b,.013,"615844",1,5)
        # Splintered strakes trail off at the fracture.
        for j in range(4):
            p=hull_point(1,4,.34+j*.14)
            m.rod(p,p+V((.055,.115,-.16-.072*(j%2))),.032,"b09a72",1,4,.006)
    m.group="Mast and rigging"
    if name == "harbor_lugger":
        m.rod((0,.28,-.54),(0,2.85,-.57),.056,oak,1,9,.025)
        m.rod((0,1.05,-.55),(.04,1.20,1.47),.039,oak)
        # The sail is tied down to the boom while the crew is ashore.
        for j in range(12):
            a,b=j/12,(j+1)/12
            def fold(t):
                return [(.04+.09*cos(k*TAU/7),1.15+.15*t+(.10+.05*sin(t*pi))*sin(k*TAU/7),-.55+2*t)
                        for k in range(7)]
            m.loft([fold(a),fold(b)],"e3d5b1" if j%3 else "ad7058")
        for end in [(-.52,.49,.21),(.52,.49,.21),(0,.73,-1.86),(0,.68,1.57)]:
            foot=V(end)
            peak=V((0,2.76,-.57))
            for j in range(4):
                a,b=j/4,(j+1)/4
                m.rod(foot.lerp(peak,a)-V((0,.057*sin(a*pi),0)),foot.lerp(peak,b)-V((0,.057*sin(b*pi),0)),
                      .012,"665c48",1,5)
        m.face([(0,2.84,-.57),(0,2.62,-.57),(.47,2.72,-.39)],tile_red,0,(0,0,1))
        for j in range(4):
            with m.frame_at((-.23+j*.155,.48,1.1),j*.14):
                m.rod((0,0,-.05),(0,0,.04),.082,["c9af77","a96749"][j%2],0,8,.06)
    m.export(name)


def turning(m,x,z,profile,color,slot=1,n=10):
    rings = [[(x+r*cos(i*TAU/n),y,z+r*sin(i*TAU/n)) for i in range(n)] for y,r in profile]
    m.loft(rings,color,slot)


def market():
    m=Mesh(114)
    for x in (-1.29,1.29):
        for z in (-.55,.55):
            turning(m,x,z,[(0,.082),(.09,.11),(.78,.077),(.88,.09),(2.25,.061),(2.37,.085)],oak)
        m.rod((x,1.80,.55),(x,2.24,-.16),.042,oak)
        m.rod((x,.39,-.55),(x,.78,.55),.046,oak)
    for z in (-.6,.60):
        m.box((0,.82,z),(2.85,.22,.14),oak,1,.02)
    for j in range(7):
        m.box((0,.93,(j-3)*.196),(2.92,.102,.186),tint("ab8966",m.rng.uniform(-.06,.06)),1,.014)
    m.group="Striped sailcloth"
    for i in range(11):
        x0,x1=(i-5.5)*.28,(i-4.5)*.28
        color="cb8162" if i%2==0 else "efe0b7"
        path=[(-.85,2.14),(-.56,2.30),(-.27,2.48),(0,2.68),(.29,2.46),(.57,2.28),(.87,2.17)]
        for (za,ya),(zb,yb) in zip(path,path[1:]):
            m.face([(x0,ya,za),(x0,yb,zb),(x1,yb,zb),(x1,ya,za)],color,0,(0,1,0))
        m.face([(x0,2.17,.87),(x1,2.17,.87),(x1,1.98,.89),(x1-.045,1.92,.89),
                ((x0+x1)*.5,1.90,.89),(x0+.045,1.92,.89),(x0,1.98,.89)],color,0,(0,0,1))
    m.rod((-1.64,2.63,0),(1.64,2.63,0),.061,oak)
    m.group="Fish crates and baskets"
    m.box((.22,1.015,.12),(1.16,.08,.72),"8e7862",1,.02)
    for z in (-.23,.47):
        m.box((.22,1.12,z),(1.18,.16,.047),"a28c70",1)
    for x in (-.36,.80):
        m.box((x,1.12,.12),(.056,.15,.72),"987b5d",1)
    for j in range(3):
        z=-.08+.21*j
        x=.17+.05*(j%2)
        m.loft([[(x+dx,y,z+zz) for y,zz in [(1.087,0),(1.14,w),(1.21,0),(1.14,-w)]]
                for dx,w in [(-.33,.014),(-.19,.073),(.07,.095),(.24,.067),(.32,.014)]],"93afa9",2)
        m.face([(x-.30,1.14,z),(x-.47,1.14,z-.078),(x-.45,1.14,z+.087)],slate,2,(0,1,0))
        m.rod((x+.21,1.18,z+.041),(x+.21,1.194,z+.048),.018,dark,0)
    for x,z,r in [(-.92,.10,.27),(1.08,.12,.19),(-1.13,-.3,.17)]:
        turning(m,x,z,[(.98,r*.70),(1.05,r*.86),(1.22,r),(1.27,r*.94)],"b58955",1,14)
        for k in range(3):
            y=1.05+.059*k
            turning(m,x,z,[(y,r*(.87+.064*k)),(y+.023,r*(.89+.061*k))],"d8b482",1,14)
        for k in range(6):
            a=k*TAU/6
            turning(m,x+.55*r*cos(a),z+.55*r*sin(a),[(1.25,.061),(1.31,.08),(1.37,.047)],"c99850",0,7)
    m.export("fish_market")


def forge():
    m=Mesh(312)
    for row in range(4):
        for col in range(5):
            x=(col-2)*.61
            m.box((x,.13+row*.24,.13),(.598,.23,1.84),m.rng.choice(["86796a","918472","7b7568"]),0,.033)
    m.group="Firebox and chimney"
    # Round-backed furnace, deep hearth mouth and voussoirs facing the player's route.
    x,z=-.32,-.22
    turning(m,x,z,[(.94,1.06),(1.33,1.02),(1.76,.90),(2.08,.71),(2.32,.42)],"9f7561",0,16)
    with m.frame_at((x,0,.67),0):
        panel(m,arch_outline(.68,.94,1.52,.52),0,.09,"3e403a")
        for j in range(11):
            t0,t1=j*pi/11+.009,(j+1)*pi/11-.009
            poly=[(cos(t)*r,1.5+sin(t)*r*.78) for t,r in [(t0,.68),(t1,.68),(t1,.87),(t0,.87)]]
            panel(m,poly,.08,.17,m.rng.choice(["a78b71","b09679","98806a"]))
        for side in (-1,1):
            for row in range(3):
                m.box((side*.765,1.03+.17*row,.156),(.185,.158,.23),"a58a6c",0,.014)
        for j in range(14):
            m.rod((-.58+j*.082,.999,.22),(-.54+j*.082,1.034,.44),.065,
                  m.rng.choice(["ca6b38","ec9351","e6a75d"]),3,6)
    turning(m,-1.12,-.51,[(.6,.46),(2.10,.44),(2.22,.51),(2.38,.39),(3.22,.33),
                         (3.36,.40),(4.24,.33),(4.35,.43),(4.52,.43)],"766c61",0,10)
    for y,r in [(2.19,.52),(3.24,.38),(4.29,.43)]:
        turning(m,-1.12,-.51,[(y,r),(y+.071,r)],iron,2,10)
    turning(m,-1.12,-.51,[(4.519,.29),(4.527,.29)],dark,0,10)
    for j in range(3):
        xx=.65+j*.23
        m.rod((xx,1.08,.52),(xx+.06,1.73,.03),.029,iron,2)
        m.rod((xx+.045,1.62,.12),(xx+.07,1.85,-.10),.048,oak)
    m.export("harbor_smithy")


def logbook_desk():
    m=Mesh(402)
    for x in (-1.11,1.11):
        for z in (-.43,.43):
            turning(m,x,z,[(.02,.103),(.08,.133),(.15,.089),(.24,.069),(.55,.091),
                           (.62,.13),(.70,.10),(.81,.13),(.91,.106)],oak,1,8)
        m.box((x,.28,0),(.09,.12,.91),"896c50",1,.012)
    m.box((0,.30,0),(2.25,.104,.094),oak,1,.014)
    m.box((0,.84,0),(2.38,.24,1.0),"876749",1,.025)
    m.box((0,.985,0),(2.65,.14,1.15),"a17d56",1,.023)
    m.box((0,1.058,.018),(2.35,.016,.98),teal,1,.006)
    for z in (-.445,.49):
        m.box((0,1.071,z),(2.28,.008,.015),brass,2)
    for x in (-1.13,1.13):
        m.box((x,1.071,.021),(.015,.008,.93),brass,2)
    m.group="Open logbook"
    # Bowed folios are built from parallel sections; the spine and ribbon remain visible.
    for side in (-1,1):
        m.box((side*.255,1.10,.065),(.514,.055,.65),"86553f",1,.012)
        samples=8
        def page(t,z,level):
            return (side*(.013+.48*t),1.124+.05*sin(pi*t)+.021*(1-t)+level*.011,z)
        for tindex in range(samples):
            a,b=tindex/samples,(tindex+1)/samples
            for level in (0,1,2):
                ring=[[page(a,z,level),page(b,z,level),page(b,z,level+1),page(a,z,level+1)]
                      for z in (-.24,.365)]
                m.loft(ring,["c9b88d","ecdfb9","f4e7c6"][level],0)
        for j in range(9):
            z=-.16+j*.050
            end=m.rng.uniform(.64,.9)
            for a,b in [(.13,.38),(.41,end)]:
                pa,pb=V(page(a,z,3)),V(page(b,z,3))
                pa.y+=.003
                pb.y+=.003
                m.rod(pa,pb,.006,"81725e" if j else "a56643",0,5)
    m.face([(-.015,1.162,.18),(.027,1.162,.18),(.050,1.146,.405),(.0,1.144,.397)],
           "ab604e",0,(0,1,0))
    m.group="Bindings and ink"
    for j in range(3):
        with m.frame_at((-.87,1.091+j*.083,-.045),(.11,-.07,.15)[j]):
            m.box((0,.009,0),(.46,.068,.41),ivory,0,.008)
            for y in (-.027,.044):
                m.box((0,y,0),(.49,.016,.43),[tile_red,slate,oak][j],1,.006)
            m.box((-.235,.009,0),(.037,.081,.43),[tile_red,slate,oak][j],1,.005)
    turning(m,.88,-.22,[(1.07,.14),(1.11,.14),(1.17,.111),(1.235,.08),(1.27,.10)],iron,2,10)
    m.rod((.88,1.21,-.22),(1.16,1.64,-.28),.013,brass,2)
    m.face([(.97,1.37,-.24),(1.015,1.51,-.25),(1.17,1.69,-.28),(1.16,1.56,-.27),
            (1.08,1.47,-.25)],ivory,0,(0,0,1))
    m.rod((.70,1.089,.20),(1.10,1.089,.13),.029,oak,1,8)
    m.export("keepers_logbook")


def survey_station():
    m=Mesh(903)
    for row,(low,high,r0,r1) in enumerate([(-.18,.24,2.13,2.30),(.24,.63,2.17,1.98),
                                            (.63,.91,1.98,1.72),(.91,1.11,1.78,1.68)]):
        for i in range(12):
            a=(i+.5*(row%2))*TAU/12+.007
            b=a+TAU/12-.016
            def course(y,r):
                return [(u*cos(t),y,u*.83*sin(t)) for t,u in [(a,r*.68),(a,r),(b,r),(b,r*.68)]]
            m.loft([course(low,r0),course(high,r1)],m.rng.choice(stone_colors))
    m.group="Triangulation pillar"
    turning(m,0,0,[(.9,1.10),(1.14,1.16),(1.29,1.04),(1.43,.97),(2.82,.77),
                    (2.92,.86),(3.19,.82),(3.30,.74)],"a1a496",0,8)
    turning(m,0,0,[(2.78,.81),(2.84,.83),(2.90,.82)],"596f68",2,8)
    for i in range(8):
        # Bronze arrow benchmarks on alternate facets.
        angle=(i+.5)*TAU/8
        with m.frame_at((sin(angle)*.82,2.20,cos(angle)*.82),angle):
            m.box((0,0,0),(.42,.56,.07),iron,2,.035)
            m.box((0,.17,.042),(.27,.039,.024),brass,2)
            for sign in (-1,1):
                m.rod((0,-.14,.055),(sign*.116,.045,.055),.019,brass,2,5)
            m.rod((0,-.14,.055),(0,.10,.055),.016,brass,2,5)
    m.group="Sighting frame and compass"
    turning(m,0,0,[(3.27,.64),(3.38,.67),(3.44,.61),(3.53,.43)],teal,2,12)
    for i in range(24):
        a=i*TAU/24
        r=.49 if i%3 else .43
        m.rod((r*cos(a),3.445,r*sin(a)),(.58*cos(a),3.448,.58*sin(a)),.014,brass,2,4)
    for sign in (-1,1):
        m.rod((sign*.38,3.47,.03),(sign*.22,4.23,.04),.058,brass,2,8)
    m.rod((-.29,4.19,.04),(.29,4.19,.04),.096,iron,2,10)
    m.rod((0,4.12,-.46),(0,4.33,.70),.102,teal,2,12,.132)
    m.rod((0,4.31,.63),(0,4.34,.74),.148,brass,2,12)
    m.rod((0,4.34,.741),(0,4.345,.749),.092,"526f76",2,12)
    m.group="Wind pennants"
    m.rod((-.63,1.08,-.75),(-.63,5.78,-.75),.064,oak,1,8,.039)
    for v,color in [(5.62,"bd7654"),(5.22,teal)]:
        for i in range(5):
            t,b=i/5,(i+1)/5
            def flag(u,lower):
                return (-.63+1.39*u,v-.19*u-.06*sin(u*pi)-(1-u)*.29*lower,-.75+.20*sin(u*4.6))
            m.face([flag(t,0),flag(t,1),flag(b,1),flag(b,0)],color,0,(0,0,1))
    turning(m,-.63,-.75,[(5.74,.068),(5.85,.082),(5.94,.029)],brass,2,8)
    m.export("moor_triangulation")


def salt_pan():
    m=Mesh(715)
    m.box((0,-.04,0),(6.05,.46,5.15),"b3b09b",0,.072)
    for yaw,length,offset in [(0,6.0,(0,0,2.46)),(pi,6.0,(0,0,-2.46)),
                              (pi/2,4.9,(2.92,0,0)),(-pi/2,4.9,(-2.92,0,0))]:
        with m.frame_at(offset,yaw):
            for i in range(9):
                m.box(((i-4)*length/9,.24,0),(length/9-.015,.28,.23),
                      m.rng.choice(["c6c2a8","cccaaf","b8b9a7"]),0,.024)
            for i in (-3,0,3):
                m.box((i*length/10,.3,-.09),(.12,.48,.13),oak,1,.015)
            m.box((0,.405,-.022),(length,.087,.20),"ada284",1,.014)
    m.group="Brine and salt bloom"
    m.box((0,.168,0),(5.65,.085,4.74),"83aba2",2,.013)
    # Growing halite forms a pale crust at the waterline and rafts on the brine.
    for side in (-1,1):
        for i in range(22):
            z0=-2.34+i*4.68/22
            z1=z0+4.68/22+.004
            a,b=2.54+.10*sin(i*1.61),2.54+.10*sin((i+1)*1.61)
            m.face([(side*2.83,.217,z0),(side*2.83,.217,z1),(side*b,.217,z1),(side*a,.217,z0)],
                   m.rng.choice(["dcdcc9","d6dac9","e0ddc9"]),0,(0,1,0))
    for i in range(29):
        x=m.rng.uniform(-2.42,2.42)
        z=m.rng.uniform(-2.10,2.10)
        width=m.rng.uniform(.07,.26)
        delta=m.rng.uniform(.01,.035)
        m.face([(x,.216,z),(x+width*.7,.216,z-.024),(x+width,.216,z-.016),
                (x+width*.4,.216,z+delta)],"b4c7b9",0,(0,1,0))
    m.group="Inlet and gate"
    with m.frame_at((-2.34,0,2.41),0):
        for side in (-1,1):
            m.box((side*.29,.53,.008),(.11,.90,.13),oak,1,.02)
        for j in range(4):
            m.box((0,.40+.096*j,.08),(.50,.085,.08),tint(teal,.035*(j%3)),1,.01)
        m.box((0,.94,.017),(.77,.12,.17),oak,1,.018)
        m.rod((0,.58,.05),(0,1.21,.05),.043,iron,2,7)
        m.rod((-.21,1.13,.05),(.21,1.13,.05),.039,brass,2,7)
    m.export("evaporation_pan")


def salt_harvest():
    m=Mesh(314)
    rings=[]
    angles=[i*TAU/15+m.rng.uniform(-.065,.065) for i in range(15)]
    for y,r in [(-.10,1.0),(.08,1.23),(.30,1.00),(.65,.63),(.96,.31),(1.14,.085)]:
        rings.append([(.17*y+cos(a)*r*m.rng.uniform(.92,1.07),y+m.rng.uniform(-.03,.03),
                       -.09*y+sin(a)*r*.77*m.rng.uniform(.9,1.08)) for a in angles])
    for row in range(len(rings)-1):
        for i in range(15):
            j=(i+1)%15
            points=[rings[row][i],rings[row][j],rings[row+1][j],rings[row+1][i]]
            for poly in [(0,1,2),(2,3,0)]:
                m.face([points[k] for k in poly],m.rng.choice(["dedcca","e2dfcd","dedcc9","e8e4d3","d3d3c5"]),
                       0,(cos(angles[i]),.8,sin(angles[i])))
    m.face(rings[-1],ivory,0,(0,1,0))
    m.group="Loose salt and crystals"
    for j in range(37):
        a=m.rng.random()*TAU
        t=m.rng.uniform(.35,1.20)
        x,z=t*cos(a),.8*t*sin(a)
        y=max(.05,1.21-t)*.85
        r=m.rng.uniform(.038,.104)
        with m.frame_at((x,y,z),a):
            m.box((0,0,0),(r*1.31,r*.73,r),"ebe7d8",0,.012)
    m.export("salt_harvest")


def harbor_crane():
    m=Mesh(856)
    for x in (-.74,.74):
        for z in (-.59,.59):
            m.box((x,.15,z),(.53,.55,.54),slab,0,.05)
            m.rod((x,.37,z),(x*.16,2.86,z*.15),.119,oak,1,5)
    turning(m,0,0,[(-.05,.53),(.22,.61),(.43,.48),(.58,.47)],iron,2,12)
    turning(m,0,0,[(.42,.29),(.75,.32),(3.04,.265),(4.75,.245),(6.12,.215),(6.32,.151)],oak,1,8)
    for y,r in [(.74,.33),(1.10,.328),(3,.283),(4.75,.269),(5.41,.247),(6.04,.237)]:
        turning(m,0,0,[(y,r),(y+.087,r)],iron,2,10)
    m.group="Jib and running rigging"
    for z in (-.145,.145):
        m.rod((-.78,4.85,z),(3.61,5.98,z),.142,"8e6b4c",1,4,.118)
        m.rod((.19,2.95,z),(2.47,5.69,z),.119,oak,1,4)
        m.rod((-.16,6.12,z),(3.45,5.98,z),.025,"766349",1,6)
    for t in (.18,1.74,2.53,3.34):
        m.box((t,5.05+(t+.04)*.255,0),(.115,.27,.45),iron,2,.015)
    def wheel(x,y,z,r):
        for i in range(14):
            a,b=i*TAU/14,(i+1)*TAU/14
            m.rod((x+r*cos(a),y+r*sin(a),z),(x+r*cos(b),y+r*sin(b),z),r*.092,oak,1,5)
            if i%2==0:
                m.rod((x,y,z),(x+r*cos(a),y+r*sin(a),z),r*.054,brass,2,5)
        m.rod((x,y,z-.065),(x,y,z+.065),r*.21,iron,2,9)
    for x,y,r in [(3.46,5.94,.188),(-.34,5.05,.193),(3.46,3.43,.146)]:
        wheel(x,y,.007,r)
    m.rod((-.43,5.03,0),(-.52,1.84,0),.026,"a58d63",1,7)
    m.rod((-.40,5.22,0),(3.42,6.12,0),.025,"ad966d",1,7)
    for x in (3.32,3.61):
        m.rod((x,5.94,0),(x,3.42,0),.021,"a88f66",1,7)
    m.group="Winch and cargo"
    for z in (-.31,.31):
        m.box((-.42,1.43,z),(.55,.89,.11),oak,1,.02)
    m.rod((-.49,1.86,-.43),(-.49,1.86,.54),.177,oak,1,12)
    for j in range(8):
        z=(j-3.5)*.065
        m.rod((-.49,1.86,z),(-.49,1.86,z+.048),.19,"bd9e73",1,12)
    wheel(-.49,1.86,.60,.52)
    m.rod((-.89,2.12,.60),(-.89,2.12,.83),.052,oak,1,7)
    for z in (-.51,.51):
        for k in range(6):
            m.box((3.46+(k-2.5)*.172,2.13,z),(.166,.76,.082),tint("a67f56",.037*(k%3)),1,.008)
        for y in (1.82,2.40):
            m.box((3.46,y,z*1.1),(1.18,.11,.078),oak,1,.011)
        for x in (2.94,3.98):
            m.rod((3.46,3.29,0),(x,2.40,z),.027,"bba177",1,7)
    for x in (2.91,4.01):
        for i in range(4):
            m.box((x,1.87+i*.171,0),(.065,.165,1.04),tint("a67f56",.03*i),1,.008)
    for i in range(5):
        m.box((3.46,2.49,(i-2)*.197),(1.09,.075,.189),"ad8b60",1,.008)
    for x in (3.10,3.82):
        m.box((x,2.54,0),(.093,.049,1.02),iron,2,.008)
    m.export("harbor_davit")



def save_blend():
    # Display the same pigment multiplied by the material brush as in glTF.
    for mat in mats:
        tree=mat.node_tree
        brush=next((node for node in tree.nodes if node.type=="TEX_IMAGE"),None)
        shader=tree.nodes.get("Principled BSDF")
        pigment=tree.nodes.new("ShaderNodeVertexColor")
        pigment.layer_name="Pigment"
        if brush:
            multiply=tree.nodes.new("ShaderNodeMixRGB")
            multiply.blend_type="MULTIPLY"
            multiply.inputs[0].default_value=1
            tree.links.new(brush.outputs["Color"],multiply.inputs[1])
            tree.links.new(pigment.outputs["Color"],multiply.inputs[2])
            tree.links.new(multiply.outputs[0],shader.inputs["Base Color"])
        else:
            tree.links.new(pigment.outputs["Color"],shader.inputs["Base Color"])
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type=="VIEW_3D":
                view=area.spaces.active
                view.shading.color_type="VERTEX"
                view.shading.show_cavity=True
                view.shading.cavity_type="WORLD"
                view.overlay.show_extras=False
                view.region_3d.view_rotation=V((-.42,.92,-.67)).to_track_quat("-Z","Y")
                view.region_3d.view_distance=47
                view.region_3d.view_location=(0,6,1.2)
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/"art_source"/"Greybay_Harbor.blend"),compress=True)


if __name__=="__main__":
    for style in ["pilot","potter","loft","cabin","library"]:
        house(style,style)
    coastline_boat("rowing_skiff", False)
    coastline_boat("wrecked_lugger", True)
    coastline_boat("harbor_lugger", False)
    market()
    forge()
    logbook_desk()
    survey_station()
    salt_pan()
    salt_harvest()
    harbor_crane()
    save_blend()
