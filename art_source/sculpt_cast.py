"""Run with Blender 4.5 --background --python. Authored in game-space metres, front is -Z."""
import sys
from pathlib import Path
from math import cos, sin, pi, tau
from tempfile import TemporaryDirectory
import bpy
from mathutils import Vector
bpy.ops.wm.read_factory_settings(use_empty=True)
sys.dont_write_bytecode=True
sys.path.insert(0,str(Path(__file__).resolve().parent))
from painted_mesh import Part, painted_material, xyz, ink, ivory, ochre, sun, saddle, brass, patina, wine
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/"game"/"art"/"cast"
OUT.mkdir(parents=True,exist_ok=True)
gallery = bpy.data.collections.new("Cast and bestiary")
bpy.context.scene.collection.children.link(gallery)
islanders = ["keeper","cartographer","postwoman","herbalist","ranger","fisherman"]
enemies = ["hound","crab","fin","lizard","elite","boss"]
zones = ["snow","tide","volcano","desert","lake","forest"]

def arrange_source(name, objects):
    # Blender collection views show the same part pivots and resting positions as Godot.
    collection = bpy.data.collections.new(name.replace("_"," ").title())
    gallery.children.link(collection)
    pivot = bpy.data.objects.new(name.title(), None)
    collection.objects.link(pivot)
    pivot.empty_display_size=.06
    if name in islanders:
        column,row=islanders.index(name),0
    elif name in enemies:
        column,row=enemies.index(name),1
    else:
        zone,rank=name.split("_")
        column,row=zones.index(zone),2 if rank=="prey" else 3
    pivot.location=((column-2.5)*2.75,-row*3.4,0)
    layout = {
        "LeftBoot":("KeeperBody",(-.16,.73,0)), "RightBoot":("KeeperBody",(.16,.73,0)),
        "LeftSleeve":("KeeperBody",(-.326,1.43,0)), "RightSleeve":("KeeperBody",(.326,1.43,0)),
        "LampCage":("LeftSleeve",(-.03,-.44,-.09)), "ScarfTail":("KeeperBody",(.135,1.52,.125)),
        "Head":("Chest",(0,1.52,0)), "GreetingArm":("Chest",(.247,1.16,0))}
    mapped={o.name:o for o in objects}
    for o in objects:
        part_name=o.name
        o.users_collection[0].objects.unlink(o)
        collection.objects.link(o)
        if part_name in layout:
            parent,offset=layout[part_name]
            o.parent=mapped[parent]
            o.location=xyz(offset)
        else:
            o.parent=pivot
        o.name=name+"_"+part_name

def export(name,parts):
    bpy.ops.object.select_all(action='DESELECT')
    with TemporaryDirectory() as directory:
        mat, tiles, count=painted_material(name,(c for p in parts for c in p.colors),directory)
    built=[p.finish(mat,tiles,count) for p in parts]
    for o in built:
        o.select_set(True)
    bpy.context.view_layer.objects.active=built[0]
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+".glb")),use_selection=True,export_format="GLB",
        export_texcoords=True,export_animations=False,export_cameras=False,export_lights=False,export_yup=True)
    arrange_source(name, built)

def face(p,y,skin,hair,role):
    # Tapered mandible, cheek plane, brow ridge and ear cartilage.
    p.loft([(y-.214,.054,.062,-.024),(y-.18,.110,.107,-.028),(y-.119,.169,.139,-.024),
            (y-.042,.201,.173,-.017),(y+.045,.199,.180,-.006),(y+.12,.187,.166,.007),
            (y+.19,.138,.132,.014),(y+.204,.04,.047,.018)],skin,26)
    p.loft([(y-.19,.091,.08),(y-.30,.088,.087)],skin,16)
    for s in (-1,1):
        p.oval((s*.193,y-.017,.006),(.042,.064,.038),skin)
        p.oval((s*.213,y-.015,-.019),(.018,.035,.015),"be8266")
        p.oval((s*.081,y+.023,-.178),(.043,.024,.012),ivory,s*.03)
        p.oval((s*.077,y+.022,-.188),(.019,.022,.008),"344549")
        p.oval((s*.077-.004,y+.029,-.194),(.006,.005,.004),"fff1cc")
        p.sweep([(s*.033,y+.063,-.177),(s*.083,y+.074,-.169),(s*.133,y+.062,-.144)],
                [.009,.017,.006],hair,8)
    p.sweep([(0,y+.050,-.167),(0,y-.012,-.183),(0,y-.039,-.207),(0,y-.052,-.197)],
            [.016,.023,.037,.026],skin)
    p.sweep([(-.043,y-.105,-.154),(-.007,y-.106,-.169),(.04,y-.101,-.156)],[.003,.006,.003],"955f54")
    p.loft([(y+.094,.190,.174,.014),(y+.143,.198,.178,.021),(y+.204,.154,.143,.022),(y+.228,.055,.068,.024)],hair)
    for s in [-1,1]:
        p.sweep([(s*.167,y+.129,-.044),(s*.179,y+.082,-.067),(s*.186,y+.009,-.048)],
                [.054,.044,.014],hair,9)
    for j in range(5):
        x=-.14+j*.058
        p.sweep([(x+.022,y+.156,-.087),(x,y+.134,-.128),(x-.024,y+.093+.014*j,-.151)],
                [.040,.039,.007],hair,9)
    if role in ("ranger","fisherman"):
        p.loft([(y-.220,.046,.044,-.047),(y-.180,.113,.106,-.043),(y-.108,.164,.135,-.025),
                (y-.083,.153,.116,-.026)],hair)
        for s in (-1,1):
            p.oval((s*.042,y-.066,-.178),(.052,.023,.024),hair,s*.23)

