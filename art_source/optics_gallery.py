"""Build the mirror room's ashlar lining and the graduated rose behind the optic.

Dimensions are metres in Godot axes. The circular kit is centred on the room.
"""
from math import cos, sin, pi, tau
from pathlib import Path
from random import Random
from tempfile import TemporaryDirectory
import sys

import bpy
import bmesh
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
sys.dont_write_bytecode = True
sys.path.insert(0, str(ROOT / "art_source"))
from painted_mesh import Part, painted_material

rng = Random(73)
stone = Part("SM_Gallery_Ashlar")
metal = Part("SM_Gallery_Brasswork")
glass = Part("SM_Gallery_SeaGlass")
floor = Part("SM_Gallery_Flagstones")


def cylindrical(radius, angle, height):
    return (radius * sin(angle), height, radius * cos(angle))


def wall_course(low, high, count, offset, colors):
    for i in range(count):
        bounds = [tau * (i + offset) / count + .001,
                  tau * (i + offset + 1) / count - .001]
        face = rng.uniform(15.31, 15.37)
        tone = rng.choice(colors)
        rings = []
        for y, radius, trim in [(low, face+.055, .0017), (low+.042, face, 0),
                                (high-.05, face, 0), (high, face+.05, .0017)]:
            a, b = bounds[0]+trim, bounds[1]-trim
            rings.append([cylindrical(radius, a, y), cylindrical(radius, b, y),
                          cylindrical(15.83, b, y), cylindrical(15.83, a, y)])
        stone.rings(rings, [tone, tone, tone], False)


for row in range(12):
    lower = ["415357", "475859", "4b5b5c", "45585b"] if row < 3 else [
        "606c68", "626e6c", "65716d", "596968", "6a716b", "5e6d6e"]
    wall_course(.09 + row*.83, .90 + row*.83, 40 if row < 3 else 48, row*.5, lower)

# The floor fits below the original 19 mm compass inlay.
for row in range(11):
    inner, outer = .6+1.33*row, 1.903+1.33*row
    sectors = max(8, round(tau * outer / 2.45))
    for i in range(sectors):
        a, b = tau*(i+row*.43)/sectors, tau*(i+1+row*.43)/sectors
        middle = (a+b)*.5
        a += .008/max(1,inner)
        b -= .008/max(1,inner)
        slab = [cylindrical(inner,a,.008), cylindrical(inner,middle,.008),
                cylindrical(inner,b,.008), cylindrical(outer,b,.008),
                cylindrical(outer,middle,.008), cylindrical(outer,a,.008)]
        floor.panel(slab, rng.choice(["526164","5a6867","586363","5e6b66","526064"]),
                    depth=-.024, axis=1)

# Elevation of the meridian instrument against the curved north wall.
CENTRE_Y = 3.8
FACE_Z = -14.52


def face(radius, angle, depth):
    return (radius*cos(angle), CENTRE_Y+radius*sin(angle), FACE_Z+depth)


def sector(part, inner, outer, a, b, depth, tone, steps=5, thickness=.035):
    # Small independent convex cells remain watertight under glTF triangulation.
    for j in range(steps):
        left, right = a+(b-a)*j/steps, a+(b-a)*(j+1)/steps
        part.panel([face(inner,left,depth), face(outer,left,depth),
                    face(outer,right,depth), face(inner,right,depth)], tone, thickness)


def ring(inner, outer, depth, color):
    sector(metal, inner, outer, 0, tau, depth, color, 96)


for i in range(24):
    a = tau*i/24
    for r0, r1, palette in [
        (.18, 1.15, ["779e98","729892","7da29c","719a96"]),
        (1.17, 2.11, ["668d8b","608882","678e8c","719892"]),
        (2.14, 2.48, ["485f62","4e6d6c","597371","506769"])]:
        sector(glass,r0,r1,a+.008,a+tau/24-.008,.02, rng.choice(palette),2)
    # Fine radial braces meeting the outer scale, and broad facets on eight compass points.
    if i % 3 == 0:
        r = 1.40 if i % 6 == 0 else 1.0
        tip, tail = face(r,a,.16), face(.16,a,.16)
        left, right = face(.45,a-.28,.16), face(.45,a+.28,.16)
        metal.panel([tip, left, tail], "c29d67")
        metal.panel([tip, tail, right], "827758")
    elif i % 2:
        sector(metal,1.19,2.10,a-.007,a+.007,.075,"526564",1)

