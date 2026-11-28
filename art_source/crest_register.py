"""Six regional enamel seals, their recessed counterforms and the beacon's crystal."""
from math import cos, sin, pi, tau
from pathlib import Path
from tempfile import TemporaryDirectory
import sys

import bpy
from mathutils import Vector

bpy.ops.wm.read_factory_settings(use_empty=True)
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/"art_source"))
from painted_mesh import Part, painted_material

ZONES=["snow","tide","volcano","desert","lake","forest"]
ENAMEL=["80bad3","58a493","bc6245","c79548","548ca0","75a16f"]
BRASS="b49662"
SHADOW="364b4b"


def station(x):
    return Vector((x,1.27+.025*x*x,1.50-.14*x*x))


def basis(x):
    tangent=Vector((1,0,-.28*x)).normalized()
    normal=Vector((.28*x,.48,1)).normalized()
    return tangent,normal.cross(tangent).normalized(),normal


def point(x, u, v, d):
    tangent,vertical,normal=basis(x)
    return station(x)+tangent*u+vertical*v+normal*d


def bezel(p,x,profile,colors):
    p.rings([[tuple(point(x,r*cos(tau*i/32),r*sin(tau*i/32),depth)) for i in range(32)]
             for depth,r in profile],colors,False)


def strokes(zone):
    if zone=="snow":
        lines=[]
        for i in range(6):
            a=tau*i/6
            def arm(r,s):
                return (r*cos(a)-s*sin(a), r*sin(a)+s*cos(a))
            lines.extend([[arm(0,0),arm(.82,0)],[arm(.64,-.19),arm(.42,0),arm(.64,.19)]])
        return lines
    if zone=="tide":
        return [[(-.66,.07),(-.52,.43),(-.16,.62),(.13,.61),(.51,.42),(.68,.09),(.13,-.53),(-.15,-.53),(-.66,.07)],
                [(-.13,-.43),(-.40,.33)],[(0,-.46),(0,.46)],[(.13,-.43),(.40,.33)]]
    if zone=="volcano":
        return [[(-.13,-.65),(-.51,-.38),(-.54,-.05),(-.25,.40),(-.19,.07),(.14,.43),(.22,.80),
                 (.56,.22),(.61,-.17),(.27,-.61),(-.13,-.65)],
                [(-.12,-.38),(.08,.03),(.26,-.21),(.14,-.42)]]
    if zone=="desert":
        return [[(-.76,-.37),(-.27,-.19),(.16,.25),(.42,.09),(.75,-.30)],
                [(-.63,-.60),(-.06,-.49),(.39,-.35)], [(-.71,.35),(-.28,.41),(.08,.61),(.40,.60)]]
    if zone=="lake":
        return [[(-.72,-.09),(-.43,.09),(-.16,.13),(.13,-.05),(.39,-.06),(.69,.13)],
                [(-.58,-.41),(-.24,-.27),(-.06,-.27),(.16,-.43),(.41,-.43),(.62,-.31)],
                [(-.08,.34),(-.04,.57),(.10,.76),(.25,.52),(.20,.34),(.06,.28),(-.08,.34)]]
    return [[(-.05,-.31),(-.19,-.03),(-.48,.18),(-.47,.44),(-.24,.46)],
            [(-.12,-.16),(.15,.19),(.41,.34),(.48,.58)],[(.11,.15),(.06,.50),(-.07,.72)],
            [(-.05,-.31),(-.31,-.47),(-.55,-.50)],[(-.05,-.31),(.14,-.58),(.37,-.65)],
            [(-.05,-.31),(-.07,-.67)]]


def relief(p,zone,x,depth,color,width):
    for stroke in strokes(zone):
        points=[tuple(point(x,u*.224,v*.224,depth)) for u,v in stroke]
        p.sweep(points,[width]*len(points),color,7)