def cap(p,y,crown,role):
    if role=="cartographer":
        p.loft([(y+.11,.222,.196),(y+.127,.231,.204),(y+.15,.224,.20,-.016),
                (y+.22,.215,.20,-.035,-.015),(y+.258,.128,.15,-.038,-.044)],["564d44",crown,crown,"b29a73"])
    elif role in ("ranger","fisherman"):
        p.loft([(y+.082,.221,.203),(y+.102,.238,.219),(y+.16,.230,.216),
                (y+.185,.211,.20),(y+.257,.155,.146,.011),(y+.286,.048,.065,.028)],["48565b","677e79","82938a",crown,crown],24)
        for i in range(22):
            a=tau*i/22
            p.sweep([(.233*sin(a),y+.106,.216*cos(a)),(.225*sin(a+.012),y+.153,.211*cos(a+.012))],[.005,.005],"839489",5)
    elif role=="herbalist":
        p.loft([(y+.084,.214,.183,.014),(y+.117,.226,.196,.02),(y+.20,.207,.184,.027),
                (y+.239,.105,.115,.032)],["ce9680",crown,crown],22)
        p.oval((.14,y+.058,.154),(.074,.062,.063),crown)
        for i in range(5):
            p.oval((-.166+.013*sin(i*2),y+.053-i*.056,.082-i*.013),(.056-i*.005,.054,.046),"644c40",.2*(-1)**i)
    else:
        keeper = role=="keeper"
        p.loft([(y+.104,.234,.219,-.015),(y+.114,.290 if keeper else .323,.265 if keeper else .288,-.027),
                (y+.130,.30 if keeper else .335,.274 if keeper else .30,-.027),(y+.147,.221,.204)], [ink if keeper else "8e714d",crown,crown],32)
        p.loft([(y+.138,.205,.192),(y+.157,.218,.204),(y+.186,.219,.205,-.008),
                (y+.229,.228,.213,-.017),(y+.264,.189,.186,-.02),(y+.28,.105,.115,-.018)],
                [crown,"33515a" if keeper else saddle,brass if keeper else "a27b55",crown,crown],26)
        p.oval((0,y+.179,-.208),(.034,.034,.012),brass)
        p.oval((0,y+.179,-.217),(.018,.019,.006),crown)
        if role=="postwoman":
            p.oval((0,y+.048,.17),(.109,.095,.084),"584536")

def boot(p,x,base,scale=1):
    p.loft([(base,.101*scale,.146*scale,-.04,x),(base+.028,.114*scale,.177*scale,-.052,x),
            (base+.059,.113*scale,.173*scale,-.052,x),(base+.11,.105*scale,.15*scale,-.044,x),
            (base+.145,.083*scale,.095*scale,-.004,x),(base+.252,.094*scale,.10*scale,.004,x),
            (base+.27,.102*scale,.105*scale,.004,x)],["31383a","494440","665143","6c5140","624c3e","967454"],20)
    for i in range(2):
        p.sweep([(x-.055,base+.124+i*.024,-.114+i*.017),(x+.051,base+.115+i*.024,-.12+i*.017)],
                [.007,.007],"c4a77c",6)

def coat(p,profile,base,collar,trim,role):
    p.loft(profile,base,30,.024)
    hem,hw,hd=profile[0][:3]
    p.loft([(hem+.008,hw*1.005,hd*1.005),(hem+.035,hw*.996,hd*.998)],trim,30,.024)
    for s in (-1,1):
        p.panel([(s*.031,collar+.034,-.162),(s*.15,collar+.047,-.106),(s*.186,collar-.019,-.155),
                 (s*.099,collar-.095,-.211)],trim)
    for j in range(4):
        y=collar-.115-j*.086
        idx=next((i for i in range(1,len(profile)) if profile[i][0]>=y),len(profile)-1)
        a,b=profile[idx-1],profile[idx]
        t=min(1,max(0,(y-a[0])/(b[0]-a[0])))
        d=a[2]+t*(b[2]-a[2])
        p.oval((.035,y,-d-.003),(.015,.015,.008),brass)
    if role=="keeper":
        p.loft([(1.067,.307,.220),(1.08,.311,.225),(1.122,.310,.225),(1.133,.303,.219)],["674531",saddle,"ae7951"],26)
        p.panel([(-.044,1.127,-.227),(.062,1.127,-.227),(.062,1.071,-.227),(-.044,1.071,-.227)],brass)
        p.panel([(-.024,1.116,-.236),(.045,1.116,-.236),(.045,1.084,-.236),(-.024,1.084,-.236)],saddle)

def scarf_collar(p,y,c):
    p.loft([(y-.044,.159,.134),(y-.02,.19,.151),(y+.003,.174,.143,-.008),(y+.028,.16,.132,.006),
            (y+.05,.14,.118)], [c,"cd6a50" if c==wine else c,c,c],22)

