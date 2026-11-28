"""Greybay dip net. Godot metres, grip at the origin, leading rim along -Z."""
from math import cos, sin, pi, tau
from pathlib import Path
from tempfile import TemporaryDirectory
import sys

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
sys.dont_write_bytecode = True
sys.path.insert(0, str(ROOT / "art_source"))
from painted_mesh import Part, painted_material

wood = Part("SM_DipNet_AshFrame")
cord = Part("SM_DipNet_KnottedBag")
wrap = Part("SM_DipNet_Bindings")

# Tapered ash shaft. Distinct facets around the oval cross section follow the grain.
profile = [(.068,.016,.019),(.059,.021,.024),(.029,.021,.023),(-.04,.018,.022),
           (-.113,.017,.020),(-.17,.016,.019),(-.32,.014,.016),(-.425,.013,.016),
           (-.49,.013,.018),(-.515,.011,.017)]
def shaft_y(z):
    return .021 * max(0., -z/.515)**2
rings = [[(rx*cos(tau*i/12),shaft_y(z)+ry*sin(tau*i/12),z)
          for i in range(12)] for z,rx,ry in profile]
wood.rings(rings,"a27149")
for i in range(len(rings)-1):
    for j in range(12):
        wood.colors[1+i*12+j] = ["b38458","b9895d","aa7850","a97b54","ac7e55","bd9063",
                                 "b08358","a77650","af8157","b0845b","b48258","a7784f"][j]

# The forward-tilted mouth and the hanging bag keep their silhouettes legible through a scoop.
centre=Vector((0,-.119,-.666))
long_axis=Vector((0,.64,.7684)).normalized()
mouth=Vector((0,long_axis.z,-long_axis.y))
X=Vector((1.,0,0))
def hoop(angle):
    return centre + X*(.201*sin(angle)*(1.-.09*cos(angle))) + long_axis*(.224*cos(angle))

def tube_loop(part, centres, normals, outward, widths, palette):
    rings=[]
    sides=8
    for i,point in enumerate(centres):
        rings.append([tuple(point + outward[i]*widths[0]*cos(j*tau/sides)
                            + normals[i]*widths[1]*sin(j*tau/sides)) for j in range(sides)])
    # Join the last profile to the first without duplicate seam vertices or hidden cap faces.
    first=len(part.points)
    for ring in rings:
        part.points.extend(ring)
    for i in range(len(rings)):
        for j in range(sides):
            a=first+i*sides+j
            b=first+i*sides+(j+1)%sides
            c=first+((i+1)%len(rings))*sides+(j+1)%sides
            d=first+((i+1)%len(rings))*sides+j
            part.polygon((a,b,c,d),palette[j],True)

samples=64
rim=[hoop(tau*i/samples) for i in range(samples)]
radials=[(X*sin(tau*i/samples)+long_axis*cos(tau*i/samples)).normalized() for i in range(samples)]
tube_loop(wood,rim,[mouth]*samples,radials,(.011,.010),
          ["af8256","c69667","cfa574","ba8a5c","8d6945","775840","997451","a57c53"])

# The ash strip has two bent tails lashed into the grip.
for side in (-1,1):
    fork=[(side*.009,.017,-.421),(side*.012,.021,-.457),(side*.021,.022,-.493)]
    fork.extend([tuple(hoop(side*a)) for a in (.19,.31,.44)])
    wood.sweep(fork,[.008,.009,.010,.010,.009,.008],"b8895f",7)

def grip_roll(z0,z1,radius,color,turns):
    divisions=turns*10
    path=[]
    for i in range(divisions+1):
        f=i/divisions
        a=tau*turns*f
        z=z0+(z1-z0)*f
        path.append((radius*cos(a),shaft_y(z)+radius*1.14*sin(a),z))
    wrap.sweep(path,[.0026]*(divisions+1),color,5)

grip_roll(.036,-.068,.020,"675145",12)
grip_roll(-.434,-.472,.017,"497d79",6)
grip_roll(-.430,-.435,.018,"d8b37e",1)
grip_roll(-.471,-.477,.018,"d8b37e",1)
# A worn wrist thong extends to the side of the hand so the pivot stays at the grip.
wrap.sweep([(.012,0,.050),(.032,-.014,.070),(.053,-.040,.079),
            (.067,-.061,.062),(.063,-.061,.037),(.048,-.046,.030),
            (.024,-.016,.039),(.014,-.005,.045)],
           [.0038]*8,"836044",6)

strands=16
levels=7
def knot(angle, row):
    t=row/levels
    # The upper rows open into a basket, then pull together at the repaired bottom.
    scale=(1.-t**1.55)**.78
    bottom=centre-mouth*.226+Vector((.013,-.074,-.01))
    centreline=centre.lerp(bottom,t)
    return centreline+(hoop(angle)-centre)*scale

for i in range(strands):
    a=tau*i/strands
    # Hitch every strand over the wooden bow.
    p=hoop(a)
    radial=(p-centre).normalized()
    tangent=(hoop(a+.01)-hoop(a-.01)).normalized()
    loop=[tuple(p+mouth*(.0128*sin(t)) + radial*(.0145*cos(t)) + tangent*(.003*cos(t)))
          for t in [j*tau/9 for j in range(10)]]
    wrap.sweep(loop,[.0038]*len(loop),"d2bf96",5)
    for direction in [-1,1]:
        path=[tuple(knot(a+direction*pi*row/strands,row)) for row in range(levels+1)]
        base=["d3c498","c7b78f","cbbc91","b8a984"][(i+(direction==1))%4]
        colors=[base]*len(path)
        if i in (3,4) and direction==1:
            colors[3:5]=["69928a","72958a"]
        cord.sweep(path,[.0036,.0036,.0035,.0034,.0033,.0031,.0029,.0028],colors,4)
bottom=knot(0,levels)
cord.sweep([tuple(bottom+Vector((-.01,0,-.008))),tuple(bottom),
            tuple(bottom+Vector((.009,-.014,.002)))],[.006,.008,.004],"72958a",5)

parts=(wood,cord,wrap)
with TemporaryDirectory() as directory:
    mat,tiles,count=painted_material("Greybay_FieldNet",[c for p in parts for c in p.colors],directory)
    for p in parts:
        p.finish(mat,tiles,count)
    image=mat.node_tree.nodes.get("Image Texture").image
    image.filepath="//Greybay_FieldNet_pigment.png"
mat.name="MAT_Greybay_AshAndHemp"
for area in bpy.context.screen.areas:
    if area.type=="VIEW_3D":
        space=area.spaces.active
        space.region_3d.view_location=(0,.40,-.105)
        space.region_3d.view_distance=1.65
        space.region_3d.view_rotation=Vector((.8,1.2,.8)).to_track_quat('Z','Y')
        space.shading.color_type='TEXTURE'
        space.overlay.show_overlays=False

bpy.ops.export_scene.gltf(filepath=str(ROOT/"game/art/greybay/field_net.glb"),export_format="GLB",
                          export_animations=False,export_lights=False,export_cameras=False)
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/"art_source/Greybay_FieldNet.blend"))