def register_body():
    p=Part("Register")
    # Carved brass-bound console curved around the original optical carriage.
    for low,high,back,front,color in [(-.32,.31,-.32,.007,"466664"),
            (.30,.34,-.32,.022,BRASS),(-.34,-.30,-.32,.018,BRASS),(-.28,-.245,-.31,.017,"748781")]:
        sections=[]
        for i in range(21):
            x=-2.08+4.16*i/20
            sections.append([tuple(point(x,0,v,d)) for v,d in
                [(low,back),(high,back),(high,front-.018),(high-.016,front),(low+.016,front),(low,front-.018)]])
        p.rings(sections,color,False)
    for x in [-1.73,-.91,.91,1.73]:
        loc=station(x)
        p.loft([(0,.24,.27,loc.z-.17,x),(.10,.25,.27,loc.z-.17,x),(.17,.21,.23,loc.z-.17,x),
                (.22,.15,.16,loc.z-.17,x),(.86,.14,.16,loc.z-.20,x),(1.16,.21,.22,loc.z-.19,x)],
               ["8e9083","afa48d","797f77","526766",BRASS],8,smooth=False)
    for x in [-1.98,1.98]:
        p.oval(tuple(point(x,0,0,.052)),(.055,.055,.05),BRASS)
    return p


parts=[register_body()]
for i,zone in enumerate(ZONES):
    x=(i-2.5)*.64
    body=parts[0]
    bezel(body,x,[(.013,.262),(.034,.292),(.081,.292),(.095,.258),(.096,.245)],
          ["7f7763",BRASS,"d0b078","7a735b",SHADOW])
    bezel(body,x,[(.0965,.232),(.098,.21)],["53605a",SHADOW])
    relief(body,zone,x,.102,"727666",.007)
    plate=Part("Crest_"+zone)
    bezel(plate,x,[(.105,.205),(.120,.223),(.143,.222),(.151,.204),(.153,.189)],
          [BRASS,"e3c683",BRASS,"536965",ENAMEL[i]])
    relief(plate,zone,x,.157,"f8dfa4",.013)
    parts.append(plate)
    filament=Part("Filament_"+zone)
    filament.sweep([tuple(point(x,0,.21,.16)),(x*.88,1.76,1.24-.06*x*x),
                    (x*.55,1.97,1.02),(x*.30,2.18,.67),(x*.15,2.40,.52),(0,2.71,.19)],
                   [.018,.026,.025,.026,.034,.044],"ecd485",8)
    parts.append(filament)

for on in (False,True):
    crystal=Part("LitGlass" if on else "DormantGlass")
    profile=[]
    colors=[]
    for i in range(9):
        r=.30+.20*sin(pi*(i+.5)/9)
        h=2.22+i*.103
        profile.extend([(h,r-.04,r-.04),(h+.036,r+.024,r+.024),(h+.084,r,r)])
        colors.extend(["d7a15e","ecd485","fff0b0"] if on else ["416864","689a96","acc6b4"])
    crystal.loft(profile,colors,28,smooth=False)
    parts.append(crystal)

with TemporaryDirectory() as tmp:
    mat,tiles,count=painted_material("Beacon_register",[c for p in parts for c in p.colors],tmp)
objects=[p.finish(mat,tiles,count) for p in parts]
out=ROOT/"game/art/lighthouse/crest_register.glb"
bpy.ops.export_scene.gltf(filepath=str(out),export_format="GLB",export_animations=False,export_lights=False,export_cameras=False)
bpy.data.objects["DormantGlass"].hide_set(True)
bpy.data.objects["DormantGlass"].hide_render=True
for zone in ZONES:
    bpy.data.objects["Filament_"+zone].hide_set(True)
    bpy.data.objects["Filament_"+zone].hide_render=True
for area in bpy.context.screen.areas:
    if area.type=="VIEW_3D":
        space=area.spaces.active
        space.region_3d.view_location=(0,-.24,1.55)
        space.region_3d.view_distance=7.8
        space.region_3d.view_rotation=Vector((1.6,-7.,2.6)).to_track_quat('Z','Y')
        space.shading.color_type='TEXTURE'
        space.overlay.show_overlays=False
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/"art_source/Beacon_Register.blend"))