def sleeve(p,s,keeper,coat_color,skin):
    dy=.055 if keeper else .08
    p.sweep([(0,.035,0),(s*.022,-.026,0),(s*.048,-.127,-.006),(s*dy,-.24,-.035),
             (s*dy,-.28,-.051),(s*.035,-.33,-.072)],[.069,.129,.115,.103,.113,.081],
            [coat_color,coat_color,coat_color,coat_color,"8b694c" if keeper else coat_color])
    p.sweep([(s*.037,-.325,-.071),(s*.035,-.37,-.085)],[.084,.076],ink if keeper else "d7bc94")
    y=-.415 if keeper else -.39
    p.oval((s*.033,y,-.082),(.071,.089,.07),saddle if keeper else skin)
    p.oval((-s*.022,y+.012,-.112),(.032,.048,.032),saddle if keeper else skin)

def make_keeper():
    p=Part("KeeperBody")
    coat(p,[(.61,.342,.258),(.65,.361,.264),(.79,.351,.251),(1.065,.299,.217),(1.17,.303,.22),
            (1.37,.332,.237),(1.46,.304,.205),(1.50,.162,.145)],ochre,1.47,sun,"keeper")
    for side in (-1,1):
        p.panel([(side*.102,.974,-.212),(side*.247,.954,-.167),(side*.232,.816,-.201),
                 (side*.139,.784,-.244),(side*.106,.817,-.248)],"bd802e")
        p.panel([(side*.098,.978,-.224),(side*.253,.959,-.181),(side*.248,.919,-.197),
                 (side*.157,.902,-.227),(side*.105,.936,-.237)],"edb04c")
        p.oval((side*.157,.925,-.235),(.011,.011,.007),brass)
    p.sweep([(-.278,1.39,-.156),(-.154,1.279,-.208),(.016,1.174,-.229),(.192,1.082,-.186)],
            [.029,.027,.028,.025],saddle,8,.45)
    p.oval((-.09,1.239,-.222),(.022,.020,.010),brass)
    # Storm cape has a weighted, scalloped hem and raised piping.
    p.loft([(1.307,.410,.26),(1.32,.424,.267),(1.38,.411,.26),(1.46,.345,.214),
            (1.515,.222,.168)],["985e30",sun,"eeb549","dca144"],30,.031)
    scarf_collar(p,1.526,wine)
    face(p,1.748,"dbab87","59483b","keeper")
    cap(p,1.748,"37606a","keeper")
    # Satchel, seaman's blanket and two shoulder straps read from the follow camera.
    for s in (-1,1):
        p.sweep([(s*.202,1.06,.214),(s*.19,1.26,.243),(s*.202,1.417,.199),(s*.201,1.458,.139)],
                [.028,.031,.031,.023],saddle,8,.48)
    p.satchel(0,1.025,.235,.205,.161,.083)
    p.sweep([(-.254,1.20,.285),(-.24,1.20,.285),(.235,1.20,.285),(.254,1.20,.285)],
            [.061,.083,.083,.063],["739793","52827f","739793"],16)
    for s in (-1,1):
        p.sweep([(s*.154,1.20,.285),(s*.182,1.20,.285)],[.086,.086],saddle,14)
        p.oval((s*.17,1.206,.364),(.014,.015,.008),brass)
    parts=[p]
    for s,label in [(-1,"Left"),(1,"Right")]:
        leg=Part(label+"Boot")
        leg.loft([(-.53,.073,.078),(-.459,.079,.080),(-.405,.107,.122),(-.24,.118,.129),(-.13,.128,.135),(.018,.131,.129)],
                 [ink,"384e54","41595d","384e54"],18)
        boot(leg,0,-.727,1.02)
        parts.append(leg)
        arm=Part(label+"Sleeve")
        sleeve(arm,s,True,ochre,saddle)
        parts.append(arm)
    tail=Part("ScarfTail")
    tail.panel([(-.063,.019,.006),(.059,.021,.008),(.06,-.097,.051),(.098,-.215,.078),
                (.024,-.192,.069),(-.024,-.234,.064),(-.056,-.111,.031)],wine)
    tail.sweep([(-.052,-.138,.053),(.076,-.128,.073)],[.007,.007],"e2946b",6)
    parts.append(tail)
    lamp=Part("LampCage")
    lamp.loft([(-.45,.075,.075),(-.438,.133,.133),(-.42,.151,.151),(-.40,.150,.150),(-.381,.115,.115)],
               [ink,"516c69",brass,ink],12)
    lamp.loft([(-.183,.128,.128),(-.166,.15,.15),(-.146,.15,.15),(-.134,.126,.126),
               (-.099,.098,.098),(-.085,.061,.061)], [brass,ink,"5b7878","466864",brass],12)
    for i in range(6):
        a=tau*i/6
        lamp.sweep([(.114*sin(a),-.397,.114*cos(a)),(.128*sin(a),-.273,.128*cos(a)),(.119*sin(a),-.168,.119*cos(a))],
                   [.009,.011,.009],brass,8)
    lamp.sweep([(-.078,-.114,0),(-.086,-.052,0),(-.061,-.012,0),(0,.009,0),(.061,-.012,0),(.086,-.052,0),(.078,-.114,0)],
               [.012]*7,brass,8)
    parts.append(lamp)
    export("keeper",parts)