ring(.15,.23,.10,"a2906d")
ring(1.13,1.18,.09,"677b72")
ring(2.07,2.15,.08,"978c6d")
ring(2.47,2.55,.09,"bea378")
ring(2.55,2.69,.035,"405753")
ring(2.68,2.76,.055,"887d65")
for i in range(72):
    angle = tau*i/72
    start = 2.18 if i%6 == 0 else (2.25 if i%3 == 0 else 2.34)
    sector(metal,start,2.445,angle-.0065,angle+.0065,.09,"cbb082",1)

for i in range(8):
    a=tau*i/8
    x,y,z=face(2.62,a,.105)
    metal.loft([(y-.047,.046,.052,z,x),(y+.047,.046,.052,z,x)],"c2a77a",8, smooth=False)

# A pair of forged brackets ties the dial into the masonry.
for side in [-1,1]:
    x=side*2.96
    metal.sweep([(x,.45,FACE_Z-.05),(x,2.85,FACE_Z-.05),(x-.38*side,3.3,FACE_Z+.03)],
                [.072,.072,.055],"617773",8)
    for y in [.52,1.36,2.48]:
        metal.loft([(y-.045,.145,.11,FACE_Z-.06,x),(y+.045,.145,.11,FACE_Z-.06,x)],
                   "9f8b65",8,smooth=False)

# Three use-specific finishes share one embedded pigment atlas.
with TemporaryDirectory() as tmp:
    base, tiles, count = painted_material("OpticsGallery", [
        c for p in (stone, floor, metal, glass) for c in p.colors], tmp)
base.name="MAT_Gallery_CutStone"
def finish(name, roughness, metallic):
    mat=base.copy()
    mat.name=name
    shader=mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Roughness"].default_value=roughness
    shader.inputs["Metallic"].default_value=metallic
    return mat
weathered = finish("MAT_Gallery_AgedBrass",.44,.62)
frosted = finish("MAT_Gallery_LeadedGlass",.25,.13)
glass_shader=frosted.node_tree.nodes.get("Principled BSDF")
frosted.node_tree.links.new(frosted.node_tree.nodes.get("Image Texture").outputs["Color"],
                            glass_shader.inputs["Emission Color"])
glass_shader.inputs["Emission Strength"].default_value=.10
for part, mat in [(stone,base),(floor,base),(metal,weathered),(glass,frosted)]:
    obj=part.finish(mat,tiles,count)
    # A masonry lining is always viewed from inside. Omit faces buried in the walls and floor.
    if part in (stone,floor):
        mesh=bmesh.new()
        mesh.from_mesh(obj.data)
        if part is stone:
            hidden=[f for f in mesh.faces if f.normal.xy.dot(f.calc_center_median().xy) > -.1]
        else:
            hidden=[f for f in mesh.faces if f.normal.z < -.8]
        bmesh.ops.delete(mesh,geom=hidden,context='FACES')
        mesh.to_mesh(obj.data)
        mesh.free()

tri_count=0
for obj in bpy.context.scene.objects:
    obj.data.calc_loop_triangles()
    tri_count+=len(obj.data.loop_triangles)
print("Gallery triangles",tri_count)
out=ROOT/"game/art/lighthouse/optics_gallery.glb"
bpy.ops.export_scene.gltf(filepath=str(out),export_format="GLB",export_animations=False,
                          export_lights=False,export_cameras=False)
for area in bpy.context.screen.areas:
    if area.type=="VIEW_3D":
        view=area.spaces.active
        view.region_3d.view_location=(0,14.52,3.8)
        view.region_3d.view_distance=11
        view.region_3d.view_rotation=Vector((2.4,-8,2.2)).to_track_quat('Z','Y')
        view.shading.color_type='TEXTURE'
        view.overlay.show_overlays=False
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/"art_source/Optics_Gallery.blend"))
