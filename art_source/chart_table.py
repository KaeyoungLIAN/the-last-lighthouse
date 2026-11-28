"""Build Greybay's trestle, folded chart, rewards, and flags in Godot metre coordinates."""
from math import cos,sin,tau,pi
from pathlib import Path
from tempfile import TemporaryDirectory
import os, subprocess, sys

import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
sys.dont_write_bytecode=True
sys.path.insert(0,str(ROOT/"art_source"))
from painted_mesh import Part,painted_material,xyz

frame=Part("SurveyTrestle")
flags=[]
marks=[]
def block(p,x,y,z,w,h,d,color,bevel=.012):
    k=min(bevel,w*.18,h*.32,d*.18)
    rows=[]
    for height,shrink in [(-h/2,k),(-h/2+k,0),(h/2-k,0),(h/2,k)]:
        a,b=w/2-shrink,d/2-shrink
        outline=[(-a,-b+k),(-a+k,-b),(a-k,-b),(a,-b+k),(a,b-k),(a-k,b),(-a+k,b),(-a,b-k)]
        rows.append([(x+u,y+height,z+v) for u,v in outline])
    p.rings(rows,color,False)

def beam(a,b,thickness,color,sides=6):
    frame.sweep([a,b],[thickness]*2,color,sides)

for x in [-.72,.72]:
    for z in [-.31,.31]:
        dx=.042 if x>0 else -.042
        dz=.091 if z>0 else -.091
        frame.sweep([(x+dx,.035,z+dz),(x,.84,z),(x,.954,z)],[.086,.064,.074],"47706b",6)
        frame.loft([(.015,.093,.094,z+dz,x+dx),(.068,.093,.094,z+dz,x+dx)],
                   "695c49",8, smooth=False)
    block(frame,x,.22,0,.147,.098,.70,"765e45")
    block(frame,x,.87,0,.161,.16,.84,"466662")
    beam((x,.27,-.29),(x,.77,.25),.037,"9c7951")
block(frame,0,.27,0,1.56,.105,.11,"906c4b")
for side in [-1,1]:
    block(frame,0,.875,side*.417,1.67,.15,.09,"486e67")
    block(frame,0,.914,side*.468,1.67,.026,.011,"b89c69",.003)
for row,paint in enumerate(["956e49","a17d55","96734f","a67f55","9b764f"]):
    z=-.426+.213*row
    block(frame,0,.99,z,1.85,.109,.208,paint)
for x in [-.88,.88]:
    block(frame,x,1.015,0,.061,.08,1.063,"826549")
    for z in [-.45,.45]:
        frame.loft([(1.055,.012,.012,z,x),(1.061,.012,.012,z,x)],"baa070",7,smooth=False)

colors=["9dbec7","76a797","b87557","cda963","719eae","83a278"]
zones=["snow","tide","volcano","desert","lake","forest"]
for i,name in enumerate(zones):
    angle=-2.30-tau*i/6
    x,z=cos(angle)*.50,sin(angle)*.27
    frame.loft([(1.065,.076,.076,z,x),(1.077,.079,.079,z,x),(1.088,.070,.070,z,x)],
               ["8f7958",colors[i],colors[i]],8,smooth=False)
    relief=Part("ChartToken_"+name)
    relief.loft([(1.087,.045,.045,z,x),(1.117,.049,.049,z,x),(1.126,.039,.039,z,x),
                 (1.169,.021,.021,z,x),(1.172,.014,.014,z,x)],
                ["866e49","c79f5b","ecd485","e4c98f"],6,smooth=False)
    marks.append(relief)
    flag=Part("CatchPennant_"+name)
    fx=-.70+i*.28
    # The hem kicks forward into a swallow-tail; the crease catches side light.
    columns=[(-.083,1.325,.008),(-.040,1.299,.019),(0,1.342,.010),(.041,1.298,-.003),(.082,1.326,.007)]
    for k in range(4):
        u,y,d=columns[k]; v,h,e=columns[k+1]
        flag.panel([(fx+u,1.507,-.445),(fx+v,1.507,-.445),
                    (fx+v,h,-.432+e),(fx+u,y,-.432+d)],colors[i],.006)
    for u in [-.055,.055]:
        flag.sweep([(fx+u,1.476,-.432),(fx+u,1.516,-.448),(fx+u,1.493,-.46)],
                   [.004]*3,"d4c29a",6)
    flag.panel([(fx,1.449,-.425),(fx+.022,1.419,-.415),(fx,1.379,-.414),
                (fx-.022,1.419,-.413)],"e4d0a0",.003)
    flags.append(flag)

for x in [-.83,.83]:
    frame.loft([(1.033,.031,.032,-.445,x),(1.487,.023,.024,-.445,x),(1.535,.032,.032,-.445,x)],
               ["805e43","aa8761"],8,smooth=False)