def relocate(part, offset):
    part.points=[tuple(a+b for a,b in zip(v,offset)) for v in part.points]

def make_islander(role,base,skin,hair,hat):
    p=Part("Chest")
    w={"ranger":.312,"herbalist":.287,"cartographer":.269,"postwoman":.259,"fisherman":.307}[role]
    coat(p,[(.386,w*1.1,.198),(.42,w*1.12,.201),(.64,w*.98,.195),(.83,w*.80,.178),
            (1.04,w*.94,.192),(1.17,w,.187),(1.23,w*.76,.146),(1.28,.118,.111)],
         base,1.22,"b89a71" if role=="cartographer" else ("8b9b79" if role=="herbalist" else base),role)
    for s in [-1,1]:
        x=s*.12
        p.loft([(.185,.062,.067,.018,x),(.252,.062,.070,.01,x),(.29,.085,.089,.013,x),(.43,.097,.106,.006,x),
                (.56,.102,.104,.004,x)],"465658",16)
        boot(p,x,.006,.85)
    head=Part("Head")
    face(head,0,skin,hair,role)
    cap(head,0,hat,role)
    arm=Part("GreetingArm")
    sleeve(arm,1,False,base,skin)
    fixed=Part("OtherSleeve")
    sleeve(fixed,-1,False,base,skin)
    relocate(fixed,(-.247,1.16,0))
    shift=len(p.points)
    p.points.extend(fixed.points)
    for f,c,s in zip(fixed.faces,fixed.colors,fixed.smoothing):
        p.polygon(tuple(shift+j for j in f),c,s)
    if role=="cartographer":
        for s in (-1,1):
            ring=[(s*.084+.050*cos(j*tau/20),.018+.042*sin(j*tau/20),-.194) for j in range(21)]
            head.sweep(ring,[.0055]*21,brass,6)
        head.sweep([(-.034,.025,-.196),(0,.033,-.210),(.034,.025,-.196)], [.005]*3,brass)
        p.panel([(-.31,.873,-.246),(.14,.894,-.239),(.17,.813,-.421),(-.29,.790,-.430)],ivory)
        p.sweep([(-.23,.819,-.403),(-.18,.846,-.346),(-.075,.845,-.349),(.016,.871,-.298),(.079,.865,-.314)],
                [.006]*5,patina,6)
        arm.sweep([(.031,-.385,-.105),(-.034,-.46,-.29)],[.012,.003],ink)
        p.sweep([(-.19,.613,.173),(.224,1.195,.160)], [.064,.064],"c79d67",12)
    elif role=="postwoman":
        scarf_collar(p,1.27,patina)
        p.sweep([(-.17,1.237,-.10),(-.122,1.125,-.179),(.061,.89,-.18),(.213,.682,-.131)],
                [.030]*4,saddle,8,.4)
        p.satchel(.208,.684,-.128,.115,.114,.099)
        arm.panel([(-.071,-.33,-.154),(.13,-.343,-.154),(.125,-.447,-.159),(-.074,-.428,-.16)],ivory)
        arm.oval((.024,-.393,-.167),(.016,.014,.006),wine)
    elif role=="herbalist":
        p.panel([(-.151,1.14,-.203),(.138,1.14,-.203),(.161,.84,-.210),(.227,.433,-.224),
                 (.10,.409,-.233),(-.173,.413,-.222),(-.209,.459,-.218)],"c1b18a")
        p.panel([(-.105,.780,-.221),(.102,.795,-.221),(.091,.684,-.230),(-.084,.675,-.230)],"a29370")
        scarf_collar(p,1.266,"798d65")
        arm.loft([(-.47,.086,.088,-.175,.054),(-.442,.123,.112,-.175,.054),(-.341,.153,.13,-.175,.054),
                  (-.33,.157,.133,-.175,.054)],["8c6548","bb9060","e2bd7e"],16)
        for j in range(11):
            a=2.4*j
            x=.054+.13*cos(a)
            z=-.175+.092*sin(a)
            y=-.20+.055*sin(j*1.7)
            arm.sweep([(.052,-.36,-.174),(x,y,z)],[.008,.005],"608066",6)
            arm.oval((x,y,z),(.029,.064,.024),["b88b91","80a382","9aaf76"][j%3],cos(a)*.63)
    elif role=="fisherman":
        for j in range(4):
            y=.91+j*.074
            w=.269+j*.009
            p.loft([(y,w,.193),(y+.031,w+.003,.194)],"647f82",24)
        p.satchel(-.20,.658,.07,.09,.106,.076)
        for j in range(4):
            ring=[(.044+(.114-j*.006)*cos(a*tau/26),-.457+(.164-j*.009)*sin(a*tau/26),-.104-.012*j) for a in range(27)]
            arm.sweep(ring,[.011]*27,"c5a778",7)
        scarf_collar(p,1.268,"926450")
    else:
        p.loft([(1.00,.342,.222),(1.037,.358,.236),(1.138,.339,.217),(1.235,.229,.166),
                (1.28,.141,.12)],["6e816d","899b83","778c78","657f73"],24,.034)
        p.satchel(-.031,.876,.192,.172,.206,.102,"7e684a")
        arm.sweep([(.045,-1.15,-.103),(.051,-.4,-.098),(.05,.17,-.109),(.074,.246,-.101)],
                  [.023,.032,.026,.019],["958061","ad9970","72634a"],10)
    export(role,[p,head,arm])

make_keeper()
make_islander("cartographer","578880","d1a57c","9d978a","8f8068")
make_islander("postwoman","b36c52","d4ab86","594735","c7a267")
make_islander("herbalist","738864","ce9e78","715548","ae7377")
make_islander("ranger","657c84","ad815e","715d4c","5d716d")

make_islander("fisherman","607981","c89875","7f7363","5a7377")

def horizontal(p, rows, coat, belly=None, segments=24):
    # Cross sections run from muzzle/head to tail. Pigment follows the flank.
    rings=[]
    last=len(p.faces)
    for z,y,w,h in rows:
        rings.append([(w*cos(tau*j/segments), y+h*sin(tau*j/segments),z) for j in range(segments)])
    p.rings(rings,coat)
    if belly:
        for i in range(len(rows)-1):
            for j in range(segments):
                if sin(tau*(j+.5)/segments)<-.51:
                    p.colors[last+1+i*segments+j]=belly

def eye(p,x,y,z,r=.042):
    for s in (-1,1):
        p.oval((s*x,y,z),(r*.82,r,r*.85),"263e40")
        p.oval((s*(x+r*.41),y+.002,z-r*.27),(r*.55,r*.7,r*.52),"ecd485")
        p.oval((s*(x+r*.64),y+.001,z-r*.46),(r*.25,r*.53,r*.21),"344447")

def walk_piece(parts,origin):
    piece=Part("Walk%02d"%(len(parts)-1))
    piece.origin=origin
    parts.append(piece)
    return piece

def paws(parts,h,w,l,coat,hoof=False,wide=False,rows=2):
    for row in range(rows):
        z=(row/(max(1,rows-1))-.5)*l
        for side in (-1,1):
            p=walk_piece(parts,(w*side,h,z))
            if wide:
                end=(side*.53,-h+.029,-.083+.1*row)
                p.sweep([(0,0,0),(side*.161,.07,0),(side*.319,.080,.04),(side*.388,-.06,.037),end],
                        [.085,.073,.087,.044,.008], [coat,"ab9871",coat,"694d44"],10,.81)
                continue
            back=row==rows-1 and rows>1
            p.sweep([(0,.025,0),(.022*side,-h*.20,.02),(.031*side,-h*.43,-.079 if back else .004),
                     (.044*side,-h*.65,.061 if back else .044),(.041*side,-h*.90,.025)],
                    [.117 if back else .104,.105,.080,.055,.043],[coat,coat,coat,"65574c"],12)
            p.oval((side*.04,-h+.045,-.018),(.070 if hoof else .078,.051,.090 if hoof else .118),
                   "424848" if hoof else "736557")
            if not hoof:
                for k in (-1,0,1):
                    p.oval((side*.04+k*.040,-h+.033,-.091),(.019,.021,.032),"aa9675")

def leaf(p,root,tip,width,color,thick=.018):
    a,b=Vector(root),Vector(tip)
    delta=b-a
    side=delta.cross(Vector((0,0,1)))
    if side.length<.04:
        side=delta.cross(Vector((0,1,0)))
    side.normalize()
    c=a+delta*.39
    path=[tuple(a),tuple(c+width*side),tuple(b),tuple(c-width*side)]
    # Closed tapered scale with a raised medial ridge.
    ring=len(p.points)
    peak=tuple(c+Vector((0,.016,-thick)))
    p.points.extend(path+[peak])
    p.polygon((ring+3,ring+2,ring+1,ring),color)
    for j in range(4):
        p.polygon((ring+j,ring+(j+1)%4,ring+4),color)