frame.sweep([(-.83,1.521,-.445),(0,1.497,-.445),(.83,1.521,-.445)],
            [.010,.010,.010],"bfac82",6)
# Hand-cut notches in the plinth store the dip net at the front edge.
frame.sweep([(.57,.883,.453),(.57,.903,.531),(.57,.928,.566)],
            [.016,.013,.009],"ab8b58",7)
# An old copper signal lantern hung by a hook off the outside of the port trestle.
p=-.87; z=-.375
frame.loft([(.01,.058,.059,z,p),(.12,.057,.055,z,p),(.19,.049,.047,z,p),
            (1.89,.035,.033,z,p),(1.965,.043,.039,z,p)],["725c4a","a58b68","98774e","bc9e6a"],8,smooth=False)
beam((p,1.922,z),(-.46,1.922,z),.032,"97764f")
beam((p,1.76,z),(-.64,1.92,z),.019,"9e7e55")
beam((-.55,1.92,z),(-.55,1.81,z),.007,"605a4c")
frame.loft([(1.446,.079,.079,z,-.55),(1.473,.127,.127,z,-.55),(1.496,.115,.115,z,-.55),
            (1.525,.08,.08,z,-.55),(1.696,.091,.091,z,-.55),(1.724,.125,.125,z,-.55),
            (1.774,.077,.077,z,-.55),(1.811,.024,.024,z,-.55)],
           ["78654f","b39564","6b755f","ecd485","887859","678079","a2885c"],8,smooth=False)
for i in range(4):
    a=tau*i/4
    beam((-.55+.087*cos(a),1.499,z+.087*sin(a)),(-.55+.098*cos(a),1.702,z+.098*sin(a)),
         .008,"696959")

parts=[frame,*flags,*marks]
with TemporaryDirectory() as directory:
    paint,tiles,count=painted_material("Greybay_ChartWood",[c for p in parts for c in p.colors],directory)
    for p in parts: p.finish(paint,tiles,count)
    paint.node_tree.nodes.get("Image Texture").image.filepath="//Greybay_ChartWood_pigment.png"
    sheet=Path(directory)/"ChartPaper.png"
    subprocess.run([os.environ.get("GREYBAY_PYTHON","python"),str(ROOT/"art_source/chart_ink.py"),str(sheet)],check=True)
    image=bpy.data.images.load(str(sheet));image.pack();image.filepath="//ChartPaper.png"

mat=bpy.data.materials.new("MAT_Chart_FoldedPaper")
mat.use_nodes=True
bsdf=mat.node_tree.nodes.get("Principled BSDF");bsdf.inputs["Roughness"].default_value=.92
tex=mat.node_tree.nodes.new("ShaderNodeTexImage");tex.image=image
mat.node_tree.links.new(tex.outputs["Color"],bsdf.inputs["Base Color"])
us=[0,.025,.32,1/3,.347,.65,2/3,.684,.975,1]
vs=[0,.04,.482,.5,.521,.96,1]
pts=[];uv=[];faces=[]
for v in vs:
    for u in us:
        fold=.014 if abs(u-1/3)<.001 else (.010 if abs(u-2/3)<.001 else 0)
        fold+=.006 if v==.5 else 0
        curl=.017*(max(0,.032-u)+max(0,u-.968))/.032*(.5+.5*cos(v*5))
        pts.append(xyz(((u-.5)*1.49,1.063+fold+curl,(v-.5)*.79)))
        uv.append((u,1-v))
for j in range(len(vs)-1):
    for i in range(len(us)-1):
        k=j*len(us)+i;faces.append((k,k+len(us),k+len(us)+1,k+1))
mesh=bpy.data.meshes.new("FoldoutChart");mesh.from_pydata(pts,[],faces);mesh.materials.append(mat)
layer=mesh.uv_layers.new(name="Survey");mesh.update()
for poly in mesh.polygons:
    for loop in poly.loop_indices: layer.data[loop].uv=uv[mesh.loops[loop].vertex_index]
obj=bpy.data.objects.new("FoldoutChart",mesh);bpy.context.collection.objects.link(obj)
for area in bpy.context.screen.areas:
    if area.type=="VIEW_3D":
        v=area.spaces.active;v.region_3d.view_location=(0,0,.95);v.region_3d.view_distance=3.55
        v.region_3d.view_rotation=Vector((.7,-1.3,.94)).to_track_quat('Z','Y');v.shading.color_type='TEXTURE'
bpy.ops.export_scene.gltf(filepath=str(ROOT/"game/art/greybay/voyage_chart.glb"),export_format="GLB",
                          export_animations=False,export_lights=False,export_cameras=False)
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/"art_source/Greybay_ChartTable.blend"))