def land_animal(name, coat, underside, style):
    p=Part("Body")
    parts=[p]
    hoof=style in ["ram","deer","storm"]
    rabbit=style=="rabbit"
    h=.78 if hoof else (.48 if rabbit else .53)
    if style=="lizard": h=.36
    neck=.31 if hoof else (.24 if style not in ["lizard","marten"] else .075)
    muzzle=h+neck
    horizontal(p,[(-1.04,muzzle-.047,.056,.046),(-.98,muzzle-.038,.108,.090),(-.90,muzzle,.146,.111),
                  (-.80,muzzle+.045,.199,.155),(-.69,muzzle+.063,.216,.195),(-.56,muzzle+.037,.194,.185),
                  (-.43,h+.071,.217,.205),(-.33,h+.022,.284,.258),(-.16,h,.343,.308),(.035,h+.023,.352,.285),
                  (.235,h+.035,.306,.234),(.417,h+.053,.312,.247),(.548,h+.044,.257,.213),
                  (.646,h+.015,.124,.127)],coat,underside)
    p.oval((0,muzzle-.003,-1.027),(.077,.040,.032),"414a46")
    eye(p,.187,muzzle+.085,-.804,.038 if style=="lizard" else .046)
    if style!="lizard":
        for s in (-1,1):
            top=.54 if rabbit else (.24 if not hoof else .18)
            direction=.082 if rabbit else (.206 if hoof else .114)
            root=(s*.133,muzzle+.183,-.655)
            tip=(s*(.139+direction),muzzle+.187+top,-.608+(.099 if hoof else .038))
            leaf(p,root,tip,.081 if rabbit else .073,coat,.036)
            leaf(p,(s*.142,muzzle+.224,-.679),(tip[0],tip[1]-.037,tip[2]-.01),.046,"bc947f" if rabbit else underside)
    paws(parts,h-.021,.224,.72,coat,hoof,style=="lizard")
    if style=="rabbit":
        p.oval((0,h+.14,.655),(.126,.127,.134),ivory)
    else:
        end=1.56 if style in ["marten","lizard"] else 1.03
        p.sweep([(0,h+.04,.53),(.056,h+.11,.76),(.122,h+.116,.94),(.173,h+.027,end-.13),(.196,h+.02,end)],
                [.135,.133,.099,.078,.008],[coat,coat,underside,underside],14)
    if hoof:
        for s in (-1,1):
            start=(s*.133,muzzle+.215,-.642)
            if style=="ram":
                for i in range(15):
                    a=.3+i*.33
                    b=a+.33
                    def curl(t):
                        r=.246-.022*t
                        return (s*(.198+.031*t),muzzle+.25+r*sin(t),-.63+r*cos(t))
                    w=.118-.0057*i
                    p.sweep([curl(a),curl((a+b)/2),curl(b)],[w*.92,w,w*.93],["b8a17e","988569"],12)
            elif style=="deer":
                elbow=(s*.39,muzzle+.58,-.526)
                end=(s*.695,muzzle+.928,-.26)
                p.sweep([start,elbow,(s*.54,muzzle+.74,-.446),end],[.084,.066,.051,.006],["887153","c7a268",ivory],12)
                for off,tip in [(0,(-.05,.33,-.23)),(.13,(.03,.31,-.14)),(.23,(.05,.27,-.09))]:
                    a=(s*(.369+off),muzzle+.55+off,-.539+off*.59)
                    p.sweep([a,(a[0]+s*tip[0],a[1]+tip[1]*.55,a[2]+tip[2]*.63),
                             (a[0]+s*tip[0],a[1]+tip[1],a[2]+tip[2])],[.052,.029,.003],["af8f66",ivory],9)
            else:
                p.sweep([start,(s*.23,muzzle+.42,-.56),(s*.325,muzzle+.54,-.487),(s*.38,muzzle+.84,-.59)],
                        [.096,.079,.068,.005],["595d61","79979a","b2d7d6"],7)
    if style in ["wolf","storm","lizard","ram"]:
        for j in range(7):
            z=-.515+j*.15
            base=h+.176+(.095 if j<5 else .049)
            if style=="ram":
                for s in (-1,1):
                    leaf(p,(s*.19,base,z),(s*.30,base-.233,z+.18),.104,["97aaab","b0b9af","a9b6b1"][j%3])
            else:
                leaf(p,(0,base-.032,z-.058),(0,base+.15+.048*cos(j),z+.167),.096,
                     ["87a78d","6c8e83","a9b29a"][j%3] if style=="wolf" else ["c19063","dba35e","c77d53"][j%3])
    if style in ["deer","marten","rabbit"]:
        for s in (-1,1):
            for j in range(7):
                z=-.13+j*.091
                p.oval((s*(.298+.024*cos(j*.89)),h+.137+.027*sin(2*j),z),(.013,.026,.043),underside)
    export(name,parts)

def shellfish(name, coat, giant, scorpion=False):
    p=Part("Body")
    parts=[p]
    p.loft([(.26,.31,.41),(.31,.53,.48),(.39,.649,.552),(.427,.672,.568),(.447,.662,.555),
            (.515,.619,.503),(.610,.518,.395),(.678,.283,.244),(.70,.081,.059)],
           ["897857",coat,"e1c28b",coat,coat,coat,"9ba78a",coat],26)
    for side in (-1,1):
        for j in range(4):
            z=-.267+.153*j
            p.sweep([(side*.11,.667,z*.65),(side*.262,.633,z),(side*.448,.574,z+.057)],
                    [.012,.015,.005],"7a8170",8)
            p.oval((side*(.370+.037*cos(j)),.592,z+.032),(.032,.018,.041),"c5b990")
    for s in (-1,1):
        p.sweep([(s*.22,.483,-.415),(s*.251,.596,-.524),(s*.273,.644,-.551)],[.059,.043,.037],coat)
        for j in range(5):
            z=-.29+j*.153
            p.sweep([(s*.403,.536,z),(s*.540,.515,z+.022),(s*(.644+.059*sin(j)),.54,z+.102)],
                    [.082,.068,.004],["9b9b78","ddc291"],8)
        p.sweep([(s*.111,.423,-.443),(s*.146,.466,-.653),(s*.21,.488,-.806)],[.016,.011,.002],brass,7)
    eye(p,.266,.635,-.546)
    paws(parts,.343,.458,.71,coat,wide=True,rows=3)
    for s in (-1,1):
        claw=walk_piece(parts,(s*.42,.42,-.26))
        claw.sweep([(0,0,0),(s*.168,.072,-.07),(s*.297,.071,-.16)],[.110,.121,.084],coat)
        claw.oval((s*.345,.117,-.295),(.173,.166,.235),coat)
        for k in (-1,1):
            claw.sweep([(s*(.343+k*.091),.119,-.386),(s*(.343+k*.12),.165,-.504),
                        (s*(.343+k*.057),.205,-.638)],[.083,.066,.007],[coat,"e4c18c"],12)
    if scorpion:
        path=[(0,.482,.31),(.028,.580,.701),(.05,.836,.98),(.04,1.163,1.047),
              (.02,1.435,.921),(0,1.510,.674),(-.045,1.42,.494)]
        for i,(a,b) in enumerate(zip(path,path[1:])):
            mid=tuple(Vector(a).lerp(Vector(b),.55))
            rad=.199-i*.014
            p.sweep([a,mid,b],[rad*.68,rad,rad*.73],[coat,"ad895c"],14)
        p.sweep([path[-1],(-.079,1.359,.423),(-.095,1.196,.394)],[.087,.062,.003],"5e5148",10)
    elif giant:
        p.oval((0,.769,.162),(.548,.478,.541),"ae8e63")
        path=[]
        for i in range(68):
            a=i*.166
            r=.024+.034*a
            path.append((r*cos(a),.795+r*sin(a),-.374+.178*(r/.401)**2))
        p.sweep(path,[.028+i*.00033 for i in range(68)],"dbc399",8)
        p.sweep([(-.351,.638,-.306),(.418,1.406,.062)],[.052,.053],"536968")
        p.sweep([(-.533,.801,-.35),(-.356,.620,-.31),(-.088,.609,-.32)],[.025,.067,.017],"566d6a")
    export(name,parts)

def swimmer(name, ray, coat, side_color):
    p=Part("Body")
    parts=[p]
    horizontal(p,[(-.794,.48,.045,.04),(-.71,.5,.177,.110),(-.53,.52,.285,.158 if ray else .218),
                  (-.26,.53,.330,.173 if ray else .279),(.0,.502,.299,.159 if ray else .296),
                  (.31,.48,.213,.132 if ray else .227),(.57,.453,.128,.087 if ray else .122),
                  (.78,.470,.060,.048 if ray else .076)],coat,side_color)
    for s in (-1,1):
        fin=walk_piece(parts,(s*.201,.49,-.196))
        tip=(s*1.127,.107,.272) if ray else (s*.358,-.212,.26)
        outline=[(0,.039,-.274),(s*.241,.012,-.123),tip,(s*(.54 if ray else .169),-.093,.359),
                 (s*.185,-.055,.564),(0,-.01,.418)]
        fin.panel(outline,coat,.028)
        for j in range(3):
            root=(0,.017,-.166+j*.14)
            end=tuple(Vector(tip).lerp(Vector(outline[3]),j*.30))
            fin.sweep([root,(s*.14,.019-j*.014,-.023+j*.075),end],[.020,.015,.002],side_color,7)
        for j in range(6):
            z=-.368+j*.135
            p.oval((s*(.288-.021*abs(j-1)),.616+.024*cos(j),z),(.021,.025,.050),side_color)
    if ray:
        p.sweep([(0,.47,.62),(0,.476,.933),(.034,.524,1.26),(.092,.618,1.535)],
                [.097,.060,.027,.005],[coat,side_color,coat],14)
        eye(p,.183,.622,-.477)
    else:
        p.panel([(0,.50,.70),(0,.76,1.125),(0,.607,1.10),(0,.47,.985),(0,.332,1.14),(0,.262,1.112),(0,.408,.706)],side_color,.012,axis=0)
        # Tail membranes have thickness across X as they lie in the sagittal plane.
        p.panel([(0,.704,-.269),(0,.862,-.147),(0,1.065,.168),(0,.854,.16),
                 (0,.706,.29)],side_color,.025,axis=0)
        p.sweep([(0,.687,-.273),(0,.867,-.147),(0,1.070,.171),(0,.698,.29)],
                [.057,.058,.014,.024],side_color,8)
        eye(p,.236,.586,-.555)
    export(name,parts)
def grouse():
    p=Part("Body")
    parts=[p]
    horizontal(p,[(-.59,.74,.059,.075),(-.48,.766,.155,.156),(-.36,.742,.189,.188),
                  (-.28,.593,.163,.200),(-.21,.476,.222,.221),(.0,.439,.268,.246),
                  (.21,.426,.235,.196),(.401,.436,.118,.105)],"dedccc","f0e6cc")
    p.sweep([(0,.766,-.519),(0,.73,-.644),(0,.715,-.694)],[.061,.042,.005],"877655",10)
    eye(p,.143,.795,-.474,.031)
    for s in (-1,1):
        for j in range(5):
            p.sweep([(s*.203,.545,-.077+j*.045),(s*(.262-j*.004),.436,.075+j*.057),
                     (s*(.234-j*.014),.35+j*.014,.191+j*.060)],
                    [.061,.072,.012],["a4b1a9","c4c6b7"],10,.60)
        for j in range(3):
            leaf(p,(s*.108,.50,.262),(s*(.111+j*.047),.63-j*.018,.674-j*.044),.066,
                 ["8f9c95","b4bcae","c7cbb9"][j])
        leg=walk_piece(parts,(s*.096,.253,0))
        leg.sweep([(0,0,0),(.016*s,-.136,.037),(.023*s,-.218,-.008)],[.041,.022,.018],"a68a65")
        for j in range(3):
            leg.sweep([(.022*s,-.215,-.006),(.02*s+(j-1)*.048,-.232,-.093+.02*abs(j-1))],
                      [.016,.003],"937c60",7)
    export("snow_prey",parts)

def sentinel(name,boss):
    p=Part("Body")
    parts=[p]
    plate="526e76" if boss else "657667"
    bronze="c49e63" if boss else "a99a70"
    metal="354b55" if boss else "404f49"
    p.loft([(.337,.431,.31),(.390,.559,.381),(.445,.584,.393),(.732,.506,.341),(1.020,.458,.310),
            (1.270,.394,.279),(1.383,.451,.31),(1.719,.530,.350),(1.944,.491,.323),(2.006,.278,.225)],
           [metal,bronze,plate,metal,plate,bronze,metal,plate,metal],18)
    for i in range(12):
        a=tau*i/12
        x,z=sin(a),cos(a)
        p.sweep([(.447*x,1.055,.312*z),(.505*x,.798,.35*z),(.568*x,.486,.39*z)],
                [.022,.019,.019],bronze,8)
    p.loft([(1.704,.613,.398),(1.744,.701,.426),(1.778,.718,.437),(1.846,.692,.420),
            (1.981,.58,.386),(2.084,.371,.259)], [metal,bronze,"49636a",plate,plate],20)
    p.loft([(2.029,.215,.194),(2.071,.269,.233),(2.142,.317,.264),(2.346,.326,.271),
            (2.492,.289,.245),(2.559,.194,.174)],metal,20)
    p.loft([(2.453,.307,.261),(2.478,.373,.301),(2.508,.38,.313),(2.545,.337,.286),
            (2.604,.224,.206),(2.651,.054,.056)],[bronze,metal,bronze,plate,plate],18)
    for s in (-1,1):
        p.sweep([(s*.495,1.889,0),(s*.609,1.720,-.01),(s*.653,1.511,-.027),(s*.695,1.355,-.071),
                 (s*.707,1.213,-.109),(s*.694,1.112,-.119)],
                [.183,.182,.125,.167,.124,.085],[plate,metal,bronze,plate,metal],14)
        p.sweep([(s*.261,2.46,.073),(s*.32,2.593,.085),(s*.372,2.799,.141),(s*.346,2.922,.181)],
                [.059,.063,.035,.006],bronze,9)
    for j in range(4):
        w=.205-.031*j
        p.sweep([(-w,1.725-j*.113,-.31),(0,1.667-j*.113,-.36),(w,1.725-j*.113,-.31)],
                [.009,.021,.009],bronze,7)
    p.sweep([(.701,.125,-.16),(.702,1.578,-.16),(.702,2.489,-.16),(.702,2.751,-.16)],
            [.046,.041,.047,.035],["9d865e","8b795b",bronze],10)
    if boss:
        p.panel([(.69,2.73,-.157),(.82,2.83,-.157),(1.012,2.759,-.157),(1.146,2.61,-.157),
                 (1.174,2.425,-.157),(.965,2.514,-.157),(.789,2.54,-.157),(.69,2.507,-.157)],"afbfba",.056)
    else:
        p.sweep([(.701,2.431,-.16),(.827,2.53,-.16),(.898,2.712,-.16)],[.041,.044,.003],bronze,9)
    for s in (-1,1):
        leg=walk_piece(parts,(s*.267,.561,0))
        leg.loft([(-.517,.151,.187,-.052),(-.481,.155,.192,-.052),(-.389,.134,.152,-.034),
                  (-.345,.106,.105),(-.213,.127,.127),(-.181,.131,.131),(-.047,.097,.10),(.014,.094,.097)],
                 [metal,plate,metal,plate,bronze,metal,metal],12)
    export(name,parts)

land_animal("hound","496562","91a38a","wolf")
land_animal("lizard","806957","cf9b6a","lizard")
shellfish("crab","bc7c59",False)
swimmer("fin",False,"538581","afc8ac")
sentinel("elite",False)
sentinel("boss",True)
grouse()
land_animal("snow_champion","8d9fa0","dce0cf","ram")
shellfish("tide_prey","648c81",False)
shellfish("tide_champion","728778",True)
land_animal("volcano_prey","88816b","cbab80","lizard")
land_animal("volcano_champion","77685d","b99979","storm")
land_animal("desert_prey","c09a73","eed5a5","rabbit")
shellfish("desert_champion","bd986b",True,True)
swimmer("lake_prey",False,"729e9f","d0d9bc")
swimmer("lake_champion",True,"5f969a","accaaf")
land_animal("forest_prey","85705b","c0b7a1","marten")
land_animal("forest_champion","957458","d5bc89","deer")

# Retain an editable gallery of the fitted meshes and packed pigment atlases.
bpy.ops.object.select_all(action="DESELECT")
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type == "VIEW_3D":
            space=area.spaces.active
            space.overlay.show_extras=False
            space.shading.color_type="TEXTURE"
            space.shading.light="STUDIO"
            space.region_3d.view_distance=21
            space.region_3d.view_rotation=Vector((-.19,-.76,-.63)).to_track_quat("-Z","Y")
            space.region_3d.view_location=(0,-5.1,.7)
source=ROOT/"art_source"
source.mkdir(exist_ok=True)
bpy.context.preferences.filepaths.save_version=0
for image in bpy.data.images:
    if image.packed_file:
        image.filepath_raw="//"+image.name
bpy.ops.wm.save_as_mainfile(filepath=str(source/"Greybay_Cast.blend"),compress=True)
